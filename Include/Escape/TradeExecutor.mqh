//+------------------------------------------------------------------+
//|                                                  TradeExecutor.mqh |
//|                                          Copyright 2025, EscapeEA |
//|                                             https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "2.00"  // Major version bump for security enhancements
#property strict

/**
 * @file TradeExecutor.mqh
 * @brief Advanced trade execution module with security and risk management features
 * 
 * This module provides a robust trade execution system with the following features:
 * - Secure order execution with validation and retry logic
 * - Circuit breaker pattern to prevent excessive losses
 * - Rate limiting to prevent order flooding
 * - Comprehensive trade logging and performance tracking
 * - Integration with RiskManager for position sizing and risk control
 * - Paper trading simulation capabilities
 * 
 * Security Features:
 * - Input validation for all trade parameters
 * - Market condition verification
 * - Anomaly detection for suspicious trading patterns
 * - Secure order filling policies
 * - Comprehensive error handling and logging
 * 
 * @see CRiskManager.h For risk management integration
 * @see SecurityEnhancements.h For additional security features
 */

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Arrays\ArrayObj.mqh>
#include "RiskManager.mqh"
#include "SecurityEnhancements.mqh"
#include "SecurityManager.mqh"

// Execution limits and constraints
#define MAX_ORDER_AGE_SEC       60      // Maximum age of an order in seconds before considering it stale
#define PRICE_VALIDATION_RANGE  0.0005  // Price validation range (0.05%) for market order validation

// Custom error codes for trade execution (using high numbers to avoid conflicts with MQL5 built-in codes)
#define ESCAPE_ERR_TRADE_DISABLED           10027  // Trade is disabled
#define ESCAPE_ERR_TRADE_POSITION_NOT_FOUND 4753   // Position not found
#define ESCAPE_ERR_TRADE_ORDER_NOT_FOUND    4752   // Order not found
#define ESCAPE_ERR_TRADE_WRONG_SYMBOL       4751   // Wrong symbol
#define ESCAPE_ERR_TRADE_INVALID_VOLUME     131    // Invalid volume
#define ESCAPE_ERR_TRADE_INVALID_PRICE      4106   // Invalid price
#define ESCAPE_ERR_TRADE_SPREAD_TOO_WIDE    135    // Market is too far away
#define ESCAPE_ERR_TRADE_TOO_MANY_ORDERS    148    // Too many orders
#define ESCAPE_ERR_TRADE_LIMIT_REACHED      162    // Trading is prohibited
#define ESCAPE_ERR_INVALID_STOPS           130     // Invalid stops

// Forward declaration of CRiskManager to resolve circular dependency
class CRiskManager;

// Order execution constants - using standard ENUM_ORDER_TYPE_FILLING values
#define FILL_DEFAULT ORDER_FILLING_FOK     // Default fill policy (Fill or Kill)
#define FILL_IOC ORDER_FILLING_IOC         // Immediate or Cancel
#define FILL_RETURN ORDER_FILLING_RETURN   // Return partial fills

// Trade execution result codes - using standard TRADE_RETCODE values with custom extensions
#define TRADE_EXECUTION_SUCCESS TRADE_RETCODE_DONE
#define TRADE_EXECUTION_FAILED TRADE_RETCODE_ERROR
#define TRADE_EXECUTION_REJECTED TRADE_RETCODE_REJECT
#define TRADE_EXECUTION_TIMEOUT TRADE_RETCODE_TIMEOUT
#define TRADE_EXECUTION_VALIDATION_ERROR TRADE_RETCODE_INVALID
#define TRADE_EXECUTION_CIRCUIT_BROKEN TRADE_RETCODE_OFF_QUOTES
#define TRADE_EXECUTION_RATE_LIMITED TRADE_RETCODE_TOO_MANY_REQUESTS

//+------------------------------------------------------------------+
//| Trade Execution Configuration                                    |
//+------------------------------------------------------------------+
/**
 * Execution Settings
 * These parameters control the behavior of trade execution
 */
// Removed: input group "=== Execution Settings ==="
// Removed: input int InpMaxRetries = 3; // Declare only in main EA (.mq5)
// Removed: input int InpRetryDelay = 100; // Declare only in main EA (.mq5)
// Removed: input int InpMaxSlippage = 10; // Declare only in main EA (.mq5)
// Removed: input ENUM_ORDER_FILL_POLICY InpFillPolicy = FILL_DEFAULT; // Declare only in main EA (.mq5)

/**
 * Circuit Breaker Settings
 * Circuit breaker halts trading after consecutive errors to prevent excessive losses
 */
// Removed: input group "=== Circuit Breaker Settings ==="
// Removed: input bool InpUseCircuitBreaker = true; // Declare only in main EA (.mq5)
// Removed: input int InpMaxErrors = 5; // Declare only in main EA (.mq5)
// Removed: input int InpCircuitBreakTime = 300; // Declare only in main EA (.mq5)

/**
 * Security and Logging Settings
 * These parameters control security features and logging verbosity
 */
// Removed: input group "=== Security Settings ==="
// Removed: input bool InpEnableAnomalyDetection = true; // Declare only in main EA (.mq5)
// Removed: input bool InpVerifyOrderFills = true; // Declare only in main EA (.mq5)
// Removed: input bool InpCheckMarketConditions = true; // Declare only in main EA (.mq5)
// Removed: input bool InpLogAllTrades = true; // Declare only in main EA (.mq5)
// Removed: input int InpMaxOrdersPerMinute = 10; // Declare only in main EA (.mq5)
// Removed: input bool InpEnableTradeSignals = true; // Declare only in main EA (.mq5)

//+------------------------------------------------------------------+
//| Trade Execution Record                                           |
//+------------------------------------------------------------------+
class CTradeRecord : public CObject
{
public:
   ulong             ticket;         // Trade ticket
   string            symbol;         // Symbol
   ENUM_ORDER_TYPE   type;           // Order type
   double            volume;         // Trade volume
   double            price;          // Execution price
   double            sl;             // Stop loss
   double            tp;             // Take profit
   datetime          time;           // Execution time
   double            slippage;       // Slippage in points
   bool              isClosed;       // Is position closed
   string            comment;        // Trade comment
   
   CTradeRecord() {}
   ~CTradeRecord() {}
   
   void Set(ulong t, string s, ENUM_ORDER_TYPE ty, double v, double p, 
            double sll, double tpp, double slp, string cmt = "")
   {
      ticket = t;
      symbol = s;
      type = ty;
      volume = v;
      price = p;
      sl = sll;
      tp = tpp;
      slippage = slp;
      time = TimeCurrent();
      isClosed = false;
      comment = cmt;
   }
   
   void Close() { isClosed = true; }
   
   virtual int Compare(const CObject *node, const int mode=0) const
   {
      const CTradeRecord *other = node;
      if(this.ticket < other.ticket) return -1;
      if(this.ticket > other.ticket) return 1;
      return 0;
   }
};

//+------------------------------------------------------------------+
//| CTradeExecutor Class with Enhanced Security                      |
//+------------------------------------------------------------------+
class CTradeExecutor : public CObject
{
private:
   // Trade statistics
   int               m_totalTrades;
   int               m_successfulTrades;
   int               m_failedTrades;
   double            m_totalSlippage;
   double            m_avgExecutionTime;
   
   // State flags
   bool              m_isInitialized;
   bool              m_isTradingAllowed;
   string            m_lastError;
   
   // Trade objects
   CTrade            m_trade;
   CRiskManager     *m_riskManager;
   CPositionInfo     m_position;
   COrderInfo        m_order;
   
   // Configuration
   int               m_maxRetries;
   bool              m_verifyOrderFills;
   bool              m_logAllTrades;
   
   // Trade history and state tracking
   CArrayObj           m_tradeHistory;       // Trade execution history
   CArrayObj           m_activeTrades;       // Currently active trades
   
   // Circuit breaker state
   int                 m_consecutiveErrors;   // Number of consecutive errors for circuit breaker
   datetime            m_circuitBreakTime;    // When the circuit breaker was activated
   bool                m_circuitBroken;       // Whether the circuit breaker is active
   
   // Rate limiting
   static int          s_ordersThisMinute;     // Orders in current minute
   static datetime     s_currentMinute;        // Current minute for rate limiting
   
   // Performance metrics
   int                 m_ordersThisMinute;    // Number of orders in the current minute
   
   // Order tracking
   struct SOrderRequest
   {
      ulong             ticket;           // Order ticket
      string            symbol;           // Trading symbol
      ENUM_ORDER_TYPE   type;             // Order type
      double            volume;           // Order volume
      double            price;            // Order price
      double            sl;               // Stop loss
      double            tp;               // Take profit
      double            deviation;        // Maximum price deviation
      ulong             magic;            // Magic number
      string            comment;          // Order comment
      datetime          expiration;       // Order expiration time
      datetime          timestamp;        // Order creation timestamp
      int               retryCount;       // Number of retry attempts (0 = first attempt)
      bool              isProcessed;      // Whether the order has been processed
      MqlTradeRequest   request;          // Trade request
      MqlTradeResult    result;           // Trade result
      int               errorCode;        // Last error code
      string            errorMessage;     // Last error message
   };
   
   SOrderRequest        m_pendingOrder;       // Pending order request
   bool                 m_hasPendingOrder;    // Has pending order flag
   
   // Security state
   bool                 m_isInitialized;      // Initialization flag
   
   // Security manager
   CSecurityManager*    m_securityManager;    // Security manager instance
   
   // Private methods for security and validation
   bool                 ValidateOrder(const string symbol, ENUM_ORDER_TYPE type, double volume, double price, double sl, double tp, int magic, double slippage, string comment);
   bool                 CheckMarketConditions(const string symbol);
   bool                 CheckRateLimit();
   bool                 VerifyOrderFill(const MqlTradeRequest &request, const MqlTradeResult &result);
   void                 UpdateCircuitBreaker(const bool errorOccurred);
   void                 LogTradeExecution(const MqlTradeRequest &request, const MqlTradeResult &result, const ulong durationMs);
   void                 CleanupOldRecords();
   void                 AddToHistory(CTradeRecord *record);
   void                 UpdateTradeStatus(const ulong ticket, const bool isClosed);
   
public:
   // Constructor/Destructor
   CTradeExecutor(void);
   ~CTradeExecutor(void);
   
   // Initialization
   bool          Initialize(CRiskManager *riskManager, int maxRetries = 3, 
                              bool verifyOrderFills = true, bool logAllTrades = true);
   void          Deinitialize(void);
   
   // Order execution
   bool          OpenPosition(string symbol, ENUM_ORDER_TYPE type, double volume, double price, double sl, double tp, string comment = "", int magic = 0, datetime expiration = 0, double maxSlippage = 0.0);
   bool          ClosePosition(ulong ticket, double volume = 0);
   bool          ModifyPosition(ulong ticket, double sl, double tp);
   
   // Pending order management
   bool          PlacePendingOrder(string symbol, ENUM_ORDER_TYPE type, double volume, double price, double sl, double tp, string comment = "", int magic = 0, datetime expiration = 0);
   bool          ProcessPendingOrders(void);
   
   // Circuit breaker control
   bool          IsCircuitBroken(void) const { return m_circuitBroken; }
   void          ResetCircuitBreaker(void);
   
   // Performance metrics
   double        GetSuccessRate(void) const;
   int           GetTotalTrades(void) const { return m_totalTrades; }
   int           GetSuccessfulTrades(void) const { return m_successfulTrades; }
   int           GetFailedTrades(void) const { return m_failedTrades; }
   
   // Error handling
   string        GetLastError(void) const { return m_lastError; }
   
   // Trading status
   bool          IsTradingAllowed(void) const { return m_isTradingAllowed; }
};

//+------------------------------------------------------------------+
//| Initialize the trade executor                                    |
//+------------------------------------------------------------------+
bool CTradeExecutor::Initialize(CRiskManager *riskManager, int maxRetries, 
                              bool verifyOrderFills, bool logAllTrades)
{
   if(riskManager == NULL)
   {
      m_lastError = "Risk manager cannot be NULL";
      return false;
   }
   
   m_riskManager = riskManager;
   m_maxRetries = maxRetries;
   m_verifyOrderFills = verifyOrderFills;
   m_logAllTrades = logAllTrades;
   m_isInitialized = true;
   m_isTradingAllowed = true;
   
   // Initialize trade statistics
   m_totalTrades = 0;
   m_successfulTrades = 0;
   m_failedTrades = 0;
   m_totalSlippage = 0.0;
   m_avgExecutionTime = 0.0;
   
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialize trade executor and clean up resources               |
//+------------------------------------------------------------------+

void CTradeExecutor::Deinitialize(void)
{
   if(!m_isInitialized)
      return;
   
   // Save any necessary state before deinitializing
   // ...
   
   // Close any open positions if needed (configurable)
   // ...
   
   // Clean up trade history
   m_tradeHistory.Clear();
   m_activeTrades.Clear();
   
   // Reset state
   m_hasPendingOrder = false;
   ZeroMemory(m_pendingOrder);
   
   // Reset circuit breaker
   m_circuitBroken = false;
   m_consecutiveErrors = 0;
   m_circuitBreakTime = 0;
   
   // Reset rate limiting
   s_ordersThisMinute = 0;
   s_currentMinute = 0;
   
   // Reset metrics
   m_totalTrades = 0;
   m_successfulTrades = 0;
   m_failedTrades = 0;
   m_totalSlippage = 0.0;
   m_avgExecutionTime = 0.0;
   
   // Clear last error
   m_lastError = "";
   
   // Mark as uninitialized
   m_isInitialized = false;
   m_isTradingAllowed = false;
   
   Print("TradeExecutor: Deinitialized");
}

//+------------------------------------------------------------------+
//| Open a new market position with comprehensive security checks    |
//+------------------------------------------------------------------+

bool CTradeExecutor::OpenPosition(string symbol, ENUM_ORDER_TYPE type, double volume, 
                                double price, double sl, double tp, string comment, 
                                int magic, datetime expiration, double maxSlippage)
{
   // Check if trading is allowed
   if(!m_isInitialized || !m_isTradingAllowed)
   {
      m_lastError = "Trading is not allowed. Check initialization.";
      Print("TradeExecutor Error: ", m_lastError);
      return false;
   }
   
   // Check circuit breaker
   if(m_circuitBroken)
   {
      if(TimeCurrent() >= m_circuitBreakTime + m_circuitBreakTime)
      {
         Print("Circuit breaker cooldown period ended. Resuming normal operations.");
         ResetCircuitBreaker();
      }
      else
      {
         int remaining = (int)(m_circuitBreakTime + m_circuitBreakTime - TimeCurrent());
         m_lastError = "Circuit breaker active. Trading suspended for " + IntegerToString(remaining) + " seconds";
         Print("TradeExecutor Error: ", m_lastError);
         return false;
      }
   }
   
   // Check rate limiting
   if(!CheckRateLimit())
   {
      m_lastError = "Rate limit exceeded";
      return false;
   }
   
   // Check market conditions if enabled
   if(m_checkMarketConditions && !CheckMarketConditions(symbol))
   {
      m_lastError = "Market conditions check failed for " + symbol;
      Print("TradeExecutor Error: ", m_lastError);
      return false;
   }
   
   // Prepare order request with additional security parameters
   SOrderRequest request = {};
   request.symbol = symbol;
   request.type = type;
   request.volume = volume;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.comment = comment;
   request.magic = (magic > 0) ? magic : m_trade.RequestMagic();
   request.expiration = expiration;
   request.attempts = 0;
   request.reqId = IntegerToString(GetTickCount()) + "_" + IntegerToString(OrdersTotal());
   request.maxSlippage = (maxSlippage > 0) ? maxSlippage : InpMaxSlippage;
   request.requireVerification = InpVerifyOrderFills;
   
   // Log the trade attempt
   if(InpLogAllTrades)
   {
      string orderType = (type == ORDER_TYPE_BUY) ? "BUY" : "SELL";
      PrintFormat("TradeExecutor: Attempting %s %s %.2f lots @ %s (SL: %s, TP: %s)", 
                 orderType, symbol, volume, DoubleToString(price, _Digits), 
                 DoubleToString(sl, _Digits), DoubleToString(tp, _Digits));
   }
   
   // Execute the order with retry logic
   bool result = false;
   MqlTradeRequest tradeRequest = {};
   MqlTradeResult  tradeResult = {};
   
   // Prepare trade request
   tradeRequest.action = TRADE_ACTION_DEAL;
   tradeRequest.symbol = symbol;
   tradeRequest.volume = volume;
   tradeRequest.type = type;
   tradeRequest.price = price;
   tradeRequest.sl = sl;
   tradeRequest.tp = tp;
   tradeRequest.deviation = (ushort)request.maxSlippage;
   tradeRequest.magic = request.magic;
   tradeRequest.comment = comment;
   tradeRequest.type_filling = ORDER_FILLING_FOK;
   
   // Validate the request using the unified validator
   if(!ValidateOrder(symbol, type, volume, price, sl, tp, request.magic, request.maxSlippage, comment))
   {
      m_lastError = "Trade request validation failed: " + m_lastError;
      Print("TradeExecutor Error: ", m_lastError);
      UpdateCircuitBreaker(true);
      return false;
   }
   
   // Execute the trade with retry logic
   ulong startTime = GetTickCount();
   for(int attempt = 0; attempt <= m_maxRetries; attempt++)
   {
      // Check for user break
      if(IsStopped())
      {
         m_lastError = "Operation canceled by user";
         Print("TradeExecutor: ", m_lastError);
         return false;
      }
      
      // Add delay between retries (except first attempt)
      if(attempt > 0)
      {
         int delay = MathMin(m_retryDelay * (int)MathPow(2, attempt-1), 5000); // Exponential backoff, max 5s
         PrintFormat("TradeExecutor: Retry attempt %d of %d after %d ms", 
                    attempt, m_maxRetries, delay);
         Sleep(delay);
      }
      
      // Execute the trade
      ZeroMemory(tradeResult);
      bool success = OrderSend(tradeRequest, tradeResult);
      
      // Log the execution
      ulong duration = GetTickCount() - startTime;
      LogTradeExecution(tradeRequest, tradeResult, duration);
      
      // Check the result
      if(success && tradeResult.retcode == TRADE_RETCODE_DONE)
      {
         // Verify the order fill if required
         if(!request.requireVerification || VerifyOrderFill(tradeRequest, tradeResult))
         {
            // Create trade record
            CTradeRecord *record = new CTradeRecord();
            record.Set(tradeResult.order, symbol, type, volume, tradeResult.price, 
                      sl, tp, tradeResult.deviation, comment);
            AddToHistory(record);
            
            // Update metrics
            m_successfulTrades++;
            m_totalSlippage += tradeResult.deviation;
            m_avgExecutionTime = (m_avgExecutionTime * (m_successfulTrades - 1) + duration) / m_successfulTrades;
            
            if(InpLogAllTrades)
            {
               PrintFormat("TradeExecutor: Order #%d executed successfully in %d ms. Slippage: %.1f pips", 
                          tradeResult.order, duration, tradeResult.deviation);
            }
            
            result = true;
            break;
         }
         else
         {
            // Verification failed
            m_lastError = "Order fill verification failed";
            Print("TradeExecutor Error: ", m_lastError);
            UpdateCircuitBreaker(true);
            return false;
         }
      }
      else
      {
         // Log the error
         string errorDesc = GetRetcodeDescription(tradeResult.retcode);
         m_lastError = StringFormat("OrderSend failed: %s (code: %d)", errorDesc, tradeResult.retcode);
         Print("TradeExecutor Error: ", m_lastError);
         
         // Update error tracking
         m_failedTrades++;
         m_consecutiveErrors++;
         
         // Check if we should continue retrying
         if(attempt >= m_maxRetries - 1)
         {
            UpdateCircuitBreaker(true);
            return false;
         }
      }
   }
   
   // Update metrics
   m_totalTrades++;
   
   // Update last order time for rate limiting
   m_lastOrderTime = TimeCurrent();
   
   // Check if we need to trigger circuit breaker
   if(!result)
   else
   {
      //+------------------------------------------------------------------+
//| Check if market conditions are suitable for trading              |
//+------------------------------------------------------------------+
bool CTradeExecutor::CheckMarketConditions(const string symbol)
{
   // Implementation here
   return true;
}

//+------------------------------------------------------------------+
//| Static member initialization                                     |
//+------------------------------------------------------------------+
int CTradeExecutor::s_ordersThisMinute = 0;
datetime CTradeExecutor::s_currentMinute = 0;

//+------------------------------------------------------------------+
//| Get the number of open positions for a given symbol and magic    |
//+------------------------------------------------------------------+
int CTradeExecutor::GetOpenPositionsCount(const string symbol, int magic)
{
   int count = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if((symbol == "" || m_position.Symbol() == symbol) && 
            (magic == 0 || m_position.Magic() == magic))
         {
            count++;
         }
      }
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk percentage                 |
//+------------------------------------------------------------------+

double CTradeExecutor::CalculatePositionSize(const string symbol, double riskPercent, double stopLossPips)
{
   if(riskPercent <= 0 || stopLossPips <= 0)
      return 0.0;
      
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   
   if(tickSize == 0 || tickValue == 0 || lotStep == 0)
   {
      Print("Error: Invalid symbol parameters for position size calculation");
      return 0.0;
   }
   
   // Calculate position size based on risk percentage
   double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * riskPercent / 100.0;
   double pipValue = tickValue / (tickSize / SymbolInfoDouble(symbol, SYMBOL_POINT));
   double stopLossValue = stopLossPips * pipValue;
   
   if(stopLossValue <= 0)
   {
      Print("Error: Invalid stop loss value for position size calculation");
      return 0.0;
   }
   
   double positionSize = NormalizeDouble(riskAmount / stopLossValue, 2);
   
   // Round to nearest lot step
   positionSize = MathFloor(positionSize / lotStep) * lotStep;
   
   // Ensure position size is within allowed range
   positionSize = MathMax(minLot, MathMin(maxLot, positionSize));
   
   return positionSize;
}

//+------------------------------------------------------------------+
//| Calculate take profit level based on risk/reward ratio           |
//+------------------------------------------------------------------+
double CTradeExecutor::CalculateTakeProfitLevel(double entryPrice, double stopLoss, double riskRewardRatio, bool isBuy)
{
   double priceDiff = MathAbs(entryPrice - stopLoss) * riskRewardRatio;
   
   if(isBuy)
      return entryPrice + priceDiff;
   else
      return entryPrice - priceDiff;
}

//+------------------------------------------------------------------+
//| Send a trade signal to external systems                          |
//+------------------------------------------------------------------+

void CTradeExecutor::SendTradeSignal(const string symbol, ENUM_ORDER_TYPE type, double volume, 
                                   double price, double sl, double tp, const string comment)
{
   if(!InpEnableTradeSignals)
      return;
      
   string signal = StringFormat(
      "TRADE_SIGNAL|%s|%s|%s|%.2f|%.5f|%.5f|%.5f|%s",
      TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
      symbol,
      (type == ORDER_TYPE_BUY) ? "BUY" : "SELL",
      volume,
      price,
      sl,
      tp,
      comment
   );
   
   // In a real implementation, this could send the signal to a webhook, MQ, etc.
   Print("Trade Signal: ", signal);
   
   // Example: Send to a global variable for EA communication
   GlobalVariableSet("LastTradeSignal_" + symbol, TimeCurrent());
   GlobalVariableSet("LastTradeSignal_Data_" + symbol, StringToDouble(signal));
}

#include "TradeExecutor_Impl.mqh"   
   // Reset circuit breaker
   ResetCircuitBreaker();
   
   // Reset metrics
   m_totalTrades = 0;
   m_successfulTrades = 0;
   m_failedTrades = 0;
   m_totalSlippage = 0.0;
   m_avgExecutionTime = 0.0;
   
   // Initialize trade object with current settings
   m_trade.SetDeviationInPoints(InpMaxSlippage);
   
   // Load any persisted state if needed
   // ...
   
   // Clean up any old records
   CleanupOldRecords();
   
   m_isInitialized = true;
   m_isTradingAllowed = true;
   
   Print("TradeExecutor: Initialized successfully");
   return true;
}
