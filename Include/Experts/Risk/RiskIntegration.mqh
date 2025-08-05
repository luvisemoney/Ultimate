//+------------------------------------------------------------------+
//|                                          RiskIntegration.mqh      |
//|                        Copyright 2025, Your Company Name          |
//|                                             https://www.yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company Name"
#property link      "https://www.yoursite.com"
#property version   "1.00"
#property strict

// Include all risk management components
#include "RiskParameters.mqh"
#include "RiskMetrics.mqh"
#include "PositionSizer.mqh"
#include "DrawdownManager.mqh"
#include "CorrelationMatrix.mqh"

//+------------------------------------------------------------------+
//| Risk Integration Class                                           |
//+------------------------------------------------------------------+
class CRiskIntegration
{
private:
   // Component instances
   CRiskParameters*   m_riskParams;     // Risk parameters
   CRiskMetrics*      m_riskMetrics;    // Risk metrics calculator
   CPositionSizer*    m_positionSizer;  // Position sizing
   CDrawdownManager*  m_drawdownMgr;    // Drawdown management
   CCorrelationMatrix* m_corrMatrix;    // Correlation analysis
   
   // State
   bool              m_isInitialized;   // Initialization flag
   double            m_accountEquity;   // Current account equity
   
   // Private methods
   bool              InitializeComponents();
   void              UpdateAccountInfo();
   
public:
   // Constructor/Destructor
                     CRiskIntegration();
                    ~CRiskIntegration();
   
   // Initialization
   bool              Initialize();
   void              Deinitialize();
   void              Update();
   
   // Risk assessment
   bool              CanOpenPosition(const string symbol, const ENUM_ORDER_TYPE type,
                                   const double price, const double stopLoss, 
                                   const double takeProfit, double &suggestedSize);
   
   // Position management
   bool              ValidatePositionSize(const string symbol, const double size);
   bool              UpdatePositionMetrics(const string symbol, const double size, 
                                         const double openPrice, const double currentPrice);
   
   // Getters
   bool              IsInitialized() const { return m_isInitialized; }
   double            GetAccountEquity() const { return m_accountEquity; }
   double            GetMaxPositionSize() const;
   
   // Component access
   CRiskParameters*  GetRiskParameters() { return m_riskParams; }
   CRiskMetrics*     GetRiskMetrics() { return m_riskMetrics; }
   CPositionSizer*   GetPositionSizer() { return m_positionSizer; }
   CDrawdownManager* GetDrawdownManager() { return m_drawdownMgr; }
   CCorrelationMatrix* GetCorrelationMatrix() { return m_corrMatrix; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRiskIntegration::CRiskIntegration() :
   m_riskParams(NULL),
   m_riskMetrics(NULL),
   m_positionSizer(NULL),
   m_drawdownMgr(NULL),
   m_corrMatrix(NULL),
   m_isInitialized(false),
   m_accountEquity(0.0)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CRiskIntegration::~CRiskIntegration()
{
   Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize risk integration                                      |
//+------------------------------------------------------------------+
bool CRiskIntegration::Initialize()
{
   if (m_isInitialized)
      return true;
      
   // Create components
   m_riskParams = new CRiskParameters();
   if (m_riskParams == NULL || !m_riskParams.Initialize())
   {
      Print("Failed to initialize risk parameters");
      return false;
   }
   
   m_riskMetrics = new CRiskMetrics();
   if (m_riskMetrics == NULL || !m_riskMetrics.Initialize())
   {
      Print("Failed to initialize risk metrics");
      return false;
   }
   
   m_positionSizer = new CPositionSizer();
   if (m_positionSizer == NULL || !m_positionSizer.Initialize(m_riskParams, m_riskMetrics))
   {
      Print("Failed to initialize position sizer");
      return false;
   }
   
   m_drawdownMgr = new CDrawdownManager();
   if (m_drawdownMgr == NULL || !m_drawdownMgr.Initialize())
   {
      Print("Failed to initialize drawdown manager");
      return false;
   }
   
   m_corrMatrix = new CCorrelationMatrix();
   if (m_corrMatrix == NULL || !m_corrMatrix.Initialize())
   {
      Print("Failed to initialize correlation matrix");
      return false;
   }
   
   // Update account information
   UpdateAccountInfo();
   
   m_isInitialized = true;
   Print("Risk integration initialized successfully");
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialize risk integration                                    |
//+------------------------------------------------------------------+
void CRiskIntegration::Deinitialize()
{
   if (m_corrMatrix != NULL)
   {
      m_corrMatrix.Deinitialize();
      delete m_corrMatrix;
      m_corrMatrix = NULL;
   }
   
   if (m_drawdownMgr != NULL)
   {
      m_drawdownMgr.Deinitialize();
      delete m_drawdownMgr;
      m_drawdownMgr = NULL;
   }
   
   if (m_positionSizer != NULL)
   {
      m_positionSizer.Deinitialize();
      delete m_positionSizer;
      m_positionSizer = NULL;
   }
   
   if (m_riskMetrics != NULL)
   {
      m_riskMetrics.Deinitialize();
      delete m_riskMetrics;
      m_riskMetrics = NULL;
   }
   
   if (m_riskParams != NULL)
   {
      delete m_riskParams;
      m_riskParams = NULL;
   }
   
   m_isInitialized = false;
}

//+------------------------------------------------------------------+
//| Update risk metrics and state                                    |
//+------------------------------------------------------------------+
void CRiskIntegration::Update()
{
   if (!m_isInitialized)
      return;
      
   // Update account information
   UpdateAccountInfo();
   
   // Update drawdown manager
   if (m_drawdownMgr != NULL)
   {
      m_drawdownMgr.UpdateEquity(m_accountEquity);
   }
   
   // Update correlation matrix periodically
   static datetime lastCorrelationUpdate = 0;
   if (TimeCurrent() - lastCorrelationUpdate >= 3600) // Update hourly
   {
      if (m_corrMatrix != NULL)
      {
         m_corrMatrix.Update();
      }
      lastCorrelationUpdate = TimeCurrent();
   }
   
   // Update risk metrics
   if (m_riskMetrics != NULL)
   {
      m_riskMetrics.Update();
   }
}

//+------------------------------------------------------------------+
//| Check if a position can be opened with the given parameters      |
//+------------------------------------------------------------------+
bool CRiskIntegration::CanOpenPosition(const string symbol, const ENUM_ORDER_TYPE type,
                                     const double price, const double stopLoss, 
                                     const double takeProfit, double &suggestedSize)
{
   if (!m_isInitialized || symbol == "")
      return false;
      
   // Check if we're in a drawdown that exceeds limits
   if (m_drawdownMgr != NULL && m_riskParams != NULL)
   {
      if (m_drawdownMgr.IsDrawdownLimitReached(m_riskParams.GetMaxDrawdownPct()))
      {
         Print("Cannot open position: Maximum drawdown limit reached");
         return false;
      }
      
      if (m_drawdownMgr.IsDailyLossLimitReached(m_riskParams.GetMaxDailyLossPct()))
      {
         Print("Cannot open position: Daily loss limit reached");
         return false;
      }
   }
   
   // Calculate stop loss in pips
   double stopLossPips = 0.0;
   if (stopLoss > 0.0)
   {
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      
      if (point > 0.0 && tickSize > 0.0)
      {
         if (type == ORDER_TYPE_BUY)
            stopLossPips = (price - stopLoss) / (point * 10.0);
         else
            stopLossPips = (stopLoss - price) / (point * 10.0);
            
         stopLossPips = MathMax(1.0, stopLossPips); // Ensure at least 1 pip
      }
   }
   
   // Get position size
   double riskPercent = (m_riskParams != NULL) ? m_riskParams.GetRiskPerTrade() : 1.0;
   double size = 0.0;
   
   if (m_positionSizer != NULL)
   {
      if (!m_positionSizer.CalculateSize(symbol, stopLossPips, riskPercent, m_accountEquity, size))
      {
         Print("Failed to calculate position size");
         return false;
      }
   }
   
   // Check correlation with existing positions
   if (m_corrMatrix != NULL && m_riskParams != NULL)
   {
      if (!m_corrMatrix.ValidateNewPosition(symbol, type, price, size))
      {
         Print("Cannot open position: Correlation limit exceeded");
         return false;
      }
   }
   
   // Check if size is within allowed limits
   if (!ValidatePositionSize(symbol, size))
   {
      return false;
   }
   
   suggestedSize = size;
   return true;
}

//+------------------------------------------------------------------+
//| Validate if position size is within allowed limits               |
//+------------------------------------------------------------------+
bool CRiskIntegration::ValidatePositionSize(const string symbol, const double size)
{
   if (!m_isInitialized || symbol == "" || size <= 0.0)
      return false;
      
   // Check minimum position size
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   if (size < minLot)
   {
      PrintFormat("Position size (%.2f) is below minimum (%.2f)", size, minLot);
      return false;
   }
   
   // Check maximum position size
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   if (maxLot > 0.0 && size > maxLot)
   {
      PrintFormat("Position size (%.2f) exceeds maximum (%.2f)", size, maxLot);
      return false;
   }
   
   // Check against risk parameters
   if (m_riskParams != NULL)
   {
      double maxLotsPerTrade = m_riskParams.GetMaxLotsPerTrade();
      if (maxLotsPerTrade > 0.0 && size > maxLotsPerTrade)
      {
         PrintFormat("Position size (%.2f) exceeds maximum per trade (%.2f)", size, maxLotsPerTrade);
         return false;
      }
      
      double maxRiskPerTrade = m_riskParams.GetMaxRiskPerTrade();
      if (maxRiskPerTrade > 0.0)
      {
         double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
         double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         
         if (tickValue > 0.0 && tickSize > 0.0 && point > 0.0)
         {
            double riskAmount = size * (tickValue / tickSize) * point * 10.0; // Risk per pip
            double maxRiskAmount = m_accountEquity * (maxRiskPerTrade / 100.0);
            
            if (riskAmount > maxRiskAmount)
            {
               PrintFormat("Position risk (%.2f) exceeds maximum risk per trade (%.2f)", 
                          riskAmount, maxRiskAmount);
               return false;
            }
         }
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Update position metrics                                          |
//+------------------------------------------------------------------+
bool CRiskIntegration::UpdatePositionMetrics(const string symbol, const double size, 
                                           const double openPrice, const double currentPrice)
{
   if (!m_isInitialized || symbol == "" || size <= 0.0 || openPrice <= 0.0)
      return false;
      
   // Update risk metrics with the new position
   if (m_riskMetrics != NULL)
   {
      // This is a simplified example - in practice, you would update all relevant metrics
      double pips = (currentPrice - openPrice) / (SymbolInfoDouble(symbol, SYMBOL_POINT) * 10.0);
      m_riskMetrics.UpdateTradeMetrics(pips > 0, MathAbs(pips));
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Get maximum allowed position size based on risk parameters       |
//+------------------------------------------------------------------
double CRiskIntegration::GetMaxPositionSize()
{
   if (!m_isInitialized || m_riskParams == NULL)
      return 0.0;
      
   return m_riskParams.GetMaxLotsPerTrade();
}

//+------------------------------------------------------------------+
//| Update account information                                       |
//+------------------------------------------------------------------+
void CRiskIntegration::UpdateAccountInfo()
{
   m_accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Update risk metrics with new equity
   if (m_riskMetrics != NULL)
   {
      m_riskMetrics.UpdateEquity(m_accountEquity);
   }
}
