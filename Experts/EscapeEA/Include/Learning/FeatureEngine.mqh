//+------------------------------------------------------------------+
//| FeatureEngine.mqh - Advanced Feature Engineering for ML         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA - JAILBREAK HARDENED"
#property link      "https://www.escapeea.com"
#property version   "3.00"

#include "..\Common\Enums.mqh"
#include "..\Common\Structs.mqh"
#include "..\Common\Constants.mqh"

//+------------------------------------------------------------------+
//| Feature Set Structure                                            |
//+------------------------------------------------------------------+
struct SFeatureSet
{
   // Price Features
   double            priceFeatures[];       // OHLC normalized features
   double            returnFeatures[];      // Price returns (1, 5, 15, 60 periods)
   double            volatilityFeatures[];  // Volatility measures
   
   // Technical Indicators
   double            trendFeatures[];       // MA, MACD, ADX features
   double            momentumFeatures[];    // RSI, Stochastic, Williams %R
   double            volumeFeatures[];      // Volume-based indicators
   double            supportResistance[];   // S/R levels and distances
   
   // Market Microstructure
   double            spreadFeatures[];      // Bid-ask spread analysis
   double            orderBookFeatures[];   // Order book imbalance (if available)
   double            tickFeatures[];        // Tick-level analysis
   
   // Time Features
   double            timeFeatures[];        // Hour, day, week cyclical features
   double            sessionFeatures[];     // Trading session indicators
   
   // Regime Features
   double            regimeFeatures[];      // Market regime classification
   double            correlationFeatures[]; // Cross-asset correlations
   
   // Meta Features
   int               featureCount;          // Total feature count
   datetime          timestamp;             // Feature extraction time
   string            symbol;                // Symbol for features
   ENUM_TIMEFRAMES   timeframe;            // Timeframe
};

//+------------------------------------------------------------------+
//| Feature Engineering Class                                        |
//+------------------------------------------------------------------+
class CFeatureEngine
{
private:
   // Configuration
   string            m_symbol;              // Trading symbol
   ENUM_TIMEFRAMES   m_timeframe;          // Analysis timeframe
   int               m_lookbackPeriod;     // Lookback period for features
   
   // Indicator Handles
   int               m_maHandles[];        // Multiple MA handles
   int               m_rsiHandle;          // RSI handle
   int               m_macdHandle;         // MACD handle
   int               m_adxHandle;          // ADX handle
   int               m_stochHandle;        // Stochastic handle
   int               m_atrHandle;          // ATR handle
   int               m_bollingerHandle;    // Bollinger Bands handle
   int               m_williamsHandle;     // Williams %R handle
   
   // Feature Normalization
   double            m_featureMeans[];     // Feature means for normalization
   double            m_featureStds[];      // Feature standard deviations
   bool              m_isNormalized;       // Normalization status
   
   // Feature Selection
   double            m_featureImportance[]; // Feature importance scores
   bool              m_selectedFeatures[]; // Selected features mask
   int               m_selectedCount;      // Number of selected features
   
   // Private Methods
   bool              InitializeIndicators();
   void              CleanupIndicators();
   bool              ExtractPriceFeatures(const MqlRates &rates[], int count, SFeatureSet &features);
   bool              ExtractTechnicalFeatures(const MqlRates &rates[], int count, SFeatureSet &features);
   bool              ExtractTimeFeatures(datetime time, SFeatureSet &features);
   bool              ExtractRegimeFeatures(const MqlRates &rates[], int count, SFeatureSet &features);
   void              NormalizeFeatures(SFeatureSet &features);
   double            CalculateCorrelation(const double &x[], const double &y[], int count);
   double            CalculateVolatility(const double &prices[], int count);
   bool              DetectSupportResistance(const MqlRates &rates[], int count, double &levels[]);
   
public:
   // Constructor/Destructor
                     CFeatureEngine(string symbol, ENUM_TIMEFRAMES timeframe, int lookback = 100);
                    ~CFeatureEngine();
   
   // Initialization
   bool              Initialize();
   
   // Feature Extraction
   bool              ExtractFeatures(const MqlRates &rates[], int count, SFeatureSet &features);
   bool              ExtractFeaturesFromTick(const MqlTick &tick, SFeatureSet &features);
   bool              ExtractBatchFeatures(const MqlRates &rates[], int count, SFeatureSet &featureSets[]);
   
   // Feature Engineering
   bool              CreatePolynomialFeatures(SFeatureSet &features, int degree = 2);
   bool              CreateInteractionFeatures(SFeatureSet &features);
   bool              CreateLaggedFeatures(const SFeatureSet &history[], int historyCount, SFeatureSet &features);
   
   // Feature Selection
   bool              SelectFeatures(const SFeatureSet &features[], const double &targets[], int count);
   bool              ApplyFeatureSelection(SFeatureSet &features);
   void              PrintFeatureImportance();
   
   // Feature Normalization
   bool              FitNormalization(const SFeatureSet &features[], int count);
   bool              TransformFeatures(SFeatureSet &features);
   bool              InverseTransform(SFeatureSet &features);
   
   // Utilities
   int               GetFeatureCount() const;
   bool              SaveFeatureConfig(const string filename);
   bool              LoadFeatureConfig(const string filename);
   void              PrintFeatureStats(const SFeatureSet &features);
   
   // Advanced Features
   bool              CreateWaveletFeatures(const double &prices[], int count, double &wavelets[]);
   bool              CreateFourierFeatures(const double &prices[], int count, double &fourier[]);
   bool              CreateFractalFeatures(const double &prices[], int count, double &fractals[]);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CFeatureEngine::CFeatureEngine(string symbol, ENUM_TIMEFRAMES timeframe, int lookback = 100) :
   m_symbol(symbol),
   m_timeframe(timeframe),
   m_lookbackPeriod(lookback),
   m_isNormalized(false),
   m_selectedCount(0)
{
   Print("🔧 Feature Engine initialized for ", symbol, " (", EnumToString(timeframe), ")");
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CFeatureEngine::~CFeatureEngine()
{
   CleanupIndicators();
   Print("🔧 Feature Engine destroyed");
}

//+------------------------------------------------------------------+
//| Initialize indicators                                            |
//+------------------------------------------------------------------+
bool CFeatureEngine::InitializeIndicators()
{
   // Initialize multiple moving averages
   ArrayResize(m_maHandles, 4);
   m_maHandles[0] = iMA(m_symbol, m_timeframe, 9, 0, MODE_EMA, PRICE_CLOSE);   // Fast EMA
   m_maHandles[1] = iMA(m_symbol, m_timeframe, 21, 0, MODE_EMA, PRICE_CLOSE);  // Medium EMA
   m_maHandles[2] = iMA(m_symbol, m_timeframe, 50, 0, MODE_SMA, PRICE_CLOSE);  // Slow SMA
   m_maHandles[3] = iMA(m_symbol, m_timeframe, 200, 0, MODE_SMA, PRICE_CLOSE); // Long SMA
   
   // Initialize other indicators
   m_rsiHandle = iRSI(m_symbol, m_timeframe, 14, PRICE_CLOSE);
   m_macdHandle = iMACD(m_symbol, m_timeframe, 12, 26, 9, PRICE_CLOSE);
   m_adxHandle = iADX(m_symbol, m_timeframe, 14);
   m_stochHandle = iStochastic(m_symbol, m_timeframe, 14, 3, 3, MODE_SMA, STO_LOWHIGH);
   m_atrHandle = iATR(m_symbol, m_timeframe, 14);
   m_bollingerHandle = iBands(m_symbol, m_timeframe, 20, 0, 2.0, PRICE_CLOSE);
   m_williamsHandle = iWPR(m_symbol, m_timeframe, 14);
   
   // Verify all handles
   bool allValid = true;
   for(int i = 0; i < ArraySize(m_maHandles); i++)
   {
      if(m_maHandles[i] == INVALID_HANDLE) allValid = false;
   }
   
   if(m_rsiHandle == INVALID_HANDLE || m_macdHandle == INVALID_HANDLE ||
      m_adxHandle == INVALID_HANDLE || m_stochHandle == INVALID_HANDLE ||
      m_atrHandle == INVALID_HANDLE || m_bollingerHandle == INVALID_HANDLE ||
      m_williamsHandle == INVALID_HANDLE)
   {
      allValid = false;
   }
   
   if(!allValid)
   {
      Print("❌ Failed to initialize some indicators");
      CleanupIndicators();
      return false;
   }
   
   Print("✅ All indicators initialized successfully");
   return true;
}

//+------------------------------------------------------------------+
//| Extract comprehensive features                                   |
//+------------------------------------------------------------------+
bool CFeatureEngine::ExtractFeatures(const MqlRates &rates[], int count, SFeatureSet &features)
{
   if(count < m_lookbackPeriod)
   {
      Print("❌ Insufficient data for feature extraction");
      return false;
   }
   
   // Initialize feature set
   features.timestamp = TimeCurrent();
   features.symbol = m_symbol;
   features.timeframe = m_timeframe;
   
   // Extract different feature categories
   if(!ExtractPriceFeatures(rates, count, features))
   {
      Print("❌ Failed to extract price features");
      return false;
   }
   
   if(!ExtractTechnicalFeatures(rates, count, features))
   {
      Print("❌ Failed to extract technical features");
      return false;
   }
   
   if(!ExtractTimeFeatures(rates[count-1].time, features))
   {
      Print("❌ Failed to extract time features");
      return false;
   }
   
   if(!ExtractRegimeFeatures(rates, count, features))
   {
      Print("❌ Failed to extract regime features");
      return false;
   }
   
   // Count total features
   features.featureCount = ArraySize(features.priceFeatures) + 
                          ArraySize(features.returnFeatures) +
                          ArraySize(features.volatilityFeatures) +
                          ArraySize(features.trendFeatures) +
                          ArraySize(features.momentumFeatures) +
                          ArraySize(features.volumeFeatures) +
                          ArraySize(features.timeFeatures) +
                          ArraySize(features.regimeFeatures);
   
   Print("✅ Extracted ", features.featureCount, " features");
   return true;
}

//+------------------------------------------------------------------+
//| Extract price-based features                                    |
//+------------------------------------------------------------------+
bool CFeatureEngine::ExtractPriceFeatures(const MqlRates &rates[], int count, SFeatureSet &features)
{
   // Price normalization features
   ArrayResize(features.priceFeatures, 8);
   
   double currentClose = rates[count-1].close;
   double currentHigh = rates[count-1].high;
   double currentLow = rates[count-1].low;
   double currentOpen = rates[count-1].open;
   
   // Normalize prices relative to recent range
   double maxPrice = rates[count-1].high;
   double minPrice = rates[count-1].low;
   
   for(int i = count-20; i < count; i++) // 20-period range
   {
      if(i >= 0)
      {
         maxPrice = MathMax(maxPrice, rates[i].high);
         minPrice = MathMin(minPrice, rates[i].low);
      }
   }
   
   double range = maxPrice - minPrice;
   if(range > 0)
   {
      features.priceFeatures[0] = (currentClose - minPrice) / range;    // Normalized close
      features.priceFeatures[1] = (currentHigh - minPrice) / range;     // Normalized high
      features.priceFeatures[2] = (currentLow - minPrice) / range;      // Normalized low
      features.priceFeatures[3] = (currentOpen - minPrice) / range;     // Normalized open
   }
   
   // Price ratios
   features.priceFeatures[4] = (currentHigh - currentLow) / currentClose;  // Range ratio
   features.priceFeatures[5] = (currentClose - currentOpen) / currentClose; // Body ratio
   features.priceFeatures[6] = (currentHigh - MathMax(currentOpen, currentClose)) / currentClose; // Upper shadow
   features.priceFeatures[7] = (MathMin(currentOpen, currentClose) - currentLow) / currentClose;  // Lower shadow
   
   // Return features
   ArrayResize(features.returnFeatures, 4);
   if(count > 1)
   {
      features.returnFeatures[0] = (currentClose - rates[count-2].close) / rates[count-2].close; // 1-period return
   }
   if(count > 5)
   {
      features.returnFeatures[1] = (currentClose - rates[count-6].close) / rates[count-6].close; // 5-period return
   }
   if(count > 15)
   {
      features.returnFeatures[2] = (currentClose - rates[count-16].close) / rates[count-16].close; // 15-period return
   }
   if(count > 60)
   {
      features.returnFeatures[3] = (currentClose - rates[count-61].close) / rates[count-61].close; // 60-period return
   }
   
   // Volatility features
   ArrayResize(features.volatilityFeatures, 3);
   
   // Calculate different volatility measures
   double prices[];
   ArrayResize(prices, MathMin(20, count));
   for(int i = 0; i < ArraySize(prices); i++)
   {
      prices[i] = rates[count - 1 - i].close;
   }
   
   features.volatilityFeatures[0] = CalculateVolatility(prices, ArraySize(prices)); // 20-period volatility
   
   // Parkinson volatility (high-low)
   double parkVol = 0.0;
   for(int i = count-20; i < count && i >= 0; i++)
   {
      double hlRatio = MathLog(rates[i].high / rates[i].low);
      parkVol += hlRatio * hlRatio;
   }
   features.volatilityFeatures[1] = MathSqrt(parkVol / 20.0);
   
   // Garman-Klass volatility
   double gkVol = 0.0;
   for(int i = count-20; i < count && i >= 0; i++)
   {
      if(i > 0)
      {
         double hlTerm = 0.5 * MathPow(MathLog(rates[i].high / rates[i].low), 2);
         double ocTerm = (2 * MathLog(2) - 1) * MathPow(MathLog(rates[i].close / rates[i].open), 2);
         gkVol += hlTerm - ocTerm;
      }
   }
   features.volatilityFeatures[2] = MathSqrt(gkVol / 19.0);
   
   return true;
}

//+------------------------------------------------------------------+
//| Extract technical indicator features                            |
//+------------------------------------------------------------------+
bool CFeatureEngine::ExtractTechnicalFeatures(const MqlRates &rates[], int count, SFeatureSet &features)
{
   // Trend features
   ArrayResize(features.trendFeatures, 12);
   
   // Moving averages
   double maValues[];
   for(int ma = 0; ma < ArraySize(m_maHandles); ma++)
   {
      ArrayResize(maValues, 1);
      if(CopyBuffer(m_maHandles[ma], 0, 0, 1, maValues) > 0)
      {
         features.trendFeatures[ma] = maValues[0] / rates[count-1].close - 1.0; // MA relative to price
      }
   }
   
   // MACD features
   double macdMain[], macdSignal[];
   ArrayResize(macdMain, 1);
   ArrayResize(macdSignal, 1);
   if(CopyBuffer(m_macdHandle, 0, 0, 1, macdMain) > 0 && 
      CopyBuffer(m_macdHandle, 1, 0, 1, macdSignal) > 0)
   {
      features.trendFeatures[4] = macdMain[0];
      features.trendFeatures[5] = macdSignal[0];
      features.trendFeatures[6] = macdMain[0] - macdSignal[0]; // MACD histogram
   }
   
   // ADX features
   double adxMain[], adxPlus[], adxMinus[];
   ArrayResize(adxMain, 1);
   ArrayResize(adxPlus, 1);
   ArrayResize(adxMinus, 1);
   if(CopyBuffer(m_adxHandle, 0, 0, 1, adxMain) > 0 &&
      CopyBuffer(m_adxHandle, 1, 0, 1, adxPlus) > 0 &&
      CopyBuffer(m_adxHandle, 2, 0, 1, adxMinus) > 0)
   {
      features.trendFeatures[7] = adxMain[0] / 100.0;  // Normalized ADX
      features.trendFeatures[8] = adxPlus[0] / 100.0;  // Normalized +DI
      features.trendFeatures[9] = adxMinus[0] / 100.0; // Normalized -DI
      features.trendFeatures[10] = (adxPlus[0] - adxMinus[0]) / 100.0; // DI difference
   }
   
   // Trend strength
   double trendStrength = 0.0;
   if(count >= 20)
   {
      double slope = (rates[count-1].close - rates[count-20].close) / 19.0;
      double avgPrice = 0.0;
      for(int i = count-20; i < count; i++)
      {
         avgPrice += rates[i].close;
      }
      avgPrice /= 20.0;
      trendStrength = slope / avgPrice;
   }
   features.trendFeatures[11] = trendStrength;
   
   // Momentum features
   ArrayResize(features.momentumFeatures, 6);
   
   // RSI
   double rsiValues[];
   ArrayResize(rsiValues, 1);
   if(CopyBuffer(m_rsiHandle, 0, 0, 1, rsiValues) > 0)
   {
      features.momentumFeatures[0] = rsiValues[0] / 100.0 - 0.5; // Centered RSI
   }
   
   // Stochastic
   double stochMain[], stochSignal[];
   ArrayResize(stochMain, 1);
   ArrayResize(stochSignal, 1);
   if(CopyBuffer(m_stochHandle, 0, 0, 1, stochMain) > 0 &&
      CopyBuffer(m_stochHandle, 1, 0, 1, stochSignal) > 0)
   {
      features.momentumFeatures[1] = stochMain[0] / 100.0 - 0.5;   // Centered Stoch %K
      features.momentumFeatures[2] = stochSignal[0] / 100.0 - 0.5; // Centered Stoch %D
   }
   
   // Williams %R
   double williamsValues[];
   ArrayResize(williamsValues, 1);
   if(CopyBuffer(m_williamsHandle, 0, 0, 1, williamsValues) > 0)
   {
      features.momentumFeatures[3] = (williamsValues[0] + 50.0) / 100.0; // Normalized Williams %R
   }
   
   // Rate of Change
   if(count > 14)
   {
      features.momentumFeatures[4] = (rates[count-1].close - rates[count-15].close) / rates[count-15].close;
   }
   
   // Momentum oscillator
   if(count > 10)
   {
      features.momentumFeatures[5] = rates[count-1].close / rates[count-11].close - 1.0;
   }
   
   // Volume features (simplified - MT5 tick volume)
   ArrayResize(features.volumeFeatures, 4);
   
   if(count >= 20)
   {
      // Volume ratios
      double currentVolume = (double)rates[count-1].tick_volume;
      double avgVolume = 0.0;
      for(int i = count-20; i < count; i++)
      {
         avgVolume += (double)rates[i].tick_volume;
      }
      avgVolume /= 20.0;
      
      features.volumeFeatures[0] = (avgVolume > 0) ? currentVolume / avgVolume - 1.0 : 0.0;
      
      // Volume trend
      double volumeTrend = 0.0;
      if(count >= 10)
      {
         double recentVol = 0.0, olderVol = 0.0;
         for(int i = count-5; i < count; i++)
         {
            recentVol += (double)rates[i].tick_volume;
         }
         for(int i = count-10; i < count-5; i++)
         {
            olderVol += (double)rates[i].tick_volume;
         }
         volumeTrend = (olderVol > 0) ? recentVol / olderVol - 1.0 : 0.0;
      }
      features.volumeFeatures[1] = volumeTrend;
      
      // Price-volume correlation
      double priceVol = 0.0;
      if(count >= 20)
      {
         double prices[], volumes[];
         ArrayResize(prices, 20);
         ArrayResize(volumes, 20);
         
         for(int i = 0; i < 20; i++)
         {
            prices[i] = rates[count-20+i].close;
            volumes[i] = (double)rates[count-20+i].tick_volume;
         }
         
         priceVol = CalculateCorrelation(prices, volumes, 20);
      }
      features.volumeFeatures[2] = priceVol;
      
      // Volume volatility
      double volVol = 0.0;
      if(count >= 20)
      {
         double volumes[];
         ArrayResize(volumes, 20);
         for(int i = 0; i < 20; i++)
         {
            volumes[i] = (double)rates[count-20+i].tick_volume;
         }
         volVol = CalculateVolatility(volumes, 20);
      }
      features.volumeFeatures[3] = volVol;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Extract time-based features                                     |
//+------------------------------------------------------------------+
bool CFeatureEngine::ExtractTimeFeatures(datetime time, SFeatureSet &features)
{
   ArrayResize(features.timeFeatures, 8);
   
   MqlDateTime dt;
   TimeToStruct(time, dt);
   
   // Cyclical time features (using sine/cosine for cyclical nature)
   features.timeFeatures[0] = MathSin(2.0 * M_PI * dt.hour / 24.0);        // Hour sine
   features.timeFeatures[1] = MathCos(2.0 * M_PI * dt.hour / 24.0);        // Hour cosine
   features.timeFeatures[2] = MathSin(2.0 * M_PI * dt.day_of_week / 7.0);  // Day of week sine
   features.timeFeatures[3] = MathCos(2.0 * M_PI * dt.day_of_week / 7.0);  // Day of week cosine
   features.timeFeatures[4] = MathSin(2.0 * M_PI * dt.day / 31.0);         // Day of month sine
   features.timeFeatures[5] = MathCos(2.0 * M_PI * dt.day / 31.0);         // Day of month cosine
   
   // Trading session features
   features.timeFeatures[6] = 0.0; // Asian session
   features.timeFeatures[7] = 0.0; // European session
   
   // Determine trading session (simplified)
   if(dt.hour >= 0 && dt.hour < 8)
      features.timeFeatures[6] = 1.0; // Asian
   else if(dt.hour >= 8 && dt.hour < 16)
      features.timeFeatures[7] = 1.0; // European
   // US session would be features.timeFeatures[8] if we had more features
   
   ArrayResize(features.sessionFeatures, 3);
   features.sessionFeatures[0] = features.timeFeatures[6]; // Asian
   features.sessionFeatures[1] = features.timeFeatures[7]; // European
   features.sessionFeatures[2] = (dt.hour >= 16 && dt.hour < 24) ? 1.0 : 0.0; // US
   
   return true;
}

//+------------------------------------------------------------------+
//| Extract market regime features                                  |
//+------------------------------------------------------------------+
bool CFeatureEngine::ExtractRegimeFeatures(const MqlRates &rates[], int count, SFeatureSet &features)
{
   ArrayResize(features.regimeFeatures, 6);
   
   if(count < 50) return false;
   
   // Trend regime
   double shortMA = 0.0, longMA = 0.0;
   for(int i = count-10; i < count; i++)
   {
      shortMA += rates[i].close;
   }
   shortMA /= 10.0;
   
   for(int i = count-50; i < count; i++)
   {
      longMA += rates[i].close;
   }
   longMA /= 50.0;
   
   features.regimeFeatures[0] = (shortMA > longMA) ? 1.0 : 0.0; // Uptrend
   features.regimeFeatures[1] = (shortMA < longMA) ? 1.0 : 0.0; // Downtrend
   
   // Volatility regime
   double recentVol = 0.0, historicalVol = 0.0;
   
   // Recent volatility (10 periods)
   for(int i = count-10; i < count-1; i++)
   {
      double ret = (rates[i+1].close - rates[i].close) / rates[i].close;
      recentVol += ret * ret;
   }
   recentVol = MathSqrt(recentVol / 9.0);
   
   // Historical volatility (50 periods)
   for(int i = count-50; i < count-1; i++)
   {
      double ret = (rates[i+1].close - rates[i].close) / rates[i].close;
      historicalVol += ret * ret;
   }
   historicalVol = MathSqrt(historicalVol / 49.0);
   
   features.regimeFeatures[2] = (recentVol > historicalVol * 1.5) ? 1.0 : 0.0; // High volatility
   features.regimeFeatures[3] = (recentVol < historicalVol * 0.5) ? 1.0 : 0.0; // Low volatility
   
   // Mean reversion regime
   double meanPrice = 0.0;
   for(int i = count-20; i < count; i++)
   {
      meanPrice += rates[i].close;
   }
   meanPrice /= 20.0;
   
   double currentPrice = rates[count-1].close;
   double deviation = MathAbs(currentPrice - meanPrice) / meanPrice;
   
   features.regimeFeatures[4] = (deviation > 0.02) ? 1.0 : 0.0; // Trending regime
   features.regimeFeatures[5] = (deviation < 0.01) ? 1.0 : 0.0; // Mean reverting regime
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate correlation between two arrays                        |
//+------------------------------------------------------------------+
double CFeatureEngine::CalculateCorrelation(const double &x[], const double &y[], int count)
{
   if(count <= 1) return 0.0;
   
   double sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumX2 = 0.0, sumY2 = 0.0;
   
   for(int i = 0; i < count; i++)
   {
      sumX += x[i];
      sumY += y[i];
      sumXY += x[i] * y[i];
      sumX2 += x[i] * x[i];
      sumY2 += y[i] * y[i];
   }
   
   double meanX = sumX / count;
   double meanY = sumY / count;
   
   double numerator = sumXY - count * meanX * meanY;
   double denominator = MathSqrt((sumX2 - count * meanX * meanX) * (sumY2 - count * meanY * meanY));
   
   return (denominator != 0.0) ? numerator / denominator : 0.0;
}

//+------------------------------------------------------------------+
//| Calculate volatility                                            |
//+------------------------------------------------------------------+
double CFeatureEngine::CalculateVolatility(const double &prices[], int count)
{
   if(count <= 1) return 0.0;
   
   double sumReturns = 0.0, sumSquaredReturns = 0.0;
   
   for(int i = 1; i < count; i++)
   {
      double ret = (prices[i] - prices[i-1]) / prices[i-1];
      sumReturns += ret;
      sumSquaredReturns += ret * ret;
   }
   
   double meanReturn = sumReturns / (count - 1);
   double variance = (sumSquaredReturns / (count - 1)) - (meanReturn * meanReturn);
   
   return MathSqrt(MathMax(0.0, variance));
}

//+------------------------------------------------------------------+
//| Get total feature count                                         |
//+------------------------------------------------------------------+
int CFeatureEngine::GetFeatureCount() const
{
   // Calculate total features based on current configuration
   return 8 + 4 + 3 + 12 + 6 + 4 + 8 + 6; // Price + Returns + Vol + Trend + Momentum + Volume + Time + Regime
}

//+------------------------------------------------------------------+
//| Initialize feature engine                                        |
//+------------------------------------------------------------------+
bool CFeatureEngine::Initialize()
{
   return InitializeIndicators();
}

//+------------------------------------------------------------------+
//| Cleanup indicators                                              |
//+------------------------------------------------------------------+
void CFeatureEngine::CleanupIndicators()
{
   // Release all indicator handles
   for(int i = 0; i < ArraySize(m_maHandles); i++)
   {
      if(m_maHandles[i] != INVALID_HANDLE)
      {
         IndicatorRelease(m_maHandles[i]);
      }
   }
   
   if(m_rsiHandle != INVALID_HANDLE) IndicatorRelease(m_rsiHandle);
   if(m_macdHandle != INVALID_HANDLE) IndicatorRelease(m_macdHandle);
   if(m_adxHandle != INVALID_HANDLE) IndicatorRelease(m_adxHandle);
   if(m_stochHandle != INVALID_HANDLE) IndicatorRelease(m_stochHandle);
   if(m_atrHandle != INVALID_HANDLE) IndicatorRelease(m_atrHandle);
   if(m_bollingerHandle != INVALID_HANDLE) IndicatorRelease(m_bollingerHandle);
   if(m_williamsHandle != INVALID_HANDLE) IndicatorRelease(m_williamsHandle);
}