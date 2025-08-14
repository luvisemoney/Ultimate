//+------------------------------------------------------------------+
//|                                                 KBAppendSmoke.mq5|
//|                      Non-trading KB append smoke test (DualEA)   |
//+------------------------------------------------------------------+
#property script_show_inputs
#property strict

#include <KnowledgeBase.mqh>

void OnStart()
{
   // Use the shared KB path in Common Files
   CKnowledgeBase kb("DualEA\\knowledge_base.csv", ",");

   TradeRecord r;
   r.timestamp    = TimeCurrent();
   r.symbol       = "KB_SMOKE";         // clearly tagged test symbol
   r.type         = ORDER_TYPE_BUY;
   r.entry_price  = 0.0;
   r.stop_loss    = 0.0;
   r.take_profit  = 0.0;
   r.close_price  = 0.0;
   r.profit       = 0.0;
   r.strategy_id  = "KBAppendSmoke";    // test tag 1

   bool ok1 = kb.WriteRecord(r);
   Sleep(50);

   r.timestamp    = TimeCurrent();
   r.strategy_id  = "KBAppendSmoke2";   // test tag 2
   bool ok2 = kb.WriteRecord(r);

   PrintFormat("KBAppendSmoke: write1=%s, write2=%s (to Common Files \\DualEA\\knowledge_base.csv)",
               ok1?"OK":"FAIL", ok2?"OK":"FAIL");
}
