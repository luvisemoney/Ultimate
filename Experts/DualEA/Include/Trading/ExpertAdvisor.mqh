//+------------------------------------------------------------------+
//|                                                   ExpertAdvisor.mqh |
//|                                  Copyright 2025, MetaQuotes Software |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software"
#property link      "https://www.mql5.com"
#property strict

#include <Trade\Trade.mqh>
#include "..\Core\JailbreakSecurity.mqh"
#include "..\Risk\InstitutionalRiskManager.mqh"
#include "..\Performance\PerformanceMonitor.mqh"
#include "..\Signals\AdvancedSignalProcessor.mqh"

//+------------------------------------------------------------------+
//| Base Expert Advisor class for Paper and Live trading              |
//+------------------------------------------------------------------+
class CExpertAdvisor
{
protected:
    CTrade *m_trade;
    CJailbreakSecurity *m_security;
    CInstitutionalRiskManager *m_riskManager;
    CPerformanceMonitor *m_perfMonitor;
    CAdvancedSignalProcessor *m_signalProcessor;
    
    bool m_isInitialized;
    string m_symbol;
    ENUM_TIMEFRAMES m_timeframe;
    
public:
    CExpertAdvisor(void);
    ~CExpertAdvisor(void);
    
    // Virtual interface
    virtual bool Init(string symbol, ENUM_TIMEFRAMES timeframe);
    virtual void Deinit(void);
    virtual bool ProcessTick(void);
    virtual bool ProcessSignal(void);
    virtual bool ExecuteTrade(void);
    
    // Common functionality
    bool IsInitialized(void) const { return m_isInitialized; }
    string GetSymbol(void) const { return m_symbol; }
    ENUM_TIMEFRAMES GetTimeframe(void) const { return m_timeframe; }
};
