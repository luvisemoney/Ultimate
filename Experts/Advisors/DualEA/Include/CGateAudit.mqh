#ifndef DUALEA_GATE_AUDIT_MQH
#define DUALEA_GATE_AUDIT_MQH
// Tracks signal coverage for each registered strategy.
class CGateAudit
{
private:
   string m_names[];
   int m_counts[];
   bool m_enabled;
   int m_min_signals, m_min_uptime, m_cooldown;
   datetime m_started, m_last_alert;
public:
   CGateAudit() : m_enabled(false), m_min_signals(1), m_min_uptime(5), m_cooldown(30), m_started(0), m_last_alert(0) {}
   void Initialize(string strategies)
   {
      int count = StringSplit(strategies, ',', m_names);
      ArrayResize(m_counts, count);
      ArrayInitialize(m_counts, 0);
      m_started = TimeCurrent();
      m_last_alert = 0;
   }
   void Configure(int signals, int uptime, int cooldown)
   {
      m_min_signals = MathMax(0, signals);
      m_min_uptime = MathMax(0, uptime);
      m_cooldown = MathMax(0, cooldown);
   }
   void SetEnabled(bool enabled) { m_enabled = enabled; }
   void LogStrategyProcessed(string strategy, string id, bool passed, double confidence, string reason)
   {
      if(!m_enabled) return;
      for(int i=0; i<ArraySize(m_names); i++)
         if(m_names[i] == strategy) { m_counts[i]++; break; }
      string skipped;
      int count;
      RunAudit(skipped, count);
   }
   bool RunAudit(string &skipped_strategies, int &skipped_count)
   {
      skipped_strategies = "";
      skipped_count = 0;
      if(!m_enabled || TimeCurrent()-m_started < m_min_uptime*60) return true;
      for(int i=0; i<ArraySize(m_names); i++)
         if(m_counts[i] < m_min_signals)
         {
            if(skipped_count > 0) skipped_strategies += ",";
            skipped_strategies += m_names[i];
            skipped_count++;
         }
      if(skipped_count > 0 && (m_last_alert == 0 || TimeCurrent()-m_last_alert >= m_cooldown*60))
      {
         Print("[GateAudit] Strategies below signal coverage: ", skipped_strategies);
         m_last_alert = TimeCurrent();
      }
      return skipped_count == 0;
   }
};
CGateAudit g_gate_audit;
#endif
