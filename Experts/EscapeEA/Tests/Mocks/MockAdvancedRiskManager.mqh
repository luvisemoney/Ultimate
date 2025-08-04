//+------------------------------------------------------------------+
//| MockAdvancedRiskManager.mqh - Mock implementation of CAdvancedRiskManager |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include <Object.mqh>
#include "..\\..\\Include\\Core\\AdvancedRiskManager.mqh"

//+------------------------------------------------------------------+
//| Mock implementation of CAdvancedRiskManager for testing          |
//+------------------------------------------------------------------+
class CMockAdvancedRiskManager : public CAdvancedRiskManager
  {
private:
   bool              m_initialized;     // Whether the risk manager is initialized
   bool              m_forceError;      // Whether to force an error
   string            m_lastError;       // Last error message
   
   // Test data
   double            m_positionSize;    // Position size to return
   double            m_stopLoss;        // Stop loss to return
   double            m_takeProfit;      // Take profit to return
   
public:
   // Constructor/destructor
                     CMockAdvancedRiskManager() : 
                        CAdvancedRiskManager(),
                        m_initialized(false),
                        m_forceError(false),
                        m_positionSize(0.1),
                        m_stopLoss(1.1900),
                        m_takeProfit(1.2100)
                        {
                           // Initialize with default values
                           m_initialized = Initialize(0.01, 100.0, 0.0, 0.0, 0.0);
                        }
                    
                    ~CMockAdvancedRiskManager() {}
   
   // Override methods
   virtual bool      Initialize(double riskPerTrade = 1.0, double maxDailyDrawdown = 5.0, 
                             double maxPositionRisk = 2.0, double maxCorrelation = 0.7, 
                             double volatilityThreshold = 0.5) 
                     { 
                        if (m_forceError) return false;
                        return CAdvancedRiskManager::Initialize(riskPerTrade, maxDailyDrawdown, 
                                                             maxPositionRisk, maxCorrelation, 
                                                             volatilityThreshold);
                     }
   
   virtual double    CalculatePositionSize(double entryPrice, double stopLoss, double riskPercent)
                     {
                        if(m_forceError)
                           return 0.0;
                           
                        return m_positionSize;
                     }
   
   virtual double    CalculateStopLoss(double entryPrice, ENUM_ORDER_TYPE orderType, double atr = 0.0)
                     {
                        if(m_forceError)
                           return 0.0;
                           
                        return m_stopLoss;
                     }
   
   virtual double    CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double atr = 0.0)
                     {
                        if(m_forceError)
                           return 0.0;
                           
                        return m_takeProfit;
                     }
   
   // Test control methods
   void              SetInitialized(bool initialized) { m_initialized = initialized; }
   void              SetPositionSize(double size) { m_positionSize = size; }
   void              SetStopLoss(double sl) { m_stopLoss = sl; }
   void              SetTakeProfit(double tp) { m_takeProfit = tp; }
   
   void              ForceError(bool force, string error = "") 
                     { 
                        m_forceError = force; 
                        if(force) 
                           m_lastError = (error == "") ? "Forced error for testing" : error;
                     }
   
   string            GetLastError() const { return m_forceError ? m_lastError : ""; }
  };

//+------------------------------------------------------------------+
