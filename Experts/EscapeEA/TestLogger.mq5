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
   // Test directory creation
   string testDir = "TestDir\\SubDir\\NestedDir";
   Print("Testing directory creation for: ", testDir);
   
   // Call the function directly
   bool result = CreateDirectoryRecursive(testDir, 3);
   
   // Check result
   if(result)
     {
      Print("Successfully created directory: ", testDir);
      
      // Verify the directory was created
      if(FileIsExist(testDir, FILE_COMMON))
         Print("Verified directory exists: ", testDir);
      else
         Print("ERROR: Directory was not created: ", testDir);
     }
   else
     {
      Print("Failed to create directory: ", testDir);
      Print("Last error: ", GetLastError());
     }
  }
//+------------------------------------------------------------------+
