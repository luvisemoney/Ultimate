//+------------------------------------------------------------------+
//|                                              OTCTypes.mqh          |
//|                        Copyright 2025, OTC Escape EA              |
//|                                             https://www.yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, OTC Escape EA"
#property link      "https://www.yoursite.com"
#property version   "1.00"
#property strict

#include <Object.mqh>
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Enumeration for Market Regimes                                   |
//+------------------------------------------------------------------+
enum E_MARKET_REGIME
{
   REGIME_STABLE_RANGING,
   REGIME_STABLE_TRENDING,
   REGIME_VOLATILE_RANGING,
   REGIME_VOLATILE_TRENDING,
   REGIME_QUIET_TRENDING,
   REGIME_QUIET_RANGING,
   REGIME_UNDEFINED
};

//+------------------------------------------------------------------+
//| Struct for a set of performance metrics                          |
//+------------------------------------------------------------------+
struct SMetricSet
{
   int total_trades;
   int total_wins;
   int total_losses;
   double gross_profit;
   double gross_loss;
   double net_profit;
   double profit_factor;
   double win_rate;
   double total_sl_pips;
   double total_tp_pips;
   double avg_sl;
   double avg_tp;

   void Reset()
   {
      total_trades = 0;
      total_wins = 0;
      total_losses = 0;
      gross_profit = 0.0;
      gross_loss = 0.0;
      net_profit = 0.0;
      profit_factor = 0.0;
      win_rate = 0.0;
      total_sl_pips = 0.0;
      total_tp_pips = 0.0;
      avg_sl = 0.0;
      avg_tp = 0.0;
   }
};

//+------------------------------------------------------------------+
//| Struct for detailed performance metrics per regime               |
//+------------------------------------------------------------------+
struct SPerformanceMetrics
{
   SMetricSet buy_metrics;
   SMetricSet sell_metrics;
   SMetricSet total_metrics;
   double max_drawdown;
   double cumulative_balance;
   double peak_balance;

   SPerformanceMetrics() : max_drawdown(0), cumulative_balance(0), peak_balance(0) {}
};

//+------------------------------------------------------------------+
//| Trade Record Structure                                           |
//+------------------------------------------------------------------+
class STradeRecord : public CObject
{
public:
   long ticket;
   ENUM_ORDER_TYPE trade_type;
   double entry_price;
   double exit_price;
   double lot_size;
   double stop_loss;
   double take_profit;
   double profit;
   datetime entry_time;
   datetime exit_time;
   double spread;
   double volatility;
   double trend_strength;
   E_MARKET_REGIME market_regime;

   STradeRecord() : ticket(0), trade_type((ENUM_ORDER_TYPE)-1), entry_price(0), exit_price(0), lot_size(0), stop_loss(0), take_profit(0), profit(0), entry_time(0), exit_time(0), spread(0), volatility(0), trend_strength(0), market_regime(REGIME_UNDEFINED) {}

   virtual bool Save(const int handle)
   {
      if(handle == INVALID_HANDLE) return false;
      if(FileWriteLong(handle, ticket) <= 0) return false;
      if(FileWriteInteger(handle, (int)trade_type) <= 0) return false;
      if(FileWriteDouble(handle, entry_price) <= 0) return false;
      if(FileWriteDouble(handle, exit_price) <= 0) return false;
      if(FileWriteDouble(handle, lot_size) <= 0) return false;
      if(FileWriteDouble(handle, stop_loss) <= 0) return false;
      if(FileWriteDouble(handle, take_profit) <= 0) return false;
      if(FileWriteDouble(handle, profit) <= 0) return false;
      if(FileWriteLong(handle, entry_time) <= 0) return false;
      if(FileWriteLong(handle, exit_time) <= 0) return false;
      if(FileWriteDouble(handle, spread) <= 0) return false;
      if(FileWriteDouble(handle, volatility) <= 0) return false;
      if(FileWriteDouble(handle, trend_strength) <= 0) return false;
      if(FileWriteInteger(handle, (int)market_regime) <= 0) return false;
      return true;
   }

   virtual bool Load(const int handle)
   {
      if(handle == INVALID_HANDLE) return false;
      ticket = FileReadLong(handle);
      trade_type = (ENUM_ORDER_TYPE)FileReadInteger(handle);
      entry_price = FileReadDouble(handle);
      exit_price = FileReadDouble(handle);
      lot_size = FileReadDouble(handle);
      stop_loss = FileReadDouble(handle);
      take_profit = FileReadDouble(handle);
      profit = FileReadDouble(handle);
      entry_time = FileReadLong(handle);
      exit_time = FileReadLong(handle);
      spread = FileReadDouble(handle);
      volatility = FileReadDouble(handle);
      trend_strength = FileReadDouble(handle);
      market_regime = (E_MARKET_REGIME)FileReadInteger(handle);
      return !FileIsEnding(handle);
   }
};

//+------------------------------------------------------------------+
//| Market State Structure                                           |
//+------------------------------------------------------------------+
struct SMarketState
{
   double volatility;
   double trend_strength;
   E_MARKET_REGIME regime;
   ENUM_ORDER_TYPE trade_direction;
   double optimal_sl;
   double optimal_tp;

   SMarketState() : volatility(0), trend_strength(0), regime(REGIME_UNDEFINED), trade_direction((ENUM_ORDER_TYPE)-1), optimal_sl(0), optimal_tp(0) {}
   void Reset() { volatility=0; trend_strength=0; regime=REGIME_UNDEFINED; trade_direction=(ENUM_ORDER_TYPE)-1; optimal_sl=0; optimal_tp=0; }
};

//+------------------------------------------------------------------+
