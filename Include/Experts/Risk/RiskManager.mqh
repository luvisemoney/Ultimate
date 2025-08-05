//+------------------------------------------------------------------+
//|                                                RiskManager.mqh    |
//|                        Copyright 2025, Your Company Name          |
//|                                             https://www.yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company Name"
#property link      "https://www.yoursite.com"
#property version   "1.00"
#property strict

#include "RiskParameters.mqh"
#include "RiskMetrics.mqh"
#include "PositionSizer.mqh"
#include "DrawdownManager.mqh"
#include "CorrelationMatrix.mqh"

//+------------------------------------------------------------------+
//| Risk Manager Class                                               |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
   // Components
   CRiskParameters*   m_params;        // Risk parameters
   CRiskMetrics*      m_metrics;       // Risk metrics calculator
   CPositionSizer*    m_sizer;         // Position sizer
   CDrawdownManager*  m_drawdownMgr;   // Drawdown manager
   CCorrelationMatrix*m_corrMatrix;    // Correlation matrix
   
   // State
   bool              m_isInitialized;  // Initialization flag
   double            m_accountEquity;  // Current account equity
   double            m_maxRiskPerTrade; // Max risk per trade (% of equity)
   double            m_maxDailyLoss;   // Max daily loss (% of equity)
   
   // Private methods
   bool              CalculatePositionSize(const string symbol, const double stopLossPips, double &size);
   bool              CheckCorrelation(const string symbol1, const string symbol2, double &correlation);
   
public:
   // Constructor/Destructor
                     CRiskManager();
                    ~CRiskManager();
   
   // Initialization
   bool              Initialize(const string symbol = NULL, const ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   void              Deinitialize();
   
   // Risk Assessment
   bool              IsTradeAllowed(const string symbol, const ENUM_ORDER_TYPE type, 
                                   const double price, const double stopLoss, const double takeProfit);
   double            GetMaxPositionSize(const string symbol, const double stopLossPips);
   
   // State Management
   void              UpdateAccountInfo();
   void              UpdateMarketConditions();
   
   // Getters
   bool              IsInitialized() const { return m_isInitialized; }
   double            GetAccountEquity() const { return m_accountEquity; }
   double            GetMaxRiskPerTrade() const { return m_maxRiskPerTrade; }
   
   // Configuration
   bool              SetRiskParameters(const double riskPerTrade, const double dailyLossLimit);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager() : 
   m_params(NULL),
   m_metrics(NULL),
   m_sizer(NULL),
   m_drawdownMgr(NULL),
   m_corrMatrix(NULL),
   m_isInitialized(false),
   m_accountEquity(0.0),
   m_maxRiskPerTrade(1.0),  // Default 1% risk per trade
   m_maxDailyLoss(5.0)      // Default 5% max daily loss
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CRiskManager::~CRiskManager()
{
   Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize risk manager                                          |
//+------------------------------------------------------------------+
bool CRiskManager::Initialize(const string symbol = NULL, const ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
{
   if (m_isInitialized)
      return true;
      
   // Initialize components
   m_params = new CRiskParameters();
   m_metrics = new CRiskMetrics();
   m_sizer = new CPositionSizer();
   m_drawdownMgr = new CDrawdownManager();
   m_corrMatrix = new CCorrelationMatrix();
   
   // Initialize components
   if (!m_params.Initialize() ||
       !m_metrics.Initialize(symbol, timeframe) ||
       !m_sizer.Initialize() ||
       !m_drawdownMgr.Initialize() ||
       !m_corrMatrix.Initialize())
   {
      Print("Failed to initialize risk manager components");
      return false;
   }
   
   // Update account info
   UpdateAccountInfo();
   
   m_isInitialized = true;
   Print("Risk Manager initialized successfully");
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialize risk manager                                        |
//+------------------------------------------------------------------+
void CRiskManager::Deinitialize()
{
   // Clean up components
   if (m_params != NULL)
   {
      delete m_params;
      m_params = NULL;
   }
   
   if (m_metrics != NULL)
   {
      m_metrics.Deinitialize();
      delete m_metrics;
      m_metrics = NULL;
   }
   
   if (m_sizer != NULL)
   {
      m_sizer.Deinitialize();
      delete m_sizer;
      m_sizer = NULL;
   }
   
   if (m_drawdownMgr != NULL)
   {
      m_drawdownMgr.Deinitialize();
      delete m_drawdownMgr;
      m_drawdownMgr = NULL;
   }
   
   if (m_corrMatrix != NULL)
   {
      m_corrMatrix.Deinitialize();
      delete m_corrMatrix;
      m_corrMatrix = NULL;
   }
   
   m_isInitialized = false;
}

//+------------------------------------------------------------------+
//| Check if trade is allowed based on risk parameters               |
//+------------------------------------------------------------------+
bool CRiskManager::IsTradeAllowed(const string symbol, const ENUM_ORDER_TYPE type, 
                                 const double price, const double stopLoss, const double takeProfit)
{
   if (!m_isInitialized)
      return false;
      
   // Check daily loss limit
   if (m_drawdownMgr.GetDailyDrawdownPercent() >= m_maxDailyLoss)
   {
      Print("Trade rejected: Daily loss limit reached");
      return false;
   }
   
   // Check maximum position size
   double maxSize = GetMaxPositionSize(symbol, stopLoss);
   if (maxSize <= 0.0)
   {
      Print("Trade rejected: Invalid position size");
      return false;
   }
   
   // Check correlation with existing positions
   if (!m_corrMatrix.ValidateNewPosition(symbol, type, price, stopLoss, maxSize))
   {
      Print("Trade rejected: Correlation check failed");
      return false;
   }
   
   // Additional risk checks can be added here
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate maximum position size based on risk parameters          |
//+------------------------------------------------------------------+
double CRiskManager::GetMaxPositionSize(const string symbol, const double stopLossPips)
{
   if (!m_isInitialized || stopLossPips <= 0.0)
      return 0.0;
      
   double size = 0.0;
   if (!m_sizer.CalculateSize(symbol, stopLossPips, m_maxRiskPerTrade, m_accountEquity, size))
      return 0.0;
      
   return size;
}

//+------------------------------------------------------------------+
//| Update account information                                       |
//+------------------------------------------------------------------+
void CRiskManager::UpdateAccountInfo()
{
   m_accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Update drawdown manager
   if (m_drawdownMgr != NULL)
      m_drawdownMgr.UpdateEquity(m_accountEquity);
}

//+------------------------------------------------------------------+
//| Update market conditions                                         |
//+------------------------------------------------------------------+
void CRiskManager::UpdateMarketConditions()
{
   if (!m_isInitialized)
      return;
      
   // Update volatility metrics
   m_metrics.UpdateVolatility();
   
   // Update correlation matrix
   m_corrMatrix.Update();
   
   // Update position sizer with latest market conditions
   double volatility = m_metrics.GetCurrentVolatility();
   m_sizer.UpdateVolatility(volatility);
}

//+------------------------------------------------------------------+
//| Set risk parameters                                              |
//+------------------------------------------------------------------+
bool CRiskManager::SetRiskParameters(const double riskPerTrade, const double dailyLossLimit)
{
   if (riskPerTrade <= 0.0 || riskPerTrade > 10.0) // Max 10% risk per trade
      return false;
      
   if (dailyLossLimit <= 0.0 || dailyLossLimit > 50.0) // Max 50% daily loss
      return false;
      
   m_maxRiskPerTrade = riskPerTrade;
   m_maxDailyLoss = dailyLossLimit;
   
   return true;
}
