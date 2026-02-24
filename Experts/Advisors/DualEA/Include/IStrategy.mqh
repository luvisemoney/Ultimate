//+------------------------------------------------------------------+
//| IStrategy.mqh - Strategy Interface Definition                      |
//| Defines the base interface for all trading strategies            |
//+------------------------------------------------------------------+
#ifndef ISTRATEGY_MQH
#define ISTRATEGY_MQH

#include <Object.mqh>  // Required for CObject base class

//+------------------------------------------------------------------+
//| Trailing Stop Types                                                |
//+------------------------------------------------------------------+
enum TrailingType
{
   TRAIL_NONE = 0,        // No trailing stop
   TRAIL_FIXED = 1,       // Fixed points trailing
   TRAIL_FIXED_POINTS = 1,
   TRAIL_ATR = 2,         // ATR-based trailing
   TRAIL_PERCENT = 3,     // Percentage trailing
   TRAIL_STEP = 4         // Step-based trailing
};

//+------------------------------------------------------------------+
//| Trading Signal Structure                                           |
//+------------------------------------------------------------------+
struct TradingSignal
{
   // Core identity
   string            id;                 // Unique signal id (for logging/telemetry)
   string            strategy_name;      // Legacy strategy name field
   string            strategy;           // Canonical strategy identifier
   string            symbol;             // Symbol
   ENUM_TIMEFRAMES   timeframe;          // Timeframe

   // Direction / type
   int               direction;          // -1=Sell, 0=None, 1=Buy (legacy)
   int               type;               // 0=buy,1=sell (used by execution logic)
   ENUM_ORDER_TYPE   order_type;         // Order type: BUY, SELL, BUY_STOP, SELL_STOP, BUY_LIMIT, SELL_LIMIT, etc.

   // Prices and risk
   double            confidence;         // 0.0-1.0
   double            entry_price;        // Entry price (for gates)
   double            stop_loss;          // Stop loss level (for gates)
   double            take_profit;        // Take profit level (for gates)
   double            price;              // Canonical price (used by PaperEA and optimizers)
   double            sl;                 // Canonical SL
   double            tp;                 // Canonical TP
   double            volume;             // Lots

   // Context
   datetime          timestamp;          // Signal timestamp
   bool              is_exit;            // Is exit signal
   string            regime;             // Regime tag
   string            market_regime;      // Market regime tag
   double            volatility;         // Volatility metric
   double            correlation;        // Correlation metric
   
   TradingSignal() { Init(); }

   void Init()
   {
      id              = "";
      strategy_name   = "";
      strategy        = "";
      symbol          = "";
      timeframe       = PERIOD_CURRENT;
      direction       = 0;
      type            = 0;
      order_type      = ORDER_TYPE_BUY;  // Default to market buy
      confidence      = 0.0;
      entry_price     = 0.0;
      stop_loss       = 0.0;
      take_profit     = 0.0;
      price           = 0.0;
      sl              = 0.0;
      tp              = 0.0;
      volume          = 0.0;
      timestamp       = 0;
      is_exit         = false;
      regime          = "";
      market_regime   = "";
      volatility      = 0.0;
      correlation     = 0.0;
   }
};

//+------------------------------------------------------------------+
//| Trade Order Structure                                              |
//+------------------------------------------------------------------+
struct TradeOrder
{
   int               action;             // ACTION_BUY, ACTION_SELL, ACTION_NONE
   ENUM_ORDER_TYPE   order_type;
   double            lots;
   double            price;
   double            stop_loss;
   double            take_profit;
   string            strategy_name;
   datetime          timestamp;
   double            volume;

   bool              trailing_enabled;
   TrailingType      trailing_type;
   double            trail_distance_points;
   double            trail_activation_points;
   double            trail_step_points;
   int               atr_period;
   double            atr_multiplier;
   
   TradeOrder()
   {
      action = 0; // ACTION_NONE
      order_type = (ENUM_ORDER_TYPE)0;
      lots = 0.0;
      price = 0.0;
      stop_loss = 0.0;
      take_profit = 0.0;
      strategy_name = "";
      timestamp = 0;
      volume = 0.0;

      trailing_enabled = false;
      trailing_type = TRAIL_NONE;
      trail_distance_points = 0.0;
      trail_activation_points = 0.0;
      trail_step_points = 0.0;
      atr_period = 14;
      atr_multiplier = 2.0;
   }
};

double GetATR(const int period = 14, const int shift = 0)
{
   int handle = iATR(_Symbol, _Period, period);
   if(handle == INVALID_HANDLE) return 0.0;
   double buf[1];
   if(CopyBuffer(handle, 0, shift, 1, buf) != 1) { IndicatorRelease(handle); return 0.0; }
   IndicatorRelease(handle);
   return buf[0];
}

// Constants for action types
#define ACTION_NONE     0
#define ACTION_BUY      1
#define ACTION_SELL     2

//+------------------------------------------------------------------+
//| Base Strategy Interface                                            |
//+------------------------------------------------------------------+
class IStrategy : public CObject
{
protected:
   string            m_name;           // Strategy name
   string            m_symbol;         // Trading symbol
   ENUM_TIMEFRAMES   m_timeframe;      // Timeframe
   bool              m_enabled;        // Enabled flag

public:
   // Constructor
   IStrategy(string name, string symbol, ENUM_TIMEFRAMES tf)
      : m_name(name), m_symbol(symbol), m_timeframe(tf), m_enabled(true) {}

   // Pure virtual methods that must be implemented
   virtual void      Refresh() = 0;                    // Update indicator calculations
   virtual TradeOrder CheckSignal() = 0;               // Check for trading signal
   virtual string    Name() const { return m_name; }     // Get strategy name
   virtual string    Symbol() const { return m_symbol; } // Get symbol
   virtual int       Magic() const { return 0; }         // Get magic number

   // Feature export for ML (optional)
   virtual void      ExportFeatures(CObject* kb, const datetime ts) {} 

   // Position management (optional overrides)
   virtual double    GetStopLossPoints() const { return 0; }
   virtual double    GetTakeProfitPoints() const { return 0; }
   virtual bool      IsExitSignal() const { return false; }
   virtual void      SetExitSignal(bool exit) {}
   virtual bool      IsBullish() const { return false; }
   virtual bool      IsBearish() const { return false; }

   // Lifecycle
   virtual bool      Init() { return true; }
   virtual void      Deinit() {}

   // Enable/disable
   void              SetEnabled(bool enabled) { m_enabled = enabled; }
   bool              IsEnabled() const { return m_enabled; }
};

#endif // ISTRATEGY_MQH
