//+------------------------------------------------------------------+
//| MockTradeExecutor.mqh - Mock implementation of ITradeExecutor for testing |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include <Object.mqh>
#include "..\..\Include\Core\ITradeExecutor.mqh"

// Trade position structure
struct STradePosition
  {
   ulong            ticket;       // Position ticket
   string           symbol;       // Symbol name
   double           volume;       // Position volume
   ENUM_POSITION_TYPE type;       // Position type (buy/sell)
   double           price_open;   // Open price
   double           sl;           // Stop loss level
   double           tp;           // Take profit level
   
   // Default constructor
   STradePosition() : ticket(0), symbol(""), volume(0), type(POSITION_TYPE_BUY), 
                     price_open(0), sl(0), tp(0) {}
  };

// STradeRecord is now defined in ITradeExecutor.mqh

//+------------------------------------------------------------------+
//| Mock Trade Executor for Testing                                  |
//+------------------------------------------------------------------+
class CMockTradeExecutor : public ITradeExecutor
  {
private:
   string            m_symbol;         // Symbol
   double            m_slippage;       // Slippage in points
   bool              m_forceError;     // Whether to force an error
   string            m_errorMessage;   // Last error message
   
   // Internal trade history
   struct InternalTradeRecord
     {
      ulong            ticket;       // Ticket number
      string           symbol;       // Symbol
      double           volume;       // Volume
      ENUM_ORDER_TYPE  type;         // Order type
      double           price_open;    // Open price
      double           sl;           // Stop Loss
      double           tp;           // Take Profit
      datetime         openTime;     // Open time
      
      // Constructor
      InternalTradeRecord() : ticket(0), symbol(""), volume(0), type(WRONG_VALUE), 
                            price_open(0), sl(0), tp(0), openTime(0) {}
      
      // Copy constructor
      InternalTradeRecord(const InternalTradeRecord &other) :
         ticket(other.ticket),
         symbol(other.symbol),
         volume(other.volume),
         type(other.type),
         price_open(other.price_open),
         sl(other.sl),
         tp(other.tp),
         openTime(other.openTime) {}
      
      // Assignment operator
      void operator=(const InternalTradeRecord &other)
        {
         ticket = other.ticket;
         symbol = other.symbol;
         volume = other.volume;
         type = other.type;
         price_open = other.price_open;
         sl = other.sl;
         tp = other.tp;
         openTime = other.openTime;
        }
     };
   
   InternalTradeRecord m_tradeHistory[];  // Array of trade records
   
   // Trade result
   MqlTradeResult    m_tradeResult;    // Last trade result
   
   // Private methods
   void              AddToHistory(ENUM_ORDER_TYPE orderType, double orderVolume, double orderPrice, 
                                double orderSl, double orderTp, string comment = "")
     {
        // Create a new trade record
        InternalTradeRecord newTrade;
        newTrade.type = orderType;
        newTrade.volume = orderVolume;
        newTrade.price_open = orderPrice;
        newTrade.sl = orderSl;
        newTrade.tp = orderTp;
        newTrade.openTime = TimeCurrent();
        newTrade.ticket = (ulong)(MathRand() % 1000000 + 100000);
        newTrade.symbol = m_symbol;
        
        // Add to history - use direct assignment to avoid reference issues
        int count = ArraySize(m_tradeHistory);
        ArrayResize(m_tradeHistory, count + 1);
        m_tradeHistory[count] = newTrade;
     }
   
public:
   // Constructor/destructor
                     CMockTradeExecutor() : m_symbol(""), m_slippage(0.0), m_forceError(false) 
                     { 
                        ArrayResize(m_tradeHistory, 0); 
                        ZeroMemory(m_tradeResult);
                     }
                    ~CMockTradeExecutor() { ArrayFree(m_tradeHistory); }
   
   // ITradeExecutor interface implementation
   virtual bool OpenPosition(ENUM_ORDER_TYPE type, double volume, double price, 
                           double sl, double tp, string comment = "")
     {
        if(m_forceError) return false;
        
        AddToHistory(type, volume, price, sl, tp, comment);
        
        return true;
     }
     
   //--- Trade information methods
   bool              GetLastTrade(STradeRecord &trade) const override
     {
        int size = ArraySize(m_tradeHistory);
        if(size == 0)
           return false;
           
        // Create a local copy to avoid reference issues
        InternalTradeRecord lastTrade = m_tradeHistory[size - 1];
        
        // Map internal record to STradeRecord
        trade.type = lastTrade.type;
        trade.volume = lastTrade.volume;
        trade.price = lastTrade.price_open;
        trade.sl = lastTrade.sl;
        trade.tp = lastTrade.tp;
        trade.comment = ""; // No comment in internal record
        trade.timestamp = lastTrade.openTime;
        
        return true;
     }
     
   int               GetTradeHistory(STradeRecord &trades[]) const override
     {
        int size = ArraySize(m_tradeHistory);
        ArrayResize(trades, size);
        
        for(int i = 0; i < size; i++)
          {
           trades[i].type = m_tradeHistory[i].type;
           trades[i].volume = m_tradeHistory[i].volume;
           trades[i].price = m_tradeHistory[i].price_open;
           trades[i].sl = m_tradeHistory[i].sl;
           trades[i].tp = m_tradeHistory[i].tp;
           trades[i].comment = ""; // No comment in internal record
           trades[i].timestamp = m_tradeHistory[i].openTime;
          }
        return size;
     }
     
   virtual int GetOpenPositionsCount() const
     {
        // Return count of open positions (simplified for testing)
        int count = 0;
        for(int i = 0; i < ArraySize(m_tradeHistory); i++)
           if(m_tradeHistory[i].type != WRONG_VALUE)
              count++;
        return count;
     }
     
   virtual bool GetPositionInfo(ulong ticket, STradePosition &position)
     {
        // Find the trade by ticket
        for(int i = 0; i < ArraySize(m_tradeHistory); i++)
          {
           if(m_tradeHistory[i].ticket == ticket)
             {
              // Create a local copy to avoid reference issues
              InternalTradeRecord trade = m_tradeHistory[i];
              
              // Map internal record to STradePosition
              position.ticket = trade.ticket;
              position.symbol = trade.symbol;
              position.volume = trade.volume;
              position.type = (trade.type == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
              position.price_open = trade.price_open;
              position.sl = trade.sl;
              position.tp = trade.tp;
              return true;
             }
          }
        return false;
     }
     
   virtual bool GetLastTradeResult(MqlTradeResult &result) const
     {
        result = m_tradeResult;
        return true;
     }
   
   //--- Error handling
   string            GetLastError() const { return m_errorMessage; }
   
   //--- Position management methods
   virtual bool ClosePosition(ulong ticket, double volume = 0) override
     {
        if(m_forceError) return false;
        
        // Find the trade by ticket
        for(int i = 0; i < ArraySize(m_tradeHistory); i++)
          {
           if(m_tradeHistory[i].ticket == ticket)
             {
              // Remove from history (simulate close)
              int count = ArraySize(m_tradeHistory);
              for(int j = i; j < count - 1; j++)
                {
                 m_tradeHistory[j] = m_tradeHistory[j + 1];
                }
              ArrayResize(m_tradeHistory, count - 1);
              return true;
             }
          }
        return false;
     }
     
   virtual bool ModifyPosition(ulong ticket, double newStopLoss, double newTakeProfit)
     {
        if(m_forceError)
          {
           m_errorMessage = "Forced error in ModifyPosition";
           return false;
          }
          
        // Find and update the position
        for(int i = 0; i < ArraySize(m_tradeHistory); i++)
          {
           if(m_tradeHistory[i].ticket == ticket)
             {
              m_tradeHistory[i].sl = newStopLoss;
              m_tradeHistory[i].tp = newTakeProfit;
              m_tradeResult.retcode = TRADE_RETCODE_DONE;
              return true;
             }
          }
          
        m_errorMessage = "Position not found";
        return false;
     }
   
   //--- Utility methods
   void              SetSymbol(string symbol) override { m_symbol = symbol; }
   string            GetSymbol() const override { return m_symbol; }
   void              SetSlippage(double points) override { m_slippage = points; }
   double            GetSlippage() const override { return m_slippage; }
   
   //--- For testing purposes
   void              ForceError(bool enable, string errorMsg = "") 
     { 
        m_forceError = enable; 
        if(enable && errorMsg != "")
           m_errorMessage = errorMsg;
     }
   
   // Verification methods
   int               GetTradeHistoryCount() const 
                     { 
                        return ArraySize(m_tradeHistory); 
                     }
   
   // GetLastTrade is already implemented above
   
   void              ClearTradeHistory() 
                     { 
                        ArrayResize(this.m_tradeHistory, 0); 
                     }
  };

//+------------------------------------------------------------------+
