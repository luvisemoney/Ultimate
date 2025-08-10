// BollAveragesStrategy.mqh
// Strategy using the 2_Averages_with_BollingerBands indicator.

#property copyright "2025, Windsurf Engineering"
#property link      "https://www.windsurf.ai"

#include "..\IStrategy.mqh"
// For CFeaturesKB
#include "..\KnowledgeBase.mqh"

// --- Buffer indices for the '2_Averages_with_BollingerBands' custom indicator
#define MA1_BUFFER 0
#define MA2_BUFFER 1
#define BB_UPPER_BUFFER 4
#define BB_MIDDLE_BUFFER 5
#define BB_LOWER_BUFFER 6

class CBollAveragesStrategy : public IStrategy
  {
private:
   int               m_indicator_handle;
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;

   // --- Data arrays
   double            m_ma1_buffer[];
   double            m_ma2_buffer[];

public:
                     CBollAveragesStrategy(string symbol, ENUM_TIMEFRAMES timeframe);
                    ~CBollAveragesStrategy();

   // --- IStrategy interface methods
   virtual void      Refresh() override;
   virtual TradeOrder  CheckSignal() override;
   virtual string    Name() override { return "BollAveragesStrategy"; }
   virtual void      ExportFeatures(CFeaturesKB* kb, const datetime ts) override
     {
      if(CheckPointer(kb)==POINTER_INVALID) return;
      if(m_indicator_handle==INVALID_HANDLE) return;
      // Read latest buffers
      double ma1[1], ma2[1], bb_up[1], bb_mid[1], bb_lo[1];
      if(CopyBuffer(m_indicator_handle, MA1_BUFFER, 0, 1, ma1)==1)
         (*kb).WriteKV(ts, m_symbol, Name(), "ma1", ma1[0]);
      if(CopyBuffer(m_indicator_handle, MA2_BUFFER, 0, 1, ma2)==1)
         (*kb).WriteKV(ts, m_symbol, Name(), "ma2", ma2[0]);
      if(CopyBuffer(m_indicator_handle, BB_UPPER_BUFFER, 0, 1, bb_up)==1)
         (*kb).WriteKV(ts, m_symbol, Name(), "bb_upper", bb_up[0]);
      if(CopyBuffer(m_indicator_handle, BB_MIDDLE_BUFFER, 0, 1, bb_mid)==1)
         (*kb).WriteKV(ts, m_symbol, Name(), "bb_middle", bb_mid[0]);
      if(CopyBuffer(m_indicator_handle, BB_LOWER_BUFFER, 0, 1, bb_lo)==1)
         (*kb).WriteKV(ts, m_symbol, Name(), "bb_lower", bb_lo[0]);
     }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CBollAveragesStrategy::CBollAveragesStrategy(string symbol, ENUM_TIMEFRAMES timeframe)
  {
   m_symbol = symbol;
   m_timeframe = timeframe;

   // --- Get indicator handle
   m_indicator_handle = iCustom(m_symbol, m_timeframe, "Downloads\\2_Averages_with_BollingerBands");

   // --- Set buffers as series
   ArraySetAsSeries(m_ma1_buffer, true);
   ArraySetAsSeries(m_ma2_buffer, true);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CBollAveragesStrategy::~CBollAveragesStrategy()
  {
   IndicatorRelease(m_indicator_handle);
  }

//+------------------------------------------------------------------+
//| Refresh - Copies the latest indicator data into local buffers    |
//+------------------------------------------------------------------+
void CBollAveragesStrategy::Refresh()
  {
   if(m_indicator_handle == INVALID_HANDLE)
     {
      Print("CBollAveragesStrategy: Invalid indicator handle.");
      return;
     }

   // Copy the last 3 bars of data for crossover detection
   CopyBuffer(m_indicator_handle, MA1_BUFFER, 0, 3, m_ma1_buffer);
   CopyBuffer(m_indicator_handle, MA2_BUFFER, 0, 3, m_ma2_buffer);
  }

//+------------------------------------------------------------------+
//| CheckSignal - Checks for a moving average crossover              |
//+------------------------------------------------------------------+
TradeOrder CBollAveragesStrategy::CheckSignal()
  {
   TradeOrder order;
   order.strategy_name = Name();

   // Check for bullish crossover (MA1 crosses above MA2)
   // Bar 1 is the most recently closed bar
   if (m_ma1_buffer[1] > m_ma2_buffer[1] && m_ma1_buffer[2] <= m_ma2_buffer[2])
     {
      order.action = ACTION_BUY;
      order.order_type = ORDER_TYPE_BUY;
      double price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      order.stop_loss = price - 150 * _Point; // Example SL
      order.take_profit = price + 300 * _Point; // Example TP
      return order;
     }

   // Check for bearish crossover (MA1 crosses below MA2)
   if (m_ma1_buffer[1] < m_ma2_buffer[1] && m_ma1_buffer[2] >= m_ma2_buffer[2])
     {
      order.action = ACTION_SELL;
      order.order_type = ORDER_TYPE_SELL;
      double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      order.stop_loss = price + 150 * _Point; // Example SL
      order.take_profit = price - 300 * _Point; // Example TP
      return order;
     }

   return order; // Returns order with ACTION_NONE
  }
