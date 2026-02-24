//+------------------------------------------------------------------+
//| LogMiddleware.mqh - Logging Middleware Stub                        |
//| Provides backward compatible logging functionality                 |
//+------------------------------------------------------------------+
#ifndef LOGMIDDLEWARE_MQH
#define LOGMIDDLEWARE_MQH

// MQL5 native includes only - no C++ stdlib
#include <Files\File.mqh>

// Simple LOG macro - just prints to console
#define LOG(msg) Print(msg)

//+------------------------------------------------------------------+
//| Simple Log Middleware Class                                        |
//+------------------------------------------------------------------+
class CLogMiddleware
{
private:
   string            m_logFile;
   bool              m_enabled;
   bool              m_useDebugPrint;
   bool              m_is_tester;

public:
   // Constructor
   CLogMiddleware(string logFile = "", bool enabled = true)
   {
      m_logFile = logFile;
      m_enabled = enabled;
      m_useDebugPrint = true;
      m_is_tester = (MQLInfoInteger(MQL_TESTER) != 0);
      
      // In tester mode, disable file logging to prevent crashes
      if(m_is_tester)
      {
         m_logFile = "";  // Disable file logging in tester
         Print("[LogMiddleware] TESTER MODE: File logging disabled");
      }
   }

   // Destructor
   ~CLogMiddleware() {}

   // Log a message
   void Log(string message)
   {
      if (!m_enabled) return;

      string timestamp = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
      string logLine = "[" + timestamp + "] " + message;

      // Print to Experts log
      Print(logLine);

      // Write to file if specified (disabled in tester mode)
      if (!m_is_tester && StringLen(m_logFile) > 0)
      {
         // Ensure directory exists before writing
         string folder = "";
         int sepPos = StringFind(m_logFile, "\\");
         if(sepPos > 0)
         {
            folder = StringSubstr(m_logFile, 0, sepPos);
            FolderCreate(folder, FILE_COMMON);
         }
         
         int handle = FileOpen(m_logFile, FILE_WRITE | FILE_TXT | FILE_COMMON);
         if (handle != INVALID_HANDLE)
         {
            FileSeek(handle, 0, SEEK_END);
            FileWriteString(handle, logLine + "\r\n");
            FileClose(handle);
         }
      }
   }

   // Set enabled state
   void SetEnabled(bool enabled) { m_enabled = enabled; }
   bool IsEnabled() const { return m_enabled; }

   // Set log file
   void SetLogFile(string logFile) { m_logFile = logFile; }
   string GetLogFile() const { return m_logFile; }
};

// Global singleton for backward compatibility
CLogMiddleware* LogMiddleware = NULL;

#endif // LOGMIDDLEWARE_MQH
