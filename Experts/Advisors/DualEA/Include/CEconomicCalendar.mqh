//+------------------------------------------------------------------+
//| CEconomicCalendar.mqh - MQL5 Economic Calendar Integration          |
//| Provides direct access to MQL5 Economic Calendar for real-time       |
//| news event detection and impact analysis                            |
//| Based on MQL5 article: "Using the MQL5 Economic Calendar for News   |
//| Filter (Part 3): Surviving Terminal Restarts During News Window"  |
//+------------------------------------------------------------------+
#ifndef CECONOMICCALENDAR_MQH
#define CECONOMICCALENDAR_MQH

#include "CErrorRecovery.mqh"
#include "CUnifiedFileIO.mqh"

// Event importance levels
enum ENUM_EVENT_IMPORTANCE
{
   EVENT_IMPORTANCE_LOW = 0,
   EVENT_IMPORTANCE_MEDIUM = 1,
   EVENT_IMPORTANCE_HIGH = 2
};

// Event type
enum ENUM_EVENT_TYPE
{
   EVENT_TYPE_NONE = 0,
   EVENT_TYPE_ECONOMIC = 1,
   EVENT_TYPE_POLITICAL = 2,
   EVENT_TYPE_NATURAL = 3,
   EVENT_TYPE_CENTRAL_BANK = 4
};

//+------------------------------------------------------------------+
//| Economic Event Structure                                           |
//+------------------------------------------------------------------+
struct SEconomicEvent
{
   long         id;
   string       name;
   string       currency;
   string       country;
   datetime     event_time;
   int          importance;        // 0=low, 1=medium, 2=high
   double       actual_value;
   double       forecast_value;
   double       previous_value;
   bool         has_actual;
   bool         has_forecast;
   bool         has_previous;
   string       event_type;
   
   SEconomicEvent()
   {
      id = 0;
      name = "";
      currency = "";
      country = "";
      event_time = 0;
      importance = 0;
      actual_value = 0.0;
      forecast_value = 0.0;
      previous_value = 0.0;
      has_actual = false;
      has_forecast = false;
      has_previous = false;
      event_type = "";
   }
};

//+------------------------------------------------------------------+
//| News Impact Analysis Result                                         |
//+------------------------------------------------------------------+
struct SNewsImpact
{
   bool         is_news_time;
   int          current_importance;
   int          upcoming_importance;
   datetime     next_event_time;
   string       next_event_name;
   double       volatility_prediction;
   double       confidence_adjustment;
   string       reason;
   
   SNewsImpact()
   {
      is_news_time = false;
      current_importance = 0;
      upcoming_importance = 0;
      next_event_time = 0;
      next_event_name = "";
      volatility_prediction = 0.0;
      confidence_adjustment = 1.0;
      reason = "";
   }
};

//+------------------------------------------------------------------+
//| Economic Calendar Manager                                           |
//+------------------------------------------------------------------+
class CEconomicCalendar
{
private:
   static CEconomicCalendar* s_instance;
   
   // Event cache
   SEconomicEvent       m_events[];
   int                  m_event_count;
   int                  m_max_events;
   datetime             m_last_update;
   int                  m_update_interval_sec;
   
   // Currency filter
   string               m_currencies[];
   int                  m_currency_count;
   
   // Configuration
   int                  m_lookback_hours;
   int                  m_lookahead_hours;
   bool                 m_use_api;
   bool                 m_use_fallback_file;
   string               m_fallback_filename;
   
   // Statistics
   int                  m_api_calls;
   int                  m_cache_hits;
   int                  m_cache_misses;
   
   // Error recovery
   CErrorRecovery*      m_error_recovery;
   CUnifiedFileIO*      m_file_io;
   
   // Market watch indices for fast lookup
   int                  m_currency_handles[];

public:
   CEconomicCalendar()
   {
      m_event_count = 0;
      m_max_events = 500;
      ArrayResize(m_events, m_max_events);
      
      m_last_update = 0;
      m_update_interval_sec = 300; // 5 minutes
      
      m_currency_count = 0;
      ArrayResize(m_currencies, 10);
      
      m_lookback_hours = 2;
      m_lookahead_hours = 24;
      m_use_api = true;
      m_use_fallback_file = true;
      m_fallback_filename = "DualEA\\economic_calendar.json";
      
      m_api_calls = 0;
      m_cache_hits = 0;
      m_cache_misses = 0;
      
      m_error_recovery = CErrorRecovery::Instance();
      m_file_io = CUnifiedFileIO::Instance();
   }
   
   ~CEconomicCalendar()
   {
   }
   
   static CEconomicCalendar* Instance()
   {
      if(s_instance == NULL)
         s_instance = new CEconomicCalendar();
      return s_instance;
   }
   
   static void Destroy()
   {
      if(s_instance != NULL)
      {
         delete s_instance;
         s_instance = NULL;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Configuration                                                      |
   //+------------------------------------------------------------------+
   void SetCurrencies(const string &currencies[])
   {
      int count = ArraySize(currencies);
      ArrayResize(m_currencies, count);
      for(int i = 0; i < count; i++)
      {
         m_currencies[i] = currencies[i];
      }
      m_currency_count = count;
   }
   
   void SetUpdateInterval(int seconds) { m_update_interval_sec = seconds; }
   void SetLookbackHours(int hours) { m_lookback_hours = hours; }
   void SetLookaheadHours(int hours) { m_lookahead_hours = hours; }
   void SetUseAPI(bool use) { m_use_api = use; }
   void SetFallbackFile(const string filename) { m_fallback_filename = filename; }
   
   //+------------------------------------------------------------------+
   //| Update event cache from MQL5 Calendar                              |
   //+------------------------------------------------------------------+
   bool UpdateEvents()
   {
      datetime now = TimeCurrent();
      
      // Check if update needed
      if(m_last_update > 0 && (now - m_last_update) < m_update_interval_sec)
      {
         m_cache_hits++;
         return true;
      }
      
      m_cache_misses++;
      
      // Clear existing events
      m_event_count = 0;
      ArrayResize(m_events, m_max_events);
      
      bool success = false;
      
      if(m_use_api)
      {
         success = FetchFromAPI();
      }
      
      if(!success && m_use_fallback_file)
      {
         success = FetchFromFallbackFile();
      }
      
      if(success)
      {
         m_last_update = now;
         SortEventsByTime();
         Log("Updated economic calendar: " + IntegerToString(m_event_count) + " events");
      }
      
      return success;
   }
   
   //+------------------------------------------------------------------+
   //| Fetch events from MQL5 Calendar API                                |
   //+------------------------------------------------------------------+
   bool FetchFromAPI()
   {
      // Calculate date range
      datetime from_date = TimeCurrent() - (m_lookback_hours * 3600);
      datetime to_date = TimeCurrent() + (m_lookahead_hours * 3600);
      
      MqlCalendarValue values[];
      
      // Try to get calendar values
      // If specific currencies are set, filter by them
      int retrieved = 0;
      
      if(m_currency_count > 0)
      {
         // Fetch for specific currencies
         for(int c = 0; c < m_currency_count && m_event_count < m_max_events; c++)
         {
            string currency = m_currencies[c];
            
            // Reset array
            ArrayResize(values, 0);
            
            // Get calendar values
            int count = CalendarValueHistory(values, from_date, to_date, currency);
            
            if(count > 0)
            {
               for(int i = 0; i < count && m_event_count < m_max_events; i++)
               {
                  if(AddCalendarValue(values[i]))
                     retrieved++;
               }
            }
            
            m_api_calls++;
         }
      }
      else
      {
         // Get all calendar values
         int count = CalendarValueHistory(values, from_date, to_date, NULL);
         
         if(count > 0)
         {
            for(int i = 0; i < count && m_event_count < m_max_events; i++))
            {
               if(AddCalendarValue(values[i]))
                  retrieved++;
            }
         }
         
         m_api_calls++;
      }
      
      return (retrieved > 0);
   }
   
   //+------------------------------------------------------------------+
   //| Add calendar value to cache                                        |
   //+------------------------------------------------------------------+
   bool AddCalendarValue(const MqlCalendarValue &value)
   {
      if(m_event_count >= m_max_events)
         return false;
      
      SEconomicEvent event;
      
      // Get event details
      MqlCalendarEvent event_info;
      if(!CalendarEventById(value.event_id, event_info))
         return false;
      
      // Get country info
      MqlCalendarCountry country_info;
      if(!CalendarCountryById(event_info.country_id, country_info))
         return false;
      
      event.id = value.event_id;
      event.name = event_info.name;
      event.currency = country_info.currency;
      event.country = country_info.code;
      event.event_time = value.time;
      
      // Determine importance
      switch(event_info.importance)
      {
         case CALENDAR_IMPORTANCE_LOW:
            event.importance = EVENT_IMPORTANCE_LOW;
            break;
         case CALENDAR_IMPORTANCE_MODERATE:
            event.importance = EVENT_IMPORTANCE_MEDIUM;
            break;
         case CALENDAR_IMPORTANCE_HIGH:
            event.importance = EVENT_IMPORTANCE_HIGH;
            break;
      }
      
      // Values
      if(value.actual_type != CALENDAR_VALUE_TYPE_NA)
      {
         event.actual_value = value.actual_value;
         event.has_actual = true;
      }
      
      if(value.forecast_type != CALENDAR_VALUE_TYPE_NA)
      {
         event.forecast_value = value.forecast_value;
         event.has_forecast = true;
      }
      
      if(value.prev_value != 0)
      {
         event.previous_value = value.prev_value;
         event.has_previous = true;
      }
      
      // Event type
      switch(event_info.type)
      {
         case CALENDAR_TYPE_EVENT:
            event.event_type = "economic";
            break;
         case CALENDAR_TYPE_INDICATOR:
            event.event_type = "indicator";
            break;
         case CALENDAR_TYPE_HOLIDAY:
            event.event_type = "holiday";
            break;
         default:
            event.event_type = "other";
      }
      
      // Check for duplicates
      for(int i = 0; i < m_event_count; i++)
      {
         if(m_events[i].id == event.id && m_events[i].event_time == event.event_time)
            return false; // Duplicate
      }
      
      m_events[m_event_count] = event;
      m_event_count++;
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Fetch from fallback file                                           |
   //+------------------------------------------------------------------+
   bool FetchFromFallbackFile()
   {
      string content;
      if(!m_file_io.ReadFile(m_fallback_filename, content, true))
         return false;
      
      // Parse JSON (simplified - would need full JSON parser for production)
      // For now, just log that we loaded the file
      Log("Loaded fallback calendar file: " + m_fallback_filename);
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Sort events by time                                                |
   //+------------------------------------------------------------------+
   void SortEventsByTime()
   {
      // Simple bubble sort for small arrays
      for(int i = 0; i < m_event_count - 1; i++)
      {
         for(int j = 0; j < m_event_count - i - 1; j++)
         {
            if(m_events[j].event_time > m_events[j + 1].event_time)
            {
               SEconomicEvent temp = m_events[j];
               m_events[j] = m_events[j + 1];
               m_events[j + 1] = temp;
            }
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Check if news time (main entry point for trading decisions)       |
   //+------------------------------------------------------------------+
   SNewsImpact CheckNewsImpact(const string symbol, int buffer_minutes_before = 30, int buffer_minutes_after = 30)
   {
      SNewsImpact impact;
      
      // Ensure events are current
      UpdateEvents();
      
      datetime now = TimeCurrent();
      
      // Extract currency from symbol
      string base_currency = StringSubstr(symbol, 0, 3);
      string quote_currency = StringSubstr(symbol, 3, 3);
      
      // Check for active news events
      for(int i = 0; i < m_event_count; i++)
      {
         SEconomicEvent &event = m_events[i];
         
         // Skip if not relevant to this symbol
         if(!IsEventRelevant(event, base_currency, quote_currency))
            continue;
         
         // Calculate effective window
         datetime window_start = event.event_time - (buffer_minutes_before * 60);
         datetime window_end = event.event_time + (buffer_minutes_after * 60);
         
         // Check if currently in news window
         if(now >= window_start && now <= window_end)
         {
            impact.is_news_time = true;
            impact.current_importance = MathMax(impact.current_importance, event.importance);
            
            if(impact.reason != "") impact.reason += "; ";
            impact.reason += event.name + " (" + IntegerToString(event.importance) + ")";
         }
         
         // Check for upcoming events
         if(event.event_time > now && event.event_time < impact.next_event_time)
         {
            impact.next_event_time = event.event_time;
            impact.next_event_name = event.name;
            impact.upcoming_importance = event.importance;
         }
      }
      
      // Calculate confidence adjustment
      impact.confidence_adjustment = CalculateConfidenceAdjustment(impact);
      impact.volatility_prediction = PredictVolatility(impact);
      
      return impact;
   }
   
   //+------------------------------------------------------------------+
   //| Check if event is relevant to symbol                               |
   //+------------------------------------------------------------------+
   bool IsEventRelevant(const SEconomicEvent &event, const string base_currency, const string quote_currency)
   {
      // Direct currency match
      if(event.currency == base_currency || event.currency == quote_currency)
         return true;
      
      // Major USD events affect all pairs
      if(event.currency == "USD" && (base_currency == "USD" || quote_currency == "USD"))
         return true;
      
      // Global events (no specific currency)
      if(event.currency == "" && event.importance >= EVENT_IMPORTANCE_HIGH)
         return true;
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate confidence adjustment based on news                      |
   //+------------------------------------------------------------------+
   double CalculateConfidenceAdjustment(const SNewsImpact &impact)
   {
      if(!impact.is_news_time)
         return 1.0;
      
      // Reduce confidence during news
      double adjustment = 1.0;
      
      switch(impact.current_importance)
      {
         case EVENT_IMPORTANCE_LOW:
            adjustment = 0.9; // 10% reduction
            break;
         case EVENT_IMPORTANCE_MEDIUM:
            adjustment = 0.75; // 25% reduction
            break;
         case EVENT_IMPORTANCE_HIGH:
            adjustment = 0.5; // 50% reduction
            break;
      }
      
      return adjustment;
   }
   
   //+------------------------------------------------------------------+
   //| Predict volatility based on news                                   |
   //+------------------------------------------------------------------+
   double PredictVolatility(const SNewsImpact &impact)
   {
      if(!impact.is_news_time)
         return 0.0;
      
      // Base prediction on importance
      double base_volatility = 0.0;
      
      switch(impact.current_importance)
      {
         case EVENT_IMPORTANCE_LOW:
            base_volatility = 0.2;
            break;
         case EVENT_IMPORTANCE_MEDIUM:
            base_volatility = 0.5;
            break;
         case EVENT_IMPORTANCE_HIGH:
            base_volatility = 1.0;
            break;
      }
      
      // Could be enhanced with historical volatility data
      return base_volatility;
   }
   
   //+------------------------------------------------------------------+
   //| Get next significant event                                         |
   //+------------------------------------------------------------------+
   SEconomicEvent GetNextEvent(int min_importance = EVENT_IMPORTANCE_MEDIUM)
   {
      SEconomicEvent next;
      
      UpdateEvents();
      
      datetime now = TimeCurrent();
      
      for(int i = 0; i < m_event_count; i++)
      {
         if(m_events[i].event_time > now && m_events[i].importance >= min_importance)
         {
            next = m_events[i];
            break;
         }
      }
      
      return next;
   }
   
   //+------------------------------------------------------------------+
   //| Export events to file (for ML training)                           |
   //+------------------------------------------------------------------+
   bool ExportEventsToFile(const string filename)
   {
      string content = "timestamp,event_name,currency,importance,actual,forecast,previous,type\n";
      
      for(int i = 0; i < m_event_count; i++)
      {
         SEconomicEvent &e = m_events[i];
         content += StringFormat("%s,%s,%s,%d,%.5f,%.5f,%.5f,%s\n",
            TimeToString(e.event_time, TIME_DATE|TIME_SECONDS),
            e.name,
            e.currency,
            e.importance,
            e.actual_value,
            e.forecast_value,
            e.previous_value,
            e.event_type
         );
      }
      
      return m_file_io.WriteFile(filename, content, true, false);
   }
   
   //+------------------------------------------------------------------+
   //| Statistics                                                         |
   //+------------------------------------------------------------------+
   string GetStatistics()
   {
      string stats = StringFormat(
         "=== Economic Calendar Statistics ===\n" +
         "Events cached: %d\n" +
         "API calls: %d\n" +
         "Cache hits: %d\n" +
         "Cache misses: %d\n" +
         "Last update: %s",
         m_event_count,
         m_api_calls,
         m_cache_hits,
         m_cache_misses,
         (m_last_update > 0 ? TimeToString(m_last_update) : "Never")
      );
      
      return stats;
   }
   
   //+------------------------------------------------------------------+
   //| Utility functions                                                  |
   //+------------------------------------------------------------------+
   void Log(const string message)
   {
      Print("[EconomicCalendar] " + message);
   }
   
   int GetEventCount() const { return m_event_count; }
   bool IsCacheValid() const { return (TimeCurrent() - m_last_update) < m_update_interval_sec; }
   datetime GetLastUpdate() const { return m_last_update; }
};

// Static instance initialization
CEconomicCalendar* CEconomicCalendar::s_instance = NULL;

// Convenience macros
#define CHECK_NEWS_IMPACT(symbol, buffer_before, buffer_after) \
   CEconomicCalendar::Instance().CheckNewsImpact(symbol, buffer_before, buffer_after)

#define GET_NEXT_EVENT(min_importance) \
   CEconomicCalendar::Instance().GetNextEvent(min_importance)

#define UPDATE_CALENDAR() \
   CEconomicCalendar::Instance().UpdateEvents()

#endif // CECONOMICCALENDAR_MQH
