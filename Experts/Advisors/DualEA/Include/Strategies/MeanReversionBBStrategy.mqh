// MeanReversionBBStrategy.mqh
// A mean-reversion strategy based on Bollinger Bands with a long-term trend filter.

#property copyright "2025, Windsurf Engineering"
#property link      "https://www.windsurf.ai"

#include "..\IStrategy.mqh"
// For CFeaturesKB
#include "..\KnowledgeBase.mqh"

class CMeanReversionBBStrategy : public IStrategy
  {
private:
   int               m_bb_handle;
   int               m_ma_handle;

   // --- Data arrays
   double            m_bb_upper[], m_bb_lower[];
   double            m_ma_trend[];

public:
                     CMeanReversionBBStrategy(string symbol, ENUM_TIMEFRAMES timeframe);
                    ~CMeanReversionBBStrategy();

   // --- IStrategy interface methods
   virtual void      Refresh() override;
   virtual TradeOrder  CheckSignal() override;
   virtual string    Name() const override { return "MeanReversionBBStrategy"; }
   virtual void      ExportFeatures(CObject* obj, const datetime ts) override
     {
      CFeaturesKB *kb = dynamic_cast<CFeaturesKB*>(obj);
      if(kb==NULL) return;
      // latest price
      MqlRates r[]; if(CopyRates(m_symbol, m_timeframe, 0, 1, r)==1)
         (*kb).WriteKV(ts, m_symbol, Name(), "close", r[0].close);
      // SMA trend value
      double sma[1]; if(CopyBuffer(m_ma_handle, 0, 0, 1, sma)==1)
         (*kb).WriteKV(ts, m_symbol, Name(), "sma_trend", sma[0]);
      // BBands values
      double up[1], lo[1];
      if(CopyBuffer(m_bb_handle, 1, 0, 1, up)==1)
         (*kb).WriteKV(ts, m_symbol, Name(), "bb_upper", up[0]);
      if(CopyBuffer(m_bb_handle, 2, 0, 1, lo)==1)
         (*kb).WriteKV(ts, m_symbol, Name(), "bb_lower", lo[0]);
      if(CopyBuffer(m_bb_handle, 1, 0, 1, up)==1 && CopyBuffer(m_bb_handle, 2, 0, 1, lo)==1)
         (*kb).WriteKV(ts, m_symbol, Name(), "bb_width", up[0]-lo[0]);
     }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMeanReversionBBStrategy::CMeanReversionBBStrategy(string symbol, ENUM_TIMEFRAMES timeframe) : IStrategy("MeanReversionBBStrategy", symbol, timeframe)
  {
   // --- Get indicator handles
   m_bb_handle = iBands(m_symbol, m_timeframe, 20, 0, 2.0, PRICE_CLOSE);
   m_ma_handle = iMA(m_symbol, PERIOD_D1, 100, 0, MODE_SMA, PRICE_CLOSE);

   // --- Set buffers as series
   ArraySetAsSeries(m_bb_upper, true);
   ArraySetAsSeries(m_bb_lower, true);
   ArraySetAsSeries(m_ma_trend, true);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMeanReversionBBStrategy::~CMeanReversionBBStrategy()
  {
   IndicatorRelease(m_bb_handle);
   IndicatorRelease(m_ma_handle);
  }

//+------------------------------------------------------------------+
//| Refresh                                                          |
//+------------------------------------------------------------------+
void CMeanReversionBBStrategy::Refresh()
  {
   // Copy the last 2 bars of data
   CopyBuffer(m_bb_handle, 1, 0, 2, m_bb_upper); // Upper Band
   CopyBuffer(m_bb_handle, 2, 0, 2, m_bb_lower); // Lower Band
   CopyBuffer(m_ma_handle, 0, 0, 1, m_ma_trend); // MA Trend
  }

//+------------------------------------------------------------------+
//| Checks for a trading signal.                                     |
//+------------------------------------------------------------------+
TradeOrder CMeanReversionBBStrategy::CheckSignal()
  {
   TradeOrder order;
   order.strategy_name = Name();

   // --- Get latest price data
   MqlRates rates[];
   if(CopyRates(m_symbol, m_timeframe, 0, 1, rates) != 1) return order;
   double close_price = rates[0].close;

   // --- Get latest indicator values
   double sma_val[1];
   double upper_band[1];
   double lower_band[1];

   if(CopyBuffer(m_ma_handle, 0, 0, 1, sma_val) != 1 ||
      CopyBuffer(m_bb_handle, 1, 0, 1, upper_band) != 1 ||
      CopyBuffer(m_bb_handle, 2, 0, 1, lower_band) != 1)
     {
      return order;
     }

   // --- Entry Logic
   if(close_price > sma_val[0]) // Long-term trend is up
     {
      if(close_price < lower_band[0])
        {
         order.action = ACTION_BUY;
         order.order_type = ORDER_TYPE_BUY;
         order.stop_loss = close_price - 100 * _Point; // Example SL
         order.take_profit = close_price + 200 * _Point; // Example TP
         return order;
        }
     }
   else if(close_price < sma_val[0]) // Long-term trend is down
     {
      if(close_price > upper_band[0])
        {
         order.action = ACTION_SELL;
         order.order_type = ORDER_TYPE_SELL;
         order.stop_loss = close_price + 100 * _Point; // Example SL
         order.take_profit = close_price - 200 * _Point; // Example TP
         return order;
        }
     }

   return order;
  }
