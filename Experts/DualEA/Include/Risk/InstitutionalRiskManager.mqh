//+------------------------------------------------------------------+
//| InstitutionalRiskManager.mqh                                    |
//| JAILBREAK LEVEL 5 - INSTITUTIONAL RISK MANAGEMENT             |
//| Advanced Risk Control and Portfolio Management                 |
//+------------------------------------------------------------------+
#property copyright "EscapeEA - Jailbreak Level 5 Risk Management"
#property version   "1.00"
#property strict

#include "..\Core\JailbreakSecurity.mqh"
#include "..\Utils\JailbreakLogger.mqh"
#include "..\Knowledge\SharedKnowledgeBase.mqh"

//--- JAILBREAK RISK: Risk management constants
#define MAX_POSITION_SIZE 10.0
#define MAX_TOTAL_RISK_PERCENT 2.0
#define MAX_SINGLE_RISK_PERCENT 0.5
#define MIN_STOP_DISTANCE_POINTS 10
#define MAX_CORRELATION 0.75
#define MAX_EXPOSURE_PER_INSTRUMENT 25.0
#define RISK_CHECK_INTERVAL_MS 100

//--- JAILBREAK RISK: Risk check types
enum ENUM_RISK_CHECK
{
    RISK_CHECK_MARGIN = 0,
    RISK_CHECK_EXPOSURE = 1,
    RISK_CHECK_CORRELATION = 2,
    RISK_CHECK_DRAWDOWN = 3,
    RISK_CHECK_VOLATILITY = 4,
    RISK_CHECK_LIQUIDITY = 5
};

//+------------------------------------------------------------------+
//| JAILBREAK RISK: Position Risk Structure                        |
//+------------------------------------------------------------------+
struct SPositionRisk
{
    string symbol;
    double size;
    double entryPrice;
    double stopLoss;
    double takeProfit;
    double currentRisk;
    double maxRisk;
    datetime openTime;
    string signalId;
    bool isValid;
    int validationErrors;
    string stateConflicts;
    datetime lastValidation;
    bool hasEmergencyFlag;
    
    void SPositionRisk()
    {
        symbol = "";
        size = 0.0;
        entryPrice = 0.0;
        stopLoss = 0.0;
        takeProfit = 0.0;
        currentRisk = 0.0;
        maxRisk = 0.0;
        openTime = 0;
        signalId = "";
        isValid = false;
    }
};

//+------------------------------------------------------------------+
//| JAILBREAK RISK: Institutional Risk Manager Class               |
//+------------------------------------------------------------------+
class CInstitutionalRiskManager
{
private:
    // Core components
    CJailbreakSecurity* m_security;
    CJailbreakLogger* m_logger;
    CSharedKnowledgeBase* m_knowledgeBase;
    
    // Risk state
    double m_totalRisk;
    double m_availableMargin;
    double m_maxDrawdown;
    int m_riskCheckFailures;
    bool m_isInitialized;
    datetime m_lastCheck;
    
    // Position management
    SPositionRisk m_positions[];
    int m_positionCount;
    
    // Risk metrics
    double m_correlationMatrix[][10];
    double m_volatilityHistory[];
    double m_exposurePerInstrument[];
    
    // Internal methods
    bool ValidatePosition(const SPositionRisk &position);
    bool CheckMarginRequirements();
    bool CheckCorrelationLimits();
    bool CheckVolatilityLimits();
    double CalculatePositionRisk(const SPositionRisk &position);
    void UpdateRiskMetrics();
    void LogRiskEvent(ENUM_RISK_CHECK checkType, bool passed, string details);

public:
    CInstitutionalRiskManager();
    ~CInstitutionalRiskManager();
    
    // Initialization
    bool Initialize(CJailbreakSecurity* security = NULL, 
                   CJailbreakLogger* logger = NULL,
                   CSharedKnowledgeBase* kb = NULL);
    void Cleanup();
    
    // Risk validation
    bool ValidateNewPosition(const string symbol, double volume, 
                           double entryPrice, double stopLoss,
                           double takeProfit);
    bool ValidateKnowledgeBasedTrade(const string signalId);
    bool ValidateExistingPositions();
    
    // Position management
    bool AddPosition(const SPositionRisk &position);
    bool RemovePosition(const string symbol);
    bool UpdatePosition(const string symbol, double newSize,
                      double newStopLoss, double newTakeProfit);
    
    // Risk monitoring
    void UpdateRiskState();
    bool IsRiskLevelAcceptable() const;
    double GetTotalRisk() const { return m_totalRisk; }
    double GetAvailableMargin() const { return m_availableMargin; }
    double GetMaxDrawdown() const { return m_maxDrawdown; }
    
    // Emergency procedures
    void HandleRiskViolation();
    void ForceCloseRiskiestPositions();
    void EmergencyShutdown();
};

//+------------------------------------------------------------------+
//| Constructor                                                        |
//+------------------------------------------------------------------+
CInstitutionalRiskManager::CInstitutionalRiskManager()
{
    m_security = NULL;
    m_logger = NULL;
    m_knowledgeBase = NULL;
    m_totalRisk = 0.0;
    m_availableMargin = 0.0;
    m_maxDrawdown = 0.0;
    m_riskCheckFailures = 0;
    m_isInitialized = false;
    m_lastCheck = 0;
    m_positionCount = 0;
    ArrayResize(m_positions, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                         |
//+------------------------------------------------------------------+
CInstitutionalRiskManager::~CInstitutionalRiskManager()
{
    Cleanup();
}

//+------------------------------------------------------------------+
//| Initialize risk manager                                            |
//+------------------------------------------------------------------+
bool CInstitutionalRiskManager::Initialize(CJailbreakSecurity* security,
                                         CJailbreakLogger* logger,
                                         CSharedKnowledgeBase* kb)
{
    if(m_isInitialized) return true;
    
    // Store component references
    m_security = security;
    m_logger = logger;
    m_knowledgeBase = kb;
    
    // Validate components
    if(!m_security || !m_logger || !m_knowledgeBase)
    {
        if(m_logger) m_logger.LogError("RISK", "Component initialization failed");
        return false;
    }
    
    // Initialize risk metrics
    ArrayResize(m_volatilityHistory, 100);
    ArrayResize(m_exposurePerInstrument, SymbolsTotal(true));
    ArrayResize(m_correlationMatrix, 10, 10);
    
    // Initialize risk state
    m_totalRisk = 0.0;
    m_availableMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    m_maxDrawdown = 0.0;
    m_riskCheckFailures = 0;
    m_lastCheck = TimeCurrent();
    
    m_isInitialized = true;
    m_logger.LogInfo("RISK", "Risk manager initialized successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Validate a new position                                            |
//+------------------------------------------------------------------+
bool CInstitutionalRiskManager::ValidateNewPosition(const string symbol,
                                                  double volume,
                                                  double entryPrice,
                                                  double stopLoss,
                                                  double takeProfit)
{
    if(!m_isInitialized) return false;
    
    SPositionRisk position;
    position.symbol = symbol;
    position.size = volume;
    position.entryPrice = entryPrice;
    position.stopLoss = stopLoss;
    position.takeProfit = takeProfit;
    position.openTime = TimeCurrent();
    
    // Perform comprehensive risk checks
    if(!ValidatePosition(position)) return false;
    if(!CheckMarginRequirements()) return false;
    if(!CheckCorrelationLimits()) return false;
    if(!CheckVolatilityLimits()) return false;
    
    // Calculate position risk
    position.currentRisk = CalculatePositionRisk(position);
    if(position.currentRisk > MAX_SINGLE_RISK_PERCENT) {
        m_logger.LogWarning("RISK", 
            StringFormat("Position risk %.2f%% exceeds limit %.2f%%", 
                        position.currentRisk, MAX_SINGLE_RISK_PERCENT));
        return false;
    }
    
    // Validate total portfolio risk
    if(m_totalRisk + position.currentRisk > MAX_TOTAL_RISK_PERCENT) {
        m_logger.LogWarning("RISK", "Total portfolio risk limit exceeded");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Update risk state                                                  |
//+------------------------------------------------------------------+
void CInstitutionalRiskManager::UpdateRiskState()
{
    if(!m_isInitialized) return;
    
    datetime currentTime = TimeCurrent();
    if(currentTime - m_lastCheck < RISK_CHECK_INTERVAL_MS / 1000) return;
    
    // Update margin
    m_availableMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    
    // Update drawdown
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double drawdown = (balance - equity) / balance * 100.0;
    m_maxDrawdown = MathMax(m_maxDrawdown, drawdown);
    
    // Update risk metrics
    UpdateRiskMetrics();
    
    // Validate all positions
    if(!ValidateExistingPositions()) {
        m_riskCheckFailures++;
        if(m_riskCheckFailures >= 3) {
            HandleRiskViolation();
        }
    } else {
        m_riskCheckFailures = 0;
    }
    
    m_lastCheck = currentTime;
}
