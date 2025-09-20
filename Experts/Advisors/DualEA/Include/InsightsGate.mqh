// Include guard for InsightsGate
#ifndef __DUALEA_INSIGHTS_GATE_MQH__
#define __DUALEA_INSIGHTS_GATE_MQH__
//+------------------------------------------------------------------+
//| InsightsGate.mqh                                                 |
//| Purpose: Placeholder for insights gating & exploration quotas    |
//| Status: Stub only – not referenced by EAs yet                    |
//+------------------------------------------------------------------+

class CInsightsGate
  {
public:
   CInsightsGate() {}

   bool Allow(const string strategy,const string symbol,const ENUM_TIMEFRAMES timeframe,string &reason)
     {
      reason = "stub";
      return true; // always allow in stub
     }

   int GetExploreCount(const string key) const { return 0; }
   int GetExploreCountDay(const string key) const { return 0; }
  };

#endif // __DUALEA_INSIGHTS_GATE_MQH__
