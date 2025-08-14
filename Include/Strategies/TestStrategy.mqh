// TestStrategy.mqh
// A simple strategy for testing the EA framework. Generates frequent signals.

#property copyright "2025, Windsurf Engineering"
#property link      "https://www.windsurf.ai"

#include "..\IStrategy.mqh"

class CTestStrategy : public IStrategy
  {
private:
   string            m_symbol;
   double            m_last_tick;

public:
                     CTestStrategy(string symbol);
                    ~CTestStrategy() {};

   // --- IStrategy interface methods
   virtual void      Refresh();
   virtual SignalType  CheckSignal();
   virtual string    Name() { return "TestStrategy"; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTestStrategy::CTestStrategy(string symbol)
  {
   m_symbol = symbol;
   m_last_tick = 0;
  }

//+------------------------------------------------------------------+
//| Refresh                                                          |
//+------------------------------------------------------------------+
void CTestStrategy::Refresh()
  {
   // Nothing to refresh for this simple strategy
  }

//+------------------------------------------------------------------+
//| CheckSignal                                                      |
//+------------------------------------------------------------------+
SignalType CTestStrategy::CheckSignal()
  {
   double current_bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);

   if(m_last_tick == 0)
     {
      m_last_tick = current_bid;
      return SIGNAL_NONE;
     }

   SignalType signal = SIGNAL_NONE;
   if(current_bid > m_last_tick)
     {
      signal = SIGNAL_BUY;
     }
   else if(current_bid < m_last_tick)
     {
      signal = SIGNAL_SELL;
     }

   m_last_tick = current_bid;
   return signal;
  }
