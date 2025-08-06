//+------------------------------------------------------------------+
//|                                                        PaperEA.mqh |
//|                                  Copyright 2025, MetaQuotes Software |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software"
#property link      "https://www.mql5.com"
#property strict

#include "ExpertAdvisor.mqh"
#include "..\Knowledge\SharedKnowledgeBase.mqh"
#include "..\Signals\AdvancedSignalProcessor.mqh"
#include "..\Performance\PerformanceMonitor.mqh"
#include "..\Core\JailbreakSecurity.mqh"
#include "..\Risk\InstitutionalRiskManager.mqh"
#include "..\Utils\JailbreakLogger.mqh"
#include "..\Trading\Trade.mqh"
#include "..\Core\EmergencyCircuitBreaker.mqh"

//+------------------------------------------------------------------+
//| Paper EA Class - Advanced Learning & Strategy Development          |
//+------------------------------------------------------------------+
class CPaperEA : public CExpertAdvisor
{
private:
    CSharedKnowledgeBase *m_knowledgeBase;
   CJailbreakSecurity *m_security_local;
   CInstitutionalRiskManager *m_riskManager_local;
   CPerformanceMonitor *m_perfMonitor_local;
   CAdvancedSignalProcessor *m_signalProcessor_local;
   CTrade *m_trade_local;
    
    // Learning parameters
    double m_learningRate;
    int m_epochCount;
    int m_minTradesForSignal;
    double m_minConfidenceThreshold;
    
    bool ValidateComponents(void)
    {
        if(!m_security || !m_knowledgeBase || !m_riskManager || 
           !m_perfMonitor || !m_signalProcessor || !m_trade)
            return false;
            
        return true;
    }
    
    bool ProcessSignals(void)
    {
        if(!ValidateComponents()) return false;
        
        double signal = m_signalProcessor.ProcessPaperLiveSignal("PAPER");
        if(signal > m_minConfidenceThreshold)
        {
            return ExecutePaperTrade(signal);
        }
        
        return false;
    }
    
    bool ExecutePaperTrade(double confidence)
    {
        if(!m_trade) return false;
        
        // Paper trade execution with zero risk
        bool result = m_trade.Buy(0.1, Symbol(), 0, 0, 0, "PAPER_TRADE");
        
        if(result)
        {
            UpdateKnowledgeBase(confidence);
            m_perfMonitor.MonitorPaperLiveSync();
        }
        
        return result;
    }
    
    void UpdateKnowledgeBase(double confidence)
    {
        if(!m_knowledgeBase) return;
        
        string signalId = m_signalProcessor.GetCurrentSignalId();
        double profit = m_trade.ResultProfit();
        bool wasWin = profit > 0;
        
        m_knowledgeBase.UpdateSignalMetrics(signalId, profit, wasWin);
    }

public:
    CPaperEA(void)
    {
        m_knowledgeBase = new CSharedKnowledgeBase();
        m_security = new CJailbreakSecurity();
        m_riskManager = new CInstitutionalRiskManager();
        m_perfMonitor = new CPerformanceMonitor();
        m_signalProcessor = new CAdvancedSignalProcessor();
        m_trade = new CTrade();
        
        m_learningRate = 0.001;
        m_epochCount = 1000;
        m_minTradesForSignal = 100;
        m_minConfidenceThreshold = 0.8;
    }
    
    ~CPaperEA(void)
    {
        if(m_knowledgeBase) delete m_knowledgeBase;
        if(m_security) delete m_security;
        if(m_riskManager) delete m_riskManager;
        if(m_perfMonitor) delete m_perfMonitor;
        if(m_signalProcessor) delete m_signalProcessor;
        if(m_trade) delete m_trade;
    }
    
    bool Initialize(void)
    {
        if(!m_security.Initialize()) return false;
        if(!m_knowledgeBase.Initialize()) return false;
        if(!m_riskManager.Initialize()) return false;
        if(!m_perfMonitor.Initialize()) return false;
        if(!m_signalProcessor.Initialize()) return false;
        
        m_trade.SetExpertMagicNumber(EXPERT_MAGIC);
        m_trade.SetMarginMode();
        m_trade.SetTypeFillingBySymbol(Symbol());
        
        return true;
    }
    
    void OnTick(void)
    {
        if(!ValidateComponents()) return;
        
        // Process market data and execute paper trades
        ProcessSignals();
    }
};
