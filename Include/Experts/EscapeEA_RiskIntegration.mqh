//+------------------------------------------------------------------+
//|                                   EscapeEA_RiskIntegration.mqh    |
//|                        Copyright 2025, Your Company Name          |
//|                                             https://www.yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company Name"
#property link      "https://www.yoursite.com"
#property version   "1.00"
#property strict

#include "EscapeEARiskManager.mqh"

//+------------------------------------------------------------------+
//| Risk Integration for EscapeEA                                    |
//+------------------------------------------------------------------+
class CEscapeEARiskIntegration
{
private:
   static CEscapeEARiskIntegration* m_instance;  // Singleton instance
   CEscapeEARiskManager*            m_riskManager; // Risk manager
   
   // Risk parameters
   double            m_riskPerTrade;     // Risk per trade (% of balance)
   double            m_maxDrawdownPct;   // Maximum allowed drawdown (%)
   double            m_maxDailyLossPct;  // Maximum daily loss (%)
   
   // State
   bool              m_isInitialized;    // Initialization flag
   
   // Private constructor for singleton
                     CEscapeEARiskIntegration();
   
public:
   // Destructor
                    ~CEscapeEARiskIntegration();
   
   // Singleton access
   static CEscapeEARiskIntegration* Instance();
   
   // Initialization
   bool              Initialize();
   void              Deinitialize();
   void              Update();
   
   // Position management
   bool              CanOpenPosition(const string symbol, const ENUM_ORDER_TYPE type,
                                   const double price, const double stopLoss, 
                                   const double takeProfit, double &suggestedSize);
   
   bool              ValidatePositionSize(const string symbol, const double size);
   void              UpdatePositionMetrics(const string symbol, const double size, 
                                         const double openPrice, const double currentPrice);
   
   // Getters
   bool              IsInitialized() const { return m_isInitialized; }
   double            GetRiskPerTrade() const { return m_riskPerTrade; }
   double            GetMaxDrawdownPct() const { return m_maxDrawdownPct; }
   double            GetMaxDailyLossPct() const { return m_maxDailyLossPct; }
   
   // Setters
   void              SetRiskPerTrade(const double risk) { m_riskPerTrade = risk; }
   void              SetMaxDrawdownPct(const double drawdown) { m_maxDrawdownPct = drawdown; }
   void              SetMaxDailyLossPct(const double loss) { m_maxDailyLossPct = loss; }
   
   // Component access
   CEscapeEARiskManager* GetRiskManager() { return m_riskManager; }
};

// Initialize static member
CEscapeEARiskIntegration* CEscapeEARiskIntegration::m_instance = NULL;

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CEscapeEARiskIntegration::CEscapeEARiskIntegration() :
   m_riskManager(NULL),
   m_riskPerTrade(1.0),
   m_maxDrawdownPct(10.0),
   m_maxDailyLossPct(5.0),
   m_isInitialized(false)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CEscapeEARiskIntegration::~CEscapeEARiskIntegration()
{
   Deinitialize();
}

//+------------------------------------------------------------------+
//| Get singleton instance                                           |
//+------------------------------------------------------------------+
CEscapeEARiskIntegration* CEscapeEARiskIntegration::Instance()
{
   if (m_instance == NULL)
      m_instance = new CEscapeEARiskIntegration();
      
   return m_instance;
}

//+------------------------------------------------------------------+
//| Initialize risk integration                                      |
//+------------------------------------------------------------------+
bool CEscapeEARiskIntegration::Initialize()
{
   if (m_isInitialized)
      return true;
      
   // Initialize risk manager
   m_riskManager = CEscapeEARiskManager::Instance();
   if (m_riskManager == NULL || !m_riskManager.Initialize())
   {
      Print("Failed to initialize risk manager");
      return false;
   }
   
   // Configure risk parameters
   if (m_riskManager.GetRiskParameters() != NULL)
   {
      m_riskManager.GetRiskParameters().SetRiskPerTrade(m_riskPerTrade);
      m_riskManager.GetRiskParameters().SetMaxDrawdownPct(m_maxDrawdownPct);
      m_riskManager.GetRiskParameters().SetMaxDailyLossPct(m_maxDailyLossPct);
   }
   
   m_isInitialized = true;
   Print("EscapeEA Risk Integration initialized successfully");
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialize risk integration                                    |
//+------------------------------------------------------------------+
void CEscapeEARiskIntegration::Deinitialize()
{
   if (m_riskManager != NULL)
   {
      m_riskManager.Deinitialize();
      m_riskManager = NULL;
   }
   
   if (m_instance != NULL)
   {
      delete m_instance;
      m_instance = NULL;
   }
   
   m_isInitialized = false;
}

//+------------------------------------------------------------------+
//| Update risk integration state                                    |
//+------------------------------------------------------------------+
void CEscapeEARiskIntegration::Update()
{
   if (m_riskManager != NULL && m_isInitialized)
      m_riskManager.Update();
}

//+------------------------------------------------------------------+
//| Check if a position can be opened with the given parameters      |
//+------------------------------------------------------------------+
bool CEscapeEARiskIntegration::CanOpenPosition(const string symbol, const ENUM_ORDER_TYPE type,
                                             const double price, const double stopLoss, 
                                             const double takeProfit, double &suggestedSize)
{
   if (!m_isInitialized || m_riskManager == NULL)
      return false;
      
   return m_riskManager.CanOpenPosition(symbol, type, price, stopLoss, takeProfit, suggestedSize);
}

//+------------------------------------------------------------------+
//| Validate if position size is within allowed limits               |
//+------------------------------------------------------------------+
bool CEscapeEARiskIntegration::ValidatePositionSize(const string symbol, const double size)
{
   if (!m_isInitialized || m_riskManager == NULL)
      return false;
      
   return m_riskManager.ValidatePositionSize(symbol, size);
}

//+------------------------------------------------------------------+
//| Update position metrics                                          |
//+------------------------------------------------------------------+
void CEscapeEARiskIntegration::UpdatePositionMetrics(const string symbol, const double size, 
                                                   const double openPrice, const double currentPrice)
{
   if (m_isInitialized && m_riskManager != NULL)
   {
      m_riskManager.UpdatePositionMetrics(symbol, size, openPrice, currentPrice);
   }
}

//+------------------------------------------------------------------+
//| Global functions for easy access                                 |
//+------------------------------------------------------------------+

// Initialize risk management
bool InitializeRiskManagement()
{
   return CEscapeEARiskIntegration::Instance().Initialize();
}

// Update risk management
void UpdateRiskManagement()
{
   CEscapeEARiskIntegration::Instance().Update();
}

// Check if position can be opened
bool CanOpenPosition(const string symbol, const ENUM_ORDER_TYPE type,
                    const double price, const double stopLoss, 
                    const double takeProfit, double &suggestedSize)
{
   return CEscapeEARiskIntegration::Instance().CanOpenPosition(symbol, type, price, stopLoss, takeProfit, suggestedSize);
}

// Validate position size
bool ValidatePositionSize(const string symbol, const double size)
{
   return CEscapeEARiskIntegration::Instance().ValidatePositionSize(symbol, size);
}

// Update position metrics
void UpdatePositionMetrics(const string symbol, const double size, 
                          const double openPrice, const double currentPrice)
{
   CEscapeEARiskIntegration::Instance().UpdatePositionMetrics(symbol, size, openPrice, currentPrice);
}

// Get risk manager instance
CEscapeEARiskManager* GetRiskManager()
{
   return CEscapeEARiskIntegration::Instance().GetRiskManager();
}
