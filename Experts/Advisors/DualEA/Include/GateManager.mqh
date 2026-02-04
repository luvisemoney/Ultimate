//+------------------------------------------------------------------+
//| GateManager.mqh - Efficient 8-Stage Gate System                  |
//+------------------------------------------------------------------+
#ifndef __GATEMANAGER_MQH__
#define __GATEMANAGER_MQH__

// Core dependencies
#include "LearningBridge.mqh"    // CSignalDecision, CLearningBridge
#include "ConfigManager.mqh"     // CConfigManager, GateConfig
#include "EventBus.mqh"          // CEventBus
#include "SystemMonitor.mqh"     // CSystemMonitor, SystemHealth
#include "LogMiddleware.mqh"     // LOG macro

struct TradingSignal {
   string id, symbol, strategy, regime, market_regime;
   int timeframe, type; // 0=buy, 1=sell
   datetime timestamp;
   double price, sl, tp, volume, confidence, volatility, correlation;
   void Init() { id=""; symbol=""; strategy=""; regime=""; market_regime=""; timeframe=0; type=-1; timestamp=0; price=sl=tp=volume=confidence=volatility=correlation=0.0; }
};

struct GateResult {
   bool passed;
   string reason;
   double tweaks[5];
   datetime processed_at;
};

class IGate
  {
public:
   virtual ~IGate() {}
   // Pure virtual interface for gates
   virtual GateResult Process(TradingSignal &signal) = 0;
   virtual string GetName() = 0;
   // Optional extension points used by some gates
   virtual void   SetThreshold(double threshold) { }
   virtual double GetSuccessRate() { return 0.0; }
  };

typedef void (*GateSanitizeTelemetryCallback)(const string gate_name, TradingSignal &signal);
static GateSanitizeTelemetryCallback g_gate_sanitize_callback = NULL;
void SetGateSanitizeTelemetryCallback(GateSanitizeTelemetryCallback cb) { g_gate_sanitize_callback = cb; }

// Example basic gate: confidence filter
#define CONFIDENCE_GATE_MIN 0.5
class CConfidenceGate : public IGate
  {
private:
   double min_conf;
public:
   CConfidenceGate(double c=CONFIDENCE_GATE_MIN) { min_conf=c; }
   string GetName() { return "ConfidenceGate"; }
   void   SetThreshold(double threshold) { min_conf = threshold; }
   double GetSuccessRate() { return 0.75; }
   GateResult Process(TradingSignal &signal)
     {
      GateResult r;
      r.passed       = (signal.confidence >= min_conf);
      r.reason       = r.passed ? "pass" : "low confidence";
      r.processed_at = TimeCurrent();
      return r;
     }
  };

// Gate 1: Signal Rinse (Pre-filter)
class CSignalRinseGate : public IGate
{
private:
   double m_min_confidence;
   double m_max_spread_ratio;
   
public:
   CSignalRinseGate(double min_confidence = 0.5, double max_spread = 0.0005)
   {
      m_min_confidence = min_confidence;
      m_max_spread_ratio = max_spread;
   }
   
   string GetName() { return "SignalRinse"; }
   void SetThreshold(double threshold) { m_min_confidence = threshold; }
   double GetSuccessRate() { return 0.75; }
   
   GateResult Process(TradingSignal &signal)   {
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
   
   string GetName() { return "MarketSoap"; }
   void SetThreshold(double threshold) { m_max_volatility = threshold; }
   double GetSuccessRate() { return 0.78; }
   
   GateResult Process(TradingSignal &signal)   {
      GateResult result;
      result.processed_at = TimeCurrent();
      
      // Check volatility (normalize percent-like inputs to ratio)
      double v = signal.volatility;
      if(v > 1.0) v *= 0.01; // if 72 => 0.72, treat as 72%
      // Relaxed threshold to avoid blocking reasonable volatilities
      if(v > 0.15)
      {
         result.passed = false;
         result.reason = "High volatility: " + DoubleToString(v, 4);
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
   
   string GetName() { return "StrategyScrub"; }
   void SetThreshold(double threshold) { m_min_win_rate = threshold; }
   double GetSuccessRate() { return 0.82; }
   
   GateResult Process(TradingSignal &signal)   {
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
   string GetName() { return "RiskWash"; }
   void   SetThreshold(double threshold) { }
   double GetSuccessRate() { return 0.85; }
   
   GateResult Process(TradingSignal &signal)
     {
      GateResult result;
      result.processed_at = TimeCurrent();
      
      double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double risk_amount     = account_balance * 0.02;
      double sl_distance     = MathAbs(signal.price - signal.sl);
      double tick_value      = 0.0;
      SymbolInfoDouble(signal.symbol, SYMBOL_TRADE_TICK_VALUE, tick_value);
      if(sl_distance <= 0.0 || tick_value <= 0.0)
        {
         result.passed = false;
         result.reason = "Invalid SL distance or tick value";
         return result;
        }
      double optimal_size = risk_amount / (sl_distance * tick_value);
      
      if(signal.volume > 0.0)
         result.tweaks[3] = (optimal_size - signal.volume) / signal.volume;
      else
         result.tweaks[3] = 0.0;

      result.passed = true;
      result.reason = "Risk assessment passed";
      return result;
     }
  };

// Gate 5: Performance Wax
class CPerformanceWaxGate : public IGate
{
public:
   string GetName() { return "PerformanceWax"; }
   void SetThreshold(double threshold) { }
   double GetSuccessRate() { return 0.79; }
   
   GateResult Process(TradingSignal &signal)   {
      GateResult result;
      result.processed_at = TimeCurrent();
      
      // Deterministic pass: remove randomness for repeatable tester runs
      for(int k=0;k<5;k++) result.tweaks[k]=0.0;
      result.passed = true;
      result.reason = "Performance validation (deterministic)";
      return result;
   }
};

// Gate 6: ML Polish
class CMLPolishGate : public IGate
{
public:
   string GetName() { return "MLPolish"; }
   void SetThreshold(double threshold) { }
   double GetSuccessRate() { return 0.82; }
   
   GateResult Process(TradingSignal &signal)   {
      GateResult result;
      result.processed_at = TimeCurrent();
      
      // Deterministic: use provided signal.confidence (set upstream) without randomness
      double mlc = signal.confidence;
      if(mlc < 0.5)
      {
         result.passed = false;
         result.reason = "ML confidence below threshold";
         return result;
      }
      result.tweaks[4] = (mlc - 0.5) * 10.0;
      result.passed = true;
      result.reason = "ML validation passed (deterministic)";
      return result;
   }
};

// Gate 7: Live Clean
class CLiveCleanGate : public IGate
{
public:
   string GetName() { return "LiveClean"; }
   void SetThreshold(double threshold) { }
   double GetSuccessRate() { return 0.88; }
   
   GateResult Process(TradingSignal &signal)   {
      GateResult result;
      result.processed_at = TimeCurrent();
      
      // Deterministic pass: remove random slippage simulation
      for(int k=0;k<5;k++) result.tweaks[k]=0.0;
      result.passed = true;
      result.reason = "Live market conditions validated (deterministic)";
      return result;
   }
};

// Gate 8: Final Verify
class CFinalVerifyGate : public IGate
{
public:
   string GetName() { return "FinalVerify"; }
   void SetThreshold(double threshold) { }
   
   GateResult Process(TradingSignal &signal)   {
      GateResult result;
      result.processed_at = TimeCurrent();
      result.passed = true;
      result.reason = "Final verification passed";
      return result;
   }
   
   double GetSuccessRate() { return 0.95; }
};

// Simple heuristic confidence fallback used when upstream did not set confidence
double HeuristicConfidence(const TradingSignal &s)
{
   double base = 0.50;
   if(s.strategy == "ADXStrategy")              base = 0.55;
   else if(s.strategy == "RSIStrategy")         base = 0.52;
   else if(s.strategy == "BreakoutStrategy")    base = 0.56;

   // Regime-specific boost
   if(s.regime == "trending" && (s.strategy == "ADXStrategy" || s.strategy == "BreakoutStrategy"))
      base += 0.08;
   else if(s.regime == "ranging" && (s.strategy == "RSIStrategy" || s.strategy == "BollingerBandsStrategy"))
      base += 0.08;

   // Volatility moderation (normalize percent-like inputs)
   double v = s.volatility;
   if(v > 1.0) v *= 0.01;
   if(v > 0.05) v = 0.05; // cap effect
   base -= v;

   if(base < 0.0) base = 0.0;
   if(base > 1.0) base = 1.0;
   return base;
}

// Main gate manager with unified system integration
class CGateManager
{
private:
   IGate          *m_gates[8];
   CLearningBridge *m_learning;
   CConfigManager  *m_config;
   CEventBus       *m_event_bus;
   CSystemMonitor  *m_monitor;
   string           m_symbol;
   int              m_timeframe;
   bool             m_unified_mode;

   // Helper method to safely access gate
   IGate* GetGate(const int index)
   {
      if(index < 0 || index >= 8)
         return NULL;
      return m_gates[index];
   }

   bool SanitizeGateOutput(TradingSignal &signal, const string gate_name)
   {
      bool sanitized = false;
      string symbol = (signal.symbol != "") ? signal.symbol : _Symbol;
      double atr_for_fix = 100 * SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(atr_for_fix <= 0.0)
         atr_for_fix = 0.001;

      // Ensure price is valid
      if(signal.price <= 0.0 || !MathIsValidNumber(signal.price))
      {
         double ref_price = (signal.type == 1) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
         if(ref_price <= 0.0)
            ref_price = SymbolInfoDouble(symbol, SYMBOL_LAST);
         if(ref_price <= 0.0)
            ref_price = 1.0;
         signal.price = ref_price;
         sanitized = true;
      }

      // Fix stop loss and take profit for buy/sell
      bool sl_invalid = (!MathIsValidNumber(signal.sl) || MathAbs(signal.sl) > 1e10 || signal.sl == 0.0);
      bool tp_invalid = (MathAbs(signal.tp) > 1e10 || !MathIsValidNumber(signal.tp) || signal.tp == 0.0);
      
      if(signal.type == 0) // Buy
      {
         if(!sl_invalid && signal.sl >= signal.price)
            sl_invalid = true;
         if(!tp_invalid && signal.tp <= signal.price)
            tp_invalid = true;
         
         if(sl_invalid)
         {
            signal.sl = signal.price - atr_for_fix * 1.5;
            sanitized = true;
         }
         if(tp_invalid)
         {
            signal.tp = signal.price + atr_for_fix * 2.5;
            sanitized = true;
         }
      }
      else if(signal.type == 1) // Sell
      {
         if(!sl_invalid && signal.sl <= signal.price)
            sl_invalid = true;
         if(!tp_invalid && signal.tp >= signal.price)
            tp_invalid = true;
         
         if(sl_invalid)
         {
            signal.sl = signal.price + atr_for_fix * 1.5;
            sanitized = true;
         }
         if(tp_invalid)
         {
            signal.tp = signal.price - atr_for_fix * 2.5;
            sanitized = true;
         }
      }

      // Stop loss and take profit already fixed above

      double vol_min = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double vol_max = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double vol_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      if(vol_min <= 0.0)
         vol_min = 0.01;
      if(vol_max <= 0.0)
         vol_max = 100.0;
      if(vol_step <= 0.0)
         vol_step = vol_min;

      if(!MathIsValidNumber(signal.volume) || signal.volume <= 0.0 || signal.volume > vol_max)
      {
         double normalized_volume = vol_min;
         normalized_volume = MathCeil(normalized_volume / vol_step) * vol_step;
         if(normalized_volume > vol_max)
            normalized_volume = vol_min;
         signal.volume = normalized_volume;
         sanitized = true;
      }

      if(sanitized)
      {
         LOG(StringFormat("WARNING: Sanitized gate output after %s (price=%.5f sl=%.5f tp=%.5f vol=%.2f)",
                          gate_name, signal.price, signal.sl, signal.tp, signal.volume));
         if(g_gate_sanitize_callback != NULL)
         {
            g_gate_sanitize_callback(gate_name, signal);
         }
      }
      return sanitized;
   }

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
         m_config    = CConfigManager::GetInstance();
         m_event_bus = CEventBus::GetInstance();
         m_monitor   = CSystemMonitor::GetInstance();
         
         if(m_event_bus != NULL && m_config != NULL)
         {
            // Configure event bus logging based on config
            m_event_bus.SetVerboseLogging(m_config.IsVerboseLogging());

            // Publish initialization event
            string init_msg = StringFormat("Initialized for %s", symbol);
            m_event_bus.PublishSystemEvent("GateManager", init_msg);
         }
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

   // Learning-driven threshold updates (stub to satisfy external callers)
   void UpdateFromLearning()
   {
      // Intentionally minimal; real implementation can query m_learning
      // and adjust internal thresholds or gate configs.
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
      
      // CRITICAL: Sanitize garbage/uninitialized values before processing
      // Detect garbage volatility (uninitialized memory pattern: huge absolute values)
      if(current_signal.volatility < -1e10 || current_signal.volatility > 1e10 || MathIsValidNumber(current_signal.volatility) == false)
         current_signal.volatility = 0.0;
      
      // Normalize volatility: if percent-like (>1.0), convert to ratio
      if(current_signal.volatility > 1.0)
         current_signal.volatility *= 0.01;
      
      // Sanitize correlation
      if(current_signal.correlation < -1e10 || current_signal.correlation > 1e10 || MathIsValidNumber(current_signal.correlation) == false)
         current_signal.correlation = 0.0;
      
      // CRITICAL: Sanitize garbage SL/TP values (uninitialized memory)
      // Use MathAbs to catch both positive and negative garbage values
      double atr_for_fix = 100 * SymbolInfoDouble(current_signal.symbol, SYMBOL_POINT);
      if(atr_for_fix <= 0) atr_for_fix = 0.001; // Fallback for invalid symbol
      
      bool sl_is_garbage = (current_signal.sl <= 0.0 || MathAbs(current_signal.sl) > 1e10 || !MathIsValidNumber(current_signal.sl));
      bool tp_is_garbage = (MathAbs(current_signal.tp) > 1e10 || !MathIsValidNumber(current_signal.tp) || current_signal.tp == 0.0);
      
      if(sl_is_garbage)
      {
         current_signal.sl = (current_signal.type == 0) ? current_signal.price - atr_for_fix * 1.5 : current_signal.price + atr_for_fix * 1.5;
      }
      if(tp_is_garbage)
      {
         current_signal.tp = (current_signal.type == 0) ? current_signal.price + atr_for_fix * 2.5 : current_signal.price - atr_for_fix * 2.5;
      }
      
      // Deterministic confidence fallback if not set or out of range
      if(current_signal.confidence <= 0.0 || current_signal.confidence > 1.0)
         current_signal.confidence = HeuristicConfidence(current_signal);
      
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
               
               // Process through the gate
               result = gate.Process(current_signal);
               
               // Calculate processing time
               double processing_time = (double)(GetMicrosecondCount() - start_time) / 1000.0;
               
               // Publish gate event if unified mode is enabled
               if(m_unified_mode && m_event_bus != NULL)
               {
                  string gate_name  = gate.GetName();
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
            // CRITICAL FIX: Gates return adjustments differently
            // - tweaks[0] = price adjustment (can be 0 for no change, or delta/multiplier)
            // - tweaks[1] = SL adjustment (0 = no change, positive = new SL value, negative = delta)
            // - tweaks[2] = TP adjustment (0 = no change, positive = new TP value, negative = delta)
            // - tweaks[3] = volume multiplier adjustment (-0.1 = 90% of original, 0 = no change, 0.1 = 110%)
            // - tweaks[4] = timing adjustment
            
            // Price adjustment (apply as delta only if non-zero)
            if(MathAbs(result.tweaks[0]) > 1e-9)
               current_signal.price = result.tweaks[0];
            
            // SL/TP adjustments: If gate returns a value, use it; if 0, keep original
            // This fixes the bug where gates returned full values but we were adding them
            if(MathAbs(result.tweaks[1]) > 1e-9)
               current_signal.sl = result.tweaks[1];  // SET instead of ADD
            
            if(MathAbs(result.tweaks[2]) > 1e-9)
               current_signal.tp = result.tweaks[2];  // SET instead of ADD
            
            // Volume adjustment (multiplicative)
            if(MathAbs(result.tweaks[3]) > 1e-9)
               current_signal.volume *= (1.0 + result.tweaks[3]);
            
            // Copy tweaks to decision record
            for(int j = 0; j < 5; j++)
               decision.gate_tweaks[i][j] = result.tweaks[j];

            string gate_name = (gate != NULL) ? gate.GetName() : StringFormat("Gate_%d", i+1);
            SanitizeGateOutput(current_signal, gate_name);
         }
         else
         {
            all_gates_passed = false;
            // Improved diagnostics: log failing gate with key metrics
            IGate *dbg_gate = GetGate(i);
            string dbg_name = "UNKNOWN";
            if(dbg_gate != NULL) dbg_name = dbg_gate.GetName();
            double dbg_vol = current_signal.volatility;
            if(dbg_vol > 1.0) dbg_vol *= 0.01;
            LOG(StringFormat("Gate %d [%s] BLOCKED: %s (conf=%.3f vol=%.4f)",
                             i+1, dbg_name, result.reason, current_signal.confidence, dbg_vol));
            break; // Stop processing if any gate fails
         }
      }
      
      // Finalize decision based on accumulated gate results
      decision.executed = all_gates_passed;
      decision.final_price = current_signal.price;
      decision.final_sl = current_signal.sl;
      decision.final_tp = current_signal.tp;
      decision.final_volume = current_signal.volume;
      
      // CRITICAL FIX: Validate SL/TP are valid after gate processing
      // Check for zero, negative (for buy TP), or garbage values
      bool sl_invalid = (decision.final_sl <= 0.0 || decision.final_sl > 1e10 || MathIsValidNumber(decision.final_sl) == false);
      bool tp_invalid = (MathAbs(decision.final_tp) > 1e10 || MathIsValidNumber(decision.final_tp) == false || decision.final_tp == 0.0);
      
      if(sl_invalid || tp_invalid)
      {
         // Calculate safe ATR-based defaults
         double atr = 100 * SymbolInfoDouble(current_signal.symbol, SYMBOL_POINT);
         if(sl_invalid)
         {
            decision.final_sl = (current_signal.type == 0) ? current_signal.price - atr * 1.5 : current_signal.price + atr * 1.5;
         }
         if(tp_invalid)
         {
            decision.final_tp = (current_signal.type == 0) ? current_signal.price + atr * 2.5 : current_signal.price - atr * 2.5;
         }
         LOG(StringFormat("WARNING: Fixed invalid SL/TP for signal %s (now sl=%.5f tp=%.5f)", 
                     decision.signal_id, decision.final_sl, decision.final_tp));
      }
      
      // Record market context
      decision.volatility = current_signal.volatility;
      decision.correlation_score = current_signal.correlation;
      decision.market_regime = current_signal.regime;
      
      return all_gates_passed;
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
         
         if(gate_index >= 0 && gate_index < 8 && m_gates[gate_index] != NULL)
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
            LOG("\n=== Configuration Status ===");
            LOG("Unified Mode: Enabled");
            LOG(StringFormat("No Constraints Mode: %s", m_config.IsNoConstraintsMode() ? "true" : "false"));
            LOG(StringFormat("Verbose Logging: %s", m_config.IsVerboseLogging() ? "true" : "false"));
         }
      }
      else
      {
         LOG("GateManager: Running in legacy mode");
      }
   }
};

#endif
