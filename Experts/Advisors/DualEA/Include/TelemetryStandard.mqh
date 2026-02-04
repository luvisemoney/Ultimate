//+------------------------------------------------------------------+
//| TelemetryStandard.mqh - Efficient Telemetry for DualEA           |
//+------------------------------------------------------------------+
#ifndef __DUALEA_TELEMETRYSTANDARD_MQH__
#define __DUALEA_TELEMETRYSTANDARD_MQH__

#property copyright "DualEA"
#property version   "1.00"

// Use the full CTelemetry implementation
#include "Telemetry.mqh"

//+------------------------------------------------------------------+
//| Standardized telemetry event types and schemas                  |
//+------------------------------------------------------------------+

// Event type prefixes for consistent categorization
#define TEL_GATE_PREFIX    "gate:"
#define TEL_EXEC_PREFIX    "exec:"
#define TEL_CB_PREFIX      "cb:"
#define TEL_PM_PREFIX      "pm:"
#define TEL_CORR_PREFIX    "corr:"
#define TEL_VOL_PREFIX     "vol:"
#define TEL_SESSION_PREFIX "session:"

//+------------------------------------------------------------------+
//| Gate telemetry events                                           |
//+------------------------------------------------------------------+
class CTelemetryStandard
{
private:
   CTelemetry* m_telemetry;
   
public:
   CTelemetryStandard(CTelemetry* tel) : m_telemetry(tel) {}
   
   // Gate events with standardized schema
   void LogGateEvent(const string symbol, const int timeframe, const string gate_name, 
                     const bool allowed, const string phase, const int latency_ms, 
                     const string reason = "ok")
   {
      if(!m_telemetry) return;
      
      string event_key = StringFormat("%s%s_%s", TEL_GATE_PREFIX, gate_name, (allowed ? "allow" : "block"));
      string details = StringFormat("phase=%s p6_latency_ms=%d reason=%s", phase, latency_ms, reason);
      
      m_telemetry.LogEvent(symbol, timeframe, "gate", event_key, details);
   }
   
   // Execution events
   void LogExecEvent(const string symbol, const int timeframe, const string strategy_name,
                     const string exec_type, const bool success, const int latency_ms,
                     const double volume = 0.0, const double price = 0.0)
   {
      if(!m_telemetry) return;
      
      string event_key = StringFormat("%s%s_%s", TEL_EXEC_PREFIX, exec_type, (success ? "success" : "failed"));
      string details = StringFormat("strategy=%s latency_ms=%d volume=%.2f price=%.5f", 
                                   strategy_name, latency_ms, volume, price);
      
      m_telemetry.LogEvent(symbol, timeframe, "execution", event_key, details);
   }
   
   // Circuit breaker events
   void LogCircuitBreakerEvent(const string symbol, const int timeframe, const string cb_type,
                              const string action, const double threshold, const double current_value)
   {
      if(!m_telemetry) return;
      
      string event_key = StringFormat("%s%s_%s", TEL_CB_PREFIX, cb_type, action);
      string details = StringFormat("threshold=%.2f current=%.2f", threshold, current_value);
      
      m_telemetry.LogEvent(symbol, timeframe, "circuit_breaker", event_key, details);
   }
   
   // Position Manager events
   void LogPositionManagerEvent(const string symbol, const int timeframe, const string pm_action,
                               const ulong position_id, const double price, const string reason = "")
   {
      if(!m_telemetry) return;
      
      string event_key = StringFormat("%s%s", TEL_PM_PREFIX, pm_action);
      string details = StringFormat("position_id=%I64u price=%.5f reason=%s", position_id, price, reason);
      
      m_telemetry.LogEvent(symbol, timeframe, "position_manager", event_key, details);
   }
   
   // Correlation events
   void LogCorrelationEvent(const string symbol, const int timeframe, const string corr_action,
                           const double correlation, const double threshold, const string correlated_symbol = "")
   {
      if(!m_telemetry) return;
      
      string event_key = StringFormat("%s%s", TEL_CORR_PREFIX, corr_action);
      string details = StringFormat("correlation=%.3f threshold=%.3f corr_symbol=%s", 
                                   correlation, threshold, correlated_symbol);
      
      m_telemetry.LogEvent(symbol, timeframe, "correlation", event_key, details);
   }
   
   // Volatility sizing events
   void LogVolatilitySizingEvent(const string symbol, const int timeframe, const double base_size,
                                const double vol_multiplier, const double final_size, const double atr_pct)
   {
      if(!m_telemetry) return;
      
      string event_key = StringFormat("%svol_sizing", TEL_VOL_PREFIX);
      string details = StringFormat("base_size=%.2f vol_mult=%.3f final_size=%.2f atr_pct=%.2f", 
                                   base_size, vol_multiplier, final_size, atr_pct);
      
      m_telemetry.LogEvent(symbol, timeframe, "volatility", event_key, details);
   }
   
   // Generic gate parameter event (for adaptive thresholds / context)
   void LogGateParams(const string symbol, const int timeframe, const string gate_name, const string details)
   {
      if(!m_telemetry) return;
      string event_key = StringFormat("%s%s_params", TEL_GATE_PREFIX, gate_name);
      m_telemetry.LogEvent(symbol, timeframe, "gate_params", event_key, details);
   }

   void LogGateSanitize(const string symbol,
                        const int timeframe,
                        const string gate_name,
                        const double severity,
                        const double sl_gap,
                        const double tp_gap,
                        const double volume)
   {
      if(!m_telemetry) return;

      string event_key = "gate:sanitize";
      string fields = StringFormat("\"gate\":%s,\"severity\":%.6f,\"sl_gap\":%.6f,\"tp_gap\":%.6f,\"volume\":%.2f",
                                   m_telemetry.JsonQuote(gate_name),
                                   severity,
                                   sl_gap,
                                   tp_gap,
                                   volume);

      m_telemetry.LogEventJson(symbol, timeframe, "gate_sanitize", event_key, fields);
   }
   
   // Session events
   void LogSessionEvent(const string symbol, const int timeframe, const string session_action,
                       const int trades_count, const int max_trades, const double pnl = 0.0)
   {
      if(!m_telemetry) return;
      
      string event_key = StringFormat("%s%s", TEL_SESSION_PREFIX, session_action);
      string details = StringFormat("trades=%d max_trades=%d pnl=%.2f", trades_count, max_trades, pnl);
      
      m_telemetry.LogEvent(symbol, timeframe, "session", event_key, details);
   }
};

#endif // __DUALEA_TELEMETRYSTANDARD_MQH__
