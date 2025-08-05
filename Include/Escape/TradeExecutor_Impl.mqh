//+------------------------------------------------------------------+
//| TradeExecutor_Impl.mqh                                           |
//|   Implementation of CTradeExecutor methods                       |
//+------------------------------------------------------------------+
#property strict

#include "TradeExecutor.mqh"   // include header for class definition

// NOTE: This file contains implementations of CTradeExecutor methods
//       Only method implementations should be in this file - no class definitions.

//+------------------------------------------------------------------+
//| Check if trading is allowed                                      |
//+------------------------------------------------------------------+
bool CTradeExecutor::IsTradingAllowed()
{
   if(!m_isInitialized)
   {
      m_lastError = "Trade executor not initialized";
      return false;
   }
   if(!m_isTradingAllowed)
   {
      m_lastError = "Trading is disabled by configuration";
      return false;
   }
   if(m_circuitBroken)
   {
      if(TimeCurrent() - m_circuitBreakTime < m_circuitBreakPeriod)
      {
         m_lastError = "Circuit breaker active";
         return false;
      }
      else
      {
         m_circuitBroken = false;
         m_consecutiveErrors = 0;
      }
   }
   
   // Rate limit check
   datetime currentTime = TimeCurrent();
   if(TimeMinute(currentTime) != TimeMinute(m_currentMinute))
   {
      m_currentMinute = currentTime - (currentTime % 60);
      m_ordersThisMinute = 0;
   }
   
   if(m_ordersThisMinute >= m_maxOrdersPerMinute)
   {
      m_lastError = "Rate limit exceeded";
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTradeExecutor::CTradeExecutor() :
   m_totalTrades(0),
   m_successfulTrades(0),
   m_failedTrades(0),
   m_totalSlippage(0.0),
   m_avgExecutionTime(0.0),
   m_isInitialized(false),
   m_isTradingAllowed(false),
   m_riskManager(NULL),
   m_retryDelay(1000),  // 1 second default retry delay
   m_maxSlippage(10),   // 10 points default slippage
   m_useCircuitBreaker(true),
   m_checkMarketConditions(true)
{
   // Initialize trade object with default settings
   m_trade.SetDeviationInPoints(m_maxSlippage);
   m_trade.SetExpertMagicNumber(0);
   m_trade.SetMarginMode();
   m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   // Initialize arrays
   m_tradeHistory = new CArrayObj();
   m_pendingOrders = new CArrayObj();
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTradeExecutor::~CTradeExecutor()
{
   // Clean up trade history
   if(CheckPointer(m_tradeHistory) == POINTER_DYNAMIC)
      delete m_tradeHistory;
      
   // Clean up pending orders
   if(CheckPointer(m_pendingOrders) == POINTER_DYNAMIC)
      delete m_pendingOrders;
}

//+------------------------------------------------------------------+
//| Reset circuit breaker                                            |
//+------------------------------------------------------------------+
void CTradeExecutor::ResetCircuitBreaker()
{
   m_circuitBreakTime = 0;
   m_consecutiveErrors = 0;
}

//+------------------------------------------------------------------+
//| Clean up old trade records                                       |
//+------------------------------------------------------------------+
void CTradeExecutor::CleanupOldRecords()
{
   datetime cutoff = TimeCurrent() - 7 * 24 * 60 * 60; // 1 week
   
   for(int i = m_tradeHistory.Total() - 1; i >= 0; i--)
   {
      CTradeRecord* record = m_tradeHistory.At(i);
      if(record != NULL && record.time < cutoff)
      {
         m_tradeHistory.Delete(i);
      }
   }
}

//+------------------------------------------------------------------+
//| Update circuit breaker state                                     |
//+------------------------------------------------------------------+
void CTradeExecutor::UpdateCircuitBreaker(bool errorOccurred)
{
   if(errorOccurred)
   {
      m_consecutiveErrors++;
      
      // If we've hit the maximum consecutive errors, activate circuit breaker
      if(m_consecutiveErrors >= m_maxConsecutiveErrors)
      {
         m_circuitBreakTime = TimeCurrent() + 300; // 5 minutes cooldown
         m_isTradingAllowed = false;
         Print("Circuit breaker activated! Trading paused for 5 minutes.");
      }
   }
   else
   {
      // Reset error counter on successful operation
      m_consecutiveErrors = 0;
   }
}

//+------------------------------------------------------------------+
//| Initialize                                                      |
//+------------------------------------------------------------------+
bool CTradeExecutor::Initialize(CRiskManager *riskManager)
{
   if(m_isInitialized)
      return true;
   m_trade.SetExpertMagicNumber(0);
   m_trade.SetDeviationInPoints(m_maxSlippage);
   m_trade.SetAsyncMode(true);
   m_riskManager = riskManager;
   if(!m_security.Initialize())
   {
      m_lastError = "Failed to initialize security enhancements: "+m_security.GetLastError();
      return false;
   }
   ResetCircuitBreaker();
   m_totalTrades = m_successfulTrades = m_failedTrades = 0;
   m_totalSlippage = m_avgExecutionTime = 0.0;
   m_trade.SetDeviationInPoints(InpMaxSlippage);
   CleanupOldRecords();
   m_isInitialized = true;
   m_isTradingAllowed = true;
   Print("TradeExecutor: Initialized successfully");
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialize                                                    |
//+------------------------------------------------------------------+
void CTradeExecutor::Deinitialize(void)
{
   if(!m_isInitialized)
      return;
   m_tradeHistory.Clear();
   m_activeTrades.Clear();
   m_hasPendingOrder = false;
   ZeroMemory(m_pendingOrder);
   m_circuitBroken = false;
   m_consecutiveErrors = 0;
   m_circuitBreakTime = 0;
   s_ordersThisMinute = 0;
   s_currentMinute = 0;
   m_totalTrades = m_successfulTrades = m_failedTrades = 0;
   m_totalSlippage = m_avgExecutionTime = 0.0;
   m_lastError = "";
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
   for(int attempt = 0; attempt <= InpMaxRetries; attempt++)
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
         int delay = MathMin(InpRetryDelay * (int)MathPow(2, attempt-1), 5000); // Exponential backoff, max 5s
         PrintFormat("TradeExecutor: Retry attempt %d of %d after %d ms", 
                    attempt, InpMaxRetries, delay);
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
         if(attempt >= InpMaxRetries - 1)
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
   {
      UpdateCircuitBreaker(true);
   }
   
   return result;
}

// Static member definitions --------------------------------------------------
int CTradeExecutor::s_ordersThisMinute = 0;
datetime CTradeExecutor::s_currentMinute = 0;

//---------------------------------------------------------------------------
//  END MOVED IMPLEMENTATIONS
//---------------------------------------------------------------------------
