//+------------------------------------------------------------------+
//|                                      LiveEA_MLEnhanced.mq5     |
//|                          Copyright 2025, EscapeEA - JAILBREAK   |
//|                                          https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA - JAILBREAK HARDENED"
#property link      "https://www.escapeea.com"
#property version   "3.00"
#property strict

//+------------------------------------------------------------------+
//| ML ENHANCED LIVE EA INCLUDES                                     |
//+------------------------------------------------------------------+
#include "..\Include\Common\Enums.mqh"
#include "..\Include\Common\Structs.mqh"
#include "..\Include\Common\Constants.mqh"
#include "..\Include\Core\EmergencyCircuitBreaker.mqh"
#include "..\Include\Learning\MLLearningEngine.mqh"
#include "..\Include\Learning\KnowledgeBase.mqh"
#include "..\Include\Core\RiskManager.mqh"
#include "..\Include\Core\TradeExecutor.mqh"
#include "..\Include\Communication\SignalReceiver.mqh"
#include "..\Include\Communication\SignalBroadcaster.mqh"

//+------------------------------------------------------------------+
//| ML ENHANCED LIVE EA INPUT PARAMETERS                            |
//+------------------------------------------------------------------+
input group "=== SAFETY LIMITS (PRODUCTION HARDENED) ==="
input double   InpMaxDailyLoss = 1.0;                // Maximum daily loss % (0.5-2.0)
input double   InpMaxDrawdown = 3.0;                 // Maximum drawdown % (1.0-5.0)
input double   InpMaxPositionSize = 0.5;             // Maximum position size lots (0.01-1.0)
input int      InpMaxOpenPositions = 2;              // Maximum open positions (1-3)
input double   InpMarginCallLevel = 300.0;           // Margin call protection % (200-500)
input bool     InpEnableEmergencyStop = true;        // Enable emergency circuit breaker

input group "=== ML SIGNAL PROCESSING (ENHANCED) ==="
input bool     InpEnableMLSignals = true;            // Enable ML signal processing
input double   InpMLSignalConfidence = 0.8;          // Minimum ML signal confidence (0.7-0.95)
input bool     InpMLAdaptiveThreshold = true;        // Adaptive confidence threshold
input double   InpMLSignalWeight = 0.7;              // ML signal weight vs traditional (0.5-1.0)
input bool     InpMLEnsembleValidation = true;       // Require ensemble agreement
input int      InpMLSignalTimeout = 300;             // ML signal timeout (60-600)

input group "=== BIDIRECTIONAL LEARNING ==="
input bool     InpEnableBidirectionalLearning = true; // Enable bidirectional learning
input string   InpPaperEAPrefix = "ESCAPEEA_ML_";    // Paper EA ML signal prefix
input bool     InpAdaptFromPaperEA = true;           // Adapt from Paper EA ML results
input bool     InpSendFeedbackToPaper = true;        // Send feedback to Paper EA
input int      InpFeedbackInterval = 300;            // Feedback interval (60-600)

input group "=== TRADING PARAMETERS (ML VALIDATED) ==="
input string   InpSymbol = "";                       // Trading symbol (empty for chart symbol)
input double   InpRiskPerTrade = 0.5;                // Risk per trade % (0.1-1.0)
input int      InpMagicNumber = 123457;              // Magic number (100000-999999)
input double   InpSlippage = 5.0;                    // Slippage in points (0-20)
input bool     InpEnableTrading = false;             // Enable live trading (DEFAULT: FALSE)

input group "=== KNOWLEDGE BASE (SHARED LEARNING) ==="
input string   InpSharedKBDir = "C:\\Users\\echuk\\Mon Drive\\Shared Knowledge Base"; // Shared KB directory
input bool     InpMLContinuousLearning = true;       // Continuous ML learning
input int      InpMLUpdateInterval = 1800;           // ML update interval (300-3600)

input group "=== MONITORING & LOGGING ==="
input bool     InpEnableDetailedLogging = true;      // Enable detailed logging
input bool     InpLogMLDecisions = true;             // Log ML decisions
input int      InpHeartbeatInterval = 60;            // Heartbeat interval (30-300)
input bool     InpEnableAlerts = true;               // Enable trading alerts

//+------------------------------------------------------------------+
//| ML ENHANCED GLOBAL VARIABLES                                     |
//+------------------------------------------------------------------+
CEmergencyCircuitBreaker *g_circuitBreaker = NULL;   // Emergency safety system
CMLLearningEngine        *g_mlEngine = NULL;         // ML learning engine
CKnowledgeBase           *g_knowledgeBase = NULL;    // Shared knowledge base
CRiskManager             *g_riskManager = NULL;      // Risk management
CTradeExecutor           *g_tradeExecutor = NULL;    // Trade execution
CSignalReceiver          *g_signalReceiver = NULL;   // Signal receiver
CSignalBroadcaster       *g_signalBroadcaster = NULL;// Signal broadcaster

// ML State
string                   g_symbol;                   // Trading symbol
bool                     g_initialized = false;     // Initialization flag
bool                     g_tradingEnabled = false;  // Trading enabled flag
bool                     g_mlInitialized = false;   // ML initialization status
datetime                 g_lastMLUpdate = 0;        // Last ML update time
datetime                 g_lastFeedbackSent = 0;    // Last feedback sent time
datetime                 g_lastHeartbeat = 0;       // Last heartbeat time

// Performance Tracking
int                      g_totalMLSignals = 0;      // Total ML signals received
int                      g_executedMLTrades = 0;    // ML trades executed
int                      g_successfulMLTrades = 0;  // Successful ML trades
double                   g_mlSignalAccuracy = 0.0;  // ML signal accuracy
double                   g_adaptiveThreshold = 0.8; // Adaptive confidence threshold

//+------------------------------------------------------------------+
//| ML ENHANCED INITIALIZATION                                       |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("🧠 INITIALIZING ML ENHANCED LIVE EA v3.00");
   
   // Reset state
   g_initialized = false;
   g_tradingEnabled = false;
   g_mlInitialized = false;
   
   // Validate inputs
   if(!ValidateMLInputs())
   {
      Print("❌ ML INPUT VALIDATION FAILED");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // Set symbol
   g_symbol = (StringLen(InpSymbol) > 0) ? InpSymbol : _Symbol;
   Print("📊 Trading Symbol: ", g_symbol);
   
   // Initialize emergency circuit breaker first
   if(!InitializeEmergencySystem())
   {
      Print("❌ FAILED TO INITIALIZE EMERGENCY SYSTEM");
      return INIT_FAILED;
   }
   
   // Initialize ML components
   if(!InitializeMLComponents())
   {
      Print("❌ FAILED TO INITIALIZE ML COMPONENTS");
      return INIT_FAILED;
   }
   
   // Initialize trading components
   if(!InitializeTradingComponents())
   {
      Print("❌ FAILED TO INITIALIZE TRADING COMPONENTS");
      return INIT_FAILED;
   }
   
   // Initialize ML learning system
   if(!InitializeMLLearning())
   {
      Print("⚠️ ML LEARNING INITIALIZATION FAILED - CONTINUING WITHOUT ML");
   }
   
   // Set timer for monitoring
   if(!EventSetTimer(1))
   {
      Print("⚠️ WARNING: Failed to set monitoring timer");
   }
   
   // Final safety check
   if(InpEnableTrading && !g_circuitBreaker.IsTradingAllowed())
   {
      Print("❌ TRADING DISABLED: Safety systems prevent trading");
      g_tradingEnabled = false;
   }
   else
   {
      g_tradingEnabled = InpEnableTrading;
   }
   
   g_initialized = true;
   
   Print("✅ ML ENHANCED LIVE EA INITIALIZED SUCCESSFULLY");
   Print("🧠 ML Learning: ", g_mlInitialized ? "ENABLED" : "DISABLED");
   Print("🔒 Trading Enabled: ", g_tradingEnabled ? "YES" : "NO");
   Print("🛡️ Emergency Protection: ACTIVE");
   Print("🔄 Bidirectional Learning: ", InpEnableBidirectionalLearning ? "ENABLED" : "DISABLED");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Validate ML input parameters                                    |
//+------------------------------------------------------------------+
bool ValidateMLInputs()
{
   // Validate ML parameters
   if(InpMLSignalConfidence < 0.7 || InpMLSignalConfidence > 0.95)
   {
      Alert("INVALID: ML signal confidence must be between 0.7 and 0.95");
      return false;
   }
   
   if(InpMLSignalWeight < 0.5 || InpMLSignalWeight > 1.0)
   {
      Alert("INVALID: ML signal weight must be between 0.5 and 1.0");
      return false;
   }
   
   // Validate safety parameters
   if(InpMaxDailyLoss < 0.5 || InpMaxDailyLoss > 2.0)
   {
      Alert("INVALID: Max daily loss must be between 0.5% and 2.0%");
      return false;
   }
   
   if(InpMaxDrawdown < 1.0 || InpMaxDrawdown > 5.0)
   {
      Alert("INVALID: Max drawdown must be between 1.0% and 5.0%");
      return false;
   }
   
   if(InpMaxPositionSize < 0.01 || InpMaxPositionSize > 1.0)
   {
      Alert("INVALID: Max position size must be between 0.01 and 1.0 lots");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Initialize emergency safety system                              |
//+------------------------------------------------------------------+
bool InitializeEmergencySystem()
{
   Print("🚨 Initializing Emergency Circuit Breaker...");
   
   g_circuitBreaker = new CEmergencyCircuitBreaker(
      InpMaxDailyLoss,
      InpMaxDrawdown,
      InpMaxPositionSize,
      InpMaxOpenPositions,
      InpMarginCallLevel
   );
   
   if(CheckPointer(g_circuitBreaker) != POINTER_DYNAMIC)
   {
      Print("❌ Failed to create Emergency Circuit Breaker");
      return false;
   }
   
   if(!g_circuitBreaker.IsAccountSafe())
   {
      Print("❌ Account failed initial safety check");
      return false;
   }
   
   Print("✅ Emergency Circuit Breaker initialized");
   return true;
}

//+------------------------------------------------------------------+
//| Initialize ML components                                         |
//+------------------------------------------------------------------+
bool InitializeMLComponents()
{
   Print("🧠 Initializing ML components...");
   
   // Initialize shared knowledge base
   Print("📚 Initializing Shared Knowledge Base...");
   string kbName = "EscapeEA_ML_Live_" + g_symbol;
   g_knowledgeBase = new CKnowledgeBase(kbName, InpSharedKBDir);
   
   if(CheckPointer(g_knowledgeBase) != POINTER_DYNAMIC)
   {
      Print("❌ Failed to create Knowledge Base");
      return false;
   }
   
   // Initialize ML learning engine
   if(InpEnableMLSignals)
   {
      Print("🧠 Initializing ML Learning Engine...");
      g_mlEngine = new CMLLearningEngine(g_symbol, PERIOD_CURRENT);
      
      if(CheckPointer(g_mlEngine) != POINTER_DYNAMIC)
      {
         Print("❌ Failed to create ML Learning Engine");
         return false;
      }
      
      if(!g_mlEngine.Initialize(g_knowledgeBase))
      {
         Print("�� Failed to initialize ML Learning Engine");
         return false;
      }
   }
   
   Print("✅ ML components initialized");
   return true;
}

//+------------------------------------------------------------------+
//| Initialize trading components                                    |
//+------------------------------------------------------------------+
bool InitializeTradingComponents()
{
   Print("⚡ Initializing trading components...");
   
   // Initialize risk manager
   g_riskManager = new CRiskManager(
      g_symbol,
      InpRiskPerTrade,
      InpMaxDailyLoss,
      InpMaxDrawdown,
      InpMaxPositionSize,
      InpMaxOpenPositions
   );
   
   if(CheckPointer(g_riskManager) != POINTER_DYNAMIC)
   {
      Print("❌ Failed to create Risk Manager");
      return false;
   }
   
   // Initialize trade executor
   g_tradeExecutor = new CTradeExecutor(
      InpMagicNumber,
      InpEnableTrading,
      g_symbol,
      InpSlippage
   );
   
   if(CheckPointer(g_tradeExecutor) != POINTER_DYNAMIC)
   {
      Print("❌ Failed to create Trade Executor");
      return false;
   }
   
   // Initialize signal receiver
   string signalPrefix = InpPaperEAPrefix + g_symbol + "_" + IntegerToString(InpMagicNumber) + "_";
   g_signalReceiver = new CSignalReceiver(signalPrefix, InpMLSignalTimeout);
   
   if(CheckPointer(g_signalReceiver) == POINTER_INVALID)
   {
      Print("❌ Failed to create Signal Receiver");
      return false;
   }
   
   // Initialize signal broadcaster for feedback
   if(InpSendFeedbackToPaper)
   {
      g_signalBroadcaster = new CSignalBroadcaster("LIVE_FEEDBACK_" + g_symbol + "_");
      
      if(CheckPointer(g_signalBroadcaster) == POINTER_INVALID)
      {
         Print("⚠️ Failed to create Signal Broadcaster - feedback disabled");
      }
   }
   
   Print("✅ Trading components initialized");
   return true;
}

//+------------------------------------------------------------------+
//| Initialize ML learning system                                   |
//+------------------------------------------------------------------+
bool InitializeMLLearning()
{
   if(!InpEnableMLSignals || CheckPointer(g_mlEngine) != POINTER_DYNAMIC)
   {
      return false;
   }
   
   Print("🧠 Initializing ML learning system...");
   
   // Check if we have enough data for ML
   int totalTrades = g_knowledgeBase.GetTotalTrades();
   if(totalTrades >= 50)
   {
      Print("📊 Found ", totalTrades, " trades - training ML model...");
      
      if(g_mlEngine.TrainModel())
      {
         g_mlInitialized = true;
         g_lastMLUpdate = TimeCurrent();
         
         SMLPerformance performance = g_mlEngine.GetPerformance();
         Print("✅ ML model trained successfully");
         Print("📊 ML Accuracy: ", DoubleToString(performance.validationAccuracy * 100, 2), "%");
         Print("📊 Win Rate: ", DoubleToString(performance.winRate * 100, 2), "%");
         
         // Set adaptive threshold based on model performance
         if(InpMLAdaptiveThreshold)
         {
            g_adaptiveThreshold = MathMax(0.7, performance.validationAccuracy * 0.9);
            Print("🎯 Adaptive threshold set to: ", DoubleToString(g_adaptiveThreshold * 100, 1), "%");
         }
      }
      else
      {
         Print("❌ ML model training failed");
         return false;
      }
   }
   else
   {
      Print("📊 Insufficient data for ML training (", totalTrades, "/50 trades)");
      Print("🔄 Will train ML model after receiving more data from PaperEA");
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| ML ENHANCED TICK PROCESSING                                      |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_initialized)
      return;
      
   // Safety check first
   if(CheckPointer(g_circuitBreaker) == POINTER_INVALID)
      return;
      
   // Update circuit breaker
   g_circuitBreaker.UpdateEquityPeak();
   
   // Check emergency state
   if(g_circuitBreaker.IsEmergencyTriggered())
   {
      Print("🚨 EMERGENCY STATE ACTIVE: ", g_circuitBreaker.GetEmergencyReason());
      return;
   }
   
   // Process ML signals if enabled and trading allowed
   if(g_tradingEnabled && g_circuitBreaker.IsTradingAllowed())
   {
      ProcessMLSignals();
   }
   
   // Update ML model with market data
   if(g_mlInitialized && InpMLContinuousLearning)
   {
      UpdateMLWithMarketData();
   }
}

//+------------------------------------------------------------------+
//| Process ML signals from PaperEA                                 |
//+------------------------------------------------------------------+
void ProcessMLSignals()
{
   if(!InpEnableMLSignals || CheckPointer(g_signalReceiver) != POINTER_DYNAMIC)
      return;
      
   // Check for new ML signals
   STradeSignal signals[];
   int signalCount = g_signalReceiver.CheckForNewSignals(signals);
   
   for(int i = 0; i < signalCount; i++)
   {
      ProcessSingleMLSignal(signals[i]);
   }
}

//+------------------------------------------------------------------+
//| Process single ML signal                                        |
//+------------------------------------------------------------------+
void ProcessSingleMLSignal(const STradeSignal &signal)
{
   g_totalMLSignals++;
   
   Print("🎯 Processing ML signal: ", EnumToString(signal.signal), 
         " (Confidence: ", DoubleToString(signal.confidence * 100, 1), "%)");
   
   // Validate ML signal
   if(!ValidateMLSignal(signal))
   {
      Print("❌ ML signal validation failed");
      return;
   }
   
   // Enhanced ML signal processing
   double enhancedConfidence = signal.confidence;
   
   // If we have our own ML model, validate the signal
   if(g_mlInitialized)
   {
      enhancedConfidence = ValidateSignalWithLocalML(signal);
      
      if(enhancedConfidence < g_adaptiveThreshold)
      {
         Print("🚫 ML signal rejected by local validation (", 
               DoubleToString(enhancedConfidence * 100, 1), "% < ", 
               DoubleToString(g_adaptiveThreshold * 100, 1), "%)");
         return;
      }
   }
   
   // Check circuit breaker
   if(!g_circuitBreaker.IsNewPositionAllowed())
   {
      Print("🚫 ML signal rejected: Circuit breaker prevents new positions");
      return;
   }
   
   // Calculate position size with ML confidence weighting
   double lotSize = CalculateMLPositionSize(signal, enhancedConfidence);
   if(lotSize <= 0)
   {
      Print("❌ Invalid ML position size calculated");
      return;
   }
   
   // Validate position size
   if(!g_circuitBreaker.IsPositionSizeAllowed(lotSize))
   {
      Print("📏 ML signal rejected: Position size exceeds limits");
      return;
   }
   
   // Execute ML-based trade
   ExecuteMLTrade(signal, enhancedConfidence, lotSize);
}

//+------------------------------------------------------------------+
//| Validate ML signal                                              |
//+------------------------------------------------------------------+
bool ValidateMLSignal(const STradeSignal &signal)
{
   // Check signal age
   if((TimeCurrent() - signal.timestamp) > InpMLSignalTimeout)
   {
      Print("⏰ ML signal too old: ", TimeCurrent() - signal.timestamp, " seconds");
      return false;
   }
   
   // Check confidence threshold
   if(signal.confidence < InpMLSignalConfidence)
   {
      Print("📉 ML signal confidence too low: ", DoubleToString(signal.confidence * 100, 1), "%");
      return false;
   }
   
   // Check signal validity
   if(signal.signal == SIGNAL_HOLD)
   {
      Print("⏸️ ML signal is HOLD - no action required");
      return false;
   }
   
   // Validate price levels
   if(signal.entry <= 0 || signal.stopLoss <= 0 || signal.takeProfit <= 0)
   {
      Print("❌ Invalid ML signal price levels");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Validate signal with local ML model                            |
//+------------------------------------------------------------------+
double ValidateSignalWithLocalML(const STradeSignal &signal)
{
   if(!g_mlInitialized)
      return signal.confidence;
      
   // Get current market data
   MqlRates rates[];
   int rateCount = CopyRates(g_symbol, PERIOD_CURRENT, 0, 100);
   if(rateCount < 50)
      return signal.confidence;
      
   // Generate local ML prediction
   double localConfidence = 0.0;
   ENUM_TRADE_SIGNAL localSignal = g_mlEngine.GenerateSignal(rates, rateCount, localConfidence);
   
   // Compare signals
   if(localSignal == signal.signal)
   {
      // Signals agree - combine confidences
      double combinedConfidence = (signal.confidence * InpMLSignalWeight) + 
                                 (localConfidence * (1.0 - InpMLSignalWeight));
      
      Print("✅ ML signals agree - Combined confidence: ", 
            DoubleToString(combinedConfidence * 100, 1), "%");
      
      return combinedConfidence;
   }
   else
   {
      // Signals disagree - reduce confidence
      double reducedConfidence = signal.confidence * 0.5;
      
      Print("⚠️ ML signals disagree - Reduced confidence: ", 
            DoubleToString(reducedConfidence * 100, 1), "%");
      
      return reducedConfidence;
   }
}

//+------------------------------------------------------------------+
//| Calculate ML-weighted position size                             |
//+------------------------------------------------------------------+
double CalculateMLPositionSize(const STradeSignal &signal, double confidence)
{
   if(CheckPointer(g_riskManager) == POINTER_INVALID)
      return 0.0;
      
   // Calculate base position size
   double stopDistance = MathAbs(signal.entry - signal.stopLoss);
   double baseLotSize = g_riskManager.CalculatePositionSize(stopDistance / _Point);
   
   // Apply confidence weighting
   double confidenceMultiplier = confidence; // Scale by confidence
   double adjustedLotSize = baseLotSize * confidenceMultiplier;
   
   // Apply safety limits
   adjustedLotSize = MathMin(adjustedLotSize, InpMaxPositionSize);
   adjustedLotSize = MathMax(adjustedLotSize, 0.01);
   
   Print("📏 ML Position Size: Base=", DoubleToString(baseLotSize, 2), 
         " Confidence=", DoubleToString(confidence * 100, 1), 
         "% Adjusted=", DoubleToString(adjustedLotSize, 2));
   
   return adjustedLotSize;
}

//+------------------------------------------------------------------+
//| Execute ML-based trade                                          |
//+------------------------------------------------------------------+
void ExecuteMLTrade(const STradeSignal &signal, double confidence, double lotSize)
{
   ENUM_ORDER_TYPE orderType = (signal.signal == SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   string comment = StringFormat("ML_%s_%.1f%%", EnumToString(signal.signal), confidence * 100);
   
   if(g_tradeExecutor.OpenPosition(orderType, lotSize, signal.stopLoss, signal.takeProfit, comment))
   {
      g_executedMLTrades++;
      
      // Record trade in circuit breaker
      g_circuitBreaker.RecordTrade(lotSize, 0.0);
      
      // Record trade in knowledge base for bidirectional learning
      STradeRecord trade;
      trade.ticket = g_tradeExecutor.ResultOrder();
      trade.symbol = g_symbol;
      trade.type = (signal.signal == SIGNAL_BUY) ? TRADE_TYPE_BUY : TRADE_TYPE_SELL;
      trade.openTime = TimeCurrent();
      trade.openPrice = signal.entry;
      trade.stopLoss = signal.stopLoss;
      trade.takeProfit = signal.takeProfit;
      trade.lots = lotSize;
      trade.signal = signal.signal;
      trade.confidence = confidence;
      trade.comment = comment;
      trade.isLive = true; // Live trading
      
      g_knowledgeBase.AddTrade(trade);
      
      Print("✅ ML trade executed: ", comment, " Ticket: ", trade.ticket);
      
      if(InpEnableAlerts)
      {
         Alert("ML LiveEA: ", EnumToString(signal.signal), " ", DoubleToString(lotSize, 2), 
               " lots (", DoubleToString(confidence * 100, 1), "% confidence)");
      }
      
      if(InpLogMLDecisions)
      {
         LogMLTrade(trade, confidence);
      }
   }
   else
   {
      Print("❌ ML trade execution failed: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Update ML model with current market data                        |
//+------------------------------------------------------------------+
void UpdateMLWithMarketData()
{
   static datetime lastUpdate = 0;
   datetime currentTime = TimeCurrent();
   
   // Update every 5 minutes
   if((currentTime - lastUpdate) < 300)
      return;
      
   // Check for closed positions to update ML model
   static int lastHistoryCount = 0;
   int currentHistoryCount = g_tradeExecutor.GetTradeHistoryCount();
   
   if(currentHistoryCount > lastHistoryCount)
   {
      // Get recently closed trades
      STradeRecord closedTrades[];
      if(g_tradeExecutor.GetTradeHistory(closedTrades))
      {
         for(int i = lastHistoryCount; i < currentHistoryCount; i++)
         {
            if(i < ArraySize(closedTrades))
            {
               // Update ML model with trade outcome
               if(g_mlInitialized)
               {
                  g_mlEngine.UpdateModel(closedTrades[i]);
               }
               
               // Send feedback to PaperEA
               if(InpSendFeedbackToPaper)
               {
                  SendFeedbackToPaperEA(closedTrades[i]);
               }
               
               // Update accuracy tracking
               UpdateMLAccuracy(closedTrades[i]);
            }
         }
      }
      
      lastHistoryCount = currentHistoryCount;
   }
   
   lastUpdate = currentTime;
}

//+------------------------------------------------------------------+
//| Send feedback to PaperEA                                        |
//+------------------------------------------------------------------+
void SendFeedbackToPaperEA(const STradeRecord &trade)
{
   if(!InpSendFeedbackToPaper || CheckPointer(g_signalBroadcaster) != POINTER_DYNAMIC)
      return;
      
   // Create feedback message
   string feedbackData = StringFormat("LIVE_RESULT|%s|%.2f|%.5f|%.5f|%.3f|%d",
                                     EnumToString(trade.signal),
                                     trade.profit,
                                     trade.openPrice,
                                     trade.closePrice,
                                     trade.confidence,
                                     trade.closeTime);
   
   if(g_signalBroadcaster.BroadcastStatus(feedbackData))
   {
      Print("📤 Feedback sent to PaperEA: ", DoubleToString(trade.profit, 2), " profit");
      g_lastFeedbackSent = TimeCurrent();
   }
   
   // Update signal outcome in knowledge base
   STradeOutcome outcome;
   outcome.signal_id = "ML_" + IntegerToString(trade.ticket);
   outcome.close_time = trade.closeTime;
   outcome.pips = (trade.closePrice - trade.openPrice) / _Point;
   outcome.profit = trade.profit;
   outcome.close_reason = "ML_LIVE_RESULT";
   outcome.max_drawdown = 0.0; // Would be calculated in practice
   
   g_knowledgeBase.UpdateSignalOutcome(outcome);
}

//+------------------------------------------------------------------+
//| Update ML accuracy tracking                                     |
//+------------------------------------------------------------------+
void UpdateMLAccuracy(const STradeRecord &trade)
{
   if(trade.confidence <= 0)
      return;
      
   // Check if prediction was correct
   bool correctPrediction = false;
   
   if(trade.signal == SIGNAL_BUY && trade.profit > 0)
      correctPrediction = true;
   else if(trade.signal == SIGNAL_SELL && trade.profit > 0)
      correctPrediction = true;
   
   if(correctPrediction)
   {
      g_successfulMLTrades++;
   }
   
   // Update accuracy
   g_mlSignalAccuracy = (g_executedMLTrades > 0) ? 
                       (double)g_successfulMLTrades / g_executedMLTrades : 0.0;
   
   // Adjust adaptive threshold based on recent performance
   if(InpMLAdaptiveThreshold && g_executedMLTrades >= 10)
   {
      if(g_mlSignalAccuracy > 0.8)
      {
         g_adaptiveThreshold = MathMax(g_adaptiveThreshold * 0.95, 0.7); // Lower threshold for good performance
      }
      else if(g_mlSignalAccuracy < 0.6)
      {
         g_adaptiveThreshold = MathMin(g_adaptiveThreshold * 1.05, 0.9); // Raise threshold for poor performance
      }
   }
}

//+------------------------------------------------------------------+
//| Timer function for ML updates                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(!g_initialized)
      return;
      
   datetime currentTime = TimeCurrent();
   
   // Continuous safety monitoring
   if(!g_circuitBreaker.IsTradingAllowed())
   {
      if(g_tradingEnabled)
      {
         g_tradingEnabled = false;
         Print("🚫 Trading disabled by safety systems");
         
         if(InpEnableAlerts)
         {
            Alert("ML LiveEA: Trading disabled by safety systems");
         }
      }
   }
   
   // ML model updates
   if(g_mlInitialized && InpMLContinuousLearning && 
      (currentTime - g_lastMLUpdate) >= InpMLUpdateInterval)
   {
      UpdateMLModel();
   }
   
   // Send heartbeat
   if((currentTime - g_lastHeartbeat) >= InpHeartbeatInterval)
   {
      SendMLHeartbeat();
      g_lastHeartbeat = currentTime;
   }
}

//+------------------------------------------------------------------+
//| Update ML model                                                 |
//+------------------------------------------------------------------+
void UpdateMLModel()
{
   Print("🔄 Updating ML model...");
   
   if(g_mlEngine.TrainModel())
   {
      SMLPerformance performance = g_mlEngine.GetPerformance();
      
      Print("✅ ML model updated");
      Print("📊 New Accuracy: ", DoubleToString(performance.validationAccuracy * 100, 2), "%");
      
      // Update adaptive threshold
      if(InpMLAdaptiveThreshold)
      {
         g_adaptiveThreshold = MathMax(0.7, performance.validationAccuracy * 0.9);
      }
      
      g_lastMLUpdate = TimeCurrent();
   }
   else
   {
      Print("❌ ML model update failed");
   }
}

//+------------------------------------------------------------------+
//| Send ML heartbeat                                               |
//+------------------------------------------------------------------+
void SendMLHeartbeat()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double marginLevel = (AccountInfoDouble(ACCOUNT_MARGIN) > 0) ? 
                       (equity / AccountInfoDouble(ACCOUNT_MARGIN)) * 100.0 : 0.0;
   
   string status = "OK";
   if(g_circuitBreaker.IsEmergencyTriggered())
   {
      status = "EMERGENCY: " + g_circuitBreaker.GetEmergencyReason();
   }
   
   string heartbeat = StringFormat("ML_LIVE_HEARTBEAT | Status: %s | Balance: %.2f | Equity: %.2f | ML Accuracy: %.1f%% | ML Trades: %d/%d",
                                 status, balance, equity, 
                                 g_mlSignalAccuracy * 100, 
                                 g_successfulMLTrades, g_executedMLTrades);
   
   Print("💓 ", heartbeat);
   
   // Update chart comment
   string chartStatus = StringFormat("ML LiveEA | Accuracy: %.1f%% | Trades: %d/%d | Emergency: %s",
                                   g_mlSignalAccuracy * 100,
                                   g_successfulMLTrades, g_executedMLTrades,
                                   g_circuitBreaker.IsEmergencyTriggered() ? "ACTIVE" : "OK");
   Comment(chartStatus);
   
   if(InpEnableDetailedLogging)
   {
      LogToFile("ML_Live_Heartbeat.log", heartbeat);
   }
}

//+------------------------------------------------------------------+
//| Log ML trade                                                    |
//+------------------------------------------------------------------+
void LogMLTrade(const STradeRecord &trade, double confidence)
{
   string logEntry = StringFormat("%s - ML_LIVE_TRADE: %s %.2f lots Entry:%.5f SL:%.5f TP:%.5f Confidence:%.3f Ticket:%d",
                                 TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
                                 EnumToString(trade.signal),
                                 trade.lots,
                                 trade.openPrice,
                                 trade.stopLoss,
                                 trade.takeProfit,
                                 confidence,
                                 trade.ticket);
   
   LogToFile("ML_Live_Trades.log", logEntry);
}

//+------------------------------------------------------------------+
//| Safe file logging                                               |
//+------------------------------------------------------------------+
bool LogToFile(string filename, string message)
{
   int handle = FileOpen(filename, FILE_READ|FILE_WRITE|FILE_TXT|FILE_COMMON, ",", CP_UTF8);
   if(handle != INVALID_HANDLE)
   {
      FileSeek(handle, 0, SEEK_END);
      FileWrite(handle, message);
      FileClose(handle);
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| ML ENHANCED DEINITIALIZATION                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("🧠 DEINITIALIZING ML ENHANCED LIVE EA");
   
   // Print final ML statistics
   if(g_totalMLSignals > 0)
   {
      Print("📊 Final ML Statistics:");
      Print("   Total ML Signals: ", g_totalMLSignals);
      Print("   Executed ML Trades: ", g_executedMLTrades);
      Print("   Successful ML Trades: ", g_successfulMLTrades);
      Print("   ML Signal Accuracy: ", DoubleToString(g_mlSignalAccuracy * 100, 2), "%");
   }
   
   // Save ML model state
   if(g_mlInitialized && CheckPointer(g_mlEngine) != POINTER_INVALID)
   {
      g_mlEngine.SaveModel("ML_LiveEA_Final.json");
   }
   
   // Cleanup components
   if(CheckPointer(g_circuitBreaker) != POINTER_INVALID)
   {
      delete g_circuitBreaker;
      g_circuitBreaker = NULL;
   }
   
   if(CheckPointer(g_mlEngine) != POINTER_INVALID)
   {
      delete g_mlEngine;
      g_mlEngine = NULL;
   }
   
   if(CheckPointer(g_knowledgeBase) != POINTER_INVALID)
   {
      delete g_knowledgeBase;
      g_knowledgeBase = NULL;
   }
   
   if(CheckPointer(g_riskManager) != POINTER_INVALID)
   {
      delete g_riskManager;
      g_riskManager = NULL;
   }
   
   if(CheckPointer(g_tradeExecutor) != POINTER_INVALID)
   {
      delete g_tradeExecutor;
      g_tradeExecutor = NULL;
   }
   
   if(CheckPointer(g_signalReceiver) != POINTER_INVALID)
   {
      delete g_signalReceiver;
      g_signalReceiver = NULL;
   }
   
   if(CheckPointer(g_signalBroadcaster) != POINTER_INVALID)
   {
      delete g_signalBroadcaster;
      g_signalBroadcaster = NULL;
   }
   
   Print("✅ ML ENHANCED LIVE EA DEINITIALIZED");
}