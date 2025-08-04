//+------------------------------------------------------------------+
//| IRiskManager.mqh - Interface for Risk Management                |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| IRiskManager - Interface for risk management                     |
//+------------------------------------------------------------------+
class IRiskManager
  {
public:
   // Virtual destructor
   virtual ~IRiskManager() {}
   
   // Risk calculation methods
   virtual double    CalculatePositionSize(double stopLossPips) = 0;
   virtual bool      IsTradeAllowed() = 0;
   
   // Getters
   virtual double    RiskPercent() const = 0;
   virtual double    MaxDrawdown() const = 0;
   virtual double    MaxDailyLoss() const = 0;
   virtual double    MaxPositionSize() const = 0;
   virtual int       MaxOpenTrades() const = 0;
   
   // Setters
   virtual void      SetRiskPercent(double percent) = 0;
   virtual void      SetMaxDrawdown(double drawdown) = 0;
   virtual void      SetMaxDailyLoss(double loss) = 0;
   virtual void      SetMaxPositionSize(double size) = 0;
   virtual void      SetMaxOpenTrades(int maxTrades) = 0;
   
   // Additional methods from MockRiskManager
   virtual bool      UseHardStops() const = 0;
   virtual string    GetLastError() const = 0;
  };
//+------------------------------------------------------------------+
