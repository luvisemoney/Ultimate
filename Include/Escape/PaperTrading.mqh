//+------------------------------------------------------------------+
//|                                              PaperTrading.mqh     |
//|                                          Copyright 2025, EscapeEA |
//|                                             https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "2.00"
#property strict

#include <Trade\PositionInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Arrays\ArrayObj.mqh>

// Forward declarations
class CRiskManager;  // Forward declaration of RiskManager

// Include the actual header files after forward declarations
#include "RiskManager.mqh"

//+------------------------------------------------------------------+
//| Paper Trade Settings                                             |
//+------------------------------------------------------------------+
input group "=== Paper Trading Settings ==="
input bool     InpEnablePaperTrading = true;    // Enable Paper Trading
input int      InpPaperTradesRequired = 5;      // Total Paper Trades
input int      InpPaperWinsRequired = 3;        // Required Wins for Live Trading
input double   InpPaperInitialBalance = 10000.0; // Initial Paper Balance
input bool     InpSimulateSlippage = true;      // Simulate Slippage
input bool     InpSimulatePartialFills = true;  // Simulate Partial Fills
input double   InpMaxSlippagePips = 1.0;        // Max Slippage (pips)
input int      InpFillProbability = 90;         // Fill Probability (%)

//+------------------------------------------------------------------+
//| Paper Trade Structure                                            |
//+------------------------------------------------------------------+
struct SPaperTrade {
   ulong        ticket;           // Trade ticket
   string       symbol;           // Symbol
   ENUM_ORDER_TYPE type;          // Order type
   double       volume;           // Trade volume
   double       openPrice;        // Open price
   double       stopLoss;         // Stop loss
   double       takeProfit;       // Take profit
   datetime     openTime;         // Open time
   datetime     closeTime;        // Close time
   double       closePrice;       // Close price
   double       commission;       // Commission
   double       swap;             // Swap
   double       profit;           // Profit/loss
   bool         isClosed;         // Is trade closed
   bool         isWinner;         // Is winning trade
   
   // Constructor
   SPaperTrade() {
      ticket = 0;
      volume = 0.0;
      openPrice = 0.0;
      stopLoss = 0.0;
      takeProfit = 0.0;
      closePrice = 0.0;
      commission = 0.0;
      swap = 0.0;
      profit = 0.0;
      isClosed = false;
      isWinner = false;
   }
};

//+------------------------------------------------------------------+
//| CPaperTrading class                                              |
//+------------------------------------------------------------------+
class CPaperTrading
{
private:
   // Trade management
   CArrayObj      m_trades;           // Array of paper trades
   double         m_balance;          // Current paper balance
   double         m_equity;           // Current paper equity
   int            m_totalTrades;      // Total paper trades
   int            m_winningTrades;    // Number of winning trades
   int            m_losingTrades;     // Number of losing trades
   bool           m_liveTrading;      // Live trading enabled
   
   // Simulation parameters
   double         m_slippage;         // Current slippage
   double         m_spread;           // Current spread
   
   // External components
   CSymbolInfo   m_symbol;           // Symbol info
   CAccountInfo  m_account;          // Account info
   CRiskManager *m_riskManager;      // Risk manager (forward declared)
   
   // Private methods
   double         CalculateCommission(double volume, double price);
   double         CalculateSwap(double volume, double price, ENUM_ORDER_TYPE type);
   double         CalculateSlippage();
   bool           SimulateFill();
   void           UpdateEquity();
   
public:
   // Constructor/Destructor
                  CPaperTrading(CRiskManager *riskManager = NULL);
                 ~CPaperTrading();
   
   // Initialization
   bool           Initialize(CSymbolInfo *symbol, CAccountInfo *account, 
                           CEnhancedRiskManager *riskManager);
   void           Deinitialize();
   
   // Trading operations
   bool           OpenPosition(ENUM_ORDER_TYPE type, double volume, 
                             double price, double sl, double tp, 
                             string comment = "");
   bool           ClosePosition(ulong ticket, double price);
   void           CheckForExits();
   
   // Getters
   double         GetBalance() const { return m_balance; }
   double         GetEquity() const { return m_equity; }
   int            GetTotalTrades() const { return m_totalTrades; }
   int            GetWinningTrades() const { return m_winningTrades; }
   int            GetLosingTrades() const { return m_losingTrades; }
   double         GetWinRate() const { 
      return (m_totalTrades > 0) ? (double)m_winningTrades / m_totalTrades * 100.0 : 0.0; 
   }
   bool           IsLiveTradingAllowed() const { 
      return m_liveTrading || (!InpEnablePaperTrading); 
   }
   
   // State management
   void           Reset();
   void           Update();
   
   // Chart display
   void           UpdateChart();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPaperTrading::CPaperTrading() : m_balance(InpPaperInitialBalance),
                                m_equity(InpPaperInitialBalance),
                                m_totalTrades(0),
                                m_winningTrades(0),
                                m_losingTrades(0),
                                m_liveTrading(false),
                                m_slippage(0.0),
                                m_spread(0.0),
                                m_symbol(NULL),
                                m_account(NULL),
                                m_riskManager(NULL)
{
   m_trades.Clear();
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CPaperTrading::~CPaperTrading()
{
   Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize paper trading system                                  |
//+------------------------------------------------------------------+
bool CPaperTrading::Initialize(CSymbolInfo *symbol, CAccountInfo *account, 
                             CEnhancedRiskManager *riskManager)
{
   // Validate inputs
   if(symbol == NULL || account == NULL || riskManager == NULL) {
      Print("PaperTrading: Invalid initialization parameters");
      return false;
   }
   
   // Store references
   m_symbol = symbol;
   m_account = account;
   m_riskManager = riskManager;
   
   // Reset state
   Reset();
   
   // Initialize chart objects
   UpdateChart();
   
   return true;
}

//+------------------------------------------------------------------+
//| Clean up resources                                               |
//+------------------------------------------------------------------+
void CPaperTrading::Deinitialize()
{
   // Clean up resources
   m_trades.Clear();
   
   // Remove chart objects
   string prefix = "PaperTrade_";
   ObjectsDeleteAll(0, prefix);
   ChartRedraw();
   
   // Reset references
   m_symbol = NULL;
   m_account = NULL;
   m_riskManager = NULL;
}

//+------------------------------------------------------------------+
//| Open a new paper position                                        |
//+------------------------------------------------------------------+
bool CPaperTrading::OpenPosition(ENUM_ORDER_TYPE type, double volume, 
                               double price, double sl, double tp, 
                               string comment = "")
{
   // Check if paper trading is enabled
   if(!InpEnablePaperTrading) {
      m_liveTrading = true;
      return true; // Allow live trading
   }
   
   // Check if we have enough wins to trade live
   if(m_winningTrades >= InpPaperWinsRequired && m_totalTrades >= InpPaperTradesRequired) {
      m_liveTrading = true;
      return true; // Allow live trading
   }
   
   // Check if we've reached the maximum number of paper trades
   if(m_totalTrades >= InpPaperTradesRequired) {
      Print("PaperTrading: Maximum number of paper trades reached (", InpPaperTradesRequired, "). ", 
            m_winningTrades, " wins out of ", InpPaperWinsRequired, " required for live trading.");
      return false;
   }
   
   // Check risk management
   if(m_riskManager != NULL && !m_riskManager.IsTradingAllowed()) {
      Print("PaperTrading: Risk management restricts trading");
      return false;
   }
   
   // Check if we can simulate a fill
   if(!SimulateFill()) {
      Print("PaperTrading: Order fill simulation failed");
      return false;
   }
   
   // Calculate slippage if enabled
   double actualPrice = price;
   if(InpSimulateSlippage) {
      double slippage = CalculateSlippage();
      if(type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_BUY_STOP) {
         actualPrice += slippage;
      } else {
         actualPrice -= slippage;
      }
   }
   
   // Create new trade
   SPaperTrade *trade = new SPaperTrade();
   if(trade == NULL) {
      Print("PaperTrading: Failed to create new trade");
      return false;
   }
   
   // Initialize trade
   trade.ticket = (ulong)(TimeCurrent() % 1000000 + m_trades.Total());
   trade.symbol = m_symbol.Name();
   trade.type = type;
   trade.volume = volume;
   trade.openPrice = actualPrice;
   trade.stopLoss = sl;
   trade.takeProfit = tp;
   trade.openTime = TimeCurrent();
   trade.commission = CalculateCommission(volume, actualPrice);
   trade.swap = 0.0; // Will be updated on bar close
   trade.isClosed = false;
   trade.isWinner = false;
   
   // Add to trades array
   if(!m_trades.Add(trade)) {
      delete trade;
      Print("PaperTrading: Failed to add trade to array");
      return false;
   }
   
   // Update statistics
   m_totalTrades++;
   
   // Update balance (subtract margin, will be added back on close)
   double margin = m_riskManager != NULL ? 
                  m_riskManager.CalculateMargin(trade.symbol, trade.volume, trade.type) : 
                  (trade.volume * m_symbol.TickValue() * m_symbol.TickSize());
   m_balance -= margin;
   
   PrintFormat("PaperTrading: Opened %s position %.2f lots at %.5f (SL: %.5f, TP: %.5f)", 
              EnumToString(type), volume, actualPrice, sl, tp);
   
   // Update chart
   UpdateChart();
   
   return true;
}

//+------------------------------------------------------------------+
//| Close a paper position                                           |
//+------------------------------------------------------------------+
bool CPaperTrading::ClosePosition(ulong ticket, double price)
{
   for(int i = 0; i < m_trades.Total(); i++) {
      SPaperTrade *trade = m_trades.At(i);
      if(trade == NULL || trade.isClosed || trade.ticket != ticket) continue;
      
      // Calculate P/L
      double priceDiff = price - trade.openPrice;
      if(trade.type == ORDER_TYPE_SELL || trade.type == ORDER_TYPE_SELL_LIMIT || trade.type == ORDER_TYPE_SELL_STOP) {
         priceDiff = -priceDiff;
      }
      
      double pips = priceDiff / m_symbol.Point();
      double profit = pips * m_symbol.TickValue() * trade.volume / (m_symbol.Point() / m_symbol.TickSize());
      
      // Update trade info
      trade.closePrice = price;
      trade.closeTime = TimeCurrent();
      trade.profit = profit;
      trade.isClosed = true;
      
      // Update balance
      m_balance += profit - trade.commission - trade.swap;
      
      // Update statistics
      if(profit > 0) {
         m_winningTrades++;
      } else {
         m_losingTrades++;
      }
      
      // Update equity
      UpdateEquity();
      
      PrintFormat("PaperTrading: Closed position %d at %.5f, P/L: $%.2f", 
                 ticket, price, profit - trade.commission - trade.swap);
      
      // Update chart
      UpdateChart();
      
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check for exit conditions                                        |
//+------------------------------------------------------------------+
void CPaperTrading::CheckForExits()
{
   double bid = m_symbol.Bid();
   double ask = m_symbol.Ask();
   
   for(int i = m_trades.Total() - 1; i >= 0; i--) {
      SPaperTrade *trade = m_trades.At(i);
      if(trade == NULL || trade.isClosed) continue;
      
      // Check if position should be closed by stop loss or take profit
      double currentPrice = (trade.type == ORDER_TYPE_BUY || trade.type == ORDER_TYPE_BUY_LIMIT || trade.type == ORDER_TYPE_BUY_STOP) ? bid : ask;
      
      // Check stop loss
      if((trade.type == ORDER_TYPE_BUY || trade.type == ORDER_TYPE_BUY_LIMIT || trade.type == ORDER_TYPE_BUY_STOP) && 
         trade.stopLoss > 0 && currentPrice <= trade.stopLoss) {
         ClosePosition(trade.ticket, trade.stopLoss);
         trade.isWinner = false;
         continue;
      }
      
      if((trade.type == ORDER_TYPE_SELL || trade.type == ORDER_TYPE_SELL_LIMIT || trade.type == ORDER_TYPE_SELL_STOP) && 
         trade.stopLoss > 0 && currentPrice >= trade.stopLoss) {
         ClosePosition(trade.ticket, trade.stopLoss);
         trade.isWinner = false;
         continue;
      }
      
      // Check take profit
      if((trade.type == ORDER_TYPE_BUY || trade.type == ORDER_TYPE_BUY_LIMIT || trade.type == ORDER_TYPE_BUY_STOP) && 
         trade.takeProfit > 0 && currentPrice >= trade.takeProfit) {
         ClosePosition(trade.ticket, trade.takeProfit);
         trade.isWinner = true;
         continue;
      }
      
      if((trade.type == ORDER_TYPE_SELL || trade.type == ORDER_TYPE_SELL_LIMIT || trade.type == ORDER_TYPE_SELL_STOP) && 
         trade.takeProfit > 0 && currentPrice <= trade.takeProfit) {
         ClosePosition(trade.ticket, trade.takeProfit);
         trade.isWinner = true;
         continue;
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate commission for a trade                                 |
//+------------------------------------------------------------------+
double CPaperTrading::CalculateCommission(double volume, double price)
{
   // Default commission: $5 per lot
   return 5.0 * volume;
}

//+------------------------------------------------------------------+
//| Calculate swap for an open position                             |
//+------------------------------------------------------------------+
double CPaperTrading::CalculateSwap(double volume, double price, ENUM_ORDER_TYPE type)
{
   // Simulate swap based on position type and size
   double swapRate = (type == ORDER_TYPE_BUY) ? -0.5 : 0.2; // pips per lot per day
   return volume * swapRate * m_symbol.Point() * 10000.0;
}

//+------------------------------------------------------------------+
//| Calculate slippage for order execution                          |
//+------------------------------------------------------------------
double CPaperTrading::CalculateSlippage()
{
   if(!InpSimulateSlippage) return 0.0;
   
   // Random slippage up to max slippage
   return MathRand() / 32767.0 * InpMaxSlippagePips * m_symbol.Point();
}

//+------------------------------------------------------------------+
//| Simulate order fill probability                                  |
//+------------------------------------------------------------------+
bool CPaperTrading::SimulateFill()
{
   if(!InpSimulatePartialFills) return true;
   
   // Random chance of fill based on fill probability
   return (MathRand() % 100) < InpFillProbability;
}

//+------------------------------------------------------------------+
//| Update equity based on open positions                            |
//+------------------------------------------------------------------+
void CPaperTrading::UpdateEquity()
{
   double floatingPL = 0.0;
   double bid = m_symbol.Bid();
   double ask = m_symbol.Ask();
   double pointValue = m_symbol.Point() * m_symbol.TradeTickValue() / m_symbol.TradeTickSize();
   
   for(int i = 0; i < m_trades.Total(); i++) {
      SPaperTrade *trade = m_trades.At(i);
      if(trade == NULL || trade.isClosed) continue;
      
      if(trade.type == ORDER_TYPE_BUY) {
         floatingPL += (bid - trade.openPrice) * trade.volume * pointValue;
      } else {
         floatingPL += (trade.openPrice - ask) * trade.volume * pointValue;
      }
   }
   
   m_equity = m_balance + floatingPL;
}

//+------------------------------------------------------------------+
//| Reset paper trading account                                      |
//+------------------------------------------------------------------+
void CPaperTrading::Reset()
{
   // Clear existing trades
   m_trades.Clear();
   
   // Reset metrics
   m_balance = InpPaperInitialBalance;
   m_equity = InpPaperInitialBalance;
   m_totalTrades = 0;
   m_winningTrades = 0;
   m_losingTrades = 0;
   m_liveTrading = false;
   
   // Reset chart
   UpdateChart();
   
   Print("PaperTrading: Account reset");
}

//+------------------------------------------------------------------+
//| Update paper trading system                                      |
//+------------------------------------------------------------------+
void CPaperTrading::Update()
{
   // Update market data
   m_symbol.RefreshRates();
   
   // Check for exits
   CheckForExits();
   
   // Update equity
   UpdateEquity();
   
   // Update chart periodically
   static datetime lastUpdate = 0;
   if(TimeCurrent() - lastUpdate >= 1) {
      UpdateChart();
      lastUpdate = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Update chart with paper trading information                      |
//+------------------------------------------------------------------+
void CPaperTrading::UpdateChart()
{
   string prefix = "PaperTrade_";
   
   // Create or update info panel
   string objName = prefix + "Info";
   
   // Create or update info text
   string infoText = StringFormat("=== Paper Trading ===\n" +
                                "Balance: $%.2f\n" +
                                "Equity: $%.2f\n" +
                                "Trades: %d (%d wins, %d losses)\n" +
                                "Win Rate: %.1f%%\n" +
                                "Live Trading: %s",
                                m_balance, m_equity,
                                m_totalTrades, m_winningTrades, m_losingTrades,
                                GetWinRate(),
                                m_liveTrading ? "Enabled" : "Disabled");
   
   // Create or update the info label
   if(ObjectFind(0, objName) < 0) {
      ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 20);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 20);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, clrNavy);
      ObjectSetInteger(0, objName, OBJPROP_BACK, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, objName, OBJPROP_ZORDER, 0);
   }
   
   ObjectSetString(0, objName, OBJPROP_TEXT, infoText);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 8);
   
   // Update trade markers on chart
   for(int i = 0; i < m_trades.Total(); i++) {
      SPaperTrade *trade = m_trades.At(i);
      if(trade == NULL) continue;
      
      string tradePrefix = prefix + IntegerToString(trade.ticket) + "_";
      
      // Create or update entry marker
      string entryName = tradePrefix + "Entry";
      if(ObjectFind(0, entryName) < 0) {
         ObjectCreate(0, entryName, OBJ_ARROW, 0, trade.openTime, 
                     trade.type <= 1 ? trade.openPrice + 10 * m_symbol.Point() : trade.openPrice - 10 * m_symbol.Point());
         ObjectSetInteger(0, entryName, OBJPROP_ARROWCODE, trade.type <= 1 ? 233 : 234);
         ObjectSetInteger(0, entryName, OBJPROP_COLOR, trade.type <= 1 ? clrLime : clrRed);
         ObjectSetInteger(0, entryName, OBJPROP_WIDTH, 2);
      }
      
      // Create or update exit marker if closed
      if(trade.isClosed) {
         string exitName = tradePrefix + "Exit";
         if(ObjectFind(0, exitName) < 0) {
            ObjectCreate(0, exitName, OBJ_ARROW, 0, trade.closeTime, 
                        trade.type <= 1 ? trade.closePrice - 10 * m_symbol.Point() : trade.closePrice + 10 * m_symbol.Point());
            ObjectSetInteger(0, exitName, OBJPROP_ARROWCODE, 251);
            ObjectSetInteger(0, exitName, OBJPROP_COLOR, trade.isWinner ? clrLime : clrRed);
            ObjectSetInteger(0, exitName, OBJPROP_WIDTH, 2);
         }
      }
   }
   
   // Redraw the chart
   ChartRedraw();
   if(ObjectFind(0, objName) < 0) {
      ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 10);
      ObjectSetInteger(0, objName, OBJPROP_XSIZE, 200);
      ObjectSetInteger(0, objName, OBJPROP_YSIZE, 120);
      ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, clrWhiteSmoke);
      ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_BACK, false);
   }
   
   // Update info text
   string infoText = "=== Paper Trading ===\n";
   infoText += StringFormat("Balance: %.2f %s\n", m_balance, m_account.Currency());
   infoText += StringFormat("Equity: %.2f %s\n", m_equity, m_account.Currency());
   infoText += StringFormat("Trades: %d (%dW/%dL)\n", 
                           m_totalTrades, m_winningTrades, m_losingTrades);
   infoText += StringFormat("Win Rate: %.1f%%\n", GetWinRate());
   infoText += StringFormat("Status: %s", 
                           m_liveTrading ? "LIVE TRADING" : "PAPER TRADING");
   
   objName = prefix + "InfoText";
   if(ObjectFind(0, objName) < 0) {
      ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 15);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 15);
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrBlack);
      ObjectSetString(0, objName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 8);
   }
   ObjectSetString(0, objName, OBJPROP_TEXT, infoText);
   
   // Redraw chart
   ChartRedraw();
}
//+------------------------------------------------------------------+
