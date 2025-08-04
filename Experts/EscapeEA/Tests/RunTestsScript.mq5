//+------------------------------------------------------------------+
//|                                               RunTestsScript.mq5 |
//|                                      Copyright 2025, EscapeEA     |
//|                                          https://www.escapeea.com |
//+------------------------------------------------------------------+
#property script_show_inputs
#property script_show_confirm

// Include test runner and test cases
#include "TestRunner.mqh"
#include "Unit\\TestKnowledgeBase.mqh"
// Note: TestRiskManager is a standalone script, not a test class

// Input parameters
input bool   InpVerboseOutput = true;      // Show detailed test output
input string InpReportPath = "TestReport.html"; // Path to save HTML report

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   // Initialize test runner with HTML report path
   CTestRunner runner(InpVerboseOutput, InpReportPath);
   
   // Add test cases that use the test framework
   runner.AddTest(new CTestKnowledgeBase());
   // Add more test classes here as they are created
   
   // Note: TestRiskManager.mq5 is a standalone script that needs to be run separately
   
   // Run all tests (this will generate the HTML report automatically)
   runner.RunAllTests();
   
   // Display completion message
   if(FileIsExist(InpReportPath, 0))
     {
      Print("\nTest execution completed. Report saved to: ", InpReportPath);
     }
     
   // Display test summary in the Experts tab
   // Display test summary in the Experts tab
   Print("\n=== Test Execution Summary ===");
   Print("----------------------------");
   Print(StringFormat("Total Tests:  %d", runner.TotalTests()));
   Print(StringFormat("Passed:       %d (%.1f%%)", 
                     runner.PassedTests(), 
                     runner.PassRate()));
   Print(StringFormat("Failed:       %d", runner.FailedTests()));
   Print(StringFormat("Skipped:      %d", runner.SkippedTests()));
   Print(StringFormat("Duration:     %d ms", runner.GetStats().totalDurationMs));
   Print("============================\n");
   
   // Note about standalone test scripts
   Print("Note: Some tests (like TestRiskManager.mq5) are standalone scripts");
   Print("and need to be run separately from the Scripts section in MetaEditor.");
   
   // If there were failures, list them
   if(runner.FailedTests() > 0)
     {
      Print("Failed Tests:");
      Print("------------");
      
      for(int i = 0; i < runner.TotalTests(); i++)
        {
         TestResult result = runner.GetTestResult(i);
         if(result.result == TEST_FAILED)
           {
            PrintFormat("\x1B[31m[FAILED] %s\x1B[0m - %s", 
                       result.testName, result.message);
           }
        }
      Print("");
     }
  }
//+------------------------------------------------------------------+
