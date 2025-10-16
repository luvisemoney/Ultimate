// TradeManager.mqh
// Handles all trade execution logic.

#property copyright "2025, Windsurf Engineering"
#property link      "https://www.windsurf.ai"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Object.mqh>
#include "IStrategy.mqh"
#include "..\Include\Indicators\ATR.mqh"
#include "LogMiddleware.mqh"

// Use TrailingType from IStrategy.mqh instead of defining a duplicate enum

class CTradeManager
  {
private:
   // Trailing stop configuration
   class CTrailConfig : public CObject
     {
   public:
      string            symbol;             // Symbol this config applies to
      bool              enabled;            // Whether trailing is enabled
      TrailingType      type;               // Type of trailing (points, ATR, etc.)
      int               distance_points;    // Distance in points for fixed trailing
      int               activation_points;  // Activation distance in points
      int               step_points;        // Minimum step in points for adjustment
      int               atr_period;         // Period for ATR calculation
      double            atr_multiplier;     // Multiplier for ATR distance
      
      // Constructor with defaults
      CTrailConfig() : enabled(false), type(TRAIL_NONE), distance_points(100), 
                      activation_points(50), step_points(10), atr_period(14), 
                      atr_multiplier(2.0) {}
     };

   CTrade            m_trade;
   string            m_symbol;
   double            m_lot_size;
   int               m_magic_number;
   CArrayObj         m_trails;           // Array of CTrailConfig objects

   // Find trail configuration by symbol - implementation moved to public section
   
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
         LOG(StringFormat("[VOL] Normalized volume %.4f out of bounds [%.4f..%.4f] step=%.5f for %s, falling back to min",
                     norm, vmin, vmax, vstep, m_symbol));
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
         LOG(StringFormat("[SYMBOL] Failed to select symbol %s", m_symbol));
         return false;
        }
      // Check trading mode
      long tmode = 0; SymbolInfoInteger(m_symbol, SYMBOL_TRADE_MODE, tmode);
      if(tmode==SYMBOL_TRADE_MODE_DISABLED)
        {
         LOG(StringFormat("[SYMBOL] Trading disabled for %s", m_symbol));
         return false;
        }
      // Get latest tick
      MqlTick tick; if(!SymbolInfoTick(m_symbol, tick))
        {
         LOG(StringFormat("[SYMBOL] No tick for %s", m_symbol));
         return false;
        }
      if(tick.bid<=0.0 || tick.ask<=0.0)
        {
         LOG(StringFormat("[SYMBOL] Invalid bid/ask for %s (bid=%.5f ask=%.5f)", m_symbol, tick.bid, tick.ask));
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

   // Compute safe default SL/TP using ATR and broker min distances when one or both are missing
   void              EnsureFallbackStops(const ENUM_ORDER_TYPE otype, double &entry_price, double &sl, double &tp)
     {
      if(sl>0.0 && tp>0.0) return; // already provided
      double bid=0.0, ask=0.0; SymbolInfoDouble(m_symbol, SYMBOL_BID, bid); SymbolInfoDouble(m_symbol, SYMBOL_ASK, ask);
      double pt=0.0; SymbolInfoDouble(m_symbol, SYMBOL_POINT, pt);
      if(pt<=0.0) pt = TickSize();
      double needDist = MathMax(MinStopDistance(), FreezeDistance());
      // Try ATR-based distance (14-period on current chart TF)
      double atr_dist = 0.0;
      int h = iATR(m_symbol, _Period, 14);
      if(h!=INVALID_HANDLE)
        {
         double buf[]; int c = CopyBuffer(h, 0, 0, 1, buf);
         IndicatorRelease(h);
         if(c==1 && buf[0]>0.0) atr_dist = buf[0] * 2.0; // 2x ATR for SL/TP baseline
        }
      if(atr_dist<=0.0)
        {
         // Fallback to conservative multiple of broker min distance or 100 points
         double fallback = 100.0 * pt;
         atr_dist = MathMax(fallback, needDist * 3.0);
        }
      // Use entry price if provided (pending orders), else use current market
      if(otype==ORDER_TYPE_BUY || otype==ORDER_TYPE_BUY_LIMIT || otype==ORDER_TYPE_BUY_STOP)
        {
         double ref_sl = (entry_price>0.0 ? entry_price : bid);
         double ref_tp = (entry_price>0.0 ? entry_price : ask);
         if(sl<=0.0) sl = RoundToTickBelow(ref_sl - MathMax(atr_dist, needDist), m_symbol);
         if(tp<=0.0) tp = RoundToTickAbove(ref_tp + MathMax(atr_dist, needDist), m_symbol);
        }
      else if(otype==ORDER_TYPE_SELL || otype==ORDER_TYPE_SELL_LIMIT || otype==ORDER_TYPE_SELL_STOP)
        {
         double ref_sl = (entry_price>0.0 ? entry_price : ask);
         double ref_tp = (entry_price>0.0 ? entry_price : bid);
         if(sl<=0.0) sl = RoundToTickAbove(ref_sl + MathMax(atr_dist, needDist), m_symbol);
         if(tp<=0.0) tp = RoundToTickBelow(ref_tp - MathMax(atr_dist, needDist), m_symbol);
        }
     }
   // Find trail config by symbol - implementation is in the public section
     
   // Normalize SL for an existing position with given side; return false if cannot make valid
   bool NormalizeSLForPosition(const ENUM_POSITION_TYPE ptype, double &sl)
     {
      return NormalizeSLForPosition(m_symbol, ptype, sl);
     }
   bool NormalizeSLForPosition(const string sym, const ENUM_POSITION_TYPE ptype, double &sl)
     {
      double bid = 0.0, ask = 0.0; 
      if(!SymbolInfoDouble(sym, SYMBOL_BID, bid) || !SymbolInfoDouble(sym, SYMBOL_ASK, ask))
         return false;
         
      double minDist = MinStopDistance(sym);
      double frz = FreezeDistance(sym);
      double needDist = MathMax(minDist, frz);
      int dg = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      
      if(ptype == POSITION_TYPE_BUY)
        {
         if(sl <= 0.0) return false;
         double maxSL = bid - needDist;
         if(sl >= bid || (bid - sl) < needDist) sl = RoundToTickBelow(maxSL, sym);
         if(sl >= bid) return false;
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         if(sl <= 0.0) return false;
         double minSL = ask + needDist;
         if(sl <= ask || (sl - ask) < needDist) sl = RoundToTickAbove(minSL, sym);
         if(sl <= ask) return false;
        }
      
      sl = NormalizeDouble(sl, dg);
      return true;
     }

   // Find trailing configuration by symbol
   CTrailConfig* FindTrailBySymbol(const string symbol)
     {
      for(int i = 0; i < m_trails.Total(); i++)
        {
         CTrailConfig* cfg = (CTrailConfig*)m_trails.At(i);
         if(cfg != NULL && cfg.symbol == symbol)
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
   
   // Find trail configuration by symbol (implementation moved from private section)
   CTrailConfig*     FindTrailConfig(const string symbol);
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
      LOG(StringFormat("[SYMBOL] Failed to select on ctor: %s", m_symbol));
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
   if(!EnsureSymbolReady())
     {
      LOG(StringFormat("[SYMBOL] Not ready for trading: %s. Skipping order %s", m_symbol, EnumToString(order.order_type)));
      return false;
     }
   double vol_in = (order.lots>0.0 ? order.lots : m_lot_size);
   bool   lots_overridden = (order.lots>0.0);
   double vol = NormalizeVolume(vol_in);
   if(vol<=0.0)
     {
      double vmin=0,vmax=0,vstep=0; SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_MIN,vmin); SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_MAX,vmax); SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_STEP,vstep);
      LOG(StringFormat("[VOL] Invalid normalized volume (%.4f). Symbol %s constraints: min=%.4f max=%.4f step=%.4f", vol, m_symbol, vmin, vmax, vstep));
      return false;
     }
   double sl = order.stop_loss;
   double tp = order.take_profit;
   double entry_px = order.price;
   NormalizeStops(order.order_type, entry_px, sl, tp);
   // Enforce fallback SL/TP if missing
   if(sl<=0.0 || tp<=0.0)
     {
      EnsureFallbackStops(order.order_type, entry_px, sl, tp);
      NormalizeStops(order.order_type, entry_px, sl, tp);
     }
   // Log final stops state
   if(sl==0.0 || tp==0.0)
     {
      LOG(StringFormat("[STOPS] Warning: SL/TP zero after fallback for %s on %s -> SL=%.5f TP=%.5f (entry=%.5f)", EnumToString(order.order_type), m_symbol, sl, tp, entry_px));
     }
   else
     {
      LOG(StringFormat("[STOPS] Using SL/TP for %s on %s -> SL=%.5f TP=%.5f (entry=%.5f)", EnumToString(order.order_type), m_symbol, sl, tp, entry_px));
     }
   
   // CRITICAL SAFETY CHECK: Prevent execution without SL/TP
   if(sl <= 0.0 || tp <= 0.0)
     {
      LOG(StringFormat("[SAFETY] BLOCKING ORDER: Cannot execute %s on %s without valid SL/TP (SL=%.5f TP=%.5f)", 
                  EnumToString(order.order_type), m_symbol, sl, tp));
      LOG("[SAFETY] This indicates a critical bug in signal generation or gate processing");
      LOG(StringFormat("[SAFETY] Order details: entry=%.5f volume=%.4f strategy=%s", entry_px, vol, order.strategy_name));
      return false; // BLOCK EXECUTION
     }

   int max_attempts = 3;
   int attempt = 0;
   ulong t_start = GetTickCount();
   for(attempt=1; attempt<=max_attempts; ++attempt)
   {
     ok = false;
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
        LOG(StringFormat("Unsupported order type in TradeManager: %s", EnumToString(order.order_type)));
        ok = false;
        break;
     }
     uint rc = m_trade.ResultRetcode();
     ulong deal = m_trade.ResultDeal();
     ulong ord  = m_trade.ResultOrder();
     double px  = m_trade.ResultPrice();
     datetime now = TimeCurrent();
     LOG(StringFormat("OrderSend: type=%s symbol=%s lots_req=%.4f lots_used=%.4f override=%s retcode=%u deal=%I64u order=%I64u price=%.5f ok=%s attempt=%d time=%s",
                 EnumToString(order.order_type), m_symbol, vol_in, vol, (lots_overridden?"true":"false"), rc, deal, ord, px, (ok?"true":"false"), attempt, TimeToString(now, TIME_DATE|TIME_SECONDS)));
     if(ok) break;
     // Only retry on transient errors (requote, busy, timeout, etc.)
     if(rc==10004 || rc==10006 || rc==10007 || rc==10009 || rc==10010 || rc==10013 || rc==10014)
     {
       LOG(StringFormat("[RETRY] Trade failed with retcode=%u (attempt %d/%d) at %s. Sleeping before retry...", rc, attempt, max_attempts, TimeToString(now, TIME_DATE|TIME_SECONDS)));
       Sleep(200);
     }
     else
     {
       LOG(StringFormat("[FAIL] Trade failed with non-retryable retcode=%u at %s. Aborting retries.", rc, TimeToString(now, TIME_DATE|TIME_SECONDS)));
       break;
     }
    }
    ulong t_end = GetTickCount();
    LOG(StringFormat("OrderSend: total attempts=%d duration_ms=%d final_ok=%s", attempt, (int)(t_end-t_start), (ok?"true":"false")));
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
   cfg.distance_points = (int)order.trail_distance_points;
   cfg.activation_points = (int)order.trail_activation_points;
   cfg.step_points = (int)order.trail_step_points;
   cfg.atr_period = (int)order.atr_period;
   cfg.atr_multiplier = (int)order.atr_multiplier;
  }

//+------------------------------------------------------------------+
//| Update trailing stops for all positions with our magic number     |
//+------------------------------------------------------------------+
void CTradeManager::UpdateTrailingStops()
  {
   int total = PositionsTotal();
   for(int i=0;i<total;++i)
     {
      // Ensure a valid position context is selected before reading properties
      ulong tk = PositionGetTicket(i);
      if(tk==0)
         continue;
      if(!PositionSelectByTicket(tk))
         continue;
     string sym = PositionGetString(POSITION_SYMBOL);
     if(sym=="")
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
                     { LOG(StringFormat("[TRAIL] %s BUY skip: delta<tick (sl=%.5f tmp=%.5f tick=%.5f)", sym, sl, tmp_sl, tick)); }
                   else if(tmp_sl <= fbid2 - needDist2)
                     {
                      double new_sl_out = NormalizeDouble(tmp_sl, digits);
                      // Extra guard: avoid server-side 10025 (no change) by skipping equal normalized SL
                      double cur_sl_norm = NormalizeDouble(sl, digits);
                      if(MathAbs(new_sl_out - cur_sl_norm) < (tick*0.1))
                        { LOG(StringFormat("[TRAIL] %s BUY skip: no-change after normalize (sl=%.5f new=%.5f)", sym, sl, new_sl_out)); }
                      else
                        {
                       LOG(StringFormat("[TRAIL] %s BUY modify: old_sl=%.5f -> new_sl=%.5f bid=%.5f needDist=%.5f", sym, sl, new_sl_out, fbid2, needDist2));
                       if(!m_trade.PositionModify(sym, new_sl_out, tp))
                         { LOG(StringFormat("[TRAIL] %s BUY modify failed: ret=%d lastErr=%d", sym, m_trade.ResultRetcode(), GetLastError())); }
                        }
                     }
                   else
                     { LOG(StringFormat("[TRAIL] %s BUY skip: inside needDist (tmp=%.5f bid=%.5f needDist=%.5f)", sym, tmp_sl, fbid2, needDist2)); }
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
                     { LOG(StringFormat("[TRAIL] %s SELL skip: delta<tick (sl=%.5f tmp=%.5f tick=%.5f)", sym, sl, tmp_sl, tick)); }
                   else if(tmp_sl >= fask2 + needDist2)
                     {
                      double new_sl_out = NormalizeDouble(tmp_sl, digits);
                      // Extra guard: avoid server-side 10025 (no change) by skipping equal normalized SL
                      double cur_sl_norm = NormalizeDouble(sl, digits);
                      if(MathAbs(new_sl_out - cur_sl_norm) < (tick*0.1))
                        { LOG(StringFormat("[TRAIL] %s SELL skip: no-change after normalize (sl=%.5f new=%.5f)", sym, sl, new_sl_out)); }
                      else
                        {
                       LOG(StringFormat("[TRAIL] %s SELL modify: old_sl=%.5f -> new_sl=%.5f ask=%.5f needDist=%.5f", sym, sl, new_sl_out, fask2, needDist2));
                       if(!m_trade.PositionModify(sym, new_sl_out, tp))
                         { LOG(StringFormat("[TRAIL] %s SELL modify failed: ret=%d lastErr=%d", sym, m_trade.ResultRetcode(), GetLastError())); }
                        }
                     }
                   else
                     { LOG(StringFormat("[TRAIL] %s SELL skip: inside needDist (tmp=%.5f ask=%.5f needDist=%.5f)", sym, tmp_sl, fask2, needDist2)); }
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
                          { LOG(StringFormat("[TRAIL] %s BUY(ATR) skip: delta<tick (sl=%.5f tmp=%.5f tick=%.5f)", sym, sl, tmp_sl, tick)); }
                        else if(tmp_sl <= fbid - needDist)
                          {
                           double new_sl_out = NormalizeDouble(tmp_sl, digits);
                           // Extra guard: avoid server-side 10025 (no change) by skipping equal normalized SL
                           double cur_sl_norm = NormalizeDouble(sl, digits);
                           if(MathAbs(new_sl_out - cur_sl_norm) < (tick*0.1))
                             { LOG(StringFormat("[TRAIL] %s BUY(ATR) skip: no-change after normalize (sl=%.5f new=%.5f)", sym, sl, new_sl_out)); }
                           else
                             {
                           LOG(StringFormat("[TRAIL] %s BUY(ATR) modify: old_sl=%.5f -> new_sl=%.5f bid=%.5f needDist=%.5f", sym, sl, new_sl_out, fbid, needDist));
                           if(!m_trade.PositionModify(sym, new_sl_out, tp))
                             { LOG(StringFormat("[TRAIL] %s BUY(ATR) modify failed: ret=%d lastErr=%d", sym, m_trade.ResultRetcode(), GetLastError())); }
                             }
                          }
                        else
                          { LOG(StringFormat("[TRAIL] %s BUY(ATR) skip: inside needDist (tmp=%.5f bid=%.5f needDist=%.5f)", sym, tmp_sl, fbid, needDist)); }
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
                          { LOG(StringFormat("[TRAIL] %s SELL(ATR) skip: delta<tick (sl=%.5f tmp=%.5f tick=%.5f)", sym, sl, tmp_sl, tick)); }
                        else if(tmp_sl >= fask + needDist)
                          {
                           double new_sl_out = NormalizeDouble(tmp_sl, digits);
                           // Extra guard: avoid server-side 10025 (no change) by skipping equal normalized SL
                           double cur_sl_norm = NormalizeDouble(sl, digits);
                           if(MathAbs(new_sl_out - cur_sl_norm) < (tick*0.1))
                             { LOG(StringFormat("[TRAIL] %s SELL(ATR) skip: no-change after normalize (sl=%.5f new=%.5f)", sym, sl, new_sl_out)); }
                           else
                             {
                           LOG(StringFormat("[TRAIL] %s SELL(ATR) modify: old_sl=%.5f -> new_sl=%.5f ask=%.5f needDist=%.5f", sym, sl, new_sl_out, fask, needDist));
                           if(!m_trade.PositionModify(sym, new_sl_out, tp))
                             { LOG(StringFormat("[TRAIL] %s SELL(ATR) modify failed: ret=%d lastErr=%d", sym, m_trade.ResultRetcode(), GetLastError())); }
                             }
                          }
                        else
                          { LOG(StringFormat("[TRAIL] %s SELL(ATR) skip: inside needDist (tmp=%.5f ask=%.5f needDist=%.5f)", sym, tmp_sl, fask, needDist)); }
                       }
                    }
                 }
              }
            IndicatorRelease(handle);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Find trail configuration by symbol                              |
//+------------------------------------------------------------------+
CTradeManager::CTrailConfig* CTradeManager::FindTrailConfig(const string symbol)
  {
   for(int i = 0; i < m_trails.Total(); i++)
     {
      CTradeManager::CTrailConfig* config = (CTradeManager::CTrailConfig*)m_trails.At(i);
      if(config != NULL && config.symbol == symbol)
        return config;
     }
   return NULL;
  }
