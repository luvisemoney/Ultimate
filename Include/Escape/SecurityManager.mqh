//+------------------------------------------------------------------+
//|                                              SecurityManager.mqh  |
//|                                          Copyright 2025, EscapeEA |
//|                                             https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.10"  // Added rate limiting and enhanced error handling
#property strict

#include <Trade\AccountInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include "SecureMemory.mqh"
#include "InputValidation.mqh"

// Security event categories
enum ENUM_SECURITY_EVENT_CATEGORY {
   SECURITY_CATEGORY_AUTH,      // Authentication/Authorization
   SECURITY_CATEGORY_TRADE,     // Trading operations
   SECURITY_CATEGORY_FILE,      // File operations
   SECURITY_CATEGORY_NETWORK,   // Network operations
   SECURITY_CATEGORY_SYSTEM     // System operations
};

//--- Security levels
enum ENUM_SECURITY_LEVEL {
   SECURITY_LEVEL_CRITICAL = 0,  // Critical security issue - stop trading
   SECURITY_LEVEL_HIGH = 1,      // High risk - log and potentially block
   SECURITY_LEVEL_MEDIUM = 2,    // Medium risk - log and warn
   SECURITY_LEVEL_LOW = 3,       // Low risk - log only
   SECURITY_LEVEL_INFO = 4,      // Informational messages
   SECURITY_LEVEL_DEBUG = 5      // Debug information
};

// Alias for backward compatibility
#define SECURITY_LEVEL_INFO SECURITY_LEVEL_DEBUG

//--- Security event structure
struct SSecurityEvent {
   datetime          time;          // Time of the event
   string            source;        // Source of the event
   string            message;       // Event message
   ENUM_SECURITY_LEVEL level;       // Security level
   ENUM_SECURITY_EVENT_CATEGORY category; // Event category
   int               errorCode;     // Error code if any
   string            details;       // Additional details
};

//+------------------------------------------------------------------+
//| Security Manager class                                           |
//+------------------------------------------------------------------+
class CSecurityManager {
private:
   CAccountInfo      m_account;      // Account info
   CSymbolInfo       m_symbol;       // Symbol info
   
   // Security settings
   bool              m_enableDllImportCheck;  // Check for unauthorized DLL imports
   bool              m_enableEnvironmentCheck; // Check environment integrity
   bool              m_enableTradeValidation; // Validate trades before execution
   
   // Internal state
   bool              m_isInitialized;
   string            m_logFilePath;
   
   // Prevent copying
   CSecurityManager(const CSecurityManager&);
   void operator=(const CSecurityManager&);
   
   // Private constructor for singleton pattern
   CSecurityManager() : m_isInitialized(false) {}
   
   // Rate limiting for security events
   struct RateLimitEntry {
      int      count;
      datetime lastReset;
      int      maxEvents;
      int      timeWindow;  // in seconds
   };
   
   RateLimitEntry m_rateLimits[];
   
   // Initialize rate limits
   void InitializeRateLimits() {
      // Default rate limits (events per minute)
      ArrayResize(m_rateLimits, 3);
      
      // Critical events (10 per hour)
      m_rateLimits[0].count = 0;
      m_rateLimits[0].lastReset = TimeCurrent();
      m_rateLimits[0].maxEvents = 10;
      m_rateLimits[0].timeWindow = 3600;  // 1 hour
      
      // High priority events (30 per hour)
      m_rateLimits[1].count = 0;
      m_rateLimits[1].lastReset = TimeCurrent();
      m_rateLimits[1].maxEvents = 30;
      m_rateLimits[1].timeWindow = 3600;  // 1 hour
      
      // Normal events (100 per hour)
      m_rateLimits[2].count = 0;
      m_rateLimits[2].lastReset = TimeCurrent();
      m_rateLimits[2].maxEvents = 100;
      m_rateLimits[2].timeWindow = 3600;  // 1 hour
   }
   
   // Check if event should be logged based on rate limiting
   bool CheckRateLimit(ENUM_SECURITY_LEVEL level) {
      int index = 2; // Default to normal events
      
      if(level == SECURITY_LEVEL_CRITICAL) index = 0;
      else if(level == SECURITY_LEVEL_HIGH) index = 1;
      
      if(index < 0 || index >= ArraySize(m_rateLimits)) return true;
      
      datetime currentTime = TimeCurrent();
      if(currentTime - m_rateLimits[index].lastReset > m_rateLimits[index].timeWindow) {
         m_rateLimits[index].count = 0;
         m_rateLimits[index].lastReset = currentTime;
      }
      
      if(m_rateLimits[index].count >= m_rateLimits[index].maxEvents) {
         return false;
      }
      
      m_rateLimits[index].count++;
      return true;
   }
   
   // Log security event to file with rate limiting
   void LogSecurityEvent(const SSecurityEvent &event) {
      // Skip logging if rate limit exceeded (except for critical events)
      if(event.level > SECURITY_LEVEL_CRITICAL && !CheckRateLimit(event.level)) {
         return;
      }
      
      string levelText;
      switch(event.level) {
         case SECURITY_LEVEL_CRITICAL: levelText = "CRITICAL"; break;
         case SECURITY_LEVEL_HIGH:     levelText = "HIGH    "; break;
         case SECURITY_LEVEL_MEDIUM:   levelText = "MEDIUM  "; break;
         case SECURITY_LEVEL_LOW:      levelText = "LOW     "; break;
         case SECURITY_LEVEL_DEBUG:    levelText = "DEBUG   "; break;
         default:                      levelText = "UNKNOWN "; break;
      }
      
      string categoryText;
      switch(event.category) {
         case SECURITY_CATEGORY_AUTH:    categoryText = "AUTH    "; break;
         case SECURITY_CATEGORY_TRADE:   categoryText = "TRADE   "; break;
         case SECURITY_CATEGORY_FILE:    categoryText = "FILE    "; break;
         case SECURITY_CATEGORY_NETWORK: categoryText = "NETWORK "; break;
         case SECURITY_CATEGORY_SYSTEM:  categoryText = "SYSTEM  "; break;
         default:                        categoryText = "UNKNOWN "; break;
      }
      
      string logEntry = StringFormat("[%s] [%s] [%s] %s: %s (Code: %d, Details: %s)",
                                   TimeToString(event.time, TIME_DATE|TIME_SECONDS|TIME_MINUTES|TIME_SECONDS),
                                   levelText,
                                   categoryText,
                                   event.source,
                                   event.message,
                                   event.errorCode,
                                   event.details);
      
      // Print to journal with appropriate verbosity
      if(event.level <= SECURITY_LEVEL_MEDIUM) {
         Print(logEntry);
      }
      
      // Always log to file if path is set
      if(m_logFilePath != "") {
         int fileHandle = FileOpen(m_logFilePath, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
         if(fileHandle != INVALID_HANDLE) {
            FileSeek(fileHandle, 0, SEEK_END);
            FileWriteString(fileHandle, logEntry + "\n");
            FileFlush(fileHandle);
            FileClose(fileHandle);
         } else {
            // If we can't log to file, at least print to journal
            Print("Failed to write to security log: ", GetLastError());
         }
      }
   }
   
public:
   // Get singleton instance
   static CSecurityManager* Instance() {
      static CSecurityManager instance;
      return &instance;
   }
   
   // Initialize security manager
   bool Initialize(const string symbol = "", const string logPath = "") {
      if(m_isInitialized) return true;
      
      // Set up logging with validation
      if(logPath != "") {
         if(!ExtInputValidator.IsValidFilePath(logPath)) {
            Print("Invalid log file path: ", logPath);
            return false;
         }
         m_logFilePath = logPath;
      }
      
      // Initialize rate limits
      InitializeRateLimits();
      
      // Initialize account and symbol info
      if(symbol != "") {
         if(!m_symbol.Name(symbol)) {
            Print("Failed to set symbol for security manager");
            return false;
         }
      }
      
      // Enable all security checks by default
      m_enableDllImportCheck = true;
      m_enableEnvironmentCheck = true;
      m_enableTradeValidation = true;
      
      m_isInitialized = true;
      return true;
   }
   
   // Validate the trading environment
   bool ValidateEnvironment() {
      bool isValid = true;
      int errorCode = 0;
      
      // 1. Check if terminal is allowed to trade
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
         errorCode = GetLastError();
         LogEvent(SECURITY_LEVEL_CRITICAL, SECURITY_CATEGORY_TRADE, 
                 "Environment", "AutoTrading is disabled in terminal settings",
                 errorCode, "Trading operations will be blocked");
         isValid = false;
      }
      
      // 2. Check if DLL imports are allowed
      if(TerminalInfoInteger(TERMINAL_DLLS_ALLOWED) == 0) {
         LogEvent(SECURITY_LEVEL_HIGH, SECURITY_CATEGORY_SYSTEM,
                 "Environment", "DLL imports are disabled in terminal settings",
                 0, "Some functionality may be limited");
      }
      
      // 3. Check if file operations are allowed
      if(TerminalInfoInteger(TERMINAL_CODEPAGE) == 0) {
         LogEvent(SECURITY_LEVEL_MEDIUM, SECURITY_CATEGORY_FILE,
                 "Environment", "File operations may be restricted",
                 0, "Check terminal permissions");
      }
      
      // 4. Check for terminal updates
      if(!TerminalInfoInteger(TERMINAL_CONNECTED)) {
         LogEvent(SECURITY_LEVEL_MEDIUM, SECURITY_CATEGORY_NETWORK,
                 "Environment", "Terminal is not connected to the internet",
                 0, "Some features may not work as expected");
      }
      
      // 5. Check for running in strategy tester
      if(MQLInfoInteger(MQL_TESTER)) {
         LogEvent(SECURITY_LEVEL_DEBUG, SECURITY_CATEGORY_SYSTEM,
                 "Environment", "Running in Strategy Tester",
                 0, "Some security checks may be bypassed");
      }
      
      // 6. Check for running in visual mode
      if(MQLInfoInteger(MQL_VISUAL_MODE)) {
         LogEvent(SECURITY_LEVEL_DEBUG, SECURITY_CATEGORY_SYSTEM,
                 "Environment", "Running in visual mode",
                 0, "Performance may be affected");
      }
      
      // 7. Check for sufficient permissions
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
         errorCode = GetLastError();
         LogEvent(SECURITY_LEVEL_CRITICAL, SECURITY_CATEGORY_AUTH,
                 "Permissions", "Insufficient trading permissions",
                 errorCode, "Check terminal settings and account permissions");
         isValid = false;
      }
      
      // 8. Check for account permissions
      if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) {
         errorCode = GetLastError();
         LogEvent(SECURITY_LEVEL_CRITICAL, SECURITY_CATEGORY_AUTH,
                 "Account", "Trading is not allowed for this account",
                 errorCode, "Check account settings");
         isValid = false;
      }
      
      // 9. Check for demo account if required
      if(AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO) {
         LogEvent(SECURITY_LEVEL_INFO, SECURITY_CATEGORY_TRADE,
                 "Account", "Running on demo account",
                 0, "No real funds are at risk");
      }
      
      // 10. Log environment summary
      if(isValid) {
         LogEvent(SECURITY_LEVEL_DEBUG, SECURITY_CATEGORY_SYSTEM,
                 "Environment", "Environment validation passed",
                 0, "All required permissions and settings are valid");
      } else {
         LogEvent(SECURITY_LEVEL_CRITICAL, SECURITY_CATEGORY_SYSTEM,
                 "Environment", "Environment validation failed",
                 0, "See previous messages for details");
      }
      
      // Check if symbol is selected and valid
      if(m_symbol.Name() != "") {
         // Use the correct Select method signature for CSymbolInfo
         if(!m_symbol.Name(m_symbol.Name())) {
            SSecurityEvent event = {0};
            event.time = TimeCurrent();
            event.source = "Symbol";
            event.message = "Failed to select symbol: " + m_symbol.Name();
            event.level = SECURITY_LEVEL_CRITICAL;
            event.errorCode = GetLastError();
            LogSecurityEvent(event);
            isValid = false;
         } else {
            // Update symbol rates and refresh after selection
            m_symbol.RefreshRates();
         }
      }
      
      return isValid;
   }
   
   // Get current security level
   ENUM_SECURITY_LEVEL GetSecurityLevel() {
      // Default to high security level
      ENUM_SECURITY_LEVEL level = SECURITY_LEVEL_LOW;
      
      // Check for critical issues first
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !m_account.TradeAllowed()) {
         return SECURITY_LEVEL_CRITICAL;
      }
      
      // Check for high-priority issues
      if(!TerminalInfoInteger(TERMINAL_DLLS_ALLOWED) && m_enableDllImportCheck) {
         level = (ENUM_SECURITY_LEVEL)MathMin(level, SECURITY_LEVEL_HIGH);
      }
      
      // Add more checks as needed
      
      return level;
   }
   
   // Log a security event with category and details
   void LogEvent(ENUM_SECURITY_LEVEL level, ENUM_SECURITY_EVENT_CATEGORY category, 
                const string source, const string message, 
                int errorCode = 0, const string details = "") {
      SSecurityEvent event = {0};
      event.time = TimeCurrent();
      event.source = source;
      event.message = message;
      event.level = level;
      event.category = category;
      event.errorCode = errorCode;
      event.details = details;
      LogSecurityEvent(event);
   }
   
   // Clean up resources
   void Shutdown() {
      m_isInitialized = false;
   }
   
   // Destructor
   ~CSecurityManager() {
      Shutdown();
   }
};

// Global instance
CSecurityManager* ExtSecurity = NULL;
