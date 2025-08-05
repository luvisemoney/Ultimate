//+------------------------------------------------------------------+
//|                                                SignalGenerator.mqh |
//|                                          Copyright 2025, EscapeEA |
//|                                             https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"
#property strict

#include <Arrays\ArrayObj.mqh>
#include <Indicators\Trend.mqh>
#include <Indicators\Oscilators.mqh>

// Forward declarations
class CSymbolInfo;

//+------------------------------------------------------------------+
//| Signal types and enums                                           |
//+------------------------------------------------------------------+
enum ENUM_SIGNAL_TYPE {
   SIGNAL_TYPE_NONE = 0,      // No signal
   SIGNAL_TYPE_BUY = 1,       // Buy signal
   SIGNAL_TYPE_SELL = -1,     // Sell signal
   SIGNAL_TYPE_CLOSE = 2      // Close position signal
};

//+------------------------------------------------------------------+
//| Signal structure to hold signal details                          |
//+------------------------------------------------------------------+
struct SSignal {
   ENUM_SIGNAL_TYPE type;     // Signal type
   double           price;     // Entry price
   double           sl;        // Stop loss
   double           tp;        // Take profit
   double           strength;  // Signal strength (0.0 to 1.0)
   string           comment;   // Signal comment/description
   datetime         time;      // Signal time
   
   // Default constructor
   SSignal() {
      type = SIGNAL_TYPE_NONE;
      price = 0.0;
      sl = 0.0;
      tp = 0.0;
      strength = 0.0;
      comment = "";
      time = 0;
   }
};

//+------------------------------------------------------------------+
//| Signal Generator class                                           |
//+------------------------------------------------------------------+
class CSignalGenerator {
private:
   // Indicators
   CiMA             m_ma;              // Moving Average
   CiMA             m_maFast;          // Fast Moving Average
   CiMA             m_maSlow;          // Slow Moving Average
   CiATR            m_atr;             // Average True Range
   
   // Configuration
   int              m_maPeriod;        // MA Period
   int              m_maFastPeriod;    // Fast MA Period
   int              m_maSlowPeriod;    // Slow MA Period
   int              m_atrPeriod;       // ATR Period
   double           m_atrMultiplier;   // ATR Multiplier for SL/TP
   
   // State
   bool             m_initialized;     // Initialization flag
   CSymbolInfo     *m_symbol;          // Symbol info
   
   // Private methods
   bool             InitializeIndicators();
   double           CalculateATRMultiplier() const;
   
public:
   // Constructor/Destructor
                     CSignalGenerator();
                    ~CSignalGenerator();
   
   // Initialization
   bool              Initialize(CSymbolInfo *symbol, 
                              int maPeriod, 
                              int maFastPeriod, 
                              int maSlowPeriod, 
                              int atrPeriod, 
                              double atrMultiplier);
   
   // Signal generation
   bool              GenerateSignal(SSignal &signal);
   
   // Getters
   bool              IsInitialized() const { return m_initialized; }
   
   // Utility
   static string     SignalTypeToString(ENUM_SIGNAL_TYPE type);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSignalGenerator::CSignalGenerator() : 
   m_maPeriod(20),
   m_maFastPeriod(10),
   m_maSlowPeriod(50),
   m_atrPeriod(14),
   m_atrMultiplier(2.0),
   m_initialized(false),
   m_symbol(NULL)
{
   // Initialize indicators
   m_ma = CiMA();
   m_maFast = CiMA();
   m_maSlow = CiMA();
   m_atr = CiATR();
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSignalGenerator::~CSignalGenerator() {
   // Release indicators
   m_ma.Release();
   m_maFast.Release();
   m_maSlow.Release();
   m_atr.Release();
   
   // Clear symbol reference
   m_symbol = NULL;
   m_initialized = false;
}

//+------------------------------------------------------------------+
//| Initialize the signal generator                                  |
//+------------------------------------------------------------------+
bool CSignalGenerator::Initialize(CSymbolInfo *symbol, 
                                int maPeriod, 
                                int maFastPeriod, 
                                int maSlowPeriod, 
                                int atrPeriod, 
                                double atrMultiplier) {
   // Validate inputs
   if(symbol == NULL || !symbol.Name() == "") {
      Print("Error: Invalid symbol info");
      return false;
   }
   
   if(maPeriod <= 0 || maFastPeriod <= 0 || maSlowPeriod <= 0 || atrPeriod <= 0) {
      Print("Error: Invalid indicator periods");
      return false;
   }
   
   // Store configuration
   m_symbol = symbol;
   m_maPeriod = maPeriod;
   m_maFastPeriod = maFastPeriod;
   m_maSlowPeriod = maSlowPeriod;
   m_atrPeriod = atrPeriod;
   m_atrMultiplier = atrMultiplier;
   
   // Initialize indicators
   if(!InitializeIndicators()) {
      Print("Error: Failed to initialize indicators");
      return false;
   }
   
   m_initialized = true;
   return true;
}

//+------------------------------------------------------------------+
//| Initialize indicators                                            |
//+------------------------------------------------------------------+
bool CSignalGenerator::InitializeIndicators() {
   // Initialize MA
   if(!m_ma.Create(m_symbol.Name(), PERIOD_CURRENT, m_maPeriod, 0, MODE_SMA, PRICE_CLOSE)) {
      Print("Error creating MA indicator");
      return false;
   }
   
   // Initialize Fast MA
   if(!m_maFast.Create(m_symbol.Name(), PERIOD_CURRENT, m_maFastPeriod, 0, MODE_SMA, PRICE_CLOSE)) {
      Print("Error creating Fast MA indicator");
      return false;
   }
   
   // Initialize Slow MA
   if(!m_maSlow.Create(m_symbol.Name(), PERIOD_CURRENT, m_maSlowPeriod, 0, MODE_SMA, PRICE_CLOSE)) {
      Print("Error creating Slow MA indicator");
      return false;
   }
   
   // Initialize ATR
   if(!m_atr.Create(m_symbol.Name(), PERIOD_CURRENT, m_atrPeriod)) {
      Print("Error creating ATR indicator");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Generate trading signal                                          |
//+------------------------------------------------------------------+
bool CSignalGenerator::GenerateSignal(SSignal &signal) {
   // Reset signal
   signal = SSignal();
   
   // Check initialization
   if(!m_initialized || m_symbol == NULL) {
      signal.comment = "Signal generator not properly initialized";
      return false;
   }
   
   // Update symbol rates
   m_symbol.RefreshRates();
   
   // Get current prices
   double ask = m_symbol.Ask();
   double bid = m_symbol.Bid();
   double point = m_symbol.Point();
   int digits = (int)m_symbol.Digits();
   
   // Update indicators
   m_ma.Refresh(-1);
   m_maFast.Refresh(-1);
   m_maSlow.Refresh(-1);
   m_atr.Refresh(-1);
   
   // Get indicator values
   double ma[3], maFast[3], maSlow[3];
   
   if(m_ma.GetData(1, 1, 0, 3, ma) != 3 ||
      m_maFast.GetData(1, 1, 0, 3, maFast) != 3 ||
      m_maSlow.GetData(1, 1, 0, 3, maSlow) != 3) {
      signal.comment = "Failed to get indicator data";
      return false;
   }
   
   // Get ATR value for volatility
   double atr[1];
   if(m_atr.GetData(1, 1, 0, 1, atr) != 1) {
      signal.comment = "Failed to get ATR data";
      return false;
   }
   
   // Calculate signal strength (0.0 to 1.0)
   double strength = 0.0;
   
   // Check for trend direction
   bool uptrend = ma[0] > ma[1] && ma[1] > ma[2];
   bool downtrend = ma[0] < ma[1] && ma[1] < ma[2];
   
   // Check for MA cross
   bool fastAboveSlow = maFast[0] > maSlow[0] && maFast[1] <= maSlow[1];  // Bullish cross
   bool fastBelowSlow = maFast[0] < maSlow[0] && maFast[1] >= maSlow[1];  // Bearish cross
   
   // Generate signals based on strategy
   if(uptrend && fastAboveSlow) {
      // Strong buy signal
      signal.type = SIGNAL_TYPE_BUY;
      signal.price = ask;
      signal.strength = 0.8 + (MathRand() % 20) / 100.0; // 0.8-1.0
      signal.comment = "Strong buy: Uptrend with bullish MA cross";
   }
   else if(downtrend && fastBelowSlow) {
      // Strong sell signal
      signal.type = SIGNAL_TYPE_SELL;
      signal.price = bid;
      signal.strength = 0.8 + (MathRand() % 20) / 100.0; // 0.8-1.0
      signal.comment = "Strong sell: Downtrend with bearish MA cross";
   }
   else if(fastAboveSlow) {
      // Weak buy signal
      signal.type = SIGNAL_TYPE_BUY;
      signal.price = ask;
      signal.strength = 0.5 + (MathRand() % 30) / 100.0; // 0.5-0.8
      signal.comment = "Buy: Bullish MA cross";
   }
   else if(fastBelowSlow) {
      // Weak sell signal
      signal.type = SIGNAL_TYPE_SELL;
      signal.price = bid;
      signal.strength = 0.5 + (MathRand() % 30) / 100.0; // 0.5-0.8
      signal.comment = "Sell: Bearish MA cross";
   }
   
   // If we have a valid signal, calculate SL/TP
   if(signal.type != SIGNAL_TYPE_NONE) {
      double atrValue = atr[0];
      
      if(signal.type == SIGNAL_TYPE_BUY) {
         signal.sl = signal.price - (atrValue * m_atrMultiplier);
         signal.tp = signal.price + (atrValue * m_atrMultiplier * 1.5); // 1.5:1 reward:risk
      }
      else if(signal.type == SIGNAL_TYPE_SELL) {
         signal.sl = signal.price + (atrValue * m_atrMultiplier);
         signal.tp = signal.price - (atrValue * m_atrMultiplier * 1.5); // 1.5:1 reward:risk
      }
      
      // Normalize prices
      signal.sl = NormalizeDouble(signal.sl, digits);
      signal.tp = NormalizeDouble(signal.tp, digits);
      signal.time = TimeCurrent();
   }
   
   return (signal.type != SIGNAL_TYPE_NONE);
}

//+------------------------------------------------------------------+
//| Convert signal type to string                                    |
//+------------------------------------------------------------------+
string CSignalGenerator::SignalTypeToString(ENUM_SIGNAL_TYPE type) {
   switch(type) {
      case SIGNAL_TYPE_BUY:   return "BUY";
      case SIGNAL_TYPE_SELL:  return "SELL";
      case SIGNAL_TYPE_CLOSE: return "CLOSE";
      default:                return "NONE";
   }
}
//+------------------------------------------------------------------+
