//+------------------------------------------------------------------+
//| CFeatures.mqh                                                    |
//| Feature extraction class for gate system                         |
//| Provides technical indicators and market features                |
//+------------------------------------------------------------------+
#ifndef CFEATURES_MQH
#define CFEATURES_MQH

#include <Math\Stat\Math.mqh>

//+------------------------------------------------------------------+
//| Feature Container Structure                                      |
//+------------------------------------------------------------------+
struct SFeatureSet
{
   // Price features
   double   open_price;
   double   high_price;
   double   low_price;
   double   close_price;
   
   // Returns
   double   return_1d;
   double   return_5d;
   double   return_10d;
   double   return_20d;
   
   // Volatility features
   double   volatility_daily;
   double   volatility_weekly;
   double   atr_ratio;
   
   // Trend features
   double   ma_20_slope;
   double   ma_50_slope;
   double   price_vs_ma20;
   double   price_vs_ma50;
   
   // Momentum features
   double   rsi_14;
   double   macd_signal;
   double   stochastic;
   
   // Volume features (if available)
   double   volume_ratio;
   double   volume_ma_ratio;
   
   void Reset()
   {
      open_price = 0.0;
      high_price = 0.0;
      low_price = 0.0;
      close_price = 0.0;
      return_1d = 0.0;
      return_5d = 0.0;
      return_10d = 0.0;
      return_20d = 0.0;
      volatility_daily = 0.0;
      volatility_weekly = 0.0;
      atr_ratio = 0.0;
      ma_20_slope = 0.0;
      ma_50_slope = 0.0;
      price_vs_ma20 = 0.0;
      price_vs_ma50 = 0.0;
      rsi_14 = 50.0;
      macd_signal = 0.0;
      stochastic = 50.0;
      volume_ratio = 1.0;
      volume_ma_ratio = 1.0;
   }
};

//+------------------------------------------------------------------+
//| Feature Extraction Class                                         |
//+------------------------------------------------------------------+
class CFeatures
{
private:
   string   m_symbol;
   int      m_timeframe;
   int      m_bars_needed;
   bool     m_initialized;
   
   // Cached data
   double   m_close[];
   double   m_high[];
   double   m_low[];
   double   m_open[];
   double   m_volume[];
   datetime m_time[];
   
   // Indicator handles
   int      m_handle_atr;
   int      m_handle_rsi;
   int      m_handle_macd;
   int      m_handle_stoch;
   int      m_handle_ma20;
   int      m_handle_ma50;
   
public:
   // Constructor
   CFeatures(const string symbol = NULL, int timeframe = PERIOD_CURRENT)
   {
      m_symbol = (symbol == NULL || symbol == "") ? _Symbol : symbol;
      m_timeframe = (timeframe == PERIOD_CURRENT) ? _Period : timeframe;
      m_bars_needed = 100;
      m_initialized = false;
      
      ArraySetAsSeries(m_close, true);
      ArraySetAsSeries(m_high, true);
      ArraySetAsSeries(m_low, true);
      ArraySetAsSeries(m_open, true);
      ArraySetAsSeries(m_volume, true);
      ArraySetAsSeries(m_time, true);
      
      m_handle_atr = INVALID_HANDLE;
      m_handle_rsi = INVALID_HANDLE;
      m_handle_macd = INVALID_HANDLE;
      m_handle_stoch = INVALID_HANDLE;
      m_handle_ma20 = INVALID_HANDLE;
      m_handle_ma50 = INVALID_HANDLE;
   }
   
   // Destructor
   ~CFeatures()
   {
      ReleaseHandles();
   }
   
   //+------------------------------------------------------------------+
   //| Initialize feature extractor                                     |
   //+------------------------------------------------------------------+
   bool Initialize(const string symbol = NULL, int timeframe = PERIOD_CURRENT)
   {
      if(symbol != NULL && symbol != "")
         m_symbol = symbol;
      if(timeframe != PERIOD_CURRENT)
         m_timeframe = timeframe;
      
      // Create indicator handles
      m_handle_atr = iATR(m_symbol, m_timeframe, 14);
      m_handle_rsi = iRSI(m_symbol, m_timeframe, 14, PRICE_CLOSE);
      m_handle_macd = iMACD(m_symbol, m_timeframe, 12, 26, 9, PRICE_CLOSE);
      m_handle_stoch = iStochastic(m_symbol, m_timeframe, 14, 3, 3, MODE_SMA, STO_LOWHIGH);
      m_handle_ma20 = iMA(m_symbol, m_timeframe, 20, 0, MODE_SMA, PRICE_CLOSE);
      m_handle_ma50 = iMA(m_symbol, m_timeframe, 50, 0, MODE_SMA, PRICE_CLOSE);
      
      if(m_handle_atr == INVALID_HANDLE || 
         m_handle_rsi == INVALID_HANDLE ||
         m_handle_macd == INVALID_HANDLE ||
         m_handle_stoch == INVALID_HANDLE ||
         m_handle_ma20 == INVALID_HANDLE ||
         m_handle_ma50 == INVALID_HANDLE)
      {
         PrintFormat("[CFeatures] ERROR: Failed to create indicator handles for %s", m_symbol);
         ReleaseHandles();
         return false;
      }
      
      m_initialized = true;
      PrintFormat("[CFeatures] Initialized for %s %s", m_symbol, EnumToString((ENUM_TIMEFRAMES)m_timeframe));
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Extract all features for current bar                             |
   //+------------------------------------------------------------------+
   SFeatureSet ExtractFeatures()
   {
      SFeatureSet features;
      features.Reset();
      
      if(!m_initialized)
      {
         if(!Initialize())
            return features;
      }
      
      // Copy price data
      if(CopyClose(m_symbol, m_timeframe, 0, m_bars_needed, m_close) <= 0 ||
         CopyHigh(m_symbol, m_timeframe, 0, m_bars_needed, m_high) <= 0 ||
         CopyLow(m_symbol, m_timeframe, 0, m_bars_needed, m_low) <= 0 ||
         CopyOpen(m_symbol, m_timeframe, 0, m_bars_needed, m_open) <= 0 ||
         CopyTime(m_symbol, m_timeframe, 0, m_bars_needed, m_time) <= 0)
      {
         return features;
      }
      
      // Basic price features
      features.open_price = m_open[0];
      features.high_price = m_high[0];
      features.low_price = m_low[0];
      features.close_price = m_close[0];
      
      // Calculate returns
      if(ArraySize(m_close) >= 21)
      {
         features.return_1d = (m_close[0] - m_close[1]) / m_close[1];
         features.return_5d = (m_close[0] - m_close[5]) / m_close[5];
         features.return_10d = (m_close[0] - m_close[10]) / m_close[10];
         features.return_20d = (m_close[0] - m_close[20]) / m_close[20];
      }
      
      // Get indicator values
      double atr_buffer[], rsi_buffer[], macd_main[], macd_signal_buf[];
      double stoch_main[], stoch_sig[];
      double ma20_buffer[], ma50_buffer[];
      
      ArraySetAsSeries(atr_buffer, true);
      ArraySetAsSeries(rsi_buffer, true);
      ArraySetAsSeries(macd_main, true);
      ArraySetAsSeries(macd_signal_buf, true);
      ArraySetAsSeries(stoch_main, true);
      ArraySetAsSeries(stoch_sig, true);
      ArraySetAsSeries(ma20_buffer, true);
      ArraySetAsSeries(ma50_buffer, true);
      
      if(CopyBuffer(m_handle_atr, 0, 0, 3, atr_buffer) > 0)
      {
         features.volatility_daily = atr_buffer[0];
         // ATR ratio relative to price
         features.atr_ratio = atr_buffer[0] / m_close[0];
      }
      
      if(CopyBuffer(m_handle_rsi, 0, 0, 3, rsi_buffer) > 0)
      {
         features.rsi_14 = rsi_buffer[0];
      }
      
      if(CopyBuffer(m_handle_macd, 0, 0, 3, macd_main) > 0 &&
         CopyBuffer(m_handle_macd, 1, 0, 3, macd_signal_buf) > 0)
      {
         features.macd_signal = macd_main[0] - macd_signal_buf[0];
      }
      
      if(CopyBuffer(m_handle_stoch, 0, 0, 3, stoch_main) > 0)
      {
         features.stochastic = stoch_main[0];
      }
      
      if(CopyBuffer(m_handle_ma20, 0, 0, 10, ma20_buffer) > 0)
      {
         features.price_vs_ma20 = (m_close[0] - ma20_buffer[0]) / ma20_buffer[0];
         // Slope approximation
         if(ArraySize(ma20_buffer) >= 5)
            features.ma_20_slope = (ma20_buffer[0] - ma20_buffer[4]) / ma20_buffer[4];
      }
      
      if(CopyBuffer(m_handle_ma50, 0, 0, 10, ma50_buffer) > 0)
      {
         features.price_vs_ma50 = (m_close[0] - ma50_buffer[0]) / ma50_buffer[0];
         // Slope approximation
         if(ArraySize(ma50_buffer) >= 5)
            features.ma_50_slope = (ma50_buffer[0] - ma50_buffer[4]) / ma50_buffer[4];
      }
      
      // Volatility calculation (standard deviation of returns)
      if(ArraySize(m_close) >= 21)
      {
         double returns[];
         ArrayResize(returns, 20);
         for(int i = 0; i < 20; i++)
            returns[i] = (m_close[i] - m_close[i+1]) / m_close[i+1];
         
         features.volatility_daily = StandardDeviation(returns, 20);
         
         // Weekly volatility (approximate)
         if(ArraySize(m_close) >= 100)
         {
            ArrayResize(returns, 100);
            for(int i = 0; i < 100; i++)
               returns[i] = (m_close[i] - m_close[i+1]) / m_close[i+1];
            features.volatility_weekly = StandardDeviation(returns, 100) * MathSqrt(5);
         }
      }
      
      // Volume features (if volume data available)
      if(CopyVolume(m_symbol, m_timeframe, 0, 21, m_volume) > 0)
      {
         double avg_volume = 0;
         for(int i = 1; i <= 20; i++)
            avg_volume += m_volume[i];
         avg_volume /= 20.0;
         
         if(avg_volume > 0)
         {
            features.volume_ratio = m_volume[0] / avg_volume;
            
            // Volume MA ratio (current vs longer average)
            double long_avg = 0;
            for(int i = 1; i <= 50 && i < ArraySize(m_volume); i++)
               long_avg += m_volume[i];
            long_avg /= MathMin(50, ArraySize(m_volume) - 1);
            
            if(long_avg > 0)
               features.volume_ma_ratio = avg_volume / long_avg;
         }
      }
      
      return features;
   }
   
   //+------------------------------------------------------------------+
   //| Get specific feature by name                                     |
   //+------------------------------------------------------------------+
   double GetFeature(const string name)
   {
      SFeatureSet features = ExtractFeatures();
      
      if(name == "return_1d") return features.return_1d;
      if(name == "return_5d") return features.return_5d;
      if(name == "return_10d") return features.return_10d;
      if(name == "return_20d") return features.return_20d;
      if(name == "volatility_daily") return features.volatility_daily;
      if(name == "volatility_weekly") return features.volatility_weekly;
      if(name == "atr_ratio") return features.atr_ratio;
      if(name == "ma_20_slope") return features.ma_20_slope;
      if(name == "ma_50_slope") return features.ma_50_slope;
      if(name == "price_vs_ma20") return features.price_vs_ma20;
      if(name == "price_vs_ma50") return features.price_vs_ma50;
      if(name == "rsi_14") return features.rsi_14;
      if(name == "macd_signal") return features.macd_signal;
      if(name == "stochastic") return features.stochastic;
      if(name == "volume_ratio") return features.volume_ratio;
      if(name == "volume_ma_ratio") return features.volume_ma_ratio;
      
      return 0.0;
   }
   
   //+------------------------------------------------------------------+
   //| Check if initialized                                             |
   //+------------------------------------------------------------------+
   bool IsInitialized() const
   {
      return m_initialized;
   }
   
   //+------------------------------------------------------------------+
   //| Get symbol                                                       |
   //+------------------------------------------------------------------+
   string GetSymbol() const
   {
      return m_symbol;
   }
   
   //+------------------------------------------------------------------+
   //| Get timeframe                                                    |
   //+------------------------------------------------------------------+
   int GetTimeframe() const
   {
      return m_timeframe;
   }
   
private:
   //+------------------------------------------------------------------+
   //| Release indicator handles                                        |
   //+------------------------------------------------------------------+
   void ReleaseHandles()
   {
      if(m_handle_atr != INVALID_HANDLE)
         IndicatorRelease(m_handle_atr);
      if(m_handle_rsi != INVALID_HANDLE)
         IndicatorRelease(m_handle_rsi);
      if(m_handle_macd != INVALID_HANDLE)
         IndicatorRelease(m_handle_macd);
      if(m_handle_stoch != INVALID_HANDLE)
         IndicatorRelease(m_handle_stoch);
      if(m_handle_ma20 != INVALID_HANDLE)
         IndicatorRelease(m_handle_ma20);
      if(m_handle_ma50 != INVALID_HANDLE)
         IndicatorRelease(m_handle_ma50);
      
      m_handle_atr = INVALID_HANDLE;
      m_handle_rsi = INVALID_HANDLE;
      m_handle_macd = INVALID_HANDLE;
      m_handle_stoch = INVALID_HANDLE;
      m_handle_ma20 = INVALID_HANDLE;
      m_handle_ma50 = INVALID_HANDLE;
      m_initialized = false;
   }
};

#endif // CFEATURES_MQH
