//+------------------------------------------------------------------+
//| CErrorHandling.mqh - Centralized Error Management System         |
//| Provides structured error handling across all subsystems         |
//+------------------------------------------------------------------+
#ifndef CERROR_HANDLING_MQH
#define CERROR_HANDLING_MQH

//+------------------------------------------------------------------+
//| Error Severity Levels                                            |
//+------------------------------------------------------------------+
enum ENUM_ERROR_SEVERITY
{
   ERR_SEVERITY_INFO = 0,      // Informational, no action needed
   ERR_SEVERITY_WARNING = 1,   // Warning, operation can continue
   ERR_SEVERITY_ERROR = 2,     // Error, current operation failed
   ERR_SEVERITY_CRITICAL = 3,  // Critical, system stability at risk
   ERR_SEVERITY_FATAL = 4      // Fatal, shutdown required
};

//+------------------------------------------------------------------+
//| Error Categories                                                 |
//+------------------------------------------------------------------+
enum ENUM_ERROR_CATEGORY
{
   ERR_CAT_NONE = 0,
   ERR_CAT_INIT = 1,           // Initialization
   ERR_CAT_MEMORY = 2,         // Memory/Allocation
   ERR_CAT_FILE = 3,           // File I/O
   ERR_CAT_NETWORK = 4,        // Network/HTTP
   ERR_CAT_TRADE = 5,          // Trade execution
   ERR_CAT_GATE = 6,           // Gate system
   ERR_CAT_SQLITE = 7,         // SQLite operations
   ERR_CAT_CONFIG = 8,         // Configuration
   ERR_CAT_SYSTEM = 9          // General system
};

//+------------------------------------------------------------------+
//| Error Context Structure                                          |
//+------------------------------------------------------------------+
struct SErrorContext
{
   datetime          timestamp;
   ENUM_ERROR_SEVERITY severity;
   ENUM_ERROR_CATEGORY category;
   string            source;        // Component name
   string            function;      // Function name
   int               code;          // Error code
   string            message;       // Human-readable message
   string            details;       // Additional details
   
   void Init(ENUM_ERROR_SEVERITY sev, ENUM_ERROR_CATEGORY cat, 
             const string src, const string func, int err_code, 
             const string msg, const string det = "")
   {
      timestamp = TimeCurrent();
      severity = sev;
      category = cat;
      source = src;
      function = func;
      code = err_code;
      message = msg;
      details = det;
   }
   
   string ToString()
   {
      return StringFormat("[%s] %s | %s.%s | Code=%d | %s%s",
         TimeToString(timestamp, TIME_DATE|TIME_SECONDS),
         SeverityToString(severity),
         source, function, code, message,
         StringLen(details) > 0 ? " | " + details : "");
   }
   
   static string SeverityToString(ENUM_ERROR_SEVERITY sev)
   {
      switch(sev)
      {
         case ERR_SEVERITY_INFO: return "INFO";
         case ERR_SEVERITY_WARNING: return "WARN";
         case ERR_SEVERITY_ERROR: return "ERROR";
         case ERR_SEVERITY_CRITICAL: return "CRITICAL";
         case ERR_SEVERITY_FATAL: return "FATAL";
      }
      return "UNKNOWN";
   }
};

//+------------------------------------------------------------------+
//| Error Handler Class                                              |
//+------------------------------------------------------------------+
class CErrorHandler
{
private:
   SErrorContext     m_error_history[];
   int               m_history_size;
   int               m_history_index;
   int               m_error_counts[5]; // Per severity
   int               m_category_counts[10]; // Per category
   
   // Circuit breaker for repeated errors
   datetime          m_last_error_time;
   int               m_recent_error_count;
   int               m_circuit_breaker_threshold;
   int               m_circuit_breaker_window_sec;
   
public:
   CErrorHandler()
   {
      m_history_size = 100;
      m_history_index = 0;
      ArrayResize(m_error_history, m_history_size);
      
      for(int i = 0; i < 5; i++) m_error_counts[i] = 0;
      for(int i = 0; i < 10; i++) m_category_counts[i] = 0;
      
      m_last_error_time = 0;
      m_recent_error_count = 0;
      m_circuit_breaker_threshold = 10;
      m_circuit_breaker_window_sec = 60;
   }
   
   //+------------------------------------------------------------------+
   //| Log an error to history                                          |
   //+------------------------------------------------------------------+
   void LogError(ENUM_ERROR_SEVERITY severity, ENUM_ERROR_CATEGORY category,
                 const string source, const string function, int code,
                 const string message, const string details = "")
   {
      // Create error context
      SErrorContext ctx;
      ctx.Init(severity, category, source, function, code, message, details);
      
      // Add to ring buffer
      m_error_history[m_history_index] = ctx;
      m_history_index = (m_history_index + 1) % m_history_size;
      
      // Update counters
      m_error_counts[severity]++;
      m_category_counts[category]++;
      
      // Check circuit breaker
      CheckCircuitBreaker();
      
      // Always print critical/fatal immediately
      if(severity >= ERR_SEVERITY_CRITICAL)
      {
         Print(ctx.ToString());
      }
   }
   
   //+------------------------------------------------------------------+
   //| Convenience methods                                              |
   //+------------------------------------------------------------------+
   void Info(ENUM_ERROR_CATEGORY cat, const string src, const string func, 
             const string msg, const string det = "")
   {
      LogError(ERR_SEVERITY_INFO, cat, src, func, 0, msg, det);
   }
   
   void Warning(ENUM_ERROR_CATEGORY cat, const string src, const string func, 
                int code, const string msg, const string det = "")
   {
      LogError(ERR_SEVERITY_WARNING, cat, src, func, code, msg, det);
   }
   
   void Error(ENUM_ERROR_CATEGORY cat, const string src, const string func, 
              int code, const string msg, const string det = "")
   {
      LogError(ERR_SEVERITY_ERROR, cat, src, func, code, msg, det);
   }
   
   void Critical(ENUM_ERROR_CATEGORY cat, const string src, const string func, 
                 int code, const string msg, const string det = "")
   {
      LogError(ERR_SEVERITY_CRITICAL, cat, src, func, code, msg, det);
   }
   
   void Fatal(ENUM_ERROR_CATEGORY cat, const string src, const string func, 
              int code, const string msg, const string det = "")
   {
      LogError(ERR_SEVERITY_FATAL, cat, src, func, code, msg, det);
   }
   
   //+------------------------------------------------------------------+
   //| Get error statistics                                             |
   //+------------------------------------------------------------------+
   int GetErrorCount(ENUM_ERROR_SEVERITY sev) { return m_error_counts[sev]; }
   int GetCategoryCount(ENUM_ERROR_CATEGORY cat) { return m_category_counts[cat]; }
   
   string GetErrorSummary()
   {
      string summary = "=== Error Summary ===\n";
      summary += StringFormat("Total Errors: %d (Info:%d Warn:%d Err:%d Crit:%d Fatal:%d)\n",
         GetTotalErrorCount(),
         m_error_counts[ERR_SEVERITY_INFO],
         m_error_counts[ERR_SEVERITY_WARNING],
         m_error_counts[ERR_SEVERITY_ERROR],
         m_error_counts[ERR_SEVERITY_CRITICAL],
         m_error_counts[ERR_SEVERITY_FATAL]);
      
      summary += "By Category:\n";
      for(int i = 1; i < 10; i++)
      {
         if(m_category_counts[i] > 0)
            summary += StringFormat("  %s: %d\n", CategoryToString(i), m_category_counts[i]);
      }
      
      return summary;
   }
   
   //+------------------------------------------------------------------+
   //| Get recent errors (last N)                                       |
   //+------------------------------------------------------------------+
   string GetRecentErrors(int count = 10)
   {
      string result = "=== Recent Errors ===\n";
      int start = m_history_index - MathMin(count, m_history_size);
      if(start < 0) start += m_history_size;
      
      for(int i = 0; i < MathMin(count, m_history_size); i++)
      {
         int idx = (start + i) % m_history_size;
         if(StringLen(m_error_history[idx].message) > 0)
            result += m_error_history[idx].ToString() + "\n";
      }
      return result;
   }
   
   //+------------------------------------------------------------------+
   //| Circuit breaker check                                            |
   //+------------------------------------------------------------------+
   bool IsCircuitBreakerTripped()
   {
      return m_recent_error_count >= m_circuit_breaker_threshold;
   }
   
   void ResetCircuitBreaker()
   {
      m_recent_error_count = 0;
      m_last_error_time = 0;
   }
   
private:
   int GetTotalErrorCount()
   {
      int total = 0;
      for(int i = 0; i < 5; i++) total += m_error_counts[i];
      return total;
   }
   
   void CheckCircuitBreaker()
   {
      datetime now = TimeCurrent();
      if(now - m_last_error_time <= m_circuit_breaker_window_sec)
      {
         m_recent_error_count++;
      }
      else
      {
         m_recent_error_count = 1;
      }
      m_last_error_time = now;
      
      if(IsCircuitBreakerTripped())
      {
         Print(StringFormat("[CIRCUIT BREAKER] %d errors in %d seconds - throttling error logging",
            m_recent_error_count, m_circuit_breaker_window_sec));
      }
   }
   
   static string CategoryToString(int cat)
   {
      switch(cat)
      {
         case ERR_CAT_INIT: return "INIT";
         case ERR_CAT_MEMORY: return "MEMORY";
         case ERR_CAT_FILE: return "FILE";
         case ERR_CAT_NETWORK: return "NETWORK";
         case ERR_CAT_TRADE: return "TRADE";
         case ERR_CAT_GATE: return "GATE";
         case ERR_CAT_SQLITE: return "SQLITE";
         case ERR_CAT_CONFIG: return "CONFIG";
         case ERR_CAT_SYSTEM: return "SYSTEM";
      }
      return "UNKNOWN";
   }
};

// Global error handler instance
CErrorHandler* g_error_handler = NULL;

//+------------------------------------------------------------------+
//| Initialize error handling                                        |
//+------------------------------------------------------------------+
bool InitializeErrorHandling()
{
   if(g_error_handler != NULL)
      delete g_error_handler;
   
   g_error_handler = new CErrorHandler();
   
   Print("[ErrorHandling] Initialized");
   return true;
}

//+------------------------------------------------------------------+
//| Shutdown error handling                                          |
//+------------------------------------------------------------------+
void ShutdownErrorHandling()
{
   if(g_error_handler != NULL)
   {
      // Avoid macro collisions on method name resolution.
      // Summary can be printed by call sites that include this header.
      delete g_error_handler;
      g_error_handler = NULL;
   }
}

//+------------------------------------------------------------------+
//| Convenience macros for error logging                             |
//+------------------------------------------------------------------+
#ifdef LOG_INFO
 #undef LOG_INFO
#endif
#ifdef LOG_DEBUG
 #undef LOG_DEBUG
#endif
#ifdef LOG_WARNING
 #undef LOG_WARNING
#endif
#ifdef LOG_ERROR
 #undef LOG_ERROR
#endif

#define LOG_INFO(cat, msg) \
   do { if(g_error_handler != NULL) g_error_handler->Info(cat, __FILE__, __FUNCTION__, msg); } while(0)

#define LOG_WARN(cat, code, msg) \
   do { if(g_error_handler != NULL) g_error_handler->Warning(cat, __FILE__, __FUNCTION__, code, msg); } while(0)

#define LOG_ERROR(cat, code, msg) \
   do { if(g_error_handler != NULL) g_error_handler->Error(cat, __FILE__, __FUNCTION__, code, msg); } while(0)

#define LOG_CRITICAL(cat, code, msg) \
   do { if(g_error_handler != NULL) g_error_handler->Critical(cat, __FILE__, __FUNCTION__, code, msg); } while(0)

#endif // CERROR_HANDLING_MQH
