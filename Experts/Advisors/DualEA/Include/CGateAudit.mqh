//+------------------------------------------------------------------+
//| CGateAudit.mqh                                                   |
//| Gate system audit and performance tracking                       |
//| Tracks strategy performance through gate system                  |
//+------------------------------------------------------------------+
#ifndef CGATEAUDIT_MQH
#define CGATEAUDIT_MQH

#include "IStrategy.mqh"
#include "Arrays/ArrayObj.mqh"

//+------------------------------------------------------------------+
//| Strategy Audit Record                                            |
//+------------------------------------------------------------------+
struct SStrategyAudit
{
   string   strategy_name;
   int      total_signals;
   int      passed_gates;
   int      failed_gates;
   int      profitable_trades;
   int      losing_trades;
   double   total_pnl;
   double   avg_confidence;
   datetime last_signal_time;
   datetime first_seen;
   
   void Reset()
   {
      strategy_name = "";
      total_signals = 0;
      passed_gates = 0;
      failed_gates = 0;
      profitable_trades = 0;
      losing_trades = 0;
      total_pnl = 0.0;
      avg_confidence = 0.0;
      last_signal_time = 0;
      first_seen = TimeCurrent();
   }
};

//+------------------------------------------------------------------+
//| Gate Audit System Class                                          |
//+------------------------------------------------------------------+
class CGateAudit
{
private:
   CArrayObj m_audits;              // Array of SStrategyAudit
   bool      m_enabled;
   int       m_min_signals;         // Minimum signals before alert
   int       m_min_uptime_minutes;  // Minimum uptime before evaluation
   int       m_alert_cooldown_minutes;
   datetime  m_last_alert_time;
   
   // Find audit index by strategy name
   int FindAudit(const string strategy_name)
   {
      for(int i = 0; i < m_audits.Total(); i++)
      {
         SStrategyAudit* audit = (SStrategyAudit*)m_audits.At(i);
         if(audit != NULL && audit.strategy_name == strategy_name)
            return i;
      }
      return -1;
   }
   
public:
   // Constructor
   CGateAudit()
   {
      m_enabled = true;
      m_min_signals = 10;
      m_min_uptime_minutes = 60;
      m_alert_cooldown_minutes = 30;
      m_last_alert_time = 0;
   }
   
   // Destructor
   ~CGateAudit()
   {
      m_audits.Clear();
   }
   
   //+------------------------------------------------------------------+
   //| Initialize with all strategies                                   |
   //+------------------------------------------------------------------+
   void Initialize(ISignalGenerator*& strategies[])
   {
      m_audits.Clear();
      
      for(int i = 0; i < ArraySize(strategies); i++)
      {
         if(CheckPointer(strategies[i]) == POINTER_INVALID)
            continue;
            
         SStrategyAudit* audit = new SStrategyAudit;
         if(audit != NULL)
         {
            audit.Reset();
            audit.strategy_name = strategies[i].GetName();
            m_audits.Add(audit);
         }
      }
      
      PrintFormat("[GateAudit] Initialized with %d strategies", m_audits.Total());
   }
   
   //+------------------------------------------------------------------+
   //| Configure audit parameters                                       |
   //+------------------------------------------------------------------+
   void Configure(int min_signals, int min_uptime_min, int alert_cooldown_min)
   {
      m_min_signals = min_signals;
      m_min_uptime_minutes = min_uptime_min;
      m_alert_cooldown_minutes = alert_cooldown_min;
      
      PrintFormat("[GateAudit] Configured: min_signals=%d, min_uptime=%dmin, cooldown=%dmin",
                  m_min_signals, m_min_uptime_minutes, m_alert_cooldown_minutes);
   }
   
   //+------------------------------------------------------------------+
   //| Enable/disable audit                                             |
   //+------------------------------------------------------------------+
   void SetEnabled(bool enabled)
   {
      m_enabled = enabled;
      PrintFormat("[GateAudit] %s", enabled ? "enabled" : "disabled");
   }
   
   bool IsEnabled() const { return m_enabled; }
   
   //+------------------------------------------------------------------+
   //| Log strategy signal processed                                    |
   //+------------------------------------------------------------------+
   void LogStrategyProcessed(const string strategy_name, const long signal_id, 
                             bool passed_gate, double confidence, const string reason)
   {
      if(!m_enabled)
         return;
      
      int idx = FindAudit(strategy_name);
      if(idx < 0)
      {
         // Create new audit record
         SStrategyAudit* audit = new SStrategyAudit;
         audit.Reset();
         audit.strategy_name = strategy_name;
         audit.first_seen = TimeCurrent();
         m_audits.Add(audit);
         idx = m_audits.Total() - 1;
      }
      
      SStrategyAudit* audit = (SStrategyAudit*)m_audits.At(idx);
      if(audit == NULL)
         return;
      
      audit.total_signals++;
      audit.last_signal_time = TimeCurrent();
      
      if(passed_gate)
         audit.passed_gates++;
      else
         audit.failed_gates++;
      
      // Update average confidence
      audit.avg_confidence = ((audit.avg_confidence * (audit.total_signals - 1)) + confidence) / 
                              audit.total_signals;
      
      // Log to terminal (verbose mode)
      #ifdef __DEBUG__
      PrintFormat("[GateAudit] Strategy=%s Signal=%lld Passed=%s Confidence=%.2f Reason=%s",
                  strategy_name, signal_id, passed_gate ? "YES" : "NO", confidence, reason);
      #endif
      
      // Check for alerts
      CheckAlerts(audit);
   }
   
   //+------------------------------------------------------------------+
   //| Log trade result                                                 |
   //+------------------------------------------------------------------+
   void LogTradeResult(const string strategy_name, double pnl)
   {
      if(!m_enabled)
         return;
      
      int idx = FindAudit(strategy_name);
      if(idx < 0)
         return;
      
      SStrategyAudit* audit = (SStrategyAudit*)m_audits.At(idx);
      if(audit == NULL)
         return;
      
      audit.total_pnl += pnl;
      
      if(pnl > 0)
         audit.profitable_trades++;
      else if(pnl < 0)
         audit.losing_trades++;
   }
   
   //+------------------------------------------------------------------+
   //| Get audit report for strategy                                    |
   //+------------------------------------------------------------------+
   string GetStrategyReport(const string strategy_name)
   {
      int idx = FindAudit(strategy_name);
      if(idx < 0)
         return "Strategy not found";
      
      SStrategyAudit* audit = (SStrategyAudit*)m_audits.At(idx);
      if(audit == NULL)
         return "Audit data unavailable";
      
      string report;
      report += StringFormat("=== Strategy Audit: %s ===\n", audit.strategy_name);
      report += StringFormat("Total Signals: %d\n", audit.total_signals);
      report += StringFormat("Passed Gates: %d (%.1f%%)\n", audit.passed_gates, 
                             audit.total_signals > 0 ? (100.0 * audit.passed_gates / audit.total_signals) : 0);
      report += StringFormat("Failed Gates: %d\n", audit.failed_gates);
      report += StringFormat("Avg Confidence: %.2f\n", audit.avg_confidence);
      report += StringFormat("Profitable Trades: %d\n", audit.profitable_trades);
      report += StringFormat("Losing Trades: %d\n", audit.losing_trades);
      report += StringFormat("Total PnL: %.2f\n", audit.total_pnl);
      
      datetime uptime = TimeCurrent() - audit.first_seen;
      int minutes = (int)(uptime / 60);
      report += StringFormat("Uptime: %d minutes\n", minutes);
      
      return report;
   }
   
   //+------------------------------------------------------------------+
   //| Get full audit summary                                           |
   //+------------------------------------------------------------------+
   string GetFullSummary()
   {
      string summary = "[GateAudit Summary]\n";
      
      for(int i = 0; i < m_audits.Total(); i++)
      {
         SStrategyAudit* audit = (SStrategyAudit*)m_audits.At(i);
         if(audit == NULL)
            continue;
            
         summary += StringFormat("%s: %d signals, %.1f%% pass rate, %.2f avg conf\n",
                                audit.strategy_name,
                                audit.total_signals,
                                audit.total_signals > 0 ? (100.0 * audit.passed_gates / audit.total_signals) : 0,
                                audit.avg_confidence);
      }
      
      return summary;
   }
   
   //+------------------------------------------------------------------+
   //| Private: Check for alerts                                        |
   //+------------------------------------------------------------------+
private:
   void CheckAlerts(SStrategyAudit* audit)
   {
      if(audit == NULL)
         return;
      
      // Check cooldown
      if(m_last_alert_time > 0)
      {
         datetime elapsed = TimeCurrent() - m_last_alert_time;
         if(elapsed < m_alert_cooldown_minutes * 60)
            return;
      }
      
      // Check minimum signals
      if(audit.total_signals < m_min_signals)
         return;
      
      // Check minimum uptime
      datetime uptime = TimeCurrent() - audit.first_seen;
      if(uptime < m_min_uptime_minutes * 60)
         return;
      
      // Calculate pass rate
      double pass_rate = 100.0 * audit.passed_gates / audit.total_signals;
      
      // Alert on very low pass rate
      if(pass_rate < 20.0)
      {
         PrintFormat("[GateAudit ALERT] Strategy '%s' has very low pass rate: %.1f%% (%d/%d signals)",
                     audit.strategy_name, pass_rate, audit.passed_gates, audit.total_signals);
         m_last_alert_time = TimeCurrent();
      }
      
      // Alert on zero profitable trades after many signals
      if(audit.total_signals >= m_min_signals * 2 && audit.profitable_trades == 0 && audit.losing_trades > 0)
      {
         PrintFormat("[GateAudit ALERT] Strategy '%s' has no profitable trades after %d signals",
                     audit.strategy_name, audit.total_signals);
         m_last_alert_time = TimeCurrent();
      }
   }
};

// Global instance (declared in PaperEA_v2.mq5)
extern CGateAudit g_gate_audit;

#endif // CGATEAUDIT_MQH
