//+------------------------------------------------------------------+
//| Test_StrategySelector.mq5                                        |
//| Unit test for CStrategySelector                                  |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include "../Include/StrategySelector.mqh"

input int Verbosity = 2;

void OnStart()
{
   Print("[Test] CStrategySelector: BEGIN");
   CStrategySelector selector;

   // Test: Configure weights
   selector.ConfigureWeights(1.0, 0.5, 0.2, 0.1);
   selector.ConfigureRecency(true, 10, 0.5);
   selector.SetStrictThresholds(true);
   
   // Test: PickBest with empty strategies
   string empty_strats[];
   double scores[];
   int idx = selector.PickBest(_Symbol, _Period, empty_strats, scores);
   if(idx != -1) Print("FAIL: PickBest should return -1 for empty");
   else Print("PASS: PickBest returns -1 for empty");

   // Test: PickBest with mock strategies
   string strats[] = {"ADXStrategy", "RSIStrategy"};
   ArrayResize(scores,2);
   idx = selector.PickBest(_Symbol, _Period, strats, scores);
   if(idx >= 0 && idx < ArraySize(strats))
      PrintFormat("PASS: PickBest returned idx=%d (%s)", idx, strats[idx]);
   else
      Print("FAIL: PickBest did not return a valid index");

   // Test: EnsureRecentLoaded
   selector.EnsureRecentLoaded(14);
   Print("PASS: EnsureRecentLoaded did not crash");

   Print("[Test] CStrategySelector: END");
}
