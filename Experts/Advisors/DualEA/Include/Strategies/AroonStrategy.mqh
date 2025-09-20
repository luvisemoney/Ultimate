#include "..\IStrategy.mqh"
#include "..\KnowledgeBase.mqh"
#include "..\TradeManager.mqh"

class CAroonStrategy : public IStrategy
{
private:
   string           m_symbol;
   ENUM_TIMEFRAMES  m_tf;
   int              m_period;
   int              m_upThreshold;
   int              m_downThreshold;
   
   // Cached values
   double m_aroon_up, m_aroon_down;
   double m_close0, m_close1;
   
public:
   CAroonStrategy(const string symbol, const ENUM_TIMEFRAMES tf)
   {
      m_symbol = symbol; m_tf = tf;
      m_period = 14; m_upThreshold = 70; m_downThreshold = 30;
      m_aroon_up = m_aroon_down = 0;
      m_close0 = m_close1 = 0;
   }
   
   virtual string Name() { return "AroonStrategy"; }
   
   virtual void Refresh()
   {
      m_close0 = iClose(m_symbol, m_tf, 0);
      m_close1 = iClose(m_symbol, m_tf, 1);
      
      // Manual Aroon computation: Up = (period - barsSinceHigh)/period * 100
      //                          Down = (period - barsSinceLow)/period * 100
      int bars_since_high = iHighest(m_symbol, m_tf, MODE_HIGH, m_period, 0);
      int bars_since_low  = iLowest(m_symbol, m_tf, MODE_LOW,  m_period, 0);
      if(bars_since_high>=0 && bars_since_low>=0)
      {
         m_aroon_up   = 100.0 * (m_period - bars_since_high) / m_period;
         m_aroon_down = 100.0 * (m_period - bars_since_low)  / m_period;
      }
   }
   
   virtual TradeOrder CheckSignal()
   {
      TradeOrder ord; ord.strategy_name = Name();
      
      // Aroon crossover strategy
      if(m_aroon_up > m_upThreshold && m_aroon_down < m_downThreshold)
      {
         // Strong uptrend
         ord.action = ACTION_BUY;
         ord.order_type = ORDER_TYPE_BUY;
         double atr = GetATR(14, 0);
         double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double min_stop = MathMax(atr * 1.5, MathMax(spread*3, SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point));
         ord.stop_loss = m_close0 - min_stop;
         ord.take_profit = m_close0 + min_stop * 3.0;
         if(spread > min_stop*0.5) return ord; // skip if spread is too high
         return ord;
      }
      else if(m_aroon_down > m_upThreshold && m_aroon_up < m_downThreshold)
      {
         // Strong downtrend
         ord.action = ACTION_SELL;
         ord.order_type = ORDER_TYPE_SELL;
         double atr = GetATR(14, 0);
         double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double min_stop = MathMax(atr * 1.5, MathMax(spread*3, SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point));
         ord.stop_loss = m_close0 + min_stop;
         ord.take_profit = m_close0 - min_stop * 3.0;
         if(spread > min_stop*0.5) return ord; // skip if spread is too high
         return ord;
      }
      
      return ord;
   }
   
   virtual void ExportFeatures(CFeaturesKB* kb, const datetime ts)
   {
      if(CheckPointer(kb)==POINTER_INVALID) return;
      (*kb).WriteKV(ts, m_symbol, Name(), "aroon_up", m_aroon_up);
      (*kb).WriteKV(ts, m_symbol, Name(), "aroon_down", m_aroon_down);
   }
};
