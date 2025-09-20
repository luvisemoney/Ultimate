#ifndef __TELEMETRY_MQH__
#define __TELEMETRY_MQH__

class CTelemetry
  {
public:
   CTelemetry() {}
   ~CTelemetry() {}

   void LogGatingShadow(const string strategy,
                        const string symbol,
                        const int timeframe,
                        const string stage,
                        const bool allowed,
                        const string reason,
                        const bool no_constraints_active)
     {
       // no-op stub
     }

   void LogGating(const string symbol,
                  const int timeframe,
                  const string strategy,
                  const string stage,
                  const bool allowed,
                  const string reason)
     {
       // no-op stub
     }

   void LogTradeExecuted(const string strategy,
                         const string symbol,
                         const int timeframe,
                         const int retcode,
                         const ulong deal,
                         const ulong order_id)
     {
       // no-op stub
     }

   void LogTradeFailed(const string strategy,
                       const string symbol,
                       const int timeframe,
                       const int error_code)
     {
       // no-op stub
     }

   void LogEvent(const string symbol,
                 const int timeframe,
                 const string strategy,
                 const string event,
                 const string details)
     {
       // no-op stub
     }
  };

#endif // __TELEMETRY_MQH__
