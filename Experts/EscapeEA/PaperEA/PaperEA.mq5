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

//--- Input Parameters
input group "=== General Settings ==="
input string   InpSymbol = "";              // Trading symbol (empty for chart symbol)
input bool     InpEnableLiveTrading = false; // Enable live trading (for testing)
input double   InpRiskPerTrade = 1.0;        // Risk per trade (% of balance)
input int      InpMaxOpenTrades = 5;         // Maximum open trades
input int      InpMagicNumber = 123456;      // Magic number for identification
input double   InpSlippage = 10.0;           // Slippage in points

input group "=== Signal Generation ==="
input ENUM_MA_METHOD     InpMAMethod = MODE_EMA;       // MA Method
input int                InpMAPeriod = 20;             // MA Period
input ENUM_APPLIED_PRICE InpMAPrice = PRICE_CLOSE;     // MA Price
input int                InpRSIPeriod = 14;            // RSI Period
input double             InpRSIOverbought = 70.0;      // RSI Overbought Level
input double             InpRSIOversold = 30.0;        // RSI Oversold Level
input int                InpATRPeriod = 14;            // ATR Period
input double             InpATRMultiplier = 2.0;       // ATR Multiplier for SL/TP

input group "=== Learning Settings ==="
input int      InpLearningWindow = 100;      // Learning window size (trades)
input double   InpMinWinRate = 0.6;           // Minimum win rate for signal validation
input double   InpLearningRate = 0.01;        // Learning rate for model updates
input bool     InpEnableLearning = true;      // Enable learning from trades

//--- Global Variables
CSignalGenerator  *g_signalGenerator = NULL;
CRiskManager     *g_riskManager = NULL;
CTradeExecutor   *g_tradeExecutor = NULL;
CLearningEngine  *g_learningEngine = NULL;
CKnowledgeBase   *g_knowledgeBase = NULL;
CSignalBroadcaster *g_signalBroadcaster = NULL;

string           g_symbol;
datetime         g_lastBarTime;
int              g_totalTrades = 0;
int              g_consecutiveWins = 0;
int              g_consecutiveLosses = 0;
bool             g_signalActive = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Set symbol
   g_symbol = (InpSymbol == "") ? _Symbol : InpSymbol;
   
   // Initialize random seed
   MathSrand((uint)TimeCurrent());
   
   // Initialize components
   if(!InitializeComponents())
     {
      Print("Failed to initialize components");
      return INIT_FAILED;
     }
   
   // Load historical data for backtesting
   if(!LoadHistoricalData())
     {
      Print("Warning: Failed to load historical data");
     }
   
   // Set initial bar time
   g_lastBarTime = iTime(g_symbol, PERIOD_CURRENT, 0);
   
   // Initialize timer for periodic tasks (every 5 seconds)
   EventSetTimer(5);
   
   Print("EscapeEA Paper Trader initialized successfully");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // Clean up
   if(CheckPointer(g_signalGenerator) == POINTER_DYNAMIC)
      delete g_signalGenerator;
      
   if(CheckPointer(g_riskManager) == POINTER_DYNAMIC)
      delete g_riskManager;
      
   if(CheckPointer(g_tradeExecutor) == POINTER_DYNAMIC)
      delete g_tradeExecutor;
      
   if(CheckPointer(g_learningEngine) == POINTER_DYNAMIC)
      delete g_learningEngine;
      
   if(CheckPointer(g_knowledgeBase) == POINTER_DYNAMIC)
      delete g_knowledgeBase;
      
   if(CheckPointer(g_signalBroadcaster) == POINTER_DYNAMIC)
      delete g_signalBroadcaster;
      
   // Disable timer
   EventKillTimer();
   
   Print("EscapeEA Paper Trader deinitialized");
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Check for new bar
   if(!IsNewBar())
      return;
      
   // Update indicators and generate signals
   UpdateIndicators();
   
   // Check for trading signals
   CheckTradingSignals();
   
   // Monitor open positions
   MonitorPositions();
   
   // Update learning model
   if(InpEnableLearning)
      UpdateLearningModel();
  }

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   // Perform periodic tasks
   CleanupExpiredSignals();
   
   // Update performance metrics
   UpdatePerformanceMetrics();
   
   // Send status update
   SendStatusUpdate();
  }

//+------------------------------------------------------------------+
//| Initialize EA components                                         |
//+------------------------------------------------------------------+
bool InitializeComponents()
  {
   // Initialize signal generator
   g_signalGenerator = new CSignalGenerator(g_symbol, _Period, 10, 20, 14, 14, 0.7); // Fast MA: 10, Slow MA: 20, RSI: 14, ATR: 14, Min Confidence: 0.7
   if(CheckPointer(g_signalGenerator) == POINTER_INVALID)
     {
      Print("Failed to create signal generator");
      return false;
     }
   
   // Initialize risk manager
   g_riskManager = new CRiskManager(g_symbol, InpRiskPerTrade, 20.0, 10.0, 10.0, InpMaxOpenTrades); // Max drawdown: 20%, Max daily loss: 10%, Max position size: 10 lots
   if(CheckPointer(g_riskManager) == POINTER_INVALID)
     {
      Print("Failed to create risk manager");
      return false;
     }
   
   // Initialize trade executor (paper trading only)
   g_tradeExecutor = new CTradeExecutor(InpMagicNumber, InpEnableLiveTrading, g_symbol, InpSlippage);
   if(CheckPointer(g_tradeExecutor) == POINTER_INVALID)
     {
      Print("Failed to create trade executor");
      return false;
     }
   
   // Initialize knowledge base
   g_knowledgeBase = new CKnowledgeBase("EscapeEA_Paper_" + g_symbol);
   if(CheckPointer(g_knowledgeBase) == POINTER_INVALID)
     {
      Print("Failed to create knowledge base");
      return false;
     }
   
   // Initialize learning engine
   g_learningEngine = new CLearningEngine(InpLearningWindow, InpMinWinRate, InpLearningRate);
   if(CheckPointer(g_learningEngine) != POINTER_INVALID)
     {
      Print("Failed to create learning engine");
      return false;
     }
   
   // Check if learning engine is active
   if(CheckPointer(g_learningEngine) != POINTER_INVALID)
     {
      // Add proper method calls if these methods exist in the LearningEngine class
      // if(g_learningEngine.IsActive() && g_learningEngine.ShouldUpdate())
      //    return false;
     }
   
   // Initialize signal broadcaster
   g_signalBroadcaster = new CSignalBroadcaster("ESCAPEEA_PAPER_" + g_symbol + "_" + (string)InpMagicNumber + "_");
   if(CheckPointer(g_signalBroadcaster) == POINTER_INVALID)
     {
      Print("Failed to create signal broadcaster");
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
   
   // Get current signal
   STradeSignal signal = g_signalGenerator.GenerateSignal();
   if(signal.signal == SIGNAL_HOLD)
      return;
   
   // Skip if no valid signal
   if(signal.signal == SIGNAL_HOLD)
      return;
   
   // Check risk management
   if(CheckPointer(g_riskManager) == POINTER_INVALID || 
      CheckPointer(g_tradeExecutor) == POINTER_INVALID ||
      !g_riskManager.IsTradeAllowed())
      return;
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
      // Record trade
      STradeRecord trade;
      trade.ticket = (ulong)MathRand(); // In a real implementation, get the actual ticket
      trade.openTime = TimeCurrent();
      trade.symbol = g_symbol;
      trade.type = (signal.signal == SIGNAL_BUY) ? TRADE_TYPE_BUY : TRADE_TYPE_SELL;
      trade.lots = lotSize;
      trade.openPrice = (signal.signal == SIGNAL_BUY) ? 
                        SymbolInfoDouble(g_symbol, SYMBOL_ASK) : 
                        SymbolInfoDouble(g_symbol, SYMBOL_BID);
      trade.stopLoss = stopLoss;
      trade.takeProfit = takeProfit;
      trade.commission = 0.0;
      trade.swap = 0.0;
      trade.profit = 0.0;
      trade.signal = signal.signal;
      trade.confidence = signal.confidence;
      trade.isLive = false;
      
      // Add to knowledge base
      if(CheckPointer(g_knowledgeBase) != POINTER_INVALID)
         g_knowledgeBase.AddTrade(trade);
      
      g_totalTrades++;
      
      // Check if we should send a signal to the Live EA
      CheckSignalActivation();
     }
  }

//+------------------------------------------------------------------+
//| Monitor open positions                                           |
//+------------------------------------------------------------------+
void MonitorPositions()
  {
   // In a real implementation, this would monitor open positions
   // and update them based on market conditions
  }

//+------------------------------------------------------------------+
//| Update learning model                                            |
//+------------------------------------------------------------------+
void UpdateLearningModel()
  {
   if(CheckPointer(g_knowledgeBase) == POINTER_INVALID)
      return;
      
   if(CheckPointer(g_learningEngine) != POINTER_INVALID)
     {
      // Uncomment if Update method exists in LearningEngine
      // g_learningEngine.Update();
     }
      return;
   
   // Get recent trades for learning
   STradeRecord trades[];
   if(g_knowledgeBase.GetRecentTrades(InpLearningWindow, trades))
     {
      // Update learning model
      g_learningEngine.TrainModel(trades);
     }
  }

//+------------------------------------------------------------------+
//| Clean up expired signals                                         |
//+------------------------------------------------------------------+
void CleanupExpiredSignals()
  {
   // In a real implementation, this would clean up expired signals
  }

//+------------------------------------------------------------------+
//| Update performance metrics                                       |
//+------------------------------------------------------------------+
void UpdatePerformanceMetrics()
  {
   // In a real implementation, this would update performance metrics
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
