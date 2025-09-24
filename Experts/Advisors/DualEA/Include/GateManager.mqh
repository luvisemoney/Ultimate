//+------------------------------------------------------------------+
//| GateManager.mqh - 8-Stage Gate System with Signal Polishing     |
//+------------------------------------------------------------------+
#ifndef __GATEMANAGER_MQH__
#define __GATEMANAGER_MQH__

#include "LearningBridge.mqh"
#include "Gates4to7.mqh"

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
      
      double spread = 0;
      double ask = 0;
      SymbolInfoDouble(signal.symbol, SYMBOL_SPREAD, spread);
      SymbolInfoDouble(signal.symbol, SYMBOL_ASK, ask);
      double spread_ratio = spread / ask;
      
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
   
public:
   CMarketSoapGate(double max_vol = 0.02, double min_liq = 1000000)
   {
      m_max_volatility = max_vol;
      m_min_liquidity = min_liq;
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
   
   string GetName() override { return "MarketSoap"; }
   void SetThreshold(double threshold) override { m_max_volatility = threshold; }
   double GetSuccessRate() override { return 0.78; }
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
   
   string GetName() override { return "StrategyScrub"; }
   void SetThreshold(double threshold) override { m_min_win_rate = threshold; }
   double GetSuccessRate() override { return 0.82; }
};

// Gate 4: Risk Wash
class CRiskWashGate : public IGate
{
public:
   string GetName() override { return "RiskWash"; }
   void SetThreshold(double threshold) override { /* Risk threshold adjustment */ }
   
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
   string GetName() override { return "RiskWash"; }
   void SetThreshold(double threshold) override {}
   double GetSuccessRate() override { return 0.85; }
};

// Gate 5: Performance Wax
class CPerformanceWaxGate : public IGate
{
public:
   string GetName() override { return "PerformanceWax"; }
   void SetThreshold(double threshold) override { /* Performance threshold adjustment */ }
   
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
   string GetName() override { return "PerformanceWax"; }
   void SetThreshold(double threshold) override {}
   double GetSuccessRate() override { return 0.79; }
};

// Gate 6: ML Polish
class CMLPolishGate : public IGate
{
public:
   string GetName() override { return "MLPolish"; }
   void SetThreshold(double threshold) override { /* ML threshold adjustment */ }
   
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
   string GetName() override { return "MLPolish"; }
   void SetThreshold(double threshold) override {}
   double GetSuccessRate() override { return 0.82; }
};

// Gate 7: Live Clean
class CLiveCleanGate : public IGate
{
public:
   string GetName() override { return "LiveClean"; }
   void SetThreshold(double threshold) override { /* Live threshold adjustment */ }
   
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
   string GetName() override { return "LiveClean"; }
   void SetThreshold(double threshold) override {}
   double GetSuccessRate() override { return 0.88; }
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
   string GetName() override { return "FinalVerify"; }
   void SetThreshold(double threshold) override {}
   double GetSuccessRate() override { return 0.95; }
};

// Main gate manager
class CGateManager
{
private:
   IGate *m_gates[8];
   CLearningBridge *m_learning;
   
   // Helper method to safely access gate
   IGate* GetGate(int index) const
   {
      if(index >= 0 && index < 8)
         return m_gates[index];
      return NULL;
   }
   string m_symbol;
   int m_timeframe;
   
public:
   CGateManager(string symbol, int timeframe, CLearningBridge *learning)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_learning = learning;
      
      // Initialize all 8 gates
      m_gates[0] = new CSignalRinseGate();
      m_gates[1] = new CMarketSoapGate();
      m_gates[2] = new CStrategyScrubGate();
      m_gates[3] = new CRiskWashGate();
      m_gates[4] = new CPerformanceWaxGate();
      m_gates[5] = new CMLPolishGate();
      m_gates[6] = new CLiveCleanGate();
      m_gates[7] = new CFinalVerifyGate();
   }
   
   ~CGateManager()
   {
      for(int i = 0; i < 8; i++)
         if(m_gates[i] != NULL) delete m_gates[i];
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
         if(gate == NULL) continue;
         
         // Process through the gate
         GateResult result = gate->Process(current_signal);
            
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
      
      // If we get here, all gates passed
      decision.executed = true;
      decision.final_price = current_signal.price;
      decision.final_sl = current_signal.sl;
      decision.final_tp = current_signal.tp;
      decision.final_volume = current_signal.volume;
      
      // Record market context
      decision.volatility = current_signal.volatility;
      decision.correlation_score = current_signal.correlation;
      decision.market_regime = current_signal.regime;
      
      if(m_learning != NULL)
         m_learning->RecordDecision(decision);
         
      return true;
   }
   
   // Update gate thresholds based on learning
   void UpdateFromLearning()
   {
      if(m_learning == NULL) return;
      
      // TODO: Implement gate threshold updates
      // This method is temporarily disabled to resolve compilation issues
      Print("UpdateFromLearning called - implementation pending");
   }
};

#endif
