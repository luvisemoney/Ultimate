//+------------------------------------------------------------------+
//|                             OTC Escape EA (Learning)              |
//|                        Optimized for OTC Markets                  |
//|                              With Machine Learning                |
//+------------------------------------------------------------------+
#property version   "1.10"
#property strict

//--- Include files
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>  
#include <Trade\AccountInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Arrays\ArrayObj.mqh>
#include <OTCTypes.mqh>
#include <OTCLearningEngine.mqh>
#include <MarketAnalysis.mqh>

//--- Global Objects
CPositionInfo  m_position;                   // trade position object
CTrade         m_trade;                      // trading object
CSymbolInfo    m_symbol;                     // symbol info object
CAccountInfo   m_account;                    // account info wrapper
CDealInfo      m_deal;                       // deals object
COrderInfo     m_order;                      // pending orders object
CMarketAnalysis* market_analysis = NULL;     // market analysis object
CLearningEngine* learning_engine = NULL;     // learning engine object

//--- Indicator Handles and Buffers
int          handle_ma_fast;                // Handle for fast MA
int          handle_ma_slow;                // Handle for slow MA
double       ma_fast[];                     // Buffer for fast MA
double       ma_slow[];                     // Buffer for slow MA

//--- Input Parameters (Optimized for OTC Markets)
input ushort InpTakeProfit = 40;            // TakeProfit for positions (points)
input ushort InpStopLoss = 30;              // StopLoss for positions (points)
input bool   InpUseStopLoss = true;         // Use stop loss
input bool   InpUseTakeProfit = true;       // Use take profit
input string InpName_Expert  = "OTC_Escape_Learning"; // Expert Name
input ulong  InpSlippage     = 3;            // Slippage (points)
input bool   UseSound        = false;        // Enable sounds
input string NameFileSound   = "Alert.wav";  // Sound file
input double InpLots         = 0.02;         // Lot size
input int    InpMAPeriod1    = 5;            // Fast MA Period
input int    InpMAPeriod2    = 10;           // Slow MA Period
input ENUM_MA_METHOD InpMAMethod = MODE_SMA; // MA Method
input ENUM_APPLIED_PRICE InpMAPrice = PRICE_CLOSE; // MA Price

//--- Spread Settings
input group "=== Spread Settings ==="
input bool   InpUseDynamicSpread = true;    // Use dynamic spread limits
input int    InpMaxSpread = 30;             // Default max spread (points)
input int    InpMaxSpreadForex = 20;        // Max spread for forex (points)
input int    InpMaxSpreadGold = 100;        // Max spread for gold (points)
input int    InpMaxSpreadCrypto = 200;      // Max spread for crypto (points)

//--- Order Settings
input group "=== Order Settings ==="
enum ENUM_ORDER_TYPE_MODE {
   ORDER_MARKET = 0,      // Market orders
   ORDER_PENDING_STOP = 1, // Stop orders
   ORDER_PENDING_LIMIT = 2,// Limit orders
   ORDER_BOTH = 3         // Both stop and limit orders
};

input ENUM_ORDER_TYPE_MODE InpOrderType = ORDER_MARKET; // Order type
input double InpPendingOrderDistance = 10.0; // Distance for pending orders (points)
input bool   InpHedgingAllowed = true;      // Allow hedging positions
input int    InpMaxOpenTrades = 5;          // Maximum number of open trades

//--- Trading Hours
input group "=== Trading Hours ==="
input bool   InpUseTimeFilter = true;       // Use time filter
input int    InpStartHour    = 1;           // Start trading hour (broker time)
input int    InpEndHour      = 22;          // End trading hour (broker time)
input double InpRiskPercent  = 2.0;         // Risk per trade (%)
input bool   InpUseLearning  = true;        // Enable learning engine
input double InpLearningRate = 0.1;         // Learning rate (0.01-1.0)

//--- Global Variables
ulong        m_magic = 987570;              // Magic number (changed from original)
int          m_digits_adjust = 1;           // Digits adjustment
bool         m_is_otc = true;               // OTC market flag
bool         m_learning_initialized = false; // Learning engine initialized flag

//| Get maximum spread for specific symbol                          |
//+------------------------------------------------------------------+
int GetMaxSpreadForSymbol(string symbol)
{
   if(!InpUseDynamicSpread)
      return InpMaxSpread;
      
   // Check for gold
   if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
      return InpMaxSpreadGold;
      
   // Check for crypto
   if(StringFind(symbol, "BTC") >= 0 || StringFind(symbol, "ETH") >= 0)
      return InpMaxSpreadCrypto;
      
   // Default for forex majors
   if(StringFind(symbol, "EURUSD") >= 0 || 
      StringFind(symbol, "GBPUSD") >= 0 ||
      StringFind(symbol, "USDJPY") >= 0)
      return 10;  // Tighter spread for majors
      
   return InpMaxSpread;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialize symbol and trading objects
   m_symbol.Name(Symbol());
   m_trade.SetExpertMagicNumber(m_magic);
   m_trade.SetDeviationInPoints(InpSlippage);
   m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   //--- Check if symbol is valid for OTC trading
   if(!IsOTCSymbol())
   {
      Print("Warning: This EA is optimized for OTC symbols. Current symbol: ", Symbol());
      m_is_otc = false;
   }
   
   //--- Initialize indicator handles
   handle_ma_fast = iMA(Symbol(), Period(), InpMAPeriod1, 0, InpMAMethod, InpMAPrice);
   handle_ma_slow = iMA(Symbol(), Period(), InpMAPeriod2, 0, InpMAMethod, InpMAPrice);
   
   //--- Check if indicator handles are valid
   if(handle_ma_fast == INVALID_HANDLE || handle_ma_slow == INVALID_HANDLE)
   {
      Print("Error creating indicator handles");
      return(INIT_FAILED);
   }
   
   // Initialize market analysis
   market_analysis = new CMarketAnalysis(handle_ma_fast, handle_ma_slow);
   if(market_analysis == NULL)
   {
      Print("Failed to create market analysis object");
      return(INIT_FAILED);
   }
   
   //--- Initialize learning engine if enabled
   if(InpUseLearning)
   {
      learning_engine = new CLearningEngine();
      if(learning_engine != NULL)
      {
         m_learning_initialized = learning_engine.LoadTradeHistory();
         Print("Learning engine initialized: ", m_learning_initialized ? "Success" : "Failed");
      }
      
      // Initialize market analysis
      int ma_fast_handle = iMA(NULL, 0, InpMAPeriod1, 0, InpMAMethod, InpMAPrice);
      int ma_slow_handle = iMA(NULL, 0, InpMAPeriod2, 0, InpMAMethod, InpMAPrice);
      market_analysis = new CMarketAnalysis(ma_fast_handle, ma_slow_handle);
   }
   
   //--- Adjust for 3/5 digit brokers
   m_digits_adjust = (m_symbol.Digits() == 3 || m_symbol.Digits() == 5) ? 10 : 1;
   
   //--- Check if we have enough bars
   if(Bars(Symbol(), Period()) < 100)
   {
      Print("Not enough bars");
      return(INIT_FAILED);
   }
   
   //--- All initialization successful
   Print("OTC Escape EA with Learning initialized successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up market analysis
   if(market_analysis != NULL)
   {
      delete market_analysis;
      market_analysis = NULL;
   }
   
   // Clean up learning engine
   if(learning_engine != NULL)
   {
      // Save learning data before deletion
      if(m_learning_initialized)
         learning_engine.SaveTradeHistory();
         
      delete learning_engine;
      learning_engine = NULL;
   }
   
   //--- Release indicator handles
   if(handle_ma_fast != INVALID_HANDLE)
      IndicatorRelease(handle_ma_fast);
   if(handle_ma_slow != INVALID_HANDLE)
      IndicatorRelease(handle_ma_slow);
      
   Comment("");
   Print("EA deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check for new bar
   static datetime last_bar = 0;
   datetime current_bar = (datetime)SeriesInfoInteger(Symbol(), Period(), SERIES_LASTBAR_DATE);
   if(last_bar == current_bar)
      return;
   last_bar = current_bar;
   
   //--- Check if we can trade
   if(!CanTrade())
      return;
   
   //--- Check for open positions
   if(PositionsTotal() > 0)
   {
      CheckForClose();
      return;
   }
   
   //--- Check for new trading signals
   CheckForOpen();
}

//+------------------------------------------------------------------+
//| Check if we can trade                                            |
//+------------------------------------------------------------------+
bool CanTrade()
{
   //--- Check if learning engine is initialized and has enough data
   if(InpUseLearning && m_learning_initialized && learning_engine != NULL)
   {
      int total_trades = learning_engine.GetTotalTrades();
      
      // If we have enough trades in history, check performance
      if(total_trades >= 10) // Minimum trades before making decisions
      {
         double win_rate = 0, profit_factor = 0, avg_win = 0, avg_loss = 0;
         learning_engine.GetPerformanceStats(win_rate, profit_factor, avg_win, avg_loss);
         
         // If performance is too poor, don't trade
         if(profit_factor < 0.8) // Arbitrary threshold
         {
            Print("Trading paused: Poor historical performance (PF: ", profit_factor, ")");
            return false;
         }
      }
   }
   
   //--- Check if market is open
   if(m_is_otc)
   {
      if(InpUseTimeFilter)
      {
         datetime time = TimeCurrent();
         MqlDateTime tm;
         TimeToStruct(time, tm);
         
         if(tm.hour < InpStartHour || tm.hour >= InpEndHour)
            return false;
      }
   }
   
   //--- Check spread with dynamic limits
   double spread = m_symbol.Ask() - m_symbol.Bid();
   int maxSpread = GetMaxSpreadForSymbol(m_symbol.Name());
   double spreadPoints = spread / m_symbol.Point();
   
   if(spreadPoints > maxSpread)
   {
      Print("Spread too high: ", DoubleToString(spreadPoints, 1), " points (max: ", maxSpread, ")");
      return false;
   }
   
   //--- Check if we have enough money
   if(m_account.FreeMargin() < (1000 * InpLots))
   {
      Print("Not enough free margin. Free Margin = ", m_account.FreeMargin());
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate lot size based on account balance and risk            |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   double account_risk = AccountInfoDouble(ACCOUNT_BALANCE) * (InpRiskPercent / 100.0);
   double point_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double risk_based_lots = NormalizeDouble(account_risk / (InpStopLoss * point_value), 2);
   double final_lots = MathMin(risk_based_lots, InpLots);
   
   return final_lots;
}

//+------------------------------------------------------------------+
//| Calculate market volatility using ATR                            |
//+------------------------------------------------------------------+
double CalculateVolatility()
{
   double atr[];
   int atr_handle = iATR(_Symbol, PERIOD_CURRENT, 14);
   
   if(atr_handle == INVALID_HANDLE)
   {
      Print("Error getting ATR handle");
      return 0.0;
   }
   
   // Copy ATR values
   if(CopyBuffer(atr_handle, 0, 0, 1, atr) <= 0)
   {
      Print("Error copying ATR buffer");
      return 0.0;
   }
   
   // Convert ATR to points
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double atr_points = atr[0] / point;
   
   // Normalize to a 0-1 range based on typical values
   double normalized_volatility = MathMin(atr_points / 100.0, 1.0);
   
   return normalized_volatility;
}

//+------------------------------------------------------------------+
//| Calculate trend strength using ADX                               |
//+------------------------------------------------------------------+
double CalculateTrendStrength()
{
   double adx[];
   int adx_handle = iADX(_Symbol, PERIOD_CURRENT, 14);
   
   if(adx_handle == INVALID_HANDLE)
   {
      Print("Error getting ADX handle");
      return 0.5; // Neutral value
   }
   
   // Copy ADX values
   if(CopyBuffer(adx_handle, 0, 0, 1, adx) <= 0)
   {
      Print("Error copying ADX buffer");
      return 0.5; // Neutral value
   }
   
   // Normalize ADX to 0-1 range (0-50 is typical for ADX)
   double normalized_strength = MathMin(adx[0] / 50.0, 1.0);
   
   return normalized_strength;
}

//+------------------------------------------------------------------+
//| Check for open positions                                         |
//+------------------------------------------------------------------+
void CheckForOpen()
{
   if(!RefreshRates())
      return;
      
   //--- Get current market conditions
   double current_volatility = CalculateVolatility();
   double current_spread = (m_symbol.Ask() - m_symbol.Bid()) / m_symbol.Point();
   double current_trend_strength = CalculateTrendStrength();
   
   //--- Get learning-based parameters if enabled
   double tp_long = InpTakeProfit;
   double sl_long = InpStopLoss;
   double tp_short = InpTakeProfit;
   double sl_short = InpStopLoss;
   
   // Initialize stop_loss and take_profit variables
   double stop_loss = 0.0;
   double take_profit = 0.0;
   
   if(InpUseLearning && m_learning_initialized && learning_engine != NULL)
   {
      double learned_tp = 0, learned_sl = 0, learned_ma_fast = 0, learned_ma_slow = 0;
      learning_engine.GetOptimizedParameters(learned_tp, learned_sl, learned_ma_fast, learned_ma_slow);
      
      // Blend learned parameters with defaults (50/50 weight)
      if(learned_tp > 0) tp_long = (tp_long + learned_tp) / 2.0;
      if(learned_sl > 0) sl_long = (sl_long + learned_sl) / 2.0;
      if(learned_tp > 0) tp_short = (tp_short + learned_tp) / 2.0;
      if(learned_sl > 0) sl_short = (sl_short + learned_sl) / 2.0;
      
      // Ensure minimum values
      tp_long = MathMax(tp_long, 10);
      sl_long = MathMax(sl_long, 10);
      tp_short = MathMax(tp_short, 10);
      sl_short = MathMax(sl_short, 10);
   }
   
   //--- Calculate risk-based position size
   double account_risk = AccountInfoDouble(ACCOUNT_BALANCE) * (InpRiskPercent / 100.0);
   double point_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double risk_based_lots = NormalizeDouble(account_risk / (sl_long * point_value), 2);
   double final_lots = MathMin(risk_based_lots, InpLots);
   
   //--- Get indicator values
   double ma_fast[2], ma_slow[2];
   if(CopyBuffer(handle_ma_fast, 0, 0, 2, ma_fast) <= 0 ||
      CopyBuffer(handle_ma_slow, 0, 0, 2, ma_slow) <= 0)
   {
      Print("Error copying indicator buffers");
      return;
   }
   
   //--- Check for buy signal
   bool buy_signal = (ma_fast[1] <= ma_slow[1] && ma_fast[0] > ma_slow[0]);
   bool sell_signal = (ma_fast[1] >= ma_slow[1] && ma_fast[0] < ma_slow[0]);
   
   //--- Check with learning engine if enabled
   if(InpUseLearning && m_learning_initialized && learning_engine != NULL)
   {
      ENUM_POSITION_TYPE ml_signal = learning_engine.AnalyzeMarket(
         current_volatility, current_spread, current_trend_strength);
         
      if(ml_signal != WRONG_VALUE)
      {
         // Override signals based on learning engine
         buy_signal = (ml_signal == POSITION_TYPE_BUY);
         sell_signal = (ml_signal == POSITION_TYPE_SELL);
      }
   }
   
   //--- Execute trades
   if(buy_signal)
   {
      OpenBuy(final_lots, tp_long, sl_long);
      return;
   }
   
   if(sell_signal)
   {
      OpenSell(final_lots, tp_short, sl_short);
      return;
   }
}

//+------------------------------------------------------------------+
//| Check for close positions                                        |
//+------------------------------------------------------------------+
void CheckForClose()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == Symbol() && m_position.Magic() == m_magic)
         {
            if(m_position.PositionType() == POSITION_TYPE_BUY)
            {
               if(m_position.Profit() > 0 && 
                  m_symbol.Bid() >= m_position.PriceOpen() + InpTakeProfit * m_symbol.Point())
               {
                  ClosePosition(m_position.Ticket(), m_position.Profit());
               }
               else if(m_symbol.Bid() <= m_position.PriceOpen() - InpStopLoss * m_symbol.Point())
               {
                  ClosePosition(m_position.Ticket(), m_position.Profit());
               }
            }
            else
            {
               if(m_position.Profit() > 0 && 
                  m_symbol.Ask() <= m_position.PriceOpen() - InpTakeProfit * m_symbol.Point())
               {
                  ClosePosition(m_position.Ticket(), m_position.Profit());
               }
               else if(m_symbol.Ask() >= m_position.PriceOpen() + InpStopLoss * m_symbol.Point())
               {
                  ClosePosition(m_position.Ticket(), m_position.Profit());
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Close a position and record the trade                            |
//+------------------------------------------------------------------+
void ClosePosition(ulong ticket, double profit)
{
   // Get position details before closing
   if(!m_position.SelectByTicket(ticket))
   {
      Print("Failed to select position with ticket: ", ticket);
      return;
   }
   
   // Close the position
   m_trade.PositionClose(ticket);
   
   // Record the trade in the learning engine
   if(InpUseLearning && m_learning_initialized && learning_engine != NULL)
   {
      STradeRecord trade;
      trade.entry_time = m_position.Time();
      trade.exit_time = TimeCurrent();
      trade.entry_price = m_position.PriceOpen();
      trade.exit_price = (m_position.PositionType() == POSITION_TYPE_BUY) ? m_symbol.Bid() : m_symbol.Ask();
      trade.profit = profit;
      trade.lot_size = m_position.Volume();
      trade.hold_time = (int)(trade.exit_time - trade.entry_time);
      trade.spread = (m_symbol.Ask() - m_symbol.Bid()) / m_symbol.Point();
      trade.volatility = CalculateVolatility();
      trade.trend_strength = CalculateTrendStrength();
      trade.CalculateMetrics();
      
      // Add the trade to the learning engine
      learning_engine.AddTrade(trade);
      
      // Log the learning update
      double win_rate = 0, profit_factor_val = 0, avg_win = 0, avg_loss = 0;
      int total_trades = 0;
      
      // Get performance stats
      win_rate = learning_engine.GetWinRate();
      profit_factor_val = learning_engine.GetProfitFactor();
      avg_win = learning_engine.GetAverageWin();
      avg_loss = learning_engine.GetAverageLoss();
      total_trades = learning_engine.GetTotalTrades();
      
      Print("Learning update - Trades: ", total_trades, 
            " Win Rate: ", DoubleToString(win_rate * 100, 2), "%",
            " Profit Factor: ", DoubleToString(profit_factor_val, 2),
            " Avg Win: ", DoubleToString(avg_win, 2),
            " Avg Loss: ", DoubleToString(avg_loss, 2));
      
      // Save the updated trade history
      learning_engine.SaveTradeHistory();
   }
   
   if(UseSound)
      PlaySound(NameFileSound);
}

//+------------------------------------------------------------------+
//| Open Buy position                                                |
//+------------------------------------------------------------------+
void OpenBuy(double lots, double tp_points, double sl_points)
{
   //--- Check for buy condition
   if(ma_fast[0] > ma_slow[0] && ma_fast[1] <= ma_slow[1])
   {
      if(market_analysis != NULL && !market_analysis.ValidateTradeSetup(POSITION_TYPE_BUY))
      {
         Print("Buy setup validation failed");
         return;
      }
      
      double lot = CalculateLotSize();
      double price = m_symbol.Ask();
      
      // Declare variables at the function scope
      double take_profit = 0.0;
      double stop_loss = 0.0;
      double trade_stop_loss = 0.0;
      double trade_take_profit = 0.0;
      
      // Calculate take profit and stop loss levels
      if(InpUseTakeProfit)
         take_profit = NormalizeDouble(price + InpTakeProfit * m_symbol.Point(), m_symbol.Digits());
      if(InpUseStopLoss)
         stop_loss = NormalizeDouble(price - InpStopLoss * m_symbol.Point(), m_symbol.Digits());
         
      // Store these values for later use in trade logging
      trade_stop_loss = stop_loss;
      trade_take_profit = take_profit;
      
      // Handle different order types
      bool order_placed = false;
      
      // Market order
      if(InpOrderType == ORDER_MARKET)
      {
         if(!m_trade.Buy(lot, _Symbol, 0, stop_loss, take_profit, "EA Buy Market"))
         {
            Print("Market buy order failed with error: ", GetLastError());
         }
         else
         {
            Print("Market buy order placed successfully");
            order_placed = true;
         }
      }
      
      // Pending stop order (buy stop)
      if(InpOrderType == ORDER_PENDING_STOP || InpOrderType == ORDER_BOTH)
      {
         double stop_price = price + InpPendingOrderDistance * m_symbol.Point();
         if(!m_trade.BuyStop(lot, stop_price, _Symbol, stop_loss, take_profit, ORDER_TIME_GTC, 0, "EA Buy Stop"))
         {
            Print("Buy stop order failed with error: ", GetLastError());
         }
         else
         {
            Print("Buy stop order placed at ", stop_price);
            order_placed = true;
         }
      }
      
      // Pending limit order (buy limit)
      if(InpOrderType == ORDER_PENDING_LIMIT || (InpOrderType == ORDER_BOTH && !order_placed))
      {
         double limit_price = price - InpPendingOrderDistance * m_symbol.Point();
         if(!m_trade.BuyLimit(lot, limit_price, _Symbol, stop_loss, take_profit, ORDER_TIME_GTC, 0, "EA Buy Limit"))
         {
            Print("Buy limit order failed with error: ", GetLastError());
         }
         else
         {
            Print("Buy limit order placed at ", limit_price);
            order_placed = true;
         }
      }
      
      // Add to learning engine if order was placed
      if(order_placed && InpUseLearning && learning_engine != NULL)
      {
         STradeRecord trade;
         trade.entry_time = TimeCurrent();
         trade.entry_price = price;
         trade.lot_size = lot;
         trade.stop_loss = trade_stop_loss;
         trade.take_profit = trade_take_profit;
         trade.spread = m_symbol.Spread();
         trade.volatility = CalculateVolatility();
         trade.trend_strength = 0.0; // Will be updated later
         learning_engine.AddTrade(trade);
      }
   }   
}

//+------------------------------------------------------------------+
//| Open sell position                                                |
//+------------------------------------------------------------------+
void OpenSell(double lots, double tp_points, double sl_points)
{
   //--- Check for sell condition
   if(ma_fast[0] < ma_slow[0] && ma_fast[1] >= ma_slow[1])
   {
      if(market_analysis != NULL && !market_analysis.ValidateTradeSetup(POSITION_TYPE_SELL))
      {
         Print("Sell setup validation failed");
         return;
      }
      
      double lot = CalculateLotSize();
      double price = m_symbol.Bid();
      
      // Declare variables at the function scope
      double take_profit = 0.0;
      double stop_loss = 0.0;
      double trade_stop_loss = 0.0;
      double trade_take_profit = 0.0;
      
      // Calculate take profit and stop loss levels
      if(InpUseTakeProfit)
         take_profit = NormalizeDouble(price - InpTakeProfit * m_symbol.Point(), m_symbol.Digits());
      if(InpUseStopLoss)
         stop_loss = NormalizeDouble(price + InpStopLoss * m_symbol.Point(), m_symbol.Digits());
         
      // Store these values for later use in trade logging
      trade_stop_loss = stop_loss;
      trade_take_profit = take_profit;
      
      // Handle different order types
      bool order_placed = false;
      
      // Market order
      if(InpOrderType == ORDER_MARKET)
      {
         if(!m_trade.Sell(lot, _Symbol, 0, stop_loss, take_profit, "EA Sell Market"))
         {
            Print("Market sell order failed with error: ", GetLastError());
         }
         else
         {
            Print("Market sell order placed successfully");
            order_placed = true;
         }
      }
      
      // Pending stop order (sell stop)
      if(InpOrderType == ORDER_PENDING_STOP || InpOrderType == ORDER_BOTH)
      {
         double stop_price = price - InpPendingOrderDistance * m_symbol.Point();
         if(!m_trade.SellStop(lot, stop_price, _Symbol, stop_loss, take_profit, ORDER_TIME_GTC, 0, "EA Sell Stop"))
         {
            Print("Sell stop order failed with error: ", GetLastError());
         }
         else
         {
            Print("Sell stop order placed at ", stop_price);
            order_placed = true;
         }
      }
      
      // Pending limit order (sell limit)
      if(InpOrderType == ORDER_PENDING_LIMIT || (InpOrderType == ORDER_BOTH && !order_placed))
      {
         double limit_price = price + InpPendingOrderDistance * m_symbol.Point();
         if(!m_trade.SellLimit(lot, limit_price, _Symbol, stop_loss, take_profit, ORDER_TIME_GTC, 0, "EA Sell Limit"))
         {
            Print("Sell limit order failed with error: ", GetLastError());
         }
         else
         {
            Print("Sell limit order placed at ", limit_price);
            order_placed = true;
         }
      }
      
      // Add to learning engine if order was placed
      if(order_placed && InpUseLearning && learning_engine != NULL)
      {
         STradeRecord trade;
         trade.entry_time = TimeCurrent();
         trade.entry_price = price;
         trade.lot_size = lot;
         trade.stop_loss = trade_stop_loss;
         trade.take_profit = trade_take_profit;
         trade.spread = m_symbol.Spread();
         trade.volatility = CalculateVolatility();
         trade.trend_strength = 0.0; // Will be updated later
         learning_engine.AddTrade(trade);
      }
   }
}



//+------------------------------------------------------------------+
//| Check if the current symbol is suitable for OTC trading          |
//+------------------------------------------------------------------+
bool IsOTCSymbol(string symbol = NULL)
{
   if(symbol == NULL)
      symbol = Symbol();
      
   // Check if the symbol contains common OTC market identifiers
   if(StringFind(symbol, "OTC") >= 0 || 
      StringFind(symbol, "CFD") >= 0 || 
      StringFind(symbol, "_") >= 0)
   {
      return true;
   }
   
   // Check for major forex pairs (not OTC)
   string major_pairs[] = {"EURUSD", "GBPUSD", "USDJPY", "USDCHF", "AUDUSD", "USDCAD", "NZDUSD"};
   for(int i = 0; i < ArraySize(major_pairs); i++)
   {
      if(StringFind(symbol, major_pairs[i]) >= 0)
         return false;
   }
   
   // If we get here, assume it's an OTC symbol
   return true;
}

//+------------------------------------------------------------------+
//| Refresh rates and check for errors                               |
//+------------------------------------------------------------------+
bool RefreshRates()
{
   if(!m_symbol.RefreshRates())
   {
      Print("Error refreshing symbol data");
      return false;
   }
   
   if(m_symbol.Ask() == 0 || m_symbol.Bid() == 0)
   {
      Print("Invalid price data");
      return false;
   }
   
   return true;
}
//+------------------------------------------------------------------+
