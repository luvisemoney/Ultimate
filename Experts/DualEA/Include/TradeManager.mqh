// TradeManager.mqh
// Handles all trade execution logic.

#property copyright "2025, Windsurf Engineering"
#property link      "https://www.windsurf.ai"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Object.mqh>
#include "IStrategy.mqh"

class CTradeManager
  {
private:
   CTrade            m_trade;
   string            m_symbol;
   double            m_lot_size;
   int               m_magic_number;

   // Trailing configurations keyed by symbol (netting mode assumption)
   class CTrailConfig : public CObject
     {
      public:
        string       symbol;
        bool         enabled;
        TrailingType type;
        double       distance_points;
        double       activation_points;
        double       step_points;
        // ATR-based trailing params
        int          atr_period;
        double       atr_multiplier;
        CTrailConfig(): enabled(false), type(TRAIL_NONE), distance_points(0), activation_points(0), step_points(0), atr_period(14), atr_multiplier(2.0) {}
     };
   CArrayObj         m_trails;

   CTrailConfig*     FindTrailBySymbol(const string sym)
     {
      for(int i=0;i<m_trails.Total();++i)
        {
         CTrailConfig* cfg = (CTrailConfig*)m_trails.At(i);
         if(CheckPointer(cfg)!=POINTER_INVALID && cfg.symbol==sym)
            return cfg;
        }
      return NULL;
     }

public:
                     CTradeManager(string symbol, double lot_size, int magic_number);
                    ~CTradeManager();

   bool              ExecuteOrder(const TradeOrder &order);
   // Accessors for last trade results
   uint              ResultRetcode();
   ulong             ResultDeal();
   ulong             ResultOrder();
   double            ResultPrice();

   // Trailing management
   void              ConfigureTrailing(const TradeOrder &order);
   void              UpdateTrailingStops();
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTradeManager::CTradeManager(string symbol, double lot_size, int magic_number)
  {
   m_symbol = symbol;
   m_lot_size = lot_size;
   m_magic_number = magic_number;
   m_trade.SetExpertMagicNumber(m_magic_number);
   m_trade.SetMarginMode();
   m_trails.Clear();
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTradeManager::~CTradeManager()
  {
  }

//+------------------------------------------------------------------+
//| Executes any type of trade order based on the TradeOrder struct  |
//+------------------------------------------------------------------+
bool CTradeManager::ExecuteOrder(const TradeOrder &order)
  {
   if(order.action == ACTION_NONE) return false;

   switch(order.order_type)
     {
      case ORDER_TYPE_BUY:
         return m_trade.Buy(m_lot_size, m_symbol, 0, order.stop_loss, order.take_profit);

      case ORDER_TYPE_SELL:
         return m_trade.Sell(m_lot_size, m_symbol, 0, order.stop_loss, order.take_profit);

      case ORDER_TYPE_BUY_STOP:
         return m_trade.BuyStop(m_lot_size, order.price, m_symbol, order.stop_loss, order.take_profit);

      case ORDER_TYPE_SELL_STOP:
         return m_trade.SellStop(m_lot_size, order.price, m_symbol, order.stop_loss, order.take_profit);

      case ORDER_TYPE_BUY_LIMIT:
         return m_trade.BuyLimit(m_lot_size, order.price, m_symbol, order.stop_loss, order.take_profit);

      case ORDER_TYPE_SELL_LIMIT:
         return m_trade.SellLimit(m_lot_size, order.price, m_symbol, order.stop_loss, order.take_profit);

      default:
         Print("Unsupported order type in TradeManager: ", EnumToString(order.order_type));
         return false;
     }
  }

//+------------------------------------------------------------------+
//| Accessors for last trade result                                   |
//+------------------------------------------------------------------+
uint CTradeManager::ResultRetcode()
  {
   return m_trade.ResultRetcode();
  }

ulong CTradeManager::ResultDeal()
  {
   return m_trade.ResultDeal();
  }

ulong CTradeManager::ResultOrder()
  {
   return m_trade.ResultOrder();
  }

double CTradeManager::ResultPrice()
  {
   return m_trade.ResultPrice();
  }

//+------------------------------------------------------------------+
//| Configure trailing for current symbol from TradeOrder             |
//+------------------------------------------------------------------+
void CTradeManager::ConfigureTrailing(const TradeOrder &order)
  {
   CTrailConfig* cfg = FindTrailBySymbol(m_symbol);
   if(cfg==NULL)
     {
      cfg = new CTrailConfig();
      cfg.symbol = m_symbol;
      m_trails.Add(cfg);
     }
   cfg.enabled = order.trailing_enabled;
   cfg.type = order.trailing_type;
   cfg.distance_points = order.trail_distance_points;
   cfg.activation_points = order.trail_activation_points;
   cfg.step_points = order.trail_step_points;
   cfg.atr_period = order.atr_period;
   cfg.atr_multiplier = order.atr_multiplier;
  }

//+------------------------------------------------------------------+
//| Update trailing stops for all positions with our magic number     |
//+------------------------------------------------------------------+
void CTradeManager::UpdateTrailingStops()
  {
   int total = PositionsTotal();
   for(int i=0;i<total;++i)
     {
      string sym = PositionGetSymbol(i);
      if(sym=="")
         continue;
      if(!PositionSelect(sym))
         continue;
      long pos_magic = (long)PositionGetInteger(POSITION_MAGIC);
      if(pos_magic != m_magic_number)
         continue;
      CTrailConfig* cfg = FindTrailBySymbol(sym);
      if(cfg==NULL || !cfg.enabled || cfg.type==TRAIL_NONE)
         continue;

      // read position
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double point = SymbolInfoDouble(sym, SYMBOL_POINT);
      int    digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

      double bid = 0, ask = 0;
      SymbolInfoDouble(sym, SYMBOL_BID, bid);
      SymbolInfoDouble(sym, SYMBOL_ASK, ask);

      double activation = cfg.activation_points * point;
      double distance = cfg.distance_points * point;
      double step = cfg.step_points * point;

      if(cfg.type==TRAIL_FIXED_POINTS)
        {
         if(ptype==POSITION_TYPE_BUY)
           {
            // Ensure activation
            if((bid - open_price) < activation)
               continue;
            double new_sl = NormalizeDouble(bid - distance, digits);
            // Only move SL upwards by step or more
            if(sl==0 || new_sl > sl + step)
               m_trade.PositionModify(sym, new_sl, tp);
           }
         else if(ptype==POSITION_TYPE_SELL)
           {
            if((open_price - ask) < activation)
               continue;
            double new_sl = NormalizeDouble(ask + distance, digits);
            if(sl==0 || new_sl < sl - step)
               m_trade.PositionModify(sym, new_sl, tp);
           }
        }
      else if(cfg.type==TRAIL_ATR)
        {
         // Compute ATR and convert to price distance
         int handle = iATR(sym, _Period, cfg.atr_period);
         if(handle!=INVALID_HANDLE)
           {
            double atr_buf[];
            if(CopyBuffer(handle, 0, 0, 1, atr_buf)==1)
              {
               double atr = atr_buf[0];
               double atr_distance = atr * cfg.atr_multiplier;
               // Activation still based on points; distance from ATR
               if(ptype==POSITION_TYPE_BUY)
                 {
                  if((bid - open_price) < activation)
                     { IndicatorRelease(handle); continue; }
                  double new_sl = NormalizeDouble(bid - atr_distance, digits);
                  if(sl==0 || new_sl > sl + step)
                     m_trade.PositionModify(sym, new_sl, tp);
                 }
               else if(ptype==POSITION_TYPE_SELL)
                 {
                  if((open_price - ask) < activation)
                     { IndicatorRelease(handle); continue; }
                  double new_sl = NormalizeDouble(ask + atr_distance, digits);
                  if(sl==0 || new_sl < sl - step)
                     m_trade.PositionModify(sym, new_sl, tp);
                 }
              }
            IndicatorRelease(handle);
           }
        }
     }
  }
