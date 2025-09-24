//+------------------------------------------------------------------+
//| PaperEA_v2.mq5 - Enhanced Paper EA with 8-Stage Gates           |
//+------------------------------------------------------------------+
#property copyright "DualEA Enhanced Paper System"
#property version   "2.0"
#property strict

//+------------------------------------------------------------------+
//| INCLUDES                                                         |
//+------------------------------------------------------------------+
#include "..\Include\IStrategy.mqh"
#include "..\Include\LearningBridge.mqh"
#include "..\Include\GateManager.mqh"
#include "..\Include\TradeManager.mqh"
#include "..\Include\Telemetry.mqh"
#include "..\Include\TelemetryStandard.mqh"

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input string   TradingSymbol = "EURUSD";
input int      Timeframe = 15; // 15 minutes
input double   LotSize = 0.1;
input int      MagicNumber = 12345;

// Gate parameters
input bool     UseGateSystem = true;
input string   LearningDataPath = "C:\\DualEA\\PaperData";
input int      MaxLearningRecords = 10000;

//+------------------------------------------------------------------+
//| STRUCTURES                                                       |
//+------------------------------------------------------------------+
struct TradingSignal
{
   string id;
   string symbol;
   int timeframe;
   datetime timestamp;
   double price;
   int type; // 0 = buy, 1 = sell
   double sl;
   double tp;
   double volume;
   double confidence;
   string market_regime;
   string regime; // Alias for market_regime
   double volatility;
   double correlation;
};

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
CLearningBridge *g_learning_bridge = NULL;
CGateManager *g_gate_manager = NULL;
CTradeManager *g_trade_manager = NULL;
CTelemetryStandard *g_telemetry = NULL;

//+------------------------------------------------------------------+
//| EXPERT INITIALIZATION                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize learning bridge
   g_learning_bridge = new CLearningBridge(LearningDataPath, MaxLearningRecords);
   
   // Initialize gate manager
   g_gate_manager = new CGateManager(TradingSymbol, Timeframe, g_learning_bridge);
   
   // Initialize trade manager
   g_trade_manager = new CTradeManager(TradingSymbol, 0.1, MagicNumber);
   
   // Initialize telemetry
   CTelemetry *base_telemetry = new CTelemetry();
   g_telemetry = new CTelemetryStandard(base_telemetry);
   
   Print("PaperEA v2 initialized with 8-stage gate system");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| EXPERT DEINITIALIZATION                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_learning_bridge != NULL)
      delete g_learning_bridge;
   if(g_gate_manager != NULL)
      delete g_gate_manager;
   if(g_trade_manager != NULL)
      delete g_trade_manager;
   if(g_telemetry != NULL)
      delete g_telemetry;
}

//+------------------------------------------------------------------+
//| MAIN TRADING FUNCTION                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   // Generate trading signals (this would be your strategy)
   TradingSignal signal = GenerateSignal();
   
   if(signal.id != "")
   {
      // Process through gate system
      if(UseGateSystem)
      {
         CSignalDecision decision;
         bool passed = g_gate_manager->ProcessSignal(signal, decision);
         
         if(passed)
         {
            // Execute paper trade
            ExecutePaperTrade(decision);
            
            // Log telemetry
            LogDecisionTelemetry(decision);
         }
         else
         {
            Print("Signal rejected by gates: " + signal.id);
         }
      }
      else
      {
         // Bypass gates for testing
         ExecutePaperTrade(signal);
      }
   }
   
   // Update gate thresholds periodically
   static datetime last_update = 0;
   if(TimeCurrent() - last_update > 3600) // Update every hour
   {
      if(g_gate_manager != NULL) g_gate_manager->UpdateFromLearning();
      last_update = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| SIGNAL GENERATION                                                |
//+------------------------------------------------------------------+
TradingSignal GenerateSignal()
{
   TradingSignal signal;
   
   // Simple moving average crossover strategy
   int fast_ma_handle = iMA(TradingSymbol, (ENUM_TIMEFRAMES)Timeframe, 20, 0, MODE_SMA, PRICE_CLOSE);
   double fast_ma_array[1];
   CopyBuffer(fast_ma_handle, 0, 0, 1, fast_ma_array);
   double fast_ma = fast_ma_array[0];
   
   int slow_ma_handle = iMA(TradingSymbol, (ENUM_TIMEFRAMES)Timeframe, 50, 0, MODE_SMA, PRICE_CLOSE);
   double slow_ma_array[1];
   CopyBuffer(slow_ma_handle, 0, 0, 1, slow_ma_array);
   double slow_ma = slow_ma_array[0];
   
   double current_price = 0;
   SymbolInfoDouble(TradingSymbol, SYMBOL_BID, current_price);
   
   if(fast_ma > slow_ma && fast_ma < current_price)
   {
      signal.id = "MA_CROSS_" + IntegerToString(TimeCurrent());
      signal.symbol = TradingSymbol;
      signal.timeframe = Timeframe;
      signal.timestamp = TimeCurrent();
      signal.price = current_price;
      signal.type = 0; // 0=buy
      signal.sl = current_price - 100 * Point();
      signal.tp = current_price + 200 * Point();
      signal.volume = LotSize;
      signal.confidence = 0.75;
      
      // Market context
      signal.volatility = GetVolatility();
      signal.correlation = GetCorrelation();
      signal.regime = GetMarketRegime();
   }
   else if(fast_ma < slow_ma && fast_ma > current_price)
   {
      signal.id = "MA_CROSS_" + IntegerToString(TimeCurrent());
      signal.symbol = TradingSymbol;
      signal.timeframe = Timeframe;
      signal.timestamp = TimeCurrent();
      signal.price = current_price;
      signal.type = 1; // 1=sell
      signal.sl = current_price + 100 * Point();
      signal.tp = current_price - 200 * Point();
      signal.volume = LotSize;
      signal.confidence = 0.75;
      
      // Market context
      signal.volatility = GetVolatility();
      signal.correlation = GetCorrelation();
      signal.regime = GetMarketRegime();
   }
   
   return signal;
}

//+------------------------------------------------------------------+
//| TRADE EXECUTION                                                  |
//+------------------------------------------------------------------+
void ExecutePaperTrade(CSignalDecision &decision)
{
   // Execute paper trade (simulated)
   Print("Executing paper trade: " + decision.signal_id + 
         " at " + DoubleToString(decision.final_price, 5));
   
   // In real implementation, this would create a paper position
   // and track it for learning purposes
}

void ExecutePaperTrade(TradingSignal &signal)
{
   // Direct execution without gates
   Print("Executing paper trade (no gates): " + signal.id + 
         " at " + DoubleToString(signal.price, 5));
}

//+------------------------------------------------------------------+
//| TELEMETRY LOGGING                                                |
//+------------------------------------------------------------------+
void LogDecisionTelemetry(CSignalDecision &decision)
{
   // Log decision telemetry
   
   string log_data = StringFormat(
      "Decision: %s, Symbol: %s, Gates: [%d,%d,%d,%d,%d,%d,%d,%d], " +
      "Original: %.5f/%.5f/%.5f/%.2f, " +
      "Final: %.5f/%.5f/%.5f/%.2f",
      decision.signal_id, decision.symbol,
      decision.gate_results[0], decision.gate_results[1], 
      decision.gate_results[2], decision.gate_results[3],
      decision.gate_results[4], decision.gate_results[5],
      decision.gate_results[6], decision.gate_results[7],
      decision.original_price, decision.original_sl, 
      decision.original_tp, decision.original_volume,
      decision.final_price, decision.final_sl, 
      decision.final_tp, decision.final_volume
   );
   
   Print(log_data);
}

//+------------------------------------------------------------------+
//| MARKET ANALYSIS HELPERS                                          |
//+------------------------------------------------------------------+
double GetVolatility()
{
   // Calculate ATR-based volatility
   int atr_handle = iATR(TradingSymbol, (ENUM_TIMEFRAMES)Timeframe, 14);
   double atr_array[1];
   CopyBuffer(atr_handle, 0, 0, 1, atr_array);
   double atr = atr_array[0];
   double price = 0;
   SymbolInfoDouble(TradingSymbol, SYMBOL_BID, price);
   return atr / price;
}

double GetCorrelation()
{
   // Simplified correlation calculation
   return 0.5; // Placeholder
}

string GetMarketRegime()
{
   // Simple regime detection based on ADX
   int adx_handle = iADX(TradingSymbol, (ENUM_TIMEFRAMES)Timeframe, 14);
   double adx_array[1];
   CopyBuffer(adx_handle, 0, 0, 1, adx_array);
   double adx = adx_array[0];
   
   if(adx > 25) return "trending";
   else return "ranging";
}

//+------------------------------------------------------------------+
//| TIMER FOR LEARNING UPDATES                                       |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Periodic learning updates
   g_gate_manager->UpdateFromLearning();
   
   // Transfer successful signals to live EA
   g_learning_bridge->TransferSuccessfulSignals("C:\\DualEA\\LiveData");
}
