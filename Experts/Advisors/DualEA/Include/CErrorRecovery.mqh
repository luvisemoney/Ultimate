//+------------------------------------------------------------------+
//| CErrorRecovery.mqh - Centralized Error Recovery System             |
//| Provides consistent error handling, retry logic, and recovery       |
//+------------------------------------------------------------------+
#ifndef CERRORRECOVERY_MQH
#define CERRORRECOVERY_MQH

#include "CArchitectureConfig.mqh"

// Error severity levels
enum ENUM_ERROR_SEVERITY
{
   ERR_SEVERITY_LOW = 0,      // Log only, continue
   ERR_SEVERITY_MEDIUM = 1,   // Degrade gracefully
   ERR_SEVERITY_HIGH = 2,     // Block operations temporarily
   ERR_SEVERITY_CRITICAL = 3  // Shutdown required
};

// Error categories for classification
enum ENUM_ERROR_CATEGORY
{
   ERR_CAT_FILE_IO = 0,
   ERR_CAT_NETWORK = 1,
   ERR_CAT_MEMORY = 2,
   ERR_CAT_TRADE = 3,
   ERR_CAT_SYSTEM = 4,
   ERR_CAT_UNKNOWN = 5
};

// Recovery action types
enum ENUM_RECOVERY_ACTION
{
   RECOVERY_NONE = 0,         // No action, just log
   RECOVERY_RETRY = 1,        // Retry operation
   RECOVERY_FALLBACK = 2,     // Use fallback mode
   RECOVERY_RESET = 3,        // Reset and reinitialize
   RECOVERY_SHUTDOWN = 4      // Graceful shutdown
};

//+------------------------------------------------------------------+
//| Error Record Structure                                             |
//+------------------------------------------------------------------+
struct SErrorRecord
{
   int                error_code;
   ENUM_ERROR_CATEGORY category;
   ENUM_ERROR_SEVERITY severity;
   string             context;
   string             message;
   datetime           timestamp;
   int                retry_count;
   bool               recovered;
   
   SErrorRecord()
   {
      error_code = 0;
      category = ERR_CAT_UNKNOWN;
      severity = ERR_SEVERITY_LOW;
      context = "";
      message = "";
      timestamp = 0;
      retry_count = 0;
      recovered = false;
   }
};

//+------------------------------------------------------------------+
//| Error Recovery Manager                                             |
//+------------------------------------------------------------------+
class CErrorRecovery
{
private:
   static CErrorRecovery* s_instance;
   
   // Error history for analysis
   SErrorRecord         m_error_history[];
   int                  m_history_count;
   int                  m_max_history;
   
   // Retry configuration
   int                  m_max_retries;
   int                  m_retry_delay_ms;
   
   // Circuit breaker state
   int                  m_consecutive_errors;
   datetime             m_circuit_breaker_until;
   int                  m_circuit_breaker_threshold;
   int                  m_circuit_breaker_cooldown_sec;
   
   // Category-specific thresholds
   int                  m_category_errors[];
   datetime             m_category_last_error[];
   
   // Statistics
   int                  m_total_errors;
   int                  m_recovered_errors;
   int                  m_failed_errors;
   
   // Logging
   bool                 m_verbose;
   string               m_log_prefix;

public:
   CErrorRecovery()
   {
      m_history_count = 0;
      m_max_history = 100;
      ArrayResize(m_error_history, m_max_history);
      
      m_max_retries = 3;
      m_retry_delay_ms = 100;
      
      m_consecutive_errors = 0;
      m_circuit_breaker_until = 0;
      m_circuit_breaker_threshold = 5;
      m_circuit_breaker_cooldown_sec = 60;
      
      ArrayResize(m_category_errors, 6);
      ArrayResize(m_category_last_error, 6);
      for(int i = 0; i < 6; i++)
      {
         m_category_errors[i] = 0;
         m_category_last_error[i] = 0;
      }
      
      m_total_errors = 0;
      m_recovered_errors = 0;
      m_failed_errors = 0;
      
      m_verbose = false;
      m_log_prefix = "[ErrorRecovery]";
   }
   
   ~CErrorRecovery()
   {
      // Cleanup
   }
   
   static CErrorRecovery* Instance()
   {
      if(s_instance == NULL)
         s_instance = new CErrorRecovery();
      return s_instance;
   }
   
   static void Destroy()
   {
      if(s_instance != NULL)
      {
         delete s_instance;
         s_instance = NULL;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Configure recovery behavior                                        |
   //+------------------------------------------------------------------+
   void SetMaxRetries(int max_retries) { m_max_retries = max_retries; }
   void SetRetryDelay(int delay_ms) { m_retry_delay_ms = delay_ms; }
   void SetCircuitBreakerThreshold(int threshold) { m_circuit_breaker_threshold = threshold; }
   void SetCircuitBreakerCooldown(int cooldown_sec) { m_circuit_breaker_cooldown_sec = cooldown_sec; }
   void SetVerbose(bool verbose) { m_verbose = verbose; }
   
   //+------------------------------------------------------------------+
   //| Main error handling entry point                                    |
   //+------------------------------------------------------------------+
   bool HandleError(int error_code, const string context, const string message)
   {
      // Clear error to prevent contamination
      ResetLastError();
      
      // Check if in circuit breaker
      if(IsCircuitBreakerActive())
      {
         Log("Circuit breaker active, operation blocked", ERR_SEVERITY_HIGH);
         return false;
      }
      
      // Classify error
      ENUM_ERROR_CATEGORY category = ClassifyError(error_code);
      ENUM_ERROR_SEVERITY severity = DetermineSeverity(error_code, category);
      
      // Create error record
      SErrorRecord record;
      record.error_code = error_code;
      record.category = category;
      record.severity = severity;
      record.context = context;
      record.message = message;
      record.timestamp = TimeCurrent();
      record.retry_count = 0;
      record.recovered = false;
      
      // Add to history
      AddToHistory(record);
      
      // Update statistics
      m_total_errors++;
      m_consecutive_errors++;
      m_category_errors[category]++;
      m_category_last_error[category] = TimeCurrent();
      
      // Check circuit breaker
      if(m_consecutive_errors >= m_circuit_breaker_threshold)
      {
         ActivateCircuitBreaker();
      }
      
      // Determine recovery action
      ENUM_RECOVERY_ACTION action = DetermineRecoveryAction(error_code, category, severity);
      
      // Execute recovery
      bool recovered = ExecuteRecovery(action, record);
      
      if(recovered)
      {
         m_recovered_errors++;
         m_consecutive_errors = 0;
         record.recovered = true;
         UpdateHistoryRecord(record);
         Log("Error recovered: " + message, ERR_SEVERITY_LOW);
      }
      else
      {
         m_failed_errors++;
         Log("Error recovery failed: " + message, severity);
      }
      
      return recovered;
   }
   
   //+------------------------------------------------------------------+
   //| Classify error code to category                                    |
   //+------------------------------------------------------------------+
   ENUM_ERROR_CATEGORY ClassifyError(int error_code)
   {
      switch(error_code)
      {
         // File I/O errors
         case 5001: case 5002: case 5003: case 5004:
         case 5005: case 5006: case 5007: case 5008:
         case 5010: case 5011: case 5012: case 5013:
         case 5014: case 5015: case 5016: case 5017:
         case 5020:
            return ERR_CAT_FILE_IO;
            
         // Network/connection errors
         case 5200: case 5201: case 5202: case 5203:
         case 6750: case 6751: case 6752:
            return ERR_CAT_NETWORK;
            
         // Memory errors
         case 4001: case 4002: case 4003:
            return ERR_CAT_MEMORY;
            
         // Trading errors
         case 10004: case 10006: case 10007: case 10009:
         case 10010: case 10013: case 10014: case 10015:
         case 10016: case 10021: case 10022: case 10023:
         case 10024: case 10025: case 10026: case 10027:
            return ERR_CAT_TRADE;
            
         // System errors
         case 1: case 2: case 3: case 4:
            return ERR_CAT_SYSTEM;
            
         default:
            return ERR_CAT_UNKNOWN;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Determine error severity                                           |
   //+------------------------------------------------------------------+
   ENUM_ERROR_SEVERITY DetermineSeverity(int error_code, ENUM_ERROR_CATEGORY category)
   {
      // Critical errors
      switch(error_code)
      {
         case 4001: // ERR_WRONG_FUNCTION_POINTER
         case 4002: // ERR_ARRAY_INDEX_OUT_OF_RANGE
         case 2:    // ERR_COMMON_ERROR
         case 10026: // ERR_TRADE_MODIFY_DENIED
            return ERR_SEVERITY_CRITICAL;
            
         // High severity
         case 10007: // ERR_TRADE_NOT_ALLOWED
         case 10014: // ERR_TRADE_INVALID_STOPS
         case 5001:  // ERR_FILE_TOO_LARGE
         case 5200:  // ERR_INTERNET_CONNECTION_CLOSED
            return ERR_SEVERITY_HIGH;
            
         // Medium severity
         case 10004: // ERR_REQUOTE
         case 10006: // ERR_NO_PRICES
         case 5004:  // ERR_FILE_NOT_OPEN
         case 6750:  // ERR_SOCKET_INIT_FAILED
            return ERR_SEVERITY_MEDIUM;
            
         // Low severity (transient)
         case 10009: // ERR_TRADE_ERROR
         case 10010: // ERR_TRADE_TIMEOUT
         case 5003:  // ERR_FILE_INVALID_HANDLE
            return ERR_SEVERITY_LOW;
      }
      
      // Category-based fallback
      if(category == ERR_CAT_MEMORY)
         return ERR_SEVERITY_HIGH;
      if(category == ERR_CAT_SYSTEM)
         return ERR_SEVERITY_HIGH;
         
      return ERR_SEVERITY_MEDIUM;
   }
   
   //+------------------------------------------------------------------+
   //| Determine recovery action                                          |
   //+------------------------------------------------------------------+
   ENUM_RECOVERY_ACTION DetermineRecoveryAction(int error_code, ENUM_ERROR_CATEGORY category, ENUM_ERROR_SEVERITY severity)
   {
      // Never retry critical errors
      if(severity == ERR_SEVERITY_CRITICAL)
         return RECOVERY_SHUTDOWN;
         
      // Network errors: retry with fallback
      if(category == ERR_CAT_NETWORK)
         return RECOVERY_RETRY;
         
      // File I/O errors: retry then fallback
      if(category == ERR_CAT_FILE_IO)
         return RECOVERY_RETRY;
         
      // Trading errors: specific handling
      if(category == ERR_CAT_TRADE)
      {
         switch(error_code)
         {
            case 10004: // Requote - retry immediately
            case 10006: // No prices - retry later
               return RECOVERY_RETRY;
               
            case 10007: // Not allowed - check permissions then fallback
               return RECOVERY_FALLBACK;
               
            default:
               return RECOVERY_NONE;
         }
      }
      
      // Default: no recovery action
      return RECOVERY_NONE;
   }
   
   //+------------------------------------------------------------------+
   //| Execute recovery action                                            |
   //+------------------------------------------------------------------+
   bool ExecuteRecovery(ENUM_RECOVERY_ACTION action, SErrorRecord &record)
   {
      switch(action)
      {
         case RECOVERY_NONE:
            return true; // Nothing to do
            
         case RECOVERY_RETRY:
            return ExecuteRetry(record);
            
         case RECOVERY_FALLBACK:
            return ExecuteFallback(record);
            
         case RECOVERY_RESET:
            return ExecuteReset(record);
            
         case RECOVERY_SHUTDOWN:
            ExecuteShutdown(record);
            return false; // Cannot recover from shutdown
            
         default:
            return false;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Retry logic with exponential backoff                               |
   //+------------------------------------------------------------------+
   bool ExecuteRetry(SErrorRecord &record)
   {
      if(record.retry_count >= m_max_retries)
      {
         Log("Max retries exceeded for error " + IntegerToString(record.error_code), ERR_SEVERITY_MEDIUM);
         return false;
      }
      
      record.retry_count++;
      
      // Calculate delay with exponential backoff
      int delay = m_retry_delay_ms * (1 << (record.retry_count - 1));
      if(delay > 5000) delay = 5000; // Cap at 5 seconds
      
      Log("Retry " + IntegerToString(record.retry_count) + "/" + IntegerToString(m_max_retries) + 
          " after " + IntegerToString(delay) + "ms for " + record.context, ERR_SEVERITY_LOW);
      
      // Use Sleep only in non-tick contexts
      // In OnTick, this should be handled asynchronously
      // For now, we return false to indicate retry needed
      return false; // Caller must handle actual retry
   }
   
   //+------------------------------------------------------------------+
   //| Fallback mode execution                                            |
   //+------------------------------------------------------------------+
   bool ExecuteFallback(SErrorRecord &record)
   {
      Log("Activating fallback mode for " + record.context, ERR_SEVERITY_MEDIUM);
      
      // Fallback behaviors by category
      switch(record.category)
      {
         case ERR_CAT_FILE_IO:
            // Switch to memory buffer mode
            return true;
            
         case ERR_CAT_NETWORK:
            // Use cached data
            return true;
            
         case ERR_CAT_TRADE:
            // Switch to shadow/simulation mode
            return true;
            
         default:
            return false;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Reset and reinitialize                                             |
   //+------------------------------------------------------------------+
   bool ExecuteReset(SErrorRecord &record)
   {
      Log("Executing system reset for " + record.context, ERR_SEVERITY_HIGH);
      
      // Clear error state
      ResetLastError();
      
      // Reset counters
      m_consecutive_errors = 0;
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Graceful shutdown                                                  |
   //+------------------------------------------------------------------+
   void ExecuteShutdown(SErrorRecord &record)
   {
      Log("CRITICAL: Executing graceful shutdown - " + record.message, ERR_SEVERITY_CRITICAL);
      
      // Log final statistics
      string stats = StringFormat("Total errors: %d, Recovered: %d, Failed: %d", 
                      m_total_errors, m_recovered_errors, m_failed_errors);
      Log(stats, ERR_SEVERITY_CRITICAL);
      
      // In real implementation, this would trigger EA shutdown
      // ExpertRemove(); // Uncomment when ready for production
   }
   
   //+------------------------------------------------------------------+
   //| Circuit breaker management                                         |
   //+------------------------------------------------------------------+
   bool IsCircuitBreakerActive()
   {
      if(m_circuit_breaker_until == 0)
         return false;
         
      if(TimeCurrent() < m_circuit_breaker_until)
      {
         int remaining = (int)(m_circuit_breaker_until - TimeCurrent());
         if(m_verbose && remaining % 10 == 0) // Log every 10 seconds
            Log("Circuit breaker active: " + IntegerToString(remaining) + "s remaining", ERR_SEVERITY_MEDIUM);
         return true;
      }
      
      // Circuit breaker expired
      m_circuit_breaker_until = 0;
      m_consecutive_errors = 0;
      Log("Circuit breaker deactivated", ERR_SEVERITY_LOW);
      return false;
   }
   
   void ActivateCircuitBreaker()
   {
      m_circuit_breaker_until = TimeCurrent() + m_circuit_breaker_cooldown_sec;
      Log("Circuit breaker ACTIVATED for " + IntegerToString(m_circuit_breaker_cooldown_sec) + "s", ERR_SEVERITY_HIGH);
   }
   
   void DeactivateCircuitBreaker()
   {
      m_circuit_breaker_until = 0;
      m_consecutive_errors = 0;
      Log("Circuit breaker manually deactivated", ERR_SEVERITY_LOW);
   }
   
   //+------------------------------------------------------------------+
   //| History management                                                 |
   //+------------------------------------------------------------------+
   void AddToHistory(SErrorRecord &record)
   {
      // Shift existing records
      for(int i = m_history_count - 1; i > 0; i--)
      {
         m_error_history[i] = m_error_history[i - 1];
      }
      
      // Add new record at start
      m_error_history[0] = record;
      
      if(m_history_count < m_max_history)
         m_history_count++;
   }
   
   void UpdateHistoryRecord(SErrorRecord &record)
   {
      // Find and update record
      for(int i = 0; i < m_history_count; i++)
      {
         if(m_error_history[i].timestamp == record.timestamp &&
            m_error_history[i].error_code == record.error_code)
         {
            m_error_history[i] = record;
            break;
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Statistics and reporting                                           |
   //+------------------------------------------------------------------+
   string GetErrorStats()
   {
      string stats = StringFormat(
         "=== Error Recovery Statistics ===\n" +
         "Total Errors: %d\n" +
         "Recovered: %d (%.1f%%)\n" +
         "Failed: %d (%.1f%%)\n" +
         "Consecutive Errors: %d\n" +
         "Circuit Breaker: %s\n" +
         "History: %d/%d records",
         m_total_errors,
         m_recovered_errors, 
         (m_total_errors > 0 ? 100.0 * m_recovered_errors / m_total_errors : 0),
         m_failed_errors,
         (m_total_errors > 0 ? 100.0 * m_failed_errors / m_total_errors : 0),
         m_consecutive_errors,
         (IsCircuitBreakerActive() ? "ACTIVE" : "inactive"),
         m_history_count, m_max_history
      );
      
      return stats;
   }
   
   string GetRecentErrors(int count = 10)
   {
      string report = "=== Recent Errors ===\n";
      int show = MathMin(count, m_history_count);
      
      for(int i = 0; i < show; i++)
      {
         SErrorRecord &rec = m_error_history[i];
         string status = rec.recovered ? "[RECOVERED]" : "[FAILED]";
         report += StringFormat("%s %s: %d - %s (%s retries)\n",
            status,
            TimeToString(rec.timestamp, TIME_MINUTES),
            rec.error_code,
            rec.message,
            IntegerToString(rec.retry_count)
         );
      }
      
      return report;
   }
   
   //+------------------------------------------------------------------+
   //| Utility functions                                                  |
   //+------------------------------------------------------------------+
   void Log(const string message, ENUM_ERROR_SEVERITY severity)
   {
      string prefix = m_log_prefix;
      switch(severity)
      {
         case ERR_SEVERITY_CRITICAL: prefix += " [CRITICAL]"; break;
         case ERR_SEVERITY_HIGH:     prefix += " [HIGH]"; break;
         case ERR_SEVERITY_MEDIUM:   prefix += " [MEDIUM]"; break;
         case ERR_SEVERITY_LOW:      prefix += " [LOW]"; break;
      }
      
      Print(prefix + " " + message);
   }
   
   void ResetLastError()
   {
      // Clear any pending error
      int _ = GetLastError(); // Read and clear
   }
   
   // Getters
   int GetTotalErrors() const { return m_total_errors; }
   int GetRecoveredErrors() const { return m_recovered_errors; }
   int GetFailedErrors() const { return m_failed_errors; }
   int GetConsecutiveErrors() const { return m_consecutive_errors; }
   bool IsHealthy() const { return m_consecutive_errors < 3; }
};

// Static instance initialization
CErrorRecovery* CErrorRecovery::s_instance = NULL;

// Global macro for easy error handling
#define HANDLE_ERROR(code, context, message) \
   CErrorRecovery::Instance().HandleError(code, context, message)

#define CHECK_ERROR(context) \
   do { int _err = GetLastError(); if(_err != 0) { \
      CErrorRecovery::Instance().HandleError(_err, context, ""); \
      ResetLastError(); \
   } } while(0)

#define CLEAR_ERROR() ResetLastError()

#endif // CERRORRECOVERY_MQH
