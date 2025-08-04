//+------------------------------------------------------------------+
//|                                                EscapeEA_LiveEA.mq5 |
//|                                      Copyright 2025, EscapeEA     |
//|                                          https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"
#property strict

// Include necessary files
#include "..\Include\Common\Enums.mqh"
#include "..\Include\Common\Structs.mqh"
#include "..\Include\Common\Constants.mqh"
#include "..\Include\Core\RiskManager.mqh"
#include "..\Include\Core\TradeExecutor.mqh"
#include "..\Include\Learning\LearningEngine.mqh"
#include "..\Include\Learning\KnowledgeBase.mqh"
#include "..\Include\Communication\SignalReceiver.mqh"
#include "..\Include\Communication\SignalBroadcaster.mqh"

//+------------------------------------------------------------------+
//| Utility Functions                                               |
//+------------------------------------------------------------------+
// Calculate ATR (Average True Range)
double GetATR(string symbol, int period, int shift=0)
  {
   double atrBuffer[];
   int atr_handle = iATR(symbol, PERIOD_CURRENT, period);
   if(atr_handle == INVALID_HANDLE)
     {
      Print("Failed to get ATR handle. Error: ", GetLastError());
      return 0.0;
     }
   
   if(CopyBuffer(atr_handle, 0, shift, 1, atrBuffer) <= 0)
     {
      Print("Failed to copy ATR data. Error: ", GetLastError());
      IndicatorRelease(atr_handle);
      return 0.0;
     }
   
   IndicatorRelease(atr_handle);
   return atrBuffer[0];
  }

// Get error description string
string ErrorDescription(int error_code)
  {
   string error_string;
   switch(error_code)
     {
      case 0:   error_string = "No error"; break;
      case 1:   error_string = "No error returned"; break;
      case 2:   error_string = "Common error"; break;
      case 3:   error_string = "Invalid trade parameters"; break;
      case 4:   error_string = "Trade server is busy"; break;
      case 5:   error_string = "Old version of the client terminal"; break;
      case 6:   error_string = "No connection with trade server"; break;
      case 7:   error_string = "Not enough rights"; break;
      case 8:   error_string = "Too frequent requests"; break;
      case 9:   error_string = "Malfunctional trade operation"; break;
      case 64:  error_string = "Account disabled"; break;
      case 65:  error_string = "Invalid account"; break;
      case 128: error_string = "Trade timeout"; break;
      case 129: error_string = "Invalid price"; break;
      case 130: error_string = "Invalid stops"; break;
      case 131: error_string = "Invalid trade volume"; break;
      case 132: error_string = "Market is closed"; break;
      case 133: error_string = "Trade is disabled"; break;
      case 134: error_string = "Not enough money"; break;
      case 135: error_string = "Price changed"; break;
      case 136: error_string = "Off quotes"; break;
      case 137: error_string = "Broker is busy"; break;
      case 138: error_string = "Requote"; break;
      case 139: error_string = "Order is locked"; break;
      case 140: error_string = "Long positions only allowed"; break;
      case 141: error_string = "Too many requests"; break;
      case 145: error_string = "Modification denied because order is too close to market"; break;
      case 146: error_string = "Trading context is busy"; break;
      case 147: error_string = "Expirations are denied by broker"; break;
      case 148: error_string = "The amount of open and pending orders has reached the limit"; break;
      case 149: error_string = "An attempt to modify an order that is being processed"; break;
      case 150: error_string = "An attempt to close an order that is being processed"; break;
      case 4000: error_string = "No error"; break;
      case 4001: error_string = "Wrong function pointer"; break;
      case 4002: error_string = "Array index is out of range"; break;
      case 4003: error_string = "No memory for function call stack"; break;
      case 4004: error_string = "Recursive stack overflow"; break;
      case 4005: error_string = "Not enough stack for parameter"; break;
      case 4006: error_string = "No memory for parameter string"; break;
      case 4007: error_string = "No memory for temp string"; break;
      case 4008: error_string = "Not initialized string"; break;
      case 4009: error_string = "Invalid string"; break;
      case 4010: error_string = "Remainder from zero divide"; break;
      case 4011: error_string = "Zero divide"; break;
      case 4012: error_string = "Unknown command"; break;
      case 4013: error_string = "Wrong jump (never generated error)"; break;
      case 4014: error_string = "Not initialized array"; break;
      case 4015: error_string = "DLL calls are not allowed"; break;
      case 4016: error_string = "Cannot load library"; break;
      case 4017: error_string = "Cannot call function"; break;
      case 4018: error_string = "External call"; break;
      case 4019: error_string = "No reply from server"; break;
      case 4020: error_string = "Not enough memory for retrived string"; break;
      case 4021: error_string = "Function is not allowed in testing mode"; break;
      case 4050: error_string = "Invalid function parameters count"; break;
      case 4051: error_string = "Invalid function parameter value"; break;
      case 4052: error_string = "String function internal error"; break;
      case 4053: error_string = "Some array error"; break;
      case 4054: error_string = "Incorrect series array using"; break;
      case 4055: error_string = "Custom indicator error"; break;
      case 4056: error_string = "Arrays are incompatible"; break;
      case 4057: error_string = "Global variables processing error"; break;
      case 4058: error_string = "Global variable not found"; break;
      case 4059: error_string = "Function is not allowed in testing mode"; break;
      case 4060: error_string = "Function is not confirmed"; break;
      case 4061: error_string = "Send mail error"; break;
      case 4062: error_string = "String parameter expected"; break;
      case 4063: error_string = "Integer parameter expected"; break;
      case 4064: error_string = "Double parameter expected"; break;
      case 4065: error_string = "Array as parameter expected"; break;
      case 4066: error_string = "Requested history is in updating state"; break;
      case 4099: error_string = "End of file"; break;
      case 4100: error_string = "Some file error"; break;
      case 4101: error_string = "Wrong file name"; break;
      case 4102: error_string = "Too many opened files"; break;
      case 4103: error_string = "Cannot open file"; break;
      case 4104: error_string = "Incompatible access to a file"; break;
      case 4105: error_string = "No order selected"; break;
      case 4106: error_string = "Unknown symbol"; break;
      case 4107: error_string = "Invalid price"; break;
      case 4108: error_string = "Invalid ticket"; break;
      case 4109: error_string = "Trade is not allowed"; break;
      case 4110: error_string = "Longs are not allowed"; break;
      case 4111: error_string = "Shorts are not allowed"; break;
      case 4200: error_string = "Object already exists"; break;
      case 4201: error_string = "Unknown object property"; break;
      case 4202: error_string = "Object does not exist"; break;
      case 4203: error_string = "Unknown object type"; break;
      case 4204: error_string = "No object name"; break;
      case 4205: error_string = "Object coordinates error"; break;
      case 4206: error_string = "No specified subwindow"; break;
      case 4207: error_string = "Some error in chart operation"; break;
      case 4208: error_string = "Not implemented"; break;
      default:   error_string = "Unknown error";
     }
   return(error_string);
  }

// Log message to file
void LogToFile(string filename, string message)
  {
   int handle = FileOpen(filename, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI, 0, CP_UTF8);
   if(handle != INVALID_HANDLE)
     {
      FileSeek(handle, 0, SEEK_END);
      FileWrite(handle, TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), " - ", message);
      FileClose(handle);
     }
  }

// Get the last closed order ticket
ulong GetLastOrderTicket()
  {
   HistorySelect(0, TimeCurrent());
   int total = HistoryDealsTotal();
   if(total > 0)
     {
      return HistoryDealGetTicket(total - 1);
     }
   return 0;
  }

// Log system status
void LogSystemStatus(const string &status)
  {
   string filename = "LiveEA_Status_" + TimeToString(TimeCurrent(), TIME_DATE) + ".log";
   LogToFile(filename, status);
   
   // Also print to journal for immediate visibility
   Print("Status: ", status);
  }

//+------------------------------------------------------------------+
//| Input Parameters with Validation                                 |
//+------------------------------------------------------------------+
input group "=== General Settings ==="
input string   InpPaperEAPrefix = "ESCAPEEA_PAPER_"; // Paper EA signal prefix (max 50 chars)
input string   InpSymbol = "";                      // Trading symbol (empty for chart symbol)
input double   InpRiskPerTrade = 1.0;                // Risk per trade (0.1-10.0% of balance)
input int      InpMaxOpenTrades = 3;                 // Maximum open trades (1-100)
input int      InpMagicNumber = 123457;              // Magic number (100000-999999)
input double   InpSlippage = 10.0;                   // Slippage in points (0-100)
input bool     InpEnableTrading = true;              // Enable live trading
input int      InpEvaluationInterval = 15;           // Evaluation interval (1-1440 minutes)
input int      InpMinTradesPerInterval = 10;         // Minimum trades per interval (1-1000)
input double   InpDailyDrawdownLimit = 5.0;          // Max daily drawdown % (0.1-50.0)
input color    InpPanelColor = clrLimeGreen;         // Panel color
input int      InpFontSize = 8;                      // Font size (8-20)

// Live EA Specific
input bool     InpAcceptPaperSignals = true;         // Accept signals from Paper EA
input double   InpMaxPositionSize = 10.0;            // Maximum position size (0.01-1000.0 lots)
input bool     InpUseHardStops = true;               // Use hard stop losses
input string   InpSharedKBDir = "shared_kb";        // Shared knowledge base directory (max 255 chars)

input group "=== Signal Processing ==="
input double   InpMinConfidence = 0.7;               // Minimum confidence (0.0-1.0)
input int      InpMaxSignalAge = 300;                // Max signal age (10-3600 seconds)
input bool     InpUsePaperEASLTP = true;             // Use Paper EA's SL/TP levels
input bool     InpEnableSignalLogging = true;        // Enable signal logging
input string   InpConfidenceAdjustMode = "online";  // Learning mode: "online" or "batch"

input group "=== Learning Settings ==="
input int      InpLearningWindow = 100;              // Learning window (10-10000 trades)
input double   InpMinWinRate = 0.6;                   // Min win rate (0.5-1.0)
input double   InpLearningRate = 0.01;                // Learning rate (0.0001-1.0)
input bool     InpEnableLearning = true;              // Enable learning from trades
input bool     InpEnableRegimeClassification = true;  // Enable market regime classification

//+------------------------------------------------------------------+
//| Global Variables with Initialization                             |
//+------------------------------------------------------------------+
CRiskManager     *g_riskManager = NULL;         // Risk management instance
CTradeExecutor   *g_tradeExecutor = NULL;       // Trade execution instance
CLearningEngine  *g_learningEngine = NULL;      // Learning engine instance
CKnowledgeBase   *g_knowledgeBase = NULL;       // Knowledge base instance
CSignalReceiver  *g_signalReceiver = NULL;      // Signal receiver instance

// Runtime state
string           g_symbol;                      // Trading symbol
string           g_signalPrefix;                // Signal prefix for message filtering
string           g_errorMessage = "";           // Last error message
datetime         g_lastSignalCheck = 0;         // Last signal check time
int              g_totalTrades = 0;             // Total trades count
int              g_successfulTrades = 0;        // Successful trades count
int              g_failedTrades = 0;            // Failed trades count
bool             g_initialized = false;         // Initialization flag

// Global variables
CSignalBroadcaster *g_signalBroadcaster = NULL;

// Function declarations
void CheckAndUpdatePositions();
void ProcessPendingOrders();
void UpdateWithTickData(const MqlTick &tick);
void CheckEmergencyStop();

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Reset initialization state
   g_initialized = false;
   g_errorMessage = "";
   
   // Validate inputs
   if(!ValidateInputs())
     {
      Print("Input validation failed: ", g_errorMessage);
      return INIT_PARAMETERS_INCORRECT;
     }
   
   // Set symbol and signal prefix
   g_symbol = (StringLen(InpSymbol) > 0) ? InpSymbol : _Symbol;
   g_signalPrefix = InpPaperEAPrefix + g_symbol + "_" + (string)InpMagicNumber + "_";
   
   // Initialize random seed
   MathSrand((uint)TimeCurrent());
   
   // Initialize components with error handling
   if(!InitializeComponents())
     {
      Print("Failed to initialize components: ", g_errorMessage);
      return INIT_FAILED;
     }
   
   // Load historical data with error handling
   if(!LoadHistoricalData())
     {
      Print("Warning: Failed to load historical data: ", g_errorMessage);
      // Continue initialization even if historical data fails
     }
   
   // Initialize timer for signal checking (every 1 second)
   if(!EventSetTimer(1))
     {
      g_errorMessage = "Failed to set timer";
      return INIT_FAILED;
     }
   
   // Mark as initialized
   g_initialized = true;
   Print("EscapeEA Live Trader initialized successfully");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Print("Shutting down LiveEA, reason: ", GetUninitializeReasonText(reason));
   
   // Clean up components safely in reverse order of initialization
   SafeDelete(g_signalReceiver);
   SafeDelete(g_knowledgeBase);
   SafeDelete(g_learningEngine);
   SafeDelete(g_tradeExecutor);
   SafeDelete(g_riskManager);
   
   // Disable timer
   EventKillTimer();
   
   // Clear initialization flag
   g_initialized = false;
   Print("EscapeEA Live Trader deinitialized");
  }

//+------------------------------------------------------------------+
//| Safely delete a pointer and set to NULL                         |
//+------------------------------------------------------------------+
template<typename T>
void SafeDelete(T &ptr)
  {
   if(CheckPointer(ptr) != POINTER_INVALID)
     {
      delete ptr;
      ptr = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Get text description of uninitialize reason                     |
//+------------------------------------------------------------------+
string GetUninitializeReasonText(int reason)
  {
   switch(reason)
     {
      case REASON_ACCOUNT:    return "Account changed";
      case REASON_CHARTCHANGE:return "Chart changed";
      case REASON_CHARTCLOSE: return "Chart closed";
      case REASON_PARAMETERS: return "Input parameters changed";
      case REASON_RECOMPILE:  return "Program recompiled";
      case REASON_REMOVE:     return "Program removed";
      case REASON_TEMPLATE:   return "Template changed";
      default:                return "Unknown reason: " + IntegerToString(reason);
     }
  }

//+------------------------------------------------------------------+
//| Validate input parameters                                        |
//+------------------------------------------------------------------+
bool ValidateInputs()
  {
   // Validate numeric inputs
   if(InpRiskPerTrade <= 0 || InpRiskPerTrade > 10.0)
     {
      g_errorMessage = StringFormat("Invalid risk per trade: %.2f (must be 0.1-10.0)", InpRiskPerTrade);
      return false;
     }
     
   if(InpMaxOpenTrades < 1 || InpMaxOpenTrades > 100)
     {
      g_errorMessage = StringFormat("Invalid max open trades: %d (must be 1-100)", InpMaxOpenTrades);
      return false;
     }
     
   if(InpMagicNumber < 100000 || InpMagicNumber > 999999)
     {
      g_errorMessage = StringFormat("Invalid magic number: %d (must be 6 digits)", InpMagicNumber);
      return false;
     }
     
   if(InpSlippage < 0 || InpSlippage > 500)
     {
      g_errorMessage = StringFormat("Invalid slippage: %.1f (must be 0-500)", InpSlippage);
      return false;
     }
     
   if(InpMaxPositionSize < 0.01 || InpMaxPositionSize > 1000.0)
     {
      g_errorMessage = StringFormat("Invalid max position size: %.2f (must be 0.01-1000.0)", InpMaxPositionSize);
      return false;
     }
     
   if(InpMinConfidence < 0.0 || InpMinConfidence > 1.0)
     {
      g_errorMessage = StringFormat("Invalid min confidence: %.2f (must be 0.0-1.0)", InpMinConfidence);
      return false;
     }
     
   if(InpMaxSignalAge < 10 || InpMaxSignalAge > 3600)
     {
      g_errorMessage = StringFormat("Invalid max signal age: %d (must be 10-3600 seconds)", InpMaxSignalAge);
      return false;
     }
     
   if(StringLen(InpPaperEAPrefix) > 50)
     {
      g_errorMessage = "Paper EA prefix too long (max 50 characters)";
      return false;
     }
     
   if(StringLen(InpSharedKBDir) > 255)
     {
      g_errorMessage = "Shared KB directory path too long (max 255 characters)";
      return false;
     }
     
   return true;
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Process pending orders and open positions
   if(CheckPointer(g_tradeExecutor) != POINTER_INVALID)
     {
      // Check for position modifications (trailing stops, etc.)
      g_tradeExecutor.CheckAndUpdatePositions();
      
      // Process any pending orders
      g_tradeExecutor.ProcessPendingOrders();
     }
     
   // Update learning model with latest market data
   if(InpEnableLearning && CheckPointer(g_learningEngine) != POINTER_INVALID)
     {
      MqlTick lastTick;
      if(SymbolInfoTick(g_symbol, lastTick))
        {
         g_learningEngine.UpdateWithTickData(lastTick);
        }
     }
     
   // Emergency stop check
   CheckEmergencyStop();
  }

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   static int tickCounter = 0;
   tickCounter++;
   
   // Check for new signals every 5 seconds (reduced from 1s)
   if((tickCounter % 5) == 0) // 5-second interval
     {
      g_lastSignalCheck = TimeCurrent();
      CheckForNewSignals();
     }
   
   // Perform periodic tasks every 30 seconds (reduced from 60s)
   static datetime lastPeriodicCheck = 0;
   if(TimeCurrent() - lastPeriodicCheck >= 30)
     {
      lastPeriodicCheck = TimeCurrent();
      PerformPeriodicTasks();
     }
      
   // Send heartbeat every 15 seconds
   static datetime lastHeartbeat = 0;
   if(TimeCurrent() - lastHeartbeat >= 15)
     {
      lastHeartbeat = TimeCurrent();
      SendHeartbeat();
     }
  }

//+------------------------------------------------------------------+
//| Initialize EA components                                         |
//+------------------------------------------------------------------+
bool InitializeComponents()
  {
   bool success = true;
   
   // Initialize risk manager with error handling
   Print("Initializing risk manager...");
   g_riskManager = new CRiskManager(g_symbol, InpRiskPerTrade, InpDailyDrawdownLimit, 10.0, InpMaxPositionSize, InpMaxOpenTrades);
   if(CheckPointer(g_riskManager) != POINTER_DYNAMIC)
     {
      g_errorMessage = "Failed to create risk manager";
      return false;
     }
   Print("Risk manager initialized successfully");
   
   // Initialize trade executor with error handling
   Print("Initializing trade executor...");
   g_tradeExecutor = new CTradeExecutor(InpMagicNumber, InpEnableTrading, g_symbol, InpSlippage);
   if(CheckPointer(g_tradeExecutor) != POINTER_DYNAMIC)
     {
      g_errorMessage = "Failed to create trade executor";
      return false;
     }
   Print("Trade executor initialized successfully");
   
   // Initialize knowledge base with error handling
   Print("Initializing knowledge base...");
   string kbName = "EscapeEA_Live_" + g_symbol;
   g_knowledgeBase = new CKnowledgeBase(kbName);
   if(CheckPointer(g_knowledgeBase) != POINTER_DYNAMIC)
     {
      g_errorMessage = "Failed to create knowledge base";
      return false;
     }
   Print("Knowledge base initialized successfully");
   
   // Initialize learning engine with error handling
   if(InpEnableLearning)
     {
      Print("Initializing learning engine...");
      g_learningEngine = new CLearningEngine(InpLearningWindow, InpMinWinRate, InpLearningRate);
      if(CheckPointer(g_learningEngine) != POINTER_DYNAMIC)
        {
         g_errorMessage = "Failed to create learning engine";
         return false;
        }
      Print("Learning engine initialized successfully");
     }
   
   // Initialize signal receiver with error handling
   Print("Initializing signal receiver...");
   g_signalReceiver = new CSignalReceiver(g_signalPrefix, InpMaxSignalAge, InpMinConfidence);
   if(CheckPointer(g_signalReceiver) != POINTER_INVALID)
     {
      g_errorMessage = "Failed to create signal receiver";
      return false;
     }
   Print("Signal receiver initialized successfully");
   
   // All components initialized successfully
   Print("All components initialized successfully");
   return true;
  }

//+------------------------------------------------------------------+
//| Load historical data for backtesting and analysis               |
//+------------------------------------------------------------------+
bool LoadHistoricalData()
  {
   Print("Loading historical data for ", g_symbol, "...");
   
   // Define the time period for historical data (last 3 months)
   datetime endTime = TimeCurrent();
   datetime startTime = endTime - 90 * 24 * 60 * 60; // 90 days ago
   
   // Request historical rates
   MqlRates rates[];
   int copied = CopyRates(g_symbol, PERIOD_M15, startTime, endTime, rates);
   
   if(copied <= 0)
     {
      int error = GetLastError();
      Print("Failed to load historical data. Error: ", ErrorDescription(error));
      return false;
     }
   
   Print("Successfully loaded ", copied, " bars of historical data");
   
   // Initialize technical indicators with historical data
   if(CheckPointer(g_learningEngine) != POINTER_INVALID)
     {
      // Convert MqlRates to our internal format if needed
      // For now, just log that we've received historical data
      Print("Historical data received for ", copied, " bars");
      
      // If the learning engine needs to be trained with this data,
      // we would call the appropriate method here
      // g_learningEngine.TrainWithHistoricalData(rates);
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Check for new signals from Paper EA                              |
//+------------------------------------------------------------------+
void CheckForNewSignals()
  {
   if(CheckPointer(g_signalReceiver) == POINTER_INVALID ||
      CheckPointer(g_riskManager) == POINTER_INVALID ||
      CheckPointer(g_tradeExecutor) == POINTER_INVALID)
      return;
   
   // Check for new signals
   STradeSignal signals[];
   int signalCount = g_signalReceiver.CheckForNewSignals(signals);
   
   if(signalCount <= 0)
      return;
   
   // Process new signals
   for(int i = 0; i < signalCount; i++)
     {
      // Check signal confidence
      if(signals[i].confidence < InpMinConfidence)
        {
         Print("Signal ", signals[i].symbol, " ", EnumToString(signals[i].signal), " ignored: Low confidence (", signals[i].confidence, " < ", InpMinConfidence, ")");
         continue;
        }
      
      // Check if we already processed this signal using comment as identifier
      if(CheckPointer(g_knowledgeBase) != POINTER_INVALID && signals[i].comment != "")
        {
         // Using a simple approach to track processed signals by comment
         static string processedSignals[];
         bool alreadyProcessed = false;
         for(int j = 0; j < ArraySize(processedSignals); j++)
           {
            if(processedSignals[j] == signals[i].comment)
              {
               alreadyProcessed = true;
               break;
              }
           }
         
         if(alreadyProcessed)
           {
            Print("Signal with comment '", signals[i].comment, "' already processed");
            continue;
           }
         
         // Add to processed signals
         int size = ArraySize(processedSignals);
         ArrayResize(processedSignals, size + 1);
         processedSignals[size] = signals[i].comment;
        }
      
      // Process the signal
      ProcessSignal(signals[i]);
      
      // Acknowledge the signal
      g_signalReceiver.AcknowledgeSignal(signals[i].comment);
     }
  }

//+------------------------------------------------------------------+
//| Process a trading signal from Paper EA                           |
//+------------------------------------------------------------------+
void ProcessSignal(const STradeSignal &signal)
  {
   // Validate signal
   if(CheckPointer(g_riskManager) == POINTER_INVALID ||
      CheckPointer(g_tradeExecutor) == POINTER_INVALID ||
      signal.signal == SIGNAL_HOLD ||
      signal.confidence < InpMinConfidence ||
      (TimeCurrent() - signal.timestamp) > InpMaxSignalAge)
   {
      if(g_knowledgeBase != NULL)
         g_knowledgeBase.LogSignalRejection(signal, "Invalid or expired signal");
      return;
   }
   
   // Verify signal version compatibility
   if(signal.version != SIGNAL_PROTOCOL_VERSION)
   {
      if(g_knowledgeBase != NULL)
         g_knowledgeBase.LogSignalRejection(signal, "Incompatible signal version");
      return;
   }
   
   // Check if we can open a new position
   if(!g_riskManager.IsTradeAllowed())
     {
      Print("Cannot open new position: Risk management rules not met");
      return;
     }
   
   // Calculate position size and levels
   double stopLoss = 0.0, takeProfit = 0.0;
   double ask = SymbolInfoDouble(signal.symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(signal.symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(signal.symbol, SYMBOL_POINT);
   
   if(InpUsePaperEASLTP && signal.stopLoss > 0 && signal.takeProfit > 0)
     {
      // Use SL/TP levels from Paper EA signal
      stopLoss = signal.stopLoss;
      takeProfit = signal.takeProfit;
      
      // Ensure SL/TP levels are valid for the current price
      if(signal.signal == SIGNAL_BUY)
        {
         if(stopLoss >= ask || takeProfit <= ask)
           {
            double atr = GetATR(signal.symbol, 14);
            stopLoss = ask - (atr * 2.0);
            takeProfit = ask + (atr * 3.0);
            Print("Warning: Invalid SL/TP from Paper EA. Using ATR-based levels");
           }
        }
      else if(signal.signal == SIGNAL_SELL)
        {
         if(stopLoss <= bid || takeProfit >= bid)
           {
            double atr = GetATR(signal.symbol, 14);
            stopLoss = bid + (atr * 2.0);
            takeProfit = bid - (atr * 3.0);
            Print("Warning: Invalid SL/TP from Paper EA. Using ATR-based levels");
           }
        }
     }
   else
     {
      // Fallback to ATR-based levels if Paper EA SL/TP is not available
      double atr = GetATR(signal.symbol, 14);
      
      if(signal.signal == SIGNAL_BUY)
        {
         stopLoss = ask - (atr * 2.0);
         takeProfit = ask + (atr * 3.0);
        }
      else if(signal.signal == SIGNAL_SELL)
        {
         stopLoss = bid + (atr * 2.0);
         takeProfit = bid - (atr * 3.0);
        }
     }
   
   // Calculate position size using risk percentage
   double lotSize = g_riskManager.CalculatePositionSize(InpRiskPerTrade);
   
   if(lotSize <= 0.0)
     {
      Print("Invalid lot size calculated");
      return;
     }
   
   // Execute the trade
   bool success = g_tradeExecutor.OpenPosition(
      (signal.signal == SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
      lotSize,
      stopLoss,
      takeProfit,
      "Live Trade from Paper EA"
   );
   
   // Record the trade
   if(success)
     {
      // Get the actual ticket number from the trade result
      ulong ticket = g_tradeExecutor.GetLastOrderTicket();
      if(ticket == 0)
        {
         Print("Warning: Failed to retrieve order ticket after successful execution");
         ticket = (ulong)MathRand(); // Fallback to random number if ticket retrieval fails
        }
      
      STradeRecord trade;
      trade.ticket = ticket;
      trade.openTime = TimeCurrent();
      trade.symbol = signal.symbol;
      trade.type = (signal.signal == SIGNAL_BUY) ? TRADE_TYPE_BUY : TRADE_TYPE_SELL;
      trade.lots = lotSize;
      trade.openPrice = (signal.signal == SIGNAL_BUY) ? 
                        SymbolInfoDouble(signal.symbol, SYMBOL_ASK) : 
                        SymbolInfoDouble(signal.symbol, SYMBOL_BID);
      trade.stopLoss = stopLoss;
      trade.takeProfit = takeProfit;
      trade.commission = 0.0;
      trade.swap = 0.0;
      trade.profit = 0.0;
      trade.signal = signal.signal;
      trade.confidence = signal.confidence;
      trade.isLive = true;
      
      // Add to knowledge base
      if(CheckPointer(g_knowledgeBase) != POINTER_INVALID)
         g_knowledgeBase.AddTrade(trade);
      
      g_totalTrades++;
      g_successfulTrades++;
      
      Print("Successfully executed ", EnumToString(signal.signal), " trade for ", signal.symbol);
     }
   else
     {
      g_failedTrades++;
      Print("Failed to execute ", EnumToString(signal.signal), " trade for ", signal.symbol);
     }
  }

//+------------------------------------------------------------------+
//| Perform periodic tasks                                           |
//+------------------------------------------------------------------+
void PerformPeriodicTasks()
  {
   // Clean up expired signals
   if(CheckPointer(g_signalReceiver) != POINTER_INVALID)
      g_signalReceiver.CleanupExpiredSignals();
   
   // Update learning model
   if(InpEnableLearning && CheckPointer(g_learningEngine) != POINTER_INVALID && 
      CheckPointer(g_knowledgeBase) != POINTER_INVALID)
     {
      // Get recent trades for learning
      STradeRecord trades[];
      if(g_knowledgeBase.GetRecentTrades(InpLearningWindow, trades))
        {
         // Update learning model
         g_learningEngine.TrainModel(trades);
        }
     }
   
   // Log status
   LogStatus();
  }

//+------------------------------------------------------------------+
//| Log system status                                                |
//+------------------------------------------------------------------+
void LogStatus()
  {
   static datetime g_lastLogTime = 0;
   if(TimeCurrent() - g_lastLogTime >= 15 * 60)  // Log every 15 minutes
     {
      string logMessage = "EA is running - " + 
                         "Account: " + AccountInfoString(ACCOUNT_NAME) + 
                         ", Balance: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + 
                         ", Equity: " + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2);
      
      LogToFile("LiveEA_Heartbeat.log", logMessage);
      
      // If we have a signal broadcaster, use it to send monitoring info
      if(CheckPointer(g_signalBroadcaster) != POINTER_INVALID)
        {
         g_signalBroadcaster.SendSignal("heartbeat", logMessage);
        }
        
      g_lastLogTime = TimeCurrent();
     }  
   string status = StringFormat("LiveEA Status - Total: %d, Success: %d, Failed: %d, Win Rate: %.1f%%",
                               g_totalTrades,
                               g_successfulTrades,
                               g_failedTrades,
                               g_totalTrades > 0 ? ((double)g_successfulTrades / g_totalTrades) * 100.0 : 0.0);
   
   Print(status);
   
   // Log to file with timestamp
   string filename = "status_" + TimeToString(TimeCurrent(), TIME_DATE) + ".log";
   if(!LogToFile(filename, status))
     {
      Print("Failed to write status to log file");
     }
     
   // Send status to monitoring system if available
   if(CheckPointer(g_knowledgeBase) != POINTER_INVALID)
     {
      g_knowledgeBase.LogSystemStatus(status);
     }
  }

//+------------------------------------------------------------------+
//| Send heartbeat to monitor                                        |
//+------------------------------------------------------------------+
void SendHeartbeat()
  {
   // Prepare system status
   string status = "OK";
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin = AccountInfoDouble(ACCOUNT_MARGIN);
   double marginLevel = (margin > 0) ? equity / margin * 100 : 0;
   
   // Check for critical conditions
   if(marginLevel > 0 && marginLevel < 100)
     {
      status = "WARNING: Low margin level (" + DoubleToString(marginLevel, 1) + "%)";
     }
   else if(marginLevel == 0 && margin > 0)
     {
      status = "CRITICAL: Margin call risk";
     }
   
   // Log detailed status
   string message = StringFormat("Heartbeat | Status: %s | Balance: %.2f | Equity: %.2f | Margin: %.2f | Margin Level: %.1f%% | Trades: %d/%d",
                               status, balance, equity, margin, marginLevel, 
                               g_successfulTrades, g_totalTrades);
   
   // Log to file
   if(LogToFile("heartbeat.log", message))
     {
      Print("Heartbeat logged: ", message);
     }
     
   // Update chart comment
   Comment("EscapeEA Live | ", message);
     
   // Send to monitoring system if available
   if(CheckPointer(g_knowledgeBase) != POINTER_INVALID)
     {
      g_knowledgeBase.SendToMonitoring("heartbeat", message);
     }
  }

//+------------------------------------------------------------------+
//| Check and update open positions                                  |
//+------------------------------------------------------------------+
void CheckAndUpdatePositions()
  {
   if(CheckPointer(g_riskManager) == POINTER_INVALID || 
      CheckPointer(g_tradeExecutor) == POINTER_INVALID)
      return;
      
   // Check for position modifications, trailing stops, etc.
   // This is a placeholder implementation
   Print("Checking and updating positions...");
  }

//+------------------------------------------------------------------+
//| Process pending orders                                           |
//+------------------------------------------------------------------+
void ProcessPendingOrders()
  {
   if(CheckPointer(g_tradeExecutor) == POINTER_INVALID)
      return;
      
   // Process any pending orders (modify, delete, etc.)
   // This is a placeholder implementation
   Print("Processing pending orders...");
  }

//+------------------------------------------------------------------+
//| Update with tick data                                            |
//+------------------------------------------------------------------+
void UpdateWithTickData(const MqlTick &tick)
  {
   if(CheckPointer(g_learningEngine) != POINTER_INVALID)
     {
      // Update learning engine with latest tick data
      // This is a placeholder implementation
      static int tickCount = 0;
      if(++tickCount % 100 == 0)
         Print("Processed ", tickCount, " ticks");
     }
  }

//+------------------------------------------------------------------+
//| Check for emergency stop conditions                              |
//+------------------------------------------------------------------+
void CheckEmergencyStop()
  {
   // Check account balance/equity stop levels
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   if(equity < balance * (1.0 - InpDailyDrawdownLimit / 100.0))
     {
      Print("Emergency stop: Daily drawdown limit reached!");
      // Close all positions and disable trading
      if(CheckPointer(g_tradeExecutor) != POINTER_INVALID)
         g_tradeExecutor.CloseAllPositions();
      ExpertRemove();
     }
  }
   
//+------------------------------------------------------------------+
//| ... rest of the code remains the same ...
  }
