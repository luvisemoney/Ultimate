// Include guard for InsightsGate
#ifndef __DUALEA_INSIGHTS_GATE_MQH__
#define __DUALEA_INSIGHTS_GATE_MQH__
//+------------------------------------------------------------------+
//| InsightsGate.mqh                                                 |
//| Purpose: Insights gating & exploration quotas management         |
//| Status: Full implementation with quota tracking                   |
//+------------------------------------------------------------------+

class CInsightsGate
  {
private:
   string   m_explore_keys[];
   int      m_explore_values[];
   string   m_daily_keys[];
   int      m_daily_values[];
   string   m_reset_keys[];
   datetime m_reset_times[];

   int m_max_explores_per_hour;              // Maximum explorations per hour
   int m_max_explores_per_day;               // Maximum explorations per day
   int m_max_explores_per_strategy;          // Maximum per strategy-symbol pair
   
   int FindKeyIndex(const string key, string &keys[]) const
     {
      for(int i=0;i<ArraySize(keys);++i)
         if(keys[i]==key)
            return i;
      return -1;
     }
   
   int GetIntValue(const string key, string &keys[], int &values[]) const
     {
      int idx=FindKeyIndex(key, keys);
      if(idx<0)
         return 0;
      return values[idx];
     }
   
   void SetIntValue(const string key, const int value, string &keys[], int &values[])
     {
      int idx=FindKeyIndex(key, keys);
      if(idx<0)
        {
         int size=ArraySize(keys);
         ArrayResize(keys, size+1);
         ArrayResize(values, size+1);
         keys[size]=key;
         values[size]=value;
        }
      else
        {
         values[idx]=value;
        }
     }
   
   void ClearKey(const string key, string &keys[], int &values[])
     {
      int idx=FindKeyIndex(key, keys);
      if(idx>=0)
        {
         // Shrink by swapping with last element for O(1) removal
         int last=ArraySize(keys)-1;
         if(idx!=last)
           {
            keys[idx]=keys[last];
            values[idx]=values[last];
           }
         ArrayResize(keys, last);
         ArrayResize(values, last);
        }
     }
   
   bool TryGetReset(const string key, datetime &value) const
     {
      for(int i=0;i<ArraySize(m_reset_keys);++i)
        {
         if(m_reset_keys[i]==key)
           {
            value=m_reset_times[i];
            return true;
           }
        }
      return false;
     }
   
   void SetReset(const string key, const datetime value)
     {
      int idx=FindKeyIndex(key, m_reset_keys);
      if(idx<0)
        {
         int size=ArraySize(m_reset_keys);
         ArrayResize(m_reset_keys, size+1);
         ArrayResize(m_reset_times, size+1);
         m_reset_keys[size]=key;
         m_reset_times[size]=value;
        }
      else
        {
         m_reset_times[idx]=value;
        }
     }

   string GetHourKey(const string strategy, const string symbol, const ENUM_TIMEFRAMES timeframe)
     {
      datetime now = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(now, dt);
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
      if(TryGetReset(key, last_reset_time))
        {
         // Reset hourly counts every hour
         if(current_time - last_reset_time >= 3600) // 1 hour
           {
            ClearKey(key, m_explore_keys, m_explore_values);
            SetReset(key, current_time);
           }
        }
      else
        {
         SetReset(key, current_time);
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
      int hour_count = GetIntValue(hour_key, m_explore_keys, m_explore_values);
      if(hour_count >= m_max_explores_per_hour)
        {
         reason = StringFormat("hourly_quota_exceeded_%d", m_max_explores_per_hour);
         return false;
        }
      
      // Check daily quota
      int day_count = GetIntValue(day_key, m_daily_keys, m_daily_values);
      if(day_count >= m_max_explores_per_day)
        {
         reason = StringFormat("daily_quota_exceeded_%d", m_max_explores_per_day);
         return false;
        }
      
      // Check per-strategy quota
      int strategy_count = GetIntValue(strategy_key, m_explore_keys, m_explore_values);
      if(strategy_count >= m_max_explores_per_strategy)
        {
         reason = StringFormat("strategy_quota_exceeded_%d", m_max_explores_per_strategy);
         return false;
        }
      
      // All quotas passed - increment counters and allow
      SetIntValue(hour_key, hour_count + 1, m_explore_keys, m_explore_values);
      SetIntValue(day_key, day_count + 1, m_daily_keys, m_daily_values);
      SetIntValue(strategy_key, strategy_count + 1, m_explore_keys, m_explore_values);
      
      reason = StringFormat("allowed_h%d_d%d_s%d", hour_count + 1, day_count + 1, strategy_count + 1);
      return true;
     }

   int GetExploreCount(const string key) const 
     { 
      return GetIntValue(key, m_explore_keys, m_explore_values);
     }
   
   int GetExploreCountDay(const string key) const 
     { 
      return GetIntValue(key, m_daily_keys, m_daily_values);
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
      ArrayResize(m_explore_keys, 0);
      ArrayResize(m_explore_values, 0);
      ArrayResize(m_daily_keys, 0);
      ArrayResize(m_daily_values, 0);
      ArrayResize(m_reset_keys, 0);
      ArrayResize(m_reset_times, 0);
     }
  };

#endif // __DUALEA_INSIGHTS_GATE_MQH__
