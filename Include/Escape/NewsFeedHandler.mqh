//+------------------------------------------------------------------+
//|                                               NewsFeedHandler.mqh |
//|                                  Copyright 2025, EscapeEA Team   |
//|                                             https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA Team"
#property link      "https://www.escapeea.com"
#property version   "1.00"
#property strict

#include <Arrays\ArrayObj.mqh>
#include <Escape/Common/ErrorHandler.mqh>

//+------------------------------------------------------------------+
//| News Event Structure                                             |
//+------------------------------------------------------------------+
struct SNewsEvent : public CObject
  {
   datetime          time;           // Event time
   string            currency;       // Currency code (e.g., "USD")
   string            title;          // Event title
   int               importance;     // 1-100 importance level
   double            actual;         // Actual value
   double            forecast;       // Forecasted value
   double            previous;       // Previous value
   string            impact;         // Impact level (Low/Medium/High)
   
   //--- Constructor
   SNewsEvent() : time(0), importance(0), actual(0), forecast(0), previous(0) {}
   
   //--- Comparison operator for sorting
   int Compare(const CObject *node, const int mode=0) const
     {
      const SNewsEvent* other = node;
      if(this.time < other.time) return -1;
      if(this.time > other.time) return 1;
      return 0;
     }
  };

//+------------------------------------------------------------------+
//| News Feed Handler Class                                          |
//+------------------------------------------------------------------+
class CNewsFeedHandler
  {
private:
   CArrayObj         m_events;       // Sorted array of news events
   bool              m_initialized;  // Initialization flag
   datetime          m_lastUpdate;   // Last update time
   
   // Configuration
   int               m_updateInterval;  // Update interval in seconds
   string            m_currencies[];    // Currencies to monitor
   
   // Cache
   string            m_cacheDir;     // Cache directory
   
public:
   //--- Constructor/Destructor
                     CNewsFeedHandler(void);
                    ~CNewsFeedHandler(void);
   
   //--- Initialization
   bool              Initialize(void);
   void              Shutdown(void);
   
   //--- Event Management
   bool              UpdateEvents(void);
   bool              GetNextEvent(const datetime time, MqlCalendarEvent &event);
   bool              HasUpcomingEvent(const string currency, const int hoursAhead=24);
   
   //--- Configuration
   void              SetUpdateInterval(const int seconds) { m_updateInterval = seconds; }
   void              SetCurrencies(const string &currencies[]);
   
private:
   //--- Helper Methods
   bool              LoadEventsFromWeb(void);
   bool              LoadEventsFromFile(const string filename);
   bool              SaveEventsToFile(const string filename);
   void              SortEvents(void);
   bool              IsEventRelevant(const SNewsEvent &event);
   
   //--- Web API Helpers
   string            BuildRequestUrl(void) const;
   bool              ParseJsonResponse(const string json);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CNewsFeedHandler::CNewsFeedHandler(void) :
   m_initialized(false),
   m_lastUpdate(0),
   m_updateInterval(3600)  // Default: 1 hour
  {
   // Default currencies to monitor
   ArrayResize(m_currencies, 8);
   m_currencies[0] = "USD";
   m_currencies[1] = "EUR";
   m_currencies[2] = "GBP";
   m_currencies[3] = "JPY";
   m_currencies[4] = "AUD";
   m_currencies[5] = "NZD";
   m_currencies[6] = "CAD";
   m_currencies[7] = "CHF";
   
   // Set cache directory
   m_cacheDir = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\EscapeEA\\Cache\\";
   FileCreateDirectory(m_cacheDir);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CNewsFeedHandler::~CNewsFeedHandler(void)
  {
   Shutdown();
  }

//+------------------------------------------------------------------+
//| Initialize the news handler                                      |
//+------------------------------------------------------------------+
bool CNewsFeedHandler::Initialize(void)
  {
   if(m_initialized)
      return true;
      
   // Load cached events if available
   string cacheFile = m_cacheDir + "news_events.cache";
   if(FileIsExist(cacheFile))
     {
      if(LoadEventsFromFile(cacheFile))
        {
         m_lastUpdate = TimeCurrent();
         m_initialized = true;
         return true;
        }
     }
     
   // Otherwise, force an update
   m_initialized = UpdateEvents();
   return m_initialized;
  }

//+------------------------------------------------------------------+
//| Shutdown the news handler                                        |
//+------------------------------------------------------------------+
void CNewsFeedHandler::Shutdown(void)
  {
   if(!m_initialized)
      return;
      
   // Save events to cache
   string cacheFile = m_cacheDir + "news_events.cache";
   SaveEventsToFile(cacheFile);
   
   // Clear events
   m_events.Clear();
   m_initialized = false;
  }

//+------------------------------------------------------------------+
//| Update the list of events from the web                           |
//+------------------------------------------------------------------+
bool CNewsFeedHandler::UpdateEvents(void)
  {
   // Check if we need to update
   if(TimeCurrent() - m_lastUpdate < m_updateInterval && m_events.Total() > 0)
      return true;
      
   // Clear existing events
   m_events.Clear();
   
   // Try to load from web
   bool success = LoadEventsFromWeb();
   
   // If web load failed, try to load from cache
   if(!success)
     {
      string cacheFile = m_cacheDir + "news_events.cache";
      if(FileIsExist(cacheFile))
         success = LoadEventsFromFile(cacheFile);
     }
     
   if(success)
     {
      // Sort events by time
      SortEvents();
      m_lastUpdate = TimeCurrent();
      
      // Save to cache
      string cacheFile = m_cacheDir + "news_events.cache";
      SaveEventsToFile(cacheFile);
     }
     
   return success;
  }

//+------------------------------------------------------------------+
//| Get the next upcoming event after the specified time             |
//+------------------------------------------------------------------+
bool CNewsFeedHandler::GetNextEvent(const datetime time, MqlCalendarEvent &event)
  {
   if(!m_initialized && !Initialize())
      return false;
      
   // Find the first event after the specified time
   for(int i = 0; i < m_events.Total(); i++)
     {
      SNewsEvent* e = m_events.At(i);
      if(e.time > time)
        {
         // Convert to MqlCalendarEvent
         event.time = e.time;
         event.currency = e.currency;
         event.title = e.title;
         event.importance = e.importance;
         event.actual = e.actual;
         event.forecast = e.forecast;
         event.previous = e.previous;
         return true;
        }
     }
     
   return false;
  }

//+------------------------------------------------------------------+
//| Check if there's an upcoming event for the specified currency    |
//+------------------------------------------------------------------+
bool CNewsFeedHandler::HasUpcomingEvent(const string currency, const int hoursAhead=24)
  {
   if(!m_initialized && !Initialize())
      return false;
      
   datetime now = TimeCurrent();
   datetime endTime = now + hoursAhead * 3600;
   
   for(int i = 0; i < m_events.Total(); i++)
     {
      SNewsEvent* e = m_events.At(i);
      if(e.time >= now && e.time <= endTime && e.currency == currency)
         return true;
     }
     
   return false;
  }

//+------------------------------------------------------------------+
//| Set the list of currencies to monitor                            |
//+------------------------------------------------------------------+
void CNewsFeedHandler::SetCurrencies(const string &currencies[])
  {
   int count = ArraySize(currencies);
   ArrayResize(m_currencies, count);
   for(int i = 0; i < count; i++)
      m_currencies[i] = currencies[i];
      
   // Force reload on next update
   m_events.Clear();
  }

//+------------------------------------------------------------------+
//| Load events from a web API                                       |
//+------------------------------------------------------------------+
bool CNewsFeedHandler::LoadEventsFromWeb(void)
  {
   string url = BuildRequestUrl();
   string headers;
   char   data[];
   char   result[];
   
   // Make HTTP request
   int res = WebRequest("GET", url, headers, 5000, data, result, headers);
   if(res != 200)
     {
      CErrorHandler::HandleError(ERR_WEB_REQUEST, "Failed to fetch news data: " + IntegerToString(res));
      return false;
     }
     
   // Parse JSON response
   return ParseJsonResponse(CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8));
  }

//+------------------------------------------------------------------+
//| Load events from a file                                          |
//+------------------------------------------------------------------+
bool CNewsFeedHandler::LoadEventsFromFile(const string filename)
  {
   int handle = FileOpen(filename, FILE_READ|FILE_BIN);
   if(handle == INVALID_HANDLE)
     {
      CErrorHandler::HandleError(ERR_CANNOT_OPEN_FILE, "Failed to open cache file: " + filename);
      return false;
     }
     
   // Read number of events
   int count;
   if(FileReadInteger(handle, INT_VALUE) != 0x454E5753)  // "SWNE" magic number
     {
      FileClose(handle);
      return false;
     }
     
   int version = FileReadInteger(handle, INT_VALUE);
   if(version != 1)
     {
      FileClose(handle);
      return false;
     }
     
   count = FileReadInteger(handle, INT_VALUE);
   
   // Read events
   for(int i = 0; i < count; i++)
     {
      SNewsEvent* event = new SNewsEvent();
      event.time = (datetime)FileReadLong(handle);
      event.currency = FileReadString(handle);
      event.title = FileReadString(handle);
      event.importance = FileReadInteger(handle, INT_VALUE);
      event.actual = FileReadDouble(handle);
      event.forecast = FileReadDouble(handle);
      event.previous = FileReadDouble(handle);
      event.impact = FileReadString(handle);
      
      if(IsEventRelevant(*event))
         m_events.Add(event);
      else
         delete event;
     }
     
   FileClose(handle);
   return m_events.Total() > 0;
  }

//+------------------------------------------------------------------+
//| Save events to a file                                            |
//+------------------------------------------------------------------+
bool CNewsFeedHandler::SaveEventsToFile(const string filename)
  {
   int handle = FileOpen(filename, FILE_WRITE|FILE_BIN);
   if(handle == INVALID_HANDLE)
     {
      CErrorHandler::HandleError(ERR_CANNOT_CREATE_FILE, "Failed to create cache file: " + filename);
      return false;
     }
     
   // Write header
   FileWriteInteger(handle, 0x454E5753, INT_VALUE);  // "SWNE" magic number
   FileWriteInteger(handle, 1, INT_VALUE);           // Version
   FileWriteInteger(handle, m_events.Total(), INT_VALUE);
   
   // Write events
   for(int i = 0; i < m_events.Total(); i++)
     {
      SNewsEvent* event = m_events.At(i);
      FileWriteLong(handle, event.time);
      FileWriteString(handle, event.currency, -1);
      FileWriteString(handle, event.title, -1);
      FileWriteInteger(handle, event.importance, INT_VALUE);
      FileWriteDouble(handle, event.actual, DOUBLE_VALUE);
      FileWriteDouble(handle, event.forecast, DOUBLE_VALUE);
      FileWriteDouble(handle, event.previous, DOUBLE_VALUE);
      FileWriteString(handle, event.impact, -1);
     }
     
   FileClose(handle);
   return true;
  }

//+------------------------------------------------------------------+
//| Sort events by time                                              |
//+------------------------------------------------------------------+
void CNewsFeedHandler::SortEvents(void)
  {
   m_events.Sort(0, WHOLE_ARRAY);
  }

//+------------------------------------------------------------------+
//| Check if an event is relevant to our trading                     |
//+------------------------------------------------------------------+
bool CNewsFeedHandler::IsEventRelevant(const SNewsEvent &event)
  {
   // Check currency
   bool currencyMatch = false;
   for(int i = 0; i < ArraySize(m_currencies); i++)
     {
      if(event.currency == m_currencies[i])
        {
         currencyMatch = true;
         break;
        }
     }
     
   if(!currencyMatch)
      return false;
      
   // Check importance (only medium and high impact)
   if(event.importance < 2)  // Assuming 0-2 scale where 2 is highest
      return false;
      
   return true;
  }

//+------------------------------------------------------------------+
//| Build the web request URL                                        |
//+------------------------------------------------------------------+
string CNewsFeedHandler::BuildRequestUrl(void) const
  {
   // This is a placeholder - replace with actual economic calendar API
   string url = "https://api.example.com/economic-calendar?apikey=YOUR_API_KEY";
   
   // Add date range (next 7 days)
   datetime now = TimeCurrent();
   string from = TimeToString(now, TIME_DATE|TIME_DATE);
   string to = TimeToString(now + 7*24*60*60, TIME_DATE|TIME_DATE);
   
   url += "&from=" + from + "&to=" + to;
   
   // Add currencies
   for(int i = 0; i < ArraySize(m_currencies); i++)
      url += "&currency=" + m_currencies[i];
      
   return url;
  }

//+------------------------------------------------------------------+
//| Parse JSON response from web API                                 |
//+------------------------------------------------------------------+
bool CNewsFeedHandler::ParseJsonResponse(const string json)
  {
   // This is a placeholder - implement actual JSON parsing
   // using your preferred method (JSON Parser library, StringSplit, etc.)
   
   // Example structure (simplified):
   /*
   [
     {
       "date": "2025-08-01T14:30:00Z",
       "currency": "USD",
       "title": "Non-Farm Payrolls",
       "importance": 3,
       "actual": 185,
       "forecast": 190,
       "previous": 178,
       "impact": "High"
     },
     ...
   ]
   */
   
   // For now, just return false to indicate parsing failure
   return false;
  }
//+------------------------------------------------------------------+
