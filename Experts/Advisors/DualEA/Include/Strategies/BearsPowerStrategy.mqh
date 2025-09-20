#include "..\IStrategy.mqh"
#include "..\KnowledgeBase.mqh"
#include "..\TradeManager.mqh"

class CBearsPowerStrategy : public IStrategy
{
private:
   string           m_symbol;
   ENUM_TIMEFRAMES  m_tf;
   
   // Bears Power parameters
   int m_emaPeriod, m_bearsPeriod;
   
   // Cached values
   double m_bears_power, m_ema;
   double m_close0, m_close1;
   
public:
   CBearsPowerStrategy(const string symbol, const ENUM_TIMEFRAMES tf)
   {
      m_symbol = symbol; m_tf = tf;
      m_emaPeriod = 13; m_bearsPeriod = 13;
      ResetValues();
   }
   
   virtual string Name() { return "BearsPowerStrategy"; }
   
   void ResetValues()
   {
      m_bears_power = m_ema = 0;
      m_close0 = m_close1 = 0;
   }
   
   virtual void Refresh()
   {
      ResetValues();
      m_close0 = iClose(m_symbol, m_tf, 0);
      m_close1 = iClose(m_symbol, m_tf, 1);
      
      // Calculate Bears Power
      double low = iLow(m_symbol, m_tf, 0);
      double ema_buffer[];
      int ema_handle = iMA(m_symbol, m_tf, m_emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      
      if(ema_handle > 0)
      {
         CopyBuffer(ema_handle, 0, 0, 1, ema_buffer);
         m_ema = ema_buffer[0];
         m_bears_power = low - m_ema;
      }
   }
   
   virtual TradeOrder CheckSignal()
   {
      TradeOrder ord; ord.strategy_name = Name();
      
      // Bears Power reversal strategy
      bool bullish_reversal = (m_bears_power < 0 && m_bears_power > -0.0010 && 
                              m_close0 > m_ema);
      bool bearish_continuation = (m_bears_power < -0.0010 && m_close0 < m_ema);
      
      // Zero line cross
      bool zero_cross_up = (m_bears_power > 0);
      
      // Bullish reversal
      if(bullish_reversal || zero_cross_up)
      {
         ord.action = ACTION_BUY;
         ord.order_type = ORDER_TYPE_BUY;
         ord.stop_loss = m_close0 - 20 * _Point;
         ord.take_profit = m_close0 + 60 * _Point;
         return ord;
      }
      
      // Bearish continuation
      else if(bearish_continuation)
      {
         ord.action = ACTION_SELL;
         ord.order_type = ORDER_TYPE_SELL;
         ord.stop_loss = m_close0 + 20 * _Point;
         ord.take_profit = m_close0 - 60 * _Point;
         return ord;
      }
      
      return ord;
   }
   
   virtual void ExportFeatures(CFeaturesKB* kb, const datetime ts)
   {
      if(CheckPointer(kb)==POINTER_INVALID) return;
      (*kb).WriteKV(ts, m_symbol, Name(), "bears_power", m_bears_power);
      (*kb).WriteKV(ts, m_symbol, Name(), "ema", m_ema);
      (*kb).WriteKV(ts, m_symbol, Name(), "bears_ema_distance", m_bears_power);
   }
};
