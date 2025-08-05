//+------------------------------------------------------------------+
//|                                               MarketAnalyzer.mqh |
//|                                  Copyright 2025, EscapeEA Team   |
//|                                             https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA Team"
#property link      "https://www.escapeea.com"
#property version   "1.00"
#property strict

#include <Escape/NewsFeedHandler.mqh>
#include <Escape/VolatilityManager.mqh>

//+------------------------------------------------------------------+
//| News Impact Score Enumeration                                    |
//+------------------------------------------------------------------+
enum ENUM_NEWS_IMPACT
  {
   IMPACT_NONE = 0,    // No Impact
   IMPACT_LOW = 1,     // Low Impact
   IMPACT_MEDIUM = 2,  // Medium Impact
   IMPACT_HIGH = 3,    // High Impact
   IMPACT_EXTREME = 4  // Extreme Impact
  };

//+------------------------------------------------------------------+
//| News Impact Analysis Class                                       |
//+------------------------------------------------------------------+
class CMarketAnalyzer
  {
private:
   CNewsFeedHandler   *m_newsHandler;     // News feed handler
   CVolatilityManager *m_volManager;      // Volatility manager
   
   // Configuration
   int                m_lookbackPeriod;   // Period for historical analysis
   double             m_impactThreshold;  // Threshold for significant impact
   bool               m_enableNewsFilter; // Enable/disable news filtering
   
   // State
   datetime           m_lastUpdate;       // Last update time
   
public:
   //--- Constructor/Destructor
                     CMarketAnalyzer(void);
                    ~CMarketAnalyzer(void);
   
   //--- Initialization
   bool              Initialize(void);
   void              Shutdown(void);
   
   //--- News Impact Analysis
   ENUM_NEWS_IMPACT  GetNewsImpact(const string symbol, const datetime time);
   bool              IsNewsImpactHigh(const string symbol, const datetime time);
   
   //--- Configuration
   void              SetLookbackPeriod(const int period) { m_lookbackPeriod = period; }
   void              SetImpactThreshold(const double threshold) { m_impactThreshold = threshold; }
   void              EnableNewsFilter(const bool enable) { m_enableNewsFilter = enable; }
   
private:
   //--- Helper Methods
   double            CalculateImpactScore(const MqlCalendarEvent &event);
   bool              IsWithinTradingHours(const datetime time);
   
   //--- Volatility Analysis
   double            GetVolatilityAdjustment(const string symbol, const datetime time);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMarketAnalyzer::CMarketAnalyzer(void) :
   m_lookbackPeriod(14),
   m_impactThreshold(0.7),
   m_enableNewsFilter(true),
   m_lastUpdate(0)
  {
   m_newsHandler = new CNewsFeedHandler();
   m_volManager = new CVolatilityManager();
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMarketAnalyzer::~CMarketAnalyzer(void)
  {
   Shutdown();
   delete m_newsHandler;
   delete m_volManager;
  }

//+------------------------------------------------------------------+
//| Initialize the analyzer                                          |
//+------------------------------------------------------------------+
bool CMarketAnalyzer::Initialize(void)
  {
   if(!m_newsHandler.Initialize())
     {
      Print("Failed to initialize news feed handler");
      return false;
     }
     
   if(!m_volManager.Initialize())
     {
      Print("Failed to initialize volatility manager");
      return false;
     }
     
   return true;
  }

//+------------------------------------------------------------------+
//| Shutdown the analyzer                                            |
//+------------------------------------------------------------------+
void CMarketAnalyzer::Shutdown(void)
  {
   m_newsHandler.Shutdown();
   m_volManager.Shutdown();
  }

//+------------------------------------------------------------------+
//| Get news impact for a specific symbol and time                   |
//+------------------------------------------------------------------+
ENUM_NEWS_IMPACT CMarketAnalyzer::GetNewsImpact(const string symbol, const datetime time)
  {
   if(!m_enableNewsFilter)
      return IMPACT_NONE;
      
   // Check if we have news data for this time
   MqlCalendarEvent event;
   if(!m_newsHandler.GetNextEvent(time, event))
      return IMPACT_NONE;
      
   // Calculate impact score
   double score = CalculateImpactScore(event);
   
   // Adjust for current market volatility
   double volAdjustment = GetVolatilityAdjustment(symbol, time);
   score *= volAdjustment;
   
   // Map score to impact level
   if(score >= 0.8) return IMPACT_EXTREME;
   if(score >= 0.6) return IMPACT_HIGH;
   if(score >= 0.4) return IMPACT_MEDIUM;
   if(score >= 0.2) return IMPACT_LOW;
   
   return IMPACT_NONE;
  }

//+------------------------------------------------------------------+
//| Check if news impact is high                                     |
//+------------------------------------------------------------------+
bool CMarketAnalyzer::IsNewsImpactHigh(const string symbol, const datetime time)
  {
   return GetNewsImpact(symbol, time) >= IMPACT_HIGH;
  }

//+------------------------------------------------------------------+
//| Calculate impact score for a news event                          |
//+------------------------------------------------------------------+
double CMarketAnalyzer::CalculateImpactScore(const MqlCalendarEvent &event)
  {
   // Base score from event importance
   double score = event.importance / 100.0;
   
   // Adjust for event type (e.g., NFP, FOMC, etc.)
   switch(event.event_type)
     {
      case CALENDAR_EVENT_NFP:      score *= 1.2; break;
      case CALENDAR_EVENT_FOMC:     score *= 1.5; break;
      case CALENDAR_EVENT_CPI:      score *= 1.3; break;
      case CALENDAR_EVENT_RATE:     score *= 1.4; break;
      // Add more event types as needed
      default:                      score *= 0.8; break;
     }
     
   return MathMin(1.0, MathMax(0.0, score));
  }

//+------------------------------------------------------------------+
//| Check if time is within trading hours                            |
//+------------------------------------------------------------------+
bool CMarketAnalyzer::IsWithinTradingHours(const datetime time)
  {
   MqlDateTime dt;
   TimeToStruct(time, dt);
   
   // Example: Trade only between 8 AM and 4 PM
   return (dt.hour >= 8 && dt.hour < 16);
  }

//+------------------------------------------------------------------+
//| Get volatility adjustment factor                                 |
//+------------------------------------------------------------------+
double CMarketAnalyzer::GetVolatilityAdjustment(const string symbol, const datetime time)
  {
   double currentVol = m_volManager.GetCurrentVolatility(symbol, PERIOD_CURRENT, 14);
   double avgVol = m_volManager.GetAverageVolatility(symbol, PERIOD_CURRENT, 14, 100);
   
   // If current volatility is more than 2x average, reduce impact
   if(currentVol > 2 * avgVol)
      return 0.5;
      
   // If current volatility is less than half of average, increase impact
   if(currentVol < 0.5 * avgVol)
      return 1.5;
      
   return 1.0;
  }
//+------------------------------------------------------------------+
