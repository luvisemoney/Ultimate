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
                        m_forceError(false) {}
                    ~CMockRiskManager() {}
   
   // IRiskManager interface implementation
   virtual bool      IsTradeAllowed() { return !m_forceError && m_tradeAllowed; }
   virtual double    CalculatePositionSize(double riskPercent) { return !m_forceError ? m_positionSize : -1; }
   virtual double    GetMaxPositionSize() const { return m_maxPositionSize; }
   virtual bool      UseHardStops() const { return m_useHardStops; }
   virtual string    GetLastError() const { return m_lastError; }
   
   // Test control methods
   void              SetTradeAllowed(bool allowed) { m_tradeAllowed = allowed; }
   void              SetPositionSize(double size) { m_positionSize = size; }
   void              SetUseHardStops(bool useHardStops) { m_useHardStops = useHardStops; }
   void              SetMaxPositionSize(double maxSize) { m_maxPositionSize = maxSize; }
   void              ForceError(bool force, string error = "") { 
                        m_forceError = force; 
                        if(force) m_lastError = (error == "") ? "Forced error for testing" : error;
                     }
  };

//+------------------------------------------------------------------+
