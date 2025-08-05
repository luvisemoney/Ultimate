//+------------------------------------------------------------------+
//|                                                EscapeEA_Enhanced.mq5 |
//|                                          Copyright 2025, EscapeEA |
//|                                             https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "3.01"  // Updated version with integrated components
#property strict
            
// +------------------------------------------------------------------+
// | SecurityEnhancements.mqh inputs migrated to main EA              |
// +------------------------------------------------------------------+
input group "=== News Filter Settings ==="
input bool   InpEnableNewsFilter = true;       // Enable news event filtering
input string InpAffectedSymbols = "";          // Comma-separated list of symbols affected by news (empty = all)
input datetime InpNewsStartTime = 0;           // Start time of news blackout period
input datetime InpNewsEndTime = 0;             // End time of news blackout period

input group "=== Rate Limiting ==="
input bool   InpEnableRateLimiting = true;     // Enable rate limiting
input int    InpMaxTradesPerMinute = 5;        // Maximum trades per minute

input group "=== Price Validation ==="
input bool   InpValidatePrices = true;         // Enable price validation
input int    InpMaxPriceDeviation = 10;        // Maximum price deviation in points
input int    InpMaxSlippage = 3;               // Maximum allowed slippage in points

input group "=== Anomaly Detection ==="
input bool   InpEnableAnomalyDetection = true; // Enable anomaly detection
input int    InpMaxAnomalyCount = 3;           // Maximum allowed anomalies before blocking

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

// Include our custom security components
#include <Escape/SecureMemory.mqh>
#include <Escape/InputValidation.mqh>
#include <Escape/SecurityManager.mqh>

// News Impact Analysis System
#include <Escape/MarketAnalyzer.mqh>
#include <Escape/NewsFeedHandler.mqh>
#include <Escape/VolatilityManager.mqh>

// Forward declarations for our custom components
class CRiskManager;
class CTradeExecutor;
class CPaperTrading;
class CEnhancedSecurity;
class CSignalGenerator;
class CPositionManager;
class CSecurityManager;
class CConfigManager;

// Include our custom components from Include/Escape directory
#include <Escape/RiskManager.mqh>
#include <Escape/TradeExecutor.mqh>
#include <Escape/PaperTrading.mqh>
#include <Escape/EnhancedSecurity.mqh>
#include <Escape/SignalGenerator.mqh>
#include <Escape/PositionManager.mqh>

// Include security components
#include <Escape/RAII.mqh>
#include <Escape/ConfigManager.mqh>

//--- Constants
#define EXPERT_NAME "EscapeEA_Enhanced"
#define EXPERT_VERSION "3.01"

//--- Enums
enum ENUM_TRADE_MODE {
   TRADE_MODE_PAPER,     // Paper trading only
   TRADE_MODE_LIVE,      // Live trading only
   TRADE_MODE_BOTH       // Both paper and live
};

// Scaling profiles for position management
enum ENUM_SCALING_PROFILE {
   SCALING_NONE,         // No scaling
   SCALING_CONSERVATIVE, // Conservative scaling
   SCALING_MODERATE,     // Moderate scaling
   SCALING_AGGRESSIVE    // Aggressive scaling
};

// Exit profiles for position management
enum ENUM_EXIT_PROFILE {
   EXIT_AGGRESSIVE,      // Aggressive exit (tighter stops)
   EXIT_BALANCED,        // Balanced exit
   EXIT_CONSERVATIVE     // Conservative exit (wider stops)
};

//+------------------------------------------------------------------+
//| Global Variables and Input Parameters                            |
//+------------------------------------------------------------------+

//--- Trading Components
CPositionInfo  ExtPosition;                        // Position info object
CSymbolInfo    ExtSymbol;                          // Symbol info object
CAccountInfo   ExtAccount;                         // Account info object
CDealInfo      ExtDeal;                            // Deal info object
CTrade*        ExtTrade = NULL;                    // Trade object
CTradeExecutor* ExtTradeExecutor = NULL;           // Trade executor
CRiskManager*  ExtRiskManager = NULL;              // Risk manager
CPositionManager* ExtPositionManager = NULL;       // Position manager
CPaperTrading* ExtPaperTrading = NULL;             // Paper trading system
CSignalGenerator* ExtSignalGenerator = NULL;       // Signal generator
CEnhancedSecurity* ExtSecurity = NULL;             // Security manager
CConfigManager* ExtConfig = NULL;                  // Configuration manager

//--- News Impact Analysis System
CVolatilityManager* ExtVolatilityManager = NULL;   // Volatility manager
CNewsFeedHandler* ExtNewsHandler = NULL;           // News feed handler
CMarketAnalyzer* ExtMarketAnalyzer = NULL;         // Market analyzer

//--- Trading State
bool ExtPaperTradingActive = false;               // Paper trading mode flag
PaperTradeStats ExtPaperStats;                    // Paper trading statistics

//--- Indicator Handles
int ExtHandleMA = INVALID_HANDLE;                 // MA indicator handle
int ExtHandleATR = INVALID_HANDLE;                // ATR indicator handle

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+

//--- Trade Settings
input group "=== Trade Settings ==="
input ENUM_TRADE_MODE InpTradeMode = TRADE_MODE_BOTH;  // Trading mode
input double   InpLotSize = 0.1;               // Lot size
input int      InpStopLoss = 200;               // Stop Loss in points
input int      InpTakeProfit = 400;             // Take Profit in points
input int      InpMagicNumber = 123456;         // Magic Number
input double   InpRiskPerTrade = 1.0;           // Risk per trade (% of balance)
input bool     InpUseFixedLot = false;          // Use fixed lot size

//--- Paper Trading Settings
input group "=== Paper Trading ==="
input bool     InpEnablePaperTrading = true;    // Enable paper trading
input int      InpPaperTradesRequired = 5;      // Required paper trades
input int      InpPaperWinsRequired = 3;        // Required winning trades
input double   InpPaperInitialBalance = 10000;  // Initial paper balance

//--- Risk Management
input group "=== Risk Management ==="
input double   InpMaxRiskPerTrade = 2.0;        // Max risk per trade (%)
input double   InpMaxDailyDrawdown = 5.0;       // Max daily drawdown (%)
input int      InpMaxOpenTrades = 5;            // Max open trades

//--- Indicator Parameters
input group "=== Indicator Settings ==="
input int      InpMAPeriod = 14;                // MA Period
input int      InpMAShift = 0;                  // MA Shift
input ENUM_MA_METHOD InpMAMethod = MODE_SMA;    // MA Method
input ENUM_APPLIED_PRICE InpMAApplied = PRICE_CLOSE;  // MA Applied Price
input int      InpATRPeriod = 14;               // ATR Period

//--- Trading Hours
input group "=== Trading Hours ==="
input bool     InpUseTradingHours = false;      // Use trading hours
input int      InpStartHour = 8;                // Trading start hour (server time)
input int      InpEndHour = 20;                 // Trading end hour (server time)

//--- Advanced Settings
input group "=== Advanced Settings ==="
input int      InpMaxSlippage = 30;             // Max Slippage (points)
input bool     InpUseTrailingStop = true;       // Use Trailing Stop
input int      InpTrailingStop = 100;           // Trailing Stop (points)
input int      InpTrailingStep = 10;            // Trailing Step (points)
input bool     InpUseBreakEven = true;          // Use Break Even
input int      InpBreakEven = 100;              // Break Even (points)
input int      InpBreakEvenProfit = 50;         // Break Even Profit (points)

//--- Visual Settings
input group "=== Visual Settings ==="
color          InpBuyColor = clrDodgerBlue;     // Buy signal color
color          InpSellColor = clrCrimson;       // Sell signal color
int            InpSignalWidth = 2;              // Signal line width
ENUM_LINE_STYLE InpSignalStyle = STYLE_SOLID;   // Signal line style

// Paper Trading Statistics
struct PaperTradeStats {
   int totalTrades;          // Total paper trades taken
   int winningTrades;        // Number of winning paper trades
   int losingTrades;         // Number of losing paper trades
   double totalProfit;       // Total profit from paper trades
   double totalLoss;         // Total loss from paper trades
   double winRate;           // Current win rate
   double profitFactor;      // Profit factor (gross profit / gross loss)
   datetime lastTradeTime;   // Time of last trade
   
   // Adaptive learning parameters
   double positionSizeMultiplier;  // Adjusts position size based on performance
   double riskMultiplier;          // Adjusts risk based on performance
   double stopLossMultiplier;      // Adjusts stop loss based on performance
   double takeProfitMultiplier;    // Adjusts take profit based on performance
   
   // Initialize with default values
   PaperTradeStats() {
      totalTrades = 0;
      winningTrades = 0;
      losingTrades = 0;
      totalProfit = 0.0;
      totalLoss = 0.0;
      winRate = 0.0;
      profitFactor = 0.0;
      lastTradeTime = 0;
      positionSizeMultiplier = 1.0;
      riskMultiplier = 1.0;
      stopLossMultiplier = 1.0;
      takeProfitMultiplier = 1.0;
   }
   
   // Update statistics after a trade
   void UpdateStats(bool isWin, double profit) {
      totalTrades++;
      if(isWin) {
         winningTrades++;
         totalProfit += MathAbs(profit);
      } else {
         losingTrades++;
         totalLoss += MathAbs(profit);
      }
      winRate = (double)winningTrades / totalTrades * 100.0;
      profitFactor = (totalLoss > 0) ? totalProfit / totalLoss : 0.0;
      lastTradeTime = TimeCurrent();
   }
   
   // Check if live trading is allowed (3/5 win rule)
   bool IsLiveTradingAllowed() {
      if(totalTrades < InpPaperTradesRequired) return false;
      return (winningTrades >= InpPaperWinsRequired);
   }
   
   // Adaptive learning - adjust parameters based on trade outcomes
   void LearnFromTrade(bool isWin, double profit, double learningRate) {
      if(!InpEnableAdaptiveLearning) return;
      
      // Adjust position size multiplier based on win/loss
      if(isWin) {
         // Increase position size multiplier on wins, but cap it
         positionSizeMultiplier = MathMin(2.0, positionSizeMultiplier * (1.0 + learningRate));
      } else {
         // Decrease position size multiplier on losses, but keep it above 0.1
         positionSizeMultiplier = MathMax(0.1, positionSizeMultiplier * (1.0 - learningRate));
      }
      
      // Adjust risk multiplier based on recent performance
      double recentWinRate = (winningTrades > 0) ? (double)winningTrades / totalTrades : 0.5;
      riskMultiplier = 0.5 + recentWinRate; // Range: 0.5 to 1.5
      
      // Adjust stop loss and take profit based on volatility
      // (This is a simplified example - you can make this more sophisticated)
      if(isWin) {
         // On wins, we can be more aggressive with take profit
         takeProfitMultiplier = MathMin(2.0, takeProfitMultiplier * (1.0 + learningRate * 0.5));
      } else {
         // On losses, tighten stop loss
         stopLossMultiplier = MathMax(0.5, stopLossMultiplier * (1.0 - learningRate * 0.5));
      }
      
      // Ensure multipliers stay within reasonable bounds
      positionSizeMultiplier = MathMax(0.1, MathMin(2.0, positionSizeMultiplier));
      riskMultiplier = MathMax(0.5, MathMin(1.5, riskMultiplier));
      stopLossMultiplier = MathMax(0.5, MathMin(1.5, stopLossMultiplier));
      takeProfitMultiplier = MathMax(0.5, MathMin(2.0, takeProfitMultiplier));
   }
};

PaperTradeStats ExtPaperStats;  // Global instance of paper trading statistics

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
#define OBJ_PREFIX "EscapeEA_"                     // Prefix for chart objects

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize security components
   if(!InitializeSecurity())
   {
      Print("Failed to initialize security components");
      return INIT_FAILED;
   }
   
   // Initialize indicators
   if(!InitializeIndicators())
   {
      Print("Failed to initialize indicators");
      return INIT_FAILED;
   }
   
   // Initialize trading components
   if(!InitializeTradingComponents())
   {
      Print("Failed to initialize trading components");
      return INIT_FAILED;
   }
   
   // Initialize News Impact Analysis System
   if(!InitializeNewsImpactAnalysis())
   {
      Print("Warning: News Impact Analysis System initialization failed. Continuing without it.");
      // Don't fail initialization if news system fails
   }
   
   // Initialize visualization
   if(!InitializeVisualization())
   {
      Print("Warning: Failed to initialize visualization components");
      // Don't fail initialization if visualization fails
   }
   
   // Set up timer for periodic updates
   EventSetTimer(1);
   
   Print(EXPERT_NAME " v" + EXPERT_VERSION + " initialized successfully");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Initialize News Impact Analysis System                           |
//+------------------------------------------------------------------+
bool InitializeNewsImpactAnalysis()
{
   // Initialize Volatility Manager
   ExtVolatilityManager = new CVolatilityManager();
   if(ExtVolatilityManager == NULL)
   {
      Print("Failed to create Volatility Manager");
      return false;
   }
   
   // Initialize News Feed Handler
   ExtNewsHandler = new CNewsFeedHandler();
   if(ExtNewsHandler == NULL)
   {
      Print("Failed to create News Feed Handler");
      delete ExtVolatilityManager;
      ExtVolatilityManager = NULL;
      return false;
   }
   
   // Initialize Market Analyzer with dependencies
   ExtMarketAnalyzer = new CMarketAnalyzer(ExtNewsHandler, ExtVolatilityManager);
   if(ExtMarketAnalyzer == NULL)
   {
      Print("Failed to create Market Analyzer");
      delete ExtVolatilityManager;
      delete ExtNewsHandler;
      ExtVolatilityManager = NULL;
      ExtNewsHandler = NULL;
      return false;
   }
   
   // Configure news filter settings
   if(InpEnableNewsFilter)
   {
      // Set up affected symbols
      if(StringLen(InpAffectedSymbols) > 0)
      {
         string symbols[];
         StringSplit(InpAffectedSymbols, ',', symbols);
         for(int i = 0; i < ArraySize(symbols); i++)
         {
            string symbol = StringTrimRight(StringTrimLeft(symbols[i]));
            if(symbol != "")
               ExtMarketAnalyzer.AddAffectedSymbol(symbol);
         }
      }
      
      // Set up news blackout period if specified
      if(InpNewsStartTime > 0 && InpNewsEndTime > 0 && InpNewsStartTime < InpNewsEndTime)
      {
         ExtMarketAnalyzer.SetNewsBlackoutPeriod(InpNewsStartTime, InpNewsEndTime);
      }
   }
   
   // Initialize components
   if(!ExtVolatilityManager.Initialize())
   {
      Print("Failed to initialize Volatility Manager");
      return false;
   }
   
   if(!ExtNewsHandler.Initialize())
   {
      Print("Failed to initialize News Feed Handler");
      return false;
   }
   
   if(!ExtMarketAnalyzer.Initialize())
   {
      Print("Failed to initialize Market Analyzer");
      return false;
   }
   
   Print("News Impact Analysis System initialized successfully");
   return true;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Stop the timer
   EventKillTimer();
   
   // Clean up trading components
   if(ExtTrade != NULL)
   {
      delete ExtTrade;
      ExtTrade = NULL;
   }
   
   if(ExtTradeExecutor != NULL)
   {
      delete ExtTradeExecutor;
      ExtTradeExecutor = NULL;
   }
   
   if(ExtRiskManager != NULL)
   {
      delete ExtRiskManager;
      ExtRiskManager = NULL;
   }
   
   if(ExtPositionManager != NULL)
   {
      delete ExtPositionManager;
      ExtPositionManager = NULL;
   }
   
   if(ExtSignalGenerator != NULL)
   {
      delete ExtSignalGenerator;
      ExtSignalGenerator = NULL;
   }
   
   if(ExtPaperTrading != NULL)
   {
      delete ExtPaperTrading;
      ExtPaperTrading = NULL;
   }
   
   // Release indicator handles
   if(ExtHandleMA != INVALID_HANDLE)
   {
      IndicatorRelease(ExtHandleMA);
      ExtHandleMA = INVALID_HANDLE;
   }
   
   if(ExtHandleATR != INVALID_HANDLE)
   {
      IndicatorRelease(ExtHandleATR);
      ExtHandleATR = INVALID_HANDLE;
   }
   
   // Clean up visualization objects
   ObjectsDeleteAll(0, OBJ_PREFIX);
   
   Print("EscapeEA successfully deinitialized");
}

//+------------------------------------------------------------------+
//| Initialize trading components                                    |
//+------------------------------------------------------------------+
bool InitializeTradingComponents()
{
   // Initialize trade object
   ExtTrade = new CTrade();
   if(ExtTrade == NULL)
   {
      Print("Failed to create trade object");
      return false;
   }
   
   // Set trade parameters
   ExtTrade.SetDeviationInPoints(InpMaxSlippage);
   ExtTrade.SetTypeFilling(ORDER_FILLING_FOK);
   ExtTrade.SetExpertMagicNumber(InpMagicNumber);
   
   // Initialize trade executor
   ExtTradeExecutor = new CTradeExecutor(ExtTrade);
   if(ExtTradeExecutor == NULL)
   {
      Print("Failed to create trade executor");
      return false;
   }
   
   // Initialize risk manager
   ExtRiskManager = new CRiskManager(InpRiskPerTrade, InpMaxRiskPerTrade, InpMaxDailyDrawdown);
   if(ExtRiskManager == NULL)
   {
      Print("Failed to create risk manager");
      return false;
   }
   
   // Initialize position manager
   ExtPositionManager = new CPositionManager(ExtTrade, InpMagicNumber);
   if(ExtPositionManager == NULL)
   {
      Print("Failed to create position manager");
      return false;
   }
   
   // Initialize signal generator
   ExtSignalGenerator = new CSignalGenerator(ExtHandleMA, ExtHandleATR, InpMAPeriod);
   if(ExtSignalGenerator == NULL)
   {
      Print("Failed to create signal generator");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Initialize technical indicators                                  |
//+------------------------------------------------------------------+
bool InitializeIndicators()
{
   // Initialize MA indicator
   ExtHandleMA = iMA(_Symbol, PERIOD_CURRENT, InpMAPeriod, InpMAShift, InpMAMethod, InpMAApplied);
   if(ExtHandleMA == INVALID_HANDLE)
   {
      Print("Failed to create MA indicator");
      return false;
   }
   
   // Initialize ATR indicator
   ExtHandleATR = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   if(ExtHandleATR == INVALID_HANDLE)
   {
      Print("Failed to create ATR indicator");
      return false;
   }
   
   // All indicators initialized successfully
   return true;
}

//+------------------------------------------------------------------+
//| Initialize paper trading system                                  |
//+------------------------------------------------------------------+
bool InitializePaperTrading()
{
   ExtPaperTrading = new CPaperTrading(InpPaperInitialBalance, InpMagicNumber);
   if(ExtPaperTrading == NULL)
   {
      Print("Failed to create paper trading system");
      return false;
   }
   
   // Set paper trading mode based on input parameters
   ExtPaperTradingActive = (InpTradeMode == TRADE_MODE_PAPER || 
                           (InpTradeMode == TRADE_MODE_BOTH && !ExtPaperStats.IsLiveTradingAllowed()));
   
   Print("Paper trading ", ExtPaperTradingActive ? "enabled" : "disabled");
   return true;
}

//+------------------------------------------------------------------+
//| Initialize security components                                   |
//+------------------------------------------------------------------+
bool InitializeSecurity() 
{
   // Initialize input validator first
   ExtInputValidator = CInputValidator::Instance();
   if(ExtInputValidator == NULL) 
   {
      Print("Failed to create input validator");
      return false;
   }
   
   // Create security manager instance
   ExtSecurity = CSecurityManager::Instance();
   if(ExtSecurity == NULL) 
   {
      Print("Failed to create security manager");
      return false;
   }
   
   // Initialize with current symbol and log path
   string logPath = StringFormat("%s\\%s", TerminalInfoString(TERMINAL_DATA_PATH), "Logs\\EscapeEA_Security_Log.txt");
   if(!ExtSecurity->Initialize(_Symbol, logPath)) 
   {
      Print("Failed to initialize security manager");
      return false;
   }
   
   // Validate environment
   if(!ExtSecurity->ValidateEnvironment()) 
   {
      Print("Security validation failed");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Update trading statistics                                        |
//+------------------------------------------------------------------+
void UpdateTradingStats()
{
   // Update total trades count
   int totalTrades = TradesTotal();
   
   // If no trades, nothing to update
   if(totalTrades == 0)
      return;
      
   // Loop through closed trades
   for(int i = totalTrades - 1; i >= 0; i--)
   {
      if(ExtDeal.SelectByIndex(i))
      {
         // Check if this is our trade
         if(ExtDeal.Magic() == InpMagicNumber && 
            ExtDeal.Symbol() == _Symbol)
         {
            // Update statistics
            ExtTotalTrades++;
            double profit = ExtDeal.Profit();
            
            if(profit > 0)
               ExtWinningTrades++;
            else
               ExtLosingTrades++;
                
            ExtTotalProfit += profit;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Update account info panel                                        |
//+------------------------------------------------------------------+
bool UpdateAccountInfoPanel()
{
   string panelName = OBJ_PREFIX + "AccountInfo";
   string text = "";
   
   // Format account info
   text += "Balance: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\n";
   text += "Equity: " + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "\n";
   text += "Margin: " + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN), 2) + "\n";
   text += "Free Margin: " + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 2) + "\n\n";
   
   // Add trading statistics
   text += "=== Trading Stats ===\n";
   text += "Total Trades: " + IntegerToString(ExtTotalTrades) + "\n";
   text += "Win Rate: " + (ExtTotalTrades > 0 ? 
          DoubleToString((double)ExtWinningTrades / ExtTotalTrades * 100, 2) + "%" : "N/A") + "\n";
   text += "Total Profit: " + DoubleToString(ExtTotalProfit, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + "\n";
   
   // Add paper trading info if enabled
   if(InpEnablePaperTrading)
   {
      text += "\n=== Paper Trading ===\n";
      text += "Mode: " + (ExtPaperTradingActive ? "ACTIVE" : "INACTIVE") + "\n";
      text += "Trades: " + IntegerToString(ExtPaperStats.totalTrades) + "\n";
      text += "Wins: " + IntegerToString(ExtPaperStats.winningTrades) + "\n";
      text += "Win Rate: " + (ExtPaperStats.totalTrades > 0 ? 
             DoubleToString((double)ExtPaperStats.winningTrades / ExtPaperStats.totalTrades * 100, 2) + "%" : "N/A") + "\n";
   }
   
   // Create or update the panel
   if(ObjectFind(0, panelName) < 0)
   {
      if(!ObjectCreate(0, panelName, OBJ_LABEL, 0, 0, 0))
      {
         Print("Failed to create account info panel");
         return false;
      }
      
      // Set panel properties
      ObjectSetInteger(0, panelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, panelName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, panelName, OBJPROP_YDISTANCE, 20);
      ObjectSetInteger(0, panelName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, panelName, OBJPROP_FONTSIZE, 8);
   }
   
   // Update panel text
   ObjectSetString(0, panelName, OBJPROP_TEXT, text);
   
   return true;
}

//+------------------------------------------------------------------+
//| Display current trading mode (Paper/Live)                        |
//+------------------------------------------------------------------+
bool DisplayMode()
{
   string modeText = ExtPaperTradingActive ? "PAPER TRADING" : "LIVE TRADING";
   string modeColor = ExtPaperTradingActive ? clrDodgerBlue : clrLime;
   
   // Create or update mode label
   string labelName = OBJ_PREFIX + "ModeLabel";
   if(ObjectFind(0, labelName) < 0)
   {
      if(!ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0))
      {
         Print("Failed to create mode label");
         return false;
      }
      
      // Set label properties
      ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, 20);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, modeColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, labelName, OBJPROP_FONT, "Arial Bold");
   }
   
   // Update label text and color
   ObjectSetString(0, labelName, OBJPROP_TEXT, modeText);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, modeColor);
   
   return true;
}

//+------------------------------------------------------------------+
//| Update signal visualization on the chart                         |
//+------------------------------------------------------------------+
bool UpdateSignalVisualization(bool buySignal, bool sellSignal, double price, double stopLoss, double takeProfit)
{
   // Remove any existing signal objects
   ObjectsDeleteAll(0, OBJ_PREFIX + "Signal_");
   
   // If no signals, exit
   if(!buySignal && !sellSignal)
      return true;
   
   // Calculate the current time and price for the signal arrow
   datetime currentTime = TimeCurrent();
   
   // Create signal arrow
   string arrowName = OBJ_PREFIX + "Signal_Arrow";
   if(!ObjectCreate(0, arrowName, OBJ_ARROW, 0, currentTime, price))
   {
      Print("Failed to create signal arrow");
      return false;
   }
   
   // Set arrow properties based on signal type
   if(buySignal)
   {
      ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, 233);  // Up arrow
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 2);
   }
   else if(sellSignal)
   {
      ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, 234);  // Down arrow
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 2);
   }
   
   // Add stop loss and take profit levels if provided
   if(stopLoss > 0)
   {
      string slName = OBJ_PREFIX + "Signal_SL";
      if(!ObjectCreate(0, slName, OBJ_HLINE, 0, 0, stopLoss))
      {
         Print("Failed to create stop loss line");
         return false;
      }
      ObjectSetInteger(0, slName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, slName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetString(0, slName, OBJPROP_TEXT, "SL: " + DoubleToString(stopLoss, _Digits));
   }
   
   if(takeProfit > 0)
   {
      string tpName = OBJ_PREFIX + "Signal_TP";
      if(!ObjectCreate(0, tpName, OBJ_HLINE, 0, 0, takeProfit))
      {
         Print("Failed to create take profit line");
         return false;
      }
      ObjectSetInteger(0, tpName, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, tpName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetString(0, tpName, OBJPROP_TEXT, "TP: " + DoubleToString(takeProfit, _Digits));
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Timer function for periodic updates                              |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Update visualization periodically
   UpdateVisualization();
   
   // Check for news events if enabled
   if(ExtSecurity != NULL)
   {
      ExtSecurity->CheckNewsEvents();
   }
   
   // Update trading statistics
   UpdateTradingStats();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check if we're properly initialized
   if(!IsInitialized()) 
   {
      Print("EA not properly initialized");
      return;
   }
   
   // Check if trading is allowed
   if(!IsTradeAllowed()) 
   {
      Print("Trading is not allowed at this time");
      return;
   }
   
   // Update account and symbol info
   if(!ExtAccount.RefreshRates() || !ExtSymbol.RefreshRates()) 
   {
      Print("Failed to refresh rates");
      return;
   }
   
   // Update indicators
   if(!UpdateIndicators()) 
   {
      Print("Failed to update indicators");
      return;
   }
   
   // Process trading signals based on current mode
   ProcessTradingMode();
   
   // Manage open positions
   ManagePositions();
   
   // Update visualization
   UpdateVisualization();
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                     |
//+------------------------------------------------------------------+
bool IsTradeAllowed()
{
   // Check if trading is allowed by the expert
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      Print("Trading is not allowed in the terminal settings");
      return false;
   }
   
   // Check if the expert is allowed to trade
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      Print("Trading is not allowed for this expert");
      return false;
   }
   
   // Check if we're in paper trading mode
   if(ExtPaperTradingActive && !ExtPaperStats.IsLiveTradingAllowed())
   {
      Print("Paper trading: " + string(ExtPaperStats.winningTrades) + 
            " out of " + string(ExtPaperStats.totalTrades) + " required trades are winners");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if the expert is properly initialized                     |
//+------------------------------------------------------------------+
bool IsInitialized()
{
   if(ExtTrade == NULL || ExtTradeExecutor == NULL || 
      ExtRiskManager == NULL || ExtPositionManager == NULL)
   {
      Print("One or more components are not initialized");
      return false;
   }
   
   // Check if indicators are properly initialized
   if(ExtHandleMA == INVALID_HANDLE || ExtHandleATR == INVALID_HANDLE)
   {
      Print("One or more indicators are not initialized");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Update market indicators                                         |
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
   // Update MA indicator
   if(CopyBuffer(ExtHandleMA, 0, 0, 3, ExtMABuffer) != 3)
   {
      Print("Failed to copy MA buffer: ", GetLastError());
      return false;
   }
   
   // Update ATR indicator
   if(CopyBuffer(ExtHandleATR, 0, 0, 1, &ExtATRValue) != 1)
   {
      Print("Failed to copy ATR buffer: ", GetLastError());
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Process trading based on current mode                            |
//+------------------------------------------------------------------+
void ProcessTradingMode()
{
   // Check if we have any open positions
   if(PositionsTotal() > 0)
   {
      // Manage existing positions
      return;
   }
   
   // Generate trading signals
   bool buySignal = false, sellSignal = false;
   double stopLoss = 0.0, takeProfit = 0.0;
   
   if(ExtSignalGenerator != NULL && 
      ExtSignalGenerator.GenerateSignals(buySignal, sellSignal, stopLoss, takeProfit))
   {
      // Execute trade based on signal
      if(buySignal)
      {
         ExecuteTrade(ORDER_TYPE_BUY, stopLoss, takeProfit);
      }
      else if(sellSignal)
      {
         ExecuteTrade(ORDER_TYPE_SELL, stopLoss, takeProfit);
      }
   }
}

//+------------------------------------------------------------------+
//| Execute a trade with proper risk management                      |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE orderType, double stopLoss, double takeProfit)
{
   // Calculate position size based on risk management
   double lotSize = ExtRiskManager.CalculatePositionSize(stopLoss);
   if(lotSize <= 0)
   {
      Print("Invalid position size calculated");
      return;
   }
   
   // Execute the trade
   if(ExtPaperTradingActive)
   {
      // Execute paper trade
      if(ExtPaperTrading.ExecutePaperTrade(orderType, lotSize, stopLoss, takeProfit))
      {
         Print("Paper trade executed successfully");
      }
      else
      {
         Print("Failed to execute paper trade");
      }
   }
   else
   {
      // Execute live trade
      if(ExtTradeExecutor.ExecuteTrade(orderType, lotSize, stopLoss, takeProfit))
      {
         Print("Live trade executed successfully");
      }
      else
      {
         Print("Failed to execute live trade: ", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManagePositions()
{
   // Check if we have any open positions
   if(PositionsTotal() == 0)
      return;
      
   // Loop through all open positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(ExtPosition.SelectByIndex(i))
      {
         // Check if this is our position
         if(ExtPosition.Magic() == InpMagicNumber && 
            ExtPosition.Symbol() == _Symbol)
         {
            // Update trailing stop if enabled
            if(InpUseTrailingStop)
            {
               ExtPositionManager.UpdateTrailingStop(ExtPosition.Ticket(), 
                                                   InpTrailingStop, 
                                                   InpTrailingStep);
            }
            
            // Check for break even
            if(InpUseBreakEven)
            {
               ExtPositionManager.CheckBreakEven(ExtPosition.Ticket(), 
                                               InpBreakEven, 
                                               InpBreakEvenProfit);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Update visualization on the chart                                |
//+------------------------------------------------------------------+
void UpdateVisualization()
{
   // Update account info panel
   if(!UpdateAccountInfoPanel()) 
   {
      Print("Failed to update account info panel");
   }
   
   // Update mode display (Paper/Live)
   if(!DisplayMode()) 
   {
      Print("Failed to update mode display");
   }
   
   // Update signal visualization if needed
   if(ExtSignalGenerator != NULL) 
   {
      bool buySignal = false, sellSignal = false;
      double stopLoss = 0.0, takeProfit = 0.0;
      
      if(ExtSignalGenerator.GenerateSignals(buySignal, sellSignal, stopLoss, takeProfit)) 
      {
         double price = SymbolInfoDouble(_Symbol, buySignal ? SYMBOL_ASK : SYMBOL_BID);
         if(!UpdateSignalVisualization(buySignal, sellSignal, price, stopLoss, takeProfit)) 
         {
            Print("Failed to update signal visualization");
         }
      }
   }
   
   // Force chart redraw
   ChartRedraw(0);
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
   
   // Create signal arrow
   string arrowName = "EscapeEA_Signal_Arrow";
   if(!ObjectCreate(0, arrowName, OBJ_ARROW, 0, currentTime, currentPrice - stopLoss))
   {
      Print("Failed to create signal arrow");
      return;
   }
   
   // Set arrow properties based on signal type
   if(buySignal)
   {
      ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, 233);  // Up arrow
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 2);
   }
   else if(sellSignal)
   {
      ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, 234);  // Down arrow
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 2);
   }
   
   // Add stop loss and take profit levels if provided
   if(stopLoss > 0)
   {
      string slName = "EscapeEA_SL";
      if(!ObjectCreate(0, slName, OBJ_HLINE, 0, 0, currentPrice - stopLoss))
      {
         Print("Failed to create stop loss line");
         return;
      }
      ObjectSetInteger(0, slName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, slName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetString(0, slName, OBJPROP_TEXT, "SL: " + DoubleToString(currentPrice - stopLoss, _Digits));
   }
   
   if(takeProfit > 0)
   {
      string tpName = "EscapeEA_TP";
      if(!ObjectCreate(0, tpName, OBJ_HLINE, 0, 0, currentPrice + takeProfit))
      {
         Print("Failed to create take profit line");
         return;
      }
      ObjectSetInteger(0, tpName, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, tpName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetString(0, tpName, OBJPROP_TEXT, "TP: " + DoubleToString(currentPrice + takeProfit, _Digits));
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
