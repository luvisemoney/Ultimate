//+------------------------------------------------------------------+
//| CGateAudit.mqh - Gate System Audit Trail                         |
//| Tracks signal processing through gate pipeline                    |
//+------------------------------------------------------------------+
#ifndef CGATEAUDIT_MQH
#define CGATEAUDIT_MQH

//+------------------------------------------------------------------+
//| Gate Audit Log Entry                                              |
//+------------------------------------------------------------------+
struct SGateAuditEntry
{
   datetime timestamp;
   string   signal_id;
   string   strategy;
   string   gate_name;
   bool     passed;
   double   confidence;
   double   threshold;
   string   reason;
};

//+------------------------------------------------------------------+
//| Gate Audit Class                                                  |
//+------------------------------------------------------------------+
class CGateAudit
{
private:
   SGateAuditEntry  m_entries[];
   int              m_entry_count;
   int              m_max_entries;
   bool             m_enabled;
   int              m_min_signals_expected;
   int              m_min_uptime_minutes;
   datetime         m_start_time;
   datetime         m_last_alert_time;
   int              m_alert_cooldown_minutes;
   
   string           m_expected_strategies[];
   int              m_expected_strategy_count;
   
public:
   CGateAudit()
   {
      m_entry_count = 0;
      m_max_entries = 10000;
      m_enabled = false;
      m_min_signals_expected = 10;
      m_min_uptime_minutes = 5;
      m_start_time = TimeCurrent();
      m_last_alert_time = 0;
      m_alert_cooldown_minutes = 15;
      m_expected_strategy_count = 0;
      ArrayResize(m_entries, 0);
      ArrayResize(m_expected_strategies, 0);
   }
   
   ~CGateAudit()
   {
      ArrayResize(m_entries, 0);
      ArrayResize(m_expected_strategies, 0);
   }
   
   bool Initialize(const string strategies_csv = "")
   {
      m_start_time = TimeCurrent();
      if(strategies_csv != "")
         SetExpectedStrategies(strategies_csv);
      Print("[GateAudit] Initialized");
      return true;
   }
   
   void Configure(int min_signals, int min_uptime_min, int alert_cooldown_min)
   {
      m_min_signals_expected = min_signals;
      m_min_uptime_minutes = min_uptime_min;
      m_alert_cooldown_minutes = alert_cooldown_min;
   }
   
   void SetEnabled(bool enabled) { m_enabled = enabled; }
   bool IsEnabled() const { return m_enabled; }
   
   void LogStrategyProcessed(const string strategy_name, const string signal_id, 
                             bool passed, double confidence, const string gate_name)
   {
      if(!m_enabled) return;
      
      int idx = m_entry_count;
      if(idx >= m_max_entries)
      {
         // Shift entries to make room
         for(int i = 0; i < m_max_entries - 1; i++)
            m_entries[i] = m_entries[i + 1];
         idx = m_max_entries - 1;
      }
      else
      {
         ArrayResize(m_entries, idx + 1);
         m_entry_count++;
      }
      
      m_entries[idx].timestamp = TimeCurrent();
      m_entries[idx].signal_id = signal_id;
      m_entries[idx].strategy = strategy_name;
      m_entries[idx].gate_name = gate_name;
      m_entries[idx].passed = passed;
      m_entries[idx].confidence = confidence;
      m_entries[idx].threshold = 0.0;
      m_entries[idx].reason = passed ? "PASS" : "BLOCK";
   }
   
   void LogGateDecision(const string gate_name, const string signal_id,
                        bool passed, double confidence, double threshold,
                        const string reason)
   {
      if(!m_enabled) return;
      
      int idx = m_entry_count;
      if(idx >= m_max_entries)
      {
         for(int i = 0; i < m_max_entries - 1; i++)
            m_entries[i] = m_entries[i + 1];
         idx = m_max_entries - 1;
      }
      else
      {
         ArrayResize(m_entries, idx + 1);
         m_entry_count++;
      }
      
      m_entries[idx].timestamp = TimeCurrent();
      m_entries[idx].signal_id = signal_id;
      m_entries[idx].strategy = "";
      m_entries[idx].gate_name = gate_name;
      m_entries[idx].passed = passed;
      m_entries[idx].confidence = confidence;
      m_entries[idx].threshold = threshold;
      m_entries[idx].reason = reason;
   }
   
   bool RunAudit(string &skipped_strategies, int &skipped_count)
   {
      if(!m_enabled) return false;
      
      skipped_strategies = "";
      skipped_count = 0;
      
      datetime now = TimeCurrent();
      int uptime_minutes = (int)((now - m_start_time) / 60);
      
      // Check if enough signals have been processed
      if(uptime_minutes >= m_min_uptime_minutes)
      {
         if(m_entry_count < m_min_signals_expected)
         {
            // Check cooldown
            if(m_last_alert_time == 0 || 
               (now - m_last_alert_time) / 60 >= m_alert_cooldown_minutes)
            {
               Print("[GateAudit] ALERT: Only " + IntegerToString(m_entry_count) + 
                     " signals processed in " + IntegerToString(uptime_minutes) + 
                     " minutes (expected: " + IntegerToString(m_min_signals_expected) + ")");
               m_last_alert_time = now;
               return false;
            }
         }
      }
      
      return true;
   }
   
   int GetProcessedSignalCount() const { return m_entry_count; }
   
   int GetPassCount()
   {
      int count = 0;
      for(int i = 0; i < m_entry_count; i++)
      {
         if(m_entries[i].passed)
            count++;
      }
      return count;
   }
   
   int GetBlockCount()
   {
      int count = 0;
      for(int i = 0; i < m_entry_count; i++)
      {
         if(!m_entries[i].passed)
            count++;
      }
      return count;
   }
   
   void GetAuditReport(string &report)
   {
      report = "=== Gate Audit Report ===\n";
      report += "Total entries: " + IntegerToString(m_entry_count) + "\n";
      report += "Passed: " + IntegerToString(GetPassCount()) + "\n";
      report += "Blocked: " + IntegerToString(GetBlockCount()) + "\n";
      
      datetime now = TimeCurrent();
      int uptime_minutes = (int)((now - m_start_time) / 60);
      report += "Uptime: " + IntegerToString(uptime_minutes) + " minutes\n";
   }
   
   void Clear()
   {
      ArrayResize(m_entries, 0);
      m_entry_count = 0;
   }
   
   void SetExpectedStrategies(const string &strategies_csv)
   {
      // Parse comma-separated strategy names
      string temp = strategies_csv;
      m_expected_strategy_count = 0;
      ArrayResize(m_expected_strategies, 0);
      
      int pos = 0;
      while(StringFind(temp, ",", pos) != -1 || StringLen(temp) > 0)
      {
         int comma_pos = StringFind(temp, ",", pos);
         string strategy;
         if(comma_pos == -1)
         {
            strategy = StringSubstr(temp, pos);
            temp = "";
         }
         else
         {
            strategy = StringSubstr(temp, pos, comma_pos - pos);
            pos = comma_pos + 1;
         }
         
         StringTrimLeft(strategy);
         StringTrimRight(strategy);
         
         if(StringLen(strategy) > 0)
         {
            int idx = m_expected_strategy_count;
            ArrayResize(m_expected_strategies, idx + 1);
            m_expected_strategies[idx] = strategy;
            m_expected_strategy_count++;
         }
      }
   }
   
   int GetExpectedStrategyCount() const { return m_expected_strategy_count; }
   
   string GetExpectedStrategy(int index) const
   {
      if(index >= 0 && index < m_expected_strategy_count)
         return m_expected_strategies[index];
      return "";
   }
};

// Global instance for PaperEA
CGateAudit g_gate_audit;

#endif // CGATEAUDIT_MQH
