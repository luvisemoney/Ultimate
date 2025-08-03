//+------------------------------------------------------------------+
//|                                               EscapeEA_Tests.mq5 |
//|                                      Copyright 2025, EscapeEA     |
//|                                          https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"
#property script_show_inputs
#property script_show_confirm

// Include test runner and test cases
#include "TestRunner.mqh"
#include "Unit\TestKnowledgeBase.mqh"

// Input parameters
input bool InpVerboseOutput = true;  // Show detailed test output

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("=== Starting Test Execution ===");
   
   // Initialize test runner
   Print("1. Initializing test runner...");
   CTestRunner runner(InpVerboseOutput);
   
   // Add test cases
   Print("2. Adding test cases...");
   CTestKnowledgeBase *test = new CTestKnowledgeBase();
   if(test == NULL)
     {
      Print("ERROR: Failed to create test instance!");
      return;
     }
     
   Print("3. Adding test to runner...");
   runner.AddTest(test);
   
   // Run all tests
   Print("4. Running tests...");
   runner.RunAllTests();
   
   // Print final result
   Print("5. Test execution completed. Generating report...");
   if(runner.FailedTests() > 0)
     {
      PrintFormat("\n=== %d TEST(S) FAILED! ===\n", runner.FailedTests());
     }
   else
     {
      Print("\n=== ALL TESTS PASSED! ===\n");
     }
     
   Print("=== Test Execution Finished ===");
  }
//+------------------------------------------------------------------+
