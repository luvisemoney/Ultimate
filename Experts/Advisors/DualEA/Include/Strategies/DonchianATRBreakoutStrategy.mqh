#include "..\\IStrategy.mqh"
#include "..\\KnowledgeBase.mqh"
#include "..\\TradeManager.mqh"
#include "..\\Indicators\\Donchian.mqh"

class CDonchianATRBreakoutStrategy : public IStrategy
  {
private:
   string m_symbol; ENUM_TIMEFRAMES m_tf;
   CDonchian m_dc; int m_dcPeriod;
   int m_hATR; int m_atrPeriod; double m_atrMult;
   // cached
   double m_up1, m_lo1, m_close1, m_atr1;
public:
   CDonchianATRBreakoutStrategy(const string symbol, const ENUM_TIMEFRAMES tf)
     {
      m_symbol=symbol; m_tf=tf; m_dcPeriod=20; m_atrPeriod=14; m_atrMult=2.0;
      m_dc.Init(symbol, tf, m_dcPeriod);
      m_hATR = iATR(symbol, tf, m_atrPeriod);
      m_up1=m_lo1=m_close1=m_atr1=0;
     }
   virtual string Name(){ return "DonchianATRBreakoutStrategy"; }
   virtual void Refresh()
     {
      // closed bar values
      m_close1 = iClose(m_symbol, m_tf, 1);
      m_up1 = m_dc.Upper(1);
      m_lo1 = m_dc.Lower(1);

      // ATR readiness checks and read
      m_atr1 = 0.0;
      if(m_hATR>0)
        {
         int bc = BarsCalculated(m_hATR);
         if(bc>0)
           {
            double b[]; ArraySetAsSeries(b, true);
            if(CopyBuffer(m_hATR, 0, 1, 1, b)==1)
               m_atr1 = b[0];
           }
        }
     }
   virtual TradeOrder CheckSignal()
     {
      TradeOrder ord; ord.strategy_name=Name();
      if(m_close1<=0 || m_up1<=0 || m_lo1<=0 || m_atr1<=0) return ord;
      // Long breakout: price near upper channel
      if(m_close1>=m_up1)
        {
         ord.action=ACTION_BUY; ord.order_type=ORDER_TYPE_BUY_STOP;
         double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT); if(point<=0) point=_Point;
         int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
         double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
         long stops_level_pts = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
         double min_dist = (stops_level_pts>0 ? (double)stops_level_pts*point : 0.0);
         double raw_price = m_up1 + 5.0*point;
         // ensure buy stop above ask + min distance
         double min_buy_stop = ask + min_dist;
         if(raw_price < min_buy_stop) raw_price = min_buy_stop;
         ord.price = NormalizeDouble(raw_price, digits);
         // ATR-based SL/TP with spread/min distance checks
         double atr = GetATR(m_atrPeriod, 0);
         double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double min_stop = MathMax(atr * m_atrMult, MathMax(spread*3, SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point));
         ord.stop_loss = NormalizeDouble(ord.price - min_stop, digits);
         ord.take_profit = NormalizeDouble(ord.price + 2.0*min_stop, digits);
         if(spread > min_stop*0.5) return ord;
         ord.trailing_enabled=true; ord.trailing_type=TRAIL_ATR; ord.atr_period=m_atrPeriod; ord.atr_multiplier=m_atrMult; return ord;
        }
      // Short breakout
      if(m_close1<=m_lo1)
        {
         ord.action=ACTION_SELL; ord.order_type=ORDER_TYPE_SELL_STOP;
         double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT); if(point<=0) point=_Point;
         int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
         double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
         long stops_level_pts = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
         double min_dist = (stops_level_pts>0 ? (double)stops_level_pts*point : 0.0);
         double raw_price = m_lo1 - 5.0*point;
         // ensure sell stop below bid - min distance
         double max_sell_stop = bid - min_dist;
         if(raw_price > max_sell_stop) raw_price = max_sell_stop;
         ord.price = NormalizeDouble(raw_price, digits);
         // ATR-based SL/TP with spread/min distance checks
         double atr = GetATR(m_atrPeriod, 0);
         double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double min_stop = MathMax(atr * m_atrMult, MathMax(spread*3, SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point));
         ord.stop_loss = NormalizeDouble(ord.price + min_stop, digits);
         ord.take_profit = NormalizeDouble(ord.price - 2.0*min_stop, digits);
         if(spread > min_stop*0.5) return ord;
         ord.trailing_enabled=true; ord.trailing_type=TRAIL_ATR; ord.atr_period=m_atrPeriod; ord.atr_multiplier=m_atrMult; return ord;
        }
      return ord;
     }
   virtual void ExportFeatures(CFeaturesKB* kb, const datetime ts)
     {
      if(CheckPointer(kb)==POINTER_INVALID) return;
      (*kb).WriteKV(ts, m_symbol, Name(), "dc_upper", m_up1);
      (*kb).WriteKV(ts, m_symbol, Name(), "dc_lower", m_lo1);
      (*kb).WriteKV(ts, m_symbol, Name(), "atr", m_atr1);
     }
  };
