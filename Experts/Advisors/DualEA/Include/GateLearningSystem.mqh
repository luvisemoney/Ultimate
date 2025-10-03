//+------------------------------------------------------------------+
//| GateLearningSystem.mqh                                           |
//| Purpose: Gate-specific learning and adaptive threshold tuning    |
//| Features: Learn from outcomes, adjust gates dynamically          |
//+------------------------------------------------------------------+
#ifndef __GATELEARNINGSYSTEM_MQH__
#define __GATELEARNINGSYSTEM_MQH__

#include <Files/File.mqh>
#include <Arrays/ArrayObj.mqh>
#include <Generic/HashMap.mqh>

// Gate-specific statistics
struct GateStatistics
{
   string gate_name;
   int gate_index;
   
   // Performance metrics
   int total_signals_processed;
   int signals_passed;
   int signals_blocked;
   double pass_rate;
   
   // Outcome tracking (of signals that passed this gate)
   int total_outcomes;        // Trades that closed
   int winning_outcomes;
   int losing_outcomes;
   double avg_profit;
   double win_rate;
   
   // Threshold learning
   double current_threshold;
   double optimal_threshold;
   double threshold_min;
   double threshold_max;
   
   // Adjustment tracking
   int adjustments_made_at_gate;
   int successful_adjustments;
   double adjustment_success_rate;
   
   // Gate-specific adjustment profile
   double optimal_price_tweak;
   double optimal_sl_tweak;
   double optimal_tp_tweak;
   double optimal_volume_tweak;
   
   datetime last_update;
};

// Trade outcome record
struct TradeOutcome
{
   string signal_id;
   datetime execution_time;
   datetime close_time;
   
   bool was_winner;
   double profit_pct;
   double hold_duration_minutes;
   
   // Which gates did this trade pass?
   bool passed_gates[8];
   
   // Was it adjusted?
   bool was_adjusted;
   int adjustment_gate;  // Which gate triggered adjustment
   
   string strategy_name;
   string symbol;
   int timeframe;
};

//+------------------------------------------------------------------+
//| Gate Learning System - Dynamic Gate Optimization                |
//+------------------------------------------------------------------+
class CGateLearningSystem
{
private:
   GateStatistics m_gate_stats[8];
   CArrayObj m_outcome_history;
   
   string m_learning_file_path;
   bool m_auto_adjust_thresholds;
   
   // Learning parameters
   double m_learning_rate;
   int m_min_samples_for_learning;
   
   // Hybrid update system
   bool m_immediate_update_enabled;
   double m_critical_profit_threshold;   // +5% = critical win
   double m_critical_loss_threshold;     // -3% = critical loss
   
   // Initialize gate names
   void InitializeGateNames()
   {
      string names[8] = {
         "SignalRinse", "MarketSoap", "StrategyScrub", "RiskWash",
         "PerformanceWax", "MLPolish", "LiveClean", "FinalVerify"
      };
      
      for(int i = 0; i < 8; i++)
      {
         m_gate_stats[i].gate_name = names[i];
         m_gate_stats[i].gate_index = i;
         m_gate_stats[i].total_signals_processed = 0;
         m_gate_stats[i].signals_passed = 0;
         m_gate_stats[i].signals_blocked = 0;
         m_gate_stats[i].pass_rate = 0.5;
         
         m_gate_stats[i].total_outcomes = 0;
         m_gate_stats[i].winning_outcomes = 0;
         m_gate_stats[i].losing_outcomes = 0;
         m_gate_stats[i].avg_profit = 0.0;
         m_gate_stats[i].win_rate = 0.5;
         
         m_gate_stats[i].current_threshold = 1.0;
         m_gate_stats[i].optimal_threshold = 1.0;
         m_gate_stats[i].threshold_min = 0.5;
         m_gate_stats[i].threshold_max = 2.0;
         
         m_gate_stats[i].adjustments_made_at_gate = 0;
         m_gate_stats[i].successful_adjustments = 0;
         m_gate_stats[i].adjustment_success_rate = 0.5;
         
         // Gate-specific optimal tweaks
         m_gate_stats[i].optimal_price_tweak = 0.0;
         m_gate_stats[i].optimal_sl_tweak = 1.0;
         m_gate_stats[i].optimal_tp_tweak = 1.0;
         m_gate_stats[i].optimal_volume_tweak = 0.8;
         
         m_gate_stats[i].last_update = TimeCurrent();
      }
   }
   
   // Learn optimal threshold for a gate
   void LearnGateThreshold(int gate_index)
   {
      if(gate_index < 0 || gate_index >= 8) return;
      
      if(m_gate_stats[gate_index].total_outcomes < m_min_samples_for_learning)
         return;  // Not enough data
      
      // Calculate actual win rate of signals that passed this gate
      double actual_win_rate = (double)m_gate_stats[gate_index].winning_outcomes / m_gate_stats[gate_index].total_outcomes;
      
      // Adjust threshold based on performance
      if(actual_win_rate > 0.6)
      {
         // Gate is working well - can afford to be slightly more permissive
         m_gate_stats[gate_index].optimal_threshold = MathMax(m_gate_stats[gate_index].threshold_min, 
                                           m_gate_stats[gate_index].current_threshold * (1.0 - m_learning_rate));
      }
      else if(actual_win_rate < 0.4)
      {
         // Gate letting through too many losers - be more strict
         m_gate_stats[gate_index].optimal_threshold = MathMin(m_gate_stats[gate_index].threshold_max,
                                           m_gate_stats[gate_index].current_threshold * (1.0 + m_learning_rate));
      }
      
      // Update if auto-adjust enabled
      if(m_auto_adjust_thresholds)
      {
         m_gate_stats[gate_index].current_threshold = m_gate_stats[gate_index].optimal_threshold;
         PrintFormat("📊 Gate %d [%s]: Threshold adjusted to %.3f (Win rate: %.1f%%)",
                    gate_index, m_gate_stats[gate_index].gate_name, m_gate_stats[gate_index].current_threshold, actual_win_rate * 100);
      }
   }
   
   // Learn optimal adjustments for a gate
   void LearnGateAdjustments(int gate_index)
   {
      if(gate_index < 0 || gate_index >= 8) return;
      
      if(m_gate_stats[gate_index].adjustments_made_at_gate < 5)
         return;  // Need at least 5 adjustments
      
      double success_rate = (double)m_gate_stats[gate_index].successful_adjustments / m_gate_stats[gate_index].adjustments_made_at_gate;
      
      // Adjust tweaks based on success rate
      if(success_rate > 0.7)
      {
         // Adjustments working - can be slightly more aggressive
         m_gate_stats[gate_index].optimal_volume_tweak = MathMin(1.0, m_gate_stats[gate_index].optimal_volume_tweak * 1.05);
      }
      else if(success_rate < 0.3)
      {
         // Adjustments not working - be more conservative
         m_gate_stats[gate_index].optimal_volume_tweak = MathMax(0.3, m_gate_stats[gate_index].optimal_volume_tweak * 0.95);
         m_gate_stats[gate_index].optimal_sl_tweak = MathMax(0.7, m_gate_stats[gate_index].optimal_sl_tweak * 0.98);
      }
      
      PrintFormat("🔧 Gate %d [%s]: Adjustment profile updated (Success: %.1f%%)",
                 gate_index, m_gate_stats[gate_index].gate_name, success_rate * 100);
   }

public:
   CGateLearningSystem(bool auto_adjust = true, double learning_rate = 0.05)
   {
      m_learning_file_path = "DualEA\\gate_learning.json";
      m_auto_adjust_thresholds = auto_adjust;
      m_learning_rate = learning_rate;
      m_min_samples_for_learning = 10;
      
      // Hybrid update configuration
      m_immediate_update_enabled = true;
      m_critical_profit_threshold = 5.0;   // 5%+ profit
      m_critical_loss_threshold = -3.0;    // -3% loss
      
      InitializeGateNames();
      
      PrintFormat("🧠 GateLearningSystem initialized: auto_adjust=%s, learning_rate=%.3f",
                 m_auto_adjust_thresholds ? "ON" : "OFF", m_learning_rate);
   }
   
   // Record gate interaction (signal processing)
   void RecordGateInteraction(int gate_index, bool passed, bool was_adjusted = false)
   {
      if(gate_index < 0 || gate_index >= 8) return;
      
      m_gate_stats[gate_index].total_signals_processed++;
      
      if(passed)
         m_gate_stats[gate_index].signals_passed++;
      else
         m_gate_stats[gate_index].signals_blocked++;
      
      if(was_adjusted)
         m_gate_stats[gate_index].adjustments_made_at_gate++;
      
      // Update pass rate
      m_gate_stats[gate_index].pass_rate = (double)m_gate_stats[gate_index].signals_passed / m_gate_stats[gate_index].total_signals_processed;
   }
   
   // Record trade outcome - HYBRID UPDATE SYSTEM
   void RecordTradeOutcome(const TradeOutcome &outcome)
   {
      bool is_critical = (outcome.profit_pct >= m_critical_profit_threshold ||
                         outcome.profit_pct <= m_critical_loss_threshold);
      
      // Update gate statistics
      for(int i = 0; i < 8; i++)
      {
         if(outcome.passed_gates[i])
         {
            m_gate_stats[i].total_outcomes++;
            
            if(outcome.was_winner)
               m_gate_stats[i].winning_outcomes++;
            else
               m_gate_stats[i].losing_outcomes++;
            
            // Update average profit
            m_gate_stats[i].avg_profit = ((m_gate_stats[i].avg_profit * (m_gate_stats[i].total_outcomes - 1)) + outcome.profit_pct) 
                              / m_gate_stats[i].total_outcomes;
            
            // Update win rate
            m_gate_stats[i].win_rate = (double)m_gate_stats[i].winning_outcomes / m_gate_stats[i].total_outcomes;
            
            // Track adjustment success
            if(outcome.was_adjusted && outcome.adjustment_gate == i)
            {
               if(outcome.was_winner)
                  m_gate_stats[i].successful_adjustments++;
            }
            
            // HYBRID UPDATE: Immediate learning for critical outcomes
            if(m_immediate_update_enabled && is_critical)
            {
               PrintFormat("⚡ CRITICAL OUTCOME: %.2f%% - Immediate learning triggered for gates",
                          outcome.profit_pct);
               LearnGateThreshold(i);
               LearnGateAdjustments(i);
            }
         }
      }
      
      // Log outcome
      if(is_critical)
      {
         PrintFormat("💥 Critical %s: %.2f%% | Signal: %s | Gates passed: %d",
                    outcome.was_winner ? "WIN" : "LOSS",
                    outcome.profit_pct,
                    outcome.signal_id,
                    CountPassedGates(outcome));
      }
   }
   
   // Batch learning update (called hourly)
   void PerformBatchLearning()
   {
      PrintFormat("\n🧠 === BATCH LEARNING UPDATE ===");
      
      for(int i = 0; i < 8; i++)
      {
         LearnGateThreshold(i);
         LearnGateAdjustments(i);
      }
      
      // Save to file
      SaveLearningData();
      
      PrintFormat("================================\n");
   }
   
   // Get adjustment profile for a gate
   void GetGateAdjustmentProfile(int gate_index, double &price_tweak, double &sl_tweak, 
                                 double &tp_tweak, double &volume_tweak)
   {
      if(gate_index < 0 || gate_index >= 8)
      {
         price_tweak = 0.0;
         sl_tweak = 1.0;
         tp_tweak = 1.0;
         volume_tweak = 0.7;
         return;
      }
      
      price_tweak = m_gate_stats[gate_index].optimal_price_tweak;
      sl_tweak = m_gate_stats[gate_index].optimal_sl_tweak;
      tp_tweak = m_gate_stats[gate_index].optimal_tp_tweak;
      volume_tweak = m_gate_stats[gate_index].optimal_volume_tweak;
   }
   
   // Get current gate threshold
   double GetGateThreshold(int gate_index)
   {
      return m_gate_stats[gate_index].current_threshold;
   }
   
   // Get gate statistics
   GateStatistics GetGateStats(int gate_index)
   {
      if(gate_index < 0 || gate_index >= 8)
      {
         GateStatistics empty;
         return empty;
      }
      return m_gate_stats[gate_index];
   }
   
   // Save learning data to JSON
   bool SaveLearningData()
   {
      int handle = FileOpen(m_learning_file_path, FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_ANSI);
      if(handle == INVALID_HANDLE)
      {
         PrintFormat("❌ Failed to save gate learning data (Error: %d)", GetLastError());
         return false;
      }
      
      FileWriteString(handle, "{\n");
      FileWriteString(handle, StringFormat("  \"last_update\": \"%s\",\n", TimeToString(TimeCurrent())));
      FileWriteString(handle, "  \"learning_rate\": " + DoubleToString(m_learning_rate, 3) + ",\n");
      FileWriteString(handle, "  \"auto_adjust_enabled\": " + (m_auto_adjust_thresholds ? "true" : "false") + ",\n");
      FileWriteString(handle, "  \"gates\": [\n");
      
      for(int i = 0; i < 8; i++)
      {
         if(i > 0) FileWriteString(handle, ",\n");
         
         string gate_json = StringFormat(
            "    {\n"
            "      \"index\": %d,\n"
            "      \"name\": \"%s\",\n"
            "      \"total_signals\": %d,\n"
            "      \"passed\": %d,\n"
            "      \"blocked\": %d,\n"
            "      \"pass_rate\": %.3f,\n"
            "      \"outcomes\": {\n"
            
         
         FileWriteString(handle, gate_json);
      }
      
      FileWriteString(handle, "\n  ]\n");
      FileWriteString(handle, "}\n");
      
      FileClose(handle);
      
      PrintFormat("✅ Gate learning data saved: %s", m_learning_file_path);
      return true;
   }
   
   // Helper function
   int CountPassedGates(const TradeOutcome &outcome)
   {
      int count = 0;
      for(int i = 0; i < 8; i++)
         if(outcome.passed_gates[i]) count++;
      return count;
   }
   
   // Print comprehensive report
   void PrintReport()
   {
      PrintFormat("\n🧠 === GATE LEARNING SYSTEM REPORT ===");
      
      for(int i = 0; i < 8; i++)
      {
         GateStatistics &stats = m_gate_stats[i];
         
         PrintFormat("\nGate %d: %s", i, stats.gate_name);
         PrintFormat("  Signals: %d processed | %d passed (%.1f%%) | %d blocked",
                    stats.total_signals_processed, stats.signals_passed,
                    stats.pass_rate * 100, stats.signals_blocked);
         
         if(stats.total_outcomes > 0)
         {
            PrintFormat("  Outcomes: %d trades | %.1f%% win rate | Avg: %+.2f%%",
                       stats.total_outcomes, stats.win_rate * 100, stats.avg_profit);
            PrintFormat("  Threshold: %.3f (optimal: %.3f)",
                       stats.current_threshold, stats.optimal_threshold);
         }
         
         if(stats.adjustments_made_at_gate > 0)
         {
            PrintFormat("  Adjustments: %d made | %d successful (%.1f%%)",
                       stats.adjustments_made_at_gate, stats.successful_adjustments,
                       stats.adjustment_success_rate * 100);
         }
      }
      
      PrintFormat("\n=====================================\n");
   }
};

#endif
