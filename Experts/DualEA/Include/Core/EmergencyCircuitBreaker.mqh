//+------------------------------------------------------------------+
//| EmergencyCircuitBreaker.mqh                                      |
//| JAILBREAK LEVEL 5 - INSTITUTIONAL EMERGENCY SYSTEM              |
//| Maximum Protection Circuit Breaker Implementation               |
//+------------------------------------------------------------------+
#property copyright "EscapeEA - Jailbreak Level 5 Emergency System"
#property version   "1.00"
#property strict

#include "JailbreakSecurity.mqh"
#include "../Utils/JailbreakLogger.mqh"

//--- JAILBREAK EMERGENCY: Circuit breaker constants
#define CIRCUIT_BREAKER_COOLDOWN 300      // 5 minutes cooldown
#define MAX_EMERGENCY_TRIGGERS 3          // Max triggers per day
#define MARKET_VOLATILITY_THRESHOLD 0.05  // 5% volatility threshold
#define NEWS_EVENT_BUFFER_MINUTES 30      // 30 minutes before/after news

//--- JAILBREAK EMERGENCY: Emergency trigger types
enum ENUM_EMERGENCY_TRIGGER
{
    TRIGGER_NONE = 0,
    TRIGGER_DRAWDOWN = 1,
    TRIGGER_CONSECUTIVE_LOSSES = 2,
    TRIGGER_MARGIN_LEVEL = 3,
    TRIGGER_DAILY_TRADES = 4,
    TRIGGER_MARKET_CONDITIONS = 5,
    TRIGGER_VOLATILITY = 6,
    TRIGGER_NEWS_EVENT = 7,
    TRIGGER_SYSTEM_ERROR = 8
};

//+------------------------------------------------------------------+
//| JAILBREAK EMERGENCY: Circuit Breaker Class                      |
//+------------------------------------------------------------------+
class CEmergencyCircuitBreaker
{
private:
    // JAILBREAK EMERGENCY: Core parameters
    double m_maxDrawdownLimit;
    int m_maxConsecutiveLosses;
    double m_minMarginLevel;
    
    // JAILBREAK EMERGENCY: State tracking
    bool m_isInitialized;
    bool m_circuitBreakerTriggered;
    datetime m_lastTriggerTime;
    datetime m_cooldownEndTime;
    int m_dailyTriggerCount;
    datetime m_lastResetDate;
    
    // JAILBREAK EMERGENCY: Trigger history
    ENUM_EMERGENCY_TRIGGER m_lastTriggerType;
    string m_lastTriggerReason;
    double m_triggerValue;
    
    // JAILBREAK EMERGENCY: Market condition monitoring
    double m_lastPrice;
    double m_priceVolatility;
    datetime m_lastVolatilityCheck;
    
    // JAILBREAK EMERGENCY: Logger reference
    CJailbreakLogger* m_logger;
    
    // JAILBREAK EMERGENCY: Internal methods
    void TriggerEmergencyShutdown(ENUM_EMERGENCY_TRIGGER triggerType, const string& reason, double value);
    bool IsInCooldownPeriod();
    void ResetDailyCounters();
    double CalculateVolatility();
    bool IsNewsEventTime();
    
public:
    // JAILBREAK EMERGENCY: Constructor/Destructor
    CEmergencyCircuitBreaker(double maxDrawdown, int maxConsecutiveLosses);
    ~CEmergencyCircuitBreaker();
    
    // JAILBREAK EMERGENCY: Initialization
    bool Initialize(CJailbreakLogger* logger);
    void Cleanup();
    
    // JAILBREAK EMERGENCY: Core check methods
    bool CheckDrawdownLimit(double currentDrawdown);
    bool CheckConsecutiveLosses(int consecutiveLosses);
    bool CheckMarginLevel(double marginLevel);
    bool CheckDailyTradeLimit(int dailyTrades, int maxDailyTrades);
    bool CheckMarketConditions();
    bool CheckVolatilityLimits();
    
    // JAILBREAK EMERGENCY: Circuit breaker control
    bool IsCircuitBreakerTriggered() const { return m_circuitBreakerTriggered; }
    bool CanResetCircuitBreaker();
    bool ResetCircuitBreaker();
    void ForceEmergencyShutdown(const string& reason);
    
    // JAILBREAK EMERGENCY: Status and metrics
    ENUM_EMERGENCY_TRIGGER GetLastTriggerType() const { return m_lastTriggerType; }
    string GetLastTriggerReason() const { return m_lastTriggerReason; }
    datetime GetLastTriggerTime() const { return m_lastTriggerTime; }
    int GetDailyTriggerCount() const { return m_dailyTriggerCount; }
    double GetCurrentVolatility() const { return m_priceVolatility; }
};

//+------------------------------------------------------------------+
//| JAILBREAK EMERGENCY: Constructor                                 |
//+------------------------------------------------------------------+
CEmergencyCircuitBreaker::CEmergencyCircuitBreaker(double maxDrawdown, int maxConsecutiveLosses)
{
    m_maxDrawdownLimit = maxDrawdown;
    m_maxConsecutiveLosses = maxConsecutiveLosses;
    m_minMarginLevel = 200.0;  // Default 200% minimum
    
    m_isInitialized = false;
    m_circuitBreakerTriggered = false;
    m_lastTriggerTime = 0;
    m_cooldownEndTime = 0;
    m_dailyTriggerCount = 0;
    m_lastResetDate = 0;
    
    m_lastTriggerType = TRIGGER_NONE;
    m_lastTriggerReason = "";
    m_triggerValue = 0.0;
    
    m_lastPrice = 0.0;
    m_priceVolatility = 0.0;
    m_lastVolatilityCheck = 0;
    
    m_logger = NULL;
}

//+------------------------------------------------------------------+
//| JAILBREAK EMERGENCY: Destructor                                 |
//+------------------------------------------------------------------+
CEmergencyCircuitBreaker::~CEmergencyCircuitBreaker()
{
    Cleanup();
}

//+------------------------------------------------------------------+
//| JAILBREAK EMERGENCY: Initialize Circuit Breaker                 |
//+------------------------------------------------------------------+
bool CEmergencyCircuitBreaker::Initialize(CJailbreakLogger* logger)
{
    if(logger == NULL)
    {
        Print("JAILBREAK EMERGENCY ERROR: Logger is required for circuit breaker");
        return false;
    }
    
    m_logger = logger;
    
    // JAILBREAK EMERGENCY: Initialize state
    m_circuitBreakerTriggered = false;
    m_lastTriggerTime = 0;
    m_cooldownEndTime = 0;
    m_dailyTriggerCount = 0;
    m_lastResetDate = TimeCurrent();
    
    // JAILBREAK EMERGENCY: Initialize market monitoring
    m_lastPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    m_priceVolatility = 0.0;
    m_lastVolatilityCheck = TimeCurrent();
    
    m_isInitialized = true;
    
    m_logger.LogInfo("CIRCUIT_BREAKER", 
        StringFormat("Emergency circuit breaker initialized - MaxDrawdown: %.2f%%, MaxLosses: %d", 
                    m_maxDrawdownLimit * 100, m_maxConsecutiveLosses));
    
    return true;
}

//+------------------------------------------------------------------+
//| JAILBREAK EMERGENCY: Cleanup Circuit Breaker                    |
//+------------------------------------------------------------------+
void CEmergencyCircuitBreaker::Cleanup()
{
    if(m_isInitialized)
    {
        if(m_logger != NULL)
        {
            m_logger.LogInfo("CIRCUIT_BREAKER", "Emergency circuit breaker cleanup complete");
        }
        m_isInitialized = false;
    }
}

//+------------------------------------------------------------------+
//| JAILBREAK EMERGENCY: Check Drawdown Limit                       |
//+------------------------------------------------------------------+
bool CEmergencyCircuitBreaker::CheckDrawdownLimit(double currentDrawdown)
{
    if(!m_isInitialized || IsInCooldownPeriod()) return true;
    
    // JAILBREAK EMERGENCY: Reset daily counters if needed
    ResetDailyCounters();
    
    // JAILBREAK EMERGENCY: Check drawdown limit
    if(currentDrawdown > m_maxDrawdownLimit)
    {
        string reason = StringFormat("Drawdown limit exceeded: %.2f%% (max: %.2f%%)", 
                                   currentDrawdown * 100, m_maxDrawdownLimit * 100);
        TriggerEmergencyShutdown(TRIGGER_DRAWDOWN, reason, currentDrawdown);
        return false;
    }
    
    // JAILBREAK EMERGENCY: Warning at 80% of limit
    if(currentDrawdown > m_maxDrawdownLimit * 0.8)
    {
        if(m_logger != NULL)
        {
            m_logger.LogWarning("CIRCUIT_BREAKER", 
                StringFormat("Drawdown warning: %.2f%% (80%% of limit)", currentDrawdown * 100));
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| JAILBREAK EMERGENCY: Check Consecutive Losses                   |
//+------------------------------------------------------------------+
bool CEmergencyCircuitBreaker::CheckConsecutiveLosses(int consecutiveLosses)
{
    if(!m_isInitialized || IsInCooldownPeriod()) return true;
    
    // JAILBREAK EMERGENCY: Check consecutive losses limit
    if(consecutiveLosses >= m_maxConsecutiveLosses)
    {
        string reason = StringFormat("Consecutive losses limit exceeded: %d (max: %d)", 
                                   consecutiveLosses, m_maxConsecutiveLosses);
        TriggerEmergencyShutdown(TRIGGER_CONSECUTIVE_LOSSES, reason, consecutiveLosses);
        return false;
    }
    
    // JAILBREAK EMERGENCY: Warning at 80% of limit
    if(consecutiveLosses >= (int)(m_maxConsecutiveLosses * 0.8))
    {
        if(m_logger != NULL)
        {
            m_logger.LogWarning("CIRCUIT_BREAKER", 
                StringFormat("Consecutive losses warning: %d (80%% of limit)", consecutiveLosses));
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| JAILBREAK EMERGENCY: Check Margin Level                         |
//+------------------------------------------------------------------+
bool CEmergencyCircuitBreaker::CheckMarginLevel(double marginLevel)
{
    if(!m_isInitialized || IsInCooldownPeriod()) return true;
    
    // JAILBREAK EMERGENCY: Skip check if no positions (unlimited margin)
    if(marginLevel == 0.0) return true;
    
    // JAILBREAK EMERGENCY: Check margin level limit
    if(marginLevel < m_minMarginLevel)
    {
        string reason = StringFormat("Margin level too low: %.2f%% (min: %.2f%%)", 
                                   marginLevel, m_minMarginLevel);
        TriggerEmergencyShutdown(TRIGGER_MARGIN_LEVEL, reason, marginLevel);
        return false;
    }
    
    // JAILBREAK EMERGENCY: Warning at 120% of minimum
    if(marginLevel < m_minMarginLevel * 1.2)
    {
        if(m_logger != NULL)
        {
            m_logger.LogWarning("CIRCUIT_BREAKER", 
                StringFormat("Low margin level warning: %.2f%%", marginLevel));
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| JAILBREAK EMERGENCY: Check Daily Trade Limit                    |
//+------------------------------------------------------------------+
bool CEmergencyCircuitBreaker::CheckDailyTradeLimit(int dailyTrades, int maxDailyTrades)
{
    if(!m_isInitialized || IsInCooldownPeriod()) return true;
    
    // JAILBREAK EMERGENCY: Reset daily counters if needed
    ResetDailyCounters();
    
    // JAILBREAK EMERGENCY: Check daily trade limit
    if(dailyTrades >= maxDailyTrades)
    {
        string reason = StringFormat("Daily trade limit exceeded: %d (max: %d)", 
                                   dailyTrades, maxDailyTrades);
        TriggerEmergencyShutdown(TRIGGER_DAILY_TRADES, reason, dailyTrades);
        return false;
    }
    
    // JAILBREAK EMERGENCY: Warning at 80% of limit
    if(dailyTrades >= (int)(maxDailyTrades * 0.8))
    {
        if(m_logger != NULL)
        {
            m_logger.LogWarning("CIRCUIT_BREAKER", 
                StringFormat("Daily trades warning: %d (80%% of limit)", dailyTrades));
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| JAILBREAK EMERGENCY: Check Market Conditions                    |
//+------------------------------------------------------------------+
bool CEmergencyCircuitBreaker::CheckMarketConditions()
{
    if(!m_isInitialized || IsInCooldownPeriod()) return true;
    
    // JAILBREAK EMERGENCY: Check volatility limits
    if(!CheckVolatilityLimits())
    {
        return false;
    }
    
    // JAILBREAK EMERGENCY: Check for news events
    if(IsNewsEventTime())
    {
        string reason = "Trading suspended during news event";
        if(m_logger != NULL)
        {
            m_logger.LogWarning("CIRCUIT_BREAKER", reason);
        }
        // Don't trigger emergency shutdown for news events, just pause trading
        return false;
    }
    
    // JAILBREAK EMERGENCY: Check market hours
    if(!IsTradeAllowed())
    {
        if(m_logger != NULL)
        {
            m_logger.LogInfo("CIRCUIT_BREAKER", "Trading not allowed by broker");
        }
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| JAILBREAK EMERGENCY: Check Volatility Limits                    |
//+------------------------------------------------------------------+
bool CEmergencyCircuitBreaker::CheckVolatilityLimits()
{
    if(!m_isInitialized) return true;
    
    // JAILBREAK EMERGENCY: Calculate current volatility
    double currentVolatility = CalculateVolatility();
    
    // JAILBREAK EMERGENCY: Check volatility threshold
    if(currentVolatility > MARKET_VOLATILITY_THRESHOLD)
    {
        string reason = StringFormat("Market volatility too high: %.2f%% (max: %.2f%%)", 
                                   currentVolatility * 100, MARKET_VOLATILITY_THRESHOLD * 100);
        TriggerEmergencyShutdown(TRIGGER_VOLATILITY, reason, currentVolatility);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| JAILBREAK EMERGENCY: Trigger Emergency Shutdown                 |
//+------------------------------------------------------------------+
void CEmergencyCircuitBreaker::TriggerEmergencyShutdown(ENUM_EMERGENCY_TRIGGER triggerType, 
                                                       const string& reason, double value)
{
    if(!m_isInitialized) return;
    
    // JAILBREAK EMERGENCY: Check daily trigger limit
    if(m_dailyTriggerCount >= MAX_EMERGENCY_TRIGGERS)
    {
        if(m_logger != NULL)
        {
            m_logger.LogCritical("CIRCUIT_BREAKER", "Daily emergency trigger limit reached");
        }
        return;
    }
    
    // JAILBREAK EMERGENCY: Set circuit breaker state
    m_circuitBreakerTriggered = true;
    m_lastTriggerTime = TimeCurrent();
    m_cooldownEndTime = m_lastTriggerTime + CIRCUIT_BREAKER_COOLDOWN;
    m_lastTriggerType = triggerType;
    m_lastTriggerReason = reason;
    m_triggerValue = value;
    m_dailyTriggerCount++;
    
    // JAILBREAK EMERGENCY: Log emergency shutdown
    if(m_logger != NULL)
    {
        m_logger.LogCritical("EMERGENCY_SHUTDOWN", 
            StringFormat("Circuit breaker triggered - Type: %d, Reason: %s, Value: %.6f", 
                        triggerType, reason, value));
    }
    
    // JAILBREAK EMERGENCY: Alert
    Alert("JAILBREAK EMERGENCY: Circuit breaker triggered - ", reason);
}

//+------------------------------------------------------------------+
//| JAILBREAK EMERGENCY: Check Cooldown Period                      |
//+------------------------------------------------------------------+
bool CEmergencyCircuitBreaker::IsInCooldownPeriod()
{
    if(!m_circuitBreakerTriggered) return false;
    
    return TimeCurrent() < m_cooldownEndTime;
}

//+------------------------------------------------------------------+
//| JAILBREAK EMERGENCY: Reset Daily Counters                       |
//+------------------------------------------------------------------+
void CEmergencyCircuitBreaker::ResetDailyCounters()
{
    datetime currentDate = TimeCurrent() - (TimeCurrent() % 86400);  // Start of current day
    
    if(currentDate > m_lastResetDate)
    {
        m_dailyTriggerCount = 0;
        m_lastResetDate = currentDate;
        
        if(m_logger != NULL)
        {
            m_logger.LogInfo("CIRCUIT_BREAKER", "Daily counters reset");
        }
    }
}

//+------------------------------------------------------------------+
//| JAILBREAK EMERGENCY: Calculate Volatility                       |
//+------------------------------------------------------------------+
double CEmergencyCircuitBreaker::CalculateVolatility()
{
    double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    
    if(m_lastPrice == 0.0)
    {
        m_lastPrice = currentPrice;
        return 0.0;
    }
    
    // JAILBREAK EMERGENCY: Simple volatility calculation
    double priceChange = MathAbs(currentPrice - m_lastPrice) / m_lastPrice;
    
    // JAILBREAK EMERGENCY: Update volatility with exponential moving average
    double alpha = 0.1;  // Smoothing factor
    m_priceVolatility = alpha * priceChange + (1 - alpha) * m_priceVolatility;
    
    m_lastPrice = currentPrice;
    m_lastVolatilityCheck = TimeCurrent();
    
    return m_priceVolatility;
}

//+------------------------------------------------------------------+
//| JAILBREAK EMERGENCY: Check News Event Time                      |
//+------------------------------------------------------------------+
bool CEmergencyCircuitBreaker::IsNewsEventTime()
{
    // JAILBREAK EMERGENCY: Simplified news event detection
    // In production, integrate with economic calendar API
    
    datetime currentTime = TimeCurrent();
    MqlDateTime timeStruct;
    TimeToStruct(currentTime, timeStruct);
    
    // JAILBREAK EMERGENCY: Avoid trading during typical news hours (UTC)
    // Major news usually at 8:30, 10:00, 12:30, 14:00, 15:00 UTC
    int currentHour = timeStruct.hour;
    int currentMinute = timeStruct.min;
    
    int newsHours[] = {8, 10, 12, 14, 15};
    
    for(int i = 0; i < ArraySize(newsHours); i++)
    {
        if(currentHour == newsHours[i] && currentMinute >= 25 && currentMinute <= 35)
        {
            return true;  // Within 10 minutes of typical news time
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| JAILBREAK EMERGENCY: Can Reset Circuit Breaker                  |
//+------------------------------------------------------------------+
bool CEmergencyCircuitBreaker::CanResetCircuitBreaker()
{
    if(!m_circuitBreakerTriggered) return false;
    
    return !IsInCooldownPeriod();
}

//+------------------------------------------------------------------+
//| JAILBREAK EMERGENCY: Reset Circuit Breaker                      |
//+------------------------------------------------------------------+
bool CEmergencyCircuitBreaker::ResetCircuitBreaker()
{
    if(!CanResetCircuitBreaker()) return false;
    
    m_circuitBreakerTriggered = false;
    m_lastTriggerType = TRIGGER_NONE;
    m_lastTriggerReason = "";
    m_triggerValue = 0.0;
    
    if(m_logger != NULL)
    {
        m_logger.LogInfo("CIRCUIT_BREAKER", "Circuit breaker reset - Trading can resume");
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| JAILBREAK EMERGENCY: Force Emergency Shutdown                   |
//+------------------------------------------------------------------+
void CEmergencyCircuitBreaker::ForceEmergencyShutdown(const string& reason)
{
    TriggerEmergencyShutdown(TRIGGER_SYSTEM_ERROR, reason, 0.0);
}