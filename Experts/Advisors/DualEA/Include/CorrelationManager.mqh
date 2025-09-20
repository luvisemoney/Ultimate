//+------------------------------------------------------------------+
//| CorrelationManager.mqh                                           |
//| FR-05: Correlation Exposure Caps Management                     |
//+------------------------------------------------------------------+
#property copyright "DualEA"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Correlation exposure management and filtering                   |
//+------------------------------------------------------------------+
class CCorrelationManager
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   
   // Configuration
   bool m_enabled;
   double m_max_correlation;
   int m_lookback_days;
   int m_min_periods;
   
   // Correlation cache
   struct CorrelationData
   {
      string symbol_pair;
      double correlation;
      datetime last_update;
   };
   CorrelationData m_correlation_cache[];
   
public:
   CCorrelationManager(const string symbol, const ENUM_TIMEFRAMES timeframe) :
      m_symbol(symbol), m_timeframe(timeframe), m_enabled(false),
      m_max_correlation(0.7), m_lookback_days(30), m_min_periods(20) {}
   
   // Configuration
   void SetEnabled(const bool enabled) { m_enabled = enabled; }
   void SetMaxCorrelation(const double max_corr) { m_max_correlation = max_corr; }
   void SetLookbackDays(const int days) { m_lookback_days = days; }
   void SetMinPeriods(const int periods) { m_min_periods = periods; }
   
   // Calculate correlation between two symbols
   double CalculateCorrelation(const string symbol1, const string symbol2, const int periods)
   {
      if(symbol1 == symbol2) return 1.0;
      
      double prices1[], prices2[];
      ArrayResize(prices1, periods);
      ArrayResize(prices2, periods);
      
      // Get price data for both symbols
      int copied1 = CopyClose(symbol1, m_timeframe, 0, periods, prices1);
      int copied2 = CopyClose(symbol2, m_timeframe, 0, periods, prices2);
      
      if(copied1 != periods || copied2 != periods)
         return 0.0; // Unable to calculate
      
      // Calculate returns
      double returns1[], returns2[];
      ArrayResize(returns1, periods - 1);
      ArrayResize(returns2, periods - 1);
      
      for(int i = 1; i < periods; i++)
      {
         returns1[i-1] = (prices1[i] - prices1[i-1]) / prices1[i-1];
         returns2[i-1] = (prices2[i] - prices2[i-1]) / prices2[i-1];
      }
      
      // Calculate correlation coefficient
      double sum1 = 0, sum2 = 0, sum1_sq = 0, sum2_sq = 0, sum_prod = 0;
      int n = periods - 1;
      
      for(int i = 0; i < n; i++)
      {
         sum1 += returns1[i];
         sum2 += returns2[i];
         sum1_sq += returns1[i] * returns1[i];
         sum2_sq += returns2[i] * returns2[i];
         sum_prod += returns1[i] * returns2[i];
      }
      
      double mean1 = sum1 / n;
      double mean2 = sum2 / n;
      
      double numerator = sum_prod - n * mean1 * mean2;
      double denominator = MathSqrt((sum1_sq - n * mean1 * mean1) * (sum2_sq - n * mean2 * mean2));
      
      if(denominator == 0.0) return 0.0;
      
      return numerator / denominator;
   }
   
   // Get correlation from cache or calculate if needed
   double GetCorrelation(const string other_symbol, bool force_recalc = false)
   {
      if(!m_enabled) return 0.0;
      
      string pair_key = m_symbol + "|" + other_symbol;
      datetime current_time = TimeCurrent();
      
      // Check cache first
      if(!force_recalc)
      {
         for(int i = 0; i < ArraySize(m_correlation_cache); i++)
         {
            if(m_correlation_cache[i].symbol_pair == pair_key)
            {
               // Use cached value if less than 1 hour old
               if(current_time - m_correlation_cache[i].last_update < 3600)
               {
                  return m_correlation_cache[i].correlation;
               }
               break;
            }
         }
      }
      
      // Calculate new correlation
      int periods = m_lookback_days * 24; // Assuming H1 timeframe, adjust as needed
      if(m_timeframe == PERIOD_M1) periods *= 60;
      else if(m_timeframe == PERIOD_M5) periods *= 12;
      else if(m_timeframe == PERIOD_M15) periods *= 4;
      else if(m_timeframe == PERIOD_M30) periods *= 2;
      else if(m_timeframe == PERIOD_D1) periods = m_lookback_days;
      
      periods = MathMax(periods, m_min_periods);
      
      double correlation = CalculateCorrelation(m_symbol, other_symbol, periods);
      
      // Update cache
      bool found = false;
      for(int i = 0; i < ArraySize(m_correlation_cache); i++)
      {
         if(m_correlation_cache[i].symbol_pair == pair_key)
         {
            m_correlation_cache[i].correlation = correlation;
            m_correlation_cache[i].last_update = current_time;
            found = true;
            break;
         }
      }
      
      if(!found)
      {
         int size = ArraySize(m_correlation_cache);
         ArrayResize(m_correlation_cache, size + 1);
         m_correlation_cache[size].symbol_pair = pair_key;
         m_correlation_cache[size].correlation = correlation;
         m_correlation_cache[size].last_update = current_time;
      }
      
      return correlation;
   }
   
   // Check if correlation exposure is within limits
   bool IsCorrelationAllowed(string &symbols_to_check[], string &reason, double &max_correlation_found)
   {
      reason = "ok";
      max_correlation_found = 0.0;
      
      if(!m_enabled)
         return true;
      
      string problematic_symbol = "";
      
      for(int i = 0; i < ArraySize(symbols_to_check); i++)
      {
         if(symbols_to_check[i] == m_symbol) continue;
         
         double correlation = MathAbs(GetCorrelation(symbols_to_check[i]));
         
         if(correlation > max_correlation_found)
         {
            max_correlation_found = correlation;
            problematic_symbol = symbols_to_check[i];
         }
         
         if(correlation > m_max_correlation)
         {
            reason = StringFormat("correlation_limit_exceeded_%.3f_with_%s", correlation, symbols_to_check[i]);
            return false;
         }
      }
      
      return true;
   }
   
   // Get list of currently open positions for correlation checking
   void GetOpenPositionSymbols(string &symbols[])
   {
      ArrayResize(symbols, 0);
      
      for(int i = 0; i < PositionsTotal(); i++)
      {
         if(PositionGetTicket(i) > 0)
         {
            string pos_symbol = PositionGetString(POSITION_SYMBOL);
            
            // Add to array if not already present
            bool found = false;
            for(int j = 0; j < ArraySize(symbols); j++)
            {
               if(symbols[j] == pos_symbol)
               {
                  found = true;
                  break;
               }
            }
            
            if(!found)
            {
               int size = ArraySize(symbols);
               ArrayResize(symbols, size + 1);
               symbols[size] = pos_symbol;
            }
         }
      }
   }
   
   // Main correlation gate check
   bool CheckCorrelationLimits(string &reason, double &max_correlation)
   {
      reason = "ok";
      max_correlation = 0.0;
      
      if(!m_enabled)
         return true;
      
      string open_symbols[];
      GetOpenPositionSymbols(open_symbols);
      
      return IsCorrelationAllowed(open_symbols, reason, max_correlation);
   }
   
   // Clear correlation cache (for testing or manual refresh)
   void ClearCache()
   {
      ArrayResize(m_correlation_cache, 0);
   }
};
