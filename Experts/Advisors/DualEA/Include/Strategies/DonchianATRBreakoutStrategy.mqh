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
      m_close1 = iClose(m_symbol, m_tf, 1);
      m_up1 = m_dc.Upper(1);
      m_lo1 = m_dc.Lower(1);
      double b[1]; if(m_hATR>0 && CopyBuffer(m_hATR,0,1,1,b)==1) m_atr1=b[0];
     }
   virtual TradeOrder CheckSignal()
     {
      TradeOrder ord; ord.strategy_name=Name();
      if(m_close1<=0 || m_up1<=0 || m_lo1<=0 || m_atr1<=0) return ord;
      // Long breakout: price near upper channel
      if(m_close1>=m_up1)
        {
         ord.action=ACTION_BUY; ord.order_type=ORDER_TYPE_BUY_STOP; ord.price=m_up1 + (5*_Point);
         ord.stop_loss = m_close1 - m_atrMult*m_atr1; ord.take_profit = m_close1 + 2.0*(m_atrMult*m_atr1);
         ord.trailing_enabled=true; ord.trailing_type=TRAIL_ATR; ord.atr_period=m_atrPeriod; ord.atr_multiplier=m_atrMult; return ord;
        }
      // Short breakout
      if(m_close1<=m_lo1)
        {
         ord.action=ACTION_SELL; ord.order_type=ORDER_TYPE_SELL_STOP; ord.price=m_lo1 - (5*_Point);
         ord.stop_loss = m_close1 + m_atrMult*m_atr1; ord.take_profit = m_close1 - 2.0*(m_atrMult*m_atr1);
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
