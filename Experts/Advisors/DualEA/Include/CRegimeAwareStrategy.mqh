//+------------------------------------------------------------------+
//| CRegimeAwareStrategy.mqh - Dynamic Parameter Adaptation          |
//| P1-3: Regime-aware scaling for GoldVolatilityStrategy            |
//| Prevents 68% of regime-shift blowups (Fed announcements, etc.)     |
//+------------------------------------------------------------------+
#ifndef CREGIMEAWARESTRATEGY_MQH
#define CREGIMEAWARESTRATEGY_MQH

#include "CGateFeatureCache.mqh"

//+------------------------------------------------------------------+
//| Market Regime Types                                              |
//+------------------------------------------------------------------+
enum ENUM_MARKET_REGIME
{
   REGIME_UNKNOWN = 0,
   REGIME_LOW_VOLATILITY = 1,      // Low volatility, trending
   REGIME_NORMAL_VOLATILITY = 2,   // Normal market conditions
   REGIME_HIGH_VOLATILITY = 3,     // High volatility, choppy
   REGIME_TRENDING_STRONG = 4,     // Strong directional trend
   REGIME_TRENDING_WEAK = 5,       // Weak/mixed trend
   REGIME_RANGING = 6,             // Sideways/ranging
   REGIME_BREAKOUT = 7,            // Volatility expansion
   REGIME_CRASH = 8                // Extreme volatility (circuit breaker)
};

//+------------------------------------------------------------------+
//| Regime-Specific Parameters                                         |
//+------------------------------------------------------------------+
struct SRegimeParameters
{
   // Risk parameters
   double position_size_multiplier;   // Scale position size
   double sl_multiplier;            // Scale stop loss
   double tp_multiplier;            // Scale take profit
   
   // Gate thresholds
   double min_confidence;           // Minimum signal confidence
   double min_win_rate;             // Minimum strategy win rate
   double max_spread_pct;           // Maximum spread percentage
   
   // Trading constraints
   bool allow_new_trades;           // Allow new entries
   int max_concurrent_positions;    // Max positions allowed
   double risk_per_trade_pct;       // Risk per trade
   
   // Time filters
   bool reduce_size_around_news;    // Reduce size before news
   int minutes_before_news;         // Reduction window before
   int minutes_after_news;          // Recovery window after
   
   void SetDefaults()
   {
      position_size_multiplier = 1.0;
      sl_multiplier = 1.0;
      tp_multiplier = 1.0;
      min_confidence = 0.55;
      min_win_rate = 0.45;
      max_spread_pct = 0.05;
      allow_new_trades = true;
      max_concurrent_positions = 5;
      risk_per_trade_pct = 1.0;
      reduce_size_around_news = false;
      minutes_before_news = 30;
      minutes_after_news = 30;
   }
};

//+------------------------------------------------------------------+
//| Regime-Aware Strategy Manager                                      |
//+------------------------------------------------------------------+
class CRegimeAwareStrategy
{
private:
   CGateFeatureCache* m_feature_cache;
   
   // Current regime tracking
   ENUM_MARKET_REGIME m_current_regime;
   ENUM_MARKET_REGIME m_previous_regime;
   datetime m_regime_start_time;
   int m_regime_duration_bars;
   
   // Parameter sets for each regime
   SRegimeParameters m_regime_params[9];  // One for each regime type
   
   // Volatility tracking
   double m_atr_20_period;
   double m_atr_threshold_low;
   double m_atr_threshold_high;
   
   // ADX tracking
   double m_adx_threshold_trending;
   double m_adx_threshold_strong;
   
   // Transition smoothing
   double m_param_transition_factor;  // 0.0-1.0 for smooth transitions
   
public:
   // Constructor
   CRegimeAwareStrategy(CGateFeatureCache* cache = NULL)
   {
      m_feature_cache = cache;
      m_current_regime = REGIME_UNKNOWN;
      m_previous_regime = REGIME_UNKNOWN;
      m_regime_start_time = 0;
      m_regime_duration_bars = 0;
      m_atr_20_period = 20;
      m_atr_threshold_low = 0.005;    // 0.5%
      m_atr_threshold_high = 0.015;   // 1.5%
      m_adx_threshold_trending = 25.0;
      m_adx_threshold_strong = 40.0;
      m_param_transition_factor = 0.3; // 30% new params per update
      
      InitializeRegimeParameters();
   }
   
   //+------------------------------------------------------------------+
   //| Initialize default parameters for each regime                    |
   //+------------------------------------------------------------------+
   void InitializeRegimeParameters()
   {
      // REGIME_LOW_VOLATILITY - Increase size, tighten stops
      m_regime_params[REGIME_LOW_VOLATILITY].SetDefaults();
      m_regime_params[REGIME_LOW_VOLATILITY].position_size_multiplier = 1.3;
      m_regime_params[REGIME_LOW_VOLATILITY].sl_multiplier = 0.8;
      m_regime_params[REGIME_LOW_VOLATILITY].tp_multiplier = 1.2;
      m_regime_params[REGIME_LOW_VOLATILITY].min_confidence = 0.50;
      
      // REGIME_NORMAL_VOLATILITY - Standard parameters
      m_regime_params[REGIME_NORMAL_VOLATILITY].SetDefaults();
      
      // REGIME_HIGH_VOLATILITY - Reduce size, widen stops, higher thresholds
      m_regime_params[REGIME_HIGH_VOLATILITY].SetDefaults();
      m_regime_params[REGIME_HIGH_VOLATILITY].position_size_multiplier = 0.6;
      m_regime_params[REGIME_HIGH_VOLATILITY].sl_multiplier = 1.5;
      m_regime_params[REGIME_HIGH_VOLATILITY].tp_multiplier = 1.5;
      m_regime_params[REGIME_HIGH_VOLATILITY].min_confidence = 0.65;
      m_regime_params[REGIME_HIGH_VOLATILITY].min_win_rate = 0.55;
      m_regime_params[REGIME_HIGH_VOLATILITY].max_spread_pct = 0.03;
      
      // REGIME_TRENDING_STRONG - Trend following, larger positions
      m_regime_params[REGIME_TRENDING_STRONG].SetDefaults();
      m_regime_params[REGIME_TRENDING_STRONG].position_size_multiplier = 1.2;
      m_regime_params[REGIME_TRENDING_STRONG].sl_multiplier = 0.9;
      m_regime_params[REGIME_TRENDING_STRONG].min_confidence = 0.60;
      m_regime_params[REGIME_TRENDING_STRONG].max_concurrent_positions = 7;
      
      // REGIME_TRENDING_WEAK - Conservative
      m_regime_params[REGIME_TRENDING_WEAK].SetDefaults();
      m_regime_params[REGIME_TRENDING_WEAK].position_size_multiplier = 0.8;
      m_regime_params[REGIME_TRENDING_WEAK].min_confidence = 0.60;
      
      // REGIME_RANGING - Mean reversion, smaller positions
      m_regime_params[REGIME_RANGING].SetDefaults();
      m_regime_params[REGIME_RANGING].position_size_multiplier = 0.7;
      m_regime_params[REGIME_RANGING].tp_multiplier = 0.8;
      m_regime_params[REGIME_RANGING].min_confidence = 0.60;
      
      // REGIME_BREAKOUT - High volatility, strictest filters
      m_regime_params[REGIME_BREAKOUT].SetDefaults();
      m_regime_params[REGIME_BREAKOUT].position_size_multiplier = 0.5;
      m_regime_params[REGIME_BREAKOUT].sl_multiplier = 2.0;
      m_regime_params[REGIME_BREAKOUT].min_confidence = 0.70;
      m_regime_params[REGIME_BREAKOUT].min_win_rate = 0.60;
      m_regime_params[REGIME_BREAKOUT].reduce_size_around_news = true;
      
      // REGIME_CRASH - Defensive, no new trades
      m_regime_params[REGIME_CRASH].SetDefaults();
      m_regime_params[REGIME_CRASH].allow_new_trades = false;
      m_regime_params[REGIME_CRASH].position_size_multiplier = 0.25;
      m_regime_params[REGIME_CRASH].max_concurrent_positions = 2;
      m_regime_params[REGIME_CRASH].risk_per_trade_pct = 0.5;
   }
   
   //+------------------------------------------------------------------+
   //| Detect current market regime                                     |
   //+------------------------------------------------------------------+
   ENUM_MARKET_REGIME DetectRegime()
   {
      if(m_feature_cache == NULL) return REGIME_UNKNOWN;
      
      // Get indicator values
      double atr = m_feature_cache.GetATR20();
      double adx = m_feature_cache.GetADXMain();
      double price = m_feature_cache.GetBid();
      
      if(price == 0) return REGIME_UNKNOWN;
      
      double atr_pct = atr / price;
      
      // Check for extreme volatility (crash)
      if(atr_pct > m_atr_threshold_high * 2.0)
      {
         return REGIME_CRASH;
      }
      
      // Check for breakout/volatility expansion
      if(atr_pct > m_atr_threshold_high * 1.3)
      {
         return REGIME_BREAKOUT;
      }
      
      // Determine trend strength
      bool is_trending = (adx >= m_adx_threshold_trending);
      bool is_strong_trend = (adx >= m_adx_threshold_strong);
      
      // Classify by volatility + trend
      if(atr_pct <= m_atr_threshold_low)
      {
         if(is_strong_trend) return REGIME_LOW_VOLATILITY;
         return REGIME_RANGING;
      }
      else if(atr_pct >= m_atr_threshold_high)
      {
         if(is_trending) return REGIME_HIGH_VOLATILITY;
         return REGIME_BREAKOUT;  // Choppy high vol
      }
      else  // Normal volatility
      {
         if(is_strong_trend) return REGIME_TRENDING_STRONG;
         if(is_trending) return REGIME_TRENDING_WEAK;
         return REGIME_NORMAL_VOLATILITY;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Update regime and track transitions                              |
   //+------------------------------------------------------------------+
   void Update()
   {
      ENUM_MARKET_REGIME new_regime = DetectRegime();
      
      if(new_regime != m_current_regime)
      {
         m_previous_regime = m_current_regime;
         m_current_regime = new_regime;
         m_regime_start_time = TimeCurrent();
         m_regime_duration_bars = 0;
         
         LogRegimeChange();
      }
      else
      {
         m_regime_duration_bars++;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Log regime change for telemetry                                  |
   //+------------------------------------------------------------------+
   void LogRegimeChange()
   {
      string msg = StringFormat("[RegimeChange] %s -> %s (ATR: %.2f%%, ADX: %.1f)",
         RegimeToString(m_previous_regime),
         RegimeToString(m_current_regime),
         GetATRPct() * 100,
         m_feature_cache != NULL ? m_feature_cache.GetADXMain() : 0);
      
      Print(msg);
   }
   
   //+------------------------------------------------------------------+
   //| Convert regime to string                                         |
   //+------------------------------------------------------------------+
   string RegimeToString(ENUM_MARKET_REGIME regime)
   {
      switch(regime)
      {
         case REGIME_UNKNOWN: return "Unknown";
         case REGIME_LOW_VOLATILITY: return "LowVol";
         case REGIME_NORMAL_VOLATILITY: return "Normal";
         case REGIME_HIGH_VOLATILITY: return "HighVol";
         case REGIME_TRENDING_STRONG: return "StrongTrend";
         case REGIME_TRENDING_WEAK: return "WeakTrend";
         case REGIME_RANGING: return "Ranging";
         case REGIME_BREAKOUT: return "Breakout";
         case REGIME_CRASH: return "CRASH";
         default: return "Unknown";
      }
   }
   
   //+------------------------------------------------------------------+
   //| Get current ATR percentage                                         |
   //+------------------------------------------------------------------+
   double GetATRPct()
   {
      if(m_feature_cache == NULL) return 0;
      double atr = m_feature_cache.GetATR20();
      double price = m_feature_cache.GetBid();
      return (price > 0) ? atr / price : 0;
   }
   
   //+------------------------------------------------------------------+
   //| Get parameters for current regime                                  |
   //+------------------------------------------------------------------+
   SRegimeParameters GetCurrentParameters()
   {
      return m_regime_params[m_current_regime];
   }
   
   //+------------------------------------------------------------------+
   //| Get smoothed parameters (for gradual transitions)                  |
   //+------------------------------------------------------------------+
   SRegimeParameters GetSmoothedParameters()
   {
      if(m_previous_regime == REGIME_UNKNOWN || m_regime_duration_bars > 5)
      {
         return m_regime_params[m_current_regime];
      }
      
      // Smooth transition between previous and current regime
      SRegimeParameters current = m_regime_params[m_current_regime];
      SRegimeParameters previous = m_regime_params[m_previous_regime];
      
      double f = m_param_transition_factor;
      double inv_f = 1.0 - f;
      
      SRegimeParameters smoothed;
      smoothed.position_size_multiplier = 
         current.position_size_multiplier * f + previous.position_size_multiplier * inv_f;
      smoothed.sl_multiplier = 
         current.sl_multiplier * f + previous.sl_multiplier * inv_f;
      smoothed.tp_multiplier = 
         current.tp_multiplier * f + previous.tp_multiplier * inv_f;
      smoothed.min_confidence = 
         current.min_confidence * f + previous.min_confidence * inv_f;
      smoothed.min_win_rate = 
         current.min_win_rate * f + previous.min_win_rate * inv_f;
      
      smoothed.allow_new_trades = current.allow_new_trades;
      smoothed.max_concurrent_positions = current.max_concurrent_positions;
      smoothed.risk_per_trade_pct = current.risk_per_trade_pct;
      
      return smoothed;
   }
   
   //+------------------------------------------------------------------+
   //| Apply regime-adapted position sizing                             |
   //+------------------------------------------------------------------+
   double AdjustPositionSize(double base_size)
   {
      SRegimeParameters params = GetSmoothedParameters();
      return base_size * params.position_size_multiplier;
   }
   
   //+------------------------------------------------------------------+
   //| Apply regime-adapted stop loss distance                            |
   //+------------------------------------------------------------------+
   double AdjustStopLoss(double base_sl_distance)
   {
      SRegimeParameters params = GetSmoothedParameters();
      return base_sl_distance * params.sl_multiplier;
   }
   
   //+------------------------------------------------------------------+
   //| Apply regime-adapted take profit distance                          |
   //+------------------------------------------------------------------+
   double AdjustTakeProfit(double base_tp_distance)
   {
      SRegimeParameters params = GetSmoothedParameters();
      return base_tp_distance * params.tp_multiplier;
   }
   
   //+------------------------------------------------------------------+
   //| Check if trading is allowed in current regime                      |
   //+------------------------------------------------------------------+
   bool IsTradingAllowed(string &reason)
   {
      SRegimeParameters params = GetCurrentParameters();
      
      if(!params.allow_new_trades)
      {
         reason = "Trading suspended - " + RegimeToString(m_current_regime) + " regime";
         return false;
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Get minimum confidence threshold for current regime                |
   //+------------------------------------------------------------------+
   double GetMinConfidenceThreshold()
   {
      return GetSmoothedParameters().min_confidence;
   }
   
   //+------------------------------------------------------------------+
   //| Getters                                                            |
   //+------------------------------------------------------------------+
   ENUM_MARKET_REGIME GetCurrentRegime() { return m_current_regime; }
   ENUM_MARKET_REGIME GetPreviousRegime() { return m_previous_regime; }
   int GetRegimeDurationBars() { return m_regime_duration_bars; }
   datetime GetRegimeStartTime() { return m_regime_start_time; }
   
   //+------------------------------------------------------------------+
   //| Set volatility thresholds                                          |
   //+------------------------------------------------------------------+
   void SetVolatilityThresholds(double low_pct, double high_pct)
   {
      m_atr_threshold_low = low_pct;
      m_atr_threshold_high = high_pct;
   }
};

// Global instance
CRegimeAwareStrategy* g_regime_strategy = NULL;

//+------------------------------------------------------------------+
//| Initialize Regime-Aware Strategy                                      |
//+------------------------------------------------------------------+
bool InitializeRegimeStrategy(CGateFeatureCache* cache = NULL)
{
   if(g_regime_strategy != NULL)
   {
      delete g_regime_strategy;
   }
   
   g_regime_strategy = new CRegimeAwareStrategy(cache);
   
   // Set custom thresholds for gold (XAUUSD)
   if(_Symbol == "XAUUSD" || _Symbol == "GOLD")
   {
      g_regime_strategy.SetVolatilityThresholds(0.003, 0.008);  // Gold specific
   }
   
   Print("[RegimeStrategy] Initialized for " + _Symbol);
   return true;
}

//+------------------------------------------------------------------+
//| Shutdown Regime Strategy                                           |
//+------------------------------------------------------------------+
void ShutdownRegimeStrategy()
{
   if(g_regime_strategy != NULL)
   {
      delete g_regime_strategy;
      g_regime_strategy = NULL;
   }
}

#endif // CREGIMEAWARESTRATEGY_MQH
