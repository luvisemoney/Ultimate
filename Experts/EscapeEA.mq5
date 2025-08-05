//+------------------------------------------------------------------+
//|                                                   EscapeEA.mq5    |
//|                                          Copyright 2025, EscapeEA |
//|                                             https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "2.00"  // Major version bump for TradeExecutor integration
#property strict

/**
 * @file EscapeEA.mq5
 * @brief Advanced Expert Advisor with integrated TradeExecutor for secure trading
 * 
 * This EA implements a sophisticated trading strategy with the following features:
 * - Multi-timeframe analysis using moving averages
 * - Paper trading simulation with win requirement for live trading
 * - Advanced risk management with position sizing
 * - Secure trade execution with circuit breaker protection
 * - Comprehensive logging and monitoring
 * 
 * @see TradeExecutor.mqh For trade execution details
 * @see RiskManager.mqh For risk management
 */

//--- Required Includes
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include "Escape\TradeExecutor.mqh"
#include "Escape\RiskManager.mqh"

//--- Strategy Parameters
input group "=== Strategy Settings ==="
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M15;   // Chart timeframe
input int      InpMAPeriod = 20;                   // MA Period
input int      InpMAFastPeriod = 10;               // Fast MA Period
input int      InpMASlowPeriod = 50;               // Slow MA Period
input int      InpATRPeriod = 14;                  // ATR Period for volatility
input double   InpATRMultiplier = 2.0;             // ATR Multiplier for SL/TP

//--- Risk Management
input group "=== Risk Management ==="
input double   InpRiskPerTrade = 1.0;              // Risk per trade (% of balance)
input bool     InpUseFixedLot = false;             // Use fixed lot size
input double   InpLotSize = 0.1;                   // Fixed lot size (if UseFixedLot = true)
input double   InpMaxLotSize = 10.0;               // Maximum lot size
input int      InpMaxOpenTrades = 5;               // Maximum number of open trades
input bool     InpHedgeAllowed = false;            // Allow hedging positions

//--- Trade Execution
input group "=== Trade Execution ==="
input int      InpMaxSlippage = 10;                // Maximum allowed slippage (points)
input bool     InpUseTrailingStop = true;          // Use Trailing Stop
input int      InpTrailingStop = 50;               // Trailing Stop in points
input int      InpTrailingStep = 10;               // Trailing Step in points
input bool     InpUseBreakeven = true;             // Use breakeven after reaching target
input int      InpBreakevenPoints = 30;            // Points in profit to activate breakeven

//--- Time Filters
input group "=== Time Filters ==="
input bool     InpUseTimeFilter = false;           // Use Time Filter
input int      InpStartHour = 8;                   // Trading Start Hour (server time)
input int      InpEndHour = 20;                    // Trading End Hour (server time)
input bool     InpFridayClose = true;              // Close on Friday
input int      InpFridayCloseHour = 16;            // Friday Close Hour (server time)

//--- Notifications
input group "=== Notifications ==="
input bool     InpUseSound = true;                 // Use Sound Alerts
input string   InpSoundFile = "alert.wav";         // Sound File
input bool     InpSendEmail = false;               // Send email notifications
input bool     InpSendPush = false;                // Send push notifications

//--- Paper Trading
input group "=== Paper Trading ==="
input bool     InpPaperTrading = true;             // Enable paper trading
input int      InpPaperWinsRequired = 3;           // Required wins for live trading
input int      InpPaperTotalTrades = 5;            // Total paper trades to evaluate

//--- Global Variables
// Indicator Handles
int            ExtHandleMA = INVALID_HANDLE;       // MA indicator handle
int            ExtHandleFastMA = INVALID_HANDLE;   // Fast MA indicator handle
int            ExtHandleSlowMA = INVALID_HANDLE;   // Slow MA indicator handle
int            ExtHandleATR = INVALID_HANDLE;      // ATR indicator handle

// Trading Objects
CPositionInfo  ExtPosition;                        // Position info object
CSymbolInfo    ExtSymbol;                          // Symbol info object
CTradeExecutor ExtTradeExecutor;                   // Trade executor
CRiskManager   ExtRiskManager;                     // Risk manager

// Trading State
bool           ExtIsTradingAllowed = true;         // Global trading flag
bool           ExtIsFirstTick = true;              // First tick flag
bool           ExtPaperTradingActive = false;      // Paper trading mode flag
datetime       ExtLastTradeTime = 0;               // Last trade time

// Paper Trading
struct SPaperTrade
{
   double            entryPrice;                    // Entry price
   double            stopLoss;                      // Stop loss level
   double            takeProfit;                    // Take profit level
   double            closePrice;                    // Close price (if closed)
   ENUM_ORDER_TYPE   type;                         // Trade type (BUY/SELL)
   datetime          openTime;                      // Open time
   datetime          closeTime;                     // Close time
   bool              isClosed;                      // Is trade closed?
   bool              isWinner;                      // Was the trade a winner?
   double            profit;                        // Profit in account currency
};

SPaperTrade     ExtPaperTrades[];                  // Array of paper trades
int             ExtPaperTradeCount = 0;            // Number of paper trades
int             ExtPaperWins = 0;                  // Number of winning paper trades
int             ExtPaperLosses = 0;                // Number of losing paper trades

// Trading Statistics
double          ExtTotalProfit = 0.0;              // Total profit/loss
int             ExtTotalTrades = 0;                // Total number of trades
int             ExtWinningTrades = 0;              // Number of winning trades
int             ExtLosingTrades = 0;               // Number of losing trades
double          ExtMaxDrawdown = 0.0;              // Maximum drawdown

// Market Data
MqlRates        ExtRates[];                        // Price data array
double          ExtMABuffer[];                     // MA indicator buffer
double          ExtFastMABuffer[];                 // Fast MA buffer
double          ExtSlowMABuffer[];                 // Slow MA buffer
double          ExtATRBuffer[];                    // ATR buffer
   double         closePrice;
   datetime       closeTime;
   double         profit;
};

SPaperTrade     ExtPaperTrades[];              // Array to store paper trades
int             ExtPaperTradeCount = 0;        // Count of paper trades
int             ExtPaperWins = 0;              // Count of winning paper trades
int             ExtPaperLosses = 0;            // Count of losing paper trades
bool            ExtPaperTrading = true;        // Paper trading mode flag
int             ExtPaperTradesRequired = 5;    // Required paper trades before live trading
int             ExtPaperWinsRequired = 3;      // Required paper wins before live trading

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize random seed for any random operations
   MathSrand(GetTickCount());
   
   // Initialize symbol info
   if(!ExtSymbol.Name(_Symbol))
   {
      Print("Error initializing symbol info!");
      return(INIT_FAILED);
   }
   
   // Set magic number for the EA
   ExtTradeExecutor.SetMagicNumber(123456);
   
   // Initialize TradeExecutor
   if(!ExtTradeExecutor.Initialize())
   {
      Print("Failed to initialize TradeExecutor!");
      return(INIT_FAILED);
   }
   
   // Initialize RiskManager
   if(!ExtRiskManager.Initialize())
   {
      Print("Failed to initialize RiskManager!");
      return(INIT_FAILED);
   }
   
   // Initialize indicators
   if(!InitializeIndicators())
   {
      Print("Failed to initialize indicators!");
      return(INIT_FAILED);
   }
   
   // Initialize paper trading if enabled
   if(InpPaperTrading)
   {
      ExtPaperTradingActive = true;
      Print("Paper trading mode ENABLED. ", InpPaperWinsRequired, 
            " out of ", InpPaperTotalTrades, " wins required for live trading.");
   }
   
   // Initialize arrays
   ArrayResize(ExtPaperTrades, InpPaperTotalTrades);
   ArraySetAsSeries(ExtRates, true);
   ArraySetAsSeries(ExtMABuffer, true);
   ArraySetAsSeries(ExtFastMABuffer, true);
   ArraySetAsSeries(ExtSlowMABuffer, true);
   ArraySetAsSeries(ExtATRBuffer, true);
   

   if(!LoadHistoricalData())
   {
      Print("Warning: Failed to load complete historical data");
   }
   
   // Set up timer for periodic checks (every 5 seconds)
   EventSetTimer(5);
   
   // Print initialization status
   Print("\n=== EscapeEA Initialized Successfully ===");
   Print("Symbol: ", _Symbol, " | Timeframe: ", EnumToString(InpTimeframe));
   Print("Account Balance: ", AccountInfoDouble(ACCOUNT_BALANCE), " ", AccountInfoString(ACCOUNT_CURRENCY));
   Print("Leverage: 1:", AccountInfoInteger(ACCOUNT_LEVERAGE));
   Print("Trading Mode: ", (ExtPaperTradingActive ? "PAPER" : "LIVE"));
   if(ExtPaperTradingActive)
   {
      Print("Paper Trading: ", ExtPaperTradeCount, " trades, ", 
            ExtPaperWins, " wins, ", ExtPaperLosses, " losses");
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Initialize technical indicators                                  |
//+------------------------------------------------------------------+
bool InitializeIndicators()
{
   // Initialize Moving Averages
   ExtHandleMA = iMA(_Symbol, InpTimeframe, InpMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   ExtHandleFastMA = iMA(_Symbol, InpTimeframe, InpMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   ExtHandleSlowMA = iMA(_Symbol, InpTimeframe, InpMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   ExtHandleATR = iATR(_Symbol, InpTimeframe, InpATRPeriod);
   
   // Check if all indicators were created successfully
   if(ExtHandleMA == INVALID_HANDLE || 
      ExtHandleFastMA == INVALID_HANDLE || 
      ExtHandleSlowMA == INVALID_HANDLE ||
      ExtHandleATR == INVALID_HANDLE)
   {
      Print("Error creating indicators!");
      return false;
   }
   
   // Set indicator buffers
   SetIndexBuffer(0, ExtMABuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ExtFastMABuffer, INDICATOR_DATA);
   SetIndexBuffer(2, ExtSlowMABuffer, INDICATOR_DATA);
   SetIndexBuffer(3, ExtATRBuffer, INDICATOR_DATA);
   
   // Set indicator parameters
   IndicatorSetString(INDICATOR_SHORTNAME, "EscapeEA (" + string(InpMAPeriod) + ")");
   
   return true;
}

//+------------------------------------------------------------------+
//| Load historical data for analysis                                |
//+------------------------------------------------------------------+
bool LoadHistoricalData()
{
   // Load rates for the current symbol and timeframe
   int copied = CopyRates(_Symbol, InpTimeframe, 0, InpMAPeriod * 3, ExtRates);
   if(copied <= 0)
   {
      Print("Error loading historical rates: ", GetLastError());
      return false;
   }
   
   // Load indicator data
   if(CopyBuffer(ExtHandleMA, 0, 0, InpMAPeriod * 3, ExtMABuffer) <= 0 ||
      CopyBuffer(ExtHandleFastMA, 0, 0, InpMAPeriod * 3, ExtFastMABuffer) <= 0 ||
      CopyBuffer(ExtHandleSlowMA, 0, 0, InpMAPeriod * 3, ExtSlowMABuffer) <= 0 ||
      CopyBuffer(ExtHandleATR, 0, 0, InpMAPeriod * 3, ExtATRBuffer) <= 0)
   {
      Print("Error loading indicator data: ", GetLastError());
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Stop the timer
   EventKillTimer();
   
   // Release indicators
   if(ExtHandleMA != INVALID_HANDLE) IndicatorRelease(ExtHandleMA);
   if(ExtHandleFastMA != INVALID_HANDLE) IndicatorRelease(ExtHandleFastMA);
   if(ExtHandleSlowMA != INVALID_HANDLE) IndicatorRelease(ExtHandleSlowMA);
   if(ExtHandleATR != INVALID_HANDLE) IndicatorRelease(ExtHandleATR);
   
   // Clean up arrays
   ArrayFree(ExtPaperTrades);
   ArrayFree(ExtRates);
   ArrayFree(ExtMABuffer);
   ArrayFree(ExtFastMABuffer);
   ArrayFree(ExtSlowMABuffer);
   ArrayFree(ExtATRBuffer);
   
   ArrayFree(ExtMABuffer);
   ArrayFree(ExtFastMABuffer);
   ArrayFree(ExtSlowMABuffer);
   ArrayFree(ExtATRBuffer);
   
   // Deinitialize components
   ExtTradeExecutor.Deinitialize();
   ExtRiskManager.Deinitialize();
   
   // Print deinitialization message
   string reasonText = GetUninitReasonText(reason);
   Print("\n=== EscapeEA Deinitialized ===");
   Print("Reason: ", reasonText);
   Print("Total Trades: ", ExtTotalTrades);
   Print("Winning Trades: ", ExtWinningTrades, " (", 
         (ExtTotalTrades > 0 ? DoubleToString((double)ExtWinningTrades/ExtTotalTrades*100, 1) : "0"), "%)");
   Print("Total Profit: ", DoubleToString(ExtTotalProfit, 2), " ", AccountInfoString(ACCOUNT_CURRENCY));
   
   if(ExtPaperTradingActive)
   {
      Print("\n=== Paper Trading Summary ===");
      Print("Total Trades: ", ExtPaperTradeCount);
      Print("Wins: ", ExtPaperWins, " | Losses: ", ExtPaperLosses);
      double winRate = (ExtPaperTradeCount > 0) ? (double)ExtPaperWins/ExtPaperTradeCount*100 : 0;
      Print("Win Rate: ", DoubleToString(winRate, 1), "%");
      Print("Required for Live Trading: ", InpPaperWinsRequired, " out of ", InpPaperTotalTrades, " wins");
      
      if(winRate >= (double)InpPaperWinsRequired/InpPaperTotalTrades*100 && ExtPaperTradeCount >= InpPaperTotalTrades)
      {
         Print("\nPAPER TRADING SUCCESSFUL! Ready for live trading.");
      }
      else if(ExtPaperTradeCount >= InpPaperTotalTrades)
      {
         Print("\nPAPER TRADING FAILED. Strategy needs improvement before live trading.");
      }
   }
}

//+------------------------------------------------------------------+
//| Get text description of uninitialization reason                  |
//+------------------------------------------------------------------+
string GetUninitReasonText(int reasonCode)
{
   switch(reasonCode)
   {
      case REASON_ACCOUNT:    return "Account was changed";
      case REASON_CHARTCHANGE:return "Symbol or timeframe was changed";
      case REASON_CHARTCLOSE: return "Chart was closed";
      case REASON_PARAMETERS: return "Input parameters were changed";
      case REASON_RECOMPILE:  return "Program " + __FILE__ + " was recompiled";
      case REASON_REMOVE:     return "Program " + __FILE__ + " was removed from chart";
      case REASON_TEMPLATE:   return "New template was applied to chart";
      default:                return "Unknown reason";
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check if the symbol is selected and data is synchronized
   if(!ExtSymbol.RefreshRates())
   {
      Print("Failed to refresh rates!");
      return;
   }
   
   // Check if we're in paper trading mode and need to simulate trades
   if(ExtPaperTrading)
   {
      ProcessPaperTrading();
      
      // Check if we've met the paper trading requirements
      if(ExtPaperTradeCount >= ExtPaperTradesRequired && ExtPaperWins >= ExtPaperWinsRequired)
      {
         ExtPaperTrading = false;
         Print("Paper trading complete. Switching to live trading mode.");
      }
      else
      {
         // If we're still in paper trading mode, only update the chart
         UpdateChart();
         return;
      }
   }
   
   // Check for trading conditions
   if(!IsTradingAllowed())
      return;
   
   // Process trades
   ProcessTrades();
   
   // Update chart and trailing stops
   UpdateChart();
   CheckTrailingStop();
}

//+------------------------------------------------------------------+
//| Process trading signals and execute trades                       |
//+------------------------------------------------------------------+
void ProcessTrades()
{
   // Get indicator values
   double ma[], fastMA[], slowMA[];
   ArraySetAsSeries(ma, true);
   ArraySetAsSeries(fastMA, true);
   ArraySetAsSeries(slowMA, true);
   
   if(CopyBuffer(ExtHandleMA, 0, 0, 3, ma) <= 0 ||
      CopyBuffer(ExtHandleFastMA, 0, 0, 3, fastMA) <= 0 ||
      CopyBuffer(ExtHandleSlowMA, 0, 0, 3, slowMA) <= 0)
   {
      Print("Error copying indicator buffers!");
      return;
   }
   
   // Check for open positions
   bool hasPosition = ExtPosition.Select(ExtSymbol.Name());
   
   // Calculate stop loss and take profit levels
   double stopLoss = 0, takeProfit = 0;
   double point = ExtSymbol.Point();
   double ask = ExtSymbol.Ask();
   double bid = ExtSymbol.Bid();
   
   // Check for buy signal (fast MA crosses above slow MA and price is above MA)
   if(!hasPosition && fastMA[1] > slowMA[1] && fastMA[2] <= slowMA[2] && ask > ma[0])
   {
      stopLoss = InpStopLoss > 0 ? ask - InpStopLoss * point : 0;
      takeProfit = InpTakeProfit > 0 ? ask + InpTakeProfit * point : 0;
      
      // Execute buy order using the trade executor
      ExtTradeExecutor.Buy(ExtSymbol.Name(), InpLotSize, ask, stopLoss, takeProfit, "EscapeEA Buy");
   }
   // Check for sell signal (fast MA crosses below slow MA and price is below MA)
   else if(!hasPosition && fastMA[1] < slowMA[1] && fastMA[2] >= slowMA[2] && bid < ma[0])
   {
      stopLoss = InpStopLoss > 0 ? bid + InpStopLoss * point : 0;
      takeProfit = InpTakeProfit > 0 ? bid - InpTakeProfit * point : 0;
      
      // Execute sell order using the trade executor
      ExtTradeExecutor.Sell(ExtSymbol.Name(), InpLotSize, bid, stopLoss, takeProfit, "EscapeEA Sell");
   }
}

//+------------------------------------------------------------------+
//| Process paper trading simulation                                 |
//+------------------------------------------------------------------+
void ProcessPaperTrading()
{
   // Get indicator values
   double ma[], fastMA[], slowMA[];
   ArraySetAsSeries(ma, true);
   ArraySetAsSeries(fastMA, true);
   ArraySetAsSeries(slowMA, true);
   
   if(CopyBuffer(ExtHandleMA, 0, 0, 3, ma) <= 0 ||
      CopyBuffer(ExtHandleFastMA, 0, 0, 3, fastMA) <= 0 ||
      CopyBuffer(ExtHandleSlowMA, 0, 0, 3, slowMA) <= 0)
   {
      Print("Error copying indicator buffers for paper trading!");
      return;
   }
   
   // Check for open paper positions
   bool hasOpenPosition = false;
   for(int i = 0; i < ExtPaperTradeCount; i++)
   {
      if(!ExtPaperTrades[i].isClosed)
      {
         hasOpenPosition = true;
         CheckPaperTradeExit(i, ma[0]);
         break;
      }
   }
   
   // If no open positions, check for new entry
   if(!hasOpenPosition && ExtPaperTradeCount < ArraySize(ExtPaperTrades))
   {
      double ask = ExtSymbol.Ask();
      double bid = ExtSymbol.Bid();
      
      // Check for buy signal
      if(fastMA[1] > slowMA[1] && fastMA[2] <= slowMA[2] && ask > ma[0])
      {
         OpenPaperTrade(ORDER_TYPE_BUY, ask, InpStopLoss, InpTakeProfit);
      }
      // Check for sell signal
      else if(fastMA[1] < slowMA[1] && fastMA[2] >= slowMA[2] && bid < ma[0])
      {
         OpenPaperTrade(ORDER_TYPE_SELL, bid, InpStopLoss, InpTakeProfit);
      }
   }
}

//+------------------------------------------------------------------+
//| Open a new paper trade                                           |
//+------------------------------------------------------------------+
void OpenPaperTrade(ENUM_ORDER_TYPE type, double price, int stopLoss, int takeProfit)
{
   int index = ExtPaperTradeCount++;
   ExtPaperTrades[index].type = type;
   ExtPaperTrades[index].entryPrice = price;
   ExtPaperTrades[index].openTime = TimeCurrent();
   ExtPaperTrades[index].isClosed = false;
   
   double point = ExtSymbol.Point();
   
   if(type == ORDER_TYPE_BUY)
   {
      ExtPaperTrades[index].stopLoss = stopLoss > 0 ? price - stopLoss * point : 0;
      ExtPaperTrades[index].takeProfit = takeProfit > 0 ? price + takeProfit * point : 0;
   }
   else
   {
      ExtPaperTrades[index].stopLoss = stopLoss > 0 ? price + stopLoss * point : 0;
      ExtPaperTrades[index].takeProfit = takeProfit > 0 ? price - takeProfit * point : 0;
   }
   
   Print("Paper Trade Opened: ", type == ORDER_TYPE_BUY ? "BUY" : "SELL", 
         " at ", price, " SL: ", ExtPaperTrades[index].stopLoss, 
         " TP: ", ExtPaperTrades[index].takeProfit);
}

//+------------------------------------------------------------------+
//| Check if a paper trade should be closed                          |
//+------------------------------------------------------------------+
void CheckPaperTradeExit(int index, double maValue)
{
   if(ExtPaperTrades[index].isClosed)
      return;
      
   double currentBid = ExtSymbol.Bid();
   double currentAsk = ExtSymbol.Ask();
   
   // Check for exit conditions based on trade type
   if(ExtPaperTrades[index].type == ORDER_TYPE_BUY)
   {
      // Check take profit
      if(ExtPaperTrades[index].takeProfit > 0 && currentBid >= ExtPaperTrades[index].takeProfit)
      {
         ClosePaperTrade(index, currentBid, "TP");
         ExtPaperWins++;
      }
      // Check stop loss
      else if(ExtPaperTrades[index].stopLoss > 0 && currentBid <= ExtPaperTrades[index].stopLoss)
      {
         ClosePaperTrade(index, currentBid, "SL");
         ExtPaperLosses++;
      }
      // Check exit signal (price crosses below MA)
      else if(currentBid < maValue && ExtPaperTrades[index].entryPrice < currentBid)
      {
         ClosePaperTrade(index, currentBid, "Signal");
         ExtPaperWins++;
      }
   }
   else // SELL
   {
      // Check take profit
      if(ExtPaperTrades[index].takeProfit > 0 && currentAsk <= ExtPaperTrades[index].takeProfit)
      {
         ClosePaperTrade(index, currentAsk, "TP");
         ExtPaperWins++;
      }
      // Check stop loss
      else if(ExtPaperTrades[index].stopLoss > 0 && currentAsk >= ExtPaperTrades[index].stopLoss)
      {
         ClosePaperTrade(index, currentAsk, "SL");
         ExtPaperLosses++;
      }
      // Check exit signal (price crosses above MA)
      else if(currentAsk > maValue && ExtPaperTrades[index].entryPrice > currentAsk)
      {
         ClosePaperTrade(index, currentAsk, "Signal");
         ExtPaperWins++;
      }
   }
}

//+------------------------------------------------------------------+
//| Close a paper trade                                              |
//+------------------------------------------------------------------+
void ClosePaperTrade(int index, double closePrice, string reason)
{
   ExtPaperTrades[index].isClosed = true;
   ExtPaperTrades[index].closePrice = closePrice;
   ExtPaperTrades[index].closeTime = TimeCurrent();
   
   // Calculate profit
   if(ExtPaperTrades[index].type == ORDER_TYPE_BUY)
      ExtPaperTrades[index].profit = closePrice - ExtPaperTrades[index].entryPrice;
   else
      ExtPaperTrades[index].profit = ExtPaperTrades[index].entryPrice - closePrice;
   
   Print("Paper Trade Closed: ", reason, " at ", closePrice, 
         " Profit: ", ExtPaperTrades[index].profit * ExtSymbol.Point(), " pips");
}

//+------------------------------------------------------------------+
//| Check and update trailing stops                                   |
//+------------------------------------------------------------------+
void CheckTrailingStop()
{
   if(!InpUseTrailingStop || !ExtPosition.Select(ExtSymbol.Name()))
      return;
   
   double point = ExtSymbol.Point();
   double bid = ExtSymbol.Bid();
   double ask = ExtSymbol.Ask();
   
   // Get position details
   double sl = ExtPosition.StopLoss();
   double openPrice = ExtPosition.PriceOpen();
   ulong ticket = ExtPosition.Ticket();
   
   if(ExtPosition.PositionType() == POSITION_TYPE_BUY)
   {
      double newSl = bid - InpTrailingStop * point;
      
      if(sl < newSl && (sl == 0 || bid - openPrice > InpTrailingStep * point))
      {
         ExtTradeExecutor.ModifyPosition(ticket, newSl, ExtPosition.TakeProfit());
      }
   }
   else if(ExtPosition.PositionType() == POSITION_TYPE_SELL)
   {
      double newSl = ask + InpTrailingStop * point;
      
      if((sl == 0 || sl > newSl) && (openPrice - ask > InpTrailingStep * point))
      {
         ExtTradeExecutor.ModifyPosition(ticket, newSl, ExtPosition.TakeProfit());
      }
   }
}

//+------------------------------------------------------------------+
      return false;
   
   // Check if the symbol is selected and data is synchronized
   if(!ExtSymbol.RefreshRates())
   {
      Print("Failed to refresh rates!");
      return false;
   }
   
   // Check if the market is open
   if(!ExtSymbol.IsTradeAllowed())
   {
      Print("Trading is not allowed for this symbol");
      return false;
   }
   
   // Check time filter
   if(InpUseTimeFilter)
   {
      MqlDateTime time;
      TimeToStruct(TimeCurrent(), time);
      
      // Check if current time is within trading hours
      if(time.hour < InpStartHour || time.hour >= InpEndHour)
      {
         // Don't print message on every tick to avoid spamming
         static datetime lastPrintTime = 0;
         if(TimeCurrent() - lastPrintTime > 60)
         {
            Print("Outside of trading hours");
            lastPrintTime = TimeCurrent();
         }
         return false;
      }
      
      // Check if it's Friday and after close time
      if(InpFridayClose && time.day_of_week == 5 && time.hour >= InpFridayCloseHour)
      {
         Print("Friday close - no new positions");
         return false;
      }
   }
   

   
//+------------------------------------------------------------------+
