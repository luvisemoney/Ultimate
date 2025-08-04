//+------------------------------------------------------------------+
//|                                               TestLogger.mq5 |
//|                                      Copyright 2025, EscapeEA     |
//|                                          https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"
#property strict

// Include the Logger class
#include "Include/Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| Test script to verify Logger functionality                      |
//+------------------------------------------------------------------+
void OnStart()
  {
   // Initialize logger
   string logPath = "Logs\\Test";
   string logPrefix = "TestLogger";
   int maxLogFiles = 5;
   int maxLogSizeMB = 1;
   ENUM_LOG_LEVEL minLogLevel = LOG_LEVEL_DEBUG;
   bool enableConsole = true;
   
   // Initialize logger with test parameters
   if(!CLogger::Instance().Initialize(logPath, logPrefix, minLogLevel, enableConsole, maxLogFiles, maxLogSizeMB))
     {
      Print("Failed to initialize logger!");
      return;
     }
   
   Print("Logger initialized successfully!");
   
   // Test different log levels
   Print("\nTesting log levels:");
   
   // Debug level
   CLogger::Instance().Debug("This is a debug message", "TestLogger");
   Print("- Debug message logged");
   
   // Info level
   CLogger::Instance().Info("This is an info message", "TestLogger");
   Print("- Info message logged");
   
   // Warning level
   CLogger::Instance().Warning("This is a warning message", "TestLogger");
   Print("- Warning message logged");
   
   // Error level
   CLogger::Instance().Error("This is an error message", "TestLogger");
   Print("- Error message logged");
   
   // Critical level
   CLogger::Instance().Critical("This is a critical message", "TestLogger");
   Print("- Critical message logged");
   
   // Test log rotation by writing many entries
   Print("\nTesting log rotation by writing 1000 log entries...");
   for(int i = 0; i < 1000; i++)
     {
      CLogger::Instance().Info("Test log entry #" + IntegerToString(i) + 
                             " - This is a test message to fill up the log file quickly.", 
                             "TestLogger");
     }
   
   // Flush any pending log entries
   CLogger::Instance().Flush();
   Print("Log entries flushed to disk");
   
   // Test log level filtering
   Print("\nTesting log level filtering:");
   ENUM_LOG_LEVEL currentLevel = CLogger::Instance().GetLogLevel();
   Print("Current log level: ", EnumToString(currentLevel));
   
   // Change log level to only show errors and above
   CLogger::Instance().SetLogLevel(LOG_LEVEL_ERROR);
   Print("Changed log level to LOG_LEVEL_ERROR");
   
   // These should not appear in the log file
   CLogger::Instance().Debug("This debug message should NOT appear", "TestLogger");
   CLogger::Instance().Info("This info message should NOT appear", "TestLogger");
   CLogger::Instance().Warning("This warning message should NOT appear", "TestLogger");
   
   // These should appear in the log file
   CLogger::Instance().Error("This error message SHOULD appear", "TestLogger");
   CLogger::Instance().Critical("This critical message SHOULD appear", "TestLogger");
   
   // Restore original log level
   CLogger::Instance().SetLogLevel(minLogLevel);
   
   Print("\nLogger test completed. Check the log files in the 'MQL5/Common/Files/Logs/Test' directory.");
   Print("Look for files starting with: ", logPrefix, "_");
  }
//+------------------------------------------------------------------+
