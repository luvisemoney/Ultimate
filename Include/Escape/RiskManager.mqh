//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh |
//|                                          Copyright 2025, EscapeEA |
//|                                             https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "2.20"  // Version bump for major enhancements
#property strict

// Standard Library Includes
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Arrays\ArrayString.mqh>
#include <Arrays\ArrayDouble.mqh>
#include <Files\FileBin.mqh>
#include <Math\Stat\Math.mqh>
#include <Math\Stat\Normal.mqh>

// Forward declarations
class CSecurityManager;

// Risk error codes
enum ENUM_RISK_ERROR_CODES
{
   RISK_ERROR_NONE = 0,           // No error
   RISK_ERROR_INVALID_STATE = 1000, // Invalid object state
   RISK_ERROR_MEMORY = 1001,      // Memory allocation failure
   RISK_ERROR_INVALID_PARAM = 1002, // Invalid parameter
   RISK_ERROR_IO = 1003,          // I/O operation failed
   RISK_ERROR_RATE_LIMIT = 1004,  // Rate limit exceeded
   RISK_ERROR_DAILY_LIMIT = 1005, // Daily limit reached
   RISK_ERROR_TRADE_LIMIT = 1006, // Trade limit reached
   RISK_ERROR_CONFIG = 1007,      // Configuration error
   RISK_ERROR_THREAD = 1008,      // Threading error
   RISK_ERROR_NOT_INITIALIZED = 1009, // Manager not initialized
   RISK_ERROR_SYMBOL = 1010,      // Invalid symbol
   RISK_ERROR_VOLUME = 1011,      // Invalid volume
   RISK_ERROR_PRICE = 1012,       // Invalid price
   RISK_ERROR_STOPLOSS = 1013,    // Invalid stop loss
   RISK_ERROR_TAKEPROFIT = 1014,  // Invalid take profit
   RISK_ERROR_MARGIN = 1015,      // Not enough margin
   RISK_ERROR_MARKET_CLOSED = 1016, // Market is closed
   RISK_ERROR_TRADE_DISABLED = 1017, // Trading is disabled
   RISK_ERROR_ACCOUNT = 1018,     // Account error
   RISK_ERROR_TIMEOUT = 1019,     // Operation timeout
   RISK_ERROR_CONNECTION = 1020   // Connection error
};

// Risk error severity levels
enum ENUM_RISK_ERROR_SEVERITY
{
   RISK_SEVERITY_NONE = 0,     // No error
   RISK_SEVERITY_INFO = 1,     // Informational message
   RISK_SEVERITY_WARNING = 2,  // Warning - non-critical issue
   RISK_SEVERITY_CRITICAL = 3, // Critical error - trading should be paused
   RISK_SEVERITY_FATAL = 4     // Fatal error - immediate action required
};

// Position sizing methods
enum ENUM_POSITION_SIZING_METHOD
{
   POSITION_SIZING_FIXED = 0,     // Fixed lot size
   POSITION_SIZING_RISK_BASED,    // Based on account risk percentage
   POSITION_SIZING_VOLATILITY,    // Based on market volatility (ATR)
   POSITION_SIZING_KELLY,         // Kelly Criterion
   POSITION_SIZING_OPTIMAL_F,     // Optimal F
   POSITION_SIZING_HYBRID,        // Hybrid approach
   POSITION_SIZING_MARTINGALE,    // Martingale (use with caution)
   POSITION_SIZING_ANTI_MARTINGALE // Anti-Martingale
};

// Position scaling methods
enum ENUM_POSITION_SCALING
{
   SCALING_NONE = 0,     // No scaling
   SCALING_LINEAR,       // Linear scaling with account growth
   SCALING_SQRT,         // Square root scaling
   SCALING_LOGARITHMIC,  // Logarithmic scaling
   SCALING_AGGRESSIVE,   // Aggressive scaling (exponential)
   SCALING_CONSERVATIVE  // Conservative scaling (diminishing returns)
};

// Trade direction
enum ENUM_TRADE_DIRECTION
{
   TRADE_DIRECTION_LONG = 1,  // Long position
   TRADE_DIRECTION_SHORT = -1, // Short position
   TRADE_DIRECTION_BOTH = 0    // Both directions
};

// Trade metrics structure for performance analysis
struct STradeMetrics
{
   datetime   timestamp;          // Time of the trade
   string     symbol;             // Symbol
   double     volume;             // Trade volume in lots
   double     entryPrice;         // Entry price
   double     exitPrice;          // Exit price (0 if still open)
   double     stopLoss;           // Stop loss level
   double     takeProfit;         // Take profit level
   double     pips;               // Pips gained/lost
   double     profit;             // Profit/loss in account currency
   double     drawdown;           // Drawdown at time of trade
   double     volatility;         // Market volatility (ATR)
   double     spread;             // Spread at time of trade
   int        duration;           // Trade duration in seconds
   string     comment;            // Additional comments
   double     winRate;            // Current win rate when trade was opened
   double     riskReward;         // Risk/reward ratio
   double     kellySize;          // Kelly position size
   double     optimalFSize;       // Optimal F position size
   
   // Default constructor
   STradeMetrics() : timestamp(0), symbol(""), volume(0), entryPrice(0), exitPrice(0),
                    stopLoss(0), takeProfit(0), pips(0), profit(0), drawdown(0),
                    volatility(0), spread(0), duration(0), winRate(0), riskReward(0),
                    kellySize(0), optimalFSize(0) {}
};

//+------------------------------------------------------------------+
//| CRiskManager - Advanced Risk Management Class                    |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
   // Thread synchronization
   CCriticalSection     m_cs;                // Thread synchronization object
   
   // Configuration
   double              m_riskPerTrade;       // Risk percentage per trade (0.1-5.0%)
   double              m_dailyLossLimit;     // Daily loss limit (% of account)
   int                 m_maxOpenTrades;      // Maximum number of open trades
   int                 m_maxOrdersPerDay;    // Maximum orders per day
   
   // State
   double              m_dailyPnL;           // Today's P&L
   int                 m_todayTrades;        // Trades executed today
   bool                m_initialized;        // Initialization flag
   datetime            m_lastTradeDay;       // Last trading day
   
   // Error handling
   string              m_lastError;          // Last error message
   ENUM_RISK_ERROR_CODES m_lastErrorCode;    // Last error code
   ENUM_RISK_ERROR_SEVERITY m_lastErrorSeverity; // Error severity
   
   // Position sizing
   ENUM_POSITION_SIZING_METHOD m_sizingMethod; // Current sizing method
   ENUM_POSITION_SCALING m_scalingMethod;    // Position scaling method
   double              m_minPositionSize;     // Minimum position size
   double              m_maxPositionSize;     // Maximum position size
   double              m_positionSizeStep;    // Position size step
   double              m_kellyFraction;       // Kelly fraction (0-1)
   double              m_optimalFFraction;    // Optimal F fraction (0-1)
   double              m_volatilityPeriod;    // Period for volatility calculation
   double              m_volatilityMultiplier; // Volatility multiplier
   
   // Caching
   struct SSymbolCache
   {
      double            lastPrice;           // Last price
      double            atrValue;            // Last ATR value
      datetime          lastUpdate;          // Last update time
      double            spread;              // Current spread
      double            pointValue;          // Point value in account currency
      
      SSymbolCache() : lastPrice(0), atrValue(0), lastUpdate(0), spread(0), pointValue(0) {}
   };
   
   CArrayObj*          m_symbolCache;        // Cache for symbol data
   
   // Trade history
   CArrayObj*          m_tradeHistory;       // Trade history for analysis
   int                 m_maxHistorySize;     // Maximum number of trades to keep in history
   
   // Performance metrics
   double              m_equityPeak;         // Peak equity for drawdown calculation
   double              m_maxDrawdown;        // Maximum drawdown percentage
   double              m_winRate;            // Current win rate
   double              m_avgWin;             // Average win amount
   double              m_avgLoss;            // Average loss amount
   double              m_riskRewardRatio;    // Average risk/reward ratio
   
   // Private methods
   double              CalculateRiskBasedSize(const string symbol, double entryPrice, double stopLoss, double riskAmount);
   double              CalculateVolatilitySize(const string symbol, double entryPrice, double stopLoss, double riskAmount);
   double              CalculateKellySize(double winRate, double winLossRatio, double riskAmount);
   double              CalculateOptimalFSize(double winRate, double winLossRatio, double riskAmount);
   double              CalculateHybridSize(const string symbol, double entryPrice, double stopLoss, double riskAmount);
   double              ScalePositionSize(double size, double accountGrowth);
   
   // Helper methods
   bool                IsValidSymbol(const string symbol) const;
   double              NormalizeLotSize(double lots) const;
   double              GetATR(const string symbol, int timeframe, int period, int shift = 0) const;
   void                UpdateSymbolCache(const string symbol);
   void                UpdateTradeMetrics(const STradeMetrics& metrics);
   double              CalculateWinRate() const;
   double              CalculateWinLossRatio() const;
   
public:
   // Constructor/Destructor
                        CRiskManager();
                       ~CRiskManager();
   
   // Initialization
   bool                  Initialize();
   void                  Deinitialize();
   bool                  IsInitialized() const { return m_initialized; }
   
   // Configuration
   void                  SetRiskParameters(double riskPerTrade, double dailyLossLimit, int maxOpenTrades, int maxOrdersPerDay);
   void                  SetPositionSizingMethod(ENUM_POSITION_SIZING_METHOD method) { m_sizingMethod = method; }
   void                  SetPositionScaling(ENUM_POSITION_SCALING method) { m_scalingMethod = method; }
   void                  SetPositionSizeLimits(double minSize, double maxSize, double step = 0.01);
   void                  SetKellyFraction(double fraction) { m_kellyFraction = MathClamp(fraction, 0.0, 1.0); }
   void                  SetOptimalFFraction(double fraction) { m_optimalFFraction = MathClamp(fraction, 0.0, 1.0); }
   void                  SetVolatilityPeriod(int period) { m_volatilityPeriod = MathMax(5, period); }
   void                  SetVolatilityMultiplier(double multiplier) { m_volatilityMultiplier = MathMax(0.1, multiplier); }
   
   // Position sizing
   double                CalculatePositionSize(const string symbol, double entryPrice, double stopLoss, double riskAmount);
   
   // Risk management
   bool                  CheckTradeRisk(const string symbol, double lots, double entryPrice, double stopLoss, double takeProfit, ENUM_ORDER_TYPE orderType);
   bool                  CheckDailyLossLimit() const;
   bool                  CheckMaxOpenTrades() const;
   bool                  CheckDrawdownLimit() const;
   bool                  CheckVolatility(const string symbol) const;
   
   // Trade event handlers
   void                  OnTradeOpen(ulong ticket, const string symbol, ENUM_ORDER_TYPE orderType, double volume, double price, double stopLoss, double takeProfit);
   void                  OnTradeClose(ulong ticket, const string symbol, ENUM_ORDER_TYPE orderType, double volume, double price, double profit, double swap);
   
   // Performance analysis
   double                GetWinRate() const { return m_winRate; }
   double                GetMaxDrawdown() const { return m_maxDrawdown; }
   double                GetRiskRewardRatio() const { return m_riskRewardRatio; }
   int                   GetTotalTrades() const { return m_tradeHistory.Total(); }
   
   // Error handling
   string                GetLastError() const { return m_lastError; }
   ENUM_RISK_ERROR_CODES GetLastErrorCode() const { return m_lastErrorCode; }
   ENUM_RISK_ERROR_SEVERITY GetLastErrorSeverity() const { return m_lastErrorSeverity; }
   
   // State management
   void                  ResetDailyMetrics();
   void                  ResetAllMetrics();
   double                GetDailyPnL() const { return m_dailyPnL; }
   int                   GetTodayTrades() const { return m_todayTrades; }
   
   // Reporting
   string                GenerateReport() const;
   
   // Adversarial testing hooks
   #ifdef ADVSECURITY_ENABLE_TESTING
   friend class CRiskManagerTester;
   #endif
};

// Include implementation
#include "RiskManager_Impl.mqh"
