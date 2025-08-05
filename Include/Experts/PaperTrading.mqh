//+------------------------------------------------------------------+
//|                                              PaperTrading.mqh     |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Arrays\ArrayObj.mqh>
#include <Trade\PositionInfo.mqh>
#include "TradeExecutor.mqh"

//+------------------------------------------------------------------+
//| Paper Trade Position Class                                       |
//+------------------------------------------------------------------+
class CPosition : public CObject
{
public:
   ulong           ticket;           // Position ticket
   string          symbol;           // Symbol
   ENUM_POSITION_TYPE type;          // Position type
   double          volume;           // Position volume
   double          openPrice;        // Open price
   double          stopLoss;         // Stop loss level
   double          takeProfit;       // Take profit level
   datetime        openTime;         // Open time
   
   // Constructor
   CPosition(ulong t, string s, ENUM_POSITION_TYPE pt, double v, double op, 
            double sl, double tp, datetime ot) :
      ticket(t), symbol(s), type(pt), volume(v), openPrice(op), 
      stopLoss(sl), takeProfit(tp), openTime(ot) {}
      
   // Check if position is closed
   bool IsClosed() const { return volume <= 0; }
   
   // Calculate current profit
   double CalculateProfit(double currentBid, double currentAsk) const
   {
      if(IsClosed()) return 0.0;
      
      double profit = 0.0;
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      if(type == POSITION_TYPE_BUY)
      {
         profit = (currentBid - openPrice) * volume * SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE) / point;
      }
      else if(type == POSITION_TYPE_SELL)
      {
         profit = (openPrice - currentAsk) * volume * SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE) / point;
      }
      
      return profit;
   }
};

//+------------------------------------------------------------------+
//| Paper Trading Class                                              |
//+------------------------------------------------------------------+
class CPaperTrading
{
private:
   CArrayObj        m_positions;           // Array of open positions
   double           m_balance;             // Paper trading balance
   double           m_equity;              // Current equity
   double           m_margin;              // Used margin
   double           m_freeMargin;          // Free margin
   
   // Simulation parameters
   bool             m_simulateSlippage;    // Simulate slippage
   bool             m_simulatePartialFills; // Simulate partial fills
   double           m_maxSlippagePips;     // Maximum slippage in pips
   double           m_fillProbability;      // Probability of fill (0-1)
   
   // Statistics
   int              m_totalTrades;         // Total number of trades
   int              m_winningTrades;       // Number of winning trades
   int              m_losingTrades;        // Number of losing trades
   double           m_totalProfit;         // Total profit
   double           m_totalLoss;           // Total loss
   
   // Objects
   CSymbolInfo     *m_symbol;              // Pointer to symbol info
   
   // Private methods
   double           ApplySlippage(double price, ENUM_ORDER_TYPE type);
   double           ApplyPartialFill(double requestedVolume);
   void             UpdateMetrics();
   
public:
                     CPaperTrading();
                    ~CPaperTrading();
                    
   // Initialization
   bool              Initialize(CSymbolInfo *symbol, double initialBalance = 10000.0,
                              bool simulateSlippage = true, bool simulatePartialFills = true,
                              double maxSlippagePips = 1.0, double fillProbability = 0.95);
   
   // Trading operations
   bool              OpenPosition(ENUM_ORDER_TYPE type, double lots, double price,
                                double sl = 0, double tp = 0);
   bool              ClosePosition(ulong ticket, double lots = 0);
   bool              ModifyPosition(ulong ticket, double sl, double tp);
   
   // Position management
   bool              SelectPosition(ulong ticket, CPosition *&position);
   int               TotalPositions() const { return m_positions.Total(); }
   
   // Account information
   double            GetBalance() const { return m_balance; }
   double            GetEquity() const { return m_equity; }
   double            GetMargin() const { return m_margin; }
   double            GetFreeMargin() const { return m_freeMargin; }
   
   // Statistics
   int               GetTotalTrades() const { return m_totalTrades; }
   int               GetWinningTrades() const { return m_winningTrades; }
   int               GetLosingTrades() const { return m_losingTrades; }
   double            GetTotalProfit() const { return m_totalProfit; }
   double            GetTotalLoss() const { return m_totalLoss; }
   double            GetWinRate() const 
   { 
      return (m_totalTrades > 0) ? (double)m_winningTrades / m_totalTrades * 100.0 : 0.0; 
   }
   
   // Visualization
   void              UpdateVisualization();
   
   // Update method called on each tick
   void              Update();
   
   // Check if live trading is allowed based on paper trading results
   bool              IsLiveTradingAllowed();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPaperTrading::CPaperTrading() : m_balance(10000.0),
                               m_equity(10000.0),
                               m_margin(0.0),
                               m_freeMargin(10000.0),
                               m_simulateSlippage(true),
                               m_simulatePartialFills(true),
                               m_maxSlippagePips(1.0),
                               m_fillProbability(0.95),
                               m_totalTrades(0),
                               m_winningTrades(0),
                               m_losingTrades(0),
                               m_totalProfit(0.0),
                               m_totalLoss(0.0),
                               m_symbol(NULL)
{
   m_positions.Clear();
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CPaperTrading::~CPaperTrading()
{
   m_positions.Clear();
   m_symbol = NULL;
}

//+------------------------------------------------------------------+
//| Initialize paper trading                                         |
//+------------------------------------------------------------------+
bool CPaperTrading::Initialize(CSymbolInfo *symbol, double initialBalance,
                             bool simulateSlippage, bool simulatePartialFills,
                             double maxSlippagePips, double fillProbability)
{
   if(symbol == NULL || initialBalance <= 0)
   {
      Print("Error: Invalid parameters in PaperTrading initialization");
      return false;
   }
   
   m_symbol = symbol;
   m_balance = initialBalance;
   m_equity = initialBalance;
   m_freeMargin = initialBalance;
   
   // Set simulation parameters
   m_simulateSlippage = simulateSlippage;
   m_simulatePartialFills = simulatePartialFills;
   m_maxSlippagePips = maxSlippagePips;
   m_fillProbability = MathMax(0.0, MathMin(1.0, fillProbability));
   
   // Initialize statistics
   m_totalTrades = 0;
   m_winningTrades = 0;
   m_losingTrades = 0;
   m_totalProfit = 0.0;
   m_totalLoss = 0.0;
   
   return true;
}

//+------------------------------------------------------------------+
//| Open a new position                                              |
//+------------------------------------------------------------------+
bool CPaperTrading::OpenPosition(ENUM_ORDER_TYPE type, double lots, double price,
                               double sl, double tp)
{
   if(m_symbol == NULL || lots <= 0 || price <= 0)
   {
      Print("Error: Invalid parameters in OpenPosition");
      return false;
   }
   
   // Apply slippage if enabled
   double executionPrice = ApplySlippage(price, type);
   
   // Apply partial fill if enabled
   double filledLots = m_simulatePartialFills ? 
                      ApplyPartialFill(lots) : lots;
   
   if(filledLots <= 0)
   {
      Print("Order not filled (partial fill simulation)");
      return false;
   }
   
   // Generate a unique ticket
   static ulong lastTicket = 1000;
   ulong ticket = ++lastTicket;
   
   // Create and add the position
   CPosition *position = new CPosition(ticket, m_symbol.Name(), 
                                      (type == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL,
                                      filledLots, executionPrice, sl, tp, TimeCurrent());
   
   if(position == NULL)
   {
      Print("Error: Failed to create position object");
      return false;
   }
   
   m_positions.Add(position);
   
   // Update metrics
   UpdateMetrics();
   
   // Update statistics
   m_totalTrades++;
   
   return true;
}

//+------------------------------------------------------------------+
//| Close a position                                                 |
//+------------------------------------------------------------------+
bool CPaperTrading::ClosePosition(ulong ticket, double lots = 0)
{
   CPosition *position = NULL;
   
   // Find the position
   for(int i = 0; i < m_positions.Total(); i++)
   {
      CPosition *pos = m_positions.At(i);
      if(pos != NULL && pos.ticket == ticket && !pos.IsClosed())
      {
         position = pos;
         break;
      }
   }
   
   if(position == NULL)
   {
      Print("Error: Position not found or already closed");
      return false;
   }
   
   // Calculate close price with slippage
   double closePrice = ApplySlippage(
      (position.type == POSITION_TYPE_BUY) ? m_symbol.Bid() : m_symbol.Ask(),
      (position.type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY
   );
   
   // Calculate profit/loss
   double profit = 0.0;
   double point = m_symbol.Point();
   double tickValue = m_symbol.TickValue();
   
   if(position.type == POSITION_TYPE_BUY)
   {
      profit = (closePrice - position.openPrice) * position.volume * tickValue / point;
   }
   else // POSITION_TYPE_SELL
   {
      profit = (position.openPrice - closePrice) * position.volume * tickValue / point;
   }
   
   // Update balance and statistics
   m_balance += profit;
   
   if(profit >= 0)
   {
      m_winningTrades++;
      m_totalProfit += profit;
   }
   else
   {
      m_losingTrades++;
      m_totalLoss -= profit; // Loss is stored as positive value
   }
   
   // Close the position or reduce its volume
   if(lots <= 0 || lots >= position.volume)
   {
      // Close the entire position
      position.volume = 0;
   }
   else
   {
      // Partial close
      position.volume -= lots;
   }
   
   // Update metrics
   UpdateMetrics();
   
   return true;
}

//+------------------------------------------------------------------+
//| Modify position's stop loss and take profit                      |
//+------------------------------------------------------------------+
bool CPaperTrading::ModifyPosition(ulong ticket, double sl, double tp)
{
   CPosition *position = NULL;
   
   // Find the position
   for(int i = 0; i < m_positions.Total(); i++)
   {
      CPosition *pos = m_positions.At(i);
      if(pos != NULL && pos.ticket == ticket && !pos.IsClosed())
      {
         position = pos;
         break;
      }
   }
   
   if(position == NULL)
   {
      Print("Error: Position not found or already closed");
      return false;
   }
   
   // Update stop loss and take profit
   position.stopLoss = sl;
   position.takeProfit = tp;
   
   return true;
}

//+------------------------------------------------------------------+
//| Select position by ticket                                        |
//+------------------------------------------------------------------+
bool CPaperTrading::SelectPosition(ulong ticket, CPosition *&position)
{
   for(int i = 0; i < m_positions.Total(); i++)
   {
      CPosition *pos = m_positions.At(i);
      if(pos != NULL && pos.ticket == ticket && !pos.IsClosed())
      {
         position = pos;
         return true;
      }
   }
   
   position = NULL;
   return false;
}

//+------------------------------------------------------------------+
//| Apply slippage to price                                          |
//+------------------------------------------------------------------+
double CPaperTrading::ApplySlippage(double price, ENUM_ORDER_TYPE type)
{
   if(!m_simulateSlippage || m_maxSlippagePips <= 0)
      return price;
   
   // Generate random slippage (can be positive or negative)
   double slippagePips = ((double)MathRand() / 32767.0 - 0.5) * 2.0 * m_maxSlippagePips;
   double point = m_symbol.Point();
   
   // For buy orders, slippage is added to the price (worse execution)
   // For sell orders, slippage is subtracted from the price (worse execution)
   if(type == ORDER_TYPE_BUY)
      return price + slippagePips * point;
   else
      return price - slippagePips * point;
}

//+------------------------------------------------------------------+
//| Apply partial fill to order                                      |
//+------------------------------------------------------------------
double CPaperTrading::ApplyPartialFill(double requestedVolume)
{
   if(!m_simulatePartialFills || m_fillProbability >= 1.0)
      return requestedVolume;
   
   // Check if order is filled based on probability
   if(((double)MathRand() / 32767.0) > m_fillProbability)
      return 0.0; // Order not filled
   
   // For simplicity, we either fill the entire order or nothing
   // In a more advanced simulation, you could implement partial fills
   return requestedVolume;
}

//+------------------------------------------------------------------+
//| Update account metrics                                           |
//+------------------------------------------------------------------+
void CPaperTrading::UpdateMetrics()
{
   if(m_symbol == NULL)
      return;
   
   // Update current prices
   m_symbol.RefreshRates();
   
   // Calculate equity and margin
   double floatingProfit = 0.0;
   m_margin = 0.0;
   
   // Calculate floating P/L and used margin for all open positions
   for(int i = 0; i < m_positions.Total(); i++)
   {
      CPosition *pos = m_positions.At(i);
      if(pos != NULL && !pos.IsClosed())
      {
         // Calculate floating profit/loss
         if(pos.type == POSITION_TYPE_BUY)
         {
            floatingProfit += (m_symbol.Bid() - pos.openPrice) * pos.volume * 
                             m_symbol.TickValue() / m_symbol.Point();
         }
         else // POSITION_TYPE_SELL
         {
            floatingProfit += (pos.openPrice - m_symbol.Ask()) * pos.volume * 
                             m_symbol.TickValue() / m_symbol.Point();
         }
         
         // Calculate margin (simplified)
         m_margin += pos.volume * pos.openPrice / 100.0; // 1:100 leverage
      }
   }
   
   // Update equity and free margin
   m_equity = m_balance + floatingProfit;
   m_freeMargin = m_equity - m_margin;
}

//+------------------------------------------------------------------+
//| Update method called on each tick                                |
//+------------------------------------------------------------------+
void CPaperTrading::Update()
{
   // Update metrics and visualization
   UpdateMetrics();
   UpdateVisualization();
}

//+------------------------------------------------------------------+
//| Check if live trading is allowed based on paper trading results  |
//+------------------------------------------------------------------+
bool CPaperTrading::IsLiveTradingAllowed()
{
   // Check if we have enough trades
   if(m_totalTrades < 5) // Minimum number of trades required
      return false;
      
   // Check win rate (e.g., at least 60% win rate)
   double winRate = GetWinRate();
   if(winRate < 60.0)
      return false;
      
   // Check profit factor (e.g., at least 1.5)
   double profitFactor = (m_totalLoss != 0) ? m_totalProfit / m_totalLoss : m_totalProfit;
   if(profitFactor < 1.5)
      return false;
      
   // All conditions met, allow live trading
   return true;
}

//+------------------------------------------------------------------+
//| Update visualization                                             |
//+------------------------------------------------------------------+
void CPaperTrading::UpdateVisualization()
{
   // Update metrics first
   UpdateMetrics();
   
   // Create or update panel
   string panelName = "PaperTrading_Panel";
   
   // Create panel background
   if(ObjectFind(0, panelName) < 0)
   {
      ObjectCreate(0, panelName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, panelName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, panelName, OBJPROP_YDISTANCE, 150);
      ObjectSetInteger(0, panelName, OBJPROP_XSIZE, 200);
      ObjectSetInteger(0, panelName, OBJPROP_YSIZE, 120);
      ObjectSetInteger(0, panelName, OBJPROP_BGCOLOR, clrWhiteSmoke);
      ObjectSetInteger(0, panelName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, panelName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, panelName, OBJPROP_COLOR, clrDimGray);
      ObjectSetInteger(0, panelName, OBJPROP_BACK, false);
   }
   
   // Create or update title
   string titleName = panelName + "_Title";
   if(ObjectFind(0, titleName) < 0)
   {
      ObjectCreate(0, titleName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, titleName, OBJPROP_COLOR, clrBlack);
      ObjectSetInteger(0, titleName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, titleName, OBJPROP_XDISTANCE, 20);
      ObjectSetInteger(0, titleName, OBJPROP_YDISTANCE, 160);
      ObjectSetInteger(0, titleName, OBJPROP_FONTSIZE, 10);
   }
   ObjectSetString(0, titleName, OBJPROP_TEXT, "PAPER TRADING");
   
   // Create or update balance label
   string balanceName = panelName + "_Balance";
   if(ObjectFind(0, balanceName) < 0)
   {
      ObjectCreate(0, balanceName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, balanceName, OBJPROP_COLOR, clrBlack);
      ObjectSetInteger(0, balanceName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, balanceName, OBJPROP_XDISTANCE, 20);
      ObjectSetInteger(0, balanceName, OBJPROP_YDISTANCE, 180);
      ObjectSetInteger(0, balanceName, OBJPROP_FONTSIZE, 9);
   }
   ObjectSetString(0, balanceName, OBJPROP_TEXT, "Balance: " + DoubleToString(m_balance, 2));
   
   // Create or update equity label
   string equityName = panelName + "_Equity";
   if(ObjectFind(0, equityName) < 0)
   {
      ObjectCreate(0, equityName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, equityName, OBJPROP_COLOR, clrBlack);
      ObjectSetInteger(0, equityName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, equityName, OBJPROP_XDISTANCE, 20);
      ObjectSetInteger(0, equityName, OBJPROP_YDISTANCE, 200);
      ObjectSetInteger(0, equityName, OBJPROP_FONTSIZE, 9);
   }
   ObjectSetString(0, equityName, OBJPROP_TEXT, "Equity: " + DoubleToString(m_equity, 2));
   
   // Create or update margin label
   string marginName = panelName + "_Margin";
   if(ObjectFind(0, marginName) < 0)
   {
      ObjectCreate(0, marginName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, marginName, OBJPROP_COLOR, clrBlack);
      ObjectSetInteger(0, marginName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, marginName, OBJPROP_XDISTANCE, 20);
      ObjectSetInteger(0, marginName, OBJPROP_YDISTANCE, 220);
      ObjectSetInteger(0, marginName, OBJPROP_FONTSIZE, 9);
   }
   ObjectSetString(0, marginName, OBJPROP_TEXT, "Margin: " + DoubleToString(m_margin, 2));
   
   // Create or update free margin label
   string freeMarginName = panelName + "_FreeMargin";
   if(ObjectFind(0, freeMarginName) < 0)
   {
      ObjectCreate(0, freeMarginName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, freeMarginName, OBJPROP_COLOR, clrBlack);
      ObjectSetInteger(0, freeMarginName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, freeMarginName, OBJPROP_XDISTANCE, 20);
      ObjectSetInteger(0, freeMarginName, OBJPROP_YDISTANCE, 240);
      ObjectSetInteger(0, freeMarginName, OBJPROP_FONTSIZE, 9);
   }
   ObjectSetString(0, freeMarginName, OBJPROP_TEXT, "Free Margin: " + DoubleToString(m_freeMargin, 2));
   
   // Update the chart
   ChartRedraw();
}
//+------------------------------------------------------------------+
