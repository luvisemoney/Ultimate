// include guard for MQL5
#ifndef __POLICYENGINE_MQH__
#define __POLICYENGINE_MQH__
//+------------------------------------------------------------------+
//| PolicyEngine.mqh                                                 |
//| Purpose: Placeholder for centralized policy loading/queries      |
//| Status: Stub only – not referenced by EAs yet                    |
//+------------------------------------------------------------------+

class CPolicyEngine
  {
public:
   CPolicyEngine() {}

   bool Load(const string path)
     {
      // Stub: pretend load succeeded
      return true;
     }

   double GetPolicyProb(const string strategy,const string symbol,const ENUM_TIMEFRAMES timeframe) const
     {
      // Sanity: invalid timeframe -> unknown
      if((int)timeframe<=0) return -1.0;
      // Stub implementation returns unknown slice; always a valid number
      double p = -1.0;
      // Defensive: never return NaN
      if(!MathIsValidNumber(p)) return -1.0;
      // Clamp to [0,1] if it ever becomes a probability in future implementation
      if(p<0.0) return -1.0;
      if(p>1.0) p = 1.0;
      return p;
     }

   bool HasSlice(const string strategy,const string symbol,const ENUM_TIMEFRAMES timeframe) const
    {
     // Stub: report missing by default
     return false;
    }
 };

#endif // __POLICYENGINE_MQH__
