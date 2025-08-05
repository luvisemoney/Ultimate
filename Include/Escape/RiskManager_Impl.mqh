//+------------------------------------------------------------------+
//|                                           RiskManager_Impl.mqh   |
//|                                          Copyright 2025, EscapeEA |
//|                                             https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "2.10"
#property strict

// Include necessary headers
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Arrays\ArrayString.mqh>
#include <Arrays\List.mqh>
#include <Files\FileBin.mqh>
#include <Files\FileTxt.mqh>
#include <Indicators\Oscilators.mqh>
#include <Math\Stat\Math.mqh>

// Logging levels
enum ENUM_LOG_LEVEL
{
   LOG_LEVEL_NONE = 0,    // No logging
   LOG_LEVEL_ERROR,       // Only errors
   LOG_LEVEL_WARNING,     // Errors and warnings
   LOG_LEVEL_INFO,        // Basic information
   LOG_LEVEL_DEBUG,       // Detailed debug information
   LOG_LEVEL_TRACE        // Very detailed tracing
};

// Trade metrics structure
struct STradeMetrics
{
   datetime   timestamp;          // Time of the trade
   string     symbol;             // Symbol
   double     volume;             // Trade volume
   double     entryPrice;         // Entry price
   double     exitPrice;          // Exit price
   double     pips;               // Pips gained/lost
   double     profit;             // Profit/loss in account currency
   double     drawdown;           // Drawdown at time of trade
   double     volatility;         // Market volatility (ATR)
   double     spread;             // Spread at time of trade
   int        duration;           // Trade duration in seconds
   string     comment;            // Additional comments
   
   // Default constructor
   STradeMetrics() : timestamp(0), symbol(""), volume(0), entryPrice(0), exitPrice(0), 
                     pips(0), profit(0), drawdown(0), volatility(0), spread(0), duration(0), comment("") {}
};

// Performance metrics structure
struct SPerformanceMetrics
{
   int         totalTrades;       // Total number of trades
   int         winningTrades;     // Number of winning trades
   double      totalProfit;       // Total profit
   double      totalLoss;         // Total loss
   double      largestWin;        // Largest winning trade
   double      largestLoss;       // Largest losing trade
   double      maxDrawdown;       // Maximum drawdown
   double      profitFactor;      // Profit factor (gross profit / gross loss)
   double      recoveryFactor;    // Net profit / max drawdown
   double      sharpeRatio;       // Risk-adjusted return
   double      sortinoRatio;      // Downside risk-adjusted return
   double      averageTrade;      // Average trade result
   double      standardDeviation; // Standard deviation of returns
   double      winRate;           // Win rate percentage
   
   // Default constructor
   SPerformanceMetrics() : totalTrades(0), winningTrades(0), totalProfit(0), totalLoss(0),
                          largestWin(0), largestLoss(0), maxDrawdown(0), profitFactor(0),
                          recoveryFactor(0), sharpeRatio(0), sortinoRatio(0), averageTrade(0),
                          standardDeviation(0), winRate(0) {}
};

// Forward declarations
class CSecurityManager;
class CTradeRiskRecord;

// Include the header file to get class declaration
#include "RiskManager.mqh"

// Circuit breaker thresholds
#define CIRCUIT_BREAKER_THRESHOLD 5      // Number of consecutive failures before tripping
#define CIRCUIT_BREAKER_TIMEOUT 300      // Timeout in seconds before reset attempt
#define MAX_RETRY_ATTEMPTS 3             // Maximum number of retry attempts
#define INITIAL_RETRY_DELAY 1000         // Initial retry delay in milliseconds
#define MAX_RETRY_DELAY 60000            // Maximum retry delay in milliseconds

// Metrics file constants
#define METRICS_FILE_PREFIX "RiskMetrics_"
#define MAX_METRICS_ENTRIES 10000        // Maximum number of metrics entries to keep in memory

// Log file constants
#define LOG_FILE_PREFIX "RiskManager_"
#define MAX_LOG_FILE_SIZE 10485760        // 10 MB max log file size
#define MAX_LOG_FILES 5                  // Maximum number of log files to keep

// Define missing ENUM_ACCOUNT_INFO_DOUBLE values if not already defined
#ifndef ACCOUNT_COMMISSION
   #define ACCOUNT_COMMISSION 16
#endif

#ifndef ACCOUNT_SWAP
   #define ACCOUNT_SWAP 32
#endif

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager() :
   m_security(NULL),
   m_riskPerTrade(1.0),
   m_dailyLossLimit(2.0),
   m_maxOpenTrades(5),
   m_maxOrdersPerDay(20),
   m_useVolatilityAdjustment(true),
   m_atrPeriod(14),
   m_maxSpread(50.0),
   m_circuitBreakerActive(false),
   m_consecutiveFailures(0),
   m_circuitBreakerTime(0),
   m_logLevel(LOG_LEVEL_INFO),
   m_enableMetrics(true),
   m_enableDetailedLogging(false),
   m_lastMetricsUpdate(0),
   m_metricsUpdateInterval(60),  // Update metrics every 60 seconds
   m_retryAttempts(0),
   m_nextRetryTime(0),
   m_anomalyDetection(true),
   m_maxLeverage(30),
   m_dailyPnL(0.0),
   m_todayOrders(0),
   m_lastTradeDay(0),
   m_equityHigh(0.0),
   m_maxDrawdown(0.0),
   m_openTrades(NULL),
   m_watchlist(NULL),
   m_lastError(""),
   m_lastErrorSeverity(RISK_ERROR_NONE),
   m_atrHandle(INVALID_HANDLE),
   m_rateLimitHistory(NULL),
   m_enableRateLimiting(true),
   m_maxRequestsPerMinute(60),
   m_ordersToday(0)
{
   m_openTrades = new CArrayObj();
   m_watchlist = new CArrayString();
   m_security = new CSecurityManager();
   m_rateLimitHistory = new CArrayObj();
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CRiskManager::~CRiskManager()
{
   if(CheckPointer(m_openTrades) == POINTER_DYNAMIC)
      delete m_openTrades;
      
   if(CheckPointer(m_watchlist) == POINTER_DYNAMIC)
      delete m_watchlist;
      
   if(CheckPointer(m_security) == POINTER_DYNAMIC)
      delete m_security;
      
   if(CheckPointer(m_rateLimitHistory) == POINTER_DYNAMIC)
      delete m_rateLimitHistory;
      
   if(m_atrHandle != INVALID_HANDLE)
      IndicatorRelease(m_atrHandle);
}

//+------------------------------------------------------------------+
//| Initialize the risk manager                                      |
//+------------------------------------------------------------------+
bool CRiskManager::Initialize()
{
   if(m_initialized)
   {
      m_lastError = "Risk manager already initialized";
      return true;
   }
   
   // Initialize ATR indicator for volatility calculation
   m_atrHandle = iATR(_Symbol, PERIOD_CURRENT, m_atrPeriod);
   if(m_atrHandle == INVALID_HANDLE)
   {
      m_lastError = "Failed to create ATR indicator";
      m_lastErrorSeverity = RISK_ERROR_CRITICAL;
      return false;
   }
   
   // Initialize security manager
   if(m_security == NULL)
   {
      m_security = new CSecurityManager();
   }
   
   if(!m_security.Initialize())
   {
      m_lastError = "Failed to initialize security manager: " + m_security.GetLastError();
      m_lastErrorSeverity = RISK_ERROR_CRITICAL;
      return false;
   }
   
   // Initialize state
   m_equityHigh = AccountInfoDouble(ACCOUNT_EQUITY);
   m_lastTradeDay = TimeCurrent();
   m_initialized = true;
   
   // Load configuration
   if(!LoadConfiguration())
   {
      m_lastError = "Warning: Using default configuration - " + m_lastError;
      m_lastErrorSeverity = RISK_ERROR_WARNING;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialize the risk manager                                   |
//+------------------------------------------------------------------+
void CRiskManager::Deinitialize()
{
   if(m_atrHandle != INVALID_HANDLE)
   {
      IndicatorRelease(m_atrHandle);
      m_atrHandle = INVALID_HANDLE;
   }
   
   if(CheckPointer(m_security) == POINTER_DYNAMIC)
   {
      m_security.Deinitialize();
   }
   
   m_initialized = false;
}

//+------------------------------------------------------------------+
//| Validate a trade request                                        |
//+------------------------------------------------------------------+
bool CRiskManager::ValidateTrade(const string symbol, double volume, double price, double sl, double tp)
{
   if(!m_initialized)
   {
      m_lastError = "Risk manager not initialized";
      m_lastErrorSeverity = RISK_ERROR_CRITICAL;
      return false;
   }
   
   // Check if trading is allowed
   if(!IsTradingAllowed())
      return false;
      
   // Check if symbol is in watchlist
   if(m_watchlist.Total() > 0 && m_watchlist.SearchLinear(symbol) < 0)
   {
      m_lastError = "Symbol " + symbol + " not in watchlist";
      m_lastErrorSeverity = RISK_ERROR_WARNING;
      return false;
   }
   
   // Validate lot size
   if(!ValidateLotSize(symbol, volume))
      return false;
      
   // Validate spread
   if(!ValidateSpread(symbol))
      return false;
      
   // Check daily loss limit
   if(!ValidateDailyLossLimit())
      return false;
      
   // Check circuit breaker
   if(m_circuitBreakerActive)
   {
      m_lastError = "Trading suspended - circuit breaker active";
      m_lastErrorSeverity = RISK_ERROR_CRITICAL;
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Validate lot size                                               |
//+------------------------------------------------------------------+
bool CRiskManager::ValidateLotSize(const string symbol, double volume)
{
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   if(volume < minLot || volume > maxLot)
   {
      m_lastError = StringFormat("Invalid lot size %.2f for %s (min: %.2f, max: %.2f)", 
                               volume, symbol, minLot, maxLot);
      m_lastErrorSeverity = RISK_ERROR_WARNING;
      return false;
   }
   
   // Check if volume is a multiple of lot step
   if(MathMod(volume, lotStep) > 0.0001) // Account for floating point precision
   {
      m_lastError = StringFormat("Lot size %.2f for %s must be a multiple of %.2f", 
                               volume, symbol, lotStep);
      m_lastErrorSeverity = RISK_ERROR_WARNING;
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Validate spread                                                 |
//+------------------------------------------------------------------+
bool CRiskManager::ValidateSpread(const string symbol)
{
   double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(spread > m_maxSpread)
   {
      m_lastError = StringFormat("Spread %.1f for %s exceeds maximum allowed (%.1f)", 
                               spread, symbol, m_maxSpread);
      m_lastErrorSeverity = RISK_ERROR_WARNING;
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Validate daily loss limit                                       |
//+------------------------------------------------------------------+
bool CRiskManager::ValidateDailyLossLimit()
{
   if(m_dailyPnL < 0 && MathAbs(m_dailyPnL) >= (AccountInfoDouble(ACCOUNT_BALANCE) * m_dailyLossLimit / 100.0))
   {
      m_lastError = StringFormat("Daily loss limit reached (%.2f%% of balance)", m_dailyLossLimit);
      m_lastErrorSeverity = RISK_ERROR_CRITICAL;
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk parameters                |
//+------------------------------------------------------------------+
double CRiskManager::CalculatePositionSize(const string symbol, const double entryPrice, const double stopLoss, const double riskAmount)
{
   if(entryPrice <= 0 || stopLoss <= 0 || riskAmount <= 0)
   {
      m_lastError = "Invalid parameters for position sizing";
      m_lastErrorSeverity = RISK_ERROR_WARNING;
      return 0.0;
   }
   
   double positionSize = 0.0;
   
   // Select position sizing method
   switch(m_positionSizingMethod)
   {
      case POSITION_SIZING_FIXED:
         positionSize = m_fixedLotSize;
         break;
         
      case POSITION_SIZING_VOLATILITY:
         positionSize = CalculateVolatilityBasedSize(symbol, entryPrice, stopLoss, riskAmount);
         break;
         
      case POSITION_SIZING_KELLY:
      {
         double winRate = CalculateWinRate(symbol);
         double winLossRatio = CalculateWinLossRatio(symbol);
         positionSize = CalculateKellySize(symbol, entryPrice, stopLoss, winRate, winLossRatio);
         break;
      }
         
      case POSITION_SIZING_OPTIMAL_F:
      {
         double winRate = CalculateWinRate(symbol);
         double winLossRatio = CalculateWinLossRatio(symbol);
         positionSize = CalculateOptimalFSize(symbol, entryPrice, stopLoss, winRate, winLossRatio);
         break;
      }
         
      case POSITION_SIZING_HYBRID:
      {
         double winRate = CalculateWinRate(symbol);
         double winLossRatio = CalculateWinLossRatio(symbol);
         positionSize = CalculateHybridSize(symbol, entryPrice, stopLoss, riskAmount, winRate, winLossRatio);
         break;
      }
         
      case POSITION_SIZING_RISK_BASED:
      default:
         positionSize = CalculateRiskBasedSize(symbol, entryPrice, stopLoss, riskAmount);
   }
   
   // Apply position scaling based on account growth if enabled
   if(m_positionScaling != SCALING_NONE)
   {
      double initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      double currentBalance = AccountInfoDouble(ACCOUNT_EQUITY);
      double growthFactor = (currentBalance - initialBalance) / initialBalance;
      positionSize = ScalePositionSize(positionSize, growthFactor);
   }
   
   // Apply position size limits
   positionSize = MathMax(m_minPositionSize, MathMin(positionSize, m_maxPositionSize));
   
   // Round to nearest step
   if(m_positionSizeStep > 0)
   {
      positionSize = MathRound(positionSize / m_positionSizeStep) * m_positionSizeStep;
   }
   
   return NormalizeLotSize(positionSize);
}

//+------------------------------------------------------------------+
//| Calculate position size based on volatility (ATR)               |
//+------------------------------------------------------------------+
double CRiskManager::CalculateVolatilityBasedSize(const string symbol, const double entryPrice, const double stopLoss, const double riskAmount)
{
   double atrValue = GetATRValue(symbol, PERIOD_CURRENT, (int)m_volatilityPeriod);
   
   if(atrValue <= 0)
   {
      // Fall back to standard risk-based if ATR is not available
      return CalculateRiskBasedSize(symbol, entryPrice, stopLoss, riskAmount);
   }
   
   double stopDistance = MathAbs(entryPrice - stopLoss);
   double atrMultiple = stopDistance / atrValue;
   
   // Adjust risk amount based on volatility
   double adjustedRisk = riskAmount * (1.0 + (1.0 - 1.0 / (1.0 + atrMultiple)) * m_volatilityMultiplier);
   
   return CalculateRiskBasedSize(symbol, entryPrice, stopLoss, adjustedRisk);
}

//+------------------------------------------------------------------+
//| Calculate position size using Kelly Criterion                    |
//+------------------------------------------------------------------+
double CRiskManager::CalculateKellySize(const string symbol, const double entryPrice, const double stopLoss, 
                                      const double winRate, const double winLossRatio)
{
   if(winRate <= 0 || winRate >= 1.0 || winLossRatio <= 0)
   {
      // Fall back to standard risk-based if invalid parameters
      return CalculateRiskBasedSize(symbol, entryPrice, stopLoss, m_riskPerTrade);
   }
   
   // Kelly formula: f* = (bp - q) / b
   // where: f* = fraction of current bankroll to wager
   //        b = net odds received on wager (win amount / loss amount)
   //        p = probability of winning
   //        q = probability of losing (1 - p)
   double kellyFraction = (winRate * winLossRatio - (1.0 - winRate)) / winLossRatio;
   
   // Apply user-defined fraction of Kelly (0.0 to 1.0)
   kellyFraction = MathMax(0.0, MathMin(kellyFraction * m_kellyFraction, 1.0));
   
   // Calculate position size based on Kelly fraction
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * kellyFraction;
   
   return CalculateRiskBasedSize(symbol, entryPrice, stopLoss, riskAmount);
}

//+------------------------------------------------------------------+
//| Calculate position size using Optimal F                          |
//+------------------------------------------------------------------+
double CRiskManager::CalculateOptimalFSize(const string symbol, const double entryPrice, const double stopLoss, 
                                         const double winRate, const double winLossRatio)
{
   if(winRate <= 0 || winRate >= 1.0 || winLossRatio <= 0)
   {
      // Fall back to standard risk-based if invalid parameters
      return CalculateRiskBasedSize(symbol, entryPrice, stopLoss, m_riskPerTrade);
   }
   
   // Simplified Optimal F calculation
   // Optimal f = ( (1 + winLossRatio) * winRate - 1 ) / winLossRatio
   double optimalF = ((1.0 + winLossRatio) * winRate - 1.0) / winLossRatio;
   
   // Apply user-defined fraction of Optimal F (0.0 to 1.0)
   optimalF = MathMax(0.0, MathMin(optimalF * m_optimalFFraction, 1.0));
   
   // Calculate position size based on Optimal F
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * optimalF;
   
   return CalculateRiskBasedSize(symbol, entryPrice, stopLoss, riskAmount);
}

//+------------------------------------------------------------------+
//| Calculate position size using hybrid approach                    |
//+------------------------------------------------------------------+
double CRiskManager::CalculateHybridSize(const string symbol, const double entryPrice, const double stopLoss, 
                                       const double riskAmount, const double winRate, const double winLossRatio)
{
   // Calculate position sizes using different methods
   double riskBased = CalculateRiskBasedSize(symbol, entryPrice, stopLoss, riskAmount);
   double volatilityBased = CalculateVolatilityBasedSize(symbol, entryPrice, stopLoss, riskAmount);
   
   // If we have valid win rate and win/loss ratio, include Kelly and Optimal F
   if(winRate > 0 && winRate < 1.0 && winLossRatio > 0)
   {
      double kellySize = CalculateKellySize(symbol, entryPrice, stopLoss, winRate, winLossRatio);
      double optimalFSize = CalculateOptimalFSize(symbol, entryPrice, stopLoss, winRate, winLossRatio);
      
      // Use weighted average of all methods
      return (riskBased * 0.2 + volatilityBased * 0.3 + kellySize * 0.25 + optimalFSize * 0.25);
   }
   
   // Fall back to average of risk-based and volatility-based
   return (riskBased + volatilityBased) / 2.0;
}

//+------------------------------------------------------------------+
//| Scale position size based on account growth                      |
//+------------------------------------------------------------------+
double CRiskManager::ScalePositionSize(const double size, const double accountGrowth)
{
   if(accountGrowth <= 0 || m_positionScaling == SCALING_NONE)
   {
      return size;
   }
   
   double scaleFactor = 1.0;
   
   switch(m_positionScaling)
   {
      case SCALING_LINEAR:
         scaleFactor = 1.0 + accountGrowth;
         break;
         
      case SCALING_SQRT:
         scaleFactor = MathSqrt(1.0 + accountGrowth);
         break;
         
      case SCALING_LOG:
         scaleFactor = 1.0 + MathLog(1.0 + accountGrowth);
         break;
         
      case SCALING_NONE:
      default:
         return size;
   }
   
   return size * scaleFactor;
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk (base method)              |
//+------------------------------------------------------------------+
double CRiskManager::CalculateRiskBasedSize(const string symbol, const double entryPrice, 
                                          const double stopLoss, const double riskAmount)
{
   if(entryPrice <= 0 || stopLoss <= 0 || riskAmount <= 0)
   {
      m_lastError = "Invalid parameters for risk-based position sizing";
      m_lastErrorSeverity = RISK_ERROR_WARNING;
      return 0.0;
   }
   
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   if(tickSize <= 0 || tickValue <= 0 || lotStep <= 0)
   {
      m_lastError = "Invalid symbol parameters for position sizing";
      m_lastErrorSeverity = RISK_ERROR_WARNING;
      return 0.0;
   }
   
   double stopDistance = MathAbs(entryPrice - stopLoss) / tickSize;
   double riskPerLot = stopDistance * tickValue;
   
   if(riskPerLot <= 0)
   {
      m_lastError = "Invalid risk per lot calculation";
      m_lastErrorSeverity = RISK_ERROR_WARNING;
      return 0.0;
   }
   
   double lots = riskAmount / riskPerLot;
   
   // Normalize to lot step
   lots = MathFloor(lots / lotStep) * lotStep;
   
   // Check against symbol limits
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   
   return MathMax(minLot, MathMin(lots, maxLot));
}

//+------------------------------------------------------------------+
//| Calculate risk amount based on account balance and risk percent |
//+------------------------------------------------------------------+
double CRiskManager::CalculateRiskAmount(double accountBalance, double riskPercent)
{
   if(accountBalance <= 0 || riskPercent <= 0)
      return 0.0;
      
   return accountBalance * riskPercent / 100.0;
}

//+------------------------------------------------------------------+
//| Calculate risk for a trade                                      |
//+------------------------------------------------------------------+
double CRiskManager::CalculateTradeRisk(const string symbol, double volume, double entryPrice, double stopLoss)
{
   if(entryPrice <= 0 || stopLoss <= 0 || volume <= 0)
      return 0.0;
      
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   if(tickSize == 0 || tickValue == 0 || point == 0)
      return 0.0;
      
   double riskPoints = MathAbs(entryPrice - stopLoss) / point;
   return riskPoints * tickValue * volume / (tickSize / point);
}

//+------------------------------------------------------------------+
//| Get current risk exposure                                       |
//+------------------------------------------------------------------+
double CRiskManager::GetCurrentRiskExposure()
{
   if(!m_initialized)
      return 0.0;
      
   double totalRisk = 0.0;
   
   // Calculate risk from open positions
   for(int i = 0; i < m_openTrades.Total(); i++)
   {
      CTradeRiskRecord* trade = m_openTrades.At(i);
      if(trade != NULL)
      {
         totalRisk += CalculateTradeRisk(trade.symbol, trade.volume, trade.entry, trade.sl);
      }
   }
   
   return totalRisk;
}

//+------------------------------------------------------------------+
//| Check circuit breaker status                                    |
//+------------------------------------------------------------------+
bool CRiskManager::CheckCircuitBreaker()
{
   if(!m_initialized)
   {
      m_lastError = "Risk manager not initialized";
      m_lastErrorSeverity = RISK_ERROR_CRITICAL;
      return false;
   }
   
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double drawdown = 1.0 - (equity / m_equityHigh);
   
   if(drawdown >= m_circuitBreakerLevel)
   {
      m_circuitBreakerActive = true;
      m_circuitBreakerLevel = drawdown;
      m_lastError = StringFormat("Circuit breaker triggered at %.2f%% drawdown", drawdown * 100.0);
      m_lastErrorSeverity = RISK_ERROR_CRITICAL;
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Reset circuit breaker                                           |
//+------------------------------------------------------------------+
void CRiskManager::ResetCircuitBreaker()
{
   m_circuitBreakerActive = false;
   m_equityHigh = AccountInfoDouble(ACCOUNT_EQUITY);
   m_lastError = "Circuit breaker reset";
   m_lastErrorSeverity = RISK_ERROR_NONE;
}

//+------------------------------------------------------------------+
//| Load configuration from file                                    |
//+------------------------------------------------------------------+
bool CRiskManager::LoadConfiguration()
{
   string filename = "RiskManager.cfg";
   int handle = FileOpen(filename, FILE_READ|FILE_BIN|FILE_COMMON);
   
   if(handle == INVALID_HANDLE)
   {
      m_lastError = "No configuration file found, using defaults";
      return false;
   }
   
   // Read configuration values
   m_riskPerTrade = FileReadDouble(handle);
   m_dailyLossLimit = FileReadDouble(handle);
   m_maxOpenTrades = (int)FileReadInteger(handle);
   m_maxOrdersPerDay = (int)FileReadInteger(handle);
   m_useVolatilityAdjustment = FileReadInteger(handle) != 0;
   m_atrPeriod = (int)FileReadInteger(handle);
   m_maxSpread = FileReadDouble(handle);
   m_anomalyDetection = FileReadInteger(handle) != 0;
   m_maxLeverage = (int)FileReadInteger(handle);
   m_enableRateLimiting = FileReadInteger(handle) != 0;
   m_maxRequestsPerMinute = (int)FileReadInteger(handle);
   
   FileClose(handle);
   return true;
}

//+------------------------------------------------------------------+
//| Save configuration to file                                      |
//+------------------------------------------------------------------+
bool CRiskManager::SaveConfiguration()
{
   if(!m_initialized)
   {
      m_lastError = "Risk manager not initialized";
      m_lastErrorSeverity = RISK_ERROR_CRITICAL;
      return false;
   }
   
   string filename = "RiskManager.cfg";
   int handle = FileOpen(filename, FILE_WRITE|FILE_BIN|FILE_COMMON);
   
   if(handle == INVALID_HANDLE)
   {
      m_lastError = "Failed to open configuration file for writing";
      m_lastErrorSeverity = RISK_ERROR_WARNING;
      return false;
   }
   
   // Write configuration values
   FileWriteDouble(handle, m_riskPerTrade);
   FileWriteDouble(handle, m_dailyLossLimit);
   FileWriteInteger(handle, m_maxOpenTrades);
   FileWriteInteger(handle, m_maxOrdersPerDay);
   FileWriteInteger(handle, m_useVolatilityAdjustment ? 1 : 0);
   FileWriteInteger(handle, m_atrPeriod);
   FileWriteDouble(handle, m_maxSpread);
   FileWriteInteger(handle, m_anomalyDetection ? 1 : 0);
   FileWriteInteger(handle, m_maxLeverage);
   FileWriteInteger(handle, m_enableRateLimiting ? 1 : 0);
   FileWriteInteger(handle, m_maxRequestsPerMinute);
   
   FileClose(handle);
   return true;
}

//+------------------------------------------------------------------+
//| Event handler for tick events                                   |
//+------------------------------------------------------------------+
void CRiskManager::OnTick()
{
   if(!m_initialized)
      return;
      
   // Update equity high water mark
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity > m_equityHigh)
      m_equityHigh = equity;
      
   // Check for new trading day
   MqlDateTime dt;
   TimeCurrent(dt);
   MqlDateTime lastDt;
   TimeToStruct(m_lastTradeDay, lastDt);
   
   if(dt.day != lastDt.day || dt.mon != lastDt.mon || dt.year != lastDt.year)
   {
      // New trading day - reset daily counters
      m_todayOrders = 0;
      m_dailyPnL = 0;
      m_lastTradeDay = TimeCurrent();
   }
   
   // Check circuit breaker
   CheckCircuitBreaker();
}

//+------------------------------------------------------------------+
//| Event handler for trade events                                  |
//+------------------------------------------------------------------+
void CRiskManager::OnTrade()
{
   if(!m_initialized)
      return;
      
   // Update open trades list
   UpdateOpenTrades();
   
   // Update daily P&L
   UpdateDailyPnL();
}

//+------------------------------------------------------------------+
//| Update list of open trades                                      |
//+------------------------------------------------------------------+
void CRiskManager::UpdateOpenTrades()
{
   if(!m_initialized)
      return;
      
   m_openTrades.Clear();
   
   // Get all open positions
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         CTradeRiskRecord* trade = new CTradeRiskRecord();
         trade.ticket = ticket;
         trade.symbol = PositionGetString(POSITION_SYMBOL);
         trade.volume = PositionGetDouble(POSITION_VOLUME);
         trade.entry = PositionGetDouble(POSITION_PRICE_OPEN);
         trade.sl = PositionGetDouble(POSITION_SL);
         trade.tp = PositionGetDouble(POSITION_TP);
         trade.risk = CalculateTradeRisk(trade.symbol, trade.volume, trade.entry, trade.sl);
         trade.openTime = (datetime)PositionGetInteger(POSITION_TIME);
         
         m_openTrades.Add(trade);
      }
   }
}

//+------------------------------------------------------------------+
//| Update daily P&L                                                |
//+------------------------------------------------------------------+
void CRiskManager::UpdateDailyPnL()
{
   if(!m_initialized)
      return;
      
   m_dailyPnL = 0.0;
   
   // Calculate P&L for today's closed trades
   HistorySelect(TimeCurrent() - 86400, TimeCurrent());
   int totalDeals = HistoryDealsTotal();
   
   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         datetime dealTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         if(TimeDay(dealTime) == TimeDay(TimeCurrent()))
         {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                          HistoryDealGetDouble(ticket, DEAL_COMMISSION) +
                          HistoryDealGetDouble(ticket, DEAL_SWAP);
            m_dailyPnL += profit;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Event handler for trade transactions                            |
//+------------------------------------------------------------------+
void CRiskManager::OnTradeTransaction(const MqlTradeTransaction& trans,
                                     const MqlTradeRequest& request,
                                     const MqlTradeResult& result)
{
   if(!m_initialized)
      return;
      
   // Increment order counter for the day
   if(trans.type == TRADE_TRANSACTION_ORDER_ADD || 
      trans.type == TRADE_TRANSACTION_ORDER_UPDATE ||
      trans.type == TRADE_TRANSACTION_ORDER_DELETE)
   {
      m_todayOrders++;
   }
   
   // Update open trades if position was opened/closed
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      UpdateOpenTrades();
      UpdateDailyPnL();
   }
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                     |
//+------------------------------------------------------------------+
bool CRiskManager::IsTradingAllowed()
{
   if(!m_initialized)
   {
      m_lastError = "Risk manager not initialized";
      m_lastErrorSeverity = RISK_ERROR_CRITICAL;
      return false;
   }
   
   // Check circuit breaker
   if(m_circuitBreakerActive)
   {
      m_lastError = "Circuit breaker active";
      m_lastErrorSeverity = RISK_ERROR_CRITICAL;
      return false;
   }
   
   // Check security manager
   if(m_security != NULL && !m_security.IsTradingAllowed())
   {
      m_lastError = "Security restrictions: " + m_security.GetLastError();
      m_lastErrorSeverity = RISK_ERROR_CRITICAL;
      return false;
   }
   
   // Check daily order limit
   if(m_todayOrders >= m_maxOrdersPerDay)
   {
      m_lastError = "Daily order limit reached";
      m_lastErrorSeverity = RISK_ERROR_CRITICAL;
      return false;
   }
   
   // Check open trades limit
   if(m_openTrades.Total() >= m_maxOpenTrades)
   {
      m_lastError = "Maximum number of open trades reached";
      m_lastErrorSeverity = RISK_ERROR_WARNING;
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Save risk manager state                                         |
//+------------------------------------------------------------------+
bool CRiskManager::Save(const int handle)
{
   if(handle == INVALID_HANDLE)
   {
      m_lastError = "Invalid file handle";
      m_lastErrorSeverity = RISK_ERROR_WARNING;
      return false;
   }
   
   // Save state variables
   FileWriteLong(handle, m_lastTradeDay);
   FileWriteDouble(handle, m_equityHigh);
   FileWriteDouble(handle, m_dailyPnL);
   FileWriteInteger(handle, m_todayOrders);
   FileWriteInteger(handle, m_circuitBreakerActive ? 1 : 0);
   FileWriteDouble(handle, m_circuitBreakerLevel);
   FileWriteInteger(handle, m_ordersToday);
   
   return true;
}

//+------------------------------------------------------------------+
//| Load risk manager state                                         |
//+------------------------------------------------------------------+
bool CRiskManager::Load(const int handle)
{
   if(handle == INVALID_HANDLE)
   {
      m_lastError = "Invalid file handle";
      m_lastErrorSeverity = RISK_ERROR_WARNING;
      return false;
   }
   
   // Load state variables
   m_lastTradeDay = (datetime)FileReadLong(handle);
   m_equityHigh = FileReadDouble(handle);
   m_dailyPnL = FileReadDouble(handle);
   m_todayOrders = (int)FileReadInteger(handle);
   m_circuitBreakerActive = FileReadInteger(handle) != 0;
   m_circuitBreakerLevel = FileReadDouble(handle);
   m_ordersToday = (int)FileReadInteger(handle);
   
   return true;
}

//+------------------------------------------------------------------+
//| Update symbol cache with latest market data                     |
//+------------------------------------------------------------------+
void CRiskManager::UpdateSymbolCache(const string symbol)
{
   // Implementation for updating symbol cache
   // This is a placeholder - actual implementation would depend on requirements
}

//+------------------------------------------------------------------+
//| Check if rate limit is exceeded                                 |
//+------------------------------------------------------------------+
bool CRiskManager::CheckRateLimit()
{
   // Thread-safe section
   CCriticalLock lock(m_cs);
   
   // Check if rate limiting is enabled
   if(!m_enableRateLimiting)
   {
      m_lastErrorCode = RISK_ERROR_NONE;
      return true; // Rate limiting is disabled
   }
      
   // Get current time once to ensure consistency
   datetime currentTime = TimeCurrent();
   MqlDateTime timeStruct;
   if(!TimeToStruct(currentTime, timeStruct))
   {
      m_lastError = FormatError("Failed to get time structure", RISK_ERROR_INVALID_STATE);
      m_lastErrorCode = RISK_ERROR_INVALID_STATE;
      m_lastErrorSeverity = RISK_ERROR_CRITICAL;
      return false;
   }
   
   // Validate configuration
   if(!ValidateConfig())
   {
      m_lastErrorSeverity = RISK_ERROR_CRITICAL;
      return false;
   }
   
   // Validate member variables
   if(CheckPointer(m_rateLimitHistory) == POINTER_INVALID)
   {
      m_lastError = FormatError("Rate limit history not initialized", RISK_ERROR_INVALID_STATE);
      m_lastErrorCode = RISK_ERROR_INVALID_STATE;
      m_lastErrorSeverity = RISK_ERROR_CRITICAL;
      return false;
   }
   
   // Clean up old entries from the rate limit history
   for(int i = m_rateLimitHistory.Total() - 1; i >= 0; i--)
   {
      CTradeRiskRecord* record = m_rateLimitHistory.At(i);
      if(CheckPointer(record) == POINTER_INVALID) 
      {
         m_rateLimitHistory.Delete(i);
         continue;
      }
      
      // Remove entries older than our rate limit window (1 minute)
      if(currentTime - record.Time() > 60) // 60 seconds window
      {
         CTradeRiskRecord* oldRecord = m_rateLimitHistory.Detach(i);
         if(CheckPointer(oldRecord) == POINTER_DYNAMIC)
            delete oldRecord;
      }
   }
   
   // Check if we've exceeded the maximum allowed requests per minute
   if(m_rateLimitHistory.Total() >= m_maxRequestsPerMinute)
   {
      m_lastError = FormatError("Rate limit exceeded: " + 
                               IntegerToString(m_rateLimitHistory.Total()) + 
                               " requests in the last minute", 
                               RISK_ERROR_RATE_LIMIT);
      m_lastErrorCode = RISK_ERROR_RATE_LIMIT;
      m_lastErrorSeverity = RISK_ERROR_WARNING;
      return false;
   }
   
   // Check if we've exceeded the maximum concurrent open trades
   int totalPositions = PositionsTotal();
   if(totalPositions < 0) // Handle error case
   {
      m_lastError = FormatError("Failed to get open positions count", RISK_ERROR_INVALID_STATE);
      m_lastErrorCode = RISK_ERROR_INVALID_STATE;
      m_lastErrorSeverity = RISK_ERROR_CRITICAL;
      return false;
   }
   
   if(totalPositions >= m_maxOpenTrades)
   {
      m_lastError = FormatError("Maximum open trades limit reached: " + 
                               IntegerToString(m_maxOpenTrades), 
                               RISK_ERROR_TRADE_LIMIT);
      m_lastErrorCode = RISK_ERROR_TRADE_LIMIT;
      m_lastErrorSeverity = RISK_ERROR_CRITICAL;
      return false;
   }
   
   // Check if we've exceeded daily order limit with boundary check
   if(m_ordersToday < 0) 
      m_ordersToday = 0; // Fix corrupted counter
   
   if(m_ordersToday >= m_maxOrdersPerDay)
   {
      m_lastError = FormatError("Daily order limit reached: " + 
                               IntegerToString(m_ordersToday) + " of " + 
                               IntegerToString(m_maxOrdersPerDay), 
                               RISK_ERROR_DAILY_LIMIT);
      m_lastErrorCode = RISK_ERROR_DAILY_LIMIT;
      m_lastErrorSeverity = RISK_ERROR_CRITICAL;
      return false;
   }
   
   // Add current request to rate limit history with memory safety
   CTradeRiskRecord* newRecord = new CTradeRiskRecord();
   if(CheckPointer(newRecord) == POINTER_INVALID)
   {
      m_lastError = FormatError("Failed to allocate memory for rate limit tracking", 
                               RISK_ERROR_MEMORY);
      m_lastErrorCode = RISK_ERROR_MEMORY;
      m_lastErrorSeverity = RISK_ERROR_CRITICAL;
      return false;
   }
   
   newRecord.SetTime(currentTime);
   if(m_rateLimitHistory.Add(newRecord) < 0)
   {
      delete newRecord;
      m_lastError = FormatError("Failed to track rate limit", RISK_ERROR_INVALID_STATE);
      m_lastErrorCode = RISK_ERROR_INVALID_STATE;
      m_lastErrorSeverity = RISK_ERROR_CRITICAL;
      return false;
   }
   
   // Reset daily counters at the start of a new trading day
   if(timeStruct.day != m_lastTradeDay)
   {
      m_lastTradeDay = timeStruct.day;
      m_ordersToday = 0;
      m_todayOrders = 0;
   }
   
   m_lastErrorCode = RISK_ERROR_NONE;
   return true;
}

//+------------------------------------------------------------------+
//| Adversarial testing: Simulate slippage                          |
//+------------------------------------------------------------------+
#ifdef ADVERSARIAL_TESTING
void CRiskManager::SimulateSlippage()
{
   // Implementation for slippage simulation in testing
}

//+------------------------------------------------------------------+
//| Adversarial testing: Simulate network latency                   |
//+------------------------------------------------------------------+
void CRiskManager::SimulateNetworkLatency()
{
   // Implementation for network latency simulation in testing
}

//+------------------------------------------------------------------+
//| Adversarial testing: Inject fault                               |
//+------------------------------------------------------------------+
void CRiskManager::InjectFault(const string component, const string type)
{
   // Implementation for fault injection in testing
}
#endif
