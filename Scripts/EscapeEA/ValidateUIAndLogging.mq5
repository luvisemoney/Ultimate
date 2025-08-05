//+------------------------------------------------------------------+
//|                                        ValidateUIAndLogging.mq5  |
//|                                      Copyright 2025, EscapeEA     |
//|                                          https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"
#property script_show_inputs
#property strict

// Input parameters
input bool TestPaperEA = true;      // Test Paper EA
input bool TestLiveEA = true;       // Test Live EA
input int  TestDuration = 10;       // Test duration (seconds)

// Global variables
CLogger *g_logger = NULL;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   // Initialize logger
   g_logger = CLogger::Instance();
   g_logger.Initialize("Logs/EscapeEA/Tests/", "UI_Log_Test_");
   
   Print("=== Starting UI and Logging Validation ===");
   LOG_INFO("Starting UI and Logging Validation Test", "OnStart");
   
   // Run tests
   if(TestPaperEA)
      TestEA("PaperEA");
      
   if(TestLiveEA)
      TestEA("LiveEA");
      
   // Wait for test duration
   int startTime = (int)TimeCurrent();
   while(!IsStopped() && (TimeCurrent() - startTime) < TestDuration)
     {
      // Update status every second
      static int lastUpdate = 0;
      if(TimeCurrent() - lastUpdate >= 1)
        {
         lastUpdate = (int)TimeCurrent();
         int remaining = TestDuration - (lastUpdate - startTime);
         PrintFormat("Test running... %d seconds remaining", remaining);
        }
      
      // Small delay to prevent high CPU usage
      Sleep(100);
     }
     
   // Cleanup
   LOG_INFO("UI and Logging Validation Test Completed", "OnStart");
   g_logger.Flush();
   delete g_logger;
   g_logger = NULL;
   
   Print("=== UI and Logging Validation Completed ===");
  }

//+------------------------------------------------------------------+
//| Test a specific EA                                               |
//+------------------------------------------------------------------+
void TestEA(string eaName)
  {
   LOG_INFO(StringFormat("Testing %s", eaName), "TestEA");
   
   // Check if EA is attached to the chart
   string eaLabel = StringFormat("%s_Status_Label", eaName);
   if(ObjectFind(0, eaLabel) < 0)
     {
      LOG_ERROR(StringFormat("%s UI not found on chart", eaName), "TestEA");
      PrintFormat("ERROR: %s UI not found on chart. Please attach %s to the chart first.", eaName, eaName);
      return;
     }
   
   // Verify UI elements
   if(!VerifyUIElements(eaName))
     {
      LOG_ERROR(StringFormat("%s UI verification failed", eaName), "TestEA");
      PrintFormat("ERROR: %s UI verification failed", eaName);
      return;
     }
   
   LOG_INFO(StringFormat("%s UI verification passed", eaName), "TestEA");
   PrintFormat("SUCCESS: %s UI verification passed", eaName);
   
   // Check log files
   if(!VerifyLogFiles(eaName))
     {
      LOG_ERROR(StringFormat("%s log verification failed", eaName), "TestEA");
      PrintFormat("ERROR: %s log verification failed", eaName);
      return;
     }
   
   LOG_INFO(StringFormat("%s log verification passed", eaName), "TestEA");
   PrintFormat("SUCCESS: %s log verification passed", eaName);
  }

//+------------------------------------------------------------------+
//| Verify UI elements                                               |
//+------------------------------------------------------------------+
bool VerifyUIElements(string eaName)
  {
   LOG_INFO(StringFormat("Verifying %s UI elements", eaName), "VerifyUIElements");
   
   // List of expected UI elements
   string elements[] = {
      "Status",
      "Equity",
      "Balance",
      "Trades",
      "Profit"
   };
   
   if(eaName == "LiveEA")
     {
      ArrayResize(elements, 6);
      elements[5] = "Connection";
     }
   
   // Check each element
   bool allFound = true;
   for(int i = 0; i < ArraySize(elements); i++)
     {
      string elementName = StringFormat("%s_%s_Label", eaName, elements[i]);
      if(ObjectFind(0, elementName) < 0)
        {
         LOG_ERROR(StringFormat("UI element not found: %s", elementName), "VerifyUIElements");
         PrintFormat("ERROR: UI element not found: %s", elementName);
         allFound = false;
        }
     }
   
   return allFound;
  }

//+------------------------------------------------------------------+
//| Verify log files                                                 |
//+------------------------------------------------------------------+
bool VerifyLogFiles(string eaName)
  {
   LOG_INFO(StringFormat("Verifying %s log files", eaName), "VerifyLogFiles");
   
   // Build log file path
   string logPath = StringFormat("Logs\\EscapeEA\\%s\\%s_%s.log", 
                               eaName, eaName, TimeToString(TimeCurrent(), TIME_DATE));
   StringReplace(logPath, ".", "");
   
   // Check if log file exists
   if(!FileIsExist(logPath, FILE_COMMON))
     {
      LOG_ERROR(StringFormat("Log file not found: %s", logPath), "VerifyLogFiles");
      PrintFormat("ERROR: Log file not found: %s", logPath);
      return false;
     }
   
   // Check log file size
   int handle = FileOpen(logPath, FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(handle == INVALID_HANDLE)
     {
      LOG_ERROR(StringFormat("Failed to open log file: %s, error: %d", logPath, GetLastError()), "VerifyLogFiles");
      PrintFormat("ERROR: Failed to open log file: %s, error: %d", logPath, GetLastError());
      return false;
     }
   
   ulong fileSize = FileSize(handle);
   FileClose(handle);
   
   if(fileSize == 0)
     {
      LOG_ERROR(StringFormat("Log file is empty: %s", logPath), "VerifyLogFiles");
      PrintFormat("ERROR: Log file is empty: %s", logPath);
      return false;
     }
   
   LOG_INFO(StringFormat("Log file verified: %s (%d bytes)", logPath, fileSize), "VerifyLogFiles");
   PrintFormat("SUCCESS: Log file verified: %s (%d bytes)", logPath, fileSize);
   
   return true;
  }
//+------------------------------------------------------------------+
