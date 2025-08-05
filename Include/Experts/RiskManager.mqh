//+------------------------------------------------------------------+
//|                                              RiskManager.mqh      |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Indicators\Trend.mqh>
#include <Indicators\Oscilators.mqh>

// Risk calculation modes
enum ENUM_RISK_CALC_MODE
{
   RISK_FIXED_PERCENT,     // Fixed percentage of balance
   RISK_VOLATILITY_BASED,  // Based on market volatility (ATR)
   RISK_FIXED_FRACTIONAL,  // Fixed fractional position sizing
   RISK_KELLY_CRITERION    // Kelly Criterion for position sizing
};

// Enhanced risk state with more granular control
enum ENUM_RISK_STATE
{
   RISK_STATE_OPTIMAL,     // Optimal conditions (increased position size)
   RISK_STATE_NORMAL,      // Normal trading conditions
   RISK_STATE_CAUTION,     // Increased risk (reduced position size)
   RISK_STATE_ALERT,       // High risk (no new positions)
   RISK_STATE_STOP,        // Stop trading (emergency)
   RISK_STATE_RECOVERY     // Recovery mode after stop
};

// Market regime detection
enum ENUM_MARKET_REGIME
{
   REGIME_TRENDING_UP,     // Strong uptrend
   REGIME_TRENDING_DOWN,   // Strong downtrend
   REGIME_RANGING,         // Sideways market
   REGIME_VOLATILE,        // High volatility
   REGIME_LOW_VOLATILITY   // Low volatility
};

//+------------------------------------------------------------------+
//| Risk Manager Class                                               |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
   // Basic risk parameters
   double            m_riskPerTrade;         // Risk per trade as percentage of balance
   double            m_maxLeverage;          // Maximum allowed leverage
   int               m_maxOpenTrades;        // Maximum number of open trades
   double            m_dailyLossLimit;       // Daily loss limit as percentage of balance
   double            m_maxPositionSize;      // Maximum position size in lots
   double            m_maxPortfolioRisk;     // Maximum portfolio risk as percentage
   double            m_maxDrawdown;          // Maximum allowed drawdown percentage
   
   // Advanced risk parameters
   ENUM_RISK_CALC_MODE m_riskMode;           // Risk calculation mode
   ENUM_RISK_STATE     m_riskState;          // Current risk state
   double              m_volatilityFactor;   // Volatility adjustment factor
   double              m_correlationFactor;  // Correlation adjustment factor
   
   // Enhanced risk metrics
   double            m_riskOfRuin;           // Current risk of ruin
   double            m_sharpeRatio;          // Current Sharpe ratio
   double            m_sortinoRatio;         // Sortino ratio (downside risk)
   double            m_valueAtRisk;          // Value at Risk (VaR)
   double            m_expectedShortfall;    // Expected Shortfall (ES)
   double            m_maxAdverseExcursion;  // Maximum adverse excursion
   double            m_winLossRatio;         // Current win/loss ratio
   double            m_profitFactor;         // Profit factor
   double            m_recoveryFactor;       // Recovery factor
   int               m_consecutiveLosses;    // Number of consecutive losses
   int               m_consecutiveWins;      // Number of consecutive wins
   double            m_maxDrawdown;          // Maximum drawdown (peak to trough)
   double            m_avgWin;               // Average win amount
   double            m_avgLoss;              // Average loss amount
   int               m_totalTrades;          // Total number of trades
   double            m_winRate;              // Win rate percentage
   
   // Market regime detection
   ENUM_MARKET_REGIME m_marketRegime;        // Current market regime
   double            m_volatilityIndex;      // Volatility index (0-100)
   double            m_trendStrength;        // Trend strength (0-100)
   double            m_correlationIndex;     // Correlation index (-100 to 100)
   
   // Time-based controls
   datetime          m_lastTradeTime;        // Time of last trade
   int               m_minMinutesBetweenTrades; // Minimum minutes between trades
   
   // Objects
   CSymbolInfo      *m_symbol;               // Pointer to symbol info
   CAccountInfo     *m_account;              // Pointer to account info
   CiATR           *m_atr;                  // ATR indicator for volatility
   
   // Internal methods
   double           NormalizeLots(double lots);
   double           CalculateVolatilityFactor(int period = 14);
   double           CalculateCorrelationFactor();
   void             UpdateRiskMetrics();
   void             UpdateRiskState();
   bool             CheckTimeRestrictions();
   bool             CheckNewsRisk();
   double           CalculateKellyFraction(double winRate, double winLossRatio);
   
   // Enhanced risk calculations
   double           CalculateValueAtRisk(int period = 20, double confidence = 0.95);
   double           CalculateExpectedShortfall(int period = 20, double confidence = 0.95);
   void             UpdateMarketRegime();
   double           CalculateVolatilityIndex(int period = 14);
   double           CalculateTrendStrength(int period = 20);
   double           CalculateCorrelationIndex(string symbol1, string symbol2, ENUM_TIMEFRAMES timeframe, int period);
   void             UpdateWinLossMetrics();
   void             UpdateDrawdownMetrics();
   void             SaveStateToFile();
   bool             LoadStateFromFile();
   
public:
                     CRiskManager();
                    ~CRiskManager();
                    
   // Initialization
   bool              Initialize(CSymbolInfo *symbol, CAccountInfo *account, 
                              double riskPerTrade = 1.0, double maxLeverage = 30.0,
                              int maxOpenTrades = 5, double dailyLossLimit = 5.0,
                              double maxPortfolioRisk = 30.0, double maxDrawdown = 20.0);
   
   // Enhanced position sizing
   double            CalculatePositionSize(double stopLossPoints, ENUM_ORDER_TYPE orderType = ORDER_TYPE_BUY);
   double            CalculateCorrelationAdjustedSize(double baseLots, string symbol1, string symbol2, ENUM_TIMEFRAMES timeframe, int period);
   double            CalculateRegimeAdjustedSize(double baseLots, ENUM_MARKET_REGIME regime);
   double            CalculateMLAdjustedSize(double baseLots, double mlConfidence);
   
   // Enhanced risk validation
   bool              CheckRisk(double lots, double stopLoss, double takeProfit, ENUM_ORDER_TYPE orderType = ORDER_TYPE_BUY);
   bool              CheckPortfolioRisk();
   bool              CheckLeverageRisk();
   bool              CheckConcentrationRisk();
   bool              CheckLiquidityRisk();
   bool              CheckEventRisk();
   
   // Enhanced risk management
   void              Update();  // Call this on each tick or bar close
   void              ResetDailyMetrics();
   void              UpdateMarketRegime();
   void              UpdateRiskMetrics();
   void              UpdateRiskState();
   bool              CheckDrawdownLimits();
   bool              CheckVolatilityLimits();
   bool              CheckCorrelationLimits();
   void              SaveState();
   bool              LoadState();
   void              TriggerRecovery();
   
   // Getters
   double            GetRiskPerTrade() const { return m_riskPerTrade; }
   double            GetMaxLeverage() const { return m_maxLeverage; }
   int               GetMaxOpenTrades() const { return m_maxOpenTrades; }
   double            GetDailyLossLimit() const { return m_dailyLossLimit; }
   double            GetMaxPortfolioRisk() const { return m_maxPortfolioRisk; }
   double            GetMaxDrawdown() const { return m_maxDrawdown; }
   double            GetRiskOfRuin() const { return m_riskOfRuin; }
   double            GetSharpeRatio() const { return m_sharpeRatio; }
   ENUM_RISK_STATE   GetRiskState() const { return m_riskState; }
   
   // Setters
   void              SetRiskPerTrade(double risk) { m_riskPerTrade = MathMax(0.1, MathMin(risk, 10.0)); }
   void              SetMaxLeverage(double leverage) { m_maxLeverage = MathMax(1.0, MathMin(leverage, 100.0)); }
   void              SetMaxOpenTrades(int maxTrades) { m_maxOpenTrades = MathMax(1, maxTrades); }
   void              SetDailyLossLimit(double limit) { m_dailyLossLimit = MathMax(0.1, MathMin(limit, 50.0)); }
   void              SetMaxPortfolioRisk(double risk) { m_maxPortfolioRisk = MathMax(5.0, MathMin(risk, 100.0)); }
   void              SetMaxDrawdown(double drawdown) { m_maxDrawdown = MathMax(1.0, MathMin(drawdown, 50.0)); }
   void              SetRiskMode(ENUM_RISK_CALC_MODE mode) { m_riskMode = mode; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager() : m_riskPerTrade(1.0),
                              m_maxLeverage(30.0),
                              m_maxOpenTrades(5),
                              m_dailyLossLimit(5.0),
                              m_maxPositionSize(100.0),
                              m_maxPortfolioRisk(30.0),
                              m_maxDrawdown(20.0),
                              m_riskMode(RISK_FIXED_PERCENT),
                              m_riskState(RISK_STATE_NORMAL),
                              m_volatilityFactor(1.0),
                              m_correlationFactor(1.0),
                              m_riskOfRuin(0.0),
                              m_sharpeRatio(0.0),
                              m_maxAdverseExcursion(0.0),
                              m_winLossRatio(0.0),
                              m_consecutiveLosses(0),
                              m_lastTradeTime(0),
                              m_minMinutesBetweenTrades(1),
                              m_symbol(NULL),
                              m_account(NULL),
                              m_atr(NULL)
{
   // Create ATR indicator
   m_atr = new CiATR();
   
   // Set default ATR period (can be changed later)
   if(m_atr != NULL)
   {
      m_atr.Create(m_symbol.Name(), PERIOD_CURRENT, 14);
   }
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CRiskManager::~CRiskManager()
{
   // Clean up ATR indicator
   if(m_atr != NULL)
   {
      delete m_atr;
      m_atr = NULL;
   }
   
   // Reset pointers
   m_symbol = NULL;
   m_account = NULL;
}

//+------------------------------------------------------------------+
//| Initialize risk manager with enhanced parameters                 |
//+------------------------------------------------------------------+
bool CRiskManager::Initialize(CSymbolInfo *symbol, CAccountInfo *account, 
                            double riskPerTrade, double maxLeverage,
                            int maxOpenTrades, double dailyLossLimit,
                            double maxPortfolioRisk, double maxDrawdown)
{
   // Validate inputs
   if(symbol == NULL || account == NULL)
   {
      Print("Error: Invalid symbol or account pointer in RiskManager initialization");
      return false;
   }
   
   // Store pointers
   m_symbol = symbol;
   m_account = account;
   
   // Set basic risk parameters with validation
   SetRiskPerTrade(riskPerTrade);
   SetMaxLeverage(maxLeverage);
   SetMaxOpenTrades(maxOpenTrades);
   SetDailyLossLimit(dailyLossLimit);
   SetMaxPortfolioRisk(maxPortfolioRisk);
   SetMaxDrawdown(maxDrawdown);
   
   // Get maximum position size from symbol
   m_maxPositionSize = SymbolInfoDouble(m_symbol.Name(), SYMBOL_VOLUME_MAX);
   
   // Initialize ATR indicator if not already done
   if(m_atr == NULL)
   {
      m_atr = new CiATR();
      if(m_atr != NULL)
      {
         if(!m_atr.Create(m_symbol.Name(), PERIOD_CURRENT, 14))
         {
            Print("Warning: Failed to create ATR indicator");
            delete m_atr;
            m_atr = NULL;
         }
      }
   }
   
   // Initialize risk metrics
   UpdateRiskMetrics();
   UpdateRiskState();
   
   Print("RiskManager initialized successfully");
   PrintFormat("Risk per trade: %.2f%%, Max leverage: 1:%.0f, Max open trades: %d", 
              m_riskPerTrade, m_maxLeverage, m_maxOpenTrades);
   PrintFormat("Daily loss limit: %.2f%%, Max portfolio risk: %.2f%%, Max drawdown: %.2f%%",
              m_dailyLossLimit, m_maxPortfolioRisk, m_maxDrawdown);
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk and current market conditions |
//+------------------------------------------------------------------+
double CRiskManager::CalculatePositionSize(double stopLossPoints, ENUM_ORDER_TYPE orderType)
{
   if(stopLossPoints <= 0 || m_symbol == NULL || m_account == NULL)
      return 0.0;
      
   // Update risk metrics before calculating position size
   UpdateRiskMetrics();
   UpdateRiskState();
   
   // Check if we're in a high-risk state that prevents new positions
   if(m_riskState == RISK_STATE_STOP)
   {
      Print("Position size calculation: Trading stopped due to risk state");
      return 0.0;
   }
   
   // Get account balance and symbol information
   double balance = m_account.Balance();
   double equity = m_account.Equity();
   double freeMargin = m_account.FreeMargin();
   double tickValue = m_symbol.TickValue();
   double tickSize = m_symbol.TickSize();
   double point = m_symbol.Point();
   
   if(balance <= 0 || tickValue <= 0 || tickSize <= 0 || point <= 0)
   {
      Print("Position size calculation: Invalid account or symbol data");
      return 0.0;
   }
   
   // Calculate base risk amount based on risk per trade
   double riskAmount = balance * (m_riskPerTrade / 100.0);
   
   // Adjust risk based on current risk state
   switch(m_riskState)
   {
      case RISK_STATE_CAUTION:
         riskAmount *= 0.5; // Reduce position size by 50%
         break;
      case RISK_STATE_ALERT:
         riskAmount *= 0.25; // Reduce position size by 75%
         break;
      default:
         break; // Normal risk, use full amount
   }
   
   // Get symbol lot information
   double lotStep = SymbolInfoDouble(m_symbol.Name(), SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(m_symbol.Name(), SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(m_symbol.Name(), SYMBOL_VOLUME_MAX);
   
   if(lotStep <= 0 || minLot <= 0 || maxLot <= 0)
   {
      Print("Position size calculation: Invalid lot size parameters");
      return 0.0;
   }
   
   // Calculate position size based on the selected risk calculation mode
   double lots = 0.0;
   
   switch(m_riskMode)
   {
      case RISK_VOLATILITY_BASED:
         // Use ATR-based position sizing
         if(m_atr != NULL && m_atr.Main(0) > 0)
         {
            double atrValue = m_atr.Main(0);
            double atrMultiplier = 2.0; // Standard multiplier for ATR-based sizing
            double atrStop = atrValue * atrMultiplier;
            
            // Calculate position size based on ATR stop
            double riskPerUnit = atrStop * tickValue / point;
            if(riskPerUnit > 0)
            {
               lots = riskAmount / riskPerUnit;
            }
         }
         break;
         
      case RISK_FIXED_FRACTIONAL:
         // Fixed fractional position sizing
         lots = (balance * (m_riskPerTrade / 100.0)) / stopLossPoints;
         break;
         
      case RISK_KELLY_CRITERION:
         // Kelly Criterion position sizing
         if(m_winLossRatio > 0)
         {
            double kellyFraction = CalculateKellyFraction(0.5, m_winLossRatio);
            lots = (balance * kellyFraction) / stopLossPoints;
         }
         break;
         
      case RISK_FIXED_PERCENT:
      default:
         // Standard fixed percentage risk model
         double moneyPerLot = (stopLossPoints * point / tickSize) * tickValue;
         if(moneyPerLot > 0)
         {
            lots = riskAmount / moneyPerLot;
         }
         break;
   }
   
   // Apply volatility adjustment if ATR is available
   if(m_atr != NULL && m_volatilityFactor > 0)
   {
      lots *= m_volatilityFactor;
   }
   
   // Apply correlation adjustment
   lots *= m_correlationFactor;
   
   // Normalize lots to allowed values
   lots = MathFloor(lots / lotStep) * lotStep;
   lots = MathMax(minLot, MathMin(lots, MathMin(maxLot, m_maxPositionSize)));
   
   // Check margin requirements
   double marginRequired = 0.0;
   double price = (orderType == ORDER_TYPE_BUY) ? m_symbol.Ask() : m_symbol.Bid();
   
   // Calculate margin required for this position
   marginRequired = lots * price / m_account.Leverage();
   
   // If we don't have enough margin, reduce position size
   if(marginRequired > freeMargin * 0.9) // Leave 10% margin buffer
   {
      double maxLotsByMargin = (freeMargin * 0.9 * m_account.Leverage()) / price;
      lots = MathMin(lots, maxLotsByMargin);
      
      // Re-normalize after margin adjustment
      lots = MathFloor(lots / lotStep) * lotStep;
      lots = MathMax(minLot, MathMin(lots, Math.min(maxLot, m_maxPositionSize)));
      
      PrintFormat("Position size reduced to %.2f lots due to margin requirements", lots);
   }
   
   // Final validation
   if(lots < minLot || lots > m_maxPositionSize)
   {
      PrintFormat("Invalid position size calculated: %.2f (min: %.2f, max: %.2f)",
                lots, minLot, m_maxPositionSize);
      return 0.0;
   }
   
   PrintFormat("Calculated position size: %.2f lots (Risk: %.2f%%, Stop: %.1f pips)",
             lots, m_riskPerTrade, stopLossPoints / 10.0);
             
   return lots;
}

//+------------------------------------------------------------------+
//| Check if trade meets all risk parameters and is allowed          |
//+------------------------------------------------------------------+
bool CRiskManager::CheckRisk(double lots, double stopLoss, double takeProfit, ENUM_ORDER_TYPE orderType)
{
   if(m_symbol == NULL || m_account == NULL)
   {
      Print("Risk check failed: Symbol or account not initialized");
      return false;
   }
   
   // Update risk metrics before checking
   UpdateRiskMetrics();
   UpdateRiskState();
   
   // Check if we're in a stop state
   if(m_riskState == RISK_STATE_STOP)
   {
      Print("Risk check failed: Trading stopped due to risk state");
      return false;
   }
   
   // Check time restrictions (e.g., news events, market close, etc.)
   if(!CheckTimeRestrictions())
   {
      Print("Risk check failed: Time restrictions in effect");
      return false;
   }
   
   // Check for news events that might increase risk
   if(!CheckNewsRisk())
   {
      Print("Risk check failed: High-impact news event detected");
      return false;
   }
   
   // Check if we've reached max open trades for this symbol
   CPositionInfo position;
   int totalPositions = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == m_symbol.Name() && 
            (m_magicNumber == 0 || position.Magic() == m_magicNumber))
         {
            totalPositions++;
         }
      }
   }
   
   if(totalPositions >= m_maxOpenTrades)
   {
      Print("Risk check failed: Maximum open trades (", m_maxOpenTrades, ") reached");
      return false;
   }
   
   // Check daily loss limit
   double dailyProfit = m_account.Profit() - m_account.Balance() + m_account.Equity();
   double dailyLimit = m_account.Balance() * (m_dailyLossLimit / 100.0);
   
   if(dailyProfit <= -dailyLimit)
   {
      Print("Risk check failed: Daily loss limit (", m_dailyLossLimit, "%) reached");
      return false;
   }
   
   // Check maximum portfolio risk
   double portfolioRisk = (1.0 - (m_account.Equity() / m_account.Balance())) * 100.0;
   if(portfolioRisk >= m_maxPortfolioRisk)
   {
      Print("Risk check failed: Portfolio risk (", DoubleToString(portfolioRisk, 2), 
            "%) exceeds maximum (", m_maxPortfolioRisk, "%)");
      return false;
   }
   
   // Check maximum drawdown
   double drawdown = (1.0 - (m_account.Equity() / m_account.Balance())) * 100.0;
   if(drawdown >= m_maxDrawdown)
   {
      Print("Risk check failed: Maximum drawdown (", m_maxDrawdown, "%) reached");
      return false;
   }
   
   // Calculate position value and check margin
   double price = (orderType == ORDER_TYPE_BUY) ? m_symbol.Ask() : m_symbol.Bid();
   double marginRequired = lots * price / m_account.Leverage();
   
   // Add a 10% buffer to margin requirement for price fluctuations
   if(marginRequired > m_account.FreeMargin() * 0.9)
   {
      Print("Risk check failed: Not enough margin. Required: ", marginRequired, 
            ", Free: ", m_account.FreeMargin());
      return false;
   }
   
   // Check if stop loss and take profit are valid
   if(stopLoss > 0 && takeProfit > 0)
   {
      double slDistance = MathAbs(price - stopLoss) / m_symbol.Point();
      double tpDistance = MathAbs(takeProfit - price) / m_symbol.Point();
      
      // Get minimum distance from broker and add a small buffer
      double minDistance = (double)SymbolInfoInteger(m_symbol.Name(), SYMBOL_TRADE_STOPS_LEVEL) * 1.5;
      
      if(slDistance < minDistance || tpDistance < minDistance)
      {
         Print("Risk check failed: Stop loss or take profit too close to current price");
         return false;
      }
      
      // Check risk/reward ratio (minimum 1:1.5)
      double riskRewardRatio = tpDistance / slDistance;
      if(riskRewardRatio < 1.5)
      {
         Print("Risk check failed: Risk/reward ratio (", DoubleToString(riskRewardRatio, 2), 
               ":1) is below minimum (1.5:1)");
         return false;
      }
   }
   
   // Check if we have too many consecutive losses
   if(m_consecutiveLosses >= 3)
   {
      Print("Risk check failed: ", m_consecutiveLosses, " consecutive losses. Reducing risk.");
      return false;
   }
   
   // Check minimum time between trades
   if(TimeCurrent() - m_lastTradeTime < m_minMinutesBetweenTrades * 60)
   {
      Print("Risk check failed: Minimum time between trades not met");
      return false;
   }
   
   // All checks passed
   Print("Risk check passed: Trade allowed");
   return true;
}

//+------------------------------------------------------------------+
//| Update all risk metrics based on current market conditions       |
//+------------------------------------------------------------------+
void CRiskManager::UpdateRiskMetrics()
{
   if(m_symbol == NULL || m_account == NULL)
      return;
      
   // Update market regime first as it affects other metrics
   UpdateMarketRegime();
   
   // Update volatility metrics
   if(m_atr != NULL)
   {
      m_atr.Refresh(OBJ_ALL_PERIODS);
      m_volatilityFactor = CalculateVolatilityFactor();
      m_volatilityIndex = CalculateVolatilityIndex();
   }
   
   // Update correlation metrics
   m_correlationFactor = CalculateCorrelationFactor();
   m_correlationIndex = CalculateCorrelationIndex(_Symbol, "USDX", PERIOD_H1, 50);
   
   // Update trend metrics
   m_trendStrength = CalculateTrendStrength();
   
   // Update trade performance metrics
   UpdateWinLossMetrics();
   UpdateDrawdownMetrics();
   
   // Calculate advanced risk metrics
   m_valueAtRisk = CalculateValueAtRisk();
   m_expectedShortfall = CalculateExpectedShortfall();
   m_riskOfRuin = CalculateRiskOfRuin();
   m_sharpeRatio = CalculateSharpeRatio();
   m_sortinoRatio = CalculateSortinoRatio();
   m_profitFactor = CalculateProfitFactor();
   m_recoveryFactor = CalculateRecoveryFactor();
   m_maxAdverseExcursion = CalculateMaxAdverseExcursion();
   
   // Update risk state based on all metrics
   UpdateRiskState();
   
   // Save state periodically
   static datetime lastSave = 0;
   if(TimeCurrent() - lastSave > 3600) // Save hourly
   {
      SaveState();
      lastSave = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Update risk state based on comprehensive market analysis         |
//+------------------------------------------------------------------+
void CRiskManager::UpdateRiskState()
{
   // Check for emergency stop conditions first
   if(CheckDrawdownLimits() || CheckVolatilityLimits() || CheckCorrelationLimits())
   {
      if(m_riskState != RISK_STATE_STOP)
      {
         m_riskState = RISK_STATE_STOP;
         Print("Emergency stop: Risk limits breached!");
         // Save state before stopping
         SaveState();
      }
      return;
   }
   
   // If in recovery state, check if we can exit recovery
   if(m_riskState == RISK_STATE_RECOVERY)
   {
      if(m_account.Profit() > 0 && m_consecutiveWins >= 2)
      {
         m_riskState = RISK_STATE_CAUTION;
         Print("Exiting recovery mode, moving to CAUTION state");
      }
      return;
   }
   
   // If in stop state, check if we can start recovery
   if(m_riskState == RISK_STATE_STOP)
   {
      if(m_account.Profit() > 0 && m_consecutiveWins >= 1)
      {
         m_riskState = RISK_STATE_RECOVERY;
         Print("Starting recovery process");
      }
      return;
   }
   
   // Calculate risk score (0-100, higher is riskier)
   double riskScore = 0;
   
   // Account metrics
   riskScore += NormalizeDouble(m_maxDrawdown, 2) * 0.5;
   riskScore += (1.0 - (m_account.Equity() / m_account.Balance())) * 100 * 0.3;
   
   // Trade metrics
   riskScore += (m_consecutiveLosses * 5);
   riskScore += (m_winRate < 50) ? (50 - m_winRate) * 0.5 : 0;
   
   // Market metrics
   riskScore += (m_volatilityIndex > 70) ? 15 : (m_volatilityIndex > 50) ? 5 : 0;
   riskScore += (m_trendStrength < 30) ? 10 : 0; // Low trend strength = more risk
   
   // Update state based on risk score
   if(riskScore >= 80 || m_consecutiveLosses >= 3)
   {
      m_riskState = RISK_STATE_ALERT;
   }
   else if(riskScore >= 60 || m_consecutiveLosses >= 1)
   {
      m_riskState = RISK_STATE_CAUTION;
   }
   else if(riskScore <= 20 && m_consecutiveWins >= 3)
   {
      m_riskState = RISK_STATE_OPTIMAL;
   }
   else
   {
      m_riskState = RISK_STATE_NORMAL;
   }
   
   // Log state changes
   static ENUM_RISK_STATE lastState = (ENUM_RISK_STATE)-1;
   if(m_riskState != lastState)
   {
      PrintFormat("Risk state changed from %d to %d (Score: %.1f)", lastState, m_riskState, riskScore);
      lastState = m_riskState;
   }
}

//+------------------------------------------------------------------+
//| Check if trading is allowed based on comprehensive risk analysis |
//+------------------------------------------------------------------+
bool CRiskManager::IsTradingAllowed()
{
   // Update all metrics before checking
   UpdateRiskMetrics();
   
   // Check risk state first (fastest check)
   switch(m_riskState)
   {
      case RISK_STATE_STOP:
         Print("Trading stopped: Emergency stop condition active");
         return false;
         
      case RISK_STATE_ALERT:
         Print("Trading paused: High risk condition detected");
         return false;
         
      case RISK_STATE_RECOVERY:
         // Only allow reduced size trades in recovery
         if(AccountInfoDouble(ACCOUNT_EQUITY) < AccountInfoDouble(ACCOUNT_BALANCE) * 0.95)
         {
            Print("Trading in recovery mode: Only reduced size trades allowed");
            return true;
         }
         break;
         
      case RISK_STATE_OPTIMAL:
         // Full trading allowed
         break;
         
      case RISK_STATE_CAUTION:
      case RISK_STATE_NORMAL:
      default:
         // Continue with other checks
         break;
   }
   
   // Check portfolio-level risk
   if(!CheckPortfolioRisk())
   {
      Print("Trading not allowed: Portfolio risk limit reached");
      return false;
   }
   
   // Check leverage risk
   if(!CheckLeverageRisk())
   {
      Print("Trading not allowed: Leverage risk too high");
      return false;
   }
   
   // Check concentration risk
   if(!CheckConcentrationRisk())
   {
      Print("Trading not allowed: Position concentration too high");
      return false;
   }
   
   // Check liquidity risk
   if(!CheckLiquidityRisk())
   {
      Print("Trading not allowed: Insufficient liquidity");
      return false;
   }
   
   // Check event risk (news, etc.)
   if(!CheckEventRisk())
   {
      Print("Trading not allowed: High event risk detected");
      return false;
   }
   
   // Check time restrictions
   if(!CheckTimeRestrictions())
   {
      Print("Trading not allowed: Time restriction active");
      return false;
   }
   
   // All checks passed
   return true;
}

//+------------------------------------------------------------------+
//| Check if trading is allowed based on time restrictions           |
//+------------------------------------------------------------------+
bool CRiskManager::CheckTimeRestrictions()
{
   // Check if we're in a time-restricted period (e.g., news events, market close)
   // This is a placeholder - implement actual time restrictions based on your strategy
   
   // Example: Don't trade during the first and last hour of the trading day
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // Skip weekend trading
   if(dt.day_of_week == 0 || dt.day_of_week == 6) // Sunday or Saturday
      return false;
      
   // Skip first and last hour of the trading day
   int hour = dt.hour;
   if((hour >= 0 && hour < 1) || (hour >= 23 && hour <= 23))
      return false;
      
   return true;
}

//+------------------------------------------------------------------+
//| Check for high-impact news events                                |
//+------------------------------------------------------------------+
bool CRiskManager::CheckNewsRisk()
{
   // This is a placeholder - implement actual news checking
   // In a real implementation, you would check an economic calendar
   
   // Example: Skip trading during major news events
   // You would typically use an economic calendar API here
   
   return true; // No news risk detected
}

//+------------------------------------------------------------------+
//| Calculate position size using the Kelly Criterion                |
//+------------------------------------------------------------------+
double CRiskManager::CalculateKellyFraction(double winRate, double winLossRatio)
{
   // Kelly % = W - [(1 - W) / R]
   // Where:
   // W = Win probability
   // R = Win/loss ratio
   
   if(winRate <= 0 || winRate >= 1.0 || winLossRatio <= 0)
      return 0.0;
      
   double kelly = winRate - ((1.0 - winRate) / winLossRatio);
   
   // Conservative approach: use half-Kelly to reduce risk
   return kelly * 0.5;
}

//+------------------------------------------------------------------+
//| Normalize lots to allowed values                                 |
//+------------------------------------------------------------------+
double CRiskManager::NormalizeLots(double lots)
{
   if(m_symbol == NULL)
      return 0.0;
      
   double lotStep = SymbolInfoDouble(m_symbol.Name(), SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(m_symbol.Name(), SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(m_symbol.Name(), SYMBOL_VOLUME_MAX);
   
   if(lotStep <= 0 || minLot <= 0 || maxLot <= 0)
      return 0.0;
      
   lots = MathFloor(lots / lotStep) * lotStep;
   lots = MathMax(minLot, MathMin(lots, maxLot));
   
   return lots;
}
