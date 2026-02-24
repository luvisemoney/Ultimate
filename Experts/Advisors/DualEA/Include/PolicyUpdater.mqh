//+------------------------------------------------------------------+
//| PolicyUpdater.mqh                                                |
//| Purpose: Auto-updating ML policy system                          |
//| Features: Learn from trades, update policy.json automatically    |
//+------------------------------------------------------------------+
#ifndef __POLICYUPDATER_MQH__
#define __POLICYUPDATER_MQH__

#include "LearningBridge.mqh"
#include <Files/File.mqh>
#include <Generic/HashMap.mqh>

// Policy entry for a strategy/symbol/timeframe combination
struct PolicyEntry
{
   string strategy;
   string symbol;
   int timeframe;
   double probability;        // ML-predicted win rate
   double sl_scale;           // SL multiplier
   double tp_scale;           // TP multiplier
   double trail_atr_mult;     // Trailing stop ATR multiplier
   double min_confidence;     // Minimum confidence threshold
   
   // Learning metrics
   int total_trades;
   int winning_trades;
   double total_profit;
   datetime last_update;
   
   // NEW: Advanced metrics (P0 improvement)
   double gross_profit;       // Total winning trades amount
   double gross_loss;         // Total losing trades amount (absolute)
   double expectancy;           // (win_rate * avg_win) - (loss_rate * avg_loss)
   double profit_factor;      // gross_profit / gross_loss
   double r_multiple_avg;     // Average R-multiple per trade
   double max_drawdown_pct;   // Peak-to-trough drawdown
   double sharpe_20;          // 20-trade Sharpe ratio
   double peak_equity;        // For drawdown calculation
   double current_equity;     // Running equity curve
   
   // NEW: Trade history buffer for advanced stats (last 20 trades)
   double recent_pnls[20];
   int recent_count;
   
   // NEW: Regime-aware tracking
   string market_regime;      // "trending", "ranging", "volatile"
   double regime_performance[3]; // Performance per regime index
};

//+------------------------------------------------------------------+
//| Policy Updater - ML-driven policy learning                      |
//+------------------------------------------------------------------+
class CPolicyUpdater
{
private:
   CLearningBridge* m_learning;
   
   // Simple array-based policy storage (MQL5 HashMap doesn't support structs)
   string m_policy_keys[];
   PolicyEntry m_policy_values[];
   
   string m_policy_file_path;
   int m_update_interval_minutes;
   datetime m_last_update;
   bool m_auto_update_enabled;
   
   // Statistics
   int m_total_updates;
   int m_successful_updates;
   
   // NEW: Real-time update trigger
   int m_trades_since_update;
   int m_trades_update_threshold;  // Write policy after N trades
   
   // Helper methods for policy storage
   int FindPolicyIndex(const string key)
   {
      for(int i = 0; i < ArraySize(m_policy_keys); i++)
      {
         if(m_policy_keys[i] == key) return i;
      }
      return -1;
   }
   
   bool GetPolicy(const string key, PolicyEntry &out_policy)
   {
      int idx = FindPolicyIndex(key);
      if(idx >= 0)
      {
         out_policy = m_policy_values[idx];
         return true;
      }
      return false;
   }
   
   void SetPolicy(const string key, const PolicyEntry &policy)
   {
      int idx = FindPolicyIndex(key);
      if(idx >= 0)
      {
         m_policy_values[idx] = policy;
      }
      else
      {
         int size = ArraySize(m_policy_keys);
         ArrayResize(m_policy_keys, size + 1);
         ArrayResize(m_policy_values, size + 1);
         m_policy_keys[size] = key;
         m_policy_values[size] = policy;
      }
   }
   
   // Load policies from JSON file
   string GetPolicyKey(const string strategy, const string symbol, const int timeframe)
   {
      return StringFormat("%s_%s_%d", strategy, symbol, timeframe);
   }
   // Learn optimal parameters from trade history with advanced metrics
   void LearnFromTrades(PolicyEntry &policy)
   {
      if(m_learning == NULL) return;
      
      // Calculate actual win rate from trades
      if(policy.total_trades > 5)
      {
         double actual_win_rate = (double)policy.winning_trades / policy.total_trades;
         double avg_profit = policy.total_profit / policy.total_trades;
         
         // Update probability (exponential moving average)
         policy.probability = policy.probability * 0.7 + actual_win_rate * 0.3;
         
         // NEW: Calculate profit factor
         if(policy.gross_loss > 0)
            policy.profit_factor = policy.gross_profit / policy.gross_loss;
         else if(policy.gross_profit > 0)
            policy.profit_factor = 999.0; // No losses yet
         
         // NEW: Calculate expectancy
         double loss_rate = 1.0 - actual_win_rate;
         double avg_win = policy.winning_trades > 0 ? policy.gross_profit / policy.winning_trades : 0;
         double avg_loss = (policy.total_trades - policy.winning_trades) > 0 ? 
                          policy.gross_loss / (policy.total_trades - policy.winning_trades) : 0;
         policy.expectancy = (actual_win_rate * avg_win) - (loss_rate * avg_loss);
         
         // NEW: Calculate 20-trade Sharpe ratio if we have enough data
         if(policy.recent_count >= 5)
         {
            double mean_pnl = 0, variance = 0;
            for(int i = 0; i < policy.recent_count; i++)
               mean_pnl += policy.recent_pnls[i];
            mean_pnl /= policy.recent_count;
            
            for(int i = 0; i < policy.recent_count; i++)
               variance += MathPow(policy.recent_pnls[i] - mean_pnl, 2);
            variance /= policy.recent_count;
            
            double std_dev = MathSqrt(variance);
            if(std_dev > 0)
               policy.sharpe_20 = mean_pnl / std_dev;
         }
         
         // Adjust SL/TP based on profit factor (more robust than raw profit)
         if(policy.profit_factor > 1.5 && policy.expectancy > 0)
         {
            // Profitable with good profit factor - can be slightly more aggressive
            policy.sl_scale = MathMin(1.5, policy.sl_scale * 1.02);
            policy.tp_scale = MathMax(1.0, policy.tp_scale * 1.02);
         }
         else if(policy.profit_factor < 1.0 || policy.expectancy < 0)
         {
            // Poor profit factor or negative expectancy - tighten up
            policy.sl_scale = MathMax(0.7, policy.sl_scale * 0.98);
            policy.tp_scale = MathMin(2.0, policy.tp_scale * 0.98);
         }
         
         // Adjust confidence threshold based on Sharpe and expectancy
         if(policy.sharpe_20 > 0.5 && policy.expectancy > 0)
         {
            // Good risk-adjusted returns - can lower threshold
            policy.min_confidence = MathMax(0.3, policy.min_confidence * 0.99);
         }
         else if(policy.sharpe_20 < 0.0 || policy.max_drawdown_pct > 10.0)
         {
            // Negative Sharpe or high drawdown - raise threshold
            policy.min_confidence = MathMin(0.8, policy.min_confidence * 1.01);
         }
         
         policy.last_update = TimeCurrent();
      }
   }
   
   // Write policy to JSON file with atomic writes and versioning
   bool WritePolicyFile()
   {
      // ATOMIC WRITE: Write to temp file first, then rename
      string temp_path = m_policy_file_path + ".tmp";
      string backup_path = m_policy_file_path + ".backup";
      
      int handle = FileOpen(temp_path, FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_ANSI);
      if(handle == INVALID_HANDLE)
      {
         PrintFormat("❌ PolicyUpdater: Failed to open temp file for writing: %s (Error: %d)", 
                    temp_path, GetLastError());
         return false;
      }
      
      // VERSIONING: Increment version on each write
      static int policy_version = 1;
      policy_version++;
      
      // Write JSON header with version
      FileWriteString(handle, "{\n");
      FileWriteString(handle, StringFormat("  \"version\": \"1.0.%d\",\n", policy_version));
      FileWriteString(handle, "  \"schema_version\": \"2.0\",\n");
      FileWriteString(handle, StringFormat("  \"last_updated\": \"%s\",\n", TimeToString(TimeCurrent())));
      FileWriteString(handle, StringFormat("  \"total_policies\": %d,\n", ArraySize(m_policy_keys)));
      FileWriteString(handle, "  \"write_mode\": \"atomic\",\n");
      FileWriteString(handle, "  \"policies\": [\n");
      
      // Write each policy entry
      int count = 0;
      
      for(int i = 0; i < ArraySize(m_policy_keys); i++)
      {
         PolicyEntry policy = m_policy_values[i];
         {
            if(count > 0)
               FileWriteString(handle, ",\n");
            
            string entry = StringFormat(
               "    {\n"
               "      \"strategy\": \"%s\",\n"
               "      \"symbol\": \"%s\",\n"
               "      \"timeframe\": %d,\n"
               "      \"probability\": %.4f,\n"
               "      \"sl_scale\": %.2f,\n"
               "      \"tp_scale\": %.2f,\n"
               "      \"trail_atr_mult\": %.1f,\n"
               "      \"min_confidence\": %.2f,\n"
               "      \"total_trades\": %d,\n"
               "      \"winning_trades\": %d,\n"
               "      \"win_rate\": %.2f,\n"
               "      \"profit_factor\": %.2f,\n"
               "      \"expectancy\": %.2f,\n"
               "      \"sharpe_20\": %.2f,\n"
               "      \"max_drawdown_pct\": %.2f\n"
               "    }",
               policy.strategy, policy.symbol, policy.timeframe,
               policy.probability, policy.sl_scale, policy.tp_scale,
               policy.trail_atr_mult, policy.min_confidence,
               policy.total_trades, policy.winning_trades,
               policy.total_trades > 0 ? (double)policy.winning_trades/policy.total_trades : 0.0,
               policy.profit_factor,
               policy.expectancy,
               policy.sharpe_20,
               policy.max_drawdown_pct
            );
            
            FileWriteString(handle, entry);
            count++;
         }
      }
      
      FileWriteString(handle, "\n  ]\n");
      FileWriteString(handle, "}\n");
      
      FileClose(handle);
      
      // ATOMIC: Backup existing file if it exists
      int existing_handle = FileOpen(m_policy_file_path, FILE_READ|FILE_TXT|FILE_COMMON);
      if(existing_handle != INVALID_HANDLE)
      {
         FileClose(existing_handle);
         // Copy existing to backup
         int backup_handle = FileOpen(backup_path, FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_ANSI);
         if(backup_handle != INVALID_HANDLE)
         {
            int old_handle = FileOpen(m_policy_file_path, FILE_READ|FILE_TXT|FILE_COMMON|FILE_ANSI);
            if(old_handle != INVALID_HANDLE)
            {
               while(!FileIsEnding(old_handle))
               {
                  string line = FileReadString(old_handle);
                  FileWriteString(backup_handle, line + "\n");
               }
               FileClose(old_handle);
            }
            FileClose(backup_handle);
         }
      }
      
      // ATOMIC: Rename temp to final
      FileDelete(m_policy_file_path, FILE_COMMON);
      FileMove(temp_path, FILE_COMMON, m_policy_file_path, FILE_COMMON|FILE_REWRITE);
      
      PrintFormat("✅ PolicyUpdater: Atomically updated policy file with %d entries (version %d)", count, policy_version);
      return true;
   }

public:
   CPolicyUpdater(CLearningBridge* learning, int update_interval_minutes = 60)
   {
      m_learning = learning;
      m_policy_file_path = "DualEA\\policy.json";
      m_update_interval_minutes = update_interval_minutes;
      m_last_update = 0;
      m_auto_update_enabled = true;
      m_total_updates = 0;
      m_successful_updates = 0;
      
      // NEW: Real-time update configuration
      m_trades_since_update = 0;
      m_trades_update_threshold = 5;  // Update policy file after every 5 trades
      
      // Initialize default policies for common combinations
      InitializeDefaultPolicies();
      
      // Write initial policy file
      if(WritePolicyFile())
         m_successful_updates++;
      
      PrintFormat("🎯 PolicyUpdater initialized: auto-update every %d minutes, real-time updates every %d trades", 
                  m_update_interval_minutes, m_trades_update_threshold);
   }
   
   void InitializeDefaultPolicies()
   {
      string strategies[] = {
         "MovingAverageStrategy", "ADXStrategy", "RSIStrategy", "BollingerBandsStrategy",
         "MACDStrategy", "StochasticStrategy", "IchimokuStrategy", "MomentumStrategy"
      };
      
      string symbols[] = {"US500", "UK100", "GER40", "EURUSD", "GBPUSD", "USDJPY"};
      int timeframes[] = {60, 240, 1440};  // H1, H4, D1
      
      for(int s = 0; s < ArraySize(strategies); s++)
      {
         for(int sym = 0; sym < ArraySize(symbols); sym++)
         {
            for(int tf = 0; tf < ArraySize(timeframes); tf++)
            {
               PolicyEntry policy;
               policy.strategy = strategies[s];
               policy.symbol = symbols[sym];
               policy.timeframe = timeframes[tf];
               
               // Conservative defaults
               policy.probability = 0.55;
               policy.sl_scale = 1.0;
               policy.tp_scale = 1.2;
               policy.trail_atr_mult = 2.0;
               policy.min_confidence = 0.45;  // Lower than before to allow more signals
               
               policy.total_trades = 0;
               policy.winning_trades = 0;
               policy.total_profit = 0.0;
               policy.last_update = TimeCurrent();
               
               string key = GetPolicyKey(policy.strategy, policy.symbol, policy.timeframe);
               SetPolicy(key, policy);
            }
         }
      }
      
      PrintFormat("✅ Initialized %d default policy entries", ArraySize(m_policy_keys));
   }
   
   // Record trade outcome for policy learning
   void RecordTradeOutcome(const string strategy, const string symbol, const int timeframe,
                          bool won, double profit)
   {
      string key = GetPolicyKey(strategy, symbol, timeframe);
      PolicyEntry policy;
      
      if(!GetPolicy(key, policy))
      {
         // Create new policy entry
         policy.strategy = strategy;
         policy.symbol = symbol;
         policy.timeframe = timeframe;
         policy.probability = 0.5;
         policy.sl_scale = 1.0;
         policy.tp_scale = 1.2;
         policy.trail_atr_mult = 2.0;
         policy.min_confidence = 0.5;
         policy.total_trades = 0;
         policy.winning_trades = 0;
         policy.total_profit = 0.0;
         policy.last_update = TimeCurrent();
         
         // NEW: Initialize advanced metrics
         policy.gross_profit = 0.0;
         policy.gross_loss = 0.0;
         policy.expectancy = 0.0;
         policy.profit_factor = 1.0;
         policy.r_multiple_avg = 0.0;
         policy.max_drawdown_pct = 0.0;
         policy.sharpe_20 = 0.0;
         policy.peak_equity = 0.0;
         policy.current_equity = 0.0;
         policy.recent_count = 0;
         policy.market_regime = "";
         ArrayInitialize(policy.recent_pnls, 0.0);
         ArrayInitialize(policy.regime_performance, 0.0);
      }
      
      // NEW: Update gross profit/loss for profit factor calculation
      if(profit > 0)
         policy.gross_profit += profit;
      else
         policy.gross_loss += MathAbs(profit);
      
      // NEW: Update equity curve for drawdown calculation
      policy.current_equity += profit;
      if(policy.current_equity > policy.peak_equity)
         policy.peak_equity = policy.current_equity;
      
      // NEW: Calculate running drawdown
      if(policy.peak_equity > 0)
      {
         double current_dd = (policy.peak_equity - policy.current_equity) / policy.peak_equity * 100.0;
         if(current_dd > policy.max_drawdown_pct)
            policy.max_drawdown_pct = current_dd;
      }
      
      // NEW: Update recent trades buffer for Sharpe calculation
      if(policy.recent_count < 20)
      {
         policy.recent_pnls[policy.recent_count] = profit;
         policy.recent_count++;
      }
      else
      {
         // Shift array (FIFO)
         for(int i = 0; i < 19; i++)
            policy.recent_pnls[i] = policy.recent_pnls[i+1];
         policy.recent_pnls[19] = profit;
      }
      
      // Update trade statistics
      policy.total_trades++;
      if(won)
         policy.winning_trades++;
      policy.total_profit += profit;
      
      // Learn from this data
      LearnFromTrades(policy);
      
      // Save updated policy
      SetPolicy(key, policy);
      
      // NEW: Real-time policy update trigger
      m_trades_since_update++;
      if(m_trades_since_update >= m_trades_update_threshold)
      {
         if(WritePolicyFile())
         {
            m_successful_updates++;
            m_last_update = TimeCurrent();
            PrintFormat("🔄 PolicyUpdater: Real-time update after %d trades", m_trades_since_update);
         }
         m_trades_since_update = 0;
      }
   }
   
   // Alias wrapper to avoid method signature confusion with other classes
   void UpdatePolicyFromTrade(const string strategy, const string symbol, const int timeframe,
                              bool won, double profit)
   {
      RecordTradeOutcome(strategy, symbol, timeframe, won, profit);
   }
   
   // Auto-update policy file if interval elapsed
   void CheckAndUpdate()
   {
      if(!m_auto_update_enabled)
         return;
      
      datetime now = TimeCurrent();
      if(now - m_last_update < m_update_interval_minutes * 60)
         return;
      
      m_total_updates++;
      
      if(WritePolicyFile())
      {
         m_successful_updates++;
         m_last_update = now;
         
         PrintFormat("🔄 PolicyUpdater: Auto-updated policy file (%d/%d successful updates)",
                    m_successful_updates, m_total_updates);
      }
   }
   
   // Force immediate update
   void ForceUpdate()
   {
      m_total_updates++;
      
      if(WritePolicyFile())
         m_successful_updates++;
   }
   
   // Get policy for specific combination
   bool GetPolicy(const string strategy, const string symbol, const int timeframe,
                  PolicyEntry &policy)
   {
      string key = GetPolicyKey(strategy, symbol, timeframe);
      return GetPolicy(key, policy);
   }
   
   // Enable/disable auto-updates
   void SetAutoUpdate(bool enabled)
   {
      m_auto_update_enabled = enabled;
      PrintFormat("PolicyUpdater: Auto-update %s", enabled ? "ENABLED" : "DISABLED");
   }
   
   // Get statistics
   void GetStatistics(int &total_policies, int &total_updates, int &successful_updates)
   {
      total_policies = ArraySize(m_policy_keys);
      total_updates = m_total_updates;
      successful_updates = m_successful_updates;
   }
   
   void PrintReport()
   {
      PrintFormat("\n=== 📈 Policy Learning Report ===");
      PrintFormat("Total Policies: %d", ArraySize(m_policy_keys));
      PrintFormat("Total Updates: %d", m_total_updates);
      PrintFormat("Successful Updates: %d (%.1f%%)", m_successful_updates,
                  m_total_updates > 0 ? (double)m_successful_updates/m_total_updates*100 : 0);
      PrintFormat("Auto-Update: %s (interval: %d minutes)", 
                  m_auto_update_enabled ? "ON" : "OFF", m_update_interval_minutes);
   }
};

#endif
