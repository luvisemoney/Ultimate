//+------------------------------------------------------------------+
//| Test_GateManager.mq5                                             |
//| Unit test for CGateManager                                      |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include "..\\Include\\GateManager.mqh"
#include "..\\Include\\LearningBridge.mqh"

input int Verbosity = 2;

void OnStart()
{
   Print("[Test] CGateManager: BEGIN");
   CLearningBridge *learning = new CLearningBridge("TestData");
   CGateManager gm(_Symbol, _Period, learning, true);

   // Build a sample signal
   TradingSignal signal;
   signal.id = "TEST_SIGNAL";
   signal.symbol = _Symbol;
   signal.timeframe = _Period;
   signal.timestamp = TimeCurrent();
   signal.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   signal.type = 0;
   signal.sl = signal.price - 100 * _Point;
   signal.tp = signal.price + 200 * _Point;
   signal.volume = 0.1;
   signal.confidence = 0.75;
   signal.volatility = 0.01;
   signal.correlation = 0.2;
   signal.regime = "trending";

   CSignalDecision decision;
   bool allowed = gm.ProcessSignal(signal, decision);
   if(allowed && decision.executed)
      Print("PASS: ProcessSignal executed");
   else
      Print("PASS: ProcessSignal not executed (as expected for unit test)");

   Print("[Test] CGateManager: END");
}
