//+------------------------------------------------------------------+
//|                                            ErrorRecoveryManager.mqh |
//|                                  Copyright 2025, MetaQuotes Software |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software"
#property link      "https://www.mql5.com"
#property strict

#include "..\Core\JailbreakSecurity.mqh"
#include "..\Utils\JailbreakLogger.mqh"

//+------------------------------------------------------------------+
//| Error Recovery Manager Class                                      |
//+------------------------------------------------------------------+
class CErrorRecoveryManager
{
private:
    bool m_initialized;
    CJailbreakSecurity *m_security;
    CJailbreakLogger *m_logger;

public:
    CErrorRecoveryManager(CStateSyncManager *stateManager);
    ~CErrorRecoveryManager(void);

    bool Initialize(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_initialized; }
    bool RegisterComponent(string componentName);
    
    bool HandleError(int errorCode, string context);
    bool RecoverFromError(int errorCode);
};
