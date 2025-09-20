// Include guard for TelemetrySupport
#ifndef __DUALEA_TELEMETRY_SUPPORT_MQH__
#define __DUALEA_TELEMETRY_SUPPORT_MQH__
//+------------------------------------------------------------------+
//| TelemetrySupport.mqh                                            |
//| Purpose: Placeholder wrappers for telemetry emission             |
//| Status: Stub only – not referenced by EAs yet                    |
//+------------------------------------------------------------------+

class CTelemetrySupport
  {
public:
   CTelemetrySupport() {}

   void LogGating(const string symbol,const int timeframe,const string strategy,const string gate,const bool allow,const string reason)
     {
      // Stub: no-op
     }

   void LogGatingShadow(const string strategy,const string symbol,const int timeframe,const string gate,const bool allow,const string reason,const bool shadow)
     {
      // Stub: no-op
     }

   void Flush()
     {
      // Stub: no-op
     }
  };

#endif // __DUALEA_TELEMETRY_SUPPORT_MQH__
