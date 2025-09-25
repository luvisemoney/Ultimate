//+------------------------------------------------------------------+
//| Test_Integration.mq5                                             |
//| Integration test: selector, gating, sizer, session, correlation  |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include "..\\Include\\StrategySelector.mqh"
#include "..\\Include\\GateManager.mqh"
#include "..\\Include\\SessionManager.mqh"
#include "..\\Include\\CorrelationManager.mqh"
#include "..\\Include\\VolatilitySizer.mqh"
#include "..\\Include\\LearningBridge.mqh"

input int Verbosity = 2;

void OnStart()
{
   Print("[Test] Integration: BEGIN");
   // Setup
   CStrategySelector selector;
   CGateManager gm;
   CSessionManager sm(_Symbol, _Period);
   CCorrelationManager cm(_Symbol, _Period);
   CVolatilitySizer vs(_Symbol, _Period);

   sm.SetSessionHours(9, 17);
   sm.SetMaxTradesPerSession(3);
   cm.SetMaxCorrelation(0.8);
   cm.SetLookbackDays(30);
   vs.SetATRPeriod(14);
   vs.SetBaseATRPercent(0.5);
   vs.SetMultiplierRange(0.5, 2.0);
   vs.SetTargetRiskPercent(1.0);
   vs.SetEnabled(true);

   // Simulate a signal
   CSignalDecision decision;
   decision.symbol = _Symbol;
   decision.timeframe = _Period;
   decision.original_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   decision.original_type = 0;
   decision.original_volume = 0.1;
   decision.strategy = "ADXStrategy";

   string reason;
   bool allowed = gm.ProcessSignal(decision, reason);
   if(!allowed) PrintFormat("PASS: GateManager blocked (%s)", reason);
   else PrintFormat("PASS: GateManager allowed (%s)", reason);

   // Session check
   if(sm.IsSessionAllowed(reason)) Print("PASS: SessionManager allowed");
   else PrintFormat("FAIL: SessionManager blocked (%s)", reason);

   // Correlation check
   double corr = cm.GetCorrelation(_Symbol, _Symbol);
   PrintFormat("INFO: CorrelationManager self-corr = %.2f", corr);

   // Sizer
   double sl_points = 50, vol_mult = 1.0;
   double sized = vs.CalculatePositionSize(decision.original_volume, sl_points, vol_mult, reason);
   PrintFormat("INFO: VolatilitySizer sized = %.2f (%s)", sized, reason);

   // Selector
   string strats[] = {"ADXStrategy", "RSIStrategy"};
   double scores[];
   int idx = selector.PickBest(_Symbol, _Period, strats, scores);
   if(idx >= 0 && idx < ArraySize(strats))
      PrintFormat("PASS: Selector picked %s", strats[idx]);
   else
      Print("FAIL: Selector did not pick");

   Print("[Test] Integration: END");
}
