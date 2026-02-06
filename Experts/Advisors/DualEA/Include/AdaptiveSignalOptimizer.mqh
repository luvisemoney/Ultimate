//+------------------------------------------------------------------+
//| AdaptiveSignalOptimizer.mqh                                      |
//| Purpose: ML-Driven Adaptive Signal Optimization System           |
//| Features: Strategy-specific profiles, Multi-pass validation,     |
//|           Learning-based parameter tuning                        |
//+------------------------------------------------------------------+
#ifndef __ADAPTIVESIGNALOPTIMIZER_MQH__
#define __ADAPTIVESIGNALOPTIMIZER_MQH__

#include "LearningBridge.mqh"
#include "GateSystemAutoLearning.mqh"

// Forward declaration - CEfficientGateManagerEnhanced is defined in GateSystemAutoLearning

// Strategy-specific adjustment profile
struct StrategyProfile
{
   string strategy_name;
   
   // Adjustment ranges (min, max, step)
   double price_adjust_range[3];      // [min, max, step]
   double sl_adjust_range[3];
   double tp_adjust_range[3];
   double volume_adjust_range[3];
   
   // Learning metrics
   double success_rate;
   int total_adjustments;
   int successful_adjustments;
   datetime last_update;
   
   // ML-derived optimal adjustments
   double optimal_price_tweak;
   double optimal_sl_tweak;
   double optimal_tp_tweak;
   double optimal_volume_tweak;
};

// Gate journey step - tracks what happened at each gate
struct GateJourneyStep
{
   string gate_name;
   int gate_index;
   bool passed;
   string reason;
   
   // Adjustments made at this gate
   double price_before;
   double price_after;
   double sl_before;
   double sl_after;
   double tp_before;
   double tp_after;
   double volume_before;
   double volume_after;
   
   bool was_adjusted;
   datetime step_time;
};

// Adjustment attempt record
struct AdjustmentAttempt
{
   int attempt_number;
   string gate_blocked;
   double price_tweak;
   double sl_tweak;
   double tp_tweak;
   double volume_tweak;
   bool passed;
   string reason;
   
   // Full gate journey for this attempt
   GateJourneyStep journey[8];
   int journey_length;
};

// Enhanced decision with adjustment tracking
class CAdaptiveDecision : public CSignalDecision
{
public:
   bool is_adjusted;
   int adjustment_attempts;
   AdjustmentAttempt attempts[3];  // Max 3 attempts
   string original_signal_id;
   
   // Full gate journey (all gates, all attempts)
   GateJourneyStep complete_journey[24];  // 8 gates × 3 attempts max
   int complete_journey_length;
   
   CAdaptiveDecision() : CSignalDecision()
   {
      is_adjusted = false;
      adjustment_attempts = 0;
      original_signal_id = "";
      complete_journey_length = 0;
   }
};

//+------------------------------------------------------------------+
//| Main Adaptive Signal Optimizer Class                            |
//+------------------------------------------------------------------+
class CAdaptiveSignalOptimizer
{
private:
   CLearningBridge* m_learning;
   CEfficientGateManagerEnhanced* m_gate_manager;
   
   // Simple array-based profile storage (MQL5 HashMap doesn't support structs)
   string m_profile_keys[];
   StrategyProfile m_profile_values[];
   
   // Configuration
   int m_max_attempts;
   bool m_use_ml_optimization;
   bool m_verbose_logging;
   
   // Statistics
   int m_total_optimizations;
   int m_successful_optimizations;
   
   // Helper methods for profile storage
   int FindProfileIndex(const string key)
   {
      for(int i = 0; i < ArraySize(m_profile_keys); i++)
      {
         if(m_profile_keys[i] == key) return i;
      }
      return -1;
   }
   
   bool GetProfile(const string key, StrategyProfile &out_profile)
   {
      int idx = FindProfileIndex(key);
      if(idx >= 0)
      {
         out_profile = m_profile_values[idx];
         return true;
      }
      return false;
   }
   
   void SetProfile(const string key, const StrategyProfile &profile)
   {
      int idx = FindProfileIndex(key);
      if(idx >= 0)
      {
         m_profile_values[idx] = profile;
      }
      else
      {
         int size = ArraySize(m_profile_keys);
         ArrayResize(m_profile_keys, size + 1);
         ArrayResize(m_profile_values, size + 1);
         m_profile_keys[size] = key;
         m_profile_values[size] = profile;
      }
   }
   
   // Initialize strategy profiles for all 23 strategies
   void InitializeStrategyProfiles()
   {
      string strategies[] = {
         "MovingAverageStrategy", "ADXStrategy", "RSIStrategy", "BollingerBandsStrategy",
         "MACDStrategy", "StochasticStrategy", "IchimokuStrategy", "ParabolicSARStrategy",
         "CCIStrategy", "WilliamsRStrategy", "ATRStrategy", "FibonacciStrategy",
         "PivotPointStrategy", "BreakoutStrategy", "MomentumStrategy", "VolumeStrategy",
         "GapStrategy", "NewsStrategy", "CorrelationStrategy", "SeasonalStrategy",
         "MachineLearningStrategy", "EnsembleStrategy", "HybridStrategy"
      };
      
      for(int i = 0; i < ArraySize(strategies); i++)
      {
         StrategyProfile profile;
         profile.strategy_name = strategies[i];
         
         // Default adjustment ranges (will be ML-optimized)
         // Price: ±1% adjustment range (more conservative)
         profile.price_adjust_range[0] = -0.01;
         profile.price_adjust_range[1] = 0.01;
         profile.price_adjust_range[2] = 0.0025;  // 0.25% steps
         
         // SL: 0.8x to 1.2x (more conservative)
         profile.sl_adjust_range[0] = 0.8;
         profile.sl_adjust_range[1] = 1.2;
         profile.sl_adjust_range[2] = 0.05;
         
         // TP: 0.9x to 1.5x (more conservative)
         profile.tp_adjust_range[0] = 0.9;
         profile.tp_adjust_range[1] = 1.5;
         profile.tp_adjust_range[2] = 0.1;
         
         // Volume: 0.5x to 1.0x (reduce only for safety)
         profile.volume_adjust_range[0] = 0.5;
         profile.volume_adjust_range[1] = 1.0;
         profile.volume_adjust_range[2] = 0.05;
         
         // Initialize metrics
         profile.success_rate = 0.0;
         profile.total_adjustments = 0;
         profile.successful_adjustments = 0;
         profile.last_update = 0;
         
         // Start with more conservative tweaks
         profile.optimal_price_tweak = 0.0;
         profile.optimal_sl_tweak = 1.0;
         profile.optimal_tp_tweak = 1.1;  // Slightly more aggressive TP
         profile.optimal_volume_tweak = 0.8;  // Less conservative volume
         
         SetProfile(strategies[i], profile);
      }
      
      PrintFormat("✅ AdaptiveSignalOptimizer: Initialized %d strategy profiles", ArraySize(strategies));
   }
   
   // Learn optimal adjustments from historical data
   void LearnOptimalAdjustments(string strategy_name)
   {
      if(m_learning == NULL) return;
      
      StrategyProfile profile;
      if(!GetProfile(strategy_name, profile))
         return;
      
      // Query learning bridge for successful adjustments
      // This is where ML magic happens - analyze what tweaks led to profitable trades
      
      // For now, use simple heuristics based on success rate
      if(profile.total_adjustments > 10)
      {
         double success_rate = (double)profile.successful_adjustments / profile.total_adjustments;
         
         if(success_rate > 0.7)
         {
            // Good performance - be more aggressive
            profile.optimal_volume_tweak = MathMin(1.0, profile.optimal_volume_tweak * 1.1);
         }
         else if(success_rate < 0.4)
         {
            // Poor performance - be more conservative
            profile.optimal_volume_tweak = MathMax(0.3, profile.optimal_volume_tweak * 0.9);
            profile.optimal_sl_tweak = MathMax(0.5, profile.optimal_sl_tweak * 0.95);
         }
         
         profile.last_update = TimeCurrent();
         SetProfile(strategy_name, profile);
         
         if(m_verbose_logging)
            PrintFormat("📊 ML Update [%s]: Success=%.1f%% Vol=%.2f SL=%.2f", 
                       strategy_name, success_rate * 100, 
                       profile.optimal_volume_tweak, profile.optimal_sl_tweak);
      }
   }

   bool ValidateAdjustedSignal(const TradingSignal &signal, string &reason) const
   {
      string symbol = (signal.symbol != "") ? signal.symbol : _Symbol;
      if(symbol == "") symbol = _Symbol;

      if(!MathIsValidNumber(signal.price) || signal.price <= 0.0)
      {
         reason = "invalid price";
         return false;
      }

      if(!MathIsValidNumber(signal.sl) || !MathIsValidNumber(signal.tp))
      {
         reason = "invalid SL/TP";
         return false;
      }

      bool is_buy = (signal.type == 0);
      if(is_buy)
      {
         if(signal.sl >= signal.price)
         {
            reason = "buy SL above price";
            return false;
         }
         if(signal.tp <= signal.price)
         {
            reason = "buy TP below price";
            return false;
         }
      }
      else if(signal.type == 1)
      {
         if(signal.sl <= signal.price)
         {
            reason = "sell SL below price";
            return false;
         }
         if(signal.tp >= signal.price)
         {
            reason = "sell TP above price";
            return false;
         }
      }

      double vol_min = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double vol_max = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      if(vol_min <= 0.0) vol_min = 0.01;
      if(vol_max <= 0.0) vol_max = 100.0;

      if(!MathIsValidNumber(signal.volume) || signal.volume < vol_min || signal.volume > vol_max)
      {
         reason = "invalid volume";
         return false;
      }

      return true;
   }

public:
   CAdaptiveSignalOptimizer(CLearningBridge* learning, CEfficientGateManagerEnhanced* gate_mgr, 
                            int max_attempts = 3, bool use_ml = true)
   {
      m_learning = learning;
      m_gate_manager = gate_mgr;
      m_max_attempts = max_attempts;
      m_use_ml_optimization = use_ml;
      m_verbose_logging = true;
      
      m_total_optimizations = 0;
      m_successful_optimizations = 0;
      
      InitializeStrategyProfiles();
      
      PrintFormat("🎯 AdaptiveSignalOptimizer initialized: max_attempts=%d, ML=%s", 
                  m_max_attempts, m_use_ml_optimization ? "ON" : "OFF");
   }
   
   ~CAdaptiveSignalOptimizer()
   {
      PrintFormat("AdaptiveSignalOptimizer stats: %d/%d optimizations successful (%.1f%%)",
                  m_successful_optimizations, m_total_optimizations,
                  m_total_optimizations > 0 ? (double)m_successful_optimizations/m_total_optimizations*100 : 0);
   }
   
   // Main optimization function with multi-pass validation
   bool OptimizeSignal(TradingSignal &signal, CAdaptiveDecision &decision, 
                       const string strategy_name, string &blocking_reason)
   {
      m_total_optimizations++;
      
      // First attempt: Try original signal
      CSignalDecision temp_decision;
      bool passed = m_gate_manager->ProcessSignal(signal, temp_decision);
      
      if(passed)
      {
         // Original signal passed - no adjustment needed
         CopyDecision(temp_decision, decision);
         decision.is_adjusted = false;
         decision.adjustment_attempts = 0;
         
         blocking_reason = "Original signal passed all gates";
         return true;
      }
      
      // Original failed - start adaptive optimization
      blocking_reason = "Original signal blocked";
      decision.original_signal_id = signal.id;
      decision.is_adjusted = true;
      
      if(m_verbose_logging)
         PrintFormat("🔧 Optimizing blocked signal: %s [%s]", signal.id, strategy_name);
      
      // Get strategy profile
      StrategyProfile profile;
      if(!GetProfile(strategy_name, profile))
      {
         // Unknown strategy - use default profile
         if(m_verbose_logging)
            PrintFormat("⚠️ Unknown strategy: %s, using defaults", strategy_name);
         
         profile.optimal_price_tweak = 0.0;
         profile.optimal_sl_tweak = 1.0;
         profile.optimal_tp_tweak = 1.0;
         profile.optimal_volume_tweak = 0.7;
      }
      
      // Update ML-learned adjustments
      if(m_use_ml_optimization)
         LearnOptimalAdjustments(strategy_name);
      
      // Multi-attempt optimization
      for(int attempt = 0; attempt < m_max_attempts; attempt++)
      {
         TradingSignal adjusted_signal = signal;

         // Normalize symbol and volume bounds early so validation doesn't skip all attempts.
         string symbol = (adjusted_signal.symbol != "") ? adjusted_signal.symbol : _Symbol;
         if(symbol == "") symbol = _Symbol;
         double vol_min = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
         double vol_max = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
         double vol_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
         if(vol_min <= 0.0) vol_min = 0.01;
         if(vol_max <= 0.0) vol_max = 100.0;
         if(vol_step <= 0.0) vol_step = vol_min;
         if(!MathIsValidNumber(adjusted_signal.volume) || adjusted_signal.volume <= 0.0)
            adjusted_signal.volume = vol_min;
         // Clamp and round to step
         if(adjusted_signal.volume < vol_min) adjusted_signal.volume = vol_min;
         if(adjusted_signal.volume > vol_max) adjusted_signal.volume = vol_max;
         adjusted_signal.volume = MathFloor(adjusted_signal.volume / vol_step + 1e-9) * vol_step;
         if(adjusted_signal.volume < vol_min) adjusted_signal.volume = vol_min;
         if(adjusted_signal.volume > vol_max) adjusted_signal.volume = vol_max;
         
         // Calculate adjustments based on attempt number and ML insights
         // Use more conservative adjustments to increase success rate
         double aggressiveness = 1.0 + (attempt * 0.15);  // Slower increase in adjustments
         
         // Apply ML-optimized adjustments with more conservative ranges
         adjusted_signal.price = signal.price * (1.0 + profile.optimal_price_tweak * aggressiveness * 0.5);  // Reduce price adjustment impact
         double sl_dist = MathAbs(signal.price - signal.sl);
         double tp_dist = MathAbs(signal.tp - signal.price);
         if(sl_dist <= 0.0) sl_dist = MathAbs(signal.price) * 0.001;
         if(tp_dist <= 0.0) tp_dist = MathAbs(signal.price) * 0.001;
         double sl_mult = (profile.optimal_sl_tweak * (1.0 - attempt * 0.05));
         double tp_mult = (profile.optimal_tp_tweak * (1.0 + attempt * 0.075));
         if(sl_mult <= 0.01) sl_mult = 0.01;
         if(tp_mult <= 0.01) tp_mult = 0.01;
         if(signal.type == 0)
         {
            adjusted_signal.sl = adjusted_signal.price - sl_dist * sl_mult;
            adjusted_signal.tp = adjusted_signal.price + tp_dist * tp_mult;
         }
         else
         {
            adjusted_signal.sl = adjusted_signal.price + sl_dist * sl_mult;
            adjusted_signal.tp = adjusted_signal.price - tp_dist * tp_mult;
         }
         adjusted_signal.volume = adjusted_signal.volume * (profile.optimal_volume_tweak * (1.0 - attempt * 0.075));  // Gentler volume reduction
         // Re-clamp after applying tweaks
         if(adjusted_signal.volume < vol_min) adjusted_signal.volume = vol_min;
         if(adjusted_signal.volume > vol_max) adjusted_signal.volume = vol_max;
         adjusted_signal.volume = MathFloor(adjusted_signal.volume / vol_step + 1e-9) * vol_step;
         if(adjusted_signal.volume < vol_min) adjusted_signal.volume = vol_min;
         if(adjusted_signal.volume > vol_max) adjusted_signal.volume = vol_max;
         
         // Special adjustments based on confidence
         if(signal.confidence < 0.3)
         {
            // Very low confidence - be extra conservative
            adjusted_signal.volume *= 0.7;
            double dist = MathAbs(adjusted_signal.price - adjusted_signal.sl);
            adjusted_signal.sl = (adjusted_signal.type == 0) ? adjusted_signal.price - dist * 0.9 : adjusted_signal.price + dist * 0.9;
         }
         else if(signal.confidence < 0.5)
         {
            // Low confidence - be moderately conservative
            adjusted_signal.volume *= 0.85;
            double dist = MathAbs(adjusted_signal.price - adjusted_signal.sl);
            adjusted_signal.sl = (adjusted_signal.type == 0) ? adjusted_signal.price - dist * 0.95 : adjusted_signal.price + dist * 0.95;
         }
         
         // Update signal ID to track adjustment
         adjusted_signal.id = signal.id + "_adj" + IntegerToString(attempt + 1);
         
         // Record attempt
         AdjustmentAttempt att;
         att.attempt_number = attempt + 1;
         att.price_tweak = (adjusted_signal.price - signal.price) / signal.price;
         if(MathIsValidNumber(signal.sl) && MathAbs(signal.sl) > 1e-12)
            att.sl_tweak = adjusted_signal.sl / signal.sl;
         else
            att.sl_tweak = 0.0;
         if(MathIsValidNumber(signal.tp) && MathAbs(signal.tp) > 1e-12)
            att.tp_tweak = adjusted_signal.tp / signal.tp;
         else
            att.tp_tweak = 0.0;
         if(MathIsValidNumber(signal.volume) && MathAbs(signal.volume) > 1e-12)
            att.volume_tweak = adjusted_signal.volume / signal.volume;
         else
            att.volume_tweak = 0.0;
         
         // Try adjusted signal through gates
         CSignalDecision adj_decision;
         string validation_reason;
         if(!ValidateAdjustedSignal(adjusted_signal, validation_reason))
         {
            att.passed = false;
            att.reason = "Sanity check failed: " + validation_reason;
            decision.attempts[attempt] = att;
            decision.adjustment_attempts++;
            if(m_verbose_logging)
               PrintFormat("⚠️ Adjustment attempt %d skipped (%s)", attempt + 1, validation_reason);
            continue;
         }

         bool adj_passed = m_gate_manager->ProcessSignal(adjusted_signal, adj_decision);
         
         att.passed = adj_passed;
         att.gate_blocked = adj_passed ? "NONE" : "Multiple";
         att.reason = adj_passed ? "Passed after adjustment" : "Still blocked";
         
         decision.attempts[attempt] = att;
         decision.adjustment_attempts++;
         
         if(adj_passed)
         {
            // Success! Multi-pass validation (2 re-validation cycles)
            if(m_verbose_logging)
               PrintFormat("✅ Adjustment attempt %d succeeded, starting re-validation...", attempt + 1);
            
            bool revalidation_passed = true;
            
            for(int revalidation = 1; revalidation <= 2; revalidation++)
            {
               CSignalDecision revalidation_decision;
               bool revalidation_result = m_gate_manager->ProcessSignal(adjusted_signal, revalidation_decision);
               
               if(!revalidation_result)
               {
                  revalidation_passed = false;
                  if(m_verbose_logging)
                     PrintFormat("❌ Re-validation cycle %d FAILED", revalidation);
                  break;
               }
               else
               {
                  if(m_verbose_logging)
                     PrintFormat("✅ Re-validation cycle %d PASSED", revalidation);
                  
                  // Update decision with latest validation
                  CopyDecision(revalidation_decision, adj_decision);
               }
            }
            
            if(revalidation_passed)
            {
               // All validations passed!
               CopyDecision(adj_decision, decision);
               decision.is_adjusted = true;
               
               // Update profile statistics
               profile.total_adjustments++;
               profile.successful_adjustments++;
               SetProfile(strategy_name, profile);
               
               m_successful_optimizations++;
               
               blocking_reason = StringFormat("Optimized on attempt %d, passed 2 re-validations", attempt + 1);
               
               if(m_verbose_logging)
                  PrintFormat("🎉 Signal optimized successfully: %s → %s (Volume: %.2f → %.2f)",
                             signal.id, adjusted_signal.id, signal.volume, adjusted_signal.volume);
               
               return true;
            }
            else
            {
               // Re-validation failed, try next adjustment
               if(m_verbose_logging)
                  PrintFormat("⚠️ Adjustment passed gates but failed re-validation, trying next adjustment...");
               continue;
            }
         }
         
         // This attempt failed, log and try next
         if(m_verbose_logging)
            PrintFormat("❌ Adjustment attempt %d failed: V%.2f SL%.2f TP%.2f", 
                       attempt + 1, att.volume_tweak, att.sl_tweak, att.tp_tweak);
      }
      
      // All attempts exhausted
      profile.total_adjustments++;
      SetProfile(strategy_name, profile);
      
      blocking_reason = StringFormat("All %d optimization attempts failed", m_max_attempts);
      
      if(m_verbose_logging)
         PrintFormat("🚫 Signal optimization FAILED after %d attempts: %s", m_max_attempts, signal.id);
      
      return false;
   }
   
   // Helper to copy decision data
   void CopyDecision(const CSignalDecision &source, CSignalDecision &dest)
   {
      dest.signal_id = source.signal_id;
      dest.timestamp = source.timestamp;
      dest.symbol = source.symbol;
      dest.timeframe = source.timeframe;
      dest.original_price = source.original_price;
      dest.original_type = source.original_type;
      dest.original_sl = source.original_sl;
      dest.original_tp = source.original_tp;
      dest.original_volume = source.original_volume;
      dest.executed = source.executed;
      dest.final_price = source.final_price;
      dest.final_sl = source.final_sl;
      dest.final_tp = source.final_tp;
      dest.final_volume = source.final_volume;
      dest.confidence = source.confidence;
      dest.volatility = source.volatility;
      dest.correlation_score = source.correlation_score;
      dest.market_regime = source.market_regime;
      
      // Copy gate results
      for(int i = 0; i < 8; i++)
      {
         dest.gate_results[i] = source.gate_results[i];
         dest.gate_reasons[i] = source.gate_reasons[i];
         dest.gate_timestamps[i] = source.gate_timestamps[i];
         
         for(int j = 0; j < 5; j++)
            dest.gate_tweaks[i][j] = source.gate_tweaks[i][j];
      }
   }
   
   // Get optimization statistics
   void GetStatistics(int &total, int &successful, double &success_rate)
   {
      total = m_total_optimizations;
      successful = m_successful_optimizations;
      success_rate = total > 0 ? (double)successful / total * 100.0 : 0.0;
   }
   
   // Print detailed report
   void PrintOptimizationReport()
   {
      PrintFormat("\n=== 📊 Adaptive Signal Optimization Report ===");
      PrintFormat("Total Optimizations: %d", m_total_optimizations);
      PrintFormat("Successful: %d (%.1f%%)", m_successful_optimizations,
                  m_total_optimizations > 0 ? (double)m_successful_optimizations/m_total_optimizations*100 : 0);
      
      Print("\nStrategy-Specific Performance:");
      
      // Print top 5 strategies by success rate
      // (Full implementation would iterate through all profiles)
      Print("(Strategy profiles tracked internally)");
   }
   
   // Print complete gate journey
   void PrintCompleteGateJourney(CAdaptiveDecision &decision)
   {
      if(decision.complete_journey_length == 0) return;
      
      PrintFormat("\n📍 ==== COMPLETE GATE JOURNEY for %s ====", decision.signal_id);
      PrintFormat("Original Signal: %s | Total Attempts: %d | Is Adjusted: %s",
                 decision.original_signal_id != "" ? decision.original_signal_id : decision.signal_id,
                 decision.adjustment_attempts,
                 decision.is_adjusted ? "YES" : "NO");
      
      int current_attempt = 0;
      
      for(int i = 0; i < decision.complete_journey_length; i++)
      {
         GateJourneyStep step = decision.complete_journey[i];
         
         // Check if new attempt started
         if(i > 0 && step.gate_index == 0)
         {
            current_attempt++;
            PrintFormat("\n--- Attempt %d ---", current_attempt + 1);
         }
         else if(i == 0)
         {
            PrintFormat("--- Attempt 1 (Original Signal) ---");
         }
         
         // Print gate status
         string status_icon = step.passed ? "✅" : "❌";
         PrintFormat("  Gate %d [%s]: %s %s",
                    step.gate_index + 1,
                    step.gate_name,
                    status_icon,
                    step.passed ? "PASSED" : "BLOCKED");
         
         if(!step.passed)
            PrintFormat("    Reason: %s", step.reason);
         
         // Print adjustments if any
         if(step.was_adjusted)
         {
            PrintFormat("    🔧 ADJUSTMENTS:");
            
            if(step.price_before != step.price_after)
               PrintFormat("       Price: %.5f → %.5f (%+.2f%%)",
                          step.price_before, step.price_after,
                          (step.price_after - step.price_before) / step.price_before * 100);
            
            if(step.sl_before != step.sl_after)
               PrintFormat("       SL: %.5f → %.5f (%+.2f%%)",
                          step.sl_before, step.sl_after,
                          (step.sl_after - step.sl_before) / step.sl_before * 100);
            
            if(step.tp_before != step.tp_after)
               PrintFormat("       TP: %.5f → %.5f (%+.2f%%)",
                          step.tp_before, step.tp_after,
                          (step.tp_after - step.tp_before) / step.tp_before * 100);
            
            if(step.volume_before != step.volume_after)
               PrintFormat("       Volume: %.2f → %.2f (%+.2f%%)",
                          step.volume_before, step.volume_after,
                          (step.volume_after - step.volume_before) / step.volume_before * 100);
         }
      }
      
      PrintFormat("\n🏁 FINAL OUTCOME: %s", decision.executed ? "✅ EXECUTED" : "❌ REJECTED");
      if(decision.executed)
      {
         PrintFormat("   Final Price: %.5f | SL: %.5f | TP: %.5f | Volume: %.2f",
                    decision.final_price, decision.final_sl, decision.final_tp, decision.final_volume);
      }
      PrintFormat("==========================================\n");
   }
};

#endif
