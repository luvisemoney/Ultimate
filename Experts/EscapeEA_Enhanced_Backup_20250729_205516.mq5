//+------------------------------------------------------------------+
//|                                                EscapeEA_Enhanced.mq5 |
//|                                          Copyright 2025, EscapeEA |
//|                                             https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "3.01"  // Updated version with integrated components
#property strict

/**
 * @file EscapeEA_Enhanced.mq5
 * @brief Advanced Expert Advisor with integrated Paper Trading and Security
 * 
 * This EA implements a sophisticated trading strategy with the following features:
 * - Multi-timeframe analysis using moving averages
 * - Advanced paper trading simulation with win requirement for live trading
 * - Comprehensive risk management with position sizing
 * - Secure trade execution with circuit breaker protection
 * - Real-time adaptive learning from trade outcomes
 * - Visual feedback for paper and live trades
 * 
 * @see PaperTrading.mqh For paper trading simulation
 * @see TradeExecutor.mqh For trade execution details
 * @see RiskManager.mqh For risk management
 * @see EnhancedSecurity.mqh For security features
 */

//--- Required Includes
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\Trade.mqh>
#include <Arrays\ArrayObj.mqh>

// Forward declarations for our custom components
class CRiskManager;
class CTradeExecutor;
class CPaperTrading;
class CEnhancedSecurity;

// Include our custom components from Include/Experts directory
#include <Experts/RiskManager.mqh>
#include <Experts/TradeExecutor.mqh>
#include <Experts/PaperTrading.mqh>
#include <Experts/EnhancedSecurity.mqh>

//--- Constants
#define EXPERT_NAME "EscapeEA_Enhanced"
#define EXPERT_VERSION "3.01"

//--- Enums
enum ENUM_TRADE_MODE {
   TRADE_MODE_PAPER,     // Paper trading only
   TRADE_MODE_LIVE,      // Live trading only
   TRADE_MODE_BOTH       // Both paper and live
};

//--- Global Variables
// Trading Components
CPositionInfo  ExtPosition;                        // Position info object
CSymbolInfo    ExtSymbol;                          // Symbol info object
CAccountInfo   ExtAccount;                         // Account info object
CDealInfo      ExtDeal;                            // Deal info object
CTrade        *ExtTrade = NULL;                    // Trade object
CTradeExecutor *ExtTradeExecutor = NULL;           // Trade executor
CRiskManager   *ExtRiskManager = NULL;             // Risk manager
CPaperTrading *ExtPaperTrading = NULL;             // Paper trading system
CEnhancedSecurity *ExtSecurity = NULL;             // Security manager

// Trading State
ENUM_TRADE_MODE ExtTradeMode = TRADE_MODE_PAPER;   // Trading mode
bool           ExtIsTradingAllowed = true;         // Global trading flag
bool           ExtIsFirstTick = true;              // First tick flag
bool           ExtPaperTradingActive = true;       // Paper trading mode flag
datetime       ExtLastTradeTime = 0;               // Last trade time
datetime       ExtLastOrderTime = 0;               // Last order time
int            ExtOrderCount = 0;                  // Order counter for rate limiting
datetime       ExtLastOrderCountReset = 0;         // Last order count reset time
int            ExtTimerId = -1;                    // Timer ID

// Trading Statistics
double         ExtTotalProfit = 0.0;               // Total profit
int            ExtTotalTrades = 0;                 // Total trades
int            ExtWinningTrades = 0;               // Winning trades
int            ExtLosingTrades = 0;                // Losing trades

// Chart Objects
#define OBJ_PREFIX "EscapeEA_"                     // Prefix for chart objects

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
input double   InpMaxDailyLoss = 5.0;              // Max daily loss (% of balance)
input double   InpMaxPortfolioRisk = 20.0;         // Max portfolio risk (%)
input double   InpMaxLeverage = 30.0;              // Maximum leverage (1:30 by default)

//--- Trade Execution
input group "=== Trade Execution ==="
input int      InpMaxSlippage = 10;                // Maximum allowed slippage (points)
input bool     InpUseTrailingStop = true;          // Use Trailing Stop
input int      InpTrailingStop = 50;               // Trailing Stop in points
input int      InpTrailingStep = 10;               // Trailing Step in points
input bool     InpUseBreakeven = true;             // Use breakeven after reaching target
input int      InpBreakevenPoints = 30;            // Points in profit to activate breakeven
input bool     InpUsePartialFills = true;          // Allow partial order fills
input int      InpMaxOrderRetries = 3;             // Maximum order retry attempts
input int      InpOrderRetryDelay = 100;           // Delay between retries (ms)

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
input bool     InpEnablePaperTrading = true;       // Enable paper trading
input int      InpPaperTradesRequired = 5;         // Total paper trades to evaluate
input int      InpPaperWinsRequired = 3;           // Required wins for live trading
input double   InpPaperInitialBalance = 10000.0;   // Initial paper balance
input bool     InpSimulateSlippage = true;         // Simulate slippage in paper trading
input bool     InpSimulatePartialFills = true;     // Simulate partial fills
input double   InpMaxSlippagePips = 1.0;           // Max slippage in pips
input int      InpFillProbability = 90;            // Fill probability (%)

//--- Security Settings
input group "=== Security Settings ==="
input bool     InpEnableSecurity = true;           // Enable security features
input int      InpMaxOrderRate = 10;               // Max orders per minute
input bool     InpEnableTamperDetection = true;    // Enable tamper detection
input bool     InpEnableRateLimiting = true;       // Enable rate limiting
input int      InpMaxDailyTrades = 50;             // Max trades per day

//--- Indicator Handles
int            ExtHandleMA = INVALID_HANDLE;       // MA indicator handle
int            ExtHandleFastMA = INVALID_HANDLE;   // Fast MA indicator handle
int            ExtHandleSlowMA = INVALID_HANDLE;   // Slow MA indicator handle
int            ExtHandleATR = INVALID_HANDLE;      // ATR indicator handle

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize random seed
   MathSrand(GetTickCount());
   
   // Initialize symbol info
   if(!ExtSymbol.Name(_Symbol)) {
      Print("Failed to initialize symbol info");
      return INIT_FAILED;
   }
   ExtSymbol.RefreshRates();
   
   // Initialize trade object
   ExtTrade = new CTrade();
   if(ExtTrade == NULL) {
      Print("Failed to create trade object");
      return INIT_FAILED;
   }
   ExtTrade.SetDeviationInPoints(InpMaxSlippage);
   ExtTrade.SetTypeFilling(ORDER_FILLING_FOK);
   
   // Initialize security manager
   if(InpEnableSecurity) {
      ExtSecurity = new CEnhancedSecurity();
      if(ExtSecurity == NULL) {
         Print("Failed to create security manager");
         return INIT_FAILED;
      }
      
      if(!ExtSecurity.Initialize(&ExtAccount)) {
         Print("Failed to initialize security manager");
         return INIT_FAILED;
      }
   }
   
   // Initialize risk manager
   ExtRiskManager = new CRiskManager();
   if(ExtRiskManager == NULL) {
      Print("Failed to create risk manager");
      return INIT_FAILED;
   }
   
   if(!ExtRiskManager.Initialize(&ExtSymbol, &ExtAccount)) {
      Print("Failed to initialize risk manager");
      return INIT_FAILED;
   }
   
   // Initialize paper trading system
   if(InpEnablePaperTrading) {
      ExtPaperTrading = new CPaperTrading();
      if(ExtPaperTrading == NULL) {
         Print("Failed to create paper trading system");
         return INIT_FAILED;
      }
      
      // Initialize paper trading with symbol info and parameters
      if(!ExtPaperTrading->Initialize(&ExtSymbol, InpPaperInitialBalance, 
                                   InpSimulateSlippage, InpSimulatePartialFills,
                                   InpMaxSlippagePips, InpFillProbability/100.0)) {
         Print("Failed to initialize paper trading");
         return INIT_FAILED;
      }
      
      ExtPaperTradingActive = true;
      Print("Paper trading mode activated");
   }
   
   // Initialize indicators
   ExtHandleMA = iMA(_Symbol, InpTimeframe, InpMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   ExtHandleFastMA = iMA(_Symbol, InpTimeframe, InpMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   ExtHandleSlowMA = iMA(_Symbol, InpTimeframe, InpMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   ExtHandleATR = iATR(_Symbol, InpTimeframe, InpATRPeriod);
   
   if(ExtHandleMA == INVALID_HANDLE || ExtHandleFastMA == INVALID_HANDLE || 
      ExtHandleSlowMA == INVALID_HANDLE || ExtHandleATR == INVALID_HANDLE) {
      Print("Failed to create indicator handles");
      return INIT_FAILED;
   }
   
   // Set up timer for periodic updates (every 1 second)
   ExtTimerId = EventSetTimer(1);
   if(ExtTimerId == -1) {
      Print("Warning: Failed to create timer, continuing without timer updates");
   }
   
   // Initialize chart objects for visualization
   if(!InitializeChartObjects()) {
      Print("Warning: Failed to initialize chart objects");
   }
   
   // Log successful initialization
   Print("=== ", EXPERT_NAME, " v", EXPERT_VERSION, " ===");
   Print("Symbol: ", _Symbol, " | Timeframe: ", EnumToString(InpTimeframe));
   Print("Account: ", ExtAccount.Login(), " | Balance: ", ExtAccount.Balance());
   Print("Risk per trade: ", InpRiskPerTrade, "% | Max daily loss: ", InpMaxDailyLoss, "%");
   
   if(ExtPaperTradingActive) {
      Print("=== PAPER TRADING MODE ACTIVE ===");
      Print("Initial balance: ", InpPaperInitialBalance);
      Print("Required wins for live trading: ", InpPaperWinsRequired, 
            " out of ", InpPaperTradesRequired);
   } else {
      Print("=== LIVE TRADING MODE ACTIVE ===");
   }
   
   Print("Expert initialized successfully");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                     |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
   // Check if EA is properly initialized
   if(!ExtIsTradingAllowed) {
      return false;
   }
   
   // Check if market is open
   if(!ExtSymbol.IsTradeAllowed()) {
      return false;
   }
   
   // Check if we're in the strategy tester
   if(MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE) || MQLInfoInteger(MQL_OPTIMIZATION)) {
      return true;
   }
   
   // Check if we're connected to the server
   if(!TerminalInfoInteger(TERMINAL_CONNECTED)) {
      Print("No connection to the server");
      return false;
   }
   
   // Check if expert is allowed to trade
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
      Print("Trading is not allowed in the terminal settings");
      return false;
   }
   
   // Check if auto-trading is allowed
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
      Print("AutoTrading is not allowed in the terminal settings");
      return false;
   }
   
   // Check if the symbol is selected in MarketWatch
   if(!SymbolSelect(_Symbol, true)) {
      Print(_Symbol, " is not selected in MarketWatch");
      return false;
   }
   
   // Check if the symbol is visible on the chart
   if(!SymbolInfoInteger(_Symbol, SYMBOL_VISIBLE)) {
      Print(_Symbol, " is not visible on the chart");
      return false;
   }
   
   // Check if the symbol is tradeable
   if(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_DISABLED) {
      Print(_Symbol, " trading is disabled");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if we can open new positions                              |
//+------------------------------------------------------------------+
bool CanOpenNewPosition()
{
   // Check if trading is allowed
   if(!IsTradingAllowed()) {
      return false;
   }
   
   // Check if we've reached the maximum number of open positions
   if(PositionsTotal() >= InpMaxOpenTrades) {
      return false;
   }
   
   // Check if we've exceeded the daily trade limit
   if(ExtOrderCount >= InpMaxOrderRate) {
      datetime now = TimeCurrent();
      if(now - ExtLastOrderCountReset >= 60) { // Reset counter every minute
         ExtOrderCount = 0;
         ExtLastOrderCountReset = now;
      } else {
         return false;
      }
   }
   
   // Check if we've exceeded the maximum daily loss
   if(ExtRiskManager != NULL) {
      double dailyProfit = ExtAccount.Profit() - ExtAccount.Balance() + ExtAccount.Equity();
      double maxDailyLoss = ExtAccount.Balance() * (InpMaxDailyLoss / 100.0);
      
      if(dailyProfit <= -maxDailyLoss) {
         Print("Daily loss limit reached");
         return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check for trading signals                                       |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE CheckTradingSignals()
{
   // Get current market conditions
   double ma, fastMA, slowMA, atr;
   if(!GetMarketConditions(ma, fastMA, slowMA, atr)) {
      return WRONG_VALUE;
   }
   
   // Get current price
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Check for buy signal (fast MA crosses above slow MA)
   if(fastMA > slowMA && ask > ma + (atr * 0.5)) {
      // Additional confirmation: price is above the MA
      return ORDER_TYPE_BUY;
   }
   
   // Check for sell signal (fast MA crosses below slow MA)
   if(fastMA < slowMA && bid < ma - (atr * 0.5)) {
      // Additional confirmation: price is below the MA
      return ORDER_TYPE_SELL;
   }
   
   return WRONG_VALUE;
}

//+------------------------------------------------------------------+
//| Manage open positions                                           |
//+------------------------------------------------------------------+
void ManagePositions()
{
   if(!InpUseTrailingStop && !InpUseBreakeven) {
      return; // No position management needed
   }
   
   if(ExtTradeExecutor == NULL) {
      Print("Error: Trade Executor not initialized in ManagePositions()");
      return;
   }
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(ExtPosition.SelectByIndex(i)) {
         if(ExtPosition.Symbol() != _Symbol) {
            continue; // Skip positions for other symbols
         }
         
         double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         
         // Get position details
         ulong ticket = ExtPosition.Ticket();
         double openPrice = ExtPosition.PriceOpen();
         double currentSL = ExtPosition.StopLoss();
         double currentTP = ExtPosition.TakeProfit();
         
         // Calculate new stop loss for trailing stop
         if(InpUseTrailingStop && ExtPosition.PositionType() == POSITION_TYPE_BUY) {
            double newSL = NormalizeDouble(currentBid - InpTrailingStop * point, _Digits);
            
            // Only move stop loss up
            if(newSL > currentSL + (InpTrailingStep * point)) {
               ExtTradeExecutor->ModifyPosition(ticket, newSL, currentTP);
            }
         }
         else if(InpUseTrailingStop && ExtPosition.PositionType() == POSITION_TYPE_SELL) {
            double newSL = NormalizeDouble(currentAsk + InpTrailingStop * point, _Digits);
            
            // Only move stop loss down
            if(newSL < currentSL - (InpTrailingStep * point) || currentSL == 0) {
               ExtTradeExecutor->ModifyPosition(ticket, newSL, currentTP);
            }
         }
         
         // Check for breakeven
         if(InpUseBreakeven) {
            double profitInPoints = 0;
            
            if(ExtPosition.PositionType() == POSITION_TYPE_BUY) {
               profitInPoints = (currentBid - openPrice) / point;
               
               if(profitInPoints >= InpBreakevenPoints && 
                  (currentSL < openPrice || currentSL == 0)) {
                  double newSL = openPrice + (point * 10); // Small buffer above entry
                  ExtTradeExecutor->ModifyPosition(ticket, newSL, currentTP);
               }
            }
            else if(ExtPosition.PositionType() == POSITION_TYPE_SELL) {
               profitInPoints = (openPrice - currentAsk) / point;
               
               if(profitInPoints >= InpBreakevenPoints && 
                  (currentSL > openPrice || currentSL == 0)) {
                  double newSL = openPrice - (point * 10); // Small buffer below entry
                  ExtTradeExecutor->ModifyPosition(ticket, newSL, currentTP);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Initialize chart objects                                        |
//+------------------------------------------------------------------+
bool InitializeChartObjects()
{
   // Remove any existing objects
   ObjectsDeleteAll(0, OBJ_PREFIX);
   
   // Create info panel background
   if(!ObjectCreate(0, OBJ_PREFIX + "Panel", OBJ_RECTANGLE_LABEL, 0, 0, 0)) {
      Print("Failed to create panel object");
      return false;
   }
   
   ObjectSetInteger(0, OBJ_PREFIX + "Panel", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, OBJ_PREFIX + "Panel", OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, OBJ_PREFIX + "Panel", OBJPROP_XSIZE, 200);
   ObjectSetInteger(0, OBJ_PREFIX + "Panel", OBJPROP_YSIZE, 150);
   ObjectSetInteger(0, OBJ_PREFIX + "Panel", OBJPROP_BGCOLOR, clrWhiteSmoke);
   ObjectSetInteger(0, OBJ_PREFIX + "Panel", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, OBJ_PREFIX + "Panel", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, OBJ_PREFIX + "Panel", OBJPROP_COLOR, clrDimGray);
   ObjectSetInteger(0, OBJ_PREFIX + "Panel", OBJPROP_BACK, false);
   
   // Create title label
   if(!ObjectCreate(0, OBJ_PREFIX + "Title", OBJ_LABEL, 0, 0, 0)) {
      Print("Failed to create title object");
      return false;
   }
   
   ObjectSetString(0, OBJ_PREFIX + "Title", OBJPROP_TEXT, EXPERT_NAME + " v" + EXPERT_VERSION);
   ObjectSetInteger(0, OBJ_PREFIX + "Title", OBJPROP_XDISTANCE, 30);
   ObjectSetInteger(0, OBJ_PREFIX + "Title", OBJPROP_YDISTANCE, 30);
   ObjectSetInteger(0, OBJ_PREFIX + "Title", OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, OBJ_PREFIX + "Title", OBJPROP_FONTSIZE, 10);
   
   // Create mode label
   if(!ObjectCreate(0, OBJ_PREFIX + "Mode", OBJ_LABEL, 0, 0, 0)) {
      Print("Failed to create mode object");
      return false;
   }
   
   ObjectSetString(0, OBJ_PREFIX + "Mode", OBJPROP_TEXT, "Mode: " + (ExtPaperTradingActive ? "PAPER" : "LIVE"));
   ObjectSetInteger(0, OBJ_PREFIX + "Mode", OBJPROP_XDISTANCE, 30);
   ObjectSetInteger(0, OBJ_PREFIX + "Mode", OBJPROP_YDISTANCE, 50);
   ObjectSetInteger(0, OBJ_PREFIX + "Mode", OBJPROP_COLOR, ExtPaperTradingActive ? clrBlue : clrGreen);
   ObjectSetInteger(0, OBJ_PREFIX + "Mode", OBJPROP_FONTSIZE, 9);
   
   // Create balance label
   if(!ObjectCreate(0, OBJ_PREFIX + "Balance", OBJ_LABEL, 0, 0, 0)) {
      Print("Failed to create balance object");
      return false;
   }
   
   ObjectSetString(0, OBJ_PREFIX + "Balance", OBJPROP_TEXT, "Balance: " + DoubleToString(ExtAccount.Balance(), 2));
   ObjectSetInteger(0, OBJ_PREFIX + "Balance", OBJPROP_XDISTANCE, 30);
   ObjectSetInteger(0, OBJ_PREFIX + "Balance", OBJPROP_YDISTANCE, 70);
   ObjectSetInteger(0, OBJ_PREFIX + "Balance", OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, OBJ_PREFIX + "Balance", OBJPROP_FONTSIZE, 9);
   
   // Create equity label
   if(!ObjectCreate(0, OBJ_PREFIX + "Equity", OBJ_LABEL, 0, 0, 0)) {
      Print("Failed to create equity object");
      return false;
   }
   
   ObjectSetString(0, OBJ_PREFIX + "Equity", OBJPROP_TEXT, "Equity: " + DoubleToString(ExtAccount.Equity(), 2));
   ObjectSetInteger(0, OBJ_PREFIX + "Equity", OBJPROP_XDISTANCE, 30);
   ObjectSetInteger(0, OBJ_PREFIX + "Equity", OBJPROP_YDISTANCE, 90);
   ObjectSetInteger(0, OBJ_PREFIX + "Equity", OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, OBJ_PREFIX + "Equity", OBJPROP_FONTSIZE, 9);
   
   // Create profit label
   if(!ObjectCreate(0, OBJ_PREFIX + "Profit", OBJ_LABEL, 0, 0, 0)) {
      Print("Failed to create profit object");
      return false;
   }
   
   double profit = ExtAccount.Profit();
   color profitColor = profit >= 0 ? clrGreen : clrRed;
   
   ObjectSetString(0, OBJ_PREFIX + "Profit", OBJPROP_TEXT, "Profit: " + DoubleToString(profit, 2));
   ObjectSetInteger(0, OBJ_PREFIX + "Profit", OBJPROP_XDISTANCE, 30);
   ObjectSetInteger(0, OBJ_PREFIX + "Profit", OBJPROP_YDISTANCE, 110);
   ObjectSetInteger(0, OBJ_PREFIX + "Profit", OBJPROP_COLOR, profitColor);
   ObjectSetInteger(0, OBJ_PREFIX + "Profit", OBJPROP_FONTSIZE, 9);
   
   // Create status label
   if(!ObjectCreate(0, OBJ_PREFIX + "Status", OBJ_LABEL, 0, 0, 0)) {
      Print("Failed to create status object");
      return false;
   }
   
   ObjectSetString(0, OBJ_PREFIX + "Status", OBJPROP_TEXT, "Status: Ready");
   ObjectSetInteger(0, OBJ_PREFIX + "Status", OBJPROP_XDISTANCE, 30);
   ObjectSetInteger(0, OBJ_PREFIX + "Status", OBJPROP_YDISTANCE, 130);
   ObjectSetInteger(0, OBJ_PREFIX + "Status", OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, OBJ_PREFIX + "Status", OBJPROP_FONTSIZE, 9);
   
   // Create signal objects (initially hidden)
   if(!ObjectCreate(0, OBJ_PREFIX + "Signal_Buy", OBJ_ARROW_BUY, 0, 0, 0)) {
      Print("Failed to create buy signal object");
      return false;
   }
   
   ObjectSetInteger(0, OBJ_PREFIX + "Signal_Buy", OBJPROP_TIME, 0);
   ObjectSetDouble(0, OBJ_PREFIX + "Signal_Buy", OBJPROP_PRICE, 0);
   ObjectSetInteger(0, OBJ_PREFIX + "Signal_Buy", OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, OBJ_PREFIX + "Signal_Buy", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, OBJ_PREFIX + "Signal_Buy", OBJPROP_HIDDEN, true);
   
   if(!ObjectCreate(0, OBJ_PREFIX + "Signal_Sell", OBJ_ARROW_SELL, 0, 0, 0)) {
      Print("Failed to create sell signal object");
      return false;
   }
   
   ObjectSetInteger(0, OBJ_PREFIX + "Signal_Sell", OBJPROP_TIME, 0);
   ObjectSetDouble(0, OBJ_PREFIX + "Signal_Sell", OBJPROP_PRICE, 0);
   ObjectSetInteger(0, OBJ_PREFIX + "Signal_Sell", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, OBJ_PREFIX + "Signal_Sell", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, OBJ_PREFIX + "Signal_Sell", OBJPROP_HIDDEN, true);
   
   // Update the chart
   ChartRedraw();
   
   return true;
}



//+------------------------------------------------------------------+
//| Remove all chart objects                                        |
//+------------------------------------------------------------------+
void RemoveChartObjects()
{
   ObjectsDeleteAll(0, OBJ_PREFIX);
   ChartRedraw();
}


   
// This code should be inside a function, not in global scope
   }
}

// Removed duplicate OnTimer function - keeping the more comprehensive one below

//+------------------------------------------------------------------+
//| Update account information                                      |
//+------------------------------------------------------------------+
void ExtAccountInfo()
{
   // This is a placeholder for account info updates
   // The actual account info is accessed directly from the CAccountInfo object
   // This function is called periodically to refresh the display
   
   // Update the account info object
   ExtAccount.RefreshRates();
   
   // Update the symbol info
   ExtSymbol.RefreshRates();
   
   // Update the position info
   ExtPosition.Select(_Symbol);
}

//+------------------------------------------------------------------+
//| Execute trade based on signal                                   |
//+------------------------------------------------------------------+
bool ExecuteTrade(ENUM_ORDER_TYPE signalType)
{
   if(signalType == WRONG_VALUE) {
      return false;
   }
   
   // Get current market conditions
   double ma, fastMA, slowMA, atr;
   if(!GetMarketConditions(ma, fastMA, slowMA, atr)) {
      return false;
   }
   
   // Calculate position size based on risk
   double stopLossPips = atr * 2.0; // 2x ATR for stop loss
   double lotSize = ExtRiskManager.CalculatePositionSize(stopLossPips);
   
   if(lotSize <= 0) {
      Print("Invalid lot size calculated: ", lotSize);
      return false;
   }
   
   // Calculate stop loss and take profit levels
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double stopLoss = 0, takeProfit = 0;
   
   if(signalType == ORDER_TYPE_BUY) {
      stopLoss = NormalizeDouble(bid - stopLossPips * point, _Digits);
      takeProfit = NormalizeDouble(ask + (stopLossPips * 1.5 * point), _Digits);
   } else {
      stopLoss = NormalizeDouble(ask + stopLossPips * point, _Digits);
      takeProfit = NormalizeDouble(bid - (stopLossPips * 1.5 * point), _Digits);
   }
   
   // Execute the trade
   bool result = false;
   string comment = StringFormat("%s v%s | %s", EXPERT_NAME, EXPERT_VERSION, EnumToString(signalType));
   
   if(ExtPaperTradingActive && ExtPaperTrading != NULL) {
      // Execute paper trade
      result = ExtPaperTrading->OpenPosition(
         (signalType == ORDER_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
         lotSize,
         (signalType == ORDER_TYPE_BUY) ? ask : bid,
         stopLoss,
         takeProfit,
         comment
      );
      
      if(result) {
         Print("Paper trade executed: ", EnumToString(signalType), " ", lotSize, " lots");
         
         // Check if we can switch to live trading
         if(ExtPaperTrading->GetWinningTrades() >= InpPaperWinsRequired &&
            ExtPaperTrading->GetTotalTrades() >= InpPaperTradesRequired) {
            ExtPaperTradingActive = false;
            Print("=== SWITCHING TO LIVE TRADING ===");
            Print("Paper trading requirements met");
            Print("Total Trades: ", ExtPaperTrading->GetTotalTrades());
            Print("Winning Trades: ", ExtPaperTrading->GetWinningTrades());
            Print("Win Rate: ", DoubleToString(ExtPaperTrading->GetWinRate(), 2), "%");
         }
      }
   } else if(ExtTradeExecutor != NULL) {
      // Execute live trade
      if(signalType == ORDER_TYPE_BUY) {
         result = ExtTradeExecutor->Buy(lotSize, ask, stopLoss, takeProfit, comment);
      } else {
         result = ExtTradeExecutor->Sell(lotSize, bid, stopLoss, takeProfit, comment);
      }
      
      if(result) {
         ExtOrderCount++;
         ExtLastOrderTime = TimeCurrent();
         Print("Live trade executed: ", EnumToString(signalType), " ", lotSize, " lots");
      } else {
         Print("Failed to execute trade: ", ExtTradeExecutor->GetLastErrorMsg());
      }
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Get current market conditions                                   |
//+------------------------------------------------------------------+
bool GetMarketConditions(double &ma, double &fastMA, double &slowMA, double &atr)
{
   // Get MA values
   double maBuffer[];
   ArraySetAsSeries(maBuffer, true);
   
   // Get current MA values
   if(CopyBuffer(ExtHandleMA, 0, 0, 2, maBuffer) != 2) {
      Print("Error getting MA values");
      return false;
   }
   ma = maBuffer[1]; // Previous bar's MA
   
   // Get fast MA values
   if(CopyBuffer(ExtHandleFastMA, 0, 0, 2, maBuffer) != 2) {
      Print("Error getting Fast MA values");
      return false;
   }
   fastMA = maBuffer[1];
   
   // Get slow MA values
   if(CopyBuffer(ExtHandleSlowMA, 0, 0, 2, maBuffer) != 2) {
      Print("Error getting Slow MA values");
      return false;
   }
   slowMA = maBuffer[1];
   
   // Get ATR value
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   if(CopyBuffer(ExtHandleATR, 0, 0, 1, atrBuffer) != 1) {
      Print("Error getting ATR value");
      return false;
   }
   atr = atrBuffer[0];
   
   return true;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Stop the timer
   if(ExtTimerId != -1) {
      EventKillTimer(ExtTimerId);
      ExtTimerId = -1;
   }
   
   // Clean up components
   if(ExtSecurity != NULL) {
      delete ExtSecurity;
      ExtSecurity = NULL;
   }
   
   if(ExtPaperTrading != NULL) {
      delete ExtPaperTrading;
      ExtPaperTrading = NULL;
   }
   
   if(ExtTradeExecutor != NULL) {
      delete ExtTradeExecutor;
      ExtTradeExecutor = NULL;
   }
   
   if(ExtRiskManager != NULL) {
      delete ExtRiskManager;
      ExtRiskManager = NULL;
   }
   
   // Remove all chart objects
   ObjectsDeleteAll(0, OBJ_PREFIX);
   
   // Release indicator handles
   if(ExtHandleMA != INVALID_HANDLE) {
      IndicatorRelease(ExtHandleMA);
      ExtHandleMA = INVALID_HANDLE;
   }
   if(ExtHandleFastMA != INVALID_HANDLE) {
      IndicatorRelease(ExtHandleFastMA);
      ExtHandleFastMA = INVALID_HANDLE;
   }
   if(ExtHandleSlowMA != INVALID_HANDLE) {
      IndicatorRelease(ExtHandleSlowMA);
      ExtHandleSlowMA = INVALID_HANDLE;
   }
   if(ExtHandleATR != INVALID_HANDLE) {
      IndicatorRelease(ExtHandleATR);
      ExtHandleATR = INVALID_HANDLE;
   }
   
   // Clean up dynamically allocated objects
   if(ExtTrade != NULL) {
      delete ExtTrade;
      ExtTrade = NULL;
   }
   
   if(ExtTradeExecutor != NULL) {
      delete ExtTradeExecutor;
      ExtTradeExecutor = NULL;
   }
   
   if(ExtRiskManager != NULL) {
      delete ExtRiskManager;
      ExtRiskManager = NULL;
   }
   
   if(ExtPaperTrading != NULL) {
      delete ExtPaperTrading;
      ExtPaperTrading = NULL;
   }
   
   if(ExtSecurity != NULL) {
      delete ExtSecurity;
      ExtSecurity = NULL;
   }
   
   // Remove chart objects
   RemoveChartObjects();
   
   // Log shutdown information
   string reasonText;
   switch(reason) {
      case REASON_PROGRAM:    reasonText = "Program"; break;
      case REASON_REMOVE:     reasonText = "Removed from chart"; break;
      case REASON_RECOMPILE:  reasonText = "Recompiled"; break;
      case REASON_CHARTCHANGE:reasonText = "Chart changed"; break;
      case REASON_CHARTCLOSE: reasonText = "Chart closed"; break;
      case REASON_PARAMETERS: reasonText = "Input parameters changed"; break;
      case REASON_ACCOUNT:    reasonText = "Account changed"; break;
      default:                reasonText = "Unknown";
   }
   
   // Log final statistics
   if(ExtTotalTrades > 0) {
      double winRate = (double)ExtWinningTrades / ExtTotalTrades * 100.0;
      PrintFormat("Trading statistics: %d trades, %.2f%% win rate, %.2f total profit", 
                 ExtTotalTrades, winRate, ExtTotalProfit);
   }
   
   Print(EXPERT_NAME, " v", EXPERT_VERSION, " deinitialized (Reason: ", reasonText, ")");
   
   // Release indicators
   if(ExtHandleMA != INVALID_HANDLE) IndicatorRelease(ExtHandleMA);
   if(ExtHandleFastMA != INVALID_HANDLE) IndicatorRelease(ExtHandleFastMA);
   if(ExtHandleSlowMA != INVALID_HANDLE) IndicatorRelease(ExtHandleSlowMA);
   if(ExtHandleATR != INVALID_HANDLE) IndicatorRelease(ExtHandleATR);
   
   // Clean up paper trading
   if(ExtPaperTrading != NULL) {
      ExtPaperTrading->Deinitialize();
      delete ExtPaperTrading;
      ExtPaperTrading = NULL;
   }
   
   // Clean up security manager
   if(ExtSecurity != NULL) {
      ExtSecurity->Deinitialize();
      delete ExtSecurity;
      ExtSecurity = NULL;
   }
   
   // Clear chart objects
   ObjectsDeleteAll(0, "EscapeEA_");
   ChartRedraw();
   
   Print("EscapeEA Enhanced deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Update market data
   ExtSymbol.RefreshRates();
   
   // Skip if not enough bars
   if(Bars(_Symbol, InpTimeframe) < InpMAPeriod + 1) {
      Print("Not enough bars");
      return;
   }
   
   // Check if trading is allowed
   if(!IsTradingAllowed()) {
      return;
   }
   
   // Update paper trading system
   if(ExtPaperTrading != NULL) {
      ExtPaperTrading->Update();
      
      // Check if we can switch to live trading
      if(ExtPaperTradingActive && ExtPaperTrading->IsLiveTradingAllowed()) {
         ExtPaperTradingActive = false;
         Print("Switching to LIVE TRADING mode!");
         
         // Optional: Play sound or send notification
         if(InpUseSound) PlaySound(InpSoundFile);
         if(InpSendEmail) SendMail("EscapeEA: Live Trading Activated", 
                                 "Paper trading completed successfully.\n" +
                                 "Win rate: " + DoubleToString(ExtPaperTrading->GetWinRate(), 1) + "%\n" +
                                 "Switching to LIVE TRADING mode.");
      }
   }
   
   // Get indicator values
   double ma[], fastMA[], slowMA[], atr[];
   ArraySetAsSeries(ma, true);
   ArraySetAsSeries(fastMA, true);
   ArraySetAsSeries(slowMA, true);
   ArraySetAsSeries(atr, true);
   
   if(CopyBuffer(ExtHandleMA, 0, 0, 3, ma) <= 0 ||
      CopyBuffer(ExtHandleFastMA, 0, 0, 3, fastMA) <= 0 ||
      CopyBuffer(ExtHandleSlowMA, 0, 0, 3, slowMA) <= 0 ||
      CopyBuffer(ExtHandleATR, 0, 0, 1, atr) <= 0) {
      Print("Error copying indicator buffers");
      return;
   }
   
   // Check for trading signals
   bool buySignal = (fastMA[1] > slowMA[1] && fastMA[2] <= slowMA[2]);  // Fast MA crosses above Slow MA
   bool sellSignal = (fastMA[1] < slowMA[1] && fastMA[2] >= slowMA[2]);  // Fast MA crosses below Slow MA
   
   // Calculate position size based on ATR
   double atrValue = atr[0];
   double stopLoss = atrValue * InpATRMultiplier;
   double takeProfit = stopLoss * 2.0;  // 1:2 risk-reward ratio
   
   // Calculate position size based on risk
   double positionSize = ExtRiskManager->CalculatePositionSize(stopLoss, InpRiskPerTrade);
   positionSize = MathMin(positionSize, InpMaxLotSize);
   
   // Execute trades based on signals
   if(buySignal && !HasOpenPosition(POSITION_TYPE_BUY)) {
      double ask = ExtSymbol.Ask();
      double sl = ask - stopLoss * ExtSymbol.Point();
      double tp = ask + takeProfit * ExtSymbol.Point();
      
      if(ExtPaperTradingActive) {
         // Execute paper trade
         ExtPaperTrading->OpenPosition(ORDER_TYPE_BUY, positionSize, ask, sl, tp, "Buy Signal");
      } else if(ExtTradeExecutor->OpenPosition(ORDER_TYPE_BUY, positionSize, ask, sl, tp, "Buy Signal")) {
         ExtLastTradeTime = TimeCurrent();
         Print("Buy order executed");
      }
   }
   
   if(sellSignal && !HasOpenPosition(POSITION_TYPE_SELL)) {
      double bid = ExtSymbol.Bid();
      double sl = bid + stopLoss * ExtSymbol.Point();
      double tp = bid - takeProfit * ExtSymbol.Point();
      
      if(ExtPaperTradingActive) {
         // Execute paper trade
         ExtPaperTrading->OpenPosition(ORDER_TYPE_SELL, positionSize, bid, sl, tp, "Sell Signal");
      } else if(ExtTradeExecutor->OpenPosition(ORDER_TYPE_SELL, positionSize, bid, sl, tp, "Sell Signal")) {
         ExtLastTradeTime = TimeCurrent();
         Print("Sell order executed");
      }
   }
   
   // Manage open positions
   ManagePositions();
   
   // Update chart
   UpdateChart();
   
   ExtIsFirstTick = false;
}

//+------------------------------------------------------------------+
//| Timer function - handles periodic updates                        |
//+------------------------------------------------------------------+
void OnTimer()
{
   static datetime lastUpdate = 0;
   datetime currentTime = TimeCurrent();
   
   // Update account information (every 5 seconds)
   if(currentTime - lastUpdate >= 5) {
      // Update account information
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double margin = AccountInfoDouble(ACCOUNT_MARGIN);
      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      
      // Update risk metrics
      if(ExtRiskManager != NULL) {
         ExtRiskManager->UpdateMetrics();
      }
      
      // Update paper trading metrics if active
      if(ExtPaperTradingActive && ExtPaperTrading != NULL) {
         ExtPaperTrading->UpdateMetrics();
      }
      
      // Update the display
      UpdateAccountInfoDisplay(balance, equity, margin, freeMargin);
      
      lastUpdate = currentTime;
   }
   
   // Check for news events (every 30 seconds)
   static datetime lastNewsCheck = 0;
   if(currentTime - lastNewsCheck >= 30) {
      CheckNewsEvents();
      lastNewsCheck = currentTime;
   }
   
   // Update visualization (every second)
   UpdateVisualization();
   
   // Force chart redraw
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update account information display on the chart                  |
//+------------------------------------------------------------------+
void UpdateAccountInfoDisplay(double balance, double equity, double margin, double freeMargin)
{
   // Create or update account info panel
   string prefix = "EscapeEA_Account_";
   
   // Panel background
   ObjectCreate(0, prefix + "BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, prefix + "BG", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, prefix + "BG", OBJPROP_YDISTANCE, 70);
   ObjectSetInteger(0, prefix + "BG", OBJPROP_XSIZE, 200);
   ObjectSetInteger(0, prefix + "BG", OBJPROP_YSIZE, 100);
   ObjectSetInteger(0, prefix + "BG", OBJPROP_BGCOLOR, clrWhiteSmoke);
   ObjectSetInteger(0, prefix + "BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, prefix + "BG", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, prefix + "BG", OBJPROP_COLOR, clrDimGray);
   ObjectSetInteger(0, prefix + "BG", OBJPROP_BACK, false);
   
   // Panel title
   ObjectCreate(0, prefix + "Title", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, prefix + "Title", OBJPROP_TEXT, "ACCOUNT INFO");
   ObjectSetInteger(0, prefix + "Title", OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, prefix + "Title", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, prefix + "Title", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, prefix + "Title", OBJPROP_YDISTANCE, 80);
   ObjectSetInteger(0, prefix + "Title", OBJPROP_FONTSIZE, 10);
   
   // Balance
   ObjectCreate(0, prefix + "Balance", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, prefix + "Balance", OBJPROP_TEXT, "Balance: " + DoubleToString(balance, 2));
   ObjectSetInteger(0, prefix + "Balance", OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, prefix + "Balance", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, prefix + "Balance", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, prefix + "Balance", OBJPROP_YDISTANCE, 100);
   
   // Equity
   ObjectCreate(0, prefix + "Equity", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, prefix + "Equity", OBJPROP_TEXT, "Equity: " + DoubleToString(equity, 2));
   ObjectSetInteger(0, prefix + "Equity", OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, prefix + "Equity", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, prefix + "Equity", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, prefix + "Equity", OBJPROP_YDISTANCE, 120);
   
   // Margin
   ObjectCreate(0, prefix + "Margin", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, prefix + "Margin", OBJPROP_TEXT, "Margin: " + DoubleToString(margin, 2));
   ObjectSetInteger(0, prefix + "Margin", OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, prefix + "Margin", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, prefix + "Margin", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, prefix + "Margin", OBJPROP_YDISTANCE, 140);
   
   // Free Margin
   ObjectCreate(0, prefix + "FreeMargin", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, prefix + "FreeMargin", OBJPROP_TEXT, "Free Margin: " + DoubleToString(freeMargin, 2));
   ObjectSetInteger(0, prefix + "FreeMargin", OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, prefix + "FreeMargin", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, prefix + "FreeMargin", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, prefix + "FreeMargin", OBJPROP_YDISTANCE, 160);
   
   // Update the chart to show the changes
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update visualization elements on the chart                      |
//+------------------------------------------------------------------+
void UpdateVisualization()
{
   // Update the main chart with any necessary visual elements
   // This function is called from OnTimer() to refresh the display
   
   // Update the trading mode display (Paper/Live)
   string modeText = ExtPaperTradingActive ? "PAPER TRADING" : "LIVE TRADING";
   color modeColor = ExtPaperTradingActive ? clrDodgerBlue : clrLime;
   
   // Update the mode label on the chart
   ObjectCreate(0, "EscapeEA_Mode", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, "EscapeEA_Mode", OBJPROP_TEXT, modeText);
   ObjectSetInteger(0, "EscapeEA_Mode", OBJPROP_COLOR, modeColor);
   ObjectSetInteger(0, "EscapeEA_Mode", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "EscapeEA_Mode", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "EscapeEA_Mode", OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, "EscapeEA_Mode", OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, "EscapeEA_Mode", OBJPROP_SELECTABLE, false);
   
   // Update the paper trading display if active
   if(ExtPaperTradingActive && ExtPaperTrading != NULL) {
      ExtPaperTrading->UpdateVisualization();
   }
   
   // Update any other visualization elements
   UpdateSignalVisualization(false, false, 0, 0, 0);
   
   // Force chart redraw
   ChartRedraw();
}


   }
   
   // Check for minimum account balance
   if(AccountInfoDouble(ACCOUNT_BALANCE) < 100.0) {  // Minimum $100 balance
      Print("Account balance too low");
      return false;
   }
   
   // Check time filter
   if(InpUseTimeFilter && !IsTradingTime()) {
      return false;
   }
   
   // Check for maximum open trades
   if(PositionsTotal() >= InpMaxOpenTrades) {
      return false;
   }
   
   // Check security restrictions
   if(ExtSecurity != NULL && !ExtSecurity->IsTradingAllowed()) {
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if current time is within trading hours                    |
//+------------------------------------------------------------------+
bool IsTradingTime()
{
   MqlDateTime time;
   TimeToStruct(TimeCurrent(), time);
   
   // Check for weekend
   if(time.day_of_week == 0 || time.day_of_week == 6) {
      return false;
   }
   
   // Check for Friday early close
   if(InpFridayClose && time.day_of_week == 5 && time.hour >= InpFridayCloseHour) {
      return false;
   }
   
   // Check trading hours
   if(time.hour < InpStartHour || time.hour >= InpEndHour) {
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if there's already an open position                        |
//+------------------------------------------------------------------+
bool HasOpenPosition(ENUM_POSITION_TYPE positionType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(ExtPosition.SelectByIndex(i)) {
         if(ExtPosition.Symbol() == _Symbol && ExtPosition.PositionType() == positionType) {
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Manage open positions (trailing stop, breakeven, etc.)           |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(ExtPosition.SelectByIndex(i) && ExtPosition.Symbol() == _Symbol) {
         double currentBid = ExtSymbol.Bid();
         double currentAsk = ExtSymbol.Ask();
         double positionOpenPrice = ExtPosition.PriceOpen();
         double currentSL = ExtPosition.StopLoss();
         double currentTP = ExtPosition.TakeProfit();
         
         // Skip if no stop loss or take profit
         if(currentSL == 0 || currentTP == 0) continue;
         
         // Calculate trailing stop
         if(InpUseTrailingStop) {
            double newSL = currentSL;
            double points = ExtPosition.PositionType() == POSITION_TYPE_BUY ? 
                           (currentBid - currentSL) / ExtSymbol.Point() : 
                           (currentSL - currentAsk) / ExtSymbol.Point();
            
            if(points > InpTrailingStop) {
               double trailAmount = (points - InpTrailingStop + InpTrailingStep) / ExtSymbol.Point();
               newSL = ExtPosition.PositionType() == POSITION_TYPE_BUY ? 
                      currentBid - InpTrailingStop * ExtSymbol.Point() : 
                      currentAsk + InpTrailingStop * ExtSymbol.Point();
               
               // Only move stop loss in profit direction
               if((ExtPosition.PositionType() == POSITION_TYPE_BUY && newSL > currentSL) ||
                  (ExtPosition.PositionType() == POSITION_TYPE_SELL && (newSL < currentSL || currentSL == 0))) {
                  ExtTradeExecutor->ModifyPosition(ExtPosition.Ticket(), newSL, currentTP);
               }
            }
         }
         
         // Check for breakeven
         if(InpUseBreakeven) {
            double profitInPoints = ExtPosition.PositionType() == POSITION_TYPE_BUY ?
                                  (currentBid - positionOpenPrice) / ExtSymbol.Point() :
                                  (positionOpenPrice - currentAsk) / ExtSymbol.Point();
            
            if(profitInPoints >= InpBreakevenPoints && 
               ((ExtPosition.PositionType() == POSITION_TYPE_BUY && currentSL < positionOpenPrice) ||
                (ExtPosition.PositionType() == POSITION_TYPE_SELL && (currentSL > positionOpenPrice || currentSL == 0)))) {
               ExtTradeExecutor->ModifyPosition(ExtPosition.Ticket(), positionOpenPrice, currentTP);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check for important news events                                  |
//+------------------------------------------------------------------+
void CheckNewsEvents()
{
   // This is a placeholder for news event checking
   // In a real implementation, you would integrate with a news API or economic calendar
   
   // Example: Check for high-impact news in the next 30 minutes
   // This is a simplified example - replace with actual news checking logic
   static datetime lastNewsCheck = 0;
   if(TimeCurrent() - lastNewsCheck < 300) {  // Check every 5 minutes
      return;
   }
   
   lastNewsCheck = TimeCurrent();
   
   // In a real implementation, you would check for upcoming news
   // and adjust trading behavior accordingly
   bool highImpactNews = false;  // Replace with actual news check
   
   if(highImpactNews) {
      Print("High impact news detected - adjusting trading parameters");
      // Reduce position sizes, widen stops, or disable trading
   }
}

//+------------------------------------------------------------------+
//| Update chart with trading information                            |
//+------------------------------------------------------------------+
void UpdateChart()
{
   // Update the main chart with any necessary visual elements
   // This function is called from OnTick() to refresh the display
   
   // Update the trading mode display (Paper/Live)
   string modeText = ExtPaperTradingActive ? "PAPER TRADING" : "LIVE TRADING";
   color modeColor = ExtPaperTradingActive ? clrDodgerBlue : clrLime;
   
   // Update the mode label on the chart
   ObjectCreate(0, "EscapeEA_Mode", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, "EscapeEA_Mode", OBJPROP_TEXT, modeText);
   ObjectSetInteger(0, "EscapeEA_Mode", OBJPROP_COLOR, modeColor);
   ObjectSetInteger(0, "EscapeEA_Mode", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "EscapeEA_Mode", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "EscapeEA_Mode", OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, "EscapeEA_Mode", OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, "EscapeEA_Mode", OBJPROP_SELECTABLE, false);
   
   // Update the account information display
   if(ExtPaperTradingActive && ExtPaperTrading != NULL) {
      ExtPaperTrading->UpdateVisualization();
   }
   
   // Force chart redraw
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update signal visualization on the chart                         |
//+------------------------------------------------------------------+
void UpdateSignalVisualization(bool buySignal, bool sellSignal, double currentPrice, double stopLoss, double takeProfit)
{
   // Remove any existing signal objects
   ObjectsDeleteAll(0, "EscapeEA_Signal_");
   
   // If no signals, exit
   if(!buySignal && !sellSignal) {
      return;
   }
   
   // Calculate the current time and price for the signal arrow
   datetime currentTime = TimeCurrent();
   color signalColor = clrNONE;
   string signalText = "";
   
   if(buySignal) {
      signalColor = clrLime;
      signalText = "BUY";
      
      // Draw buy signal arrow
      string arrowName = "EscapeEA_Signal_Buy_" + TimeToString(currentTime, TIME_DATE|TIME_SECONDS);
      ObjectCreate(0, arrowName, OBJ_ARROW_BUY, 0, currentTime, currentPrice - stopLoss);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, signalColor);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 2);
      
      // Draw stop loss and take profit levels
      string slLine = "EscapeEA_SL_" + TimeToString(currentTime, TIME_DATE|TIME_SECONDS);
      string tpLine = "EscapeEA_TP_" + TimeToString(currentTime, TIME_DATE|TIME_SECONDS);
      
      // Stop loss line
      ObjectCreate(0, slLine, OBJ_HLINE, 0, 0, currentPrice - stopLoss);
      ObjectSetInteger(0, slLine, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, slLine, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, slLine, OBJPROP_WIDTH, 1);
      
      // Take profit line
      ObjectCreate(0, tpLine, OBJ_HLINE, 0, 0, currentPrice + takeProfit);
      ObjectSetInteger(0, tpLine, OBJPROP_COLOR, clrGreen);
      ObjectSetInteger(0, tpLine, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, tpLine, OBJPROP_WIDTH, 1);
      
      // Add signal label
      string labelName = "EscapeEA_Label_" + TimeToString(currentTime, TIME_DATE|TIME_SECONDS);
      ObjectCreate(0, labelName, OBJ_TEXT, 0, currentTime, currentPrice - stopLoss * 1.5);
      ObjectSetString(0, labelName, OBJPROP_TEXT, "BUY @ " + DoubleToString(currentPrice, _Digits));
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, signalColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
   }
   
   if(sellSignal) {
      signalColor = clrRed;
      signalText = "SELL";
      
      // Draw sell signal arrow
      string arrowName = "EscapeEA_Signal_Sell_" + TimeToString(currentTime, TIME_DATE|TIME_SECONDS);
      ObjectCreate(0, arrowName, OBJ_ARROW_SELL, 0, currentTime, currentPrice + stopLoss);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, signalColor);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 2);
      
      // Draw stop loss and take profit levels
      string slLine = "EscapeEA_SL_" + TimeToString(currentTime, TIME_DATE|TIME_SECONDS);
      string tpLine = "EscapeEA_TP_" + TimeToString(currentTime, TIME_DATE|TIME_SECONDS);
      
      // Stop loss line
      ObjectCreate(0, slLine, OBJ_HLINE, 0, 0, currentPrice + stopLoss);
      ObjectSetInteger(0, slLine, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, slLine, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, slLine, OBJPROP_WIDTH, 1);
      
      // Take profit line
      ObjectCreate(0, tpLine, OBJ_HLINE, 0, 0, currentPrice - takeProfit);
      ObjectSetInteger(0, tpLine, OBJPROP_COLOR, clrGreen);
      ObjectSetInteger(0, tpLine, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, tpLine, OBJPROP_WIDTH, 1);
      
      // Add signal label
      string labelName = "EscapeEA_Label_" + TimeToString(currentTime, TIME_DATE|TIME_SECONDS);
      ObjectCreate(0, labelName, OBJ_TEXT, 0, currentTime, currentPrice + stopLoss * 1.5);
      ObjectSetString(0, labelName, OBJPROP_TEXT, "SELL @ " + DoubleToString(currentPrice, _Digits));
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, signalColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
   }
   
   // Update the signal status label
   if(buySignal || sellSignal) {
      string statusText = signalText + " SIGNAL " + TimeToString(currentTime, TIME_MINUTES|TIME_SECONDS);
      ObjectCreate(0, "EscapeEA_Signal_Status", OBJ_LABEL, 0, 0, 0);
      ObjectSetString(0, "EscapeEA_Signal_Status", OBJPROP_TEXT, statusText);
      ObjectSetInteger(0, "EscapeEA_Signal_Status", OBJPROP_COLOR, signalColor);
      ObjectSetInteger(0, "EscapeEA_Signal_Status", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, "EscapeEA_Signal_Status", OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, "EscapeEA_Signal_Status", OBJPROP_YDISTANCE, 40);
      ObjectSetInteger(0, "EscapeEA_Signal_Status", OBJPROP_FONTSIZE, 10);
   }
   
   // Force chart redraw
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Display current mode (Paper/Live)                               |
//+------------------------------------------------------------------+
void DisplayMode()
{
   string modeText = ExtPaperTradingActive ? "PAPER TRADING" : "LIVE TRADING";
   string modeColor = ExtPaperTradingActive ? clrDodgerBlue : clrLime;
   
   // Create or update mode label
   string modeLabel = "EscapeEA_Mode";
   if(ObjectFind(0, modeLabel) < 0) {
      ObjectCreate(0, modeLabel, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, modeLabel, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, modeLabel, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, modeLabel, OBJPROP_YDISTANCE, 10);
      ObjectSetInteger(0, modeLabel, OBJPROP_COLOR, modeColor);
      ObjectSetInteger(0, modeLabel, OBJPROP_FONTSIZE, 12);
      ObjectSetString(0, modeLabel, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, modeLabel, OBJPROP_BACK, false);
   }
   ObjectSetString(0, modeLabel, OBJPROP_TEXT, modeText);
   ObjectSetInteger(0, modeLabel, OBJPROP_COLOR, modeColor);
   
   // Display paper trading info if active
   if(ExtPaperTradingActive && ExtPaperTrading != NULL) {
      string infoText = StringFormat("Paper Balance: %.2f\n" +
                                   "Equity: %.2f\n" +
                                   "Trades: %d (%dW/%dL)\n" +
                                   "Win Rate: %.1f%%",
                                   ExtPaperTrading->GetBalance(),
                                   ExtPaperTrading->GetEquity(),
                                   ExtPaperTrading->GetTotalTrades(),
                                   ExtPaperTrading->GetWinningTrades(),
                                   ExtPaperTrading->GetLosingTrades(),
                                   ExtPaperTrading->GetWinRate());
      
      string infoLabel = "EscapeEA_PaperInfo";
      if(ObjectFind(0, infoLabel) < 0) {
         ObjectCreate(0, infoLabel, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, infoLabel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, infoLabel, OBJPROP_XDISTANCE, 10);
         ObjectSetInteger(0, infoLabel, OBJPROP_YDISTANCE, 30);
         ObjectSetInteger(0, infoLabel, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, infoLabel, OBJPROP_FONTSIZE, 10);
         ObjectSetString(0, infoLabel, OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, infoLabel, OBJPROP_BACK, true);
      }
      ObjectSetString(0, infoLabel, OBJPROP_TEXT, infoText);
   }
   
   // Update account info
   string accountInfo = StringFormat("Balance: %.2f %s\n" +
                                   "Equity: %.2f %s\n" +
                                   "Margin: %.2f %s\n" +
                                   "Free Margin: %.2f %s",
                                   AccountInfoDouble(ACCOUNT_BALANCE),
                                   AccountInfoString(ACCOUNT_CURRENCY),
                                   AccountInfoDouble(ACCOUNT_EQUITY),
                                   AccountInfoString(ACCOUNT_CURRENCY),
                                   AccountInfoDouble(ACCOUNT_MARGIN),
                                   AccountInfoString(ACCOUNT_CURRENCY),
                                   AccountInfoDouble(ACCOUNT_MARGIN_FREE),
                                   AccountInfoString(ACCOUNT_CURRENCY));
   
   string accountLabel = "EscapeEA_AccountInfo";
   if(ObjectFind(0, accountLabel) < 0) {
      ObjectCreate(0, accountLabel, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, accountLabel, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, accountLabel, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, accountLabel, OBJPROP_YDISTANCE, 30);
      ObjectSetInteger(0, accountLabel, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, accountLabel, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, accountLabel, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, accountLabel, OBJPROP_BACK, true);
   }
   ObjectSetString(0, accountLabel, OBJPROP_TEXT, accountInfo);
   
   // Update chart
   ChartRedraw();
}
//+------------------------------------------------------------------+
