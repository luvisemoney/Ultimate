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
 
 
//+------------------------------------------------------------------+
//| Initialize with external knowledge base - JAILBREAK ADDITION    |
//+------------------------------------------------------------------+
bool CLearningEngine::Initialize(CKnowledgeBase *knowledgeBase)
  {
   if(knowledgeBase == NULL)
     {
      Print("Error: External knowledge base is NULL");
      return false;
     }
   
   // Replace internal knowledge base with external one
   if(m_knowledgeBase != NULL)
      delete m_knowledgeBase;
   
   m_knowledgeBase = knowledgeBase;
   
   // Load existing model if available
   if(m_knowledgeBase.ModelExists())
     {
      double weights[];
      if(m_knowledgeBase.LoadModel(weights))
        {
         ArrayCopy(m_modelWeights, weights);
         m_isTrained = true;
         Print("Model loaded from external knowledge base");
        }
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Recognize pattern from price array - JAILBREAK ADDITION         |
//+------------------------------------------------------------------+
string CLearningEngine::RecognizePattern(const double &prices[], int count)
  {
   if(count < 3 || ArraySize(prices) < count)
     {
      return "";
     }
   
   // Simple pattern recognition
   double trend = prices[count-1] - prices[0];
   double volatility = 0.0;
   
   // Calculate volatility
   for(int i = 1; i < count; i++)
     {
      volatility += MathAbs(prices[i] - prices[i-1]);
     }
   volatility /= (count - 1);
   
   // Classify pattern
   if(trend > volatility * 2)
      return "UPTREND";
   else if(trend < -volatility * 2)
      return "DOWNTREND";
   else if(volatility > (prices[0] * 0.01))
      return "VOLATILE";
   else
      return "SIDEWAYS";
  }

//+------------------------------------------------------------------+
//| Calculate pattern confidence - JAILBREAK ADDITION               |
//+------------------------------------------------------------------+
double CLearningEngine::CalculatePatternConfidence(const string pattern, const string symbol)
  {
   if(pattern == "")
      return 0.0;
   
   // Simple confidence calculation based on pattern type
   if(pattern == "UPTREND" || pattern == "DOWNTREND")
      return 0.8;
   else if(pattern == "VOLATILE")
      return 0.6;
   else if(pattern == "SIDEWAYS")
      return 0.4;
   
   return 0.5; // Default confidence
  }

//+------------------------------------------------------------------+
//| Process performance feedback - JAILBREAK ADDITION               |
//+------------------------------------------------------------------+
bool CLearningEngine::ProcessPerformanceFeedback(const SPerformanceMetrics &metrics)
  {
   if(metrics.totalTrades <= 0)
     {
      Print("Invalid performance metrics");
      return false;
     }
   
   // Adjust learning parameters based on performance
   if(metrics.winRate < m_minWinRate)
     {
      // Increase learning rate for poor performance
      m_learningRate = MathMin(m_learningRate * 1.1, 0.1);
      Print("Increased learning rate due to poor performance: ", m_learningRate);
     }
   else if(metrics.winRate > 0.8)
     {
      // Decrease learning rate for good performance (fine-tuning)
      m_learningRate = MathMax(m_learningRate * 0.9, 0.001);
      Print("Decreased learning rate for fine-tuning: ", m_learningRate);
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Track trade result - JAILBREAK ADDITION                         |
//+------------------------------------------------------------------+
bool CLearningEngine::TrackTradeResult(const STradeResult &result)
  {
   if(result.symbol == "" || result.timestamp == 0)
     {
      Print("Invalid trade result");
      return false;
     }
   
   // Convert trade result to trade record for storage
   STradeRecord trade;
   trade.ticket = (ulong)GetTickCount(); // Generate unique ticket
   trade.symbol = result.symbol;
   trade.signal = result.signal;
   trade.openTime = result.timestamp - (result.duration * 60);
   trade.closeTime = result.timestamp;
   trade.openPrice = result.entryPrice;
   trade.closePrice = result.exitPrice;
   trade.profit = result.profit;
   trade.confidence = result.confidence;
   trade.comment = "Tracked result";
   trade.isLive = false; // Simulated for tracking
   
   // Add to knowledge base
   if(m_knowledgeBase != NULL)
     {
      return m_knowledgeBase.AddTrade(trade);
     }
   
   return false;
  }

//+------------------------------------------------------------------+
//| Analyze performance - JAILBREAK ADDITION                        |
//+------------------------------------------------------------------+
SPerformanceMetrics CLearningEngine::AnalyzePerformance(const string symbol, int timeframeHours)
  {
   SPerformanceMetrics metrics;
   metrics.symbol = symbol;
   metrics.strategy = "CLearningEngine";
   metrics.timeframe = timeframeHours;
   metrics.timestamp = TimeCurrent();
   
   if(m_knowledgeBase == NULL)
     {
      return metrics;
     }
   
   // Get recent trades
   STradeRecord trades[];
   if(!m_knowledgeBase.GetRecentTrades(m_windowSize, trades))
     {
      return metrics;
     }
   
   int totalTrades = ArraySize(trades);
   if(totalTrades == 0)
     {
      return metrics;
     }
   
   // Calculate metrics
   metrics.totalTrades = totalTrades;
   
   int wins = 0;
   double totalProfit = 0.0;
   double totalLoss = 0.0;
   
   for(int i = 0; i < totalTrades; i++)
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
   
   metrics.winRate = (double)wins / totalTrades;
   metrics.avgProfit = totalProfit / totalTrades;
   metrics.profitFactor = (totalLoss > 0) ? (totalProfit / totalLoss) : 0.0;
   metrics.maxDrawdown = GetMaxDrawdown(0);
   
   return metrics;
  }

//+------------------------------------------------------------------+
//| Analyze market condition - JAILBREAK ADDITION                   |
//+------------------------------------------------------------------+
string CLearningEngine::AnalyzeMarketCondition(const string symbol)
  {
   // Get recent price data
   MqlRates rates[];
   if(CopyRates(symbol, PERIOD_H1, 0, 24, rates) < 24)
     {
      return "UNKNOWN";
     }
   
   // Calculate volatility
   double totalRange = 0.0;
   for(int i = 0; i < 24; i++)
     {
      totalRange += rates[i].high - rates[i].low;
     }
   double avgRange = totalRange / 24;
   
   // Calculate trend
   double trend = rates[23].close - rates[0].close;
   double trendPercent = trend / rates[0].close * 100;
   
   // Classify market condition
   if(MathAbs(trendPercent) > 1.0)
     {
      return (trendPercent > 0) ? "STRONG_UPTREND" : "STRONG_DOWNTREND";
     }
   else if(avgRange > (rates[23].close * 0.005))
     {
      return "VOLATILE";
     }
   else
     {
      return "SIDEWAYS";
     }
  }
