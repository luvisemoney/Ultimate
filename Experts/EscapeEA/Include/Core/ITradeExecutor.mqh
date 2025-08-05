//+------------------------------------------------------------------+
//| ITradeExecutor.mqh - Trade execution interface for EscapeEA     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include "..\Common\Enums.mqh"
#include "..\Common\Structs.mqh"

//+------------------------------------------------------------------+
//| Trade Executor Interface                                         |
//+------------------------------------------------------------------+
class ITradeExecutor
  {
public:
   // Virtual destructor
   virtual          ~ITradeExecutor() {}
   
   // Trade execution methods
   virtual bool      OpenPosition(ENUM_ORDER_TYPE orderType, double lots, double sl, double tp, string comment = "") = 0;
   virtual bool      ClosePosition(ulong ticket, double lots = 0) = 0;
   virtual bool      CloseAllPositions() = 0;
   virtual bool      ModifyPosition(ulong ticket, double sl, double tp) = 0;
   
   // Position management
   virtual int       GetOpenPositionsCount() = 0;
   virtual double    GetOpenPositionsProfit() = 0;
   virtual bool      PositionExists(ulong ticket) = 0;
   
   // Getters
   virtual ulong     Magic() const = 0;
   virtual bool      IsLive() const = 0;
   virtual string    Symbol() const = 0;
   virtual double    Slippage() const = 0;
   
   // Setters
   virtual void      SetMagic(ulong magic) = 0;
   virtual void      SetLiveMode(bool isLive) = 0;
   virtual void      SetSlippage(double slippage) = 0;
  };