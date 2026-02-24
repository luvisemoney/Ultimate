//+------------------------------------------------------------------+
//| CGateBase.mqh - Abstract Gate Interface                          |
//| Based on chat-8Stage Gate System Integration Guide               |
//| Enhances modularity with shadow logging & auto-tuning support    |
//+------------------------------------------------------------------+
#ifndef CGATEBASE_MQH
#define CGATEBASE_MQH

#include <Arrays/ArrayLong.mqh>
#include "IStrategy.mqh"

//+------------------------------------------------------------------+
//| Gate Result Structure                                            |
//+------------------------------------------------------------------+
struct EGateResult
{
   bool   passed;           // Gate passed?
   double confidence;       // Confidence score (0.0-1.0)
   double threshold;        // Applied threshold
   string block_reason;     // Why blocked (if failed)
   ulong  latency_us;       // Execution time in microseconds
   
   void Set(bool p, double c, double t, string r="", ulong l=0)
   {
      passed = p;
      confidence = c;
      threshold = t;
      block_reason = r;
      latency_us = l;
   }
};

//+------------------------------------------------------------------+
//| Auto-Tuning Configuration                                         |
//+------------------------------------------------------------------+
struct SGateAutoTuneConfig
{
   bool   enabled;          // Auto-tuning active?
   double min_threshold;    // Minimum allowed threshold
   double max_threshold;    // Maximum allowed threshold
   int    lookback_trades;  // Trades to analyze
   double target_winrate;   // Target win rate for optimization
   double learning_rate;    // Adjustment speed (0.01-0.1)
   
   void Init(double min_t=0.3, double max_t=0.9, int lookback=20, 
             double target_wr=0.55, double lr=0.05)
   {
      enabled = true;
      min_threshold = min_t;
      max_threshold = max_t;
      lookback_trades = lookback;
      target_winrate = target_wr;
      learning_rate = lr;
   }
};

//+------------------------------------------------------------------+
//| Abstract Gate Base Class                                           |
//+------------------------------------------------------------------+
class CGateBase
{
protected:
   string m_name;                    // Gate name
   bool   m_enabled;                   // Gate enabled?
   bool   m_shadow_mode;              // Shadow logging only?
   double m_threshold;                // Current threshold
   double m_default_threshold;       // Default/fallback threshold
   
   // Auto-tuning
   SGateAutoTuneConfig m_autotune;  // Auto-tuning config
   double m_trade_history[];         // Trade PnL history for learning
   bool   m_pass_history[];          // Gate pass/fail history
   
   // Performance tracking
   ulong  m_total_evaluations;       // Total validations
   ulong  m_passed_count;            // Passed count
   double m_avg_latency_us;          // Average latency
   
public:
   // Constructor
   CGateBase(string name) 
   : m_name(name), 
     m_enabled(true), 
     m_shadow_mode(false),
     m_threshold(0.5),
     m_default_threshold(0.5),
     m_total_evaluations(0),
     m_passed_count(0),
     m_avg_latency_us(0.0)
   {
      ArrayResize(m_trade_history, 0);
      ArrayResize(m_pass_history, 0);
   }
   
   // Virtual destructor
   virtual ~CGateBase() {}
   
   //+------------------------------------------------------------------+
   //| Core Interface (MUST OVERRIDE)                                   |
   //+------------------------------------------------------------------+
   virtual bool Initialize() { return true; }
   virtual bool Validate(TradingSignal &signal, EGateResult &result) = 0;
   virtual double CalculateConfidence(const TradingSignal &signal) = 0;
   
   //+------------------------------------------------------------------+
   //| Configuration Interface                                          |
   //+------------------------------------------------------------------+
   void Enable(bool enable) { m_enabled = enable; }
   void SetShadowMode(bool shadow) { m_shadow_mode = shadow; }
   void SetThreshold(double threshold) 
   { 
      m_threshold = MathMax(0.0, MathMin(1.0, threshold));
   }
   void SetDefaultThreshold(double threshold)
   {
      m_default_threshold = MathMax(0.0, MathMin(1.0, threshold));
      if(m_threshold == 0.0) m_threshold = m_default_threshold;
   }
   
   //+------------------------------------------------------------------+
   //| Auto-Tuning Interface                                            |
   //+------------------------------------------------------------------+
   void EnableAutoTune(const SGateAutoTuneConfig &config)
   {
      m_autotune = config;
   }
   
   void DisableAutoTune() { m_autotune.enabled = false; }
   
   void RecordTradeOutcome(double pnl, bool gate_passed)
   {
      // Add to history ring buffer
      int size = ArraySize(m_trade_history);
      if(size >= m_autotune.lookback_trades)
      {
         // Shift array (ring buffer)
         for(int i=0; i<size-1; i++)
         {
            m_trade_history[i] = m_trade_history[i+1];
            m_pass_history[i] = m_pass_history[i+1];
         }
         m_trade_history[size-1] = pnl;
         m_pass_history[size-1] = gate_passed;
      }
      else
      {
         ArrayResize(m_trade_history, size+1);
         ArrayResize(m_pass_history, size+1);
         m_trade_history[size] = pnl;
         m_pass_history[size] = gate_passed;
      }
      
      // Trigger auto-tuning if enough data
      if(m_autotune.enabled && size >= m_autotune.lookback_trades/2)
      {
         AutoTuneThreshold();
      }
   }
   
   void AutoTuneThreshold()
   {
      if(!m_autotune.enabled) return;
      
      int size = ArraySize(m_trade_history);
      if(size < 5) return; // Need minimum data
      
      // Calculate win rate for trades that passed this gate
      int wins = 0, total_passed = 0;
      double total_pnl = 0;
      
      for(int i=0; i<size; i++)
      {
         if(m_pass_history[i]) // Gate was passed
         {
            total_passed++;
            if(m_trade_history[i] > 0) wins++;
            total_pnl += m_trade_history[i];
         }
      }
      
      if(total_passed == 0) return;
      
      double winrate = (double)wins / total_passed;
      double profit_factor = total_pnl > 0 ? total_pnl / MathAbs(total_pnl) : 0;
      
      // Adjust threshold based on performance
      double adjustment = 0.0;
      if(winrate < m_autotune.target_winrate * 0.9)
      {
         // Win rate too low - make threshold stricter
         adjustment = m_autotune.learning_rate;
      }
      else if(winrate > m_autotune.target_winrate * 1.1 && profit_factor > 1.2)
      {
         // Win rate high and profitable - can relax threshold
         adjustment = -m_autotune.learning_rate;
      }
      
      // Apply adjustment with bounds
      double new_threshold = m_threshold + adjustment;
      new_threshold = MathMax(m_autotune.min_threshold, 
                             MathMin(m_autotune.max_threshold, new_threshold));
      
      if(MathAbs(new_threshold - m_threshold) > 0.001)
      {
         Print(StringFormat("[Gate:%s] Auto-tuned: %.3f -> %.3f (WR=%.2f%% PF=%.2f)",
               m_name, m_threshold, new_threshold, winrate*100, profit_factor));
         m_threshold = new_threshold;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Performance Tracking                                             |
   //+------------------------------------------------------------------+
   void RecordLatency(ulong latency_us)
   {
      // Exponential moving average
      if(m_avg_latency_us == 0)
         m_avg_latency_us = (double)latency_us;
      else
         m_avg_latency_us = m_avg_latency_us * 0.9 + (double)latency_us * 0.1;
      
      m_total_evaluations++;
   }
   
   void RecordPass(bool passed)
   {
      if(passed) m_passed_count++;
   }
   
   //+------------------------------------------------------------------+
   //| Getters                                                          |
   //+------------------------------------------------------------------+
   string GetName() const { return m_name; }
   bool   IsEnabled() const { return m_enabled; }
   bool   IsShadowMode() const { return m_shadow_mode; }
   double GetThreshold() const { return m_threshold; }
   double GetDefaultThreshold() const { return m_default_threshold; }
   double GetAvgLatency() const { return m_avg_latency_us; }
   double GetPassRate() const 
   { 
      return m_total_evaluations > 0 ? (double)m_passed_count / m_total_evaluations : 0.0;
   }
   bool   IsAutoTuneEnabled() const { return m_autotune.enabled; }
   
   //+------------------------------------------------------------------+
   //| Learning Interface                                               |
   //+------------------------------------------------------------------+
   void UpdateThresholdFromLearning()
   {
      // Update threshold based on learning data
      // This is called by the gate manager to refresh thresholds
      if(m_autotune.enabled)
      {
         AutoTuneThreshold();
      }
   }
   
   //+------------------------------------------------------------------+
   //| Statistics                                                       |
   //+------------------------------------------------------------------+
   void PrintStats()
   {
      Print(StringFormat("[Gate:%s] Enabled=%s Evals=%I64u Passed=%I64u (%.1f%%) Latency=%.1fus Threshold=%.3f",
            m_name,
            m_enabled ? "YES" : "NO",
            m_total_evaluations,
            m_passed_count,
            GetPassRate() * 100,
            m_avg_latency_us,
            m_threshold));
   }
   
   void ResetStats()
   {
      m_total_evaluations = 0;
      m_passed_count = 0;
      m_avg_latency_us = 0.0;
   }
};

#endif // CGATEBASE_MQH
