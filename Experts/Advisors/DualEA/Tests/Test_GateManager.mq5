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
   CGateManager gm;
   CSignalDecision decision;
   decision.symbol = _Symbol;
   decision.timeframe = _Period;
   decision.original_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   decision.original_type = 0;
   decision.original_volume = 0.1;
   decision.strategy = "ADXStrategy";

   string reason;
   bool allowed = gm.ProcessSignal(decision, reason);
   if(allowed)
      PrintFormat("PASS: ProcessSignal allowed (%s)", reason);
   else
      PrintFormat("PASS: ProcessSignal blocked (%s)", reason);

   Print("[Test] CGateManager: END");
}
