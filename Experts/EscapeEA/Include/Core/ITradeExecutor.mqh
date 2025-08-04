//+------------------------------------------------------------------+
//| ITradeExecutor.mqh - Interface for trade execution               |
//| Copyright 2023, Your Company Name                                |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Your Company Name"
#property link      "https://www.yourcompany.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Trade record structure                                           |
//+------------------------------------------------------------------+
struct STradeRecord
  {
   ENUM_ORDER_TYPE type;      // Order type
   double         volume;     // Trade volume
   double         price;      // Open price
   double         sl;         // Stop loss level
   double         tp;         // Take profit level
   string         comment;    // Trade comment
   datetime       timestamp;  // Trade open time
   
   // Public getter methods
   ENUM_ORDER_TYPE GetType() const { return type; }
   double GetVolume() const { return volume; }
   double GetPrice() const { return price; }
   double GetStopLoss() const { return sl; }
   double GetTakeProfit() const { return tp; }
   string GetComment() const { return comment; }
   datetime GetTimestamp() const { return timestamp; }
  };

//+------------------------------------------------------------------+
//| Interface for trade execution                                    |
//+------------------------------------------------------------------+
interface ITradeExecutor
  {
   //--- Methods for trade execution
   bool              OpenPosition(ENUM_ORDER_TYPE type, double volume, double price, 
                                 double sl, double tp, string comment);
   bool              ClosePosition(ulong ticket, double volume);
   bool              ModifyPosition(ulong ticket, double sl, double tp);
   
   //--- Methods for trade information
   bool              GetLastTrade(STradeRecord &trade) const;
   int               GetTradeHistory(STradeRecord &trades[]) const;
   
   //--- Error handling
   string            GetLastError() const;
   
   //--- Utility methods
   void              SetSymbol(string symbol);
   string            GetSymbol() const;
   void              SetSlippage(double points);
   double            GetSlippage() const;
   
   //--- For testing purposes
   void              ForceError(bool enable, string errorMsg = "");
  };

//+------------------------------------------------------------------+
