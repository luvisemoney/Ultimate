//+------------------------------------------------------------------+
//| Test_SessionManager.mq5                                          |
//| Unit test for CSessionManager                                    |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include "../Include/SessionManager.mqh"

input int Verbosity = 2;

void OnStart()
{
   Print("[Test] CSessionManager: BEGIN");
   CSessionManager sm(_Symbol, _Period);
   sm.SetSessionHours(9, 17);
   sm.SetMaxTradesPerSession(3);

   string reason;
   if(sm.IsSessionAllowed(reason))
      Print("PASS: IsSessionAllowed (during session)");
   else
      PrintFormat("FAIL: IsSessionAllowed returned false (%s)", reason);

   // Simulate max trades
   for(int i=0; i<3; ++i) sm.RecordTrade();
   if(!sm.IsSessionAllowed(reason))
      Print("PASS: IsSessionAllowed blocks after max trades");
   else
      Print("FAIL: IsSessionAllowed did not block after max trades");

   sm.ResetSession();
   if(sm.IsSessionAllowed(reason))
      Print("PASS: ResetSession allows trading again");
   else
      Print("FAIL: ResetSession did not reset");

   Print("[Test] CSessionManager: END");
}
