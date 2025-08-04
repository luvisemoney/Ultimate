//+------------------------------------------------------------------+
//| MockRiskManager.mqh - Mock implementation of IRiskManager for testing |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include <Object.mqh>
#include "..\..\Include\Core\IRiskManager.mqh"

//+------------------------------------------------------------------+
//| Mock implementation of IRiskManager for testing                  |
//+------------------------------------------------------------------+
class CMockRiskManager : public IRiskManager
  {
private:
   bool              m_tradeAllowed;     // Whether trading is allowed
   double            m_positionSize;     // Position size to return
   bool              m_useHardStops;     // Whether to use hard stops
   double            m_maxPositionSize;  // Maximum position size
   double            m_riskPercent;      // Risk per trade (% of balance)
   double            m_maxDrawdown;      // Maximum allowed drawdown (%)
   double            m_maxDailyLoss;     // Maximum daily loss (%)
   int               m_maxOpenTrades;    // Maximum number of open trades
   
   // Test control
   bool              m_forceError;       // Whether to force an error
   string            m_lastError;        // Last error message
   
public:
   // Constructor/destructor
                     CMockRiskManager() : 
                        m_tradeAllowed(true), 
                        m_positionSize(0.1),
                        m_useHardStops(true),
                        m_maxPositionSize(10.0),
                        m_riskPercent(1.0),
                        m_maxDrawdown(10.0),
                        m_maxDailyLoss(5.0),
                        m_maxOpenTrades(5),
                        m_forceError(false) {}
                    ~CMockRiskManager() {}
   
   // IRiskManager interface implementation
   virtual double    CalculatePositionSize(double stopLossPips) { return !m_forceError ? m_positionSize : -1; }
   virtual bool      IsTradeAllowed() { return !m_forceError && m_tradeAllowed; }
   
   // Getters
   virtual double    RiskPercent() const { return m_riskPercent; }
   virtual double    MaxDrawdown() const { return m_maxDrawdown; }
   virtual double    MaxDailyLoss() const { return m_maxDailyLoss; }
   virtual double    MaxPositionSize() const { return m_maxPositionSize; }
   virtual int       MaxOpenTrades() const { return m_maxOpenTrades; }
   
   // Setters
   virtual void      SetRiskPercent(double percent) { m_riskPercent = percent; }
   virtual void      SetMaxDrawdown(double drawdown) { m_maxDrawdown = drawdown; }
   virtual void      SetMaxDailyLoss(double loss) { m_maxDailyLoss = loss; }
   virtual void      SetMaxPositionSize(double size) { m_maxPositionSize = size; }
   virtual void      SetMaxOpenTrades(int maxTrades) { m_maxOpenTrades = maxTrades; }
   
   // Additional methods
   virtual bool      UseHardStops() const { return m_useHardStops; }
   virtual string    GetLastError() const { return m_lastError; }
   
   // Test control methods
   void              SetTradeAllowed(bool allowed) { m_tradeAllowed = allowed; }
   void              SetPositionSize(double size) { m_positionSize = size; }
   void              SetUseHardStops(bool useHardStops) { m_useHardStops = useHardStops; }
   void              ForceError(bool force, string error = "") { 
                        m_forceError = force; 
                        if(force) m_lastError = (error == "") ? "Forced error for testing" : error;
                        else m_lastError = "";
                     }
  };

//+------------------------------------------------------------------+
