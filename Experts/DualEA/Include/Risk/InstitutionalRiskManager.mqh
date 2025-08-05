//+------------------------------------------------------------------+
//| InstitutionalRiskManager.mqh                                     |
//| JAILBREAK LEVEL 5 - INSTITUTIONAL RISK MANAGEMENT               |
//| Advanced Risk Controls and Portfolio Management                 |
//+------------------------------------------------------------------+
#property copyright "EscapeEA - Jailbreak Level 5 Risk Management"
#property version   "1.00"
#property strict

#include "../Signals/AdvancedSignalProcessor.mqh"

//--- JAILBREAK RISK: Risk management constants
#define MAX_PORTFOLIO_RISK 0.02        // 2% max portfolio risk
#define MAX_SINGLE_TRADE_RISK 0.005    // 0.5% max single trade risk
#define MAX_CORRELATION_THRESHOLD 0.7  // 70% max correlation
#define RISK_CALCULATION_PRECISION 5   // Decimal places for risk calculations

//--- JAILBREAK RISK: Risk calculation methods
enum ENUM_RISK_METHOD
{
    RISK_FIXED_AMOUNT = 0,
    RISK_FIXED_PERCENTAGE = 1,
    RISK_VOLATILITY_ADJUSTED = 2,
    RISK_KELLY_CRITERION = 3,
    RISK_VAR_BASED = 4
};

//--- JAILBREAK RISK: Position sizing models
enum ENUM_POSITION_SIZING
{
    SIZING_FIXED = 0,
    SIZING_PERCENTAGE = 1,
    SIZING_ATR_BASED = 2,
    SIZING_VOLATILITY_ADJUSTED = 3,
    SIZING_KELLY_OPTIMAL = 4
};

//+------------------------------------------------------------------+
//| JAILBREAK RISK: Risk Metrics Structure                          |
//+------------------------------------------------------------------+
struct CRiskMetrics
{
    double portfolioRisk;
    double singleTradeRisk;
    double maxDrawdown;
    double currentDrawdown;
    double valueAtRisk;
    double expectedShortfall;
    double sharpeRatio;
    double sortinoRatio;
    double maxLeverage;
    double currentLeverage;
    int openPositions;
    int maxPositions;
    datetime lastUpdate;
    
    CRiskMetrics()
    {
        portfolioRisk = 0.0;
        singleTradeRisk = 0.0;
        maxDrawdown = 0.0;
        currentDrawdown = 0.0;
        valueAtRisk = 0.0;
        expectedShortfall = 0.0;
        sharpeRatio = 0.0;
        sortinoRatio = 0.0;
        maxLeverage = 1.0;
        currentLeverage = 0.0;
        openPositions = 0;
        maxPositions = 3;
        lastUpdate = 0;
    }
};

//+------------------------------------------------------------------+
//| JAILBREAK RISK: Position Risk Structure                         |
//+------------------------------------------------------------------+
struct CPositionRisk
{
    ulong ticket;
    string symbol;
    double volume;
    double entryPrice;
    double currentPrice;
    double stopLoss;
    double takeProfit;
    double unrealizedPnL;
    double riskAmount;
    double riskPercentage;
    double marginRequired;
    datetime openTime;
    bool isValid;
    
    CPositionRisk()
    {
        ticket = 0;
        symbol = "";
        volume = 0.0;
        entryPrice = 0.0;
        currentPrice = 0.0;
        stopLoss = 0.0;
        takeProfit = 0.0;
        unrealizedPnL = 0.0;
        riskAmount = 0.0;
        riskPercentage = 0.0;
        marginRequired = 0.0;
        openTime = 0;
        isValid = false;
    }
};

//+------------------------------------------------------------------+
//| JAILBREAK RISK: Institutional Risk Manager Class                |
//+------------------------------------------------------------------+
class CInstitutionalRiskManager
{
private:
    // JAILBREAK RISK: Configuration
    bool m_isInitialized;
    double m_maxRiskPercentage;
    double m_maxLotSize;
    int m_maxPositions;
    ENUM_RISK_METHOD m_riskMethod;
    ENUM_POSITION_SIZING m_positionSizing;
    
    // JAILBREAK RISK: Account information
    double m_accountBalance;
    double m_accountEquity;
    double m_accountMargin;
    double m_accountFreeMargin;
    double m_initialBalance;
    
    // JAILBREAK RISK: Risk metrics
    CRiskMetrics m_currentMetrics;
    CPositionRisk m_positions[100];  // Max 100 positions tracking
    int m_positionCount;
    
    // JAILBREAK RISK: Historical data for calculations
    double m_dailyReturns[252];  // 1 year of daily returns
    int m_returnIndex;
    int m_totalReturns;
    
    // JAILBREAK RISK: Performance tracking
    double m_totalPnL;
    double m_totalTrades;
    double m_winningTrades;
    double m_losingTrades;
    double m_largestWin;
    double m_largestLoss;
    double m_averageWin;
    double m_averageLoss;
    
    // JAILBREAK RISK: Internal methods
    bool UpdateAccountInfo();
    bool UpdatePositionRisks();
    double CalculatePortfolioRisk();
    double CalculateVaR(double confidence = 0.95);
    double CalculateExpectedShortfall(double confidence = 0.95);
    double CalculateOptimalPositionSize(const CSignalResult& signal);
    double CalculateKellyFraction();
    bool ValidateRiskLimits(double proposedRisk);
    void UpdatePerformanceMetrics();
    
public:
    // JAILBREAK RISK: Constructor/Destructor
    CInstitutionalRiskManager();
    ~CInstitutionalRiskManager();
    
    // JAILBREAK RISK: Initialization
    bool Initialize(double maxRisk, double maxLotSize, int maxPositions);
    void Cleanup();
    
    // JAILBREAK RISK: Core risk management methods
    bool ValidateSignalRisk(const CSignalResult& signal);
    double CalculatePositionSize(const CSignalResult& signal);
    bool ValidateNewPosition(const CSignalResult& signal, double volume);
    bool ShouldClosePosition(ulong ticket);
    
    // JAILBREAK RISK: Risk monitoring methods
    bool UpdateRiskMetrics();
    CRiskMetrics GetCurrentMetrics() const { return m_currentMetrics; }
    bool IsRiskLimitExceeded();
    bool IsDrawdownLimitExceeded();
    
    // JAILBREAK RISK: Position management
    bool AddPosition(ulong ticket);
    bool RemovePosition(ulong ticket);
    bool UpdatePosition(ulong ticket);
    int GetPositionCount() const { return m_positionCount; }
    
    // JAILBREAK RISK: Performance analysis
    double GetSharpeRatio() const { return m_currentMetrics.sharpeRatio; }
    double GetMaxDrawdown() const { return m_currentMetrics.maxDrawdown; }
    double GetCurrentDrawdown() const { return m_currentMetrics.currentDrawdown; }
    double GetWinRate() const;
    double GetProfitFactor() const;
    
    // JAILBREAK RISK: Configuration methods
    void SetRiskMethod(ENUM_RISK_METHOD method) { m_riskMethod = method; }
    void SetPositionSizing(ENUM_POSITION_SIZING sizing) { m_positionSizing = sizing; }
    void SetMaxRisk(double maxRisk) { m_maxRiskPercentage = maxRisk; }
};

//+------------------------------------------------------------------+
//| JAILBREAK RISK: Constructor                                      |
//+------------------------------------------------------------------+
CInstitutionalRiskManager::CInstitutionalRiskManager()
{
    m_isInitialized = false;
    m_maxRiskPercentage = MAX_SINGLE_TRADE_RISK;
    m_maxLotSize = 1.0;
    m_maxPositions = 3;
    m_riskMethod = RISK_VOLATILITY_ADJUSTED;
    m_positionSizing = SIZING_ATR_BASED;
    
    m_accountBalance = 0.0;
    m_accountEquity = 0.0;
    m_accountMargin = 0.0;
    m_accountFreeMargin = 0.0;
    m_initialBalance = 0.0;
    
    m_positionCount = 0;
    m_returnIndex = 0;
    m_totalReturns = 0;
    
    m_totalPnL = 0.0;
    m_totalTrades = 0.0;
    m_winningTrades = 0.0;
    m_losingTrades = 0.0;
    m_largestWin = 0.0;
    m_largestLoss = 0.0;
    m_averageWin = 0.0;
    m_averageLoss = 0.0;
    
    // Initialize arrays
    for(int i = 0; i < 252; i++)
    {
        m_dailyReturns[i] = 0.0;
    }
    
    for(int i = 0; i < 100; i++)
    {
        m_positions[i] = CPositionRisk();
    }
}

//+------------------------------------------------------------------+
//| JAILBREAK RISK: Destructor                                      |
//+------------------------------------------------------------------+
CInstitutionalRiskManager::~CInstitutionalRiskManager()
{
    Cleanup();
}

//+------------------------------------------------------------------+
//| JAILBREAK RISK: Initialize Risk Manager                         |
//+------------------------------------------------------------------+
bool CInstitutionalRiskManager::Initialize(double maxRisk, double maxLotSize, int maxPositions)
{
    m_maxRiskPercentage = MathMin(maxRisk, MAX_SINGLE_TRADE_RISK);
    m_maxLotSize = maxLotSize;
    m_maxPositions = MathMin(maxPositions, 100);
    
    // JAILBREAK RISK: Initialize account information
    if(!UpdateAccountInfo())
    {
        Print("JAILBREAK RISK ERROR: Failed to update account information");
        return false;
    }
    
    m_initialBalance = m_accountBalance;
    
    // JAILBREAK RISK: Initialize risk metrics
    m_currentMetrics = CRiskMetrics();
    m_currentMetrics.maxPositions = m_maxPositions;
    m_currentMetrics.lastUpdate = TimeCurrent();
    
    m_isInitialized = true;
    
    Print("JAILBREAK RISK: Institutional risk manager initialized - MaxRisk: ", m_maxRiskPercentage * 100, 
          "%, MaxLot: ", m_maxLotSize, ", MaxPositions: ", m_maxPositions);
    
    return true;
}

//+------------------------------------------------------------------+
//| JAILBREAK RISK: Cleanup Risk Manager                            |
//+------------------------------------------------------------------+
void CInstitutionalRiskManager::Cleanup()
{
    if(m_isInitialized)
    {
        Print("JAILBREAK RISK: Risk manager cleanup complete");
        m_isInitialized = false;
    }
}

//+------------------------------------------------------------------+
//| JAILBREAK RISK: Validate Signal Risk                            |
//+------------------------------------------------------------------+
bool CInstitutionalRiskManager::ValidateSignalRisk(const CSignalResult& signal)
{
    if(!m_isInitialized || !signal.isValid)
    {
        return false;
    }
    
    // JAILBREAK RISK: Update current risk metrics
    if(!UpdateRiskMetrics())
    {
        Print("JAILBREAK RISK ERROR: Failed to update risk metrics");
        return false;
    }
    
    // JAILBREAK RISK: Check position limits
    if(m_positionCount >= m_maxPositions)
    {
        Print("JAILBREAK RISK: Maximum position limit reached: ", m_positionCount);
        return false;
    }
    
    // JAILBREAK RISK: Calculate proposed position size
    double proposedSize = CalculatePositionSize(signal);
    if(proposedSize <= 0 || proposedSize > m_maxLotSize)
    {
        Print("JAILBREAK RISK: Invalid position size: ", proposedSize);
        return false;
    }
    
    // JAILBREAK RISK: Calculate risk for proposed position
    double riskAmount = MathAbs(signal.entryPrice - signal.stopLoss) * proposedSize * 
                       SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
    double riskPercentage = riskAmount / m_accountBalance;
    
    // JAILBREAK RISK: Validate individual trade risk
    if(riskPercentage > m_maxRiskPercentage)
    {
        Print("JAILBREAK RISK: Trade risk exceeds limit: ", riskPercentage * 100, "% (max: ", 
              m_maxRiskPercentage * 100, "%)");
        return false;
    }
    
    // JAILBREAK RISK: Validate portfolio risk
    double totalPortfolioRisk = m_currentMetrics.portfolioRisk + riskPercentage;
    if(totalPortfolioRisk > MAX_PORTFOLIO_RISK)
    {
        Print("JAILBREAK RISK: Portfolio risk would exceed limit: ", totalPortfolioRisk * 100, 
              "% (max: ", MAX_PORTFOLIO_RISK * 100, "%)");
        return false;
    }
    
    // JAILBREAK RISK: Validate margin requirements
    double marginRequired = proposedSize * SymbolInfoDouble(Symbol(), SYMBOL_MARGIN_INITIAL);
    if(marginRequired > m_accountFreeMargin * 0.8)  // Use max 80% of free margin
    {
        Print("JAILBREAK RISK: Insufficient margin for position: ", marginRequired, 
              " (available: ", m_accountFreeMargin, ")");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| JAILBREAK RISK: Calculate Position Size                         |
//+------------------------------------------------------------------+
double CInstitutionalRiskManager::CalculatePositionSize(const CSignalResult& signal)
{
    if(!m_isInitialized || !signal.isValid)
    {
        return 0.0;
    }
    
    double positionSize = 0.0;
    double riskAmount = m_accountBalance * m_maxRiskPercentage;
    double stopDistance = MathAbs(signal.entryPrice - signal.stopLoss);
    
    if(stopDistance <= 0)
    {
        Print("JAILBREAK RISK ERROR: Invalid stop distance");
        return 0.0;
    }
    
    switch(m_positionSizing)
    {
        case SIZING_FIXED:
            positionSize = 0.01;  // Fixed micro lot
            break;
            
        case SIZING_PERCENTAGE:
            // Risk-based position sizing
            positionSize = riskAmount / (stopDistance * SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE));
            break;
            
        case SIZING_ATR_BASED:
            // ATR-adjusted position sizing
            double atr = iATR(Symbol(), PERIOD_CURRENT, 14);
            if(atr > 0)
            {
                double atrMultiplier = stopDistance / atr;
                positionSize = riskAmount / (stopDistance * SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE));
                positionSize *= (2.0 / MathMax(1.0, atrMultiplier));  // Adjust for volatility
            }
            else
            {
                positionSize = riskAmount / (stopDistance * SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE));
            }
            break;
            
        case SIZING_VOLATILITY_ADJUSTED:
            // Volatility-adjusted sizing
            positionSize = CalculateOptimalPositionSize(signal);
            break;
            
        case SIZING_KELLY_OPTIMAL:
            // Kelly criterion optimal sizing
            double kellyFraction = CalculateKellyFraction();
            positionSize = (m_accountBalance * kellyFraction) / 
                          (signal.entryPrice * SymbolInfoDouble(Symbol(), SYMBOL_TRADE_CONTRACT_SIZE));
            break;
            
        default:
            positionSize = riskAmount / (stopDistance * SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE));
            break;
    }
    
    // JAILBREAK RISK: Apply position size limits
    double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    double maxLot = MathMin(m_maxLotSize, SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX));
    double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
    
    positionSize = MathMax(minLot, MathMin(maxLot, positionSize));
    positionSize = MathFloor(positionSize / lotStep) * lotStep;
    
    return positionSize;
}

//+------------------------------------------------------------------+
//| JAILBREAK RISK: Update Account Information                       |
//+------------------------------------------------------------------+
bool CInstitutionalRiskManager::UpdateAccountInfo()
{
    m_accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    m_accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    m_accountMargin = AccountInfoDouble(ACCOUNT_MARGIN);
    m_accountFreeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    
    if(m_accountBalance <= 0 || m_accountEquity <= 0)
    {
        Print("JAILBREAK RISK ERROR: Invalid account information");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| JAILBREAK RISK: Update Risk Metrics                             |
//+------------------------------------------------------------------+
bool CInstitutionalRiskManager::UpdateRiskMetrics()
{
    if(!UpdateAccountInfo())
    {
        return false;
    }
    
    if(!UpdatePositionRisks())
    {
        return false;
    }
    
    // JAILBREAK RISK: Calculate portfolio risk
    m_currentMetrics.portfolioRisk = CalculatePortfolioRisk();
    
    // JAILBREAK RISK: Calculate drawdown
    if(m_initialBalance > 0)
    {
        m_currentMetrics.currentDrawdown = (m_initialBalance - m_accountBalance) / m_initialBalance;
        m_currentMetrics.maxDrawdown = MathMax(m_currentMetrics.maxDrawdown, m_currentMetrics.currentDrawdown);
    }
    
    // JAILBREAK RISK: Calculate VaR and ES
    m_currentMetrics.valueAtRisk = CalculateVaR(0.95);
    m_currentMetrics.expectedShortfall = CalculateExpectedShortfall(0.95);
    
    // JAILBREAK RISK: Calculate leverage
    if(m_accountEquity > 0)
    {
        m_currentMetrics.currentLeverage = m_accountMargin / m_accountEquity;
    }
    
    m_currentMetrics.openPositions = m_positionCount;
    m_currentMetrics.lastUpdate = TimeCurrent();
    
    // JAILBREAK RISK: Update performance metrics
    UpdatePerformanceMetrics();
    
    return true;
}

//+------------------------------------------------------------------+
//| JAILBREAK RISK: Update Position Risks                           |
//+------------------------------------------------------------------+
bool CInstitutionalRiskManager::UpdatePositionRisks()
{
    m_positionCount = 0;
    
    // JAILBREAK RISK: Iterate through all positions
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionSelectByIndex(i))
        {
            if(m_positionCount >= 100) break;  // Safety limit
            
            CPositionRisk& pos = m_positions[m_positionCount];
            pos.ticket = PositionGetInteger(POSITION_TICKET);
            pos.symbol = PositionGetString(POSITION_SYMBOL);
            pos.volume = PositionGetDouble(POSITION_VOLUME);
            pos.entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            pos.currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            pos.stopLoss = PositionGetDouble(POSITION_SL);
            pos.takeProfit = PositionGetDouble(POSITION_TP);
            pos.unrealizedPnL = PositionGetDouble(POSITION_PROFIT);
            pos.openTime = (datetime)PositionGetInteger(POSITION_TIME);
            
            // JAILBREAK RISK: Calculate position risk
            if(pos.stopLoss > 0)
            {
                pos.riskAmount = MathAbs(pos.entryPrice - pos.stopLoss) * pos.volume * 
                               SymbolInfoDouble(pos.symbol, SYMBOL_TRADE_TICK_VALUE);
                pos.riskPercentage = pos.riskAmount / m_accountBalance;
            }
            
            pos.marginRequired = pos.volume * SymbolInfoDouble(pos.symbol, SYMBOL_MARGIN_INITIAL);
            pos.isValid = true;
            
            m_positionCount++;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| JAILBREAK RISK: Calculate Portfolio Risk                        |
//+------------------------------------------------------------------+
double CInstitutionalRiskManager::CalculatePortfolioRisk()
{
    double totalRisk = 0.0;
    
    for(int i = 0; i < m_positionCount; i++)
    {
        if(m_positions[i].isValid)
        {
            totalRisk += m_positions[i].riskPercentage;
        }
    }
    
    return totalRisk;
}

//+------------------------------------------------------------------+
//| JAILBREAK RISK: Calculate Value at Risk                         |
//+------------------------------------------------------------------+
double CInstitutionalRiskManager::CalculateVaR(double confidence = 0.95)
{
    if(m_totalReturns < 30)  // Need at least 30 observations
    {
        return 0.0;
    }
    
    // JAILBREAK RISK: Sort returns for percentile calculation
    double sortedReturns[252];
    for(int i = 0; i < m_totalReturns; i++)
    {
        sortedReturns[i] = m_dailyReturns[i];
    }
    
    // Simple bubble sort for small arrays
    for(int i = 0; i < m_totalReturns - 1; i++)
    {
        for(int j = 0; j < m_totalReturns - i - 1; j++)
        {
            if(sortedReturns[j] > sortedReturns[j + 1])
            {
                double temp = sortedReturns[j];
                sortedReturns[j] = sortedReturns[j + 1];
                sortedReturns[j + 1] = temp;
            }
        }
    }
    
    // JAILBREAK RISK: Calculate VaR at specified confidence level
    int varIndex = (int)((1.0 - confidence) * m_totalReturns);
    double var = -sortedReturns[varIndex] * m_accountBalance;
    
    return MathMax(0.0, var);
}

//+------------------------------------------------------------------+
//| JAILBREAK RISK: Calculate Expected Shortfall                    |
//+------------------------------------------------------------------+
double CInstitutionalRiskManager::CalculateExpectedShortfall(double confidence = 0.95)
{
    if(m_totalReturns < 30)
    {
        return 0.0;
    }
    
    // JAILBREAK RISK: Calculate average of worst returns beyond VaR
    int varIndex = (int)((1.0 - confidence) * m_totalReturns);
    double sumWorstReturns = 0.0;
    int countWorstReturns = 0;
    
    for(int i = 0; i < m_totalReturns; i++)
    {
        if(m_dailyReturns[i] <= -CalculateVaR(confidence) / m_accountBalance)
        {
            sumWorstReturns += m_dailyReturns[i];
            countWorstReturns++;
        }
    }
    
    if(countWorstReturns > 0)
    {
        return -(sumWorstReturns / countWorstReturns) * m_accountBalance;
    }
    
    return 0.0;
}

//+------------------------------------------------------------------+
//| JAILBREAK RISK: Calculate Optimal Position Size                 |
//+------------------------------------------------------------------+
double CInstitutionalRiskManager::CalculateOptimalPositionSize(const CSignalResult& signal)
{
    // JAILBREAK RISK: Volatility-adjusted position sizing
    double baseSize = m_accountBalance * m_maxRiskPercentage;
    double stopDistance = MathAbs(signal.entryPrice - signal.stopLoss);
    
    if(stopDistance <= 0) return 0.0;
    
    // JAILBREAK RISK: Adjust for signal confidence
    double confidenceMultiplier = MathPow(signal.confidence, 2);  // Square for more conservative sizing
    
    // JAILBREAK RISK: Adjust for market volatility
    double atr = iATR(Symbol(), PERIOD_CURRENT, 14);
    double volatilityMultiplier = 1.0;
    if(atr > 0)
    {
        double normalizedVolatility = stopDistance / atr;
        volatilityMultiplier = 1.0 / MathMax(1.0, normalizedVolatility);
    }
    
    double adjustedSize = baseSize * confidenceMultiplier * volatilityMultiplier;
    double positionSize = adjustedSize / (stopDistance * SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE));
    
    return positionSize;
}

//+------------------------------------------------------------------+
//| JAILBREAK RISK: Calculate Kelly Fraction                        |
//+------------------------------------------------------------------+
double CInstitutionalRiskManager::CalculateKellyFraction()
{
    if(m_totalTrades < 10 || m_losingTrades == 0)
    {
        return 0.01;  // Conservative default
    }
    
    double winRate = m_winningTrades / m_totalTrades;
    double avgWin = m_averageWin;
    double avgLoss = MathAbs(m_averageLoss);
    
    if(avgLoss <= 0) return 0.01;
    
    // JAILBREAK RISK: Kelly formula: f = (bp - q) / b
    // where b = odds received (avgWin/avgLoss), p = win probability, q = loss probability
    double b = avgWin / avgLoss;
    double p = winRate;
    double q = 1.0 - p;
    
    double kellyFraction = (b * p - q) / b;
    
    // JAILBREAK RISK: Apply conservative limits
    kellyFraction = MathMax(0.0, MathMin(0.25, kellyFraction));  // Max 25% Kelly
    
    return kellyFraction;
}

//+------------------------------------------------------------------+
//| JAILBREAK RISK: Update Performance Metrics                      |
//+------------------------------------------------------------------+
void CInstitutionalRiskManager::UpdatePerformanceMetrics()
{
    // JAILBREAK RISK: Calculate Sharpe ratio
    if(m_totalReturns > 1)
    {
        double meanReturn = 0.0;
        double sumSquaredDeviations = 0.0;
        
        for(int i = 0; i < m_totalReturns; i++)
        {
            meanReturn += m_dailyReturns[i];
        }
        meanReturn /= m_totalReturns;
        
        for(int i = 0; i < m_totalReturns; i++)
        {
            double deviation = m_dailyReturns[i] - meanReturn;
            sumSquaredDeviations += deviation * deviation;
        }
        
        double stdDev = MathSqrt(sumSquaredDeviations / (m_totalReturns - 1));
        
        if(stdDev > 0)
        {
            m_currentMetrics.sharpeRatio = (meanReturn * MathSqrt(252)) / (stdDev * MathSqrt(252));
        }
    }
}

//+------------------------------------------------------------------+
//| JAILBREAK RISK: Get Win Rate                                    |
//+------------------------------------------------------------------+
double CInstitutionalRiskManager::GetWinRate() const
{
    if(m_totalTrades > 0)
    {
        return m_winningTrades / m_totalTrades;
    }
    return 0.0;
}

//+------------------------------------------------------------------+
//| JAILBREAK RISK: Get Profit Factor                               |
//+------------------------------------------------------------------+
double CInstitutionalRiskManager::GetProfitFactor() const
{
    if(m_losingTrades > 0 && m_averageLoss != 0)
    {
        double totalWins = m_winningTrades * m_averageWin;
        double totalLosses = m_losingTrades * MathAbs(m_averageLoss);
        
        if(totalLosses > 0)
        {
            return totalWins / totalLosses;
        }
    }
    return 0.0;
}

//+------------------------------------------------------------------+
//| JAILBREAK RISK: Is Risk Limit Exceeded                          |
//+------------------------------------------------------------------+
bool CInstitutionalRiskManager::IsRiskLimitExceeded()
{
    return (m_currentMetrics.portfolioRisk > MAX_PORTFOLIO_RISK ||
            m_currentMetrics.currentDrawdown > 0.1);  // 10% max drawdown
}

//+------------------------------------------------------------------+
//| JAILBREAK RISK: Is Drawdown Limit Exceeded                      |
//+------------------------------------------------------------------+
bool CInstitutionalRiskManager::IsDrawdownLimitExceeded()
{
    return m_currentMetrics.currentDrawdown > 0.05;  // 5% drawdown limit
}