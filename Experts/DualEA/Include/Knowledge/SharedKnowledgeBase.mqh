//+------------------------------------------------------------------+
//|                                              SharedKnowledgeBase.mqh |
//|                                  Copyright 2025, MetaQuotes Software |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software"
#property link      "https://www.mql5.com"
#property strict

#include "..\Core\JailbreakSecurity.mqh"
#include "..\Utils\JailbreakLogger.mqh"

//+------------------------------------------------------------------+
//| Signal metrics structure                                         |
//+------------------------------------------------------------------+
struct SSignalMetrics
{
    string name;
    double profitFactor;
    double winRate;
    double avgProfit;
    int totalSignals;
    datetime lastUpdate;
};

//+------------------------------------------------------------------+
//| Strategy performance structure                                   |
//+------------------------------------------------------------------+
struct SStrategyPerformance
{
    string name;
    double netProfit;
    double profitFactor;
    double drawdown;
    double recovery;
    int trades;
    datetime lastTrade;
};

//+------------------------------------------------------------------+
//| Shared Knowledge Base for Paper-Live EA Integration                |
//+------------------------------------------------------------------+
class CSharedKnowledgeBase
{
private:
    string m_knowledgeBasePath;
    bool m_isInitialized;
    CJailbreakSecurity *m_security;
    CJailbreakLogger *m_logger;
    bool m_inUse;
    
    // Sync state tracking
    datetime m_lastSyncTime;
    int m_successfulSyncs;
    int m_failedSyncs;
    double m_avgSyncLatency;
    
    // Signal confidence tracking
    public:
        struct SSignalMetrics {
            double winRate;
            double profitFactor;
            double avgWin;
            double avgLoss;
            int totalTrades;
            datetime lastUpdated;
        };
    
    // Strategy performance tracking
    struct SStrategyPerformance {
        string strategyName;
        double sharpeRatio;
        double sortinoRatio;
        double maxDrawdown;
        int consecutiveWins;
        int consecutiveLosses;
    };

    bool ValidateAccess(string operation)
    {
        if(!m_security) return false;
        return m_security.ValidatePaperLiveSync();
    }

public:
    CSharedKnowledgeBase(void)
    {
        m_isInitialized = false;
        m_security = new CJailbreakSecurity();
    }

    ~CSharedKnowledgeBase(void)
    {
        if(m_security) delete m_security;
    }

    bool Initialize(string path = "Data\\KnowledgeBase\\")
    {
        if(!m_security.Initialize()) return false;
        
        m_knowledgeBasePath = path;
        if(!CreateDirectory(path)) return false;
        
        m_isInitialized = true;
        return true;
    }

    bool UpdateSignalMetrics(string signalId, double profit, bool wasWin)
    {
        if(!ValidateAccess("UPDATE")) return false;
        
        string filename = m_knowledgeBasePath + "signals\\" + signalId + ".json";
        return SaveSignalMetrics(filename, profit, wasWin);
    }

    bool UpdateStrategyPerformance(string strategyName, SStrategyPerformance &metrics)
    {
        if(!ValidateAccess("UPDATE")) return false;
        
        string filename = m_knowledgeBasePath + "strategies\\" + strategyName + ".json";
        return SaveStrategyMetrics(filename, metrics);
    }

    bool GetTopSignals(SSignalMetrics &signals[], int count = 10)
    {
        if(!ValidateAccess("READ")) return false;
        return LoadTopSignals(signals, count);
    }

    bool GetBestStrategies(SStrategyPerformance &strategies[], int count = 5)
    {
        if(!ValidateAccess("READ")) return false;
        return LoadBestStrategies(strategies, count);
    }

private:
    bool SaveSignalMetrics(string filename, double profit, bool wasWin);
    bool SaveStrategyMetrics(string filename, SStrategyPerformance &metrics);
    bool LoadTopSignals(SSignalMetrics &signals[], int count);
    bool LoadBestStrategies(SStrategyPerformance &strategies[], int count);
};
