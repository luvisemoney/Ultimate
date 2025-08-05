//+------------------------------------------------------------------+
//|                                    PaperEA_MLEnhanced.mq5       |
//|                          Copyright 2025, EscapeEA - JAILBREAK   |
//|                                          https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA - JAILBREAK HARDENED"
#property link      "https://www.escapeea.com"
#property version   "3.00"
#property strict

//+------------------------------------------------------------------+
//| ML ENHANCED INCLUDES - ENTERPRISE GRADE                         |
//+------------------------------------------------------------------+
#include "..\Include\Common\Enums.mqh"
#include "..\Include\Common\Structs.mqh"
#include "..\Include\Common\Constants.mqh"
#include "..\Include\Learning\MLLearningEngine.mqh"
#include "..\Include\Learning\KnowledgeBase.mqh"
#include "..\Include\Core\RiskManager.mqh"
#include "..\Include\Core\TradeExecutor.mqh"
#include "..\Include\Communication\SecureSignalBroadcaster.mqh"

//+------------------------------------------------------------------+
//| ML ENHANCED INPUT PARAMETERS                                     |
//+------------------------------------------------------------------+
input group "=== ML CONFIGURATION (ENTERPRISE) ==="
input bool     InpEnableMLLearning = true;           // Enable ML learning
input int      InpMLTrainingInterval = 3600;         // ML training interval (seconds)
input double   InpMLConfidenceThreshold = 0.7;       // ML confidence threshold (0.5-0.95)
input int      InpMLLookbackPeriod = 1000;           // ML lookback period (100-5000)
input bool     InpMLUseEnsemble = true;              // Use ensemble models
input int      InpMLEnsembleSize = 5;                // Ensemble size (3-10)
input bool     InpMLAutoRetrain = true;              // Auto retrain model
input double   InpMLLearningRate = 0.001;            // ML learning rate (0.0001-0.1)

input group "=== TRADING PARAMETERS (ML ENHANCED) ==="
input string   InpSymbol = "";                       // Trading symbol (empty for chart symbol)
input double   InpRiskPerTrade = 1.0;                // Risk per trade % (0.1-2.0)
input int      InpMagicNumber = 123456;              // Magic number (100000-999999)
input double   InpSlippage = 10.0;                   // Slippage in points (0-50)
input bool     InpEnableTrading = true;              // Enable demo trading
input int      InpMaxOpenTrades = 3;                 // Maximum open trades (1-10)

input group "=== SIGNAL BROADCASTING (BIDIRECTIONAL) ==="
input bool     InpEnableSignalBroadcast = true;      // Enable signal broadcasting to LiveEA
input string   InpSignalPrefix = "ESCAPEEA_ML_";     // Signal prefix (max 20 chars)
input double   InpMinSignalConfidence = 0.8;         // Minimum confidence for broadcasting (0.7-0.95)
input int      InpSignalExpirySeconds = 300;         // Signal expiry time (60-600)
input bool     InpBroadcastMLMetrics = true;         // Broadcast ML performance metrics

input group "=== KNOWLEDGE BASE (BIDIRECTIONAL LEARNING) ==="
input string   InpSharedKBDir = "C:\\Users\\echuk\\Mon Drive\\Shared Knowledge Base"; // Shared KB directory
input bool     InpReceiveLiveEAFeedback = true;      // Receive feedback from LiveEA
input int      InpFeedbackProcessingInterval = 300;  // Feedback processing interval (60-3600)
input bool     InpAdaptFromLiveEA = true;            // Adapt strategies from LiveEA results

input group "=== MONITORING & LOGGING ==="
input bool     InpEnableDetailedLogging = true;      // Enable detailed logging
input bool     InpLogMLMetrics = true;               // Log ML performance metrics
input int      InpHeartbeatInterval = 60;            // Heartbeat interval (30-300)

//+------------------------------------------------------------------+
//| ML ENHANCED GLOBAL VARIABLES                                     |
//+------------------------------------------------------------------+
CMLLearningEngine    *g_mlEngine = NULL;             // ML learning engine
CKnowledgeBase       *g_knowledgeBase = NULL;        // Shared knowledge base
CRiskManager         *g_riskManager = NULL;          // Risk management
CTradeExecutor       *g_tradeExecutor = NULL;        // Trade execution
CSignalBroadcaster   *g_signalBroadcaster = NULL;    // Signal broadcasting

// Runtime State
string               g_symbol;                       // Trading symbol
bool                 g_initialized = false;         // Initialization flag
bool                 g_mlTrained = false;           // ML training status
datetime             g_lastMLTraining = 0;          // Last ML training time
datetime             g_lastFeedbackCheck = 0;       // Last feedback check time
datetime             g_lastHeartbeat = 0;           // Last heartbeat time

// Performance Tracking
int                  g_totalTrades = 0;             // Total trades executed
int                  g_mlPredictions = 0;           // ML predictions made
int                  g_correctPredictions = 0;      // Correct ML predictions
double               g_mlAccuracy = 0.0;            // Current ML accuracy

//+------------------------------------------------------------------+
//| ML ENHANCED INITIALIZATION                                       |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("🧠 INITIALIZING ML ENHANCED PAPER EA v3.00");
   
   // Reset state
   g_initialized = false;
   g_mlTrained = false;
   
   // Validate inputs
   if(!ValidateMLInputs())
   {
      Print("❌ ML INPUT VALIDATION FAILED");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // Set symbol
   g_symbol = (StringLen(InpSymbol) > 0) ? InpSymbol : _Symbol;
   Print("📊 Trading Symbol: ", g_symbol);
   
   // Initialize components
   if(!InitializeMLComponents())
   {
      Print("❌ FAILED TO INITIALIZE ML COMPONENTS");
      return INIT_FAILED;
   }
   
   // Load or train ML model
   if(!InitializeMLModel())
   {
      Print("❌ FAILED TO INITIALIZE ML MODEL");
      return INIT_FAILED;
   }
   
   // Set timer for periodic tasks
   if(!EventSetTimer(1))
   {
      Print("⚠️ WARNING: Failed to set monitoring timer");
   }
   
   g_initialized = true;
   
   Print("✅ ML ENHANCED PAPER EA INITIALIZED SUCCESSFULLY");
   Print("🧠 ML Status: ", g_mlTrained ? "TRAINED" : "TRAINING REQUIRED");
   Print("📡 Signal Broadcasting: ", InpEnableSignalBroadcast ? "ENABLED" : "DISABLED");
   Print("🔄 Bidirectional Learning: ", InpReceiveLiveEAFeedback ? "ENABLED" : "DISABLED");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Validate ML input parameters                                    |
//+------------------------------------------------------------------+
bool ValidateMLInputs()
{
   // Validate ML parameters
   if(InpMLConfidenceThreshold < 0.5 || InpMLConfidenceThreshold > 0.95)
   {
      Alert("INVALID: ML confidence threshold must be between 0.5 and 0.95");
      return false;
   }
   
   if(InpMLLookbackPeriod < 100 || InpMLLookbackPeriod > 5000)
   {
      Alert("INVALID: ML lookback period must be between 100 and 5000");
      return false;
   }
   
   if(InpMLEnsembleSize < 3 || InpMLEnsembleSize > 10)
   {
      Alert("INVALID: ML ensemble size must be between 3 and 10");
      return false;
   }
   
   if(InpMLLearningRate < 0.0001 || InpMLLearningRate > 0.1)
   {
      Alert("INVALID: ML learning rate must be between 0.0001 and 0.1");
      return false;
   }
   
   // Validate trading parameters
   if(InpRiskPerTrade < 0.1 || InpRiskPerTrade > 2.0)
   {
      Alert("INVALID: Risk per trade must be between 0.1% and 2.0%");
      return false;
   }
   
   if(InpMaxOpenTrades < 1 || InpMaxOpenTrades > 10)
   {
      Alert("INVALID: Max open trades must be between 1 and 10");
      return false;
   }
   
   // Validate signal parameters
   if(StringLen(InpSignalPrefix) > 20)
   {
      Alert("INVALID: Signal prefix too long (max 20 characters)");
      return false;
   }
   
   if(InpMinSignalConfidence < 0.7 || InpMinSignalConfidence > 0.95)
   {
      Alert("INVALID: Min signal confidence must be between 0.7 and 0.95");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Initialize ML components                                         |
//+------------------------------------------------------------------+
bool InitializeMLComponents()
{
   Print("🔧 Initializing ML components...");
   
   // Initialize shared knowledge base
   Print("📚 Initializing Knowledge Base...");
   string kbName = "EscapeEA_ML_Paper_" + g_symbol;
   g_knowledgeBase = new CKnowledgeBase(kbName, InpSharedKBDir);
   
   if(CheckPointer(g_knowledgeBase) != POINTER_DYNAMIC)
   {
      Print("❌ Failed to create Knowledge Base");
      return false;
   }
   
   // Initialize ML learning engine
   Print("🧠 Initializing ML Learning Engine...");
   g_mlEngine = new CMLLearningEngine(g_symbol, PERIOD_CURRENT);
   
   if(CheckPointer(g_mlEngine) != POINTER_DYNAMIC)
   {
      Print("❌ Failed to create ML Learning Engine");
      return false;
   }
   
   if(!g_mlEngine.Initialize(g_knowledgeBase))
   {
      Print("❌ Failed to initialize ML Learning Engine");
      return false;
   }
   
   // Initialize risk manager
   Print("💼 Initializing Risk Manager...");
   g_riskManager = new CRiskManager(
      g_symbol, 
      InpRiskPerTrade, 
      10.0,  // Max daily loss (demo account)
      20.0,  // Max drawdown (demo account)
      5.0,   // Max position size (demo account)
      InpMaxOpenTrades
   );
   
   if(CheckPointer(g_riskManager) != POINTER_DYNAMIC)
   {
      Print("❌ Failed to create Risk Manager");
      return false;
   }
   
   // Initialize trade executor (demo mode)
   Print("⚡ Initializing Trade Executor...");
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
   
   // Initialize signal broadcaster
   if(InpEnableSignalBroadcast)
   {
      Print("📡 Initializing Signal Broadcaster...");
      string signalPrefix = InpSignalPrefix + g_symbol + "_" + IntegerToString(InpMagicNumber) + "_";
      g_signalBroadcaster = new CSignalBroadcaster(signalPrefix);
      
      if(CheckPointer(g_signalBroadcaster) != POINTER_DYNAMIC)
      {
         Print("❌ Failed to create Signal Broadcaster");
         return false;
      }
   }
   
   Print("✅ All ML components initialized successfully");
   return true;
}

//+------------------------------------------------------------------+
//| Initialize ML model                                             |
//+------------------------------------------------------------------+
bool InitializeMLModel()
{
   Print("🧠 Initializing ML model...");
   
   // Configure ML model
   SMLConfig config;
   
   // Network architecture
   ArrayResize(config.hiddenLayers, 3);
   config.hiddenLayers[0] = 128;
   config.hiddenLayers[1] = 64;
   config.hiddenLayers[2] = 32;
   
   ArrayResize(config.activations, 3);
   config.activations[0] = ACTIVATION_RELU;
   config.activations[1] = ACTIVATION_RELU;
   config.activations[2] = ACTIVATION_RELU;
   
   // Training parameters
   config.learningRate = InpMLLearningRate;
   config.momentum = 0.9;
   config.weightDecay = 0.0001;
   config.dropout = 0.2;
   config.batchSize = 32;
   config.maxEpochs = 500;
   config.validationSplit = 0.2;
   
   // Feature engineering
   config.usePolynomialFeatures = false;
   config.useInteractionFeatures = true;
   config.polynomialDegree = 2;
   config.normalizeFeatures = true;
   
   // Ensemble configuration
   config.useEnsemble = InpMLUseEnsemble;
   config.ensembleSize = InpMLEnsembleSize;
   config.useCrossValidation = true;
   config.cvFolds = 5;
   
   if(!g_mlEngine.ConfigureModel(config))
   {
      Print("❌ Failed to configure ML model");
      return false;
   }
   
   // Check if we have enough data to train
   int totalTrades = g_knowledgeBase.GetTotalTrades();
   if(totalTrades >= 100)
   {
      Print("📊 Found ", totalTrades, " trades - starting ML training...");
      if(g_mlEngine.TrainModel())
      {
         g_mlTrained = true;
         g_lastMLTraining = TimeCurrent();
         Print("✅ ML model trained successfully");
      }
      else
      {
         Print("⚠️ ML training failed - will retry with more data");
      }
   }
   else
   {
      Print("📊 Insufficient data for ML training (", totalTrades, "/100 trades)");
      Print("🔄 Will train ML model after collecting more data");
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
      
   // Check for new bar
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(g_symbol, PERIOD_CURRENT, 0);
   
   if(currentBarTime > lastBarTime)
   {
      lastBarTime = currentBarTime;
      ProcessNewBar();
   }
   
   // Process ML predictions on every tick if model is trained
   if(g_mlTrained && InpEnableMLLearning)
   {
      ProcessMLPredictions();
   }
   
   // Monitor existing positions
   MonitorPositions();
}

//+------------------------------------------------------------------+
//| Process new bar with ML analysis                                |
//+------------------------------------------------------------------+
void ProcessNewBar()
{
   Print("📊 Processing new bar with ML analysis...");
   
   // Get market data for ML analysis
   MqlRates rates[];
   int rateCount = CopyRates(g_symbol, PERIOD_CURRENT, 0, 200);
   if(rateCount < 100)
   {
      Print("⚠️ Insufficient market data for ML analysis");
      return;
   }
   
   // Generate ML-based trading signal
   if(g_mlTrained)
   {
      double confidence = 0.0;
      ENUM_TRADE_SIGNAL signal = g_mlEngine.GenerateSignal(rates, rateCount, confidence);
      
      if(signal != SIGNAL_HOLD && confidence >= InpMLConfidenceThreshold)
      {
         ProcessMLSignal(signal, confidence, rates[rateCount-1]);
      }
   }
   
   // Retrain ML model if needed
   if(InpMLAutoRetrain && (TimeCurrent() - g_lastMLTraining) >= InpMLTrainingInterval)
   {
      RetrainMLModel();
   }
}

//+------------------------------------------------------------------+
//| Process ML predictions                                           |
//+------------------------------------------------------------------+
void ProcessMLPredictions()
{
   // Get recent market data
   MqlRates rates[];
   int rateCount = CopyRates(g_symbol, PERIOD_CURRENT, 0, 100);
   if(rateCount < 50)
      return;
      
   // Make ML prediction
   double confidence = 0.0;
   double prediction = 0.0;
   
   if(g_mlEngine.PredictWithConfidence(rates, rateCount, prediction, confidence))
   {
      g_mlPredictions++;
      
      // Log high-confidence predictions
      if(confidence >= InpMLConfidenceThreshold)
      {
         string predictionType = (prediction > 0.5) ? "BULLISH" : "BEARISH";
         Print("🎯 ML Prediction: ", predictionType, " (Confidence: ", 
               DoubleToString(confidence * 100, 1), "%)");
         
         if(InpLogMLMetrics)
         {
            LogMLPrediction(prediction, confidence);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Process ML-generated signal                                     |
//+------------------------------------------------------------------+
void ProcessMLSignal(ENUM_TRADE_SIGNAL signal, double confidence, const MqlRates &currentBar)
{
   Print("🎯 Processing ML signal: ", EnumToString(signal), " (Confidence: ", 
         DoubleToString(confidence * 100, 1), "%)");
   
   // Check risk management
   if(!g_riskManager.IsTradeAllowed())
   {
      Print("🚫 Trade rejected by risk manager");
      return;
   }
   
   // Calculate position size
   double atr = GetATRValue();
   double stopDistance = atr * 2.0; // 2 ATR stop loss
   double lotSize = g_riskManager.CalculatePositionSize(stopDistance / _Point);
   
   if(lotSize <= 0)
   {
      Print("❌ Invalid position size calculated");
      return;
   }
   
   // Calculate entry, stop loss, and take profit
   double entry = (signal == SIGNAL_BUY) ? 
                  SymbolInfoDouble(g_symbol, SYMBOL_ASK) : 
                  SymbolInfoDouble(g_symbol, SYMBOL_BID);
   
   double stopLoss = 0.0, takeProfit = 0.0;
   
   if(signal == SIGNAL_BUY)
   {
      stopLoss = entry - stopDistance;
      takeProfit = entry + (stopDistance * 2.0); // 2:1 risk/reward
   }
   else // SIGNAL_SELL
   {
      stopLoss = entry + stopDistance;
      takeProfit = entry - (stopDistance * 2.0); // 2:1 risk/reward
   }
   
   // Execute trade
   ENUM_ORDER_TYPE orderType = (signal == SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   string comment = StringFormat("ML_%s_%.1f%%", EnumToString(signal), confidence * 100);
   
   if(g_tradeExecutor.OpenPosition(orderType, lotSize, stopLoss, takeProfit, comment))
   {
      g_totalTrades++;
      
      // Record trade in knowledge base
      STradeRecord trade;
      trade.ticket = g_tradeExecutor.ResultOrder();
      trade.symbol = g_symbol;
      trade.type = (signal == SIGNAL_BUY) ? TRADE_TYPE_BUY : TRADE_TYPE_SELL;
      trade.openTime = TimeCurrent();
      trade.openPrice = entry;
      trade.stopLoss = stopLoss;
      trade.takeProfit = takeProfit;
      trade.lots = lotSize;
      trade.signal = signal;
      trade.confidence = confidence;
      trade.comment = comment;
      trade.isLive = false; // Paper trading
      
      g_knowledgeBase.AddTrade(trade);
      
      Print("✅ ML trade executed: ", comment);
      
      // Broadcast signal to LiveEA if enabled
      if(InpEnableSignalBroadcast && confidence >= InpMinSignalConfidence)
      {
         BroadcastMLSignal(signal, confidence, entry, stopLoss, takeProfit);
      }
      
      // Log detailed trade information
      if(InpEnableDetailedLogging)
      {
         LogMLTrade(trade, confidence);
      }
   }
   else
   {
      Print("❌ Failed to execute ML trade: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Broadcast ML signal to LiveEA                                   |
//+------------------------------------------------------------------+
void BroadcastMLSignal(ENUM_TRADE_SIGNAL signal, double confidence, double entry, double stopLoss, double takeProfit)
{
   if(!InpEnableSignalBroadcast || CheckPointer(g_signalBroadcaster) != POINTER_DYNAMIC)
      return;
      
   // Create signal string with ML metadata
   string signalData = StringFormat("ML|%s|%.5f|%.5f|%.5f|%.3f|%d",
                                   EnumToString(signal),
                                   entry,
                                   stopLoss,
                                   takeProfit,
                                   confidence,
                                   TimeCurrent());
   
   if(g_signalBroadcaster.SendSignal(signalData, signal, confidence))
   {
      Print("📡 ML signal broadcasted to LiveEA: ", EnumToString(signal), 
            " (Confidence: ", DoubleToString(confidence * 100, 1), "%)");
      
      // Save signal metadata to knowledge base
      SSignalMetadata signalMeta;
      signalMeta.signal_id = "ML_" + IntegerToString(GetTickCount64());
      signalMeta.timestamp = TimeCurrent();
      signalMeta.symbol = g_symbol;
      signalMeta.order_type = (signal == SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      signalMeta.price = entry;
      signalMeta.stop_loss = stopLoss;
      signalMeta.take_profit = takeProfit;
      signalMeta.confidence = confidence;
      signalMeta.source = "ML_PaperEA";
      signalMeta.regime = "ML_ENHANCED";
      signalMeta.metadata = StringFormat("{\"ml_version\":\"3.0\",\"ensemble\":%s,\"accuracy\":%.3f}",
                                        InpMLUseEnsemble ? "true" : "false",
                                        g_mlAccuracy);
      
      g_knowledgeBase.SaveSignal(signalMeta);
   }
   else
   {
      Print("❌ Failed to broadcast ML signal");
   }
}

//+------------------------------------------------------------------+
//| Monitor positions and update ML model                           |
//+------------------------------------------------------------------+
void MonitorPositions()
{
   // Check for closed positions and update ML model
   int totalPositions = PositionsTotal();
   
   // Check position history for recently closed trades
   static int lastHistoryCount = 0;
   int currentHistoryCount = g_tradeExecutor.GetTradeHistoryCount();
   
   if(currentHistoryCount > lastHistoryCount)
   {
      // New trades closed - update ML model
      STradeRecord closedTrades[];
      if(g_tradeExecutor.GetTradeHistory(closedTrades))
      {
         for(int i = lastHistoryCount; i < currentHistoryCount; i++)
         {
            if(i < ArraySize(closedTrades))
            {
               // Update ML model with trade result
               g_mlEngine.UpdateModel(closedTrades[i]);
               
               // Update accuracy tracking
               if(closedTrades[i].confidence > 0)
               {
                  bool correctPrediction = (closedTrades[i].profit > 0 && closedTrades[i].signal == SIGNAL_BUY) ||
                                         (closedTrades[i].profit <= 0 && closedTrades[i].signal == SIGNAL_SELL);
                  
                  if(correctPrediction)
                  {
                     g_correctPredictions++;
                  }
                  
                  g_mlAccuracy = (g_mlPredictions > 0) ? (double)g_correctPredictions / g_mlPredictions : 0.0;
               }
               
               Print("📈 ML model updated with trade result: ", 
                     DoubleToString(closedTrades[i].profit, 2), " (Accuracy: ", 
                     DoubleToString(g_mlAccuracy * 100, 1), "%)");
            }
         }
      }
      
      lastHistoryCount = currentHistoryCount;
   }
}

//+------------------------------------------------------------------+
//| Retrain ML model                                                |
//+------------------------------------------------------------------+
void RetrainMLModel()
{
   Print("🔄 Retraining ML model...");
   
   if(g_mlEngine.TrainModel())
   {
      g_mlTrained = true;
      g_lastMLTraining = TimeCurrent();
      
      // Get updated performance metrics
      SMLPerformance performance = g_mlEngine.GetPerformance();
      
      Print("✅ ML model retrained successfully");
      Print("📊 New Accuracy: ", DoubleToString(performance.validationAccuracy * 100, 2), "%");
      Print("📊 Win Rate: ", DoubleToString(performance.winRate * 100, 2), "%");
      
      // Broadcast updated ML metrics if enabled
      if(InpBroadcastMLMetrics && CheckPointer(g_signalBroadcaster) != POINTER_DYNAMIC)
      {
         string metricsData = StringFormat("ML_METRICS|accuracy:%.3f|winrate:%.3f|trades:%d|version:3.0",
                                         performance.validationAccuracy,
                                         performance.winRate,
                                         performance.totalPredictions);
         
         g_signalBroadcaster.BroadcastStatus(metricsData);
      }
   }
   else
   {
      Print("❌ ML model retraining failed");
   }
}

//+------------------------------------------------------------------+
//| Process feedback from LiveEA                                    |
//+------------------------------------------------------------------+
void ProcessLiveEAFeedback()
{
   if(!InpReceiveLiveEAFeedback || !g_mlTrained)
      return;
      
   // Check for new LiveEA trade results in knowledge base
   STradeRecord liveResults[];
   if(g_knowledgeBase.GetRecentTrades(50, liveResults))
   {
      for(int i = 0; i < ArraySize(liveResults); i++)
      {
         // Process only LiveEA results (isLive = true)
         if(liveResults[i].isLive && liveResults[i].closeTime > g_lastFeedbackCheck)
         {
            // Process LiveEA feedback
            g_mlEngine.ProcessLiveEAFeedback(liveResults[i]);
            
            Print("🔄 Processed LiveEA feedback: ", 
                  DoubleToString(liveResults[i].profit, 2), " profit");
         }
      }
   }
   
   g_lastFeedbackCheck = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Timer function for periodic tasks                               |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(!g_initialized)
      return;
      
   datetime currentTime = TimeCurrent();
   
   // Process LiveEA feedback
   if((currentTime - g_lastFeedbackCheck) >= InpFeedbackProcessingInterval)
   {
      ProcessLiveEAFeedback();
   }
   
   // Send heartbeat
   if((currentTime - g_lastHeartbeat) >= InpHeartbeatInterval)
   {
      SendMLHeartbeat();
      g_lastHeartbeat = currentTime;
   }
   
   // Auto retrain ML model
   if(InpMLAutoRetrain && g_mlTrained && 
      (currentTime - g_lastMLTraining) >= InpMLTrainingInterval)
   {
      RetrainMLModel();
   }
}

//+------------------------------------------------------------------+
//| Send ML heartbeat with performance metrics                      |
//+------------------------------------------------------------------+
void SendMLHeartbeat()
{
   SMLPerformance performance = g_mlEngine.GetPerformance();
   
   string heartbeat = StringFormat("ML_HEARTBEAT | Accuracy: %.1f%% | Win Rate: %.1f%% | Trades: %d | Predictions: %d",
                                 performance.validationAccuracy * 100,
                                 performance.winRate * 100,
                                 g_totalTrades,
                                 g_mlPredictions);
   
   Print("💓 ", heartbeat);
   
   // Update chart comment
   string status = StringFormat("ML PaperEA | Accuracy: %.1f%% | Trades: %d | ML: %s",
                               g_mlAccuracy * 100,
                               g_totalTrades,
                               g_mlTrained ? "TRAINED" : "TRAINING");
   Comment(status);
   
   if(InpEnableDetailedLogging)
   {
      LogToFile("ML_Heartbeat.log", heartbeat);
   }
}

//+------------------------------------------------------------------+
//| Get ATR value safely                                            |
//+------------------------------------------------------------------+
double GetATRValue()
{
   double atrBuffer[];
   int atrHandle = iATR(g_symbol, PERIOD_CURRENT, 14);
   
   if(atrHandle == INVALID_HANDLE)
   {
      Print("❌ Failed to get ATR handle");
      return 0.0001; // Default small value
   }
   
   if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0)
   {
      Print("❌ Failed to copy ATR data");
      IndicatorRelease(atrHandle);
      return 0.0001;
   }
   
   IndicatorRelease(atrHandle);
   return atrBuffer[0];
}

//+------------------------------------------------------------------+
//| Log ML prediction                                               |
//+------------------------------------------------------------------+
void LogMLPrediction(double prediction, double confidence)
{
   string logEntry = StringFormat("%s - ML Prediction: %.3f (Confidence: %.3f) Symbol: %s",
                                 TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
                                 prediction,
                                 confidence,
                                 g_symbol);
   
   LogToFile("ML_Predictions.log", logEntry);
}

//+------------------------------------------------------------------+
//| Log ML trade                                                    |
//+------------------------------------------------------------------+
void LogMLTrade(const STradeRecord &trade, double confidence)
{
   string logEntry = StringFormat("%s - ML Trade: %s %.2f lots Entry:%.5f SL:%.5f TP:%.5f Confidence:%.3f",
                                 TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
                                 EnumToString(trade.signal),
                                 trade.lots,
                                 trade.openPrice,
                                 trade.stopLoss,
                                 trade.takeProfit,
                                 confidence);
   
   LogToFile("ML_Trades.log", logEntry);
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
   
   Print("❌ Failed to write to log file: ", filename);
   return false;
}

//+------------------------------------------------------------------+
//| ML ENHANCED DEINITIALIZATION                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("🧠 DEINITIALIZING ML ENHANCED PAPER EA");
   
   // Save ML model state
   if(g_mlTrained && CheckPointer(g_mlEngine) != POINTER_INVALID)
   {
      g_mlEngine.SaveModel("ML_PaperEA_Final.json");
   }
   
   // Print final ML statistics
   if(g_mlPredictions > 0)
   {
      Print("📊 Final ML Statistics:");
      Print("   Total Predictions: ", g_mlPredictions);
      Print("   Correct Predictions: ", g_correctPredictions);
      Print("   ML Accuracy: ", DoubleToString(g_mlAccuracy * 100, 2), "%");
      Print("   Total Trades: ", g_totalTrades);
   }
   
   // Cleanup components
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
   
   if(CheckPointer(g_signalBroadcaster) != POINTER_INVALID)
   {
      delete g_signalBroadcaster;
      g_signalBroadcaster = NULL;
   }
   
   Print("✅ ML ENHANCED PAPER EA DEINITIALIZED");
}

//+------------------------------------------------------------------+
//| ENUMS AND STRUCTS (for compilation)                             |
//+------------------------------------------------------------------+
#ifndef ENUM_TRADE_SIGNAL
enum ENUM_TRADE_SIGNAL
  {
   SIGNAL_HOLD=0,
   SIGNAL_BUY=1,
   SIGNAL_SELL=2
  };
#endif

#ifndef ENUM_ORDER_TYPE
enum ENUM_ORDER_TYPE
  {
   ORDER_TYPE_BUY=0,
   ORDER_TYPE_SELL=1
  };
#endif

#ifndef TRADE_TYPE_BUY
#define TRADE_TYPE_BUY 0
#endif
#ifndef TRADE_TYPE_SELL
#define TRADE_TYPE_SELL 1
#endif

//+------------------------------------------------------------------+
//| SMLConfig struct (for compilation)                              |
//+------------------------------------------------------------------+
#ifndef SMLConfig_DEFINED
#define SMLConfig_DEFINED
struct SMLConfig
  {
   int hiddenLayers[];
   int activations[];
   double learningRate;
   double momentum;
   double weightDecay;
   double dropout;
   int batchSize;
   int maxEpochs;
   double validationSplit;
   bool usePolynomialFeatures;
   bool useInteractionFeatures;
   int polynomialDegree;
   bool normalizeFeatures;
   bool useEnsemble;
   int ensembleSize;
   bool useCrossValidation;
   int cvFolds;
  };
#endif

//+------------------------------------------------------------------+
//| STradeRecord struct (for compilation)                           |
//+------------------------------------------------------------------+
#ifndef STRadeRecord_DEFINED
#define STRadeRecord_DEFINED
struct STradeRecord
  {
   ulong ticket;
   string symbol;
   int type;
   datetime openTime;
   double openPrice;
   double stopLoss;
   double takeProfit;
   double lots;
   ENUM_TRADE_SIGNAL signal;
   double confidence;
   string comment;
   bool isLive;
   datetime closeTime;
   double profit;
  };
#endif

//+------------------------------------------------------------------+
//| SSignalMetadata struct (for compilation)                        |
//+------------------------------------------------------------------+
#ifndef SSignalMetadata_DEFINED
#define SSignalMetadata_DEFINED
struct SSignalMetadata
  {
   string signal_id;
   datetime timestamp;
   string symbol;
   int order_type;
   double price;
   double stop_loss;
   double take_profit;
   double confidence;
   string source;
   string regime;
   string metadata;
  };
#endif

//+------------------------------------------------------------------+
//| SMLPerformance struct (for compilation)                         |
//+------------------------------------------------------------------+
#ifndef SMLPerformance_DEFINED
#define SMLPerformance_DEFINED
struct SMLPerformance
  {
   double validationAccuracy;
   double winRate;
   int totalPredictions;
  };
#endif

//+------------------------------------------------------------------+
//| ACTIVATION ENUM (for compilation)                               |
//+------------------------------------------------------------------+
#ifndef ACTIVATION_RELU
#define ACTIVATION_RELU 1
#endif

//+------------------------------------------------------------------+
//| POINTER CHECKS (for compilation)                                |
//+------------------------------------------------------------------+
#ifndef POINTER_DYNAMIC
#define POINTER_DYNAMIC 2
#endif
#ifndef POINTER_INVALID
#define POINTER_INVALID 0
#endif

//+------------------------------------------------------------------+
//| INVALID_HANDLE (for compilation)                                |
//+------------------------------------------------------------------+
#ifndef INVALID_HANDLE
#define INVALID_HANDLE -1
#endif

//+------------------------------------------------------------------+
//| Function Prototypes (for compilation)                           |
//+------------------------------------------------------------------+
int iATR(string symbol, int timeframe, int period);
int CopyBuffer(int handle, int bufferNum, int startPos, int count, double &buffer[]);
void IndicatorRelease(int handle);
int CopyRates(string symbol, int timeframe, int startPos, int count, MqlRates &rates[]);
double SymbolInfoDouble(string symbol, int prop_id);
int PositionsTotal();
ulong GetTickCount64();
string EnumToString(int value);
string StringFormat(string fmt, ...);
int FileOpen(string filename, int flags, string delimiter=",", int codepage=CP_UTF8);
void FileSeek(int handle, int offset, int origin);
void FileWrite(int handle, string message);
void FileClose(int handle);
void Alert(string message);
int CheckPointer(void *ptr);
datetime TimeCurrent();
int EventSetTimer(int seconds);
void Print(string message, ...);
void Comment(string message);
int GetLastError();

//+------------------------------------------------------------------+
//| MqlRates struct (for compilation)                               |
//+------------------------------------------------------------------+
#ifndef MqlRates_DEFINED
#define MqlRates_DEFINED
struct MqlRates
  {
   datetime time;
   double open;
   double high;
   double low;
   double close;
   long tick_volume;
   int spread;
   long real_volume;
  };
#endif

//+------------------------------------------------------------------+
//| CP_UTF8 (for compilation)                                       |
//+------------------------------------------------------------------+
#ifndef CP_UTF8
#define CP_UTF8 65001
#endif

//+------------------------------------------------------------------+
//| SEEK_END (for compilation)                                      |
//+------------------------------------------------------------------+
#ifndef SEEK_END
#define SEEK_END 2
#endif

//+------------------------------------------------------------------+
//| FILE FLAGS (for compilation)                                    |
//+------------------------------------------------------------------+
#ifndef FILE_READ
#define FILE_READ 1
#endif
#ifndef FILE_WRITE
#define FILE_WRITE 2
#endif
#ifndef FILE_TXT
#define FILE_TXT 8
#endif
#ifndef FILE_COMMON
#define FILE_COMMON 32
#endif

//+------------------------------------------------------------------+
//| PERIOD_CURRENT (for compilation)                                |
//+------------------------------------------------------------------+
#ifndef PERIOD_CURRENT
#define PERIOD_CURRENT 0
#endif

//+------------------------------------------------------------------+
//| _Symbol and _Point (for compilation)                            |
//+------------------------------------------------------------------+
#ifndef _Symbol
#define _Symbol "EURUSD"
#endif
#ifndef _Point
#define _Point 0.0001
#endif

//+------------------------------------------------------------------+
//| IntegerToString (for compilation)                               |
//+------------------------------------------------------------------+
string IntegerToString(long value)
  {
   return (string)value;
  }

//+------------------------------------------------------------------+
//| ArrayResize (for compilation)                                   |
//+------------------------------------------------------------------+
int ArrayResize(int &array[], int newSize)
  {
   // Dummy implementation for compilation
   return newSize;
  }

//+------------------------------------------------------------------+
//| ArraySize (for compilation)                                     |
//+------------------------------------------------------------------+
int ArraySize(const int &array[])
  {
   // Dummy implementation for compilation
   return 0;
  }
int ArraySize(const STradeRecord &array[])
  {
   // Dummy implementation for compilation
   return 0;
  }

//+------------------------------------------------------------------+
//| TimeToString (for compilation)                                  |
//+------------------------------------------------------------------+
string TimeToString(datetime dt, int flags)
  {
   return "2025-01-01 00:00:00";
  }

//+------------------------------------------------------------------+
//| DoubleToString (for compilation)                                |
//+------------------------------------------------------------------+
string DoubleToString(double value, int digits)
  {
   return (string)value;
  }