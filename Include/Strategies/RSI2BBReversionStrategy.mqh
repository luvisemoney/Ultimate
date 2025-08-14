#include "..\\IStrategy.mqh"
#include "..\\KnowledgeBase.mqh"
#include "..\\TradeManager.mqh"
#include "..\\Indicators\\RSI.mqh"

class CRSI2BBReversionStrategy : public IStrategy
  {
private:
   string m_symbol; ENUM_TIMEFRAMES m_tf;
   CRSI   m_rsi;
   int    m_rsiPeriod;
   int    m_bbPeriod; double m_bbDev;
   int    m_hBands;
   int    m_hATR; int m_atrPeriod; double m_atrMult;
   // pending config
   bool   m_usePending; double m_pullbackPoints;

   // cached
   double m_rsi1; double m_bb_up1, m_bb_mid1, m_bb_lo1; double m_close1; double m_atr1;

public:
   CRSI2BBReversionStrategy(const string symbol, const ENUM_TIMEFRAMES tf)
     {
      m_symbol=symbol; m_tf=tf; m_rsiPeriod=2; m_bbPeriod=20; m_bbDev=2.0; m_atrPeriod=14; m_atrMult=2.0;
      m_usePending=false; m_pullbackPoints=10;
      m_rsi.Init(symbol, tf, m_rsiPeriod, PRICE_CLOSE);
      m_hBands = iBands(symbol, tf, m_bbPeriod, 2, 0, PRICE_CLOSE);
      m_hATR   = iATR(symbol, tf, m_atrPeriod);
      m_rsi1=50; m_bb_up1=m_bb_mid1=m_bb_lo1=0; m_close1=0; m_atr1=0;
     }
   virtual string Name(){ return "RSI2BBReversionStrategy"; }
   void ConfigurePending(const bool use_pending, const double pullback_points){ m_usePending=use_pending; m_pullbackPoints=pullback_points; }

   virtual void Refresh()
     {
      m_close1 = iClose(m_symbol, m_tf, 1);
      double b[1];
      if(m_hBands>0){ if(CopyBuffer(m_hBands,0,1,1,b)==1) m_bb_up1=b[0]; if(CopyBuffer(m_hBands,1,1,1,b)==1) m_bb_mid1=b[0]; if(CopyBuffer(m_hBands,2,1,1,b)==1) m_bb_lo1=b[0]; }
      m_rsi1 = m_rsi.Value(1);
      if(m_hATR>0 && CopyBuffer(m_hATR,0,1,1,b)==1) m_atr1=b[0];
     }

   virtual TradeOrder CheckSignal()
     {
      TradeOrder ord; ord.strategy_name=Name();
      if(m_close1<=0 || m_bb_lo1<=0 || m_atr1<=0) return ord;
      // Long reversion: RSI2 oversold below lower band
      if(m_rsi1<=5 && m_close1<=m_bb_lo1)
        {
         ord.action=ACTION_BUY; ord.stop_loss=m_close1 - m_atrMult*m_atr1; ord.take_profit = m_bb_mid1; ord.trailing_enabled=true; ord.trailing_type=TRAIL_ATR; ord.atr_period=m_atrPeriod; ord.atr_multiplier=m_atrMult;
         if(m_usePending){ ord.order_type=ORDER_TYPE_BUY_LIMIT; ord.price = m_bb_lo1 + (m_pullbackPoints*_Point); }
         else { ord.order_type=ORDER_TYPE_BUY; }
         return ord;
        }
      // Short reversion: RSI2 overbought above upper band
      if(m_rsi1>=95 && m_close1>=m_bb_up1)
        {
         ord.action=ACTION_SELL; ord.stop_loss=m_close1 + m_atrMult*m_atr1; ord.take_profit = m_bb_mid1; ord.trailing_enabled=true; ord.trailing_type=TRAIL_ATR; ord.atr_period=m_atrPeriod; ord.atr_multiplier=m_atrMult;
         if(m_usePending){ ord.order_type=ORDER_TYPE_SELL_LIMIT; ord.price = m_bb_up1 - (m_pullbackPoints*_Point); }
         else { ord.order_type=ORDER_TYPE_SELL; }
         return ord;
        }
      return ord;
     }

   virtual void ExportFeatures(CFeaturesKB* kb, const datetime ts)
     {
      if(CheckPointer(kb)==POINTER_INVALID) return;
      (*kb).WriteKV(ts, m_symbol, Name(), "rsi", m_rsi1);
      (*kb).WriteKV(ts, m_symbol, Name(), "bb_upper", m_bb_up1);
      (*kb).WriteKV(ts, m_symbol, Name(), "bb_middle", m_bb_mid1);
      (*kb).WriteKV(ts, m_symbol, Name(), "bb_lower", m_bb_lo1);
      (*kb).WriteKV(ts, m_symbol, Name(), "atr", m_atr1);
     }
  };
