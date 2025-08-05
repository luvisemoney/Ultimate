//+------------------------------------------------------------------+
//|                                              EscapeEA_PaperEA.mq5 |
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
#include "..\Include\Core\SignalGenerator.mqh"
#include "..\Include\Core\RiskManager.mqh"
#include "..\Include\Core\TradeExecutor.mqh"
#include "..\Include\Learning\LearningEngine.mqh"
#include "..\Include\Learning\KnowledgeBase.mqh"
#include "..\Include\Communication\SignalBroadcaster.mqh"

//+------------------------------------------------------------------+
//| Input Parameters with Validation                                 |
//+------------------------------------------------------------------+
input group "=== General Settings ==="
input string   InpSymbol = "";              // Trading symbol (empty for chart symbol)
input bool     InpEnableLiveTrading = true; // Enable live trading
input double   InpRiskPerTrade = 1.0;        // Risk per trade (% of balance, 0.1-10.0)
input int      InpMaxOpenTrades = 5;         // Maximum open trades (1-100)
input int      InpMagicNumber = 123456;      // Magic number for identification (100000-999999)
input double   InpSlippage = 10.0;           // Slippage in points (0-100)
input int      InpEvaluationInterval = 15;    // Evaluation interval in minutes (1-1440)
input int      InpMinTradesPerInterval = 10;  // Minimum trades per interval (1-1000)
input double   InpDailyDrawdownLimit = 5.0;   // Max daily drawdown % (0.1-50.0)
input color    InpPanelColor = clrDodgerBlue; // Panel color
input int      InpFontSize = 8;              // Font size (8-20)

// Paper EA Specific
input bool     InpEnableSignals = true;                  // Enable signal generation
input int      InpMaxSignalsPerInterval = 10;            // Max signals per interval (1-100)
input double   InpVirtualBalance = 10000.0;              // Virtual balance for paper trading (100-1000000)
input int      InpSignalExpiryBars = 5;                  // Signal expiry in bars (1-100)
input int      InpMaxSignalAge = 3600;                   // Max signal age in seconds (60-86400, 1 hour default)
input string   InpSharedKBDir = "C:\\Users\\echuk\\Mon Drive\\Shared Knowledge Base";            // Shared knowledge base directory (max 255 chars)

input group "=== Signal Generation ==="
input ENUM_MA_METHOD     InpMAMethod = MODE_EMA;         // MA Method (MODE_EMA, MODE_SMA, MODE_SMMA, MODE_LWMA)
input int                InpMAPeriod = 20;               // MA Period (2-200)
input ENUM_APPLIED_PRICE InpMAPrice = PRICE_CLOSE;       // MA Price (PRICE_CLOSE, PRICE_OPEN, etc.)
input int                InpRSIPeriod = 14;              // RSI Period (2-100)
input double             InpRSIOverbought = 70.0;        // RSI Overbought Level (50-90)
input double             InpRSIOversold = 30.0;          // RSI Oversold Level (10-50)
input int                InpATRPeriod = 14;              // ATR Period (2-100)
input double             InpATRMultiplier = 2.0;         // ATR Multiplier for SL/TP (0.1-10.0)
input double             InpMinConfidence = 0.8;         // Minimum confidence threshold (0.0-1.0)
input string             InpConfidenceAdjustMode = "online"; // Learning mode: "online" or "batch"

input group "=== Learning Settings ==="
input int      InpLearningWindow = 100;        // Learning window size (10-1000 trades)
input double   InpMinWinRate = 0.6;             // Minimum win rate for signal validation (0.5-1.0)
input double   InpLearningRate = 0.01;          // Learning rate for model updates (0.0001-1.0)
input bool     InpEnableLearning = true;        // Enable learning from trades
input bool     InpEnableRegimeClassification = true; // Enable market regime classification

//+------------------------------------------------------------------+
//| Global Variables with Initialization                             |
//+------------------------------------------------------------------+
CSignalGenerator  *g_signalGenerator = NULL;    // Signal generator instance
CRiskManager     *g_riskManager = NULL;         // Risk management instance
CTradeExecutor   *g_tradeExecutor = NULL;       // Trade execution instance
CLearningEngine  *g_learningEngine = NULL;      // Learning engine instance
CKnowledgeBase   *g_knowledgeBase = NULL;       // Knowledge base instance
CSignalBroadcaster *g_signalBroadcaster = NULL; // Signal broadcaster instance

// Runtime state
string           g_symbol;                      // Trading symbol
string           g_errorMessage = "";           // Last error message
string           g_learningModelPath = "EscapeEA_Model.dat"; // Path to save/load the learning model
datetime         g_lastBarTime = 0;            // Last processed bar time
int              g_totalTrades = 0;             // Total trades count
int              g_consecutiveWins = 0;         // Consecutive winning trades
int              g_consecutiveLosses = 0;       // Consecutive losing trades
bool             g_signalActive = false;        // Signal active flag
bool             g_initialized = false;         // Initialization flag

//+------------------------------------------------------------------+
//| Get error description from error code                            |
//+------------------------------------------------------------------+
string ErrorDescription(int error_code)
  {
   string error_string = "Unknown error";
   
   // Get the error description from the terminal
   ResetLastError();
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
     {
      error_string = "Terminal not connected";
     }
   else
     {
      error_string = (string)error_code + ": " + (string)GetLastError();
     }
      
   return error_string;
  }

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
   
   // Set symbol and initialize random seed
   g_symbol = (StringLen(InpSymbol) > 0) ? InpSymbol : _Symbol;
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
     
   // Set initial bar time
   g_lastBarTime = iTime(g_symbol, PERIOD_CURRENT, 0);
   
   // Initialize timer for periodic tasks (every 5 seconds)
   EventSetTimer(5);
   
   // Mark as initialized
   g_initialized = true;
   Print("EscapeEA Paper Trader initialized successfully");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Print("Shutting down PaperEA, reason: ", GetUninitializeReasonText(reason));
   
   // Clean up components safely
   SafeDelete(g_signalBroadcaster);
   SafeDelete(g_learningEngine);
   SafeDelete(g_tradeExecutor);
   SafeDelete(g_riskManager);
   SafeDelete(g_signalGenerator);
   SafeDelete(g_knowledgeBase);
   
   // Clear initialization flag
   g_initialized = false;
   Print("PaperEA shutdown complete");
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
     
   // Add more validations for other inputs...
   
   return true;
  }

//+------------------------------------------------------------------+
//| Initialize components with error handling                       |
//+------------------------------------------------------------------+
bool InitializeComponents()
  {
   bool success = true;
   
   // Initialize signal generator with error handling
   Print("Initializing signal generator...");
   g_signalGenerator = new CSignalGenerator(g_symbol, _Period, 10, 20, 14, 14, 0.7);
   if(CheckPointer(g_signalGenerator) == POINTER_INVALID)
     {
      g_errorMessage = "Failed to create signal generator";
      return false;
     }
   if(CheckPointer(g_signalGenerator) == POINTER_INVALID)
     {
      Print("Error: Failed to create signal generator");
      return false;
     }
   Print("Signal generator initialized successfully");
   
   // Initialize risk manager
   Print("Initializing risk manager...");
   g_riskManager = new CRiskManager(g_symbol, InpRiskPerTrade, 20.0, 10.0, 10.0, InpMaxOpenTrades); // Max drawdown: 20%, Max daily loss: 10%, Max position size: 10 lots
   if(CheckPointer(g_riskManager) == POINTER_INVALID)
     {
      Print("Error: Failed to create risk manager");
      return false;
     }
   Print("Risk manager initialized successfully");
   
   // Initialize trade executor (paper trading only)
   Print("Initializing trade executor...");
   g_tradeExecutor = new CTradeExecutor(InpMagicNumber, InpEnableLiveTrading, g_symbol, InpSlippage);
   if(CheckPointer(g_tradeExecutor) == POINTER_INVALID)
     {
      Print("Error: Failed to create trade executor");
      return false;
     }
   Print("Trade executor initialized successfully");
   
   // Initialize knowledge base
   Print("Initializing knowledge base...");
   string kbName = "EscapeEA_Paper_" + g_symbol;
   Print("Creating knowledge base with name: ", kbName);
   g_knowledgeBase = new CKnowledgeBase(kbName, InpSharedKBDir);
   if(CheckPointer(g_knowledgeBase) == POINTER_INVALID)
     {
      Print("Error: Failed to create knowledge base");
      return false;
     }
   Print("Knowledge base initialized successfully");
   
   // Initialize learning engine
   Print("Initializing learning engine...");
   Print("Learning window: ", InpLearningWindow, " Min win rate: ", InpMinWinRate, " Learning rate: ", InpLearningRate);
   g_learningEngine = new CLearningEngine(InpLearningWindow, InpMinWinRate, InpLearningRate);
   if(CheckPointer(g_learningEngine) == POINTER_INVALID)
     {
      Print("Error: Failed to create learning engine - memory allocation failed");
      return false;
     }
   Print("Learning engine initialized successfully");
   
   // Check if learning engine is active and needs updating
   if(CheckPointer(g_learningEngine) != POINTER_INVALID && 
      g_learningEngine.IsActive() && 
      g_learningEngine.ShouldUpdate())
     {
      Print("Learning engine is active and ready for updates");
      // Additional update logic can be added here if needed
     }
   
   // Initialize signal broadcaster
   Print("Initializing signal broadcaster...");
   string broadcasterPrefix = "ESCAPEEA_PAPER_" + g_symbol + "_" + (string)InpMagicNumber + "_";
   Print("Signal broadcaster prefix: ", broadcasterPrefix);
   g_signalBroadcaster = new CSignalBroadcaster(broadcasterPrefix);
   if(CheckPointer(g_signalBroadcaster) == POINTER_INVALID)
     {
      Print("Error: Failed to create signal broadcaster");
      return false;
     }
   Print("Signal broadcaster initialized successfully");
   
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
   
   // Define the time period for historical data (last 6 months)
   datetime endTime = TimeCurrent();
   datetime startTime = endTime - 180 * 24 * 60 * 60; // 180 days ago
   
   // Request historical rates
   MqlRates rates[];
   int copied = CopyRates(g_symbol, _Period, startTime, endTime, rates);
   
   if(copied <= 0)
     {
      int error = GetLastError();
      Print("Failed to load historical data. Error: ", (string)error, " - ", ErrorDescription(error));
      return false;
     }
   
   Print("Successfully loaded ", copied, " bars of historical data");
   
   // Initialize the learning engine with historical data
   if(CheckPointer(g_learningEngine) != POINTER_INVALID)
     {
      if(!g_learningEngine.Initialize())
        {
         Print("Warning: Failed to initialize learning engine with historical data");
        }
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Check if a new bar has formed                                    |
//+------------------------------------------------------------------+
bool IsNewBar()
  {
   datetime currentBarTime = iTime(g_symbol, PERIOD_CURRENT, 0);
   
   if(currentBarTime > g_lastBarTime)
     {
      g_lastBarTime = currentBarTime;
      return true;
     }
     
   return false;
  }

//+------------------------------------------------------------------+
//| Update indicator values                                          |
//+------------------------------------------------------------------+
void UpdateIndicators()
  {
   if(CheckPointer(g_signalGenerator) != POINTER_INVALID)
      g_signalGenerator.UpdateIndicators();
  }

//+------------------------------------------------------------------+
//| Check for trading signals                                        |
//+------------------------------------------------------------------+
void CheckTradingSignals()
  {
   if(CheckPointer(g_signalGenerator) == POINTER_INVALID ||
      CheckPointer(g_riskManager) == POINTER_INVALID ||
      CheckPointer(g_tradeExecutor) == POINTER_INVALID)
      return;
   
   // Get and validate current signal
   STradeSignal signal = g_signalGenerator.GenerateSignal();
   
   // Return if no valid signal or signal is too old
   if(signal.signal == SIGNAL_HOLD || 
      (TimeCurrent() - signal.timestamp) > InpMaxSignalAge)
      return;
   
   // Check risk management
   if(CheckPointer(g_riskManager) == POINTER_INVALID || 
      CheckPointer(g_tradeExecutor) == POINTER_INVALID ||
      !g_riskManager.IsTradeAllowed())
      return;
   
   // Calculate position size
   double stopLoss = signal.stopLoss;
   double takeProfit = signal.takeProfit;
   double lotSize = g_riskManager.CalculatePositionSize(MathAbs(signal.entry - stopLoss) / _Point);
   
   if(lotSize <= 0.0)
      return;
   
   // Execute trade (paper trading only)
   if(g_tradeExecutor.OpenPosition((signal.signal == SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                                  lotSize, stopLoss, takeProfit, "Paper Trade"))
     {
      // Record trade with proper ticket and timestamps
      STradeRecord trade; // Initialize the structure
      ZeroMemory(trade);
      
      // Initialize trade record with current values
      trade.ticket = (ulong)MathRand(); // Generate a random ticket for paper trading
      trade.symbol = g_symbol;
      trade.type = (signal.signal == SIGNAL_BUY) ? TRADE_TYPE_BUY : TRADE_TYPE_SELL;
      trade.lots = lotSize;
      trade.openPrice = (trade.type == TRADE_TYPE_BUY) ? 
                       SymbolInfoDouble(g_symbol, SYMBOL_ASK) : 
                       SymbolInfoDouble(g_symbol, SYMBOL_BID);
      trade.stopLoss = stopLoss;
      trade.takeProfit = takeProfit;
      trade.openTime = TimeCurrent();
      trade.comment = "Paper Trade";
      
      // Simulate commission and swap (for paper trading)
      double commissionRate = 0.0002; // 2 pips per lot
      trade.commission = trade.lots * SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MIN) * 
                        trade.openPrice * commissionRate;
      
      // Calculate swap (simplified)
      double swapRate = (trade.type == TRADE_TYPE_BUY) ? -0.0001 : 0.00005; // Simplified swap rates
      trade.swap = trade.lots * SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MIN) * 
                  trade.openPrice * swapRate * (1.0/30.0); // Daily swap
      
      trade.profit = 0.0; // Will be updated when position is closed
      trade.signal = signal.signal;
      trade.confidence = signal.confidence;
      trade.isLive = false;
      
      // Add to knowledge base
      if(CheckPointer(g_knowledgeBase) != POINTER_INVALID)
         g_knowledgeBase.AddTrade(trade);
      
      // Broadcast signal to Live EA if active
      if(g_signalActive && CheckPointer(g_signalBroadcaster) != POINTER_INVALID)
        {
         // Create a copy of the signal with current market prices
         STradeSignal liveSignal = signal;
         liveSignal.timestamp = TimeCurrent();
         liveSignal.entry = (signal.signal == SIGNAL_BUY) ? 
                           SymbolInfoDouble(g_symbol, SYMBOL_ASK) : 
                           SymbolInfoDouble(g_symbol, SYMBOL_BID);
         
         // Ensure SL/TP levels are valid
         if(stopLoss <= 0 || takeProfit <= 0)
           {
            // Calculate ATR-based SL/TP if not provided
            int atr_handle = iATR(g_symbol, PERIOD_CURRENT, 14);
            double atr_buffer[];
            ArraySetAsSeries(atr_buffer, true);
            
            if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) > 0)
              {
               double atr = atr_buffer[0];
               if(atr > 0)
                 {
                  if(signal.signal == SIGNAL_BUY)
                    {
                     liveSignal.stopLoss = liveSignal.entry - (2.0 * atr);
                     liveSignal.takeProfit = liveSignal.entry + (3.0 * atr);
                    }
                  else // SELL
                    {
                     liveSignal.stopLoss = liveSignal.entry + (2.0 * atr);
                     liveSignal.takeProfit = liveSignal.entry - (3.0 * atr);
                    }
                 }
              }
            
            // Release the indicator handle
            if(atr_handle != INVALID_HANDLE)
               IndicatorRelease(atr_handle);
           }
         
         // Broadcast the signal with SL/TP levels
         // Convert the signal to the format expected by SendSignal
         string signalStr = StringFormat("%s|%f|%f|%f|%f", 
                                       EnumToString(signal.signal),
                                       liveSignal.entry,
                                       liveSignal.stopLoss,
                                       liveSignal.takeProfit,
                                       signal.confidence);
         
         if(g_signalBroadcaster.SendSignal(signalStr, signal.signal, signal.confidence))
           {
            Print("Signal sent to Live EA: ", EnumToString(signal.signal), 
                  " SL:", liveSignal.stopLoss, " TP:", liveSignal.takeProfit);
           }
         else
           {
            Print("Failed to send signal to Live EA");
           }
        }
      
      g_totalTrades++;
      
      // Check if we should send a signal to the Live EA
      CheckSignalActivation();
     }
  }

//+------------------------------------------------------------------+
//| Monitor open positions and update SL/TP if needed                |
//+------------------------------------------------------------------+
void MonitorPositions()
  {
   // Get all open positions
   int total = PositionsTotal();
   for(int i = total-1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      string symbol = PositionGetString(POSITION_SYMBOL);
      if(symbol != g_symbol) continue;
      
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      
      // Calculate new ATR for dynamic SL/TP adjustment
      // In MQL5, we need to use iATR to get a handle and then copy the values
      int atr_handle = iATR(g_symbol, PERIOD_CURRENT, 14);
      double atr_buffer[];
      ArraySetAsSeries(atr_buffer, true);
      
      // Copy the ATR values
      if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) <= 0)
      {
         Print("Error copying ATR buffer: ", GetLastError());
         continue;
      }
      
      double atr = atr_buffer[0];
      if(atr <= 0 || atr == EMPTY_VALUE) continue;
      
      // Adjust SL/TP based on price movement
      double newSL = currentSL;
      double newTP = currentTP;
      bool needsUpdate = false;
      
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
         // Move SL to breakeven + 1 ATR when price moves 2*ATR in profit
         if(currentPrice > (currentTP - (3 * atr)) && currentSL < PositionGetDouble(POSITION_PRICE_OPEN))
           {
            newSL = PositionGetDouble(POSITION_PRICE_OPEN) + (1 * atr);
            needsUpdate = true;
           }
        }
      else // SELL position
        {
         // Move SL to breakeven - 1 ATR when price moves 2*ATR in profit
         if(currentPrice < (currentTP + (3 * atr)) && (currentSL > PositionGetDouble(POSITION_PRICE_OPEN) || currentSL == 0))
           {
            newSL = PositionGetDouble(POSITION_PRICE_OPEN) - (1 * atr);
            needsUpdate = true;
           }
        }
      
      // Update position if needed
      if(needsUpdate && CheckPointer(g_tradeExecutor) != POINTER_INVALID)
        {
         g_tradeExecutor.ModifyPosition(ticket, newSL, newTP);
        }
     }
  }

//+------------------------------------------------------------------+
//| Update learning model with recent trades and market data         |
//+------------------------------------------------------------------+
void UpdateLearningModel()
  {
   if(CheckPointer(g_knowledgeBase) == POINTER_INVALID || 
      CheckPointer(g_learningEngine) == POINTER_INVALID)
      return;
   
   // Get recent trades for learning (last 100 trades or all if less)
   STradeRecord trades[];
   if(g_knowledgeBase.GetRecentTrades(InpLearningWindow, trades))
     {
      // Update learning model with recent trades
      for(int i = 0; i < ArraySize(trades); i++)
        {
         g_learningEngine.UpdateModel(trades[i]);
        }
      
      // Train the model with all recent trades
      g_learningEngine.TrainModel(trades);
     }
     
   // Update market state with current tick data
   MqlTick lastTick;
   if(SymbolInfoTick(g_symbol, lastTick))
     {
      // Extract key market features from tick data
      double spread = (lastTick.ask - lastTick.bid) / _Point;
      double tickVolume = (double)lastTick.volume;
      
      // Update market state in the knowledge base
      if(CheckPointer(g_knowledgeBase) != POINTER_INVALID)
        {
         // Create a market state record
         SMarketState state;
         state.timestamp = lastTick.time;
         state.spread = spread;
         state.volume = tickVolume;
         state.bid = lastTick.bid;
         state.ask = lastTick.ask;
         
         // Save market state to knowledge base
         g_knowledgeBase.SaveMarketState(state);
         
         // Calculate and save ATR for volatility
         double atr[];
         int atrHandle = iATR(g_symbol, PERIOD_CURRENT, 14);
         if(atrHandle != INVALID_HANDLE)
           {
            if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0)
              {
               SVolatilityData volData;
               volData.timestamp = lastTick.time;
               volData.atr = atr[0];
               g_knowledgeBase.SaveVolatilityData(volData);
              }
            IndicatorRelease(atrHandle);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Clean up expired signals from the knowledge base                 |
//+------------------------------------------------------------------+
void CleanupExpiredSignals()
  {
   if(CheckPointer(g_knowledgeBase) == POINTER_INVALID)
      return;
      
   datetime currentTime = TimeCurrent();
   datetime expiryTime = currentTime - InpMaxSignalAge;
   
   // Log cleanup activity
   Print("Cleaning up signals older than ", TimeToString(expiryTime, TIME_DATE|TIME_SECONDS));
  }

//+------------------------------------------------------------------+
//| Update performance metrics and statistics                        |
//+------------------------------------------------------------------+
void UpdatePerformanceMetrics()
  {
   if(CheckPointer(g_knowledgeBase) == POINTER_INVALID)
      return;
      
   // Get performance metrics
   double winRate = 0.0;
   double profitFactor = 0.0;
   int totalTrades = 0;
   int winningTrades = 0;
   double maxDrawdown = 0.0;
   
   // Log metrics to console
   string logEntry = StringFormat("Metrics | Win Rate: %.2f%% | Profit Factor: %.2f | Max DD: %.2f%% | Trades: %d (%d wins)",
                                winRate * 100.0, profitFactor, maxDrawdown, totalTrades, winningTrades);
   Print(logEntry);
  }

//+------------------------------------------------------------------+
//| Send status update                                               |
//+------------------------------------------------------------------+
void SendStatusUpdate()
  {
   if(CheckPointer(g_signalBroadcaster) == POINTER_INVALID)
      return;
   
   string status = StringFormat("PaperEA Status - Trades: %d, Win Rate: %.1f%%, Active: %s",
                               g_totalTrades, 
                               g_learningEngine != NULL ? g_learningEngine.GetWinRate() * 100.0 : 0.0,
                               g_signalActive ? "Yes" : "No");
   
   g_signalBroadcaster.BroadcastStatus(status);
  }

//+------------------------------------------------------------------+
//| Check if we should activate signal sending to Live EA            |
//+------------------------------------------------------------------+
void CheckSignalActivation()
  {
   if(CheckPointer(g_learningEngine) == POINTER_INVALID || 
      CheckPointer(g_knowledgeBase) == POINTER_INVALID ||
      CheckPointer(g_signalBroadcaster) == POINTER_INVALID)
      return;
   
   // Only check every 20 trades
   if(g_totalTrades % 20 != 0)
      return;
   
   // Get recent performance
   double winRate = g_learningEngine.GetWinRate(20); // Last 20 trades
   
   // Activate if win rate is above threshold
   if(winRate >= 0.8) // 80% win rate
     {
      g_signalActive = true;
      Print("Signal activation: Win rate ", winRate * 100.0, "% is above threshold. Sending signals to Live EA.");
     }
   else
     {
      g_signalActive = false;
      Print("Signal deactivated: Win rate ", winRate * 100.0, "% is below threshold.");
     }
  }

//+------------------------------------------------------------------+
//| Send a trading signal to the Live EA                             |
//+------------------------------------------------------------------+
void SendTradingSignal(ENUM_TRADE_SIGNAL signal, double confidence)
  {
   if(CheckPointer(g_signalBroadcaster) == POINTER_INVALID || !g_signalActive)
      return;
   
   if(g_signalBroadcaster.SendSignal(g_symbol, signal, confidence))
      Print("Sent ", EnumToString(signal), " signal to Live EA with confidence ", confidence);
   else
      Print("Failed to send signal to Live EA");
  }
