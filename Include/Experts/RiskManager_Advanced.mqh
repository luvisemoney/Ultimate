//+------------------------------------------------------------------+
//|                                          RiskManager_Advanced.mqh |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

// Include the base RiskManager class
#include "RiskManager.mqh"

//+------------------------------------------------------------------+
//| Calculate correlation-adjusted position size                     |
//+------------------------------------------------------------------+
double CRiskManager::CalculateCorrelationAdjustedSize(double baseLots, string symbol1, string symbol2, ENUM_TIMEFRAMES timeframe, int period)
{
   if(baseLots <= 0 || symbol1 == "" || symbol2 == "" || period <= 0)
      return baseLots;
      
   // Get correlation between the two symbols
   double correlation = CalculateCorrelationIndex(symbol1, symbol2, timeframe, period);
   
   // Convert correlation from -100..100 to 0..1 range
   double correlationFactor = (correlation + 100.0) / 200.0;
   
   // Adjust position size based on correlation
   // Higher correlation = smaller position size to reduce risk
   double adjustedLots = baseLots * (1.0 - (correlationFactor * 0.5));
   
   // Ensure we don't go below minimum lot size
   double minLot = SymbolInfoDouble(symbol1, SYMBOL_VOLUME_MIN);
   return MathMax(adjustedLots, minLot);
}

//+------------------------------------------------------------------+
//| Calculate regime-adjusted position size                          |
//+------------------------------------------------------------------+
double CRiskManager::CalculateRegimeAdjustedSize(double baseLots, ENUM_MARKET_REGIME regime)
{
   if(baseLots <= 0)
      return 0.0;
      
   double adjustedLots = baseLots;
   
   switch(regime)
   {
      case REGIME_TRENDING_UP:
      case REGIME_TRENDING_DOWN:
         // Increase position size in strong trends
         adjustedLots *= 1.2;
         break;
         
      case REGIME_RANGING:
         // Reduce position size in ranging markets
         adjustedLots *= 0.7;
         break;
         
      case REGIME_VOLATILE:
         // Reduce position size in high volatility
         adjustedLots *= 0.6;
         break;
         
      case REGIME_LOW_VOLATILITY:
         // Slightly reduce position size in low volatility
         adjustedLots *= 0.9;
         break;
         
      default:
         break;
   }
   
   // Ensure we don't exceed maximum position size
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   return MathMin(adjustedLots, maxLot);
}

//+------------------------------------------------------------------+
//| Calculate ML-adjusted position size                              |
//+------------------------------------------------------------------+
double CRiskManager::CalculateMLAdjustedSize(double baseLots, double mlConfidence)
{
   if(baseLots <= 0)
      return 0.0;
      
   // Ensure confidence is in valid range (0-1)
   mlConfidence = MathMax(0.0, MathMin(1.0, mlConfidence));
   
   // Calculate position size adjustment based on confidence
   // Higher confidence = larger position size (up to 2x)
   // Lower confidence = smaller position size (down to 0.1x)
   double adjustmentFactor = 0.1 + (mlConfidence * 1.9);
   
   // Apply adjustment
   double adjustedLots = baseLots * adjustmentFactor;
   
   // Ensure we don't exceed maximum position size
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   return MathMin(adjustedLots, maxLot);
}

//+------------------------------------------------------------------+
//| Calculate correlation index between two symbols                  |
//+------------------------------------------------------------------+
double CRiskManager::CalculateCorrelationIndex(string symbol1, string symbol2, ENUM_TIMEFRAMES timeframe, int period)
{
   if(period <= 0)
      return 0.0;
      
   // Get close prices for both symbols
   double closes1[], closes2[];
   ArraySetAsSeries(closes1, true);
   ArraySetAsSeries(closes2, true);
   
   int copied1 = CopyClose(symbol1, timeframe, 0, period, closes1);
   int copied2 = CopyClose(symbol2, timeframe, 0, period, closes2);
   
   if(copied1 != period || copied2 != period || copied1 != copied2)
      return 0.0;
      
   // Calculate correlation coefficient (Pearson's r)
   double sum1 = 0, sum2 = 0, sum1Sq = 0, sum2Sq = 0, sumProd = 0;
   
   for(int i = 0; i < period; i++)
   {
      sum1 += closes1[i];
      sum2 += closes2[i];
      sum1Sq += closes1[i] * closes1[i];
      sum2Sq += closes2[i] * closes2[i];
      sumProd += closes1[i] * closes2[i];
   }
   
   double numerator = sumProd - (sum1 * sum2 / period);
   double denominator = MathSqrt((sum1Sq - (sum1 * sum1 / period)) * (sum2Sq - (sum2 * sum2 / period)));
   
   if(denominator == 0)
      return 0.0;
      
   double correlation = numerator / denominator;
   
   // Convert to -100..100 range
   return correlation * 100.0;
}

//+------------------------------------------------------------------+
//| Calculate volatility index                                       |
//+------------------------------------------------------------------+
double CRiskManager::CalculateVolatilityIndex(int period = 14)
{
   if(m_symbol == NULL || period <= 0)
      return 0.0;
      
   // Calculate ATR as percentage of price
   double atr = m_atr != NULL ? m_atr.Main(0) : 0;
   double price = m_symbol.Ask();
   
   if(price <= 0)
      return 0.0;
      
   double atrPercent = (atr / price) * 100.0;
   
   // Convert to 0-100 scale (adjust these thresholds based on your needs)
   const double MIN_ATR = 0.2;  // 0.2%
   const double MAX_ATR = 2.0;  // 2.0%
   
   double volatilityIndex = 100.0 * (atrPercent - MIN_ATR) / (MAX_ATR - MIN_ATR);
   
   // Ensure within bounds
   return MathMax(0.0, MathMin(100.0, volatilityIndex));
}

//+------------------------------------------------------------------+
//| Calculate trend strength                                         |
//+------------------------------------------------------------------+
double CRiskManager::CalculateTrendStrength(int period = 20)
{
   if(m_symbol == NULL || period <= 0)
      return 0.0;
      
   // Simple implementation using ADX
   int adxHandle = iADX(m_symbol.Name(), PERIOD_CURRENT, period);
   if(adxHandle == INVALID_HANDLE)
      return 0.0;
      
   double adx[];
   ArraySetAsSeries(adx, true);
   
   if(CopyBuffer(adxHandle, 0, 0, 1, adx) != 1)
   {
      IndicatorRelease(adxHandle);
      return 0.0;
   }
   
   IndicatorRelease(adxHandle);
   
   // ADX is already on a 0-100 scale
   return adx[0];
}

//+------------------------------------------------------------------+
//| Save risk manager state to file                                  |
//+------------------------------------------------------------------+
void CRiskManager::SaveState()
{
   int handle = FileOpen("RiskManagerState.dat", FILE_WRITE|FILE_BIN);
   if(handle != INVALID_HANDLE)
   {
      // Save basic risk parameters
      FileWriteDouble(handle, m_riskPerTrade);
      FileWriteDouble(handle, m_maxLeverage);
      FileWriteInteger(handle, m_maxOpenTrades);
      FileWriteDouble(handle, m_dailyLossLimit);
      FileWriteDouble(handle, m_maxPortfolioRisk);
      FileWriteDouble(handle, m_maxDrawdown);
      
      // Save advanced risk metrics
      FileWriteDouble(handle, m_riskOfRuin);
      FileWriteDouble(handle, m_sharpeRatio);
      FileWriteDouble(handle, m_sortinoRatio);
      FileWriteDouble(handle, m_valueAtRisk);
      FileWriteDouble(handle, m_expectedShortfall);
      FileWriteDouble(handle, m_maxAdverseExcursion);
      FileWriteDouble(handle, m_winLossRatio);
      FileWriteDouble(handle, m_profitFactor);
      FileWriteDouble(handle, m_recoveryFactor);
      FileWriteInteger(handle, m_consecutiveLosses);
      FileWriteInteger(handle, m_consecutiveWins);
      FileWriteDouble(handle, m_avgWin);
      FileWriteDouble(handle, m_avgLoss);
      FileWriteInteger(handle, m_totalTrades);
      FileWriteDouble(handle, m_winRate);
      
      // Save market regime info
      FileWriteInteger(handle, (int)m_marketRegime);
      FileWriteDouble(handle, m_volatilityIndex);
      FileWriteDouble(handle, m_trendStrength);
      FileWriteDouble(handle, m_correlationIndex);
      
      FileClose(handle);
   }
}

//+------------------------------------------------------------------+
//| Load risk manager state from file                                |
//+------------------------------------------------------------------+
bool CRiskManager::LoadState()
{
   int handle = FileOpen("RiskManagerState.dat", FILE_READ|FILE_BIN);
   if(handle != INVALID_HANDLE)
   {
      // Load basic risk parameters
      m_riskPerTrade = FileReadDouble(handle);
      m_maxLeverage = FileReadDouble(handle);
      m_maxOpenTrades = (int)FileReadInteger(handle);
      m_dailyLossLimit = FileReadDouble(handle);
      m_maxPortfolioRisk = FileReadDouble(handle);
      m_maxDrawdown = FileReadDouble(handle);
      
      // Load advanced risk metrics
      m_riskOfRuin = FileReadDouble(handle);
      m_sharpeRatio = FileReadDouble(handle);
      m_sortinoRatio = FileReadDouble(handle);
      m_valueAtRisk = FileReadDouble(handle);
      m_expectedShortfall = FileReadDouble(handle);
      m_maxAdverseExcursion = FileReadDouble(handle);
      m_winLossRatio = FileReadDouble(handle);
      m_profitFactor = FileReadDouble(handle);
      m_recoveryFactor = FileReadDouble(handle);
      m_consecutiveLosses = (int)FileReadInteger(handle);
      m_consecutiveWins = (int)FileReadInteger(handle);
      m_avgWin = FileReadDouble(handle);
      m_avgLoss = FileReadDouble(handle);
      m_totalTrades = (int)FileReadInteger(handle);
      m_winRate = FileReadDouble(handle);
      
      // Load market regime info
      m_marketRegime = (ENUM_MARKET_REGIME)FileReadInteger(handle);
      m_volatilityIndex = FileReadDouble(handle);
      m_trendStrength = FileReadDouble(handle);
      m_correlationIndex = FileReadDouble(handle);
      
      FileClose(handle);
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Trigger recovery mode                                            |
//+------------------------------------------------------------------+
void CRiskManager::TriggerRecovery()
{
   // Set risk state to recovery
   m_riskState = RISK_STATE_RECOVERY;
   
   // Log the recovery trigger
   Print("RiskManager: Recovery mode triggered. Risk state set to RECOVERY.");
   
   // Implement any additional recovery logic here
   // For example, you might want to close some positions, reduce position sizes, etc.
   
   // Save the current state
   SaveState();
}

//+------------------------------------------------------------------+
