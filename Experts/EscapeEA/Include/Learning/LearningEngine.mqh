//+------------------------------------------------------------------+
//| LearningEngine.mqh - Machine learning for EscapeEA               |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include "..\Common\Enums.mqh"
#include "..\Common\Structs.mqh"
#include "..\Common\Constants.mqh"
#include "KnowledgeBase.mqh"

//+------------------------------------------------------------------+
//| Learning Engine Class                                            |
//+------------------------------------------------------------------+
class CLearningEngine
  {
private:
   CKnowledgeBase    *m_knowledgeBase;    // Knowledge base for data persistence
   int               m_windowSize;        // Learning window size
   double            m_minWinRate;        // Minimum win rate to consider a strategy valid
   double            m_learningRate;      // Learning rate for model updates
   bool              m_isTrained;         // Flag indicating if the model is trained
   
   // Model parameters (simplified for this example)
   double            m_modelWeights[];    // Model weights
   
   // Private methods
   double            Predict(const double &features[]);
   double            CalculateWinRate(const STradeRecord &trades[], int lookback);
   
public:
   // Public methods
   bool              TrainModel(const STradeRecord &trades[]);
   // Constructor/destructor
                     CLearningEngine(int windowSize, double minWinRate, double learningRate);
                    ~CLearningEngine();
   
   // Main methods
   bool              Initialize();
   bool              UpdateModel(const STradeRecord &newTrade);
   bool              ShouldEnterTrade(const double &features[], double &confidence);
   
   // Performance metrics
   double            GetWinRate(int lookback = 0);
   double            GetProfitFactor(int lookback = 0);
   double            GetMaxDrawdown(int lookback = 0);
   
   // Getters
   int               WindowSize() const { return m_windowSize; }
   double            MinWinRate() const { return m_minWinRate; }
   bool              IsTrained() const { return m_isTrained; }
   
   // Activity and update status
   bool              IsActive() const { return m_isTrained && (CheckPointer(m_knowledgeBase) == POINTER_DYNAMIC); }
   bool              ShouldUpdate() const 
   { 
      if(!m_isTrained || CheckPointer(m_knowledgeBase) != POINTER_DYNAMIC)
         return false;
         
      // Check if we have enough new data to justify an update
      STradeRecord trades[];
      if(!m_knowledgeBase.GetRecentTrades(1, trades)) // Just check the most recent trade
         return false;
         
      // Update if last update was more than 1 hour ago
      return (TimeCurrent() - m_knowledgeBase.GetLastUpdateTime()) > 3600;
   }
   
   // Setters
   void              SetWindowSize(int size) { m_windowSize = size; }
   void              SetMinWinRate(double rate) { m_minWinRate = rate; }
   void              SetLearningRate(double rate) { m_learningRate = rate; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLearningEngine::CLearningEngine(int windowSize, double minWinRate, double learningRate) :
   m_windowSize(windowSize),
   m_minWinRate(minWinRate),
   m_learningRate(learningRate),
   m_isTrained(false)
  {
   // Initialize knowledge base
   m_knowledgeBase = new CKnowledgeBase("EscapeEA_Model.dat");
   
   // Initialize model weights (simplified example)
   ArrayResize(m_modelWeights, 10);
   ArrayInitialize(m_modelWeights, 0.0);
   
   // Load existing model if available
   if(m_knowledgeBase.ModelExists())
     {
      double weights[];
      if(m_knowledgeBase.LoadModel(weights))
        {
         ArrayCopy(m_modelWeights, weights);
         m_isTrained = true;
         Print("Model loaded successfully");
        }
     }
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLearningEngine::~CLearningEngine()
  {
   // Save model before destruction
   if(m_isTrained)
      m_knowledgeBase.SaveModel(m_modelWeights);
   
   delete m_knowledgeBase;
  }

//+------------------------------------------------------------------+
//| Initialize the learning engine                                   |
//+------------------------------------------------------------------+
bool CLearningEngine::Initialize()
  {
   // Load trade history
   STradeRecord trades[];
   if(!m_knowledgeBase.LoadTradeHistory(trades))
     {
      Print("No trade history found for training");
      return false;
     }
   
   // Train model if we have enough data
   if(ArraySize(trades) >= m_windowSize)
     {
      m_isTrained = TrainModel(trades);
      return m_isTrained;
     }
   
   return false;
  }

//+------------------------------------------------------------------+
//| Train the model on historical trade data                         |
//+------------------------------------------------------------------+
bool CLearningEngine::TrainModel(const STradeRecord &trades[])
  {
   int totalTrades = ArraySize(trades);
   if(totalTrades < m_windowSize)
     {
      Print("Not enough data for training. Need at least ", m_windowSize, " trades");
      return false;
     }
   
   // Calculate win rate on the training set
   double winRate = CalculateWinRate(trades, m_windowSize);
   
   // Simplified training process (in a real implementation, this would use actual ML)
   if(winRate >= m_minWinRate)
     {
      // Update model weights based on recent performance
      for(int i = 0; i < ArraySize(m_modelWeights); i++)
         m_modelWeights[i] += m_learningRate * (winRate - 0.5);
      
      Print("Model trained successfully. Win rate: ", winRate * 100, "%");
      return true;
     }
   
   Print("Training failed. Insufficient win rate: ", winRate * 100, "%");
   return false;
  }

//+------------------------------------------------------------------+
//| Update model with new trade data                                 |
//+------------------------------------------------------------------+
bool CLearningEngine::UpdateModel(const STradeRecord &newTrade)
  {
   // Add new trade to knowledge base
   if(!m_knowledgeBase.AddTrade(newTrade))
     {
      Print("Failed to add trade to knowledge base");
      return false;
     }
   
   // Get recent trades for retraining
   STradeRecord trades[];
   if(!m_knowledgeBase.GetRecentTrades(m_windowSize, trades))
     {
      Print("Failed to get recent trades for model update");
      return false;
     }
   
   // Retrain model with updated data
   return TrainModel(trades);
  }

//+------------------------------------------------------------------+
//| Predict whether to enter a trade based on features              |
//+------------------------------------------------------------------+
bool CLearningEngine::ShouldEnterTrade(const double &features[], double &confidence)
  {
   if(!m_isTrained)
     {
      confidence = 0.0;
      return false;
     }
   
   // Simple prediction using model weights and features
   double prediction = Predict(features);
   confidence = MathAbs(prediction - 0.5) * 2.0; // Convert to 0-1 confidence
   
   return (prediction > 0.5);
  }

//+------------------------------------------------------------------+
//| Make a prediction using the model                               |
//+------------------------------------------------------------------+
double CLearningEngine::Predict(const double &features[])
  {
   if(ArraySize(features) != ArraySize(m_modelWeights))
     {
      Print("Feature size does not match model weights");
      return 0.5; // Neutral prediction
     }
   
   // Simple linear model: weighted sum of features
   double prediction = 0.0;
   for(int i = 0; i < ArraySize(features); i++)
      prediction += features[i] * m_modelWeights[i];
   
   // Sigmoid activation
   return 1.0 / (1.0 + MathExp(-prediction));
  }

//+------------------------------------------------------------------+
//| Calculate win rate over a lookback period                        |
//+------------------------------------------------------------------+
double CLearningEngine::CalculateWinRate(const STradeRecord &trades[], int lookback)
  {
   int total = MathMin(ArraySize(trades), lookback > 0 ? lookback : m_windowSize);
   if(total == 0)
      return 0.0;
   
   int wins = 0;
   for(int i = 0; i < total; i++)
      if(trades[i].profit > 0)
         wins++;
   
   return (double)wins / total;
  }

//+------------------------------------------------------------------+
//| Get win rate for a specific lookback period                      |
//+------------------------------------------------------------------+
double CLearningEngine::GetWinRate(int lookback = 0)
  {
   STradeRecord trades[];
   if(!m_knowledgeBase.GetRecentTrades(lookback > 0 ? lookback : m_windowSize, trades))
      return 0.0;
   
   return CalculateWinRate(trades, lookback);
  }

//+------------------------------------------------------------------+
//| Calculate profit factor over a lookback period                   |
//+------------------------------------------------------------------
double CLearningEngine::GetProfitFactor(int lookback = 0)
  {
   STradeRecord trades[];
   if(!m_knowledgeBase.GetRecentTrades(lookback > 0 ? lookback : m_windowSize, trades))
      return 0.0;
   
   double grossProfit = 0.0;
   double grossLoss = 0.0;
   
   int total = ArraySize(trades);
   for(int i = 0; i < total; i++)
     {
      if(trades[i].profit > 0)
         grossProfit += trades[i].profit;
      else
         grossLoss -= trades[i].profit; // Make loss positive
     }
   
   return (grossLoss > 0) ? (grossProfit / grossLoss) : 0.0;
  }

//+------------------------------------------------------------------+
//| Calculate maximum drawdown over a lookback period               |
//+------------------------------------------------------------------
double CLearningEngine::GetMaxDrawdown(int lookback = 0)
  {
   STradeRecord trades[];
   if(!m_knowledgeBase.GetRecentTrades(lookback > 0 ? lookback : m_windowSize, trades))
      return 0.0;
   
   double peak = 0.0;
   double maxDrawdown = 0.0;
   double currentEquity = 0.0;
   
   for(int i = 0; i < ArraySize(trades); i++)
     {
      currentEquity += trades[i].profit;
      
      if(currentEquity > peak)
         peak = currentEquity;
      
      double drawdown = peak - currentEquity;
      if(drawdown > maxDrawdown)
         maxDrawdown = drawdown;
     }
   
   return (peak > 0) ? (maxDrawdown / peak * 100.0) : 0.0;
  }
