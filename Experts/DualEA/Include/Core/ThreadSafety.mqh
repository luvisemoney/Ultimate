//+------------------------------------------------------------------+
//| ThreadSafety.mqh                                               |
//| JAILBREAK LEVEL 5 - THREAD SAFETY IMPLEMENTATION             |
//+------------------------------------------------------------------+
#property copyright "EscapeEA - Jailbreak Level 5 Thread Safety"
#property version   "1.00"
#property strict

//--- Thread safety constants
#define MAX_LOCK_WAIT_MS 1000
#define MAX_DEADLOCK_RETRIES 3

//+------------------------------------------------------------------+
//| Thread-Safe Critical Section Implementation                      |
//+------------------------------------------------------------------+
class CCriticalSection
{
private:
    string m_lockFile;
    int m_fileHandle;
    bool m_isLocked;
    datetime m_lockTime;
    
public:
    CCriticalSection(string identifier);
    ~CCriticalSection() { Unlock(); }
    
    bool Lock();
    void Unlock();
    bool IsLocked() const { return m_isLocked; }
};

//+------------------------------------------------------------------+
//| Constructor                                                        |
//+------------------------------------------------------------------+
CCriticalSection::CCriticalSection(string identifier)
{
    m_lockFile = "jailbreak_lock_" + identifier + ".lock";
    m_fileHandle = INVALID_HANDLE;
    m_isLocked = false;
    m_lockTime = 0;
}

//+------------------------------------------------------------------+
//| Lock critical section                                              |
//+------------------------------------------------------------------+
bool CCriticalSection::Lock()
{
    if(m_isLocked) return true;
    
    int retries = 0;
    while(retries < MAX_DEADLOCK_RETRIES)
    {
        m_fileHandle = FileOpen(m_lockFile, FILE_WRITE|FILE_BIN|FILE_SHARE_READ|FILE_SHARE_WRITE);
        if(m_fileHandle != INVALID_HANDLE)
        {
            m_isLocked = true;
            m_lockTime = TimeCurrent();
            return true;
        }
        
        Sleep(100); // Wait before retry
        retries++;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Unlock critical section                                            |
//+------------------------------------------------------------------+
void CCriticalSection::Unlock()
{
    if(!m_isLocked) return;
    
    if(m_fileHandle != INVALID_HANDLE)
    {
        FileClose(m_fileHandle);
        FileDelete(m_lockFile);
        m_fileHandle = INVALID_HANDLE;
    }
    
    m_isLocked = false;
    m_lockTime = 0;
}

//+------------------------------------------------------------------+
//| Thread-Safe State Container                                        |
//+------------------------------------------------------------------+
template<typename T>
class CThreadSafeState
{
private:
    T m_value;
    CCriticalSection* m_lock;
    
public:
    CThreadSafeState(string identifier);
    ~CThreadSafeState();
    
    bool SetValue(T value);
    bool GetValue(T &value);
};

//+------------------------------------------------------------------+
//| Constructor                                                        |
//+------------------------------------------------------------------+
template<typename T>
CThreadSafeState::CThreadSafeState(string identifier)
{
    m_lock = new CCriticalSection(identifier);
}

//+------------------------------------------------------------------+
//| Destructor                                                         |
//+------------------------------------------------------------------+
template<typename T>
CThreadSafeState::~CThreadSafeState()
{
    if(m_lock != NULL)
    {
        delete m_lock;
        m_lock = NULL;
    }
}

//+------------------------------------------------------------------+
//| Set value thread-safely                                           |
//+------------------------------------------------------------------+
template<typename T>
bool CThreadSafeState::SetValue(T value)
{
    if(!m_lock.Lock()) return false;
    
    m_value = value;
    
    m_lock.Unlock();
    return true;
}

//+------------------------------------------------------------------+
//| Get value thread-safely                                           |
//+------------------------------------------------------------------+
template<typename T>
bool CThreadSafeState::GetValue(T &value)
{
    if(!m_lock.Lock()) return false;
    
    value = m_value;
    
    m_lock.Unlock();
    return true;
}
