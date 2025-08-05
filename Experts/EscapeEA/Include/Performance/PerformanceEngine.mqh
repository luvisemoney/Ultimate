//+------------------------------------------------------------------+
//| PerformanceEngine.mqh - ENTERPRISE PERFORMANCE OPTIMIZATION     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA - JAILBREAK HARDENED"
#property link      "https://www.escapeea.com"
#property version   "3.00"

#include "..\Common\Enums.mqh"
#include "..\Common\Structs.mqh"
#include "..\Common\Constants.mqh"

//+------------------------------------------------------------------+
//| PERFORMANCE METRICS STRUCTURE                                   |
//+------------------------------------------------------------------+
struct SPerformanceMetrics
{
   // TIMING METRICS
   ulong             tickProcessingTime;       // Microseconds
   ulong             signalProcessingTime;     // Microseconds
   ulong             riskCalculationTime;      // Microseconds
   ulong             tradeExecutionTime;       // Microseconds
   
   // THROUGHPUT METRICS
   int               ticksPerSecond;           // Ticks processed per second
   int               signalsPerSecond;         // Signals processed per second
   int               tradesPerSecond;          // Trades executed per second
   
   // RESOURCE METRICS
   ulong             memoryUsage;              // Bytes
   double            cpuUsage;                 // Percentage
   int               activeThreads;            // Thread count
   
   // QUALITY METRICS
   double            errorRate;                // Errors per operation
   double            successRate;              // Success percentage
   ulong             totalOperations;          // Total operations count
   
   // LATENCY METRICS
   ulong             p50Latency;               // 50th percentile (microseconds)
   ulong             p95Latency;               // 95th percentile (microseconds)
   ulong             p99Latency;               // 99th percentile (microseconds)
   ulong             maxLatency;               // Maximum latency (microseconds)
};

//+------------------------------------------------------------------+
//| PERFORMANCE PROFILER FOR OPERATIONS                             |
//+------------------------------------------------------------------+
class CPerformanceProfiler
{
private:
   ulong             m_startTime;              // Operation start time
   string            m_operationName;          // Operation being profiled
   bool              m_isActive;               // Profiler active flag
   
public:
                     CPerformanceProfiler(const string operationName = "");
                    ~CPerformanceProfiler();
   
   void              Start(const string operationName);
   ulong             Stop();                   // Returns elapsed microseconds
   ulong             GetElapsedMicroseconds();
   bool              IsActive() const { return m_isActive; }
};

//+------------------------------------------------------------------+
//| MEMORY POOL FOR HIGH-FREQUENCY ALLOCATIONS                      |
//+------------------------------------------------------------------+
template<typename T>
class CMemoryPool
{
private:
   T                *m_pool;                   // Memory pool array
   bool             *m_used;                   // Usage flags
   int               m_poolSize;               // Pool size
   int               m_nextFree;               // Next free slot hint
   int               m_allocatedCount;         // Currently allocated count
   
public:
                     CMemoryPool(int poolSize = 1000);
                    ~CMemoryPool();
   
   T*               Allocate();
   bool             Deallocate(T* ptr);
   void             Clear();
   
   // STATISTICS
   int              GetAllocatedCount() const { return m_allocatedCount; }
   int              GetFreeCount() const { return m_poolSize - m_allocatedCount; }
   double           GetUtilization() const { return (double)m_allocatedCount / m_poolSize * 100.0; }
};

//+------------------------------------------------------------------+
//| ENTERPRISE PERFORMANCE ENGINE                                   |
//+------------------------------------------------------------------+
class CPerformanceEngine
{
private:
   // PERFORMANCE TRACKING
   SPerformanceMetrics m_metrics;             // Current metrics
   SPerformanceMetrics m_historicalMetrics[]; // Historical metrics
   int               m_metricsHistorySize;     // History buffer size
   int               m_currentMetricsIndex;    // Current index in history
   
   // LATENCY TRACKING
   ulong             m_latencyBuffer[];        // Latency measurements buffer
   int               m_latencyBufferSize;      // Buffer size
   int               m_latencyIndex;           // Current buffer index
   
   // OPERATION COUNTERS
   ulong             m_operationCounts[];      // Operation counts by type
   ulong             m_errorCounts[];          // Error counts by type
   datetime          m_lastResetTime;          // Last metrics reset time
   
   // MEMORY POOLS
   CMemoryPool<STradeSignal> *m_signalPool;   // Signal memory pool
   CMemoryPool<STradeRecord> *m_tradePool;    // Trade record memory pool
   
   // CACHING SYSTEM
   double            m_cachedATR[];            // Cached ATR values
   datetime          m_atrCacheTime[];         // ATR cache timestamps
   int               m_atrCacheSize;           // ATR cache size
   
   // PRIVATE METHODS
   void              UpdateLatencyMetrics();
   void              UpdateThroughputMetrics();
   void              UpdateResourceMetrics();
   void              CalculatePercentiles();
   void              ResetCounters();
   
public:
   // CONSTRUCTOR/DESTRUCTOR
                     CPerformanceEngine(int historySize = 1000, int latencyBufferSize = 10000);
                    ~CPerformanceEngine();
   
   // PROFILING METHODS
   void              StartOperation(const string operationName);
   void              EndOperation(const string operationName, bool success = true);
   void              RecordLatency(ulong latencyMicroseconds);
   
   // METRICS COLLECTION
   void              UpdateMetrics();
   SPerformanceMetrics GetCurrentMetrics();
   SPerformanceMetrics GetAverageMetrics(int periodMinutes = 60);
   
   // MEMORY MANAGEMENT
   STradeSignal*     AllocateSignal();
   bool              DeallocateSignal(STradeSignal* signal);
   STradeRecord*     AllocateTrade();
   bool              DeallocateTrade(STradeRecord* trade);
   
   // CACHING SYSTEM
   double            GetCachedATR(const string symbol, int period, int maxAgeSeconds = 60);
   void              CacheATR(const string symbol, int period, double value);
   void              ClearCache();
   
   // PERFORMANCE OPTIMIZATION
   void              OptimizeForHighFrequency();
   void              OptimizeForLowLatency();
   void              OptimizeMemoryUsage();
   
   // MONITORING
   bool              IsPerformanceAcceptable();
   string            GetPerformanceReport();
   void              LogPerformanceMetrics();
   
   // ALERTS
   bool              CheckPerformanceThresholds();
   void              SetLatencyThreshold(ulong microseconds);
   void              SetThroughputThreshold(int operationsPerSecond);
   void              SetMemoryThreshold(ulong bytes);
};

//+------------------------------------------------------------------+
//| PERFORMANCE PROFILER IMPLEMENTATION                             |
//+------------------------------------------------------------------+
CPerformanceProfiler::CPerformanceProfiler(const string operationName = "") :
   m_startTime(0),
   m_operationName(operationName),
   m_isActive(false)
{
   if(StringLen(operationName) > 0)
   {
      Start(operationName);
   }
}

CPerformanceProfiler::~CPerformanceProfiler()
{
   if(m_isActive)
   {
      Stop();
   }
}

void CPerformanceProfiler::Start(const string operationName)
{
   m_operationName = operationName;
   m_startTime = GetMicrosecondCount();
   m_isActive = true;
}

ulong CPerformanceProfiler::Stop()
{
   if(!m_isActive)
      return 0;
      
   ulong elapsed = GetMicrosecondCount() - m_startTime;
   m_isActive = false;
   
   // Log if operation took too long
   if(elapsed > 1000) // More than 1ms
   {
      Print("PERF WARNING: ", m_operationName, " took ", elapsed, " microseconds");
   }
   
   return elapsed;
}

ulong CPerformanceProfiler::GetElapsedMicroseconds()
{
   if(!m_isActive)
      return 0;
      
   return GetMicrosecondCount() - m_startTime;
}

//+------------------------------------------------------------------+
//| MEMORY POOL IMPLEMENTATION                                      |
//+------------------------------------------------------------------+
template<typename T>
CMemoryPool::CMemoryPool(int poolSize = 1000) :
   m_poolSize(MathMax(100, MathMin(poolSize, 10000))),
   m_nextFree(0),
   m_allocatedCount(0)
{
   m_pool = new T[m_poolSize];
   m_used = new bool[m_poolSize];
   
   // Initialize usage flags
   for(int i = 0; i < m_poolSize; i++)
   {
      m_used[i] = false;
   }
   
   Print("PERF: Memory pool created with ", m_poolSize, " slots");
}

template<typename T>
CMemoryPool::~CMemoryPool()
{
   if(m_pool != NULL)
   {
      delete[] m_pool;
      m_pool = NULL;
   }
   
   if(m_used != NULL)
   {
      delete[] m_used;
      m_used = NULL;
   }
   
   Print("PERF: Memory pool destroyed. Peak utilization: ", 
         (double)m_allocatedCount / m_poolSize * 100.0, "%");
}

template<typename T>
T* CMemoryPool::Allocate()
{
   // Quick check at hint position
   if(m_nextFree < m_poolSize && !m_used[m_nextFree])
   {
      m_used[m_nextFree] = true;
      m_allocatedCount++;
      T* result = &m_pool[m_nextFree];
      m_nextFree++;
      return result;
   }
   
   // Linear search for free slot
   for(int i = 0; i < m_poolSize; i++)
   {
      if(!m_used[i])
      {
         m_used[i] = true;
         m_allocatedCount++;
         m_nextFree = i + 1;
         return &m_pool[i];
      }
   }
   
   // Pool exhausted
   Print("PERF ERROR: Memory pool exhausted! Allocated: ", m_allocatedCount, "/", m_poolSize);
   return NULL;
}

template<typename T>
bool CMemoryPool::Deallocate(T* ptr)
{
   if(ptr == NULL || m_pool == NULL)
      return false;
      
   // Calculate index
   int index = (int)(ptr - m_pool);
   
   // Validate index
   if(index < 0 || index >= m_poolSize)
   {
      Print("PERF ERROR: Invalid pointer in deallocate");
      return false;
   }
   
   // Check if already free
   if(!m_used[index])
   {
      Print("PERF ERROR: Double free detected at index ", index);
      return false;
   }
   
   // Mark as free
   m_used[index] = false;
   m_allocatedCount--;
   
   // Update hint
   if(index < m_nextFree)
      m_nextFree = index;
      
   return true;
}

template<typename T>
void CMemoryPool::Clear()
{
   for(int i = 0; i < m_poolSize; i++)
   {
      m_used[i] = false;
   }
   
   m_allocatedCount = 0;
   m_nextFree = 0;
   
   Print("PERF: Memory pool cleared");
}

//+------------------------------------------------------------------+
//| PERFORMANCE ENGINE IMPLEMENTATION                               |
//+------------------------------------------------------------------+
CPerformanceEngine::CPerformanceEngine(int historySize = 1000, int latencyBufferSize = 10000) :
   m_metricsHistorySize(MathMax(100, MathMin(historySize, 10000))),
   m_latencyBufferSize(MathMax(1000, MathMin(latencyBufferSize, 100000))),
   m_currentMetricsIndex(0),
   m_latencyIndex(0),
   m_atrCacheSize(100),
   m_lastResetTime(TimeCurrent())
{
   // Initialize arrays
   ArrayResize(m_historicalMetrics, m_metricsHistorySize);
   ArrayResize(m_latencyBuffer, m_latencyBufferSize);
   ArrayResize(m_operationCounts, 10); // 10 operation types
   ArrayResize(m_errorCounts, 10);     // 10 error types
   ArrayResize(m_cachedATR, m_atrCacheSize);
   ArrayResize(m_atrCacheTime, m_atrCacheSize);
   
   // Initialize memory pools
   m_signalPool = new CMemoryPool<STradeSignal>(1000);
   m_tradePool = new CMemoryPool<STradeRecord>(500);
   
   // Initialize metrics
   ZeroMemory(m_metrics);
   
   Print("PERF: Performance Engine initialized");
   Print("  Metrics history: ", m_metricsHistorySize, " entries");
   Print("  Latency buffer: ", m_latencyBufferSize, " entries");
   Print("  Signal pool: 1000 slots");
   Print("  Trade pool: 500 slots");
}

CPerformanceEngine::~CPerformanceEngine()
{
   if(m_signalPool != NULL)
   {
      delete m_signalPool;
      m_signalPool = NULL;
   }
   
   if(m_tradePool != NULL)
   {
      delete m_tradePool;
      m_tradePool = NULL;
   }
   
   Print("PERF: Performance Engine destroyed");
}

void CPerformanceEngine::RecordLatency(ulong latencyMicroseconds)
{
   // Store in circular buffer
   m_latencyBuffer[m_latencyIndex] = latencyMicroseconds;
   m_latencyIndex = (m_latencyIndex + 1) % m_latencyBufferSize;
   
   // Update metrics
   if(latencyMicroseconds > m_metrics.maxLatency)
      m_metrics.maxLatency = latencyMicroseconds;
}

void CPerformanceEngine::UpdateMetrics()
{
   // Update timing metrics
   UpdateLatencyMetrics();
   
   // Update throughput metrics
   UpdateThroughputMetrics();
   
   // Update resource metrics
   UpdateResourceMetrics();
   
   // Store in history
   m_historicalMetrics[m_currentMetricsIndex] = m_metrics;
   m_currentMetricsIndex = (m_currentMetricsIndex + 1) % m_metricsHistorySize;
   
   // Reset counters if needed (every hour)
   if(TimeCurrent() - m_lastResetTime > 3600)
   {
      ResetCounters();
   }
}

void CPerformanceEngine::UpdateLatencyMetrics()
{
   if(m_latencyBufferSize == 0)
      return;
      
   // Calculate percentiles
   CalculatePercentiles();
}

void CPerformanceEngine::CalculatePercentiles()
{
   // Simple percentile calculation (could be optimized with better algorithm)
   ulong sortedLatencies[];
   ArrayResize(sortedLatencies, m_latencyBufferSize);
   ArrayCopy(sortedLatencies, m_latencyBuffer);
   ArraySort(sortedLatencies);
   
   int p50Index = (int)(m_latencyBufferSize * 0.5);
   int p95Index = (int)(m_latencyBufferSize * 0.95);
   int p99Index = (int)(m_latencyBufferSize * 0.99);
   
   m_metrics.p50Latency = sortedLatencies[p50Index];
   m_metrics.p95Latency = sortedLatencies[p95Index];
   m_metrics.p99Latency = sortedLatencies[p99Index];
}

void CPerformanceEngine::UpdateThroughputMetrics()
{
   // Calculate operations per second based on recent activity
   datetime currentTime = TimeCurrent();
   int timeWindow = 60; // 1 minute window
   
   // This is simplified - in production, you'd track actual timestamps
   m_metrics.ticksPerSecond = (int)(m_operationCounts[0] / timeWindow);
   m_metrics.signalsPerSecond = (int)(m_operationCounts[1] / timeWindow);
   m_metrics.tradesPerSecond = (int)(m_operationCounts[2] / timeWindow);
}

void CPerformanceEngine::UpdateResourceMetrics()
{
   // Memory usage (simplified)
   m_metrics.memoryUsage = (m_signalPool.GetAllocatedCount() * sizeof(STradeSignal)) +
                          (m_tradePool.GetAllocatedCount() * sizeof(STradeRecord));
   
   // CPU usage (placeholder - MQL5 doesn't provide direct CPU metrics)
   m_metrics.cpuUsage = 0.0;
   
   // Active threads (placeholder)
   m_metrics.activeThreads = 1;
   
   // Error rate
   ulong totalOps = 0;
   ulong totalErrors = 0;
   
   for(int i = 0; i < ArraySize(m_operationCounts); i++)
   {
      totalOps += m_operationCounts[i];
      totalErrors += m_errorCounts[i];
   }
   
   m_metrics.totalOperations = totalOps;
   m_metrics.errorRate = (totalOps > 0) ? (double)totalErrors / totalOps * 100.0 : 0.0;
   m_metrics.successRate = 100.0 - m_metrics.errorRate;
}

STradeSignal* CPerformanceEngine::AllocateSignal()
{
   return m_signalPool.Allocate();
}

bool CPerformanceEngine::DeallocateSignal(STradeSignal* signal)
{
   return m_signalPool.Deallocate(signal);
}

STradeRecord* CPerformanceEngine::AllocateTrade()
{
   return m_tradePool.Allocate();
}

bool CPerformanceEngine::DeallocateTrade(STradeRecord* trade)
{
   return m_tradePool.Deallocate(trade);
}

double CPerformanceEngine::GetCachedATR(const string symbol, int period, int maxAgeSeconds = 60)
{
   datetime currentTime = TimeCurrent();
   
   // Simple linear search (could be optimized with hash table)
   for(int i = 0; i < m_atrCacheSize; i++)
   {
      if(m_atrCacheTime[i] > 0 && 
         (currentTime - m_atrCacheTime[i]) <= maxAgeSeconds)
      {
         // In production, you'd also check symbol and period
         return m_cachedATR[i];
      }
   }
   
   return 0.0; // Not found or expired
}

void CPerformanceEngine::CacheATR(const string symbol, int period, double value)
{
   // Find oldest entry to replace (simplified LRU)
   int oldestIndex = 0;
   datetime oldestTime = m_atrCacheTime[0];
   
   for(int i = 1; i < m_atrCacheSize; i++)
   {
      if(m_atrCacheTime[i] < oldestTime)
      {
         oldestTime = m_atrCacheTime[i];
         oldestIndex = i;
      }
   }
   
   // Store new value
   m_cachedATR[oldestIndex] = value;
   m_atrCacheTime[oldestIndex] = TimeCurrent();
}

bool CPerformanceEngine::IsPerformanceAcceptable()
{
   // Check key performance indicators
   if(m_metrics.p99Latency > 1000) // More than 1ms
   {
      Print("PERF WARNING: High latency detected: ", m_metrics.p99Latency, " microseconds");
      return false;
   }
   
   if(m_metrics.errorRate > 1.0) // More than 1% error rate
   {
      Print("PERF WARNING: High error rate: ", m_metrics.errorRate, "%");
      return false;
   }
   
   if(m_signalPool.GetUtilization() > 90.0) // More than 90% pool utilization
   {
      Print("PERF WARNING: High memory pool utilization: ", m_signalPool.GetUtilization(), "%");
      return false;
   }
   
   return true;
}

string CPerformanceEngine::GetPerformanceReport()
{
   string report = StringFormat(
      "PERFORMANCE REPORT:\n" +
      "Latency (μs): P50=%d, P95=%d, P99=%d, Max=%d\n" +
      "Throughput: Ticks/s=%d, Signals/s=%d, Trades/s=%d\n" +
      "Memory: Usage=%d bytes, Signal Pool=%.1f%%, Trade Pool=%.1f%%\n" +
      "Quality: Success=%.2f%%, Error=%.2f%%, Total Ops=%d",
      (int)m_metrics.p50Latency, (int)m_metrics.p95Latency, 
      (int)m_metrics.p99Latency, (int)m_metrics.maxLatency,
      m_metrics.ticksPerSecond, m_metrics.signalsPerSecond, m_metrics.tradesPerSecond,
      (int)m_metrics.memoryUsage, m_signalPool.GetUtilization(), m_tradePool.GetUtilization(),
      m_metrics.successRate, m_metrics.errorRate, (int)m_metrics.totalOperations
   );
   
   return report;
}

void CPerformanceEngine::ResetCounters()
{
   // Reset operation and error counters
   ArrayInitialize(m_operationCounts, 0);
   ArrayInitialize(m_errorCounts, 0);
   
   // Reset latency buffer
   ArrayInitialize(m_latencyBuffer, 0);
   m_latencyIndex = 0;
   
   // Reset metrics
   m_metrics.maxLatency = 0;
   m_metrics.totalOperations = 0;
   
   m_lastResetTime = TimeCurrent();
   
   Print("PERF: Performance counters reset");
}

//+------------------------------------------------------------------+
//| GLOBAL PERFORMANCE ENGINE INSTANCE                              |
//+------------------------------------------------------------------+
CPerformanceEngine* g_performanceEngine = NULL;

//+------------------------------------------------------------------+
//| PERFORMANCE MACROS FOR EASY PROFILING                           |
//+------------------------------------------------------------------+
#define PERF_START(operation) \
   CPerformanceProfiler __profiler(operation);

#define PERF_END() \
   if(g_performanceEngine != NULL) \
      g_performanceEngine.RecordLatency(__profiler.Stop());

#define PERF_RECORD_OPERATION(type) \
   if(g_performanceEngine != NULL) \
      g_performanceEngine.m_operationCounts[type]++;

#define PERF_RECORD_ERROR(type) \
   if(g_performanceEngine != NULL) \
      g_performanceEngine.m_errorCounts[type]++;