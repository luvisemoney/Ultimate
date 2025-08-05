//+------------------------------------------------------------------+
//|                                              TradeExecutor.mqh    |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Object.mqh>  // For CObject
#include <Arrays\ArrayObj.mqh>  // For CArrayObj
#include <Trade\OrderInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include "RiskManager.mqh"

//+------------------------------------------------------------------+
//| Error Codes                                                      |
//+------------------------------------------------------------------+
enum ENUM_TRADE_ERROR
{
   ERR_TRADE_SUCCESS = 0,                     // Operation successful
   ERR_TRADE_UNKNOWN_ERROR = -1,              // Unknown error occurred
   ERR_TRADE_INVALID_PARAMETER = -2,          // Invalid parameter passed
   ERR_TRADE_NOT_INITIALIZED = -3,            // Trade executor not initialized
   ERR_TRADE_DISABLED = -4,                   // Trading is disabled
   ERR_TRADE_INVALID_SYMBOL = -5,             // Invalid symbol
   ERR_TRADE_INVALID_VOLUME = -6,             // Invalid trade volume
   ERR_TRADE_INVALID_PRICE = -7,              // Invalid price
   ERR_TRADE_INVALID_STOPS = -8,              // Invalid stop loss/take profit
   ERR_TRADE_INSUFFICIENT_FUNDS = -9,         // Not enough money
   ERR_TRADE_MARKET_CLOSED = -10,             // Market is closed
   ERR_TRADE_TOO_MANY_REQUESTS = -11,         // Too many trade requests
   ERR_TRADE_TIMEOUT = -12,                   // Trade operation timed out
   ERR_TRADE_SPREAD_TOO_WIDE = -13,           // Spread is too wide
   ERR_TRADE_POSITION_NOT_FOUND = -14,        // Position not found
   ERR_TRADE_ORDER_NOT_FOUND = -15,           // Order not found
   ERR_TRADE_CONNECTION_LOST = -16,           // Connection to trade server lost
   ERR_TRADE_SERVER_BUSY = -17,               // Trade server is busy
   ERR_TRADE_CONTEXT_BUSY = -18,              // Trade context is busy
   ERR_TRADE_TOO_FREQUENT = -19,              // Too frequent trading
   ERR_TRADE_LIMIT_REACHED = -20              // Trade limit reached
};

//+------------------------------------------------------------------+
//| Trade Execution Constants                                        |
//+------------------------------------------------------------------+
#define MAX_ORDER_RETRIES           3       // Maximum number of order retry attempts
#define RETRY_DELAY_MS              1000    // Delay between retries in milliseconds
#define MAX_SLIPPAGE_PIPS           10.0    // Maximum allowed slippage in pips
#define MIN_VOLUME                  0.01    // Minimum trade volume
#define MAX_VOLUME                  100.0   // Maximum trade volume
#define DEFAULT_TRADE_TIMEOUT_MS    5000    // Default trade operation timeout
#define MAX_TRADE_ATTEMPTS          3       // Maximum trade attempts
#define MIN_SECONDS_BETWEEN_TRADES  1       // Minimum seconds between trades
#define MAX_DAILY_TRADES            100     // Maximum trades per day
#define MAX_OPEN_TRADES             10      // Maximum open trades
#define MAX_SPREAD_PIPS             30.0    // Maximum allowed spread in pips
#define MAX_CONSECUTIVE_FAILURES    5       // Maximum consecutive failures before pausing
#define TRADE_RETRY_JITTER_MS       200     // Random jitter for retry delays

// Trade execution states
enum ENUM_TRADE_STATE
{
   TRADE_STATE_IDLE,
   TRADE_STATE_PENDING,
   TRADE_STATE_EXECUTING,
   TRADE_STATE_COMPLETED,
   TRADE_STATE_FAILED
};

//+------------------------------------------------------------------+
//| Trade Executor Class                                             |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Trade Execution Statistics                                        |
//+------------------------------------------------------------------+
struct STradeStats
{
   int               totalTrades;           // Total number of trades executed
   int               successfulTrades;      // Number of successful trades
   int               failedTrades;          // Number of failed trades
   double            totalProfit;           // Total profit in account currency
   double            totalVolume;           // Total volume traded
   datetime          lastTradeTime;          // Time of last trade
   
   // Initialize all members
   void Init()
   {
      totalTrades = 0;
      successfulTrades = 0;
      failedTrades = 0;
      totalProfit = 0.0;
      totalVolume = 0.0;
      lastTradeTime = 0;
   }
};

//+------------------------------------------------------------------+
//| Trade Order Information                                          |
//+------------------------------------------------------------------+
struct STradeOrder
{
   ulong             ticket;                 // Order ticket
   string            symbol;                 // Order symbol
   double            volume;                 // Order volume
   double            price;                  // Open price
   double            sl;                     // Stop loss
   double            tp;                     // Take profit
   string            comment;                // Order comment
   datetime          time;                   // Order time
   ENUM_ORDER_TYPE   type;                   // Order type
   ENUM_TRADE_STATE  state;                  // Current order state
   
   // Initialize order
   void Init()
   {
      ticket = 0;
      symbol = "";
      volume = 0.0;
      price = 0.0;
      sl = 0.0;
      tp = 0.0;
      comment = "";
      time = 0;
      type = WRONG_VALUE;
      state = TRADE_STATE_IDLE;
   }
};

//+------------------------------------------------------------------+
//| Trade Executor Class                                             |
//+------------------------------------------------------------------+
class CTradeExecutor
{
private:
   // Default configuration values
   static const int DEFAULT_MAGIC_NUMBER = 0;            // Default magic number (0 = no filtering)
   static const int DEFAULT_SLIPPAGE = 30;                // Default slippage in points
   static const int DEFAULT_MAX_RETRIES = 3;              // Default max retry attempts
   static const int DEFAULT_RETRY_DELAY_MS = 100;         // Default delay between retries in ms
   static const double DEFAULT_MAX_SPREAD = 20.0;         // Default max spread in points
   static const int DEFAULT_MAX_OPEN_TRADES = 10;         // Default max open trades
   static const int DEFAULT_MAX_DAILY_TRADES = 50;        // Default max trades per day
   
   // Error codes
   static const int ERR_TRADE_DISABLED = 10001;           // Trading is currently disabled
   static const int ERR_TRADE_NOT_INITIALIZED = 10002;    // Trade executor not initialized
   static const int ERR_INVALID_TICKET = 10003;           // Invalid order/position ticket
   static const int ERR_ORDER_NOT_FOUND = 10004;          // Order not found
   static const int ERR_POSITION_NOT_FOUND = 10005;       // Position not found
   static const int ERR_TRADE_WRONG_SYMBOL = 10006;       // Wrong symbol for operation
   static const int ERR_TRADE_INVALID_VOLUME = 10007;     // Invalid trade volume
   static const int ERR_TRADE_INVALID_PRICE = 10008;      // Invalid trade price
   static const int ERR_TRADE_SPREAD_TOO_WIDE = 10009;    // Spread is too wide
   static const int ERR_TRADE_TOO_MANY_ORDERS = 10010;    // Too many open orders
   static const int ERR_TRADE_LIMIT_REACHED = 10011;      // Trade limit reached
   static const int ERR_INVALID_STOPS = 10012;            // Invalid stop levels
   
   // Core trading objects
   CTrade           m_trade;                  // Trade object for order execution
   CRiskManager    *m_riskManager;            // Pointer to risk manager
   CSymbolInfo     *m_symbol;                 // Pointer to symbol info
   CAccountInfo    *m_account;                // Pointer to account info
   CPositionInfo    m_position;               // Position info object
   COrderInfo       m_order;                  // Order info object
   
   // Configuration
   int              m_magicNumber;            // Magic number for order identification
   int              m_slippage;               // Maximum allowed slippage in points
   int              m_maxRetries;             // Maximum number of retry attempts for failed operations
   int              m_retryDelay;             // Delay between retry attempts in milliseconds
   double          m_maxSpread;               // Maximum allowed spread in points
   int             m_maxOpenTrades;           // Maximum number of open trades
   int             m_maxDailyTrades;          // Maximum number of trades per day
   
   // State tracking
   bool            m_isInitialized;           // Flag indicating if the executor is initialized
   bool            m_isTradeAllowed;          // Flag indicating if trading is allowed
   int             m_todayTrades;             // Number of trades executed today
   datetime        m_lastTradeTime;           // Time of the last trade
   int             m_consecutiveFailures;     // Number of consecutive failures
   
   // Thread synchronization
   int             m_mutexHandle;             // Handle for mutex synchronization
   
   // Error handling
   struct ErrorInfo
   {
      int         lastError;                  // Last error code
      string      lastErrorMsg;               // Last error message
      datetime    lastErrorTime;              // Time of the last error
      int         consecutiveErrors;          // Number of consecutive errors
      int         totalErrors;                // Total number of errors
   } m_error;
   
   // Error recovery actions
   enum ENUM_ERROR_ACTION
   {
      ERROR_ACTION_NONE = 0,      // No specific action needed
      ERROR_ACTION_RETRY,         // Operation can be retried
      ERROR_ACTION_WAIT,          // Wait before retrying
      ERROR_ACTION_ABORT,         // Abort the current operation
      ERROR_ACTION_SHUTDOWN       // Critical error, shutdown trading
   };
   
   // Thread synchronization methods
   bool CreateMutex();
   void DestroyMutex();
   bool LockMutex(const int timeout_ms = 1000);
   void UnlockMutex();
   
   // Trade execution helper methods
   bool ExecuteTrade(ENUM_ORDER_TYPE orderType, double lots, double price, double sl, double tp, 
                    datetime expiration = 0, string comment = "", double stopLimit = 0.0);
   bool ExecuteOrderModify(ulong ticket, double price, double sl, double tp, 
                          datetime expiration = 0, string comment = "");
   bool ExecuteOrderDelete(ulong ticket, string comment = "");
   bool ExecutePositionModify(ulong ticket, double sl, double tp, string comment = "");
   
   // Error handling methods
   void SetError(const int errorCode, const string message, const bool isRecoverable = true);
   bool CanRetryAfterError(const int retryCount);
   ENUM_ERROR_ACTION GetErrorAction(const int errorCode) const;
   bool HandleError(const int errorCode, const string context = "");
   void ResetErrorState();
   string GetErrorDescription(const int errorCode) const;
      int           retryDelay;               // Delay between retries in milliseconds
      double        maxSlippagePips;          // Maximum allowed slippage in pips
      double        maxSpread;                // Maximum allowed spread in points
      int           maxOpenTrades;            // Maximum number of open trades
      int           maxDailyTrades;           // Maximum trades per day
   } m_config;
   
   // Symbol information
   struct {
      double        minLot;                   // Minimum lot size
      double        maxLot;                   // Maximum lot size
      double        lotStep;                  // Lot step size
      double        tickSize;                 // Symbol tick size
      double        tickValue;                // Symbol tick value
   } m_symbolInfo;
   
   // Trade tracking
   struct {
      int           todayTrades;              // Trades executed today
      datetime      lastTradeDay;             // Last trade day
      datetime      lastTradeTime;            // Time of last trade execution
   } m_tracking;
   
   // Error handling
   struct {
      int           lastError;                // Last error code
      string        lastErrorMsg;             // Last error message
      string        lastErrorFunc;            // Function where last error occurred
      datetime      lastErrorTime;            // Time of last error
      int           consecutiveFailures;      // Consecutive error count
      int           totalErrors;              // Total error count
   } m_error;
   
   // Private methods
   bool             IsTradeTimeWindow();      // Check if current time is within allowed trading window
   void             UpdateTradeStats(bool success); // Update trade statistics
   bool             CheckLimits();            // Check trade limits
   bool             CheckExecutionConditions(); // Check if execution conditions are met
   void             UpdateErrorInfo();        // Update error information
   
   // Error handling methods
   void             SetError(const int errorCode, const string message, const string funcName = __FUNCTION__);
   bool             IsRecoverableError(const int errorCode) const;
   bool             ShouldRetryAfterError(const int errorCode) const;
   void             HandleRecoverableError(const int errorCode, const string &context);
   void             ResetErrorState();
   string           GetErrorDescription(const int errorCode) const;
   
public:
   // Constructor/Destructor (Rule of Five)
   CTradeExecutor(void);
   ~CTradeExecutor(void);
   
   // Disable copy constructor and copy assignment
   CTradeExecutor(const CTradeExecutor&) = delete;
   CTradeExecutor& operator=(const CTradeExecutor&) = delete;
   
   // Enable move constructor and move assignment
   CTradeExecutor(CTradeExecutor&& other) noexcept;
   CTradeExecutor& operator=(CTradeExecutor&& other) noexcept;
   
   // Initialization and configuration
   bool              Initialize(CSymbolInfo *symbol, CAccountInfo *account, 
                              CRiskManager *riskManager, ulong magicNumber);
   void              Deinitialize();
   bool              IsInitialized() const { return m_isInitialized; }
   
   // Configuration methods
   void              SetMaxSlippage(double slippage) { m_slippage = slippage; }
   void              SetMaxRetries(int retries) { m_maxRetries = max(1, retries); }
   void              SetRetryDelay(int delayMs) { m_retryDelay = max(100, delayMs); }
   void              SetMaxSpread(double spreadPips) { m_maxSpread = spreadPips; }
   void              SetMaxOpenTrades(int maxTrades) { m_maxOpenTrades = max(0, maxTrades); }
   void              SetMaxDailyTrades(int maxTrades) { m_maxDailyTrades = max(0, maxTrades); }
   
   // Status methods
   bool              IsTradeAllowed() const { return m_isTradeAllowed; }
   void              SetTradeAllowed(bool allowed) { m_isTradeAllowed = allowed; }
   int               GetLastError() const { return m_error.lastError; }
   string            GetLastErrorMsg() const { return m_error.lastErrorMsg; }
   string            GetLastErrorContext() const { return m_error.lastErrorFunc; }
   datetime          GetLastErrorTime() const { return m_error.lastErrorTime; }
   int               GetErrorCount() const { return m_error.totalErrors; }
   int               GetConsecutiveErrorCount() const { return m_error.consecutiveFailures; }
   
   // Trade statistics
   STradeStats       GetTradeStats() const { return m_stats; }
   int               GetOpenPositionsCount() const;
   int               GetTodayTradesCount() const;
   double            GetCurrentSpread() const { return m_currentSpread; }
   double            GetAverageSpread() const { return m_avgSpread; }
                    
   // Trade execution methods
   bool              Buy(double lots, double price, double sl = 0.0, double tp = 0.0, string comment = "");
   bool              Sell(double lots, double price, double sl = 0.0, double tp = 0.0, string comment = "");
   bool              BuyLimit(double lots, double price, double sl = 0.0, double tp = 0.0, datetime expiration = 0, string comment = "");
   bool              SellLimit(double lots, double price, double sl = 0.0, double tp = 0.0, datetime expiration = 0, string comment = "");
   bool              BuyStop(double lots, double price, double sl = 0.0, double tp = 0.0, datetime expiration = 0, string comment = "");
   bool              SellStop(double lots, double price, double sl = 0.0, double tp = 0.0, datetime expiration = 0, string comment = "");
   bool              ModifyOrder(ulong ticket, double price, double sl = 0.0, double tp = 0.0, datetime expiration = 0, string comment = "");
   bool              DeleteOrder(ulong ticket, string comment = "");
   bool              DeleteAllOrders(string comment = "");
   bool              ModifyPosition(ulong ticket, double sl = 0.0, double tp = 0.0, string comment = "");
   //+------------------------------------------------------------------+
   //| Execute buy stop order with enhanced error handling              |
   //+------------------------------------------------------------------+
   bool              BuyStop(double lots, double price, double sl = 0.0, double tp = 0.0, datetime expiration = 0, string comment = "")
   {
      // Check if trading is allowed
      if(!m_isTradeAllowed) {
         m_lastError = ERR_TRADE_DISABLED;
         m_lastErrorMsg = "Trading is currently disabled";
         return false;
      }

      // Validate input parameters
      if(!IsVolumeValid(lots)) {
         m_lastError = ERR_INVALID_TRADE_VOLUME;
         m_lastErrorMsg = StringFormat("Invalid lot size: %.2f (min: %.2f, max: %.2f, step: %.2f)",
                                    lots, m_minLot, m_maxLot, m_lotStep);
         return false;
      }
      
      if(!IsPriceValid(price)) {
         m_lastError = ERR_INVALID_PRICE;
         m_lastErrorMsg = StringFormat("Invalid price: %.5f", price);
         return false;
      }
      
      // Check if we've reached the maximum number of pending orders
      if(GetOpenOrdersCount() >= m_maxOpenTrades) {
         m_lastError = ERR_TRADE_TOO_MANY_ORDERS;
         m_lastErrorMsg = StringFormat("Maximum number of pending orders reached: %d", m_maxOpenTrades);
         return false;
      }
      
      // Execute the order with retry logic
      for(int attempt = 1; attempt <= m_maxRetries; attempt++) {
         // Reset error state
         m_lastError = 0;
         m_lastErrorMsg = "";
         
         // Execute the trade
         bool success = m_trade.BuyStop(lots, price, m_symbol.Name(), sl, tp, 
                                      ORDER_TIME_SPECIFIED, expiration, comment);
         
         // If successful, return true
         if(success) {
            m_todayTrades++;
            m_lastTradeTime = TimeCurrent();
            m_consecutiveFailures = 0;
            
            PrintFormat("Buy stop order placed: %s %.2f lots at %.5f, SL: %.5f, TP: %.5f, Ticket: %I64d",
                      m_symbol.Name(), lots, price, sl, tp, m_trade.ResultOrder());
            
            return true;
         }
         
         // If we get here, the order failed
         int errorCode = GetLastError();
         m_lastError = errorCode;
         m_lastErrorMsg = "Buy stop order failed: " + ErrorDescription(errorCode);
         m_consecutiveFailures++;
         
         // Log the failed attempt
         PrintFormat("Buy stop order attempt %d/%d failed: %s (Error %d: %s)",
                   attempt, m_maxRetries, m_symbol.Name(), 
                   errorCode, m_lastErrorMsg);
         
         // If error is not recoverable, stop retrying
         if(!IsRecoverableError(errorCode)) {
            break;
         }
         
         // Wait before retry (exponential backoff)
         int delay = m_retryDelay * (1 << (attempt - 1));
         Sleep(delay);
      }
      
      // If we get here, all retry attempts failed
      PrintFormat("Failed to place buy stop order after %d attempts. Last error: %d - %s",
                m_maxRetries, m_lastError, m_lastErrorMsg);
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Execute sell stop order with enhanced error handling             |
   //+------------------------------------------------------------------+
   bool              SellStop(double lots, double price, double sl = 0.0, double tp = 0.0, datetime expiration = 0, string comment = "")
   {
      // Check if trading is allowed
      if(!m_isTradeAllowed) {
         m_lastError = ERR_TRADE_DISABLED;
         m_lastErrorMsg = "Trading is currently disabled";
         return false;
      }

      // Validate input parameters
      if(!IsVolumeValid(lots)) {
         m_lastError = ERR_INVALID_TRADE_VOLUME;
         m_lastErrorMsg = StringFormat("Invalid lot size: %.2f (min: %.2f, max: %.2f, step: %.2f)",
                                    lots, m_minLot, m_maxLot, m_lotStep);
         return false;
      }
      
      if(!IsPriceValid(price)) {
         m_lastError = ERR_INVALID_PRICE;
         m_lastErrorMsg = StringFormat("Invalid price: %.5f", price);
         return false;
      }
      
      // Check if we've reached the maximum number of pending orders
      if(GetOpenOrdersCount() >= m_maxOpenTrades) {
         m_lastError = ERR_TRADE_TOO_MANY_ORDERS;
         m_lastErrorMsg = StringFormat("Maximum number of pending orders reached: %d", m_maxOpenTrades);
         return false;
      }
      
      // Execute the order with retry logic
      for(int attempt = 1; attempt <= m_maxRetries; attempt++) {
         // Reset error state
         m_lastError = 0;
         m_lastErrorMsg = "";
         
         // Execute the trade
         bool success = m_trade.SellStop(lots, price, m_symbol.Name(), sl, tp, 
                                       ORDER_TIME_SPECIFIED, expiration, comment);
         
         // If successful, return true
         if(success) {
            m_todayTrades++;
            m_lastTradeTime = TimeCurrent();
            m_consecutiveFailures = 0;
            
            PrintFormat("Sell stop order placed: %s %.2f lots at %.5f, SL: %.5f, TP: %.5f, Ticket: %I64d",
                      m_symbol.Name(), lots, price, sl, tp, m_trade.ResultOrder());
            
            return true;
         }
         
         // If we get here, the order failed
         int errorCode = GetLastError();
         m_lastError = errorCode;
         m_lastErrorMsg = "Sell stop order failed: " + ErrorDescription(errorCode);
         m_consecutiveFailures++;
         
         // Log the failed attempt
         PrintFormat("Sell stop order attempt %d/%d failed: %s (Error %d: %s)",
                   attempt, m_maxRetries, m_symbol.Name(), 
                   errorCode, m_lastErrorMsg);
         
         // If error is not recoverable, stop retrying
         if(!IsRecoverableError(errorCode)) {
            break;
         }
         
         // Wait before retry (exponential backoff)
         int delay = m_retryDelay * (1 << (attempt - 1));
         Sleep(delay);
      }
      
      // If we get here, all retry attempts failed
      PrintFormat("Failed to place sell stop order after %d attempts. Last error: %d - %s",
                m_maxRetries, m_lastError, m_lastErrorMsg);
      
      return false;
   }
   
   // Position management
   //+------------------------------------------------------------------+
   //| Close specified position with enhanced error handling            |
   //+------------------------------------------------------------------+
   bool              ClosePosition(ulong ticket, double lots = 0, string comment = "")
   {
      if(!m_isTradeAllowed) {
         m_lastError = ERR_TRADE_DISABLED;
         m_lastErrorMsg = "Trading is currently disabled";
         return false;
      }

      // Validate ticket
      if(ticket <= 0) {
         m_lastError = ERR_INVALID_TICKET;
         m_lastErrorMsg = "Invalid position ticket: " + IntegerToString(ticket);
         return false;
      }

      // Select the position by ticket
      if(!m_position.SelectByTicket(ticket)) {
         m_lastError = ERR_TRADE_POSITION_NOT_FOUND;
         m_lastErrorMsg = "Position not found with ticket: " + IntegerToString(ticket);
         return false;
      }

      // Validate symbol matches
      if(m_position.Symbol() != m_symbol.Name()) {
         m_lastError = ERR_TRADE_WRONG_SYMBOL;
         m_lastErrorMsg = "Position symbol " + m_position.Symbol() + " does not match " + m_symbol.Name();
         return false;
      }

      // If lots is 0, close the entire position, otherwise validate partial close
      double closeLots = (lots <= 0) ? m_position.Volume() : lots;
      if(closeLots <= 0 || closeLots > m_position.Volume()) {
         m_lastError = ERR_INVALID_TRADE_VOLUME;
         m_lastErrorMsg = StringFormat("Invalid close volume: %.2f (position volume: %.2f)", 
                                     closeLots, m_position.Volume());
         return false;
      }

      // Execute the close with retry logic
      for(int attempt = 1; attempt <= m_maxRetries; attempt++) {
         // Reset error state
         m_lastError = 0;
         m_lastErrorMsg = "";
         
         // Execute the close
         bool success = m_trade.PositionClose(ticket, (ulong)m_slippage, comment);
         
         // If successful, return true
         if(success) {
            PrintFormat("Position %I64u closed successfully: %s %.2f lots",
                      ticket, m_symbol.Name(), closeLots);
            return true;
         }
         
         // If we get here, the close failed
         int errorCode = GetLastError();
         m_lastError = errorCode;
         m_lastErrorMsg = "Position close failed: " + ErrorDescription(errorCode);
         
         // Log the failed attempt
         PrintFormat("Close position attempt %d/%d failed: %s (Error %d: %s)",
                   attempt, m_maxRetries, m_symbol.Name(), 
                   errorCode, m_lastErrorMsg);
         
         // If error is not recoverable, stop retrying
         if(!IsRecoverableError(errorCode)) {
            break;
         }
         
         // Wait before retry (exponential backoff)
         int delay = m_retryDelay * (1 << (attempt - 1));
         Sleep(delay);
      }
      
      // If we get here, all retry attempts failed
      PrintFormat("Failed to close position %I64u after %d attempts. Last error: %d - %s",
                ticket, m_maxRetries, m_lastError, m_lastErrorMsg);
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Close all open positions                                        |
   //+------------------------------------------------------------------+
   bool              CloseAllPositions(string comment = "")
   {
      if(!m_isTradeAllowed) {
         m_lastError = ERR_TRADE_DISABLED;
         m_lastErrorMsg = "Trading is currently disabled";
         return false;
      }

      bool result = true;
      int totalPositions = PositionsTotal();
      
      // Create array to store position tickets
      ulong tickets[];
      ArrayResize(tickets, totalPositions);
      int count = 0;
      
      // First, collect all position tickets
      for(int i = totalPositions - 1; i >= 0; i--) {
         if(m_position.SelectByIndex(i)) {
            if(m_position.Symbol() == m_symbol.Name() && 
               (m_magicNumber == 0 || m_position.Magic() == m_magicNumber)) {
               tickets[count++] = m_position.Ticket();
            }
         }
      }
      
      // Now close all collected positions
      for(int i = 0; i < count; i++) {
         if(!ClosePosition(tickets[i], 0, comment)) {
            PrintFormat("Failed to close position %I64u: %s", 
                       tickets[i], m_lastErrorMsg);
            result = false;
         }
      }
      
      return result;
   }
   
   //+------------------------------------------------------------------+
   //| Close positions by type                                         |
   //+------------------------------------------------------------------+
   bool              ClosePositionsByType(ENUM_POSITION_TYPE type, string comment = "")
   {
      if(!m_isTradeAllowed) {
         m_lastError = ERR_TRADE_DISABLED;
         m_lastErrorMsg = "Trading is currently disabled";
         return false;
      }

      bool result = true;
      int totalPositions = PositionsTotal();
      
      // Create array to store position tickets
      ulong tickets[];
      ArrayResize(tickets, totalPositions);
      int count = 0;
      
      // First, collect all matching position tickets
      for(int i = totalPositions - 1; i >= 0; i--) {
         if(m_position.SelectByIndex(i)) {
            if(m_position.Symbol() == m_symbol.Name() && 
               m_position.PositionType() == type &&
               (m_magicNumber == 0 || m_position.Magic() == m_magicNumber)) {
               tickets[count++] = m_position.Ticket();
            }
         }
      }
      
      // Now close all collected positions
      for(int i = 0; i < count; i++) {
         if(!ClosePosition(tickets[i], 0, comment)) {
            PrintFormat("Failed to close position %I64u: %s", 
                       tickets[i], m_lastErrorMsg);
            result = false;
         }
      }
      
      return result;
   }
   
   //+------------------------------------------------------------------+
   //| Modify position stop loss and take profit                        |
   //+------------------------------------------------------------------+
   bool              ModifyPosition(ulong ticket, double sl, double tp, string comment = "")
   {
      if(!m_isTradeAllowed) {
         m_lastError = ERR_TRADE_DISABLED;
         m_lastErrorMsg = "Trading is currently disabled";
         return false;
      }

      // Validate ticket
      if(ticket <= 0) {
         m_lastError = ERR_INVALID_TICKET;
         m_lastErrorMsg = "Invalid position ticket: " + IntegerToString(ticket);
         return false;
      }

      // Select the position by ticket
      if(!m_position.SelectByTicket(ticket)) {
         m_lastError = ERR_TRADE_POSITION_NOT_FOUND;
         m_lastErrorMsg = "Position not found with ticket: " + IntegerToString(ticket);
         return false;
      }

      // Validate symbol matches
      if(m_position.Symbol() != m_symbol.Name()) {
         m_lastError = ERR_TRADE_WRONG_SYMBOL;
         m_lastErrorMsg = "Position symbol " + m_position.Symbol() + " does not match " + m_symbol.Name();
         return false;
      }

      // Get current position details
      double openPrice = m_position.PriceOpen();
      double currentSl = m_position.StopLoss();
      double currentTp = m_position.TakeProfit();
      
      // If SL/TP values haven't changed, no need to modify
      if(MathAbs(sl - currentSl) < Point() && MathAbs(tp - currentTp) < Point()) {
         PrintFormat("No changes needed for position %I64u - SL/TP already at requested levels", ticket);
         return true;
      }

      // Execute the modification with retry logic
      for(int attempt = 1; attempt <= m_maxRetries; attempt++) {
         // Reset error state
         m_lastError = 0;
         m_lastErrorMsg = "";
         
         // Execute the modification
         bool success = m_trade.PositionModify(ticket, sl, tp);
         
         // If successful, return true
         if(success) {
            PrintFormat("Position %I64u modified successfully: SL=%.5f, TP=%.5f",
                      ticket, sl, tp);
            return true;
         }
         
         // If we get here, the modification failed
         int errorCode = GetLastError();
         m_lastError = errorCode;
         m_lastErrorMsg = "Position modify failed: " + ErrorDescription(errorCode);
         
         // Log the failed attempt
         PrintFormat("Modify position attempt %d/%d failed: %s (Error %d: %s)",
                   attempt, m_maxRetries, m_symbol.Name(), 
                   errorCode, m_lastErrorMsg);
         
         // If error is not recoverable, stop retrying
         if(!IsRecoverableError(errorCode)) {
            break;
         }
         
         // Wait before retry (exponential backoff)
         int delay = m_retryDelay * (1 << (attempt - 1));
         Sleep(delay);
      }
      
      // If we get here, all retry attempts failed
      PrintFormat("Failed to modify position %I64u after %d attempts. Last error: %d - %s",
                ticket, m_maxRetries, m_lastError, m_lastErrorMsg);
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Modify all open positions' stop loss and take profit            |
   //+------------------------------------------------------------------+
   bool              ModifyAllPositions(double sl, double tp, string comment = "")
   {
      if(!m_isTradeAllowed) {
         m_lastError = ERR_TRADE_DISABLED;
         m_lastErrorMsg = "Trading is currently disabled";
         return false;
      }

      bool result = true;
      int totalPositions = PositionsTotal();
      
      // Create array to store position tickets
      ulong tickets[];
      ArrayResize(tickets, totalPositions);
      int count = 0;
      
      // First, collect all position tickets
      for(int i = totalPositions - 1; i >= 0; i--) {
         if(m_position.SelectByIndex(i)) {
            if(m_position.Symbol() == m_symbol.Name() && 
               (m_magicNumber == 0 || m_position.Magic() == m_magicNumber)) {
               tickets[count++] = m_position.Ticket();
            }
         }
      }
      
      // Now modify all collected positions
      for(int i = 0; i < count; i++) {
         if(!ModifyPosition(tickets[i], sl, tp, comment)) {
            PrintFormat("Failed to modify position %I64u: %s", 
                       tickets[i], m_lastErrorMsg);
            result = false;
         }
      }
      
      return result;
   }
   
   // Order management
   //+------------------------------------------------------------------+
   //| Modify pending order with enhanced error handling                |
   //+------------------------------------------------------------------+
   bool              ModifyOrder(ulong ticket, double price, double sl = 0.0, double tp = 0.0, 
                               datetime expiration = 0, string comment = "")
   {
      if(!m_isTradeAllowed) {
         m_lastError = ERR_TRADE_DISABLED;
         m_lastErrorMsg = "Trading is currently disabled";
         return false;
      }

      // Validate ticket
      if(ticket <= 0) {
         m_lastError = ERR_INVALID_TICKET;
         m_lastErrorMsg = "Invalid order ticket: " + IntegerToString(ticket);
         return false;
      }

      // Select the order by ticket
      COrderInfo order;
      if(!order.Select(ticket)) {
         m_lastError = ERR_ORDER_NOT_FOUND;
         m_lastErrorMsg = "Order not found with ticket: " + IntegerToString(ticket);
         return false;
      }

      // Validate symbol matches
      if(order.Symbol() != m_symbol.Name()) {
         m_lastError = ERR_TRADE_WRONG_SYMBOL;
         m_lastErrorMsg = "Order symbol " + order.Symbol() + " does not match " + m_symbol.Name();
         return false;
      }

      // Get current order details
      double currentPrice = order.PriceOpen();
      double currentSl = order.StopLoss();
      double currentTp = order.TakeProfit();
      datetime currentExpiration = order.TimeExpiration();
      
      // If no changes are needed, return success
      if(MathAbs(price - currentPrice) < Point() && 
         MathAbs(sl - currentSl) < Point() && 
         MathAbs(tp - currentTp) < Point() &&
         expiration == currentExpiration) {
         PrintFormat("No changes needed for order %I64u - already at requested levels", ticket);
         return true;
      }

      // Execute the modification with retry logic
      for(int attempt = 1; attempt <= m_maxRetries; attempt++) {
         // Reset error state
         m_lastError = 0;
         m_lastErrorMsg = "";
         
         // Execute the modification
         bool success = m_trade.OrderModify(ticket, price, sl, tp, expiration, 0, 0);
         
         // If successful, return true
         if(success) {
            PrintFormat("Order %I64u modified successfully: Price=%.5f, SL=%.5f, TP=%.5f, Expiration=%s",
                      ticket, price, sl, tp, TimeToString(expiration));
            return true;
         }
         
         // If we get here, the modification failed
         int errorCode = GetLastError();
         m_lastError = errorCode;
         m_lastErrorMsg = "Order modify failed: " + ErrorDescription(errorCode);
         
         // Log the failed attempt
         PrintFormat("Modify order attempt %d/%d failed: %s (Error %d: %s)",
                   attempt, m_maxRetries, m_symbol.Name(), 
                   errorCode, m_lastErrorMsg);
         
         // If error is not recoverable, stop retrying
         if(!IsRecoverableError(errorCode)) {
            break;
         }
         
         // Wait before retry (exponential backoff)
         int delay = m_retryDelay * (1 << (attempt - 1));
         Sleep(delay);
      }
      
      // If we get here, all retry attempts failed
      PrintFormat("Failed to modify order %I64u after %d attempts. Last error: %d - %s",
                ticket, m_maxRetries, m_lastError, m_lastErrorMsg);
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Delete pending order with enhanced error handling               |
   //+------------------------------------------------------------------+
   bool              DeleteOrder(ulong ticket, string comment = "")
   {
      if(!m_isTradeAllowed) {
         m_lastError = ERR_TRADE_DISABLED;
         m_lastErrorMsg = "Trading is currently disabled";
         return false;
      }

      // Validate ticket
      if(ticket <= 0) {
         m_lastError = ERR_INVALID_TICKET;
         m_lastErrorMsg = "Invalid order ticket: " + IntegerToString(ticket);
         return false;
      }

      // Select the order by ticket
      COrderInfo order;
      if(!order.Select(ticket)) {
         // If order is already deleted, consider it a success
         if(GetLastError() == ERR_INVALID_TICKET) {
            PrintFormat("Order %I64u already deleted or does not exist", ticket);
            return true;
         }
         m_lastError = ERR_ORDER_NOT_FOUND;
         m_lastErrorMsg = "Order not found with ticket: " + IntegerToString(ticket);
         return false;
      }

      // Validate symbol matches
      if(order.Symbol() != m_symbol.Name()) {
         m_lastError = ERR_TRADE_WRONG_SYMBOL;
         m_lastErrorMsg = "Order symbol " + order.Symbol() + " does not match " + m_symbol.Name();
         return false;
      }

      // Execute the deletion with retry logic
      for(int attempt = 1; attempt <= m_maxRetries; attempt++) {
         // Reset error state
         m_lastError = 0;
         m_lastErrorMsg = "";
         
         // Execute the deletion
         bool success = m_trade.OrderDelete(ticket);
         
         // If successful, return true
         if(success) {
            PrintFormat("Order %I64u deleted successfully", ticket);
            return true;
         }
         
         // If order is already deleted, consider it a success
         if(GetLastError() == ERR_INVALID_TICKET) {
            PrintFormat("Order %I64u already deleted", ticket);
            return true;
         }
         
         // If we get here, the deletion failed
         int errorCode = GetLastError();
         m_lastError = errorCode;
         m_lastErrorMsg = "Order delete failed: " + ErrorDescription(errorCode);
         
         // Log the failed attempt
         PrintFormat("Delete order attempt %d/%d failed: %s (Error %d: %s)",
                   attempt, m_maxRetries, m_symbol.Name(), 
                   errorCode, m_lastErrorMsg);
         
         // If error is not recoverable, stop retrying
         if(!IsRecoverableError(errorCode)) {
            break;
         }
         
         // Wait before retry (exponential backoff)
         int delay = m_retryDelay * (1 << (attempt - 1));
         Sleep(delay);
      }
      
      // If we get here, all retry attempts failed
      PrintFormat("Failed to delete order %I64u after %d attempts. Last error: %d - %s",
                ticket, m_maxRetries, m_lastError, m_lastErrorMsg);
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Delete all pending orders                                       |
   //+------------------------------------------------------------------+
   bool              DeleteAllOrders(string comment = "")
   {
      if(!m_isTradeAllowed) {
         m_lastError = ERR_TRADE_DISABLED;
         m_lastErrorMsg = "Trading is currently disabled";
         return false;
      }

      bool result = true;
      int totalOrders = OrdersTotal();
      
      // Create array to store order tickets
      ulong tickets[];
      ArrayResize(tickets, totalOrders);
      int count = 0;
      
      // First, collect all order tickets
      for(int i = totalOrders - 1; i >= 0; i--) {
         if(m_order.SelectByIndex(i)) {
            if(m_order.Symbol() == m_symbol.Name() && 
               (m_magicNumber == 0 || m_order.Magic() == m_magicNumber)) {
               tickets[count++] = m_order.Ticket();
            }
         }
      }
      
      // Now delete all collected orders
      for(int i = 0; i < count; i++) {
         if(!DeleteOrder(tickets[i], comment)) {
            PrintFormat("Failed to delete order %I64u: %s", 
                       tickets[i], m_lastErrorMsg);
            result = false;
         }
      }
      
      return result;
   }
   
   // Rule of Five: Copy constructor, move constructor, copy assignment, move assignment, destructor
   CTradeExecutor(const CTradeExecutor&) = delete;                 // Disable copy constructor
   CTradeExecutor(CTradeExecutor&&) = delete;                      // Disable move constructor
   CTradeExecutor& operator=(const CTradeExecutor&) = delete;      // Disable copy assignment
   CTradeExecutor& operator=(CTradeExecutor&&) = delete;           // Disable move assignment
   ~CTradeExecutor();                                              // Destructor already declared
};

//+------------------------------------------------------------------+
//| Trading Constants                                               |
//+------------------------------------------------------------------+
// Default trading parameters
#define DEFAULT_SLIPPAGE_POINTS      10.0     // Default slippage in points
#define DEFAULT_MAGIC_NUMBER         0        // Default magic number (0 = not set)
#define DEFAULT_MAX_RETRIES          3        // Default number of retry attempts
#define DEFAULT_RETRY_DELAY_MS       1000     // 1 second delay between retries
#define DEFAULT_MAX_SLIPPAGE_PIPS    5.0      // 5 pips max slippage
#define DEFAULT_MAX_SPREAD_POINTS    30.0     // 30 points max spread
#define DEFAULT_MAX_OPEN_TRADES      10       // Max 10 open trades
#define DEFAULT_MAX_DAILY_TRADES     20       // Max 20 trades per day
#define DEFAULT_MIN_LOT              0.01     // Minimum lot size
#define DEFAULT_MAX_LOT              100.0    // Maximum lot size
#define DEFAULT_LOT_STEP            0.01      // Lot size step

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTradeExecutor::CTradeExecutor(void) : 
      m_riskManager(NULL),
      m_symbol(NULL),
      m_account(NULL),
      m_mutexHandle(INVALID_HANDLE),
      m_magicNumber(DEFAULT_MAGIC_NUMBER),
      m_slippage(DEFAULT_SLIPPAGE_POINTS),
      m_maxRetries(DEFAULT_MAX_RETRIES),
      m_retryDelay(DEFAULT_RETRY_DELAY_MS),
      m_maxSpread(DEFAULT_MAX_SPREAD_POINTS),
      m_maxOpenTrades(DEFAULT_MAX_OPEN_TRADES),
      m_maxDailyTrades(DEFAULT_MAX_DAILY_TRADES),
      m_isInitialized(false),
      m_isTradeAllowed(false),
      m_todayTrades(0),
      m_lastTradeTime(0),
      m_consecutiveFailures(0) 
{
   // Initialize performance metrics with zeros
   ZeroMemory(m_performance);
   
   // Initialize trade configuration with enhanced defaults
   m_config.slippage = DEFAULT_SLIPPAGE_POINTS;
   m_config.magicNumber = DEFAULT_MAGIC_NUMBER;
   m_config.maxRetries = DEFAULT_MAX_RETRIES;
   m_config.retryDelay = DEFAULT_RETRY_DELAY_MS;
   m_config.maxSlippagePips = DEFAULT_MAX_SLIPPAGE_PIPS;
   m_config.maxSpread = DEFAULT_MAX_SPREAD_POINTS;
   m_config.maxOpenTrades = DEFAULT_MAX_OPEN_TRADES;
   m_config.maxDailyTrades = DEFAULT_MAX_DAILY_TRADES;
   
   // Initialize symbol information (will be set in Initialize())
   m_symbolInfo.minLot = DEFAULT_MIN_LOT;
   m_symbolInfo.maxLot = DEFAULT_MAX_LOT;
   m_symbolInfo.lotStep = DEFAULT_LOT_STEP;
   m_symbolInfo.tickSize = 0.0;
   m_symbolInfo.tickValue = 0.0;
   
   // Initialize trade tracking
   m_tracking.todayTrades = 0;
   m_tracking.lastTradeDay = 0;
   m_tracking.lastTradeTime = TimeCurrent();
   
   // Initialize error handling
   m_error.lastError = 0;
   m_error.lastErrorMsg = "";
   
   // Set up the trade object
   m_trade.SetDeviationInPoints((ulong)m_config.slippage);
   m_trade.SetTypeFilling(ORDER_FILLING_RETURN);
   m_trade.SetExpertMagicNumber(m_config.magicNumber);
   m_trade.SetAsyncMode(true);  // Enable asynchronous execution
   m_trade.LogLevel(LOG_LEVEL_ALL);  // Log all trade operations
   
   // Initialize statistics
   m_stats.Init();
   m_currentOrder.Init();
}

//+------------------------------------------------------------------+
//| Create a mutex for thread synchronization                        |
//+------------------------------------------------------------------+
bool CTradeExecutor::CreateMutex()
{
   // Generate a unique name for the mutex based on the EA name and account number
   string mutexName = StringFormat("MTX_%s_%d_%d", MQLInfoString(MQL_PROGRAM_NAME), AccountInfoInteger(ACCOUNT_LOGIN), TimeCurrent());
   
   // Create a mutex with a unique name
   m_mutexHandle = CreateMutex(mutexName, false);
   if(m_mutexHandle == INVALID_HANDLE)
   {
      Print("Failed to create mutex: ", GetLastError());
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Destroy the mutex                                                |
//+------------------------------------------------------------------+
void CTradeExecutor::DestroyMutex()
{
   if(m_mutexHandle != INVALID_HANDLE)
   {
      ReleaseMutex(m_mutexHandle);
      CloseHandle(m_mutexHandle);
      m_mutexHandle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Lock the mutex with a timeout                                    |
//+------------------------------------------------------------------+
bool CTradeExecutor::LockMutex(const int timeout_ms)
{
   if(m_mutexHandle == INVALID_HANDLE)
   {
      if(!CreateMutex())
         return false;
   }
   
   // Try to acquire the mutex with the specified timeout
   const int startTime = GetTickCount();
   while(GetTickCount() - startTime < timeout_ms)
   {
      if(WaitForSingleObject(m_mutexHandle, 0) == WAIT_OBJECT_0)
         return true;
         
      Sleep(10); // Small delay to prevent CPU overuse
   }
   
   Print("Failed to acquire mutex: timeout");
   return false;
}

//+------------------------------------------------------------------+
//| Unlock the mutex                                                 |
//+------------------------------------------------------------------+
void CTradeExecutor::UnlockMutex()
{
   if(m_mutexHandle != INVALID_HANDLE)
   {
      ReleaseMutex(m_mutexHandle);
   }
}

//+------------------------------------------------------------------+
//| Execute a trade with the specified parameters                    |
//+------------------------------------------------------------------+
bool CTradeExecutor::ExecuteTrade(ENUM_ORDER_TYPE orderType, double lots, double price, 
                                double sl, double tp, datetime expiration, 
                                string comment, double stopLimit)
{
   // Validate input parameters
   if(lots <= 0) {
      SetError(ERR_INVALID_PARAMETER, "Invalid lot size: " + DoubleToString(lots), false);
      return false;
   }
   
   if(price <= 0) {
      SetError(ERR_INVALID_PRICE, "Invalid price: " + DoubleToString(price), false);
      return false;
   }
   
   // Ensure we're initialized
   if(!m_isInitialized) {
      SetError(ERR_TRADE_NOT_INITIALIZED, "Trade executor not initialized", false);
      return false;
   }
   
   // Check if trading is allowed
   if(!m_isTradeAllowed) {
      SetError(ERR_TRADE_DISABLED, "Trading is currently disabled", false);
      return false;
   }
   
   // Lock the mutex for thread safety
   if(!LockMutex()) {
      SetError(ERR_TRADE_CONTEXT_BUSY, "Failed to acquire mutex for trading", true);
      return false;
   }
   
   // Execute the trade with retry logic
   bool result = false;
   int attempt = 0;
   
   while(attempt < m_maxRetries) {
      attempt++;
      
      // Reset trade result
      m_trade.ResultReset();
      
      // Execute the appropriate trade type
      bool success = false;
      switch(orderType) {
         case ORDER_TYPE_BUY:
            success = m_trade.Buy(lots, m_symbol.Name(), price, sl, tp, comment);
            break;
            
         case ORDER_TYPE_SELL:
            success = m_trade.Sell(lots, m_symbol.Name(), price, sl, tp, comment);
            break;
            
         case ORDER_TYPE_BUY_LIMIT:
            success = m_trade.BuyLimit(lots, price, m_symbol.Name(), sl, tp, 
                                     (expiration > 0) ? ORDER_TIME_SPECIFIED : ORDER_TIME_GTC, 
                                     expiration, comment);
            break;
            
         case ORDER_TYPE_SELL_LIMIT:
            success = m_trade.SellLimit(lots, price, m_symbol.Name(), sl, tp, 
                                      (expiration > 0) ? ORDER_TIME_SPECIFIED : ORDER_TIME_GTC, 
                                      expiration, comment);
            break;
            
         case ORDER_TYPE_BUY_STOP:
            success = m_trade.BuyStop(lots, price, m_symbol.Name(), sl, tp, 
                                    (expiration > 0) ? ORDER_TIME_SPECIFIED : ORDER_TIME_GTC, 
                                    expiration, comment);
            break;
            
         case ORDER_TYPE_SELL_STOP:
            success = m_trade.SellStop(lots, price, m_symbol.Name(), sl, tp, 
                                     (expiration > 0) ? ORDER_TIME_SPECIFIED : ORDER_TIME_GTC, 
                                     expiration, comment);
            break;
            
         case ORDER_TYPE_BUY_STOP_LIMIT:
            success = m_trade.BuyStopLimit(lots, stopLimit, price, m_symbol.Name(), sl, tp, 
                                         (expiration > 0) ? ORDER_TIME_SPECIFIED : ORDER_TIME_GTC, 
                                         expiration, comment);
            break;
            
         case ORDER_TYPE_SELL_STOP_LIMIT:
            success = m_trade.SellStopLimit(lots, stopLimit, price, m_symbol.Name(), sl, tp, 
                                          (expiration > 0) ? ORDER_TIME_SPECIFIED : ORDER_TIME_GTC, 
                                          expiration, comment);
            break;
            
         default:
            SetError(ERR_INVALID_PARAMETER, "Unsupported order type: " + IntegerToString(orderType), false);
            UnlockMutex();
            return false;
      }
      
      // Check if the trade was executed successfully
      if(success && m_trade.ResultRetcode() == TRADE_RETCODE_DONE) {
         // Update trade statistics
         m_todayTrades++;
         m_lastTradeTime = TimeCurrent();
         m_stats.successfulTrades++;
         m_stats.totalTrades++;
         ResetErrorState();
         
         // Log successful execution
         string orderTypeStr = OrderTypeToString(orderType);
         PrintFormat("%s order executed: %s %.2f lots at %.5f, SL: %.5f, TP: %.5f, Ticket: %I64d",
                   orderTypeStr, m_symbol.Name(), lots, price, sl, tp, m_trade.ResultOrder());
         
         result = true;
         break;
      }
      
      // Get the error code and message
      int errorCode = m_trade.ResultRetcode();
      string errorMsg = m_trade.ResultRetcodeDescription();
      
      // If no error from trade object, check for system error
      if(errorCode == 0) {
         errorCode = GetLastError();
         errorMsg = ErrorDescription(errorCode);
      }
      
      // Log the failed attempt
      SetError(errorCode, 
               StringFormat("%s order attempt %d/%d failed: %s", 
                           OrderTypeToString(orderType), 
                           attempt, m_maxRetries, errorMsg));
      
      // Check if we should retry
      if(!CanRetryAfterError(attempt) || !IsRecoverableError(errorCode)) {
         break;
      }
      
      // Wait before retry (exponential backoff)
      int delay = m_retryDelay * (1 << (attempt - 1));
      Sleep(delay);
   }
   
   // Unlock the mutex
   UnlockMutex();
   
   return result;
}

//+------------------------------------------------------------------+
//| Modify an existing order with the specified parameters           |
//+------------------------------------------------------------------+
bool CTradeExecutor::ExecuteOrderModify(ulong ticket, double price, double sl, 
                                      double tp, datetime expiration, string comment)
{
   // Validate input parameters
   if(ticket <= 0) {
      SetError(ERR_INVALID_TICKET, "Invalid order ticket: " + IntegerToString(ticket), false);
      return false;
   }
   
   // Ensure we're initialized
   if(!m_isInitialized) {
      SetError(ERR_TRADE_NOT_INITIALIZED, "Trade executor not initialized", false);
      return false;
   }
   
   // Lock the mutex for thread safety
   if(!LockMutex()) {
      SetError(ERR_TRADE_CONTEXT_BUSY, "Failed to acquire mutex for order modification", true);
      return false;
   }
   
   // Execute the order modification with retry logic
   bool result = false;
   int attempt = 0;
   
   while(attempt < m_maxRetries) {
      attempt++;
      
      // Reset trade result
      m_trade.ResultReset();
      
      // Execute the order modification
      bool success = m_trade.OrderModify(ticket, price, sl, tp, 
                                       (expiration > 0) ? ORDER_TIME_SPECIFIED : ORDER_TIME_GTC, 
                                       expiration, comment);
      
      // Check if the modification was successful
      if(success && m_trade.ResultRetcode() == TRADE_RETCODE_DONE) {
         // Log successful modification
         PrintFormat("Order #%I64d modified: New price=%.5f, SL=%.5f, TP=%.5f, Expiration=%s",
                   ticket, price, sl, tp, TimeToString(expiration));
         
         m_stats.successfulModifications++;
         ResetErrorState();
         result = true;
         break;
      }
      
      // Get the error code and message
      int errorCode = m_trade.ResultRetcode();
      string errorMsg = m_trade.ResultRetcodeDescription();
      
      // If no error from trade object, check for system error
      if(errorCode == 0) {
         errorCode = GetLastError();
         errorMsg = ErrorDescription(errorCode);
      }
      
      // Log the failed attempt
      SetError(errorCode, 
               StringFormat("OrderModify #%I64d attempt %d/%d failed: %s", 
                           ticket, attempt, m_maxRetries, errorMsg));
      
      // Check if we should retry
      if(!CanRetryAfterError(attempt) || !IsRecoverableError(errorCode)) {
         break;
      }
      
      // Wait before retry (exponential backoff)
      int delay = m_retryDelay * (1 << (attempt - 1));
      Sleep(delay);
   }
   
   // Unlock the mutex
   UnlockMutex();
   
   return result;
}

//+------------------------------------------------------------------+
//| Delete an existing order                                         |
//+------------------------------------------------------------------+
bool CTradeExecutor::ExecuteOrderDelete(ulong ticket, string comment)
{
   // Validate input parameters
   if(ticket <= 0) {
      SetError(ERR_INVALID_TICKET, "Invalid order ticket: " + IntegerToString(ticket), false);
      return false;
   }
   
   // Ensure we're initialized
   if(!m_isInitialized) {
      SetError(ERR_TRADE_NOT_INITIALIZED, "Trade executor not initialized", false);
      return false;
   }
   
   // Lock the mutex for thread safety
   if(!LockMutex()) {
      SetError(ERR_TRADE_CONTEXT_BUSY, "Failed to acquire mutex for order deletion", true);
      return false;
   }
   
   // Execute the order deletion with retry logic
   bool result = false;
   int attempt = 0;
   
   while(attempt < m_maxRetries) {
      attempt++;
      
      // Reset trade result
      m_trade.ResultReset();
      
      // Execute the order deletion
      bool success = m_trade.OrderDelete(ticket, comment);
      
      // Check if the deletion was successful
      if(success && m_trade.ResultRetcode() == TRADE_RETCODE_DONE) {
         // Log successful deletion
         PrintFormat("Order #%I64d deleted: %s", ticket, comment);
         
         m_stats.successfulDeletions++;
         ResetErrorState();
         result = true;
         break;
      }
      
      // Get the error code and message
      int errorCode = m_trade.ResultRetcode();
      string errorMsg = m_trade.ResultRetcodeDescription();
      
      // If no error from trade object, check for system error
      if(errorCode == 0) {
         errorCode = GetLastError();
         errorMsg = ErrorDescription(errorCode);
      }
      
      // Log the failed attempt
      SetError(errorCode, 
               StringFormat("OrderDelete #%I64d attempt %d/%d failed: %s", 
                           ticket, attempt, m_maxRetries, errorMsg));
      
      // Check if we should retry
      if(!CanRetryAfterError(attempt) || !IsRecoverableError(errorCode)) {
         break;
      }
      
      // Wait before retry (exponential backoff)
      int delay = m_retryDelay * (1 << (attempt - 1));
      Sleep(delay);
   }
   
   // Unlock the mutex
   UnlockMutex();
   
   return result;
}

//+------------------------------------------------------------------+
//| Modify an existing position's stop loss and take profit          |
//+------------------------------------------------------------------+
bool CTradeExecutor::ExecutePositionModify(ulong ticket, double sl, double tp, string comment)
{
   // Validate input parameters
   if(ticket <= 0) {
      SetError(ERR_INVALID_TICKET, "Invalid position ticket: " + IntegerToString(ticket), false);
      return false;
   }
   
   // Ensure we're initialized
   if(!m_isInitialized) {
      SetError(ERR_TRADE_NOT_INITIALIZED, "Trade executor not initialized", false);
      return false;
   }
   
   // Lock the mutex for thread safety
   if(!LockMutex()) {
      SetError(ERR_TRADE_CONTEXT_BUSY, "Failed to acquire mutex for position modification", true);
      return false;
   }
   
   // Execute the position modification with retry logic
   bool result = false;
   int attempt = 0;
   
   while(attempt < m_maxRetries) {
      attempt++;
      
      // Reset trade result
      m_trade.ResultReset();
      
      // Execute the position modification
      bool success = m_trade.PositionModify(ticket, sl, tp, comment);
      
      // Check if the modification was successful
      if(success && m_trade.ResultRetcode() == TRADE_RETCODE_DONE) {
         // Log successful modification
         PrintFormat("Position #%I64d modified: New SL=%.5f, TP=%.5f", ticket, sl, tp);
         
         m_stats.successfulModifications++;
         ResetErrorState();
         result = true;
         break;
      }
      
      // Get the error code and message
      int errorCode = m_trade.ResultRetcode();
      string errorMsg = m_trade.ResultRetcodeDescription();
      
      // If no error from trade object, check for system error
      if(errorCode == 0) {
         errorCode = GetLastError();
         errorMsg = ErrorDescription(errorCode);
      }
      
      // Log the failed attempt
      SetError(errorCode, 
               StringFormat("PositionModify #%I64d attempt %d/%d failed: %s", 
                           ticket, attempt, m_maxRetries, errorMsg));
      
      // Check if we should retry
      if(!CanRetryAfterError(attempt) || !IsRecoverableError(errorCode)) {
         break;
      }
      
      // Wait before retry (exponential backoff)
      int delay = m_retryDelay * (1 << (attempt - 1));
      Sleep(delay);
   }
   
   // Unlock the mutex
   UnlockMutex();
   
   return result;
}

//+------------------------------------------------------------------+
//| Convert order type to string for logging                         |
//+------------------------------------------------------------------+
string CTradeExecutor::OrderTypeToString(ENUM_ORDER_TYPE orderType) const
{
   switch(orderType) {
      case ORDER_TYPE_BUY:            return "Buy";
      case ORDER_TYPE_SELL:           return "Sell";
      case ORDER_TYPE_BUY_LIMIT:      return "Buy Limit";
      case ORDER_TYPE_SELL_LIMIT:     return "Sell Limit";
      case ORDER_TYPE_BUY_STOP:       return "Buy Stop";
      case ORDER_TYPE_SELL_STOP:      return "Sell Stop";
      case ORDER_TYPE_BUY_STOP_LIMIT: return "Buy Stop Limit";
      case ORDER_TYPE_SELL_STOP_LIMIT:return "Sell Stop Limit";
      default:                        return "Unknown(" + IntegerToString(orderType) + ")";
   }
}

//+------------------------------------------------------------------+
//| Set error information and handle error state                     |
//+------------------------------------------------------------------+
void CTradeExecutor::SetError(const int errorCode, const string message, const bool isRecoverable)
{
   m_error.lastError = errorCode;
   m_error.lastErrorMsg = message;
   m_error.lastErrorTime = TimeCurrent();
   m_error.consecutiveErrors++;
   m_error.totalErrors++;
   
   string logMsg = StringFormat("Error %d: %s (Recoverable: %s)", 
                              errorCode, message, isRecoverable ? "Yes" : "No");
   Print(logMsg);
   
   if(!isRecoverable)
   {
      m_isTradeAllowed = false;
      Print("Trading disabled due to critical error");
   }
}

//+------------------------------------------------------------------+
//| Check if we can retry after an error                             |
//+------------------------------------------------------------------+
bool CTradeExecutor::CanRetryAfterError(const int retryCount)
{
   return (retryCount < m_maxRetries && m_error.consecutiveErrors <= m_maxRetries * 2);
}

//+------------------------------------------------------------------+
//| Reset the error state                                            |
//+------------------------------------------------------------------+
void CTradeExecutor::ResetErrorState()
{
   m_error.lastError = 0;
   m_error.lastErrorMsg = "";
   m_error.consecutiveErrors = 0;
}

//+------------------------------------------------------------------+
//| Initialize trade executor                                        |
//+------------------------------------------------------------------+
bool CTradeExecutor::Initialize(CSymbolInfo *symbol, CAccountInfo *account, 
                              CRiskManager *riskManager, ulong magicNumber)
{
   // Check for NULL pointers
   if(symbol == NULL || account == NULL || riskManager == NULL)
   {
      m_error.lastError = ERR_INVALID_PARAMETER;
      m_error.lastErrorMsg = "Invalid parameters in TradeExecutor initialization: " + 
                      (symbol == NULL ? "symbol is NULL, " : "") +
                      (account == NULL ? "account is NULL, " : "") +
                      (riskManager == NULL ? "riskManager is NULL" : "");
      Print(m_error.lastErrorMsg);
      return false;
   }
   
   // Initialize pointers
   m_symbol = symbol;
   m_account = account;
   m_riskManager = riskManager;
   m_config.magicNumber = magicNumber;
   
   // Initialize trade statistics and current order
   m_stats.Init();
   m_currentOrder.Init();
   
   // Set up trade parameters
   m_trade.SetExpertMagicNumber(m_config.magicNumber);
   m_trade.SetDeviationInPoints((ulong)m_config.slippage);
   m_trade.SetTypeFilling(ORDER_FILLING_RETURN);
   
   // Initialize symbol info
   if(!m_symbol.RefreshRates()) {
      m_error.lastError = GetLastError();
      m_error.lastErrorMsg = "Failed to refresh symbol rates: " + ErrorDescription(m_error.lastError);
      Print(m_error.lastErrorMsg);
      return false;
   }
   
   // Get and validate symbol parameters
   m_symbolInfo.minLot = SymbolInfoDouble(m_symbol.Name(), SYMBOL_VOLUME_MIN);
   m_symbolInfo.maxLot = SymbolInfoDouble(m_symbol.Name(), SYMBOL_VOLUME_MAX);
   m_symbolInfo.lotStep = SymbolInfoDouble(m_symbol.Name(), SYMBOL_VOLUME_STEP);
   m_symbolInfo.tickSize = m_symbol.TickSize();
   m_symbolInfo.tickValue = m_symbol.TickValue();
   
   // Check if symbol parameters are valid
   if(m_symbolInfo.minLot <= 0 || m_symbolInfo.maxLot <= 0 || 
      m_symbolInfo.lotStep <= 0 || m_symbolInfo.tickSize <= 0) {
      m_error.lastError = ERR_INVALID_PARAMETER;
      m_error.lastErrorMsg = StringFormat("Invalid symbol parameters: minLot=%.2f, maxLot=%.2f, lotStep=%.2f, tickSize=%.8f",
                                  m_symbolInfo.minLot, m_symbolInfo.maxLot, 
                                  m_symbolInfo.lotStep, m_symbolInfo.tickSize);
      Print(m_error.lastErrorMsg);
      return false;
   }
   
   // Initialize trade tracking
   m_tracking.lastTradeDay = TimeCurrent() - (TimeCurrent() % 86400); // Start of current day
   m_tracking.todayTrades = 0; // Will be updated in UpdateTradeStats()
   
   // Mark as initialized and ready for trading
   m_isInitialized = true;
   m_isTradeAllowed = true;
   
   Print("TradeExecutor initialized successfully for ", m_symbol.Name(), 
         " (Magic: ", m_config.magicNumber, ")");
   
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialize trade executor                                      |
//+------------------------------------------------------------------+
void CTradeExecutor::Deinitialize()
{
   if(!m_isInitialized)
      return;
      
   // Close any open positions (optional)
   // CloseAllPositions();
   
   // Reset pointers
   m_symbol = NULL;
   m_account = NULL;
   m_riskManager = NULL;
   
   // Reset state
   m_isInitialized = false;
   m_isTradeAllowed = false;
   m_lastError = 0;
   m_lastErrorMsg = "";
   
   Print("TradeExecutor deinitialized");
//+------------------------------------------------------------------+
//| Place buy limit order with enhanced error handling               |
//+------------------------------------------------------------------+
bool CTradeExecutor::BuyLimit(double lots, double price, double sl, double tp, datetime expiration, string comment)
{
   // Check if trading is allowed
   if(!m_isTradeAllowed) {
      SetError(ERR_TRADE_DISABLED, "Trading is currently disabled");
      return false;
   }
   
   // Check if we're initialized
   if(!m_isInitialized) {
      SetError(ERR_TRADE_NOT_INITIALIZED, "Trade executor not initialized");
      return false;
   }
   
   // Validate input parameters
   if(!IsVolumeValid(lots)) {
      SetError(ERR_TRADE_INVALID_VOLUME, 
               StringFormat("Invalid lot size: %.2f (min: %.2f, max: %.2f, step: %.2f)",
                           lots, m_minLot, m_maxLot, m_lotStep));
      return false;
   }
   
   if(!IsPriceValid(price)) {
      SetError(ERR_TRADE_INVALID_PRICE, 
               StringFormat("Invalid price: %.5f (Bid: %.5f, Ask: %.5f)", 
                           price, m_symbol.Bid(), m_symbol.Ask()));
      return false;
   }
   
   // Check if limit price is valid (must be below current price for buy limit)
   if(price >= m_symbol.Ask()) {
      SetError(ERR_TRADE_INVALID_PRICE,
               StringFormat("Buy limit price (%.5f) must be below current ask (%.5f)",
                           price, m_symbol.Ask()));
      return false;
   }
   
   // Check if spread is acceptable
   if(!IsSpreadAcceptable()) {
      SetError(ERR_TRADE_SPREAD_TOO_WIDE,
               StringFormat("Spread too high: %.1f pips (max: %.1f)", 
                           m_currentSpread / m_symbol.Point(), 
                           m_maxSpread / m_symbol.Point()));
      return false;
   }
   
   // Check if we've reached the maximum number of pending orders
   if(GetOpenOrdersCount() >= m_maxOpenTrades) {
      SetError(ERR_TRADE_TOO_MANY_ORDERS,
               StringFormat("Maximum number of pending orders reached: %d", m_maxOpenTrades));
      return false;
   }
   
   // Check daily trade limit
   if(m_todayTrades >= m_maxDailyTrades) {
      SetError(ERR_TRADE_LIMIT_REACHED,
               StringFormat("Daily trade limit reached: %d", m_maxDailyTrades));
      return false;
   }
   
   // Update current market data
   m_symbol.RefreshRates();
   m_currentSpread = m_symbol.Ask() - m_symbol.Bid();
   
   // Log the trade attempt with detailed information
   PrintFormat("Attempting to place buy limit order: %s %.2f lots at %.5f (Spread: %.1f pips), SL: %.5f, TP: %.5f, Expiration: %s",
              m_symbol.Name(), lots, price, m_currentSpread / m_symbol.Point(), sl, tp, 
              (expiration > 0) ? TimeToString(expiration) : "No expiration");
   
   // Execute the order with retry logic
   for(int attempt = 1; attempt <= m_maxRetries; attempt++) {
      // Reset trade result
      m_trade.ResultReset();
      
      // Execute the limit order
      bool success = m_trade.BuyLimit(lots, price, m_symbol.Name(), sl, tp, 
                                    (expiration > 0) ? ORDER_TIME_SPECIFIED : ORDER_TIME_GTC, 
                                    expiration, comment);
      
      // Check if the order was placed successfully
      if(success && m_trade.ResultRetcode() == TRADE_RETCODE_DONE) {
         // Update trade statistics
         m_todayTrades++;
         m_lastTradeTime = TimeCurrent();
         m_stats.successfulTrades++;
         m_stats.totalTrades++;
         ResetErrorState();
         
         // Log successful execution with ticket information
         PrintFormat("Buy limit order placed: %s %.2f lots at %.5f, SL: %.5f, TP: %.5f, Ticket: %I64d",
                    m_symbol.Name(), lots, price, sl, tp, m_trade.ResultOrder());
         
         return true;
      }
      
      // Get the error code and message
      int errorCode = m_trade.ResultRetcode();
      string errorMsg = m_trade.ResultRetcodeDescription();
      
      // If no error from trade object, check for system error
      if(errorCode == 0) {
         errorCode = GetLastError();
         errorMsg = ErrorDescription(errorCode);
      }
      
      // Log the failed attempt with detailed error information
      SetError(errorCode, 
               StringFormat("Buy limit order attempt %d/%d failed: %s", 
                           attempt, m_maxRetries, errorMsg));
      
      // If error is not recoverable, stop retrying
      if(!IsRecoverableError(errorCode)) {
         PrintFormat("Non-recoverable error detected. Aborting buy limit order.");
         break;
      }
      
      // If we should retry, handle the recoverable error
      if(attempt < m_maxRetries && ShouldRetryAfterError(errorCode)) {
         HandleRecoverableError(errorCode, "Buy limit order");
         continue;
      }
      
      // If we get here, either we shouldn't retry or we've exceeded max retries
      break;
   }
   
   // If we get here, all retry attempts failed
   m_stats.failedTrades++;
   m_stats.totalTrades++;
   
   // Log the final failure with all available context
   PrintFormat("Failed to place buy limit order after %d attempts. Last error: %d - %s",
             m_maxRetries, m_error.lastError, m_error.lastErrorMsg);
   
   return false;
}

//+------------------------------------------------------------------+
//| Place buy stop order with enhanced error handling                |
//+------------------------------------------------------------------+
bool CTradeExecutor::BuyStop(double lots, double price, double sl, double tp, datetime expiration, string comment)
{
   // Check if we're initialized
   if(!m_isInitialized) {
      SetError(ERR_TRADE_NOT_INITIALIZED, "Trade executor not initialized", false);
      return false;
   }
   
   // Validate input parameters
   if(!IsVolumeValid(lots)) {
      SetError(ERR_TRADE_INVALID_VOLUME, 
               StringFormat("Invalid lot size: %.2f (min: %.2f, max: %.2f, step: %.2f)",
                           lots, m_minLot, m_maxLot, m_lotStep),
               false);
      return false;
   }
   
   if(!IsPriceValid(price)) {
      SetError(ERR_TRADE_INVALID_PRICE, 
               StringFormat("Invalid price: %.5f (Bid: %.5f, Ask: %.5f)", 
                           price, m_symbol.Bid(), m_symbol.Ask()),
               false);
      return false;
   }
   
   // Check if stop price is valid (must be above current price for buy stop)
   if(price <= m_symbol.Ask()) {
      SetError(ERR_TRADE_INVALID_PRICE,
               StringFormat("Buy stop price (%.5f) must be above current ask (%.5f)",
                           price, m_symbol.Ask()),
               false);
      return false;
   }
   
   // Check if spread is acceptable
   if(!IsSpreadAcceptable()) {
      SetError(ERR_TRADE_SPREAD_TOO_WIDE,
               StringFormat("Spread too high: %.1f pips (max: %.1f)", 
                           m_currentSpread / m_symbol.Point(), 
                           m_maxSpread / m_symbol.Point()),
               true);
      return false;
   }
   
   // Check if we've reached the maximum number of pending orders
   if(GetOpenOrdersCount() >= m_maxOpenTrades) {
      SetError(ERR_TRADE_TOO_MANY_ORDERS,
               StringFormat("Maximum number of pending orders reached: %d", m_maxOpenTrades),
               true);
      return false;
   }
   
   // Check daily trade limit
   if(m_todayTrades >= m_maxDailyTrades) {
      SetError(ERR_TRADE_LIMIT_REACHED,
               StringFormat("Daily trade limit reached: %d", m_maxDailyTrades),
               false);
      return false;
   }
   
   // Update current market data
   m_symbol.RefreshRates();
   m_currentSpread = m_symbol.Ask() - m_symbol.Bid();
   
   // Calculate stop level in points
   double stopLevel = m_symbol.StopsLevel() * m_symbol.Point();
   
   // Validate stop loss and take profit levels if provided
   if(sl > 0 && price - sl <= stopLevel) {
      SetError(ERR_INVALID_STOPS,
               StringFormat("Stop loss too close to entry. Required distance: %.1f pips, Actual: %.1f pips",
                           stopLevel / m_symbol.Point(), 
                           (price - sl) / m_symbol.Point()),
               false);
      return false;
   }
   
   if(tp > 0 && tp - price <= stopLevel) {
      SetError(ERR_INVALID_STOPS,
               StringFormat("Take profit too close to entry. Required distance: %.1f pips, Actual: %.1f pips",
                           stopLevel / m_symbol.Point(), 
                           (tp - price) / m_symbol.Point()),
               false);
      return false;
   }
   
   // Log the trade attempt with detailed information
   PrintFormat("Attempting to place buy stop order: %s %.2f lots at %.5f (Spread: %.1f pips), SL: %.5f, TP: %.5f, Expiration: %s",
              m_symbol.Name(), lots, price, m_currentSpread / m_symbol.Point(), sl, tp, 
              (expiration > 0) ? TimeToString(expiration) : "No expiration");
   
   // Execute the trade using the helper method
   return ExecuteTrade(ORDER_TYPE_BUY_STOP, lots, price, sl, tp, expiration, comment);
}

//+------------------------------------------------------------------+
//| Modify an existing order with enhanced error handling            |
//+------------------------------------------------------------------+
bool CTradeExecutor::ModifyOrder(ulong ticket, double price, double sl, double tp, datetime expiration, string comment)
{
   // Check if trading is allowed
   if(!m_isTradeAllowed) {
      SetError(ERR_TRADE_DISABLED, "Trading is currently disabled");
      return false;
   }
   
   // Check if we're initialized
   if(!m_isInitialized) {
      SetError(ERR_TRADE_NOT_INITIALIZED, "Trade executor not initialized");
      return false;
   }
   
   // Validate ticket
   if(ticket <= 0) {
      SetError(ERR_INVALID_TICKET, "Invalid order ticket");
      return false;
   }
   
   // Try to select the order by ticket
   if(!m_order.Select(ticket)) {
      SetError(ERR_ORDER_NOT_FOUND, "Order not found with ticket: " + IntegerToString(ticket));
      return false;
   }
   
   // Validate the order belongs to this symbol
   if(m_order.Symbol() != m_symbol.Name()) {
      SetError(ERR_TRADE_WRONG_SYMBOL, 
               "Order symbol " + m_order.Symbol() + " does not match " + m_symbol.Name());
      return false;
   }
   
   // Get current order type
   ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)m_order.OrderType();
   
   // For limit/stop orders, validate the new price
   if(orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT ||
      orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_SELL_STOP) {
      
      if(!IsPriceValid(price)) {
         SetError(ERR_TRADE_INVALID_PRICE, 
                  StringFormat("Invalid price: %.5f (Bid: %.5f, Ask: %.5f)", 
                              price, m_symbol.Bid(), m_symbol.Ask()));
         return false;
      }
      
      // For limit orders, validate price is on the right side of the market
      if((orderType == ORDER_TYPE_BUY_LIMIT && price >= m_symbol.Ask()) ||
         (orderType == ORDER_TYPE_SELL_LIMIT && price <= m_symbol.Bid())) {
         SetError(ERR_TRADE_INVALID_PRICE, 
                  StringFormat("Invalid %s price: %.5f (must be %s current price)",
                              EnumToString(orderType), price,
                              orderType == ORDER_TYPE_BUY_LIMIT ? "below" : "above"));
         return false;
      }
      
      // For stop orders, validate price is on the right side of the market
      if((orderType == ORDER_TYPE_BUY_STOP && price <= m_symbol.Ask()) ||
         (orderType == ORDER_TYPE_SELL_STOP && price >= m_symbol.Bid())) {
         SetError(ERR_TRADE_INVALID_PRICE, 
                  StringFormat("Invalid %s price: %.5f (must be %s current price)",
                              EnumToString(orderType), price,
                              orderType == ORDER_TYPE_BUY_STOP ? "above" : "below"));
         return false;
      }
   }
   
   // Calculate stop level in points
   double stopLevel = m_symbol.StopsLevel() * m_symbol.Point();
   
   // Validate stop loss and take profit levels if provided
   if(sl > 0) {
      double slDistance = MathAbs(price - sl);
      if(slDistance <= stopLevel) {
         SetError(ERR_INVALID_STOPS,
                  StringFormat("Stop loss too close to entry. Required distance: %.1f pips, Actual: %.1f pips",
                              stopLevel / m_symbol.Point(), 
                              slDistance / m_symbol.Point()));
         return false;
      }
   }
   
   if(tp > 0) {
      double tpDistance = MathAbs(tp - price);
      if(tpDistance <= stopLevel) {
         SetError(ERR_INVALID_STOPS,
                  StringFormat("Take profit too close to entry. Required distance: %.1f pips, Actual: %.1f pips",
                              stopLevel / m_symbol.Point(), 
                              tpDistance / m_symbol.Point()));
         return false;
      }
   }
   
   // Get current order values if not provided
   double newPrice = (price > 0) ? price : m_order.PriceOpen();
   double newSL = (sl > 0) ? sl : m_order.StopLoss();
   double newTP = (tp > 0) ? tp : m_order.TakeProfit();
   datetime newExpiration = (expiration > 0) ? expiration : m_order.Expiration();
   
   // Log the modification attempt with detailed information
   PrintFormat("Attempting to modify order #%I64d: %s %s at %.5f, New price: %.5f, New SL: %.5f, New TP: %.5f, New Expiration: %s",
              ticket, m_symbol.Name(), EnumToString(orderType), m_order.PriceOpen(),
              newPrice, newSL, newTP, 
              (newExpiration > 0) ? TimeToString(newExpiration) : "No expiration");
   
   // Execute the modification with retry logic
   for(int attempt = 1; attempt <= m_maxRetries; attempt++) {
      // Reset trade result
      m_trade.ResultReset();
      
      // Execute the order modification
      bool success = m_trade.OrderModify(ticket, newPrice, newSL, newTP, 
                                       (newExpiration > 0) ? ORDER_TIME_SPECIFIED : ORDER_TIME_GTC, 
                                       newExpiration, comment);
      
      // Check if the modification was successful
      if(success && m_trade.ResultRetcode() == TRADE_RETCODE_DONE) {
         // Update statistics
         m_lastTradeTime = TimeCurrent();
         ResetErrorState();
         
         // Log successful modification
         PrintFormat("Order #%I64d modified successfully: New price: %.5f, New SL: %.5f, New TP: %.5f",
                    ticket, newPrice, newSL, newTP);
         
         return true;
      }
      
      // Get the error code and message
      int errorCode = m_trade.ResultRetcode();
      string errorMsg = m_trade.ResultRetcodeDescription();
      
      // If no error from trade object, check for system error
      if(errorCode == 0) {
         errorCode = GetLastError();
         errorMsg = ErrorDescription(errorCode);
      }
      
      // Log the failed attempt with detailed error information
      SetError(errorCode, 
               StringFormat("Order modification attempt %d/%d failed: %s", 
                           attempt, m_maxRetries, errorMsg));
      
      // If error is not recoverable, stop retrying
      if(!IsRecoverableError(errorCode)) {
         PrintFormat("Non-recoverable error detected. Aborting order modification.");
         break;
      }
      
      // If we should retry, handle the recoverable error
      if(attempt < m_maxRetries && ShouldRetryAfterError(errorCode)) {
         HandleRecoverableError(errorCode, "Order modification");
         continue;
      }
      
      // If we get here, either we shouldn't retry or we've exceeded max retries
      break;
   }
   
   // If we get here, all retry attempts failed
   PrintFormat("Failed to modify order #%I64d after %d attempts. Last error: %d - %s",
             ticket, m_maxRetries, m_error.lastError, m_error.lastErrorMsg);
   
   return false;
}

//+------------------------------------------------------------------+
//| Delete an order with enhanced error handling                     |
//+------------------------------------------------------------------+
bool CTradeExecutor::DeleteOrder(ulong ticket, string comment)
{
   // Check if trading is allowed
   if(!m_isTradeAllowed) {
      SetError(ERR_TRADE_DISABLED, "Trading is currently disabled");
      return false;
   }
   
   // Check if we're initialized
   if(!m_isInitialized) {
      SetError(ERR_TRADE_NOT_INITIALIZED, "Trade executor not initialized");
      return false;
   }
   
   // Validate ticket
   if(ticket <= 0) {
      SetError(ERR_INVALID_TICKET, "Invalid order ticket");
      return false;
   }
   
   // Try to select the order by ticket
   if(!m_order.Select(ticket)) {
      SetError(ERR_ORDER_NOT_FOUND, "Order not found with ticket: " + IntegerToString(ticket));
      return false;
   }
   
   // Validate the order belongs to this symbol
   if(m_order.Symbol() != m_symbol.Name()) {
      SetError(ERR_TRADE_WRONG_SYMBOL, 
               "Order symbol " + m_order.Symbol() + " does not match " + m_symbol.Name());
      return false;
   }
   
   // Log the deletion attempt
   PrintFormat("Attempting to delete order #%I64d: %s %s at %.5f, Lots: %.2f, SL: %.5f, TP: %.5f",
              ticket, m_symbol.Name(), EnumToString((ENUM_ORDER_TYPE)m_order.OrderType()),
              m_order.PriceOpen(), m_order.VolumeInitial(), 
              m_order.StopLoss(), m_order.TakeProfit());
   
   // Execute the deletion with retry logic
   for(int attempt = 1; attempt <= m_maxRetries; attempt++) {
      // Reset trade result
      m_trade.ResultReset();
      
      // Execute the order deletion
      bool success = m_trade.OrderDelete(ticket, comment);
      
      // Check if the deletion was successful
      if(success && m_trade.ResultRetcode() == TRADE_RETCODE_DONE) {
         // Update statistics
         m_lastTradeTime = TimeCurrent();
         ResetErrorState();
         
         // Log successful deletion
         PrintFormat("Order #%I64d deleted successfully", ticket);
         
         return true;
      }
      
      // Get the error code and message
      int errorCode = m_trade.ResultRetcode();
      string errorMsg = m_trade.ResultRetcodeDescription();
      
      // If no error from trade object, check for system error
      if(errorCode == 0) {
         errorCode = GetLastError();
         errorMsg = ErrorDescription(errorCode);
      }
      
      // Log the failed attempt with detailed error information
      SetError(errorCode, 
               StringFormat("Order deletion attempt %d/%d failed: %s", 
                           attempt, m_maxRetries, errorMsg));
      
      // If error is not recoverable, stop retrying
      if(!IsRecoverableError(errorCode)) {
         PrintFormat("Non-recoverable error detected. Aborting order deletion.");
         break;
      }
      
      // If we should retry, handle the recoverable error
      if(attempt < m_maxRetries && ShouldRetryAfterError(errorCode)) {
         HandleRecoverableError(errorCode, "Order deletion");
         continue;
      }
      
      // If we get here, either we shouldn't retry or we've exceeded max retries
      break;
   }
   
   // If we get here, all retry attempts failed
   PrintFormat("Failed to delete order #%I64d after %d attempts. Last error: %d - %s",
             ticket, m_maxRetries, m_error.lastError, m_error.lastErrorMsg);
   
   return false;
}

//+------------------------------------------------------------------+
//| Delete all pending orders with enhanced error handling           |
//+------------------------------------------------------------------+
bool CTradeExecutor::DeleteAllOrders(string comment)
{
   // Check if trading is allowed
   if(!m_isTradeAllowed) {
      SetError(ERR_TRADE_DISABLED, "Trading is currently disabled");
      return false;
   }
   
   // Check if we're initialized
   if(!m_isInitialized) {
      SetError(ERR_TRADE_NOT_INITIALIZED, "Trade executor not initialized");
      return false;
   }
   
   // Get total number of orders
   int totalOrders = OrdersTotal();
   if(totalOrders <= 0) {
      // No orders to delete is not an error
      return true;
   }
   
   Print("Attempting to delete all pending orders (", totalOrders, " orders found)");
   
   bool allDeleted = true;
   
   // We need to process orders from last to first because the order list changes as we delete
   for(int i = totalOrders - 1; i >= 0; i--) {
      // Select the order by position
      if(!m_order.SelectByIndex(i)) {
         PrintFormat("Failed to select order at index %d. Error: %d", i, GetLastError());
         allDeleted = false;
         continue;
      }
      
      // Check if the order belongs to our symbol
      if(m_order.Symbol() != m_symbol.Name()) {
         continue; // Skip orders for other symbols
      }
      
      // Check if the order has our magic number if magic number filtering is enabled
      if(m_magicNumber != 0 && m_order.Magic() != m_magicNumber) {
         continue; // Skip orders with different magic number
      }
      
      // Delete the order
      if(!DeleteOrder(m_order.Ticket(), comment)) {
         PrintFormat("Failed to delete order #%I64d: %s", 
                    m_order.Ticket(), m_error.lastErrorMsg);
         allDeleted = false;
      }
      
      // Small delay to avoid flooding the server
      Sleep(100);
   }
   
   return allDeleted;
}

//+------------------------------------------------------------------+
//| Modify an open position with enhanced error handling             |
//+------------------------------------------------------------------+
bool CTradeExecutor::ModifyPosition(ulong ticket, double sl, double tp, string comment)
{
   // Check if trading is allowed
   if(!m_isTradeAllowed) {
      SetError(ERR_TRADE_DISABLED, "Trading is currently disabled");
      return false;
   }
   
   // Check if we're initialized
   if(!m_isInitialized) {
      SetError(ERR_TRADE_NOT_INITIALIZED, "Trade executor not initialized");
      return false;
   }
   
   // Validate ticket
   if(ticket <= 0) {
      SetError(ERR_INVALID_TICKET, "Invalid position ticket");
      return false;
   }
   
   // Try to select the position by ticket
   if(!m_position.SelectByTicket(ticket)) {
      SetError(ERR_POSITION_NOT_FOUND, "Position not found with ticket: " + IntegerToString(ticket));
      return false;
   }
   
   // Validate the position belongs to this symbol
   if(m_position.Symbol() != m_symbol.Name()) {
      SetError(ERR_TRADE_WRONG_SYMBOL, 
               "Position symbol " + m_position.Symbol() + " does not match " + m_symbol.Name());
      return false;
   }
   
   // Get current position details
   double positionPrice = m_position.PriceOpen();
   double positionLots = m_position.Volume();
   ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE)m_position.PositionType();
   
   // If SL/TP not provided, use current values
   double newSL = (sl > 0) ? sl : m_position.StopLoss();
   double newTP = (tp > 0) ? tp : m_position.TakeProfit();
   
   // Calculate stop level in points
   double stopLevel = m_symbol.StopsLevel() * m_symbol.Point();
   
   // Validate stop loss and take profit levels
   if(newSL > 0) {
      double slDistance = (positionType == POSITION_TYPE_BUY) ? 
                         (positionPrice - newSL) : (newSL - positionPrice);
      
      if(slDistance <= stopLevel) {
         SetError(ERR_INVALID_STOPS,
                  StringFormat("Stop loss too close to entry. Required distance: %.1f pips, Actual: %.1f pips",
                              stopLevel / m_symbol.Point(), 
                              slDistance / m_symbol.Point()));
         return false;
      }
   }
   
   if(newTP > 0) {
      double tpDistance = (positionType == POSITION_TYPE_BUY) ? 
                         (newTP - positionPrice) : (positionPrice - newTP);
      
      if(tpDistance <= stopLevel) {
         SetError(ERR_INVALID_STOPS,
                  StringFormat("Take profit too close to entry. Required distance: %.1f pips, Actual: %.1f pips",
                              stopLevel / m_symbol.Point(), 
                              tpDistance / m_symbol.Point()));
         return false;
      }
   }
   
   // Log the modification attempt with detailed information
   PrintFormat("Attempting to modify position #%I64d: %s %s %.2f lots at %.5f, New SL: %.5f, New TP: %.5f",
              ticket, m_symbol.Name(), EnumToString(positionType), 
              positionLots, positionPrice, newSL, newTP);
   
   // Execute the modification with retry logic
   for(int attempt = 1; attempt <= m_maxRetries; attempt++) {
      // Reset trade result
      m_trade.ResultReset();
      
      // Execute the position modification
      bool success = m_trade.PositionModify(ticket, newSL, newTP);
      
      // Check if the modification was successful
      if(success && m_trade.ResultRetcode() == TRADE_RETCODE_DONE) {
         // Update statistics
         m_lastTradeTime = TimeCurrent();
         ResetErrorState();
         
         // Log successful modification
         PrintFormat("Position #%I64d modified successfully: New SL: %.5f, New TP: %.5f",
                    ticket, newSL, newTP);
         
         return true;
      }
      
      // Get the error code and message
      int errorCode = m_trade.ResultRetcode();
      string errorMsg = m_trade.ResultRetcodeDescription();
      
      // If no error from trade object, check for system error
      if(errorCode == 0) {
         errorCode = GetLastError();
         errorMsg = ErrorDescription(errorCode);
      }
      
      // Log the failed attempt with detailed error information
      SetError(errorCode, 
               StringFormat("Position modification attempt %d/%d failed: %s", 
                           attempt, m_maxRetries, errorMsg));
      
      // If error is not recoverable, stop retrying
      if(!IsRecoverableError(errorCode)) {
         PrintFormat("Non-recoverable error detected. Aborting position modification.");
         break;
      }
      
      // If we should retry, handle the recoverable error
      if(attempt < m_maxRetries && ShouldRetryAfterError(errorCode)) {
         HandleRecoverableError(errorCode, "Position modification");
         continue;
      }
      
      // If we get here, either we shouldn't retry or we've exceeded max retries
      break;
   }
   
   // If we get here, all retry attempts failed
   PrintFormat("Failed to modify position #%I64d after %d attempts. Last error: %d - %s",
             ticket, m_maxRetries, m_error.lastError, m_error.lastErrorMsg);
   
   return false;
}

//+------------------------------------------------------------------+
//| Place sell stop order with enhanced error handling               |
//+------------------------------------------------------------------+
bool CTradeExecutor::SellStop(double lots, double price, double sl, double tp, datetime expiration, string comment)
{
   // Check if we're initialized
   if(!m_isInitialized) {
      SetError(ERR_TRADE_NOT_INITIALIZED, "Trade executor not initialized", false);
      return false;
   }
   
   // Validate input parameters
   if(!IsVolumeValid(lots)) {
      SetError(ERR_TRADE_INVALID_VOLUME, 
               StringFormat("Invalid lot size: %.2f (min: %.2f, max: %.2f, step: %.2f)",
                           lots, m_minLot, m_maxLot, m_lotStep),
               false);
      return false;
   }
   
   if(!IsPriceValid(price)) {
      SetError(ERR_TRADE_INVALID_PRICE, 
               StringFormat("Invalid price: %.5f (Bid: %.5f, Ask: %.5f)", 
                           price, m_symbol.Bid(), m_symbol.Ask()),
               false);
      return false;
   }
   
   // Check if stop price is valid (must be below current price for sell stop)
   if(price >= m_symbol.Bid()) {
      SetError(ERR_TRADE_INVALID_PRICE,
               StringFormat("Sell stop price (%.5f) must be below current bid (%.5f)",
                           price, m_symbol.Bid()),
               false);
      return false;
   }
   
   // Check if spread is acceptable
   if(!IsSpreadAcceptable()) {
      SetError(ERR_TRADE_SPREAD_TOO_WIDE,
               StringFormat("Spread too high: %.1f pips (max: %.1f)", 
                           m_currentSpread / m_symbol.Point(), 
                           m_maxSpread / m_symbol.Point()),
               true);
      return false;
   }
   
   // Check if we've reached the maximum number of pending orders
   if(GetOpenOrdersCount() >= m_maxOpenTrades) {
      SetError(ERR_TRADE_TOO_MANY_ORDERS,
               StringFormat("Maximum number of pending orders reached: %d", m_maxOpenTrades),
               true);
      return false;
   }
   
   // Check daily trade limit
   if(m_todayTrades >= m_maxDailyTrades) {
      SetError(ERR_TRADE_LIMIT_REACHED,
               StringFormat("Daily trade limit reached: %d", m_maxDailyTrades),
               false);
      return false;
   }
   
   // Update current market data
   m_symbol.RefreshRates();
   m_currentSpread = m_symbol.Ask() - m_symbol.Bid();
   
   // Calculate stop level in points
   double stopLevel = m_symbol.StopsLevel() * m_symbol.Point();
   
   // Validate stop loss and take profit levels if provided
   if(sl > 0 && sl - price <= stopLevel) {
      SetError(ERR_INVALID_STOPS,
               StringFormat("Stop loss too close to entry. Required distance: %.1f pips, Actual: %.1f pips",
                           stopLevel / m_symbol.Point(), 
                           (sl - price) / m_symbol.Point()),
               false);
      return false;
   }
   
   if(tp > 0 && price - tp <= stopLevel) {
      SetError(ERR_INVALID_STOPS,
               StringFormat("Take profit too close to entry. Required distance: %.1f pips, Actual: %.1f pips",
                           stopLevel / m_symbol.Point(), 
                           (price - tp) / m_symbol.Point()),
               false);
      return false;
   }
   
   // Log the trade attempt with detailed information
   PrintFormat("Attempting to place sell stop order: %s %.2f lots at %.5f (Spread: %.1f pips), SL: %.5f, TP: %.5f, Expiration: %s",
              m_symbol.Name(), lots, price, m_currentSpread / m_symbol.Point(), sl, tp, 
              (expiration > 0) ? TimeToString(expiration) : "No expiration");
   
   // Execute the trade using the helper method
   return ExecuteTrade(ORDER_TYPE_SELL_STOP, lots, price, sl, tp, expiration, comment);
}

//+------------------------------------------------------------------+
//| Place sell limit order with enhanced error handling              |
//+------------------------------------------------------------------+
bool CTradeExecutor::SellLimit(double lots, double price, double sl, double tp, datetime expiration, string comment)
{
   // Check if we're initialized
   if(!m_isInitialized) {
      SetError(ERR_TRADE_NOT_INITIALIZED, "Trade executor not initialized", false);
      return false;
   }
   
   // Validate input parameters
   if(!IsVolumeValid(lots)) {
      SetError(ERR_TRADE_INVALID_VOLUME, 
               StringFormat("Invalid lot size: %.2f (min: %.2f, max: %.2f, step: %.2f)",
                           lots, m_minLot, m_maxLot, m_lotStep), 
               false);
      return false;
   }
   
   if(!IsPriceValid(price)) {
      SetError(ERR_TRADE_INVALID_PRICE, 
               StringFormat("Invalid price: %.5f (Bid: %.5f, Ask: %.5f)", 
                           price, m_symbol.Bid(), m_symbol.Ask()),
               false);
      return false;
   }
   
   // Check if limit price is valid (must be above current price for sell limit)
   if(price <= m_symbol.Bid()) {
      SetError(ERR_TRADE_INVALID_PRICE,
               StringFormat("Sell limit price (%.5f) must be above current bid (%.5f)",
                           price, m_symbol.Bid()),
               false);
      return false;
   }
   
   // Check if spread is acceptable
   if(!IsSpreadAcceptable()) {
      SetError(ERR_TRADE_SPREAD_TOO_WIDE,
               StringFormat("Spread too high: %.1f pips (max: %.1f)", 
                           m_currentSpread / m_symbol.Point(), 
                           m_maxSpread / m_symbol.Point()),
               true);
      return false;
   }
   
   // Check if we've reached the maximum number of pending orders
   if(GetOpenOrdersCount() >= m_maxOpenTrades) {
      SetError(ERR_TRADE_TOO_MANY_ORDERS,
               StringFormat("Maximum number of pending orders reached: %d", m_maxOpenTrades),
               true);
      return false;
   }
   
   // Check daily trade limit
   if(m_todayTrades >= m_maxDailyTrades) {
      SetError(ERR_TRADE_LIMIT_REACHED,
               StringFormat("Daily trade limit reached: %d", m_maxDailyTrades),
               false);
      return false;
   }
   
   // Update current market data
   m_symbol.RefreshRates();
   m_currentSpread = m_symbol.Ask() - m_symbol.Bid();
   
   // Log the trade attempt with detailed information
   PrintFormat("Attempting to place sell limit order: %s %.2f lots at %.5f (Spread: %.1f pips), SL: %.5f, TP: %.5f, Expiration: %s",
              m_symbol.Name(), lots, price, m_currentSpread / m_symbol.Point(), sl, tp, 
              (expiration > 0) ? TimeToString(expiration) : "No expiration");
   
   // Execute the trade using the helper method
   return ExecuteTrade(ORDER_TYPE_SELL_LIMIT, lots, price, sl, tp, expiration, comment);
}

//+------------------------------------------------------------------+
//| Execute buy order with enhanced error handling and retry logic   |
//+------------------------------------------------------------------+
bool CTradeExecutor::Buy(double lots, double price, double sl, double tp, string comment)
{
   // Check if trading is allowed
   if(!m_isTradeAllowed) {
      SetError(ERR_TRADE_DISABLED, "Trading is currently disabled");
      return false;
   }
   
   // Check if we're initialized
   if(!m_isInitialized) {
      SetError(ERR_TRADE_NOT_INITIALIZED, "Trade executor not initialized");
      return false;
   }
   
   // Validate input parameters
   if(!IsVolumeValid(lots)) {
      SetError(ERR_TRADE_INVALID_VOLUME, 
               StringFormat("Invalid lot size: %.2f (min: %.2f, max: %.2f, step: %.2f)",
                           lots, m_minLot, m_maxLot, m_lotStep));
      return false;
   }
   
   if(!IsPriceValid(price)) {
      SetError(ERR_TRADE_INVALID_PRICE, 
               StringFormat("Invalid price: %.5f (Bid: %.5f, Ask: %.5f)", 
                           price, m_symbol.Bid(), m_symbol.Ask()));
      return false;
   }
   
   // Check if spread is acceptable
   if(!IsSpreadAcceptable()) {
      SetError(ERR_TRADE_SPREAD_TOO_WIDE,
               StringFormat("Spread too high: %.1f pips (max: %.1f)", 
                           m_currentSpread / m_symbol.Point(), 
                           m_maxSpread / m_symbol.Point()));
      return false;
   }
   
   // Check if we've reached the maximum number of open positions
   if(GetOpenPositionsCount() >= m_maxOpenTrades) {
      SetError(ERR_TRADE_TOO_MANY_ORDERS,
               StringFormat("Maximum number of open positions reached: %d", m_maxOpenTrades));
      return false;
   }
   
   // Check daily trade limit
   if(m_todayTrades >= m_maxDailyTrades) {
      SetError(ERR_TRADE_LIMIT_REACHED,
               StringFormat("Daily trade limit reached: %d", m_maxDailyTrades));
      return false;
   }
   
   // Update current market data
   m_symbol.RefreshRates();
   m_currentSpread = m_symbol.Ask() - m_symbol.Bid();
   
   // Log the trade attempt with detailed information
   PrintFormat("Attempting to buy %s %.2f lots at %.5f (Spread: %.1f pips), SL: %.5f, TP: %.5f",
              m_symbol.Name(), lots, price, m_currentSpread / m_symbol.Point(), sl, tp);
   
   // Execute the trade with retry logic
   for(int attempt = 1; attempt <= m_maxRetries; attempt++) {
      // Reset trade result
      m_trade.ResultReset();
      
      // Execute the trade with current market price
      bool success = m_trade.Buy(lots, m_symbol.Name(), price, sl, tp, comment);
      
      // Check if the trade was executed successfully
      if(success && m_trade.ResultRetcode() == TRADE_RETCODE_DONE) {
         // Update trade statistics
         m_todayTrades++;
         m_lastTradeTime = TimeCurrent();
         m_stats.successfulTrades++;
         m_stats.totalTrades++;
         ResetErrorState();
         
         // Log successful execution with ticket information
         PrintFormat("Buy order executed: %s %.2f lots at %.5f, SL: %.5f, TP: %.5f, Ticket: %I64d",
                    m_symbol.Name(), lots, price, sl, tp, m_trade.ResultOrder());
         
         return true;
      }
      
      // Get the error code and message
      int errorCode = m_trade.ResultRetcode();
      string errorMsg = m_trade.ResultRetcodeDescription();
      
      // If no error from trade object, check for system error
      if(errorCode == 0) {
         errorCode = GetLastError();
         errorMsg = ErrorDescription(errorCode);
      }
      
      // Log the failed attempt with detailed error information
      SetError(errorCode, 
               StringFormat("Buy order attempt %d/%d failed: %s", 
                           attempt, m_maxRetries, errorMsg));
      
      // If error is not recoverable, stop retrying
      if(!IsRecoverableError(errorCode)) {
         PrintFormat("Non-recoverable error detected. Aborting buy order.");
         break;
      }
      
      // If we should retry, handle the recoverable error
      if(attempt < m_maxRetries && ShouldRetryAfterError(errorCode)) {
         HandleRecoverableError(errorCode, "Buy order");
         continue;
      }
      
      // If we get here, either we shouldn't retry or we've exceeded max retries
      break;
   }
   
   // If we get here, all retry attempts failed
   m_stats.failedTrades++;
   m_stats.totalTrades++;
   
   // Log the final failure with all available context
   PrintFormat("Failed to execute buy order after %d attempts. Last error: %d - %s",
             m_maxRetries, m_error.lastError, m_error.lastErrorMsg);
   
   return false;
}

//+------------------------------------------------------------------+
//| Execute sell order with enhanced error handling and retry logic  |
//+------------------------------------------------------------------+
bool CTradeExecutor::Sell(double lots, double price, double sl, double tp, string comment)
{
   // Check if trading is allowed
   if(!m_isTradeAllowed) {
      SetError(ERR_TRADE_DISABLED, "Trading is currently disabled");
      return false;
   }
   
   // Check if we're initialized
   if(!m_isInitialized) {
      SetError(ERR_TRADE_NOT_INITIALIZED, "Trade executor not initialized");
      return false;
   }
   
   // Validate input parameters
   if(!IsVolumeValid(lots)) {
      SetError(ERR_TRADE_INVALID_VOLUME, 
               StringFormat("Invalid lot size: %.2f (min: %.2f, max: %.2f, step: %.2f)",
                           lots, m_minLot, m_maxLot, m_lotStep));
      return false;
   }
   
   if(!IsPriceValid(price)) {
      SetError(ERR_TRADE_INVALID_PRICE, 
               StringFormat("Invalid price: %.5f (Bid: %.5f, Ask: %.5f)", 
                           price, m_symbol.Bid(), m_symbol.Ask()));
      return false;
   }
   
   // Check if spread is acceptable
   if(!IsSpreadAcceptable()) {
      SetError(ERR_TRADE_SPREAD_TOO_WIDE,
               StringFormat("Spread too high: %.1f pips (max: %.1f)", 
                           m_currentSpread / m_symbol.Point(), 
                           m_maxSpread / m_symbol.Point()));
      return false;
   }
   
   // Check if we've reached the maximum number of open positions
   if(GetOpenPositionsCount() >= m_maxOpenTrades) {
      SetError(ERR_TRADE_TOO_MANY_ORDERS,
               StringFormat("Maximum number of open positions reached: %d", m_maxOpenTrades));
      return false;
   }
   
   // Check daily trade limit
   if(m_todayTrades >= m_maxDailyTrades) {
      SetError(ERR_TRADE_LIMIT_REACHED,
               StringFormat("Daily trade limit reached: %d", m_maxDailyTrades));
      return false;
   }
   
   // Update current market data
   m_symbol.RefreshRates();
   m_currentSpread = m_symbol.Ask() - m_symbol.Bid();
   
   // Log the trade attempt with detailed information
   PrintFormat("Attempting to sell %s %.2f lots at %.5f (Spread: %.1f pips), SL: %.5f, TP: %.5f",
              m_symbol.Name(), lots, price, m_currentSpread / m_symbol.Point(), sl, tp);
   
   // Execute the trade with retry logic
   for(int attempt = 1; attempt <= m_maxRetries; attempt++) {
      // Reset trade result
      m_trade.ResultReset();
      
      // Execute the trade with current market price
      bool success = m_trade.Sell(lots, m_symbol.Name(), price, sl, tp, comment);
      
      // Check if the trade was executed successfully
      if(success && m_trade.ResultRetcode() == TRADE_RETCODE_DONE) {
         // Update trade statistics
         m_todayTrades++;
         m_lastTradeTime = TimeCurrent();
         m_stats.successfulTrades++;
         m_stats.totalTrades++;
         ResetErrorState();
         
         // Log successful execution with ticket information
         PrintFormat("Sell order executed: %s %.2f lots at %.5f, SL: %.5f, TP: %.5f, Ticket: %I64d",
                    m_symbol.Name(), lots, price, sl, tp, m_trade.ResultOrder());
         
         return true;
      }
      
      // Get the error code and message
      int errorCode = m_trade.ResultRetcode();
      string errorMsg = m_trade.ResultRetcodeDescription();
      
      // If no error from trade object, check for system error
      if(errorCode == 0) {
         errorCode = GetLastError();
         errorMsg = ErrorDescription(errorCode);
      }
      
      // Log the failed attempt with detailed error information
      SetError(errorCode, 
               StringFormat("Sell order attempt %d/%d failed: %s", 
                           attempt, m_maxRetries, errorMsg));
      
      // If error is not recoverable, stop retrying
      if(!IsRecoverableError(errorCode)) {
         PrintFormat("Non-recoverable error detected. Aborting sell order.");
         break;
      }
      
      // If we should retry, handle the recoverable error
      if(attempt < m_maxRetries && ShouldRetryAfterError(errorCode)) {
         HandleRecoverableError(errorCode, "Sell order");
         continue;
      }
      
      // If we get here, either we shouldn't retry or we've exceeded max retries
      break;
   }
   
   // If we get here, all retry attempts failed
   m_stats.failedTrades++;
   m_stats.totalTrades++;
   
   // Log the final failure with all available context
   PrintFormat("Failed to execute sell order after %d attempts. Last error: %d - %s",
             m_maxRetries, m_error.lastError, m_error.lastErrorMsg);
   
   return false;
      m_lastError = ERR_TRADE_CONTEXT_BUSY;
      m_lastErrorMsg = "Trade not allowed in current time window";
      Print(m_lastErrorMsg);
      return false;
   }
   
   // Check if we've reached the maximum number of consecutive failures
   if(m_consecutiveFailures >= m_maxRetries) {
      m_lastError = ERR_TOO_MANY_REQUESTS;
      m_lastErrorMsg = "Maximum number of consecutive failures reached";
      Print(m_lastErrorMsg, ". Please check your connection and account status.");
      return false;
   }
   
   // Add rate limiting
   static datetime lastTradeTime = 0;
   datetime currentTime = TimeCurrent();
   if(currentTime - lastTradeTime < 1) { // At least 1 second between trades
      m_lastError = ERR_TRADE_TOO_MANY_REQUESTS;
      m_lastErrorMsg = "Trade rate limit exceeded";
      Print(m_lastErrorMsg, ". Please wait before placing another trade.");
      return false;
   }
   // Log entry
   Print(__FUNCTION__, " called with lots=", lots, ", price=", price, 
         ", sl=", sl, ", tp=", tp, ", comment='", comment, "'");
   
   // Validate parameters with detailed error messages
   if(lots <= 0)
   {
      m_lastError = ERR_INVALID_PARAMETER;
      m_lastErrorMsg = StringFormat("Invalid lot size in Sell(): %.2f (must be > 0)", lots);
      Print(m_lastErrorMsg);
      return false;
   }
   
   if(price <= 0)
   {
      m_lastError = ERR_INVALID_PRICE;
      m_lastErrorMsg = StringFormat("Invalid price in Sell(): %.5f (must be > 0)", price);
      Print(m_lastErrorMsg);
      return false;
   }
}

//+------------------------------------------------------------------+
//| Close specified position                                         |
//+------------------------------------------------------------------+
bool CTradeExecutor::ClosePosition(ulong ticket, double lots = 0, string comment = "")
{
   // Check if trading is allowed
   if(!m_isTradeAllowed) {
      m_lastError = ERR_TRADE_DISABLED;
      m_lastErrorMsg = "Trading is currently disabled";
      return false;
   }
   
   // Try to select the position by ticket
   if(!m_position.SelectByTicket(ticket)) {
      m_lastError = GetLastError();
      m_lastErrorMsg = StringFormat("Failed to select position with ticket %I64u: %s", 
                                  ticket, ErrorDescription(m_lastError));
      return false;
   }
   
   // Verify this position belongs to our symbol and magic number
   if(m_position.Symbol() != m_symbol.Name() || m_position.Magic() != m_magicNumber) {
      m_lastError = ERR_TRADE_WRONG_PROPERTY;
      m_lastErrorMsg = StringFormat("Position %I64u does not belong to this EA", ticket);
      return false;
   }
   
   // If lots is 0, close the entire position
   if(lots <= 0) {
      lots = m_position.Volume();
   }
   
   // Validate lot size
   if(!IsVolumeValid(lots) || lots > m_position.Volume()) {
      m_lastError = ERR_INVALID_TRADE_VOLUME;
      m_lastErrorMsg = StringFormat("Invalid lot size: %.2f (position size: %.2f)", 
                                  lots, m_position.Volume());
      return false;
   }
   
   // Log the close attempt
   PrintFormat("Attempting to close position %I64u: %s %.2f/%s lots at %.5f (SL: %.5f, TP: %.5f)",
              ticket, 
              m_position.PositionType() == POSITION_TYPE_BUY ? "BUY" : "SELL",
              lots, DoubleToString(m_position.Volume(), 2),
              m_position.PriceOpen(), 
              m_position.StopLoss(), 
              m_position.TakeProfit());
   
   // Execute the close with retry logic
   for(int attempt = 1; attempt <= m_maxRetries; attempt++) {
      // Reset error state
      m_lastError = 0;
      m_lastErrorMsg = "";
      
      // Execute the close
      bool success = m_trade.PositionClose(ticket, lots, 
                                         StringFormat("EAClose:%s", comment));
      
      // If successful, wait for order completion and return
      if(success && WaitForOrderCompletion(m_trade.ResultOrder(), 5000)) {
         m_consecutiveFailures = 0; // Reset failure counter on success
         m_lastTradeTime = TimeCurrent();
         
         // Log successful execution
         PrintFormat("Position %I64u closed: %s %.2f lots at %.5f",
                   ticket, 
                   m_position.PositionType() == POSITION_TYPE_BUY ? "BUY" : "SELL",
                   lots, m_position.PriceCurrent());
         
         return true;
      }
      
      // If we get here, the order failed
      int errorCode = GetLastError();
      
      // If position is already closed, return success
      if(errorCode == ERR_INVALID_TICKET || errorCode == ERR_POSITION_NOT_FOUND)
      {
         PrintFormat("Position %I64u not found (already closed?)", ticket);
         return true;
      }
      
      // If error is not recoverable, give up
      if(!IsRecoverableError(errorCode))
      {
         HandleExecutionError("ClosePosition", errorCode);
         return false;
      }
      
      // Log the failed attempt
      PrintFormat("Close position attempt %d/%d failed: %s (Error %d: %s)",
                attempt, m_maxRetries, m_symbol.Name(), 
                errorCode, ErrorDescription(errorCode));
      
      // Wait before retry (exponential backoff)
      int delay = m_retryDelay * (1 << (attempt - 1));
      Sleep(delay);
   }
   
   // If we get here, all retry attempts failed
   {
      if(tickets[i] > 0) // Only process valid tickets
      {
         for(int attempt = 1; attempt <= m_maxRetries; attempt++)
         {
            // Reset error state
            m_lastError = 0;
            m_lastErrorMsg = "";
            
            // Close the position
            bool success = ClosePosition(tickets[i], 0, comment);
            
            // If successful, break out of retry loop
            if(success)
            {
               break;
                     ". Error: ", m_lastError, " - ", m_lastErrorMsg);
               result = false;
            }
         }
      }
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Modify position's stop loss and take profit with retry logic     |
//+------------------------------------------------------------------+
bool CTradeExecutor::ModifyPosition(ulong ticket, double sl, double tp, string comment = "")
{
   // Validate ticket
   if(ticket <= 0)
   {
      m_lastError = ERR_INVALID_TICKET;
      m_lastErrorMsg = "Invalid ticket number: " + IntegerToString(ticket);
      return false;
   }
   
   // Check execution conditions
   if(!CheckExecutionConditions())
   {
      Print("Modify position pre-check failed: ", m_lastErrorMsg);
      return false;
   }
   
   // Select the position by ticket
   if(!m_position.SelectByTicket(ticket))
   {
      m_lastError = GetLastError();
      m_lastErrorMsg = "Failed to select position with ticket " + IntegerToString(ticket);
      
      // If position is already closed, this isn't an error
      if(m_lastError == ERR_TRADE_POSITION_NOT_FOUND || m_lastError == ERR_INVALID_TICKET)
      {
         PrintFormat("Position %d not found (already closed?)", ticket);
         return true;
      }
      
      return false;
   }
   
   // Check if modification is needed
   if(m_position.StopLoss() == sl && m_position.TakeProfit() == tp)
   {
      PrintFormat("No modification needed for position %d - SL/TP already at desired levels", ticket);
      return true;
   }
   
   // Get position details
   string symbol = m_position.Symbol();
   
   // Execute with retry logic
   for(int attempt = 1; attempt <= m_maxRetries; attempt++)
   {
      // Reset error state
      m_lastError = 0;
      m_lastErrorMsg = "";
      
      // Modify the position
      bool success = m_trade.PositionModify(ticket, sl, tp);
      
      // If successful, wait for order completion and return
      if(success && WaitForOrderCompletion(m_trade.ResultOrder(), 5000))
      {
         m_consecutiveFailures = 0; // Reset failure counter on success
         m_lastTradeTime = TimeCurrent();
         
         // Log successful execution
         PrintFormat("Position %d modified: %s SL=%.5f, TP=%.5f",
                   ticket, symbol, sl, tp);
         
         return true;
      }
      
      // If we get here, the order failed
      int errorCode = GetLastError();
      
      // If position is already closed, this isn't an error
      if(errorCode == ERR_INVALID_TICKET || errorCode == ERR_POSITION_NOT_FOUND)
      {
         PrintFormat("Position %d not found (already closed?)", ticket);
         return true;
      }
      
      // If error is not recoverable, give up
      if(!IsRecoverableError(errorCode))
      {
         HandleExecutionError("ModifyPosition", errorCode);
         return false;
      }
      
      // Log the failed attempt
      PrintFormat("Modify position attempt %d/%d failed: %s (Error %d: %s)",
                attempt, m_maxRetries, symbol, 
                errorCode, ErrorDescription(errorCode));
      
      // Wait before retry (exponential backoff)
      int delay = m_retryDelay * (1 << (attempt - 1));
      Sleep(delay);
   }
   
   // If we get here, all retry attempts failed
   HandleExecutionError("ModifyPosition", m_lastError);
   return false;
}

//+------------------------------------------------------------------+
//| Check if trading limits are not exceeded                         |
//+------------------------------------------------------------------+
bool CTradeExecutor::CheckLimits()
{
   if(m_symbol == NULL || m_account == NULL || m_riskManager == NULL)
   {
      m_lastError = ERR_NOT_INITIALIZED;
      m_lastErrorMsg = "Trade executor not properly initialized";
      return false;
   }
   
   // Check if we can trade
   if(!m_account.TradeAllowed())
   {
      m_lastError = ERR_TRADE_DISABLED;
      m_lastErrorMsg = "Trading is not allowed for the current account";
      return false;
   }
   
   // Check if the symbol is selected and market is open
   if(!m_symbol.IsTradeAllowed())
   {
      m_lastError = ERR_MARKET_CLOSED;
      m_lastErrorMsg = "Trading is not allowed for " + m_symbol.Name();
      return false;
   }
   
   // Check if we're not too close to market close (for daily charts)
   if(m_symbol.Time() >= (TimeCurrent() - 60)) // Last tick was within the last minute
   {
      m_lastError = ERR_MARKET_CLOSED;
      m_lastErrorMsg = "Market is closed or no new prices";
      return false;
   }
   
   // Check for consecutive failures (circuit breaker)
   if(m_consecutiveFailures >= m_maxRetries)
   {
      m_lastError = ERR_LIMIT_ORDERS;
      m_lastErrorMsg = "Maximum consecutive failures reached. Trading temporarily suspended.";
      return false;
   }
   
   // Check minimum time between trades
   if(TimeCurrent() - m_lastTradeTime < 1) // At least 1 second between trades
   {
      m_lastError = ERR_TOO_FREQUENT_REQUESTS;
      m_lastErrorMsg = "Too frequent trade requests. Please wait.";
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if execution conditions are met                            |
//+------------------------------------------------------------------+
bool CTradeExecutor::CheckExecutionConditions()
{
   // Check basic trading conditions
   if(!CheckLimits())
      return false;
      
   // Check if symbol is selected and market data is fresh
   if(!m_symbol.RefreshRates())
   {
      m_lastError = ERR_MARKET_CLOSED;
      m_lastErrorMsg = "Failed to refresh market data for " + m_symbol.Name();
      return false;
   }
   
   // Check if spread is acceptable
   double spread = m_symbol.Ask() - m_symbol.Bid();
   double spreadPips = spread / m_symbol.Point();
   
   if(spreadPips > m_maxSlippagePips * 2) // Allow spread up to 2x max slippage
   {
      m_lastError = ERR_INVALID_SPREAD;
      m_lastErrorMsg = StringFormat("Spread too wide: %.1f pips (max: %.1f)", 
                                 spreadPips, m_maxSlippagePips * 2);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Handle execution error and update error info                     |
//+------------------------------------------------------------------+
void CTradeExecutor::HandleExecutionError(const string &func, const int errorCode)
{
   m_lastError = errorCode;
   m_lastErrorMsg = StringFormat("%s failed with error %d: %s", 
                              func, errorCode, ErrorDescription(errorCode));
   m_consecutiveFailures++;
   
   // Log the error
   Print(m_lastErrorMsg);
   
   // If we have too many consecutive failures, log a warning
   if(m_consecutiveFailures >= m_maxRetries)
   {
      string warning = StringFormat("WARNING: %d consecutive failures. Trading suspended.", 
                                 m_consecutiveFailures);
      Print(warning);
      // Could also send an alert or notification here
   }
}

//+------------------------------------------------------------------+
//| Wait for order completion with timeout                           |
//+------------------------------------------------------------------+
bool CTradeExecutor::WaitForOrderCompletion(ulong ticket, const uint timeout_ms)
{
   if(ticket <= 0) return false;
   
   uint start = GetTickCount();
   
   while(GetTickCount() - start < timeout_ms)
   {
      if(OrderSelect(ticket, SELECT_BY_TICKET) && 
         (OrderCloseTime() > 0 || OrderType() == OP_BUY || OrderType() == OP_SELL))
      {
         return true; // Order is closed or is a position
      }
      
      // Small delay to prevent CPU overload
      Sleep(10);
   }
   
   // If we get here, the order didn't complete in time
   m_lastError = ERR_TRADE_TIMEOUT;
   m_lastErrorMsg = StringFormat("Order %d did not complete within %d ms", 
                              ticket, timeout_ms);
   return false;
}

//+------------------------------------------------------------------+
//| Check if volume is valid                                         |
//+------------------------------------------------------------------+
bool CTradeExecutor::IsVolumeValid(double volume) const
{
   if(volume < m_minLot || volume > m_maxLot)
      return false;
      
   // Check if volume is a multiple of lot step
   double steps = volume / m_lotStep;
   return steps == MathFloor(steps);
}

//+------------------------------------------------------------------+
//| Check if price is valid                                          |
//+------------------------------------------------------------------+
bool CTradeExecutor::IsPriceValid(double price) const
{
   if(price <= 0)
      return false;
      
   // Check if price is a multiple of tick size
   double ticks = price / m_tickSize;
   return ticks == MathFloor(ticks);
}

//+------------------------------------------------------------------+
//| Check if current spread is acceptable                            |
//+------------------------------------------------------------------+
bool CTradeExecutor::IsSpreadAcceptable() const
{
   if(!m_symbol.RefreshRates()) {
      Print("Failed to refresh symbol rates");
      return false;
   }
   
   double spread = m_symbol.Ask() - m_symbol.Bid();
   double spreadPips = spread / m_symbol.Point();
   
   return (spreadPips <= m_maxSpread);
}

//+------------------------------------------------------------------+
//| Get count of open positions                                      |
//+------------------------------------------------------------------+
int CTradeExecutor::GetOpenPositionsCount() const
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(m_position.SelectByIndex(i)) {
         if(m_position.Symbol() == m_symbol.Name() && 
            m_position.Magic() == m_magicNumber) {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Set error information                                            |
//+------------------------------------------------------------------+
void CTradeExecutor::SetError(const int errorCode, const string message, const string funcName)
{
   m_error.lastError = errorCode;
   m_error.lastErrorMsg = message;
   m_error.lastErrorFunc = funcName;
   m_error.lastErrorTime = TimeCurrent();
   m_error.totalErrors++;
   
   // Update consecutive failures
   if(errorCode != ERR_TRADE_SUCCESS)
   {
      m_error.consecutiveFailures++;
      
      // If we've had too many consecutive failures, disable trading
      if(m_error.consecutiveFailures >= MAX_CONSECUTIVE_FAILURES)
      {
         m_isTradeAllowed = false;
         string warning = StringFormat("WARNING: Too many consecutive failures (%d). Trading disabled.", 
                                    m_error.consecutiveFailures);
         Print(warning);
      }
   }
   else
   {
      // Reset consecutive failures on success
      m_error.consecutiveFailures = 0;
   }
   
   // Log the error
   PrintFormat("[%s] Error %d: %s", funcName, errorCode, message);
}

//+------------------------------------------------------------------+
//| Check if an error is recoverable                                 |
//+------------------------------------------------------------------+
bool CTradeExecutor::IsRecoverableError(const int errorCode) const
{
   // No error or success
   if(errorCode == ERR_NO_ERROR || errorCode == ERR_TRADE_SUCCESS)
      return true;
      
   // Non-critical errors that might be recoverable
   switch(errorCode)
   {
      case ERR_TRADE_CONTEXT_BUSY:
      case ERR_SERVER_BUSY:
      case ERR_OFF_QUOTES:
      case ERR_BROKER_TOO_BUSY:
      case ERR_TRADE_TIMEOUT:
      case ERR_TOO_FREQUENT_REQUESTS:
      case ERR_TRADE_TOO_MANY_ORDERS:
      case ERR_TRADE_CONNECTION_LOST:
      case ERR_TRADE_SERVER_BUSY:
      case ERR_TRADE_CONTEXT_BUSY:
      case ERR_TRADE_TOO_FREQUENT:
         return true;
         
      // Critical errors that are not recoverable
      case ERR_TRADE_DISABLED:
      case ERR_MARKET_CLOSED:
      case ERR_NOT_ENOUGH_RIGHTS:
      case ERR_ACCOUNT_DISABLED:
      case ERR_ACCOUNT_MARGIN_CALL:
      case ERR_ACCOUNT_WAS_SUSPENDED:
      case ERR_ACCOUNT_INVALID:
      case ERR_TRADE_HEDGE_PROHIBITED:
      case ERR_TRADE_PROHIBITED_BY_FIFO:
      case ERR_ACCOUNT_READONLY:
      case ERR_TRADE_INVALID_ACCOUNT:
      case ERR_TRADE_NOT_ALLOWED:
         return false;
         
      default:
         // For unknown errors, assume they're not recoverable to be safe
         return false;
   }
}

//+------------------------------------------------------------------+
//| Check if we should retry after an error                          |
//+------------------------------------------------------------------+
bool CTradeExecutor::ShouldRetryAfterError(const int errorCode) const
{
   // Only retry recoverable errors
   if(!IsRecoverableError(errorCode))
      return false;
      
   // Don't retry if we've had too many consecutive failures
   if(m_error.consecutiveFailures >= MAX_CONSECUTIVE_FAILURES)
      return false;
      
   // Don't retry if trading is disabled
   if(!m_isTradeAllowed)
      return false;
      
   return true;
}

//+------------------------------------------------------------------+
//| Handle a recoverable error                                       |
//+------------------------------------------------------------------+
void CTradeExecutor::HandleRecoverableError(const int errorCode, const string &context)
{
   // Log the error
   string errorMsg = StringFormat("Recoverable error in %s: %s (%d)", 
                               context, ErrorDescription(errorCode), errorCode);
   SetError(errorCode, errorMsg);
   
   // Add a small delay before retrying
   int jitter = MathRand() % TRADE_RETRY_JITTER_MS; // Add some randomness to avoid thundering herd
   Sleep(RETRY_DELAY_MS + jitter);
   
   // Refresh market data before retrying
   if(m_symbol != NULL)
      m_symbol.RefreshRates();
}

//+------------------------------------------------------------------+
//| Reset error state                                                |
//+------------------------------------------------------------------+
void CTradeExecutor::ResetErrorState()
{
   m_error.lastError = ERR_TRADE_SUCCESS;
   m_error.lastErrorMsg = "";
   m_error.lastErrorFunc = "";
   m_error.consecutiveFailures = 0;
   // Don't reset totalErrors or lastErrorTime as they're for historical tracking
}

//+------------------------------------------------------------------+
//| Get error description for a given error code                     |
//+------------------------------------------------------------------+
string CTradeExecutor::GetErrorDescription(const int errorCode) const
{
   switch(errorCode)
   {
      case ERR_TRADE_SUCCESS:           return "Operation completed successfully";
      case ERR_TRADE_INVALID_PARAMETER: return "Invalid parameter";
      case ERR_TRADE_NOT_INITIALIZED:   return "Trade executor not initialized";
      case ERR_TRADE_DISABLED:          return "Trading is disabled";
      case ERR_TRADE_INVALID_SYMBOL:    return "Invalid symbol";
      case ERR_TRADE_INVALID_VOLUME:    return "Invalid volume";
      case ERR_TRADE_INVALID_PRICE:     return "Invalid price";
      case ERR_TRADE_INVALID_STOPS:     return "Invalid stop loss/take profit";
      case ERR_TRADE_INSUFFICIENT_FUNDS:return "Insufficient funds";
      case ERR_TRADE_MARKET_CLOSED:     return "Market is closed";
      case ERR_TRADE_TOO_MANY_REQUESTS: return "Too many trade requests";
      case ERR_TRADE_TIMEOUT:           return "Trade operation timed out";
      case ERR_TRADE_SPREAD_TOO_WIDE:   return "Spread is too wide";
      case ERR_TRADE_POSITION_NOT_FOUND:return "Position not found";
      case ERR_TRADE_ORDER_NOT_FOUND:   return "Order not found";
      case ERR_TRADE_CONNECTION_LOST:   return "Connection to trade server lost";
      case ERR_TRADE_SERVER_BUSY:       return "Trade server is busy";
      case ERR_TRADE_CONTEXT_BUSY:      return "Trade context is busy";
      case ERR_TRADE_TOO_FREQUENT:      return "Trading too frequently";
      case ERR_TRADE_LIMIT_REACHED:     return "Trade limit reached";
      default:                          return "Unknown error";
   }
}

//+------------------------------------------------------------------+
//| Update error information from the last trade operation           |
//+------------------------------------------------------------------+
void CTradeExecutor::UpdateErrorInfo()
{
   int errorCode = m_trade.ResultRetcode();
   string errorMsg = m_trade.ResultRetcodeDescription();
   
   // If no error from trade object, check for system error
   if(errorCode == 0)
   {
      errorCode = GetLastError();
      errorMsg = ErrorDescription(errorCode);
   }
   
   // Only update if there's an actual error
   if(errorCode != 0 && errorCode != ERR_NO_ERROR)
   {
      SetError(errorCode, errorMsg, __FUNCTION__);
   }
   else
   {
      // Reset error state on success
      ResetErrorState();
   }
}
//+------------------------------------------------------------------+
