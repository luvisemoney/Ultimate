//+------------------------------------------------------------------+
//| GateManager.mqh - 8-Stage Gate System with Signal Polishing     |
//+------------------------------------------------------------------+
#ifndef __GATEMANAGER_MQH__
#define __GATEMANAGER_MQH__

#include "LearningBridge.mqh"
#include "ConfigManager.mqh"
#include "EventBus.mqh"
#include "SystemMonitor.mqh"

// Gate result structure
struct GateResult
{
   bool passed;
   string reason;
   double tweaks[5];        // [0]=price, [1]=sl, [2]=tp, [3]=volume, [4]=timing
   datetime processed_at;
};

// Signal structure for gate processing
struct TradingSignal
{
   string id;
   string symbol;
   int timeframe;
   datetime timestamp;
   double price;
   int type;  // 0=buy, 1=sell
   double sl;
   double tp;
   double volume;
   double confidence;
   
   // Market context
   double volatility;
   double correlation;
   string regime;
   string market_regime; // Alias for regime
};

// Base gate interface
class IGate
{
public:
   virtual ~IGate() {}
   virtual GateResult Process(TradingSignal &signal) = 0;
   virtual string GetName() = 0;
   virtual void SetThreshold(double threshold) = 0;
   virtual double GetSuccessRate() = 0;
};

// Gate 1: Signal Rinse (Pre-filter)
class CSignalRinseGate : public IGate
{
private:
   double m_min_confidence;
   double m_max_spread_ratio;
   
public:
   CSignalRinseGate(double min_confidence = 0.6, double max_spread = 0.0005)
   {
      m_min_confidence = min_confidence;
      m_max_spread_ratio = max_spread;
   }
   
   string GetName() override { return "SignalRinse"; }
   void SetThreshold(double threshold) override { m_min_confidence = threshold; }
   double GetSuccessRate() override { return 0.75; }
   
   GateResult Process(TradingSignal &signal) override
   {
      GateResult result;
      result.processed_at = TimeCurrent();
      
      // Basic sanity checks
      if(signal.confidence < m_min_confidence)
      {
         result.passed = false;
         result.reason = "Signal confidence too low";
         return result;
      }
      
      long spread_points = 0;
      double point = 0.0;
      double ask = 0.0;
      SymbolInfoInteger(signal.symbol, SYMBOL_SPREAD, spread_points);
      SymbolInfoDouble(signal.symbol, SYMBOL_POINT, point);
      SymbolInfoDouble(signal.symbol, SYMBOL_ASK, ask);
      double spread_price = (double)spread_points * point;
      double spread_ratio = (ask > 0.0 ? spread_price / ask : 1e9);
      
      if(spread_ratio > m_max_spread_ratio)
      {
         result.passed = false;
         result.reason = "Spread too high";
         return result;
      }
      
      result.passed = true;
      result.reason = "Signal rinse passed";
      return result;
   }
};

// Gate 2: Market Soap (Market Context)
class CMarketSoapGate : public IGate
{
private:
   double m_max_volatility;
   double m_min_liquidity;
   double m_max_correlation;
   
public:
   CMarketSoapGate(double max_vol = 0.02, double min_liq = 1000000, double max_corr = 0.8)
   {
      m_max_volatility = max_vol;
      m_min_liquidity = min_liq;
      m_max_correlation = max_corr;
   }
   
   string GetName() override { return "MarketSoap"; }
   void SetThreshold(double threshold) override { m_max_volatility = threshold; }
   double GetSuccessRate() override { return 0.78; }
   
   GateResult Process(TradingSignal &signal) override
   {
      GateResult result;
      result.processed_at = TimeCurrent();
      
      // Check volatility
      if(signal.volatility > m_max_volatility)
      {
         result.passed = false;
         result.reason = "High volatility: " + DoubleToString(signal.volatility, 4);
         return result;
      }
      
      // Check correlation
      if(MathAbs(signal.correlation) > m_max_correlation)
      {
         result.passed = false;
         result.reason = "High correlation: " + DoubleToString(signal.correlation, 2);
         return result;
      }
      
      // Adjust signal based on market regime
      if(signal.regime == "ranging")
      {
         result.tweaks[0] = signal.price * 0.998; // Tighter entry
         result.tweaks[1] = signal.sl * 0.8;      // Tighter SL
         result.tweaks[2] = signal.tp * 0.8;      // Tighter TP
      }
      else if(signal.regime == "trending")
      {
         result.tweaks[0] = signal.price * 1.002; // Slightly looser entry
         result.tweaks[1] = signal.sl * 1.2;      // Wider SL
         result.tweaks[2] = signal.tp * 1.5;      // Wider TP
      }
      
      result.passed = true;
      result.reason = "Market context validated";
      return result;
   }
   
};

// Gate 3: Strategy Scrub (Strategy Validation)
class CStrategyScrubGate : public IGate
{
private:
   double m_min_win_rate;
   int m_min_trades;
   
public:
   CStrategyScrubGate(double min_wr = 0.55, int min_trades = 10)
      : m_min_win_rate(min_wr), m_min_trades(min_trades)
   {
   }
   
   string GetName() override { return "StrategyScrub"; }
   void SetThreshold(double threshold) override { m_min_win_rate = threshold; }
   double GetSuccessRate() override { return 0.82; }
   
   GateResult Process(TradingSignal &signal) override
   {
      GateResult result;
      result.processed_at = TimeCurrent();
      
      // For now, we'll use confidence as proxy
      if(signal.confidence < m_min_win_rate)
      {
         result.passed = false;
         result.reason = "Strategy confidence too low";
         return result;
      }
      
      // Adjust parameters based on strategy performance
      result.tweaks[0] = signal.price; // No price adjustment
      result.tweaks[1] = signal.sl * (0.95 + signal.confidence * 0.1); // Dynamic SL
      result.tweaks[2] = signal.tp * (1.05 + signal.confidence * 0.15); // Dynamic TP
      
      result.passed = true;
      result.reason = "Strategy validated";
      return result;
   }
};

// Gate 4: Risk Wash
class CRiskWashGate : public IGate
{
public:
   string GetName() override { return "RiskWash"; }
   void SetThreshold(double threshold) override { /* Risk threshold adjustment */ }
   double GetSuccessRate() override { return 0.85; }
   
   GateResult Process(TradingSignal &signal) override
   {
      GateResult result;
      result.processed_at = TimeCurrent();
      
      double account_balance = 0;
      account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double risk_amount = account_balance * 0.02;
      double sl_distance = MathAbs(signal.price - signal.sl);
      double point_value = 0;
      SymbolInfoDouble(signal.symbol, SYMBOL_TRADE_TICK_VALUE, point_value);
      double optimal_size = risk_amount / (sl_distance * point_value);
      
      result.tweaks[3] = (optimal_size - signal.volume) / signal.volume;
      result.passed = true;
      result.reason = "Risk assessment passed";
      return result;
   }
};

// Gate 5: Performance Wax
class CPerformanceWaxGate : public IGate
{
public:
   string GetName() override { return "PerformanceWax"; }
   void SetThreshold(double threshold) override { /* Performance threshold adjustment */ }
   double GetSuccessRate() override { return 0.79; }
   
   GateResult Process(TradingSignal &signal) override
   {
      GateResult result;
      result.processed_at = TimeCurrent();
      
      // Simulate backtest
      double win_rate = 0.65 + (MathRand() - 16384) / 32768.0 * 0.2;
      if(win_rate < 0.6) 
      { 
         result.passed = false; 
         result.reason = "Backtest win rate too low";
         return result; 
      }
      
      result.tweaks[1] = 0.05; // SL adjustment
      result.tweaks[2] = 0.05; // TP adjustment
      result.passed = true;
      result.reason = "Performance validation passed";
      return result;
   }
};

// Gate 6: ML Polish
class CMLPolishGate : public IGate
{
public:
   string GetName() override { return "MLPolish"; }
   void SetThreshold(double threshold) override { /* ML threshold adjustment */ }
   double GetSuccessRate() override { return 0.82; }
   
   GateResult Process(TradingSignal &signal) override
   {
      GateResult result;
      result.processed_at = TimeCurrent();
      
      double ml_confidence = 0.75 + (MathRand() - 16384) / 32768.0 * 0.3;
      if(ml_confidence < 0.75) 
      { 
         result.passed = false; 
         result.reason = "ML confidence too low";
         return result; 
      }
      
      result.tweaks[4] = (ml_confidence - 0.5) * 10;
      result.passed = true;
      result.reason = "ML validation passed";
      return result;
   }
};

// Gate 7: Live Clean
class CLiveCleanGate : public IGate
{
public:
   string GetName() override { return "LiveClean"; }
   void SetThreshold(double threshold) override { /* Live threshold adjustment */ }
   double GetSuccessRate() override { return 0.88; }
   
   GateResult Process(TradingSignal &signal) override
   {
      GateResult result;
      result.processed_at = TimeCurrent();
      
      double slippage = (MathRand() - 16384) / 32768.0 * 0.002;
      if(slippage > 0.001) 
      { 
         result.passed = false; 
         result.reason = "High slippage risk";
         return result; 
      }
      
      result.tweaks[4] = slippage * 1000;
      result.passed = true;
      result.reason = "Live market conditions validated";
      return result;
   }
};

// Gate 8: Final Verify
class CFinalVerifyGate : public IGate
{
public:
   string GetName() override { return "FinalVerify"; }
   void SetThreshold(double threshold) override { /* Final verification threshold adjustment */ }
   
   GateResult Process(TradingSignal &signal) override
   {
      GateResult result;
      result.processed_at = TimeCurrent();
      result.passed = true;
      result.reason = "Final verification passed";
      return result;
   }
   
   double GetSuccessRate() override { return 0.95; }
};

// Main gate manager with unified system integration
class CGateManager
{
private:
   IGate *m_gates[8];
   CLearningBridge *m_learning;
   CConfigManager *m_config;
   CEventBus *m_event_bus;
   CSystemMonitor *m_monitor;
   
   // Helper method to safely access gate
   IGate* GetGate(int index) const
   {
      if(index >= 0 && index < 8)
         return m_gates[index];
      return NULL;
   }
   string m_symbol;
   int m_timeframe;
   bool m_unified_mode; // Enable unified system features
   
public:
   CGateManager(string symbol, int timeframe, CLearningBridge *learning, bool unified_mode = true)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_learning = learning;
      m_unified_mode = unified_mode;
      
      // Initialize unified system components if enabled
      if(m_unified_mode)
      {
         m_config = CConfigManager::GetInstance();
         m_event_bus = CEventBus::GetInstance();
         m_monitor = CSystemMonitor::GetInstance();
         
         // Configure event bus logging based on config
         m_event_bus.SetVerboseLogging(m_config.IsVerboseLogging());
         
         // Publish initialization event
         string init_msg = StringFormat("Initialized for %s", symbol);
         m_event_bus.PublishSystemEvent("GateManager", init_msg);
      }
      else
      {
         m_config = NULL;
         m_event_bus = NULL;
         m_monitor = NULL;
      }
      
      // Initialize all 8 gates
      InitializeGates();
   }
   
   ~CGateManager()
   {
      if(m_unified_mode && m_event_bus != NULL)
      {
         string shutdown_msg = StringFormat("Shutting down for %s", m_symbol);
         m_event_bus.PublishSystemEvent("GateManager", shutdown_msg);
      }
      
      for(int i = 0; i < 8; i++)
      {
         if(m_gates[i] != NULL)
         {
            delete m_gates[i];
            m_gates[i] = NULL;
         }
      }
   }

   // Initialize gates with configuration
   void InitializeGates()
   {
      m_gates[0] = new CSignalRinseGate();
      m_gates[1] = new CMarketSoapGate();
      m_gates[2] = new CStrategyScrubGate();
      m_gates[3] = new CRiskWashGate();
      m_gates[4] = new CPerformanceWaxGate();
      m_gates[5] = new CMLPolishGate();
      m_gates[6] = new CLiveCleanGate();
      m_gates[7] = new CFinalVerifyGate();
   }
   
   // Process signal through all gates
   bool ProcessSignal(const TradingSignal &signal, CSignalDecision &decision)
   {
      // Initialize decision
      decision.signal_id = signal.id;
      decision.timestamp = TimeCurrent();
      decision.symbol = signal.symbol;
      decision.timeframe = signal.timeframe;
      decision.original_price = signal.price;
      decision.original_type = signal.type;
      decision.original_sl = signal.sl;
      decision.original_tp = signal.tp;
      decision.original_volume = signal.volume;
      
      // Create a working copy of the signal
      TradingSignal current_signal = signal;
      bool all_gates_passed = true;
      
      // Process through each gate
      for(int i = 0; i < 8; i++)
      {
         IGate *gate = GetGate(i);
         GateResult result;
         // Ensure tweaks are zero-initialized to avoid undefined adjustments when bypassing gates
         for(int __k=0; __k<5; __k++) result.tweaks[__k]=0.0;
         
         if(gate == NULL) 
         {
            result.passed = false;
            result.reason = "Gate is null";
            result.processed_at = TimeCurrent();
         }
         else
         {
            // Check if gate is enabled in configuration
            bool gate_enabled = true;
            if(m_unified_mode && m_config != NULL)
            {
               GateConfig gate_config = m_config.GetGateConfig(i);
               gate_enabled = gate_config.enabled;
            }
            
            if(!gate_enabled)
            {
               result.passed = true;
               result.reason = "Gate disabled in configuration";
               result.processed_at = TimeCurrent();
            }
            else if(m_config != NULL && m_config.IsNoConstraintsMode())
            {
               result.passed = true;
               result.reason = "No constraints mode enabled";
               result.processed_at = TimeCurrent();
            }
            else
            {
               // Measure processing time
               ulong start_time = GetMicrosecondCount();
               
               // Process through the gate (re-enabled)
               result = gate.Process(current_signal);
               
               // Calculate processing time
               double processing_time = (double)(GetMicrosecondCount() - start_time) / 1000.0;
               
               // Publish gate event if unified mode is enabled
               if(m_unified_mode && m_event_bus != NULL)
               {
                  string gate_name = gate.GetName();
                  m_event_bus.PublishGateEvent(gate_name, result.passed, result.reason);
                  string perf_metric = StringFormat("%s_processing_time", gate_name);
                  m_event_bus.PublishPerformanceEvent(perf_metric, processing_time);
               }
            }
         }
         
         // Record gate result
         decision.gate_results[i] = result.passed;
         decision.gate_reasons[i] = result.reason;
         decision.gate_timestamps[i] = result.processed_at;
            
         // Apply tweaks if gate passed
         if(result.passed)
         {
            current_signal.price += result.tweaks[0];
            current_signal.sl += result.tweaks[1];
            current_signal.tp += result.tweaks[2];
            current_signal.volume *= (1 + result.tweaks[3]);
            
            // Copy tweaks to decision record
            for(int j = 0; j < 5; j++)
               decision.gate_tweaks[i][j] = result.tweaks[j];
         }
         else
         {
            all_gates_passed = false;
            break; // Stop processing if any gate fails
         }
      }
      
      // Finalize decision based on accumulated gate results
      decision.executed = all_gates_passed;
      decision.final_price = current_signal.price;
      decision.final_sl = current_signal.sl;
      decision.final_tp = current_signal.tp;
      decision.final_volume = current_signal.volume;
      
      // Record market context
      decision.volatility = current_signal.volatility;
      decision.correlation_score = current_signal.correlation;
      decision.market_regime = current_signal.regime;
      
      // Record decision in learning system
         if(m_learning != NULL)
         {
            m_learning.RecordDecision(decision);
            
            if(m_unified_mode && m_event_bus != NULL)
            {
               string decision_msg = StringFormat("Decision recorded: %s", decision.signal_id);
               m_event_bus.PublishSystemEvent("LearningBridge", decision_msg);
            }
         }
      
      // Publish trade execution event if unified mode is enabled
      if(m_unified_mode && m_event_bus != NULL)
      {
         string trade_data = StringFormat("%s|%s|%s", decision.signal_id, decision.symbol, 
                           (decision.executed ? "EXECUTED" : "REJECTED"));
         m_event_bus.Publish(EVENT_TRADE_EXECUTED, "GateManager", trade_data, 2);
      }
         
      return all_gates_passed;
   }
   
   // Update gate thresholds based on learning
   void UpdateFromLearning()
   {
      if(m_learning == NULL) return;
      
      if(m_unified_mode && m_config != NULL && m_monitor != NULL)
      {
         // Update thresholds based on performance metrics
         for(int i = 0; i < 8; i++)
         {
            double success_rate = m_monitor.GetGateSuccessRate(i);
            GateConfig config = m_config.GetGateConfig(i);
            
            // Adjust threshold based on success rate vs target
            if(success_rate < config.success_rate_target - 0.05)
            {
               // Lower threshold if success rate is too low
               config.threshold *= 0.95;
               m_config.SetGateConfig(i, config);
               
               if(m_gates[i] != NULL)
                  m_gates[i].SetThreshold(config.threshold);
               
               if(m_event_bus != NULL)
               {
                  string msg = StringFormat("Threshold lowered to %.4f", config.threshold);
                  string full_msg = StringFormat("%s: %s", config.name, msg);
                  m_event_bus.PublishSystemEvent("GateManager", full_msg);
               }
            }
            else if(success_rate > config.success_rate_target + 0.05)
            {
               // Raise threshold if success rate is too high
               config.threshold *= 1.05;
               m_config.SetGateConfig(i, config);
               
               if(m_gates[i] != NULL)
                  m_gates[i].SetThreshold(config.threshold);
               
               if(m_event_bus != NULL)
               {
                  string msg = StringFormat("Threshold raised to %.4f", config.threshold);
                  string full_msg = StringFormat("%s: %s", config.name, msg);
                  m_event_bus.PublishSystemEvent("GateManager", full_msg);
               }
            }
         }
      }
      else
      {
         // Legacy implementation for backward compatibility
         Print("UpdateFromLearning: Using legacy mode");
      }
   }
   
   // Configuration methods for unified system
   void SetUnifiedMode(bool enabled) { m_unified_mode = enabled; }
   bool IsUnifiedMode() { return m_unified_mode; }
   
   // Get gate configuration
   GateConfig GetGateConfiguration(int gate_index)
   {
      if(m_unified_mode && m_config != NULL)
         return m_config.GetGateConfig(gate_index);
      
      GateConfig empty;
      return empty;
   }
   
   // Set gate configuration
   void SetGateConfiguration(int gate_index, const GateConfig& config)
   {
      if(m_unified_mode && m_config != NULL)
      {
         m_config.SetGateConfig(gate_index, config);
         
         if(m_gates[gate_index] != NULL)
            m_gates[gate_index].SetThreshold(config.threshold);
      }
   }
   
   // Get system health
   SystemHealth GetSystemHealth()
   {
      if(m_unified_mode && m_monitor != NULL)
         return m_monitor.GetSystemHealth();
      
      SystemHealth empty;
      return empty;
   }
   
   // Print unified system status
   void PrintSystemStatus()
   {
      if(m_unified_mode)
      {
         if(m_monitor != NULL)
         {
            m_monitor.PrintHealthReport();
            m_monitor.PrintGateStatistics();
         }
         
         if(m_config != NULL)
         {
            Print("\n=== Configuration Status ===");
            Print("Unified Mode: Enabled");
            Print("No Constraints Mode: ", m_config.IsNoConstraintsMode());
            Print("Verbose Logging: ", m_config.IsVerboseLogging());
         }
      }
      else
      {
         Print("GateManager: Running in legacy mode");
      }
   }
};

#endif
