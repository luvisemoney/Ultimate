//+------------------------------------------------------------------+
//| SignalPipeline.mqh - ENTERPRISE SIGNAL PROCESSING SYSTEM       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA - JAILBREAK HARDENED"
#property link      "https://www.escapeea.com"
#property version   "3.00"

#include "..\Common\Enums.mqh"
#include "..\Common\Structs.mqh"
#include "..\Common\Constants.mqh"
#include "..\Performance\PerformanceEngine.mqh"

//+------------------------------------------------------------------+
//| ENHANCED SIGNAL STRUCTURE                                       |
//+------------------------------------------------------------------+
struct SEnhancedSignal
{
   // CORE SIGNAL DATA
   STradeSignal      baseSignal;              // Original signal
   
   // ENHANCED METADATA
   string            signalId;                // Unique signal identifier
   ulong             hash;                    // Signal hash for deduplication
   double            enhancedConfidence;      // ML-enhanced confidence
   double            correlationScore;        // Correlation with portfolio
   double            riskScore;               // Risk assessment score
   double            liquidityScore;          // Liquidity assessment
   
   // PROCESSING METADATA
   datetime          receivedTime;            // Signal received timestamp
   datetime          processedTime;           // Signal processed timestamp
   int               processingLatency;       // Processing latency (ms)
   int               validationStage;         // Current validation stage
   bool              isProcessed;             // Processing complete flag
   
   // QUALITY METRICS
   double            signalQuality;           // Overall signal quality score
   double            historicalAccuracy;      // Historical accuracy of source
   double            marketRegimeScore;       // Market regime compatibility
   double            volatilityScore;         // Volatility environment score
   
   // EXECUTION METADATA
   bool              isExecutable;            // Can be executed flag
   string            rejectionReason;         // Rejection reason if any
   double            expectedSlippage;        // Expected execution slippage
   double            executionProbability;    // Probability of successful execution
};

//+------------------------------------------------------------------+
//| SIGNAL VALIDATION STAGE ENUM                                    |
//+------------------------------------------------------------------+
enum ENUM_VALIDATION_STAGE
{
   VALIDATION_RECEIVED = 0,        // Signal received
   VALIDATION_BASIC = 1,           // Basic validation
   VALIDATION_ENHANCED = 2,        // Enhanced validation
   VALIDATION_RISK = 3,            // Risk assessment
   VALIDATION_CORRELATION = 4,     // Correlation analysis
   VALIDATION_LIQUIDITY = 5,       // Liquidity check
   VALIDATION_COMPLETE = 6,        // Validation complete
   VALIDATION_REJECTED = 7         // Signal rejected
};

//+------------------------------------------------------------------+
//| SIGNAL QUEUE WITH PRIORITY ORDERING                             |
//+------------------------------------------------------------------+
class CSignalQueue
{
private:
   SEnhancedSignal   m_signals[];             // Signal queue array
   int               m_queueSize;             // Maximum queue size
   int               m_head;                  // Queue head index
   int               m_tail;                  // Queue tail index
   int               m_count;                 // Current signal count
   bool              m_isCircular;            // Circular queue flag
   
   // PRIORITY SORTING
   void              SortByPriority();
   double            CalculatePriority(const SEnhancedSignal &signal);
   
public:
                     CSignalQueue(int maxSize = 1000);
                    ~CSignalQueue();
   
   // QUEUE OPERATIONS
   bool              Enqueue(const SEnhancedSignal &signal);
   bool              Dequeue(SEnhancedSignal &signal);
   bool              Peek(SEnhancedSignal &signal);
   void              Clear();
   
   // QUEUE STATUS
   int               Count() const { return m_count; }
   int               Capacity() const { return m_queueSize; }
   bool              IsEmpty() const { return m_count == 0; }
   bool              IsFull() const { return m_count >= m_queueSize; }
   double            Utilization() const { return (double)m_count / m_queueSize * 100.0; }
   
   // PRIORITY OPERATIONS
   bool              EnqueueWithPriority(const SEnhancedSignal &signal);
   bool              GetHighestPriority(SEnhancedSignal &signal);
   void              RemoveExpiredSignals(int maxAgeSeconds = 300);
};

//+------------------------------------------------------------------+
//| SIGNAL DEDUPLICATION SYSTEM                                     |
//+------------------------------------------------------------------+
class CSignalDeduplicator
{
private:
   ulong             m_signalHashes[];        // Hash table for deduplication
   datetime          m_hashTimestamps[];      // Hash timestamps
   int               m_hashTableSize;         // Hash table size
   int               m_hashCount;             // Current hash count
   
   // HASH FUNCTIONS
   ulong             CalculateSignalHash(const STradeSignal &signal);
   ulong             SimpleHash(const string &str);
   
public:
                     CSignalDeduplicator(int tableSize = 10000);
                    ~CSignalDeduplicator();
   
   // DEDUPLICATION METHODS
   bool              IsDuplicate(const STradeSignal &signal);
   void              AddSignal(const STradeSignal &signal);
   void              CleanupExpiredHashes(int maxAgeSeconds = 3600);
   void              Clear();
   
   // STATISTICS
   int               GetHashCount() const { return m_hashCount; }
   double            GetTableUtilization() const { return (double)m_hashCount / m_hashTableSize * 100.0; }
};

//+------------------------------------------------------------------+
//| SIGNAL VALIDATOR WITH MULTIPLE STAGES                           |
//+------------------------------------------------------------------+
class CSignalValidator
{
private:
   // VALIDATION CONFIGURATION
   double            m_minConfidence;         // Minimum confidence threshold
   int               m_maxSignalAge;          // Maximum signal age (seconds)
   double            m_minLiquidity;          // Minimum liquidity score
   double            m_maxCorrelation;        // Maximum correlation with portfolio
   
   // VALIDATION STATISTICS
   int               m_totalValidated;        // Total signals validated
   int               m_totalRejected;         // Total signals rejected
   int               m_rejectionReasons[];    // Rejection reason counts
   
   // VALIDATION METHODS
   bool              ValidateBasic(SEnhancedSignal &signal);
   bool              ValidateEnhanced(SEnhancedSignal &signal);
   bool              ValidateRisk(SEnhancedSignal &signal);
   bool              ValidateCorrelation(SEnhancedSignal &signal);
   bool              ValidateLiquidity(SEnhancedSignal &signal);
   
public:
                     CSignalValidator(double minConfidence = 0.7,
                                    int maxSignalAge = 300,
                                    double minLiquidity = 0.5,
                                    double maxCorrelation = 0.8);
                    ~CSignalValidator();
   
   // VALIDATION PIPELINE
   bool              ValidateSignal(SEnhancedSignal &signal);
   ENUM_VALIDATION_STAGE ProcessNextStage(SEnhancedSignal &signal);
   
   // CONFIGURATION
   void              SetMinConfidence(double confidence);
   void              SetMaxSignalAge(int seconds);
   void              SetMinLiquidity(double liquidity);
   void              SetMaxCorrelation(double correlation);
   
   // STATISTICS
   double            GetValidationRate() const;
   string            GetValidationReport();
   void              ResetStatistics();
};

//+------------------------------------------------------------------+
//| CORRELATION ANALYZER                                            |
//+------------------------------------------------------------------+
class CCorrelationAnalyzer
{
private:
   // CORRELATION DATA
   double            m_correlationMatrix[][];  // Symbol correlation matrix
   string            m_symbols[];              // Tracked symbols
   int               m_symbolCount;            // Number of symbols
   datetime          m_lastUpdate;             // Last correlation update
   
   // HISTORICAL DATA
   double            m_returns[][];            // Historical returns matrix
   int               m_returnPeriods;          // Number of return periods
   
   // CALCULATION METHODS
   void              UpdateCorrelations();
   double            CalculateCorrelation(const string symbol1, const string symbol2);
   void              UpdateReturns();
   
public:
                     CCorrelationAnalyzer(int maxSymbols = 50);
                    ~CCorrelationAnalyzer();
   
   // SYMBOL MANAGEMENT
   bool              AddSymbol(const string symbol);
   bool              RemoveSymbol(const string symbol);
   void              ClearSymbols();
   
   // CORRELATION ANALYSIS
   double            GetCorrelation(const string symbol1, const string symbol2);
   double            GetPortfolioCorrelation(const string newSymbol);
   double            GetAverageCorrelation();
   void              UpdateAllCorrelations();
   
   // RISK ANALYSIS
   double            CalculateCorrelationRisk(const string symbol, double positionSize);
   bool              IsCorrelationAcceptable(const string symbol, double maxCorrelation = 0.8);
   
   // REPORTING
   string            GetCorrelationReport();
   void              LogCorrelationMatrix();
};

//+------------------------------------------------------------------+
//| ENTERPRISE SIGNAL PIPELINE                                      |
//+------------------------------------------------------------------+
class CSignalPipeline
{
private:
   // PIPELINE COMPONENTS
   CSignalQueue         *m_inputQueue;        // Input signal queue
   CSignalQueue         *m_outputQueue;       // Output signal queue
   CSignalDeduplicator  *m_deduplicator;      // Signal deduplicator
   CSignalValidator     *m_validator;         // Signal validator
   CCorrelationAnalyzer *m_correlationAnalyzer; // Correlation analyzer
   
   // PERFORMANCE TRACKING
   CPerformanceProfiler *m_profiler;          // Performance profiler
   int                  m_processedCount;     // Processed signal count
   int                  m_rejectedCount;      // Rejected signal count
   datetime             m_lastProcessTime;    // Last processing time
   
   // CONFIGURATION
   bool                 m_isEnabled;          // Pipeline enabled flag
   int                  m_maxProcessingTime;  // Max processing time (ms)
   bool                 m_enableMLScoring;    // Enable ML confidence scoring
   
   // PROCESSING METHODS
   bool                 ProcessSignalStage(SEnhancedSignal &signal);
   void                 EnhanceSignalConfidence(SEnhancedSignal &signal);
   void                 CalculateSignalScores(SEnhancedSignal &signal);
   
public:
                        CSignalPipeline(int inputQueueSize = 1000,
                                      int outputQueueSize = 500);
                       ~CSignalPipeline();
   
   // PIPELINE OPERATIONS
   bool                 Initialize();
   bool                 ProcessSignal(const STradeSignal &signal);
   bool                 GetProcessedSignal(SEnhancedSignal &signal);
   void                 ProcessAllSignals();
   
   // PIPELINE CONTROL
   void                 Enable() { m_isEnabled = true; }
   void                 Disable() { m_isEnabled = false; }
   bool                 IsEnabled() const { return m_isEnabled; }
   void                 Clear();
   
   // CONFIGURATION
   void                 SetMaxProcessingTime(int milliseconds);
   void                 EnableMLScoring(bool enable);
   
   // MONITORING
   int                  GetInputQueueSize() const;
   int                  GetOutputQueueSize() const;
   double               GetProcessingLatency() const;
   double               GetThroughput() const;
   string               GetPipelineStatus();
   
   // STATISTICS
   int                  GetProcessedCount() const { return m_processedCount; }
   int                  GetRejectedCount() const { return m_rejectedCount; }
   double               GetAcceptanceRate() const;
   string               GetPerformanceReport();
   
   // QUALITY CONTROL
   bool                 IsPerformanceAcceptable();
   void                 OptimizePerformance();
   void                 ResetStatistics();
};

//+------------------------------------------------------------------+
//| SIGNAL QUEUE IMPLEMENTATION                                     |
//+------------------------------------------------------------------+
CSignalQueue::CSignalQueue(int maxSize = 1000) :
   m_queueSize(MathMax(100, MathMin(maxSize, 10000))),
   m_head(0),
   m_tail(0),
   m_count(0),
   m_isCircular(true)
{
   ArrayResize(m_signals, m_queueSize);
   Print("SIGNAL: Queue created with capacity: ", m_queueSize);
}

CSignalQueue::~CSignalQueue()
{
   Print("SIGNAL: Queue destroyed. Peak utilization: ", 
         (double)m_count / m_queueSize * 100.0, "%");
}

bool CSignalQueue::Enqueue(const SEnhancedSignal &signal)
{
   if(IsFull())
   {
      Print("SIGNAL WARNING: Queue full, dropping oldest signal");
      // Remove oldest signal to make room
      SEnhancedSignal dummy;
      Dequeue(dummy);
   }
   
   m_signals[m_tail] = signal;
   m_tail = (m_tail + 1) % m_queueSize;
   m_count++;
   
   return true;
}

bool CSignalQueue::Dequeue(SEnhancedSignal &signal)
{
   if(IsEmpty())
      return false;
      
   signal = m_signals[m_head];
   m_head = (m_head + 1) % m_queueSize;
   m_count--;
   
   return true;
}

double CSignalQueue::CalculatePriority(const SEnhancedSignal &signal)
{
   // Calculate priority based on multiple factors
   double priority = 0.0;
   
   // Confidence weight (40%)
   priority += signal.enhancedConfidence * 0.4;
   
   // Signal quality weight (30%)
   priority += signal.signalQuality * 0.3;
   
   // Time decay weight (20%) - newer signals have higher priority
   datetime currentTime = TimeCurrent();
   double ageSeconds = (double)(currentTime - signal.receivedTime);
   double timeDecay = MathExp(-ageSeconds / 300.0); // 5-minute half-life
   priority += timeDecay * 0.2;
   
   // Risk score weight (10%) - lower risk = higher priority
   priority += (1.0 - signal.riskScore) * 0.1;
   
   return MathMax(0.0, MathMin(priority, 1.0));
}

//+------------------------------------------------------------------+
//| SIGNAL DEDUPLICATOR IMPLEMENTATION                              |
//+------------------------------------------------------------------+
CSignalDeduplicator::CSignalDeduplicator(int tableSize = 10000) :
   m_hashTableSize(MathMax(1000, MathMin(tableSize, 100000))),
   m_hashCount(0)
{
   ArrayResize(m_signalHashes, m_hashTableSize);
   ArrayResize(m_hashTimestamps, m_hashTableSize);
   
   // Initialize arrays
   ArrayInitialize(m_signalHashes, 0);
   ArrayInitialize(m_hashTimestamps, 0);
   
   Print("SIGNAL: Deduplicator created with table size: ", m_hashTableSize);
}

CSignalDeduplicator::~CSignalDeduplicator()
{
   Print("SIGNAL: Deduplicator destroyed. Peak utilization: ", 
         (double)m_hashCount / m_hashTableSize * 100.0, "%");
}

ulong CSignalDeduplicator::CalculateSignalHash(const STradeSignal &signal)
{
   // Create hash from key signal components
   string hashString = StringFormat("%s_%d_%.5f_%.5f_%.5f_%.3f_%d",
                                   signal.symbol,
                                   (int)signal.signal,
                                   signal.entry,
                                   signal.stopLoss,
                                   signal.takeProfit,
                                   signal.confidence,
                                   (int)signal.timestamp);
   
   return SimpleHash(hashString);
}

ulong CSignalDeduplicator::SimpleHash(const string &str)
{
   // Simple hash function (could be improved with better algorithm)
   ulong hash = 5381;
   int len = StringLen(str);
   
   for(int i = 0; i < len; i++)
   {
      int c = StringGetCharacter(str, i);
      hash = ((hash << 5) + hash) + c; // hash * 33 + c
   }
   
   return hash;
}

bool CSignalDeduplicator::IsDuplicate(const STradeSignal &signal)
{
   ulong hash = CalculateSignalHash(signal);
   
   // Linear search in hash table (could be optimized)
   for(int i = 0; i < m_hashCount; i++)
   {
      if(m_signalHashes[i] == hash)
      {
         // Check if hash is still valid (not expired)
         if((TimeCurrent() - m_hashTimestamps[i]) <= 3600) // 1 hour
         {
            return true; // Duplicate found
         }
      }
   }
   
   return false; // Not a duplicate
}

void CSignalDeduplicator::AddSignal(const STradeSignal &signal)
{
   if(m_hashCount >= m_hashTableSize)
   {
      // Table full, clean up expired entries
      CleanupExpiredHashes(3600);
      
      if(m_hashCount >= m_hashTableSize)
      {
         Print("SIGNAL ERROR: Hash table full, cannot add signal");
         return;
      }
   }
   
   ulong hash = CalculateSignalHash(signal);
   m_signalHashes[m_hashCount] = hash;
   m_hashTimestamps[m_hashCount] = TimeCurrent();
   m_hashCount++;
}

//+------------------------------------------------------------------+
//| SIGNAL VALIDATOR IMPLEMENTATION                                 |
//+------------------------------------------------------------------+
CSignalValidator::CSignalValidator(double minConfidence = 0.7,
                                 int maxSignalAge = 300,
                                 double minLiquidity = 0.5,
                                 double maxCorrelation = 0.8) :
   m_minConfidence(MathMax(0.5, MathMin(minConfidence, 1.0))),
   m_maxSignalAge(MathMax(60, MathMin(maxSignalAge, 3600))),
   m_minLiquidity(MathMax(0.1, MathMin(minLiquidity, 1.0))),
   m_maxCorrelation(MathMax(0.5, MathMin(maxCorrelation, 1.0))),
   m_totalValidated(0),
   m_totalRejected(0)
{
   ArrayResize(m_rejectionReasons, 10);
   ArrayInitialize(m_rejectionReasons, 0);
   
   Print("SIGNAL: Validator initialized");
   Print("  Min Confidence: ", m_minConfidence);
   Print("  Max Signal Age: ", m_maxSignalAge, " seconds");
   Print("  Min Liquidity: ", m_minLiquidity);
   Print("  Max Correlation: ", m_maxCorrelation);
}

bool CSignalValidator::ValidateSignal(SEnhancedSignal &signal)
{
   PERF_START("SignalValidation");
   
   signal.validationStage = VALIDATION_RECEIVED;
   
   // Stage 1: Basic validation
   if(!ValidateBasic(signal))
   {
      signal.validationStage = VALIDATION_REJECTED;
      m_totalRejected++;
      PERF_END();
      return false;
   }
   signal.validationStage = VALIDATION_BASIC;
   
   // Stage 2: Enhanced validation
   if(!ValidateEnhanced(signal))
   {
      signal.validationStage = VALIDATION_REJECTED;
      m_totalRejected++;
      PERF_END();
      return false;
   }
   signal.validationStage = VALIDATION_ENHANCED;
   
   // Stage 3: Risk validation
   if(!ValidateRisk(signal))
   {
      signal.validationStage = VALIDATION_REJECTED;
      m_totalRejected++;
      PERF_END();
      return false;
   }
   signal.validationStage = VALIDATION_RISK;
   
   // Stage 4: Correlation validation
   if(!ValidateCorrelation(signal))
   {
      signal.validationStage = VALIDATION_REJECTED;
      m_totalRejected++;
      PERF_END();
      return false;
   }
   signal.validationStage = VALIDATION_CORRELATION;
   
   // Stage 5: Liquidity validation
   if(!ValidateLiquidity(signal))
   {
      signal.validationStage = VALIDATION_REJECTED;
      m_totalRejected++;
      PERF_END();
      return false;
   }
   signal.validationStage = VALIDATION_LIQUIDITY;
   
   // All validations passed
   signal.validationStage = VALIDATION_COMPLETE;
   signal.isExecutable = true;
   m_totalValidated++;
   
   PERF_END();
   return true;
}

bool CSignalValidator::ValidateBasic(SEnhancedSignal &signal)
{
   // Check confidence threshold
   if(signal.baseSignal.confidence < m_minConfidence)
   {
      signal.rejectionReason = "Low confidence: " + DoubleToString(signal.baseSignal.confidence, 3);
      m_rejectionReasons[0]++;
      return false;
   }
   
   // Check signal age
   datetime currentTime = TimeCurrent();
   if((currentTime - signal.baseSignal.timestamp) > m_maxSignalAge)
   {
      signal.rejectionReason = "Signal too old: " + IntegerToString(currentTime - signal.baseSignal.timestamp) + "s";
      m_rejectionReasons[1]++;
      return false;
   }
   
   // Check signal type
   if(signal.baseSignal.signal != SIGNAL_BUY && signal.baseSignal.signal != SIGNAL_SELL)
   {
      signal.rejectionReason = "Invalid signal type: " + IntegerToString((int)signal.baseSignal.signal);
      m_rejectionReasons[2]++;
      return false;
   }
   
   // Check price levels
   if(signal.baseSignal.entry <= 0 || signal.baseSignal.stopLoss < 0 || signal.baseSignal.takeProfit < 0)
   {
      signal.rejectionReason = "Invalid price levels";
      m_rejectionReasons[3]++;
      return false;
   }
   
   return true;
}

bool CSignalValidator::ValidateEnhanced(SEnhancedSignal &signal)
{
   // Validate enhanced confidence
   if(signal.enhancedConfidence < m_minConfidence)
   {
      signal.rejectionReason = "Low enhanced confidence: " + DoubleToString(signal.enhancedConfidence, 3);
      m_rejectionReasons[4]++;
      return false;
   }
   
   // Validate signal quality
   if(signal.signalQuality < 0.5) // Minimum 50% quality
   {
      signal.rejectionReason = "Low signal quality: " + DoubleToString(signal.signalQuality, 3);
      m_rejectionReasons[5]++;
      return false;
   }
   
   return true;
}

bool CSignalValidator::ValidateRisk(SEnhancedSignal &signal)
{
   // Check risk score
   if(signal.riskScore > 0.8) // Maximum 80% risk
   {
      signal.rejectionReason = "High risk score: " + DoubleToString(signal.riskScore, 3);
      m_rejectionReasons[6]++;
      return false;
   }
   
   return true;
}

bool CSignalValidator::ValidateCorrelation(SEnhancedSignal &signal)
{
   // Check correlation with existing portfolio
   if(signal.correlationScore > m_maxCorrelation)
   {
      signal.rejectionReason = "High correlation: " + DoubleToString(signal.correlationScore, 3);
      m_rejectionReasons[7]++;
      return false;
   }
   
   return true;
}

bool CSignalValidator::ValidateLiquidity(SEnhancedSignal &signal)
{
   // Check liquidity score
   if(signal.liquidityScore < m_minLiquidity)
   {
      signal.rejectionReason = "Low liquidity: " + DoubleToString(signal.liquidityScore, 3);
      m_rejectionReasons[8]++;
      return false;
   }
   
   return true;
}

double CSignalValidator::GetValidationRate() const
{
   int total = m_totalValidated + m_totalRejected;
   return (total > 0) ? (double)m_totalValidated / total * 100.0 : 0.0;
}

string CSignalValidator::GetValidationReport()
{
   string report = StringFormat(
      "SIGNAL VALIDATION REPORT:\n" +
      "Total Validated: %d | Total Rejected: %d\n" +
      "Validation Rate: %.2f%%\n" +
      "Rejection Reasons:\n" +
      "  Low Confidence: %d | Signal Age: %d | Invalid Type: %d\n" +
      "  Invalid Prices: %d | Low Enhanced Conf: %d | Low Quality: %d\n" +
      "  High Risk: %d | High Correlation: %d | Low Liquidity: %d",
      m_totalValidated, m_totalRejected,
      GetValidationRate(),
      m_rejectionReasons[0], m_rejectionReasons[1], m_rejectionReasons[2],
      m_rejectionReasons[3], m_rejectionReasons[4], m_rejectionReasons[5],
      m_rejectionReasons[6], m_rejectionReasons[7], m_rejectionReasons[8]
   );
   
   return report;
}