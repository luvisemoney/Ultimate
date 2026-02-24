//+------------------------------------------------------------------+
//| PerformanceMetricsCollector.mqh - Per-Component Latency Tracking  |
//+------------------------------------------------------------------+
#ifndef PERFORMANCE_METRICS_COLLECTOR_MQH
#define PERFORMANCE_METRICS_COLLECTOR_MQH

//+------------------------------------------------------------------+
//| Component latency metric entry                                   |
//+------------------------------------------------------------------+
struct SComponentLatencyMetric
{
   string    component_name;
   datetime  timestamp;
   ulong     latency_us;      // Microseconds
   ulong     count;           // Call count
   bool      budget_exceeded; // Whether latency exceeded budget
   string    context;         // Additional context (e.g., "gate_G1", "trade_BTCUSD")
};

//+------------------------------------------------------------------+
//| Rolling window latency statistics                                  |
//+------------------------------------------------------------------+
struct SLatencyStats
{
   string    component_name;
   double    avg_latency_us;
   double    max_latency_us;
   double    min_latency_us;
   double    p95_latency_us;
   ulong     total_calls;
   ulong     budget_violations;
   datetime  last_updated;
   
   void Reset()
   {
      component_name = "";
      avg_latency_us = 0.0;
      max_latency_us = 0.0;
      min_latency_us = 1e9;
      p95_latency_us = 0.0;
      total_calls = 0;
      budget_violations = 0;
      last_updated = 0;
   }
};

//+------------------------------------------------------------------+
//| Performance Metrics Collector Class                                |
//+------------------------------------------------------------------+
class CPerformanceMetricsCollector
{
private:
   SComponentLatencyMetric m_metrics[];
   int                     m_metrics_count;
   int                     m_max_metrics;
   
   SLatencyStats           m_stats[];
   int                     m_stats_count;
   
   ulong                   m_component_budgets[]; // Per-component budgets in us
   
   // Rolling window for P95 calculation (last 100 samples per component)
   double                  m_latency_history[][100];
   int                     m_history_index[];
   int                     m_history_count[];
   
public:
   // Constructor
   CPerformanceMetricsCollector(int max_metrics = 1000)
   {
      m_metrics_count = 0;
      m_max_metrics = max_metrics;
      m_stats_count = 0;
      
      ArrayResize(m_metrics, 0);
      ArrayResize(m_stats, 0);
      ArrayResize(m_component_budgets, 0);
      ArrayResize(m_latency_history, 0);
      ArrayResize(m_history_index, 0);
      ArrayResize(m_history_count, 0);
   }
   
   //+------------------------------------------------------------------+
   //| Register a component with its latency budget                      |
   //+------------------------------------------------------------------+
   void RegisterComponent(string component_name, ulong budget_us)
   {
      int idx = FindOrCreateComponentIndex(component_name);
      if(idx >= 0)
      {
         // Ensure arrays are sized
         if(idx >= ArraySize(m_component_budgets))
         {
            int old_size = ArraySize(m_component_budgets);
            ArrayResize(m_component_budgets, idx + 1);
            ArrayResize(m_latency_history, idx + 1);
            ArrayResize(m_history_index, idx + 1);
            ArrayResize(m_history_count, idx + 1);
            
            // Initialize new entries
            for(int i = old_size; i <= idx; i++)
            {
               m_component_budgets[i] = 5000; // Default 5ms
               m_history_index[i] = 0;
               m_history_count[i] = 0;
            }
         }
         
         m_component_budgets[idx] = budget_us;
         
         // Initialize stats entry
         if(idx >= m_stats_count)
         {
            int old_stats = m_stats_count;
            m_stats_count = idx + 1;
            ArrayResize(m_stats, m_stats_count);
            
            for(int i = old_stats; i < m_stats_count; i++)
               m_stats[i].Reset();
         }
         
         m_stats[idx].component_name = component_name;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Record a latency measurement                                      |
   //+------------------------------------------------------------------+
   void RecordLatency(string component_name, ulong latency_us, string context = "")
   {
      // Add to metrics log (if not at capacity)
      if(m_metrics_count < m_max_metrics)
      {
         int idx = m_metrics_count;
         ArrayResize(m_metrics, m_metrics_count + 1);
         
         m_metrics[idx].component_name = component_name;
         m_metrics[idx].timestamp = TimeCurrent();
         m_metrics[idx].latency_us = latency_us;
         m_metrics[idx].count = 1;
         m_metrics[idx].context = context;
         
         int comp_idx = FindOrCreateComponentIndex(component_name);
         if(comp_idx >= 0 && comp_idx < ArraySize(m_component_budgets))
         {
            m_metrics[idx].budget_exceeded = (latency_us > m_component_budgets[comp_idx]);
         }
         else
         {
            m_metrics[idx].budget_exceeded = false;
         }
         
         m_metrics_count++;
      }
      
      // Update rolling statistics
      UpdateStats(component_name, latency_us);
      
      // Update history for P95
      UpdateHistory(component_name, latency_us);
   }
   
   //+------------------------------------------------------------------+
   //| Get latency statistics for a component                            |
   //+------------------------------------------------------------------+
   bool GetComponentStats(string component_name, SLatencyStats &out_stats)
   {
      int idx = FindComponentIndex(component_name);
      if(idx < 0 || idx >= m_stats_count)
         return false;
      
      // Calculate P95 from history
      CalculateP95(idx);
      
      out_stats = m_stats[idx];
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Check if component exceeded its budget                             |
   //+------------------------------------------------------------------+
   bool DidExceedBudget(string component_name, ulong latency_us)
   {
      int idx = FindComponentIndex(component_name);
      if(idx < 0 || idx >= ArraySize(m_component_budgets))
         return false;
      
      return latency_us > m_component_budgets[idx];
   }
   
   //+------------------------------------------------------------------+
   //| Get budget violation report                                       |
   //+------------------------------------------------------------------+
   string GetBudgetViolationReport()
   {
      string report = "=== Performance Budget Violations ===\n";
      bool has_violations = false;
      
      for(int i = 0; i < m_stats_count; i++)
      {
         if(m_stats[i].budget_violations > 0)
         {
            has_violations = true;
            report += StringFormat("%s: %d violations (%.2f%% of calls)\n",
               m_stats[i].component_name,
               (int)m_stats[i].budget_violations,
               100.0 * m_stats[i].budget_violations / MathMax(1, (double)m_stats[i].total_calls));
         }
      }
      
      if(!has_violations)
         report += "No budget violations recorded.\n";
      
      return report;
   }
   
   //+------------------------------------------------------------------+
   //| Get full performance report                                         |
   //+------------------------------------------------------------------+
   string GetFullReport()
   {
      string report = "=== Performance Metrics Report ===\n";
      report += StringFormat("Total components: %d\n", m_stats_count);
      report += StringFormat("Total measurements: %d\n\n", m_metrics_count);
      
      for(int i = 0; i < m_stats_count; i++)
      {
         // Calculate P95
         CalculateP95(i);
         
         report += StringFormat(
            "%s:\n"
            "  Avg: %.2fms | P95: %.2fms | Min: %.2fms | Max: %.2fms\n"
            "  Calls: %I64u | Budget violations: %I64u\n\n",
            m_stats[i].component_name,
            m_stats[i].avg_latency_us / 1000.0,
            m_stats[i].p95_latency_us / 1000.0,
            m_stats[i].min_latency_us / 1000.0,
            m_stats[i].max_latency_us / 1000.0,
            m_stats[i].total_calls,
            m_stats[i].budget_violations
         );
      }
      
      return report;
   }
   
   //+------------------------------------------------------------------+
   //| Clear old metrics (keep last N measurements per component)        |
   //+------------------------------------------------------------------+
   void TrimOldMetrics(int keep_per_component = 100)
   {
      // Simple implementation: if we exceed max, clear half
      if(m_metrics_count >= m_max_metrics)
      {
         int new_count = m_metrics_count / 2;
         ArrayResize(m_metrics, new_count);
         m_metrics_count = new_count;
      }
   }
   
private:
   //+------------------------------------------------------------------+
   //| Find or create component index                                     |
   //+------------------------------------------------------------------+
   int FindOrCreateComponentIndex(string component_name)
   {
      int idx = FindComponentIndex(component_name);
      if(idx >= 0)
         return idx;
      
      // Create new entry
      idx = m_stats_count;
      m_stats_count++;
      ArrayResize(m_stats, m_stats_count);
      m_stats[idx].Reset();
      m_stats[idx].component_name = component_name;
      
      return idx;
   }
   
   //+------------------------------------------------------------------+
   //| Find component index                                               |
   //+------------------------------------------------------------------+
   int FindComponentIndex(string component_name)
   {
      for(int i = 0; i < m_stats_count; i++)
      {
         if(m_stats[i].component_name == component_name)
            return i;
      }
      return -1;
   }
   
   //+------------------------------------------------------------------+
   //| Update statistics for a component                                 |
   //+------------------------------------------------------------------+
   void UpdateStats(string component_name, ulong latency_us)
   {
      int idx = FindOrCreateComponentIndex(component_name);
      if(idx < 0 || idx >= m_stats_count)
         return;
      
      SLatencyStats &stats = m_stats[idx];
      
      // Update running average
      double old_avg = stats.avg_latency_us;
      ulong n = stats.total_calls;
      stats.avg_latency_us = (old_avg * n + latency_us) / (n + 1);
      
      // Update min/max
      stats.max_latency_us = MathMax(stats.max_latency_us, latency_us);
      stats.min_latency_us = MathMin(stats.min_latency_us, latency_us);
      
      // Increment call count
      stats.total_calls++;
      
      // Check budget violation
      if(idx < ArraySize(m_component_budgets) && latency_us > m_component_budgets[idx])
         stats.budget_violations++;
      
      stats.last_updated = TimeCurrent();
   }
   
   //+------------------------------------------------------------------+
   //| Update latency history for P95 calculation                        |
   //+------------------------------------------------------------------+
   void UpdateHistory(string component_name, ulong latency_us)
   {
      int idx = FindOrCreateComponentIndex(component_name);
      if(idx < 0 || idx >= ArraySize(m_history_index))
         return;
      
      // Store in circular buffer
      int h_idx = m_history_index[idx];
      m_latency_history[idx][h_idx] = (double)latency_us;
      m_history_index[idx] = (h_idx + 1) % 100;
      
      if(m_history_count[idx] < 100)
         m_history_count[idx]++;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate P95 for a component                                     |
   //+------------------------------------------------------------------+
   void CalculateP95(int component_idx)
   {
      if(component_idx < 0 || component_idx >= ArraySize(m_history_count))
         return;
      
      int count = m_history_count[component_idx];
      if(count == 0)
      {
         m_stats[component_idx].p95_latency_us = 0.0;
         return;
      }
      
      // Copy and sort
      double sorted[];
      ArrayResize(sorted, count);
      ArrayCopy(sorted, m_latency_history[component_idx], 0, 0, count);
      ArraySort(sorted);
      
      // Get P95 index
      int p95_idx = (int)MathFloor(count * 0.95);
      if(p95_idx >= count) p95_idx = count - 1;
      
      m_stats[component_idx].p95_latency_us = sorted[p95_idx];
   }
};

// Global instance
CPerformanceMetricsCollector* g_performance_collector = NULL;

//+------------------------------------------------------------------+
//| Initialize performance collector                                  |
//+------------------------------------------------------------------+
bool InitializePerformanceCollector()
{
   if(g_performance_collector != NULL)
      delete g_performance_collector;
   
   g_performance_collector = new CPerformanceMetricsCollector(10000);
   
   // Register standard components with budgets
   g_performance_collector.RegisterComponent("OnTick", 5000);          // 5ms
   g_performance_collector.RegisterComponent("OnTimer", 10000);         // 10ms
   g_performance_collector.RegisterComponent("GateEvaluation", 2000);    // 2ms per gate
   g_performance_collector.RegisterComponent("TradeExecution", 5000);    // 5ms
   g_performance_collector.RegisterComponent("PolicyUpdate", 5000);    // 5ms
   g_performance_collector.RegisterComponent("FeatureCache", 1000);      // 1ms
   g_performance_collector.RegisterComponent("PositionSync", 3000);    // 3ms
   
   LOG("[PerformanceCollector] Initialized with component budgets");
   return true;
}

//+------------------------------------------------------------------+
//| Shutdown performance collector                                    |
//+------------------------------------------------------------------+
void ShutdownPerformanceCollector()
{
   if(g_performance_collector != NULL)
   {
      delete g_performance_collector;
      g_performance_collector = NULL;
   }
}

//+------------------------------------------------------------------+
//| Convenience macros for timing                                      |
//+------------------------------------------------------------------+
#define PERF_START(name) \
   ulong __perf_start_##name = GetMicrosecondCount();

#define PERF_END(name) \
   do { \
      if(g_performance_collector != NULL) { \
         g_performance_collector.RecordLatency(#name, GetMicrosecondCount() - __perf_start_##name); \
      } \
   } while(0)

#define PERF_END_CTX(name, context) \
   do { \
      if(g_performance_collector != NULL) { \
         g_performance_collector.RecordLatency(#name, GetMicrosecondCount() - __perf_start_##name, context); \
      } \
   } while(0)

#endif // PERFORMANCE_METRICS_COLLECTOR_MQH
