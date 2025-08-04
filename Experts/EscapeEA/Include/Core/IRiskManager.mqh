//+------------------------------------------------------------------+
//| IRiskManager.mqh - Interface for risk management                 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Risk Manager Interface                                           |
//+------------------------------------------------------------------+
class IRiskManager
  {
public:
   // Virtual destructor for proper cleanup
   virtual ~IRiskManager() {}
   
   // Check if trading is currently allowed
   virtual bool      IsTradeAllowed() = 0;
   
   // Calculate position size based on risk percentage
   virtual double    CalculatePositionSize(double riskPercent) = 0;
   
   // Get maximum allowed position size
   virtual double    GetMaxPositionSize() const = 0;
   
   // Check if hard stops should be used
   virtual bool      UseHardStops() const = 0;
   
   // Get the last error message
   virtual string    GetLastError() const = 0;
  };
//+------------------------------------------------------------------+
