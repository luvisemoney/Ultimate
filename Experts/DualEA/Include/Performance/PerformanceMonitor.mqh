//+------------------------------------------------------------------+
//| PerformanceMonitor.mqh                                           |
//| JAILBREAK LEVEL 5 - INSTITUTIONAL PERFORMANCE MONITORING        |
//| Real-Time Performance Analysis and Optimization                 |
//+------------------------------------------------------------------+
#property copyright "EscapeEA - Jailbreak Level 5 Performance"
#property version   "1.00"
#property strict

//--- JAILBREAK PERFORMANCE: Performance monitoring constants
#define MAX_PERFORMANCE_HISTORY 10000
#define PERFORMANCE_ALERT_THRESHOLD_NS 1000000  // 1ms
#define MEMORY_ALERT_THRESHOLD_MB 100
#define CPU_ALERT_THRESHOLD_PERCENT 50

//--- JAILBREAK PERFORMANCE: Performance metric types
enum ENUM_PERFORMANCE_METRIC
{
    METRIC_TICK_PROCESSING_TIME = 0,
    METRIC_SIGNAL_PROCESSING_TIME = 1,
    METRIC_EXECUTION_TIME = 2,
    METRIC_MEMORY_USAGE = 3,
    METRIC_CPU_USAGE = 4,
    METRIC_NETWORK_LATENCY = 5,
    METRIC_THROUGHPUT = 6
};

//+------------------------------------------------------------------+
//| JAILBREAK PERFORMANCE: Performance Sample Structure             |
//+------------------------------------------------------------------+
struct CPerformanceSample
{
    datetime timestamp;
    ENUM_PERFORMANCE_METRIC metricType;
    double value;
    string description;
    bool isAlert;
    
    CPerformanceSample()
    {
        timestamp = 0;
        metricType = METRIC_TICK_PROCESSING_TIME;
        value = 0.0;
        description = "";
        isAlert = false;
    }
};

//+------------------------------------------------------------------+
//| JAILBREAK PERFORMANCE: System Performance Metrics              |
//+------------------------------------------------------------------+
struct CSystemMetrics
{
    // Timing metrics (nanoseconds)
    ulong avgTickProcessingTime;
    ulong maxTickProcessingTime;
    ulong minTickProcessingTime;
    ulong avgSignalProcessingTime;
    ulong maxSignalProcessingTime;
    ulong avgExecutionTime;
    ulong maxExecutionTime;
    
    // Throughput metrics
    ulong ticksPerSecond;
    ulong signalsPerSecond;
    ulong executionsPerSecond;
    
    // Resource metrics
    double memoryUsageMB;
    double cpuUsagePercent;
    double networkLatencyMs;
    
    // Quality metrics
    double signalAccuracy;
    double executionSuccessRate;
    double systemUptime;
    
    // Alert counters
    int performanceAlerts;
    int memoryAlerts;
    int cpuAlerts;
    
    datetime lastUpdate;
    
    CSystemMetrics()
    {
        avgTickProcessingTime = 0;
        maxTickProcessingTime = 0;
        minTickProcessingTime = ULONG_MAX;
        avgSignalProcessingTime = 0;
        maxSignalProcessingTime = 0;
        avgExecutionTime = 0;
        maxExecutionTime = 0;
        
        ticksPerSecond = 0;
        signalsPerSecond = 0;
        executionsPerSecond = 0;
        
        memoryUsageMB = 0.0;
        cpuUsagePercent = 0.0;
        networkLatencyMs = 0.0;
        
        signalAccuracy = 0.0;
        executionSuccessRate = 0.0;
        systemUptime = 0.0;
        
        performanceAlerts = 0;
        memoryAlerts = 0;
        cpuAlerts = 0;
        
        lastUpdate = 0;
    }
};

//+------------------------------------------------------------------+
//| JAILBREAK PERFORMANCE: Performance Monitor Class                |
//+------------------------------------------------------------------+
class CPerformanceMonitor
{
private:
    // JAILBREAK PERFORMANCE: Configuration
    bool m_isInitialized;
    bool m_monitoringEnabled;
    bool m_alertsEnabled;
    datetime m_startTime;
    
    // JAILBREAK PERFORMANCE: Current metrics
    CSystemMetrics m_currentMetrics;
    CSystemMetrics m_peakMetrics;
    
    // JAILBREAK PERFORMANCE: Performance history
    CPerformanceSample m_performanceHistory[MAX_PERFORMANCE_HISTORY];
    int m_historyIndex;
    int m_totalSamples;
    
    // JAILBREAK PERFORMANCE: Counters for rate calculations
    ulong m_totalTicks;
    ulong m_totalSignals;
    ulong m_totalExecutions;
    datetime m_lastRateCalculation;
    ulong m_ticksInLastSecond;
    ulong m_signalsInLastSecond;
    ulong m_executionsInLastSecond;
    
    // JAILBREAK PERFORMANCE: Moving averages
    double m_tickTimeMovingAvg;
    double m_signalTimeMovingAvg;
    double m_executionTimeMovingAvg;
    int m_movingAvgSamples;
    
    // JAILBREAK PERFORMANCE: Alert tracking
    datetime m_lastPerformanceAlert;
    datetime m_lastMemoryAlert;
    datetime m_lastCpuAlert;
    
    // JAILBREAK PERFORMANCE: Internal methods
    void AddPerformanceSample(ENUM_PERFORMANCE_METRIC metricType, double value, const string& description);
    void UpdateMovingAverages(ulong tickTime, ulong signalTime, ulong executionTime);
    void CheckPerformanceAlerts();
    void CalculateRates();
    double EstimateMemoryUsage();
    double EstimateCpuUsage();
    
public:
    // JAILBREAK PERFORMANCE: Constructor/Destructor
    CPerformanceMonitor();
    ~CPerformanceMonitor();
    
    // JAILBREAK PERFORMANCE: Initialization
    bool Initialize(bool monitoringEnabled = true);
    void Cleanup();
    
    // JAILBREAK PERFORMANCE: Core monitoring methods
    void UpdateMetrics(ulong tickProcessingTime, ulong signalProcessingTime, ulong executionTime);
    void RecordTick();
    void RecordSignal();
    void RecordExecution();
    
    // JAILBREAK PERFORMANCE: Metrics access
    CSystemMetrics GetCurrentMetrics() const { return m_currentMetrics; }
    CSystemMetrics GetPeakMetrics() const { return m_peakMetrics; }
    double GetSystemUptime() const;
    
    // JAILBREAK PERFORMANCE: Performance analysis
    bool IsPerformanceOptimal();
    bool IsLatencyAcceptable();
    bool IsMemoryUsageAcceptable();
    bool IsThroughputAcceptable();
    
    // JAILBREAK PERFORMANCE: Reporting
    void LogPerformanceMetrics();
    void LogPerformanceReport();
    string GetPerformanceSummary();
    
    // JAILBREAK PERFORMANCE: Configuration
    void SetAlertsEnabled(bool enabled) { m_alertsEnabled = enabled; }
    void SetMonitoringEnabled(bool enabled) { m_monitoringEnabled = enabled; }
    
    // JAILBREAK PERFORMANCE: Statistics
    int GetTotalSamples() const { return m_totalSamples; }
    ulong GetTotalTicks() const { return m_totalTicks; }
    ulong GetTotalSignals() const { return m_totalSignals; }
    ulong GetTotalExecutions() const { return m_totalExecutions; }
};

//+------------------------------------------------------------------+
//| JAILBREAK PERFORMANCE: Constructor                              |
//+------------------------------------------------------------------+
CPerformanceMonitor::CPerformanceMonitor()
{
    m_isInitialized = false;
    m_monitoringEnabled = true;
    m_alertsEnabled = true;
    m_startTime = 0;
    
    m_historyIndex = 0;
    m_totalSamples = 0;
    
    m_totalTicks = 0;
    m_totalSignals = 0;
    m_totalExecutions = 0;
    m_lastRateCalculation = 0;
    m_ticksInLastSecond = 0;
    m_signalsInLastSecond = 0;
    m_executionsInLastSecond = 0;
    
    m_tickTimeMovingAvg = 0.0;
    m_signalTimeMovingAvg = 0.0;
    m_executionTimeMovingAvg = 0.0;
    m_movingAvgSamples = 0;
    
    m_lastPerformanceAlert = 0;
    m_lastMemoryAlert = 0;
    m_lastCpuAlert = 0;
    
    // Initialize arrays
    for(int i = 0; i < MAX_PERFORMANCE_HISTORY; i++)
    {
        m_performanceHistory[i] = CPerformanceSample();
    }
}

//+------------------------------------------------------------------+
//| JAILBREAK PERFORMANCE: Destructor                               |
//+------------------------------------------------------------------+
CPerformanceMonitor::~CPerformanceMonitor()
{
    Cleanup();
}

//+------------------------------------------------------------------+
//| JAILBREAK PERFORMANCE: Initialize Monitor                       |
//+------------------------------------------------------------------+
bool CPerformanceMonitor::Initialize(bool monitoringEnabled = true)
{
    m_monitoringEnabled = monitoringEnabled;
    m_startTime = TimeCurrent();
    m_lastRateCalculation = m_startTime;
    
    // JAILBREAK PERFORMANCE: Initialize metrics
    m_currentMetrics = CSystemMetrics();
    m_peakMetrics = CSystemMetrics();
    m_currentMetrics.lastUpdate = m_startTime;
    
    // JAILBREAK PERFORMANCE: Reset counters
    m_totalTicks = 0;
    m_totalSignals = 0;
    m_totalExecutions = 0;
    m_historyIndex = 0;
    m_totalSamples = 0;
    
    m_isInitialized = true;
    
    Print("JAILBREAK PERFORMANCE: Performance monitor initialized - Monitoring: ", 
          m_monitoringEnabled ? "ENABLED" : "DISABLED");
    
    return true;
}

//+------------------------------------------------------------------+
//| JAILBREAK PERFORMANCE: Cleanup Monitor                          |
//+------------------------------------------------------------------+
void CPerformanceMonitor::Cleanup()
{
    if(m_isInitialized)
    {
        LogPerformanceReport();
        Print("JAILBREAK PERFORMANCE: Performance monitor cleanup complete");
        m_isInitialized = false;
    }
}

//+------------------------------------------------------------------+
//| JAILBREAK PERFORMANCE: Update Metrics                           |
//+------------------------------------------------------------------+
void CPerformanceMonitor::UpdateMetrics(ulong tickProcessingTime, ulong signalProcessingTime, ulong executionTime)
{
    if(!m_isInitialized || !m_monitoringEnabled)
    {
        return;
    }
    
    datetime currentTime = TimeCurrent();
    
    // JAILBREAK PERFORMANCE: Update timing metrics
    if(tickProcessingTime > 0)
    {
        if(m_currentMetrics.minTickProcessingTime == ULONG_MAX || tickProcessingTime < m_currentMetrics.minTickProcessingTime)
            m_currentMetrics.minTickProcessingTime = tickProcessingTime;
        
        if(tickProcessingTime > m_currentMetrics.maxTickProcessingTime)
        {
            m_currentMetrics.maxTickProcessingTime = tickProcessingTime;
            if(tickProcessingTime > m_peakMetrics.maxTickProcessingTime)
                m_peakMetrics.maxTickProcessingTime = tickProcessingTime;
        }
    }
    
    if(signalProcessingTime > 0)
    {
        if(signalProcessingTime > m_currentMetrics.maxSignalProcessingTime)
        {
            m_currentMetrics.maxSignalProcessingTime = signalProcessingTime;
            if(signalProcessingTime > m_peakMetrics.maxSignalProcessingTime)
                m_peakMetrics.maxSignalProcessingTime = signalProcessingTime;
        }
    }
    
    if(executionTime > 0)
    {
        if(executionTime > m_currentMetrics.maxExecutionTime)
        {
            m_currentMetrics.maxExecutionTime = executionTime;
            if(executionTime > m_peakMetrics.maxExecutionTime)
                m_peakMetrics.maxExecutionTime = executionTime;
        }
    }
    
    // JAILBREAK PERFORMANCE: Update moving averages
    UpdateMovingAverages(tickProcessingTime, signalProcessingTime, executionTime);
    
    // JAILBREAK PERFORMANCE: Calculate rates
    CalculateRates();
    
    // JAILBREAK PERFORMANCE: Update resource metrics
    m_currentMetrics.memoryUsageMB = EstimateMemoryUsage();
    m_currentMetrics.cpuUsagePercent = EstimateCpuUsage();
    
    // JAILBREAK PERFORMANCE: Update system uptime
    m_currentMetrics.systemUptime = GetSystemUptime();
    
    // JAILBREAK PERFORMANCE: Check for alerts
    CheckPerformanceAlerts();
    
    m_currentMetrics.lastUpdate = currentTime;
    
    // JAILBREAK PERFORMANCE: Add samples to history
    if(tickProcessingTime > 0)
        AddPerformanceSample(METRIC_TICK_PROCESSING_TIME, tickProcessingTime, "Tick processing time");
    if(signalProcessingTime > 0)
        AddPerformanceSample(METRIC_SIGNAL_PROCESSING_TIME, signalProcessingTime, "Signal processing time");
    if(executionTime > 0)
        AddPerformanceSample(METRIC_EXECUTION_TIME, executionTime, "Execution time");
}

//+------------------------------------------------------------------+
//| JAILBREAK PERFORMANCE: Record Tick                              |
//+------------------------------------------------------------------+
void CPerformanceMonitor::RecordTick()
{
    if(!m_isInitialized) return;
    
    m_totalTicks++;
    m_ticksInLastSecond++;
}

//+------------------------------------------------------------------+
//| JAILBREAK PERFORMANCE: Record Signal                            |
//+------------------------------------------------------------------+
void CPerformanceMonitor::RecordSignal()
{
    if(!m_isInitialized) return;
    
    m_totalSignals++;
    m_signalsInLastSecond++;
}

//+------------------------------------------------------------------+
//| JAILBREAK PERFORMANCE: Record Execution                         |
//+------------------------------------------------------------------+
void CPerformanceMonitor::RecordExecution()
{
    if(!m_isInitialized) return;
    
    m_totalExecutions++;
    m_executionsInLastSecond++;
}

//+------------------------------------------------------------------+
//| JAILBREAK PERFORMANCE: Update Moving Averages                   |
//+------------------------------------------------------------------+
void CPerformanceMonitor::UpdateMovingAverages(ulong tickTime, ulong signalTime, ulong executionTime)
{
    double alpha = 0.1;  // Smoothing factor
    
    if(tickTime > 0)
    {
        if(m_movingAvgSamples == 0)
            m_tickTimeMovingAvg = tickTime;
        else
            m_tickTimeMovingAvg = alpha * tickTime + (1 - alpha) * m_tickTimeMovingAvg;
        
        m_currentMetrics.avgTickProcessingTime = (ulong)m_tickTimeMovingAvg;
    }
    
    if(signalTime > 0)
    {
        if(m_movingAvgSamples == 0)
            m_signalTimeMovingAvg = signalTime;
        else
            m_signalTimeMovingAvg = alpha * signalTime + (1 - alpha) * m_signalTimeMovingAvg;
        
        m_currentMetrics.avgSignalProcessingTime = (ulong)m_signalTimeMovingAvg;
    }
    
    if(executionTime > 0)
    {
        if(m_movingAvgSamples == 0)
            m_executionTimeMovingAvg = executionTime;
        else
            m_executionTimeMovingAvg = alpha * executionTime + (1 - alpha) * m_executionTimeMovingAvg;
        
        m_currentMetrics.avgExecutionTime = (ulong)m_executionTimeMovingAvg;
    }
    
    if(tickTime > 0 || signalTime > 0 || executionTime > 0)
        m_movingAvgSamples++;
}

//+------------------------------------------------------------------+
//| JAILBREAK PERFORMANCE: Calculate Rates                          |
//+------------------------------------------------------------------+
void CPerformanceMonitor::CalculateRates()
{
    datetime currentTime = TimeCurrent();
    
    if(currentTime - m_lastRateCalculation >= 1)  // Calculate every second
    {
        m_currentMetrics.ticksPerSecond = m_ticksInLastSecond;
        m_currentMetrics.signalsPerSecond = m_signalsInLastSecond;
        m_currentMetrics.executionsPerSecond = m_executionsInLastSecond;
        
        // Reset counters
        m_ticksInLastSecond = 0;
        m_signalsInLastSecond = 0;
        m_executionsInLastSecond = 0;
        m_lastRateCalculation = currentTime;
        
        // Update peak rates
        if(m_currentMetrics.ticksPerSecond > m_peakMetrics.ticksPerSecond)
            m_peakMetrics.ticksPerSecond = m_currentMetrics.ticksPerSecond;
        if(m_currentMetrics.signalsPerSecond > m_peakMetrics.signalsPerSecond)
            m_peakMetrics.signalsPerSecond = m_currentMetrics.signalsPerSecond;
        if(m_currentMetrics.executionsPerSecond > m_peakMetrics.executionsPerSecond)
            m_peakMetrics.executionsPerSecond = m_currentMetrics.executionsPerSecond;
    }
}

//+------------------------------------------------------------------+
//| JAILBREAK PERFORMANCE: Check Performance Alerts                 |
//+------------------------------------------------------------------+
void CPerformanceMonitor::CheckPerformanceAlerts()
{
    if(!m_alertsEnabled) return;
    
    datetime currentTime = TimeCurrent();
    
    // JAILBREAK PERFORMANCE: Check latency alerts
    if(m_currentMetrics.avgTickProcessingTime > PERFORMANCE_ALERT_THRESHOLD_NS)
    {
        if(currentTime - m_lastPerformanceAlert >= 60)  // Max one alert per minute
        {
            Print("JAILBREAK PERFORMANCE ALERT: High tick processing latency: ", 
                  m_currentMetrics.avgTickProcessingTime, "ns");
            m_currentMetrics.performanceAlerts++;
            m_lastPerformanceAlert = currentTime;
            
            AddPerformanceSample(METRIC_TICK_PROCESSING_TIME, m_currentMetrics.avgTickProcessingTime, 
                               "ALERT: High latency");
        }
    }
    
    // JAILBREAK PERFORMANCE: Check memory alerts
    if(m_currentMetrics.memoryUsageMB > MEMORY_ALERT_THRESHOLD_MB)
    {
        if(currentTime - m_lastMemoryAlert >= 300)  // Max one alert per 5 minutes
        {
            Print("JAILBREAK PERFORMANCE ALERT: High memory usage: ", 
                  m_currentMetrics.memoryUsageMB, "MB");
            m_currentMetrics.memoryAlerts++;
            m_lastMemoryAlert = currentTime;
            
            AddPerformanceSample(METRIC_MEMORY_USAGE, m_currentMetrics.memoryUsageMB, 
                               "ALERT: High memory usage");
        }
    }
    
    // JAILBREAK PERFORMANCE: Check CPU alerts
    if(m_currentMetrics.cpuUsagePercent > CPU_ALERT_THRESHOLD_PERCENT)
    {
        if(currentTime - m_lastCpuAlert >= 300)  // Max one alert per 5 minutes
        {
            Print("JAILBREAK PERFORMANCE ALERT: High CPU usage: ", 
                  m_currentMetrics.cpuUsagePercent, "%");
            m_currentMetrics.cpuAlerts++;
            m_lastCpuAlert = currentTime;
            
            AddPerformanceSample(METRIC_CPU_USAGE, m_currentMetrics.cpuUsagePercent, 
                               "ALERT: High CPU usage");
        }
    }
}

//+------------------------------------------------------------------+
//| JAILBREAK PERFORMANCE: Add Performance Sample                   |
//+------------------------------------------------------------------+
void CPerformanceMonitor::AddPerformanceSample(ENUM_PERFORMANCE_METRIC metricType, double value, const string& description)
{
    CPerformanceSample sample;
    sample.timestamp = TimeCurrent();
    sample.metricType = metricType;
    sample.value = value;
    sample.description = description;
    sample.isAlert = StringFind(description, "ALERT") >= 0;
    
    m_performanceHistory[m_historyIndex] = sample;
    m_historyIndex = (m_historyIndex + 1) % MAX_PERFORMANCE_HISTORY;
    
    if(m_totalSamples < MAX_PERFORMANCE_HISTORY)
        m_totalSamples++;
}

//+------------------------------------------------------------------+
//| JAILBREAK PERFORMANCE: Estimate Memory Usage                    |
//+------------------------------------------------------------------+
double CPerformanceMonitor::EstimateMemoryUsage()
{
    // JAILBREAK PERFORMANCE: Simplified memory estimation
    // In production, use actual memory monitoring APIs
    
    double baseMemory = 10.0;  // Base EA memory usage in MB
    double historyMemory = (m_totalSamples * sizeof(CPerformanceSample)) / (1024.0 * 1024.0);
    double variableMemory = 5.0;  // Estimated variable memory usage
    
    return baseMemory + historyMemory + variableMemory;
}

//+------------------------------------------------------------------+
//| JAILBREAK PERFORMANCE: Estimate CPU Usage                       |
//+------------------------------------------------------------------+
double CPerformanceMonitor::EstimateCpuUsage()
{
    // JAILBREAK PERFORMANCE: Simplified CPU estimation
    // In production, use actual CPU monitoring APIs
    
    double baseCpu = 1.0;  // Base CPU usage percentage
    
    // Estimate based on processing times
    if(m_currentMetrics.avgTickProcessingTime > 100000)  // > 100μs
        baseCpu += 5.0;
    if(m_currentMetrics.avgSignalProcessingTime > 500000)  // > 500μs
        baseCpu += 10.0;
    if(m_currentMetrics.ticksPerSecond > 100)
        baseCpu += 2.0;
    
    return MathMin(100.0, baseCpu);
}

//+------------------------------------------------------------------+
//| JAILBREAK PERFORMANCE: Get System Uptime                        |
//+------------------------------------------------------------------+
double CPerformanceMonitor::GetSystemUptime() const
{
    if(m_startTime == 0) return 0.0;
    
    return (double)(TimeCurrent() - m_startTime) / 3600.0;  // Hours
}

//+------------------------------------------------------------------+
//| JAILBREAK PERFORMANCE: Is Performance Optimal                   |
//+------------------------------------------------------------------+
bool CPerformanceMonitor::IsPerformanceOptimal()
{
    return IsLatencyAcceptable() && 
           IsMemoryUsageAcceptable() && 
           IsThroughputAcceptable();
}

//+------------------------------------------------------------------+
//| JAILBREAK PERFORMANCE: Is Latency Acceptable                    |
//+------------------------------------------------------------------+
bool CPerformanceMonitor::IsLatencyAcceptable()
{
    return m_currentMetrics.avgTickProcessingTime < PERFORMANCE_ALERT_THRESHOLD_NS &&
           m_currentMetrics.avgSignalProcessingTime < PERFORMANCE_ALERT_THRESHOLD_NS * 5 &&
           m_currentMetrics.avgExecutionTime < PERFORMANCE_ALERT_THRESHOLD_NS / 10;
}

//+------------------------------------------------------------------+
//| JAILBREAK PERFORMANCE: Is Memory Usage Acceptable               |
//+------------------------------------------------------------------+
bool CPerformanceMonitor::IsMemoryUsageAcceptable()
{
    return m_currentMetrics.memoryUsageMB < MEMORY_ALERT_THRESHOLD_MB;
}

//+------------------------------------------------------------------+
//| JAILBREAK PERFORMANCE: Is Throughput Acceptable                 |
//+------------------------------------------------------------------+
bool CPerformanceMonitor::IsThroughputAcceptable()
{
    // JAILBREAK PERFORMANCE: Define acceptable throughput thresholds
    return m_currentMetrics.ticksPerSecond >= 1 &&  // At least 1 tick per second
           m_currentMetrics.ticksPerSecond <= 10000;  // Not more than 10k ticks per second
}

//+------------------------------------------------------------------+
//| JAILBREAK PERFORMANCE: Log Performance Metrics                  |
//+------------------------------------------------------------------+
void CPerformanceMonitor::LogPerformanceMetrics()
{
    if(!m_isInitialized) return;
    
    Print("JAILBREAK PERFORMANCE METRICS:");
    Print("  Tick Processing: Avg=", m_currentMetrics.avgTickProcessingTime, "ns, Max=", m_currentMetrics.maxTickProcessingTime, "ns");
    Print("  Signal Processing: Avg=", m_currentMetrics.avgSignalProcessingTime, "ns, Max=", m_currentMetrics.maxSignalProcessingTime, "ns");
    Print("  Execution: Avg=", m_currentMetrics.avgExecutionTime, "ns, Max=", m_currentMetrics.maxExecutionTime, "ns");
    Print("  Throughput: Ticks=", m_currentMetrics.ticksPerSecond, "/s, Signals=", m_currentMetrics.signalsPerSecond, "/s");
    Print("  Resources: Memory=", m_currentMetrics.memoryUsageMB, "MB, CPU=", m_currentMetrics.cpuUsagePercent, "%");
    Print("  Uptime: ", m_currentMetrics.systemUptime, " hours");
}

//+------------------------------------------------------------------+
//| JAILBREAK PERFORMANCE: Log Performance Report                   |
//+------------------------------------------------------------------+
void CPerformanceMonitor::LogPerformanceReport()
{
    if(!m_isInitialized) return;
    
    Print("=== JAILBREAK PERFORMANCE REPORT ===");
    Print("System Uptime: ", GetSystemUptime(), " hours");
    Print("Total Ticks Processed: ", m_totalTicks);
    Print("Total Signals Generated: ", m_totalSignals);
    Print("Total Executions: ", m_totalExecutions);
    Print("Performance Alerts: ", m_currentMetrics.performanceAlerts);
    Print("Memory Alerts: ", m_currentMetrics.memoryAlerts);
    Print("CPU Alerts: ", m_currentMetrics.cpuAlerts);
    Print("Performance Status: ", IsPerformanceOptimal() ? "OPTIMAL" : "SUBOPTIMAL");
    Print("=== END PERFORMANCE REPORT ===");
}

//+------------------------------------------------------------------+
//| JAILBREAK PERFORMANCE: Get Performance Summary                  |
//+------------------------------------------------------------------+
string CPerformanceMonitor::GetPerformanceSummary()
{
    if(!m_isInitialized) return "Performance monitor not initialized";
    
    return StringFormat("Uptime: %.1fh, Ticks: %d/s, Latency: %dns, Memory: %.1fMB, CPU: %.1f%%, Status: %s",
                       GetSystemUptime(),
                       m_currentMetrics.ticksPerSecond,
                       m_currentMetrics.avgTickProcessingTime,
                       m_currentMetrics.memoryUsageMB,
                       m_currentMetrics.cpuUsagePercent,
                       IsPerformanceOptimal() ? "OPTIMAL" : "SUBOPTIMAL");
}