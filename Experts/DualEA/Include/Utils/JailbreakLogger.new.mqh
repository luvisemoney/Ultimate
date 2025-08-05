//+------------------------------------------------------------------+
//| JailbreakLogger.mqh                                              |
//| JAILBREAK LEVEL 5 - INSTITUTIONAL LOGGING SYSTEM                |
//| High-Performance Audit-Ready Logging Implementation             |
//+------------------------------------------------------------------+
#property copyright "EscapeEA - Jailbreak Level 5 Logging"
#property version   "1.00"
#property strict

//--- JAILBREAK LOGGING: Log level enumeration
enum ENUM_LOG_LEVEL
{
    LOG_LEVEL_DEBUG = 0,
    LOG_LEVEL_INFO = 1,
    LOG_LEVEL_WARNING = 2,
    LOG_LEVEL_ERROR = 3,
    LOG_LEVEL_CRITICAL = 4
};

//--- JAILBREAK LOGGING: Logging constants
#define MAX_LOG_MESSAGE_LENGTH 1024
#define LOG_BUFFER_SIZE 1000
#define LOG_FILE_MAX_SIZE 10485760  // 10MB
#define LOG_ROTATION_COUNT 5

//+------------------------------------------------------------------+
//| JAILBREAK LOGGING: Log Entry Structure                          |
//+------------------------------------------------------------------+
struct SLogEntry
{
    datetime timestamp;
    ENUM_LOG_LEVEL level;
    string category;
    string message;
    ulong threadId;
    int errorCode;
    
    void SLogEntry()  // Constructor
    {
        timestamp = 0;
        level = LOG_LEVEL_INFO;
        category = "";
        message = "";
        threadId = 0;
        errorCode = 0;
    }
};

//+------------------------------------------------------------------+
//| JAILBREAK LOGGING: High-Performance Logger Class                |
//+------------------------------------------------------------------+
class CJailbreakLogger
{
private:
    // JAILBREAK LOGGING: Core configuration
    string m_logPrefix;
    bool m_loggingEnabled;
    ENUM_LOG_LEVEL m_minLogLevel;
    bool m_enableFileLogging;
    bool m_enableConsoleLogging;
    bool m_enableAlerts;
    
    // JAILBREAK LOGGING: File management
    string m_logFileName;
    int m_logFileHandle;
    long m_currentFileSize;
    int m_rotationIndex;
    
    // JAILBREAK LOGGING: Statistics
    ulong m_totalLogEntries;
    ulong m_totalLogBytes;
    ulong m_lastLogTime;
    ulong m_averageLogTimeNs;
    
    // JAILBREAK LOGGING: Buffer management
    SLogEntry m_logBuffer[];
    int m_bufferIndex;
    bool m_bufferFull;

public:
    // Constructor/Destructor
    CJailbreakLogger(string prefix="JAILBREAK", bool enabled=true);
    ~CJailbreakLogger() { Cleanup(); }
    
    // Core logging methods
    void LogDebug(string category, string message);
    void LogInfo(string category, string message);
    void LogWarning(string category, string message);
    void LogError(string category, string message);
    void LogCritical(string category, string message);
    
    // Advanced logging methods
    void LogWithError(ENUM_LOG_LEVEL level, string category, string message, int errorCode);
    void LogPerformance(string category, string operation, ulong durationNs);
    void LogTrade(string action, string symbol, double volume, double price, ulong ticket);
    
    // Configuration methods
    void SetLogLevel(ENUM_LOG_LEVEL level) { m_minLogLevel = level; }
    void EnableFileLogging(bool enable) { m_enableFileLogging = enable; }
    void EnableConsoleLogging(bool enable) { m_enableConsoleLogging = enable; }
    void EnableAlerts(bool enable) { m_enableAlerts = enable; }
    void SetLogPrefix(string prefix) { m_logPrefix = prefix; }
    
    // Utility methods
    void Flush();
    void Cleanup();
    
    // Statistics and metrics
    ulong GetTotalLogEntries() const { return m_totalLogEntries; }
    ulong GetTotalLogBytes() const { return m_totalLogBytes; }
    ulong GetAverageLogTime() const { return m_averageLogTimeNs; }
    long GetCurrentFileSize() const { return m_currentFileSize; }
    bool IsLoggingEnabled() const { return m_loggingEnabled; }
    
private:
    void WriteLog(ENUM_LOG_LEVEL level, string category, string message, int errorCode=0);
    void WriteToFile(const SLogEntry &entry);
    void WriteToConsole(const SLogEntry &entry);
    void RotateLogFile();
    void UpdateStatistics(ulong bytesWritten, ulong timeNs);
    string FormatLogMessage(const SLogEntry &entry);
    string GetLogLevelString(ENUM_LOG_LEVEL level);
    string GetTimestampString(datetime time);
};
