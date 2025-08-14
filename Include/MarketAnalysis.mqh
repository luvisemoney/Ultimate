//+------------------------------------------------------------------+
//| MarketAnalysis.mqh - Market analysis utilities                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, OTC Escape EA"
#property link      "https://www.yoursite.com"
#property version   "1.00"
#property strict

#include <Indicators\Trend.mqh>
#include <Indicators\Oscilators.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Indicators\Indicators.mqh>

// Include the header that contains the CMarketAnalysis class declaration
#include "OTCTypes.mqh"

//+------------------------------------------------------------------+
//| CMarketAnalysis implementation                                   |
//+------------------------------------------------------------------+

//--- Constructor
CMarketAnalysis::CMarketAnalysis(int ma_fast_handle, int ma_slow_handle) : 
   m_ma_fast_handle(ma_fast_handle),
   m_ma_slow_handle(ma_slow_handle)
{
   // Constructor implementation - handles are managed by the EA
}

//--- Destructor
CMarketAnalysis::~CMarketAnalysis()
{
   // No need to release handles here as they are managed by the EA
}

//--- Get current market trend
ENUM_MA_TREND_STATE CMarketAnalysis::GetTrendState() const
{
   double local_ma_fast[3] = {0.0, 0.0, 0.0};
   double ma_slow[3] = {0.0, 0.0, 0.0};
   
   // Get MA values for the last 3 bars
   if(CopyBuffer(m_ma_fast_handle, 0, 0, 3, local_ma_fast) != 3 ||
      CopyBuffer(m_ma_slow_handle, 0, 0, 3, ma_slow) != 3)
   {
      return MA_TREND_NEUTRAL;
   }
   
   // Check for strong uptrend (both MAs rising and fast above slow)
   if(local_ma_fast[0] > ma_slow[0] && local_ma_fast[1] > ma_slow[1] && 
      local_ma_fast[0] > local_ma_fast[1] && ma_slow[0] > ma_slow[1])
   {
      return MA_TREND_UP;
   }
   
   // Check for strong downtrend (both MAs falling and fast below slow)
   if(local_ma_fast[0] < ma_slow[0] && local_ma_fast[1] < ma_slow[1] && 
      local_ma_fast[0] < local_ma_fast[1] && ma_slow[0] < ma_slow[1])
   {
      return MA_TREND_DOWN;
   }
   
   // Check for weak uptrend (fast above slow but not both rising)
   if(local_ma_fast[0] > ma_slow[0])
      return MA_TREND_UP;  // Treat weak uptrend as regular uptrend
      
   // Check for weak downtrend (fast below slow but not both falling)
   if(local_ma_fast[0] < ma_slow[0])
      return MA_TREND_DOWN;  // Treat weak downtrend as regular downtrend
      
   return MA_TREND_NEUTRAL;
}

//--- Get current market volatility (ATR based)
double CMarketAnalysis::GetVolatility(int period, int timeframe) const
{
   double atr[2] = {0.0, 0.0};
   
   int atr_handle = iATR(NULL, (ENUM_TIMEFRAMES)timeframe, period);
   if(atr_handle == INVALID_HANDLE)
      return 0.0;
      
   if(CopyBuffer(atr_handle, 0, 0, 2, atr) <= 0)
   {
      IndicatorRelease(atr_handle);
      return 0.0;
   }
   
   IndicatorRelease(atr_handle);
   return atr[0];
}

//--- Get trend strength (ADX based)
double CMarketAnalysis::GetTrendStrength(int period, int timeframe) const
{
   double adx[1] = {0.0};
   double plus_di[1] = {0.0};
   double minus_di[1] = {0.0};
   
   int adx_handle = iADX(NULL, (ENUM_TIMEFRAMES)timeframe, period);
   if(adx_handle == INVALID_HANDLE)
      return 0.0;
   
   if(CopyBuffer(adx_handle, 0, 0, 1, adx) != 1 ||
      CopyBuffer(adx_handle, 1, 0, 1, plus_di) != 1 ||
      CopyBuffer(adx_handle, 2, 0, 1, minus_di) != 1)
   {
      IndicatorRelease(adx_handle);
      return 0.0;
   }
   
   double strength = adx[0];
   double direction = plus_di[0] - minus_di[0];
   
   IndicatorRelease(adx_handle);
   return strength * (direction >= 0 ? 1 : -1);
}

//--- Validate trade setup based on current market conditions
bool CMarketAnalysis::ValidateTradeSetup(ENUM_ORDER_TYPE order_type, double entry_price, double sl, double tp) const
{
   if(sl <= 0 || tp <= 0)
      return false;
      
   double stop_distance = MathAbs(entry_price - sl);
   double take_distance = MathAbs(tp - entry_price);
   
   // Ensure stop loss and take profit are at reasonable distances
   if(stop_distance <= 0 || take_distance <= 0)
      return false;
      
   double ratio = take_distance / stop_distance;
   
   // Require at least 0.8:1 risk:reward ratio
   if(ratio < 0.8)
      return false;
      
   // Validate stop loss and take profit based on order type
   if(order_type == ORDER_TYPE_BUY)
   {
      if(sl >= entry_price || tp <= entry_price)
         return false;
   }
   else if(order_type == ORDER_TYPE_SELL)
   {
      if(sl <= entry_price || tp >= entry_price)
         return false;
   }
   else
   {
      // Invalid order type
      return false;
   }
   
   return true;
}
//+------------------------------------------------------------------+
