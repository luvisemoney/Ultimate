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
      executed = false;
      final_price = 0;
      final_sl = 0;
      final_tp = 0;
      final_volume = 0;
      outcome = 0;
      close_time = 0;
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
   
public:
   CLearningBridge(string data_path, int max_records=10000)
   {
      m_data_path = data_path;
      m_max_records = max_records;
      LoadLearningData();
   }
   
   ~CLearningBridge()
   {
      SaveLearningData();
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
      // This would analyze market conditions and update internal state
      // For now, it's a placeholder that does nothing
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
      CFileTxt file;
      if(file.Open(target_path + "\\paper_signals.txt", FILE_WRITE|FILE_TXT))
      {
         for(int i = 0; i < m_decisions.Total(); i++)
         {
            CSignalDecision *dec = (CSignalDecision*)m_decisions.At(i);
            
            // Only transfer successful paper trades
            if(dec.executed && dec.outcome > 0)
            {
               string line = StringFormat("%s,%s,%.5f,%.5f,%.5f,%.2f", 
                  dec.signal_id, dec.symbol, dec.final_price, 
                  dec.final_sl, dec.final_tp, dec.final_volume);
               file.WriteString(line);
            }
         }
         file.Close();
      }
   }
   
private:
   void LoadLearningData()
   {
      // Load historical decisions from file
      CFileTxt file;
      if(file.Open(m_data_path + "\\learning_data.txt", FILE_READ|FILE_TXT))
      {
         while(!file.IsEnding())
         {
            string line = file.ReadString();
            if(line != "")
            {
               CSignalDecision *decision = ParseDecisionFromString(line);
               if(decision != NULL)
                  m_decisions.Add(decision);
            }
         }
         file.Close();
      }
   }
   
   void SaveLearningData()
   {
      CFileTxt file;
      if(file.Open(m_data_path + "\\learning_data.txt", FILE_WRITE|FILE_TXT))
      {
         for(int i = 0; i < m_decisions.Total(); i++)
         {
            CSignalDecision *decision = (CSignalDecision*)m_decisions.At(i);
            string line = FormatDecisionToString(decision);
            file.WriteString(line);
         }
         file.Close();
      }
   }
   
   void SaveSignalToFile(CSignalDecision &decision)
   {
      // Save individual signal to file
      CFileTxt file;
      if(file.Open(m_data_path + "\\signals.txt", FILE_WRITE|FILE_TXT))
      {
         string line = FormatDecisionToString(&decision);
         file.WriteString(line);
         file.Close();
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
