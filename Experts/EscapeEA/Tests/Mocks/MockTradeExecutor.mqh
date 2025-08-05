//+------------------------------------------------------------------+
//| MockTradeExecutor.mqh - Mock implementation for testing          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include <Object.mqh>
#include "..\..\Include\Common\Structs.mqh"

//+------------------------------------------------------------------+
//| Mock Trade Executor for Testing                                  |
//+------------------------------------------------------------------+
class CMockTradeExecutor
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
      string           comment;      // Trade comment
      
      // Constructor
      InternalTradeRecord() : ticket(0), symbol(""), volume(0), type(WRONG_VALUE), 
                            price_open(0), sl(0), tp(0), openTime(0), comment("") {}
      
      // Copy constructor
      InternalTradeRecord(const InternalTradeRecord &other) :
         ticket(other.ticket),
         symbol(other.symbol),
         volume(other.volume),
         type(other.type),
         price_open(other.price_open),
         sl(other.sl),
         tp(other.tp),
         openTime(other.openTime),
         comment(other.comment) {}
      
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
         comment = other.comment;
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
        newTrade.comment = comment;  // Store the comment
        
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
   
   // Trade execution methods
   bool              OpenPosition(ENUM_ORDER_TYPE type, double volume, double sl, 
                                double tp, string comment = "")
     {
        if(m_forceError) 
          {
           m_errorMessage = "Forced error in OpenPosition";
           return false;
          }
        
        // Get current price based on order type
        double price = 0;
        if(type == ORDER_TYPE_BUY)
           price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        else if(type == ORDER_TYPE_SELL)
           price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
           
        if(price == 0) price = 1.2000; // Default for testing
        
        AddToHistory(type, volume, price, sl, tp, comment);
        
        // Set trade result
        m_tradeResult.retcode = TRADE_RETCODE_DONE;
        m_tradeResult.order = (ulong)(MathRand() % 1000000 + 100000);
        
        return true;
     }
     
   bool              ClosePosition(ulong ticket, double volume = 0)
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
     
   bool              ModifyPosition(ulong ticket, double newStopLoss, double newTakeProfit)
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
     
   bool              CloseAllPositions()
     {
        if(m_forceError) return false;
        
        ArrayResize(m_tradeHistory, 0);
        return true;
     }
     
   //--- Trade information methods
   bool              GetLastTrade(STradeRecord &trade) const
     {
        int size = ArraySize(m_tradeHistory);
        if(size == 0)
           return false;
           
        // Create a local copy to avoid reference issues
        InternalTradeRecord lastTrade = m_tradeHistory[size - 1];
        
        // Map internal record to STradeRecord
        trade.ticket = lastTrade.ticket;
        trade.openTime = lastTrade.openTime;
        trade.closeTime = 0; // Still open
        trade.symbol = lastTrade.symbol;
        trade.openPrice = lastTrade.price_open;
        trade.closePrice = 0;
        trade.stopLoss = lastTrade.sl;
        trade.takeProfit = lastTrade.tp;
        trade.lots = lastTrade.volume;
        trade.profit = 0;
        trade.swap = 0;
        trade.commission = 0;
        trade.signal = (lastTrade.type == ORDER_TYPE_BUY) ? SIGNAL_BUY : SIGNAL_SELL;
        trade.type = (lastTrade.type == ORDER_TYPE_BUY) ? TRADE_TYPE_BUY : TRADE_TYPE_SELL;
        trade.isLive = false; // Mock trades are not live
        trade.confidence = 0.8; // Default confidence for testing
        trade.comment = lastTrade.comment;
        
        return true;
     }
     
   int               GetTradeHistory(STradeRecord &trades[]) const
     {
        int size = ArraySize(m_tradeHistory);
        ArrayResize(trades, size);
        
        for(int i = 0; i < size; i++)
          {
           trades[i].ticket = m_tradeHistory[i].ticket;
           trades[i].openTime = m_tradeHistory[i].openTime;
           trades[i].closeTime = 0; // Still open
           trades[i].symbol = m_tradeHistory[i].symbol;
           trades[i].openPrice = m_tradeHistory[i].price_open;
           trades[i].closePrice = 0;
           trades[i].stopLoss = m_tradeHistory[i].sl;
           trades[i].takeProfit = m_tradeHistory[i].tp;
           trades[i].lots = m_tradeHistory[i].volume;
           trades[i].profit = 0;
           trades[i].swap = 0;
           trades[i].commission = 0;
           trades[i].signal = (m_tradeHistory[i].type == ORDER_TYPE_BUY) ? SIGNAL_BUY : SIGNAL_SELL;
           trades[i].type = (m_tradeHistory[i].type == ORDER_TYPE_BUY) ? TRADE_TYPE_BUY : TRADE_TYPE_SELL;
           trades[i].isLive = false;
           trades[i].confidence = 0.8;
           trades[i].comment = m_tradeHistory[i].comment;
          }
        return size;
     }
     
   int               GetOpenPositionsCount() const
     {
        // Return count of open positions (simplified for testing)
        int count = 0;
        for(int i = 0; i < ArraySize(m_tradeHistory); i++)
           if(m_tradeHistory[i].type != WRONG_VALUE)
              count++;
        return count;
     }
     
   bool              GetPositionInfo(ulong ticket, SPositionInfo &position)
     {
        // Find the trade by ticket
        for(int i = 0; i < ArraySize(m_tradeHistory); i++)
          {
           if(m_tradeHistory[i].ticket == ticket)
             {
              // Create a local copy to avoid reference issues
              InternalTradeRecord trade = m_tradeHistory[i];
              
              // Map internal record to SPositionInfo
              position.ticket = trade.ticket;
              position.symbol = trade.symbol;
              position.volume = trade.volume;
              position.type = (trade.type == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
              position.priceOpen = trade.price_open;
              position.stopLoss = trade.sl;
              position.takeProfit = trade.tp;
              position.time = trade.openTime;
              position.profit = 0;
              position.comment = "Test Position";
              return true;
             }
          }
        return false;
     }
     
   bool              GetLastTradeResult(MqlTradeResult &result) const
     {
        result = m_tradeResult;
        return true;
     }
   
   //--- Configuration
   void              SetSymbol(string symbol) { m_symbol = symbol; }
   string            GetSymbol() const { return m_symbol; }
   void              SetSlippage(double points) { m_slippage = points; }
   double            GetSlippage() const { return m_slippage; }
   
   //--- Error handling
   string            GetLastError() const { return m_errorMessage; }
   
   //--- Get result order
   ulong             ResultOrder() const { return m_tradeResult.order; }
   
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
   
   void              ClearTradeHistory() 
                     { 
                        ArrayResize(this.m_tradeHistory, 0); 
                     }
  };

//+------------------------------------------------------------------+