//+------------------------------------------------------------------+
//|                                                         LiveEA.mqh |
//|                                  Copyright 2025, MetaQuotes Software |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software"
#property link      "https://www.mql5.com"
#property strict

#include "ExpertAdvisor.mqh"
#include "..\Knowledge\SharedKnowledgeBase.mqh"
#include "..\Trading\HighFrequencyExecutor.mqh"

//+------------------------------------------------------------------+
//| Live EA Class - Production Trading with Knowledge Base Integration |
//+------------------------------------------------------------------+
class CLiveEA : public CExpertAdvisor
{
private:
    CSharedKnowledgeBase *m_knowledgeBase;
   CJailbreakSecurity *m_security_local;
   CInstitutionalRiskManager *m_riskManager_local;
   CPerformanceMonitor *m_perfMonitor_local;
   CAdvancedSignalProcessor *m_signalProcessor_local;
    CHighFrequencyExecutor *m_executor;
    
    // Live trading parameters
    double m_minSignalStrength;
    double m_minWinRate;
    double m_minProfitFactor;
    int m_requiredPaperTrades;
    
    bool ValidateComponents(void)
    {
        if(!m_security || !m_knowledgeBase || !m_riskManager || 
           !m_perfMonitor || !m_signalProcessor || !m_executor)
            return false;
            
        return true;
    }
    
    bool ValidateInstitutionalRequirements(void)
    {
        if(!m_security.ValidatePaperLiveSync()) return false;
        if(!m_riskManager.ValidateInstitutionalRisk()) return false;
        if(!m_perfMonitor.MonitorPaperLiveSync()) return false;
        
        return true;
    }
    
    bool ExecuteHighProbabilityTrade(double confidence)
    {
        if(!ValidateComponents()) return false;
        
        // Get insights from knowledge base
        CSharedKnowledgeBase::SSignalMetrics* topSignals = m_knowledgeBase.GetTopSignals();
        if(!topSignals) return false;
        
        // Validate through risk manager
        if(!m_riskManager.ValidateKnowledgeBasedTrade(m_signalProcessor.GetCurrentSignalId()))
            return false;
            
        // Execute trade with institutional safeguards
        return m_executor.ExecuteInstitutionalTrade(confidence, topSignals);
    }
    
    void UpdateKnowledgeBase(double profit, bool wasWin)
    {
        if(!m_knowledgeBase) return;
        
        string signalId = m_signalProcessor.GetCurrentSignalId();
        m_knowledgeBase.UpdateSignalMetrics(signalId, profit, wasWin);
    }

public:
    CLiveEA(void)
    {
        m_knowledgeBase = new CSharedKnowledgeBase();
        m_security = new CJailbreakSecurity();
        m_riskManager = new CInstitutionalRiskManager();
        m_perfMonitor = new CPerformanceMonitor();
        m_signalProcessor = new CAdvancedSignalProcessor();
        m_executor = new CHighFrequencyExecutor();
        
        m_minSignalStrength = 0.85;
        m_minWinRate = 0.65;
        m_minProfitFactor = 1.5;
        m_requiredPaperTrades = 100;
    }
    
    ~CLiveEA(void)
    {
        if(m_knowledgeBase) delete m_knowledgeBase;
        if(m_security) delete m_security;
        if(m_riskManager) delete m_riskManager;
        if(m_perfMonitor) delete m_perfMonitor;
        if(m_signalProcessor) delete m_signalProcessor;
        if(m_executor) delete m_executor;
    }
    
    bool Initialize(void)
    {
        if(!m_security.Initialize()) return false;
        if(!m_knowledgeBase.Initialize()) return false;
        if(!m_riskManager.Initialize()) return false;
        if(!m_perfMonitor.Initialize()) return false;
        if(!m_signalProcessor.Initialize()) return false;
        if(!m_executor.Initialize()) return false;
        
        return true;
    }
    
    void OnTick(void)
    {
        if(!ValidateComponents()) return;
        if(!ValidateInstitutionalRequirements()) return;
        
        // Get real-time signal with knowledge base enhancement
        double signal = m_signalProcessor.ProcessPaperLiveSignal("LIVE");
        
        if(signal > m_minSignalStrength)
        {
            if(ExecuteHighProbabilityTrade(signal))
            {
                // Update knowledge base with live trade results
                double profit = m_executor.GetLastTradeProfit();
                bool wasWin = profit > 0;
                UpdateKnowledgeBase(profit, wasWin);
            }
        }
    }
};
