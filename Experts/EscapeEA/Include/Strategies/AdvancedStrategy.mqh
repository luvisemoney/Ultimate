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

// Forward declarations
class CAdvancedRiskManager;

//+------------------------------------------------------------------+
//| Advanced Strategy Class                                          |
//+------------------------------------------------------------------+
class CAdvancedStrategy
  {
private:
   // Configuration
   string            m_symbol;              // Trading symbol
   ENUM_TIMEFRAMES   m_timeframe;           // Timeframe for analysis
   
   // Components
   CAdvancedRiskManager *m_riskManager;     // Risk manager instance
   CLearningEngine   *m_learningEngine;     // Machine learning engine
   
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
   
   // Private methods
   bool              InitializeIndicators();
   void              CleanupIndicators();
   double            GetIndicatorValue(int handle, int buffer, int shift = 0);
   double            CalculateConfidence(const MqlRates &rates[], int shift);
   bool              IsValidSignal(ENUM_TRADE_SIGNAL signal, double confidence);
   void              LogTradingDecision(ENUM_TRADE_SIGNAL signal, double entryPrice, 
                                      double stopLoss, double takeProfit, 
                                      double lotSize, double confidence);
   
public:
   // Constructor/destructor
                     CAdvancedStrategy(string symbol, ENUM_TIMEFRAMES timeframe);
                    ~CAdvancedStrategy()
                     {
                      // Release all resources
                      CleanupIndicators();
                      
                      // Nullify pointers (safety)
                      m_riskManager = NULL;
                      m_learningEngine = NULL;
                      
                      // Reset state
                      m_isInitialized = false;
                      m_lastBarTime = 0;
                     }
   
   // Initialization
   bool              Initialize(CAdvancedRiskManager *riskManager, 
                              CLearningEngine *learningEngine);
   
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
//| Destructor                                                       |
//+------------------------------------------------------------------+
CAdvancedStrategy::~CAdvancedStrategy()
  {
   CleanupIndicators();
  }

//+------------------------------------------------------------------+
//| Initialize strategy with required components                     |
//+------------------------------------------------------------------+
bool CAdvancedStrategy::Initialize(CAdvancedRiskManager *riskManager, 
                                 CLearningEngine *learningEngine)
  {
   // Validate inputs
   if(CheckPointer(riskManager) == POINTER_INVALID || 
      CheckPointer(learningEngine) == POINTER_INVALID)
     {
      Print("Error: Invalid risk manager or learning engine");
      return false;
     }
   
   // Store references
   m_riskManager = riskManager;
   m_learningEngine = learningEngine;
   
   // Initialize indicators
   if(!InitializeIndicators())
     {
      Print("Failed to initialize indicators");
      return false;
     }
   
   m_isInitialized = true;
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
      IndicatorRelease(m_maFastHandle);
   if(m_maMediumHandle != INVALID_HANDLE)
      IndicatorRelease(m_maMediumHandle);
   if(m_maSlowHandle != INVALID_HANDLE)
      IndicatorRelease(m_maSlowHandle);
   if(m_rsiHandle != INVALID_HANDLE)
      IndicatorRelease(m_rsiHandle);
   if(m_macdHandle != INVALID_HANDLE)
      IndicatorRelease(m_macdHandle);
   if(m_bollingerHandle != INVALID_HANDLE)
      IndicatorRelease(m_bollingerHandle);
   if(m_atrHandle != INVALID_HANDLE)
      IndicatorRelease(m_atrHandle);
      
   // Reset handles
   m_maFastHandle = INVALID_HANDLE;
   m_maMediumHandle = INVALID_HANDLE;
   m_maSlowHandle = INVALID_HANDLE;
   m_rsiHandle = INVALID_HANDLE;
   m_macdHandle = INVALID_HANDLE;
   m_bollingerHandle = INVALID_HANDLE;
   m_atrHandle = INVALID_HANDLE;
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
     
   // Validate buffer index
   int buffers = 0;
   if(!IndicatorParameters(handle, buffers) || buffer < 0 || buffer >= buffers)
     {
      PrintFormat("Error: Invalid buffer index %d for indicator", buffer);
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
double CAdvancedStrategy::CalculateConfidence(const MqlRates &rates[], int shift)
  {
   if(shift >= ArraySize(rates) - 1)
      return 0.0;
      
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
   
   // Normalize confidence to [-1, 1] range
   if(signalCount > 0)
      confidence /= signalCount;
   
   return MathMax(-1.0, MathMin(1.0, confidence));
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
   
   try
     {
      // Calculate confidence score
      confidence = CalculateConfidence(rates, shift);
      
      // Apply threshold for trading
      if(confidence > 0.5)
         return SIGNAL_BUY;
      else if(confidence < -0.5)
         return SIGNAL_SELL;
     }
   catch(const std::exception &e)
     {
      PrintFormat("Exception in GetSignal(): %s", e.what());
      confidence = 0.0;
     }
   
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
   
   try
     {
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
      double lotSize = 0.0;
      
      if(CheckPointer(m_riskManager) != POINTER_INVALID)
        {
         lotSize = m_riskManager.CalculatePositionSize(m_symbol, stopDistance, riskPercent);
         
         // Validate position size
         double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
         double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
         lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
        }
      
      if(lotSize <= 0)
        {
         Print("Error: Invalid position size calculated");
         return false;
        }
      
      // Log the trading decision
      PrintFormat("Signal: %s, Entry: %.5f, SL: %.5f, TP: %.5f, Lots: %.2f, Confidence: %.2f",
                 EnumToString(signal), entryPrice, stopLoss, takeProfit, lotSize, confidence);
      
      // Here you would typically pass the trade to the trade executor
      // For example: m_tradeExecutor->ExecuteTrade(signal, lotSize, stopLoss, takeProfit);
      
      // Update learning engine with the trade decision
      if(CheckPointer(m_learningEngine) != POINTER_INVALID)
        {
         STradeRecord trade;
         trade.symbol = m_symbol;
         trade.type = (signal == SIGNAL_BUY) ? TRADE_TYPE_BUY : TRADE_TYPE_SELL;
         trade.entryPrice = entryPrice;
         trade.stopLoss = stopLoss;
         trade.takeProfit = takeProfit;
         trade.lotSize = lotSize;
         trade.confidence = confidence;
         trade.timestamp = TimeCurrent();
         
         m_learningEngine->AddTrade(trade);
        }
      
      return true;
     }
   catch(const std::exception &e)
     {
      PrintFormat("Exception in Update(): %s", e.what());
      return false;
     }
     
   return true;
  }
