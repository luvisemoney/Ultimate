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
   m_initialized(false),
   m_symbol(NULL),
   m_maPeriod(0),
   m_maFastPeriod(0),
   m_maSlowPeriod(0),
   m_atrPeriod(0),
   m_atrMultiplier(0.0)
{
   // Initialize member variables in the initialization list
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSignalGenerator::~CSignalGenerator() {
   // Cleanup if needed
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
   if(symbol == NULL) {
      Print("Error: Invalid symbol pointer");
      return false;
   }
   
   if(maPeriod <= 0 || maFastPeriod <= 0 || maSlowPeriod <= 0 || atrPeriod <= 0 || atrMultiplier <= 0) {
      Print("Error: Invalid parameters");
      return false;
   }
   
   // Store parameters
   m_symbol = symbol;
   m_maPeriod = maPeriod;
   m_maFastPeriod = maFastPeriod;
   m_maSlowPeriod = maSlowPeriod;
   m_atrPeriod = atrPeriod;
   m_atrMultiplier = atrMultiplier;
   
   // Initialize indicators
   if(!InitializeIndicators()) {
      Print("Failed to initialize indicators");
      return false;
   }
   
   m_initialized = true;
   return true;
}

//+------------------------------------------------------------------+
//| Initialize technical indicators                                  |
//+------------------------------------------------------------------+
bool CSignalGenerator::InitializeIndicators() {
   // Initialize MA
   if(!m_ma.Create(m_symbol.Name(), PERIOD_CURRENT, m_maPeriod, 0, MODE_SMA, PRICE_CLOSE)) {
      Print("Failed to create MA indicator");
      return false;
   }
   
   // Initialize Fast MA
   if(!m_maFast.Create(m_symbol.Name(), PERIOD_CURRENT, m_maFastPeriod, 0, MODE_SMA, PRICE_CLOSE)) {
      Print("Failed to create Fast MA indicator");
      return false;
   }
   
   // Initialize Slow MA
   if(!m_maSlow.Create(m_symbol.Name(), PERIOD_CURRENT, m_maSlowPeriod, 0, MODE_SMA, PRICE_CLOSE)) {
      Print("Failed to create Slow MA indicator");
      return false;
   }
   
   // Initialize ATR
   if(!m_atr.Create(m_symbol.Name(), PERIOD_CURRENT, m_atrPeriod)) {
      Print("Failed to create ATR indicator");
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
      Print("Signal generator not properly initialized");
      return false;
   }
   
   // Update indicators
   if(m_ma.CalculateRates() == 0 || 
      m_maFast.CalculateRates() == 0 || 
      m_maSlow.CalculateRates() == 0 || 
      m_atr.CalculateRates() == 0) {
      Print("Failed to calculate indicator values");
      return false;
   }
   
   // Get current values
   double ma[3], maFast[3], maSlow[3];
   
   if(m_ma.GetData(0, 3, 0, ma) != 3 || 
      m_maFast.GetData(0, 3, 0, maFast) != 3 || 
      m_maSlow.GetData(0, 3, 0, maSlow) != 3) {
      Print("Failed to get indicator data");
      return false;
   }
   
   // Get ATR value for volatility
   double atr[1];
   if(m_atr.GetData(0, 1, 0, atr) != 1) {
      Print("Failed to get ATR data");
      return false;
   }
   
   // Simple crossover strategy
   if(maFast[0] > maSlow[0] && maFast[1] <= maSlow[1]) {
      // Bullish crossover
      signal.type = SIGNAL_TYPE_BUY;
      signal.price = m_symbol.Ask();
      signal.sl = signal.price - (atr[0] * m_atrMultiplier);
      signal.tp = signal.price + (2 * atr[0] * m_atrMultiplier); // 1:2 risk-reward
      signal.strength = 0.7; // Example strength
      signal.comment = "Bullish MA Crossover";
   }
   else if(maFast[0] < maSlow[0] && maFast[1] >= maSlow[1]) {
      // Bearish crossover
      signal.type = SIGNAL_TYPE_SELL;
      signal.price = m_symbol.Bid();
      signal.sl = signal.price + (atr[0] * m_atrMultiplier);
      signal.tp = signal.price - (2 * atr[0] * m_atrMultiplier); // 1:2 risk-reward
      signal.strength = 0.7; // Example strength
      signal.comment = "Bearish MA Crossover";
   }
   
   signal.time = TimeCurrent();
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
