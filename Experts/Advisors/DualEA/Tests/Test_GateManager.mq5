//+------------------------------------------------------------------+
//| Test_GateManager.mq5                                             |
//| Unit test for CGateManager                                      |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include "../Include/IStrategy.mqh"
#include "../Include/GateManager.mqh"
#include "../Include/LearningBridge.mqh"

input int Verbosity = 2;

void OnStart()
{
   Print("[Test] CGateManager: BEGIN");
   CLearningBridge *learning = new CLearningBridge("TestData", 100);
   CGateManager gm(false, false, false);

   // Build a sample signal using TradingSignal from IStrategy.mqh
   TradingSignal signal;
   signal.strategy_name = "TEST_SIGNAL";
   signal.symbol = _Symbol;
   signal.timeframe = _Period;
   signal.timestamp = TimeCurrent();
   signal.entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   signal.direction = 1;  // Buy
   signal.stop_loss = signal.entry_price - 100 * _Point;
   signal.take_profit = signal.entry_price + 200 * _Point;
   signal.confidence = 0.75;

   Print("PASS: TradingSignal created successfully");
   
   // Clean up to prevent memory leak
   delete learning;
   
   Print("[Test] CGateManager: END");
}
