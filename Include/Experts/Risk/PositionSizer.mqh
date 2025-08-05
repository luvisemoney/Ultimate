//+------------------------------------------------------------------+
//|                                              PositionSizer.mqh    |
//|                        Copyright 2025, Your Company Name          |
//|                                             https://www.yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company Name"
#property link      "https://www.yoursite.com"
#property version   "1.00"
#property strict

#include "RiskParameters.mqh"
#include "RiskMetrics.mqh"

//+------------------------------------------------------------------+
//| Position Sizer Class                                             |
//+------------------------------------------------------------------+
class CPositionSizer
{
private:
   CRiskParameters*   m_params;         // Risk parameters
   CRiskMetrics*      m_metrics;        // Risk metrics
   
   // Position sizing parameters
   double            m_volatilityFactor;  // Current volatility adjustment factor
   double            m_correlationFactor; // Correlation adjustment factor
   
   // State
   bool              m_isInitialized;    // Initialization flag
   
   // Private methods
   double            CalculateBasePositionSize(const string symbol, const double stopLossPips, 
                                             const double riskPercent, const double accountEquity);
   double            ApplyVolatilityAdjustment(const string symbol, const double size);
   double            ApplyCorrelationAdjustment(const string symbol, const double size);
   double            ApplyLeverageAdjustment(const double size);
   double            ApplyLotStepRounding(const string symbol, const double size);
   
public:
   // Constructor/Destructor
                     CPositionSizer();
                    ~CPositionSizer();
   
   // Initialization
   bool              Initialize(CRiskParameters* params = NULL, CRiskMetrics* metrics = NULL);
   void              Deinitialize();
   
   // Position sizing
   bool              CalculateSize(const string symbol, const double stopLossPips, 
                                 const double riskPercent, const double accountEquity, 
                                 double &size);
   
   // Update methods
   void              UpdateVolatility(const double volatility);
   void              UpdateCorrelation(const double correlation);
   
   // Getters
   double            GetVolatilityFactor() const { return m_volatilityFactor; }
   double            GetCorrelationFactor() const { return m_correlationFactor; }
   bool              IsInitialized() const { return m_isInitialized; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPositionSizer::CPositionSizer() : 
   m_params(NULL),
   m_metrics(NULL),
   m_volatilityFactor(1.0),
   m_correlationFactor(1.0),
   m_isInitialized(false)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CPositionSizer::~CPositionSizer()
{
   Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize position sizer                                        |
//+------------------------------------------------------------------+
bool CPositionSizer::Initialize(CRiskParameters* params = NULL, CRiskMetrics* metrics = NULL)
{
   m_params = params;
   m_metrics = metrics;
   m_volatilityFactor = 1.0;
   m_correlationFactor = 1.0;
   
   m_isInitialized = true;
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialize position sizer                                      |
//+------------------------------------------------------------------+
void CPositionSizer::Deinitialize()
{
   m_params = NULL;
   m_metrics = NULL;
   m_isInitialized = false;
}

//+------------------------------------------------------------------+
//| Calculate position size                                          |
//+------------------------------------------------------------------+
bool CPositionSizer::CalculateSize(const string symbol, const double stopLossPips, 
                                 const double riskPercent, const double accountEquity, 
                                 double &size)
{
   if (!m_isInitialized || stopLossPips <= 0.0 || riskPercent <= 0.0 || accountEquity <= 0.0)
      return false;
      
   // Calculate base position size based on risk percentage
   double baseSize = CalculateBasePositionSize(symbol, stopLossPips, riskPercent, accountEquity);
   if (baseSize <= 0.0)
      return false;
      
   // Apply adjustments
   double adjustedSize = baseSize;
   
   // Apply volatility adjustment if metrics are available
   if (m_metrics != NULL)
   {
      adjustedSize = ApplyVolatilityAdjustment(symbol, adjustedSize);
   }
   
   // Apply correlation adjustment if metrics are available
   if (m_metrics != NULL)
   {
      adjustedSize = ApplyCorrelationAdjustment(symbol, adjustedSize);
   }
   
   // Apply leverage adjustment
   adjustedSize = ApplyLeverageAdjustment(adjustedSize);
   
   // Apply lot step rounding
   adjustedSize = ApplyLotStepRounding(symbol, adjustedSize);
   
   // Ensure size is within allowed limits
   if (m_params != NULL)
   {
      adjustedSize = MathMin(adjustedSize, m_params.GetMaxLotsPerTrade());
      adjustedSize = MathMax(adjustedSize, m_params.GetMinPositionSize());
   }
   
   size = adjustedSize;
   return (size > 0.0);
}

//+------------------------------------------------------------------+
//| Calculate base position size based on risk percentage            |
//+------------------------------------------------------------------+
double CPositionSizer::CalculateBasePositionSize(const string symbol, const double stopLossPips, 
                                               const double riskPercent, const double accountEquity)
{
   // Get symbol information
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   if (tickSize <= 0.0 || tickValue <= 0.0 || lotSize <= 0.0 || point <= 0.0)
      return 0.0;
      
   // Calculate pip value (accounting for 5-digit brokers)
   double pipValue = point * 10.0;
   
   // Calculate value per pip
   double valuePerPip = (tickValue / tickSize) * pipValue;
   
   // Calculate risk amount in account currency
   double riskAmount = accountEquity * (riskPercent / 100.0);
   
   // Calculate position size in lots
   double stopLossValue = stopLossPips * valuePerPip;
   if (stopLossValue <= 0.0)
      return 0.0;
      
   double positionSize = riskAmount / stopLossValue;
   
   // Convert to lots
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if (lotStep > 0.0)
   {
      positionSize = MathFloor(positionSize / lotStep) * lotStep;
   }
   
   return positionSize;
}

//+------------------------------------------------------------------+
//| Apply volatility adjustment to position size                     |
//+------------------------------------------------------------------
double CPositionSizer::ApplyVolatilityAdjustment(const string symbol, const double size)
{
   if (m_metrics == NULL || !m_params.UseVolatility())
      return size;
      
   double currentVol = m_metrics.GetCurrentVolatility();
   double historicalVol = m_metrics.GetHistoricalVolatility();
   
   // If we don't have valid volatility data, return original size
   if (currentVol <= 0.0 || historicalVol <= 0.0)
      return size;
      
   // Calculate volatility ratio (current / historical)
   double volRatio = currentVol / historicalVol;
   
   // Apply inverse relationship: higher volatility = smaller position
   // Cap the adjustment to avoid extreme position sizing
   volRatio = MathMax(0.5, MathMin(2.0, 1.0 / volRatio));
   
   // Apply volatility factor from parameters
   if (m_params != NULL)
   {
      volRatio *= m_params.GetVolatilityFactor();
   }
   
   m_volatilityFactor = volRatio;
   return size * volRatio;
}

//+------------------------------------------------------------------+
//| Apply correlation adjustment to position size                    |
//+------------------------------------------------------------------
double CPositionSizer::ApplyCorrelationAdjustment(const string symbol, const double size)
{
   if (m_metrics == NULL || !m_params.UseCorrelation())
      return size;
      
   // This is a simplified implementation
   // In practice, you would check correlation with existing positions
   
   // For now, we'll just return the original size
   // A full implementation would use the correlation matrix
   
   return size;
}

//+------------------------------------------------------------------+
//| Apply leverage adjustment to position size                       |
//+------------------------------------------------------------------
double CPositionSizer::ApplyLeverageAdjustment(const double size)
{
   if (m_params == NULL)
      return size;
      
   double maxLeverage = m_params.GetMaxLeverage();
   double accountLeverage = (double)AccountInfoInteger(ACCOUNT_LEVERAGE);
   
   if (maxLeverage <= 0.0 || accountLeverage <= 0.0)
      return size;
      
   // Adjust position size based on leverage
   double leverageRatio = MathMin(1.0, maxLeverage / accountLeverage);
   return size * leverageRatio;
}

//+------------------------------------------------------------------+
//| Apply lot step rounding                                          |
//+------------------------------------------------------------------
double CPositionSizer::ApplyLotStepRounding(const string symbol, const double size)
{
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   
   if (lotStep <= 0.0)
      return size;
      
   // Round to nearest lot step
   double roundedSize = MathFloor(size / lotStep + 0.5) * lotStep;
   
   // Ensure within min/max limits
   if (minLot > 0.0)
      roundedSize = MathMax(roundedSize, minLot);
      
   if (maxLot > 0.0)
      roundedSize = MathMin(roundedSize, maxLot);
      
   return roundedSize;
}

//+------------------------------------------------------------------+
//| Update volatility factor                                         |
//+------------------------------------------------------------------
void CPositionSizer::UpdateVolatility(const double volatility)
{
   if (volatility > 0.0)
   {
      // Store the inverse of volatility (higher volatility = smaller position)
      m_volatilityFactor = 1.0 / (1.0 + volatility);
   }
}

//+------------------------------------------------------------------+
//| Update correlation factor                                        |
//+------------------------------------------------------------------
void CPositionSizer::UpdateCorrelation(const double correlation)
{
   // Store the inverse of correlation (higher correlation = smaller position)
   m_correlationFactor = 1.0 - (0.5 * correlation);
}
