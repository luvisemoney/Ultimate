// Include guard for TelemetrySupport
#ifndef __DUALEA_TELEMETRY_SUPPORT_MQH__
#define __DUALEA_TELEMETRY_SUPPORT_MQH__
//+------------------------------------------------------------------+
//| TelemetrySupport.mqh                                            |
//| Purpose: Advanced telemetry wrappers with buffering & filtering  |
//| Status: Full implementation with performance optimization         |
//+------------------------------------------------------------------+

#include "Telemetry.mqh"
#include <Generic/HashMap.mqh>

class CTelemetrySupport
  {
private:
   CTelemetry* m_telemetry;
   bool m_owns_telemetry;
   
   // Rate limiting and deduplication
   CHashMap<string,datetime> m_last_log_time;
   CHashMap<string,int> m_log_counts;
   int m_rate_limit_seconds;
   int m_max_duplicate_logs;
   
   // Performance metrics
   int m_total_logs;
   int m_filtered_logs;
   datetime m_start_time;
   
   string GetLogKey(const string symbol, const int timeframe, const string strategy, const string gate, const string reason)
     {
      return StringFormat("%s_%d_%s_%s_%s", symbol, timeframe, strategy, gate, reason);
     }
   
   bool ShouldLog(const string key)
     {
      datetime now = TimeCurrent();
      datetime last_time;
      int count;
      
      // Check rate limiting
      if(m_last_log_time.TryGetValue(key, last_time))
        {
         if(now - last_time < m_rate_limit_seconds)
           {
            // Within rate limit window - check duplicate count
            if(m_log_counts.TryGetValue(key, count))
              {
               if(count >= m_max_duplicate_logs)
                 {
                  m_filtered_logs++;
                  return false; // Too many duplicates
                 }
               m_log_counts.Add(key, count + 1);
              }
            else
              {
               m_log_counts.Add(key, 1);
              }
           }
         else
           {
            // Outside rate limit window - reset counters
            m_last_log_time.Add(key, now);
            m_log_counts.Add(key, 1);
           }
        }
      else
        {
         // First time logging this key
         m_last_log_time.Add(key, now);
         m_log_counts.Add(key, 1);
        }
      
      m_total_logs++;
      return true;
     }

public:
   CTelemetrySupport(CTelemetry* telemetry = NULL, int rate_limit_seconds = 5, int max_duplicate_logs = 10)
     {
      if(telemetry == NULL)
        {
         m_telemetry = new CTelemetry("DualEA\\telemetry", "support", 1, 128);
         m_owns_telemetry = true;
        }
      else
        {
         m_telemetry = telemetry;
         m_owns_telemetry = false;
        }
      
      m_rate_limit_seconds = rate_limit_seconds;
      m_max_duplicate_logs = max_duplicate_logs;
      m_total_logs = 0;
      m_filtered_logs = 0;
      m_start_time = TimeCurrent();
     }
   
   ~CTelemetrySupport()
     {
      if(m_owns_telemetry && m_telemetry != NULL)
        {
         delete m_telemetry;
        }
     }

   void LogGating(const string symbol, const int timeframe, const string strategy, const string gate, const bool allow, const string reason)
     {
      if(m_telemetry == NULL) return;
      
      string key = GetLogKey(symbol, timeframe, strategy, gate, reason);
      if(ShouldLog(key))
        {
         m_telemetry.LogGating(symbol, timeframe, strategy, gate, allow, reason);
        }
     }

   void LogGatingShadow(const string strategy, const string symbol, const int timeframe, const string gate, const bool allow, const string reason, const bool shadow)
     {
      if(m_telemetry == NULL) return;
      
      string key = GetLogKey(symbol, timeframe, strategy, gate, reason) + (shadow ? "_shadow" : "_normal");
      if(ShouldLog(key))
        {
         m_telemetry.LogGatingShadow(strategy, symbol, timeframe, gate, allow, reason, shadow);
        }
     }
   
   void LogEvent(const string symbol, const int timeframe, const string strategy, const string event, const string details)
     {
      if(m_telemetry == NULL) return;
      
      string key = GetLogKey(symbol, timeframe, strategy, event, details);
      if(ShouldLog(key))
        {
         m_telemetry.LogEvent(symbol, timeframe, strategy, event, details);
        }
     }
   
   void LogTradeExecuted(const string strategy, const string symbol, const int timeframe, const int retcode, const ulong deal, const ulong order_id)
     {
      if(m_telemetry == NULL) return;
      
      // Trade executions are always logged (no rate limiting)
      m_telemetry.LogTradeExecuted(strategy, symbol, timeframe, retcode, deal, order_id);
      m_total_logs++;
     }
   
   void LogTradeFailed(const string strategy, const string symbol, const int timeframe, const int error_code)
     {
      if(m_telemetry == NULL) return;
      
      // Trade failures are always logged (no rate limiting)
      m_telemetry.LogTradeFailed(strategy, symbol, timeframe, error_code);
      m_total_logs++;
     }

   void Flush()
     {
      if(m_telemetry != NULL)
        {
         m_telemetry.Flush();
        }
     }
   
   // Performance and statistics methods
   void GetStats(int &total_logs, int &filtered_logs, double &filter_rate, int &uptime_seconds)
     {
      total_logs = m_total_logs;
      filtered_logs = m_filtered_logs;
      filter_rate = (m_total_logs > 0) ? (double)m_filtered_logs / m_total_logs * 100.0 : 0.0;
      uptime_seconds = (int)(TimeCurrent() - m_start_time);
     }
   
   void PrintStats()
     {
      int total, filtered, uptime;
      double rate;
      GetStats(total, filtered, rate, uptime);
      
      PrintFormat("TelemetrySupport Stats: Total=%d, Filtered=%d (%.1f%%), Uptime=%ds, Rate=%d/s", 
                  total, filtered, rate, uptime, 
                  (uptime > 0) ? total / uptime : 0);
     }
   
   // Configuration methods
   void SetRateLimit(int seconds) { m_rate_limit_seconds = seconds; }
   void SetMaxDuplicates(int max_dups) { m_max_duplicate_logs = max_dups; }
   
   // Clear rate limiting history (for testing or reset)
   void ClearRateLimitHistory()
     {
      m_last_log_time.Clear();
      m_log_counts.Clear();
     }
  };

#endif // __DUALEA_TELEMETRY_SUPPORT_MQH__
