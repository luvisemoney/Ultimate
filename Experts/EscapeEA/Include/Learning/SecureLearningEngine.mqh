//+------------------------------------------------------------------+
//| SecureLearningEngine.mqh - Memory-safe learning engine           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "2.00"

#include "..\Common\Enums.mqh"
#include "..\Common\Structs.mqh"
#include "..\Common\Constants.mqh"
#include "KnowledgeBase.mqh"

//+------------------------------------------------------------------+
//| RAII Smart Pointer for MQL5 - MEMORY SAFETY                     |
//+------------------------------------------------------------------+
template<typename T>
class CSmartPtr
  {
private:
   T                *m_ptr;
   bool             m_owned;
   
public:
                    CSmartPtr(T *ptr = NULL, bool takeOwnership = true) : 
                       m_ptr(ptr), m_owned(takeOwnership) {}
                   ~CSmartPtr() { Reset(); }
   
   void            Reset(T *ptr = NULL, bool takeOwnership = true)
                     {
                      if(m_owned && m_ptr != NULL)
                        {
                         delete m_ptr;
                        }
                      m_ptr = ptr;
                      m_owned = takeOwnership;
                     }
   
   T*              Get() const { return m_ptr; }
   T*              Release() 
                     { 
                      T *temp = m_ptr; 
                      m_ptr = NULL; 
                      m_owned = false; 
                      return temp; 
                     }
   
   bool            IsValid() const { return m_ptr != NULL; }
   
   // Operators
   T*              operator->() const { return m_ptr; }
   T&              operator*() const { return *m_ptr; }
   bool            operator!() const { return m_ptr == NULL; }
  };

//+------------------------------------------------------------------+
//| Secure Learning Engine Class - JAILBREAK HARDENED              |
//+------------------------------------------------------------------+
class CSecureLearningEngine
  {
private:
   // Memory-safe components
   CSmartPtr<CKnowledgeBase> m_knowledgeBase;    // Smart pointer to knowledge base
   
   // Configuration with bounds checking
   int               m_windowSize;        // Learning window size (BOUNDED)
   double            m_minWinRate;        // Minimum win rate (BOUNDED)
   double            m_learningRate;      // Learning rate (BOUNDED)
   bool              m_isTrained;         // Training state
   int               m_maxModelWeights;   // Maximum model weights (MEMORY SAFETY)
   
   // Model parameters with bounds
   double            m_modelWeights[];    // Model weights (BOUNDED ARRAY)
   int               m_actualWeightCount; // Actual weight count
   
   // Security and performance tracking
   string            m_instanceId;        // Unique instance ID
   datetime          m_lastUpdate;        // Last model update time
   int               m_updateCount;       // Number of updates performed
   int               m_maxUpdatesPerHour; // Rate limiting
   
   // Memory usage tracking
   int               m_memoryUsage;       // Estimated memory usage in bytes
   int               m_maxMemoryUsage;    // Maximum allowed memory usage
   
   // Private methods - HARDENED
   bool              ValidateTradeData(const STradeRecord &trades[]);
   double            Predict(const double &features[]);
   double            CalculateWinRate(const STradeRecord &trades[], int lookback);
   bool              CheckMemoryLimits();
   void              UpdateMemoryUsage();
   bool              IsUpdateAllowed();
   void              LogSecurityEvent(const string event, const string details = "");
   
public:
   // Constructor/destructor - MEMORY SAFE
                     CSecureLearningEngine(int windowSize = DEFAULT_LEARNING_WINDOW, 
                                         double minWinRate = MIN_WIN_RATE, 
                                         double learningRate = DEFAULT_LEARNING_RATE);
                    ~CSecureLearningEngine();
   
   // Main methods - SECURE
   bool              Initialize(const string kbPath = "");
   bool              TrainModel(const STradeRecord &trades[]);
   bool              UpdateModel(const STradeRecord &newTrade);
   bool              ShouldEnterTrade(const double &features[], double &confidence);
   
   // Performance metrics - SAFE
   double            GetWinRate(int lookback = 0);
   double            GetProfitFactor(int lookback = 0);
   double            GetMaxDrawdown(int lookback = 0);
   
   // Security and monitoring
   bool              IsHealthy() const;
   int               GetMemoryUsage() const { return m_memoryUsage; }
   int               GetUpdateCount() const { return m_updateCount; }
   string            GetInstanceId() const { return m_instanceId; }
   
   // State management
   bool              IsActive() const;
   bool              ShouldUpdate() const;
   bool              SaveState();
   bool              LoadState();
   
   // Getters - SAFE
   int               WindowSize() const { return m_windowSize; }
   double            MinWinRate() const { return m_minWinRate; }
   bool              IsTrained() const { return m_isTrained; }
   
   // Setters - WITH VALIDATION
   bool              SetWindowSize(int size);
   bool              SetMinWinRate(double rate);
   bool              SetLearningRate(double rate);
  };

//+------------------------------------------------------------------+
//| Constructor - SECURE INITIALIZATION                              |
//+------------------------------------------------------------------+
CSecureLearningEngine::CSecureLearningEngine(int windowSize = DEFAULT_LEARNING_WINDOW, 
                                           double minWinRate = MIN_WIN_RATE, 
                                           double learningRate = DEFAULT_LEARNING_RATE) :
   m_windowSize(MathMax(10, MathMin(windowSize, 1000))), // BOUNDS CHECK: 10-1000
   m_minWinRate(MathMax(0.1, MathMin(minWinRate, 1.0))), // BOUNDS CHECK: 0.1-1.0
   m_learningRate(MathMax(0.0001, MathMin(learningRate, 1.0))), // BOUNDS CHECK: 0.0001-1.0
   m_isTrained(false),
   m_maxModelWeights(100), // MEMORY SAFETY: Limit model complexity
   m_actualWeightCount(0),
   m_lastUpdate(0),
   m_updateCount(0),
   m_maxUpdatesPerHour(60), // RATE LIMITING: Max 60 updates per hour
   m_memoryUsage(0),
   m_maxMemoryUsage(10485760) // MEMORY SAFETY: 10MB limit
  {
   // Generate unique instance ID for security tracking
   m_instanceId = StringFormat("SecureLearning_%d_%d_%d", 
                              GetTickCount(), MathRand(), (int)TimeCurrent());
   
   // Initialize model weights with bounds checking
   ArrayResize(m_modelWeights, m_maxModelWeights);
   ArrayInitialize(m_modelWeights, 0.0);
   m_actualWeightCount = 10; // Start with 10 weights
   
   // Initialize knowledge base with smart pointer (MEMORY SAFETY)
   string kbName = StringFormat("SecureModel_%s.dat", m_instanceId);
   m_knowledgeBase.Reset(new CKnowledgeBase(kbName), true);
   
   UpdateMemoryUsage();
   
   LogSecurityEvent("INIT", StringFormat("Window=%d, MinWinRate=%.2f, LearningRate=%.4f", 
                                        m_windowSize, m_minWinRate, m_learningRate));
   
   Print("SecureLearningEngine initialized: ", m_instanceId);
  }

//+------------------------------------------------------------------+
//| Destructor - SECURE CLEANUP                                     |
//+------------------------------------------------------------------+
CSecureLearningEngine::~CSecureLearningEngine()
  {
   // Save state before destruction
   if(m_isTrained)
     {
      SaveState();
     }
   
   // Smart pointer automatically handles cleanup
   LogSecurityEvent("DESTROY", StringFormat("Updates=%d, MemoryUsed=%d", 
                                           m_updateCount, m_memoryUsage));
   
   Print("SecureLearningEngine destroyed: ", m_instanceId);
  }

//+------------------------------------------------------------------+
//| Initialize learning engine securely                             |
//+------------------------------------------------------------------+
bool CSecureLearningEngine::Initialize(const string kbPath = "")
  {
   if(!m_knowledgeBase.IsValid())
     {
      LogSecurityEvent("ERROR", "Knowledge base not available");
      return false;
     }
   
   // Load existing state if available
   if(LoadState())
     {
      LogSecurityEvent("INIT", "Loaded existing model state");
      return true;
     }
   
   // Load trade history for initial training
   STradeRecord trades[];
   if(!m_knowledgeBase->LoadTradeHistory(trades))
     {
      LogSecurityEvent("WARNING", "No trade history found for training");
      return false;
     }
   
   // Validate trade data
   if(!ValidateTradeData(trades))
     {
      LogSecurityEvent("ERROR", "Invalid trade data detected");
      return false;
     }
   
   // Train model if we have enough data
   if(ArraySize(trades) >= m_windowSize)
     {
      bool trained = TrainModel(trades);
      LogSecurityEvent("INIT", StringFormat("Initial training: %s", trained ? "SUCCESS" : "FAILED"));
      return trained;
     }
   
   LogSecurityEvent("WARNING", StringFormat("Insufficient data for training: %d < %d", 
                                           ArraySize(trades), m_windowSize));
   return false;
  }

//+------------------------------------------------------------------+
//| Validate trade data for security                                |
//+------------------------------------------------------------------+
bool CSecureLearningEngine::ValidateTradeData(const STradeRecord &trades[])
  {
   int tradeCount = ArraySize(trades);
   
   // Bounds check
   if(tradeCount == 0 || tradeCount > 100000) // SECURITY: Prevent memory exhaustion
     {
      LogSecurityEvent("SECURITY", StringFormat("Invalid trade count: %d", tradeCount));
      return false;
     }
   
   // Validate individual trades
   int invalidCount = 0;
   for(int i = 0; i < tradeCount && i < 1000; i++) // BOUNDS: Check max 1000 trades
     {
      const STradeRecord &trade = trades[i];
      
      // Basic validation
      if(trade.ticket == 0 || 
         trade.openTime == 0 || 
         trade.lots <= 0 || 
         trade.lots > 1000 || // SECURITY: Prevent unrealistic lot sizes
         StringLen(trade.symbol) == 0 ||
         StringLen(trade.symbol) > 20) // SECURITY: Prevent buffer overflow
        {
         invalidCount++;
        }
      
      // Price validation
      if(trade.openPrice <= 0 || 
         trade.openPrice > 1000000 || // SECURITY: Prevent unrealistic prices
         (trade.closePrice > 0 && trade.closePrice > 1000000))
        {
         invalidCount++;
        }
     }
   
   // Allow up to 5% invalid trades
   double invalidRate = (double)invalidCount / MathMin(tradeCount, 1000);
   if(invalidRate > 0.05)
     {
      LogSecurityEvent("SECURITY", StringFormat("Too many invalid trades: %.2f%%", invalidRate * 100));
      return false;
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Train model with security checks                                |
//+------------------------------------------------------------------+
bool CSecureLearningEngine::TrainModel(const STradeRecord &trades[])
  {
   if(!CheckMemoryLimits())
     {
      LogSecurityEvent("ERROR", "Memory limit exceeded");
      return false;
     }
   
   int totalTrades = ArraySize(trades);
   if(totalTrades < m_windowSize)
     {
      LogSecurityEvent("ERROR", StringFormat("Insufficient data: %d < %d", totalTrades, m_windowSize));
      return false;
     }
   
   // Validate trade data first
   if(!ValidateTradeData(trades))
     {
      return false;
     }
   
   // Calculate win rate on training set
   double winRate = CalculateWinRate(trades, m_windowSize);
   
   // Security check: Unrealistic win rates might indicate data manipulation
   if(winRate > 0.95 || winRate < 0.05)
     {
      LogSecurityEvent("SECURITY", StringFormat("Suspicious win rate: %.2f", winRate));
      // Continue but log the event
     }
   
   // Simplified training process with bounds checking
   if(winRate >= m_minWinRate)
     {
      // Update model weights with bounds checking
      for(int i = 0; i < m_actualWeightCount && i < m_maxModelWeights; i++)
        {
         double adjustment = m_learningRate * (winRate - 0.5);
         
         // BOUNDS CHECK: Prevent weight explosion
         adjustment = MathMax(-0.1, MathMin(adjustment, 0.1));
         
         m_modelWeights[i] += adjustment;
         
         // BOUNDS CHECK: Keep weights reasonable
         m_modelWeights[i] = MathMax(-10.0, MathMin(m_modelWeights[i], 10.0));
        }
      
      m_isTrained = true;
      m_lastUpdate = TimeCurrent();
      m_updateCount++;
      
      UpdateMemoryUsage();
      
      LogSecurityEvent("TRAIN", StringFormat("Success: WinRate=%.2f, Weights=%d", 
                                            winRate, m_actualWeightCount));
      
      Print("Model trained successfully. Win rate: ", winRate * 100, "%");
      return true;
     }
   
   LogSecurityEvent("TRAIN", StringFormat("Failed: WinRate=%.2f < %.2f", winRate, m_minWinRate));
   Print("Training failed. Insufficient win rate: ", winRate * 100, "%");
   return false;
  }

//+------------------------------------------------------------------+
//| Update model with new trade - SECURE                            |
//+------------------------------------------------------------------+
bool CSecureLearningEngine::UpdateModel(const STradeRecord &newTrade)
  {
   if(!IsUpdateAllowed())
     {
      LogSecurityEvent("RATE_LIMIT", "Update rate limit exceeded");
      return false;
     }
   
   if(!CheckMemoryLimits())
     {
      LogSecurityEvent("ERROR", "Memory limit exceeded during update");
      return false;
     }
   
   // Validate single trade
   STradeRecord trades[1];
   trades[0] = newTrade;
   if(!ValidateTradeData(trades))
     {
      LogSecurityEvent("ERROR", "Invalid trade data in update");
      return false;
     }
   
   // Add new trade to knowledge base
   if(!m_knowledgeBase.IsValid() || !m_knowledgeBase->AddTrade(newTrade))
     {
      LogSecurityEvent("ERROR", "Failed to add trade to knowledge base");
      return false;
     }
   
   // Get recent trades for retraining
   STradeRecord recentTrades[];
   if(!m_knowledgeBase->GetRecentTrades(m_windowSize, recentTrades))
     {
      LogSecurityEvent("ERROR", "Failed to get recent trades for update");
      return false;
     }
   
   // Retrain model with updated data
   bool result = TrainModel(recentTrades);
   
   if(result)
     {
      LogSecurityEvent("UPDATE", StringFormat("Success: Ticket=%I64u, Profit=%.2f", 
                                             newTrade.ticket, newTrade.profit));
     }
   
   return result;
  }

//+------------------------------------------------------------------+
//| Check if trade entry is recommended - SECURE                    |
//+------------------------------------------------------------------+
bool CSecureLearningEngine::ShouldEnterTrade(const double &features[], double &confidence)
  {
   confidence = 0.0;
   
   if(!m_isTrained || !m_knowledgeBase.IsValid())
     {
      LogSecurityEvent("WARNING", "Model not trained or KB unavailable");
      return false;
     }
   
   // Validate features array
   int featureCount = ArraySize(features);
   if(featureCount == 0 || featureCount > 100) // BOUNDS CHECK
     {
      LogSecurityEvent("SECURITY", StringFormat("Invalid feature count: %d", featureCount));
      return false;
     }
   
   // Validate feature values
   for(int i = 0; i < featureCount; i++)
     {
      if(!MathIsValidNumber(features[i]) || 
         MathAbs(features[i]) > 1000000) // BOUNDS CHECK: Prevent extreme values
        {
         LogSecurityEvent("SECURITY", StringFormat("Invalid feature[%d]: %.2f", i, features[i]));
         return false;
        }
     }
   
   // Make prediction
   double prediction = Predict(features);
   
   // Validate prediction
   if(!MathIsValidNumber(prediction) || prediction < 0.0 || prediction > 1.0)
     {
      LogSecurityEvent("ERROR", StringFormat("Invalid prediction: %.4f", prediction));
      return false;
     }
   
   confidence = MathAbs(prediction - 0.5) * 2.0; // Convert to 0-1 confidence
   
   // BOUNDS CHECK: Ensure confidence is valid
   confidence = MathMax(0.0, MathMin(confidence, 1.0));
   
   bool shouldEnter = (prediction > 0.5);
   
   LogSecurityEvent("PREDICT", StringFormat("Prediction=%.4f, Confidence=%.4f, Enter=%s", 
                                           prediction, confidence, shouldEnter ? "YES" : "NO"));
   
   return shouldEnter;
  }

//+------------------------------------------------------------------+
//| Make prediction using model - SECURE                            |
//+------------------------------------------------------------------+
double CSecureLearningEngine::Predict(const double &features[])
  {
   int featureCount = ArraySize(features);
   int weightCount = MathMin(featureCount, m_actualWeightCount);
   
   if(weightCount == 0)
     {
      return 0.5; // Neutral prediction
     }
   
   // Simple linear model: weighted sum of features
   double prediction = 0.0;
   for(int i = 0; i < weightCount; i++)
     {
      prediction += features[i] * m_modelWeights[i];
     }
   
   // Sigmoid activation with bounds checking
   prediction = MathMax(-50.0, MathMin(prediction, 50.0)); // Prevent overflow
   double result = 1.0 / (1.0 + MathExp(-prediction));
   
   // Final bounds check
   return MathMax(0.0, MathMin(result, 1.0));
  }

//+------------------------------------------------------------------+
//| Calculate win rate with bounds checking                         |
//+------------------------------------------------------------------+
double CSecureLearningEngine::CalculateWinRate(const STradeRecord &trades[], int lookback)
  {
   int total = MathMin(ArraySize(trades), lookback > 0 ? lookback : m_windowSize);
   if(total == 0)
      return 0.0;
   
   int wins = 0;
   for(int i = 0; i < total; i++)
     {
      if(trades[i].profit > 0)
         wins++;
     }
   
   return (double)wins / total;
  }

//+------------------------------------------------------------------+
//| Check memory limits                                             |
//+------------------------------------------------------------------+
bool CSecureLearningEngine::CheckMemoryLimits()
  {
   UpdateMemoryUsage();
   
   if(m_memoryUsage > m_maxMemoryUsage)
     {
      LogSecurityEvent("MEMORY", StringFormat("Usage=%d > Limit=%d", m_memoryUsage, m_maxMemoryUsage));
      return false;
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Update memory usage estimation                                  |
//+------------------------------------------------------------------+
void CSecureLearningEngine::UpdateMemoryUsage()
  {
   // Estimate memory usage
   m_memoryUsage = sizeof(CSecureLearningEngine) + 
                   (ArraySize(m_modelWeights) * sizeof(double)) +
                   (StringLen(m_instanceId) * sizeof(ushort)) +
                   1024; // Buffer for other allocations
  }

//+------------------------------------------------------------------+
//| Check if update is allowed (rate limiting)                      |
//+------------------------------------------------------------------+
bool CSecureLearningEngine::IsUpdateAllowed()
  {
   datetime now = TimeCurrent();
   
   // Check if we've exceeded hourly update limit
   if(m_lastUpdate > 0 && (now - m_lastUpdate) < 3600) // Within last hour
     {
      // Count updates in last hour (simplified)
      if(m_updateCount > m_maxUpdatesPerHour)
        {
         return false;
        }
     }
   else
     {
      // Reset counter for new hour
      m_updateCount = 0;
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Log security events                                             |
//+------------------------------------------------------------------+
void CSecureLearningEngine::LogSecurityEvent(const string event, const string details = "")
  {
   string logMessage = StringFormat("[%s] %s: %s - %s", 
                                   TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
                                   m_instanceId, event, details);
   
   Print("SECURE_LEARNING: ", logMessage);
   
   // Could also write to security log file here
  }

//+------------------------------------------------------------------+
//| Get win rate with security checks                               |
//+------------------------------------------------------------------+
double CSecureLearningEngine::GetWinRate(int lookback = 0)
  {
   if(!m_knowledgeBase.IsValid())
      return 0.0;
   
   STradeRecord trades[];
   if(!m_knowledgeBase->GetRecentTrades(lookback > 0 ? lookback : m_windowSize, trades))
      return 0.0;
   
   return CalculateWinRate(trades, lookback);
  }

//+------------------------------------------------------------------+
//| Get profit factor with bounds checking                          |
//+------------------------------------------------------------------+
double CSecureLearningEngine::GetProfitFactor(int lookback = 0)
  {
   if(!m_knowledgeBase.IsValid())
      return 0.0;
   
   STradeRecord trades[];
   if(!m_knowledgeBase->GetRecentTrades(lookback > 0 ? lookback : m_windowSize, trades))
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
//| Get maximum drawdown with bounds checking                       |
//+------------------------------------------------------------------+
double CSecureLearningEngine::GetMaxDrawdown(int lookback = 0)
  {
   if(!m_knowledgeBase.IsValid())
      return 0.0;
   
   STradeRecord trades[];
   if(!m_knowledgeBase->GetRecentTrades(lookback > 0 ? lookback : m_windowSize, trades))
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

//+------------------------------------------------------------------+
//| Check if engine is healthy                                      |
//+------------------------------------------------------------------+
bool CSecureLearningEngine::IsHealthy() const
  {
   return m_knowledgeBase.IsValid() && 
          m_memoryUsage <= m_maxMemoryUsage &&
          m_actualWeightCount <= m_maxModelWeights;
  }

//+------------------------------------------------------------------+
//| Check if engine is active                                       |
//+------------------------------------------------------------------+
bool CSecureLearningEngine::IsActive() const
  {
   return m_isTrained && IsHealthy();
  }

//+------------------------------------------------------------------+
//| Check if model should be updated                                |
//+------------------------------------------------------------------+
bool CSecureLearningEngine::ShouldUpdate() const
  {
   if(!IsActive())
      return false;
   
   // Update if last update was more than 1 hour ago
   return (TimeCurrent() - m_lastUpdate) > 3600;
  }

//+------------------------------------------------------------------+
//| Save model state                                                |
//+------------------------------------------------------------------+
bool CSecureLearningEngine::SaveState()
  {
   if(!m_knowledgeBase.IsValid())
      return false;
   
   // Save only the actual weights used
   double activeWeights[];
   ArrayResize(activeWeights, m_actualWeightCount);
   ArrayCopy(activeWeights, m_modelWeights, 0, 0, m_actualWeightCount);
   
   bool result = m_knowledgeBase->SaveModel(activeWeights);
   
   if(result)
      LogSecurityEvent("SAVE", "Model state saved successfully");
   else
      LogSecurityEvent("ERROR", "Failed to save model state");
   
   return result;
  }

//+------------------------------------------------------------------+
//| Load model state                                                |
//+------------------------------------------------------------------+
bool CSecureLearningEngine::LoadState()
  {
   if(!m_knowledgeBase.IsValid() || !m_knowledgeBase->ModelExists())
      return false;
   
   double loadedWeights[];
   if(!m_knowledgeBase->LoadModel(loadedWeights))
      return false;
   
   // Validate loaded weights
   int loadedCount = ArraySize(loadedWeights);
   if(loadedCount == 0 || loadedCount > m_maxModelWeights)
     {
      LogSecurityEvent("ERROR", StringFormat("Invalid loaded weight count: %d", loadedCount));
      return false;
     }
   
   // Copy loaded weights with bounds checking
   m_actualWeightCount = MathMin(loadedCount, m_maxModelWeights);
   ArrayCopy(m_modelWeights, loadedWeights, 0, 0, m_actualWeightCount);
   
   m_isTrained = true;
   
   LogSecurityEvent("LOAD", StringFormat("Model state loaded: %d weights", m_actualWeightCount));
   return true;
  }

//+------------------------------------------------------------------+
//| Set window size with validation                                 |
//+------------------------------------------------------------------+
bool CSecureLearningEngine::SetWindowSize(int size)
  {
   if(size < 10 || size > 1000)
     {
      LogSecurityEvent("VALIDATION", StringFormat("Invalid window size: %d", size));
      return false;
     }
   
   m_windowSize = size;
   return true;
  }

//+------------------------------------------------------------------+
//| Set minimum win rate with validation                            |
//+------------------------------------------------------------------+
bool CSecureLearningEngine::SetMinWinRate(double rate)
  {
   if(rate < 0.1 || rate > 1.0)
     {
      LogSecurityEvent("VALIDATION", StringFormat("Invalid min win rate: %.2f", rate));
      return false;
     }
   
   m_minWinRate = rate;
   return true;
  }

//+------------------------------------------------------------------+
//| Set learning rate with validation                               |
//+------------------------------------------------------------------+
bool CSecureLearningEngine::SetLearningRate(double rate)
  {
   if(rate < 0.0001 || rate > 1.0)
     {
      LogSecurityEvent("VALIDATION", StringFormat("Invalid learning rate: %.4f", rate));
      return false;
     }
   
   m_learningRate = rate;
   return true;
  }