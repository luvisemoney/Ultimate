//+------------------------------------------------------------------+
//| SignalGenerator.mqh - Signal generation for EscapeEA             |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include "..\Common\Enums.mqh"
#include "..\Common\Structs.mqh"
#include "..\Common\Constants.mqh"
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Signal Generator Class                                           |
//+------------------------------------------------------------------+
class CSignalGenerator
  {
private:
   int               m_maFastHandle;      // Fast MA handle
   int               m_maSlowHandle;      // Slow MA handle
   int               m_rsiHandle;         // RSI handle
   int               m_atrHandle;         // ATR handle
   double            m_minConfidence;     // Minimum confidence threshold
   string            m_symbol;            // Symbol for signal generation
   ENUM_TIMEFRAMES   m_timeframe;         // Timeframe for analysis
   
   // Private methods
   double            CalculateConfidence(const double &maFast[], const double &maSlow[], const double &rsi[], const double &atr[]);
   
public:
   // Constructor/destructor
                     CSignalGenerator(string symbol, ENUM_TIMEFRAMES timeframe, int fastMAPeriod, int slowMAPeriod, 
                                    int rsiPeriod, int atrPeriod, double minConfidence);
                    ~CSignalGenerator();
   
   // Main methods
   bool              Initialize();
   STradeSignal      GenerateSignal();
   void              UpdateIndicators();
   
   // Getters
   string            Symbol() const { return m_symbol; }
   ENUM_TIMEFRAMES   Timeframe() const { return m_timeframe; }
   double            MinConfidence() const { return m_minConfidence; }
   
   // Setters
   void              SetMinConfidence(double confidence) { m_minConfidence = confidence; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSignalGenerator::CSignalGenerator(string symbol, ENUM_TIMEFRAMES timeframe, int fastMAPeriod, int slowMAPeriod, 
                                 int rsiPeriod, int atrPeriod, double minConfidence) :
   m_symbol(symbol),
   m_timeframe(timeframe),
   m_minConfidence(minConfidence),
   m_maFastHandle(INVALID_HANDLE),
   m_maSlowHandle(INVALID_HANDLE),
   m_rsiHandle(INVALID_HANDLE),
   m_atrHandle(INVALID_HANDLE)
  {
   // Initialize indicators
   m_maFastHandle = iMA(m_symbol, m_timeframe, fastMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   m_maSlowHandle = iMA(m_symbol, m_timeframe, slowMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   m_rsiHandle = iRSI(m_symbol, m_timeframe, rsiPeriod, PRICE_CLOSE);
   m_atrHandle = iATR(m_symbol, m_timeframe, atrPeriod);
   
   if(m_maFastHandle == INVALID_HANDLE || m_maSlowHandle == INVALID_HANDLE || 
      m_rsiHandle == INVALID_HANDLE || m_atrHandle == INVALID_HANDLE)
     {
      Print("Error initializing indicators");
     }
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSignalGenerator::~CSignalGenerator()
  {
   // Release indicator handles
   if(m_maFastHandle != INVALID_HANDLE)
      IndicatorRelease(m_maFastHandle);
   if(m_maSlowHandle != INVALID_HANDLE)
      IndicatorRelease(m_maSlowHandle);
   if(m_rsiHandle != INVALID_HANDLE)
      IndicatorRelease(m_rsiHandle);
   if(m_atrHandle != INVALID_HANDLE)
      IndicatorRelease(m_atrHandle);
  }

//+------------------------------------------------------------------+
//| Generate trading signal                                          |
//+------------------------------------------------------------------+
STradeSignal CSignalGenerator::GenerateSignal()
  {
   STradeSignal signal;
   signal.symbol = m_symbol;
   signal.timeframe = m_timeframe;
   signal.timestamp = TimeCurrent();
   signal.confidence = 0.0;
   signal.signal = SIGNAL_HOLD;
   
   // Get indicator values
   double maFast[3] = {0};
   double maSlow[3] = {0};
   double rsi[2] = {0};
   double atr[1] = {0};
   
   // Copy indicator data
   if(CopyBuffer(m_maFastHandle, 0, 0, 3, maFast) != 3 ||
      CopyBuffer(m_maSlowHandle, 0, 0, 3, maSlow) != 3 ||
      CopyBuffer(m_rsiHandle, 0, 0, 2, rsi) != 2 ||
      CopyBuffer(m_atrHandle, 0, 0, 1, atr) != 1)
     {
      Print("Error copying indicator data");
      return signal;
     }
   
   // Calculate signal confidence
   double confidence = CalculateConfidence(maFast, maSlow, rsi, atr);
   
   // Generate signal based on indicators
   if(confidence >= m_minConfidence)
     {
      if(maFast[0] > maSlow[0] && maFast[1] <= maSlow[1] && rsi[0] > 50)
        {
         signal.signal = SIGNAL_BUY;
         signal.confidence = confidence;
         signal.entry = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
         signal.stopLoss = signal.entry - (2.0 * atr[0]);
         signal.takeProfit = signal.entry + (3.0 * atr[0]);
         signal.riskReward = 1.5;
         signal.comment = StringFormat("BUY signal (Confidence: %.2f)", confidence);
        }
      else if(maFast[0] < maSlow[0] && maFast[1] >= maSlow[1] && rsi[0] < 50)
        {
         signal.signal = SIGNAL_SELL;
         signal.confidence = confidence;
         signal.entry = SymbolInfoDouble(m_symbol, SYMBOL_BID);
         signal.stopLoss = signal.entry + (2.0 * atr[0]);
         signal.takeProfit = signal.entry - (3.0 * atr[0]);
         signal.riskReward = 1.5;
         signal.comment = StringFormat("SELL signal (Confidence: %.2f)", confidence);
        }
     }
   
   return signal;
  }

//+------------------------------------------------------------------+
//| Calculate signal confidence                                      |
//+------------------------------------------------------------------+
double CSignalGenerator::CalculateConfidence(const double &maFast[], const double &maSlow[], 
                                           const double &rsi[], const double &atr[])
  {
   double confidence = 0.0;
   
   // Calculate trend strength (0-1)
   double maDiff = MathAbs(maFast[0] - maSlow[0]);
   double atrValue = atr[0];
   double normalizedATR = atrValue / SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   double trendStrength = MathMin(maDiff / (normalizedATR * 0.1), 1.0);
   
   // Calculate RSI confidence (0-1)
   double rsiConfidence = 0.0;
   if(rsi[0] > 70 || rsi[0] < 30)
      rsiConfidence = 0.8;  // Strong overbought/oversold
   else if(rsi[0] > 60 || rsi[0] < 40)
      rsiConfidence = 0.6;  // Moderate overbought/oversold
   else
      rsiConfidence = 0.4;  // Neutral
   
   // Combine confidence factors (weighted average)
   confidence = (trendStrength * 0.6) + (rsiConfidence * 0.4);
   
   return MathMin(MathMax(confidence, 0.0), 1.0);
  }

//+------------------------------------------------------------------+
//| Update indicators                                                |
//+------------------------------------------------------------------+
void CSignalGenerator::UpdateIndicators()
  {
   // Refresh indicator handles if needed
   if(m_maFastHandle == INVALID_HANDLE)
      m_maFastHandle = iMA(m_symbol, m_timeframe, 10, 0, MODE_EMA, PRICE_CLOSE);
   if(m_maSlowHandle == INVALID_HANDLE)
      m_maSlowHandle = iMA(m_symbol, m_timeframe, 20, 0, MODE_EMA, PRICE_CLOSE);
   if(m_rsiHandle == INVALID_HANDLE)
      m_rsiHandle = iRSI(m_symbol, m_timeframe, 14, PRICE_CLOSE);
   if(m_atrHandle == INVALID_HANDLE)
      m_atrHandle = iATR(m_symbol, m_timeframe, 14);
  }
