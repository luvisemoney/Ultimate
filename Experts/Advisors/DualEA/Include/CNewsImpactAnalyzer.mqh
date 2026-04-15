//+------------------------------------------------------------------+
//| CNewsImpactAnalyzer.mqh - Dynamic News-Based Threshold Adjustment  |
//| Analyzes news impact in real-time and adjusts trading thresholds     |
//| dynamically based on market conditions and news sentiment            |
//+------------------------------------------------------------------+
#ifndef CNEWSIMPACTANALYZER_MQH
#define CNEWSIMPACTANALYZER_MQH

#include "CEconomicCalendar.mqh"
#include "CErrorRecovery.mqh"

// News impact state
enum ENUM_NEWS_STATE
{
   NEWS_STATE_QUIET = 0,        // No significant news
   NEWS_STATE_WARNING = 1,      // News approaching
   NEWS_STATE_ACTIVE = 2,       // News happening now
   NEWS_STATE_AFTERMATH = 3     // Post-news volatility
};

// Threshold adjustment direction
enum ENUM_THRESHOLD_ADJUSTMENT
{
   THRESHOLD_NORMAL = 0,        // No adjustment
   THRESHOLD_CONSERVATIVE = 1,  // Increase thresholds (harder to trade)
   THRESHOLD_AGGRESSIVE = 2,    // Decrease thresholds (easier to trade)
   THRESHOLD_BLOCK = 3          // Block trading completely
};

//+------------------------------------------------------------------+
//| Threshold Adjustment Result                                         |
//+------------------------------------------------------------------+
struct SThresholdAdjustment
{
   ENUM_THRESHOLD_ADJUSTMENT direction;
   double                    confidence_multiplier;
   double                    risk_multiplier;
   double                    position_size_multiplier;
   int                       sl_pips_adjustment;
   int                       tp_pips_adjustment;
   string                    reason;
   datetime                  effective_until;
   bool                      should_trade;
   
   SThresholdAdjustment()
   {
      direction = THRESHOLD_NORMAL;
      confidence_multiplier = 1.0;
      risk_multiplier = 1.0;
      position_size_multiplier = 1.0;
      sl_pips_adjustment = 0;
      tp_pips_adjustment = 0;
      reason = "";
      effective_until = 0;
      should_trade = true;
   }
};

//+------------------------------------------------------------------+
//| Market Response Metrics                                           |
//+------------------------------------------------------------------+
struct SMarketResponse
{
   double   price_change_pct;
   double   volatility_spike;
   double   spread_widening;
   int      volume_surge;
   bool     is_trending;
   int      trend_direction;
   datetime measurement_time;
   
   SMarketResponse()
   {
      price_change_pct = 0.0;
      volatility_spike = 0.0;
      spread_widening = 0.0;
      volume_surge = 0;
      is_trending = false;
      trend_direction = 0;
      measurement_time = 0;
   }
};

//+------------------------------------------------------------------+
//| News Impact History Entry                                         |
//+------------------------------------------------------------------+
struct SNewsImpactHistory
{
   long         event_id;
   string       event_name;
   datetime     event_time;
   int          importance;
   double       actual_value;
   double       forecast_value;
   double       surprise_magnitude;
   SMarketResponse market_response;
   bool         profitable_to_trade;
   double       ml_confidence_score;
   
   SNewsImpactHistory()
   {
      event_id = 0;
      event_name = "";
      event_time = 0;
      importance = 0;
      actual_value = 0.0;
      forecast_value = 0.0;
      surprise_magnitude = 0.0;
      profitable_to_trade = false;
      ml_confidence_score = 0.0;
   }
};

//+------------------------------------------------------------------+
//| News Impact Analyzer                                              |
//+------------------------------------------------------------------+
class CNewsImpactAnalyzer
{
private:
   static CNewsImpactAnalyzer* s_instance;
   
   // Components
   CEconomicCalendar*     m_calendar;
   CErrorRecovery*        m_error_recovery;
   
   // State tracking
   ENUM_NEWS_STATE        m_current_state;
   datetime               m_state_since;
   SThresholdAdjustment   m_current_adjustment;
   
   // History for ML
   SNewsImpactHistory     m_impact_history[];
   int                    m_history_count;
   int                    m_max_history;
   
   // Real-time metrics
   double                 m_baseline_volatility;
   double                 m_baseline_spread;
   datetime               m_baseline_measured;
   int                    m_baseline_lookback_bars;
   
   // Configuration
   bool                   m_use_ml_predictions;
   bool                   m_export_for_training;
   string                 m_export_filename;
   int                    m_volatility_measurement_bars;
   double                 m_spread_widening_threshold;
   double                 m_volatility_spike_threshold;
   
   // Telemetry
   int                    m_analysis_count;
   int                    m_trade_blocked_count;
   int                    m_threshold_adjusted_count;

public:
   CNewsImpactAnalyzer()
   {
      m_calendar = CEconomicCalendar::Instance();
      m_error_recovery = CErrorRecovery::Instance();
      
      m_current_state = NEWS_STATE_QUIET;
      m_state_since = 0;
      
      m_history_count = 0;
      m_max_history = 200;
      ArrayResize(m_impact_history, m_max_history);
      
      m_baseline_volatility = 0.0;
      m_baseline_spread = 0.0;
      m_baseline_measured = 0;
      m_baseline_lookback_bars = 20;
      
      m_use_ml_predictions = true;
      m_export_for_training = true;
      m_export_filename = "DualEA\\news_impact_training.csv";
      m_volatility_measurement_bars = 10;
      m_spread_widening_threshold = 1.5;  // 150% of normal
      m_volatility_spike_threshold = 2.0; // 200% of normal
      
      m_analysis_count = 0;
      m_trade_blocked_count = 0;
      m_threshold_adjusted_count = 0;
   }
   
   ~CNewsImpactAnalyzer()
   {
   }
   
   static CNewsImpactAnalyzer* Instance()
   {
      if(s_instance == NULL)
         s_instance = new CNewsImpactAnalyzer();
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
   void SetUseMLPredictions(bool use) { m_use_ml_predictions = use; }
   void SetExportForTraining(bool export_data) { m_export_for_training = export_data; }
   void SetBaselineLookback(int bars) { m_baseline_lookback_bars = bars; }
   void SetSpreadThreshold(double threshold) { m_spread_widening_threshold = threshold; }
   void SetVolatilityThreshold(double threshold) { m_volatility_spike_threshold = threshold; }
   
   //+------------------------------------------------------------------+
   //| Main analysis entry point                                          |
   //+------------------------------------------------------------------+
   SThresholdAdjustment AnalyzeNewsImpact(const string symbol, int buffer_minutes_before = 30, int buffer_minutes_after = 60)
   {
      m_analysis_count++;
      
      SThresholdAdjustment adjustment;
      
      // Get news impact from calendar
      SNewsImpact news_impact = m_calendar.CheckNewsImpact(symbol, buffer_minutes_before, buffer_minutes_after);
      
      // Update baseline if needed
      UpdateBaselineMetrics(symbol);
      
      // Measure current market response
      SMarketResponse response = MeasureMarketResponse(symbol);
      
      // Determine news state
      ENUM_NEWS_STATE new_state = DetermineNewsState(news_impact, response);
      
      // Handle state transition
      if(new_state != m_current_state)
      {
         Log("News state changed from " + StateToString(m_current_state) + " to " + StateToString(new_state));
         m_current_state = new_state;
         m_state_since = TimeCurrent();
      }
      
      // Calculate threshold adjustment
      adjustment = CalculateThresholdAdjustment(new_state, news_impact, response);
      m_current_adjustment = adjustment;
      
      // Update statistics
      if(!adjustment.should_trade)
         m_trade_blocked_count++;
      if(adjustment.direction != THRESHOLD_NORMAL)
         m_threshold_adjusted_count++;
      
      // Record for ML training
      if(m_export_for_training && news_impact.is_news_time)
      {
         RecordForTraining(symbol, news_impact, response, adjustment);
      }
      
      return adjustment;
   }
   
   //+------------------------------------------------------------------+
   //| Update baseline volatility and spread                              |
   //+------------------------------------------------------------------+
   void UpdateBaselineMetrics(const string symbol)
   {
      datetime now = TimeCurrent();
      
      // Update every 5 minutes
      if((now - m_baseline_measured) < 300)
         return;
      
      // Calculate baseline volatility (ATR)
      int atr_handle = iATR(symbol, PERIOD_CURRENT, m_baseline_lookback_bars);
      if(atr_handle != INVALID_HANDLE)
      {
         double atr[];
         if(CopyBuffer(atr_handle, 0, 0, 1, atr) == 1)
         {
            m_baseline_volatility = atr[0];
         }
         IndicatorRelease(atr_handle);
      }
      
      // Get baseline spread
      m_baseline_spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      m_baseline_measured = now;
   }
   
   //+------------------------------------------------------------------+
   //| Measure current market response to news                            |
   //+------------------------------------------------------------------+
   SMarketResponse MeasureMarketResponse(const string symbol)
   {
      SMarketResponse response;
      response.measurement_time = TimeCurrent();
      
      // Price change over last N bars
      MqlRates rates[];
      if(CopyRates(symbol, PERIOD_CURRENT, 0, m_volatility_measurement_bars, rates) == m_volatility_measurement_bars)
      {
         double price_start = rates[0].close;
         double price_end = rates[m_volatility_measurement_bars - 1].close;
         response.price_change_pct = (price_end - price_start) / price_start * 100.0;
         
         // Calculate volatility spike
         double current_atr = 0.0;
         for(int i = 1; i < m_volatility_measurement_bars; i++)
         {
            current_atr += MathMax(rates[i].high - rates[i].low, 
                                  MathMax(MathAbs(rates[i].high - rates[i-1].close),
                                         MathAbs(rates[i].low - rates[i-1].close)));
         }
         current_atr /= m_volatility_measurement_bars;
         
         if(m_baseline_volatility > 0)
         {
            response.volatility_spike = current_atr / m_baseline_volatility;
         }
         
         // Determine if trending
         double highest_high = rates[0].high;
         double lowest_low = rates[0].low;
         for(int i = 1; i < m_volatility_measurement_bars; i++)
         {
            highest_high = MathMax(highest_high, rates[i].high);
            lowest_low = MathMin(lowest_low, rates[i].low);
         }
         
         double range = highest_high - lowest_low;
         if(range > 0)
         {
            response.is_trending = MathAbs(response.price_change_pct) > (range / price_start * 100.0 * 0.6);
            response.trend_direction = (response.price_change_pct > 0) ? 1 : -1;
         }
      }
      
      // Current spread vs baseline
      double current_spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(m_baseline_spread > 0)
      {
         response.spread_widening = current_spread / m_baseline_spread;
      }
      
      // Volume surge (if available)
      long volume[];
      if(CopyTickVolume(symbol, PERIOD_CURRENT, 0, m_volatility_measurement_bars, volume) == m_volatility_measurement_bars)
      {
         long avg_volume = 0;
         for(int i = 0; i < m_volatility_measurement_bars; i++)
         {
            avg_volume += volume[i];
         }
         avg_volume /= m_volatility_measurement_bars;
         
         if(avg_volume > 0)
         {
            response.volume_surge = (int)((volume[m_volatility_measurement_bars - 1] * 100) / avg_volume);
         }
      }
      
      return response;
   }
   
   //+------------------------------------------------------------------+
   //| Determine current news state                                       |
   //+------------------------------------------------------------------+
   ENUM_NEWS_STATE DetermineNewsState(const SNewsImpact &news, const SMarketResponse &response)
   {
      // Check for active news
      if(news.is_news_time)
      {
         return NEWS_STATE_ACTIVE;
      }
      
      // Check for aftermath (high volatility after recent news)
      if(response.volatility_spike > m_volatility_spike_threshold &&
         (TimeCurrent() - m_state_since) < 1800) // Within 30 min of state change
      {
         return NEWS_STATE_AFTERMATH;
      }
      
      // Check for warning (news approaching within 15 minutes)
      if(news.next_event_time > 0)
      {
         int seconds_to_event = (int)(news.next_event_time - TimeCurrent());
         if(seconds_to_event > 0 && seconds_to_event <= 900) // 15 minutes
         {
            return NEWS_STATE_WARNING;
         }
      }
      
      return NEWS_STATE_QUIET;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate threshold adjustment based on state                        |
   //+------------------------------------------------------------------+
   SThresholdAdjustment CalculateThresholdAdjustment(ENUM_NEWS_STATE state, 
                                                     const SNewsImpact &news,
                                                     const SMarketResponse &response)
   {
      SThresholdAdjustment adj;
      
      switch(state)
      {
         case NEWS_STATE_QUIET:
            // Normal trading conditions
            adj.direction = THRESHOLD_NORMAL;
            adj.confidence_multiplier = 1.0;
            adj.risk_multiplier = 1.0;
            adj.position_size_multiplier = 1.0;
            adj.should_trade = true;
            adj.reason = "Normal market conditions";
            break;
            
         case NEWS_STATE_WARNING:
            // News approaching - be more conservative
            adj.direction = THRESHOLD_CONSERVATIVE;
            adj.confidence_multiplier = 1.2; // 20% harder to meet confidence
            adj.risk_multiplier = 0.8; // 20% less risk
            adj.position_size_multiplier = 0.7; // 30% smaller positions
            adj.sl_pips_adjustment = 5; // Wider SL
            adj.tp_pips_adjustment = 3; // Wider TP
            adj.should_trade = true;
            adj.reason = "News approaching: " + news.next_event_name;
            adj.effective_until = news.next_event_time + 3600; // 1 hour after event
            break;
            
         case NEWS_STATE_ACTIVE:
            // News happening now - most conservative or block
            if(news.current_importance >= EVENT_IMPORTANCE_HIGH)
            {
               adj.direction = THRESHOLD_BLOCK;
               adj.should_trade = false;
               adj.reason = "HIGH IMPACT NEWS ACTIVE: " + news.reason;
            }
            else
            {
               adj.direction = THRESHOLD_CONSERVATIVE;
               adj.confidence_multiplier = 1.5; // 50% harder
               adj.risk_multiplier = 0.5; // 50% less risk
               adj.position_size_multiplier = 0.5; // 50% smaller
               adj.sl_pips_adjustment = 10; // Much wider SL
               adj.tp_pips_adjustment = 5;
               adj.should_trade = true;
               adj.reason = "News active: " + news.reason;
            }
            adj.effective_until = TimeCurrent() + 1800; // 30 minutes
            break;
            
         case NEWS_STATE_AFTERMATH:
            // Post-news volatility - conservative
            adj.direction = THRESHOLD_CONSERVATIVE;
            adj.confidence_multiplier = 1.3;
            adj.risk_multiplier = 0.7;
            adj.position_size_multiplier = 0.6;
            adj.should_trade = true;
            adj.reason = "Post-news volatility detected";
            adj.effective_until = TimeCurrent() + 900; // 15 minutes
            break;
      }
      
      // Additional adjustments based on market response
      if(response.volatility_spike > m_volatility_spike_threshold)
      {
         adj.confidence_multiplier *= 1.2;
         adj.reason += " | High volatility detected";
      }
      
      if(response.spread_widening > m_spread_widening_threshold)
      {
         adj.confidence_multiplier *= 1.1;
         adj.position_size_multiplier *= 0.8;
         adj.reason += " | Spread widening";
      }
      
      return adj;
   }
   
   //+------------------------------------------------------------------+
   //| Record data for ML training                                        |
   //+------------------------------------------------------------------+
   void RecordForTraining(const string symbol, 
                         const SNewsImpact &news,
                         const SMarketResponse &response,
                         const SThresholdAdjustment &adjustment)
   {
      // Build CSV line
      string line = StringFormat("%s,%s,%.4f,%.4f,%.4f,%d,%.2f,%.2f,%d,%.2f,%d,%.2f,%s\n",
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
         symbol,
         news.volatility_prediction,
         response.volatility_spike,
         response.spread_widening,
         response.volume_surge,
         response.price_change_pct,
         (double)response.is_trending,
         adjustment.direction,
         adjustment.confidence_multiplier,
         (adjustment.should_trade ? 1 : 0),
         CalculateProfitabilityScore(news, response),
         news.reason
      );
      
      // Append to training file
      int handle = FileOpen(m_export_filename, 
                           FILE_WRITE|FILE_READ|FILE_CSV|FILE_COMMON,
                           ',');
      
      if(handle != INVALID_HANDLE)
      {
         FileSeek(handle, 0, SEEK_END);
         
         // Write header if new file
         if(FileSize(handle) == 0)
         {
            FileWriteString(handle, 
               "timestamp,symbol,volatility_prediction,volatility_spike,spread_widening," +
               "volume_surge,price_change_pct,is_trending,threshold_direction," +
               "confidence_multiplier,should_trade,profitability_score,news_reason\n");
         }
         
         FileWriteString(handle, line);
         FileClose(handle);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Calculate profitability score for ML (0-1)                          |
   //+------------------------------------------------------------------+
   double CalculateProfitabilityScore(const SNewsImpact &news, const SMarketResponse &response)
   {
      // This is a heuristic - in production, this would be calculated from actual trade results
      double score = 0.5; // Neutral
      
      // Reduce score for high volatility
      if(response.volatility_spike > 2.0)
         score -= 0.2;
      
      // Reduce score for wide spreads
      if(response.spread_widening > 1.5)
         score -= 0.15;
      
      // Increase score if trending clearly
      if(response.is_trending && MathAbs(response.price_change_pct) > 0.1)
         score += 0.15;
      
      // Clamp
      if(score < 0) score = 0;
      if(score > 1) score = 1;
      
      return score;
   }
   
   //+------------------------------------------------------------------+
   //| Get current adjustment (cached)                                    |
   //+------------------------------------------------------------------+
   SThresholdAdjustment GetCurrentAdjustment()
   {
      // Check if expired
      if(m_current_adjustment.effective_until > 0 &&
         TimeCurrent() > m_current_adjustment.effective_until)
      {
         // Reset to normal
         m_current_adjustment = SThresholdAdjustment();
         m_current_state = NEWS_STATE_QUIET;
      }
      
      return m_current_adjustment;
   }
   
   //+------------------------------------------------------------------+
   //| Apply adjustment to a confidence value                             |
   //+------------------------------------------------------------------+
   double ApplyToConfidence(double base_confidence)
   {
      SThresholdAdjustment adj = GetCurrentAdjustment();
      return base_confidence / adj.confidence_multiplier;
   }
   
   //+------------------------------------------------------------------+
   //| Apply adjustment to position size                                  |
   //+------------------------------------------------------------------+
   double ApplyToPositionSize(double base_lots)
   {
      SThresholdAdjustment adj = GetCurrentAdjustment();
      return base_lots * adj.position_size_multiplier;
   }
   
   //+------------------------------------------------------------------+
   //| Check if trading should proceed                                     |
   //+------------------------------------------------------------------+
   bool ShouldTrade()
   {
      SThresholdAdjustment adj = GetCurrentAdjustment();
      return adj.should_trade;
   }
   
   //+------------------------------------------------------------------+
   //| Statistics and reporting                                           |
   //+------------------------------------------------------------------+
   string GetStatistics()
   {
      string stats = StringFormat(
         "=== News Impact Analyzer Statistics ===\n" +
         "Analyses performed: %d\n" +
         "Trades blocked: %d (%.1f%%)\n" +
         "Thresholds adjusted: %d (%.1f%%)\n" +
         "Current state: %s\n" +
         "Training records: %d\n" +
         "Baseline volatility: %.5f\n" +
         "Baseline spread: %.5f",
         m_analysis_count,
         m_trade_blocked_count,
         (m_analysis_count > 0 ? 100.0 * m_trade_blocked_count / m_analysis_count : 0),
         m_threshold_adjusted_count,
         (m_analysis_count > 0 ? 100.0 * m_threshold_adjusted_count / m_analysis_count : 0),
         StateToString(m_current_state),
         m_history_count,
         m_baseline_volatility,
         m_baseline_spread
      );
      
      return stats;
   }
   
   //+------------------------------------------------------------------+
   //| Utility functions                                                    |
   //+------------------------------------------------------------------+
   string StateToString(ENUM_NEWS_STATE state)
   {
      switch(state)
      {
         case NEWS_STATE_QUIET:     return "QUIET";
         case NEWS_STATE_WARNING:   return "WARNING";
         case NEWS_STATE_ACTIVE:    return "ACTIVE";
         case NEWS_STATE_AFTERMATH: return "AFTERMATH";
         default:                   return "UNKNOWN";
      }
   }
   
   void Log(const string message)
   {
      Print("[NewsImpactAnalyzer] " + message);
   }
   
   // Getters
   ENUM_NEWS_STATE GetCurrentState() const { return m_current_state; }
   bool IsActive() const { return m_current_state != NEWS_STATE_QUIET; }
   string GetCurrentReason() const { return m_current_adjustment.reason; }
};

// Static instance initialization
CNewsImpactAnalyzer* CNewsImpactAnalyzer::s_instance = NULL;

// Convenience macros
#define ANALYZE_NEWS(symbol) \
   CNewsImpactAnalyzer::Instance().AnalyzeNewsImpact(symbol)

#define GET_NEWS_ADJUSTMENT() \
   CNewsImpactAnalyzer::Instance().GetCurrentAdjustment()

#define SHOULD_TRADE_NEWS() \
   CNewsImpactAnalyzer::Instance().ShouldTrade()

#define APPLY_NEWS_TO_CONFIDENCE(base_conf) \
   CNewsImpactAnalyzer::Instance().ApplyToConfidence(base_conf)

#define APPLY_NEWS_TO_SIZE(base_lots) \
   CNewsImpactAnalyzer::Instance().ApplyToPositionSize(base_lots)

#endif // CNEWSIMPACTANALYZER_MQH
