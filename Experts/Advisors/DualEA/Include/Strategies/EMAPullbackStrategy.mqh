#ifndef DUALEA_STRATEGIES_EMA_PULLBACK_MQH
#define DUALEA_STRATEGIES_EMA_PULLBACK_MQH

#include "..\\IStrategy.mqh"
#include "..\\KnowledgeBase.mqh"
#include "..\\TradeManager.mqh"

class CEMAPullbackStrategy : public IStrategy
  {
private:
   int              m_fastPeriod;
   int              m_slowPeriod;
   int              m_hFast;
   int              m_hSlow;

   int              m_adxPeriod;
   int              m_hADX;

   int              m_atrPeriod;
   double           m_atrMult;
   int              m_hATR;

   // cached
   double           m_close1, m_close2;
   double           m_fast1, m_slow1;
   double           m_adx1, m_atr1;

public:
   CEMAPullbackStrategy(const string symbol, const ENUM_TIMEFRAMES tf) : IStrategy("EMAPullbackStrategy", symbol, tf)
     {
      m_fastPeriod=20; m_slowPeriod=50;
      m_hFast = iMA(symbol, tf, m_fastPeriod, 0, MODE_EMA, PRICE_CLOSE);
      m_hSlow = iMA(symbol, tf, m_slowPeriod, 0, MODE_EMA, PRICE_CLOSE);
      m_adxPeriod=14; m_hADX=iADX(symbol, tf, m_adxPeriod);
      m_atrPeriod=14; m_atrMult=2.0; m_hATR=iATR(symbol, tf, m_atrPeriod);
      m_close1=m_close2=0; m_fast1=m_slow1=0; m_adx1=0; m_atr1=0;
     }

   virtual string Name(){ return "EMAPullbackStrategy"; }

   virtual void Refresh()
     {
      m_close1=iClose(m_symbol, m_timeframe, 1);
      m_close2=iClose(m_symbol, m_timeframe, 2);
      double b[1];
      m_fast1=0.0; if(m_hFast>0 && CopyBuffer(m_hFast,0,1,1,b)==1) m_fast1=b[0];
      m_slow1=0.0; if(m_hSlow>0 && CopyBuffer(m_hSlow,0,1,1,b)==1) m_slow1=b[0];
      m_adx1 =0.0; if(m_hADX>0  && CopyBuffer(m_hADX, 0,1,1,b)==1) m_adx1=b[0];
      m_atr1 =0.0; if(m_hATR>0  && CopyBuffer(m_hATR, 0,1,1,b)==1) m_atr1=b[0];
     }

   virtual TradeOrder CheckSignal()
     {
      TradeOrder ord; ord.strategy_name=Name();
      if(m_close1<=0 || m_fast1<=0 || m_slow1<=0 || m_atr1<=0) return ord;
      bool up_trend   = (m_fast1 > m_slow1);
      bool down_trend = (m_fast1 < m_slow1);
      bool strong     = (m_adx1 >= 20.0 || m_adx1==0.0);
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);

      // Long: cross above fast EMA from below in an uptrend
      if(up_trend && strong && m_close1 > m_fast1 && m_close2 <= m_fast1)
        {
         ord.action = ACTION_BUY; ord.order_type = ORDER_TYPE_BUY;
         double sl = m_close1 - m_atrMult*m_atr1;
         double tp = m_close1 + 2.0*(m_close1 - sl);
         ord.stop_loss   = NormalizeDouble(sl, digits);
         ord.take_profit = NormalizeDouble(tp, digits);
         ord.trailing_enabled=true; ord.trailing_type=TRAIL_ATR; ord.atr_period=m_atrPeriod; ord.atr_multiplier=m_atrMult;
         return ord;
        }

      // Short: cross below fast EMA from above in a downtrend
      if(down_trend && strong && m_close1 < m_fast1 && m_close2 >= m_fast1)
        {
         ord.action = ACTION_SELL; ord.order_type = ORDER_TYPE_SELL;
         double sl = m_close1 + m_atrMult*m_atr1;
         double tp = m_close1 - 2.0*(sl - m_close1);
         ord.stop_loss   = NormalizeDouble(sl, digits);
         ord.take_profit = NormalizeDouble(tp, digits);
         ord.trailing_enabled=true; ord.trailing_type=TRAIL_ATR; ord.atr_period=m_atrPeriod; ord.atr_multiplier=m_atrMult;
         return ord;
        }

      return ord;
     }

   virtual void ExportFeatures(CFeaturesKB* kb, const datetime ts)
     {
      if(CheckPointer(kb)==POINTER_INVALID) return;
      (*kb).WriteKV(ts, m_symbol, Name(), "ema_fast", m_fast1);
      (*kb).WriteKV(ts, m_symbol, Name(), "ema_slow", m_slow1);
      (*kb).WriteKV(ts, m_symbol, Name(), "adx", m_adx1);
      (*kb).WriteKV(ts, m_symbol, Name(), "atr", m_atr1);
     }
  };

#endif // DUALEA_STRATEGIES_EMA_PULLBACK_MQH
