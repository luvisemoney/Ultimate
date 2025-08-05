//+------------------------------------------------------------------+
//| MockRiskManager.mqh - Mock implementation for testing            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include <Object.mqh>
#include "..\..\Include\Common\Constants.mqh"

//+------------------------------------------------------------------+
//| Mock implementation of RiskManager for testing                   |
//+------------------------------------------------------------------+
class CMockRiskManager
  {
private:
   double            m_riskPercent;      // Risk percentage
   double            m_maxDrawdown;      // Maximum drawdown
   double            m_maxDailyLoss;     // Maximum daily loss
   double            m_maxPositionSize;  // Maximum position size
   int               m_maxOpenTrades;    // Maximum open trades
   bool              m_useHardStops;     // Use hard stops
   bool              m_forceError;       // Force error for testing
   string            m_lastError;        // Last error message
   double            m_positionSize;     // Calculated position size
   bool              m_tradeAllowed;     // Whether trade is allowed
   
public:
   // Constructor
                     CMockRiskManager() : 
                        m_riskPercent(2.0),
                        m_maxDrawdown(20.0),
                        m_maxDailyLoss(5.0),
                        m_maxPositionSize(1.0),
                        m_maxOpenTrades(3),
                        m_useHardStops(true),
                        m_forceError(false),
                        m_lastError(""),
                        m_positionSize(0.1),
                        m_tradeAllowed(true)
                        {}
   
   // Risk calculation methods
   double            CalculatePositionSize(double stopLossPips) { return !m_forceError ? m_positionSize : -1; }
   bool              IsTradeAllowed() { return !m_forceError ? m_tradeAllowed : false; }
   
   // Getters
   double            RiskPercent() const { return m_riskPercent; }
   double            MaxDrawdown() const { return m_maxDrawdown; }
   double            MaxDailyLoss() const { return m_maxDailyLoss; }
   double            MaxPositionSize() const { return m_maxPositionSize; }
   int               MaxOpenTrades() const { return m_maxOpenTrades; }
   
   // Setters
   void              SetRiskPercent(double percent) { m_riskPercent = percent; }
   void              SetMaxDrawdown(double drawdown) { m_maxDrawdown = drawdown; }
   void              SetMaxDailyLoss(double loss) { m_maxDailyLoss = loss; }
   void              SetMaxPositionSize(double size) { m_maxPositionSize = size; }
   void              SetMaxOpenTrades(int maxTrades) { m_maxOpenTrades = maxTrades; }
   
   // Additional methods
   bool              UseHardStops() const { return m_useHardStops; }
   string            GetLastError() const { return m_lastError; }
   
   // Testing methods
   void              SetPositionSize(double size) { m_positionSize = size; }
   void              SetTradeAllowed(bool allowed) { m_tradeAllowed = allowed; }
   void              SetUseHardStops(bool useHardStops) { m_useHardStops = useHardStops; }
   void              ForceError(bool enable, string errorMsg = "")
     {
        m_forceError = enable;
        if(enable && errorMsg != "")
           m_lastError = errorMsg;
     }
  };

//+------------------------------------------------------------------+