//+------------------------------------------------------------------+
//| UnifiedSystemExample.mq5 - Example of Unified DualEA System     |
//+------------------------------------------------------------------+
#property copyright "DualEA Team"
#property link      ""
#property version   "1.00"

#include "../Include/GateManager.mqh"
#include "../Include/ConfigManager.mqh"
#include "../Include/EventBus.mqh"
#include "../Include/SystemMonitor.mqh"

// Input parameters
input bool UnifiedMode = true;           // Enable unified system
input bool VerboseLogging = false;       // Enable verbose logging
input bool NoConstraintsMode = false;    // Disable all constraints for testing
input int MonitoringInterval = 60;       // System monitoring interval (seconds)

// Global objects
CGateManager *g_gate_manager = NULL;
CLearningBridge *g_learning = NULL;
CConfigManager *g_config = NULL;
CEventBus *g_event_bus = NULL;
CSystemMonitor *g_monitor = NULL;

// Example event subscriber
class CExampleSubscriber : public IEventSubscriber
{
public:
   void OnEvent(const EventData& event) override
   {
      if(event.priority >= 2) // Only log high priority events
      {
         Print("ExampleEA: Received ", EnumToString(event.type), " from ", event.source, ": ", event.data);
      }
   }
   
   string GetSubscriberName() override { return "ExampleEA"; }
};

CExampleSubscriber *g_subscriber = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== Initializing Unified DualEA System Example ===");
   
   // Initialize unified system components
   if(UnifiedMode)
   {
      // Get singleton instances
      g_config = CConfigManager::GetInstance();
      g_event_bus = CEventBus::GetInstance();
      g_monitor = CSystemMonitor::GetInstance();
      
      // Configure system
      g_config.SetVerboseLogging(VerboseLogging);
      g_config.SetNoConstraintsMode(NoConstraintsMode);
      g_event_bus.SetVerboseLogging(VerboseLogging);
      
      // Create event subscriber
      g_subscriber = new CExampleSubscriber();
      g_event_bus.Subscribe(EVENT_GATE_PROCESSED, g_subscriber);
      g_event_bus.Subscribe(EVENT_TRADE_EXECUTED, g_subscriber);
      g_event_bus.Subscribe(EVENT_ERROR_OCCURRED, g_subscriber);
      
      Print("Unified system components initialized");
   }
   
   // Initialize learning bridge
   g_learning = new CLearningBridge("DualEA_Example");
   
   // Initialize gate manager with unified system
   g_gate_manager = new CGateManager(Symbol(), Period(), g_learning, UnifiedMode);
   
   if(UnifiedMode)
   {
      // Print initial configuration
      g_config.PrintConfiguration();
      
      // Publish initialization event
      g_event_bus.PublishSystemEvent("ExampleEA", "Initialized successfully");
   }
   
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
   
   if(g_subscriber != NULL)
   {
      delete g_subscriber;
      g_subscriber = NULL;
   }
   
   // Clean up singletons (optional - they clean up automatically)
   if(UnifiedMode)
   {
      CConfigManager::Cleanup();
      CEventBus::Cleanup();
      CSystemMonitor::Cleanup();
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
      // Create example trading signal
      TradingSignal signal;
      signal.id = "EXAMPLE_" + IntegerToString(signal_counter++);
      signal.symbol = Symbol();
      signal.timeframe = Period();
      signal.timestamp = TimeCurrent();
      signal.price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
      signal.type = (signal_counter % 2); // Alternate buy/sell
      signal.sl = signal.price - (signal.type == 0 ? 100 : -100) * _Point;
      signal.tp = signal.price + (signal.type == 0 ? 200 : -200) * _Point;
      signal.volume = 0.1;
      signal.confidence = 0.6 + (MathRand() % 40) / 100.0; // Random confidence 0.6-1.0
      signal.volatility = 0.01 + (MathRand() % 20) / 1000.0; // Random volatility
      signal.correlation = (MathRand() % 100 - 50) / 100.0; // Random correlation -0.5 to 0.5
      signal.regime = (MathRand() % 2 == 0) ? "trending" : "ranging";
      
      // Process signal through gate system
      CSignalDecision decision;
      bool result = g_gate_manager.ProcessSignal(signal, decision);
      
      if(result && decision.executed)
      {
         Print("Signal ", signal.id, " processed successfully - Final price: ", 
               DoubleToString(decision.final_price, Digits()));
      }
      else
      {
         Print("Signal ", signal.id, " rejected by gate system");
      }
      
      last_signal_time = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(!UnifiedMode || g_gate_manager == NULL) return;
   
   // Update gate thresholds based on learning
   g_gate_manager.UpdateFromLearning();
   
   // Print system status periodically
   static int timer_counter = 0;
   timer_counter++;
   
   if(timer_counter % 5 == 0) // Every 5 timer intervals
   {
      Print("\n=== System Status Update ===");
      g_gate_manager.PrintSystemStatus();
      
      // Print recent events
      if(g_event_bus != NULL)
      {
         g_event_bus.PrintEventHistory(5);
      }
   }
}

//+------------------------------------------------------------------+
//| Trade function (for demonstration)                               |
//+------------------------------------------------------------------+
void OnTrade()
{
   if(UnifiedMode && g_event_bus != NULL)
   {
      // Publish trade event
      g_event_bus.PublishTradeEvent("DEMO_TRADE", "Trade executed", 0.0);
   }
}
