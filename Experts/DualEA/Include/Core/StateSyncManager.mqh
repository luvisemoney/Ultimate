//+------------------------------------------------------------------+
//|                                                StateSyncManager.mqh |
//|                                  Copyright 2025, MetaQuotes Software |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software"
#property link      "https://www.mql5.com"
#property strict

#include "..\Core\JailbreakSecurity.mqh"

//+------------------------------------------------------------------+
//| State Synchronization Manager Class                              |
//+------------------------------------------------------------------+
class CStateSyncManager
{
private:
    bool m_initialized;
    CJailbreakSecurity *m_security;

public:
    CStateSyncManager(void);
    ~CStateSyncManager(void);

    bool Initialize(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_initialized; }
    bool RegisterComponent(string componentName);
};
