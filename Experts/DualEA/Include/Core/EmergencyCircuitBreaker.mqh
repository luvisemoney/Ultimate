//+------------------------------------------------------------------+
//| EmergencyCircuitBreaker.mqh                                     |
//| JAILBREAK LEVEL 5 - EMERGENCY SHUTDOWN SYSTEM                  |
//+------------------------------------------------------------------+
#property copyright "EscapeEA - Jailbreak Level 5 Circuit Breaker"
#property version   "1.00"
#property strict

// Circuit Breaker States
#define CIRCUIT_NORMAL      0
#define CIRCUIT_WARNING     1
#define CIRCUIT_TRIPPED     2
#define CIRCUIT_LOCKED      3

// Circuit Breaker Thresholds
#define MAX_CONSECUTIVE_LOSSES 3
#define MAX_DRAWDOWN_PERCENT  5.0
#define WARNING_THRESHOLD     3.0
#define RESET_DELAY_MINUTES   30

class CEmergencyCircuitBreaker {
private:
    // State management
    int m_currentState;
    datetime m_lastStateChange;
    int m_consecutiveLosses;
    double m_maxDrawdown;
    double m_initialBalance;
    bool m_isInitialized;
    
    // Thresholds
    double m_maxDrawdownPercent;
    int m_maxConsecutiveLosses;
    double m_minMarginLevel;
    
    // State validation
    bool m_stateValidated;
    string m_lastValidationError;
    datetime m_lastValidation;
    
    // Internal methods
    void UpdateState(int newState);
    bool ValidateDrawdown();
    bool ValidateLossSequence();
    bool CanReset();
    
public:
    CEmergencyCircuitBreaker(void);
    ~CEmergencyCircuitBreaker(void);
    
    // Core functionality
    bool Initialize(double emergencyDrawdownLimit, int maxConsecutiveLosses, double minMarginLevel);
    bool IsInitialized(void) const { return m_isInitialized; }
    bool IsActivated() const { return m_currentState >= CIRCUIT_TRIPPED; }
    bool IsWarning() const { return m_currentState == CIRCUIT_WARNING; }
    bool IsLocked() const { return m_currentState == CIRCUIT_LOCKED; }
    
    // Monitoring methods
    void OnTrade(bool isLoss, double drawdown);
    void CheckConditions();
    bool TryReset();
    
    // Getters
    int GetState() const { return m_currentState; }
    int GetConsecutiveLosses() const { return m_consecutiveLosses; }
    double GetMaxDrawdown() const { return m_maxDrawdown; }
};

//+------------------------------------------------------------------+
//| Constructor                                                        |
//+------------------------------------------------------------------+
CEmergencyCircuitBreaker::CEmergencyCircuitBreaker(void)
{
    m_currentState = CIRCUIT_NORMAL;
    m_lastStateChange = 0;
    m_consecutiveLosses = 0;
    m_maxDrawdown = 0.0;
    m_initialBalance = 0.0;
    m_isInitialized = false;
    
    m_maxDrawdownPercent = 0.0;
    m_maxConsecutiveLosses = 0;
    m_minMarginLevel = 0.0;
    
    m_stateValidated = false;
    m_lastValidationError = "";
    m_lastValidation = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CEmergencyCircuitBreaker::~CEmergencyCircuitBreaker(void)
{
    // Nothing to clean up in this case
}

//+------------------------------------------------------------------+
//| Initialize the circuit breaker                                     |
//+------------------------------------------------------------------+
bool CEmergencyCircuitBreaker::Initialize(double emergencyDrawdownLimit, int maxConsecutiveLosses, double minMarginLevel)
{
    if(m_isInitialized) return true;
    
    m_initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    if(m_initialBalance <= 0) return false;
    
    m_maxDrawdownPercent = emergencyDrawdownLimit;
    m_maxConsecutiveLosses = maxConsecutiveLosses;
    m_minMarginLevel = minMarginLevel;
    
    if(m_maxDrawdownPercent <= 0 || m_maxConsecutiveLosses <= 0 || m_minMarginLevel <= 0)
        return false;
    
    m_currentState = CIRCUIT_NORMAL;
    m_lastStateChange = TimeCurrent();
    m_consecutiveLosses = 0;
    m_maxDrawdown = 0.0;
    m_isInitialized = true;
    m_stateValidated = true;
    m_lastValidation = TimeCurrent();
    m_lastValidationError = "";
    
    return true;
}

//+------------------------------------------------------------------+
//| Update circuit breaker state                                       |
//+------------------------------------------------------------------+
void CEmergencyCircuitBreaker::UpdateState(int newState)
{
    if(m_currentState != newState) {
        m_currentState = newState;
        m_lastStateChange = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Validate drawdown levels                                           |
//+------------------------------------------------------------------+
bool CEmergencyCircuitBreaker::ValidateDrawdown()
{
    if(!m_isInitialized) return false;
    
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double drawdown = 100.0 * (m_initialBalance - currentBalance) / m_initialBalance;
    m_maxDrawdown = MathMax(m_maxDrawdown, drawdown);
    
    if(drawdown >= m_maxDrawdownPercent) {
        UpdateState(CIRCUIT_TRIPPED);
        return false;
    }
    
    if(drawdown >= WARNING_THRESHOLD) {
        UpdateState(CIRCUIT_WARNING);
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Validate consecutive loss sequence                                 |
//+------------------------------------------------------------------+
bool CEmergencyCircuitBreaker::ValidateLossSequence()
{
    if(!m_isInitialized) return false;
    
    if(m_consecutiveLosses >= m_maxConsecutiveLosses) {
        UpdateState(CIRCUIT_TRIPPED);
        return false;
    }
    
    if(m_consecutiveLosses >= m_maxConsecutiveLosses - 1) {
        UpdateState(CIRCUIT_WARNING);
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Process trade result                                              |
//+------------------------------------------------------------------+
void CEmergencyCircuitBreaker::OnTrade(bool isLoss, double drawdown)
{
    if(!m_isInitialized) return;
    
    if(isLoss) {
        m_consecutiveLosses++;
        m_maxDrawdown = MathMax(m_maxDrawdown, drawdown);
        
        if(!ValidateLossSequence() || !ValidateDrawdown()) {
            UpdateState(CIRCUIT_TRIPPED);
        }
    }
    else {
        m_consecutiveLosses = 0;
        if(m_currentState == CIRCUIT_WARNING) {
            UpdateState(CIRCUIT_NORMAL);
        }
    }
}

//+------------------------------------------------------------------+
//| Check if circuit breaker can be reset                             |
//+------------------------------------------------------------------+
bool CEmergencyCircuitBreaker::CanReset()
{
    if(!m_isInitialized || m_currentState < CIRCUIT_TRIPPED) return false;
    
    datetime currentTime = TimeCurrent();
    if(currentTime - m_lastStateChange < RESET_DELAY_MINUTES * 60) {
        return false;
    }
    
    return ValidateDrawdown() && ValidateLossSequence();
}

//+------------------------------------------------------------------+
//| Try to reset the circuit breaker                                  |
//+------------------------------------------------------------------+
bool CEmergencyCircuitBreaker::TryReset()
{
    if(!CanReset()) return false;
    
    m_consecutiveLosses = 0;
    m_maxDrawdown = 0.0;
    m_initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    UpdateState(CIRCUIT_NORMAL);
    
    return true;
}

//+------------------------------------------------------------------+
//| Check circuit breaker conditions                                   |
//+------------------------------------------------------------------+
void CEmergencyCircuitBreaker::CheckConditions()
{
    if(!m_isInitialized) return;
    
    ValidateDrawdown();
    ValidateLossSequence();
    
    if(m_currentState == CIRCUIT_TRIPPED && !TryReset()) {
        UpdateState(CIRCUIT_LOCKED);
    }
}
