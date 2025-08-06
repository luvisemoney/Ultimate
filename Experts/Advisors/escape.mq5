//+------------------------------------------------------------------+
//|                              escape.mq5 |
//|                                    Copyright 2025, EscapeEA Team |
//|                                            es_cape77@hotmail.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA Team"
#property link      "https://www.escapeea.com"
#property version   "1.00"

// Include necessary files
#include <Trade\Trade.mqh>               // For CTrade and error handling
#include <Trade\PositionInfo.mqh>        // For position information
#include <Trade\SymbolInfo.mqh>          // For symbol information
#include <Trade\AccountInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- Input Parameters ---
// General Settings
input group "=== General Settings ==="
input double InpLotSize = 0.1;              // Lot size
input int InpStopLoss = 100;                // Stop Loss in points
input int InpTakeProfit = 200;              // Take Profit in points
input bool InpUseTrailingStop = false;      // Use Trailing Stop
input int InpTrailingStop = 50;             // Trailing Stop in points
input int InpTrailingStep = 10;             // Trailing Step in points
input int InpMagicNumber = 123456;          // Magic Number
input string InpTradeComment = "Escape EA"; // Trade Comment
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M15; // Timeframe
input bool InpEnableLogging = true;         // Enable Logging
input bool InpEnableEmailAlerts = false;    // Enable Email Alerts
input bool InpEnablePushAlerts = false;     // Enable Push Notifications

// Risk Management
input group "=== Risk Management ==="
input double InpRiskPercent = 1.0;          // Risk per trade (%)
input int InpMaxOpenTrades = 5;             // Max Open Trades
input bool InpHideStopLoss = false;         // Hide Stop Loss (for brokers that don't support SL/TP)
input bool InpUseDynamicLots = true;        // Use Dynamic Lot Sizing
input double InpMinLotSize = 0.01;          // Minimum Lot Size
input double InpMaxLotSize = 10.0;          // Maximum Lot Size
input int InpSlippage = 30;                 // Slippage in points
input bool InpCloseOnOpposite = true;       // Close on Opposite Signal
input int InpMaxSpread = 50;                // Maximum Spread in points

// Trading Hours
input group "=== Trading Hours ==="
input bool InpTradeOnFriday = false;        // Trade on Friday
input int InpHourStart = 0;                 // Trading Start Hour (0-23)
input int InpHourEnd = 24;                  // Trading End Hour (0-24)

//--- Strategy 1: Moving Average Crossover ---
input group "=== MA Crossover Strategy ==="
input bool InpEnableStrategy1 = true;       // Enable MA Crossover Strategy
input int InpMAFastPeriod = 5;              // MA Fast Period
input int InpMASlowPeriod = 20;             // MA Slow Period
input ENUM_MA_METHOD InpMAMethod = MODE_EMA; // MA Method
input ENUM_APPLIED_PRICE InpMAPrice = PRICE_CLOSE; // MA Applied Price
input ENUM_TIMEFRAMES InpHigherTimeframe = PERIOD_H1; // Higher Timeframe for trend confirmation

//--- Strategy 2: RSI ---
input group "=== RSI Strategy ==="
input bool InpEnableStrategy2 = true;       // Enable RSI Strategy
input int InpRSIPeriod = 14;                // RSI Period
input double InpRSIOverbought = 70.0;       // RSI Overbought Level
input double InpRSIOversold = 30.0;         // RSI Oversold Level
input ENUM_APPLIED_PRICE InpRSIPrice = PRICE_CLOSE; // RSI Applied Price

//--- Strategy 3: MACD ---
input group "=== MACD Strategy ==="
input bool InpEnableStrategy3 = true;       // Enable MACD Strategy
input int InpMACDFastEMA = 12;              // MACD Fast EMA
input int InpMACDSlowEMA = 26;              // MACD Slow EMA
input int InpMACDSignalPeriod = 9;          // MACD Signal Period
input ENUM_APPLIED_PRICE InpMACDPrice = PRICE_CLOSE; // MACD Applied Price

//--- Strategy 4: Bollinger Bands ---
input group "=== Bollinger Bands Strategy ==="
input bool InpEnableStrategy4 = true;       // Enable Bollinger Bands Strategy
input int InpBBPeriod = 20;                 // Bollinger Bands Period
input double InpBBDeviation = 2.0;          // Bollinger Bands Deviation
input int InpBBShift = 0;                   // Bollinger Bands Shift
input ENUM_APPLIED_PRICE InpBBPrice = PRICE_CLOSE; // Bollinger Bands Applied Price

//--- Strategy Risk Management ---
input group "=== Strategy Risk Management ==="
input double InpDefaultStopLossPips = 20.0; // Default Stop Loss (pips)
input double InpDefaultTakeProfitPips = 40.0; // Default Take Profit (pips)
input double InpMaxRiskPerTrade = 1.0;      // Max Risk per Trade (%)
input bool InpUseATRForSL = true;           // Use ATR for Stop Loss
input int InpATRPeriod = 14;                // ATR Period for Stop Loss
input double InpATRMultiplier = 2.0;        // ATR Multiplier for Stop Loss

// Constants
const int MIN_PAPER_TRADES = 10;  // Minimum number of paper trades before considering live trading
const double PAPER_TRADING_TARGET = 70.0;  // Target win rate percentage for paper trading

//+------------------------------------------------------------------+
//| Trading Modes                                                    |
//+------------------------------------------------------------------+
enum ENUM_TRADING_MODE
  {
   MODE_PAPER,     // Paper trading only
   MODE_HYBRID,    // Paper trading with live execution (when conditions met)
   MODE_LIVE       // Live trading (when consistently profitable)
  };

//+------------------------------------------------------------------+
//| Market Condition Analysis                                        |
//+------------------------------------------------------------------+
enum ENUM_MARKET_CONDITION
  {
   MARKET_RANGING = 0,       // Sideways market
   MARKET_TREND_UP = 1,      // Uptrend
   MARKET_TREND_DOWN = 2,    // Downtrend
   MARKET_VOLATILE = 3,      // High volatility
   MARKET_HIGH_SPREAD = 4,   // High spread
   MARKET_NORMAL = 5         // Normal conditions
  };

//+------------------------------------------------------------------+
//| Trade Record Structure                                           |
//+------------------------------------------------------------------+
struct STradeRecord
  {
   ulong             ticket;          // Trade ticket
   string            symbol;          // Symbol
   ENUM_ORDER_TYPE   type;            // Order type
   double            volume;          // Volume in lots
   double            openPrice;       // Open price
   double            stopLoss;        // Stop loss level
   double            takeProfit;      // Take profit level
   datetime          openTime;        // Open time
   datetime          closeTime;       // Close time
   double            closePrice;      // Close price
   double            commission;      // Commission
   double            swap;            // Swap
   double            profit;          // Profit/Loss
   string            comment;         // Comment
   bool              isLive;          // True if live trade, false if paper trade

   // Initialize the structure
   void              Init()
     {
      ticket = 0;
      symbol = "";
      type = WRONG_VALUE;
      volume = 0.0;
      openPrice = 0.0;
      stopLoss = 0.0;
      takeProfit = 0.0;
      openTime = 0;
      closeTime = 0;
      closePrice = 0.0;
      commission = 0.0;
      swap = 0.0;
      profit = 0.0;
      comment = "";
      isLive = false;
     }
  };

//+------------------------------------------------------------------+
//| Trading Statistics Structure                                     |
//+------------------------------------------------------------------+
struct STradingStats
  {
   int               totalTrades;      // Total number of trades
   int               winningTrades;    // Number of winning trades
   double            totalProfit;      // Total profit
   double            totalLoss;        // Total loss
   double            maxDrawdown;      // Maximum drawdown
   double            maxProfit;        // Maximum profit
   double            winRate;          // Win rate in percentage
   double            profitFactor;     // Profit factor (gross profit / gross loss)

   // Initialize the structure
   void              Init()
     {
      totalTrades = 0;
      winningTrades = 0;
      totalProfit = 0.0;
      totalLoss = 0.0;
      maxDrawdown = 0.0;
      maxProfit = 0.0;
      winRate = 0.0;
      profitFactor = 0.0;
     }

   // Update statistics with a new trade
   void              Update(const STradeRecord &trade)
     {
      if(trade.profit > 0)
        {
         winningTrades++;
         totalProfit += trade.profit;
        }
      else
        {
         totalLoss += MathAbs(trade.profit);
        }

      totalTrades++;

      // Update win rate
      if(totalTrades > 0)
        {
         winRate = (double)winningTrades / totalTrades * 100.0;
        }

      // Update profit factor
      if(totalLoss > 0)
        {
         profitFactor = totalProfit / totalLoss;
        }
      else
         if(totalProfit > 0)
           {
            profitFactor = DBL_MAX; // Perfect profit factor (no losses)
           }

      // Update max profit/drawdown
      if(trade.profit > maxProfit)
        {
         maxProfit = trade.profit;
        }

      double currentDrawdown = (totalLoss > 0) ? (totalLoss / (totalProfit + totalLoss)) * 100.0 : 0.0;
      if(currentDrawdown > maxDrawdown)
        {
         maxDrawdown = currentDrawdown;
        }
     }

   // Reset all statistics
   void              Reset()
     {
      Init();
     }

   // Calculate maximum drawdown for the trading stats
   double            CalculateDrawdown()
     {
      if(totalProfit <= 0)
         return 0.0;
      double total = totalProfit + MathAbs(totalLoss);
      return total > 0 ? (MathAbs(totalLoss) / total) * 100.0 : 0.0;
     }
  };

//+------------------------------------------------------------------+
//| Learning Parameters Structure                                     |
//+------------------------------------------------------------------+
struct SLearningParams
  {
   int               maFastPeriod;     // Fast MA period
   int               maSlowPeriod;     // Slow MA period
   double            stopLossPips;     // Stop loss in pips
   double            takeProfitPips;   // Take profit in pips
   double            riskPerTrade;     // Risk per trade as percentage of balance

   // Initialize the structure
   void              Init()
     {
      maFastPeriod = 10;
      maSlowPeriod = 20;
      stopLossPips = 30.0;
      takeProfitPips = 60.0;
      riskPerTrade = 1.0; // 1% risk per trade by default
     }
  };

//+------------------------------------------------------------------+
//| Market Condition Structure                                       |
//+------------------------------------------------------------------+
struct SMarketCondition
  {
   ENUM_MARKET_CONDITION condition;  // Current market condition
   double            strength;     // 0-100% strength of the condition
   double            volatility;   // Current market volatility (ATR based)
   double            trend;        // Current trend strength (-1 to 1)
   double            volume;       // Volume indicator value
   double            spread;       // Current spread in points
   datetime          lastUpdate; // Timestamp of last update

   // Default constructor
                     SMarketCondition()
     {
      Init();
     }

   // Copy constructor
                     SMarketCondition(const SMarketCondition &other)
     {
      condition = other.condition;
      strength = other.strength;
      volatility = other.volatility;
      trend = other.trend;
      volume = other.volume;
      spread = other.spread;
      lastUpdate = other.lastUpdate;
     }

   // Assignment operator
   void              operator=(const SMarketCondition &other)
     {
      // No need for self-assignment check in MQL5 structs
      condition = other.condition;
      strength = other.strength;
      volatility = other.volatility;
      trend = other.trend;
      volume = other.volume;
      spread = other.spread;
      lastUpdate = other.lastUpdate;
     }

   // Initialize the structure
   void              Init()
     {
      condition = MARKET_NORMAL;
      strength = 0;
      volatility = 0;
      trend = 0;
      volume = 0;
      spread = 0;
      lastUpdate = 0;
     }
  };

// Global variables
ENUM_TRADING_MODE g_tradingMode = MODE_PAPER;  // Current trading mode
STradeRecord g_tradeHistory[];                 // Dynamic array for trade history
STradingStats g_paperStats;                    // Paper trading statistics
STradingStats g_liveStats;                     // Live trading statistics
SLearningParams g_learningParams;              // Learning parameters
int g_currentOpenTrades = 0;                   // Current number of open trades
bool g_tradingEnabled = true;                  // Global trading flag
CTrade m_trade;                                // Trade object for order execution

// Indicator handles
int handle_iMA_4 = INVALID_HANDLE;             // Handle for 4-period MA
int handle_iMA_5 = INVALID_HANDLE;             // Handle for 10-period MA

// Logging parameters
input int      MaxLogSizeKB = 1024;         // Maximum log file size in KB (default 1MB)
input int      MaxLogFiles = 5;             // Maximum number of log files to keep

// Input parameters
input int      LearningWindow = 20;        // Number of trades to analyze for learning
input double   MinWinRateForLive = 80.0;   // Minimum win rate % to enable live trading
input double   MinLiveWinRate = 70.0;      // Minimum win rate to stay in live mode
input double   MaxDrawdownPct = 20.0;      // Maximum drawdown % before disabling live trading
input int      MAX_OPEN_TRADES = 5;        // Maximum number of open trades allowed

//+------------------------------------------------------------------+
//| Global variables for paper trading timing and state              |
//+------------------------------------------------------------------+
datetime g_lastSignalCheck = 0;       // Last time signals were checked (1-minute interval)
datetime g_lastLogUpdate = 0;         // Last time logs were updated (15-minute interval)
int g_signalsSentThisMinute = 0;      // Number of signals sent in current minute
const int MAX_SIGNALS_PER_MINUTE = 10; // Maximum signals to send per minute
const int SIGNAL_CHECK_INTERVAL = 60;  // Check signals every 60 seconds
const int LOG_UPDATE_INTERVAL = 900;   // Update logs every 15 minutes (900 seconds)

//+------------------------------------------------------------------+
//| Draw a buy signal arrow on the chart                            |
//+------------------------------------------------------------------+
void DrawBuySignal()
{
   string objName = "BuySignal_" + IntegerToString(TimeCurrent());
   
   // Create an up arrow for buy signals
   if(ObjectCreate(0, objName, OBJ_ARROW_UP, 0, TimeCurrent(), iLow(_Symbol, _Period, 0)))
   {
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
      ObjectSetString(0, objName, OBJPROP_TOOLTIP, "Paper Buy Signal\n" + TimeToString(TimeCurrent()));
      
      // Set the arrow to be visible on all timeframes
      long chartId = ChartID();
      ChartRedraw(chartId);
   }
   else
   {
      Print("Failed to create buy signal arrow. Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Draw a sell signal arrow on the chart                           |
//+------------------------------------------------------------------+
void DrawSellSignal()
{
   string objName = "SellSignal_" + IntegerToString(TimeCurrent());
   
   // Create a down arrow for sell signals
   if(ObjectCreate(0, objName, OBJ_ARROW_DOWN, 0, TimeCurrent(), iHigh(_Symbol, _Period, 0)))
   {
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_TOP);
      ObjectSetString(0, objName, OBJPROP_TOOLTIP, "Paper Sell Signal\n" + TimeToString(TimeCurrent()));
      
      // Set the arrow to be visible on all timeframes
      long chartId = ChartID();
      ChartRedraw(chartId);
   }
   else
   {
      Print("Failed to create sell signal arrow. Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Clean up old signal objects to prevent chart clutter             |
//+------------------------------------------------------------------+
void CleanupOldSignals()
{
   datetime oneWeekAgo = TimeCurrent() - 7 * 24 * 60 * 60; // One week ago
   
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      
      // Check if this is one of our signal objects
      if(StringFind(name, "BuySignal_") == 0 || StringFind(name, "SellSignal_") == 0)
      {
         // Get the time from the object name
         string timeStr = "";
         if(StringFind(name, "BuySignal_") == 0)
            timeStr = StringSubstr(name, 10);
         else if(StringFind(name, "SellSignal_") == 0)
            timeStr = StringSubstr(name, 11);
            
         // Convert to datetime and check if it's older than one week
         datetime signalTime = (datetime)StringToInteger(timeStr);
         if(signalTime < oneWeekAgo)
         {
            ObjectDelete(0, name);
         }
      }
   }
   
   // Redraw the chart to update the display
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Rotate log files to prevent them from growing too large         |
//+------------------------------------------------------------------+
void RotateLogs()
  {
   string log_path = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Logs\\";
   string log_file = log_path + "escape.log";
   
   // Check if log file exists and is too large
   int handle = FileOpen(log_file, FILE_READ|FILE_BIN|FILE_COMMON);
   if(handle != INVALID_HANDLE)
     {
      ulong file_size = FileSize(handle) / 1024; // Size in KB
      FileClose(handle);
      
      if(file_size >= (ulong)MaxLogSizeKB)
        {
         // Delete oldest log file if we've reached max number of logs
         string oldest_log = log_path + "escape_" + IntegerToString(MaxLogFiles-1) + ".log";
         if(FileIsExist(oldest_log, FILE_COMMON))
           {
            FileDelete(oldest_log, FILE_COMMON);
           }
         
         // Rotate existing log files
         for(int i = MaxLogFiles-2; i >= 0; i--)
           {
            string src = (i == 0) ? log_file : log_path + "escape_" + IntegerToString(i) + ".log";
            string dst = log_path + "escape_" + IntegerToString(i+1) + ".log";
            
            if(FileIsExist(src, FILE_COMMON))
              {
               if(FileIsExist(dst, FILE_COMMON))
                 {
                  FileDelete(dst, FILE_COMMON);
                 }
               FileMove(src, 0, dst, FILE_COMMON);
              }
           }
         
         // Create new empty log file
         int handle = FileOpen("escape.log", FILE_WRITE|FILE_TXT|FILE_COMMON);
         if(handle != INVALID_HANDLE)
           {
            FileWriteString(handle, "Log file rotated at " + TimeToString(TimeCurrent()) + "\r\n");
            FileClose(handle);
           }
         Print("Log file rotated. Current size: ", file_size, "KB");
        }
     }
  }

void Print(string message) {
   // Rotate logs if needed (check every 100 prints to avoid performance hit)
   static int printCount = 0;
   if(++printCount % 100 == 0) {
      RotateLogs();
   }
   
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   printf("%s: %s", timestamp, message);
   
   // Also write to log file
   int handle = FileOpen("escape.log", FILE_READ|FILE_WRITE|FILE_TXT|FILE_COMMON);
   if(handle != INVALID_HANDLE) {
      FileSeek(handle, 0, SEEK_END);
      FileWriteString(handle, timestamp + ": " + message + "\r\n");
      FileClose(handle);
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Rotate logs if needed
   RotateLogs();
   
   // Initialize trading objects
   m_trade.SetExpertMagicNumber(123456);
   m_trade.SetDeviationInPoints(10);
   m_trade.SetTypeFilling(ORDER_FILLING_FOK);

   // Initialize learning parameters with default values if needed
   g_learningParams.Init();
   
   // Set default MA periods if not already set
   if(g_learningParams.maFastPeriod < 1) g_learningParams.maFastPeriod = 5;
   if(g_learningParams.maSlowPeriod <= g_learningParams.maFastPeriod) 
      g_learningParams.maSlowPeriod = g_learningParams.maFastPeriod * 2;
      
   Print("Initializing indicators with MA periods: Fast=", g_learningParams.maFastPeriod,
         ", Slow=", g_learningParams.maSlowPeriod);

   // Initialize indicator handles with validated periods
   handle_iMA_4 = iMA(Symbol(), 0, g_learningParams.maFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   handle_iMA_5 = iMA(Symbol(), 0, g_learningParams.maSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);

   // Check if indicators were created successfully and have enough data
   if(handle_iMA_4 == INVALID_HANDLE || handle_iMA_5 == INVALID_HANDLE)
   {
      int error = GetLastError();
      Print("Error creating indicators. Error code: ", error);
      if(error == 4002)
      {
         Print("Error 4002: Invalid parameters for iMA. Please check the MA periods.");
      }
      return(INIT_FAILED);
   }
   
   // Wait for indicators to calculate
   int retries = 0;
   while(BarsCalculated(handle_iMA_4) == 0 || BarsCalculated(handle_iMA_5) == 0)
   {
      retries++;
      if(retries > 10) 
      {
         Print("Error: Indicators not ready after 10 retries");
         return(INIT_FAILED);
      }
      Sleep(100);
   }
   
   Print("Indicators initialized successfully");
   
   // Initialize and add trading strategies
   if(!AddStrategies())
   {
      Print("Failed to initialize trading strategies");
      return(INIT_FAILED);
   }
   Print("Trading strategies initialized successfully");
   Print("Total strategies loaded: ", g_strategyManager.GetTotalStrategies());

// Initialize trading statistics
   g_paperStats.Init();
   g_liveStats.Init();

// Load any saved state
   LoadTradingState();

   Print("EA initialized in ", EnumToString(g_tradingMode), " mode");
   Print("Learning Window: ", LearningWindow, " trades");
   Print("Minimum Win Rate for Live: ", MinWinRateForLive, "%");
   Print("Minimum Live Win Rate: ", MinLiveWinRate, "%");
   Print("Maximum Drawdown: ", MaxDrawdownPct, "%");
   Print("Max Open Trades: ", MAX_OPEN_TRADES);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
// Release indicator handles
   if(handle_iMA_4 != INVALID_HANDLE)
     {
      IndicatorRelease(handle_iMA_4);
     }

   if(handle_iMA_5 != INVALID_HANDLE)
     {
      IndicatorRelease(handle_iMA_5);
     }

// Save trading state
   SaveTradingState();

   Print("EA deinitialized. Reason: ", GetUninitReasonText(reason));
  }

//+------------------------------------------------------------------+
//| Get uninitialization reason text                                 |
//+------------------------------------------------------------------+
string GetUninitReasonText(int reasonCode)
  {
   string text="";
   switch(reasonCode)
     {
      case REASON_ACCOUNT:
         text = "Account was changed";
         break;
      case REASON_CHARTCHANGE:
         text = "Symbol or timeframe was changed";
         break;
      case REASON_CHARTCLOSE:
         text = "Chart was closed";
         break;
      case REASON_PARAMETERS:
         text = "Input-parameter was changed";
         break;
      case REASON_RECOMPILE:
         text = "Program was recompiled";
         break;
      case REASON_REMOVE:
         text = "Program was removed from chart";
         break;
      case REASON_TEMPLATE:
         text = "New template was applied to chart";
         break;
      default:
         text = "Unknown reason";
     }
   return text;
  }



//+------------------------------------------------------------------+
//| Reset trading statistics                                         |
//+------------------------------------------------------------------+
void ResetTradingStats()
  {
   g_paperStats.Init();
   g_liveStats.Init();
  }

//+------------------------------------------------------------------+
//| Update trading statistics with a new trade                       |
//+------------------------------------------------------------------+
void UpdateTradingStats(const STradeRecord &trade)
  {
   if(trade.isLive)
     {
      g_liveStats.Update(trade);
     }
   else
     {
      g_paperStats.Update(trade);
     }
  }

//+------------------------------------------------------------------+
//| Record a new trade                                               |
//+------------------------------------------------------------------+
void RecordTrade(const STradeRecord &trade)
  {
   int size = ArraySize(g_tradeHistory);
   ArrayResize(g_tradeHistory, size + 1);
   g_tradeHistory[size] = trade;

// Update statistics
   UpdateTradingStats(trade);

// Check if it's time to learn
   if((g_paperStats.totalTrades % LearningWindow) == 0)
     {
      LearnFromTrades();
     }

// Check if we should switch modes
   CheckTradingMode();
  }

//+------------------------------------------------------------------+
//| Get market condition                                             |
//+------------------------------------------------------------------+
SMarketCondition GetMarketCondition()
  {
   SMarketCondition condition;
   condition.Init();

// Get technical indicators using helper functions
   double rsi = GetRSI(Symbol(), PERIOD_CURRENT, 14, 0);
   double atr = GetATR(Symbol(), PERIOD_CURRENT, 14, 0);
   double spread = (double)SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) * _Point;

   // If RSI or ATR is -1, suppress further calculations and return default condition
   if(rsi == -1 || atr == -1)
   {
      static datetime lastRSIError = 0;
      if(TimeCurrent() - lastRSIError > 60) // Only print once per minute
      {
         Print("Insufficient bars for RSI/ATR calculation. Waiting for more data...");
         lastRSIError = TimeCurrent();
      }
      condition.condition = MARKET_NORMAL;
      condition.lastUpdate = TimeCurrent();
      return condition;
   }

   // Calculate trend and volatility
   condition.trend = (rsi - 50.0) * 2.0;  // Convert RSI to -100 to +100 range
   condition.volatility = MathMin(atr / _Point / 10.0, 100.0);  // Scale ATR to 0-100 range
   condition.volume = 50.0;  // Placeholder for volume analysis
   condition.spread = spread / _Point;

   // Determine market state based on conditions
   if(spread > 30 * _Point)
     {
      condition.condition = MARKET_HIGH_SPREAD;
     }
   else
      if(condition.volatility > 70)
        {
         condition.condition = MARKET_VOLATILE;
        }
      else
         if(condition.trend > 70)
           {
            condition.condition = MARKET_TREND_UP;
           }
         else
            if(condition.trend < 30)
              {
               condition.condition = MARKET_TREND_DOWN;
              }
            else
              {
               condition.condition = MARKET_NORMAL;
              }

   condition.lastUpdate = TimeCurrent();
   return condition;
  }

//+------------------------------------------------------------------+
//| Get RSI value                                                    |
//+------------------------------------------------------------------+
double GetRSI(string symbol, ENUM_TIMEFRAMES timeframe, int period, int shift = 0)
  {
   // Check for enough bars before requesting indicator data
   if(Bars(symbol, timeframe) < period + shift)
   {
      static datetime lastRSIError = 0;
      if(TimeCurrent() - lastRSIError > 60) // Only print once per minute
      {
         Print("Not enough bars for RSI calculation. Required: ", period + shift, ", Available: ", Bars(symbol, timeframe));
         lastRSIError = TimeCurrent();
      }
      return -1;
   }
   double buffer[];
   ArraySetAsSeries(buffer, true);
   int handle = iRSI(symbol, timeframe, period, PRICE_CLOSE);
   if(handle == INVALID_HANDLE)
      return -1;

   int copied = CopyBuffer(handle, 0, shift, 1, buffer);
   if(copied <= 0)
     {
      static datetime lastRSIErrorCopy = 0;
      if(TimeCurrent() - lastRSIErrorCopy > 60)
      {
         // Suppress repeated error messages for RSI
         Print("(Suppressed) Error getting RSI values. Copied: ", copied, ", Error: ", GetLastError());
         lastRSIErrorCopy = TimeCurrent();
      }
      IndicatorRelease(handle);
      return -1;
     }

   double value = buffer[0];
   IndicatorRelease(handle);
   return value;
  }

//+------------------------------------------------------------------+
//| Get ATR value                                                    |
//+------------------------------------------------------------------+
double GetATR(string symbol, ENUM_TIMEFRAMES timeframe, int period, int shift = 0)
  {
   // Check for enough bars before requesting indicator data
   if(Bars(symbol, timeframe) < period + shift)
   {
      static datetime lastATRError = 0;
      if(TimeCurrent() - lastATRError > 60)
      {
         Print("Not enough bars for ATR calculation. Required: ", period + shift, ", Available: ", Bars(symbol, timeframe));
         lastATRError = TimeCurrent();
      }
      return -1;
   }
   double buffer[];
   ArraySetAsSeries(buffer, true);
   int handle = iATR(symbol, timeframe, period);
   if(handle == INVALID_HANDLE)
      return -1;

   int copied = CopyBuffer(handle, 0, shift, 1, buffer);
   if(copied <= 0)
     {
      static datetime lastATRErrorCopy = 0;
      if(TimeCurrent() - lastATRErrorCopy > 60)
      {
         // Suppress repeated error messages for ATR
         Print("(Suppressed) Error getting ATR values. Copied: ", copied, ", Error: ", GetLastError());
         lastATRErrorCopy = TimeCurrent();
      }
      IndicatorRelease(handle);
      return -1;
     }

   double value = buffer[0];
   IndicatorRelease(handle);
   return value;
  }

//+------------------------------------------------------------------+
//| Market Condition Analysis                                        |
//+------------------------------------------------------------------+
enum ENUM_MARKET_STATE
  {
   MARKET_STATE_NORMAL = 0,            // Normal market conditions
   MARKET_STATE_HIGH_VOLATILITY = 1,   // High volatility detected
   MARKET_STATE_LOW_VOLATILITY = 2,    // Low volatility detected
   MARKET_STATE_STRONG_TREND_UP = 3,   // Strong uptrend
   MARKET_STATE_STRONG_TREND_DOWN = 4, // Strong downtrend
   MARKET_STATE_RANGING = 5,           // Sideways market
   MARKET_STATE_BREAKOUT = 6,          // Breakout detected
   MARKET_STATE_HIGH_SPREAD = 7,       // High spread detected
   MARKET_STATE_NEWS_EVENT = 8,        // News event detected
   MARKET_STATE_OPENING = 9,           // Market opening
   MARKET_STATE_CLOSING = 10,          // Market closing
   MARKET_STATE_THIN = 11,             // Thin market (low liquidity)
   MARKET_STATE_GAP = 12               // Price gap detected
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double MarketInfo(string symbol, int type)
  {
   switch(type)
     {
      case 6:  // MODE_MARGINREQUIRED
         return SymbolInfoDouble(symbol, SYMBOL_MARGIN_INITIAL);
      // Add other cases as needed
      default:
         return 0.0;
     }
  }

// Using MathAbs() instead of redefining abs()

//+------------------------------------------------------------------+
//| Execute a market order                                           |
//+------------------------------------------------------------------+
bool ExecuteMarketOrder(ENUM_ORDER_TYPE orderType, double lots, double stopLossPips, double takeProfitPips, string comment = "")
  {
   if(!g_tradingEnabled)
     {
      Print("Trading is currently disabled");
      return false;
     }

   bool isLive = (g_tradingMode == MODE_LIVE || (g_tradingMode == MODE_HYBRID && MathRand() % 2 == 0));

// For paper trades, just record the trade without executing
   if(!isLive)
     {
      MqlTick last_tick;
      if(!SymbolInfoTick(Symbol(), last_tick))
      {
         Print("Error getting tick data for paper trading");
         return false;
      }
      
      STradeRecord trade = {};
      trade.Init();
      trade.openTime = TimeCurrent();
      trade.symbol = Symbol();
      trade.type = orderType;
      trade.volume = lots;
      trade.isLive = false;
      
      // Log paper trade details
      string orderTypeStr = (orderType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
      Print("Paper Trade Signal: ", orderTypeStr, " ", DoubleToString(lots, 2), " lots");
      Print("Current Ask: ", last_tick.ask, " Bid: ", last_tick.bid);
      
      // Set prices based on order type
      if(orderType == ORDER_TYPE_BUY)
      {
         trade.openPrice = last_tick.ask;
         trade.stopLoss = trade.openPrice - stopLossPips * _Point * 10;
         trade.takeProfit = trade.openPrice + takeProfitPips * _Point * 10;
         Print("BUY Order - Price: ", trade.openPrice, " SL: ", trade.stopLoss, " TP: ", trade.takeProfit);
      }
      else
      {
         trade.openPrice = last_tick.bid;
         trade.stopLoss = trade.openPrice + stopLossPips * _Point * 10;
         trade.takeProfit = trade.openPrice - takeProfitPips * _Point * 10;
         Print("SELL Order - Price: ", trade.openPrice, " SL: ", trade.stopLoss, " TP: ", trade.takeProfit);
      }
      
      // Log the paper trade execution
      Print("Paper Trade Executed - ", orderTypeStr, " ", DoubleToString(lots, 2), " lots at ", 
            trade.openPrice, " (SL: ", trade.stopLoss, " TP: ", trade.takeProfit, ")");
      
      // Simulate trade close after a random period
      trade.closeTime = trade.openTime + (MathRand() % 86400 + 3600);

      // Simulate random win/loss for paper trading
      bool isWin = (MathRand() % 100) < (g_learningParams.maFastPeriod > g_learningParams.maSlowPeriod ? 60 : 40);
      if(isWin)
        {
         trade.closePrice = orderType == ORDER_TYPE_BUY ?
                            trade.openPrice + (MathRand() % (int)(takeProfitPips * 10) + 10) * _Point :
                            trade.openPrice - (MathRand() % (int)(takeProfitPips * 10) + 10) * _Point;
        }
      else
        {
         trade.closePrice = orderType == ORDER_TYPE_BUY ?
                            trade.openPrice - (MathRand() % (int)(stopLossPips * 10) + 5) * _Point :
                            trade.openPrice + (MathRand() % (int)(stopLossPips * 10) + 5) * _Point;
        }

      trade.profit = (orderType == ORDER_TYPE_BUY) ?
                     (trade.closePrice - trade.openPrice) * trade.volume * 100000 :
                     (trade.openPrice - trade.closePrice) * trade.volume * 100000;

      // Store trade parameters in the comment field since we don't have separate fields anymore
      trade.comment = StringFormat("MA_Fast=%.0f,MA_Slow=%.0f,SL=%.1f,TP=%.1f,Win=%d",
                                   g_learningParams.maFastPeriod,
                                   g_learningParams.maSlowPeriod,
                                   stopLossPips,
                                   takeProfitPips,
                                   (int)isWin);

      RecordTrade(trade);
      
      // Update statistics
      if(trade.profit > 0)
         Print("Paper Trade Result: PROFIT ", trade.profit);
      else if(trade.profit < 0)
         Print("Paper Trade Result: LOSS ", trade.profit);
      else
         Print("Paper Trade Result: BREAKEVEN");
         
      return true;
     }

// Live trade execution
   double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(Symbol(), SYMBOL_ASK) :
                  SymbolInfoDouble(Symbol(), SYMBOL_BID);

   double sl = (orderType == ORDER_TYPE_BUY) ? price - stopLossPips * _Point * 10 :
               price + stopLossPips * _Point * 10;

   double tp = (orderType == ORDER_TYPE_BUY) ? price + takeProfitPips * _Point * 10 :
               price - takeProfitPips * _Point * 10;

   bool result = false;
   if(orderType == ORDER_TYPE_BUY)
     {
      result = m_trade.Buy(lots, Symbol(), price, sl, tp, comment);
     }
   else
     {
      result = m_trade.Sell(lots, Symbol(), price, sl, tp, comment);
     }

   if(result)
     {
      STradeRecord tradeRecord = {};
      tradeRecord.Init();
      tradeRecord.ticket = m_trade.ResultOrder();
      tradeRecord.openTime = TimeCurrent();
      tradeRecord.type = orderType;
      tradeRecord.symbol = Symbol();
      tradeRecord.volume = lots;
      tradeRecord.openPrice = price;
      tradeRecord.stopLoss = sl;
      tradeRecord.takeProfit = tp;
      tradeRecord.isLive = true;

      // Store trade parameters in the comment field
      tradeRecord.comment = StringFormat("MA_Fast=%.0f,MA_Slow=%.0f,SL=%.1f,TP=%.1f",
                                         g_learningParams.maFastPeriod,
                                         g_learningParams.maSlowPeriod,
                                         stopLossPips,
                                         takeProfitPips);

      RecordTrade(tradeRecord);
      Print("Live trade executed: ", EnumToString(orderType), " ", tradeRecord.volume, " lots at ", price);
     }
   else
     {
      Print("Failed to execute live trade. Error: ", GetLastError());
     }

   return result;
  }

//+------------------------------------------------------------------+
//| Strategy Interface                                              |
//+------------------------------------------------------------------+
interface IStrategy
{
public:
   virtual bool Init() = 0;
   virtual void Deinit() = 0;
   virtual bool CheckLongSignal() = 0;
   virtual bool CheckShortSignal() = 0;
   virtual double GetStopLossPips(bool isLong) = 0;
   virtual double GetTakeProfitPips(bool isLong) = 0;
   virtual string GetName() = 0;
};

//+------------------------------------------------------------------+
//| Strategy Manager                                                |
//+------------------------------------------------------------------+
class CStrategyManager
{
private:
   IStrategy* m_strategies[];
   int m_totalStrategies;
   
public:
   CStrategyManager() : m_totalStrategies(0) {}
   
   ~CStrategyManager()
   {
      for(int i = 0; i < m_totalStrategies; i++)
         delete m_strategies[i];
      ArrayFree(m_strategies);
   }
   
   bool AddStrategy(IStrategy* strategy)
   {
      if(!strategy.Init())
      {
         Print("Failed to initialize strategy: ", strategy.GetName());
         delete strategy;
         return false;
      }
      
      int size = ArraySize(m_strategies);
      if(ArrayResize(m_strategies, size + 1) == -1)
      {
         Print("Failed to resize strategies array");
         delete strategy;
         return false;
      }
      
      m_strategies[size] = strategy;
      m_totalStrategies++;
      Print("Strategy added: ", strategy.GetName());
      return true;
   }
   
   bool CheckLongSignal()
   {
      for(int i = 0; i < m_totalStrategies; i++)
      {
         if(m_strategies[i].CheckLongSignal())
         {
            Print("Long signal from strategy: ", m_strategies[i].GetName());
            return true;
         }
      }
      return false;
   }
   
   bool CheckShortSignal()
   {
      for(int i = 0; i < m_totalStrategies; i++)
      {
         if(m_strategies[i].CheckShortSignal())
         {
            Print("Short signal from strategy: ", m_strategies[i].GetName());
            return true;
         }
      }
      return false;
   }
   
   double GetStopLossPips(bool isLong)
   {
      // Default values
      double sl = isLong ? 20.0 : 20.0; // Default 20 pips
      
      // Get the most conservative (largest) stop loss from all strategies
      for(int i = 0; i < m_totalStrategies; i++)
      {
         double strategySL = m_strategies[i].GetStopLossPips(isLong);
         if(strategySL > sl)
            sl = strategySL;
      }
      
      return sl;
   }
   
   double GetTakeProfitPips(bool isLong)
   {
      // Default values
      double tp = isLong ? 40.0 : 40.0; // Default 40 pips
      
      // Get the most conservative (smallest) take profit from all strategies
      for(int i = 0; i < m_totalStrategies; i++)
      {
         double strategyTP = m_strategies[i].GetTakeProfitPips(isLong);
         if(strategyTP > 0 && (strategyTP < tp || tp == 0))
            tp = strategyTP;
      }
      
      return tp;
   }
   
   // Get the total number of strategies currently loaded
   int GetTotalStrategies() const { return m_totalStrategies; }
};

//+------------------------------------------------------------------+
//| Bollinger Bands Strategy                                        |
//+------------------------------------------------------------------+
class CBollingerBandsStrategy : public IStrategy
{
private:
   int m_bbHandle;
   int m_bbPeriod;
   double m_bbDeviation;
   int m_atrHandle;
   
public:
   CBollingerBandsStrategy(int period = 20, double deviation = 2.0) : 
      m_bbHandle(INVALID_HANDLE),
      m_bbPeriod(period),
      m_bbDeviation(deviation),
      m_atrHandle(INVALID_HANDLE) {}
      
   ~CBollingerBandsStrategy()
   {
      if(m_bbHandle != INVALID_HANDLE) IndicatorRelease(m_bbHandle);
      if(m_atrHandle != INVALID_HANDLE) IndicatorRelease(m_atrHandle);
   }
   
   bool Init() override
   {
      m_bbHandle = iBands(_Symbol, _Period, m_bbPeriod, 0, m_bbDeviation, PRICE_CLOSE);
      m_atrHandle = iATR(_Symbol, _Period, 14);
      
      if(m_bbHandle == INVALID_HANDLE || m_atrHandle == INVALID_HANDLE)
      {
         Print("Failed to create indicators for Bollinger Bands Strategy");
         return false;
      }
      
      return true;
   }
   
   void Deinit() override
   {
      if(m_bbHandle != INVALID_HANDLE) IndicatorRelease(m_bbHandle);
      if(m_atrHandle != INVALID_HANDLE) IndicatorRelease(m_atrHandle);
      
      m_bbHandle = INVALID_HANDLE;
      m_atrHandle = INVALID_HANDLE;
   }
   
   bool CheckLongSignal() override
   {
      double upperBand[2], middleBand[2], lowerBand[2], close[2];
      
      if(CopyBuffer(m_bbHandle, 1, 0, 2, upperBand) != 2 ||
         CopyBuffer(m_bbHandle, 0, 0, 2, middleBand) != 2 ||
         CopyBuffer(m_bbHandle, 2, 0, 2, lowerBand) != 2)
      {
         Print("Error getting Bollinger Bands values");
         return false;
      }
      
      // Get close prices
      if(CopyClose(_Symbol, _Period, 0, 2, close) != 2)
      {
         Print("Error getting close prices");
         return false;
      }
      
      // Buy when price bounces off the lower band
      return (close[1] <= lowerBand[1] && close[0] > lowerBand[0]);
   }
   
   bool CheckShortSignal() override
   {
      double upperBand[2], middleBand[2], lowerBand[2], close[2];
      
      if(CopyBuffer(m_bbHandle, 1, 0, 2, upperBand) != 2 ||
         CopyBuffer(m_bbHandle, 0, 0, 2, middleBand) != 2 ||
         CopyBuffer(m_bbHandle, 2, 0, 2, lowerBand) != 2)
      {
         Print("Error getting Bollinger Bands values");
         return false;
      }
      
      // Get close prices
      if(CopyClose(_Symbol, _Period, 0, 2, close) != 2)
      {
         Print("Error getting close prices");
         return false;
      }
      
      // Sell when price bounces off the upper band
      return (close[1] >= upperBand[1] && close[0] < upperBand[0]);
   }
   
   double GetStopLossPips(bool isLong) override
   {
      double atr[1];
      if(CopyBuffer(m_atrHandle, 0, 0, 1, atr) != 1)
         return isLong ? 20.0 : 20.0; // Default 20 pips
         
      // Use 1.8 * ATR for dynamic stop loss
      double atrPips = atr[0] / _Point;
      return MathMax(atrPips * 1.8, 10.0); // Minimum 10 pips
   }
   
   double GetTakeProfitPips(bool isLong) override
   {
      // 2:1 risk-reward ratio
      return GetStopLossPips(isLong) * 2.0;
   }
   
   string GetName() override 
   { 
      return StringFormat("Bollinger Bands(%d,%.1f) Strategy", m_bbPeriod, m_bbDeviation); 
   }
};

//+------------------------------------------------------------------+
//| MACD Strategy                                                   |
//+------------------------------------------------------------------+
class CMACDStrategy : public IStrategy
{
private:
   int m_macdHandle;
   int m_fastEMA;
   int m_slowEMA;
   int m_signalPeriod;
   int m_atrHandle;
   
public:
   CMACDStrategy(int fastEMA = 12, int slowEMA = 26, int signalPeriod = 9) : 
      m_macdHandle(INVALID_HANDLE),
      m_fastEMA(fastEMA),
      m_slowEMA(slowEMA),
      m_signalPeriod(signalPeriod),
      m_atrHandle(INVALID_HANDLE) {}
      
   ~CMACDStrategy()
   {
      if(m_macdHandle != INVALID_HANDLE) IndicatorRelease(m_macdHandle);
      if(m_atrHandle != INVALID_HANDLE) IndicatorRelease(m_atrHandle);
   }
   
   bool Init() override
   {
      m_macdHandle = iMACD(_Symbol, _Period, m_fastEMA, m_slowEMA, m_signalPeriod, PRICE_CLOSE);
      m_atrHandle = iATR(_Symbol, _Period, 14);
      
      if(m_macdHandle == INVALID_HANDLE || m_atrHandle == INVALID_HANDLE)
      {
         Print("Failed to create indicators for MACD Strategy");
         return false;
      }
      
      return true;
   }
   
   void Deinit() override
   {
      if(m_macdHandle != INVALID_HANDLE) IndicatorRelease(m_macdHandle);
      if(m_atrHandle != INVALID_HANDLE) IndicatorRelease(m_atrHandle);
      
      m_macdHandle = INVALID_HANDLE;
      m_atrHandle = INVALID_HANDLE;
   }
   
   bool CheckLongSignal() override
   {
      double macdMain[3], macdSignal[3];
      
      if(CopyBuffer(m_macdHandle, 0, 0, 3, macdMain) != 3 ||
         CopyBuffer(m_macdHandle, 1, 0, 3, macdSignal) != 3)
      {
         Print("Error getting MACD values");
         return false;
      }
      
      // Buy when MACD crosses above signal line
      return (macdMain[1] <= macdSignal[1] && macdMain[0] > macdSignal[0]);
   }
   
   bool CheckShortSignal() override
   {
      double macdMain[3], macdSignal[3];
      
      if(CopyBuffer(m_macdHandle, 0, 0, 3, macdMain) != 3 ||
         CopyBuffer(m_macdHandle, 1, 0, 3, macdSignal) != 3)
      {
         Print("Error getting MACD values");
         return false;
      }
      
      // Sell when MACD crosses below signal line
      return (macdMain[1] >= macdSignal[1] && macdMain[0] < macdSignal[0]);
   }
   
   double GetStopLossPips(bool isLong) override
   {
      double atr[1];
      if(CopyBuffer(m_atrHandle, 0, 0, 1, atr) != 1)
         return isLong ? 20.0 : 20.0; // Default 20 pips
         
      // Use 2.0 * ATR for dynamic stop loss
      double atrPips = atr[0] / _Point;
      return MathMax(atrPips * 2.0, 10.0); // Minimum 10 pips
   }
   
   double GetTakeProfitPips(bool isLong) override
   {
      // 3:1 risk-reward ratio for MACD strategy
      return GetStopLossPips(isLong) * 3.0;
   }
   
   string GetName() override 
   { 
      return StringFormat("MACD(%d,%d,%d) Strategy", m_fastEMA, m_slowEMA, m_signalPeriod); 
   }
};

//+------------------------------------------------------------------+
//| RSI Strategy                                                    |
//+------------------------------------------------------------------+
class CRSIStrategy : public IStrategy
{
private:
   int m_rsiHandle;
   int m_rsiPeriod;
   double m_overbought;
   double m_oversold;
   int m_maHandle;
   int m_atrHandle;
   
   bool CheckDivergence(bool isBullish)
   {
      // Simple divergence detection
      double rsi[5], low[5], high[5];
      
      if(CopyBuffer(m_rsiHandle, 0, 0, 5, rsi) != 5 ||
         CopyLow(_Symbol, _Period, 0, 5, low) != 5 ||
         CopyHigh(_Symbol, _Period, 0, 5, high) != 5)
      {
         return false;
      }
      
      if(isBullish)
      {
         // Bullish divergence: price makes lower low but RSI makes higher low
         return (low[0] < low[2] && rsi[0] > rsi[2]);
      }
      else
      {
         // Bearish divergence: price makes higher high but RSI makes lower high
         return (high[0] > high[2] && rsi[0] < rsi[2]);
      }
   }
   
   bool CheckMAConfirmation()
   {
      double rsi[2], ma[2];
      
      if(CopyBuffer(m_rsiHandle, 0, 0, 2, rsi) != 2 ||
         CopyBuffer(m_maHandle, 0, 0, 2, ma) != 2)
      {
         return true; // Default to true if we can't get the data
      }
      
      // Check if RSI is above its MA (bullish) or below (bearish)
      return (rsi[0] > ma[0]);
   }
   
public:
   CRSIStrategy(int period = 14, double overbought = 70.0, double oversold = 30.0) : 
      m_rsiHandle(INVALID_HANDLE),
      m_rsiPeriod(period),
      m_overbought(overbought),
      m_oversold(oversold),
      m_maHandle(INVALID_HANDLE),
      m_atrHandle(INVALID_HANDLE) {}
      
   ~CRSIStrategy()
   {
      if(m_rsiHandle != INVALID_HANDLE) IndicatorRelease(m_rsiHandle);
      if(m_maHandle != INVALID_HANDLE) IndicatorRelease(m_maHandle);
      if(m_atrHandle != INVALID_HANDLE) IndicatorRelease(m_atrHandle);
   }
   
   bool Init() override
   {
      // Initialize RSI indicator
      m_rsiHandle = iRSI(_Symbol, _Period, m_rsiPeriod, PRICE_CLOSE);
      if(m_rsiHandle == INVALID_HANDLE)
      {
         Print("Failed to create RSI indicator. Error: ", GetLastError());
         return false;
      }
      
      // Initialize Moving Average indicator
      m_maHandle = iMA(_Symbol, _Period, 14, 0, MODE_SMA, PRICE_CLOSE);
      if(m_maHandle == INVALID_HANDLE)
      {
         Print("Failed to create MA indicator. Error: ", GetLastError());
         return false;
      }
      
      // Initialize ATR indicator for dynamic stop loss
      m_atrHandle = iATR(_Symbol, _Period, 14);
      if(m_atrHandle == INVALID_HANDLE)
      {
         Print("Failed to create ATR indicator. Error: ", GetLastError());
         return false;
      }
      
      // Wait for indicators to calculate
      int retries = 0;
      while(BarsCalculated(m_rsiHandle) == 0 || BarsCalculated(m_maHandle) == 0 || BarsCalculated(m_atrHandle) == 0)
      {
         retries++;
         if(retries > 10) 
         {
            Print("Error: Indicators not ready after 10 retries");
            return false;
         }
         Sleep(100);
      }
      
      return true;
   }
   
   void Deinit() override
   {
      if(m_rsiHandle != INVALID_HANDLE) IndicatorRelease(m_rsiHandle);
      if(m_maHandle != INVALID_HANDLE) IndicatorRelease(m_maHandle);
      if(m_atrHandle != INVALID_HANDLE) IndicatorRelease(m_atrHandle);
      
      m_rsiHandle = INVALID_HANDLE;
      m_maHandle = INVALID_HANDLE;
      m_atrHandle = INVALID_HANDLE;
   }
   
   bool CheckLongSignal() override
   {
      // Check if indicator handle is valid
      if(m_rsiHandle == INVALID_HANDLE) 
      {
         Print("RSI handle not valid in CheckLongSignal");
         return false;
      }
      
      // Get RSI values with error checking
      double rsi[3] = {0};
      int copied = CopyBuffer(m_rsiHandle, 0, 0, 3, rsi);
      if(copied != 3)
      {
         Print("Error getting RSI values. Copied: ", copied, ", Error: ", GetLastError());
         return false;
      }
      
      // Check for valid RSI values
      if(rsi[0] == 0 || rsi[1] == 0 || rsi[2] == 0)
      {
         Print("Invalid RSI values: ", rsi[0], ", ", rsi[1], ", ", rsi[2]);
         return false;
      }
      
      // Check for oversold condition
      bool isOversold = (rsi[1] <= m_oversold && rsi[0] > m_oversold);
      
      // Check for bullish divergence
      bool hasBullishDivergence = CheckDivergence(true);
      
      // Check MA confirmation
      bool maConfirmation = CheckMAConfirmation();
      
      // Buy when RSI crosses above oversold level with confirmation
      return (isOversold || hasBullishDivergence) && maConfirmation;
   }
   
   bool CheckShortSignal() override
   {
      // Check if indicator handle is valid
      if(m_rsiHandle == INVALID_HANDLE) 
      {
         Print("RSI handle not valid in CheckShortSignal");
         return false;
      }
      
      // Get RSI values with error checking
      double rsi[3] = {0};
      int copied = CopyBuffer(m_rsiHandle, 0, 0, 3, rsi);
      if(copied != 3)
      {
         Print("Error getting RSI values. Copied: ", copied, ", Error: ", GetLastError());
         return false;
      }
      
      // Check for valid RSI values
      if(rsi[0] == 0 || rsi[1] == 0 || rsi[2] == 0)
      {
         Print("Invalid RSI values: ", rsi[0], ", ", rsi[1], ", ", rsi[2]);
         return false;
      }
      
      // Check for overbought condition
      bool isOverbought = (rsi[1] >= m_overbought && rsi[0] < m_overbought);
      
      // Check for bearish divergence
      bool hasBearishDivergence = CheckDivergence(false);
      
      // Check MA confirmation (inverse for short)
      bool maConfirmation = !CheckMAConfirmation();
      
      // Sell when RSI crosses below overbought level with confirmation
      return (isOverbought || hasBearishDivergence) && maConfirmation;
   }
   
   double GetStopLossPips(bool isLong) override
   {
      double atr[1];
      if(CopyBuffer(m_atrHandle, 0, 0, 1, atr) != 1)
         return isLong ? 20.0 : 20.0; // Default 20 pips
         
      // Use 1.5 * ATR for dynamic stop loss
      double atrPips = atr[0] / _Point;
      return MathMax(atrPips * 1.5, 10.0); // Minimum 10 pips
   }
   
   double GetTakeProfitPips(bool isLong) override
   {
      // 2.5:1 risk-reward ratio for RSI strategy
      return GetStopLossPips(isLong) * 2.5;
   }
   
   string GetName() override 
   { 
      return StringFormat("RSI(%d) Strategy", m_rsiPeriod); 
   }
};

//+------------------------------------------------------------------+
//| Moving Average Crossover Strategy                                |
//+------------------------------------------------------------------+
class CMAStrategy : public IStrategy
{
private:
   int m_maFastHandle;
   int m_maSlowHandle;
   int m_volumeHandle;
   int m_atrHandle;
   int m_maFastPeriod;
   int m_maSlowPeriod;
   ENUM_TIMEFRAMES m_higherTimeframe;
   int m_maFastHandleHTF;
   int m_maSlowHandleHTF;
   
   bool CheckVolumeConfirmation()
   {
      double volume[2];
      if(CopyBuffer(m_volumeHandle, 0, 0, 2, volume) != 2)
         return true; // Default to true if we can't get volume data
         
      // Get more volume data for the moving average calculation
      double volumeData[20];
      if(CopyBuffer(m_volumeHandle, 0, 0, 20, volumeData) != 20)
         return true; // Default to true if we can't get enough volume data
         
      // Calculate 20-period SMA of volume using iMAOnArray
      double avgVolume = 0;
      for(int i = 0; i < 20; i++)
         avgVolume += volumeData[i];
      avgVolume /= 20.0;
      
      return (volume[1] > avgVolume);
   }
   
   bool CheckVolatility()
   {
      double atr[1];
      if(CopyBuffer(m_atrHandle, 0, 0, 1, atr) != 1)
         return true; // Default to true if we can't get ATR data
         
      // Only trade if volatility is above minimum threshold
      return (atr[0] > (10 * _Point));
   }
   
   bool CheckHigherTimeframeTrend()
   {
      double maFastHTF[2], maSlowHTF[2];
      
      if(CopyBuffer(m_maFastHandleHTF, 0, 0, 2, maFastHTF) != 2 ||
         CopyBuffer(m_maSlowHandleHTF, 0, 0, 2, maSlowHTF) != 2)
         return true; // Default to true if we can't get HTF data
         
      // Check if higher timeframe trend is up
      return (maFastHTF[0] > maSlowHTF[0]);
   }
   
public:
   CMAStrategy(int fastPeriod = 10, int slowPeriod = 20, ENUM_TIMEFRAMES higherTimeframe = PERIOD_H1) : 
      m_maFastHandle(INVALID_HANDLE),
      m_maSlowHandle(INVALID_HANDLE),
      m_volumeHandle(INVALID_HANDLE),
      m_atrHandle(INVALID_HANDLE),
      m_maFastPeriod(fastPeriod),
      m_maSlowPeriod(slowPeriod),
      m_higherTimeframe(higherTimeframe),
      m_maFastHandleHTF(INVALID_HANDLE),
      m_maSlowHandleHTF(INVALID_HANDLE) {}
      
   ~CMAStrategy()
   {
      if(m_maFastHandle != INVALID_HANDLE) IndicatorRelease(m_maFastHandle);
      if(m_maSlowHandle != INVALID_HANDLE) IndicatorRelease(m_maSlowHandle);
      if(m_volumeHandle != INVALID_HANDLE) IndicatorRelease(m_volumeHandle);
      if(m_atrHandle != INVALID_HANDLE) IndicatorRelease(m_atrHandle);
      if(m_maFastHandleHTF != INVALID_HANDLE) IndicatorRelease(m_maFastHandleHTF);
      if(m_maSlowHandleHTF != INVALID_HANDLE) IndicatorRelease(m_maSlowHandleHTF);
   }
   
   bool Init() override
   {
      // Initialize indicators for current timeframe
      m_maFastHandle = iMA(_Symbol, _Period, m_maFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
      m_maSlowHandle = iMA(_Symbol, _Period, m_maSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
      m_volumeHandle = iVolumes(_Symbol, _Period, VOLUME_TICK);
      m_atrHandle = iATR(_Symbol, _Period, 14);
      
      // Initialize indicators for higher timeframe
      m_maFastHandleHTF = iMA(_Symbol, m_higherTimeframe, m_maFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
      m_maSlowHandleHTF = iMA(_Symbol, m_higherTimeframe, m_maSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
      
      if(m_maFastHandle == INVALID_HANDLE || m_maSlowHandle == INVALID_HANDLE ||
         m_volumeHandle == INVALID_HANDLE || m_atrHandle == INVALID_HANDLE ||
         m_maFastHandleHTF == INVALID_HANDLE || m_maSlowHandleHTF == INVALID_HANDLE)
      {
         Print("Failed to create indicators for MA Crossover Strategy");
         return false;
      }
      
      return true;
   }
   
   void Deinit() override
   {
      if(m_maFastHandle != INVALID_HANDLE) IndicatorRelease(m_maFastHandle);
      if(m_maSlowHandle != INVALID_HANDLE) IndicatorRelease(m_maSlowHandle);
      if(m_volumeHandle != INVALID_HANDLE) IndicatorRelease(m_volumeHandle);
      if(m_atrHandle != INVALID_HANDLE) IndicatorRelease(m_atrHandle);
      if(m_maFastHandleHTF != INVALID_HANDLE) IndicatorRelease(m_maFastHandleHTF);
      if(m_maSlowHandleHTF != INVALID_HANDLE) IndicatorRelease(m_maSlowHandleHTF);
      
      m_maFastHandle = INVALID_HANDLE;
      m_maSlowHandle = INVALID_HANDLE;
      m_volumeHandle = INVALID_HANDLE;
      m_atrHandle = INVALID_HANDLE;
      m_maFastHandleHTF = INVALID_HANDLE;
      m_maSlowHandleHTF = INVALID_HANDLE;
   }
   
   bool CheckLongSignal() override
   {
      double maFast[3], maSlow[3];
      
      if(CopyBuffer(m_maFastHandle, 0, 0, 3, maFast) != 3 ||
         CopyBuffer(m_maSlowHandle, 0, 0, 3, maSlow) != 3)
      {
         Print("Error getting MA values");
         return false;
      }
      
      // Check for MA crossover
      bool maCrossover = (maFast[1] <= maSlow[1] && maFast[0] > maSlow[0]);
      
      // Additional confirmations
      bool volumeConfirm = CheckVolumeConfirmation();
      bool volatilityConfirm = CheckVolatility();
      bool trendConfirm = CheckHigherTimeframeTrend();
      
      // All conditions must be true for a valid signal
      return (maCrossover && volumeConfirm && volatilityConfirm && trendConfirm);
   }
   
   bool CheckShortSignal() override
   {
      double maFast[3], maSlow[3];
      
      if(CopyBuffer(m_maFastHandle, 0, 0, 3, maFast) != 3 ||
         CopyBuffer(m_maSlowHandle, 0, 0, 3, maSlow) != 3)
      {
         Print("Error getting MA values");
         return false;
      }
      
      // Check for MA crossunder
      bool maCrossunder = (maFast[1] >= maSlow[1] && maFast[0] < maSlow[0]);
      
      // Additional confirmations
      bool volumeConfirm = CheckVolumeConfirmation();
      bool volatilityConfirm = CheckVolatility();
      bool trendConfirm = !CheckHigherTimeframeTrend(); // Inverse for short
      
      // All conditions must be true for a valid signal
      return (maCrossunder && volumeConfirm && volatilityConfirm && trendConfirm);
   }
   
   double GetStopLossPips(bool isLong) override
   {
      double atr[1];
      if(CopyBuffer(m_atrHandle, 0, 0, 1, atr) != 1)
         return isLong ? 20.0 : 20.0; // Default 20 pips
         
      // Use 1.5 * ATR for dynamic stop loss
      double atrPips = atr[0] / _Point;
      return MathMax(atrPips * 1.5, 10.0); // Minimum 10 pips
   }
   
   double GetTakeProfitPips(bool isLong) override
   {
      // 2:1 risk-reward ratio
      return GetStopLossPips(isLong) * 2.0;
   }
   
   string GetName() override 
   { 
      return StringFormat("MA Crossover(%d,%d) Strategy", m_maFastPeriod, m_maSlowPeriod); 
   }
};

// Global strategy manager
CStrategyManager g_strategyManager;

// In OnInit() - Add this after other initializations
bool AddStrategies()
{
   // Add MA Crossover Strategy
   if(InpEnableStrategy1)
   {
      if(!g_strategyManager.AddStrategy(new CMAStrategy(InpMAFastPeriod, InpMASlowPeriod, InpHigherTimeframe)))
      {
         Print("Failed to add MA Crossover strategy");
         return false;
      }
      Print("MA Crossover Strategy enabled (Fast:", InpMAFastPeriod, ", Slow:", InpMASlowPeriod, ")");
   }
   
   // Add RSI Strategy
   if(InpEnableStrategy2)
   {
      if(!g_strategyManager.AddStrategy(new CRSIStrategy(InpRSIPeriod, InpRSIOverbought, InpRSIOversold)))
      {
         Print("Failed to add RSI strategy");
         return false;
      }
      Print("RSI Strategy enabled (Period:", InpRSIPeriod, ", Overbought:", InpRSIOverbought, ", Oversold:", InpRSIOversold, ")");
   }
   
   // Add MACD Strategy
   if(InpEnableStrategy3)
   {
      if(!g_strategyManager.AddStrategy(new CMACDStrategy(InpMACDFastEMA, InpMACDSlowEMA, InpMACDSignalPeriod)))
      {
         Print("Failed to add MACD strategy");
         return false;
      }
      Print("MACD Strategy enabled (Fast:", InpMACDFastEMA, ", Slow:", InpMACDSlowEMA, ", Signal:", InpMACDSignalPeriod, ")");
   }
   
   // Add Bollinger Bands Strategy
   if(InpEnableStrategy4)
   {
      if(!g_strategyManager.AddStrategy(new CBollingerBandsStrategy(InpBBPeriod, InpBBDeviation)))
      {
         Print("Failed to add Bollinger Bands strategy");
         return false;
      }
      Print("Bollinger Bands Strategy enabled (Period:", InpBBPeriod, ", Deviation:", InpBBDeviation, ")");
   }
   
   // Check if at least one strategy is enabled
   if(g_strategyManager.GetTotalStrategies() == 0)
   {
      Print("Error: No trading strategies are enabled!");
      return false;
   }
   
   Print("Total strategies enabled: ", g_strategyManager.GetTotalStrategies());
   return true;
}

// Check trading signals and execute trades if conditions are met
void CheckSignals(int tickCount)
{
   // Check if we can enter new trades
   if(g_currentOpenTrades >= MAX_OPEN_TRADES)
   {
      if(tickCount % 100 == 0)
         Print("Maximum number of open trades reached (", g_currentOpenTrades, "/", MAX_OPEN_TRADES, ")");
      return;
   }
   
   // Check for signals from all strategies
   bool longSignal = g_strategyManager.CheckLongSignal();
   bool shortSignal = g_strategyManager.CheckShortSignal();
   
   if(tickCount % 50 == 0) // Log signal status every 50 ticks
   {
      Print("Signal Status - Long: ", (longSignal ? "YES" : "no"), ", Short: ", (shortSignal ? "YES" : "no"));
   }
   
   if(longSignal)
   {
      Print("Processing BUY signal...");
      double stopLoss = g_strategyManager.GetStopLossPips(true);
      double takeProfit = g_strategyManager.GetTakeProfitPips(true);
      double lotSize = CalculatePositionSize(stopLoss);
      
      Print("  Stop Loss: ", stopLoss, " pips, Take Profit: ", takeProfit, " pips, Lot Size: ", lotSize);
      
      if(lotSize > 0)
      {
         // Draw buy signal on chart
         DrawBuySignal();
         
         if(ExecuteMarketOrder(ORDER_TYPE_BUY, lotSize, stopLoss, takeProfit, "Strategy Buy"))
         {
            Print("Successfully executed BUY order");
            g_currentOpenTrades++;
         }
         else
            Print("Failed to execute BUY order");
      }
   }
   if(shortSignal && !longSignal) // Only process short if not already processing long
   {
      Print("Processing SELL signal...");
      double stopLoss = g_strategyManager.GetStopLossPips(false);
      double takeProfit = g_strategyManager.GetTakeProfitPips(false);
      double lotSize = CalculatePositionSize(stopLoss);
      
      Print("  Stop Loss: ", stopLoss, " pips, Take Profit: ", takeProfit, " pips, Lot Size: ", lotSize);
      
      if(lotSize > 0)
      {
         // Draw sell signal on chart
         DrawSellSignal();
         
         if(ExecuteMarketOrder(ORDER_TYPE_SELL, lotSize, stopLoss, takeProfit, "Strategy Sell"))
         {
            Print("Successfully executed SELL order");
            g_currentOpenTrades++;
         }
         else
            Print("Failed to execute SELL order");
      }
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Log tick processing
   static int tickCount = 0;
   tickCount++;
   if(tickCount % 100 == 0) // Log every 100 ticks to avoid flooding
      Print("OnTick called. Current open trades: ", g_currentOpenTrades, "/", MAX_OPEN_TRADES);
      
   // Check for trading signals
   if(tickCount % 50 == 0) // Log status every 50 ticks
   {
      Print("=== Trading Status ===");
      Print("Current Time: ", TimeToString(TimeCurrent()));
      Print("Trading Allowed: ", (TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ? "Yes" : "No"));
      Print("Expert Enabled: ", (MQLInfoInteger(MQL_TRADE_ALLOWED) ? "Yes" : "No"));
      Print("Current Open Trades: ", g_currentOpenTrades, "/", MAX_OPEN_TRADES);
      Print("Last Signal Check: ", (g_lastSignalCheck == 0 ? "Never" : TimeToString(g_lastSignalCheck)));
      Print("Last Log Update: ", (g_lastLogUpdate == 0 ? "Never" : TimeToString(g_lastLogUpdate)));
      Print("Signals This Minute: ", g_signalsSentThisMinute, "/", MAX_SIGNALS_PER_MINUTE);
   }
   
   // Check for trading signals
   CheckSignals(tickCount);

   // Get current price and time
   MqlTick last_tick;
   double current_price = 0.0;
   datetime current_time = TimeCurrent();

   if(SymbolInfoTick(_Symbol, last_tick))
     {
      current_price = last_tick.last;
      if(tickCount % 100 == 0)
         Print("Current price: ", current_price, " (Ask: ", last_tick.ask, ", Bid: ", last_tick.bid, ")");
     }
     else
     {
      Print("Error getting tick data");
      return;
     }

   // Check if trading is allowed
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
     {
      Print("Trading is not allowed. Check AutoTrading button and Expert Advisors settings.");
      return;
     }

// Implement your position closing logic here
// For now, return false to indicate no action needed
// Update market condition
   SMarketCondition condition = GetMarketCondition();

// Get current price and time for position management
// Update current open trades count
   g_currentOpenTrades = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol)
         g_currentOpenTrades++;
   }
   
   // Clean up old signals periodically
   static datetime lastCleanup = 0;
   if(TimeCurrent() - lastCleanup > 3600) // Clean up every hour
   {
      CleanupOldSignals();
      lastCleanup = TimeCurrent();
   }
   
   // Check if we should close any positions
   if(PositionsTotal() > 0)
     {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && PositionSelectByTicket(ticket))
           {
            if(ShouldClosePosition(ticket))
              {
               // Close the position
               if(m_trade.PositionClose(ticket))
                 {
                  Print("Position closed: ", ticket);
                 }
               else
                 {
                  Print("Failed to close position ", ticket, ". Error: ", GetLastError());
                 }
              }
           }
        }
     }

// Check if we can open new positions
   if(g_currentOpenTrades < MAX_OPEN_TRADES)
     {
      CheckSignals(tickCount);
     }
     else
     {
      if(tickCount % 100 == 0)
         Print("Maximum number of open trades reached (", g_currentOpenTrades, "/", MAX_OPEN_TRADES, ")");
     }

// Update trading statistics and check trading modes once per 15 minutes
   static datetime lastUpdateTime = 0;
   datetime currentTime = TimeCurrent();
   
   if(currentTime - lastUpdateTime >= 900)  // Only update once every 15 minutes
   {
      // Create a string with all the information
      string info = "=== 15-Minute Update ===\n";
      info += "Time: " + TimeToString(currentTime) + "\n";
      info += "Open Positions: " + IntegerToString(PositionsTotal()) + "\n";
      info += "Trading Mode: " + EnumToString(g_tradingMode) + "\n\n";
      info += "=== Trading Stats ===\n";
      info += "Paper Trades: " + IntegerToString(g_paperStats.totalTrades) + "\n";
      info += "Winners: " + IntegerToString(g_paperStats.winningTrades) + "\n";
      info += "Win Rate: " + DoubleToString(g_paperStats.winRate, 2) + "%\n\n";
      info += "Live Trades: " + IntegerToString(g_liveStats.totalTrades) + "\n";
      info += "Winners: " + IntegerToString(g_liveStats.winningTrades) + "\n";
      info += "Win Rate: " + DoubleToString(g_liveStats.winRate, 2) + "%";
      
      // Display on chart
      Comment(info);
      
      // Also print to log
      Print("=== 15-Minute Update ===");
      Print("Current time: ", TimeToString(currentTime));
      Print("Open positions: ", PositionsTotal());
      Print("Current trading mode: ", EnumToString(g_tradingMode));
      Print("Paper trades: ", g_paperStats.totalTrades, " (Winners: ", g_paperStats.winningTrades, ", Win rate: ", g_paperStats.winRate, "%)");
      Print("Live trades: ", g_liveStats.totalTrades, " (Winners: ", g_liveStats.winningTrades, ", Win rate: ", g_liveStats.winRate, "%)");
      
      UpdateTradingStats();
      CheckTradingMode();
      lastUpdateTime = currentTime;
      
      // Log current indicator values for debugging
      double maFast[3], maSlow[3];
      if(CopyBuffer(handle_iMA_4, 0, 0, 3, maFast) == 3 &&
         CopyBuffer(handle_iMA_5, 0, 0, 3, maSlow) == 3)
      {
         string maInfo = "\n\n=== Current MA Values ===\n";
         maInfo += "Fast MA: " + DoubleToString(maFast[0], 6) + ", " + DoubleToString(maFast[1], 6) + ", " + DoubleToString(maFast[2], 6) + "\n";
         maInfo += "Slow MA: " + DoubleToString(maSlow[0], 6) + ", " + DoubleToString(maSlow[1], 6) + ", " + DoubleToString(maSlow[2], 6);
         
         // Add MA info to chart
         Comment(info + maInfo);
         
         // Also print to log
         Print("Current MA Values - Fast: ", maFast[0], ", ", maFast[1], ", ", maFast[2]);
         Print("Current MA Values - Slow: ", maSlow[0], ", ", maSlow[1], ", ", maSlow[2]);
      }
   }
  }

//+------------------------------------------------------------------+
//| Check for buy signal based on MA crossover                       |
//+------------------------------------------------------------------+
bool CheckBuySignal()
{
   // Check if indicators are valid
   if(handle_iMA_4 == INVALID_HANDLE || handle_iMA_5 == INVALID_HANDLE)
   {
      Print("Error: Indicator handles not valid in CheckBuySignal");
      return false;
   }
   
   // Use dynamic arrays for indicator values
   double maFast[];
   double maSlow[];
   
   // Set as series and resize arrays
   ArraySetAsSeries(maFast, true);
   ArraySetAsSeries(maSlow, true);
   
   // Resize arrays to hold 3 values (current and 2 previous)
   ArrayResize(maFast, 3);
   ArrayResize(maSlow, 3);
   
   // Copy more bars to ensure we have enough data
   if(CopyBuffer(handle_iMA_4, 0, 0, 3, maFast) != 3 ||
      CopyBuffer(handle_iMA_5, 0, 0, 3, maSlow) != 3)
   {
      Print("Error copying indicator buffers in CheckBuySignal");
      return false;
   }
   
   // Check for valid values
   if(maFast[0] == 0 || maFast[1] == 0 || maSlow[0] == 0 || maSlow[1] == 0)
   {
      Print("Warning: Indicator values not ready");
      return false;
   }
   
   // Check for buy signal (fast MA crosses above slow MA)
   bool signal = (maFast[1] <= maSlow[1] && maFast[0] > maSlow[0]);
   
   if(signal)
   {
      Print("BUY Signal: Fast MA(", maFast[0], ") crossed above Slow MA(", maSlow[0], ")");
   }
   
   return signal;
}

//+------------------------------------------------------------------+
//| Check for sell signal based on MA crossover                      |
//+------------------------------------------------------------------+
bool CheckSellSignal()
{
   // Check if indicators are valid
   if(handle_iMA_4 == INVALID_HANDLE || handle_iMA_5 == INVALID_HANDLE)
   {
      Print("Error: Indicator handles not valid in CheckSellSignal");
      return false;
   }
   
   // Use dynamic arrays for indicator values
   double maFast[];
   double maSlow[];
   
   // Set as series and resize arrays
   ArraySetAsSeries(maFast, true);
   ArraySetAsSeries(maSlow, true);
   
   // Resize arrays to hold 3 values (current and 2 previous)
   ArrayResize(maFast, 3);
   ArrayResize(maSlow, 3);
   
   // Copy more bars to ensure we have enough data
   if(CopyBuffer(handle_iMA_4, 0, 0, 3, maFast) != 3 ||
      CopyBuffer(handle_iMA_5, 0, 0, 3, maSlow) != 3)
   {
      Print("Error copying indicator buffers in CheckSellSignal");
      return false;
   }
   
   // Check for valid values
   if(maFast[0] == 0 || maFast[1] == 0 || maSlow[0] == 0 || maSlow[1] == 0)
   {
      Print("Warning: Indicator values not ready");
      return false;
   }
   
   // Check for sell signal (fast MA crosses below slow MA)
   bool signal = (maFast[1] >= maSlow[1] && maFast[0] < maSlow[0]);
   
   if(signal)
   {
      Print("SELL Signal: Fast MA(", maFast[0], ") crossed below Slow MA(", maSlow[0], ")");
   }
   
   return signal;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckTradingMode()
  {
// Check if we should switch to live mode
   if(g_tradingMode == MODE_PAPER &&
      g_paperStats.totalTrades >= MIN_PAPER_TRADES &&
      g_paperStats.winRate >= MinWinRateForLive)
     {
      g_tradingMode = MODE_HYBRID;
      Print("Switching to HYBRID trading mode. Paper performance: ", g_paperStats.winRate, "% win rate");
     }

// Check if we should switch back to paper mode
   if((g_tradingMode == MODE_HYBRID || g_tradingMode == MODE_LIVE) &&
      (g_paperStats.winRate < (MinWinRateForLive * 0.8) || g_paperStats.profitFactor < 1.2))
     {
      g_tradingMode = MODE_PAPER;
      Print("Switching back to PAPER trading mode due to performance drop");
     }

// Check if we should switch to full live mode
   if(g_tradingMode == MODE_HYBRID &&
      g_paperStats.totalTrades >= MIN_PAPER_TRADES * 2 &&
      g_paperStats.winRate >= MinLiveWinRate)
     {
      g_tradingMode = MODE_LIVE;
      Print("Switching to FULL LIVE trading mode. Performance: ", g_paperStats.winRate, "% win rate");
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LearnFromTrades()
  {
// Simple learning logic - can be enhanced with more sophisticated algorithms
   if(g_paperStats.winRate > 70.0)
     {
      // If winning, be more aggressive
      g_learningParams.riskPerTrade = MathMin(2.0, g_learningParams.riskPerTrade * 1.1);
      g_learningParams.takeProfitPips = MathMin(100.0, g_learningParams.takeProfitPips * 1.05);
      g_learningParams.stopLossPips = MathMax(10.0, g_learningParams.stopLossPips * 0.95);
     }
   else
     {
      // If losing, be more conservative
      g_learningParams.riskPerTrade = MathMax(0.1, g_learningParams.riskPerTrade * 0.9);
      g_learningParams.takeProfitPips = MathMax(20.0, g_learningParams.takeProfitPips * 0.95);
      g_learningParams.stopLossPips = MathMin(50.0, g_learningParams.stopLossPips * 1.05);
     }

// Adjust MA periods based on volatility
   SMarketCondition condition = GetMarketCondition();
   if(condition.volatility > 70)
     {
      // In high volatility, use slower MAs
      g_learningParams.maFastPeriod = MathMin(14, g_learningParams.maFastPeriod + 1);
      g_learningParams.maSlowPeriod = MathMin(28, g_learningParams.maSlowPeriod + 1);
     }
   else
      if(condition.volatility < 30)
        {
         // In low volatility, use faster MAs
         g_learningParams.maFastPeriod = MathMax(5, g_learningParams.maFastPeriod - 1);
         g_learningParams.maSlowPeriod = MathMax(10, g_learningParams.maSlowPeriod - 1);
        }

// Ensure fast MA is always faster than slow MA
   if(g_learningParams.maFastPeriod >= g_learningParams.maSlowPeriod)
     {
      g_learningParams.maSlowPeriod = g_learningParams.maFastPeriod + 5;
     }

   Print("Learning complete. New parameters: ",
         "Risk: ", g_learningParams.riskPerTrade,
         ", TP: ", g_learningParams.takeProfitPips,
         ", SL: ", g_learningParams.stopLossPips,
         ", MA Fast: ", g_learningParams.maFastPeriod,
         ", MA Slow: ", g_learningParams.maSlowPeriod);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SaveTradingState()
  {
// Implementation to save trading state to a file
// This is a placeholder - implement actual file I/O as needed
   Print("Trading state saved");
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LoadTradingState()
  {
// Implementation to load trading state from a file
// This is a placeholder - implement actual file I/O as needed
   Print("Trading state loaded");
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Calculate position size based on risk percentage                 |
//+------------------------------------------------------------------+
double CalculatePositionSize(double stopLossPips, double riskPercent = 1.0)
  {
   // Get symbol and account information
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Log input parameters
   Print("Calculating position size:");
   Print("  Stop Loss: ", stopLossPips, " pips");
   Print("  Risk %: ", riskPercent);
   Print("  Account Balance: $", balance);
   Print("  Symbol Info - Tick Size: ", tickSize, ", Tick Value: $", tickValue, ", Lot Step: ", lotStep);
   
   // Validate inputs
   if(stopLossPips <= 0)
     {
      Print("Error: Invalid stop loss pips: ", stopLossPips);
      return 0.0;
     }
     
   if(tickSize <= 0 || tickValue <= 0 || lotStep <= 0)
     {
      Print("Error: Invalid symbol parameters - TickSize: ", tickSize, ", TickValue: ", tickValue, ", LotStep: ", lotStep);
      return 0.0;
     }

   // Calculate risk amount in account currency
   double riskAmount = balance * (riskPercent / 100.0);
   Print("  Risk Amount: $", riskAmount);
   
   // Calculate value per pip
   double pipValue = tickValue / (tickSize / _Point);
   Print("  Pip Value: $", pipValue);
   
   // Calculate money at risk per lot
   double moneyRiskPerLot = stopLossPips * pipValue;
   Print("  Money Risk per Lot: $", moneyRiskPerLot);
   
   if(moneyRiskPerLot <= 0)
     {
      Print("Error: Invalid money risk per lot calculation: ", moneyRiskPerLot);
      return 0.0;
     }

   // Calculate position size in lots
   double lots = riskAmount / moneyRiskPerLot;
   Print("  Raw Lots: ", lots);
   
   // Round to nearest lot step
   lots = MathFloor(lots / lotStep) * lotStep;
   Print("  Rounded Lots: ", lots);
   
   // Ensure position size is within allowed range
   lots = MathMax(minLot, MathMin(lots, maxLot));
   Print("  Final Lots (after min/max check): ", lots);
   
   if(lots < minLot)
     {
      Print("Error: Calculated lot size (", lots, ") is below minimum allowed (", minLot, ")");
      return 0.0;
     }
   
   if(lots > maxLot)
     {
      Print("Warning: Calculated lot size (", lots, ") exceeds maximum allowed (", maxLot, "). Using maximum.");
      lots = maxLot;
     }
   
   Print("  Final Position Size: ", lots, " lots");
   return lots;
  }

//+------------------------------------------------------------------+
//| Check if a position should be closed                             |
//+------------------------------------------------------------------+
bool ShouldClosePosition(ulong ticket)
  {
   if(!PositionSelectByTicket(ticket))
     {
      Print("Failed to select position ", ticket);
      return false;
     }

// Get position details
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   double profit = PositionGetDouble(POSITION_PROFIT);
   double stopLoss = PositionGetDouble(POSITION_SL);
   double takeProfit = PositionGetDouble(POSITION_TP);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

// Check if stop loss or take profit was hit
   if((posType == POSITION_TYPE_BUY && (currentPrice <= stopLoss || currentPrice >= takeProfit)) ||
      (posType == POSITION_TYPE_SELL && (currentPrice >= stopLoss || currentPrice <= takeProfit)))
     {
      return true;
     }

// Check for reversal signals
   bool isBuy = (posType == POSITION_TYPE_BUY);
   bool reversalSignal = isBuy ? CheckSellSignal() : CheckBuySignal();

// Consider taking profits if we have a reversal signal
   if(reversalSignal && profit > 0)
     {
      return true;
     }

// Check for extreme market conditions
   SMarketCondition condition = GetMarketCondition();
   if(condition.volatility > 80)
     {
      // Close position if volatility is too high and we have a decent profit
      if(profit > 0)
        {
         return true;
        }
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Update trading statistics                                        |
//+------------------------------------------------------------------+
void UpdateTradingStats()
  {
// Update live trading statistics
   g_liveStats.Init();

// Get all closed positions from history
   HistorySelect(0, TimeCurrent());
   int totalDeals = HistoryDealsTotal();

   for(int i = 0; i < totalDeals; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
        {
         // Process deal information
         STradeRecord trade = {};
         trade.Init();
         trade.ticket = ticket;
         trade.symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
         trade.type = (ENUM_ORDER_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
         trade.volume = HistoryDealGetDouble(ticket, DEAL_VOLUME);
         trade.openPrice = HistoryDealGetDouble(ticket, DEAL_PRICE);
         trade.profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         trade.commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         trade.swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
         trade.openTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         trade.isLive = true;

         // Update statistics (isWin is calculated in STradingStats.Update)
         g_liveStats.Update(trade);
        }
     }

// Log current status
   Print("=== Trading Status ===");
   Print("Mode: ", EnumToString(g_tradingMode));
   Print("Paper Trades: ", g_paperStats.totalTrades, ", Win Rate: ", g_paperStats.winRate, "%");
   Print("Live Trades: ", g_liveStats.totalTrades, ", Win Rate: ", g_liveStats.winRate, "%");
   Print("Current Open Trades: ", g_currentOpenTrades, " (Max: ", MAX_OPEN_TRADES, ")");
   Print("Current Balance: ", AccountInfoDouble(ACCOUNT_BALANCE));
   Print("Current Equity: ", AccountInfoDouble(ACCOUNT_EQUITY));
   Print("Free Margin: ", AccountInfoDouble(ACCOUNT_MARGIN_FREE));
   Print("Max Drawdown: ", g_liveStats.maxDrawdown, "%");
   Print("====================");
  }
//+------------------------------------------------------------------+
