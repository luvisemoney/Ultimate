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
   
   // Normalize and validate volume according to symbol constraints
   double            NormalizeVolume(double lots)
     {
      double vmin = 0.0, vmax = 0.0, vstep = 0.0;
      SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN, vmin);
      SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX, vmax);
      SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP, vstep);
      if(vstep<=0.0) vstep = vmin; // safety fallback
      // Derive volume digits from step (e.g., 0.01 -> 2)
      int vdigits = 0;
      double tmp = vstep;
      for(int i=0;i<8 && (MathRound(tmp) != tmp); ++i) { tmp *= 10.0; vdigits++; }
      // Clamp to range first
      double clamped = lots;
      if(clamped < vmin) clamped = vmin;
      if(clamped > vmax) clamped = vmax;
      // Snap to step grid (floor to avoid exceeding max)
      double steps = MathFloor((clamped + 1e-12) / vstep);
      double snapped = steps * vstep;
      // Ensure not below min after snapping
      if(snapped < vmin) snapped = vmin;
      // Normalize to derived volume digits
      double norm = NormalizeDouble(snapped, vdigits);
      // Final guard
      if(norm < vmin || norm > vmax)
        {
         PrintFormat("[VOL] Normalized volume %.4f out of bounds [%.4f..%.4f] step=%.5f for %s, falling back to min",
                     norm, vmin, vmax, vstep, m_symbol);
         norm = vmin;
        }
      return norm;
     }

   // --- Price/tick helpers
   // default to manager symbol
   double            TickSize() { double ts=0.0; SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE, ts); if(ts<=0.0) SymbolInfoDouble(m_symbol, SYMBOL_POINT, ts); return ts; }
   double            TickSize(const string sym) { double ts=0.0; SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE, ts); if(ts<=0.0) SymbolInfoDouble(sym, SYMBOL_POINT, ts); return ts; }
   int               PriceDigits() { return (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS); }
   int               PriceDigits(const string sym) { return (int)SymbolInfoInteger(sym, SYMBOL_DIGITS); }
   double            RoundToTick(double price)
     {
      double ts = TickSize(); if(ts<=0.0) return price; int dg = PriceDigits();
      // snap to nearest tick
      double ticks = MathRound(price/ts);
      return NormalizeDouble(ticks*ts, dg);
     }
   double            RoundToTick(double price, const string sym)
     {
      double ts = TickSize(sym); if(ts<=0.0) return price; int dg = PriceDigits(sym);
      double ticks = MathRound(price/ts);
      return NormalizeDouble(ticks*ts, dg);
     }
   double            RoundToTickBelow(double price, const string sym)
     {
      double ts = TickSize(sym); if(ts<=0.0) return price; int dg = PriceDigits(sym);
      double ticks = MathFloor(price/ts);
      return NormalizeDouble(ticks*ts, dg);
     }
   double            RoundToTickAbove(double price, const string sym)
     {
      double ts = TickSize(sym); if(ts<=0.0) return price; int dg = PriceDigits(sym);
      double ticks = MathCeil(price/ts);
      return NormalizeDouble(ticks*ts, dg);
     }
   double            MinStopDistance()
     {
      long lvl = 0; SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL, lvl);
      double pt = 0.0; SymbolInfoDouble(m_symbol, SYMBOL_POINT, pt);
      return (double)lvl * pt; // price distance
     }
   double            MinStopDistance(const string sym)
     {
      long lvl = 0; SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL, lvl);
      double pt = 0.0; SymbolInfoDouble(sym, SYMBOL_POINT, pt);
      return (double)lvl * pt;
     }
   double            FreezeDistance()
     {
      long lvl = 0; SymbolInfoInteger(m_symbol, SYMBOL_TRADE_FREEZE_LEVEL, lvl);
      double pt = 0.0; SymbolInfoDouble(m_symbol, SYMBOL_POINT, pt);
      return (double)lvl * pt;
     }
   double            FreezeDistance(const string sym)
     {
      long lvl = 0; SymbolInfoInteger(sym, SYMBOL_TRADE_FREEZE_LEVEL, lvl);
      double pt = 0.0; SymbolInfoDouble(sym, SYMBOL_POINT, pt);
      return (double)lvl * pt;
     }
   
   // Ensure symbol is selected, tradable, and has valid bid/ask
   bool              EnsureSymbolReady()
     {
      // Select symbol in Market Watch
      if(!SymbolSelect(m_symbol, true))
        {
         PrintFormat("[SYMBOL] Failed to select symbol %s", m_symbol);
         return false;
        }
      // Check trading mode
      long tmode = 0; SymbolInfoInteger(m_symbol, SYMBOL_TRADE_MODE, tmode);
      if(tmode==SYMBOL_TRADE_MODE_DISABLED)
        {
         PrintFormat("[SYMBOL] Trading disabled for %s", m_symbol);
         return false;
        }
      // Get latest tick
      MqlTick tick; if(!SymbolInfoTick(m_symbol, tick))
        {
         PrintFormat("[SYMBOL] No tick for %s", m_symbol);
         return false;
        }
      if(tick.bid<=0.0 || tick.ask<=0.0)
        {
         PrintFormat("[SYMBOL] Invalid bid/ask for %s (bid=%.5f ask=%.5f)", m_symbol, tick.bid, tick.ask);
         return false;
        }
      return true;
     }
   
   // Normalize SL/TP relative to current market and stops level. Return via refs.
   void              NormalizeStops(const ENUM_ORDER_TYPE otype, double &entry_price, double &sl, double &tp)
     {
      double bid=0.0, ask=0.0; SymbolInfoDouble(m_symbol, SYMBOL_BID, bid); SymbolInfoDouble(m_symbol, SYMBOL_ASK, ask);
      double minDist = MinStopDistance(); double frz = FreezeDistance(); double needDist = MathMax(minDist, frz);
      int dg = PriceDigits(); double ts = TickSize();
      // Ensure entry price lies on correct side for pending orders and obeys min distance
      if(otype==ORDER_TYPE_BUY_LIMIT)
        { if(entry_price>=bid - needDist) entry_price = RoundToTickBelow(bid - needDist, m_symbol); }
      else if(otype==ORDER_TYPE_SELL_LIMIT)
        { if(entry_price<=ask + needDist) entry_price = RoundToTickAbove(ask + needDist, m_symbol); }
      else if(otype==ORDER_TYPE_BUY_STOP)
        { if(entry_price<=ask + needDist) entry_price = RoundToTickAbove(ask + needDist, m_symbol); }
      else if(otype==ORDER_TYPE_SELL_STOP)
        { if(entry_price>=bid - needDist) entry_price = RoundToTickBelow(bid - needDist, m_symbol); }
      // Market orders: use current market for distance checks
      if(otype==ORDER_TYPE_BUY || otype==ORDER_TYPE_BUY_LIMIT || otype==ORDER_TYPE_BUY_STOP)
        {
         if(sl>0.0)
           {
            double minSL = bid - needDist; // SL must be below market for BUY
            if(sl>=bid || (bid - sl) < needDist) sl = RoundToTickBelow(minSL, m_symbol);
           }
         if(tp>0.0)
           {
            double minTP = ask + needDist; // TP must be above for BUY
            if(tp<=ask || (tp - ask) < needDist) tp = RoundToTickAbove(minTP, m_symbol);
           }
        }
      else if(otype==ORDER_TYPE_SELL || otype==ORDER_TYPE_SELL_LIMIT || otype==ORDER_TYPE_SELL_STOP)
        {
         if(sl>0.0)
           {
            double minSL = ask + needDist; // SL must be above market for SELL
            if(sl<=ask || (sl - ask) < needDist) sl = RoundToTickAbove(minSL, m_symbol);
           }
         if(tp>0.0)
           {
            double minTP = bid - needDist; // TP must be below for SELL
            if(tp>=bid || (bid - tp) < needDist) tp = RoundToTickBelow(minTP, m_symbol);
           }
        }
      // Final side sanity: if still invalid (crossed), drop to zero to avoid rejection
      if(otype==ORDER_TYPE_BUY || otype==ORDER_TYPE_BUY_LIMIT || otype==ORDER_TYPE_BUY_STOP)
        {
         if(sl>=bid) sl=0.0; if(tp<=ask) tp=0.0;
        }
      else
        {
         if(sl<=ask) sl=0.0; if(tp>=bid) tp=0.0;
        }
      // Normalize to digits
      if(sl>0.0) sl = NormalizeDouble(RoundToTick(sl), dg);
      if(tp>0.0) tp = NormalizeDouble(RoundToTick(tp), dg);
      if(entry_price>0.0) entry_price = NormalizeDouble(RoundToTick(entry_price), dg);
     }

   // Normalize SL for an existing position with given side; return false if cannot make valid
   bool              NormalizeSLForPosition(const ENUM_POSITION_TYPE ptype, double &sl)
     {
      double bid=0.0, ask=0.0; SymbolInfoDouble(m_symbol, SYMBOL_BID, bid); SymbolInfoDouble(m_symbol, SYMBOL_ASK, ask);
      double minDist = MinStopDistance(); double frz = FreezeDistance(); double needDist = MathMax(minDist, frz); int dg = PriceDigits();
      if(ptype==POSITION_TYPE_BUY)
        {
         // SL must be below Bid by at least minDist
         if(sl<=0.0) return false;
         double maxSL = bid - needDist;
         if(sl>=bid || (bid - sl) < needDist) sl = RoundToTickBelow(maxSL, m_symbol);
         if(sl>=bid) return false; // still invalid
        }
      else if(ptype==POSITION_TYPE_SELL)
        {
         // SL must be above Ask by at least minDist
         if(sl<=0.0) return false;
         double minSL = ask + needDist;
         if(sl<=ask || (sl - ask) < needDist) sl = RoundToTickAbove(minSL, m_symbol);
         if(sl<=ask) return false;
        }
      sl = NormalizeDouble(sl, dg);
      return true;
     }
   bool              NormalizeSLForPosition(const string sym, const ENUM_POSITION_TYPE ptype, double &sl)
     {
      double bid=0.0, ask=0.0; SymbolInfoDouble(sym, SYMBOL_BID, bid); SymbolInfoDouble(sym, SYMBOL_ASK, ask);
      double minDist = MinStopDistance(sym); double frz = FreezeDistance(sym); double needDist = MathMax(minDist, frz); int dg = PriceDigits(sym);
      if(ptype==POSITION_TYPE_BUY)
        {
         if(sl<=0.0) return false;
         double maxSL = bid - needDist;
         if(sl>=bid || (bid - sl) < needDist) sl = RoundToTickBelow(maxSL, sym);
         if(sl>=bid) return false;
        }
      else if(ptype==POSITION_TYPE_SELL)
        {
         if(sl<=0.0) return false;
         double minSL = ask + needDist;
         if(sl<=ask || (sl - ask) < needDist) sl = RoundToTickAbove(minSL, sym);
         if(sl<=ask) return false;
        }
      sl = NormalizeDouble(sl, dg);
      return true;
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
   // Ensure symbol is visible/ready upfront
   if(!SymbolSelect(m_symbol, true))
     {
      PrintFormat("[SYMBOL] Failed to select on ctor: %s", m_symbol);
     }
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
   bool ok = false;
   // Guard: ensure symbol has valid market data before any normalization/sends
   if(!EnsureSymbolReady())
     {
      PrintFormat("[SYMBOL] Not ready for trading: %s. Skipping order %s", m_symbol, EnumToString(order.order_type));
      return false;
     }
   // Normalize volume for this symbol to avoid ERR_INVALID_VOLUME
   double vol = NormalizeVolume(m_lot_size);
   if(vol<=0.0)
     {
      double vmin=0,vmax=0,vstep=0; SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_MIN,vmin); SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_MAX,vmax); SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_STEP,vstep);
      PrintFormat("[VOL] Invalid normalized volume (%.4f). Symbol %s constraints: min=%.4f max=%.4f step=%.4f", vol, m_symbol, vmin, vmax, vstep);
      return false;
     }
   // Normalize stops and pending price according to broker constraints
   double sl = order.stop_loss;
   double tp = order.take_profit;
   double entry_px = order.price;
   NormalizeStops(order.order_type, entry_px, sl, tp);
   if((order.order_type==ORDER_TYPE_BUY || order.order_type==ORDER_TYPE_SELL) && (sl==0.0 || tp==0.0))
     {
      // Not fatal; we can open without one of the stops if broker distance too tight.
      PrintFormat("[STOPS] Adjusted SL/TP for %s on %s -> SL=%.5f TP=%.5f (entry px=%.5f)", EnumToString(order.order_type), m_symbol, sl, tp, entry_px);
     }

   switch(order.order_type)
     {
      case ORDER_TYPE_BUY:
         ok = m_trade.Buy(vol, m_symbol, 0, sl, tp);
         break;

      case ORDER_TYPE_SELL:
         ok = m_trade.Sell(vol, m_symbol, 0, sl, tp);
         break;

      case ORDER_TYPE_BUY_STOP:
         ok = m_trade.BuyStop(vol, entry_px, m_symbol, sl, tp);
         break;

      case ORDER_TYPE_SELL_STOP:
         ok = m_trade.SellStop(vol, entry_px, m_symbol, sl, tp);
         break;

      case ORDER_TYPE_BUY_LIMIT:
         ok = m_trade.BuyLimit(vol, entry_px, m_symbol, sl, tp);
         break;

      case ORDER_TYPE_SELL_LIMIT:
         ok = m_trade.SellLimit(vol, entry_px, m_symbol, sl, tp);
         break;

      default:
         Print("Unsupported order type in TradeManager: ", EnumToString(order.order_type));
         ok = false;
         break;
     }

   // Diagnostics: log retcode and identifiers regardless of success
   uint rc = m_trade.ResultRetcode();
   ulong deal = m_trade.ResultDeal();
   ulong ord  = m_trade.ResultOrder();
   double px  = m_trade.ResultPrice();
   PrintFormat("OrderSend: type=%s symbol=%s lots=%.4f retcode=%u deal=%I64u order=%I64u price=%.5f ok=%s",
               EnumToString(order.order_type), m_symbol, vol, rc, deal, ord, px, (ok?"true":"false"));

   return ok;
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
            // Normalize to broker rules (below Bid by min distance)
            double tmp_sl = new_sl;
            if(!NormalizeSLForPosition(sym, ptype, tmp_sl))
              { /* too close or invalid, skip */ }
            else
              {
               if(sl==0 || tmp_sl > sl + step)
                 {
                  double fbid=0.0, fask=0.0; SymbolInfoDouble(sym, SYMBOL_BID, fbid); SymbolInfoDouble(sym, SYMBOL_ASK, fask);
                  double needDist = MathMax(MinStopDistance(sym), FreezeDistance(sym));
                  if(sl==0 || tmp_sl > sl + step)
                  {
                   double fbid2=0.0, fask2=0.0; SymbolInfoDouble(sym, SYMBOL_BID, fbid2); SymbolInfoDouble(sym, SYMBOL_ASK, fask2);
                   double needDist2 = MathMax(MinStopDistance(sym), FreezeDistance(sym));
                   double tick = TickSize(sym);
                   if(MathAbs(tmp_sl - sl) < tick)
                     { PrintFormat("[TRAIL] %s BUY skip: delta<tick (sl=%.5f tmp=%.5f tick=%.5f)", sym, sl, tmp_sl, tick); }
                   else if(tmp_sl <= fbid2 - needDist2)
                     {
                      double new_sl_out = NormalizeDouble(tmp_sl, digits);
                      PrintFormat("[TRAIL] %s BUY modify: old_sl=%.5f -> new_sl=%.5f bid=%.5f needDist=%.5f", sym, sl, new_sl_out, fbid2, needDist2);
                      if(!m_trade.PositionModify(sym, new_sl_out, tp))
                        { PrintFormat("[TRAIL] %s BUY modify failed: ret=%d lastErr=%d", sym, m_trade.ResultRetcode(), GetLastError()); }
                     }
                   else
                     { PrintFormat("[TRAIL] %s BUY skip: inside needDist (tmp=%.5f bid=%.5f needDist=%.5f)", sym, tmp_sl, fbid2, needDist2); }
                  }
                 }
              }
           }
         else if(ptype==POSITION_TYPE_SELL)
           {
            if((open_price - ask) < activation)
               continue;
            double new_sl = NormalizeDouble(ask + distance, digits);
            double tmp_sl = new_sl;
            if(!NormalizeSLForPosition(sym, ptype, tmp_sl))
              { /* too close or invalid, skip */ }
            else
              {
               if(sl==0 || tmp_sl < sl - step)
                 {
                  double fbid=0.0, fask=0.0; SymbolInfoDouble(sym, SYMBOL_BID, fbid); SymbolInfoDouble(sym, SYMBOL_ASK, fask);
                  double needDist = MathMax(MinStopDistance(sym), FreezeDistance(sym));
                  if(sl==0 || tmp_sl < sl - step)
                  {
                   double fbid2=0.0, fask2=0.0; SymbolInfoDouble(sym, SYMBOL_BID, fbid2); SymbolInfoDouble(sym, SYMBOL_ASK, fask2);
                   double needDist2 = MathMax(MinStopDistance(sym), FreezeDistance(sym));
                   double tick = TickSize(sym);
                   if(MathAbs(tmp_sl - sl) < tick)
                     { PrintFormat("[TRAIL] %s SELL skip: delta<tick (sl=%.5f tmp=%.5f tick=%.5f)", sym, sl, tmp_sl, tick); }
                   else if(tmp_sl >= fask2 + needDist2)
                     {
                      double new_sl_out = NormalizeDouble(tmp_sl, digits);
                      PrintFormat("[TRAIL] %s SELL modify: old_sl=%.5f -> new_sl=%.5f ask=%.5f needDist=%.5f", sym, sl, new_sl_out, fask2, needDist2);
                      if(!m_trade.PositionModify(sym, new_sl_out, tp))
                        { PrintFormat("[TRAIL] %s SELL modify failed: ret=%d lastErr=%d", sym, m_trade.ResultRetcode(), GetLastError()); }
                     }
                   else
                     { PrintFormat("[TRAIL] %s SELL skip: inside needDist (tmp=%.5f ask=%.5f needDist=%.5f)", sym, tmp_sl, fask2, needDist2); }
                  }
                 }
              }
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
                  double tmp_sl = new_sl;
                  if(!NormalizeSLForPosition(sym, ptype, tmp_sl))
                    { /* too close or invalid, skip */ }
                  else
                    {
                     if(sl==0 || tmp_sl > sl + step)
                       {
                        double fbid=0.0, fask=0.0; SymbolInfoDouble(sym, SYMBOL_BID, fbid); SymbolInfoDouble(sym, SYMBOL_ASK, fask);
                        double needDist = MathMax(MinStopDistance(sym), FreezeDistance(sym));
                        double tick = TickSize(sym);
                        if(MathAbs(tmp_sl - sl) < tick)
                          { PrintFormat("[TRAIL] %s BUY(ATR) skip: delta<tick (sl=%.5f tmp=%.5f tick=%.5f)", sym, sl, tmp_sl, tick); }
                        else if(tmp_sl <= fbid - needDist)
                          {
                           double new_sl_out = NormalizeDouble(tmp_sl, digits);
                           PrintFormat("[TRAIL] %s BUY(ATR) modify: old_sl=%.5f -> new_sl=%.5f bid=%.5f needDist=%.5f", sym, sl, new_sl_out, fbid, needDist);
                           if(!m_trade.PositionModify(sym, new_sl_out, tp))
                             { PrintFormat("[TRAIL] %s BUY(ATR) modify failed: ret=%d lastErr=%d", sym, m_trade.ResultRetcode(), GetLastError()); }
                          }
                        else
                          { PrintFormat("[TRAIL] %s BUY(ATR) skip: inside needDist (tmp=%.5f bid=%.5f needDist=%.5f)", sym, tmp_sl, fbid, needDist); }
                       }
                    }
                 }
               else if(ptype==POSITION_TYPE_SELL)
                 {
                  if((open_price - ask) < activation)
                     { IndicatorRelease(handle); continue; }
                  double new_sl = NormalizeDouble(ask + atr_distance, digits);
                  double tmp_sl = new_sl;
                  if(!NormalizeSLForPosition(sym, ptype, tmp_sl))
                    { /* too close or invalid, skip */ }
                  else
                    {
                     if(sl==0 || tmp_sl < sl - step)
                       {
                        double fbid=0.0, fask=0.0; SymbolInfoDouble(sym, SYMBOL_BID, fbid); SymbolInfoDouble(sym, SYMBOL_ASK, fask);
                        double needDist = MathMax(MinStopDistance(sym), FreezeDistance(sym));
                        double tick = TickSize(sym);
                        if(MathAbs(tmp_sl - sl) < tick)
                          { PrintFormat("[TRAIL] %s SELL(ATR) skip: delta<tick (sl=%.5f tmp=%.5f tick=%.5f)", sym, sl, tmp_sl, tick); }
                        else if(tmp_sl >= fask + needDist)
                          {
                           double new_sl_out = NormalizeDouble(tmp_sl, digits);
                           PrintFormat("[TRAIL] %s SELL(ATR) modify: old_sl=%.5f -> new_sl=%.5f ask=%.5f needDist=%.5f", sym, sl, new_sl_out, fask, needDist);
                           if(!m_trade.PositionModify(sym, new_sl_out, tp))
                             { PrintFormat("[TRAIL] %s SELL(ATR) modify failed: ret=%d lastErr=%d", sym, m_trade.ResultRetcode(), GetLastError()); }
                          }
                        else
                          { PrintFormat("[TRAIL] %s SELL(ATR) skip: inside needDist (tmp=%.5f ask=%.5f needDist=%.5f)", sym, tmp_sl, fask, needDist); }
                       }
                    }
                 }
              }
            IndicatorRelease(handle);
           }
        }
     }
  }
