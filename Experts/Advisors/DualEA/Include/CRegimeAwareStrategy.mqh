//+------------------------------------------------------------------+
//| CRegimeAwareStrategy.mqh                                         |
//| Regime-aware position sizing and strategy adaptation             |
//| Wraps CAdvancedRegimeDetector for regime-based adjustments       |
//+------------------------------------------------------------------+
#ifndef CREGIMEAWARESTRATEGY_MQH
#define CREGIMEAWARESTRATEGY_MQH

#include "AdvancedRegimeDetector.mqh"
#include "CGateFeatureCache.mqh"

//+------------------------------------------------------------------+
//| Regime-Aware Strategy Class                                      |
//| Provides position sizing adjustments based on market regime      |
//+------------------------------------------------------------------+
class CRegimeAwareStrategy
{
private:
   CAdvancedRegimeDetector* m_detector;
   CGateFeatureCache*       m_feature_cache;
   string                   m_symbol;
   int                      m_timeframe;
   
   // Regime-based multipliers
   double m_risk_multiplier;
   double m_sl_multiplier;
   double m_tp_multiplier;
   
   // Last regime result
   SRegimeResult m_last_regime;
   
public:
   // Constructor
   CRegimeAwareStrategy(CGateFeatureCache* cache = NULL)
   {
      m_feature_cache = cache;
      m_symbol = _Symbol;
      m_timeframe = PERIOD_CURRENT;
      m_detector = new CAdvancedRegimeDetector(m_symbol, m_timeframe);
      
      // Default multipliers
      m_risk_multiplier = 1.0;
      m_sl_multiplier = 1.0;
      m_tp_multiplier = 1.0;
      
      ZeroMemory(m_last_regime);
   }
   
   // Destructor
   ~CRegimeAwareStrategy()
   {
      if(CheckPointer(m_detector) != POINTER_INVALID)
         delete m_detector;
   }
   
   //+------------------------------------------------------------------+
   //| Configuration                                                    |
   //+------------------------------------------------------------------+
   void SetSymbol(const string symbol)
   {
      m_symbol = symbol;
      if(CheckPointer(m_detector) != POINTER_INVALID)
         delete m_detector;
      m_detector = new CAdvancedRegimeDetector(m_symbol, m_timeframe);
   }
   
   void SetTimeframe(const int timeframe)
   {
      m_timeframe = timeframe;
      if(CheckPointer(m_detector) != POINTER_INVALID)
         delete m_detector;
      m_detector = new CAdvancedRegimeDetector(m_symbol, m_timeframe);
   }
   
   void SetFeatureCache(CGateFeatureCache* cache)
   {
      m_feature_cache = cache;
   }
   
   //+------------------------------------------------------------------+
   //| Position Size Adjustment                                         |
   //+------------------------------------------------------------------+
   double AdjustPositionSize(double base_lots)
   {
      if(CheckPointer(m_detector) == POINTER_INVALID)
         return base_lots;
      
      // Get current regime
      SRegimeResult regime = m_detector.DetectCurrentRegime();
      m_last_regime = regime;
      
      // Apply regime-based risk multiplier
      double adjusted_lots = base_lots * GetRiskMultiplier(regime.current_regime);
      
      // Apply confidence weighting
      adjusted_lots *= regime.confidence;
      
      return NormalizeDouble(adjusted_lots, 2);
   }
   
   //+------------------------------------------------------------------+
   //| Stop Loss Adjustment                                             |
   //+------------------------------------------------------------------+
   double AdjustStopLoss(double base_sl, double entry_price, int order_type)
   {
      if(CheckPointer(m_detector) == POINTER_INVALID)
         return base_sl;
      
      SRegimeResult regime = m_detector.DetectCurrentRegime();
      m_last_regime = regime;
      
      double sl_distance = MathAbs(entry_price - base_sl);
      double adjusted_distance = sl_distance * GetSLMultiplier(regime.current_regime);
      
      if(order_type == ORDER_TYPE_BUY)
         return entry_price - adjusted_distance;
      else
         return entry_price + adjusted_distance;
   }
   
   //+------------------------------------------------------------------+
   //| Take Profit Adjustment                                           |
   //+------------------------------------------------------------------+
   double AdjustTakeProfit(double base_tp, double entry_price, int order_type)
   {
      if(CheckPointer(m_detector) == POINTER_INVALID)
         return base_tp;
      
      SRegimeResult regime = m_detector.DetectCurrentRegime();
      m_last_regime = regime;
      
      double tp_distance = MathAbs(entry_price - base_tp);
      double adjusted_distance = tp_distance * GetTPMultiplier(regime.current_regime);
      
      if(order_type == ORDER_TYPE_BUY)
         return entry_price + adjusted_distance;
      else
         return entry_price - adjusted_distance;
   }
   
   //+------------------------------------------------------------------+
   //| Get Current Regime                                               |
   //+------------------------------------------------------------------+
   SRegimeResult GetCurrentRegime()
   {
      if(CheckPointer(m_detector) == POINTER_INVALID)
      {
         ZeroMemory(m_last_regime);
         return m_last_regime;
      }
      
      m_last_regime = m_detector.DetectCurrentRegime();
      return m_last_regime;
   }
   
   string GetRegimeName()
   {
      if(CheckPointer(m_detector) == POINTER_INVALID)
         return "UNKNOWN";
      
      SRegimeResult regime = m_detector.DetectCurrentRegime();
      return m_detector.RegimeToString(regime.current_regime);
   }
   
   //+------------------------------------------------------------------+
   //| Private Helper Methods                                           |
   //+------------------------------------------------------------------+
private:
   double GetRiskMultiplier(ENUM_REGIME_TYPE regime)
   {
      switch(regime)
      {
         case REGIME_TRENDING_UP:
         case REGIME_TRENDING_DOWN:
            return 1.2;  // Increase risk in trending markets
            
         case REGIME_RANGING_LOW:
            return 0.7;  // Conservative in low volatility ranges
            
         case REGIME_RANGING_HIGH:
            return 0.9;  // Moderate in high volatility ranges
            
         case REGIME_VOLATILE_UP:
         case REGIME_VOLATILE_DOWN:
            return 0.6;  // Reduce risk in volatile conditions
            
         case REGIME_BREAKING_UP:
         case REGIME_BREAKING_DOWN:
            return 1.4;  // Aggressive in breakout conditions
            
         case REGIME_CHOPPY:
            return 0.5;  // Minimal risk in choppy markets
            
         default:
            return 1.0;
      }
   }
   
   double GetSLMultiplier(ENUM_REGIME_TYPE regime)
   {
      switch(regime)
      {
         case REGIME_TRENDING_UP:
         case REGIME_TRENDING_DOWN:
            return 1.1;
            
         case REGIME_RANGING_LOW:
            return 0.8;
            
         case REGIME_RANGING_HIGH:
            return 1.0;
            
         case REGIME_VOLATILE_UP:
         case REGIME_VOLATILE_DOWN:
            return 1.2;
            
         case REGIME_BREAKING_UP:
         case REGIME_BREAKING_DOWN:
            return 0.9;
            
         case REGIME_CHOPPY:
            return 0.7;
            
         default:
            return 1.0;
      }
   }
   
   double GetTPMultiplier(ENUM_REGIME_TYPE regime)
   {
      switch(regime)
      {
         case REGIME_TRENDING_UP:
         case REGIME_TRENDING_DOWN:
            return 1.3;
            
         case REGIME_RANGING_LOW:
            return 0.9;
            
         case REGIME_RANGING_HIGH:
            return 1.1;
            
         case REGIME_VOLATILE_UP:
         case REGIME_VOLATILE_DOWN:
            return 1.5;
            
         case REGIME_BREAKING_UP:
         case REGIME_BREAKING_DOWN:
            return 1.6;
            
         case REGIME_CHOPPY:
            return 0.8;
            
         default:
            return 1.0;
      }
   }
};

#endif // CREGIMEAWARESTRATEGY_MQH
