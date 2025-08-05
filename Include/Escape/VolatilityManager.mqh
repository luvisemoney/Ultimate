//+------------------------------------------------------------------+
//|                                              VolatilityManager.mqh |
//|                                  Copyright 2025, EscapeEA Team   |
//|                                             https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA Team"
#property link      "https://www.escapeea.com"
#property version   "1.00"
#property strict

#include <Escape/Common/ErrorHandler.mqh>

//+------------------------------------------------------------------+
//| Volatility Calculation Methods                                   |
//+------------------------------------------------------------------+
enum ENUM_VOLATILITY_METHOD
  {
   VOL_ATR,         // Average True Range
   VOL_STD_DEV,     // Standard Deviation
   VOL_PARKINSON,   // Parkinson's volatility
   VOL_GK,          // Garman-Klass volatility
   VOL_RS,          // Rogers-Satchell volatility
   VOL_YZ           // Yang-Zhang volatility
  };

//+------------------------------------------------------------------+
//| Volatility Manager Class                                         |
//+------------------------------------------------------------------+
class CVolatilityManager
  {
private:
   // Configuration
   ENUM_TIMEFRAMES   m_timeframe;     // Default timeframe for calculations
   int               m_period;        // Default period for calculations
   ENUM_VOLATILITY_METHOD m_method;   // Default calculation method
   
   // State
   bool              m_initialized;   // Initialization flag
   
   // Cache
   double            m_lastValues[];  // Cache of last calculated values
   datetime          m_lastUpdate;    // Last update time
   
public:
   //--- Constructor/Destructor
                     CVolatilityManager(void);
                    ~CVolatilityManager(void);
   
   //--- Initialization
   bool              Initialize(void);
   void              Shutdown(void);
   
   //--- Volatility Calculation
   double            GetVolatility(const string symbol, const ENUM_TIMEFRAMES timeframe, const int period,
                                 const ENUM_VOLATILITY_METHOD method, const int shift=0);
   
   double            GetCurrentVolatility(const string symbol, const ENUM_TIMEFRAMES timeframe, 
                                       const int period, const ENUM_VOLATILITY_METHOD method);
   
   double            GetAverageVolatility(const string symbol, const ENUM_TIMEFRAMES timeframe, 
                                        const int period, const int bars, const ENUM_VOLATILITY_METHOD method);
   
   //--- Configuration
   void              SetDefaultTimeframe(const ENUM_TIMEFRAMES timeframe) { m_timeframe = timeframe; }
   void              SetDefaultPeriod(const int period) { m_period = period; }
   void              SetDefaultMethod(const ENUM_VOLATILITY_METHOD method) { m_method = method; }
   
private:
   //--- Calculation Methods
   double            CalculateATR(const string symbol, const int period, const int shift);
   double            CalculateStdDev(const string symbol, const int period, const int shift);
   double            CalculateParkinson(const string symbol, const int period, const int shift);
   double            CalculateGarmanKlass(const string symbol, const int period, const int shift);
   double            CalculateRogersSatchell(const string symbol, const int period, const int shift);
   double            CalculateYangZhang(const string symbol, const int period, const int shift);
   
   //--- Helper Methods
   void              UpdateCache(const string symbol, const ENUM_TIMEFRAMES timeframe, 
                               const int period, const ENUM_VOLATILITY_METHOD method);
   string            GenerateCacheKey(const string symbol, const ENUM_TIMEFRAMES timeframe, 
                                   const int period, const ENUM_VOLATILITY_METHOD method) const;
   double            GetCachedValue(const string key);
   void              SetCachedValue(const string key, const double value);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CVolatilityManager::CVolatilityManager(void) :
   m_timeframe(PERIOD_CURRENT),
   m_period(14),
   m_method(VOL_ATR),
   m_initialized(false),
   m_lastUpdate(0)
  {
   ArrayResize(m_lastValues, 0);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CVolatilityManager::~CVolatilityManager(void)
  {
   Shutdown();
  }

//+------------------------------------------------------------------+
//| Initialize the volatility manager                                |
//+------------------------------------------------------------------+
bool CVolatilityManager::Initialize(void)
  {
   if(m_initialized)
      return true;
      
   // Initialize any required resources
   m_initialized = true;
   return true;
  }

//+------------------------------------------------------------------+
//| Shutdown the volatility manager                                  |
//+------------------------------------------------------------------+
void CVolatilityManager::Shutdown(void)
  {
   if(!m_initialized)
      return;
      
   // Clean up resources
   ArrayFree(m_lastValues);
   m_initialized = false;
  }

//+------------------------------------------------------------------+
//| Get volatility using specified parameters                        |
//+------------------------------------------------------------------+
double CVolatilityManager::GetVolatility(const string symbol, const ENUM_TIMEFRAMES timeframe, 
                                       const int period, const ENUM_VOLATILITY_METHOD method, const int shift)
  {
   // Check for valid parameters
   if(period <= 0)
     {
      CErrorHandler::HandleError(ERR_INVALID_PARAMETER, "Invalid period: " + IntegerToString(period));
      return 0.0;
     }
     
   // Use default values if not specified
   ENUM_TIMEFRAMES tf = (timeframe == PERIOD_CURRENT) ? m_timeframe : timeframe;
   int p = (period <= 0) ? m_period : period;
   ENUM_VOLATILITY_METHOD m = (method == -1) ? m_method : method;
   
   // Calculate volatility based on selected method
   double volatility = 0.0;
   switch(m)
     {
      case VOL_ATR:
         volatility = CalculateATR(symbol, p, shift);
         break;
         
      case VOL_STD_DEV:
         volatility = CalculateStdDev(symbol, p, shift);
         break;
         
      case VOL_PARKINSON:
         volatility = CalculateParkinson(symbol, p, shift);
         break;
         
      case VOL_GK:
         volatility = CalculateGarmanKlass(symbol, p, shift);
         break;
         
      case VOL_RS:
         volatility = CalculateRogersSatchell(symbol, p, shift);
         break;
         
      case VOL_YZ:
         volatility = CalculateYangZhang(symbol, p, shift);
         break;
         
      default:
         CErrorHandler::HandleError(ERR_INVALID_PARAMETER, "Unknown volatility method: " + IntegerToString(m));
         break;
     }
     
   return volatility;
  }

//+------------------------------------------------------------------+
//| Get current volatility                                           |
//+------------------------------------------------------------------+
double CVolatilityManager::GetCurrentVolatility(const string symbol, const ENUM_TIMEFRAMES timeframe, 
                                             const int period, const ENUM_VOLATILITY_METHOD method)
  {
   return GetVolatility(symbol, timeframe, period, method, 0);
  }

//+------------------------------------------------------------------+
//| Get average volatility over a number of bars                     |
//+------------------------------------------------------------------+
double CVolatilityManager::GetAverageVolatility(const string symbol, const ENUM_TIMEFRAMES timeframe, 
                                             const int period, const int bars, const ENUM_VOLATILITY_METHOD method)
  {
   if(bars <= 0)
     {
      CErrorHandler::HandleError(ERR_INVALID_PARAMETER, "Invalid number of bars: " + IntegerToString(bars));
      return 0.0;
     }
     
   double sum = 0.0;
   int count = 0;
   
   // Calculate average volatility over the specified number of bars
   for(int i = 0; i < bars; i++)
     {
      double vol = GetVolatility(symbol, timeframe, period, method, i);
      if(vol > 0)
        {
         sum += vol;
         count++;
        }
     }
     
   return (count > 0) ? sum / count : 0.0;
  }

//+------------------------------------------------------------------+
//| Calculate Average True Range (ATR)                               |
//+------------------------------------------------------------------+
double CVolatilityManager::CalculateATR(const string symbol, const int period, const int shift)
  {
   double atr = iATR(symbol, m_timeframe, period, shift);
   if(atr == 0)
     {
      CErrorHandler::HandleError(ERR_INDICATOR_CALCULATION, "Failed to calculate ATR for " + symbol);
      return 0.0;
     }
     
   return atr;
  }

//+------------------------------------------------------------------+
//| Calculate Standard Deviation                                     |
//+------------------------------------------------------------------+
double CVolatilityManager::CalculateStdDev(const string symbol, const int period, const int shift)
  {
   double close[];
   ArraySetAsSeries(close, true);
   
   // Get close prices
   if(CopyClose(symbol, m_timeframe, shift, period, close) != period)
     {
      CErrorHandler::HandleError(ERR_HISTORY_NOT_FOUND, "Failed to get close prices for " + symbol);
      return 0.0;
     }
     
   // Calculate mean
   double sum = 0.0;
   for(int i = 0; i < period; i++)
      sum += close[i];
   double mean = sum / period;
   
   // Calculate variance
   double variance = 0.0;
   for(int i = 0; i < period; i++)
      variance += MathPow(close[i] - mean, 2);
   variance /= period;
   
   // Standard deviation is the square root of variance
   return MathSqrt(variance);
  }

//+------------------------------------------------------------------+
//| Calculate Parkinson Volatility                                   |
//+------------------------------------------------------------------+
double CVolatilityManager::CalculateParkinson(const string symbol, const int period, const int shift)
  {
   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   // Get high and low prices
   if(CopyHigh(symbol, m_timeframe, shift, period, high) != period ||
      CopyLow(symbol, m_timeframe, shift, period, low) != period)
     {
      CErrorHandler::HandleError(ERR_HISTORY_NOT_FOUND, "Failed to get price data for Parkinson");
      return 0.0;
     }
     
   // Calculate Parkinson volatility
   double sum = 0.0;
   for(int i = 0; i < period; i++)
     {
      if(high[i] > 0 && low[i] > 0)
         sum += MathLog(high[i] / low[i]) * MathLog(high[i] / low[i]);
     }
     
   return MathSqrt(sum / (4 * period * MathLog(2)));
  }

//+------------------------------------------------------------------+
//| Calculate Garman-Klass Volatility                                |
//+------------------------------------------------------------------+
double CVolatilityManager::CalculateGarmanKlass(const string symbol, const int period, const int shift)
  {
   double open[], high[], low[], close[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   // Get price data
   if(CopyOpen(symbol, m_timeframe, shift, period, open) != period ||
      CopyHigh(symbol, m_timeframe, shift, period, high) != period ||
      CopyLow(symbol, m_timeframe, shift, period, low) != period ||
      CopyClose(symbol, m_timeframe, shift, period, close) != period)
     {
      CErrorHandler::HandleError(ERR_HISTORY_NOT_FOUND, "Failed to get price data for Garman-Klass");
      return 0.0;
     }
     
   // Calculate Garman-Klass volatility
   double sum = 0.0;
   for(int i = 0; i < period; i++)
     {
      if(open[i] > 0 && high[i] > 0 && low[i] > 0 && close[i] > 0)
        {
         double u = MathLog(high[i] / open[i]);
         double d = MathLog(low[i] / open[i]);
         double c = MathLog(close[i] / open[i]);
         sum += 0.511 * (u - d) * (u - d) - 0.019 * (c * (u + d) - 2 * u * d) - 0.383 * c * c;
        }
     }
     
   return MathSqrt(sum / period);
  }

//+------------------------------------------------------------------+
//| Calculate Rogers-Satchell Volatility                             |
//+------------------------------------------------------------------+
double CVolatilityManager::CalculateRogersSatchell(const string symbol, const int period, const int shift)
  {
   double open[], high[], low[], close[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   // Get price data
   if(CopyOpen(symbol, m_timeframe, shift, period, open) != period ||
      CopyHigh(symbol, m_timeframe, shift, period, high) != period ||
      CopyLow(symbol, m_timeframe, shift, period, low) != period ||
      CopyClose(symbol, m_timeframe, shift, period, close) != period)
     {
      CErrorHandler::HandleError(ERR_HISTORY_NOT_FOUND, "Failed to get price data for Rogers-Satchell");
      return 0.0;
     }
     
   // Calculate Rogers-Satchell volatility
   double sum = 0.0;
   for(int i = 0; i < period; i++)
     {
      if(open[i] > 0 && high[i] > 0 && low[i] > 0 && close[i] > 0)
        {
         double u = MathLog(high[i] / open[i]);
         double d = MathLog(low[i] / open[i]);
         double c = MathLog(close[i] / open[i]);
         sum += u * (u - c) + d * (d - c);
        }
     }
     
   return MathSqrt(sum / period);
  }

//+------------------------------------------------------------------+
//| Calculate Yang-Zhang Volatility                                  |
//+------------------------------------------------------------------+
double CVolatilityManager::CalculateYangZhang(const string symbol, const int period, const int shift)
  {
   double open[], close[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(close, true);
   
   // Get open and close prices
   if(CopyOpen(symbol, m_timeframe, shift, period, open) != period ||
      CopyClose(symbol, m_timeframe, shift-1, period+1, close) != period+1)
     {
      CErrorHandler::HandleError(ERR_HISTORY_NOT_FOUND, "Failed to get price data for Yang-Zhang");
      return 0.0;
     }
     
   // Calculate Yang-Zhang volatility
   double sum_var = 0.0;
   double sum_mean = 0.0;
   
   for(int i = 0; i < period; i++)
     {
      if(open[i] > 0 && close[i] > 0 && close[i+1] > 0)
        {
         double o = MathLog(open[i] / close[i+1]);
         double c = MathLog(close[i] / open[i]);
         double u = MathLog(high[i] / open[i]);
         double d = MathLog(low[i] / open[i]);
         
         double rs = u * (u - c) + d * (d - c);
         double o_c = o * o;
         double c_c = c * c;
         
         sum_var += 0.511 * rs - 0.019 * (c * (u + d) - 2 * u * d) - 0.383 * c_c;
         sum_mean += o_c;
        }
     }
     
   double k = 0.34 / (1.34 + (period + 1) / (period - 1));
   return MathSqrt(sum_var / period + k * sum_mean / (period - 1));
  }

//+------------------------------------------------------------------+
//| Update the cache with latest values                              |
//+------------------------------------------------------------------+
void CVolatilityManager::UpdateCache(const string symbol, const ENUM_TIMEFRAMES timeframe, 
                                   const int period, const ENUM_VOLATILITY_METHOD method)
  {
   // Implementation for caching would go here
   // This is a placeholder for actual caching logic
  }

//+------------------------------------------------------------------+
//| Generate a cache key                                             |
//+------------------------------------------------------------------+
string CVolatilityManager::GenerateCacheKey(const string symbol, const ENUM_TIMEFRAMES timeframe, 
                                         const int period, const ENUM_VOLATILITY_METHOD method) const
  {
   return symbol + "_" + IntegerToString(timeframe) + "_" + IntegerToString(period) + "_" + IntegerToString(method);
  }

//+------------------------------------------------------------------+
//| Get a value from cache                                           |
//+------------------------------------------------------------------+
double CVolatilityManager::GetCachedValue(const string key)
  {
   // Implementation for getting cached values would go here
   // This is a placeholder for actual caching logic
   return 0.0;
  }

//+------------------------------------------------------------------+
//| Set a value in cache                                             |
//+------------------------------------------------------------------+
void CVolatilityManager::SetCachedValue(const string key, const double value)
  {
   // Implementation for setting cached values would go here
   // This is a placeholder for actual caching logic
  }
//+------------------------------------------------------------------+
