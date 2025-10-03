//+------------------------------------------------------------------+
//| Test_CorrelationManager.mq5                                      |
//| Unit test for CCorrelationManager                                |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include "..\\Include\\CorrelationManager.mqh"

input int Verbosity = 2;

void OnStart()
{
   Print("[Test] CCorrelationManager: BEGIN");
   CCorrelationManager cm(_Symbol, _Period);
   cm.SetMaxCorrelation(0.8);
   cm.SetLookbackDays(30);

   // Test: GetCorrelation for self
   double corr = cm.GetCorrelation(_Symbol);
   if(MathAbs(corr - 1.0) < 0.01)
      Print("PASS: GetCorrelation(_Symbol, _Symbol) ~ 1.0");
   else
      PrintFormat("FAIL: GetCorrelation(_Symbol, _Symbol) = %.4f", corr);

   // Test: GetCorrelation for random symbol
   corr = cm.GetCorrelation("FAKESYM");
   PrintFormat("INFO: GetCorrelation(_Symbol, FAKESYM) = %.4f", corr);

   Print("[Test] CCorrelationManager: END");
}
