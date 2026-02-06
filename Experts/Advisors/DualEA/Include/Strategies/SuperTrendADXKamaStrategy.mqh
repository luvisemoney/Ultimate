#include "..\\IStrategy.mqh"
#include "..\\KnowledgeBase.mqh"
#include "..\\TradeManager.mqh"
#include "..\\Indicators\\SuperTrend.mqh"
#include "..\\Indicators\\KAMA.mqh"

class CSuperTrendADXKamaStrategy : public IStrategy
  {
private:
   int             m_adxPeriod;
   int             m_atrPeriod;
   double          m_atrMult;
   int             m_kamaPeriod;
   int             m_adxThreshold;

   CSuperTrend     m_st;
   CKAMA           m_kama;
   int             m_hATR;
   int             m_hADX;

   // pending order config
   bool            m_usePending;     // place limit pullbacks instead of market
   double          m_pullbackPoints; // distance in points from KAMA/band

   // cached
   double m_close0, m_close1;
   double m_atr1;
   double m_adx1;
   int    m_dir1;
   double m_kama_val1, m_kama_slope1;

public:
   CSuperTrendADXKamaStrategy(const string symbol, const ENUM_TIMEFRAMES tf) : IStrategy("SuperTrendADXKamaStrategy", symbol, tf)
     {
      m_adxPeriod = 14; m_atrPeriod = 14; m_atrMult = 2.0; m_kamaPeriod=30; m_adxThreshold=22;
      m_st.Init(symbol, tf, 10, 3.0);
      m_kama.Init(symbol, tf, 10, 2, 30);
      m_hATR = iATR(symbol, tf, m_atrPeriod);
      m_hADX = iADX(symbol, tf, m_adxPeriod);
      m_close0=m_close1=0; m_atr1=0; m_adx1=0; m_dir1=0; m_kama_val1=0; m_kama_slope1=0;
      m_usePending=false; m_pullbackPoints=10;
     }

   virtual string Name() { return "SuperTrendADXKamaStrategy"; }

   virtual void Refresh()
     {
      m_close0 = iClose(m_symbol, m_timeframe, 0);
      m_close1 = iClose(m_symbol, m_timeframe, 1);
      // Copy ATR(1)
      double buf[1];
      m_atr1 = 0.0; m_adx1 = 0.0;
      if(m_hATR>0 && CopyBuffer(m_hATR, 0, 1, 1, buf)==1) m_atr1 = buf[0];
      if(m_hADX>0 && CopyBuffer(m_hADX, 0, 1, 1, buf)==1) m_adx1 = buf[0];
      m_dir1   = m_st.Direction(1);
      m_kama_val1   = m_kama.Value(1);
      m_kama_slope1 = m_kama.Slope(1);
     }

   virtual TradeOrder CheckSignal()
     {
      TradeOrder ord; ord.strategy_name = Name();
      // Basic guards
      if(m_atr1<=0 || m_close1<=0) return ord;
      // Trend filter and regime
      bool trend_up   = (m_dir1>0);
      bool trend_down = (m_dir1<0);
      bool strong_trend = (m_adx1 >= m_adxThreshold);
      // Pullback logic: price near KAMA with slope in trend direction
      bool kama_up    = (m_kama_slope1>0);
      bool kama_down  = (m_kama_slope1<0);

      // Long setup
      if(trend_up && strong_trend && kama_up && m_close1 >= m_kama_val1)
        {
         ord.action = ACTION_BUY;
         if(m_usePending){ ord.order_type = ORDER_TYPE_BUY_LIMIT; ord.price = m_kama_val1 + (m_pullbackPoints*_Point); }
         else { ord.order_type = ORDER_TYPE_BUY; }
         // ATR based stop
         double sl = m_close1 - m_atrMult*m_atr1;
         ord.stop_loss = sl;
         // optional TP: 2R
         ord.take_profit = m_close1 + 2.0*(m_close1 - sl);
         // trailing via ATR
         ord.trailing_enabled = true; ord.trailing_type = TRAIL_ATR; ord.atr_period=m_atrPeriod; ord.atr_multiplier=m_atrMult;
         return ord;
        }
      // Short setup
      if(trend_down && strong_trend && kama_down && m_close1 <= m_kama_val1)
        {
         ord.action = ACTION_SELL;
         if(m_usePending){ ord.order_type = ORDER_TYPE_SELL_LIMIT; ord.price = m_kama_val1 - (m_pullbackPoints*_Point); }
         else { ord.order_type = ORDER_TYPE_SELL; }
         double sl = m_close1 + m_atrMult*m_atr1;
         ord.stop_loss = sl;
         ord.take_profit = m_close1 - 2.0*(sl - m_close1);
         ord.trailing_enabled = true; ord.trailing_type = TRAIL_ATR; ord.atr_period=m_atrPeriod; ord.atr_multiplier=m_atrMult;
         return ord;
        }
      return ord;
     }

   virtual void ExportFeatures(CFeaturesKB* kb, const datetime ts)
     {
      if(CheckPointer(kb)==POINTER_INVALID) return;
      (*kb).WriteKV(ts, m_symbol, Name(), "adx", m_adx1);
      (*kb).WriteKV(ts, m_symbol, Name(), "supertrend_dir", (double)m_dir1);
      (*kb).WriteKV(ts, m_symbol, Name(), "kama_val", m_kama_val1);
      (*kb).WriteKV(ts, m_symbol, Name(), "kama_slope", m_kama_slope1);
      (*kb).WriteKV(ts, m_symbol, Name(), "atr", m_atr1);
     }
  };
