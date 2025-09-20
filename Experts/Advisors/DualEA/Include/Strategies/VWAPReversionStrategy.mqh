#ifndef DUALEA_STRATEGIES_VWAP_REVERSION_MQH
#define DUALEA_STRATEGIES_VWAP_REVERSION_MQH

#include "..\\IStrategy.mqh"
#include "..\\KnowledgeBase.mqh"
#include "..\\TradeManager.mqh"
#include "..\\Indicators\\VWAP.mqh"

class CVWAPReversionStrategy : public IStrategy
  {
private:
   string           m_symbol;
   ENUM_TIMEFRAMES  m_tf;

   CVWAP            m_vwap;
   int              m_vwapWindow;

   int              m_adxPeriod;
   int              m_hADX;
   int              m_atrPeriod;
   double           m_atrMult;
   double           m_devAtrMult; // deviation threshold in ATR multiples
   int              m_hATR;

   // cached
   double           m_close1;
   double           m_vwap1;
   double           m_dev1;
   double           m_atr1;
   double           m_adx1;

public:
   CVWAPReversionStrategy(const string symbol, const ENUM_TIMEFRAMES tf)
     {
      m_symbol=symbol; m_tf=tf;
      m_vwapWindow=30; m_vwap.Init(symbol, tf, m_vwapWindow);
      m_adxPeriod=14; m_hADX=iADX(symbol, tf, m_adxPeriod);
      m_atrPeriod=14; m_atrMult=1.5; m_devAtrMult=1.0; m_hATR=iATR(symbol, tf, m_atrPeriod);
      m_close1=0.0; m_vwap1=0.0; m_dev1=0.0; m_atr1=0.0; m_adx1=0.0;
     }

   virtual string Name(){ return "VWAPReversionStrategy"; }

   virtual void Refresh()
     {
      m_close1 = iClose(m_symbol, m_tf, 1);
      m_vwap1  = m_vwap.Value(1);
      m_dev1   = (m_close1>0 && m_vwap1>0? (m_close1 - m_vwap1) : 0.0);
      // ATR(1)
      m_atr1 = 0.0; if(m_hATR>0){ double b[1]; if(CopyBuffer(m_hATR,0,1,1,b)==1) m_atr1=b[0]; }
      // ADX(1)
      m_adx1 = 0.0; if(m_hADX>0){ double b[1]; if(CopyBuffer(m_hADX,0,1,1,b)==1) m_adx1=b[0]; }
     }

   virtual TradeOrder CheckSignal()
     {
      TradeOrder ord; ord.strategy_name=Name();
      if(m_close1<=0 || m_vwap1<=0 || m_atr1<=0) return ord;
      // Favor reversion when trend is not strong
      bool allow_revert = (m_adx1 <= 22.0 || m_adx1==0.0);
      if(!allow_revert) return ord;

      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);

      // Long: price sufficiently below vwap
      if(m_dev1 <= -m_devAtrMult*m_atr1)
        {
         ord.action = ACTION_BUY; ord.order_type = ORDER_TYPE_BUY;
         double sl = m_close1 - m_atrMult*m_atr1;
         double tp = (m_vwap1>m_close1? m_vwap1 : m_close1 + 1.0*m_atr1);
         ord.stop_loss = NormalizeDouble(sl, digits);
         ord.take_profit = NormalizeDouble(tp, digits);
         ord.trailing_enabled=true; ord.trailing_type=TRAIL_ATR; ord.atr_period=m_atrPeriod; ord.atr_multiplier=m_atrMult;
         return ord;
        }
      // Short: price sufficiently above vwap
      if(m_dev1 >= m_devAtrMult*m_atr1)
        {
         ord.action = ACTION_SELL; ord.order_type = ORDER_TYPE_SELL;
         double sl = m_close1 + m_atrMult*m_atr1;
         double tp = (m_vwap1<m_close1? m_vwap1 : m_close1 - 1.0*m_atr1);
         ord.stop_loss = NormalizeDouble(sl, digits);
         ord.take_profit = NormalizeDouble(tp, digits);
         ord.trailing_enabled=true; ord.trailing_type=TRAIL_ATR; ord.atr_period=m_atrPeriod; ord.atr_multiplier=m_atrMult;
         return ord;
        }

      return ord;
     }

   virtual void ExportFeatures(CFeaturesKB* kb, const datetime ts)
     {
      if(CheckPointer(kb)==POINTER_INVALID) return;
      (*kb).WriteKV(ts, m_symbol, Name(), "vwap", m_vwap1);
      (*kb).WriteKV(ts, m_symbol, Name(), "dev_from_vwap", m_dev1);
      (*kb).WriteKV(ts, m_symbol, Name(), "adx", m_adx1);
      (*kb).WriteKV(ts, m_symbol, Name(), "atr", m_atr1);
     }
  };

#endif // DUALEA_STRATEGIES_VWAP_REVERSION_MQH
