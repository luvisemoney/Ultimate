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
    
    // JAILBREAK LOGGING: Buffered logging
    SLogEntry m_logBuffer[];
    int m_logBufferIndex;
    bool m_enableAlerts;
    
    // JAILBREAK LOGGING: File management
    string m_logFileName;
    int m_logFileHandle;
    long m_currentFileSize;
    int m_rotationIndex;
    
    // JAILBREAK LOGGING: Performance tracking
    ulong m_totalLogEntries;
    ulong m_totalLogBytes;
    datetime m_lastLogTime;
    ulong m_averageLogTimeNs;
    
    // JAILBREAK LOGGING: Buffer management
    SLogEntry m_logBuffer[LOG_BUFFER_SIZE];
    int m_bufferIndex;
    bool m_bufferFull;
    
    // JAILBREAK LOGGING: Internal methods
    string FormatLogMessage(ENUM_LOG_LEVEL level, const string& category, const string& message);
    string GetLogLevelString(ENUM_LOG_LEVEL level);
    bool WriteToFile(const string& message);
    bool RotateLogFile();
    void FlushBuffer();
    bool ShouldLog(ENUM_LOG_LEVEL level);
    
public:
    // JAILBREAK LOGGING: Constructor/Destructor
    CJailbreakLogger(const string& prefix = "JAILBREAK", bool enabled = true);
    ~CJailbreakLogger();
    
    // JAILBREAK LOGGING: Initialization and configuration
    bool Initialize();
    void SetMinLogLevel(ENUM_LOG_LEVEL level) { m_minLogLevel = level; }
    void SetFileLogging(bool enabled) { m_enableFileLogging = enabled; }
    void SetConsoleLogging(bool enabled) { m_enableConsoleLogging = enabled; }
    void SetAlerts(bool enabled) { m_enableAlerts = enabled; }
    
    // JAILBREAK LOGGING: Core logging methods
    void LogDebug(const string& category, const string& message);
    void LogInfo(const string& category, const string& message);
    void LogWarning(const string& category, const string& message);
    void LogError(const string& category, const string& message);
    void LogCritical(const string& category, const string& message);
    
    // JAILBREAK LOGGING: Advanced logging methods
    void LogWithError(ENUM_LOG_LEVEL level, const string& category, const string& message, int errorCode);
    void LogPerformance(const string& category, const string& operation, ulong durationNs);
    void LogTrade(const string& action, const string& symbol, double volume, double price, ulong ticket);
    
    // JAILBREAK LOGGING: Utility methods
    void Flush();
    void Cleanup();
    
    // JAILBREAK LOGGING: Statistics and metrics
    ulong GetTotalLogEntries() const { return m_totalLogEntries; }
    ulong GetTotalLogBytes() const { return m_totalLogBytes; }
    ulong GetAverageLogTime() const { return m_averageLogTimeNs; }
    long GetCurrentFileSize() const { return m_currentFileSize; }
    bool IsLoggingEnabled() const { return m_loggingEnabled; }
};

//+------------------------------------------------------------------+
//| JAILBREAK LOGGING: Constructor                                   |
//+------------------------------------------------------------------+
CJailbreakLogger::CJailbreakLogger(const string prefix = "JAILBREAK", bool enabled = true)
{
    m_logPrefix = prefix;
    m_loggingEnabled = enabled;
    m_minLogLevel = LOG_LEVEL_INFO;
    m_enableFileLogging = true;
    m_enableConsoleLogging = true;
    m_enableAlerts = false;
    
    m_logFileName = "";
    m_logFileHandle = INVALID_HANDLE;
    m_currentFileSize = 0;
    m_rotationIndex = 0;
    
    m_totalLogEntries = 0;
    m_totalLogBytes = 0;
    m_lastLogTime = 0;
    m_averageLogTimeNs = 0;
    
    m_bufferIndex = 0;
    m_bufferFull = false;
    
    // Initialize buffer
    for(int i = 0; i < LOG_BUFFER_SIZE; i++)
    {
        m_logBuffer[i].timestamp = 0;
        m_logBuffer[i].level = LOG_LEVEL_INFO;
        m_logBuffer[i].category = "";
        m_logBuffer[i].message = "";
        m_logBuffer[i].threadId = 0;
        m_logBuffer[i].errorCode = 0;
    }
}

//+------------------------------------------------------------------+
//| JAILBREAK LOGGING: Destructor                                   |
//+------------------------------------------------------------------+
CJailbreakLogger::~CJailbreakLogger()
{
    Cleanup();
}

//+------------------------------------------------------------------+
//| JAILBREAK LOGGING: Initialize Logger                            |
//+------------------------------------------------------------------+
bool CJailbreakLogger::Initialize()
{
    if(!m_loggingEnabled) return true;
    
    // JAILBREAK LOGGING: Create log file name with timestamp
    MqlDateTime timeStruct;
    TimeToStruct(TimeCurrent(), timeStruct);
    
    m_logFileName = StringFormat("%s_%04d%02d%02d_%02d%02d%02d.log",
                                m_logPrefix,
                                timeStruct.year, timeStruct.mon, timeStruct.day,
                                timeStruct.hour, timeStruct.min, timeStruct.sec);
    
    // JAILBREAK LOGGING: Open log file
    if(m_enableFileLogging)
    {
        m_logFileHandle = FileOpen(m_logFileName, FILE_WRITE | FILE_TXT | FILE_ANSI);
        if(m_logFileHandle == INVALID_HANDLE)
        {
            Print("JAILBREAK LOGGING ERROR: Failed to open log file: ", m_logFileName);
            m_enableFileLogging = false;
        }
        else
        {
            // JAILBREAK LOGGING: Write header
            string header = StringFormat("=== JAILBREAK LEVEL 5 LOGGING STARTED - %s ===\n", 
                                       TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS));
            FileWrite(m_logFileHandle, header);
            FileFlush(m_logFileHandle);
        }
    }
    
    // JAILBREAK LOGGING: Log initialization
    LogInfo("LOGGER", "Jailbreak Level 5 logger initialized successfully");
    
    return true;
}

//+------------------------------------------------------------------+
//| JAILBREAK LOGGING: Log Debug Message                            |
//+------------------------------------------------------------------+
void CJailbreakLogger::LogDebug(const string& category, const string& message)
{
    if(ShouldLog(LOG_LEVEL_DEBUG))
    {
        LogWithError(LOG_LEVEL_DEBUG, category, message, 0);
    }
}

//+------------------------------------------------------------------+
//| JAILBREAK LOGGING: Log Info Message                             |
//+------------------------------------------------------------------+
void CJailbreakLogger::LogInfo(const string& category, const string& message)
{
    if(ShouldLog(LOG_LEVEL_INFO))
    {
        LogWithError(LOG_LEVEL_INFO, category, message, 0);
    }
}

//+------------------------------------------------------------------+
//| JAILBREAK LOGGING: Log Warning Message                          |
//+------------------------------------------------------------------+
void CJailbreakLogger::LogWarning(const string& category, const string& message)
{
    if(ShouldLog(LOG_LEVEL_WARNING))
    {
        LogWithError(LOG_LEVEL_WARNING, category, message, 0);
    }
}

//+------------------------------------------------------------------+
//| JAILBREAK LOGGING: Log Error Message                            |
//+------------------------------------------------------------------+
void CJailbreakLogger::LogError(const string& category, const string& message)
{
    if(ShouldLog(LOG_LEVEL_ERROR))
    {
        LogWithError(LOG_LEVEL_ERROR, category, message, GetLastError());
    }
}

//+------------------------------------------------------------------+
//| JAILBREAK LOGGING: Log Critical Message                         |
//+------------------------------------------------------------------+
void CJailbreakLogger::LogCritical(const string& category, const string& message)
{
    if(ShouldLog(LOG_LEVEL_CRITICAL))
    {
        LogWithError(LOG_LEVEL_CRITICAL, category, message, GetLastError());
        
        // JAILBREAK LOGGING: Always alert on critical messages
        if(m_enableAlerts)
        {
            Alert("JAILBREAK CRITICAL: ", category, " - ", message);
        }
    }
}

//+------------------------------------------------------------------+
//| JAILBREAK LOGGING: Log With Error Code                          |
//+------------------------------------------------------------------+
void CJailbreakLogger::LogWithError(ENUM_LOG_LEVEL level, const string& category, 
                                   const string& message, int errorCode)
{
    if(!m_loggingEnabled || !ShouldLog(level)) return;
    
    ulong startTime = GetMicrosecondCount();
    
    // JAILBREAK LOGGING: Create log entry
    SLogEntry entry;
    entry.timestamp = TimeCurrent();
    entry.level = level;
    entry.category = category;
    entry.message = message;
    entry.threadId = 0;  // MQL5 doesn't have thread IDs
    entry.errorCode = errorCode;
    
    // JAILBREAK LOGGING: Format message
    string formattedMessage = FormatLogMessage(level, category, message);
    if(errorCode != 0)
    {
        formattedMessage += StringFormat(" [Error: %d]", errorCode);
    }
    
    // JAILBREAK LOGGING: Console output
    if(m_enableConsoleLogging)
    {
        Print(formattedMessage);
    }
    
    // JAILBREAK LOGGING: File output
    if(m_enableFileLogging && m_logFileHandle != INVALID_HANDLE)
    {
        WriteToFile(formattedMessage);
    }
    
    // JAILBREAK LOGGING: Buffer management
    if(m_bufferIndex < LOG_BUFFER_SIZE)
    {
        m_logBuffer[m_bufferIndex] = entry;
        m_bufferIndex++;
    }
    else
    {
        m_bufferFull = true;
        FlushBuffer();
    }
    
    // JAILBREAK LOGGING: Update statistics
    m_totalLogEntries++;
    m_totalLogBytes += StringLen(formattedMessage);
    m_lastLogTime = entry.timestamp;
    
    // JAILBREAK LOGGING: Update average log time
    ulong logTime = GetMicrosecondCount() - startTime;
    m_averageLogTimeNs = (m_averageLogTimeNs * (m_totalLogEntries - 1) + logTime) / m_totalLogEntries;
}

//+------------------------------------------------------------------+
//| JAILBREAK LOGGING: Log Performance Metric                       |
//+------------------------------------------------------------------+
void CJailbreakLogger::LogPerformance(const string& category, const string& operation, ulong durationNs)
{
    if(ShouldLog(LOG_LEVEL_DEBUG))
    {
        string message = StringFormat("Performance: %s completed in %d ns", operation, durationNs);
        LogDebug(category, message);
    }
}

//+------------------------------------------------------------------+
//| JAILBREAK LOGGING: Log Trade Action                             |
//+------------------------------------------------------------------+
void CJailbreakLogger::LogTrade(const string& action, const string& symbol, 
                               double volume, double price, ulong ticket)
{
    if(ShouldLog(LOG_LEVEL_INFO))
    {
        string message = StringFormat("Trade: %s %s %.2f lots at %.5f (Ticket: %d)", 
                                    action, symbol, volume, price, ticket);
        LogInfo("TRADE", message);
    }
}

//+------------------------------------------------------------------+
//| JAILBREAK LOGGING: Format Log Message                           |
//+------------------------------------------------------------------+
string CJailbreakLogger::FormatLogMessage(ENUM_LOG_LEVEL level, const string& category, const string& message)
{
    string timestamp = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
    string levelStr = GetLogLevelString(level);
    
    return StringFormat("[%s] %s_%s_%s: %s", timestamp, m_logPrefix, levelStr, category, message);
}

//+------------------------------------------------------------------+
//| JAILBREAK LOGGING: Get Log Level String                         |
//+------------------------------------------------------------------+
string CJailbreakLogger::GetLogLevelString(ENUM_LOG_LEVEL level)
{
    switch(level)
    {
        case LOG_LEVEL_DEBUG:    return "DEBUG";
        case LOG_LEVEL_INFO:     return "INFO";
        case LOG_LEVEL_WARNING:  return "WARN";
        case LOG_LEVEL_ERROR:    return "ERROR";
        case LOG_LEVEL_CRITICAL: return "CRITICAL";
        default:                 return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| JAILBREAK LOGGING: Write To File                                |
//+------------------------------------------------------------------+
bool CJailbreakLogger::WriteToFile(const string& message)
{
    if(m_logFileHandle == INVALID_HANDLE) return false;
    
    // JAILBREAK LOGGING: Check file size for rotation
    if(m_currentFileSize > LOG_FILE_MAX_SIZE)
    {
        RotateLogFile();
    }
    
    // JAILBREAK LOGGING: Write message
    uint bytesWritten = FileWrite(m_logFileHandle, message);
    if(bytesWritten > 0)
    {
        m_currentFileSize += bytesWritten;
        FileFlush(m_logFileHandle);
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| JAILBREAK LOGGING: Rotate Log File                              |
//+------------------------------------------------------------------+
bool CJailbreakLogger::RotateLogFile()
{
    if(m_logFileHandle != INVALID_HANDLE)
    {
        FileClose(m_logFileHandle);
        m_logFileHandle = INVALID_HANDLE;
    }
    
    // JAILBREAK LOGGING: Create new log file name
    m_rotationIndex++;
    MqlDateTime timeStruct;
    TimeToStruct(TimeCurrent(), timeStruct);
    
    m_logFileName = StringFormat("%s_%04d%02d%02d_%02d%02d%02d_%d.log",
                                m_logPrefix,
                                timeStruct.year, timeStruct.mon, timeStruct.day,
                                timeStruct.hour, timeStruct.min, timeStruct.sec,
                                m_rotationIndex);
    
    // JAILBREAK LOGGING: Open new log file
    m_logFileHandle = FileOpen(m_logFileName, FILE_WRITE | FILE_TXT | FILE_ANSI);
    if(m_logFileHandle != INVALID_HANDLE)
    {
        m_currentFileSize = 0;
        string header = StringFormat("=== JAILBREAK LEVEL 5 LOGGING ROTATED - %s ===\n", 
                                   TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS));
        FileWrite(m_logFileHandle, header);
        FileFlush(m_logFileHandle);
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| JAILBREAK LOGGING: Flush Buffer                                 |
//+------------------------------------------------------------------+
void CJailbreakLogger::FlushBuffer()
{
    // JAILBREAK LOGGING: Reset buffer
    m_bufferIndex = 0;
    m_bufferFull = false;
    
    // In a more advanced implementation, we could write buffer contents to file
}

//+------------------------------------------------------------------+
//| JAILBREAK LOGGING: Should Log                                   |
//+------------------------------------------------------------------+
bool CJailbreakLogger::ShouldLog(ENUM_LOG_LEVEL level)
{
    return m_loggingEnabled && level >= m_minLogLevel;
}

//+------------------------------------------------------------------+
//| JAILBREAK LOGGING: Flush                                        |
//+------------------------------------------------------------------+
void CJailbreakLogger::Flush()
{
    if(m_logFileHandle != INVALID_HANDLE)
    {
        FileFlush(m_logFileHandle);
    }
    FlushBuffer();
}

//+------------------------------------------------------------------+
//| JAILBREAK LOGGING: Cleanup                                      |
//+------------------------------------------------------------------+
void CJailbreakLogger::Cleanup()
{
    if(m_loggingEnabled)
    {
        LogInfo("LOGGER", "Jailbreak Level 5 logger shutting down");
        Flush();
        
        if(m_logFileHandle != INVALID_HANDLE)
        {
            string footer = StringFormat("=== JAILBREAK LEVEL 5 LOGGING ENDED - %s ===\n", 
                                       TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS));
            FileWrite(m_logFileHandle, footer);
            FileClose(m_logFileHandle);
            m_logFileHandle = INVALID_HANDLE;
        }
        
        m_loggingEnabled = false;
    }
}