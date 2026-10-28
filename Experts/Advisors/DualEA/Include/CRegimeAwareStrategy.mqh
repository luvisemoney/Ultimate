#ifndef DUALEA_REGIME_AWARE_STRATEGY_MQH
#define DUALEA_REGIME_AWARE_STRATEGY_MQH
#include "CGateFeatureCache.mqh"
#include "AdvancedRegimeDetector.mqh"

// Adapt the existing regime detector to the master controller interface.
class CRegimeAwareStrategy
{
private:
   CAdvancedRegimeDetector m_detector;
   SRegimeResult m_result;
   datetime m_last_bar;
public:
   CRegimeAwareStrategy(CGateFeatureCache *cache=NULL) : m_detector(_Symbol, _Period), m_last_bar(0) {}
   void Update()
   {
      datetime bar = iTime(_Symbol, _Period, 0);
      if(bar <= 0 || bar == m_last_bar) return;
      m_result = m_detector.DetectCurrentRegime();
      if(m_result.current_regime!=REGIME_UNDEFINED) m_last_bar = bar;
   }
   ENUM_REGIME_TYPE GetCurrentRegime() { return m_result.current_regime; }
   string RegimeToString(ENUM_REGIME_TYPE regime) { return m_detector.RegimeToString(regime); }
   bool IsTradingAllowed(string &reason)
   {
      reason = "";
      if(m_result.current_regime == REGIME_UNDEFINED)
      {
         reason = "Market regime is not available";
         return false;
      }
      return true;
   }
   double GetMinConfidenceThreshold()
   {
      return m_result.current_regime == REGIME_CHOPPY ? 0.75 : 0.60;
   }
   double AdjustPositionSize(double volume)
   {
      switch(m_result.current_regime)
      {
         case REGIME_UNDEFINED: return 0.0;
         case REGIME_CHOPPY: return volume * 0.5;
         case REGIME_VOLATILE_UP:
         case REGIME_VOLATILE_DOWN:
         case REGIME_RANGING_HIGH: return volume * 0.75;
      }
      return volume;
   }
};
CRegimeAwareStrategy *g_regime_strategy = NULL;
#endif
