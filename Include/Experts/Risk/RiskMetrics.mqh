//+------------------------------------------------------------------+
//|                                                RiskMetrics.mqh    |
//|                        Copyright 2025, Your Company Name          |
//|                                             https://www.yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company Name"
#property link      "https://www.yoursite.com"
#property version   "1.00"
#property strict

#include <Math\Stat\Stat.mqh>

//+------------------------------------------------------------------+
//| Risk Metrics Class                                               |
//+------------------------------------------------------------------+
class CRiskMetrics
{
private:
   // Market data
   string            m_symbol;            // Symbol
   ENUM_TIMEFRAMES   m_timeframe;         // Timeframe
   
   // Volatility metrics
   double            m_atr;               // Average True Range
   double            m_volatility;        // Current volatility (standard deviation)
   double            m_historicalVol;     // Historical volatility
   
   // Risk metrics
   double            m_var95;             // Value at Risk (95% confidence)
   double            m_es95;              // Expected Shortfall (95% confidence)
   double            m_maxDrawdown;       // Maximum drawdown
   double            m_sharpeRatio;       // Sharpe ratio
   double            m_sortinoRatio;      // Sortino ratio
   
   // Technical indicators
   int               m_atrHandle;         // ATR indicator handle
   int               m_stdDevHandle;      // Standard Deviation handle
   
   // Parameters
   int               m_lookbackPeriod;    // Lookback period for metrics
   int               m_volatilityPeriod;  // Period for volatility calculation
   
   // Internal state
   bool              m_isInitialized;     // Initialization flag
   
   // Private methods
   bool              CalculateVolatility();
   bool              CalculateValueAtRisk();
   bool              CalculateExpectedShortfall();
   bool              CalculateDrawdown();
   bool              CalculateRatios();
   
public:
   // Constructor/Destructor
                     CRiskMetrics();
                    ~CRiskMetrics();
   
   // Initialization
   bool              Initialize(const string symbol, const ENUM_TIMEFRAMES timeframe, 
                              const int lookbackPeriod = 100, const int volatilityPeriod = 20);
   void              Deinitialize();
   
   // Update methods
   bool              UpdateVolatility();
   void              UpdateAllMetrics();
   
   // Getters
   double            GetCurrentVolatility() const { return m_volatility; }
   double            GetHistoricalVolatility() const { return m_historicalVol; }
   double            GetValueAtRisk() const { return m_var95; }
   double            GetExpectedShortfall() const { return m_es95; }
   double            GetMaxDrawdown() const { return m_maxDrawdown; }
   double            GetSharpeRatio() const { return m_sharpeRatio; }
   double            GetSortinoRatio() const { return m_sortinoRatio; }
   double            GetATR() const { return m_atr; }
   
   // Utility methods
   static double     CalculateStopLossPips(const string symbol, const double price, 
                                         const double stopDistance, const bool isPips = true);
   static double     CalculatePositionRisk(const double entryPrice, const double stopLoss, 
                                         const double positionSize, const string symbol);
   
   // Risk assessment
   bool              IsVolatilityTooHigh(const double maxVolatility = 0.02) const;
   bool              IsDrawdownLimitReached(const double maxDrawdownPercent) const;
   
   // Statistical methods
   static double     CalculateStandardDeviation(const double &values[], const int count);
   static double     CalculateCorrelation(const double &x[], const double &y[], const int count);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRiskMetrics::CRiskMetrics() :
   m_symbol(""),
   m_timeframe(PERIOD_CURRENT),
   m_atr(0.0),
   m_volatility(0.0),
   m_historicalVol(0.0),
   m_var95(0.0),
   m_es95(0.0),
   m_maxDrawdown(0.0),
   m_sharpeRatio(0.0),
   m_sortinoRatio(0.0),
   m_atrHandle(INVALID_HANDLE),
   m_stdDevHandle(INVALID_HANDLE),
   m_lookbackPeriod(100),
   m_volatilityPeriod(20),
   m_isInitialized(false)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CRiskMetrics::~CRiskMetrics()
{
   Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize risk metrics calculator                               |
//+------------------------------------------------------------------+
bool CRiskMetrics::Initialize(const string symbol, const ENUM_TIMEFRAMES timeframe, 
                            const int lookbackPeriod = 100, const int volatilityPeriod = 20)
{
   if (m_isInitialized)
      return true;
      
   if (symbol == "" || lookbackPeriod <= 0 || volatilityPeriod <= 0)
      return false;
      
   m_symbol = symbol;
   m_timeframe = timeframe;
   m_lookbackPeriod = lookbackPeriod;
   m_volatilityPeriod = volatilityPeriod;
   
   // Initialize indicators
   m_atrHandle = iATR(m_symbol, m_timeframe, 14);
   m_stdDevHandle = iStdDev(m_symbol, m_timeframe, 20, 0, MODE_SMA, PRICE_CLOSE);
   
   if (m_atrHandle == INVALID_HANDLE || m_stdDevHandle == INVALID_HANDLE)
   {
      Print("Failed to initialize indicators");
      return false;
   }
   
   // Initial calculations
   if (!UpdateAllMetrics())
   {
      Print("Failed to calculate initial metrics");
      return false;
   }
   
   m_isInitialized = true;
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialize risk metrics calculator                             |
//+------------------------------------------------------------------+
void CRiskMetrics::Deinitialize()
{
   // Release indicators
   if (m_atrHandle != INVALID_HANDLE)
   {
      IndicatorRelease(m_atrHandle);
      m_atrHandle = INVALID_HANDLE;
   }
   
   if (m_stdDevHandle != INVALID_HANDLE)
   {
      IndicatorRelease(m_stdDevHandle);
      m_stdDevHandle = INVALID_HANDLE;
   }
   
   m_isInitialized = false;
}

//+------------------------------------------------------------------+
//| Update volatility metrics                                        |
//+------------------------------------------------------------------+
bool CRiskMetrics::UpdateVolatility()
{
   if (!m_isInitialized)
      return false;
      
   // Get ATR value
   double atrBuffer[];
   if (CopyBuffer(m_atrHandle, 0, 0, 1, atrBuffer) != 1)
      return false;
      
   m_atr = atrBuffer[0];
   
   // Get standard deviation
   double stdDevBuffer[];
   if (CopyBuffer(m_stdDevHandle, 0, 0, 1, stdDevBuffer) != 1)
      return false;
      
   m_volatility = stdDevBuffer[0];
   
   // Calculate historical volatility
   if (!CalculateVolatility())
      return false;
      
   return true;
}

//+------------------------------------------------------------------+
//| Update all risk metrics                                          |
//+------------------------------------------------------------------+
void CRiskMetrics::UpdateAllMetrics()
{
   if (!m_isInitialized)
      return;
      
   // Update volatility first as it's used by other calculations
   UpdateVolatility();
   
   // Calculate other metrics
   CalculateValueAtRisk();
   CalculateExpectedShortfall();
   CalculateDrawdown();
   CalculateRatios();
}

//+------------------------------------------------------------------+
//| Calculate volatility metrics                                     |
//+------------------------------------------------------------------+
bool CRiskMetrics::CalculateVolatility()
{
   // Get close prices for volatility calculation
   double close[];
   int count = m_volatilityPeriod;
   
   if (CopyClose(m_symbol, m_timeframe, 0, count, close) != count)
      return false;
      
   // Calculate returns
   double returns[];
   ArrayResize(returns, count-1);
   
   for (int i = 0; i < count-1; i++)
   {
      if (close[i+1] > 0.0)
         returns[i] = (close[i] - close[i+1]) / close[i+1];
      else
         returns[i] = 0.0;
   }
   
   // Calculate standard deviation of returns (annualized)
   double sum = 0.0;
   double sumSq = 0.0;
   
   for (int i = 0; i < ArraySize(returns); i++)
   {
      sum += returns[i];
      sumSq += returns[i] * returns[i];
   }
   
   double mean = sum / ArraySize(returns);
   double variance = (sumSq / ArraySize(returns)) - (mean * mean);
   
   // Annualize the volatility (assuming 252 trading days)
   m_historicalVol = MathSqrt(variance) * MathSqrt(252.0);
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate Value at Risk (VaR)                                    |
//+------------------------------------------------------------------+
bool CRiskMetrics::CalculateValueAtRisk()
{
   // Get close prices
   double close[];
   int count = m_lookbackPeriod;
   
   if (CopyClose(m_symbol, m_timeframe, 0, count, close) != count)
      return false;
      
   // Calculate returns
   double returns[];
   ArrayResize(returns, count-1);
   
   for (int i = 0; i < count-1; i++)
   {
      if (close[i+1] > 0.0)
         returns[i] = (close[i] - close[i+1]) / close[i+1];
      else
         returns[i] = 0.0;
   }
   
   // Sort returns for historical simulation
   ArraySort(returns);
   
   // Calculate 95% VaR (5th percentile)
   int index = (int)MathFloor(0.05 * ArraySize(returns));
   m_var95 = returns[index];
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate Expected Shortfall (ES)                                |
//+------------------------------------------------------------------+
bool CRiskMetrics::CalculateExpectedShortfall()
{
   // This is a simplified implementation
   // In practice, you might want to use a more sophisticated method
   
   // Get close prices
   double close[];
   int count = m_lookbackPeriod;
   
   if (CopyClose(m_symbol, m_timeframe, 0, count, close) != count)
      return false;
      
   // Calculate returns
   double returns[];
   ArrayResize(returns, count-1);
   
   for (int i = 0; i < count-1; i++)
   {
      if (close[i+1] > 0.0)
         returns[i] = (close[i] - close[i+1]) / close[i+1];
      else
         returns[i] = 0.0;
   }
   
   // Sort returns for historical simulation
   ArraySort(returns);
   
   // Calculate 95% ES (average of worst 5% returns)
   int varIndex = (int)MathFloor(0.05 * ArraySize(returns));
   double sum = 0.0;
   
   for (int i = 0; i <= varIndex; i++)
   {
      sum += returns[i];
   }
   
   m_es95 = sum / (varIndex + 1);
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate drawdown metrics                                       |
//+------------------------------------------------------------------+
bool CRiskMetrics::CalculateDrawdown()
{
   // This is a simplified implementation
   // In practice, you might want to track drawdowns over time
   
   // Get equity curve (simplified as close prices for this example)
   double close[];
   int count = m_lookbackPeriod;
   
   if (CopyClose(m_symbol, m_timeframe, 0, count, close) != count)
      return false;
      
   // Calculate drawdown
   double peak = close[0];
   double maxDD = 0.0;
   
   for (int i = 1; i < count; i++)
   {
      if (close[i] > peak)
      {
         peak = close[i];
      }
      else
      {
         double dd = (peak - close[i]) / peak;
         if (dd > maxDD)
            maxDD = dd;
      }
   }
   
   m_maxDrawdown = maxDD;
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate performance ratios                                     |
//+------------------------------------------------------------------+
bool CRiskMetrics::CalculateRatios()
{
   // This is a simplified implementation
   // In practice, you would use actual returns and risk-free rate
   
   // Get close prices
   double close[];
   int count = m_lookbackPeriod;
   
   if (CopyClose(m_symbol, m_timeframe, 0, count, close) != count)
      return false;
      
   // Calculate returns
   double returns[];
   ArrayResize(returns, count-1);
   
   for (int i = 0; i < count-1; i++)
   {
      if (close[i+1] > 0.0)
         returns[i] = (close[i] - close[i+1]) / close[i+1];
      else
         returns[i] = 0.0;
   }
   
   // Calculate mean return
   double sum = 0.0;
   for (int i = 0; i < ArraySize(returns); i++)
   {
      sum += returns[i];
   }
   double meanReturn = sum / ArraySize(returns);
   
   // Calculate standard deviation of returns
   double sumSq = 0.0;
   for (int i = 0; i < ArraySize(returns); i++)
   {
      double diff = returns[i] - meanReturn;
      sumSq += diff * diff;
   }
   double stdDev = MathSqrt(sumSq / (ArraySize(returns) - 1));
   
   // Risk-free rate (simplified as 0 for this example)
   double riskFreeRate = 0.0;
   
   // Calculate Sharpe ratio
   if (stdDev > 0.0)
      m_sharpeRatio = (meanReturn - riskFreeRate) / stdDev;
   else
      m_sharpeRatio = 0.0;
   
   // Calculate Sortino ratio (simplified, using downside deviation = stdDev)
   // In practice, you would calculate downside deviation separately
   if (stdDev > 0.0)
      m_sortinoRatio = (meanReturn - riskFreeRate) / stdDev;
   else
      m_sortinoRatio = 0.0;
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate stop loss in pips                                      |
//+------------------------------------------------------------------+
double CRiskMetrics::CalculateStopLossPips(const string symbol, const double price, 
                                         const double stopDistance, const bool isPips = true)
{
   if (stopDistance <= 0.0)
      return 0.0;
      
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if (point == 0.0 || tickSize == 0.0)
      return 0.0;
      
   if (isPips)
   {
      // Convert pips to price
      double pipValue = point * 10.0; // Assuming 5-digit broker
      return stopDistance * pipValue;
   }
   else
   {
      // Already in price terms
      return stopDistance;
   }
}

//+------------------------------------------------------------------+
//| Calculate position risk in account currency                      |
//+------------------------------------------------------------------+
double CRiskMetrics::CalculatePositionRisk(const double entryPrice, const double stopLoss, 
                                         const double positionSize, const string symbol)
{
   if (entryPrice <= 0.0 || positionSize <= 0.0)
      return 0.0;
      
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if (tickValue <= 0.0 || tickSize <= 0.0)
      return 0.0;
      
   double stopDistance = MathAbs(entryPrice - stopLoss);
   double riskPerLot = (stopDistance / tickSize) * tickValue;
   
   return riskPerLot * positionSize;
}

//+------------------------------------------------------------------+
//| Check if volatility is too high                                  |
//+------------------------------------------------------------------+
bool CRiskMetrics::IsVolatilityTooHigh(const double maxVolatility = 0.02) const
{
   return (m_volatility > maxVolatility);
}

//+------------------------------------------------------------------+
//| Check if drawdown limit is reached                               |
//+------------------------------------------------------------------+
bool CRiskMetrics::IsDrawdownLimitReached(const double maxDrawdownPercent) const
{
   return (m_maxDrawdown >= maxDrawdownPercent / 100.0);
}

//+------------------------------------------------------------------+
//| Calculate standard deviation                                     |
//+------------------------------------------------------------------+
double CRiskMetrics::CalculateStandardDeviation(const double &values[], const int count)
{
   if (count <= 1)
      return 0.0;
      
   double sum = 0.0;
   double sumSq = 0.0;
   
   for (int i = 0; i < count; i++)
   {
      sum += values[i];
      sumSq += values[i] * values[i];
   }
   
   double mean = sum / count;
   double variance = (sumSq / count) - (mean * mean);
   
   return MathSqrt(variance);
}

//+------------------------------------------------------------------+
//| Calculate correlation between two arrays                         |
//+------------------------------------------------------------------+
double CRiskMetrics::CalculateCorrelation(const double &x[], const double &y[], const int count)
{
   if (count <= 1)
      return 0.0;
      
   double sumX = 0.0, sumY = 0.0;
   double sumXSq = 0.0, sumYSq = 0.0;
   double sumXY = 0.0;
   
   for (int i = 0; i < count; i++)
   {
      sumX += x[i];
      sumY += y[i];
      sumXSq += x[i] * x[i];
      sumYSq += y[i] * y[i];
      sumXY += x[i] * y[i];
   }
   
   double numerator = sumXY - (sumX * sumY / count);
   double denominator = MathSqrt((sumXSq - (sumX * sumX / count)) * (sumYSq - (sumY * sumY / count)));
   
   if (denominator == 0.0)
      return 0.0;
      
   return numerator / denominator;
}
