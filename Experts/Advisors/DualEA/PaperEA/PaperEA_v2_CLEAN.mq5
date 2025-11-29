//+------------------------------------------------------------------+
//| PaperEA_v2_CLEAN.mq5 - CLEAN RECONSTRUCTION                      |
//| Multi-Strategy Paper Trading System - REAL IMPLEMENTATION        |
//+------------------------------------------------------------------+
#property copyright "DualEA Enhanced Paper System"
#property version   "2.1-CLEAN"
#property strict

//+------------------------------------------------------------------+
//| INCLUDES - ESSENTIAL ONLY                                          |
//+------------------------------------------------------------------+
// Core Interfaces
#include "..\Include\IStrategy.mqh"
#include "..\Include\TradeManager.mqh"
#include "..\Include\KnowledgeBase.mqh"

// Essential Managers
#include "..\Include\GateManager.mqh"
#include "..\Include\StrategySelector.mqh"
#include "..\Include\PolicyEngine.mqh"
#include "..\Include\ConfigManager.mqh"

// Telemetry & Logging
#include "..\Include\TelemetryStandard.mqh"
#include "..\Include\SessionManager.mqh"
#include "..\Include\CorrelationManager.mqh"
#include "..\Include\VolatilitySizer.mqh"

// Strategy Registry
#include "..\Include\Strategies\Registry.mqh"
#include "..\Include\Strategies\AssetRegistry.mqh"

// Standard Libraries
#include <Arrays/ArrayObj.mqh>
#include <Files/File.mqh>
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>
#include <Trade/DealInfo.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - CLEAN & ESSENTIAL                              |
//+------------------------------------------------------------------+

// Core Trading Parameters
input group "Trading Settings"
input double    LotSize = 0.01;                    // Position size (0=auto)
input int       MagicNumber = 12345;               // Magic number
input double    StopLossPips = 150.0;             // SL distance in pips
input double    TakeProfitPips = 300.0;           // TP distance in pips
input bool      TrailEnabled = true;              // Enable trailing
input int       TrailType = 2;                    // 0=fixed, 2=ATR

// Strategy Selection
input group "Strategy Control"
input bool      UseStrategySelector = true;       // Enable strategy selection
input double    SelW_PF = 1.0;                    // Profit factor weight
input double    SelW_Exp = 1.0;                   // Expectancy weight
input double    SelW_WR = 0.5;                    // Win rate weight
input bool      SelStrictThresholds = false;       // Use strict thresholds

// Gating System
input group "Gate System"
input bool      UseInsightsGating = true;         // Enable insights gating
input int       GateMinTrades = 20;               // Minimum trades for gating
input double    GateMinWinRate = 0.50;            // Minimum win rate
input bool      ExploreOnNoSlice = true;          // Explore when no data
input int       ExploreMaxPerSlice = 100;         // Max exploration trades

// Risk Management
input group "Risk Management"
input int       MaxOpenPositions = 5;             // Max concurrent positions
input bool      UseCircuitBreakers = true;        // Enable circuit breakers
input double    CBDailyLossLimitPct = 5.0;        // Daily loss limit %
input double    CBDrawdownLimitPct = 10.0;        // Drawdown limit %

// Policy Engine
input group "ML Policy"
input bool      UsePolicyGating = true;           // Enable ML policy
input bool      DefaultPolicyFallback = true;     // Fallback when no policy
input string    PolicyFilePath = "DualEA\\policy.json";

// External Tools
input group "External Integration"
input bool      UseSQLiteLogging = true;          // SQLite database logging
input bool      UsePythonML = true;               // Python ML integration
input string    PythonServerUrl = "http://127.0.0.1:8000";

// Telemetry
input group "Monitoring"
input bool      TelemetryEnabled = true;          // Enable telemetry
input string    TelemetryExperiment = "paper_v2";  // Experiment name
input int       Verbosity = 2;                    // Log level (0-3)

//+------------------------------------------------------------------+
//| GLOBAL STATE - CLEAN & MINIMAL                                    |
//+------------------------------------------------------------------+

// Asset Class Enum
enum EAssetClass
{
   ASSET_UNKNOWN,
   ASSET_FX_MAJOR,
   ASSET_FX_MINOR,
   ASSET_FX_EXOTIC,
   ASSET_CRYPTO,
   ASSET_METAL,
   ASSET_INDEX,
   ASSET_ENERGY,
   ASSET_COMMODITY
};

// Trading Signal Structure
struct TradingSignal
{
   string id;
   string symbol;
   int timeframe;
   datetime timestamp;
   double price;
   int type;  // 0=buy, 1=sell
   double sl;
   double tp;
   double volume;
   double confidence;
   string strategy;
   double volatility;
   double correlation;
   string regime;
   string market_regime;
};

// Signal Decision Structure
struct CSignalDecision
{
   string signal_id;
   double original_sl;
   double original_tp;
   double original_volume;
   double final_sl;
   double final_tp;
   double final_volume;
   double final_price;
   double confidence;
   bool passed;
};

// Core Managers
CTradeManager         *g_trade_manager = NULL;
CStrategySelector     *g_strategy_selector = NULL;
CGateManager          *g_gate_manager = NULL;
CPolicyEngine         *g_policy_engine = NULL;
CKnowledgeBase        *g_knowledge_base = NULL;
CTelemetryStandard    *g_telemetry = NULL;
CSessionManager       *g_session_manager = NULL;
CCorrelationManager   *g_correlation_manager = NULL;
CVolatilitySizer      *g_volatility_sizer = NULL;

// Strategy Registry
CAssetRegistry         *g_asset_registry = NULL;

// State Tracking
datetime               g_last_trade_time = 0;
bool                   g_initialized = false;
int                    g_total_trades = 0;
int                    g_winning_trades = 0;

//+------------------------------------------------------------------+
//| UTILITY FUNCTIONS                                                  |
//+------------------------------------------------------------------+

// Logging helper
void LOG(string message, int level = LOG_INFO)
{
   if(level <= Verbosity)
      Print("[PaperEA_v2] ", message);
   
   if(TelemetryEnabled && CheckPointer(g_telemetry) != POINTER_INVALID)
      g_telemetry.LogEvent(_Symbol, _Period, "SYSTEM", "LOG", message);
}

// Error checking
bool ShouldLog(int level) { return (level <= Verbosity); }

// Log levels
#define LOG_ERROR 0
#define LOG_WARN 1
#define LOG_INFO 2
#define LOG_DEBUG 3

// Asset class detection
EAssetClass DetectAssetClass(const string symbol)
{
   string s = symbol; StringToUpper(s);
   if(StringFind(s, "BTC")>=0 || StringFind(s, "ETH")>=0) return ASSET_CRYPTO;
   if(StringFind(s, "XAU")>=0 || StringFind(s, "XAG")>=0) return ASSET_METAL;
   if(StringFind(s, "US500")>=0 || StringFind(s, "NAS100")>=0) return ASSET_INDEX;
   if(StringFind(s, "WTI")>=0 || StringFind(s, "UKOIL")>=0) return ASSET_ENERGY;
   if(StringFind(s, "USD")>=0 || StringFind(s, "EUR")>=0) return ASSET_FX_MAJOR;
   return ASSET_UNKNOWN;
}

//+------------------------------------------------------------------+
//| STRATEGY ENGINE - REAL MULTI-STRATEGY IMPLEMENTATION             |
//+------------------------------------------------------------------+

// Generate signal from specific strategy
TradingSignal GenerateSignalFromStrategy(const string strategy_name)
{
   TradingSignal signal = {};
   
   // Initialize signal structure
   signal.symbol = _Symbol;
   signal.timeframe = _Period;
   signal.timestamp = TimeCurrent();
   signal.strategy = strategy_name;
   signal.id = strategy_name + "_" + IntegerToString(TimeCurrent());
   
   // Get current price
   double bid = 0.0, ask = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   
   // Calculate ATR for SL/TP
   double atr = 0.0;
   int atr_handle = iATR(_Symbol, _Period, 14);
   if(atr_handle != INVALID_HANDLE)
   {
      double atr_arr[1];
      if(CopyBuffer(atr_handle, 0, 0, 1, atr_arr) == 1)
         atr = atr_arr[0];
      IndicatorRelease(atr_handle);
   }
   
   // Fallback ATR
   if(atr <= 0.0)
   {
      double point = 0.0;
      SymbolInfoDouble(_Symbol, SYMBOL_POINT, point);
      atr = 100.0 * point; // Minimum fallback
   }
   
   double sl_distance = atr * (StopLossPips / 100.0);
   double tp_distance = atr * (TakeProfitPips / 100.0);
   
   // STRATEGY IMPLEMENTATIONS
   if(strategy_name == "ADXStrategy")
   {
      signal = GenerateADXSignal(bid, ask, sl_distance, tp_distance);
   }
   else if(strategy_name == "RSIStrategy")
   {
      signal = GenerateRSISignal(bid, ask, sl_distance, tp_distance);
   }
   else if(strategy_name == "MACDStrategy")
   {
      signal = GenerateMACDSignal(bid, ask, sl_distance, tp_distance);
   }
   else if(strategy_name == "MovingAverageStrategy")
   {
      signal = GenerateMASignal(bid, ask, sl_distance, tp_distance);
   }
   else if(strategy_name == "BollingerStrategy")
   {
      signal = GenerateBollingerSignal(bid, ask, sl_distance, tp_distance);
   }
   else if(strategy_name == "AlligatorStrategy")
   {
      signal = GenerateAlligatorSignal(bid, ask, sl_distance, tp_distance);
   }
   else if(strategy_name == "AwesomeOscillatorStrategy")
   {
      signal = GenerateAwesomeOscillatorSignal(bid, ask, sl_distance, tp_distance);
   }
   else if(strategy_name == "BearsPowerStrategy")
   {
      signal = GenerateBearsPowerSignal(bid, ask, sl_distance, tp_distance);
   }
   else if(strategy_name == "BullsPowerStrategy")
   {
      signal = GenerateBullsPowerSignal(bid, ask, sl_distance, tp_distance);
   }
   else if(strategy_name == "CCIStrategy")
   {
      signal = GenerateCCISignal(bid, ask, sl_distance, tp_distance);
   }
   else if(strategy_name == "DeMarkerStrategy")
   {
      signal = GenerateDeMarkerSignal(bid, ask, sl_distance, tp_distance);
   }
   else if(strategy_name == "ForceIndexStrategy")
   {
      signal = GenerateForceIndexSignal(bid, ask, sl_distance, tp_distance);
   }
   else if(strategy_name == "FractalsStrategy")
   {
      signal = GenerateFractalsSignal(bid, ask, sl_distance, tp_distance);
   }
   else if(strategy_name == "GatorStrategy")
   {
      signal = GenerateGatorSignal(bid, ask, sl_distance, tp_distance);
   }
   else if(strategy_name == "IchimokuStrategy")
   {
      signal = GenerateIchimokuSignal(bid, ask, sl_distance, tp_distance);
   }
   else if(strategy_name == "MomentumStrategy")
   {
      signal = GenerateMomentumSignal(bid, ask, sl_distance, tp_distance);
   }
   else if(strategy_name == "OsMAStrategy")
   {
      signal = GenerateOsMASignal(bid, ask, sl_distance, tp_distance);
   }
   else if(strategy_name == "RVIStrategy")
   {
      signal = GenerateRVISignal(bid, ask, sl_distance, tp_distance);
   }
   else if(strategy_name == "StochasticStrategy")
   {
      signal = GenerateStochasticSignal(bid, ask, sl_distance, tp_distance);
   }
   else if(strategy_name == "TriXStrategy")
   {
      signal = GenerateTriXSignal(bid, ask, sl_distance, tp_distance);
   }
   else if(strategy_name == "UltimateOscillatorStrategy")
   {
      signal = GenerateUltimateOscillatorSignal(bid, ask, sl_distance, tp_distance);
   }
   else if(strategy_name == "WilliamsPercentRangeStrategy")
   {
      signal = GenerateWilliamsPercentRangeSignal(bid, ask, sl_distance, tp_distance);
   }
   else if(strategy_name == "ZigZagStrategy")
   {
      signal = GenerateZigZagSignal(bid, ask, sl_distance, tp_distance);
   }
   else
   {
      // Fallback to MA strategy for unknown strategies
      signal = GenerateMASignal(bid, ask, sl_distance, tp_distance);
      signal.strategy = "MovingAverageStrategy"; // Override with actual
   }
   
   // Set common fields
   signal.volatility = GetVolatility(_Symbol, _Period);
   signal.correlation = GetCorrelation();
   signal.regime = GetMarketRegime();
   
   return signal;
}

// ADX Strategy Implementation
TradingSignal GenerateADXSignal(double bid, double ask, double sl_dist, double tp_dist)
{
   TradingSignal signal = {};
   
   int adx_handle = iADX(_Symbol, _Period, 14);
   if(adx_handle == INVALID_HANDLE) return signal;
   
   double adx_arr[1], plus_di_arr[1], minus_di_arr[1];
   if(CopyBuffer(adx_handle, 0, 0, 1, adx_arr) == 1 &&
      CopyBuffer(adx_handle, 1, 0, 1, plus_di_arr) == 1 &&
      CopyBuffer(adx_handle, 2, 0, 1, minus_di_arr) == 1)
   {
      double adx = adx_arr[0];
      double plus_di = plus_di_arr[0];
      double minus_di = minus_di_arr[0];
      
      if(adx > 25) // Trend strength threshold
      {
         if(plus_di > minus_di)
         {
            signal.type = 0; // BUY
            signal.price = ask;
            signal.sl = ask - sl_dist;
            signal.tp = ask + tp_dist;
            signal.confidence = MathMin(0.9, adx / 50.0);
         }
         else
         {
            signal.type = 1; // SELL
            signal.price = bid;
            signal.sl = bid + sl_dist;
            signal.tp = bid - tp_dist;
            signal.confidence = MathMin(0.9, adx / 50.0);
         }
      }
   }
   
   IndicatorRelease(adx_handle);
   return signal;
}

// RSI Strategy Implementation  
TradingSignal GenerateRSISignal(double bid, double ask, double sl_dist, double tp_dist)
{
   TradingSignal signal = {};
   
   int rsi_handle = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
   if(rsi_handle == INVALID_HANDLE) return signal;
   
   double rsi_arr[1];
   if(CopyBuffer(rsi_handle, 0, 0, 1, rsi_arr) == 1)
   {
      double rsi = rsi_arr[0];
      
      if(rsi < 30) // Oversold
      {
         signal.type = 0; // BUY
         signal.price = ask;
         signal.sl = ask - sl_dist;
         signal.tp = ask + tp_dist;
         signal.confidence = (30.0 - rsi) / 30.0;
      }
      else if(rsi > 70) // Overbought
      {
         signal.type = 1; // SELL
         signal.price = bid;
         signal.sl = bid + sl_dist;
         signal.tp = bid - tp_dist;
         signal.confidence = (rsi - 70.0) / 30.0;
      }
   }
   
   IndicatorRelease(rsi_handle);
   return signal;
}

// MACD Strategy Implementation
TradingSignal GenerateMACDSignal(double bid, double ask, double sl_dist, double tp_dist)
{
   TradingSignal signal = {};
   
   int macd_handle = iMACD(_Symbol, _Period, 12, 26, 9, PRICE_CLOSE);
   if(macd_handle == INVALID_HANDLE) return signal;
   
   double macd_main_arr[1], macd_signal_arr[1];
   if(CopyBuffer(macd_handle, 0, 0, 1, macd_main_arr) == 1 &&
      CopyBuffer(macd_handle, 1, 0, 1, macd_signal_arr) == 1)
   {
      double macd_main = macd_main_arr[0];
      double macd_signal = macd_signal_arr[0];
      
      if(macd_main > macd_signal && macd_main < 0) // Bullish crossover below zero
      {
         signal.type = 0; // BUY
         signal.price = ask;
         signal.sl = ask - sl_dist;
         signal.tp = ask + tp_dist;
         signal.confidence = 0.7;
      }
      else if(macd_main < macd_signal && macd_main > 0) // Bearish crossover above zero
      {
         signal.type = 1; // SELL
         signal.price = bid;
         signal.sl = bid + sl_dist;
         signal.tp = bid - tp_dist;
         signal.confidence = 0.7;
      }
   }
   
   IndicatorRelease(macd_handle);
   return signal;
}

// Moving Average Strategy Implementation
TradingSignal GenerateMASignal(double bid, double ask, double sl_dist, double tp_dist)
{
   TradingSignal signal = {};
   
   int fast_ma = iMA(_Symbol, _Period, 20, 0, MODE_SMA, PRICE_CLOSE);
   int slow_ma = iMA(_Symbol, _Period, 50, 0, MODE_SMA, PRICE_CLOSE);
   
   if(fast_ma != INVALID_HANDLE && slow_ma != INVALID_HANDLE)
   {
      double fast_arr[1], slow_arr[1];
      if(CopyBuffer(fast_ma, 0, 0, 1, fast_arr) == 1 &&
         CopyBuffer(slow_ma, 0, 0, 1, slow_arr) == 1)
      {
         double fast = fast_arr[0];
         double slow = slow_arr[0];
         
         if(fast > slow && ask > fast) // Price above fast MA
         {
            signal.type = 0; // BUY
            signal.price = ask;
            signal.sl = ask - sl_dist;
            signal.tp = ask + tp_dist;
            signal.confidence = 0.6;
         }
         else if(fast < slow && bid < fast) // Price below fast MA
         {
            signal.type = 1; // SELL
            signal.price = bid;
            signal.sl = bid + sl_dist;
            signal.tp = bid - tp_dist;
            signal.confidence = 0.6;
         }
      }
   }
   
   if(fast_ma != INVALID_HANDLE) IndicatorRelease(fast_ma);
   if(slow_ma != INVALID_HANDLE) IndicatorRelease(slow_ma);
   return signal;
}

// Bollinger Bands Strategy Implementation
TradingSignal GenerateBollingerSignal(double bid, double ask, double sl_dist, double tp_dist)
{
   TradingSignal signal = {};
   
   int bb_handle = iBands(_Symbol, _Period, 20, 0, 2.0, PRICE_CLOSE);
   if(bb_handle == INVALID_HANDLE) return signal;
   
   double bb_upper_arr[1], bb_lower_arr[1], bb_middle_arr[1];
   if(CopyBuffer(bb_handle, 1, 0, 1, bb_upper_arr) == 1 &&
      CopyBuffer(bb_handle, 2, 0, 1, bb_lower_arr) == 1 &&
      CopyBuffer(bb_handle, 0, 0, 1, bb_middle_arr) == 1)
   {
      double upper = bb_upper_arr[0];
      double lower = bb_lower_arr[0];
      double middle = bb_middle_arr[0];
      
      if(bid <= lower) // Price at or below lower band
      {
         signal.type = 0; // BUY
         signal.price = ask;
         signal.sl = lower - sl_dist;
         signal.tp = middle + tp_dist;
         signal.confidence = 0.8;
      }
      else if(ask >= upper) // Price at or above upper band
      {
         signal.type = 1; // SELL
         signal.price = bid;
         signal.sl = upper + sl_dist;
         signal.tp = middle - tp_dist;
         signal.confidence = 0.8;
      }
   }
   
   IndicatorRelease(bb_handle);
   return signal;
}

// Alligator Strategy Implementation
TradingSignal GenerateAlligatorSignal(double bid, double ask, double sl_dist, double tp_dist)
{
   TradingSignal signal = {};
   
   int gator_handle = iAlligator(_Symbol, _Period, 13, 8, 8, 5, 5, 3, MODE_SMMA, PRICE_MEDIAN);
   if(gator_handle == INVALID_HANDLE) return signal;
   
   double jaw_arr[1], teeth_arr[1], lips_arr[1];
   if(CopyBuffer(gator_handle, 0, 0, 1, jaw_arr) == 1 &&
      CopyBuffer(gator_handle, 1, 0, 1, teeth_arr) == 1 &&
      CopyBuffer(gator_handle, 2, 0, 1, lips_arr) == 1)
   {
      double jaw = jaw_arr[0];
      double teeth = teeth_arr[0];
      double lips = lips_arr[0];
      
      // Bullish signal: lips above teeth above jaw
      if(lips > teeth && teeth > jaw && ask > lips)
      {
         signal.type = 0; // BUY
         signal.price = ask;
         signal.sl = ask - sl_dist;
         signal.tp = ask + tp_dist;
         signal.confidence = 0.7;
      }
      // Bearish signal: lips below teeth below jaw
      else if(lips < teeth && teeth < jaw && bid < lips)
      {
         signal.type = 1; // SELL
         signal.price = bid;
         signal.sl = bid + sl_dist;
         signal.tp = bid - tp_dist;
         signal.confidence = 0.7;
      }
   }
   
   IndicatorRelease(gator_handle);
   return signal;
}

// Awesome Oscillator Strategy Implementation
TradingSignal GenerateAwesomeOscillatorSignal(double bid, double ask, double sl_dist, double tp_dist)
{
   TradingSignal signal = {};
   
   int ao_handle = iAO(_Symbol, _Period);
   if(ao_handle == INVALID_HANDLE) return signal;
   
   double ao_arr[2]; // Need current and previous
   if(CopyBuffer(ao_handle, 0, 0, 2, ao_arr) == 2)
   {
      double ao_current = ao_arr[1];
      double ao_previous = ao_arr[0];
      
      // Bullish crossover
      if(ao_previous < 0 && ao_current > 0)
      {
         signal.type = 0; // BUY
         signal.price = ask;
         signal.sl = ask - sl_dist;
         signal.tp = ask + tp_dist;
         signal.confidence = 0.6;
      }
      // Bearish crossover
      else if(ao_previous > 0 && ao_current < 0)
      {
         signal.type = 1; // SELL
         signal.price = bid;
         signal.sl = bid + sl_dist;
         signal.tp = bid - tp_dist;
         signal.confidence = 0.6;
      }
   }
   
   IndicatorRelease(ao_handle);
   return signal;
}

// Bears Power Strategy Implementation
TradingSignal GenerateBearsPowerSignal(double bid, double ask, double sl_dist, double tp_dist)
{
   TradingSignal signal = {};
   
   int bears_handle = iBearsPower(_Symbol, _Period, 13);
   if(bears_handle == INVALID_HANDLE) return signal;
   
   double ema_handle = iMA(_Symbol, _Period, 13, 0, MODE_EMA, PRICE_CLOSE);
   if(ema_handle == INVALID_HANDLE) { IndicatorRelease(bears_handle); return signal; }
   
   double bears_arr[1], ema_arr[1];
   if(CopyBuffer(bears_handle, 0, 0, 1, bears_arr) == 1 &&
      CopyBuffer(ema_handle, 0, 0, 1, ema_arr) == 1)
   {
      double bears = bears_arr[0];
      double ema = ema_arr[0];
      
      // Buy signal: bears power negative but rising (bullish divergence)
      if(bears < 0 && bid > ema)
      {
         signal.type = 0; // BUY
         signal.price = ask;
         signal.sl = ask - sl_dist;
         signal.tp = ask + tp_dist;
         signal.confidence = MathMin(0.8, MathAbs(bears) / ema);
      }
   }
   
   IndicatorRelease(bears_handle);
   IndicatorRelease(ema_handle);
   return signal;
}

// Bulls Power Strategy Implementation
TradingSignal GenerateBullsPowerSignal(double bid, double ask, double sl_dist, double tp_dist)
{
   TradingSignal signal = {};
   
   int bulls_handle = iBullsPower(_Symbol, _Period, 13);
   if(bulls_handle == INVALID_HANDLE) return signal;
   
   double ema_handle = iMA(_Symbol, _Period, 13, 0, MODE_EMA, PRICE_CLOSE);
   if(ema_handle == INVALID_HANDLE) { IndicatorRelease(bulls_handle); return signal; }
   
   double bulls_arr[1], ema_arr[1];
   if(CopyBuffer(bulls_handle, 0, 0, 1, bulls_arr) == 1 &&
      CopyBuffer(ema_handle, 0, 0, 1, ema_arr) == 1)
   {
      double bulls = bulls_arr[0];
      double ema = ema_arr[0];
      
      // Sell signal: bulls power positive but falling (bearish divergence)
      if(bulls > 0 && bid < ema)
      {
         signal.type = 1; // SELL
         signal.price = bid;
         signal.sl = bid + sl_dist;
         signal.tp = bid - tp_dist;
         signal.confidence = MathMin(0.8, bulls / ema);
      }
   }
   
   IndicatorRelease(bulls_handle);
   IndicatorRelease(ema_handle);
   return signal;
}

// CCI Strategy Implementation
TradingSignal GenerateCCISignal(double bid, double ask, double sl_dist, double tp_dist)
{
   TradingSignal signal = {};
   
   int cci_handle = iCCI(_Symbol, _Period, 14, PRICE_TYPICAL);
   if(cci_handle == INVALID_HANDLE) return signal;
   
   double cci_arr[2]; // Current and previous
   if(CopyBuffer(cci_handle, 0, 0, 2, cci_arr) == 2)
   {
      double cci_current = cci_arr[1];
      double cci_previous = cci_arr[0];
      
      // Oversold signal
      if(cci_current < -100 && cci_previous >= -100)
      {
         signal.type = 0; // BUY
         signal.price = ask;
         signal.sl = ask - sl_dist;
         signal.tp = ask + tp_dist;
         signal.confidence = MathMin(0.9, MathAbs(cci_current) / 200.0);
      }
      // Overbought signal
      else if(cci_current > 100 && cci_previous <= 100)
      {
         signal.type = 1; // SELL
         signal.price = bid;
         signal.sl = bid + sl_dist;
         signal.tp = bid - tp_dist;
         signal.confidence = MathMin(0.9, cci_current / 200.0);
      }
   }
   
   IndicatorRelease(cci_handle);
   return signal;
}

// DeMarker Strategy Implementation
TradingSignal GenerateDeMarkerSignal(double bid, double ask, double sl_dist, double tp_dist)
{
   TradingSignal signal = {};
   
   int demarker_handle = iDeMarker(_Symbol, _Period, 14);
   if(demarker_handle == INVALID_HANDLE) return signal;
   
   double demarker_arr[2];
   if(CopyBuffer(demarker_handle, 0, 0, 2, demarker_arr) == 2)
   {
      double dem_current = demarker_arr[1];
      double dem_previous = demarker_arr[0];
      
      // Oversold signal
      if(dem_current < 0.3 && dem_previous >= 0.3)
      {
         signal.type = 0; // BUY
         signal.price = ask;
         signal.sl = ask - sl_dist;
         signal.tp = ask + tp_dist;
         signal.confidence = 0.7;
      }
      // Overbought signal
      else if(dem_current > 0.7 && dem_previous <= 0.7)
      {
         signal.type = 1; // SELL
         signal.price = bid;
         signal.sl = bid + sl_dist;
         signal.tp = bid - tp_dist;
         signal.confidence = 0.7;
      }
   }
   
   IndicatorRelease(demarker_handle);
   return signal;
}

// Force Index Strategy Implementation
TradingSignal GenerateForceIndexSignal(double bid, double ask, double sl_dist, double tp_dist)
{
   TradingSignal signal = {};
   
   int force_handle = iForce(_Symbol, _Period, 13, MODE_EMA, PRICE_CLOSE);
   if(force_handle == INVALID_HANDLE) return signal;
   
   double force_arr[2];
   if(CopyBuffer(force_handle, 0, 0, 2, force_arr) == 2)
   {
      double force_current = force_arr[1];
      double force_previous = force_arr[0];
      
      // Bullish signal: force crosses above zero
      if(force_previous < 0 && force_current > 0)
      {
         signal.type = 0; // BUY
         signal.price = ask;
         signal.sl = ask - sl_dist;
         signal.tp = ask + tp_dist;
         signal.confidence = MathMin(0.8, force_current / 100.0);
      }
      // Bearish signal: force crosses below zero
      else if(force_previous > 0 && force_current < 0)
      {
         signal.type = 1; // SELL
         signal.price = bid;
         signal.sl = bid + sl_dist;
         signal.tp = bid - tp_dist;
         signal.confidence = MathMin(0.8, MathAbs(force_current) / 100.0);
      }
   }
   
   IndicatorRelease(force_handle);
   return signal;
}

// Fractals Strategy Implementation
TradingSignal GenerateFractalsSignal(double bid, double ask, double sl_dist, double tp_dist)
{
   TradingSignal signal = {};
   
   int fractals_handle = iFractals(_Symbol, _Period);
   if(fractals_handle == INVALID_HANDLE) return signal;
   
   double upper_fractals[3], lower_fractals[3];
   if(CopyBuffer(fractals_handle, 0, 1, 3, upper_fractals) == 3 &&
      CopyBuffer(fractals_handle, 1, 1, 3, lower_fractals) == 3)
   {
      // Check for upper fractal (sell signal)
      if(upper_fractals[1] > 0 && bid < upper_fractals[1])
      {
         signal.type = 1; // SELL
         signal.price = bid;
         signal.sl = upper_fractals[1] + sl_dist;
         signal.tp = bid - tp_dist;
         signal.confidence = 0.6;
      }
      // Check for lower fractal (buy signal)
      else if(lower_fractals[1] > 0 && ask > lower_fractals[1])
      {
         signal.type = 0; // BUY
         signal.price = ask;
         signal.sl = lower_fractals[1] - sl_dist;
         signal.tp = ask + tp_dist;
         signal.confidence = 0.6;
      }
   }
   
   IndicatorRelease(fractals_handle);
   return signal;
}

// Gator Oscillator Strategy Implementation
TradingSignal GenerateGatorSignal(double bid, double ask, double sl_dist, double tp_dist)
{
   TradingSignal signal = {};
   
   int gator_handle = iGator(_Symbol, _Period, 13, 8, 8, 5, 5, 3, MODE_SMMA, PRICE_MEDIAN);
   if(gator_handle == INVALID_HANDLE) return signal;
   
   double gator_up[2], gator_down[2];
   if(CopyBuffer(gator_handle, 0, 0, 2, gator_up) == 2 &&
      CopyBuffer(gator_handle, 1, 0, 2, gator_down) == 2)
   {
      // Bullish signal: gator up crosses above zero
      if(gator_up[1] > 0 && gator_up[0] <= 0)
      {
         signal.type = 0; // BUY
         signal.price = ask;
         signal.sl = ask - sl_dist;
         signal.tp = ask + tp_dist;
         signal.confidence = 0.6;
      }
      // Bearish signal: gator down crosses below zero
      else if(gator_down[1] < 0 && gator_down[0] >= 0)
      {
         signal.type = 1; // SELL
         signal.price = bid;
         signal.sl = bid + sl_dist;
         signal.tp = bid - tp_dist;
         signal.confidence = 0.6;
      }
   }
   
   IndicatorRelease(gator_handle);
   return signal;
}

// Ichimoku Strategy Implementation
TradingSignal GenerateIchimokuSignal(double bid, double ask, double sl_dist, double tp_dist)
{
   TradingSignal signal = {};
   
   int ichimoku_handle = iIchimoku(_Symbol, _Period, 9, 26, 52);
   if(ichimoku_handle == INVALID_HANDLE) return signal;
   
   double tenkan_arr[1], kijun_arr[1], senkou_a_arr[1], senkou_b_arr[1], chikou_arr[1];
   if(CopyBuffer(ichimoku_handle, 0, 0, 1, tenkan_arr) == 1 &&
      CopyBuffer(ichimoku_handle, 1, 0, 1, kijun_arr) == 1 &&
      CopyBuffer(ichimoku_handle, 2, 0, 1, senkou_a_arr) == 1 &&
      CopyBuffer(ichimoku_handle, 3, 0, 1, senkou_b_arr) == 1 &&
      CopyBuffer(ichimoku_handle, 4, 1, 1, chikou_arr) == 1) // Chikou span shifted
   {
      double tenkan = tenkan_arr[0];
      double kijun = kijun_arr[0];
      double senkou_a = senkou_a_arr[0];
      double senkou_b = senkou_b_arr[0];
      double chikou = chikou_arr[0];
      
      // Bullish signal: tenkan crosses above kijun and price above cloud
      if(tenkan > kijun && ask > MathMax(senkou_a, senkou_b))
      {
         signal.type = 0; // BUY
         signal.price = ask;
         signal.sl = ask - sl_dist;
         signal.tp = ask + tp_dist;
         signal.confidence = 0.7;
      }
      // Bearish signal: tenkan crosses below kijun and price below cloud
      else if(tenkan < kijun && bid < MathMin(senkou_a, senkou_b))
      {
         signal.type = 1; // SELL
         signal.price = bid;
         signal.sl = bid + sl_dist;
         signal.tp = bid - tp_dist;
         signal.confidence = 0.7;
      }
   }
   
   IndicatorRelease(ichimoku_handle);
   return signal;
}

// Momentum Strategy Implementation
TradingSignal GenerateMomentumSignal(double bid, double ask, double sl_dist, double tp_dist)
{
   TradingSignal signal = {};
   
   int momentum_handle = iMomentum(_Symbol, _Period, 10, PRICE_CLOSE);
   if(momentum_handle == INVALID_HANDLE) return signal;
   
   double momentum_arr[2];
   if(CopyBuffer(momentum_handle, 0, 0, 2, momentum_arr) == 2)
   {
      double mom_current = momentum_arr[1];
      double mom_previous = momentum_arr[0];
      
      // Bullish signal: momentum crosses above 100
      if(mom_previous <= 100.0 && mom_current > 100.0)
      {
         signal.type = 0; // BUY
         signal.price = ask;
         signal.sl = ask - sl_dist;
         signal.tp = ask + tp_dist;
         signal.confidence = MathMin(0.8, (mom_current - 100.0) / 50.0);
      }
      // Bearish signal: momentum crosses below 100
      else if(mom_previous >= 100.0 && mom_current < 100.0)
      {
         signal.type = 1; // SELL
         signal.price = bid;
         signal.sl = bid + sl_dist;
         signal.tp = bid - tp_dist;
         signal.confidence = MathMin(0.8, (100.0 - mom_current) / 50.0);
      }
   }
   
   IndicatorRelease(momentum_handle);
   return signal;
}

// OsMA Strategy Implementation
TradingSignal GenerateOsMASignal(double bid, double ask, double sl_dist, double tp_dist)
{
   TradingSignal signal = {};
   
   int osma_handle = iOsMA(_Symbol, _Period, 12, 26, 9, PRICE_CLOSE);
   if(osma_handle == INVALID_HANDLE) return signal;
   
   double osma_arr[2];
   if(CopyBuffer(osma_handle, 0, 0, 2, osma_arr) == 2)
   {
      double osma_current = osma_arr[1];
      double osma_previous = osma_arr[0];
      
      // Bullish signal: OsMA crosses above zero
      if(osma_previous <= 0 && osma_current > 0)
      {
         signal.type = 0; // BUY
         signal.price = ask;
         signal.sl = ask - sl_dist;
         signal.tp = ask + tp_dist;
         signal.confidence = MathMin(0.7, osma_current / 0.001);
      }
      // Bearish signal: OsMA crosses below zero
      else if(osma_previous >= 0 && osma_current < 0)
      {
         signal.type = 1; // SELL
         signal.price = bid;
         signal.sl = bid + sl_dist;
         signal.tp = bid - tp_dist;
         signal.confidence = MathMin(0.7, MathAbs(osma_current) / 0.001);
      }
   }
   
   IndicatorRelease(osma_handle);
   return signal;
}

// RVI Strategy Implementation
TradingSignal GenerateRVISignal(double bid, double ask, double sl_dist, double tp_dist)
{
   TradingSignal signal = {};
   
   int rvi_handle = iRVI(_Symbol, _Period);
   if(rvi_handle == INVALID_HANDLE) return signal;
   
   double rvi_main_arr[2], rvi_signal_arr[2];
   if(CopyBuffer(rvi_handle, 0, 0, 2, rvi_main_arr) == 2 &&
      CopyBuffer(rvi_handle, 1, 0, 2, rvi_signal_arr) == 2)
   {
      double rvi_main_current = rvi_main_arr[1];
      double rvi_signal_current = rvi_signal_arr[1];
      double rvi_main_previous = rvi_main_arr[0];
      double rvi_signal_previous = rvi_signal_arr[0];
      
      // Bullish crossover
      if(rvi_main_previous <= rvi_signal_previous && rvi_main_current > rvi_signal_current)
      {
         signal.type = 0; // BUY
         signal.price = ask;
         signal.sl = ask - sl_dist;
         signal.tp = ask + tp_dist;
         signal.confidence = 0.6;
      }
      // Bearish crossover
      else if(rvi_main_previous >= rvi_signal_previous && rvi_main_current < rvi_signal_current)
      {
         signal.type = 1; // SELL
         signal.price = bid;
         signal.sl = bid + sl_dist;
         signal.tp = bid - tp_dist;
         signal.confidence = 0.6;
      }
   }
   
   IndicatorRelease(rvi_handle);
   return signal;
}

// Stochastic Strategy Implementation
TradingSignal GenerateStochasticSignal(double bid, double ask, double sl_dist, double tp_dist)
{
   TradingSignal signal = {};
   
   int stoch_handle = iStochastic(_Symbol, _Period, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
   if(stoch_handle == INVALID_HANDLE) return signal;
   
   double stoch_main_arr[2], stoch_signal_arr[2];
   if(CopyBuffer(stoch_handle, 0, 0, 2, stoch_main_arr) == 2 &&
      CopyBuffer(stoch_handle, 1, 0, 2, stoch_signal_arr) == 2)
   {
      double stoch_main_current = stoch_main_arr[1];
      double stoch_signal_current = stoch_signal_arr[1];
      double stoch_main_previous = stoch_main_arr[0];
      
      // Bullish crossover in oversold
      if(stoch_main_current > stoch_signal_current && stoch_main_previous <= stoch_signal_arr[0] && stoch_main_current < 20)
      {
         signal.type = 0; // BUY
         signal.price = ask;
         signal.sl = ask - sl_dist;
         signal.tp = ask + tp_dist;
         signal.confidence = 0.8;
      }
      // Bearish crossover in overbought
      else if(stoch_main_current < stoch_signal_current && stoch_main_previous >= stoch_signal_arr[0] && stoch_main_current > 80)
      {
         signal.type = 1; // SELL
         signal.price = bid;
         signal.sl = bid + sl_dist;
         signal.tp = bid - tp_dist;
         signal.confidence = 0.8;
      }
   }
   
   IndicatorRelease(stoch_handle);
   return signal;
}

// TriX Strategy Implementation
TradingSignal GenerateTriXSignal(double bid, double ask, double sl_dist, double tp_dist)
{
   TradingSignal signal = {};
   
   int trix_handle = iTriX(_Symbol, _Period, 12);
   if(trix_handle == INVALID_HANDLE) return signal;
   
   double trix_arr[2];
   if(CopyBuffer(trix_handle, 0, 0, 2, trix_arr) == 2)
   {
      double trix_current = trix_arr[1];
      double trix_previous = trix_arr[0];
      
      // Bullish signal: TriX crosses above zero
      if(trix_previous <= 0 && trix_current > 0)
      {
         signal.type = 0; // BUY
         signal.price = ask;
         signal.sl = ask - sl_dist;
         signal.tp = ask + tp_dist;
         signal.confidence = 0.6;
      }
      // Bearish signal: TriX crosses below zero
      else if(trix_previous >= 0 && trix_current < 0)
      {
         signal.type = 1; // SELL
         signal.price = bid;
         signal.sl = bid + sl_dist;
         signal.tp = bid - tp_dist;
         signal.confidence = 0.6;
      }
   }
   
   IndicatorRelease(trix_handle);
   return signal;
}

// Ultimate Oscillator Strategy Implementation
TradingSignal GenerateUltimateOscillatorSignal(double bid, double ask, double sl_dist, double tp_dist)
{
   TradingSignal signal = {};
   
   int uo_handle = iUltimateOscillator(_Symbol, _Period, 7, 14, 28);
   if(uo_handle == INVALID_HANDLE) return signal;
   
   double uo_arr[2];
   if(CopyBuffer(uo_handle, 0, 0, 2, uo_arr) == 2)
   {
      double uo_current = uo_arr[1];
      double uo_previous = uo_arr[0];
      
      // Oversold signal
      if(uo_current < 30 && uo_previous >= 30)
      {
         signal.type = 0; // BUY
         signal.price = ask;
         signal.sl = ask - sl_dist;
         signal.tp = ask + tp_dist;
         signal.confidence = 0.7;
      }
      // Overbought signal
      else if(uo_current > 70 && uo_previous <= 70)
      {
         signal.type = 1; // SELL
         signal.price = bid;
         signal.sl = bid + sl_dist;
         signal.tp = bid - tp_dist;
         signal.confidence = 0.7;
      }
   }
   
   IndicatorRelease(uo_handle);
   return signal;
}

// Williams Percent Range Strategy Implementation
TradingSignal GenerateWilliamsPercentRangeSignal(double bid, double ask, double sl_dist, double tp_dist)
{
   TradingSignal signal = {};
   
   int wpr_handle = iWPR(_Symbol, _Period, 14);
   if(wpr_handle == INVALID_HANDLE) return signal;
   
   double wpr_arr[2];
   if(CopyBuffer(wpr_handle, 0, 0, 2, wpr_arr) == 2)
   {
      double wpr_current = wpr_arr[1];
      double wpr_previous = wpr_arr[0];
      
      // Oversold signal (crosses above -80)
      if(wpr_current > -80 && wpr_previous <= -80)
      {
         signal.type = 0; // BUY
         signal.price = ask;
         signal.sl = ask - sl_dist;
         signal.tp = ask + tp_dist;
         signal.confidence = 0.7;
      }
      // Overbought signal (crosses below -20)
      else if(wpr_current < -20 && wpr_previous >= -20)
      {
         signal.type = 1; // SELL
         signal.price = bid;
         signal.sl = bid + sl_dist;
         signal.tp = bid - tp_dist;
         signal.confidence = 0.7;
      }
   }
   
   IndicatorRelease(wpr_handle);
   return signal;
}

// ZigZag Strategy Implementation
TradingSignal GenerateZigZagSignal(double bid, double ask, double sl_dist, double tp_dist)
{
   TradingSignal signal = {};
   
   int zigzag_handle = iZigZag(_Symbol, _Period, 12, 5, 3);
   if(zigzag_handle == INVALID_HANDLE) return signal;
   
   double zigzag_arr[10]; // Look back for pattern
   if(CopyBuffer(zigzag_handle, 0, 0, 10, zigzag_arr) == 10)
   {
      // Find last two swing points
      double last_high = 0, last_low = 0;
      int last_high_idx = -1, last_low_idx = -1;
      
      for(int i = 1; i < 10; i++)
      {
         if(zigzag_arr[i] > 0)
         {
            if(last_high_idx == -1)
            {
               last_high = zigzag_arr[i];
               last_high_idx = i;
            }
         }
      }
      
      // Simple breakout strategy based on last swing high
      if(last_high > 0 && ask > last_high)
      {
         signal.type = 0; // BUY breakout
         signal.price = ask;
         signal.sl = last_high - sl_dist;
         signal.tp = ask + tp_dist;
         signal.confidence = 0.6;
      }
   }
   
   IndicatorRelease(zigzag_handle);
   return signal;
}

//+------------------------------------------------------------------+
//| MARKET CONTEXT FUNCTIONS                                         |
//+------------------------------------------------------------------+

double GetVolatility(const string symbol, const ENUM_TIMEFRAMES timeframe)
{
   int atr_handle = iATR(symbol, timeframe, 14);
   if(atr_handle == INVALID_HANDLE) return 0.0;
   
   double atr_arr[1];
   double result = 0.0;
   if(CopyBuffer(atr_handle, 0, 0, 1, atr_arr) == 1)
      result = atr_arr[0];
   
   IndicatorRelease(atr_handle);
   return result;
}

double GetCorrelation()
{
   if(CheckPointer(g_correlation_manager) != POINTER_INVALID)
   {
      string reason = "";
      double correlation = 0.0;
      g_correlation_manager.CheckCorrelationLimits(reason, correlation);
      return correlation;
   }
   return 0.0;
}

string GetMarketRegime()
{
   double atr = GetVolatility(_Symbol, _Period);
   double point = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_POINT, point);
   
   if(atr > 0 && point > 0)
   {
      double atr_pips = atr / point;
      if(atr_pips > 100) return "HIGH_VOLATILITY";
      if(atr_pips < 20) return "LOW_VOLATILITY";
   }
   return "NORMAL";
}

//+------------------------------------------------------------------+
//| GATE SYSTEM - REAL IMPLEMENTATION                                 |
//+------------------------------------------------------------------+

// Apply 8-stage gate pipeline
bool ApplyGatePipeline(TradingSignal &signal, CSignalDecision &decision)
{
   if(CheckPointer(g_gate_manager) == POINTER_INVALID)
      return true; // Pass through if no gate manager
   
   // Convert to gate manager format
   GateResult result = g_gate_manager.ProcessSignal(signal);
   
   if(!result.passed)
   {
      LOG(StringFormat("Gate blocked: %s - %s", signal.strategy, result.reason));
      return false;
   }
   
   // Apply gate adjustments
   if(result.tweaks[0] != 0) signal.price *= (1.0 + result.tweaks[0]);
   if(result.tweaks[1] != 0) signal.sl *= (1.0 + result.tweaks[1]);
   if(result.tweaks[2] != 0) signal.tp *= (1.0 + result.tweaks[2]);
   if(result.tweaks[3] != 0) signal.volume *= (1.0 + result.tweaks[3]);
   
   return true;
}

// Apply policy gating
bool ApplyPolicyGating(TradingSignal &signal, CSignalDecision &decision)
{
   if(!UsePolicyGating || CheckPointer(g_policy_engine) == POINTER_INVALID)
      return true; // Pass through
   
   // Get policy for this strategy/symbol/timeframe
   PolicySlice policy;
   if(!g_policy_engine.GetPolicy(signal.strategy, signal.symbol, (ENUM_TIMEFRAMES)signal.timeframe, policy))
   {
      if(DefaultPolicyFallback)
      {
         LOG(StringFormat("No policy found for %s, using fallback", signal.strategy));
         return true;
      }
      return false;
   }
   
   // Apply confidence threshold
   if(signal.confidence < policy.min_confidence)
   {
      LOG(StringFormat("Policy blocked: confidence %.2f < min %.2f", 
                       signal.confidence, policy.min_confidence));
      return false;
   }
   
   // Apply policy scaling
   signal.sl *= policy.sl_scale;
   signal.tp *= policy.tp_scale;
   signal.volume *= policy.probability;
   
   return true;
}

//+------------------------------------------------------------------+
//| TRADE EXECUTION                                                  |
//+------------------------------------------------------------------+

// Execute trade with proper validation
bool ExecuteTrade(TradingSignal &signal)
{
   if(CheckPointer(g_trade_manager) == POINTER_INVALID)
   {
      LOG("Trade manager not initialized", LOG_ERROR);
      return false;
   }
   
   // Validate signal
   if(signal.id == "" || signal.price <= 0)
   {
      LOG("Invalid signal", LOG_ERROR);
      return false;
   }
   
   // Execute trade
   bool result = false;
   if(signal.type == 0) // BUY
   {
      result = g_trade_manager.Buy(signal.volume, signal.symbol, signal.price, 
                                  signal.sl, signal.tp, signal.strategy);
   }
   else // SELL
   {
      result = g_trade_manager.Sell(signal.volume, signal.symbol, signal.price,
                                   signal.sl, signal.tp, signal.strategy);
   }
   
   if(result)
   {
      g_total_trades++;
      g_last_trade_time = TimeCurrent();
      
      // Log to knowledge base
      if(CheckPointer(g_knowledge_base) != POINTER_INVALID)
      {
         g_knowledge_base.LogTradeExecution(signal.symbol, signal.strategy, 
                                           TimeCurrent(), signal.price, 
                                           signal.volume, signal.type);
      }
      
      LOG(StringFormat("Trade executed: %s %s %.2f @%.5f", 
                       signal.type == 0 ? "BUY" : "SELL", 
                       signal.symbol, signal.volume, signal.price));
   }
   else
   {
      LOG("Trade execution failed", LOG_ERROR);
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| MAIN TRADING LOGIC                                               |
//+------------------------------------------------------------------+

// Main trading function
void ExecuteMainTradingLogic()
{
   if(!g_initialized)
   {
      LOG("System not initialized", LOG_ERROR);
      return;
   }
   
   // Trade frequency control
   if(TimeCurrent() - g_last_trade_time < 60) // 1 minute cooldown
      return;
   
   // Risk checks
   if(MaxOpenPositions > 0 && PositionsTotal() >= MaxOpenPositions)
   {
      LOG("Max positions reached", LOG_INFO);
      return;
   }
   
   // Get strategy list
   string strategies[];
   GetDefaultStrategyNames(strategies);
   
   // Generate signals from all strategies
   TradingSignal best_signal = {};
   double best_score = -1.0;
   
   for(int i = 0; i < ArraySize(strategies); i++)
   {
      TradingSignal signal = GenerateSignalFromStrategy(strategies[i]);
      
      if(signal.id == "") continue; // Skip invalid signals
      
      // Apply gate pipeline
      CSignalDecision decision = {};
      if(!ApplyGatePipeline(signal, decision))
         continue; // Signal blocked by gates
      
      // Apply policy gating
      if(!ApplyPolicyGating(signal, decision))
         continue; // Signal blocked by policy
      
      // Score signal
      double score = signal.confidence;
      if(UseStrategySelector && CheckPointer(g_strategy_selector) != POINTER_INVALID)
      {
         score = g_strategy_selector.ScoreStrategy(strategies[i], signal.symbol, 
                                                  (ENUM_TIMEFRAMES)signal.timeframe);
      }
      
      if(score > best_score)
      {
         best_score = score;
         best_signal = signal;
      }
   }
   
   // Execute best signal
   if(best_score > 0.5) // Minimum confidence threshold
   {
      ExecuteTrade(best_signal);
   }
}

//+------------------------------------------------------------------+
//| SYSTEM INITIALIZATION                                            |
//+------------------------------------------------------------------+

// Initialize all managers
bool InitializeSystem()
{
   LOG("Initializing PaperEA_v2 CLEAN...");
   
   // Initialize trade manager
   g_trade_manager = new CTradeManager();
   if(CheckPointer(g_trade_manager) == POINTER_INVALID)
   {
      LOG("Failed to create trade manager", LOG_ERROR);
      return false;
   }
   g_trade_manager.SetMagicNumber(MagicNumber);
   
   // Initialize strategy selector
   if(UseStrategySelector)
   {
      g_strategy_selector = new CStrategySelector();
      if(CheckPointer(g_strategy_selector) != POINTER_INVALID)
      {
         g_strategy_selector.Load(); // Load insights
      }
   }
   
   // Initialize gate manager
   g_gate_manager = new CGateManager();
   
   // Initialize policy engine
   if(UsePolicyGating)
   {
      g_policy_engine = new CPolicyEngine();
      if(CheckPointer(g_policy_engine) != POINTER_INVALID)
      {
         g_policy_engine.LoadFromFile(PolicyFilePath);
      }
   }
   
   // Initialize knowledge base
   g_knowledge_base = new CKnowledgeBase();
   
   // Initialize telemetry
   if(TelemetryEnabled)
   {
      g_telemetry = new CTelemetryStandard("DualEA\\telemetry", TelemetryExperiment, 1, 256);
   }
   
   // Initialize session manager
   g_session_manager = new CSessionManager();
   
   // Initialize correlation manager
   g_correlation_manager = new CCorrelationManager();
   
   // Initialize volatility sizer
   g_volatility_sizer = new CVolatilitySizer();
   
   // Initialize asset registry
   g_asset_registry = new CAssetRegistry();
   
   g_initialized = true;
   LOG("System initialization complete");
   return true;
}

//+------------------------------------------------------------------+
//| MQL5 EVENT HANDLERS                                              |
//+------------------------------------------------------------------+

int OnInit()
{
   LOG("PaperEA_v2 CLEAN starting...");
   
   if(!InitializeSystem())
   {
      LOG("Initialization failed", LOG_ERROR);
      return INIT_FAILED;
   }
   
   LOG("PaperEA_v2 CLEAN started successfully");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   LOG("PaperEA_v2 CLEAN stopping...");
   
   // Cleanup
   if(CheckPointer(g_trade_manager) != POINTER_INVALID) delete g_trade_manager;
   if(CheckPointer(g_strategy_selector) != POINTER_INVALID) delete g_strategy_selector;
   if(CheckPointer(g_gate_manager) != POINTER_INVALID) delete g_gate_manager;
   if(CheckPointer(g_policy_engine) != POINTER_INVALID) delete g_policy_engine;
   if(CheckPointer(g_knowledge_base) != POINTER_INVALID) delete g_knowledge_base;
   if(CheckPointer(g_telemetry) != POINTER_INVALID) delete g_telemetry;
   if(CheckPointer(g_session_manager) != POINTER_INVALID) delete g_session_manager;
   if(CheckPointer(g_correlation_manager) != POINTER_INVALID) delete g_correlation_manager;
   if(CheckPointer(g_volatility_sizer) != POINTER_INVALID) delete g_volatility_sizer;
   if(CheckPointer(g_asset_registry) != POINTER_INVALID) delete g_asset_registry;
   
   LOG("PaperEA_v2 CLEAN stopped");
}

void OnTick()
{
   if(!g_initialized) return;
   ExecuteMainTradingLogic();
}

void OnTimer()
{
   // Periodic maintenance
   if(!g_initialized) return;
   
   // Reload policies if enabled
   if(UsePolicyGating && CheckPointer(g_policy_engine) != POINTER_INVALID)
   {
      static datetime last_reload = 0;
      if(TimeCurrent() - last_reload > 300) // Every 5 minutes
      {
         g_policy_engine.LoadFromFile(PolicyFilePath);
         last_reload = TimeCurrent();
      }
   }
   
   // Flush telemetry
   if(TelemetryEnabled && CheckPointer(g_telemetry) != POINTER_INVALID)
   {
      g_telemetry.Flush();
   }
}

//+------------------------------------------------------------------+
