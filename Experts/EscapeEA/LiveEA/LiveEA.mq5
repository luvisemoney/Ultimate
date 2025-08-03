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

//--- Input Parameters
input group "=== General Settings ==="
input string   InpPaperEAPrefix = "ESCAPEEA_PAPER_"; // Paper EA signal prefix
input string   InpSymbol = "";                      // Trading symbol (empty for chart symbol)
input double   InpRiskPerTrade = 1.0;                // Risk per trade (% of balance)
input int      InpMaxOpenTrades = 3;                 // Maximum open trades
input int      InpMagicNumber = 123457;              // Magic number for identification
input double   InpSlippage = 10.0;                   // Slippage in points
input bool     InpEnableTrading = true;              // Enable live trading
input int      InpEvaluationInterval = 15;           // Evaluation interval in minutes
input int      InpMinTradesPerInterval = 10;         // Minimum trades per interval
input double   InpDailyDrawdownLimit = 5.0;          // Max daily drawdown %
input color    InpPanelColor = clrLimeGreen;         // Panel color
input int      InpFontSize = 8;                      // Font size

// Live EA Specific
input bool     InpAcceptPaperSignals = true;         // Accept signals from Paper EA
input double   InpMaxPositionSize = 10.0;            // Maximum position size in lots
input bool     InpUseHardStops = true;               // Use hard stop losses
input string   InpSharedKBDir = "shared_kb";        // Shared knowledge base directory

input group "=== Signal Processing ==="
input double   InpMinConfidence = 0.7;               // Minimum confidence to accept signals (0.0-1.0)
input int      InpMaxSignalAge = 300;                // Maximum signal age (seconds)
input bool     InpUsePaperEASLTP = true;             // Use Paper EA's SL/TP levels
input bool     InpEnableSignalLogging = true;        // Enable signal logging
input string   InpConfidenceAdjustMode = "online";  // Learning mode: online or batch

input group "=== Learning Settings ==="
input int      InpLearningWindow = 100;              // Learning window size (trades)
input double   InpMinWinRate = 0.6;                   // Minimum win rate for strategy validation
input double   InpLearningRate = 0.01;                // Learning rate for model updates
input bool     InpEnableLearning = true;              // Enable learning from trades
input bool     InpEnableRegimeClassification = true;  // Enable market regime classification

//--- Global Variables
CRiskManager     *g_riskManager = NULL;
CTradeExecutor   *g_tradeExecutor = NULL;
CLearningEngine  *g_learningEngine = NULL;
CKnowledgeBase   *g_knowledgeBase = NULL;
CSignalReceiver  *g_signalReceiver = NULL;

string           g_symbol;
string           g_signalPrefix;
datetime         g_lastSignalCheck = 0;
int              g_totalTrades = 0;
int              g_successfulTrades = 0;
int              g_failedTrades = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Set symbol
   g_symbol = (InpSymbol == "") ? _Symbol : InpSymbol;
   g_signalPrefix = InpPaperEAPrefix + g_symbol + "_" + (string)InpMagicNumber + "_";
   
   // Initialize random seed
   MathSrand((uint)TimeCurrent());
   
   // Initialize components
   if(!InitializeComponents())
     {
      Print("Failed to initialize components");
      return INIT_FAILED;
     }
   
   // Load historical data
   if(!LoadHistoricalData())
     {
      Print("Warning: Failed to load historical data");
     }
   
   // Initialize timer for signal checking (every 1 second)
   EventSetTimer(1);
   
   Print("EscapeEA Live Trader initialized successfully");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // Clean up
   if(CheckPointer(g_riskManager) == POINTER_DYNAMIC)
      delete g_riskManager;
      
   if(CheckPointer(g_tradeExecutor) == POINTER_DYNAMIC)
      delete g_tradeExecutor;
      
   if(CheckPointer(g_learningEngine) == POINTER_DYNAMIC)
      delete g_learningEngine;
      
   if(CheckPointer(g_knowledgeBase) == POINTER_DYNAMIC)
      delete g_knowledgeBase;
      
   if(CheckPointer(g_signalReceiver) == POINTER_DYNAMIC)
      delete g_signalReceiver;
      
   // Disable timer
   EventKillTimer();
   
   Print("EscapeEA Live Trader deinitialized");
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // In a real implementation, this would handle tick-by-tick processing
   // For signal-based trading, we primarily use the timer
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
   // Initialize risk manager with all required parameters
   g_riskManager = new CRiskManager(
      g_symbol,                  // symbol
      InpRiskPerTrade,           // riskPercent
      20.0,                      // maxDrawdown (default 20%)
      5.0,                       // maxDailyLoss (default 5%)
      10.0,                      // maxPositionSize (default 10 lots)
      InpMaxOpenTrades           // maxOpenTrades
   );
   if(CheckPointer(g_riskManager) == POINTER_INVALID)
     {
      Print("Failed to create risk manager");
      return false;
     }
   
   // Initialize trade executor (live trading)
   g_tradeExecutor = new CTradeExecutor(InpMagicNumber, InpEnableTrading, g_symbol, InpSlippage);
   if(CheckPointer(g_tradeExecutor) == POINTER_INVALID)
     {
      Print("Failed to create trade executor");
      return false;
     }
   
   // Initialize knowledge base
   g_knowledgeBase = new CKnowledgeBase("EscapeEA_Live_" + g_symbol);
   if(CheckPointer(g_knowledgeBase) == POINTER_INVALID)
     {
      Print("Failed to create knowledge base");
      return false;
     }
   
   // Initialize learning engine
   g_learningEngine = new CLearningEngine(InpLearningWindow, InpMinWinRate, InpLearningRate);
   if(CheckPointer(g_learningEngine) == POINTER_INVALID)
     {
      Print("Failed to create learning engine");
      return false;
     }
   
   // Initialize signal receiver
   g_signalReceiver = new CSignalReceiver(g_signalPrefix, InpMaxSignalAge);
   if(CheckPointer(g_signalReceiver) == POINTER_INVALID)
     {
      Print("Failed to create signal receiver");
      return false;
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Load historical data for backtesting                             |
//+------------------------------------------------------------------+
bool LoadHistoricalData()
  {
   // In a real implementation, this would load historical data for backtesting
   // For now, we'll just return true
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
   
   if(InpUsePaperEASLTP)
     {
      // In a real implementation, we would get SL/TP levels from the Paper EA
      // For now, we'll use a simple ATR-based approach
      int atr_handle = iATR(signal.symbol, PERIOD_CURRENT, 14);
      double atr_buffer[1];
      double atr_value = 0.0;
      
      if(atr_handle != INVALID_HANDLE)
        {
         if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) > 0)
           {
            atr_value = atr_buffer[0];
           }
         IndicatorRelease(atr_handle);
        }
      
      if(atr_value <= 0)
        {
         Print("Error: Invalid ATR value");
         return;
        }
      
      double point = SymbolInfoDouble(signal.symbol, SYMBOL_POINT);
      double ask = SymbolInfoDouble(signal.symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(signal.symbol, SYMBOL_BID);
      
      if(signal.signal == SIGNAL_BUY)
        {
         stopLoss = ask - (atr_value * 2.0);
         takeProfit = ask + (atr_value * 3.0);
        }
      else if(signal.signal == SIGNAL_SELL)
        {
         stopLoss = bid + (atr_value * 2.0);
         takeProfit = bid - (atr_value * 3.0);
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
      STradeRecord trade;
      trade.ticket = (ulong)MathRand(); // In a real implementation, get the actual ticket
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
   static datetime lastLogTime = 0;
   
   // Log status every 5 minutes
   if(TimeCurrent() - lastLogTime < 300)
      return;
   
   lastLogTime = TimeCurrent();
   
   string status = StringFormat("LiveEA Status - Total: %d, Success: %d, Failed: %d, Win Rate: %.1f%%",
                               g_totalTrades,
                               g_successfulTrades,
                               g_failedTrades,
                               g_totalTrades > 0 ? ((double)g_successfulTrades / g_totalTrades) * 100.0 : 0.0);
   
   Print(status);
   
   // In a real implementation, you might want to log this to a file or send it as a notification
  }

//+------------------------------------------------------------------+
//| Send heartbeat with system status                                |
//+------------------------------------------------------------------+
void SendHeartbeat()
  {
   // Create a status message
   string heartbeatMsg = StringFormat("EscapeEA Live - %s | Trades: %d (%d/%d) | Equity: %.2f | Balance: %.2f | Drawdown: %.2f%% | Memory: %d KB",
                                    TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
                                    g_totalTrades,
                                    g_successfulTrades,
                                    g_failedTrades,
                                    AccountInfoDouble(ACCOUNT_EQUITY),
                                    AccountInfoDouble(ACCOUNT_BALANCE),
                                    AccountInfoDouble(ACCOUNT_MARGIN) > 0 ? 
                                       ((AccountInfoDouble(ACCOUNT_BALANCE) - AccountInfoDouble(ACCOUNT_EQUITY)) / AccountInfoDouble(ACCOUNT_BALANCE)) * 100.0 : 0.0,
                                    TerminalInfoInteger(TERMINAL_MEMORY_USED) / 1024);
   
   // Log to experts log
   Print("HEARTBEAT: ", heartbeatMsg);
   
   // In a real implementation, you might want to send this to a monitoring system or dashboard
   // For example: SendNotification(heartbeatMsg);
   
   // Also log to knowledge base if available
   if(CheckPointer(g_knowledgeBase) != POINTER_INVALID)
     {
      string logEntry = StringFormat("HEARTBEAT: %s", heartbeatMsg);
      g_knowledgeBase.LogIntervalSnapshot("LiveEA", g_symbol, logEntry);
     }
  }
