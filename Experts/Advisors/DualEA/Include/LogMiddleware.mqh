//+------------------------------------------------------------------+
//| LogMiddleware.mqh - Centralized Logging Middleware               |
//| Routes all Print/PrintFormat calls to local file/terminal        |
//+------------------------------------------------------------------+
#ifndef __LOGMIDDLEWARE_MQH__
#define __LOGMIDDLEWARE_MQH__

#include <Files/File.mqh>

class CLogMiddleware
{
private:
   string m_log_file;
   bool   m_to_terminal;
   int    m_handle;

public:
   CLogMiddleware(string log_file = "DualEA\\system.log", bool to_terminal = true)
   {
      m_log_file = log_file;
      m_to_terminal = to_terminal;
      m_handle = INVALID_HANDLE;
   }

   void Log(const string msg)
   {
      // Write to file
      int handle = FileOpen(m_log_file, FILE_READ|FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_ANSI);
      if(handle == INVALID_HANDLE)
      {
         // Fallback: create file if it doesn't exist yet
         handle = FileOpen(m_log_file, FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_ANSI);
      }
      if(handle != INVALID_HANDLE)
      {
         FileSeek(handle, 0, SEEK_END);
         FileWriteString(handle, msg + "\n");
         FileClose(handle);
      }
      // Optionally write to terminal
      if(m_to_terminal)
         Print(msg);
   }

   // Variadic user-defined logging is not supported in MQL5.
   // Use LOG(StringFormat(fmt, ...)) to format then route through middleware.
   // Example: LOG(StringFormat("value=%d", 42));
};

// Global logger instance
static CLogMiddleware* LogMiddleware = NULL;

// Helper macros for drop-in replacement (pointer-safe and block-safe)
// Using a do{...}while(false) wrapper avoids dangling-else issues when used in conditional contexts.
#define LOG(msg)         do { if(LogMiddleware != NULL) LogMiddleware.Log(msg); else Print(msg); } while(false)
// Use LOG(StringFormat(fmt, ...)) instead of PrintFormat to route through middleware.

#endif
