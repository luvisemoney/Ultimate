//+------------------------------------------------------------------+
//| AdvancedStrategy.mqh - Advanced trading strategies for EscapeEA  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include "..\Common\Enums.mqh"
#include "..\Common\Structs.mqh"
#include "..\Learning\LearningEngine.mqh"
#include "..\Core\AdvancedRiskManager.mqh"
#include "..\Core\TradeExecutor.mqh"

// Forward declarations
class CAdvancedRiskManager;
class CTradeExecutor;

//+------------------------------------------------------------------+
//| Advanced Strategy Class                                          |
//+------------------------------------------------------------------+
class CAdvancedStrategy
  {
private:
   // Configuration
   string            m_symbol;              // Trading symbol
   ENUM_TIMEFRAMES   m_timeframe;           // Timeframe for analysis
   ulong             m_magicNumber;         // EA's magic number
   bool              m_isLive;              // True for live trading
   
   // Components
   CAdvancedRiskManager *m_riskManager;     // Risk manager instance
   CLearningEngine   *m_learningEngine;     // Machine learning engine
   CTradeExecutor    *m_tradeExecutor;      // Trade execution component
   
   // Indicators
   int               m_maFastHandle;        // Fast MA handle
   int               m_maMediumHandle;      // Medium MA handle
   int               m_maSlowHandle;        // Slow MA handle
   int               m_rsiHandle;           // RSI handle
   int               m_macdHandle;          // MACD handle
   int               m_bollingerHandle;     // Bollinger Bands handle
   int               m_atrHandle;           // ATR handle
   
   // State
   datetime          m_lastBarTime;         // Last processed bar time
   bool              m_isInitialized;       // Initialization flag
   double            m_minConfidence;       // Minimum confidence threshold
   
   // Private methods
   bool              InitializeIndicators();
   void              CleanupIndicators();
   double            GetIndicatorValue(int handle, int buffer, int shift = 0);
   bool              CalculateConfidence(const MqlRates &rates[], int shift, double &outConfidence);
   bool              IsValidSignal(ENUM_TRADE_SIGNAL signal, double confidence);
   void              LogTradingDecision(ENUM_TRADE_SIGNAL signal, double entryPrice, 
                                      double stopLoss, double takeProfit, 
                                      double lotSize, double confidence);
   double            CalculateLotSize(double riskPercent, double entryPrice, double stopLoss);
   bool              ExecuteTrade(ENUM_TRADE_SIGNAL signal, double entryPrice,
                                double stopLoss, double takeProfit, double confidence);
   bool              InitializeTradeExecutor();
   void              CleanupTradeExecutor();
   
public:
   // Constructor/destructor
                     CAdvancedStrategy(string symbol, ENUM_TIMEFRAMES timeframe);
                    ~CAdvancedStrategy()
                     {
                      // Release all resources
                      CleanupIndicators();
                      CleanupTradeExecutor();
                      
                      // Nullify pointers (safety)
                      m_riskManager = NULL;
                      m_learningEngine = NULL;
                      m_tradeExecutor = NULL;
                      
                      // Reset state
                      m_isInitialized = false;
                      m_lastBarTime = 0;
                     }
   
   // Initialization
   bool              Initialize(CAdvancedRiskManager *riskManager = NULL, 
                              CLearningEngine *learningEngine = NULL, 
                              CTradeExecutor *tradeExecutor = NULL,
                              ulong magicNumber = 0,
                              bool isLive = false);
   
   // Strategy methods
   ENUM_TRADE_SIGNAL GetSignal(const MqlRates &rates[], int shift, double &confidence);
   bool              Update(const MqlRates &rates[]);
   
   // Getters
   string            Symbol() const { return m_symbol; }
   ENUM_TIMEFRAMES   Timeframe() const { return m_timeframe; }
   bool              IsInitialized() const { return m_isInitialized; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CAdvancedStrategy::CAdvancedStrategy(string symbol, ENUM_TIMEFRAMES timeframe) :
   m_symbol(symbol),
   m_timeframe(timeframe),
   m_riskManager(NULL),
   m_learningEngine(NULL),
   m_tradeExecutor(NULL),
   m_maFastHandle(INVALID_HANDLE),
   m_maMediumHandle(INVALID_HANDLE),
   m_maSlowHandle(INVALID_HANDLE),
   m_rsiHandle(INVALID_HANDLE),
   m_macdHandle(INVALID_HANDLE),
   m_bollingerHandle(INVALID_HANDLE),
   m_atrHandle(INVALID_HANDLE),
   m_lastBarTime(0),
   m_isInitialized(false)
  {
  }

//+------------------------------------------------------------------+
//| Initialize strategy with required components                     |
//+------------------------------------------------------------------+
bool CAdvancedStrategy::Initialize(CAdvancedRiskManager *riskManager, 
                                 CLearningEngine *learningEngine,
                                 CTradeExecutor *tradeExecutor,
                                 ulong magicNumber,
                                 bool isLive)
  {
   // Store references to components if provided
   if(riskManager != NULL)
      m_riskManager = riskManager;
   if(learningEngine != NULL)
      m_learningEngine = learningEngine;
   if(tradeExecutor != NULL)
      m_tradeExecutor = tradeExecutor;
   
   m_magicNumber = magicNumber;
   m_isLive = isLive;
   
   // Initialize indicators
   if(!InitializeIndicators())
     {
      Print("Failed to initialize indicators");
      return false;
     }
   
   m_isInitialized = true;
   Print("AdvancedStrategy initialized successfully");
   return true;
  }

//+------------------------------------------------------------------+
//| Initialize technical indicators                                  |
//+------------------------------------------------------------------+
bool CAdvancedStrategy::InitializeIndicators()
  {
   // Clean up any existing indicators
   CleanupIndicators();
   
   // Initialize Moving Averages
   m_maFastHandle = iMA(m_symbol, m_timeframe, 9, 0, MODE_EMA, PRICE_CLOSE);
   m_maMediumHandle = iMA(m_symbol, m_timeframe, 21, 0, MODE_EMA, PRICE_CLOSE);
   m_maSlowHandle = iMA(m_symbol, m_timeframe, 50, 0, MODE_SMA, PRICE_CLOSE);
   
   // Initialize RSI
   m_rsiHandle = iRSI(m_symbol, m_timeframe, 14, PRICE_CLOSE);
   
   // Initialize MACD
   m_macdHandle = iMACD(m_symbol, m_timeframe, 12, 26, 9, PRICE_CLOSE);
   
   // Initialize Bollinger Bands
   // Using the correct parameters for iBands: symbol, timeframe, period, shift, deviation, applied_price
   m_bollingerHandle = iBands(m_symbol, m_timeframe, 20, 0, 2.0, PRICE_CLOSE);
   
   // Initialize ATR
   m_atrHandle = iATR(m_symbol, m_timeframe, 14);
   
   // Verify all indicators were created successfully
   if(m_maFastHandle == INVALID_HANDLE || 
      m_maMediumHandle == INVALID_HANDLE ||
      m_maSlowHandle == INVALID_HANDLE ||
      m_rsiHandle == INVALID_HANDLE ||
      m_macdHandle == INVALID_HANDLE ||
      m_bollingerHandle == INVALID_HANDLE ||
      m_atrHandle == INVALID_HANDLE)
     {
      CleanupIndicators();
      return false;
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Clean up indicator handles                                       |
//+------------------------------------------------------------------+
void CAdvancedStrategy::CleanupIndicators()
  {
   // Release indicator handles
   if(m_maFastHandle != INVALID_HANDLE)
     {
      IndicatorRelease(m_maFastHandle);
      m_maFastHandle = INVALID_HANDLE;
     }
   
   if(m_maMediumHandle != INVALID_HANDLE)
     {
      IndicatorRelease(m_maMediumHandle);
      m_maMediumHandle = INVALID_HANDLE;
     }
   
   if(m_maSlowHandle != INVALID_HANDLE)
     {
      IndicatorRelease(m_maSlowHandle);
      m_maSlowHandle = INVALID_HANDLE;
     }
   
   if(m_rsiHandle != INVALID_HANDLE)
     {
      IndicatorRelease(m_rsiHandle);
      m_rsiHandle = INVALID_HANDLE;
     }
   
   if(m_macdHandle != INVALID_HANDLE)
     {
      IndicatorRelease(m_macdHandle);
      m_macdHandle = INVALID_HANDLE;
     }
   
   if(m_bollingerHandle != INVALID_HANDLE)
     {
      IndicatorRelease(m_bollingerHandle);
      m_bollingerHandle = INVALID_HANDLE;
     }
   
   if(m_atrHandle != INVALID_HANDLE)
     {
      IndicatorRelease(m_atrHandle);
      m_atrHandle = INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//| Initialize trade executor                                        |
//+------------------------------------------------------------------+
bool CAdvancedStrategy::InitializeTradeExecutor()
  {
   // Trade executor is initialized in the constructor
   // No explicit initialization needed here as it's handled by the constructor
   if(m_tradeExecutor == NULL)
     {
      Print("Error: Trade executor is not initialized");
      return false;
     }
   
   // Set the magic number and live mode
   m_tradeExecutor.SetMagic(m_magicNumber);
   m_tradeExecutor.SetLiveMode(m_isLive);
   
   return true;
  }

//+------------------------------------------------------------------+
//| Clean up trade executor                                          |
//+------------------------------------------------------------------+
void CAdvancedStrategy::CleanupTradeExecutor()
  {
   if(CheckPointer(m_tradeExecutor) != POINTER_INVALID)
     {
      // No explicit cleanup needed for CTradeExecutor as it inherits from CTrade
      // which handles its own cleanup in its destructor
      m_tradeExecutor = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Get indicator value safely                                       |
//+------------------------------------------------------------------+
double CAdvancedStrategy::GetIndicatorValue(int handle, int buffer, int shift = 0)
  {
   // Validate handle
   if(handle == INVALID_HANDLE)
     {
      Print("Error: Invalid indicator handle");
      return 0.0;
     }
     
   // In MQL5, we need to use IndicatorBuffers to get the number of buffers
   // For now, we'll just check if the handle is valid and proceed
   if(handle == INVALID_HANDLE)
     {
      Print("Error: Invalid indicator handle");
      return 0.0;
     }
     
   // Copy indicator data
   double values[1] = {0.0};
   int copied = CopyBuffer(handle, buffer, shift, 1, values);
   
   if(copied != 1)
     {
      PrintFormat("Error: Failed to copy indicator buffer %d. Error: %d", 
                 buffer, GetLastError());
      return 0.0;
     }
     
   // Validate the returned value
   if(!MathIsValidNumber(values[0]))
     {
      PrintFormat("Warning: Invalid indicator value: %.8f", values[0]);
      return 0.0;
     }
     
   return values[0];
  }

//+------------------------------------------------------------------+
//| Calculate trade signal confidence                                |
//+------------------------------------------------------------------+
bool CAdvancedStrategy::CalculateConfidence(const MqlRates &rates[], int shift, double &outConfidence)
  {
   outConfidence = 0.0;
   
   if(shift >= ArraySize(rates) - 1)
      return false;
      
   // Get indicator values
   double maFast = GetIndicatorValue(m_maFastHandle, 0, shift);
   double maMedium = GetIndicatorValue(m_maMediumHandle, 0, shift);
   double maSlow = GetIndicatorValue(m_maSlowHandle, 0, shift);
   double rsi = GetIndicatorValue(m_rsiHandle, 0, shift);
   double macd = GetIndicatorValue(m_macdHandle, 0, shift);
   double macdSignal = GetIndicatorValue(m_macdHandle, 1, shift);
   double upperBand = GetIndicatorValue(m_bollingerHandle, 1, shift);
   double lowerBand = GetIndicatorValue(m_bollingerHandle, 2, shift);
   double atr = GetIndicatorValue(m_atrHandle, 0, shift);
   
   // Calculate confidence based on multiple factors
   double confidence = 0.0;
   int signalCount = 0;
   bool success = true;
   
   // 1. Moving Average Crossover
   if(maFast > maMedium && maMedium > maSlow)
     {
      confidence += 0.3;
      signalCount++;
     }
   else if(maFast < maMedium && maMedium < maSlow)
     {
      confidence -= 0.3;
      signalCount++;
     }
   
   // 2. RSI
   if(rsi > 70)
     {
      confidence -= 0.2;
      signalCount++;
     }
   else if(rsi < 30)
     {
      confidence += 0.2;
      signalCount++;
     }
   
   // 3. MACD
   if(macd > macdSignal)
     {
      confidence += 0.2;
      signalCount++;
     }
   else if(macd < macdSignal)
     {
      confidence -= 0.2;
      signalCount++;
     }
   
   // 4. Bollinger Bands
   double close = rates[shift].close;
   if(close > upperBand)
     {
      confidence -= 0.15;
      signalCount++;
     }
   else if(close < lowerBand)
     {
      confidence += 0.15;
      signalCount++;
     }
   
   // 5. ATR (Volatility)
   double atrPercent = atr / close;
   if(atrPercent > 0.02)  // High volatility
     {
      confidence *= 0.8;  // Reduce confidence in high volatility
     }
   
   // Normalize confidence to [-1, 1] range if we have any signals
   if(signalCount > 0)
     {
      outConfidence = MathMin(1.0, MathMax(-1.0, confidence / signalCount));
      return true;
     }
      
   return false;
  }

//+------------------------------------------------------------------+
//| Validate trading signal                                          |
//+------------------------------------------------------------------+
bool CAdvancedStrategy::IsValidSignal(ENUM_TRADE_SIGNAL signal, double confidence)
  {
   if(signal == SIGNAL_HOLD)
      return false;
      
   // Check confidence threshold
   double minConfidence = 0.5;
   if(confidence < minConfidence && confidence > -minConfidence)
      return false;
      
   // Check if we have a valid signal
   if((signal == SIGNAL_BUY && confidence > 0) ||
      (signal == SIGNAL_SELL && confidence < 0))
     {
      return true;
     }
      
   return false;
  }

//+------------------------------------------------------------------+
//| Log trading decision                                            |
//+------------------------------------------------------------------+
void CAdvancedStrategy::LogTradingDecision(ENUM_TRADE_SIGNAL signal, double entryPrice, 
                                         double stopLoss, double takeProfit, 
                                         double lotSize, double confidence)
  {
   string logMsg = StringFormat("%s Signal - %s | ", 
                               TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
                               EnumToString(signal));
                               
   logMsg += StringFormat("Entry: %.5f, SL: %.5f, TP: %.5f, ", 
                         entryPrice, stopLoss, takeProfit);
                         
   logMsg += StringFormat("Lots: %.2f, Confidence: %.2f", 
                         lotSize, confidence);
                         
   Print(logMsg);
  }

//+------------------------------------------------------------------+
//| Get trading signal based on strategy rules                       |
//+------------------------------------------------------------------+
ENUM_TRADE_SIGNAL CAdvancedStrategy::GetSignal(const MqlRates &rates[], int shift, double &confidence)
  {
   // Reset confidence
   confidence = 0.0;
   
   // Validate inputs and state
   if(!m_isInitialized)
     {
      Print("Error: Strategy not initialized");
      return SIGNAL_HOLD;
     }
     
   if(ArraySize(rates) <= shift || shift < 0)
     {
      Print("Error: Invalid shift value or insufficient data");
      return SIGNAL_HOLD;
     }
   
   // Calculate confidence score
   double conf = 0.0;
   if(!CalculateConfidence(rates, shift, conf))
     {
      Print("Error calculating confidence score");
      confidence = 0.0;
      return SIGNAL_HOLD;
     }
   
   confidence = conf;
   
   // Apply threshold for trading
   if(confidence > 0.5)
      return SIGNAL_BUY;
   else if(confidence < -0.5)
      return SIGNAL_SELL;
   
   return SIGNAL_HOLD;
  }

//+------------------------------------------------------------------+
//| Update strategy with latest market data                          |
//+------------------------------------------------------------------+
bool CAdvancedStrategy::Update(const MqlRates &rates[])
  {
   // Validate inputs and state
   if(!m_isInitialized)
     {
      Print("Error: Strategy not initialized");
      return false;
     }
     
   if(ArraySize(rates) < 2)
     {
      Print("Error: Insufficient rate data");
      return false;
     }
   
   // Check for new bar
   if(rates[0].time == m_lastBarTime)
     {
      return true;  // No new data
     }
   
   // Update last processed bar time
   m_lastBarTime = rates[0].time;
   
   // Get signal for the most recent completed bar
   double confidence = 0.0;
   ENUM_TRADE_SIGNAL signal = GetSignal(rates, 1, confidence);
   
   // Only proceed if we have a valid signal
   if(signal == SIGNAL_HOLD)
     {
      return true;
     }
   
   // Get current market data
   double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   
   if(ask <= 0 || bid <= 0 || point <= 0)
     {
      Print("Error: Invalid market data");
      return false;
     }
      
   // Calculate position size and risk parameters
   double stopLoss = 0.0;
   double takeProfit = 0.0;
   double entryPrice = (signal == SIGNAL_BUY) ? ask : bid;
   
   // Get ATR for volatility-based position sizing
   double atr = GetIndicatorValue(m_atrHandle, 0, 0);
   if(atr <= 0)
     {
      Print("Warning: Invalid ATR value, using default");
      atr = 100 * point; // Default to 100 pips if ATR is invalid
     }
   
   // Set SL/TP based on signal type
   if(signal == SIGNAL_BUY)
     {
      stopLoss = entryPrice - (2.0 * atr);
      takeProfit = entryPrice + (3.0 * atr);
     }
   else // SIGNAL_SELL
     {
      stopLoss = entryPrice + (2.0 * atr);
      takeProfit = entryPrice - (3.0 * atr);
     }
   
   // Calculate position size using risk manager
   double riskPercent = 1.0; // Default 1% risk per trade
   double stopDistance = MathAbs(entryPrice - stopLoss);
   double calculatedLotSize = 0.0;
   
   if(CheckPointer(m_riskManager) != POINTER_INVALID)
     {
      // Calculate lot size based on risk percentage, entry price and stop loss
      calculatedLotSize = CalculateLotSize(riskPercent, entryPrice, stopLoss);
      
      // Validate position size
      double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
      calculatedLotSize = MathMax(minLot, MathMin(maxLot, calculatedLotSize));
     }
   
   if(calculatedLotSize <= 0)
     {
      Print("Error: Invalid position size calculated");
      return false;
     }
   
   // Get current time for trade record
   datetime currentTime = TimeCurrent();
   
   // Log the trading decision
   PrintFormat("Signal: %s, Entry: %.5f, SL: %.5f, TP: %.5f, Lots: %.2f, Confidence: %.2f",
              signal == SIGNAL_BUY ? "BUY" : "SELL", 
              entryPrice, stopLoss, takeProfit, calculatedLotSize, confidence);
   
   // Execute the trade
   if(!ExecuteTrade(signal, entryPrice, stopLoss, takeProfit, confidence))
     {
      Print("Failed to execute trade");
      return false;
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Execute trade based on signal                                    |
//+------------------------------------------------------------------+
bool CAdvancedStrategy::ExecuteTrade(ENUM_TRADE_SIGNAL signal, double entryPrice, 
                                   double stopLoss, double takeProfit, double confidence)
  {
   // Validate inputs
   if(signal == SIGNAL_HOLD || entryPrice <= 0 || confidence < m_minConfidence)
     {
      Print("Invalid trade signal or parameters");
      return false;
     }
   
   // Calculate position size based on risk parameters
   double riskPercent = 1.0; // Default risk percent if risk manager is not available
   if(CheckPointer(m_riskManager) != POINTER_INVALID)
     {
      riskPercent = m_riskManager.RiskPerTrade();
     }
   double calculatedLotSize = CalculateLotSize(riskPercent, entryPrice, stopLoss);
   if(calculatedLotSize <= 0)
     {
      Print("Error: Invalid position size calculated");
      return false;
     }
   
   // Get current time for trade record
   datetime currentTime = TimeCurrent();
   
   // Log the trading decision
   PrintFormat("Signal: %s, Entry: %.5f, SL: %.5f, TP: %.5f, Lots: %.2f, Confidence: %.2f",
              signal == SIGNAL_BUY ? "BUY" : "SELL", 
              entryPrice, stopLoss, takeProfit, calculatedLotSize, confidence);
   
   // Execute the trade using the trade executor
   if(CheckPointer(m_tradeExecutor) != POINTER_INVALID)
     {
      ENUM_ORDER_TYPE orderType = (signal == SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      string comment = StringFormat("AdvancedStrategy %s (%.2f%%)", 
                                  EnumToString(signal), 
                                  confidence * 100);
      
      // Execute the trade
      if(!m_tradeExecutor.OpenPosition(orderType, calculatedLotSize, stopLoss, takeProfit, comment))
        {
         Print("Failed to execute trade: ", GetLastError());
         return false;
        }
      
      // Get the ticket of the opened position
      ulong ticket = m_tradeExecutor.ResultOrder();
      if(ticket == 0)
        {
         Print("Failed to get trade ticket");
         return false;
        }
      
      PrintFormat("Trade executed successfully. Ticket: %I64u", ticket);
      
      // Update learning engine with the trade decision
      if(CheckPointer(m_learningEngine) != POINTER_INVALID)
        {
         STradeRecord trade;
         
         // Initialize trade record
         trade.ticket = ticket;
         trade.symbol = m_symbol;
         trade.type = (signal == SIGNAL_BUY) ? TRADE_TYPE_BUY : TRADE_TYPE_SELL;
         trade.openTime = currentTime;
         trade.closeTime = 0; // Not closed yet
         trade.openPrice = entryPrice;
         trade.closePrice = 0.0; // Not closed yet
         trade.stopLoss = stopLoss;
         trade.takeProfit = takeProfit;
         trade.lots = calculatedLotSize;
         trade.profit = 0.0; // Will be updated when closed
         trade.commission = 0.0; // Will be set by the broker
         trade.swap = 0.0; // Will be set by the broker
         trade.signal = signal;
         trade.confidence = confidence;
         trade.comment = comment;
         trade.isLive = m_isLive;
         
         // Update the learning model with the new trade
         if(!m_learningEngine.UpdateModel(trade))
           {
            Print("Warning: Failed to update learning model with trade");
           }
        }
      
      return true;
     }
   
   // Update learning engine with the trade decision
   if(CheckPointer(m_learningEngine) != POINTER_INVALID)
     {
      STradeRecord trade;
      
      // Initialize trade record
      trade.ticket = 0; // Will be set by the broker when the trade is executed
      trade.symbol = m_symbol;
      trade.type = (signal == SIGNAL_BUY) ? TRADE_TYPE_BUY : TRADE_TYPE_SELL;
      trade.openTime = currentTime;
      trade.closeTime = 0; // Not closed yet
      trade.openPrice = entryPrice;
      trade.closePrice = 0.0; // Not closed yet
      trade.stopLoss = stopLoss;
      trade.takeProfit = takeProfit;
      trade.lots = calculatedLotSize;
      trade.profit = 0.0; // Not closed yet
      trade.commission = 0.0; // Will be set by the broker
      trade.swap = 0.0; // Will be set by the broker
      trade.signal = signal;
      trade.confidence = confidence;
      trade.comment = "Generated by AdvancedStrategy";
      trade.isLive = true;
      
      // Update the learning model with the new trade
      bool modelUpdated = m_learningEngine.UpdateModel(trade);
      
      if(modelUpdated)
        {
         Print("Trade added to learning engine and model updated");
        }
      else
        {
         Print("Warning: Failed to update learning model with trade");
        }
     }
   
   return true;
  }
  
//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage, entry and stop loss |
//+------------------------------------------------------------------+
double CAdvancedStrategy::CalculateLotSize(double riskPercent, double entryPrice, double stopLoss)
  {
   // Default values
   double lotSize = 0.1;
   
   // Get account balance
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0 || entryPrice <= 0 || stopLoss <= 0)
      return lotSize; // Return default if inputs are invalid
      
   // Get symbol information
   double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
   
   // Calculate position size based on risk
   if(tickSize > 0 && tickValue > 0)
     {
      // Calculate stop loss distance in points
      double stopLossPoints = MathAbs(entryPrice - stopLoss) / _Point;
      if(stopLossPoints <= 0)
         return lotSize;
         
      // Calculate risk amount in account currency
      double riskAmount = balance * (riskPercent / 100.0);
      
      // Calculate position size in lots based on actual stop loss
      double positionSize = (riskAmount / (stopLossPoints * tickValue)) * (tickSize / _Point);
      
      // Normalize to lot step
      lotSize = MathFloor(positionSize / lotStep) * lotStep;
      
      // Ensure within min/max limits
      lotSize = MathMin(MathMax(lotSize, minLot), maxLot);
     }
     
   return lotSize;
  }
