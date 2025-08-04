//+------------------------------------------------------------------+
//|                                                Logger.mqh         |
//|                                      Copyright 2025, EscapeEA     |
//|                                          https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"
#property strict

#include <Files\FileTxt.mqh>
#include <Arrays\ArrayObj.mqh>

// Log levels
enum ENUM_LOG_LEVEL
  {
   LOG_LEVEL_DEBUG = 0,  // Debug information
   LOG_LEVEL_INFO,       // General information
   LOG_LEVEL_WARNING,    // Warning messages
   LOG_LEVEL_ERROR,      // Error conditions
   LOG_LEVEL_CRITICAL    // Critical errors
  };

// Log entry class (inherits from CObject for use with CArrayObj)
class CLogEntry : public CObject
  {
public:
   datetime          timestamp;
   ENUM_LOG_LEVEL   level;
   string           message;
   string           context;
   
   // Default constructor
   CLogEntry() : timestamp(0), level(LOG_LEVEL_INFO) {}
   
   // Parameterized constructor
   CLogEntry(datetime _timestamp, ENUM_LOG_LEVEL _level, const string &_message, const string &_context) :
      timestamp(_timestamp), level(_level), message(_message), context(_context) {}
      
   // Copy constructor
   CLogEntry(const CLogEntry &other) :
      timestamp(other.timestamp), level(other.level), message(other.message), context(other.context) {}
      
   // Assignment operator
   CLogEntry *operator=(const CLogEntry &other)
     {
      if(GetPointer(this) == &other)
         return GetPointer(this);
         
      timestamp = other.timestamp;
      level = other.level;
      message = other.message;
      context = other.context;
      return GetPointer(this);
     }
  };

//+------------------------------------------------------------------+
//| Logger class for handling all logging operations                 |
//+------------------------------------------------------------------+
class CLogger
  {
private:
   static CLogger   *m_instance;      // Singleton instance
   
   // Configuration
   string            m_logDir;        // Log directory
   string            m_logPrefix;     // Log file prefix
   int               m_maxLogFiles;   // Maximum number of log files to keep
   int               m_maxLogSize;    // Maximum log file size in MB
   bool              m_enableConsole; // Enable console output
   ENUM_LOG_LEVEL    m_minLogLevel;   // Minimum log level to output
   
   // State
   CArrayObj         m_logQueue;      // Queue for async logging
   bool              m_isInitialized; // Initialization flag
   
   // Private constructor for singleton
                     CLogger();
   
   // Internal methods
   string            GetLogFileName();
   void              RotateLogs();
   string            GetLogLevelString(const ENUM_LOG_LEVEL level);
   string            FormatLogMessage(const CLogEntry &entry);
   
public:
   // Destructor
                    ~CLogger();
   
   // Singleton access
   static CLogger   *Instance();
   
   // Initialization
   bool              Initialize(const string logDir = "Logs\\", 
                              const string prefix = "EscapeEA_",
                              const ENUM_LOG_LEVEL minLevel = LOG_LEVEL_INFO,
                              const bool enableConsole = true,
                              const int maxFiles = 10,
                              const int maxSizeMB = 5);
   
   // Logging methods
   void              Log(ENUM_LOG_LEVEL level, string message, string context = "");
   void              Debug(string message, string context = "")   { Log(LOG_LEVEL_DEBUG, message, context); }
   void              Info(string message, string context = "")    { Log(LOG_LEVEL_INFO, message, context); }
   void              Warning(string message, string context = "") { Log(LOG_LEVEL_WARNING, message, context); }
   void              Error(string message, string context = "")   { Log(LOG_LEVEL_ERROR, message, context); }
   void              Critical(string message, string context = "") { Log(LOG_LEVEL_CRITICAL, message, context); }
   
   // Utility methods
   void              Flush();
   void              SetLogLevel(const ENUM_LOG_LEVEL level) { m_minLogLevel = level; }
   ENUM_LOG_LEVEL    GetLogLevel() const { return m_minLogLevel; }
  };

// Initialize static member
CLogger *CLogger::m_instance = NULL;

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLogger::CLogger() : 
   m_isInitialized(false),
   m_maxLogFiles(10),
   m_maxLogSize(5),
   m_minLogLevel(LOG_LEVEL_INFO),
   m_enableConsole(true)
  {
   m_logQueue.FreeMode(false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLogger::~CLogger()
  {
   // Flush any pending log entries
   Flush();
   
   // Clean up
   m_logQueue.Clear();
   
   // Reset singleton instance
   if(CheckPointer(m_instance) == POINTER_DYNAMIC)
      delete m_instance;
   m_instance = NULL;
  }

//+------------------------------------------------------------------+
//| Get singleton instance                                           |
//+------------------------------------------------------------------+
CLogger *CLogger::Instance()
  {
   if(m_instance == NULL)
      m_instance = new CLogger();
   return m_instance;
  }

//+------------------------------------------------------------------+
//| Initialize the logger                                            |
//+------------------------------------------------------------------+
bool CLogger::Initialize(const string logDir, const string prefix, 
                        const ENUM_LOG_LEVEL minLevel, const bool enableConsole,
                        const int maxFiles, const int maxSizeMB)
  {
   if(m_isInitialized)
      return true;
   
   // Set configuration
   m_logDir = logDir;
   m_logPrefix = prefix;
   m_minLogLevel = minLevel;
   m_enableConsole = enableConsole;
   m_maxLogFiles = maxFiles;
   m_maxLogSize = maxSizeMB * 1024 * 1024; // Convert MB to bytes
   
   // Ensure log directory exists
   if(!FolderCreate(m_logDir, FILE_COMMON))
     {
      Print("Failed to create log directory: ", m_logDir);
      return false;
     }
   
   // Rotate logs if needed
   RotateLogs();
   
   m_isInitialized = true;
   Info("Logger initialized", "Logger");
   
   return true;
  }

//+------------------------------------------------------------------+
//| Log a message                                                    |
//+------------------------------------------------------------------+
void CLogger::Log(ENUM_LOG_LEVEL level, string message, string context)
  {
   if(!m_isInitialized || level < m_minLogLevel)
      return;
      
   // Create log entry
   CLogEntry *entry = new CLogEntry(TimeCurrent(), level, message, context);
   if(entry == NULL)
     {
      Print("Failed to allocate memory for log entry");
      return;
     }
   
   // Add to queue for async processing
   if(!m_logQueue.Add(entry))
     {
      Print("Failed to add log entry to queue");
      delete entry;
     }
   
   // Flush if queue gets too large
   if(m_logQueue.Total() > 100)
      Flush();
      
   // Output to console if enabled
   if(m_enableConsole)
     {
      string logLine = FormatLogMessage(entry);
      Print(logLine);
     }
  }

//+------------------------------------------------------------------+
//| Flush queued log entries to disk                                 |
//+------------------------------------------------------------------+
void CLogger::Flush()
  {
   if(m_logQueue.Total() == 0)
      return;
   
   string logFile = GetLogFileName();
   CFileTxt file;
   
   // Open file in append mode
   if(!file.Open(logFile, FILE_WRITE|FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON))
     {
      Print("Failed to open log file: ", logFile, ", error: ", GetLastError());
      return;
     }
   
   // Move to end of file - no need to check return value as Seek is void
   file.Seek(0, SEEK_END);
   
   // Write queued entries
   for(int i = 0; i < m_logQueue.Total(); i++)
     {
      CLogEntry *entry = m_logQueue.At(i);
      if(CheckPointer(entry) == POINTER_DYNAMIC)
        {
         string logLine = FormatLogMessage(*entry) + "\r\n";
         file.WriteString(logLine);
         delete entry;
        }
     }
   
   // Clear the queue
   m_logQueue.Clear();
   
   // Close the file
   file.Close();
   
   // Check if we need to rotate logs
   int fileHandle = FileOpen(logFile, FILE_READ|FILE_BIN|FILE_COMMON);
   ulong fileSize = 0;
   if(fileHandle != INVALID_HANDLE)
     {
      fileSize = (ulong)FileSize(fileHandle);
      FileClose(fileHandle);
     }
   if(fileSize > (ulong)m_maxLogSize)
      RotateLogs();
  }

//+------------------------------------------------------------------+
//| Get the current log file name                                    |
//+------------------------------------------------------------------+
string CLogger::GetLogFileName()
  {
   string dateStr = TimeToString(TimeCurrent(), TIME_DATE);
   StringReplace(dateStr, ".", "");
   return m_logDir + m_logPrefix + dateStr + ".log";
  }

//+------------------------------------------------------------------+
//| Rotate log files                                                 |
//+------------------------------------------------------------------+
void CLogger::RotateLogs()
  {
   string currentLog = GetLogFileName();
   
   // Check if current log file is too large
   ulong fileSize = 0;
   int fileHandle = FileOpen(currentLog, FILE_READ|FILE_BIN|FILE_COMMON);
   if(fileHandle != INVALID_HANDLE)
     {
      fileSize = (ulong)FileSize(fileHandle);
      FileClose(fileHandle);
     }
   if(fileSize < (ulong)m_maxLogSize && m_logQueue.Total() <= m_maxLogFiles)
      return;
   
   // Find all log files
   string currentFile;
   int count = 0;
   
   // First pass: count the number of log files
   long handle = FileFindFirst(m_logDir + m_logPrefix + "*.log", currentFile);
   if(handle != INVALID_HANDLE)
     {
      do
        {
         count++;
        }
      while(FileFindNext(handle, currentFile));
      FileFindClose(handle);
     }
   
   // If we have too many log files, delete the oldest ones
   if(count > m_maxLogFiles)
     {
      // Second pass: get all file names and their modification times
      string fileNames[];
      datetime fileTimes[];
      ArrayResize(fileNames, count);
      ArrayResize(fileTimes, count);
      
      handle = FileFindFirst(m_logDir + m_logPrefix + "*.log", currentFile);
      if(handle != INVALID_HANDLE)
        {
         int index = 0;
         do
           {
            string fullPath = m_logDir + currentFile;
            fileNames[index] = fullPath;
            fileTimes[index] = (datetime)FileGetInteger(fullPath, FILE_MODIFY_DATE, false);
            index++;
           }
         while(FileFindNext(handle, currentFile) && index < count);
         FileFindClose(handle);
         
         // Simple bubble sort to sort files by modification time (oldest first)
         for(int i = 0; i < count - 1; i++)
           {
            for(int j = 0; j < count - i - 1; j++)
              {
               if(fileTimes[j] > fileTimes[j+1])
                 {
                  // Swap times
                  datetime tempTime = fileTimes[j];
                  fileTimes[j] = fileTimes[j+1];
                  fileTimes[j+1] = tempTime;
                  
                  // Swap filenames to match
                  string tempName = fileNames[j];
                  fileNames[j] = fileNames[j+1];
                  fileNames[j+1] = tempName;
                 }
              }
           }
         
         // Delete oldest files (first in the sorted array)
         int filesToDelete = count - m_maxLogFiles;
         for(int i = 0; i < filesToDelete && i < count; i++)
           {
            FileDelete(fileNames[i], FILE_COMMON);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Get log level as string                                          |
//+------------------------------------------------------------------+
string CLogger::GetLogLevelString(const ENUM_LOG_LEVEL level)
  {
   switch(level)
     {
      case LOG_LEVEL_DEBUG:    return "DEBUG";
      case LOG_LEVEL_INFO:     return "INFO ";
      case LOG_LEVEL_WARNING:  return "WARN ";
      case LOG_LEVEL_ERROR:    return "ERROR";
      case LOG_LEVEL_CRITICAL: return "CRIT ";
      default:                 return "UNKNW";
     }
  }

//+------------------------------------------------------------------+
//| Format a log message                                             |
//+------------------------------------------------------------------+
string CLogger::FormatLogMessage(const CLogEntry &entry)
  {
   string timeStr = TimeToString(entry.timestamp, TIME_DATE|TIME_SECONDS);
   string levelStr = GetLogLevelString(entry.level);
   
   string contextStr = "";
   if(entry.context != "")
      contextStr = " [" + entry.context + "]";
   
   return StringFormat("%s | %s |%s %s", 
                      timeStr, levelStr, contextStr, entry.message);
  }

//+------------------------------------------------------------------+
//| Helper function to get file size                                 |
//+------------------------------------------------------------------+
long GetFileSize(const string fname)
  {
   int handle = FileOpen(fname, FILE_READ|FILE_BIN|FILE_COMMON);
   if(handle == INVALID_HANDLE)
      return -1;
      
   long size = (long)FileSize(handle);
   FileClose(handle);
   return size;
  }

//+------------------------------------------------------------------+
//| Helper macros for easy logging                                   |
//+------------------------------------------------------------------+
#define LOG_DEBUG(msg, ctx)      CLogger::Instance().Debug(msg, ctx)
#define LOG_INFO(msg, ctx)       CLogger::Instance().Info(msg, ctx)
#define LOG_WARNING(msg, ctx)    CLogger::Instance().Warning(msg, ctx)
#define LOG_ERROR(msg, ctx)      CLogger::Instance().Error(msg, ctx)
#define LOG_CRITICAL(msg, ctx)   CLogger::Instance().Critical(msg, ctx)

//+------------------------------------------------------------------+
