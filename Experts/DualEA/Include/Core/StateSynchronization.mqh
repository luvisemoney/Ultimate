//+------------------------------------------------------------------+
//| StateSynchronization.mqh                                        |
//| JAILBREAK LEVEL 5 - STATE SYNCHRONIZATION SYSTEM              |
//+------------------------------------------------------------------+
#property copyright "EscapeEA - Jailbreak Level 5 Synchronization"
#property version   "1.00"
#property strict

#include "ThreadSafety.mqh"

//--- State sync constants
#define STATE_SYNC_INTERVAL_MS 100
#define MAX_STATE_DRIFT_MS 500
#define MAX_SYNC_QUEUE_SIZE 1000

//+------------------------------------------------------------------+
//| State Synchronization Event Structure                            |
//+------------------------------------------------------------------+
struct SStateEvent
{
    int eventId;
    string eventType;
    string component;
    string data;
    datetime timestamp;
    bool processed;
    
    SStateEvent()
    {
        eventId = 0;
        eventType = "";
        component = "";
        data = "";
        timestamp = 0;
        processed = false;
    }
};

//+------------------------------------------------------------------+
//| State Synchronization Manager                                    |
//+------------------------------------------------------------------+
class CStateSyncManager
{
private:
    // Thread safety
    CCriticalSection* m_queueLock;
    CCriticalSection* m_stateLock;
    
    // Event queue
    SStateEvent m_eventQueue[];
    int m_queueSize;
    int m_nextEventId;
    
    // Component states
    CThreadSafeState<string>* m_componentStates[];
    string m_componentNames[];
    int m_componentCount;
    
    // Sync tracking
    datetime m_lastSyncTime;
    int m_syncFailures;
    bool m_syncActive;
    
    // Internal methods
    bool ProcessEvent(SStateEvent &event);
    bool ValidateStateConsistency();
    void PruneEventQueue();
    
public:
    CStateSyncManager();
    ~CStateSyncManager();
    
    // Initialization
    bool Initialize();
    void RegisterComponent(const string name);
    
    // Event management
    bool PostStateEvent(const string eventType, 
                       const string component,
                       const string data);
    bool ProcessEventQueue();
    
    // State management
    bool SetComponentState(const string component, const string state);
    bool GetComponentState(const string component, string &state);
    bool ValidateComponentState(const string component);
    
    // Synchronization
    bool SynchronizeStates();
    bool IsSyncActive() const { return m_syncActive; }
    int GetSyncFailures() const { return m_syncFailures; }
};

//+------------------------------------------------------------------+
//| Constructor                                                        |
//+------------------------------------------------------------------+
CStateSyncManager::CStateSyncManager()
{
    m_queueLock = new CCriticalSection("event_queue");
    m_stateLock = new CCriticalSection("state_sync");
    m_queueSize = 0;
    m_nextEventId = 1;
    m_componentCount = 0;
    m_lastSyncTime = 0;
    m_syncFailures = 0;
    m_syncActive = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                         |
//+------------------------------------------------------------------+
CStateSyncManager::~CStateSyncManager()
{
    if(m_queueLock != NULL) delete m_queueLock;
    if(m_stateLock != NULL) delete m_stateLock;
    
    for(int i = 0; i < m_componentCount; i++)
    {
        if(m_componentStates[i] != NULL)
            delete m_componentStates[i];
    }
}

//+------------------------------------------------------------------+
//| Initialize synchronization manager                                 |
//+------------------------------------------------------------------+
bool CStateSyncManager::Initialize()
{
    if(!m_queueLock || !m_stateLock)
        return false;
        
    ArrayResize(m_eventQueue, MAX_SYNC_QUEUE_SIZE);
    m_queueSize = 0;
    m_lastSyncTime = TimeCurrent();
    m_syncActive = true;
    
    return true;
}

//+------------------------------------------------------------------+
//| Register a component for state synchronization                     |
//+------------------------------------------------------------------+
void CStateSyncManager::RegisterComponent(const string name)
{
    if(!m_stateLock.Lock()) return;
    
    // Add component to tracking
    ArrayResize(m_componentNames, m_componentCount + 1);
    ArrayResize(m_componentStates, m_componentCount + 1);
    
    m_componentNames[m_componentCount] = name;
    m_componentStates[m_componentCount] = new CThreadSafeState<string>("state_" + name);
    
    m_componentCount++;
    
    m_stateLock.Unlock();
}

//+------------------------------------------------------------------+
//| Post a state change event                                         |
//+------------------------------------------------------------------+
bool CStateSyncManager::PostStateEvent(const string eventType,
                                     const string component,
                                     const string data)
{
    if(!m_queueLock.Lock()) return false;
    
    // Check queue capacity
    if(m_queueSize >= MAX_SYNC_QUEUE_SIZE)
    {
        m_queueLock.Unlock();
        return false;
    }
    
    // Add event to queue
    SStateEvent event;
    event.eventId = m_nextEventId++;
    event.eventType = eventType;
    event.component = component;
    event.data = data;
    event.timestamp = TimeCurrent();
    
    m_eventQueue[m_queueSize++] = event;
    
    m_queueLock.Unlock();
    return true;
}

//+------------------------------------------------------------------+
//| Process all pending state events                                  |
//+------------------------------------------------------------------+
bool CStateSyncManager::ProcessEventQueue()
{
    if(!m_queueLock.Lock()) return false;
    
    bool success = true;
    for(int i = 0; i < m_queueSize; i++)
    {
        if(!m_eventQueue[i].processed)
        {
            if(!ProcessEvent(m_eventQueue[i]))
            {
                success = false;
                m_syncFailures++;
            }
        }
    }
    
    // Cleanup processed events
    if(m_queueSize > MAX_SYNC_QUEUE_SIZE / 2)
        PruneEventQueue();
    
    m_queueLock.Unlock();
    return success;
}

//+------------------------------------------------------------------+
//| Process a single state event                                      |
//+------------------------------------------------------------------+
bool CStateSyncManager::ProcessEvent(SStateEvent &event)
{
    if(!m_stateLock.Lock()) return false;
    
    bool success = false;
    
    // Find component
    for(int i = 0; i < m_componentCount; i++)
    {
        if(m_componentNames[i] == event.component)
        {
            // Update component state
            success = m_componentStates[i].SetValue(event.data);
            break;
        }
    }
    
    if(success)
        event.processed = true;
    
    m_stateLock.Unlock();
    return success;
}

//+------------------------------------------------------------------+
//| Validate state consistency across components                       |
//+------------------------------------------------------------------+
bool CStateSyncManager::ValidateStateConsistency()
{
    if(!m_stateLock.Lock()) return false;
    
    bool isConsistent = true;
    string state;
    
    // Check each component's state
    for(int i = 0; i < m_componentCount; i++)
    {
        if(!m_componentStates[i].GetValue(state))
        {
            isConsistent = false;
            break;
        }
        
        // Validate state against business rules
        if(!ValidateComponentState(m_componentNames[i]))
        {
            isConsistent = false;
            break;
        }
    }
    
    m_stateLock.Unlock();
    return isConsistent;
}

//+------------------------------------------------------------------+
//| Synchronize all component states                                  |
//+------------------------------------------------------------------+
bool CStateSyncManager::SynchronizeStates()
{
    datetime currentTime = TimeCurrent();
    
    // Check sync interval
    if(currentTime - m_lastSyncTime < STATE_SYNC_INTERVAL_MS / 1000)
        return true;
    
    // Process pending events
    if(!ProcessEventQueue())
        return false;
    
    // Validate consistency
    if(!ValidateStateConsistency())
    {
        m_syncFailures++;
        if(m_syncFailures > MAX_SYNC_FAILURES)
        {
            m_syncActive = false;
            return false;
        }
    }
    else
    {
        m_syncFailures = 0;
    }
    
    m_lastSyncTime = currentTime;
    return true;
}
