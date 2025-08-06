//+------------------------------------------------------------------+
//| ErrorRecovery.mqh                                              |
//| JAILBREAK LEVEL 5 - ERROR RECOVERY SYSTEM                    |
//+------------------------------------------------------------------+
#property copyright "EscapeEA - Jailbreak Level 5 Error Recovery"
#property version   "1.00"
#property strict

#include "ThreadSafety.mqh"
#include "StateSynchronization.mqh"

//--- Error recovery constants
#define MAX_RECOVERY_ATTEMPTS 3
#define RECOVERY_WAIT_MS 1000
#define STATE_BACKUP_INTERVAL_MS 5000
#define MAX_ERROR_THRESHOLD 5

//--- Error severity levels
enum ENUM_ERROR_SEVERITY
{
    ERROR_MINOR = 1,
    ERROR_MAJOR = 2,
    ERROR_CRITICAL = 3,
    ERROR_FATAL = 4
};

//+------------------------------------------------------------------+
//| Error Recovery Manager                                           |
//+------------------------------------------------------------------+
class CErrorRecoveryManager
{
private:
    // Core components
    CCriticalSection* m_recoveryLock;
    CStateSyncManager* m_stateManager;
    
    // Recovery state
    int m_recoveryAttempts;
    int m_errorCount;
    datetime m_lastBackup;
    bool m_isRecovering;
    
    // State backup
    string m_stateBackups[];
    datetime m_backupTimestamps[];
    int m_backupCount;
    
    // Error tracking
    struct SErrorEntry {
        int errorCode;
        string component;
        string description;
        ENUM_ERROR_SEVERITY severity;
        datetime timestamp;
    };
    SErrorEntry m_errorLog[];
    int m_errorLogSize;
    
    // Internal methods
    bool BackupComponentState(const string component);
    bool RestoreComponentState(const string component);
    bool ValidateStateRecovery(const string component);
    void LogError(const SErrorEntry &error);
    bool CanAttemptRecovery() const;
    
public:
    CErrorRecoveryManager(CStateSyncManager* stateManager);
    ~CErrorRecoveryManager();
    
    // Initialization
    bool Initialize();
    void RegisterComponent(const string component);
    
    // Error handling
    bool HandleError(int errorCode, 
                    const string component,
                    const string description,
                    ENUM_ERROR_SEVERITY severity);
    bool AttemptRecovery(const string component);
    bool PerformEmergencyRecovery();
    
    // State management
    bool BackupSystemState();
    bool RestoreSystemState();
    bool ValidateSystemState();
    
    // Status checks
    bool IsRecovering() const { return m_isRecovering; }
    int GetErrorCount() const { return m_errorCount; }
    int GetRecoveryAttempts() const { return m_recoveryAttempts; }
};

//+------------------------------------------------------------------+
//| Constructor                                                        |
//+------------------------------------------------------------------+
CErrorRecoveryManager::CErrorRecoveryManager(CStateSyncManager* stateManager)
{
    m_recoveryLock = new CCriticalSection("error_recovery");
    m_stateManager = stateManager;
    m_recoveryAttempts = 0;
    m_errorCount = 0;
    m_lastBackup = 0;
    m_isRecovering = false;
    m_backupCount = 0;
    m_errorLogSize = 0;
}

//+------------------------------------------------------------------+
//| Initialize error recovery system                                   |
//+------------------------------------------------------------------+
bool CErrorRecoveryManager::Initialize()
{
    if(!m_recoveryLock || !m_stateManager)
        return false;
    
    // Initialize arrays
    ArrayResize(m_stateBackups, 0);
    ArrayResize(m_backupTimestamps, 0);
    ArrayResize(m_errorLog, 100);
    
    m_lastBackup = TimeCurrent();
    return true;
}

//+------------------------------------------------------------------+
//| Handle system error                                                |
//+------------------------------------------------------------------+
bool CErrorRecoveryManager::HandleError(int errorCode,
                                      const string component,
                                      const string description,
                                      ENUM_ERROR_SEVERITY severity)
{
    if(!m_recoveryLock.Lock()) return false;
    
    // Log error
    SErrorEntry error;
    error.errorCode = errorCode;
    error.component = component;
    error.description = description;
    error.severity = severity;
    error.timestamp = TimeCurrent();
    
    LogError(error);
    
    // Handle based on severity
    bool handled = false;
    switch(severity)
    {
        case ERROR_MINOR:
            // Log and continue
            handled = true;
            break;
            
        case ERROR_MAJOR:
            // Attempt component recovery
            handled = AttemptRecovery(component);
            break;
            
        case ERROR_CRITICAL:
            // Attempt system-wide recovery
            handled = RestoreSystemState();
            break;
            
        case ERROR_FATAL:
            // Emergency shutdown
            PerformEmergencyRecovery();
            handled = false;
            break;
    }
    
    m_recoveryLock.Unlock();
    return handled;
}

//+------------------------------------------------------------------+
//| Attempt recovery for a specific component                          |
//+------------------------------------------------------------------+
bool CErrorRecoveryManager::AttemptRecovery(const string component)
{
    if(!CanAttemptRecovery())
        return false;
        
    m_isRecovering = true;
    m_recoveryAttempts++;
    
    // Try to restore component state
    bool recovered = RestoreComponentState(component);
    
    // Validate recovery
    if(recovered)
    {
        recovered = ValidateStateRecovery(component);
        if(recovered)
            m_errorCount = 0;
    }
    
    m_isRecovering = false;
    return recovered;
}

//+------------------------------------------------------------------+
//| Perform emergency recovery                                         |
//+------------------------------------------------------------------+
bool CErrorRecoveryManager::PerformEmergencyRecovery()
{
    if(!m_recoveryLock.Lock()) return false;
    
    m_isRecovering = true;
    
    // Stop all operations
    m_stateManager.PostStateEvent("EMERGENCY_STOP", "SYSTEM", "");
    
    // Attempt full system state restore
    bool recovered = RestoreSystemState();
    
    // Validate system state
    if(recovered)
        recovered = ValidateSystemState();
        
    if(!recovered)
    {
        // If recovery failed, initiate shutdown
        m_stateManager.PostStateEvent("EMERGENCY_SHUTDOWN", "SYSTEM", "");
    }
    
    m_isRecovering = false;
    m_recoveryLock.Unlock();
    return recovered;
}

//+------------------------------------------------------------------+
//| Backup system state                                               |
//+------------------------------------------------------------------+
bool CErrorRecoveryManager::BackupSystemState()
{
    if(!m_recoveryLock.Lock()) return false;
    
    datetime currentTime = TimeCurrent();
    if(currentTime - m_lastBackup < STATE_BACKUP_INTERVAL_MS / 1000)
    {
        m_recoveryLock.Unlock();
        return true;
    }
    
    bool success = true;
    string state;
    
    // Get state from each component
    for(int i = 0; i < m_backupCount; i++)
    {
        if(!m_stateManager.GetComponentState(m_stateBackups[i], state))
        {
            success = false;
            break;
        }
        
        m_stateBackups[i] = state;
        m_backupTimestamps[i] = currentTime;
    }
    
    if(success)
        m_lastBackup = currentTime;
    
    m_recoveryLock.Unlock();
    return success;
}

//+------------------------------------------------------------------+
//| Validate system state                                             |
//+------------------------------------------------------------------+
bool CErrorRecoveryManager::ValidateSystemState()
{
    if(!m_recoveryLock.Lock()) return false;
    
    // Check state consistency
    if(!m_stateManager.ValidateStateConsistency())
    {
        m_recoveryLock.Unlock();
        return false;
    }
    
    // Verify each component's state
    string state;
    for(int i = 0; i < m_backupCount; i++)
    {
        if(!ValidateStateRecovery(m_stateBackups[i]))
        {
            m_recoveryLock.Unlock();
            return false;
        }
    }
    
    m_recoveryLock.Unlock();
    return true;
}
