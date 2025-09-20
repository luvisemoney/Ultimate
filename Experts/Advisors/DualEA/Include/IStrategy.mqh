// IStrategy.mqh
// Defines the interface for all trading strategies.

#ifndef DUALEA_INCLUDE_ISTRATEGY_MQH
#define DUALEA_INCLUDE_ISTRATEGY_MQH
#property copyright "2025, Windsurf Engineering"
#property link      "https://www.windsurf.ai"

#include <Object.mqh> // Required for CObject
#include <Trade/Trade.mqh>
// Make ATR helper available to all strategies that include IStrategy
#include "ATRUtil.mqh"
// Forward declaration to avoid circular include; concrete users should include KnowledgeBase.mqh
class CFeaturesKB;

// --- Trade action type for all strategies
enum TradeAction
  {
   ACTION_NONE = 0,
   ACTION_BUY = 1,
   ACTION_SELL = -1
  };

// --- Trailing stop policy
enum TrailingType
  {
   TRAIL_NONE = 0,
   TRAIL_FIXED_POINTS = 1,
   TRAIL_ATR = 2
  };


// --- Enum for the type of signal (added for all strategies)
enum SignalType
  {
   SIGNAL_NONE = 0,
   SIGNAL_BUY = 1,
   SIGNAL_SELL = -1
  };

// --- Struct to hold all details for a trade order
struct TradeOrder
  {
   TradeAction       action;         // Buy, Sell, or None
   ENUM_ORDER_TYPE   order_type;     // Market, Stop, Limit
   double            lots;           // Requested lot size override (0=use EA default)
   double            price;          // Entry price for pending orders
   double            stop_loss;      // Stop loss price
   double            take_profit;    // Take profit price
   string            strategy_name;  // Name of the strategy that generated the signal

    // Trailing policy
    bool              trailing_enabled;       // Enable trailing stop handling after entry
    TrailingType      trailing_type;          // Trailing algorithm
    double            trail_distance_points;  // Distance of SL from price in points
    double            trail_activation_points;// Profit in points before trailing starts
    double            trail_step_points;      // Minimum step in points to move SL
    // ATR-based trailing parameters (used when trailing_type == TRAIL_ATR)
    int               atr_period;             // ATR period
    double            atr_multiplier;         // Distance = ATR * multiplier

   // --- Constructor to initialize with default values
   TradeOrder() 
     {
      action = ACTION_NONE;
      order_type = ORDER_TYPE_BUY; // Default, should be overwritten
      lots = 0.0;
      price = 0;
      stop_loss = 0;
      take_profit = 0;
      strategy_name = "";
      trailing_enabled = false;
      trailing_type = TRAIL_NONE;
      trail_distance_points = 0;
      trail_activation_points = 0;
      trail_step_points = 0;
      atr_period = 14;
      atr_multiplier = 2.0;
     }

   // --- Copy constructor to handle assignments correctly
   TradeOrder(const TradeOrder &other)
     {
      action = other.action;
      order_type = other.order_type;
      lots = other.lots;
      price = other.price;
      stop_loss = other.stop_loss;
      take_profit = other.take_profit;
      strategy_name = other.strategy_name;
      trailing_enabled = other.trailing_enabled;
      trailing_type = other.trailing_type;
      trail_distance_points = other.trail_distance_points;
      trail_activation_points = other.trail_activation_points;
      trail_step_points = other.trail_step_points;
      atr_period = other.atr_period;
      atr_multiplier = other.atr_multiplier;
     }
  };

// --- The interface for all trading strategies
class IStrategy : public CObject
  {
protected:
   // Internal backing fields for new hooks
   long    m_id;
   bool    m_enabled;
   // Simple in-memory metadata store (parallel arrays)
   string  m_meta_keys[];
   string  m_meta_vals[];

public:
   // Base constructor initializes defaults for new fields
   IStrategy()
     {
      m_id = -1;
      m_enabled = true;
      ArrayResize(m_meta_keys, 0);
      ArrayResize(m_meta_vals, 0);
     }

   // Core lifecycle and signal hooks
   virtual void         Refresh() { }
   virtual TradeOrder   CheckSignal() { TradeOrder order; return order; }
   virtual string       Name() { return "IStrategy"; }

   // Allow a strategy to export its indicator/context features at a timestamp
   // Concrete strategies should include KnowledgeBase.mqh and write via kb->WriteKV(ts, symbol, Name(), feature, value)
   virtual void         ExportFeatures(CFeaturesKB* kb, const datetime ts) { }

   // --- New Phase 5 hooks ---
   // Unique numeric identifier (set and get)
   virtual void         SetId(const long id) { m_id = id; }
   virtual long         Id() const { return m_id; }

   // Enable/disable state (soft gating at strategy level)
   virtual void         SetEnabled(const bool enabled) { m_enabled = enabled; }
   virtual bool         Enabled() const { return m_enabled; }

   // Metadata store (string key/value)
   virtual void         MetadataSet(const string key, const string value)
     {
      int idx = -1;
      for(int i=0;i<ArraySize(m_meta_keys);++i) { if(m_meta_keys[i]==key) { idx=i; break; } }
      if(idx<0)
        {
         int n = ArraySize(m_meta_keys);
         ArrayResize(m_meta_keys, n+1);
         ArrayResize(m_meta_vals, n+1);
         m_meta_keys[n] = key;
         m_meta_vals[n] = value;
        }
      else
        {
         m_meta_vals[idx] = value;
        }
     }

   virtual string       MetadataGet(const string key, const string def_value="") const
     {
      for(int i=0;i<ArraySize(m_meta_keys);++i) { if(m_meta_keys[i]==key) return m_meta_vals[i]; }
      return def_value;
     }

   // Dump metadata in a simple key=value;key2=value2 form for persistence/logging
   virtual string       MetadataDumpString() const
     {
      string out="";
      for(int i=0;i<ArraySize(m_meta_keys);++i)
        {
         if(i>0) out += ";";
         out += m_meta_keys[i] + "=" + m_meta_vals[i];
        }
      return out;
     }

   // Dynamic indicator auto-tuning hook (return true if parameters changed)
   // Default: no-op and return false
   virtual bool         AutoTuneIndicators(const string symbol, const ENUM_TIMEFRAMES timeframe) { return false; }
   // Phase 6: prewarm indicator handles for low-latency timer scans
   virtual bool         PrewarmIndicators(const string symbol, const ENUM_TIMEFRAMES timeframe) { return false; }
  };

#endif // DUALEA_INCLUDE_ISTRATEGY_MQH
