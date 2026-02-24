//+------------------------------------------------------------------+
//| CIndicatorCache.mqh - Technical Indicator Cache                  |
//| Pre-warms and caches indicator values for performance            |
//+------------------------------------------------------------------+
#ifndef CINDICATORCACHE_MQH
#define CINDICATORCACHE_MQH

#include "CDualEAController.mqh"  // For ENUM_INDICATOR_TYPE

//+------------------------------------------------------------------+
//| Indicator Cache Entry                                             |
//+------------------------------------------------------------------+
struct SIndicatorCacheEntry
{
   string   symbol;
   ENUM_TIMEFRAMES timeframe;
   ENUM_INDICATOR_TYPE type;
   int      period;
   double   value;
   datetime last_update;
   int      handle;
   bool     valid;
};

//+------------------------------------------------------------------+
//| Indicator Cache Class                                           |
//+------------------------------------------------------------------+
class CIndicatorCache
{
private:
   SIndicatorCacheEntry m_entries[];
   int                 m_entry_count;
   int                 m_max_entries;
   int                 m_cache_ttl_seconds;
   
   int FindEntry(const string symbol, ENUM_TIMEFRAMES tf, ENUM_INDICATOR_TYPE type, int period)
   {
      for(int i = 0; i < m_entry_count; i++)
      {
         if(m_entries[i].symbol == symbol &&
            m_entries[i].timeframe == tf &&
            m_entries[i].type == type &&
            m_entries[i].period == period)
         {
            return i;
         }
      }
      return -1;
   }
   
   double CalculateIndicator(ENUM_INDICATOR_TYPE type, int period, const string symbol, ENUM_TIMEFRAMES tf)
   {
      double result = 0.0;
      
      switch(type)
      {
         case INDI_MA:
         {
            int handle = iMA(symbol, tf, period, 0, MODE_SMA, PRICE_CLOSE);
            if(handle != INVALID_HANDLE)
            {
               double ma[];
               if(CopyBuffer(handle, 0, 0, 1, ma) > 0)
                  result = ma[0];
               IndicatorRelease(handle);
            }
            break;
         }
         case INDI_RSI:
         {
            int handle = iRSI(symbol, tf, period, PRICE_CLOSE);
            if(handle != INVALID_HANDLE)
            {
               double rsi[];
               if(CopyBuffer(handle, 0, 0, 1, rsi) > 0)
                  result = rsi[0];
               IndicatorRelease(handle);
            }
            break;
         }
         case INDI_ATR:
         {
            int handle = iATR(symbol, tf, period);
            if(handle != INVALID_HANDLE)
            {
               double atr[];
               if(CopyBuffer(handle, 0, 0, 1, atr) > 0)
                  result = atr[0];
               IndicatorRelease(handle);
            }
            break;
         }
         case INDI_MACD:
         {
            int handle = iMACD(symbol, tf, 12, 26, 9, PRICE_CLOSE);
            if(handle != INVALID_HANDLE)
            {
               double macd[];
               if(CopyBuffer(handle, 0, 0, 1, macd) > 0)
                  result = macd[0];
               IndicatorRelease(handle);
            }
            break;
         }
         case INDI_ADX:
         {
            int handle = iADX(symbol, tf, period);
            if(handle != INVALID_HANDLE)
            {
               double adx[];
               if(CopyBuffer(handle, 0, 0, 1, adx) > 0)
                  result = adx[0];
               IndicatorRelease(handle);
            }
            break;
         }
         default:
            result = 0.0;
      }
      
      return result;
   }
   
public:
   CIndicatorCache()
   {
      m_entry_count = 0;
      m_max_entries = 100;
      m_cache_ttl_seconds = 5;
      ArrayResize(m_entries, 0);
   }
   
   ~CIndicatorCache()
   {
      Clear();
   }
   
   void Clear()
   {
      // Release all indicator handles
      for(int i = 0; i < m_entry_count; i++)
      {
         if(m_entries[i].handle != INVALID_HANDLE)
         {
            IndicatorRelease(m_entries[i].handle);
         }
      }
      ArrayResize(m_entries, 0);
      m_entry_count = 0;
   }
   
   bool PreWarmIndicator(const string symbol, ENUM_TIMEFRAMES tf, ENUM_INDICATOR_TYPE type, int period)
   {
      // Check if already cached
      int idx = FindEntry(symbol, tf, type, period);
      if(idx >= 0)
         return true;
      
      // Add new entry
      if(m_entry_count >= m_max_entries)
      {
         Print("[IndicatorCache] Warning: Cache full, cannot pre-warm " + IntegerToString(type));
         return false;
      }
      
      idx = m_entry_count;
      ArrayResize(m_entries, idx + 1);
      
      m_entries[idx].symbol = symbol;
      m_entries[idx].timeframe = tf;
      m_entries[idx].type = type;
      m_entries[idx].period = period;
      m_entries[idx].value = CalculateIndicator(type, period, symbol, tf);
      m_entries[idx].last_update = TimeCurrent();
      m_entries[idx].handle = INVALID_HANDLE;
      m_entries[idx].valid = true;
      
      m_entry_count++;
      return true;
   }
   
   double GetIndicatorValue(const string symbol, ENUM_TIMEFRAMES tf, ENUM_INDICATOR_TYPE type, int period)
   {
      int idx = FindEntry(symbol, tf, type, period);
      
      if(idx >= 0)
      {
         // Check if cache is still valid
         datetime now = TimeCurrent();
         if(now - m_entries[idx].last_update < m_cache_ttl_seconds)
         {
            return m_entries[idx].value;
         }
         
         // Refresh cache
         m_entries[idx].value = CalculateIndicator(type, period, symbol, tf);
         m_entries[idx].last_update = now;
         return m_entries[idx].value;
      }
      
      // Not in cache, calculate directly
      return CalculateIndicator(type, period, symbol, tf);
   }
   
   void InvalidateCache()
   {
      for(int i = 0; i < m_entry_count; i++)
      {
         m_entries[i].valid = false;
      }
   }
   
   int GetCacheSize() const { return m_entry_count; }
   
   void SetCacheTTL(int seconds) { m_cache_ttl_seconds = seconds; }
};

// Global pointer for P0-P5 integration
CIndicatorCache* g_indicator_cache = NULL;

#endif // CINDICATORCACHE_MQH
