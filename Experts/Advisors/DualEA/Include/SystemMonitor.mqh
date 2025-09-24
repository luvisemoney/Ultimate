//+------------------------------------------------------------------+
//| SystemMonitor.mqh - Unified System Health and Performance Monitoring |
//+------------------------------------------------------------------+
#ifndef __SYSTEMMONITOR_MQH__
#define __SYSTEMMONITOR_MQH__

#include "EventBus.mqh"
#include "ConfigManager.mqh"

// System health metrics structure
struct SystemHealth
{
   double gate_success_rate;
   double insights_freshness_score;
   double system_performance_score;
   double memory_usage_mb;
   double cpu_usage_percent;
   int active_signals;
   int processed_events;
   datetime last_update;
   string status; // "healthy", "warning", "critical"
   
   SystemHealth()
   {
      gate_success_rate = 0.0;
      insights_freshness_score = 0.0;
      system_performance_score = 0.0;
      memory_usage_mb = 0.0;
      cpu_usage_percent = 0.0;
      active_signals = 0;
      processed_events = 0;
      last_update = 0;
      status = "unknown";
   }
};

// Performance metrics structure
struct PerformanceMetrics
{
   double gate_processing_time_ms[8];
   double insights_update_time_ms;
   double signal_generation_time_ms;
   double trade_execution_time_ms;
   int events_per_second;
   int signals_per_hour;
   datetime measurement_start;
   
   PerformanceMetrics()
   {
      for(int i = 0; i < 8; i++)
         gate_processing_time_ms[i] = 0.0;
      
      insights_update_time_ms = 0.0;
      signal_generation_time_ms = 0.0;
      trade_execution_time_ms = 0.0;
      events_per_second = 0;
      signals_per_hour = 0;
      measurement_start = TimeCurrent();
   }
};

// System monitor with event subscription
class CSystemMonitor : public IEventSubscriber
{
private:
   static CSystemMonitor* instance;
   SystemHealth current_health;
   PerformanceMetrics current_metrics;
   CEventBus* event_bus;
   CConfigManager* config_manager;
   
   // Gate statistics
   int gate_attempts[8];
   int gate_successes[8];
   double gate_total_time[8];
   
   // System statistics
   int total_events_processed;
   int total_signals_generated;
   int total_trades_executed;
   datetime monitoring_start_time;
   
   CSystemMonitor()
   {
      event_bus = CEventBus::GetInstance();
      config_manager = CConfigManager::GetInstance();
      
      // Initialize statistics
      for(int i = 0; i < 8; i++)
      {
         gate_attempts[i] = 0;
         gate_successes[i] = 0;
         gate_total_time[i] = 0.0;
      }
      
      total_events_processed = 0;
      total_signals_generated = 0;
      total_trades_executed = 0;
      monitoring_start_time = TimeCurrent();
      
      // Subscribe to all relevant events
      SubscribeToEvents();
      
      UpdateSystemHealth();
   }
   
   void SubscribeToEvents()
   {
      event_bus.Subscribe(EVENT_GATE_PROCESSED, this);
      event_bus.Subscribe(EVENT_SIGNAL_GENERATED, this);
      event_bus.Subscribe(EVENT_INSIGHTS_UPDATED, this);
      event_bus.Subscribe(EVENT_TRADE_EXECUTED, this);
      event_bus.Subscribe(EVENT_SYSTEM_STATUS, this);
      event_bus.Subscribe(EVENT_ERROR_OCCURRED, this);
      event_bus.Subscribe(EVENT_PERFORMANCE_METRIC, this);
   }
   
public:
   static CSystemMonitor* GetInstance()
   {
      if(instance == NULL)
         instance = new CSystemMonitor();
      return instance;
   }
   
   static void Cleanup()
   {
      if(instance != NULL)
      {
         delete instance;
         instance = NULL;
      }
   }
   
   // IEventSubscriber implementation
   void OnEvent(const EventData& event) override
   {
      total_events_processed++;
      
      switch(event.type)
      {
         case EVENT_GATE_PROCESSED:
            ProcessGateEvent(event);
            break;
            
         case EVENT_SIGNAL_GENERATED:
            total_signals_generated++;
            break;
            
         case EVENT_TRADE_EXECUTED:
            total_trades_executed++;
            break;
            
         case EVENT_ERROR_OCCURRED:
            ProcessErrorEvent(event);
            break;
            
         case EVENT_PERFORMANCE_METRIC:
            ProcessPerformanceEvent(event);
            break;
            
         default:
            // Handle other events as needed
            break;
      }
      
      // Update health periodically
      static datetime last_health_update = 0;
      if(TimeCurrent() - last_health_update > 60) // Update every minute
      {
         UpdateSystemHealth();
         last_health_update = TimeCurrent();
      }
   }
   
   string GetSubscriberName() override { return "SystemMonitor"; }
   
   // Process gate-specific events
   void ProcessGateEvent(const EventData& event)
   {
      // Parse gate event data: "gate_name|PASS/FAIL|reason"
      string parts[];
      int count = StringSplit(event.data, '|', parts);
      
      if(count >= 2)
      {
         string gate_name = parts[0];
         bool passed = (parts[1] == "PASS");
         
         // Find gate index
         int gate_index = GetGateIndex(gate_name);
         if(gate_index >= 0)
         {
            gate_attempts[gate_index]++;
            if(passed)
               gate_successes[gate_index]++;
         }
      }
   }
   
   void ProcessErrorEvent(const EventData& event)
   {
      // Log critical errors and update system status
      if(event.priority >= 3)
      {
         current_health.status = "critical";
         Print("CRITICAL ERROR in ", event.source, ": ", event.data);
      }
   }
   
   void ProcessPerformanceEvent(const EventData& event)
   {
      // Parse performance metric: "metric_name|value"
      string parts[];
      int count = StringSplit(event.data, '|', parts);
      
      if(count >= 2)
      {
         string metric_name = parts[0];
         double value = StringToDouble(parts[1]);
         
         // Update relevant performance metrics
         if(StringFind(metric_name, "gate_time") >= 0)
         {
            // Extract gate index and update timing
            // Implementation depends on metric naming convention
         }
      }
   }
   
   // Get gate index from name
   int GetGateIndex(const string& gate_name)
   {
      string gate_names[] = {"SignalRinse", "MarketSoap", "StrategyScrub", "RiskWash", 
                            "PerformanceWax", "MLPolish", "LiveClean", "FinalVerify"};
      
      for(int i = 0; i < 8; i++)
      {
         if(gate_names[i] == gate_name)
            return i;
      }
      return -1;
   }
   
   // Update system health metrics
   void UpdateSystemHealth()
   {
      current_health.last_update = TimeCurrent();
      
      // Calculate gate success rate
      int total_attempts = 0;
      int total_successes = 0;
      
      for(int i = 0; i < 8; i++)
      {
         total_attempts += gate_attempts[i];
         total_successes += gate_successes[i];
      }
      
      current_health.gate_success_rate = (total_attempts > 0) ? 
         (double)total_successes / total_attempts : 0.0;
      
      // Calculate insights freshness (placeholder - would need actual insights data)
      current_health.insights_freshness_score = 0.85; // Placeholder
      
      // Calculate overall system performance score
      current_health.system_performance_score = 
         (current_health.gate_success_rate * 0.6) + 
         (current_health.insights_freshness_score * 0.4);
      
      // Update system status based on performance
      if(current_health.system_performance_score >= 0.8)
         current_health.status = "healthy";
      else if(current_health.system_performance_score >= 0.6)
         current_health.status = "warning";
      else
         current_health.status = "critical";
      
      // Update active signals and events
      current_health.active_signals = total_signals_generated;
      current_health.processed_events = total_events_processed;
      
      // Estimate memory usage (placeholder)
      current_health.memory_usage_mb = 50.0 + (total_events_processed * 0.001);
   }
   
   // Public interface methods
   SystemHealth GetSystemHealth()
   {
      UpdateSystemHealth();
      return current_health;
   }
   
   PerformanceMetrics GetPerformanceMetrics()
   {
      // Update performance metrics
      datetime now = TimeCurrent();
      int elapsed_seconds = (int)(now - current_metrics.measurement_start);
      
      if(elapsed_seconds > 0)
      {
         current_metrics.events_per_second = total_events_processed / elapsed_seconds;
         current_metrics.signals_per_hour = (total_signals_generated * 3600) / elapsed_seconds;
      }
      
      return current_metrics;
   }
   
   // Gate-specific metrics
   double GetGateSuccessRate(int gate_index)
   {
      if(gate_index < 0 || gate_index >= 8)
         return 0.0;
      
      return (gate_attempts[gate_index] > 0) ? 
         (double)gate_successes[gate_index] / gate_attempts[gate_index] : 0.0;
   }
   
   double GetGateSuccessRate(const string& gate_name)
   {
      int index = GetGateIndex(gate_name);
      return GetGateSuccessRate(index);
   }
   
   // Logging and reporting
   void LogEvent(const string& source, const string& event_description, int priority = 1)
   {
      event_bus.Publish(EVENT_SYSTEM_STATUS, source, event_description, priority);
   }
   
   void LogPerformanceMetric(const string& metric_name, double value)
   {
      event_bus.PublishPerformanceEvent(metric_name, value);
   }
   
   void LogError(const string& source, const string& error_message)
   {
      event_bus.PublishErrorEvent(source, error_message);
   }
   
   // Reporting methods
   void PrintHealthReport()
   {
      SystemHealth health = GetSystemHealth();
      
      Print("=== DualEA System Health Report ===");
      Print("Status: ", health.status);
      Print("Gate Success Rate: ", DoubleToString(health.gate_success_rate * 100, 2), "%");
      Print("Insights Freshness: ", DoubleToString(health.insights_freshness_score * 100, 2), "%");
      Print("System Performance: ", DoubleToString(health.system_performance_score * 100, 2), "%");
      Print("Active Signals: ", health.active_signals);
      Print("Processed Events: ", health.processed_events);
      Print("Memory Usage: ", DoubleToString(health.memory_usage_mb, 1), " MB");
      Print("Last Update: ", TimeToString(health.last_update));
   }
   
   void PrintGateStatistics()
   {
      Print("=== Gate Performance Statistics ===");
      string gate_names[] = {"SignalRinse", "MarketSoap", "StrategyScrub", "RiskWash", 
                            "PerformanceWax", "MLPolish", "LiveClean", "FinalVerify"};
      
      for(int i = 0; i < 8; i++)
      {
         double success_rate = GetGateSuccessRate(i);
         Print("Gate ", i, " (", gate_names[i], "): ", 
               gate_successes[i], "/", gate_attempts[i], 
               " (", DoubleToString(success_rate * 100, 1), "%)");
      }
   }
   
   void PrintPerformanceReport()
   {
      PerformanceMetrics metrics = GetPerformanceMetrics();
      
      Print("=== Performance Metrics ===");
      Print("Events per second: ", metrics.events_per_second);
      Print("Signals per hour: ", metrics.signals_per_hour);
      Print("Total events processed: ", total_events_processed);
      Print("Total signals generated: ", total_signals_generated);
      Print("Total trades executed: ", total_trades_executed);
      Print("Monitoring duration: ", (TimeCurrent() - monitoring_start_time), " seconds");
   }
   
   // Reset statistics
   void ResetStatistics()
   {
      for(int i = 0; i < 8; i++)
      {
         gate_attempts[i] = 0;
         gate_successes[i] = 0;
         gate_total_time[i] = 0.0;
      }
      
      total_events_processed = 0;
      total_signals_generated = 0;
      total_trades_executed = 0;
      monitoring_start_time = TimeCurrent();
      current_metrics.measurement_start = TimeCurrent();
      
      Print("SystemMonitor: Statistics reset");
   }
};

// Static instance declaration
static CSystemMonitor* CSystemMonitor::instance = NULL;

#endif
