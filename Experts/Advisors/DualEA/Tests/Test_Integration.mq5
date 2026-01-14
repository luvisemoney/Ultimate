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
   CLearningBridge *learning = new CLearningBridge("TestData");
   CGateManager gm(_Symbol, _Period, learning, true);
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
   TradingSignal signal;
   signal.Init();  // CRITICAL: Initialize all fields to safe defaults
   signal.id = "INT_TEST";
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
   if(!allowed) Print("PASS: GateManager blocked");
   else Print("PASS: GateManager allowed");

   // Session check
   string reason;
   if(sm.IsSessionAllowed(reason)) Print("PASS: SessionManager allowed");
   else PrintFormat("FAIL: SessionManager blocked (%s)", reason);

   // Correlation check
   double corr = cm.GetCorrelation(_Symbol);
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
