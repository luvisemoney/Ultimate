//+------------------------------------------------------------------+
//| EventBus.mqh - Unified Event System for Cross-Component Communication |
//+------------------------------------------------------------------+
#ifndef __EVENTBUS_MQH__
#define __EVENTBUS_MQH__

#include <Arrays/ArrayString.mqh>

// Event types enumeration
enum EVENT_TYPE
{
   EVENT_GATE_PROCESSED,      // Gate processing completed
   EVENT_SIGNAL_GENERATED,    // New trading signal generated
   EVENT_INSIGHTS_UPDATED,    // Insights data updated
   EVENT_TRADE_EXECUTED,      // Trade execution completed
   EVENT_SYSTEM_STATUS,       // System status change
   EVENT_CONFIG_CHANGED,      // Configuration updated
   EVENT_ERROR_OCCURRED,      // Error event
   EVENT_PERFORMANCE_METRIC   // Performance metric update
};

// Event data structure
struct EventData
{
   EVENT_TYPE type;
   string source;
   string data;
   datetime timestamp;
   int priority; // 0=low, 1=normal, 2=high, 3=critical
   
   EventData()
   {
      type = EVENT_SYSTEM_STATUS;
      source = "";
      data = "";
      timestamp = TimeCurrent();
      priority = 1;
   }
};

// Event subscriber interface
class IEventSubscriber
{
public:
   virtual ~IEventSubscriber() {}
   virtual void OnEvent(const EventData& event) = 0;
   virtual string GetSubscriberName() = 0;
};

// Simple event subscriber for function callbacks
class CFunctionSubscriber : public IEventSubscriber
{
private:
   string m_name;
   
public:
   CFunctionSubscriber(const string& name) : m_name(name) {}
   
   void OnEvent(const EventData& event) override
   {
      // Default implementation - can be overridden
      Print("[", m_name, "] Received event: ", EnumToString(event.type), " from ", event.source);
   }
   
   string GetSubscriberName() override { return m_name; }
};

// Event bus singleton
class CEventBus
{
private:
   static CEventBus* instance;
   IEventSubscriber* subscribers[EVENT_PERFORMANCE_METRIC + 1][10]; // Max 10 subscribers per event type
   int subscriber_counts[EVENT_PERFORMANCE_METRIC + 1];
   EventData event_history[100]; // Keep last 100 events
   int history_index;
   bool verbose_logging;
   
   CEventBus()
   {
      // Initialize subscriber arrays
      for(int i = 0; i <= EVENT_PERFORMANCE_METRIC; i++)
      {
         subscriber_counts[i] = 0;
         for(int j = 0; j < 10; j++)
            subscribers[i][j] = NULL;
      }
      
      history_index = 0;
      verbose_logging = false;
   }
   
public:
   static CEventBus* GetInstance()
   {
      if(instance == NULL)
         instance = new CEventBus();
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
   
   // Subscribe to events
   bool Subscribe(EVENT_TYPE event_type, IEventSubscriber* subscriber)
   {
      if(subscriber == NULL || event_type < 0 || event_type > EVENT_PERFORMANCE_METRIC)
         return false;
      
      int count = subscriber_counts[event_type];
      if(count >= 10) // Max subscribers reached
      {
         Print("EventBus: Maximum subscribers reached for event type ", EnumToString(event_type));
         return false;
      }
      
      subscribers[event_type][count] = subscriber;
      subscriber_counts[event_type]++;
      
      if(verbose_logging)
         Print("EventBus: Subscriber '", subscriber.GetSubscriberName(), 
               "' registered for ", EnumToString(event_type));
      
      return true;
   }
   
   // Unsubscribe from events
   bool Unsubscribe(EVENT_TYPE event_type, IEventSubscriber* subscriber)
   {
      if(subscriber == NULL || event_type < 0 || event_type > EVENT_PERFORMANCE_METRIC)
         return false;
      
      int count = subscriber_counts[event_type];
      for(int i = 0; i < count; i++)
      {
         if(subscribers[event_type][i] == subscriber)
         {
            // Shift remaining subscribers
            for(int j = i; j < count - 1; j++)
               subscribers[event_type][j] = subscribers[event_type][j + 1];
            
            subscribers[event_type][count - 1] = NULL;
            subscriber_counts[event_type]--;
            
            if(verbose_logging)
               Print("EventBus: Subscriber '", subscriber.GetSubscriberName(), 
                     "' unregistered from ", EnumToString(event_type));
            
            return true;
         }
      }
      
      return false;
   }
   
   // Publish event to all subscribers
   void Publish(EVENT_TYPE event_type, const string& source, const string& data, int priority = 1)
   {
      EventData event;
      event.type = event_type;
      event.source = source;
      event.data = data;
      event.timestamp = TimeCurrent();
      event.priority = priority;
      
      // Store in history
      event_history[history_index] = event;
      history_index = (history_index + 1) % 100;
      
      // Log event if verbose
      if(verbose_logging || priority >= 2) // Always log high priority events
      {
         Print("EventBus: [", source, "] ", EnumToString(event_type), " - ", data);
      }
      
      // Notify all subscribers
      int count = subscriber_counts[event_type];
      for(int i = 0; i < count; i++)
      {
         if(subscribers[event_type][i] != NULL)
         {
            subscribers[event_type][i].OnEvent(event);
         }
      }
   }
   
   // Convenience methods for common events
   void PublishGateEvent(const string& gate_name, bool passed, const string& reason)
   {
      string data = gate_name + "|" + (passed ? "PASS" : "FAIL") + "|" + reason;
      Publish(EVENT_GATE_PROCESSED, "GateManager", data, 1);
   }
   
   void PublishSignalEvent(const string& signal_id, const string& symbol, double confidence)
   {
      string data = signal_id + "|" + symbol + "|" + DoubleToString(confidence, 3);
      Publish(EVENT_SIGNAL_GENERATED, "SignalGenerator", data, 1);
   }
   
   void PublishInsightsEvent(const string& action, const string& details)
   {
      Publish(EVENT_INSIGHTS_UPDATED, "InsightsManager", action + "|" + details, 1);
   }
   
   void PublishTradeEvent(const string& trade_id, const string& action, double result)
   {
      string data = trade_id + "|" + action + "|" + DoubleToString(result, 2);
      Publish(EVENT_TRADE_EXECUTED, "TradeManager", data, 2);
   }
   
   void PublishSystemEvent(const string& component, const string& status)
   {
      Publish(EVENT_SYSTEM_STATUS, component, status, 1);
   }
   
   void PublishErrorEvent(const string& component, const string& error_msg)
   {
      Publish(EVENT_ERROR_OCCURRED, component, error_msg, 3);
   }
   
   void PublishPerformanceEvent(const string& metric_name, double value)
   {
      string data = metric_name + "|" + DoubleToString(value, 4);
      Publish(EVENT_PERFORMANCE_METRIC, "SystemMonitor", data, 1);
   }
   
   // Configuration
   void SetVerboseLogging(bool enabled) { verbose_logging = enabled; }
   bool IsVerboseLogging() { return verbose_logging; }
   
   // Event history access
   EventData GetLastEvent(EVENT_TYPE event_type)
   {
      // Search backwards through history for the last event of this type
      for(int i = 0; i < 100; i++)
      {
         int index = (history_index - 1 - i + 100) % 100;
         if(event_history[index].type == event_type && event_history[index].timestamp > 0)
            return event_history[index];
      }
      
      EventData empty;
      return empty;
   }
   
   int GetEventCount(EVENT_TYPE event_type)
   {
      int count = 0;
      for(int i = 0; i < 100; i++)
      {
         if(event_history[i].type == event_type && event_history[i].timestamp > 0)
            count++;
      }
      return count;
   }
   
   // Debug information
   void PrintSubscriberInfo()
   {
      Print("=== EventBus Subscriber Information ===");
      for(int i = 0; i <= EVENT_PERFORMANCE_METRIC; i++)
      {
         if(subscriber_counts[i] > 0)
         {
            Print("Event Type ", EnumToString((EVENT_TYPE)i), ": ", subscriber_counts[i], " subscribers");
            for(int j = 0; j < subscriber_counts[i]; j++)
            {
               if(subscribers[i][j] != NULL)
                  Print("  - ", subscribers[i][j].GetSubscriberName());
            }
         }
      }
   }
   
   void PrintEventHistory(int count = 10)
   {
      Print("=== EventBus Recent Events (last ", count, ") ===");
      for(int i = 0; i < MathMin(count, 100); i++)
      {
         int index = (history_index - 1 - i + 100) % 100;
         EventData event = event_history[index];
         if(event.timestamp > 0)
         {
            Print("[", TimeToString(event.timestamp), "] ", 
                  event.source, " -> ", EnumToString(event.type), ": ", event.data);
         }
      }
   }
};

// Static instance declaration
static CEventBus* CEventBus::instance = NULL;

#endif
