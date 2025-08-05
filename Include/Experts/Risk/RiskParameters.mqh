//+------------------------------------------------------------------+
//|                                              RiskParameters.mqh   |
//|                        Copyright 2025, Your Company Name          |
//|                                             https://www.yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company Name"
#property link      "https://www.yoursite.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Risk Parameters Class                                            |
//+------------------------------------------------------------------+
class CRiskParameters
{
private:
   // Risk parameters
   double            m_riskPerTrade;      // Risk per trade (% of equity)
   double            m_dailyLossLimit;     // Max daily loss (% of equity)
   double            m_maxPositionSize;    // Max position size (lots)
   double            m_maxLeverage;        // Maximum allowed leverage
   bool              m_useVolatility;      // Use volatility for position sizing
   bool              m_useCorrelation;     // Use correlation for risk calculation
   
   // Volatility parameters
   double            m_volatilityFactor;   // Volatility adjustment factor
   int               m_volatilityPeriod;   // Period for volatility calculation
   
   // Correlation parameters
   double            m_maxCorrelation;     // Maximum allowed correlation
   int               m_correlationPeriod;   // Period for correlation calculation
   
   // Position sizing parameters
   double            m_minPositionSize;    // Minimum position size (lots)
   double            m_maxLotsPerTrade;    // Maximum lots per trade
   
   // Internal state
   bool              m_isInitialized;      // Initialization flag
   
public:
   // Constructor/Destructor
                     CRiskParameters();
                    ~CRiskParameters() {}
   
   // Initialization
   bool              Initialize();
   
   // Getters
   double            GetRiskPerTrade() const { return m_riskPerTrade; }
   double            GetDailyLossLimit() const { return m_dailyLossLimit; }
   double            GetMaxPositionSize() const { return m_maxPositionSize; }
   double            GetMaxLeverage() const { return m_maxLeverage; }
   bool              UseVolatility() const { return m_useVolatility; }
   bool              UseCorrelation() const { return m_useCorrelation; }
   double            GetVolatilityFactor() const { return m_volatilityFactor; }
   int               GetVolatilityPeriod() const { return m_volatilityPeriod; }
   double            GetMaxCorrelation() const { return m_maxCorrelation; }
   int               GetCorrelationPeriod() const { return m_correlationPeriod; }
   double            GetMinPositionSize() const { return m_minPositionSize; }
   double            GetMaxLotsPerTrade() const { return m_maxLotsPerTrade; }
   
   // Setters with validation
   bool              SetRiskPerTrade(const double risk);
   bool              SetDailyLossLimit(const double limit);
   bool              SetMaxPositionSize(const double size);
   bool              SetMaxLeverage(const double leverage);
   void              SetUseVolatility(const bool use) { m_useVolatility = use; }
   void              SetUseCorrelation(const bool use) { m_useCorrelation = use; }
   bool              SetVolatilityFactor(const double factor);
   bool              SetVolatilityPeriod(const int period);
   bool              SetMaxCorrelation(const double correlation);
   bool              SetCorrelationPeriod(const int period);
   bool              SetMinPositionSize(const double size);
   bool              SetMaxLotsPerTrade(const double lots);
   
   // Validation
   static bool       IsValidRisk(const double risk);
   static bool       IsValidLeverage(const double leverage);
   static bool       IsValidPositionSize(const double size);
   static bool       IsValidCorrelation(const double correlation);
   
private:
   // Internal methods
   void              SetDefaults();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRiskParameters::CRiskParameters() :
   m_riskPerTrade(1.0),        // 1% risk per trade by default
   m_dailyLossLimit(5.0),      // 5% max daily loss by default
   m_maxPositionSize(100.0),   // 100 lots max position size by default
   m_maxLeverage(100.0),       // 1:100 leverage by default
   m_useVolatility(true),      // Use volatility by default
   m_useCorrelation(true),     // Use correlation by default
   m_volatilityFactor(1.0),    // No additional factor by default
   m_volatilityPeriod(20),     // 20-period lookback for volatility
   m_maxCorrelation(0.7),      // 70% max correlation
   m_correlationPeriod(100),   // 100-period lookback for correlation
   m_minPositionSize(0.01),    // 0.01 lots minimum
   m_maxLotsPerTrade(50.0),    // 50 lots maximum per trade
   m_isInitialized(false)
{
}

//+------------------------------------------------------------------+
//| Initialize with default values                                   |
//+------------------------------------------------------------------+
bool CRiskParameters::Initialize()
{
   SetDefaults();
   return true;
}

//+------------------------------------------------------------------+
//| Set default parameters                                           |
//+------------------------------------------------------------------+
void CRiskParameters::SetDefaults()
{
   // Load default values from account settings or config file
   m_riskPerTrade = 1.0;
   m_dailyLossLimit = 5.0;
   m_maxPositionSize = 100.0;
   m_maxLeverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
   
   // Advanced settings
   m_useVolatility = true;
   m_useCorrelation = true;
   m_volatilityFactor = 1.0;
   m_volatilityPeriod = 20;
   m_maxCorrelation = 0.7;
   m_correlationPeriod = 100;
   m_minPositionSize = 0.01;
   m_maxLotsPerTrade = 50.0;
   
   m_isInitialized = true;
}

//+------------------------------------------------------------------+
//| Set risk per trade with validation                               |
//+------------------------------------------------------------------+
bool CRiskParameters::SetRiskPerTrade(const double risk)
{
   if (!IsValidRisk(risk))
      return false;
      
   m_riskPerTrade = risk;
   return true;
}

//+------------------------------------------------------------------+
//| Set daily loss limit with validation                             |
//+------------------------------------------------------------------+
bool CRiskParameters::SetDailyLossLimit(const double limit)
{
   if (limit <= 0.0 || limit > 50.0) // Max 50% daily loss
      return false;
      
   m_dailyLossLimit = limit;
   return true;
}

//+------------------------------------------------------------------+
//| Set max position size with validation                            |
//+------------------------------------------------------------------+
bool CRiskParameters::SetMaxPositionSize(const double size)
{
   if (!IsValidPositionSize(size))
      return false;
      
   m_maxPositionSize = size;
   return true;
}

//+------------------------------------------------------------------+
//| Set max leverage with validation                                 |
//+------------------------------------------------------------------+
bool CRiskParameters::SetMaxLeverage(const double leverage)
{
   if (!IsValidLeverage(leverage))
      return false;
      
   m_maxLeverage = leverage;
   return true;
}

//+------------------------------------------------------------------+
//| Set volatility factor with validation                            |
//+------------------------------------------------------------------+
bool CRiskParameters::SetVolatilityFactor(const double factor)
{
   if (factor <= 0.0 || factor > 10.0) // Arbitrary upper limit
      return false;
      
   m_volatilityFactor = factor;
   return true;
}

//+------------------------------------------------------------------+
//| Set volatility period with validation                            |
//+------------------------------------------------------------------+
bool CRiskParameters::SetVolatilityPeriod(const int period)
{
   if (period < 5 || period > 200) // Reasonable range for volatility calculation
      return false;
      
   m_volatilityPeriod = period;
   return true;
}

//+------------------------------------------------------------------+
//| Set max correlation with validation                              |
//+------------------------------------------------------------------+
bool CRiskParameters::SetMaxCorrelation(const double correlation)
{
   if (!IsValidCorrelation(correlation))
      return false;
      
   m_maxCorrelation = correlation;
   return true;
}

//+------------------------------------------------------------------+
//| Set correlation period with validation                           |
//+------------------------------------------------------------------+
bool CRiskParameters::SetCorrelationPeriod(const int period)
{
   if (period < 10 || period > 500) // Reasonable range for correlation calculation
      return false;
      
   m_correlationPeriod = period;
   return true;
}

//+------------------------------------------------------------------+
//| Set min position size with validation                            |
//+------------------------------------------------------------------+
bool CRiskParameters::SetMinPositionSize(const double size)
{
   if (size <= 0.0 || size > m_maxLotsPerTrade)
      return false;
      
   m_minPositionSize = size;
   return true;
}

//+------------------------------------------------------------------+
//| Set max lots per trade with validation                           |
//+------------------------------------------------------------------+
bool CRiskParameters::SetMaxLotsPerTrade(const double lots)
{
   if (lots < m_minPositionSize || lots > 1000.0) // Arbitrary upper limit
      return false;
      
   m_maxLotsPerTrade = lots;
   return true;
}

//+------------------------------------------------------------------+
//| Validate risk percentage                                         |
//+------------------------------------------------------------------+
bool CRiskParameters::IsValidRisk(const double risk)
{
   return (risk > 0.0 && risk <= 10.0); // Max 10% risk per trade
}

//+------------------------------------------------------------------+
//| Validate leverage                                                |
//+------------------------------------------------------------------+
bool CRiskParameters::IsValidLeverage(const double leverage)
{
   return (leverage > 0.0 && leverage <= 1000.0); // Reasonable leverage range
}

//+------------------------------------------------------------------+
//| Validate position size                                           |
//+------------------------------------------------------------------+
bool CRiskParameters::IsValidPositionSize(const double size)
{
   return (size > 0.0 && size <= 1000.0); // Reasonable position size range
}

//+------------------------------------------------------------------+
//| Validate correlation value                                       |
//+------------------------------------------------------------------+
bool CRiskParameters::IsValidCorrelation(const double correlation)
{
   return (correlation >= 0.0 && correlation <= 1.0); // 0.0 to 1.0 range
}
