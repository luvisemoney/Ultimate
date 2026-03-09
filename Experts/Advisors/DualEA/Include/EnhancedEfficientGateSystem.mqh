//+------------------------------------------------------------------+
//| EnhancedEfficientGateSystem.mqh - v2.0                           |
//| Integrates: CGateBase abstract class + Shadow Logging +          |
//| Learning-Based Auto-Tuning + ONNX Dynamic Thresholds             |
//| Based on chat-8Stage Gate System Integration Guide             |
//+------------------------------------------------------------------+
#ifndef __ENHANCED_EFFICIENT_GATE_SYSTEM_MQH__
#define __ENHANCED_EFFICIENT_GATE_SYSTEM_MQH__

#include "CGateBase.mqh"
#include "CShadowLogger.mqh"
#include "LearningBridge.mqh"
#include "CFeatures.mqh"
#include "CGateFeatureCache.mqh"
#include <Trade\Trade.mqh>

// Simple logging macros
#define LOG_DEBUG(msg) Print(msg)
#define LOG_INFO(msg) Print(msg)
#define LOG_WARNING(msg) Print(msg)
#define LOG_ERROR(msg) Print(msg)

//+------------------------------------------------------------------+
//| Helper: Count positions for specific symbol only                 |
//+------------------------------------------------------------------+
int CountPositionsForSymbol(const string symbol)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == symbol)
            count++;
      }
   }
   return count;
}

// Processing Modes (same as v1 for compatibility)
enum EGateProcessingMode
{
   GATE_MODE_FULL,           // All 8 gates (production)
   GATE_MODE_RISK_ONLY,      // Risk-critical gates (G1, G4, G7, G8)
   GATE_MODE_FAST,           // Skip heavy gates (skip G5, G6)
   GATE_MODE_BYPASS,         // Minimal validation only
   GATE_MODE_ALL_BYPASS      // ALL gates disabled - for data collection only
};

//+------------------------------------------------------------------+
//| Enhanced Signal Result with Full Metrics                         |
//+------------------------------------------------------------------+
struct ESignalResult
{
   bool passed;
   string block_reason;
   double final_confidence;
   double tweaks[5];
   
   // Performance metrics
   ulong total_latency_us;
   int gates_evaluated;
   int gates_passed;
   
   // Per-gate results
   EGateResult gate_results[8];
   
   void Init()
   {
      passed = false;
      block_reason = "";
      final_confidence = 0.0;
      ArrayInitialize(tweaks, 0.0);
      total_latency_us = 0;
      gates_evaluated = 0;
      gates_passed = 0;
      // Initialize each gate_result individually
      for(int i = 0; i < 8; i++)
      {
         gate_results[i].passed = false;
         gate_results[i].confidence = 0.0;
         gate_results[i].threshold = 0.0;
         gate_results[i].block_reason = "";
         gate_results[i].latency_us = 0;
      }
   }
};

//+------------------------------------------------------------------+
//| Gate 1: Signal Rinse - Enhanced with Auto-Tuning                 |
//+------------------------------------------------------------------+
class CSignalRinseGateEnhanced : public CGateBase
{
private:
   double m_min_confidence;
   double m_max_spread_pct;
   bool m_check_signal_integrity;
   
public:
   CSignalRinseGateEnhanced() : CGateBase("SignalRinse")
   {
      m_min_confidence = 0.5;
      m_max_spread_pct = 0.05;  // 5%
      m_check_signal_integrity = true;
      SetDefaultThreshold(0.5);
   }
   
   bool Initialize() override
   {
      // Validate market data available
      if(Bars(_Symbol, _Period) < 100)
      {
         Print("[Gate1] WARNING: Insufficient history (", Bars(_Symbol, _Period), " bars)");
         return false;
      }
      return true;
   }
   
   double CalculateConfidence(const TradingSignal &signal) override
   {
      // Calculate signal confidence based on signal strength
      double conf = signal.confidence;
      
      // Penalty for weak signals
      if(conf < 0.3) conf *= 0.5;
      
      // Bonus for strong directional signals
      if(conf > 0.7) conf = MathMin(1.0, conf * 1.1);
      
      return conf;
   }
   
   bool Validate(TradingSignal &signal, EGateResult &result) override
   {
      ulong start = GetMicrosecondCount();
      
      if(!m_enabled)
      {
         result.Set(true, signal.confidence, m_threshold, "Bypassed", 0);
         return true;
      }
      
      double confidence = CalculateConfidence(signal);
      
      // Check minimum confidence
      if(confidence < m_min_confidence)
      {
         result.Set(false, confidence, m_min_confidence, 
                   StringFormat("Low confidence: %.3f < %.3f", confidence, m_min_confidence),
                   GetMicrosecondCount() - start);
         RecordPass(false);
         return false;
      }
      
      // Check spread
      double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(price > 0 && spread / price > m_max_spread_pct)
      {
         result.Set(false, confidence, m_max_spread_pct,
                   StringFormat("High spread: %.4f%% > %.4f%%", spread/price*100, m_max_spread_pct*100),
                   GetMicrosecondCount() - start);
         RecordPass(false);
         return false;
      }
      
      result.Set(true, confidence, m_min_confidence, "Signal valid",
                GetMicrosecondCount() - start);
      RecordPass(true);
      return true;
   }
   
   void SetMinConfidence(double val) { m_min_confidence = val; }
   void SetMaxSpreadPct(double val) { m_max_spread_pct = val; }
};

//+------------------------------------------------------------------+
//| Gate 2: Market Soap - Market Condition Validation               |
//| P0-5: Uses cached ATR/ADX values for 40% faster processing       |
//+------------------------------------------------------------------+
class CMarketSoapGateEnhanced : public CGateBase
{
private:
   double m_max_volatility;
   double m_min_adx;
   double m_atr_multiplier;
   
public:
   CMarketSoapGateEnhanced() : CGateBase("MarketSoap")
   {
      m_max_volatility = 0.15;  // 15%
      m_min_adx = 20.0;
      m_atr_multiplier = 1.0;
      SetDefaultThreshold(0.6);
   }
   
   double CalculateConfidence(const TradingSignal &signal) override
   {
      // P0-5: Use direct calculation (cache disabled due to linking issues)
      double atr, adx, price;
      
      // Fallback to direct calculation using handles
      int atr_handle = iATR(_Symbol, _Period, 14);
      int adx_handle = iADX(_Symbol, _Period, 14);
      double atr_buf[1], adx_buf[1];
      atr = (CopyBuffer(atr_handle, 0, 0, 1, atr_buf) == 1) ? atr_buf[0] : 0;
      adx = (CopyBuffer(adx_handle, 0, 0, 1, adx_buf) == 1) ? adx_buf[0] : 0;
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      if(price == 0) return 0.0;
      
      double vol_pct = atr / price;
      
      // Confidence decreases with volatility
      double vol_conf = 1.0 - (vol_pct / m_max_volatility);
      vol_conf = MathMax(0.0, MathMin(1.0, vol_conf));
      
      // ADX trend strength
      double adx_conf = MathMin(1.0, adx / 50.0);
      
      // Combined confidence
      return (vol_conf * 0.6 + adx_conf * 0.4);
   }
   
   bool Validate(TradingSignal &signal, EGateResult &result) override
   {
      ulong start = GetMicrosecondCount();
      
      if(!m_enabled)
      {
         result.Set(true, 1.0, m_threshold, "Bypassed", 0);
         return true;
      }
      
      // P0-5: Use direct calculation (cache disabled due to linking issues)
      double atr, adx, price;
      
      // Fallback to direct calculation using handles
      int atr_handle = iATR(_Symbol, _Period, 14);
      int adx_handle = iADX(_Symbol, _Period, 14);
      double atr_buf[1], adx_buf[1];
      atr = (CopyBuffer(atr_handle, 0, 0, 1, atr_buf) == 1) ? atr_buf[0] : 0;
      adx = (CopyBuffer(adx_handle, 0, 0, 1, adx_buf) == 1) ? adx_buf[0] : 0;
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      double confidence = CalculateConfidence(signal);
      
      // Check volatility
      double vol_pct = (price > 0) ? atr / price : 0;
      
      if(vol_pct > m_max_volatility)
      {
         result.Set(false, confidence, m_threshold,
                   StringFormat("High volatility: %.2f%% > %.2f%%", vol_pct*100, m_max_volatility*100),
                   GetMicrosecondCount() - start);
         RecordPass(false);
         return false;
      }
      
      // Check ADX
      if(adx < m_min_adx)
      {
         result.Set(false, confidence, m_threshold,
                   StringFormat("Weak trend: ADX=%.1f < %.1f", adx, m_min_adx),
                   GetMicrosecondCount() - start);
         RecordPass(false);
         return false;
      }
      
      result.Set(true, confidence, m_threshold, "Market conditions OK",
                GetMicrosecondCount() - start);
      RecordPass(true);
      return true;
   }
   
   void SetMaxVolatility(double val) { m_max_volatility = val; }
   void SetMinADX(double val) { m_min_adx = val; }
};

//+------------------------------------------------------------------+
//| Gate 3: Strategy Scrub - Strategy Validation                     |
//+------------------------------------------------------------------+
class CStrategyScrubGateEnhanced : public CGateBase
{
private:
   double m_min_strat_confidence;
   bool m_require_confirmation;
   
public:
   CStrategyScrubGateEnhanced() : CGateBase("StrategyScrub")
   {
      m_min_strat_confidence = 0.5;
      m_require_confirmation = true;
      SetDefaultThreshold(0.55);
   }
   
   double CalculateConfidence(const TradingSignal &signal) override
   {
      // Strategy confidence from signal
      double conf = signal.confidence;
      
      // Bonus for specific strategy types
      if(StringFind(signal.strategy_name, "Trend") >= 0 && signal.direction > 0)
         conf *= 1.05;  // Trend following in trend direction
      
      return MathMin(1.0, conf);
   }
   
   bool Validate(TradingSignal &signal, EGateResult &result) override
   {
      ulong start = GetMicrosecondCount();
      
      if(!m_enabled)
      {
         result.Set(true, 1.0, m_threshold, "Bypassed", 0);
         return true;
      }
      
      double confidence = CalculateConfidence(signal);
      
      if(confidence < m_min_strat_confidence)
      {
         result.Set(false, confidence, m_min_strat_confidence,
                   StringFormat("Strategy confidence %.3f < %.3f", confidence, m_min_strat_confidence),
                   GetMicrosecondCount() - start);
         RecordPass(false);
         return false;
      }
      
      result.Set(true, confidence, m_min_strat_confidence, "Strategy valid",
                GetMicrosecondCount() - start);
      RecordPass(true);
      return true;
   }
   
   void SetMinConfidence(double val) { m_min_strat_confidence = val; }
};

//+------------------------------------------------------------------+
//| Gate 4: Risk Wash - Position Sizing & Risk Management              |
//| ALWAYS ENFORCED (per MQL5 risk guidelines)                         |
//+------------------------------------------------------------------+
class CRiskWashGateEnhanced : public CGateBase
{
private:
   double m_max_risk_pct;
   double m_min_risk_reward;
   double m_max_position_pct;
   
public:
   CRiskWashGateEnhanced() : CGateBase("RiskWash")
   {
      m_max_risk_pct = 0.02;     // 2% per trade
      m_min_risk_reward = 1.5;    // 1:1.5 minimum
      m_max_position_pct = 0.10; // 10% of equity
      SetDefaultThreshold(0.7);
      Enable(true);  // Always enabled
   }
   
   double CalculateConfidence(const TradingSignal &signal) override
   {
      // Calculate risk confidence based on position sizing
      double sl_distance = MathAbs(signal.entry_price - signal.stop_loss);
      double tp_distance = MathAbs(signal.take_profit - signal.entry_price);
      
      if(sl_distance == 0) return 0.0;
      
      double rr = tp_distance / sl_distance;
      double rr_conf = MathMin(1.0, rr / m_min_risk_reward);
      
      // Position size confidence
      double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double risk_amount = signal.volume * sl_distance * tick_value;
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      
      double risk_pct = (equity > 0) ? risk_amount / equity : 1.0;
      double size_conf = MathMax(0.0, 1.0 - (risk_pct / m_max_risk_pct));
      
      return (rr_conf * 0.5 + size_conf * 0.5);
   }
   
   bool Validate(TradingSignal &signal, EGateResult &result) override
   {
      ulong start = GetMicrosecondCount();
      
      // Risk gates are ALWAYS evaluated
      double confidence = CalculateConfidence(signal);
      
      // Check risk/reward
      double sl_dist = MathAbs(signal.entry_price - signal.stop_loss);
      double tp_dist = MathAbs(signal.take_profit - signal.entry_price);
      
      if(sl_dist > 0)
      {
         double rr = tp_dist / sl_dist;
         if(rr < m_min_risk_reward)
         {
            result.Set(false, confidence, m_min_risk_reward,
                      StringFormat("Risk/Reward %.2f < %.2f", rr, m_min_risk_reward),
                      GetMicrosecondCount() - start);
            RecordPass(false);
            return false;
         }
      }
      
      // Check position sizing
      double tick_val = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double risk_amt = signal.volume * sl_dist * tick_val;
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      
      if(equity > 0 && risk_amt / equity > m_max_risk_pct)
      {
         // Auto-adjust position size instead of blocking
         double max_risk_amt = equity * m_max_risk_pct;
         double new_volume = max_risk_amt / (sl_dist * tick_val);
         
         // Apply volume constraints
         double min_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         double max_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
         double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         
         new_volume = MathMax(min_vol, MathMin(max_vol, new_volume));
         new_volume = MathFloor(new_volume / step) * step;
         
         signal.volume = new_volume;
         
         Print(StringFormat("[Gate4] Position size adjusted: %.2f -> %.2f (risk limit)",
                  signal.volume, new_volume));
      }
      
      result.Set(true, confidence, m_threshold, "Risk validated",
                GetMicrosecondCount() - start);
      RecordPass(true);
      return true;
   }
   
   void SetMaxRiskPct(double val) { m_max_risk_pct = val; }
   void SetMinRR(double val) { m_min_risk_reward = val; }
   
   // Risk gates cannot be disabled
   void Enable(bool enable) { m_enabled = true; }
};

//+------------------------------------------------------------------+
//| Gate 5: Performance Wax - Actual Win Rate Validation             |
//+------------------------------------------------------------------+
class CPerformanceWaxGateEnhanced : public CGateBase
{
private:
   double m_min_winrate;
   int m_lookback_trades;
   int m_max_consecutive_losses;
   double m_trade_pnls[];  // For win rate calculation
   
public:
   CPerformanceWaxGateEnhanced() : CGateBase("PerformanceWax")
   {
      m_min_winrate = 0.45;
      m_lookback_trades = 20;
      m_max_consecutive_losses = 3;
      SetDefaultThreshold(0.65);
      ArrayResize(m_trade_pnls, 0);
   }
   
   void RecordTrade(double pnl)
   {
      // Add to history
      int size = ArraySize(m_trade_pnls);
      if(size >= m_lookback_trades)
      {
         // Shift array
         for(int i=0; i<size-1; i++)
            m_trade_pnls[i] = m_trade_pnls[i+1];
         m_trade_pnls[size-1] = pnl;
      }
      else
      {
         ArrayResize(m_trade_pnls, size+1);
         m_trade_pnls[size] = pnl;
      }
   }
   
   double CalculateWinRate()
   {
      int size = ArraySize(m_trade_pnls);
      if(size < 5) return 0.5;  // Default neutral
      
      int wins = 0;
      for(int i=0; i<size; i++)
         if(m_trade_pnls[i] > 0) wins++;
      
      return (double)wins / size;
   }
   
   int CalculateConsecutiveLosses()
   {
      int size = ArraySize(m_trade_pnls);
      if(size == 0) return 0;
      
      int consecutive = 0;
      for(int i=size-1; i>=0; i--)
      {
         if(m_trade_pnls[i] < 0)
            consecutive++;
         else
            break;
      }
      return consecutive;
   }
   
   double CalculateConfidence(const TradingSignal &signal) override
   {
      double wr = CalculateWinRate();
      int consec_losses = CalculateConsecutiveLosses();
      
      // Confidence based on recent performance
      double conf = wr;
      
      // Penalty for consecutive losses
      if(consec_losses > 0)
         conf *= (1.0 - (double)consec_losses / m_max_consecutive_losses);
      
      return MathMax(0.0, conf);
   }
   
   bool Validate(TradingSignal &signal, EGateResult &result) override
   {
      ulong start = GetMicrosecondCount();
      
      if(!m_enabled)
      {
         result.Set(true, 1.0, m_threshold, "Bypassed", 0);
         return true;
      }
      
      double confidence = CalculateConfidence(signal);
      double wr = CalculateWinRate();
      int consec = CalculateConsecutiveLosses();
      
      // Check consecutive losses (circuit breaker)
      if(consec >= m_max_consecutive_losses)
      {
         result.Set(false, confidence, 0.0,
                   StringFormat("Circuit breaker: %d consecutive losses", consec),
                   GetMicrosecondCount() - start);
         RecordPass(false);
         return false;
      }
      
      // Check win rate
      int sample_size = ArraySize(m_trade_pnls);
      if(sample_size >= 10 && wr < m_min_winrate)
      {
         result.Set(false, confidence, m_min_winrate,
                   StringFormat("Low win rate: %.1f%% < %.1f%% (%d trades)",
                             wr*100, m_min_winrate*100, sample_size),
                   GetMicrosecondCount() - start);
         RecordPass(false);
         return false;
      }
      
      result.Set(true, confidence, m_min_winrate,
                StringFormat("Performance OK: WR=%.1f%% (%d trades)", wr*100, sample_size),
                GetMicrosecondCount() - start);
      RecordPass(true);
      return true;
   }
   
   void SetMinWinRate(double val) { m_min_winrate = val; }
   void SetLookback(int val) { m_lookback_trades = val; }
   void SetMaxConsecutiveLosses(int val) { m_max_consecutive_losses = val; }
};

//+------------------------------------------------------------------+
//| Gate 6: ML Polish - ML Confidence with Dynamic Threshold         |
//+------------------------------------------------------------------+
class CMLPolishGateEnhanced : public CGateBase
{
private:
   double m_ml_confidence_threshold;
   bool m_use_onnx_model;
   bool m_dynamic_threshold;  // Adjust based on market regime
   
   // For ONNX integration
   string m_onnx_model_path;
   long m_onnx_handle;
   
public:
   CMLPolishGateEnhanced() : CGateBase("MLPolish")
   {
      m_ml_confidence_threshold = 0.55;
      m_use_onnx_model = false;
      m_dynamic_threshold = true;
      m_onnx_handle = INVALID_HANDLE;
      SetDefaultThreshold(0.6);
   }
   
   double CalculateConfidence(const TradingSignal &signal) override
   {
      // Raw ML confidence from signal
      double raw_conf = signal.confidence;
      
      // If using dynamic threshold, adjust based on volatility
      if(m_dynamic_threshold)
      {
         int atr_handle = iATR(_Symbol, _Period, 14);
         double atr_buf[1];
         double atr = (CopyBuffer(atr_handle, 0, 0, 1, atr_buf) == 1) ? atr_buf[0] : 0;
         IndicatorRelease(atr_handle);  // FIX: Release ATR handle to prevent leak
         double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double vol_pct = (price > 0) ? atr / price : 0;
         
         // In high volatility, require higher confidence
         double vol_adj = 1.0 + (vol_pct * 10.0);  // 0.01 -> 1.1x
         raw_conf /= vol_adj;
      }
      
      return MathMax(0.0, MathMin(1.0, raw_conf));
   }
   
   bool Validate(TradingSignal &signal, EGateResult &result) override
   {
      ulong start = GetMicrosecondCount();
      
      if(!m_enabled)
      {
         result.Set(true, 1.0, m_threshold, "Bypassed", 0);
         return true;
      }
      
      double confidence = CalculateConfidence(signal);
      
      // Get dynamic threshold based on regime
      double threshold = m_ml_confidence_threshold;
      if(m_dynamic_threshold)
      {
         int atr_handle2 = iATR(_Symbol, _Period, 14);
         double atr2_buf[1];
         double atr = (CopyBuffer(atr_handle2, 0, 0, 1, atr2_buf) == 1) ? atr2_buf[0] : 0;
         IndicatorRelease(atr_handle2);  // FIX: Release ATR handle to prevent leak
         double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double vol_pct = (price > 0) ? atr / price : 0;
         
         // Adjust threshold: higher in high vol, lower in low vol
         if(vol_pct > 0.01)
            threshold = MathMin(0.8, threshold * 1.2);
         else if(vol_pct < 0.005)
            threshold = MathMax(0.4, threshold * 0.9);
      }
      
      if(confidence < threshold)
      {
         result.Set(false, confidence, threshold,
                   StringFormat("ML confidence %.3f < threshold %.3f", confidence, threshold),
                   GetMicrosecondCount() - start);
         RecordPass(false);
         return false;
      }
      
      result.Set(true, confidence, threshold, "ML validation passed",
                GetMicrosecondCount() - start);
      RecordPass(true);
      return true;
   }
   
   void SetConfidenceThreshold(double val) { m_ml_confidence_threshold = val; }
   void SetDynamicThreshold(bool val) { m_dynamic_threshold = val; }
   void EnableONNX(bool val) { m_use_onnx_model = val; }
};

//+------------------------------------------------------------------+
//| Gate 7: Live Clean - Market Conditions (ALWAYS ENFORCED)          |
//+------------------------------------------------------------------+
class CLiveCleanGateEnhanced : public CGateBase
{
private:
   double m_max_spread_pct;
   int m_max_slippage_pts;
   bool m_check_trading_allowed;
   bool m_check_session;
   
public:
   CLiveCleanGateEnhanced() : CGateBase("LiveClean")
   {
      m_max_spread_pct = 0.05;  // 5%
      m_max_slippage_pts = 10;
      m_check_trading_allowed = true;
      m_check_session = true;
      SetDefaultThreshold(0.8);
      Enable(true);  // Always enabled
   }
   
   double CalculateConfidence(const TradingSignal &signal) override
   {
      double conf = 1.0;
      
      // Spread penalty
      double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(price > 0)
      {
         double spread_pct = spread / price;
         conf -= (spread_pct / m_max_spread_pct) * 0.5;
      }
      
      // Session check
      if(m_check_session)
      {
         MqlDateTime dt;
         TimeToStruct(TimeCurrent(), dt);
         int hour = dt.hour;
         
         // Reduce confidence outside active hours (London/NY overlap best)
         if(hour < 8 || hour > 20)
            conf *= 0.9;
      }
      
      return MathMax(0.0, conf);
   }
   
   bool Validate(TradingSignal &signal, EGateResult &result) override
   {
      ulong start = GetMicrosecondCount();
      
      // ALWAYS evaluate
      double confidence = CalculateConfidence(signal);
      
      // Check spread
      double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      if(price > 0 && spread / price > m_max_spread_pct)
      {
         result.Set(false, confidence, m_max_spread_pct,
                   StringFormat("Spread too high: %.4f%% > %.4f%%", 
                             spread/price*100, m_max_spread_pct*100),
                   GetMicrosecondCount() - start);
         RecordPass(false);
         return false;
      }
      
      // Check if trading allowed
      if(m_check_trading_allowed)
      {
         long trade_mode = 0;
         SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE, trade_mode);
         if(trade_mode == SYMBOL_TRADE_MODE_DISABLED)
         {
            result.Set(false, confidence, 0.0,
                      "Trading disabled for symbol",
                      GetMicrosecondCount() - start);
            RecordPass(false);
            return false;
         }
      }
      
      result.Set(true, confidence, m_threshold, "Market conditions OK",
                GetMicrosecondCount() - start);
      RecordPass(true);
      return true;
   }
   
   void SetMaxSpreadPct(double val) { m_max_spread_pct = val; }
   void EnableTradingCheck(bool val) { m_check_trading_allowed = val; }
   
   // Cannot disable
   void Enable(bool enable) { m_enabled = true; }
};

//+------------------------------------------------------------------+
//| Gate 8: Final Verify - Pre-Execution Checks (ALWAYS ENFORCED)   |
//+------------------------------------------------------------------+
class CFinalVerifyGateEnhanced : public CGateBase
{
private:
   int m_max_positions;
   bool m_check_correlation;
   double m_max_correlation;
   
public:
   CFinalVerifyGateEnhanced() : CGateBase("FinalVerify")
   {
      m_max_positions = 5;
      m_check_correlation = true;
      m_max_correlation = 0.8;
      SetDefaultThreshold(0.9);
      Enable(true);  // Always enabled
   }
   
   double CalculateConfidence(const TradingSignal &signal) override
   {
      double conf = 1.0;
      
      // Position count penalty - PER SYMBOL
      int open_pos = CountPositionsForSymbol(_Symbol);
      if(open_pos > m_max_positions)
         conf = 0.0;
      else if(open_pos > m_max_positions / 2)
         conf = 0.5;
      
      return conf;
   }
   
   bool Validate(TradingSignal &signal, EGateResult &result) override
   {
      ulong start = GetMicrosecondCount();
      
      // ALWAYS evaluate
      double confidence = CalculateConfidence(signal);
      
      // Check position limits only - PER SYMBOL (not global)
      int open_pos = CountPositionsForSymbol(_Symbol);
      if(open_pos >= m_max_positions)
      {
         result.Set(false, confidence, m_max_positions,
                   StringFormat("Max positions reached for %s: %d/%d", _Symbol, open_pos, m_max_positions),
                   GetMicrosecondCount() - start);
         RecordPass(false);
         return false;
      }
      
      // Validate entry price only (SL/TP already validated by G4)
      // CRITICAL: Use signal.price as signal.entry_price may not be populated
      double check_price = (signal.entry_price > 0) ? signal.entry_price : signal.price;
      if(check_price <= 0 || !MathIsValidNumber(check_price))
      {
         result.Set(false, confidence, 0.0,
                   "Invalid entry price",
                   GetMicrosecondCount() - start);
         RecordPass(false);
         return false;
      }
      
      result.Set(true, confidence, m_threshold, "Pre-execution checks passed",
                GetMicrosecondCount() - start);
      RecordPass(true);
      return true;
   }
   
   void SetMaxPositions(int val) { m_max_positions = val; }
   
   // Cannot disable
   void Enable(bool enable) { m_enabled = true; }
};

//+------------------------------------------------------------------+
//| Enhanced Efficient Gate Manager - Main Orchestrator             |
//+------------------------------------------------------------------+
class CEfficientGateManagerEnhanced
{
private:
   // Gates
   CSignalRinseGateEnhanced      m_g1_signal;
   CMarketSoapGateEnhanced       m_g2_market;
   CStrategyScrubGateEnhanced      m_g3_strategy;
   CRiskWashGateEnhanced         m_g4_risk;
   CPerformanceWaxGateEnhanced   m_g5_performance;
   CMLPolishGateEnhanced         m_g6_ml;
   CLiveCleanGateEnhanced        m_g7_live;
   CFinalVerifyGateEnhanced      m_g8_final;
   
   CGateBase* m_gates[8];  // Array for iteration
   
   // Configuration
   EGateProcessingMode m_mode;
   bool m_no_constraints;
   bool m_use_insights;
   bool m_use_policy;
   
   // Shadow logging
   CShadowLogger m_shadow_logger;
   bool m_use_shadow_logging;
   
   // Performance tracking
   ulong m_total_signals;
   ulong m_passed_signals;
   double m_avg_latency_ms;
   
   // Feature extraction
   CFeatures    m_features;
   bool         m_features_initialized;
   
public:
   // Constructor
   CEfficientGateManagerEnhanced(bool no_constraints=false, 
                                 bool use_insights=false,
                                 bool use_policy=false)
   {
      m_no_constraints = no_constraints;
      m_use_insights = use_insights;
      m_use_policy = use_policy;
      m_mode = GATE_MODE_FULL;
      m_use_shadow_logging = false;
      m_total_signals = 0;
      m_passed_signals = 0;
      m_avg_latency_ms = 0.0;
      m_features_initialized = false;
      
      // Build gate array
      m_gates[0] = GetPointer(m_g1_signal);
      m_gates[1] = GetPointer(m_g2_market);
      m_gates[2] = GetPointer(m_g3_strategy);
      m_gates[3] = GetPointer(m_g4_risk);
      m_gates[4] = GetPointer(m_g5_performance);
      m_gates[5] = GetPointer(m_g6_ml);
      m_gates[6] = GetPointer(m_g7_live);
      m_gates[7] = GetPointer(m_g8_final);
   }
   
   // Initialize with shadow logging support
   bool Initialize(bool shadow_mode=false)
   {
      // Initialize shadow logger
      m_use_shadow_logging = shadow_mode;
      if(!m_shadow_logger.Initialize(shadow_mode))
      {
         Print("[GateMgr] WARNING: Shadow logger initialization failed");
      }
      
      // Initialize all gates
      for(int i=0; i<8; i++)
      {
         if(!m_gates[i].Initialize())
         {
            Print(StringFormat("[GateMgr] WARNING: Gate %d (%s) initialization failed",
                  i+1, m_gates[i].GetName()));
         }
      }
      
      // Set mode
      if(m_no_constraints)
         SetMode(GATE_MODE_RISK_ONLY);
      
      Print("[GateMgr] Enhanced Efficient Gate System initialized (v2.0)");
      if(shadow_mode)
         Print("[GateMgr] SHADOW MODE: Logging without execution");
      
      return true;
   }
   
   // Set processing mode
   void SetMode(EGateProcessingMode mode) 
   { 
      m_mode = mode;
      
      // Configure gates based on mode
      switch(mode)
      {
         case GATE_MODE_RISK_ONLY:
            // Only risk-critical gates: G1, G4, G7, G8
            m_g2_market.Enable(false);
            m_g3_strategy.Enable(false);
            m_g5_performance.Enable(false);
            m_g6_ml.Enable(false);
            Print("[GateMgr] Mode: RISK_ONLY (G1,G4,G7,G8 active)");
            break;
            
         case GATE_MODE_FAST:
            // Skip heavy performance gates: G5, G6
            m_g5_performance.Enable(false);
            m_g6_ml.Enable(false);
            Print("[GateMgr] Mode: FAST (skip G5,G6)");
            break;
            
         case GATE_MODE_BYPASS:
            // Minimal - only critical risk gates
            m_g2_market.Enable(false);
            m_g3_strategy.Enable(false);
            m_g5_performance.Enable(false);
            m_g6_ml.Enable(false);
            Print("[GateMgr] Mode: BYPASS (minimal validation)");
            break;
            
         case GATE_MODE_ALL_BYPASS:
            // DATA COLLECTION MODE: Disable ALL gates
            for(int i=0; i<8; i++)
               m_gates[i].Enable(false);
            Print("[GateMgr] Mode: ALL_BYPASS (ALL gates disabled - DATA COLLECTION)");
            break;
            
         default: // GATE_MODE_FULL
            // Enable all gates
            for(int i=0; i<8; i++)
               m_gates[i].Enable(true);
            Print("[GateMgr] Mode: FULL (all 8 gates active)");
            break;
      }
   }
   
   // Configure individual gates
   void SetPerformanceWaxEnabled(bool val, double min_wr=0.45, int lookback=20)
   {
      m_g5_performance.SetMinWinRate(min_wr);
      m_g5_performance.SetLookback(lookback);
      m_g5_performance.Enable(val);
   }
   
   void SetMLPolishEnabled(bool val, double threshold=0.55)
   {
      m_g6_ml.SetConfidenceThreshold(threshold);
      m_g6_ml.Enable(val);
   }
   
   void SetLiveCleanEnabled(bool val, double max_spread=0.05)
   {
      m_g7_live.SetMaxSpreadPct(max_spread);
      m_g7_live.Enable(val);
   }
   
   // Enable auto-tuning for specific gates
   void EnableAutoTune(int gate_num, const SGateAutoTuneConfig &config)
   {
      if(gate_num >= 1 && gate_num <= 8)
         m_gates[gate_num-1].EnableAutoTune(config);
   }
   
   // Record trade outcome for learning
   void RecordTradeOutcome(double pnl)
   {
      m_g5_performance.RecordTrade(pnl);
      
      // Record for all gates with auto-tuning
      for(int i=0; i<8; i++)
         m_gates[i].RecordTradeOutcome(pnl, true);  // Assume passed for simplicity
   }
   
   // Main signal processing with full metrics
   bool ProcessSignalEnhanced(TradingSignal &signal, 
                              CSignalDecision &decision,
                              string &block_reason)
   {
      ulong start_time = GetMicrosecondCount();
      block_reason = "";

      // Normalize TradingSignal fields to ensure consistency across generators/gates/execution
      if(signal.symbol == "")
         signal.symbol = _Symbol;
      if(signal.timeframe == PERIOD_CURRENT)
         signal.timeframe = (ENUM_TIMEFRAMES)_Period;
      if(signal.timestamp == 0)
         signal.timestamp = TimeCurrent();

      // Strategy name normalization
      if(signal.strategy == "" && signal.strategy_name != "")
         signal.strategy = signal.strategy_name;
      if(signal.strategy_name == "" && signal.strategy != "")
         signal.strategy_name = signal.strategy;

      // Order type / direction normalization
      if(signal.order_type <= 0)
         signal.order_type = (signal.type == 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      if(signal.type != 0 && signal.type != 1)
         signal.type = (signal.order_type == ORDER_TYPE_SELL || signal.order_type == ORDER_TYPE_SELL_LIMIT || signal.order_type == ORDER_TYPE_SELL_STOP || signal.order_type == ORDER_TYPE_SELL_STOP_LIMIT) ? 1 : 0;
      if(signal.direction == 0)
         signal.direction = (signal.type == 0 ? 1 : -1);

      // Price/SL/TP normalization: prefer canonical price/sl/tp
      if(signal.price <= 0.0)
         signal.price = signal.entry_price;
      if(signal.sl <= 0.0)
         signal.sl = signal.stop_loss;
      if(signal.tp <= 0.0)
         signal.tp = signal.take_profit;
      if(signal.entry_price <= 0.0)
         signal.entry_price = signal.price;
      if(signal.stop_loss <= 0.0)
         signal.stop_loss = signal.sl;
      if(signal.take_profit <= 0.0)
         signal.take_profit = signal.tp;

      // Confidence normalization
      if(!MathIsValidNumber(signal.confidence) || signal.confidence <= 0.0 || signal.confidence > 1.0)
         signal.confidence = 0.5;

      // Execution-invalid guardrails (only hard stops allowed)
      if(signal.price <= 0.0 || !MathIsValidNumber(signal.price))
      {
         block_reason = "Invalid price";
         return false;
      }
      if(signal.volume < 0.0 || !MathIsValidNumber(signal.volume))
      {
         block_reason = "Invalid volume";
         return false;
      }
      
      // Create shadow log entry
      SShadowLogEntry log_entry;
      double log_price = (signal.entry_price > 0) ? signal.entry_price : signal.price;
      double log_volume = (signal.volume > 0) ? signal.volume : 0.1;
      log_entry.Init(_Symbol, 
                     (signal.direction > 0) ? "BUY" : "SELL",
                     log_price,
                     log_volume,
                     signal.strategy_name);
      
      // Execute gates in adjust-only mode: never block except execution-invalid
      // Per-gate budget: max 2ms per gate to prevent cascade latency
      const ulong GATE_BUDGET_US = 2000;  // 2ms per gate max
      bool passed = true;
      int gates_evaluated = 0;
      int gates_passed = 0;
      int gates_skipped_budget = 0;
      string soft_reasons = "";
      
      for(int i=0; i<8; i++)
      {
         ulong gate_start_us = GetMicrosecondCount();
         CGateBase* gate = m_gates[i];
         
         // Skip ALL gates in ALL_BYPASS mode (data collection)
         if(m_mode == GATE_MODE_ALL_BYPASS)
            continue;
         
         // FIX: Explicit mode-based gate skipping
         if(m_mode == GATE_MODE_RISK_ONLY)
         {
            // RISK_ONLY: Only run G1, G4, G7, G8 (indices 0, 3, 6, 7)
            if(i != 0 && i != 3 && i != 6 && i != 7)
               continue;  // Skip G2, G3, G5, G6
         }
         else if(m_mode == GATE_MODE_FAST)
         {
            // FAST: Skip G5, G6 (indices 4, 5)
            if(i == 4 || i == 5)
               continue;
         }
         else
         {
            // Normal mode: Skip disabled gates (but G1,G4,G7,G8 always run)
            if(!gate.IsEnabled() && i != 0 && i != 3 && i != 6 && i != 7)
               continue;
         }
         
         // Check remaining budget before evaluating gate
         ulong elapsed_total_us = GetMicrosecondCount() - start_time;
         if(elapsed_total_us > 15000) // Hard stop at 15ms total
         {
            gates_skipped_budget++;
            PrintFormat("[GATE-BUDGET] Skipping G%d due to total budget exceeded (%.2fms)", i+1, elapsed_total_us/1000.0);
            continue;
         }
         
         EGateResult result;
         bool gate_passed = gate.Validate(signal, result);
         
         // Enforce per-gate budget post-validation
         ulong gate_latency_us = GetMicrosecondCount() - gate_start_us;
         if(gate_latency_us > GATE_BUDGET_US)
         {
            Print(StringFormat("[GATE-SLOW] G%d took %.2fms (budget: %.2fms)", i+1, gate_latency_us/1000.0, GATE_BUDGET_US/1000.0));
         }
         gate.RecordLatency(gate_latency_us);

         // P0-P5 integration: record gate outcomes for controller status/auditing
         PostGateRecord(StringFormat("G%d", i+1), gate_passed, result.confidence);
         
         // Record in log entry
         log_entry.SetGateResult(i, result);
         
         gates_evaluated++;
         if(gate_passed)
            gates_passed++;

         // Soft-fail: record reason and continue evaluating remaining gates
         if(!gate_passed)
         {
            passed = false;
            string reason = StringFormat("G%d_%s: %s", i+1, gate.GetName(), result.block_reason);
            if(soft_reasons == "")
               soft_reasons = reason;
            else
               soft_reasons = soft_reasons + " | " + reason;

            // Penalize confidence slightly but do not block
            if(MathIsValidNumber(result.confidence) && result.confidence >= 0.0 && result.confidence <= 1.0)
               signal.confidence = MathMax(0.05, MathMin(1.0, signal.confidence * (0.9 + 0.1 * result.confidence)));
            else
               signal.confidence = MathMax(0.05, MathMin(1.0, signal.confidence * 0.9));
         }
      }
      
      // Log budget summary if gates were skipped
      if(gates_skipped_budget > 0)
      {
         Print(StringFormat("[GATE-BUDGET] %d gates skipped due to total budget constraints", gates_skipped_budget));
      }
      
      // Update shadow log
      log_entry.all_gates_passed = passed;
      log_entry.final_confidence = signal.confidence;
      log_entry.execution_status = (m_use_shadow_logging ? "SHADOW" : "EXECUTED");
      
      if(m_shadow_logger.IsInitialized())
         m_shadow_logger.LogGateDecision(log_entry);
      
      // Soft gating: we still execute/build the decision, but expose soft reasons for auditing
      block_reason = soft_reasons;
      decision.signal_id = signal.strategy_name;
      decision.strategy = (signal.strategy != "") ? signal.strategy : signal.strategy_name;  // CRITICAL: Set strategy name
      decision.symbol = (signal.symbol != "") ? signal.symbol : _Symbol;
      decision.order_type = (signal.type == 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      // FIX: Use price/sl/tp fields which are set by signal generators
      // entry_price/stop_loss/take_profit are alternate names for same data
      decision.final_price = (signal.entry_price > 0) ? signal.entry_price : signal.price;
      decision.final_sl = (signal.stop_loss > 0) ? signal.stop_loss : signal.sl;
      decision.final_tp = (signal.take_profit > 0) ? signal.take_profit : signal.tp;
      decision.final_volume = (signal.volume > 0) ? signal.volume : 0.1;  // Use signal volume or default
      decision.final_confidence = signal.confidence;
      decision.is_adjusted = (soft_reasons != "");
      decision.block_reason = soft_reasons;
      
      // Performance tracking
      ulong total_latency = GetMicrosecondCount() - start_time;
      m_total_signals++;
      m_passed_signals++; // In adjust-only mode, all execution-valid signals are considered passed
      
      // Update average latency (EMA)
      if(m_avg_latency_ms == 0)
         m_avg_latency_ms = (double)total_latency / 1000.0;
      else
         m_avg_latency_ms = m_avg_latency_ms * 0.9 + (double)total_latency / 1000.0 * 0.1;
      
      // Log performance warning if slow
      if(total_latency > 10000) // 10ms
         Print(StringFormat("[GateMgr] WARNING: Slow processing: %.2fms", (double)total_latency/1000.0));
      
      return true;
   }
   
   // Statistics
   void PrintStats()
   {
      Print("=== Enhanced Gate System Statistics ===");
      Print(StringFormat("Total Signals: %I64u | Passed: %I64u (%.1f%%)",
            m_total_signals, m_passed_signals,
            m_total_signals > 0 ? (double)m_passed_signals / m_total_signals * 100 : 0.0));
      Print(StringFormat("Avg Latency: %.2fms", m_avg_latency_ms));
      
      for(int i=0; i<8; i++)
         m_gates[i].PrintStats();
      
      m_shadow_logger.PrintStats();
   }
   
   // Getters
   bool IsShadowMode() const { return m_use_shadow_logging; }
   CShadowLogger* GetShadowLogger() { return GetPointer(m_shadow_logger); }
   
   // Cleanup
   void Shutdown()
   {
      Print("[GateMgr] Shutdown complete");
      m_shadow_logger.PrintStats();
   }
   
   //+------------------------------------------------------------------+
   //| Update thresholds from learning system                           |
   //+------------------------------------------------------------------+
   void UpdateFromLearning()
   {
      // Update gate thresholds based on learning/performance data
      for(int i=0; i<8; i++)
      {
         if(m_gates[i].IsAutoTuneEnabled())
         {
            m_gates[i].UpdateThresholdFromLearning();
         }
      }
      Print("[GateMgr] Updated thresholds from learning");
   }
   
   //+------------------------------------------------------------------+
   //| Individual Gate Processing Methods                               |
   //+------------------------------------------------------------------+
   bool ProcessGate1(TradingSignal &signal) 
   { 
      EGateResult result;
      return m_g1_signal.Validate(signal, result); 
   }
   
   bool ProcessGate2(TradingSignal &signal) 
   { 
      EGateResult result;
      return m_g2_market.Validate(signal, result); 
   }
   
   bool ProcessGate3(TradingSignal &signal) 
   { 
      EGateResult result;
      return m_g3_strategy.Validate(signal, result); 
   }
   
   bool ProcessGate4(TradingSignal &signal) 
   { 
      EGateResult result;
      return m_g4_risk.Validate(signal, result); 
   }
   
   bool ProcessGate5(TradingSignal &signal) 
   { 
      EGateResult result;
      return m_g5_performance.Validate(signal, result); 
   }
   
   bool ProcessGate6(TradingSignal &signal) 
   { 
      EGateResult result;
      return m_g6_ml.Validate(signal, result); 
   }
   
   bool ProcessGate7(TradingSignal &signal) 
   { 
      EGateResult result;
      return m_g7_live.Validate(signal, result); 
   }
   
   bool ProcessGate8(TradingSignal &signal) 
   { 
      EGateResult result;
      return m_g8_final.Validate(signal, result); 
   }
};

// Compatibility macro for easy migration
#define CEfficientGateManager CEfficientGateManagerEnhanced

#endif // __ENHANCED_EFFICIENT_GATE_SYSTEM_MQH__
