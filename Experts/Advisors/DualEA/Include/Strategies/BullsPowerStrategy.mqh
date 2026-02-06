#include "..\IStrategy.mqh"
#include "..\KnowledgeBase.mqh"
#include "..\TradeManager.mqh"

class CBullsPowerStrategy : public IStrategy
{
private:
   // Bulls Power parameters
   int m_emaPeriod, m_bullsPeriod;
   
   // Cached values
   double m_bulls_power, m_ema;
   double m_close0, m_close1;
   
public:
   CBullsPowerStrategy(const string symbol, const ENUM_TIMEFRAMES tf) : IStrategy("BullsPowerStrategy", symbol, tf)
   {
      m_emaPeriod = 13; m_bullsPeriod = 13;
      ResetValues();
   }
   
   virtual string Name() { return "BullsPowerStrategy"; }
   
   void ResetValues()
   {
      m_bulls_power = m_ema = 0;
      m_close0 = m_close1 = 0;
   }
   
   virtual void Refresh()
   {
      ResetValues();
      m_close0 = iClose(m_symbol, m_timeframe, 0);
      m_close1 = iClose(m_symbol, m_timeframe, 1);
      
      // Calculate Bulls Power
      double high = iHigh(m_symbol, m_timeframe, 0);
      double ema_buffer[];
      int ema_handle = iMA(m_symbol, m_timeframe, m_emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      
      if(ema_handle > 0)
      {
         CopyBuffer(ema_handle, 0, 0, 1, ema_buffer);
         m_ema = ema_buffer[0];
         m_bulls_power = high - m_ema;
      }
   }
   
   virtual TradeOrder CheckSignal()
   {
      TradeOrder ord; ord.strategy_name = Name();
      
      // Bulls Power reversal strategy
      bool bearish_reversal = (m_bulls_power > 0 && m_bulls_power < 0.0010 && 
                              m_close0 < m_ema);
      bool bullish_continuation = (m_bulls_power > 0.0010 && m_close0 > m_ema);
      
      // Zero line cross
      bool zero_cross_down = (m_bulls_power < 0);
      
      // Bullish continuation
      if(bullish_continuation)
      {
         ord.action = ACTION_BUY;
         ord.order_type = ORDER_TYPE_BUY;
         ord.stop_loss = m_close0 - 20 * _Point;
         ord.take_profit = m_close0 + 60 * _Point;
         return ord;
      }
      
      // Bearish reversal
      else if(bearish_reversal || zero_cross_down)
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
      (*kb).WriteKV(ts, m_symbol, Name(), "bulls_power", m_bulls_power);
      (*kb).WriteKV(ts, m_symbol, Name(), "ema", m_ema);
      (*kb).WriteKV(ts, m_symbol, Name(), "bulls_ema_distance", m_bulls_power);
   }
};
