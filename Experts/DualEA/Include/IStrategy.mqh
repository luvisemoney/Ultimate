// IStrategy.mqh
// Defines the interface for all trading strategies.

#property copyright "2025, Windsurf Engineering"
#property link      "https://www.windsurf.ai"

#include <Trade/Trade.mqh>
#include <Object.mqh> // Required for CObject

// --- Trailing stop policy
enum TrailingType
  {
   TRAIL_NONE = 0,
   TRAIL_FIXED_POINTS = 1,
   TRAIL_ATR = 2
  };


// --- Enum for the type of trade action
enum TradeAction
  {
   ACTION_NONE,
   ACTION_BUY,
   ACTION_SELL
  };

// --- Struct to hold all details for a trade order
struct TradeOrder
  {
   TradeAction       action;         // Buy, Sell, or None
   ENUM_ORDER_TYPE   order_type;     // Market, Stop, Limit
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
public:
      virtual void         Refresh() { }
   virtual TradeOrder   CheckSignal() { TradeOrder order; return order; }
   virtual string       Name() { return "IStrategy"; }
  };
