//+------------------------------------------------------------------+
//| TradeExecutor.mqh - Trade execution for EscapeEA                 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include "..\Common\Enums.mqh"
#include "..\Common\Structs.mqh"
#include "..\Common\Constants.mqh"
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//+------------------------------------------------------------------+
//| Trade Executor Class                                             |
//+------------------------------------------------------------------+
class CTradeExecutor : public CTrade
  {
private:
   bool              m_isLive;           // True for live trading
   string            m_symbol;           // Trading symbol
   double            m_slippage;         // Allowed slippage in points
   ulong             m_eaMagic;          // Magic number for trade identification
   
   // Private methods
   bool              ValidateTradeRequest(const MqlTradeRequest &request);
   
public:
   // Constructor/destructor
                     CTradeExecutor(ulong magic, bool isLive, string symbol, double slippage = 10.0);
   
   // Trade execution methods
   bool              OpenPosition(ENUM_ORDER_TYPE orderType, double lots, double sl, double tp, string comment = "");
   bool              ClosePosition(ulong ticket, double lots = 0);
   bool              CloseAllPositions();
   bool              ModifyPosition(ulong ticket, double sl, double tp);
   
   // Position management
   int               GetOpenPositionsCount();
   double            GetOpenPositionsProfit();
   bool              PositionExists(ulong ticket);
   
   // Getters
   ulong             Magic() const { return m_eaMagic; }
   bool              IsLive() const { return m_isLive; }
   string            Symbol() const { return m_symbol; }
   double            Slippage() const { return m_slippage; }
   
   // Setters
   void              SetMagic(ulong magic) { m_eaMagic = magic; CTrade::SetExpertMagicNumber(magic); }
   void              SetLiveMode(bool isLive) { m_isLive = isLive; }
   void              SetSlippage(double slippage) { m_slippage = slippage; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTradeExecutor::CTradeExecutor(ulong magic, bool isLive, string symbol, double slippage = 10.0) :
   m_isLive(isLive),
   m_symbol(symbol),
   m_slippage(slippage),
   m_eaMagic(magic)
  {
   // Set trade parameters
   SetExpertMagicNumber(magic);
   SetDeviationInPoints((ulong)m_slippage);
   SetTypeFilling(ORDER_FILLING_RETURN);
   SetAsyncMode(true);
   
   // Set trade logging
   LogLevel(LOG_LEVEL_ERRORS);
  }

//+------------------------------------------------------------------+
//| Open a new position                                              |
//+------------------------------------------------------------------+
bool CTradeExecutor::OpenPosition(ENUM_ORDER_TYPE orderType, double lots, double sl, double tp, string comment = "")
  {
   // In paper trading mode, just log the trade
   if(!m_isLive)
     {
      double price = (orderType == ORDER_TYPE_BUY) ? 
                    SymbolInfoDouble(m_symbol, SYMBOL_ASK) : 
                    SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      PrintFormat("PAPER TRADE: %s %.2f lots at %.5f, SL: %.5f, TP: %.5f", 
                 EnumToString(orderType), lots, price, sl, tp);
      return true;
     }
   
   // In live trading mode, execute the trade
   double price = (orderType == ORDER_TYPE_BUY) ? 
                 SymbolInfoDouble(m_symbol, SYMBOL_ASK) : 
                 SymbolInfoDouble(m_symbol, SYMBOL_BID);
   return PositionOpen(m_symbol, orderType, lots, price, sl, tp, comment);
  }

//+------------------------------------------------------------------+
//| Close an existing position                                       |
//+------------------------------------------------------------------+
bool CTradeExecutor::ClosePosition(ulong ticket, double lots = 0)
  {
   CPositionInfo position;
   
   if(!position.SelectByTicket(ticket))
     {
      Print("Position ", ticket, " not found");
      return false;
     }
   
   // In paper trading mode, just log the close
   if(!m_isLive)
     {
      double profit = position.Profit() + position.Swap() + position.Commission();
      PrintFormat("PAPER CLOSE: Position %d closed with P/L: %.2f", ticket, profit);
      return true;
     }
   
   // In live trading mode, close the position
   if(lots <= 0 || lots >= position.Volume())
      return PositionClose(ticket);
   else
      return PositionClosePartial(ticket, lots);
  }

//+------------------------------------------------------------------+
//| Close all open positions                                         |
//+------------------------------------------------------------------+
bool CTradeExecutor::CloseAllPositions()
  {
   bool result = true;
   CPositionInfo position;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(position.SelectByIndex(i))
         if(position.Symbol() == m_symbol && position.Magic() == m_magic)
            if(!ClosePosition(position.Ticket()))
               result = false;
   
   return result;
  }

//+------------------------------------------------------------------+
//| Modify an existing position                                      |
//+------------------------------------------------------------------+
bool CTradeExecutor::ModifyPosition(ulong ticket, double sl, double tp)
  {
   CPositionInfo position;
   
   if(!position.SelectByTicket(ticket))
     {
      Print("Position ", ticket, " not found for modification");
      return false;
     }
   
   // In paper trading mode, just log the modification
   if(!m_isLive)
     {
      PrintFormat("PAPER MODIFY: Position %d updated - SL: %.5f, TP: %.5f", 
                 ticket, sl, tp);
      return true;
     }
   
   // In live trading mode, modify the position
   return PositionModify(ticket, sl, tp);
  }

//+------------------------------------------------------------------+
//| Get number of open positions                                     |
//+------------------------------------------------------------------+
int CTradeExecutor::GetOpenPositionsCount()
  {
   int count = 0;
   CPositionInfo position;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(position.SelectByIndex(i))
         if(position.Symbol() == m_symbol && position.Magic() == m_magic)
            count++;
   
   return count;
  }

//+------------------------------------------------------------------+
//| Get total profit of open positions                               |
//+------------------------------------------------------------------+
double CTradeExecutor::GetOpenPositionsProfit()
  {
   double profit = 0.0;
   CPositionInfo position;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(position.SelectByIndex(i))
         if(position.Symbol() == m_symbol && position.Magic() == m_magic)
            profit += position.Profit() + position.Swap() + position.Commission();
   
   return profit;
  }

//+------------------------------------------------------------------+
//| Check if a position exists                                       |
//+------------------------------------------------------------------+
bool CTradeExecutor::PositionExists(ulong ticket)
  {
   CPositionInfo position;
   return position.SelectByTicket(ticket);
  }

//+------------------------------------------------------------------+
//| Validate trade request parameters                                |
//+------------------------------------------------------------------+
bool CTradeExecutor::ValidateTradeRequest(const MqlTradeRequest &request)
  {
   // Check symbol
   if(request.symbol != m_symbol)
     {
      Print("Invalid symbol in trade request");
      return false;
     }
   
   // Check volume
   double minVolume = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
   double maxVolume = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
   double volumeStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
   
   if(request.volume < minVolume || request.volume > maxVolume)
     {
      Print("Invalid volume in trade request");
      return false;
     }
   
   // Check if volume is a multiple of the step
   if(MathMod(request.volume, volumeStep) != 0)
     {
      Print("Volume must be a multiple of ", volumeStep);
      return false;
     }
   
   // Check price and stop levels
   double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   
   if(request.price <= 0 || (request.sl > 0 && request.sl >= bid) || 
      (request.tp > 0 && request.tp <= ask))
     {
      Print("Invalid price levels in trade request");
      return false;
     }
   
   // Check minimum stop distance
   double stopLevel = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   
   if((request.sl > 0 && MathAbs(request.price - request.sl) < stopLevel) ||
      (request.tp > 0 && MathAbs(request.tp - request.price) < stopLevel))
     {
      Print("Stop levels too close to current price");
      return false;
     }
   
   return true;
  }