//+------------------------------------------------------------------+
//|                                                  EALogger.mqh     |
//|                        Copyright 2025, Your Company Name          |
//|                                             https://www.yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company Name"
#property link      "https://www.yoursite.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Log levels                                                       |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVEL
{
   LOG_LEVEL_ERROR = 0,    // Error level
   LOG_LEVEL_WARN,         // Warning level
   LOG_LEVEL_INFO,         // Information level
   LOG_LEVEL_DEBUG,        // Debug level
   LOG_LEVEL_TRACE         // Trace level
};

//+------------------------------------------------------------------+
//| Logger class                                                     |
//+------------------------------------------------------------------+
class CEALogger
{
private:
   string         m_filename;        // Log file name
   int            m_fileHandle;      // File handle
   ENUM_LOG_LEVEL m_logLevel;        // Current log level
   bool           m_consoleOutput;   // Enable console output
   bool           m_fileOutput;      // Enable file output
   
   // Log level names
   static string  m_levelNames[];
   
   // Format log message
   string FormatMessage(const string message, const ENUM_LOG_LEVEL level);
   
public:
   CEALogger() : m_fileHandle(INVALID_HANDLE), m_logLevel(LOG_LEVEL_INFO),
                 m_consoleOutput(true), m_fileOutput(true) {}
   ~CEALogger() { Deinitialize(); }
   
   // Initialization
   bool Initialize(const string filename, 
                  const ENUM_LOG_LEVEL level = LOG_LEVEL_INFO,
                  const bool consoleOutput = true,
                  const bool fileOutput = true);
   void Deinitialize();
   
   // Logging methods
   void Log(const string message, const ENUM_LOG_LEVEL level = LOG_LEVEL_INFO);
   void Error(const string message) { Log(message, LOG_LEVEL_ERROR); }
   void Warning(const string message) { Log(message, LOG_LEVEL_WARN); }
   void Info(const string message) { Log(message, LOG_LEVEL_INFO); }
   void Debug(const string message) { Log(message, LOG_LEVEL_DEBUG); }
   void Trace(const string message) { Log(message, LOG_LEVEL_TRACE); }
   
   // Getters/Setters
   ENUM_LOG_LEVEL GetLogLevel() const { return m_logLevel; }
   void SetLogLevel(const ENUM_LOG_LEVEL level) { m_logLevel = level; }
   
   // Helper methods
   static string GetLastErrorText(const int errorCode = 0);
};

// Initialize static members
string CEALogger::m_levelNames[] = {"ERROR", "WARN ", "INFO ", "DEBUG", "TRACE"};

//+------------------------------------------------------------------+
//| Initialize logger                                                |
//+------------------------------------------------------------------+
bool CEALger::Initialize(const string filename, 
                        const ENUM_LOG_LEVEL level,
                        const bool consoleOutput,
                        const bool fileOutput)
{
   // Close previous file if open
   if (m_fileHandle != INVALID_HANDLE)
      FileClose(m_fileHandle);
   
   m_filename = filename;
   m_logLevel = level;
   m_consoleOutput = consoleOutput;
   m_fileOutput = fileOutput;
   
   // Open log file if file output is enabled
   if (m_fileOutput)
   {
      m_fileHandle = FileOpen(m_filename, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
      if (m_fileHandle == INVALID_HANDLE)
      {
         // Try to create the directory if it doesn't exist
         string path = "";
         int pos = StringFind(m_filename, "\\");
         if (pos > 0)
         {
            path = StringSubstr(m_filename, 0, pos);
            if (!FolderCreate(path, 0))
            {
               Print("Failed to create log directory: ", path);
               return false;
            }
            
            // Try opening the file again
            m_fileHandle = FileOpen(m_filename, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
            if (m_fileHandle == INVALID_HANDLE)
            {
               Print("Failed to open log file: ", m_filename, ", error: ", GetLastError());
               return false;
            }
         }
      }
      
      // Write log header
      string header = StringFormat("=== Log started: %s ===\n", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
      FileWriteString(m_fileHandle, header);
      FileFlush(m_fileHandle);
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialize logger                                              |
//+------------------------------------------------------------------+
void CEALogger::Deinitialize()
{
   if (m_fileHandle != INVALID_HANDLE)
   {
      // Write log footer
      string footer = StringFormat("\n=== Log ended: %s ===\n\n", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
      FileWriteString(m_fileHandle, footer);
      
      // Close the file
      FileClose(m_fileHandle);
      m_fileHandle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Format log message                                               |
//+------------------------------------------------------------------+
string CEALogger::FormatMessage(const string message, const ENUM_LOG_LEVEL level)
{
   if (level < 0 || level >= ArraySize(m_levelNames))
      return "";
      
   datetime currentTime = TimeCurrent();
   string timeStr = TimeToString(currentTime, TIME_DATE|TIME_SECONDS);
   string levelStr = m_levelNames[level];
   
   return StringFormat("%s [%s] %s", timeStr, levelStr, message);
}

//+------------------------------------------------------------------+
//| Log a message                                                    |
//+------------------------------------------------------------------+
void CEALogger::Log(const string message, const ENUM_LOG_LEVEL level)
{
   // Check log level
   if (level > m_logLevel)
      return;
      
   // Format the message
   string formattedMsg = FormatMessage(message, level);
   if (formattedMsg == "")
      return;
   
   // Output to console
   if (m_consoleOutput)
   {
      switch (level)
      {
         case LOG_LEVEL_ERROR:
            Print("ERROR: ", message);
            break;
         case LOG_LEVEL_WARN:
            Print("WARN: ", message);
            break;
         case LOG_LEVEL_INFO:
            Print("INFO: ", message);
            break;
         case LOG_LEVEL_DEBUG:
            Print("DEBUG: ", message);
            break;
         case LOG_LEVEL_TRACE:
            Print("TRACE: ", message);
            break;
      }
   }
   
   // Output to file
   if (m_fileOutput && m_fileHandle != INVALID_HANDLE)
   {
      FileWriteString(m_fileHandle, formattedMsg + "\n");
      FileFlush(m_fileHandle);
   }
}

//+------------------------------------------------------------------+
//| Get last error text                                              |
//+------------------------------------------------------------------+
string CEALogger::GetLastErrorText(const int errorCode = 0)
{
   int code = (errorCode == 0) ? GetLastError() : errorCode;
   
   switch (code)
   {
      // Common errors
      case 0:      return "No error";
      case 1:      return "No error returned, but the result is unknown";
      case 2:      return "Common error";
      case 3:      return "Invalid trade parameters";
      case 4:      return "Trade server is busy";
      case 5:      return "Old version of the client terminal";
      case 6:      return "No connection with trade server";
      case 7:      return "Not enough rights";
      case 8:      return "Too frequent requests";
      case 9:      return "Malfunctional trade operation";
      case 64:     return "Account disabled";
      case 65:     return "Invalid account";
      case 128:    return "Trade timeout";
      case 129:    return "Invalid price";
      case 130:    return "Invalid stops";
      case 131:    return "Invalid trade volume";
      case 132:    return "Market is closed";
      case 133:    return "Trade is disabled";
      case 134:    return "Not enough money";
      case 135:    return "Price changed";
      case 136:    return "Off quotes";
      case 137:    return "Broker is busy";
      case 138:    return "Requote";
      case 139:    return "Order is locked";
      case 140:    return "Long positions only allowed";
      case 141:    return "Too many requests";
      case 145:    return "Modification denied because order is too close to market";
      case 146:    return "Trade context is busy";
      case 147:    return "Expirations are denied by broker";
      case 148:    return "Too many open and pending orders";
      case 149:    return "Hedging is prohibited";
      case 150:    return "Prohibited by FIFO rules";
      
      // Custom errors
      case 4000:   return "No error (the operation completed successfully)";
      case 4001:   return "Wrong function pointer";
      case 4002:   return "Array index is out of range";
      case 4003:   return "No memory for function call stack";
      case 4004:   return "Recursive stack overflow";
      case 4005:   return "Not enough stack for parameter";
      case 4006:   return "No memory for parameter string";
      case 4007:   return "No memory for temp string";
      case 4008:   return "Not initialized string";
      case 4009:   return "Invalid string parameter";
      case 4010:   return "Invalid string position";
      case 4011:   return "String parameter too long";
      case 4012:   return "Invalid array";
      case 4013:   return "Array resize error";
      case 4014:   return "String resize error";
      case 4015:   return "Not initialized array";
      case 4016:   return "Invalid array size";
      case 4017:   return "Abnormal program termination";
      case 4018:   return "Unhandled exception";
      case 4019:   return "Invalid pointer";
      case 4020:   return "Invalid variable type";
      case 4021:   return "Function is not allowed in testing mode";
      case 4022:   return "Function is not confirmed";
      case 4050:   return "Invalid function parameters count";
      case 4051:   return "Invalid function parameter value";
      case 4052:   return "String function internal error";
      case 4053:   return "Some array error";
      case 4054:   return "Incorrect series array using";
      case 4055:   return "Custom indicator error";
      case 4056:   return "Arrays are incompatible";
      case 4057:   return "Global variables processing error";
      case 4058:   return "Global variable not found";
      case 4059:   return "Function is not allowed in testing mode";
      case 4060:   return "Function is not confirmed";
      case 4061:   return "Send mail error";
      case 4062:   return "String parameter expected";
      case 4063:   return "Integer parameter expected";
      case 4064:   return "Double parameter expected";
      case 4065:   return "Array as parameter expected";
      case 4066:   return "Requested history not found";
      case 4067:   return "Some error in trade operation";
      case 4099:   return "End of file";
      case 4100:   return "Some file error";
      case 4101:   return "Wrong file name";
      case 4102:   return "Too many opened files";
      case 4103:   return "Cannot open file";
      case 4104:   return "Incompatible access to a file";
      case 4105:   return "No order selected";
      case 4106:   return "Unknown symbol";
      case 4107:   return "Invalid price";
      case 4108:   return "Invalid ticket";
      case 4109:   return "Trade is not allowed";
      case 4110:   return "Longs are not allowed";
      case 4111:   return "Shorts are not allowed";
      case 4200:   return "Object already exists";
      case 4201:   return "Unknown object property";
      case 4202:   return "Object does not exist";
      case 4203:   return "Unknown object type";
      case 4204:   return "No object name";
      case 4205:   return "Object coordinates error";
      case 4206:   return "No specified subwindow";
      case 4207:   return "Some error in object function";
      default:     return "Unknown error";
   }
}
