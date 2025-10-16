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
   // Learn optimal parameters from trade history
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
         
         // Adjust SL/TP based on profitability
         if(avg_profit > 0)
         {
            // Profitable - can afford to be slightly more aggressive
            policy.sl_scale = MathMin(1.5, policy.sl_scale * 1.05);
            policy.tp_scale = MathMax(1.0, policy.tp_scale * 1.05);
         }
         else
         {
            // Not profitable - tighten up
            policy.sl_scale = MathMax(0.7, policy.sl_scale * 0.95);
            policy.tp_scale = MathMin(2.0, policy.tp_scale * 0.95);
         }
         
         // Adjust confidence threshold
         if(actual_win_rate > 0.6)
         {
            // Good performance - can lower threshold slightly
            policy.min_confidence = MathMax(0.3, policy.min_confidence * 0.98);
         }
         else if(actual_win_rate < 0.4)
         {
            // Poor performance - raise threshold
            policy.min_confidence = MathMin(0.8, policy.min_confidence * 1.02);
         }
         
         policy.last_update = TimeCurrent();
      }
   }
   
   // Write policy to JSON file
   bool WritePolicyFile()
   {
      int handle = FileOpen(m_policy_file_path, FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_ANSI);
      if(handle == INVALID_HANDLE)
      {
         PrintFormat("❌ PolicyUpdater: Failed to open policy file for writing: %s (Error: %d)", 
                    m_policy_file_path, GetLastError());
         return false;
      }
      
      // Write JSON header
      FileWriteString(handle, "{\n");
      FileWriteString(handle, "  \"version\": \"1.0\",\n");
      FileWriteString(handle, StringFormat("  \"last_updated\": \"%s\",\n", TimeToString(TimeCurrent())));
      FileWriteString(handle, StringFormat("  \"total_policies\": %d,\n", ArraySize(m_policy_keys)));
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
               "      \"win_rate\": %.2f\n"
               "    }",
               policy.strategy, policy.symbol, policy.timeframe,
               policy.probability, policy.sl_scale, policy.tp_scale,
               policy.trail_atr_mult, policy.min_confidence,
               policy.total_trades, policy.winning_trades,
               policy.total_trades > 0 ? (double)policy.winning_trades/policy.total_trades : 0.0
            );
            
            FileWriteString(handle, entry);
            count++;
         }
      }
      
      FileWriteString(handle, "\n  ]\n");
      FileWriteString(handle, "}\n");
      
      FileClose(handle);
      
      PrintFormat("✅ PolicyUpdater: Updated policy file with %d entries", count);
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
      
      // Initialize default policies for common combinations
      InitializeDefaultPolicies();
      
      // Write initial policy file
      if(WritePolicyFile())
         m_successful_updates++;
      
      PrintFormat("🎯 PolicyUpdater initialized: auto-update every %d minutes", 
                  m_update_interval_minutes);
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
