#include "..\IStrategy.mqh"
#include "..\KnowledgeBase.mqh"
#include "..\TradeManager.mqh"

class CADXStrategy : public IStrategy
{
private:
   string           m_symbol;
   ENUM_TIMEFRAMES  m_tf;
   int              m_adxPeriod;
   int              m_adxThreshold;
   int              m_diPeriod;
   
   // Cached values
   double m_adx_current, m_plus_di, m_minus_di;
   double m_close0, m_close1;
   
public:
   CADXStrategy(const string symbol, const ENUM_TIMEFRAMES tf)
   {
      m_symbol = symbol; m_tf = tf;
      m_adxPeriod = 14; m_adxThreshold = 25; m_diPeriod = 14;
      m_adx_current = m_plus_di = m_minus_di = 0;
      m_close0 = m_close1 = 0;
   }
   
   virtual string Name() { return "ADXStrategy"; }
   
   virtual void Refresh()
   {
      m_close0 = iClose(m_symbol, m_tf, 0);
      m_close1 = iClose(m_symbol, m_tf, 1);
      
      double adx_buffer[], plus_di_buffer[], minus_di_buffer[];
      int adx_handle = iADX(m_symbol, m_tf, m_adxPeriod);
      
      if(adx_handle > 0)
      {
         CopyBuffer(adx_handle, 0, 0, 1, adx_buffer);
         CopyBuffer(adx_handle, 1, 0, 1, plus_di_buffer);
         CopyBuffer(adx_handle, 2, 0, 1, minus_di_buffer);
         
         m_adx_current = adx_buffer[0];
         m_plus_di = plus_di_buffer[0];
         m_minus_di = minus_di_buffer[0];
      }
   }
   
   virtual TradeOrder CheckSignal()
   {
      TradeOrder ord; ord.strategy_name = Name();
      
      // Strong trend detection
      if(m_adx_current > m_adxThreshold)
      {
         if(m_plus_di > m_minus_di && m_plus_di > 20)
         {
            // Strong uptrend
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
         else if(m_minus_di > m_plus_di && m_minus_di > 20)
         {
            // Strong downtrend
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
      }
      
      return ord;
   }
   
   virtual void ExportFeatures(CFeaturesKB* kb, const datetime ts)
   {
      if(CheckPointer(kb)==POINTER_INVALID) return;
      (*kb).WriteKV(ts, m_symbol, Name(), "adx", m_adx_current);
      (*kb).WriteKV(ts, m_symbol, Name(), "plus_di", m_plus_di);
      (*kb).WriteKV(ts, m_symbol, Name(), "minus_di", m_minus_di);
   }
};
