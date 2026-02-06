#include "..\IStrategy.mqh"
#include "..\KnowledgeBase.mqh"
#include "..\TradeManager.mqh"

class CAcceleratorOscillatorStrategy : public IStrategy
{
private:
   int              m_aoFast;
   int              m_aoSlow;
   int              m_aoSignal;
   double           m_threshold;
   
   // Cached values
   double m_ao_current, m_ao_prev;
   double m_close0, m_close1;
   
public:
   CAcceleratorOscillatorStrategy(const string symbol, const ENUM_TIMEFRAMES tf) : IStrategy("AcceleratorOscillatorStrategy", symbol, tf)
   {
      m_aoFast = 5; m_aoSlow = 34; m_aoSignal = 5;
      m_threshold = 0.0001;
      m_ao_current = m_ao_prev = 0;
      m_close0 = m_close1 = 0;
   }
   
   virtual string Name() { return "AcceleratorOscillatorStrategy"; }
   
   virtual void Refresh()
   {
      m_close0 = iClose(m_symbol, m_timeframe, 0);
      m_close1 = iClose(m_symbol, m_timeframe, 1);
      
      // Calculate Accelerator Oscillator
      double ao_buffer[];
      int ao_handle = iAO(m_symbol, m_timeframe);
      if(ao_handle > 0 && CopyBuffer(ao_handle, 0, 0, 2, ao_buffer) == 2)
      {
         m_ao_current = ao_buffer[0];
         m_ao_prev = ao_buffer[1];
      }
   }
   
   virtual TradeOrder CheckSignal()
   {
      TradeOrder ord; ord.strategy_name = Name();
      
      // Zero line cross strategy
      if(m_ao_prev < 0 && m_ao_current > 0)
      {
         // Bullish crossover
         ord.action = ACTION_BUY;
         ord.order_type = ORDER_TYPE_BUY;
         double atr = GetATR(14, 0);
         double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double min_stop = MathMax(atr * 1.5, MathMax(spread*3, SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point));
         ord.stop_loss = m_close0 - min_stop;
         ord.take_profit = m_close0 + min_stop * 3.0;
         if(spread > min_stop*0.5) return ord;
         return ord;
      }
      else if(m_ao_prev > 0 && m_ao_current < 0)
      {
         // Bearish crossover
         ord.action = ACTION_SELL;
         ord.order_type = ORDER_TYPE_SELL;
         double atr = GetATR(14, 0);
         double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double min_stop = MathMax(atr * 1.5, MathMax(spread*3, SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point));
         ord.stop_loss = m_close0 + min_stop;
         ord.take_profit = m_close0 - min_stop * 3.0;
         if(spread > min_stop*0.5) return ord;
         return ord;
      }
      
      return ord;
   }
   
   virtual void ExportFeatures(CFeaturesKB* kb, const datetime ts)
   {
      if(CheckPointer(kb)==POINTER_INVALID) return;
      (*kb).WriteKV(ts, m_symbol, Name(), "ao_current", m_ao_current);
      (*kb).WriteKV(ts, m_symbol, Name(), "ao_prev", m_ao_prev);
   }
};
