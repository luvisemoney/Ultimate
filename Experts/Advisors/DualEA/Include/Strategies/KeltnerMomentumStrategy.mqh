#ifndef DUALEA_STRATEGIES_KELTNER_MOMENTUM_MQH
#define DUALEA_STRATEGIES_KELTNER_MOMENTUM_MQH

#include "..\\IStrategy.mqh"
#include "..\\KnowledgeBase.mqh"
#include "..\\TradeManager.mqh"
#include "..\\Indicators\\Keltner.mqh"

class CKeltnerMomentumStrategy : public IStrategy
  {
private:
   CKeltner         m_kc;
   int              m_emaPeriod;
   int              m_atrPeriod;
   double           m_atrMult;

   int              m_adxPeriod;
   int              m_hADX;

   int              m_hATR;

   // cached
   double           m_close1;
   double           m_upper1, m_lower1, m_mid1, m_midSlope1;
   double           m_adx1, m_atr1;

public:
   CKeltnerMomentumStrategy(const string symbol, const ENUM_TIMEFRAMES tf) : IStrategy("KeltnerMomentumStrategy", symbol, tf)
     {
      m_emaPeriod=20; m_atrPeriod=10; m_atrMult=1.5;
      m_kc.Init(symbol, tf, m_emaPeriod, m_atrPeriod, m_atrMult);
      m_adxPeriod=14; m_hADX=iADX(symbol, tf, m_adxPeriod);
      m_hATR=iATR(symbol, tf, MathMax(14, m_atrPeriod));
      m_close1=0.0; m_upper1=m_lower1=m_mid1=m_midSlope1=0.0; m_adx1=0.0; m_atr1=0.0;
     }

   virtual string Name(){ return "KeltnerMomentumStrategy"; }

   virtual void Refresh()
     {
      m_close1 = iClose(m_symbol, m_timeframe, 1);
      m_upper1 = m_kc.Upper(1);
      m_lower1 = m_kc.Lower(1);
      m_mid1   = m_kc.Middle(1);
      m_midSlope1 = m_kc.MiddleSlope(1);
      // ADX & ATR
      double b[1];
      m_adx1=0.0; if(m_hADX>0 && CopyBuffer(m_hADX,0,1,1,b)==1) m_adx1=b[0];
      m_atr1=0.0; if(m_hATR>0 && CopyBuffer(m_hATR,0,1,1,b)==1) m_atr1=b[0];
     }

   virtual TradeOrder CheckSignal()
     {
      TradeOrder ord; ord.strategy_name=Name();
      if(m_close1<=0 || m_upper1<=0 || m_lower1<=0 || m_atr1<=0) return ord;
      bool strong_trend = (m_adx1 >= 20.0 || m_adx1==0.0);
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);

      // Long: close above upper band with positive mid slope and strong trend
      if(strong_trend && m_midSlope1>0 && m_close1 >= m_upper1)
        {
         ord.action = ACTION_BUY; ord.order_type = ORDER_TYPE_BUY;
         double sl = m_close1 - 1.5*m_atr1;
         double tp = m_close1 + 3.0*m_atr1;
         ord.stop_loss   = NormalizeDouble(sl, digits);
         ord.take_profit = NormalizeDouble(tp, digits);
         ord.trailing_enabled=true; ord.trailing_type=TRAIL_ATR; ord.atr_period=MathMax(14, m_atrPeriod); ord.atr_multiplier=2.0;
         return ord;
        }

      // Short: close below lower band with negative mid slope and strong trend
      if(strong_trend && m_midSlope1<0 && m_close1 <= m_lower1)
        {
         ord.action = ACTION_SELL; ord.order_type = ORDER_TYPE_SELL;
         double sl = m_close1 + 1.5*m_atr1;
         double tp = m_close1 - 3.0*m_atr1;
         ord.stop_loss   = NormalizeDouble(sl, digits);
         ord.take_profit = NormalizeDouble(tp, digits);
         ord.trailing_enabled=true; ord.trailing_type=TRAIL_ATR; ord.atr_period=MathMax(14, m_atrPeriod); ord.atr_multiplier=2.0;
         return ord;
        }

      return ord;
     }

   virtual void ExportFeatures(CFeaturesKB* kb, const datetime ts)
     {
      if(CheckPointer(kb)==POINTER_INVALID) return;
      (*kb).WriteKV(ts, m_symbol, Name(), "kc_upper", m_upper1);
      (*kb).WriteKV(ts, m_symbol, Name(), "kc_lower", m_lower1);
      (*kb).WriteKV(ts, m_symbol, Name(), "kc_mid",   m_mid1);
      (*kb).WriteKV(ts, m_symbol, Name(), "kc_mid_slope", m_midSlope1);
      (*kb).WriteKV(ts, m_symbol, Name(), "adx", m_adx1);
      (*kb).WriteKV(ts, m_symbol, Name(), "atr", m_atr1);
     }
  };

#endif // DUALEA_STRATEGIES_KELTNER_MOMENTUM_MQH
