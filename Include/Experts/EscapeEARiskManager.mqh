//+------------------------------------------------------------------+
//|                                      EscapeEARiskManager.mqh      |
//|                        Copyright 2025, Your Company Name          |
//|                                             https://www.yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company Name"
#property link      "https://www.yoursite.com"
#property version   "1.00"
#property strict

#include "Risk/RiskIntegration.mqh"

//+------------------------------------------------------------------+
//| Risk Manager for EscapeEA                                        |
//+------------------------------------------------------------------+
class CEscapeEARiskManager
{
private:
   static CEscapeEARiskManager* m_instance;  // Singleton instance
   CRiskIntegration*            m_riskIntegration; // Risk management system
   
   // Private constructor for singleton
                     CEscapeEARiskManager();
   
public:
   // Destructor
                    ~CEscapeEARiskManager();
   
   // Singleton access
   static CEscapeEARiskManager* Instance();
   
   // Initialization
   bool              Initialize();
   void              Deinitialize();
   void              Update();
   
   // Position management
   bool              CanOpenPosition(const string symbol, const ENUM_ORDER_TYPE type,
                                   const double price, const double stopLoss, 
                                   const double takeProfit, double &suggestedSize);
   
   bool              ValidatePositionSize(const string symbol, const double size);
   bool              UpdatePositionMetrics(const string symbol, const double size, 
                                         const double openPrice, const double currentPrice);
   
   // Getters
   bool              IsInitialized() const;
   double            GetAccountEquity() const;
   double            GetMaxPositionSize() const;
   
   // Component access
   CRiskParameters*  GetRiskParameters();
   CRiskMetrics*     GetRiskMetrics();
   CPositionSizer*   GetPositionSizer();
   CDrawdownManager* GetDrawdownManager();
   CCorrelationMatrix* GetCorrelationMatrix();
};

// Initialize static member
CEscapeEARiskManager* CEscapeEARiskManager::m_instance = NULL;

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CEscapeEARiskManager::CEscapeEARiskManager() :
   m_riskIntegration(NULL)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CEscapeEARiskManager::~CEscapeEARiskManager()
{
   Deinitialize();
}

//+------------------------------------------------------------------+
//| Get singleton instance                                           |
//+------------------------------------------------------------------+
CEscapeEARiskManager* CEscapeEARiskManager::Instance()
{
   if (m_instance == NULL)
      m_instance = new CEscapeEARiskManager();
      
   return m_instance;
}

//+------------------------------------------------------------------+
//| Initialize risk manager                                          |
//+------------------------------------------------------------------+
bool CEscapeEARiskManager::Initialize()
{
   if (m_riskIntegration != NULL)
      return m_riskIntegration.IsInitialized();
      
   m_riskIntegration = new CRiskIntegration();
   if (m_riskIntegration == NULL || !m_riskIntegration.Initialize())
   {
      Print("Failed to initialize risk integration");
      return false;
   }
   
   Print("EscapeEA Risk Manager initialized successfully");
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialize risk manager                                        |
//+------------------------------------------------------------------+
void CEscapeEARiskManager::Deinitialize()
{
   if (m_riskIntegration != NULL)
   {
      m_riskIntegration.Deinitialize();
      delete m_riskIntegration;
      m_riskIntegration = NULL;
   }
   
   if (m_instance != NULL)
   {
      delete m_instance;
      m_instance = NULL;
   }
}

//+------------------------------------------------------------------+
//| Update risk manager state                                        |
//+------------------------------------------------------------------+
void CEscapeEARiskManager::Update()
{
   if (m_riskIntegration != NULL)
      m_riskIntegration.Update();
}

//+------------------------------------------------------------------+
//| Check if a position can be opened with the given parameters      |
//+------------------------------------------------------------------+
bool CEscapeEARiskManager::CanOpenPosition(const string symbol, const ENUM_ORDER_TYPE type,
                                         const double price, const double stopLoss, 
                                         const double takeProfit, double &suggestedSize)
{
   if (m_riskIntegration == NULL)
      return false;
      
   return m_riskIntegration.CanOpenPosition(symbol, type, price, stopLoss, takeProfit, suggestedSize);
}

//+------------------------------------------------------------------+
//| Validate if position size is within allowed limits               |
//+------------------------------------------------------------------+
bool CEscapeEARiskManager::ValidatePositionSize(const string symbol, const double size)
{
   if (m_riskIntegration == NULL)
      return false;
      
   return m_riskIntegration.ValidatePositionSize(symbol, size);
}

//+------------------------------------------------------------------+
//| Update position metrics                                          |
//+------------------------------------------------------------------+
bool CEscapeEARiskManager::UpdatePositionMetrics(const string symbol, const double size, 
                                               const double openPrice, const double currentPrice)
{
   if (m_riskIntegration == NULL)
      return false;
      
   return m_riskIntegration.UpdatePositionMetrics(symbol, size, openPrice, currentPrice);
}

//+------------------------------------------------------------------+
//| Check if risk manager is initialized                             |
//+------------------------------------------------------------------+
bool CEscapeEARiskManager::IsInitialized() const
{
   return (m_riskIntegration != NULL && m_riskIntegration.IsInitialized());
}

//+------------------------------------------------------------------+
//| Get current account equity                                       |
//+------------------------------------------------------------------
double CEscapeEARiskManager::GetAccountEquity() const
{
   if (m_riskIntegration != NULL)
      return m_riskIntegration.GetAccountEquity();
      
   return AccountInfoDouble(ACCOUNT_EQUITY);
}

//+------------------------------------------------------------------+
//| Get maximum allowed position size                                |
//+------------------------------------------------------------------
double CEscapeEARiskManager::GetMaxPositionSize() const
{
   if (m_riskIntegration != NULL)
      return m_riskIntegration.GetMaxPositionSize();
      
   return 0.0;
}

//+------------------------------------------------------------------+
//| Get risk parameters                                              |
//+------------------------------------------------------------------+
CRiskParameters* CEscapeEARiskManager::GetRiskParameters()
{
   if (m_riskIntegration != NULL)
      return m_riskIntegration.GetRiskParameters();
      
   return NULL;
}

//+------------------------------------------------------------------+
//| Get risk metrics                                                 |
//+------------------------------------------------------------------+
CRiskMetrics* CEscapeEARiskManager::GetRiskMetrics()
{
   if (m_riskIntegration != NULL)
      return m_riskIntegration.GetRiskMetrics();
      
   return NULL;
}

//+------------------------------------------------------------------+
//| Get position sizer                                               |
//+------------------------------------------------------------------+
CPositionSizer* CEscapeEARiskManager::GetPositionSizer()
{
   if (m_riskIntegration != NULL)
      return m_riskIntegration.GetPositionSizer();
      
   return NULL;
}

//+------------------------------------------------------------------+
//| Get drawdown manager                                             |
//+------------------------------------------------------------------+
CDrawdownManager* CEscapeEARiskManager::GetDrawdownManager()
{
   if (m_riskIntegration != NULL)
      return m_riskIntegration.GetDrawdownManager();
      
   return NULL;
}

//+------------------------------------------------------------------+
//| Get correlation matrix                                           |
//+------------------------------------------------------------------+
CCorrelationMatrix* CEscapeEARiskManager::GetCorrelationMatrix()
{
   if (m_riskIntegration != NULL)
      return m_riskIntegration.GetCorrelationMatrix();
      
   return NULL;
}
