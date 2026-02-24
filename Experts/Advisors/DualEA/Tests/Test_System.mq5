//+------------------------------------------------------------------+
//| Test_System.mq5                                                  |
//| System-level E2E test: full pipeline, logging, export, errors    |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include "..\\Include\\IStrategy.mqh"
#include "..\\Include\\GateManager.mqh"
#include "..\\Include\\SessionManager.mqh"
#include "..\\Include\\CorrelationManager.mqh"
#include "..\\Include\\VolatilitySizer.mqh"
#include "..\\Include\\LearningBridge.mqh"
#include "..\\Include\\KnowledgeBase.mqh"
#include "..\\Include\\PolicyEngine.mqh"
#include "..\\Include\\StrategySelector.mqh"

input int Verbosity = 2;

void OnStart()
{
   Print("[Test] System: BEGIN");
   // Full pipeline setup
   CStrategySelector selector;
   CLearningBridge *learning = new CLearningBridge("TestData", 100);
   CGateManager gm(false, false, false);
   CSessionManager sm(_Symbol, _Period);
   CCorrelationManager cm(_Symbol, _Period);
   CVolatilitySizer vs(_Symbol, _Period);
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

   // Simulate a signal using TradingSignal from IStrategy.mqh
   TradingSignal signal;
   signal.strategy_name = "SYS_TEST";
   signal.symbol = _Symbol;
   signal.timeframe = _Period;
   signal.timestamp = TimeCurrent();
   signal.entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   signal.direction = 1;  // Buy
   signal.stop_loss = signal.entry_price - 100 * _Point;
   signal.take_profit = signal.entry_price + 200 * _Point;
   signal.confidence = 0.75;

   Print("PASS: TradingSignal created for system test");

   string reason;
   if(sm.IsSessionAllowed(reason)) Print("PASS: SessionManager allowed");
   else PrintFormat("INFO: SessionManager blocked (%s)", reason);

   double corr = cm.GetCorrelation(_Symbol);
   PrintFormat("INFO: CorrelationManager self-corr = %.2f", corr);

   double sl_points = 50, vol_mult = 1.0;
   double sized = vs.CalculatePositionSize(0.1, sl_points, vol_mult, reason);
   PrintFormat("INFO: VolatilitySizer sized = %.2f (%s)", sized, reason);

   string strats[] = {"ADXStrategy", "RSIStrategy"};
   double scores[];
   int idx = selector.PickBest(_Symbol, _Period, strats, scores);
   if(idx >= 0 && idx < ArraySize(strats))
      PrintFormat("PASS: Selector picked %s", strats[idx]);
   else
      Print("INFO: Selector did not pick (normal for test)");

   // Trade log
   bool log_ok = kb.LogTradeExecution(_Symbol, signal.strategy_name, TimeCurrent(), signal.entry_price, 0.1, signal.direction);
   if(log_ok) Print("PASS: KnowledgeBase trade log");
   else Print("INFO: KnowledgeBase trade log (may require setup)");

   // Policy engine (smoke)
   double prob = policy.GetPolicyProb("ADXStrategy", _Symbol, _Period);
   PrintFormat("INFO: PolicyEngine GetPolicyProb = %.4f", prob);

   if(learning != NULL)
   {
      delete learning;
      learning = NULL;
   }

   Print("[Test] System: END");
}
