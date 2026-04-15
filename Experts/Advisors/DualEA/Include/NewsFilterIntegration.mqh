//+------------------------------------------------------------------+
//| NewsFilterIntegration.mqh - Easy Integration for PaperEA/LiveEA   |
//| Drop-in replacement for existing news filter with dynamic           |
//| threshold adjustment and ML integration                              |
//+------------------------------------------------------------------+
#ifndef NEWSFILTERINTEGRATION_MQH
#define NEWSFILTERINTEGRATION_MQH

// Include new modules
#include "CErrorRecovery.mqh"
#include "CUnifiedFileIO.mqh"
#include "CEconomicCalendar.mqh"
#include "CNewsImpactAnalyzer.mqh"

//+------------------------------------------------------------------+
//| News Filter Integration Class                                       |
//+------------------------------------------------------------------+
class CNewsFilterIntegration
{
private:
   // Component references
   CEconomicCalendar*     m_calendar;
   CNewsImpactAnalyzer*   m_analyzer;
   CErrorRecovery*        m_error_recovery;
   CUnifiedFileIO*        m_file_io;
   
   // State
   bool                   m_initialized;
   string                 m_symbol;
   datetime               m_last_check;
   int                    m_check_interval_sec;
   
   // Configuration (matches existing input parameters)
   bool                   m_use_news_filter;
   int                    m_buffer_before_min;
   int                    m_buffer_after_min;
   int                    m_min_impact;
   bool                   m_use_dynamic_thresholds;
   bool                   m_export_for_ml;
   
   // Current state
   bool                   m_last_result;
   SThresholdAdjustment   m_last_adjustment;
   string                 m_last_reason;
   
   // Statistics
   int                    m_check_count;
   int                    m_block_count;
   int                    m_adjust_count;

public:
   CNewsFilterIntegration()
   {
      m_calendar = NULL;
      m_analyzer = NULL;
      m_error_recovery = NULL;
      m_file_io = NULL;
      
      m_initialized = false;
      m_symbol = "";
      m_last_check = 0;
      m_check_interval_sec = 1; // Check every second max
      
      m_use_news_filter = true;
      m_buffer_before_min = 30;
      m_buffer_after_min = 30;
      m_min_impact = 1; // Medium and high
      m_use_dynamic_thresholds = true;
      m_export_for_ml = true;
      
      m_last_result = true;
      m_last_reason = "";
      
      m_check_count = 0;
      m_block_count = 0;
      m_adjust_count = 0;
   }
   
   ~CNewsFilterIntegration()
   {
      Shutdown();
   }
   
   //+------------------------------------------------------------------+
   //| Initialize the integrated news filter                              |
   //+------------------------------------------------------------------+
   bool Initialize(const string symbol,
                  bool use_news_filter = true,
                  int buffer_before_min = 30,
                  int buffer_after_min = 30,
                  int min_impact = 1,
                  bool use_dynamic_thresholds = true,
                  bool export_for_ml = true)
   {
      if(m_initialized)
         return true;
      
      m_symbol = symbol;
      m_use_news_filter = use_news_filter;
      m_buffer_before_min = buffer_before_min;
      m_buffer_after_min = buffer_after_min;
      m_min_impact = min_impact;
      m_use_dynamic_thresholds = use_dynamic_thresholds;
      m_export_for_ml = export_for_ml;
      
      // Initialize error recovery
      m_error_recovery = CErrorRecovery::Instance();
      m_file_io = CUnifiedFileIO::Instance();
      
      // Initialize economic calendar
      m_calendar = CEconomicCalendar::Instance();
      
      // Set currencies to monitor
      string currencies[];
      ArrayResize(currencies, 10);
      currencies[0] = "USD";
      currencies[1] = "EUR";
      currencies[2] = "GBP";
      currencies[3] = "JPY";
      currencies[4] = "AUD";
      currencies[5] = "CAD";
      currencies[6] = "CHF";
      currencies[7] = "NZD";
      ArrayResize(currencies, 8);
      
      m_calendar.SetCurrencies(currencies);
      m_calendar.SetUpdateInterval(300); // 5 minutes
      
      // Initialize news impact analyzer
      if(m_use_dynamic_thresholds)
      {
         m_analyzer = CNewsImpactAnalyzer::Instance();
         m_analyzer.SetExportForTraining(m_export_for_ml);
         
         // Configure thresholds
         m_analyzer.SetSpreadThreshold(1.5);  // 150% of normal spread
         m_analyzer.SetVolatilityThreshold(2.0); // 200% of normal volatility
      }
      
      // Initial load of events
      if(m_use_news_filter)
      {
         m_calendar.UpdateEvents();
      }
      
      m_initialized = true;
      
      Log("News Filter Integration initialized for " + symbol);
      Log("  Dynamic thresholds: " + (m_use_dynamic_thresholds ? "ENABLED" : "DISABLED"));
      Log("  ML export: " + (m_export_for_ml ? "ENABLED" : "DISABLED"));
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Shutdown and cleanup                                               |
   //+------------------------------------------------------------------+
   void Shutdown()
   {
      if(!m_initialized)
         return;
      
      // Flush any pending data
      if(m_file_io != NULL)
      {
         FLUSH_FILE_BUFFER(true);
      }
      
      m_initialized = false;
      Log("News Filter Integration shutdown");
   }
   
   //+------------------------------------------------------------------+
   //| Main check function - drop-in replacement for CheckNewsFilter()    |
   //+------------------------------------------------------------------+
   bool CheckNewsFilter()
   {
      if(!m_initialized || !m_use_news_filter)
         return true; // No filter active
      
      // Rate limiting
      datetime now = TimeCurrent();
      if((now - m_last_check) < m_check_interval_sec)
      {
         // Return cached result
         return m_last_result;
      }
      m_last_check = now;
      m_check_count++;
      
      bool should_trade = true;
      string reason = "";
      
      // Dynamic threshold analysis
      if(m_use_dynamic_thresholds && m_analyzer != NULL)
      {
         SThresholdAdjustment adj = ANALYZE_NEWS(m_symbol);
         m_last_adjustment = adj;
         
         should_trade = adj.should_trade;
         reason = adj.reason;
         
         if(!should_trade)
         {
            m_block_count++;
         }
         else if(adj.direction != THRESHOLD_NORMAL)
         {
            m_adjust_count++;
         }
      }
      else
      {
         // Basic calendar check only
         SNewsImpact impact = CHECK_NEWS_IMPACT(m_symbol, m_buffer_before_min, m_buffer_after_min);
         
         if(impact.is_news_time && impact.current_importance >= m_min_impact)
         {
            should_trade = false;
            reason = "News active: " + impact.reason;
            m_block_count++;
         }
      }
      
      m_last_result = should_trade;
      m_last_reason = reason;
      
      // Log if blocked
      if(!should_trade)
      {
         Log("TRADE BLOCKED: " + reason);
      }
      
      return should_trade;
   }
   
   //+------------------------------------------------------------------+
   //| Get threshold adjustment for confidence scaling                     |
   //+------------------------------------------------------------------+
   double GetConfidenceMultiplier()
   {
      if(!m_initialized || !m_use_dynamic_thresholds)
         return 1.0;
      
      // Refresh if needed
      CheckNewsFilter();
      
      return m_last_adjustment.confidence_multiplier;
   }
   
   //+------------------------------------------------------------------+
   //| Get threshold adjustment for position sizing                        |
   //+------------------------------------------------------------------+
   double GetPositionSizeMultiplier()
   {
      if(!m_initialized || !m_use_dynamic_thresholds)
         return 1.0;
      
      return m_last_adjustment.position_size_multiplier;
   }
   
   //+------------------------------------------------------------------+
   //| Get risk multiplier                                                 |
   //+------------------------------------------------------------------+
   double GetRiskMultiplier()
   {
      if(!m_initialized || !m_use_dynamic_thresholds)
         return 1.0;
      
      return m_last_adjustment.risk_multiplier;
   }
   
   //+------------------------------------------------------------------+
   //| Get current news state description                                  |
   //+------------------------------------------------------------------+
   string GetNewsState()
   {
      if(!m_initialized)
         return "NOT INITIALIZED";
      
      if(!m_use_news_filter)
         return "DISABLED";
      
      if(!m_last_result)
         return "BLOCKED: " + m_last_reason;
      
      if(m_use_dynamic_thresholds && m_analyzer != NULL)
      {
         ENUM_NEWS_STATE state = m_analyzer.GetCurrentState();
         switch(state)
         {
            case NEWS_STATE_QUIET:     return "QUIET";
            case NEWS_STATE_WARNING:   return "WARNING: " + m_last_reason;
            case NEWS_STATE_ACTIVE:    return "ACTIVE: " + m_last_reason;
            case NEWS_STATE_AFTERMATH: return "AFTERMATH: " + m_last_reason;
            default:                   return "UNKNOWN";
         }
      }
      
      return "OK";
   }
   
   //+------------------------------------------------------------------+
   //| Apply news adjustment to a signal's confidence                     |
   //+------------------------------------------------------------------+
   double AdjustConfidence(double base_confidence)
   {
      if(!m_initialized || !m_use_dynamic_thresholds)
         return base_confidence;
      
      double multiplier = GetConfidenceMultiplier();
      return base_confidence / multiplier; // Higher multiplier = harder to meet threshold
   }
   
   //+------------------------------------------------------------------+
   //| Apply news adjustment to position size                             |
   //+------------------------------------------------------------------+
   double AdjustPositionSize(double base_lots)
   {
      if(!m_initialized || !m_use_dynamic_thresholds)
         return base_lots;
      
      double multiplier = GetPositionSizeMultiplier();
      return base_lots * multiplier;
   }
   
   //+------------------------------------------------------------------+
   //| Get statistics                                                     |
   //+------------------------------------------------------------------+
   string GetStatistics()
   {
      string stats = StringFormat(
         "=== News Filter Integration Statistics ===\n" +
         "Checks: %d\n" +
         "Blocks: %d (%.1f%%)\n" +
         "Adjustments: %d (%.1f%%)\n" +
         "Current state: %s\n" +
         "Confidence multiplier: %.2f\n" +
         "Size multiplier: %.2f",
         m_check_count,
         m_block_count,
         (m_check_count > 0 ? 100.0 * m_block_count / m_check_count : 0),
         m_adjust_count,
         (m_check_count > 0 ? 100.0 * m_adjust_count / m_check_count : 0),
         GetNewsState(),
         GetConfidenceMultiplier(),
         GetPositionSizeMultiplier()
      );
      
      return stats;
   }
   
   //+------------------------------------------------------------------+
   //| Manual refresh of calendar data                                    |
   //+------------------------------------------------------------------+
   void RefreshCalendar()
   {
      if(!m_initialized)
         return;
      
      if(m_calendar != NULL)
      {
         m_calendar.UpdateEvents();
         Log("Calendar manually refreshed");
      }
   }
   
   //+------------------------------------------------------------------+
   //| Utility functions                                                  |
   //+------------------------------------------------------------------+
   void Log(const string message)
   {
      Print("[NewsFilterIntegration] " + message);
   }
   
   // Getters
   bool IsInitialized() const { return m_initialized; }
   bool IsEnabled() const { return m_use_news_filter; }
   int GetCheckCount() const { return m_check_count; }
   int GetBlockCount() const { return m_block_count; }
};

// Global instance for easy access
CNewsFilterIntegration* g_news_filter_integration = NULL;

//+------------------------------------------------------------------+
//| Initialization helper                                               |
//+------------------------------------------------------------------+
bool InitializeNewsFilter(const string symbol,
                         bool use_news_filter = true,
                         int buffer_before_min = 30,
                         int buffer_after_min = 30,
                         int min_impact = 1,
                         bool use_dynamic_thresholds = true,
                         bool export_for_ml = true)
{
   if(g_news_filter_integration == NULL)
      g_news_filter_integration = new CNewsFilterIntegration();
   
   return g_news_filter_integration.Initialize(
      symbol,
      use_news_filter,
      buffer_before_min,
      buffer_after_min,
      min_impact,
      use_dynamic_thresholds,
      export_for_ml
   );
}

//+------------------------------------------------------------------+
//| Shutdown helper                                                    |
//+------------------------------------------------------------------+
void ShutdownNewsFilter()
{
   if(g_news_filter_integration != NULL)
   {
      delete g_news_filter_integration;
      g_news_filter_integration = NULL;
   }
}

//+------------------------------------------------------------------+
//| Drop-in replacement for CheckNewsFilter()                          |
//+------------------------------------------------------------------+
bool CheckNewsFilterIntegrated()
{
   if(g_news_filter_integration == NULL)
      return true; // No filter active
   
   return g_news_filter_integration.CheckNewsFilter();
}

//+------------------------------------------------------------------+
//| Get adjusted confidence                                            |
//+------------------------------------------------------------------+
double GetNewsAdjustedConfidence(double base_confidence)
{
   if(g_news_filter_integration == NULL)
      return base_confidence;
   
   return g_news_filter_integration.AdjustConfidence(base_confidence);
}

//+------------------------------------------------------------------+
//| Get adjusted position size                                         |
//+------------------------------------------------------------------+
double GetNewsAdjustedPositionSize(double base_lots)
{
   if(g_news_filter_integration == NULL)
      return base_lots;
   
   return g_news_filter_integration.AdjustPositionSize(base_lots);
}

// Convenience macros for integration
#define INIT_NEWS_FILTER(sym) \
   InitializeNewsFilter(sym, UseNewsFilter, NewsBufferBeforeMin, NewsBufferAfterMin, NewsImpactMin, true, true)

#define CHECK_NEWS_FILTER() \
   CheckNewsFilterIntegrated()

#define ADJUST_CONFIDENCE_FOR_NEWS(conf) \
   GetNewsAdjustedConfidence(conf)

#define ADJUST_SIZE_FOR_NEWS(lots) \
   GetNewsAdjustedPositionSize(lots)

#define GET_NEWS_STATE() \
   (g_news_filter_integration != NULL ? g_news_filter_integration.GetNewsState() : "NOT INITIALIZED")

#define REFRESH_NEWS_CALENDAR() \
   if(g_news_filter_integration != NULL) g_news_filter_integration.RefreshCalendar()

#endif // NEWSFILTERINTEGRATION_MQH
