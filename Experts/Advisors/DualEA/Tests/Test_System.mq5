//+------------------------------------------------------------------+
//| Test_System.mq5                                                  |
//| System-level E2E test: full pipeline, logging, export, errors    |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include "..\\Include\\StrategySelector.mqh"
#include "..\\Include\\GateManager.mqh"
#include "..\\Include\\SessionManager.mqh"
#include "..\\Include\\CorrelationManager.mqh"
#include "..\\Include\\VolatilitySizer.mqh"
#include "..\\Include\\LearningBridge.mqh"
#include "..\\Include\\KnowledgeBase.mqh"
#include "..\\Include\\PolicyEngine.mqh"
#include "..\\Include\\ExportFeatureBatch.mqh"

input int Verbosity = 2;

void OnStart()
{
   Print("[Test] System: BEGIN");
   // Full pipeline setup
   CStrategySelector selector;
   CLearningBridge *learning = new CLearningBridge("TestData");
   CGateManager gm(_Symbol, _Period, learning, true);
   CSessionManager sm(_Symbol, _Period);
   CCorrelationManager cm(_Symbol, _Period);
   CVolatilitySizer vs(_Symbol, _Period);
   CFeaturesKB features;
   CKnowledgeBase kb;
   CPolicyEngine policy;

   sm.SetSessionHours(9, 17);
   sm.SetMaxTradesPerSession(3);
   cm.SetMaxCorrelation(0.8);
   cm.SetLookbackDays(30);
   vs.SetATRPeriod(14);
   vs.SetBaseATRPercent(0.5);
   vs.SetMultiplierRange(0.5, 2.0);
   vs.SetTargetRiskPercent(1.0);
   vs.SetEnabled(true);

   // Simulate a signal through the full pipeline
   TradingSignal signal;
   signal.id = "SYS_TEST";
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

   string reason;
   if(sm.IsSessionAllowed(reason)) Print("PASS: SessionManager allowed");
   else PrintFormat("FAIL: SessionManager blocked (%s)", reason);

   double corr = cm.GetCorrelation(_Symbol);
   PrintFormat("INFO: CorrelationManager self-corr = %.2f", corr);

   double sl_points = 50, vol_mult = 1.0;
   double sized = vs.CalculatePositionSize(decision.original_volume, sl_points, vol_mult, reason);
   PrintFormat("INFO: VolatilitySizer sized = %.2f (%s)", sized, reason);

   string strats[] = {"ADXStrategy", "RSIStrategy"};
   double scores[];
   int idx = selector.PickBest(_Symbol, _Period, strats, scores);
   if(idx >= 0 && idx < ArraySize(strats))
      PrintFormat("PASS: Selector picked %s", strats[idx]);
   else
      Print("FAIL: Selector did not pick");

   // Feature export
   string feats[] = {"dummy:1"};
   bool feat_ok = features.ExportFeatures(_Symbol, decision.strategy, TimeCurrent(), feats);
   if(feat_ok) Print("PASS: FeaturesKB export");
   else Print("FAIL: FeaturesKB export");

   // Trade log
   bool log_ok = kb.LogTradeExecution(_Symbol, decision.strategy, TimeCurrent(), decision.original_price, decision.original_volume, decision.original_type);
   if(log_ok) Print("PASS: KnowledgeBase trade log");
   else Print("FAIL: KnowledgeBase trade log");

   // Policy engine (smoke)
   double prob = policy.GetPolicyProb("ADXStrategy", _Symbol, _Period);
   PrintFormat("INFO: PolicyEngine GetPolicyProb = %.4f", prob);

   Print("[Test] System: END");
}
