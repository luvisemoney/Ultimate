//+------------------------------------------------------------------+
//| Test_VolatilitySizer.mq5                                         |
//| Unit test for CVolatilitySizer                                   |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include "..\\Include\\VolatilitySizer.mqh"

input int Verbosity = 2;

void OnStart()
{
   Print("[Test] CVolatilitySizer: BEGIN");
   CVolatilitySizer vs(_Symbol, _Period);
   vs.SetATRPeriod(14);
   vs.SetBaseATRPercent(0.5);
   vs.SetMultiplierRange(0.5, 2.0);
   vs.SetTargetRiskPercent(1.0);
   vs.SetEnabled(true);

   double base_vol = 0.1;
   double sl_points = 50;
   double vol_mult = 1.0;
   string reason = "";
   double result = vs.CalculatePositionSize(base_vol, sl_points, vol_mult, reason);
   if(result > 0)
      PrintFormat("PASS: CalculatePositionSize returned %.2f (%s)", result, reason);
   else
      Print("FAIL: CalculatePositionSize returned non-positive");

   Print("[Test] CVolatilitySizer: END");
}
