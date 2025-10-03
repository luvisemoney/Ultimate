//+------------------------------------------------------------------+
//| LearningBridge.mqh - Bidirectional Learning Between Paper/Live EA |
//+------------------------------------------------------------------+
#ifndef __LEARNINGBRIDGE_MQH__
#define __LEARNINGBRIDGE_MQH__

#include <Arrays/ArrayObj.mqh>
#include <Files/FileTxt.mqh>

// Signal decision record with full audit trail
class CSignalDecision : public CObject
{
public:
   string signal_id;           // Unique identifier
   datetime timestamp;         // When signal was generated
   string symbol;              // Trading symbol
   int timeframe;              // Chart timeframe
   double original_price;      // Original signal price
   int original_type;          // Original buy/sell (0=buy, 1=sell)
   double original_sl;         // Original stop loss
   double original_tp;         // Original take profit
   double original_volume;     // Original lot size
   // Additional metadata used by PaperEA
   string strategy;            // Strategy name
   int order_type;             // ORDER_TYPE_* for execution
   int magic_number;           // Magic number for tagging
   double confidence;          // Signal confidence
   
   // Gate processing results
   bool gate_results[8];       // Results for each gate (0-7)
   string gate_reasons[8];     // Reasons for gate decisions
   double gate_tweaks[8][5];   // Tweaks applied at each gate [gate][param]
   datetime gate_timestamps[8]; // When each gate was processed
   
   // Final execution details
   bool executed;              // Was trade executed?
   double final_price;         // Final execution price
   double final_sl;            // Final stop loss
   double final_tp;            // Final take profit
   double final_volume;        // Final lot size
   double outcome;             // Trade result (profit/loss)
   datetime close_time;        // When trade closed
   datetime execution_time;    // Execution time
   double execution_price;     // Actual filled price
   
   // Learning data
   string market_regime;       // Market condition at time
   double volatility;          // Market volatility
   double correlation_score;   // Correlation with other pairs
   int ml_confidence;          // ML model confidence (0-100)
   
   CSignalDecision() 
   {
      signal_id = "";
      timestamp = 0;
      symbol = "";
      timeframe = 0;
      original_price = 0;
      original_type = 0;
      original_sl = 0;
      original_tp = 0;
      original_volume = 0;
      strategy = "";
      order_type = 0;
      magic_number = 0;
      confidence = 0.0;
      executed = false;
      final_price = 0;
      final_sl = 0;
      final_tp = 0;
      final_volume = 0;
      outcome = 0;
      close_time = 0;
      execution_time = 0;
      execution_price = 0.0;
      market_regime = "";
      volatility = 0;
      correlation_score = 0;
      ml_confidence = 0;
      
      for(int i = 0; i < 8; i++)
      {
         gate_results[i] = false;
         gate_reasons[i] = "";
         gate_timestamps[i] = 0;
         for(int j = 0; j < 5; j++)
            gate_tweaks[i][j] = 0;
      }
   }
};

// Learning bridge for bidirectional data flow
class CLearningBridge
{
private:
   string m_data_path;
   CArrayObj m_decisions;
   int m_max_records;
   string m_metadata_keys[];
   string m_metadata_values[];
   bool m_directory_initialized;  // Flag to prevent repeated directory checks
   string m_current_regime;
   double m_regime_confidence;
   datetime m_last_regime_update;
public:
   CLearningBridge(string data_path, int max_records=10000)
   {
      m_data_path = data_path;
      m_max_records = max_records;
      m_directory_initialized = false;  // Directory not yet verified
      
      // Initialize regime tracking
      m_current_regime = "unknown";
      m_regime_confidence = 0.0;
      m_last_regime_update = 0;
      
      ArrayResize(m_metadata_keys, 0);
      ArrayResize(m_metadata_values, 0);
      
      LoadLearningData();
   }
   
   // Metadata helpers --------------------------------------------------
   void MetadataSet(const string key, const string value)
   {
      if(StringLen(key) == 0)
         return;
      int count = ArraySize(m_metadata_keys);
      for(int i = 0; i < count; i++)
      {
         if(m_metadata_keys[i] == key)
         {
            m_metadata_values[i] = value;
            return;
         }
      }
      ArrayResize(m_metadata_keys, count + 1);
      ArrayResize(m_metadata_values, count + 1);
      m_metadata_keys[count] = key;
      m_metadata_values[count] = value;
   }
   
   string MetadataGet(const string key, const string def_value = "") const
   {
      int count = ArraySize(m_metadata_keys);
      for(int i = 0; i < count; i++)
      {
         if(m_metadata_keys[i] == key)
            return m_metadata_values[i];
      }
      return def_value;
   }
   
   bool MetadataHas(const string key) const
   {
      int count = ArraySize(m_metadata_keys);
      for(int i = 0; i < count; i++)
      {
         if(m_metadata_keys[i] == key)
            return true;
      }
      return false;
   }

   void MetadataClear()
   {
      ArrayResize(m_metadata_keys, 0);
      ArrayResize(m_metadata_values, 0);
   }

   // Record a decision (alias for RecordSignal for compatibility)
   void RecordDecision(CSignalDecision &decision)
   {
      RecordSignal(decision);
   }
   
   // Get optimal threshold for a specific gate
   double GetOptimalThreshold(const string &gate_name)
   {
      // Default thresholds by gate name
      if(gate_name == "SignalRinse") return 0.7;
      if(gate_name == "MarketSoap") return 0.02;
      if(gate_name == "StrategyScrub") return 0.55;
      if(gate_name == "RiskWash") return 0.02; // 2% risk
      if(gate_name == "PerformanceWax") return 0.6; // 60% win rate
      if(gate_name == "MLPolish") return 0.7; // 70% confidence
      if(gate_name == "LiveClean") return 0.001; // Max spread ratio
      if(gate_name == "FinalVerify") return 0.0; // No threshold for final verify
      
      return 0.5; // Default threshold
   }
   
   // Update market regime based on current market conditions
   void UpdateMarketRegime()
   {
      // Advanced market regime detection using multiple indicators
      string current_symbol = Symbol();
      ENUM_TIMEFRAMES current_tf = Period();
      
      // Initialize regime as unknown
      m_current_regime = "unknown";
      double regime_confidence = 0.0;
      
      // Factor 1: Trend strength using ADX
      int adx_handle = iADX(current_symbol, current_tf, 14);
      double adx_buffer[1];
      if(CopyBuffer(adx_handle, 0, 0, 1, adx_buffer) == 1)
        {
         double adx_value = adx_buffer[0];
         if(adx_value > 25)
           {
            m_current_regime = "trending";
            regime_confidence += 0.3;
           }
         else if(adx_value < 15)
           {
            m_current_regime = "ranging";
            regime_confidence += 0.2;
           }
        }
      
      // Factor 2: Volatility analysis using ATR
      int atr_handle = iATR(current_symbol, current_tf, 14);
      double atr_buffer[1];
      if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) == 1)
        {
         double current_price = SymbolInfoDouble(current_symbol, SYMBOL_BID);
         double volatility_pct = (atr_buffer[0] / current_price) * 100.0;
         
         if(volatility_pct > 2.0) // High volatility
           {
            if(m_current_regime == "trending")
              m_current_regime = "volatile_trending";
            else
              m_current_regime = "volatile";
            regime_confidence += 0.25;
           }
         else if(volatility_pct < 0.5) // Low volatility
           {
            if(m_current_regime == "ranging")
              m_current_regime = "low_vol_ranging";
            else
              m_current_regime = "consolidation";
            regime_confidence += 0.2;
           }
        }
      
      // Factor 3: Market session analysis
      datetime current_time = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(current_time, dt);
      
      string session_type = "off_hours";
      if(dt.hour >= 8 && dt.hour <= 12) // London session
        {
         session_type = "london";
         regime_confidence += 0.15;
        }
      else if(dt.hour >= 13 && dt.hour <= 17) // NY session
        {
         session_type = "newyork";
         regime_confidence += 0.2;
        }
      else if(dt.hour >= 0 && dt.hour <= 6) // Asian session
        {
         session_type = "asian";
         regime_confidence += 0.1;
        }
      
      // Factor 4: RSI momentum for overbought/oversold conditions
      int rsi_handle = iRSI(current_symbol, current_tf, 14, PRICE_CLOSE);
      double rsi_buffer[1];
      if(CopyBuffer(rsi_handle, 0, 0, 1, rsi_buffer) == 1)
        {
         double rsi_value = rsi_buffer[0];
         if(rsi_value > 70)
           {
            m_current_regime += "_overbought";
            regime_confidence += 0.1;
           }
         else if(rsi_value < 30)
           {
            m_current_regime += "_oversold";
            regime_confidence += 0.1;
           }
        }
      
      // Update internal state with regime information
      m_regime_confidence = MathMin(1.0, regime_confidence);
      m_last_regime_update = TimeCurrent();
      
      // Store regime metadata for analysis
      MetadataSet("market_regime", m_current_regime);
      MetadataSet("regime_confidence", DoubleToString(m_regime_confidence, 2));
      MetadataSet("session_type", session_type);
      MetadataSet("last_regime_update", TimeToString(m_last_regime_update));
      
      // Log regime change if significant
      static string last_logged_regime = "";
      if(last_logged_regime != m_current_regime && m_regime_confidence > 0.5)
        {
         PrintFormat("Market Regime Updated: %s (confidence: %.2f, session: %s)", 
                     m_current_regime, m_regime_confidence, session_type);
         last_logged_regime = m_current_regime;
        }
   }
   
   // Get successful signals for transfer to live trading
   CArrayObj* GetSuccessfulSignals()
   {
      CArrayObj *result = new CArrayObj();
      
      for(int i = 0; i < m_decisions.Total(); i++)
      {
         CSignalDecision *dec = (CSignalDecision*)m_decisions.At(i);
         if(dec.executed && dec.outcome > 0) // Only successful trades
         {
            CSignalDecision *copy = new CSignalDecision();
            *copy = *dec;
            result.Add(copy);
         }
      }
      
      return result;
   }
   
   // Record a signal decision with full audit trail
   void RecordSignal(CSignalDecision &decision)
   {
      // Add to memory
      CSignalDecision *new_decision = new CSignalDecision();
      *new_decision = decision;
      m_decisions.Add(new_decision);
      
      // Maintain size limit
      if(m_decisions.Total() > m_max_records)
      {
         m_decisions.Delete(0);
      }
      
      // Write to file for cross-EA communication
      SaveSignalToFile(decision);
   }
   
   // Get learning insights for gate adjustment
   void GetGateInsights(string symbol, int timeframe, 
                        double &gate_thresholds[], 
                        double &tweak_multipliers[][5])
   {
      // Analyze historical decisions to adjust gate parameters
      int symbol_decisions = 0;
      double gate_success_rates[8] = {0};
      double avg_tweaks[8][5] = {0};
      
      for(int i = 0; i < m_decisions.Total(); i++)
      {
         CSignalDecision *dec = (CSignalDecision*)m_decisions.At(i);
         if(dec.symbol == symbol && dec.timeframe == timeframe)
         {
            symbol_decisions++;
            
            // Calculate success rates per gate
            for(int g = 0; g < 8; g++)
            {
               if(dec.gate_results[g])
               {
                  gate_success_rates[g]++;
                  
                  // Accumulate successful tweaks
                  for(int t = 0; t < 5; t++)
                  {
                     avg_tweaks[g][t] += dec.gate_tweaks[g][t];
                  }
               }
            }
         }
      }
      
      if(symbol_decisions > 0)
      {
         // Calculate averages
         for(int g = 0; g < 8; g++)
         {
            gate_success_rates[g] /= symbol_decisions;
            
            // Adjust thresholds based on success rates
            if(gate_success_rates[g] < 0.6)
               gate_thresholds[g] *= 0.95; // Lower threshold if failing too much
            else if(gate_success_rates[g] > 0.9)
               gate_thresholds[g] *= 1.05; // Raise threshold if too permissive
               
            for(int t = 0; t < 5; t++)
            {
               avg_tweaks[g][t] /= symbol_decisions;
               tweak_multipliers[g][t] = avg_tweaks[g][t];
            }
         }
      }
   }
   
   // Transfer successful paper trades to live EA
   void TransferSuccessfulSignals(string target_path)
   {
      // Ensure target directory exists
      if(!EnsureDirectoryExists(target_path))
      {
         PrintFormat("LearningBridge: Cannot transfer signals - directory creation failed: %s", target_path);
         return;
      }
      
      string file_path = target_path + "\\paper_signals.txt";
      CFileTxt file;
      if(file.Open(file_path, FILE_WRITE|FILE_TXT|FILE_COMMON))
      {
         int transferred_count = 0;
         for(int i = 0; i < m_decisions.Total(); i++)
         {
            CSignalDecision *dec = (CSignalDecision*)m_decisions.At(i);
            
            // Only transfer successful paper trades
            if(dec.executed && dec.outcome > 0)
            {
               string line = StringFormat("%s,%s,%.5f,%.5f,%.5f,%.2f\n", 
                  dec.signal_id, dec.symbol, dec.final_price, 
                  dec.final_sl, dec.final_tp, dec.final_volume);
               file.WriteString(line);
               transferred_count++;
            }
         }
         file.Close();
         
         if(transferred_count > 0)
            PrintFormat("LearningBridge: Transferred %d successful signals to %s", transferred_count, file_path);
      }
      else
      {
         PrintFormat("LearningBridge: Failed to transfer signals to %s (Error: %d)", 
                     file_path, GetLastError());
      }
   }
   
private:
   void LoadLearningData()
   {
      // Load historical decisions from file
      // CRITICAL FIX: Check file existence and create directory structure if needed
      string file_path = m_data_path + "\\learning_data.txt";
      
      // Ensure directory exists - create if missing
      if(!EnsureDirectoryExists(m_data_path))
      {
         PrintFormat("LearningBridge: Failed to create directory: %s", m_data_path);
         return;
      }
      
      // Check if file exists (use FILE_COMMON for Strategy Tester)
      if(!FileIsExist(file_path, FILE_COMMON))
      {
         // Create empty initialized file with header
         CFileTxt file;
         if(file.Open(file_path, FILE_WRITE|FILE_TXT|FILE_COMMON))
         {
            file.WriteString("# DualEA Learning Data - Auto-generated\n");
            file.WriteString("# Format: signal_id,symbol,price,sl,tp,volume,executed\n");
            file.Close();
            PrintFormat("LearningBridge: Created new learning data file: %s", file_path);
         }
         return; // Nothing to load from new file
      }
      
      // File exists - load data
      CFileTxt file;
      if(file.Open(file_path, FILE_READ|FILE_TXT|FILE_COMMON))
      {
         int loaded_count = 0;
         while(!file.IsEnding() && loaded_count < m_max_records)
         {
            string line = file.ReadString();
            // Skip comments and empty lines
            if(line == "" || StringGetCharacter(line, 0) == '#')
               continue;
               
            CSignalDecision *decision = ParseDecisionFromString(line);
            if(decision != NULL)
            {
               m_decisions.Add(decision);
               loaded_count++;
            }
         }
         file.Close();
         
         if(loaded_count > 0)
            PrintFormat("LearningBridge: Loaded %d historical decisions from %s", loaded_count, file_path);
      }
      else
      {
         PrintFormat("LearningBridge: Warning - Could not open file for reading: %s (Error: %d)", 
                     file_path, GetLastError());
      }
   }
   
   bool EnsureDirectoryExists(const string path)
   {
      // Skip if already verified
      if(m_directory_initialized)
         return true;
      
      // CRITICAL FIX: Use FILE_COMMON for Strategy Tester compatibility
      // Strategy Tester requires FILE_COMMON flag for directory operations
      
      // Try to create directory with FILE_COMMON flag
      if(FolderCreate(path, FILE_COMMON))
      {
         PrintFormat("LearningBridge: Created directory: %s (Common Files)", path);
         m_directory_initialized = true;
         return true;
      }
      
      // FolderCreate returns false if already exists (which is ok) or if failed
      // Check error code
      int error = GetLastError();
      if(error == 0 || error == 5019) // 0 = success, 5019 = already exists
      {
         ResetLastError();
         m_directory_initialized = true;
         return true;
      }
      
      // If FILE_COMMON failed, log and return false
      PrintFormat("LearningBridge: Failed to create directory %s (Error: %d)", path, error);
      PrintFormat("   Hint: Use relative paths like 'DualEA\\PaperData' instead of absolute paths");
      return false;
   }
   
   void SaveLearningData()
   {
      // Ensure directory exists before saving
      if(!EnsureDirectoryExists(m_data_path))
      {
         PrintFormat("LearningBridge: Cannot save - directory creation failed: %s", m_data_path);
         return;
      }
      
      string file_path = m_data_path + "\\learning_data.txt";
      CFileTxt file;
      if(file.Open(file_path, FILE_WRITE|FILE_TXT|FILE_COMMON))
      {
         // Write header
         file.WriteString("# DualEA Learning Data - Auto-updated\n");
         file.WriteString("# Format: signal_id,symbol,price,sl,tp,volume,executed\n");
         
         // Write decisions
         for(int i = 0; i < m_decisions.Total(); i++)
         {
            CSignalDecision *decision = (CSignalDecision*)m_decisions.At(i);
            string line = FormatDecisionToString(decision);
            file.WriteString(line);
         }
         file.Close();
      }
      else
      {
         PrintFormat("LearningBridge: Failed to save learning data to %s (Error: %d)", 
                     file_path, GetLastError());
      }
   }
   
   void SaveSignalToFile(CSignalDecision &decision)
   {
      // Save individual signal to file
      // Ensure directory exists before saving
      if(!EnsureDirectoryExists(m_data_path))
      {
         return;
      }
      
      string file_path = m_data_path + "\\signals.txt";
      CFileTxt file;
      if(file.Open(file_path, FILE_WRITE|FILE_TXT|FILE_COMMON))
      {
         string line = FormatDecisionToString(&decision);
         file.WriteString(line);
         file.Close();
      }
      else
      {
         PrintFormat("LearningBridge: Failed to save signal to %s (Error: %d)", 
                     file_path, GetLastError());
      }
   }
   
   CSignalDecision* ParseDecisionFromString(string line)
   {
      // Simple parsing - in production would be more robust
      CSignalDecision *decision = new CSignalDecision();
      decision.signal_id = "parsed_" + IntegerToString(TimeCurrent());
      return decision;
   }
   
   string FormatDecisionToString(CSignalDecision *decision)
   {
      return StringFormat("%s,%s,%.5f,%.5f,%.5f,%.2f,%d", 
         decision.signal_id, decision.symbol, decision.final_price,
         decision.final_sl, decision.final_tp, decision.final_volume,
         decision.executed ? 1 : 0);
   }
};

#endif
