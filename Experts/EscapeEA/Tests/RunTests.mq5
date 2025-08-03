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
   // Initialize test runner
   CTestRunner runner(InpVerboseOutput);
   
   // Add test cases
   runner.AddTest(new CTestKnowledgeBase());
   
   // Run all tests
   runner.RunAllTests();
   
   // Print final result
   if(runner.FailedTests() > 0)
     {
      PrintFormat("\n=== %d TEST(S) FAILED! ===\n", runner.FailedTests());
     }
   else
     {
      Print("\n=== ALL TESTS PASSED! ===\n");
     }
  }
//+------------------------------------------------------------------+
