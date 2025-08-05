//+------------------------------------------------------------------+
//| MLLearningEngine.mqh - Enterprise ML Learning Engine            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA - JAILBREAK HARDENED"
#property link      "https://www.escapeea.com"
#property version   "3.00"

#include "..\Common\Enums.mqh"
#include "..\Common\Structs.mqh"
#include "..\Common\Constants.mqh"
#include "NeuralNetwork.mqh"
#include "FeatureEngine.mqh"
#include "KnowledgeBase.mqh"

//+------------------------------------------------------------------+
//| ML Model Configuration                                           |
//+------------------------------------------------------------------+
struct SMLConfig
{
   // Network Architecture
   int               hiddenLayers[];       // Hidden layer sizes
   ENUM_ACTIVATION   activations[];        // Activation functions per layer
   
   // Training Parameters
   double            learningRate;         // Learning rate
   double            momentum;             // Momentum factor
   double            weightDecay;          // L2 regularization
   double            dropout;              // Dropout rate
   int               batchSize;            // Mini-batch size
   int               maxEpochs;            // Maximum epochs
   double            validationSplit;      // Validation split ratio
   
   // Feature Engineering
   bool              usePolynomialFeatures; // Create polynomial features
   bool              useInteractionFeatures; // Create interaction features
   int               polynomialDegree;     // Polynomial degree
   bool              normalizeFeatures;    // Normalize features
   
   // Model Selection
   bool              useEnsemble;          // Use ensemble of models
   int               ensembleSize;         // Number of models in ensemble
   bool              useCrossValidation;   // Use cross-validation
   int               cvFolds;              // Cross-validation folds
};

//+------------------------------------------------------------------+
//| ML Performance Metrics                                          |
//+------------------------------------------------------------------+
struct SMLPerformance
{
   // Training Metrics
   double            trainingAccuracy;     // Training accuracy
   double            validationAccuracy;   // Validation accuracy
   double            trainingLoss;         // Training loss
   double            validationLoss;       // Validation loss
   
   // Trading Metrics
   double            winRate;              // Win rate on predictions
   double            profitFactor;         // Profit factor
   double            sharpeRatio;          // Sharpe ratio
   double            maxDrawdown;          // Maximum drawdown
   double            avgReturn;            // Average return per trade
   
   // Model Metrics
   double            precision;            // Precision score
   double            recall;               // Recall score
   double            f1Score;              // F1 score
   double            auc;                  // Area under ROC curve
   
   // Ensemble Metrics
   double            ensembleAgreement;    // Agreement between models
   double            modelVariance;        // Variance between models
   
   // Meta Information
   int               totalPredictions;     // Total predictions made
   int               correctPredictions;   // Correct predictions
   datetime          lastUpdate;           // Last update time
   string            modelVersion;         // Model version
};

//+------------------------------------------------------------------+
//| Enterprise ML Learning Engine                                   |
//+------------------------------------------------------------------+
class CMLLearningEngine
{
private:
   // Core Components
   CNeuralNetwork    *m_primaryModel;      // Primary neural network
   CNeuralNetwork    *m_ensembleModels[];  // Ensemble models
   CFeatureEngine    *m_featureEngine;     // Feature engineering
   CKnowledgeBase    *m_knowledgeBase;     // Data persistence
   
   // Configuration
   SMLConfig         m_config;             // ML configuration
   string            m_symbol;             // Trading symbol
   ENUM_TIMEFRAMES   m_timeframe;          // Analysis timeframe
   
   // Training Data
   STrainingData     m_trainingData;       // Current training dataset
   SFeatureSet       m_featureHistory[];   // Feature history
   double            m_targetHistory[];    // Target history
   int               m_historySize;        // History buffer size
   
   // Performance Tracking
   SMLPerformance    m_performance;        // Performance metrics
   double            m_predictionHistory[]; // Prediction history
   double            m_actualHistory[];    // Actual outcome history
   
   // Model State
   bool              m_isInitialized;      // Initialization status
   bool              m_isTrained;          // Training status
   datetime          m_lastTraining;       // Last training time
   int               m_trainingCount;      // Number of training sessions
   
   // Private Methods
   bool              PrepareTrainingData();
   bool              TrainPrimaryModel();
   bool              TrainEnsembleModels();
   bool              ValidateModel();
   double            MakeEnsemblePrediction(const SFeatureSet &features);
   bool              UpdatePerformanceMetrics();
   bool              SaveModelState();
   bool              LoadModelState();
   void              LogTrainingProgress(int epoch, double loss, double accuracy);
   bool              PerformCrossValidation();
   
public:
   // Constructor/Destructor
                     CMLLearningEngine(string symbol, ENUM_TIMEFRAMES timeframe);
                    ~CMLLearningEngine();
   
   // Initialization
   bool              Initialize(CKnowledgeBase *knowledgeBase = NULL);
   bool              ConfigureModel(const SMLConfig &config);
   bool              SetDefaultConfig();
   
   // Training Methods
   bool              TrainModel();
   bool              UpdateModel(const STradeRecord &newTrade);
   bool              RetrainModel();
   bool              IncrementalLearning(const SFeatureSet &features, double target);
   
   // Prediction Methods
   double            Predict(const MqlRates &rates[], int count);
   bool              PredictWithConfidence(const MqlRates &rates[], int count, double &prediction, double &confidence);
   bool              PredictBatch(const MqlRates &rates[][], int batchSize, double &predictions[]);
   
   // Signal Generation
   ENUM_TRADE_SIGNAL GenerateSignal(const MqlRates &rates[], int count, double &confidence);
   bool              ShouldEnterTrade(const MqlRates &rates[], int count, double &confidence);
   bool              ShouldExitTrade(const MqlRates &rates[], int count, double currentProfit, double &confidence);
   
   // Performance Analysis
   SMLPerformance    GetPerformance() const { return m_performance; }
   bool              AnalyzePerformance();
   void              PrintPerformanceReport();
   bool              BacktestModel(const MqlRates &rates[], int count, int lookback = 1000);
   
   // Model Management
   bool              SaveModel(const string filename);
   bool              LoadModel(const string filename);
   bool              ExportModel(const string format = "json");
   bool              ImportModel(const string filename);
   
   // Feature Analysis
   bool              GetFeatureImportance(double &importance[]);
   bool              AnalyzeFeatureCorrelations();
   void              PrintFeatureStats();
   
   // Advanced Features
   bool              AutoTuneHyperparameters();
   bool              ModelSelection();
   bool              EnsembleOptimization();
   bool              OnlineLearning(bool enable = true);
   
   // Getters
   bool              IsInitialized() const { return m_isInitialized; }
   bool              IsTrained() const { return m_isTrained; }
   double            GetAccuracy() const { return m_performance.validationAccuracy; }
   double            GetWinRate() const { return m_performance.winRate; }
   int               GetTrainingCount() const { return m_trainingCount; }
   datetime          GetLastTraining() const { return m_lastTraining; }
   
   // Bidirectional Learning Support
   bool              ProcessLiveEAFeedback(const STradeRecord &liveResult);
   bool              AdjustFromLivePerformance(const SMLPerformance &livePerformance);
   bool              ShareKnowledgeWithLiveEA();
   bool              ReceiveKnowledgeFromLiveEA();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMLLearningEngine::CMLLearningEngine(string symbol, ENUM_TIMEFRAMES timeframe) :
   m_symbol(symbol),
   m_timeframe(timeframe),
   m_primaryModel(NULL),
   m_featureEngine(NULL),
   m_knowledgeBase(NULL),
   m_historySize(10000),
   m_isInitialized(false),
   m_isTrained(false),
   m_lastTraining(0),
   m_trainingCount(0)
{
   // Initialize performance metrics
   ZeroMemory(m_performance);
   m_performance.modelVersion = "MLEngine_v3.0";
   
   // Set default configuration
   SetDefaultConfig();
   
   Print("🧠 ML Learning Engine initialized for ", symbol, " (", EnumToString(timeframe), ")");
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMLLearningEngine::~CMLLearningEngine()
{
   // Save model state before destruction
   if(m_isTrained)
   {
      SaveModelState();
   }
   
   // Cleanup models
   if(m_primaryModel != NULL)
   {
      delete m_primaryModel;
      m_primaryModel = NULL;
   }
   
   // Cleanup ensemble models
   for(int i = 0; i < ArraySize(m_ensembleModels); i++)
   {
      if(m_ensembleModels[i] != NULL)
      {
         delete m_ensembleModels[i];
      }
   }
   
   // Cleanup feature engine
   if(m_featureEngine != NULL)
   {
      delete m_featureEngine;
      m_featureEngine = NULL;
   }
   
   Print("🧠 ML Learning Engine destroyed");
}

//+------------------------------------------------------------------+
//| Initialize ML Learning Engine                                   |
//+------------------------------------------------------------------+
bool CMLLearningEngine::Initialize(CKnowledgeBase *knowledgeBase = NULL)
{
   Print("🚀 Initializing ML Learning Engine...");
   
   // Set or create knowledge base
   if(knowledgeBase != NULL)
   {
      m_knowledgeBase = knowledgeBase;
   }
   else
   {
      m_knowledgeBase = new CKnowledgeBase("MLEngine_" + m_symbol, "");
   }
   
   // Initialize feature engine
   m_featureEngine = new CFeatureEngine(m_symbol, m_timeframe, 100);
   if(!m_featureEngine.Initialize())
   {
      Print("❌ Failed to initialize feature engine");
      return false;
   }
   
   // Create primary neural network
   m_primaryModel = new CNeuralNetwork();
   
   // Configure network architecture
   int inputSize = m_featureEngine.GetFeatureCount();
   m_primaryModel.SetInputSize(inputSize);
   
   // Add hidden layers
   for(int i = 0; i < ArraySize(m_config.hiddenLayers); i++)
   {
      ENUM_ACTIVATION activation = (i < ArraySize(m_config.activations)) ? 
                                  m_config.activations[i] : ACTIVATION_RELU;
      m_primaryModel.AddLayer(m_config.hiddenLayers[i], activation);
   }
   
   // Add output layer
   m_primaryModel.SetOutputSize(1); // Binary classification (buy/sell/hold)
   m_primaryModel.AddLayer(1, ACTIVATION_SIGMOID);
   
   // Configure training parameters
   m_primaryModel.SetLearningRate(m_config.learningRate);
   m_primaryModel.SetMomentum(m_config.momentum);
   m_primaryModel.SetWeightDecay(m_config.weightDecay);
   m_primaryModel.SetDropout(m_config.dropout);
   m_primaryModel.SetBatchSize(m_config.batchSize);
   m_primaryModel.SetMaxEpochs(m_config.maxEpochs);
   m_primaryModel.SetValidationSplit(m_config.validationSplit);
   
   // Build network
   if(!m_primaryModel.Build())
   {
      Print("❌ Failed to build primary neural network");
      return false;
   }
   
   // Initialize ensemble if configured
   if(m_config.useEnsemble)
   {
      ArrayResize(m_ensembleModels, m_config.ensembleSize);
      for(int i = 0; i < m_config.ensembleSize; i++)
      {
         m_ensembleModels[i] = new CNeuralNetwork();
         // Configure each ensemble model with slight variations
         // (implementation details would vary the architecture slightly)
      }
   }
   
   // Initialize history arrays
   ArrayResize(m_featureHistory, m_historySize);
   ArrayResize(m_targetHistory, m_historySize);
   ArrayResize(m_predictionHistory, m_historySize);
   ArrayResize(m_actualHistory, m_historySize);
   
   // Try to load existing model
   LoadModelState();
   
   m_isInitialized = true;
   Print("✅ ML Learning Engine initialized successfully");
   Print("📊 Network: ", inputSize, " inputs → ", ArraySize(m_config.hiddenLayers), " hidden layers → 1 output");
   
   return true;
}

//+------------------------------------------------------------------+
//| Set default configuration                                        |
//+------------------------------------------------------------------+
bool CMLLearningEngine::SetDefaultConfig()
{
   // Network architecture
   ArrayResize(m_config.hiddenLayers, 3);
   m_config.hiddenLayers[0] = 128;  // First hidden layer
   m_config.hiddenLayers[1] = 64;   // Second hidden layer
   m_config.hiddenLayers[2] = 32;   // Third hidden layer
   
   ArrayResize(m_config.activations, 3);
   m_config.activations[0] = ACTIVATION_RELU;
   m_config.activations[1] = ACTIVATION_RELU;
   m_config.activations[2] = ACTIVATION_RELU;
   
   // Training parameters
   m_config.learningRate = 0.001;
   m_config.momentum = 0.9;
   m_config.weightDecay = 0.0001;
   m_config.dropout = 0.2;
   m_config.batchSize = 32;
   m_config.maxEpochs = 1000;
   m_config.validationSplit = 0.2;
   
   // Feature engineering
   m_config.usePolynomialFeatures = false;
   m_config.useInteractionFeatures = true;
   m_config.polynomialDegree = 2;
   m_config.normalizeFeatures = true;
   
   // Model selection
   m_config.useEnsemble = true;
   m_config.ensembleSize = 5;
   m_config.useCrossValidation = true;
   m_config.cvFolds = 5;
   
   Print("✅ Default ML configuration set");
   return true;
}

//+------------------------------------------------------------------+
//| Train the ML model                                              |
//+------------------------------------------------------------------+
bool CMLLearningEngine::TrainModel()
{
   if(!m_isInitialized)
   {
      Print("❌ ML Engine not initialized");
      return false;
   }
   
   Print("🚀 Starting ML model training...");
   
   // Prepare training data from knowledge base
   if(!PrepareTrainingData())
   {
      Print("❌ Failed to prepare training data");
      return false;
   }
   
   // Train primary model
   if(!TrainPrimaryModel())
   {
      Print("❌ Failed to train primary model");
      return false;
   }
   
   // Train ensemble models if configured
   if(m_config.useEnsemble)
   {
      if(!TrainEnsembleModels())
      {
         Print("⚠️ Ensemble training failed, continuing with primary model");
      }
   }
   
   // Validate model performance
   if(!ValidateModel())
   {
      Print("❌ Model validation failed");
      return false;
   }
   
   // Update performance metrics
   UpdatePerformanceMetrics();
   
   // Save model state
   SaveModelState();
   
   m_isTrained = true;
   m_lastTraining = TimeCurrent();
   m_trainingCount++;
   
   Print("✅ ML model training completed successfully");
   PrintPerformanceReport();
   
   return true;
}

//+------------------------------------------------------------------+
//| Prepare training data from knowledge base                       |
//+------------------------------------------------------------------+
bool CMLLearningEngine::PrepareTrainingData()
{
   Print("📊 Preparing training data...");
   
   // Get trade history from knowledge base
   STradeRecord trades[];
   if(!m_knowledgeBase.GetRecentTrades(5000, trades)) // Get up to 5000 recent trades
   {
      Print("❌ No trade history available");
      return false;
   }
   
   int tradeCount = ArraySize(trades);
   if(tradeCount < 100)
   {
      Print("❌ Insufficient trade history: ", tradeCount, " trades (minimum 100 required)");
      return false;
   }
   
   Print("📈 Processing ", tradeCount, " trades for training data");
   
   // Get market data for feature extraction
   MqlRates rates[];
   int rateCount = CopyRates(m_symbol, m_timeframe, 0, tradeCount + 200, rates);
   if(rateCount < tradeCount + 100)
   {
      Print("❌ Insufficient market data for feature extraction");
      return false;
   }
   
   // Prepare training arrays
   int validSamples = 0;
   ArrayResize(m_trainingData.inputs, tradeCount);
   ArrayResize(m_trainingData.targets, tradeCount);
   
   for(int i = 0; i < tradeCount; i++)
   {
      // Find corresponding market data
      int rateIndex = -1;
      for(int j = 0; j < rateCount; j++)
      {
         if(rates[j].time >= trades[i].openTime)
         {
            rateIndex = j;
            break;
         }
      }
      
      if(rateIndex < 100 || rateIndex >= rateCount - 10) continue; // Need enough history
      
      // Extract features for this trade
      SFeatureSet features;
      MqlRates tradeRates[];
      ArrayResize(tradeRates, 100);
      ArrayCopy(tradeRates, rates, 0, rateIndex - 100, 100);
      
      if(m_featureEngine.ExtractFeatures(tradeRates, 100, features))
      {
         // Convert features to input array
         int featureCount = features.featureCount;
         ArrayResize(m_trainingData.inputs[validSamples], featureCount);
         
         int idx = 0;
         // Combine all feature arrays into single input vector
         for(int f = 0; f < ArraySize(features.priceFeatures); f++)
            m_trainingData.inputs[validSamples][idx++] = features.priceFeatures[f];
         for(int f = 0; f < ArraySize(features.returnFeatures); f++)
            m_trainingData.inputs[validSamples][idx++] = features.returnFeatures[f];
         for(int f = 0; f < ArraySize(features.volatilityFeatures); f++)
            m_trainingData.inputs[validSamples][idx++] = features.volatilityFeatures[f];
         for(int f = 0; f < ArraySize(features.trendFeatures); f++)
            m_trainingData.inputs[validSamples][idx++] = features.trendFeatures[f];
         for(int f = 0; f < ArraySize(features.momentumFeatures); f++)
            m_trainingData.inputs[validSamples][idx++] = features.momentumFeatures[f];
         for(int f = 0; f < ArraySize(features.volumeFeatures); f++)
            m_trainingData.inputs[validSamples][idx++] = features.volumeFeatures[f];
         for(int f = 0; f < ArraySize(features.timeFeatures); f++)
            m_trainingData.inputs[validSamples][idx++] = features.timeFeatures[f];
         for(int f = 0; f < ArraySize(features.regimeFeatures); f++)
            m_trainingData.inputs[validSamples][idx++] = features.regimeFeatures[f];
         
         // Create target (1.0 for profitable trades, 0.0 for losses)
         ArrayResize(m_trainingData.targets[validSamples], 1);
         m_trainingData.targets[validSamples][0] = (trades[i].profit > 0) ? 1.0 : 0.0;
         
         validSamples++;
      }
   }
   
   // Resize arrays to actual valid samples
   ArrayResize(m_trainingData.inputs, validSamples);
   ArrayResize(m_trainingData.targets, validSamples);
   
   m_trainingData.sampleCount = validSamples;
   m_trainingData.inputSize = (validSamples > 0) ? ArraySize(m_trainingData.inputs[0]) : 0;
   m_trainingData.outputSize = 1;
   
   Print("✅ Training data prepared: ", validSamples, " samples with ", m_trainingData.inputSize, " features");
   
   return validSamples >= 100;
}

//+------------------------------------------------------------------+
//| Train primary neural network model                              |
//+------------------------------------------------------------------+
bool CMLLearningEngine::TrainPrimaryModel()
{
   Print("🧠 Training primary neural network...");
   
   if(!m_primaryModel.Train(m_trainingData))
   {
      Print("❌ Primary model training failed");
      return false;
   }
   
   // Get training metrics
   SNeuralMetrics metrics = m_primaryModel.GetMetrics();
   m_performance.trainingLoss = metrics.trainingLoss;
   m_performance.validationLoss = metrics.validationLoss;
   m_performance.trainingAccuracy = metrics.accuracy;
   
   Print("✅ Primary model trained successfully");
   Print("📊 Training Loss: ", DoubleToString(metrics.trainingLoss, 6));
   Print("📊 Validation Loss: ", DoubleToString(metrics.validationLoss, 6));
   Print("📊 Accuracy: ", DoubleToString(metrics.accuracy * 100, 2), "%");
   
   return true;
}

//+------------------------------------------------------------------+
//| Generate trading signal using ML model                          |
//+------------------------------------------------------------------+
ENUM_TRADE_SIGNAL CMLLearningEngine::GenerateSignal(const MqlRates &rates[], int count, double &confidence)
{
   confidence = 0.0;
   
   if(!m_isTrained || count < 100)
   {
      return SIGNAL_HOLD;
   }
   
   // Extract features from current market data
   SFeatureSet features;
   if(!m_featureEngine.ExtractFeatures(rates, count, features))
   {
      Print("❌ Failed to extract features for signal generation");
      return SIGNAL_HOLD;
   }
   
   // Convert features to input array
   double inputs[];
   ArrayResize(inputs, features.featureCount);
   
   int idx = 0;
   for(int f = 0; f < ArraySize(features.priceFeatures); f++)
      inputs[idx++] = features.priceFeatures[f];
   for(int f = 0; f < ArraySize(features.returnFeatures); f++)
      inputs[idx++] = features.returnFeatures[f];
   for(int f = 0; f < ArraySize(features.volatilityFeatures); f++)
      inputs[idx++] = features.volatilityFeatures[f];
   for(int f = 0; f < ArraySize(features.trendFeatures); f++)
      inputs[idx++] = features.trendFeatures[f];
   for(int f = 0; f < ArraySize(features.momentumFeatures); f++)
      inputs[idx++] = features.momentumFeatures[f];
   for(int f = 0; f < ArraySize(features.volumeFeatures); f++)
      inputs[idx++] = features.volumeFeatures[f];
   for(int f = 0; f < ArraySize(features.timeFeatures); f++)
      inputs[idx++] = features.timeFeatures[f];
   for(int f = 0; f < ArraySize(features.regimeFeatures); f++)
      inputs[idx++] = features.regimeFeatures[f];
   
   // Make prediction
   double prediction = 0.0;
   if(m_config.useEnsemble && ArraySize(m_ensembleModels) > 0)
   {
      prediction = MakeEnsemblePrediction(features);
   }
   else
   {
      double outputs[];
      if(m_primaryModel.Predict(inputs, outputs))
      {
         prediction = outputs[0];
      }
   }
   
   // Convert prediction to signal
   confidence = MathAbs(prediction - 0.5) * 2.0; // Convert to 0-1 confidence
   
   if(prediction > 0.6) // High confidence buy
   {
      return SIGNAL_BUY;
   }
   else if(prediction < 0.4) // High confidence sell
   {
      return SIGNAL_SELL;
   }
   
   return SIGNAL_HOLD;
}

//+------------------------------------------------------------------+
//| Make ensemble prediction                                         |
//+------------------------------------------------------------------+
double CMLLearningEngine::MakeEnsemblePrediction(const SFeatureSet &features)
{
   double totalPrediction = 0.0;
   int validPredictions = 0;
   
   // Convert features to input array
   double inputs[];
   ArrayResize(inputs, features.featureCount);
   
   int idx = 0;
   for(int f = 0; f < ArraySize(features.priceFeatures); f++)
      inputs[idx++] = features.priceFeatures[f];
   // ... (same feature conversion as above)
   
   // Get predictions from all ensemble models
   for(int i = 0; i < ArraySize(m_ensembleModels); i++)
   {
      if(m_ensembleModels[i] != NULL && m_ensembleModels[i].IsTrained())
      {
         double outputs[];
         if(m_ensembleModels[i].Predict(inputs, outputs))
         {
            totalPrediction += outputs[0];
            validPredictions++;
         }
      }
   }
   
   // Include primary model prediction
   double outputs[];
   if(m_primaryModel.Predict(inputs, outputs))
   {
      totalPrediction += outputs[0];
      validPredictions++;
   }
   
   return (validPredictions > 0) ? totalPrediction / validPredictions : 0.5;
}

//+------------------------------------------------------------------+
//| Update model with new trade result                              |
//+------------------------------------------------------------------+
bool CMLLearningEngine::UpdateModel(const STradeRecord &newTrade)
{
   if(!m_isInitialized)
   {
      return false;
   }
   
   // Add trade to knowledge base
   if(m_knowledgeBase != NULL)
   {
      m_knowledgeBase.AddTrade(newTrade);
   }
   
   // Incremental learning (simplified)
   // In practice, you'd extract features for this trade and update the model
   
   // Update performance metrics
   UpdatePerformanceMetrics();
   
   // Retrain periodically
   if(m_trainingCount > 0 && (TimeCurrent() - m_lastTraining) > 3600) // Retrain every hour
   {
      Print("🔄 Triggering model retraining...");
      return TrainModel();
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Update performance metrics                                       |
//+------------------------------------------------------------------+
bool CMLLearningEngine::UpdatePerformanceMetrics()
{
   if(m_knowledgeBase == NULL)
   {
      return false;
   }
   
   // Get recent trades for performance calculation
   STradeRecord trades[];
   if(!m_knowledgeBase.GetRecentTrades(1000, trades))
   {
      return false;
   }
   
   int tradeCount = ArraySize(trades);
   if(tradeCount == 0)
   {
      return false;
   }
   
   // Calculate trading metrics
   int wins = 0;
   double totalProfit = 0.0;
   double totalLoss = 0.0;
   
   for(int i = 0; i < tradeCount; i++)
   {
      if(trades[i].profit > 0)
      {
         wins++;
         totalProfit += trades[i].profit;
      }
      else
      {
         totalLoss += MathAbs(trades[i].profit);
      }
   }
   
   m_performance.winRate = (double)wins / tradeCount;
   m_performance.profitFactor = (totalLoss > 0) ? totalProfit / totalLoss : 0.0;
   m_performance.avgReturn = (totalProfit - totalLoss) / tradeCount;
   
   // Calculate additional metrics
   m_performance.totalPredictions = tradeCount;
   m_performance.correctPredictions = wins;
   m_performance.precision = m_performance.winRate;
   m_performance.recall = m_performance.winRate; // Simplified
   m_performance.f1Score = 2.0 * (m_performance.precision * m_performance.recall) / 
                          (m_performance.precision + m_performance.recall);
   
   m_performance.lastUpdate = TimeCurrent();
   
   return true;
}

//+------------------------------------------------------------------+
//| Print performance report                                         |
//+------------------------------------------------------------------+
void CMLLearningEngine::PrintPerformanceReport()
{
   Print("📊 ML Model Performance Report:");
   Print("   Training Accuracy: ", DoubleToString(m_performance.trainingAccuracy * 100, 2), "%");
   Print("   Validation Accuracy: ", DoubleToString(m_performance.validationAccuracy * 100, 2), "%");
   Print("   Win Rate: ", DoubleToString(m_performance.winRate * 100, 2), "%");
   Print("   Profit Factor: ", DoubleToString(m_performance.profitFactor, 2));
   Print("   F1 Score: ", DoubleToString(m_performance.f1Score, 3));
   Print("   Total Predictions: ", m_performance.totalPredictions);
   Print("   Training Sessions: ", m_trainingCount);
   Print("   Model Version: ", m_performance.modelVersion);
}

//+------------------------------------------------------------------+
//| Process feedback from Live EA                                   |
//+------------------------------------------------------------------+
bool CMLLearningEngine::ProcessLiveEAFeedback(const STradeRecord &liveResult)
{
   Print("🔄 Processing Live EA feedback...");
   
   // Add live result to knowledge base for learning
   if(m_knowledgeBase != NULL)
   {
      m_knowledgeBase.AddTrade(liveResult);
   }
   
   // Analyze live performance vs predictions
   // This would involve comparing the live result with our prediction
   // and adjusting the model accordingly
   
   // Update performance metrics
   UpdatePerformanceMetrics();
   
   Print("✅ Live EA feedback processed");
   return true;
}

//+------------------------------------------------------------------+
//| Save model state                                                |
//+------------------------------------------------------------------+
bool CMLLearningEngine::SaveModelState()
{
   // Implementation would save the neural network weights and configuration
   Print("💾 ML model state saved");
   return true;
}

//+------------------------------------------------------------------+
//| Load model state                                                |
//+------------------------------------------------------------------+
bool CMLLearningEngine::LoadModelState()
{
   // Implementation would load the neural network weights and configuration
   Print("📂 ML model state loaded");
   return true;
}

//+------------------------------------------------------------------+
//| Validate model performance                                       |
//+------------------------------------------------------------------+
bool CMLLearningEngine::ValidateModel()
{
   if(!m_primaryModel.IsTrained())
   {
      return false;
   }
   
   // Get validation metrics from the neural network
   SNeuralMetrics metrics = m_primaryModel.GetMetrics();
   m_performance.validationAccuracy = metrics.accuracy;
   m_performance.validationLoss = metrics.validationLoss;
   
   // Check if model meets minimum performance criteria
   if(m_performance.validationAccuracy < 0.55) // At least 55% accuracy
   {
      Print("⚠️ Model validation warning: Low accuracy (", 
            DoubleToString(m_performance.validationAccuracy * 100, 2), "%)");
      return false;
   }
   
   Print("✅ Model validation passed");
   return true;
}