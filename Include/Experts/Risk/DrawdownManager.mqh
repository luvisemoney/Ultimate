//+------------------------------------------------------------------+
//|                                            DrawdownManager.mqh    |
//|                        Copyright 2025, Your Company Name          |
//|                                             https://www.yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company Name"
#property link      "https://www.yoursite.com"
#property version   "1.00"
#property strict

#include <Arrays\ArrayObj.mqh>

//+------------------------------------------------------------------+
//| Drawdown Period Structure                                        |
//+------------------------------------------------------------------+
struct SDrawdownPeriod
{
   datetime startTime;      // Start time of drawdown
   datetime endTime;        // End time of drawdown (0 if ongoing)
   double   startEquity;    // Equity at start of drawdown
   double   minEquity;      // Minimum equity during drawdown
   double   maxDrawdown;    // Maximum drawdown in account currency
   double   maxDrawdownPct; // Maximum drawdown in percentage
   
   // Constructor
   SDrawdownPeriod()
   {
      startTime = 0;
      endTime = 0;
      startEquity = 0.0;
      minEquity = 0.0;
      maxDrawdown = 0.0;
      maxDrawdownPct = 0.0;
   }
};

//+------------------------------------------------------------------+
//| Drawdown Manager Class                                           |
//+------------------------------------------------------------------+
class CDrawdownManager
{
private:
   CArrayObj*        m_drawdowns;      // Array of drawdown periods
   SDrawdownPeriod*  m_currentDD;      // Current drawdown period (if any)
   
   // Statistics
   double            m_equityPeak;     // Peak equity value
   double            m_maxDrawdown;    // Maximum drawdown (currency)
   double            m_maxDrawdownPct; // Maximum drawdown (%)
   double            m_avgDrawdown;    // Average drawdown
   int               m_ddCount;        // Number of drawdowns
   
   // Parameters
   double            m_equity;         // Current equity
   bool              m_isInitialized;   // Initialization flag
   
   // Private methods
   void              UpdateDrawdownStats();
   
public:
   // Constructor/Destructor
                     CDrawdownManager();
                    ~CDrawdownManager();
   
   // Initialization
   bool              Initialize();
   void              Deinitialize();
   
   // Update methods
   void              UpdateEquity(const double equity);
   void              UpdateFromHistory();
   
   // Getters
   double            GetCurrentDrawdown() const;
   double            GetCurrentDrawdownPct() const;
   double            GetMaxDrawdown() const { return m_maxDrawdown; }
   double            GetMaxDrawdownPct() const { return m_maxDrawdownPct; }
   double            GetAvgDrawdown() const;
   int               GetDrawdownCount() const { return m_ddCount; }
   bool              IsInDrawdown() const { return (m_currentDD != NULL); }
   bool              IsInitialized() const { return m_isInitialized; }
   
   // Risk management
   bool              IsDrawdownLimitReached(const double maxDrawdownPct) const;
   bool              IsDailyLossLimitReached(const double maxDailyLossPct) const;
   
   // Statistics
   void              CalculateStatistics();
   
   // Persistence
   bool              SaveToFile(const string filename);
   bool              LoadFromFile(const string filename);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CDrawdownManager::CDrawdownManager() :
   m_drawdowns(NULL),
   m_currentDD(NULL),
   m_equityPeak(0.0),
   m_maxDrawdown(0.0),
   m_maxDrawdownPct(0.0),
   m_avgDrawdown(0.0),
   m_ddCount(0),
   m_equity(0.0),
   m_isInitialized(false)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CDrawdownManager::~CDrawdownManager()
{
   Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize drawdown manager                                      |
//+------------------------------------------------------------------+
bool CDrawdownManager::Initialize()
{
   if (m_isInitialized)
      return true;
      
   m_drawdowns = new CArrayObj();
   if (m_drawdowns == NULL)
      return false;
      
   m_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   m_equityPeak = m_equity;
   m_currentDD = NULL;
   
   // Load historical drawdowns if available
   // LoadFromFile("drawdown_history.dat");
   
   m_isInitialized = true;
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialize drawdown manager                                    |
//+------------------------------------------------------------------+
void CDrawdownManager::Deinitialize()
{
   if (m_drawdowns != NULL)
   {
      m_drawdowns.Clear();
      delete m_drawdowns;
      m_drawdowns = NULL;
   }
   
   if (m_currentDD != NULL)
   {
      delete m_currentDD;
      m_currentDD = NULL;
   }
   
   m_isInitialized = false;
}

//+------------------------------------------------------------------+
//| Update equity and check for drawdowns                            |
//+------------------------------------------------------------------+
void CDrawdownManager::UpdateEquity(const double equity)
{
   if (!m_isInitialized)
      return;
      
   m_equity = equity;
   
   // Check for new peak
   if (m_equity > m_equityPeak)
   {
      // If we were in a drawdown and now reached a new peak, end the drawdown
      if (m_currentDD != NULL)
      {
         m_currentDD.endTime = TimeCurrent();
         m_drawdowns.Add(m_currentDD);
         m_currentDD = NULL;
      }
      
      m_equityPeak = m_equity;
   }
   // Check for drawdown
   else if (m_equity < m_equityPeak)
   {
      // Start new drawdown if not already in one
      if (m_currentDD == NULL)
      {
         m_currentDD = new SDrawdownPeriod();
         if (m_currentDD != NULL)
         {
            m_currentDD.startTime = TimeCurrent();
            m_currentDD.startEquity = m_equityPeak;
            m_currentDD.minEquity = m_equity;
            m_currentDD.maxDrawdown = m_equityPeak - m_equity;
            m_currentDD.maxDrawdownPct = (m_currentDD.maxDrawdown / m_equityPeak) * 100.0;
         }
      }
      // Update existing drawdown
      else
      {
         m_currentDD.minEquity = MathMin(m_currentDD.minEquity, m_equity);
         double currentDD = m_equityPeak - m_equity;
         double currentDDPct = (currentDD / m_equityPeak) * 100.0;
         
         if (currentDD > m_currentDD.maxDrawdown)
         {
            m_currentDD.maxDrawdown = currentDD;
            m_currentDD.maxDrawdownPct = currentDDPct;
         }
      }
      
      // Update global max drawdown
      if (m_currentDD != NULL && m_currentDD.maxDrawdown > m_maxDrawdown)
      {
         m_maxDrawdown = m_currentDD.maxDrawdown;
         m_maxDrawdownPct = m_currentDD.maxDrawdownPct;
      }
   }
   
   // Recalculate statistics
   CalculateStatistics();
}

//+------------------------------------------------------------------+
//| Update from account history                                      |
//+------------------------------------------------------------------+
void CDrawdownManager::UpdateFromHistory()
{
   // This would load historical drawdowns from account history
   // Implementation depends on how you want to track historical drawdowns
}

//+------------------------------------------------------------------+
//| Get current drawdown in account currency                         |
//+------------------------------------------------------------------+
double CDrawdownManager::GetCurrentDrawdown() const
{
   if (m_currentDD != NULL)
      return m_equityPeak - m_equity;
      
   return 0.0;
}

//+------------------------------------------------------------------+
//| Get current drawdown as percentage of peak equity                |
//+------------------------------------------------------------------
double CDrawdownManager::GetCurrentDrawdownPct() const
{
   if (m_equityPeak > 0.0)
      return ((m_equityPeak - m_equity) / m_equityPeak) * 100.0;
      
   return 0.0;
}

//+------------------------------------------------------------------+
//| Calculate average drawdown                                       |
//+------------------------------------------------------------------
double CDrawdownManager::GetAvgDrawdown() const
{
   if (m_ddCount == 0)
      return 0.0;
      
   double totalDD = 0.0;
   int count = m_drawdowns.Total();
   
   for (int i = 0; i < count; i++)
   {
      SDrawdownPeriod* dd = (SDrawdownPeriod*)m_drawdowns.At(i);
      if (dd != NULL)
      {
         totalDD += dd.maxDrawdownPct;
      }
   }
   
   return (count > 0) ? (totalDD / count) : 0.0;
}

//+------------------------------------------------------------------+
//| Check if drawdown limit is reached                               |
//+------------------------------------------------------------------
bool CDrawdownManager::IsDrawdownLimitReached(const double maxDrawdownPct) const
{
   if (maxDrawdownPct <= 0.0)
      return false;
      
   double currentDD = GetCurrentDrawdownPct();
   return (currentDD >= maxDrawdownPct);
}

//+------------------------------------------------------------------+
//| Check if daily loss limit is reached                             |
//+------------------------------------------------------------------
bool CDrawdownManager::IsDailyLossLimitReached(const double maxDailyLossPct) const
{
   if (maxDailyLossPct <= 0.0)
      return false;
      
   // This would check the daily loss from the start of the day
   // Implementation depends on how you want to track daily P/L
   
   return false;
}

//+------------------------------------------------------------------+
//| Calculate drawdown statistics                                    |
//+------------------------------------------------------------------
void CDrawdownManager::CalculateStatistics()
{
   int count = m_drawdowns.Total();
   
   // Count only closed drawdowns
   m_ddCount = 0;
   double totalDD = 0.0;
   
   for (int i = 0; i < count; i++)
   {
      SDrawdownPeriod* dd = (SDrawdownPeriod*)m_drawdowns.At(i);
      if (dd != NULL && dd.endTime > 0)
      {
         totalDD += dd.maxDrawdownPct;
         m_ddCount++;
      }
   }
   
   // Calculate average drawdown
   m_avgDrawdown = (m_ddCount > 0) ? (totalDD / m_ddCount) : 0.0;
   
   // Update max drawdown if current drawdown is larger
   if (m_currentDD != NULL && m_currentDD.maxDrawdown > m_maxDrawdown)
   {
      m_maxDrawdown = m_currentDD.maxDrawdown;
      m_maxDrawdownPct = m_currentDD.maxDrawdownPct;
   }
}

//+------------------------------------------------------------------+
//| Save drawdown data to file                                       |
//+------------------------------------------------------------------
bool CDrawdownManager::SaveToFile(const string filename)
{
   // Implementation depends on how you want to persist the data
   return false;
}

//+------------------------------------------------------------------+
//| Load drawdown data from file                                     |
//+------------------------------------------------------------------
bool CDrawdownManager::LoadFromFile(const string filename)
{
   // Implementation depends on how you want to load the data
   return false;
}
