#ifndef DUALEA_STRATEGIES_OPENING_RANGE_BREAKOUT_MQH
#define DUALEA_STRATEGIES_OPENING_RANGE_BREAKOUT_MQH

#include "..\\IStrategy.mqh"
#include "..\\KnowledgeBase.mqh"
#include "..\\TradeManager.mqh"

class COpeningRangeBreakoutStrategy : public IStrategy
  {
private:
   // ORB params
   int              m_session_open_hour;  // server time hour
   int              m_session_open_min;   // server time minute
   int              m_orb_minutes;        // opening range duration in minutes
   double           m_buffer_points;      // extra points above/below range for stops

   // Risk params
   int              m_atrPeriod;
   double           m_atrMult;
   int              m_hATR;

   // Cached
   double           m_close1;
   double           m_atr1;
   double           m_orb_high;
   double           m_orb_low;
   datetime         m_orb_start_ts;
   datetime         m_orb_end_ts;
   // Robustness for higher TF charts: compute range on lower TF
   ENUM_TIMEFRAMES  m_orb_base_tf;
   // State: place only one pending per session day
   bool             m_pending_placed;
   int              m_anchor_day;

   datetime MakeSessionAnchor(const datetime now)
     {
      MqlDateTime dt; TimeToStruct(now, dt);
      dt.hour = m_session_open_hour; dt.min = m_session_open_min; dt.sec = 0;
      return StructToTime(dt);
     }

   int AnchorDay(const datetime ts)
     {
      MqlDateTime dt; TimeToStruct(ts, dt);
      return (dt.year*10000 + dt.mon*100 + dt.day);
     }

   void ComputeORBWindow()
     {
      datetime now = TimeCurrent();
      datetime anchor = MakeSessionAnchor(now);
      // if current time is before anchor (e.g., after midnight but before session start), shift anchor back one day
      if(now < anchor) anchor -= (24*60*60);
      m_orb_start_ts = anchor;
      m_orb_end_ts   = anchor + (m_orb_minutes*60);
     }

   void ComputeORBRange()
     {
      m_orb_high = 0.0; m_orb_low = 0.0;
      // Prefer a lower base TF (e.g., M5) to ensure enough bars in the ORB window on higher chart TFs
      ENUM_TIMEFRAMES tf_use = m_orb_base_tf;
      datetime from = m_orb_start_ts;
      datetime to   = (m_orb_end_ts>0 ? m_orb_end_ts-1 : m_orb_end_ts);
      double highs[]; double lows[];
      int nH = CopyHigh(m_symbol, tf_use, from, to, highs);
      int nL = CopyLow(m_symbol,  tf_use, from, to, lows);
      if(nH>0 && nL==nH)
        {
         for(int i=0;i<nH;++i)
           {
            double h = highs[i];
            double l = lows[i];
            if(h>0.0 && (m_orb_high==0.0 || h>m_orb_high)) m_orb_high=h;
            if(l>0.0 && (m_orb_low==0.0  || l<m_orb_low))  m_orb_low=l;
           }
        }

      // Fallback to strategy TF if base timeframe had no bars
      if(m_orb_high==0.0 || m_orb_low==0.0)
        {
         for(int i=1;i<500;++i)
           {
            datetime t = iTime(m_symbol, m_timeframe, i);
            if(t==0) break;
            if(t < m_orb_start_ts) break; // earlier than window
            if(t >= m_orb_end_ts) continue; // opened at/after end
            double h = iHigh(m_symbol, m_timeframe, i);
            double l = iLow(m_symbol,  m_timeframe, i);
            if(m_orb_high==0.0 || h>m_orb_high) m_orb_high=h;
            if(m_orb_low==0.0  || l<m_orb_low)  m_orb_low=l;
           }
        }
     }

public:
   COpeningRangeBreakoutStrategy(const string symbol, const ENUM_TIMEFRAMES tf) : IStrategy("OpeningRangeBreakoutStrategy", symbol, tf)
     {
      m_session_open_hour=8; m_session_open_min=0; m_orb_minutes=30; m_buffer_points=0;
      m_atrPeriod=14; m_atrMult=1.5; m_hATR=iATR(m_symbol, (ENUM_TIMEFRAMES)m_timeframe, m_atrPeriod);
      m_close1=0; m_atr1=0; m_orb_high=0; m_orb_low=0; m_orb_start_ts=0; m_orb_end_ts=0;
      m_orb_base_tf = PERIOD_M5; m_pending_placed=false; m_anchor_day=0;
     }

   virtual string Name(){ return "OpeningRangeBreakoutStrategy"; }

   virtual void Refresh()
     {
      m_close1 = iClose(m_symbol, m_timeframe, 1);
      // ATR(1)
      m_atr1=0.0; if(m_hATR>0){ double b[1]; if(CopyBuffer(m_hATR,0,1,1,b)==1) m_atr1=b[0]; }
      // Window and range
      ComputeORBWindow();
      // Reset daily placement state on new session day
      int day_now = AnchorDay(m_orb_start_ts);
      if(day_now!=m_anchor_day){ m_anchor_day=day_now; m_pending_placed=false; }
      // Only compute range if after the ORB end
      if(TimeCurrent() >= m_orb_end_ts) ComputeORBRange(); else { m_orb_high=0.0; m_orb_low=0.0; }
     }

   virtual TradeOrder CheckSignal()
     {
      TradeOrder ord; ord.strategy_name=Name();
      // Require ATR and an established ORB window
      if(m_atr1<=0) return ord;
      if(TimeCurrent() < m_orb_end_ts) return ord; // Not ready yet
      if(m_orb_high<=0 || m_orb_low<=0) return ord;
      // Prevent duplicate placements within the same session day
      if(m_pending_placed) return ord;

      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT); if(point<=0) point=_Point;
      int    digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      long   stops_level_pts = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double min_dist = (stops_level_pts>0 ? (double)stops_level_pts*point : 0.0);

      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double mid = 0.0; if(ask>0.0 && bid>0.0) mid=(ask+bid)/2.0; else mid=m_close1;

      // Choose the nearer side to current price and place a single pending stop
      double d_high = MathAbs(mid - m_orb_high);
      double d_low  = MathAbs(mid - m_orb_low);
      bool choose_buy = (d_high <= d_low);

      if(choose_buy)
        {
         ord.action=ACTION_BUY; ord.order_type=ORDER_TYPE_BUY_STOP;
         double raw = m_orb_high + m_buffer_points*point;
         double min_buy = ask + min_dist; if(raw < min_buy) raw = min_buy;
         ord.price = NormalizeDouble(raw, digits);
         ord.stop_loss = NormalizeDouble(ord.price - m_atrMult*m_atr1, digits);
         ord.take_profit = NormalizeDouble(ord.price + 2.0*(m_atrMult*m_atr1), digits);
        }
      else
        {
         ord.action=ACTION_SELL; ord.order_type=ORDER_TYPE_SELL_STOP;
         double raw = m_orb_low - m_buffer_points*point;
         double max_sell = bid - min_dist; if(raw > max_sell) raw = max_sell;
         ord.price = NormalizeDouble(raw, digits);
         ord.stop_loss = NormalizeDouble(ord.price + m_atrMult*m_atr1, digits);
         ord.take_profit = NormalizeDouble(ord.price - 2.0*(m_atrMult*m_atr1), digits);
        }

      ord.trailing_enabled=true; ord.trailing_type=TRAIL_ATR; ord.atr_period=m_atrPeriod; ord.atr_multiplier=m_atrMult;
      // Mark as placed for the current session day (EA will handle actual execution)
      m_pending_placed = true;
      return ord;
     }

   virtual void ExportFeatures(CFeaturesKB* kb, const datetime ts)
     {
      if(CheckPointer(kb)==POINTER_INVALID) return;
      (*kb).WriteKV(ts, m_symbol, Name(), "orb_high", m_orb_high);
      (*kb).WriteKV(ts, m_symbol, Name(), "orb_low",  m_orb_low);
      (*kb).WriteKV(ts, m_symbol, Name(), "orb_minutes", (double)m_orb_minutes);
      (*kb).WriteKV(ts, m_symbol, Name(), "atr", m_atr1);
     }
  };

#endif // DUALEA_STRATEGIES_OPENING_RANGE_BREAKOUT_MQH
