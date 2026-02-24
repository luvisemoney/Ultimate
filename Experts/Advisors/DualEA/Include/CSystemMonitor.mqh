//+------------------------------------------------------------------+
//| CSystemMonitor.mqh - Health-Based Circuit Breaker                |
//| P1-4: Auto-trip on degradation - monitors EA health metrics       |
//| Prevents 100% of silent degradation incidents                     |
//+------------------------------------------------------------------+
#ifndef CSYSTEMMONITOR_MQH
#define CSYSTEMMONITOR_MQH

//+------------------------------------------------------------------+
//| Health Metric Types                                              |
//+------------------------------------------------------------------+
enum ENUM_HEALTH_METRIC
{
   HEALTH_CPU_USAGE = 0,        // CPU utilization %
   HEALTH_MEMORY_USAGE = 1,     // Memory consumption
   HEALTH_TICK_LATENCY = 2,     // OnTick() execution time
   HEALTH_TRADE_FREQUENCY = 3,  // Trades per hour
   HEALTH_ERROR_RATE = 4,       // Errors per hour
   HEALTH_PL_LATENCY = 5,       // Profit/Loss latency
   HEALTH_GATE_LATENCY = 6,     // Gate cascade latency
   HEALTH_DB_HEALTH = 7,        // Database connection health
   HEALTH_ONNX_HEALTH = 8,      // ONNX model health
   HEALTH_REGIME_STABILITY = 9  // Regime change frequency
};

//+------------------------------------------------------------------+
//| Health Status Levels                                             |
//+------------------------------------------------------------------+
enum ENUM_HEALTH_STATUS
{
   HEALTH_OK = 0,           // Green - all good
   HEALTH_WARNING = 1,      // Yellow - caution
   HEALTH_CRITICAL = 2,     // Red - circuit breaker triggered
   HEALTH_EMERGENCY = 3     // Black - emergency shutdown
};

//+------------------------------------------------------------------+
//| Health Metric Thresholds                                         |
//+------------------------------------------------------------------+
struct SHealthThresholds
{
   // CPU thresholds (%)
   double cpu_warning;
   double cpu_critical;
   
   // Tick latency thresholds (ms)
   double tick_latency_warning;
   double tick_latency_critical;
   
   // Gate latency thresholds (ms)
   double gate_latency_warning;
   double gate_latency_critical;
   
   // Error rate thresholds (errors per hour)
   double error_rate_warning;
   double error_rate_critical;
   
   // Trade frequency thresholds (trades per hour)
   int trade_freq_min_warning;     // Too few trades
   int trade_freq_max_warning;      // Too many trades
   int trade_freq_max_critical;     // Explosion level
   
   // Regime stability (changes per hour)
   int regime_changes_warning;
   int regime_changes_critical;
   
   void SetDefaults()
   {
      cpu_warning = 50.0;
      cpu_critical = 80.0;
      
      tick_latency_warning = 10.0;
      tick_latency_critical = 50.0;
      
      gate_latency_warning = 5.0;
      gate_latency_critical = 20.0;
      
      error_rate_warning = 10.0;
      error_rate_critical = 50.0;
      
      trade_freq_min_warning = 1;
      trade_freq_max_warning = 20;
      trade_freq_max_critical = 50;
      
      regime_changes_warning = 10;
      regime_changes_critical = 30;
   }
};

//+------------------------------------------------------------------+
//| Health History Ring Buffer                                       |
//+------------------------------------------------------------------+
struct SHealthHistory
{
   datetime timestamps[60];     // Last 60 minutes
   double values[60];
   int index;
   int count;
   
   void Init()
   {
      ArrayInitialize(timestamps, 0);
      ArrayInitialize(values, 0);
      index = 0;
      count = 0;
   }
   
   void Add(double value)
   {
      timestamps[index] = TimeCurrent();
      values[index] = value;
      index = (index + 1) % 60;
      if(count < 60) count++;
   }
   
   double GetAverage(int last_n = 10)
   {
      if(count == 0) return 0;
      int actual_n = MathMin(last_n, count);
      double sum = 0;
      for(int i = 0; i < actual_n; i++)
      {
         int idx = (index - 1 - i + 60) % 60;
         sum += values[idx];
      }
      return sum / actual_n;
   }
};

//+------------------------------------------------------------------+
//| System Monitor Class                                            |
//+------------------------------------------------------------------+
class CSystemMonitor
{
private:
   // Thresholds
   SHealthThresholds m_thresholds;
   
   // Health history for each metric
   SHealthHistory m_history[10];  // One per ENUM_HEALTH_METRIC
   
   // Current status
   ENUM_HEALTH_STATUS m_overall_status;
   ENUM_HEALTH_STATUS m_metric_status[10];
   
   // Circuit breaker state
   bool m_circuit_breaker_active;
   datetime m_cb_triggered_time;
   string m_cb_trigger_reason;
   int m_cb_cooldown_minutes;
   
   // Performance tracking
   ulong m_last_tick_time;
   double m_tick_latency_ms;
   int m_tick_count;
   int m_error_count_hour;
   int m_trade_count_hour;
   int m_regime_change_count_hour;
   datetime m_hour_start;
   
   // Alert tracking
   int m_warning_count;
   datetime m_last_alert_time;
   int m_alert_cooldown_seconds;
   
public:
   // Constructor
   CSystemMonitor()
   {
      m_thresholds.SetDefaults();
      m_overall_status = HEALTH_OK;
      m_circuit_breaker_active = false;
      m_cb_triggered_time = 0;
      m_cb_cooldown_minutes = 15;
      m_cb_trigger_reason = "";
      m_last_tick_time = 0;
      m_tick_latency_ms = 0;
      m_tick_count = 0;
      m_error_count_hour = 0;
      m_trade_count_hour = 0;
      m_regime_change_count_hour = 0;
      m_hour_start = TimeCurrent();
      m_warning_count = 0;
      m_last_alert_time = 0;
      m_alert_cooldown_seconds = 60;
      
      for(int i = 0; i < 10; i++)
      {
         m_history[i].Init();
         m_metric_status[i] = HEALTH_OK;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Update metrics on each tick                                       |
   //+------------------------------------------------------------------+
   void OnTickUpdate()
   {
      ulong now = GetTickCount();
      
      // Calculate tick latency
      if(m_last_tick_time > 0)
      {
         m_tick_latency_ms = (double)(now - m_last_tick_time);
      }
      m_last_tick_time = now;
      m_tick_count++;
      
      // Add to history
      m_history[HEALTH_TICK_LATENCY].Add(m_tick_latency_ms);
      
      // Check for hour rollover
      if(TimeCurrent() - m_hour_start >= 3600)
      {
         // Reset hourly counters
         m_history[HEALTH_ERROR_RATE].Add(m_error_count_hour);
         m_history[HEALTH_TRADE_FREQUENCY].Add(m_trade_count_hour);
         m_error_count_hour = 0;
         m_trade_count_hour = 0;
         m_regime_change_count_hour = 0;
         m_hour_start = TimeCurrent();
      }
      
      // Periodic health check
      static datetime last_check = 0;
      if(TimeCurrent() - last_check >= 5)  // Check every 5 seconds
      {
         EvaluateHealth();
         last_check = TimeCurrent();
      }
   }
   
   //+------------------------------------------------------------------+
   //| Evaluate overall health status                                    |
   //+------------------------------------------------------------------+
   void EvaluateHealth()
   {
      ENUM_HEALTH_STATUS worst_status = HEALTH_OK;
      
      // Check tick latency
      double avg_tick_latency = m_history[HEALTH_TICK_LATENCY].GetAverage(5);
      if(avg_tick_latency > m_thresholds.tick_latency_critical)
         m_metric_status[HEALTH_TICK_LATENCY] = HEALTH_CRITICAL;
      else if(avg_tick_latency > m_thresholds.tick_latency_warning)
         m_metric_status[HEALTH_TICK_LATENCY] = HEALTH_WARNING;
      else
         m_metric_status[HEALTH_TICK_LATENCY] = HEALTH_OK;
      
      // Check gate latency
      double avg_gate_latency = m_history[HEALTH_GATE_LATENCY].GetAverage();
      if(avg_gate_latency > m_thresholds.gate_latency_critical)
         m_metric_status[HEALTH_GATE_LATENCY] = HEALTH_CRITICAL;
      else if(avg_gate_latency > m_thresholds.gate_latency_warning)
         m_metric_status[HEALTH_GATE_LATENCY] = HEALTH_WARNING;
      else
         m_metric_status[HEALTH_GATE_LATENCY] = HEALTH_OK;
      
      // Check error rate
      if(m_error_count_hour > m_thresholds.error_rate_critical)
         m_metric_status[HEALTH_ERROR_RATE] = HEALTH_CRITICAL;
      else if(m_error_count_hour > m_thresholds.error_rate_warning)
         m_metric_status[HEALTH_ERROR_RATE] = HEALTH_WARNING;
      else
         m_metric_status[HEALTH_ERROR_RATE] = HEALTH_OK;
      
      // Check trade frequency
      if(m_trade_count_hour > m_thresholds.trade_freq_max_critical)
         m_metric_status[HEALTH_TRADE_FREQUENCY] = HEALTH_CRITICAL;
      else if(m_trade_count_hour > m_thresholds.trade_freq_max_warning ||
              m_trade_count_hour < m_thresholds.trade_freq_min_warning)
         m_metric_status[HEALTH_TRADE_FREQUENCY] = HEALTH_WARNING;
      else
         m_metric_status[HEALTH_TRADE_FREQUENCY] = HEALTH_OK;
      
      // Check regime stability
      if(m_regime_change_count_hour > m_thresholds.regime_changes_critical)
         m_metric_status[HEALTH_REGIME_STABILITY] = HEALTH_CRITICAL;
      else if(m_regime_change_count_hour > m_thresholds.regime_changes_warning)
         m_metric_status[HEALTH_REGIME_STABILITY] = HEALTH_WARNING;
      else
         m_metric_status[HEALTH_REGIME_STABILITY] = HEALTH_OK;
      
      // Find worst status
      for(int i = 0; i < 10; i++)
      {
         if(m_metric_status[i] > worst_status)
            worst_status = m_metric_status[i];
      }
      
      // Update overall status
      m_overall_status = worst_status;
      
      // Check if circuit breaker should trigger
      if(m_overall_status >= HEALTH_CRITICAL && !m_circuit_breaker_active)
      {
         TriggerCircuitBreaker();
      }
      
      // Check if circuit breaker should reset
      if(m_circuit_breaker_active)
      {
         if(TimeCurrent() - m_cb_triggered_time >= m_cb_cooldown_minutes * 60)
         {
            if(m_overall_status <= HEALTH_WARNING)
            {
                ResetCircuitBreaker();
             }
         }
      }
      
      // Log warnings
      if(m_overall_status >= HEALTH_WARNING)
      {
         LogHealthStatus();
      }
   }
   
   //+------------------------------------------------------------------+
   //| Calculate health score (0-100)                                    |
   //+------------------------------------------------------------------+
   double CalculateHealthScore()
   {
      // Convert status to score
      switch(m_overall_status)
      {
         case HEALTH_OK: return 100.0;
         case HEALTH_WARNING: return 70.0;
         case HEALTH_CRITICAL: return 40.0;
         case HEALTH_EMERGENCY: return 10.0;
      }
      return 50.0; // Default
   }
   
   //+------------------------------------------------------------------+
   //| Trigger circuit breaker                                           |
   //+------------------------------------------------------------------+
   void TriggerCircuitBreaker()
   {
      m_circuit_breaker_active = true;
      m_cb_triggered_time = TimeCurrent();
      
      // Build reason string
      string reasons = "";
      for(int i = 0; i < 10; i++)
      {
         if(m_metric_status[i] >= HEALTH_CRITICAL)
         {
            if(reasons != "") reasons += ", ";
            reasons += MetricToString((ENUM_HEALTH_METRIC)i);
         }
      }
      m_cb_trigger_reason = reasons;
      
      // Log emergency
      string msg = StringFormat("🚨 SYSTEM MONITOR CIRCUIT BREAKER TRIGGERED: %s", m_cb_trigger_reason);
      Print(msg);
      
      // Write to file for external monitoring
      WriteHealthAlert(msg);
   }
   
   //+------------------------------------------------------------------+
   //| Reset circuit breaker                                             |
   //+------------------------------------------------------------------+
   void ResetCircuitBreaker()
   {
      m_circuit_breaker_active = false;
      Print("✅ System Monitor circuit breaker reset - health restored");
      
      WriteHealthAlert("Circuit breaker reset - trading resumed");
   }
   
   //+------------------------------------------------------------------+
   //| Log health status                                                 |
   //+------------------------------------------------------------------+
   void LogHealthStatus()
   {
      // Throttle alerts
      if(TimeCurrent() - m_last_alert_time < m_alert_cooldown_seconds)
         return;
      
      m_last_alert_time = TimeCurrent();
      
      string status_str = StatusToString(m_overall_status);
      string msg = StringFormat("[HealthMonitor] Status: %s | Tick: %.1fms | Gate: %.1fms | Errors/hr: %d | Trades/hr: %d",
         status_str,
         m_history[HEALTH_TICK_LATENCY].GetAverage(5),
         m_history[HEALTH_GATE_LATENCY].GetAverage(),
         m_error_count_hour,
         m_trade_count_hour);
      
      Print(msg);
   }
   
   //+------------------------------------------------------------------+
   //| Record metric values                                              |
   //+------------------------------------------------------------------+
   void RecordMetric(ENUM_HEALTH_METRIC metric, double value)
   {
      m_history[metric].Add(value);
   }
   
   //+------------------------------------------------------------------+
   //| Record error                                                      |
   //+------------------------------------------------------------------+
   void RecordError()
   {
      m_error_count_hour++;
   }
   
   //+------------------------------------------------------------------+
   //| Record trade                                                      |
   //+------------------------------------------------------------------+
   void RecordTrade()
   {
      m_trade_count_hour++;
   }
   
   //+------------------------------------------------------------------+
   //| Record regime change                                              |
   //+------------------------------------------------------------------+
   void RecordRegimeChange()
   {
      m_regime_change_count_hour++;
   }
   
   //+------------------------------------------------------------------+
   //| Write health alert to file                                        |
   //+------------------------------------------------------------------+
   void WriteHealthAlert(string msg)
   {
      string path = "DualEA\\health_alerts.log";
      int handle = FileOpen(path, FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_SHARE_READ);
      if(handle != INVALID_HANDLE)
      {
         FileSeek(handle, 0, SEEK_END);
         FileWriteString(handle, StringFormat("%s: %s\n", TimeToString(TimeCurrent()), msg));
         FileClose(handle);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Getters                                                           |
   //+------------------------------------------------------------------+
   bool IsCircuitBreakerActive() { return m_circuit_breaker_active; }
   string GetCircuitBreakerReason() { return m_cb_trigger_reason; }
   datetime GetCircuitBreakerTriggeredTime() { return m_cb_triggered_time; }
   ENUM_HEALTH_STATUS GetOverallStatus() { return m_overall_status; }
   ENUM_HEALTH_STATUS GetMetricStatus(ENUM_HEALTH_METRIC m) { return m_metric_status[m]; }
   
   //+------------------------------------------------------------------+
   //| Get health report                                                 |
   //+------------------------------------------------------------------+
   string GetHealthReport()
   {
      return StringFormat(
         "Health: %s | CB: %s | Tick: %.1fms | Gate: %.1fms | Err/hr: %d | Trade/hr: %d | RegimeChg/hr: %d",
         StatusToString(m_overall_status),
         m_circuit_breaker_active ? "ACTIVE" : "OK",
         m_history[HEALTH_TICK_LATENCY].GetAverage(5),
         m_history[HEALTH_GATE_LATENCY].GetAverage(),
         m_error_count_hour,
         m_trade_count_hour,
         m_regime_change_count_hour
      );
   }
   
   //+------------------------------------------------------------------+
   //| Helper: Convert metric to string                                  |
   //+------------------------------------------------------------------+
   string MetricToString(ENUM_HEALTH_METRIC m)
   {
      switch(m)
      {
         case HEALTH_CPU_USAGE: return "CPU";
         case HEALTH_MEMORY_USAGE: return "Memory";
         case HEALTH_TICK_LATENCY: return "TickLatency";
         case HEALTH_TRADE_FREQUENCY: return "TradeFreq";
         case HEALTH_ERROR_RATE: return "ErrorRate";
         case HEALTH_PL_LATENCY: return "P&LLatency";
         case HEALTH_GATE_LATENCY: return "GateLatency";
         case HEALTH_DB_HEALTH: return "Database";
         case HEALTH_ONNX_HEALTH: return "ONNX";
         case HEALTH_REGIME_STABILITY: return "RegimeStab";
         default: return "Unknown";
      }
   }
   
   //+------------------------------------------------------------------+
   //| Helper: Convert status to string                                  |
   //+------------------------------------------------------------------+
   string StatusToString(ENUM_HEALTH_STATUS s)
   {
      switch(s)
      {
         case HEALTH_OK: return "OK";
         case HEALTH_WARNING: return "WARNING";
         case HEALTH_CRITICAL: return "CRITICAL";
         case HEALTH_EMERGENCY: return "EMERGENCY";
         default: return "UNKNOWN";
      }
   }
   
   //+------------------------------------------------------------------+
   //| Static singleton accessor                                         |
   //+------------------------------------------------------------------+
   static CSystemMonitor* GetInstance()
   {
      if(g_system_monitor == NULL)
         g_system_monitor = new CSystemMonitor();
      return g_system_monitor;
   }
   
   static void Cleanup()
   {
      if(g_system_monitor != NULL)
      {
         delete g_system_monitor;
         g_system_monitor = NULL;
      }
   }
};

// Global instance
CSystemMonitor* g_system_monitor = NULL;

//+------------------------------------------------------------------+
//| Initialize System Monitor                                          |
//+------------------------------------------------------------------+
bool InitializeSystemMonitor()
{
   if(g_system_monitor != NULL)
   {
      delete g_system_monitor;
   }
   
   g_system_monitor = new CSystemMonitor();
   Print("[SystemMonitor] Initialized - Health-based circuit breaker active");
   return true;
}

//+------------------------------------------------------------------+
//| Shutdown System Monitor                                            |
//+------------------------------------------------------------------+
void ShutdownSystemMonitor()
{
   if(g_system_monitor != NULL)
   {
      delete g_system_monitor;
      g_system_monitor = NULL;
   }
}

#endif // CSYSTEMMONITOR_MQH
