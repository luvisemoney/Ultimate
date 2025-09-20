#include "..\IStrategy.mqh"
#include "..\KnowledgeBase.mqh"
#include "..\TradeManager.mqh"

class CAlligatorStrategy : public IStrategy
{
private:
   string           m_symbol;
   ENUM_TIMEFRAMES  m_tf;
   int              m_jawPeriod;
   int              m_teethPeriod;
   int              m_lipsPeriod;
   int              m_jawShift;
   int              m_teethShift;
   int              m_lipsShift;
   
   // Cached values
   double m_jaw, m_teeth, m_lips;
   double m_close0, m_close1;
   
public:
   CAlligatorStrategy(const string symbol, const ENUM_TIMEFRAMES tf)
   {
      m_symbol = symbol; m_tf = tf;
      m_jawPeriod = 13; m_teethPeriod = 8; m_lipsPeriod = 5;
      m_jawShift = 8; m_teethShift = 5; m_lipsShift = 3;
      m_jaw = m_teeth = m_lips = 0;
      m_close0 = m_close1 = 0;
   }
   
   virtual string Name() { return "AlligatorStrategy"; }
   
   virtual void Refresh()
   {
      m_close0 = iClose(m_symbol, m_tf, 0);
      m_close1 = iClose(m_symbol, m_tf, 1);
      
      double jaw_buffer[], teeth_buffer[], lips_buffer[];
      
      // Alligator Jaw (Blue)
      int jaw_handle = iAlligator(m_symbol, m_tf, m_jawPeriod, m_jawShift, m_teethPeriod, m_teethShift, m_lipsPeriod, m_lipsShift, MODE_SMMA, PRICE_MEDIAN);
      
      if(jaw_handle > 0)
      {
         CopyBuffer(jaw_handle, 0, 0, 1, jaw_buffer);
         CopyBuffer(jaw_handle, 1, 0, 1, teeth_buffer);
         CopyBuffer(jaw_handle, 2, 0, 1, lips_buffer);
         
         m_jaw = jaw_buffer[0];
         m_teeth = teeth_buffer[0];
         m_lips = lips_buffer[0];
      }
   }
   
   virtual TradeOrder CheckSignal()
   {
      TradeOrder ord; ord.strategy_name = Name();
      
      // Alligator awakening (lines converge then diverge)
      bool awakening_up = (m_lips > m_teeth && m_teeth > m_jaw);
      bool awakening_down = (m_lips < m_teeth && m_teeth < m_jaw);
      
      if(awakening_up && m_close0 > m_lips)
      {
         // Bullish awakening
         ord.action = ACTION_BUY;
         ord.order_type = ORDER_TYPE_BUY;
         double atr = GetATR(14, 0);
         double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double min_stop = MathMax(atr * 1.5, MathMax(spread*3, SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point));
         ord.stop_loss = m_jaw - min_stop;
         ord.take_profit = m_close0 + min_stop * 3.0;
         if(spread > min_stop*0.5) return ord;
         return ord;
      }
      else if(awakening_down && m_close0 < m_lips)
      {
         // Bearish awakening
         ord.action = ACTION_SELL;
         ord.order_type = ORDER_TYPE_SELL;
         double atr = GetATR(14, 0);
         double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double min_stop = MathMax(atr * 1.5, MathMax(spread*3, SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point));
         ord.stop_loss = m_jaw + min_stop;
         ord.take_profit = m_close0 - min_stop * 3.0;
         if(spread > min_stop*0.5) return ord;
         return ord;
      }
      
      return ord;
   }
   
   virtual void ExportFeatures(CFeaturesKB* kb, const datetime ts)
   {
      if(CheckPointer(kb)==POINTER_INVALID) return;
      (*kb).WriteKV(ts, m_symbol, Name(), "jaw", m_jaw);
      (*kb).WriteKV(ts, m_symbol, Name(), "teeth", m_teeth);
      (*kb).WriteKV(ts, m_symbol, Name(), "lips", m_lips);
   }
};
