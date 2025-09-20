#include "..\IStrategy.mqh"
#include "..\KnowledgeBase.mqh"
#include "..\TradeManager.mqh"

class CAwesomeOscillatorStrategy : public IStrategy
{
private:
   string           m_symbol;
   ENUM_TIMEFRAMES  m_tf;
   
   // AO parameters
   int m_fastPeriod, m_slowPeriod;
   
   // Cached values
   double m_ao_current, m_ao_prev1, m_ao_prev2;
   double m_close0, m_close1;
   
public:
   CAwesomeOscillatorStrategy(const string symbol, const ENUM_TIMEFRAMES tf)
   {
      m_symbol = symbol; m_tf = tf;
      m_fastPeriod = 5; m_slowPeriod = 34;
      ResetValues();
   }
   
   virtual string Name() { return "AwesomeOscillatorStrategy"; }
   
   void ResetValues()
   {
      m_ao_current = m_ao_prev1 = m_ao_prev2 = 0;
      m_close0 = m_close1 = 0;
   }
   
   virtual void Refresh()
   {
      ResetValues();
      m_close0 = iClose(m_symbol, m_tf, 0);
      m_close1 = iClose(m_symbol, m_tf, 1);
      
      // Calculate Awesome Oscillator
      double ao_buffer[];
      int ao_handle = iAO(m_symbol, m_tf);
      if(ao_handle > 0 && CopyBuffer(ao_handle, 0, 0, 3, ao_buffer) == 3)
      {
         m_ao_current = ao_buffer[0];
         m_ao_prev1 = ao_buffer[1];
         m_ao_prev2 = ao_buffer[2];
      }
   }
   
   virtual TradeOrder CheckSignal()
   {
      TradeOrder ord; ord.strategy_name = Name();
      
      // Saucer strategy - three consecutive bars
      bool saucer_bullish = (m_ao_prev2 < m_ao_prev1 && m_ao_prev1 < m_ao_current && 
                            m_ao_prev1 > 0 && m_ao_current > 0);
      bool saucer_bearish = (m_ao_prev2 > m_ao_prev1 && m_ao_prev1 > m_ao_current && 
                            m_ao_prev1 < 0 && m_ao_current < 0);
      
      // Zero line cross
      bool zero_cross_up = (m_ao_prev1 < 0 && m_ao_current > 0);
      bool zero_cross_down = (m_ao_prev1 > 0 && m_ao_current < 0);
      
      // Twin peaks strategy
      bool twin_peaks_bullish = false;
      bool twin_peaks_bearish = false;
      
      // Bullish saucer or zero cross
      if(saucer_bullish || zero_cross_up)
      {
         ord.action = ACTION_BUY;
         ord.order_type = ORDER_TYPE_BUY;
         ord.stop_loss = m_close0 - 30 * _Point;
         ord.take_profit = m_close0 + 90 * _Point;
         return ord;
      }
      
      // Bearish saucer or zero cross
      else if(saucer_bearish || zero_cross_down)
      {
         ord.action = ACTION_SELL;
         ord.order_type = ORDER_TYPE_SELL;
         ord.stop_loss = m_close0 + 30 * _Point;
         ord.take_profit = m_close0 - 90 * _Point;
         return ord;
      }
      
      return ord;
   }
   
   virtual void ExportFeatures(CFeaturesKB* kb, const datetime ts)
   {
      if(CheckPointer(kb)==POINTER_INVALID) return;
      (*kb).WriteKV(ts, m_symbol, Name(), "ao_current", m_ao_current);
      (*kb).WriteKV(ts, m_symbol, Name(), "ao_prev1", m_ao_prev1);
      (*kb).WriteKV(ts, m_symbol, Name(), "ao_prev2", m_ao_prev2);
      (*kb).WriteKV(ts, m_symbol, Name(), "ao_momentum", m_ao_current - m_ao_prev1);
   }
};
