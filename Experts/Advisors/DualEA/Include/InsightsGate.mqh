// Include guard for InsightsGate
#ifndef __DUALEA_INSIGHTS_GATE_MQH__
#define __DUALEA_INSIGHTS_GATE_MQH__
//+------------------------------------------------------------------+
//| InsightsGate.mqh                                                 |
//| Purpose: Insights gating & exploration quotas management         |
//| Status: Full implementation with quota tracking                   |
//+------------------------------------------------------------------+

#include <Generic/HashMap.mqh>

class CInsightsGate
  {
private:
   CHashMap<string,int> m_explore_counts;     // Per-key exploration counts
   CHashMap<string,int> m_daily_counts;      // Daily exploration counts
   CHashMap<string,datetime> m_last_reset;   // Last reset timestamps
   
   int m_max_explores_per_hour;              // Maximum explorations per hour
   int m_max_explores_per_day;               // Maximum explorations per day
   int m_max_explores_per_strategy;          // Maximum per strategy-symbol pair
   
   string GetHourKey(const string strategy, const string symbol, const ENUM_TIMEFRAMES timeframe)
     {
      datetime now = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(now, dt);
      return StringFormat("%s_%s_%d_%04d%02d%02d_%02d", strategy, symbol, (int)timeframe, dt.year, dt.mon, dt.day, dt.hour);
     }
   
   string GetDayKey(const string strategy, const string symbol, const ENUM_TIMEFRAMES timeframe)
     {
      datetime now = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(now, dt);
      return StringFormat("%s_%s_%d_%04d%02d%02d", strategy, symbol, (int)timeframe, dt.year, dt.mon, dt.day);
     }
   
   string GetStrategyKey(const string strategy, const string symbol, const ENUM_TIMEFRAMES timeframe)
     {
      return StringFormat("%s_%s_%d", strategy, symbol, (int)timeframe);
     }
   
   void ResetIfNeeded(const string key, const datetime current_time)
     {
      datetime last_reset_time;
      if(m_last_reset.TryGetValue(key, last_reset_time))
        {
         // Reset hourly counts every hour
         if(current_time - last_reset_time >= 3600) // 1 hour
           {
            m_explore_counts.Remove(key);
            m_last_reset.Add(key, current_time);
           }
        }
      else
        {
         m_last_reset.Add(key, current_time);
        }
     }

public:
   CInsightsGate(int max_per_hour=10, int max_per_day=50, int max_per_strategy=5)
     {
      m_max_explores_per_hour = max_per_hour;
      m_max_explores_per_day = max_per_day;
      m_max_explores_per_strategy = max_per_strategy;
     }

   bool Allow(const string strategy, const string symbol, const ENUM_TIMEFRAMES timeframe, string &reason)
     {
      datetime now = TimeCurrent();
      
      // Generate keys for different quota levels
      string hour_key = GetHourKey(strategy, symbol, timeframe);
      string day_key = GetDayKey(strategy, symbol, timeframe);
      string strategy_key = GetStrategyKey(strategy, symbol, timeframe);
      
      // Reset counters if needed
      ResetIfNeeded(hour_key, now);
      
      // Check hourly quota
      int hour_count = 0;
      if(m_explore_counts.TryGetValue(hour_key, hour_count))
        {
         if(hour_count >= m_max_explores_per_hour)
           {
            reason = StringFormat("hourly_quota_exceeded_%d", m_max_explores_per_hour);
            return false;
           }
        }
      
      // Check daily quota
      int day_count = 0;
      if(m_daily_counts.TryGetValue(day_key, day_count))
        {
         if(day_count >= m_max_explores_per_day)
           {
            reason = StringFormat("daily_quota_exceeded_%d", m_max_explores_per_day);
            return false;
           }
        }
      
      // Check per-strategy quota
      int strategy_count = 0;
      if(m_explore_counts.TryGetValue(strategy_key, strategy_count))
        {
         if(strategy_count >= m_max_explores_per_strategy)
           {
            reason = StringFormat("strategy_quota_exceeded_%d", m_max_explores_per_strategy);
            return false;
           }
        }
      
      // All quotas passed - increment counters and allow
      m_explore_counts.Add(hour_key, hour_count + 1);
      m_daily_counts.Add(day_key, day_count + 1);
      m_explore_counts.Add(strategy_key, strategy_count + 1);
      
      reason = StringFormat("allowed_h%d_d%d_s%d", hour_count + 1, day_count + 1, strategy_count + 1);
      return true;
     }

   int GetExploreCount(const string key) const 
     { 
      int count = 0;
      m_explore_counts.TryGetValue(key, count);
      return count;
     }
   
   int GetExploreCountDay(const string key) const 
     { 
      int count = 0;
      m_daily_counts.TryGetValue(key, count);
      return count;
     }
   
   // Get exploration statistics
   void GetStats(const string strategy, const string symbol, const ENUM_TIMEFRAMES timeframe, 
                 int &hour_count, int &day_count, int &strategy_count)
     {
      string hour_key = GetHourKey(strategy, symbol, timeframe);
      string day_key = GetDayKey(strategy, symbol, timeframe);
      string strategy_key = GetStrategyKey(strategy, symbol, timeframe);
      
      hour_count = GetExploreCount(hour_key);
      day_count = GetExploreCountDay(day_key);
      strategy_count = GetExploreCount(strategy_key);
     }
   
   // Reset all quotas (for testing or manual reset)
   void ResetAllQuotas()
     {
      m_explore_counts.Clear();
      m_daily_counts.Clear();
      m_last_reset.Clear();
     }
  };

#endif // __DUALEA_INSIGHTS_GATE_MQH__
