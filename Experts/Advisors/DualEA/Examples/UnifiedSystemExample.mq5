//+------------------------------------------------------------------+
//| UnifiedSystemExample.mq5 - Example of Unified DualEA System     |
//+------------------------------------------------------------------+
#property copyright "DualEA Team"
#property link      ""
#property version   "1.00"

// New Architecture: Auto-learning gate system
#include "../Include/GateSystemAutoLearning.mqh"
#include "../Include/ConfigManager.mqh"
#include "../Include/EventBus.mqh"
#include "../Include/CSystemMonitor.mqh"
#include "../Include/LearningBridge.mqh"

// Input parameters
input bool UnifiedMode = true;           // Enable unified system
input bool VerboseLogging = false;       // Enable verbose logging
input bool NoConstraintsMode = false;    // Disable all constraints for testing
input int MonitoringInterval = 60;       // System monitoring interval (seconds)

// Global objects - Use new CEfficientGateManagerEnhanced type
CEfficientGateManagerEnhanced *g_gate_manager = NULL;
CLearningBridge *g_learning = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== Initializing Unified DualEA System Example ===");
   
   // Initialize learning bridge
   g_learning = new CLearningBridge("DualEA_Example", 1000);
   
   // Initialize gate manager
   g_gate_manager = new CEfficientGateManagerEnhanced(NoConstraintsMode, UnifiedMode, false);
   
   // Set up timer for monitoring
   EventSetTimer(MonitoringInterval);
   
   Print("=== DualEA Example EA Initialized Successfully ===");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("=== Shutting Down DualEA Example EA ===");
   
   EventKillTimer();
   
   // Clean up objects
   if(g_gate_manager != NULL)
   {
      delete g_gate_manager;
      g_gate_manager = NULL;
   }
   
   if(g_learning != NULL)
   {
      delete g_learning;
      g_learning = NULL;
   }
   
   Print("DualEA Example EA shutdown complete");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime last_signal_time = 0;
   static int signal_counter = 0;
   
   // Generate example signals every 10 ticks (for demonstration)
   static int tick_counter = 0;
   tick_counter++;
   
   if(tick_counter % 10 == 0 && TimeCurrent() - last_signal_time > 30)
   {
      // Create example trading signal using TradingSignal from IStrategy.mqh
      TradingSignal signal;
      signal.strategy_name = "EXAMPLE_" + IntegerToString(signal_counter++);
      signal.symbol = Symbol();
      signal.timeframe = Period();
      signal.timestamp = TimeCurrent();
      signal.entry_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
      signal.direction = (signal_counter % 2 == 0) ? 1 : -1; // Alternate buy/sell
      signal.stop_loss = signal.entry_price - (signal.direction == 1 ? 100 : -100) * _Point;
      signal.take_profit = signal.entry_price + (signal.direction == 1 ? 200 : -200) * _Point;
      signal.confidence = 0.6 + (MathRand() % 40) / 100.0; // Random confidence 0.6-1.0
      
      Print("Signal ", signal.strategy_name, " generated - Direction: ", 
            signal.direction == 1 ? "BUY" : "SELL", 
            " Price: ", DoubleToString(signal.entry_price, Digits()));
      
      last_signal_time = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   static int timer_counter = 0;
   timer_counter++;
   
   if(timer_counter % 5 == 0) // Every 5 timer intervals
   {
      Print("\n=== System Status Update ===");
      
      // Check system health
      CSystemMonitor monitor;
      double health_score = monitor.CalculateHealthScore();
      double cpu_percent = 0.0;
      double memory_used_mb = 0.0;
      Print(StringFormat("Health Score: %.1f | CPU: %.1f%% | Memory: %.1f MB",
               health_score, cpu_percent, memory_used_mb));
   }
}
