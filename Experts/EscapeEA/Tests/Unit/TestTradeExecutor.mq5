//+------------------------------------------------------------------+
//|                                            TestTradeExecutor.mq5 |
//|                                      Copyright 2025, EscapeEA     |
//|                                          https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include "TestBase.mqh"
#include "..\\Mocks\\MockTradeExecutor.mqh"

//+------------------------------------------------------------------+
//| Test class for CTradeExecutor                                    |
//+------------------------------------------------------------------+
class CTestTradeExecutor : public CTestBase
  {
private:
   CMockTradeExecutor *m_tradeExecutor;
   string            m_symbol;
   
public:
   // Constructor/destructor
                     CTestTradeExecutor() : CTestBase("CTradeExecutor Tests", true), m_tradeExecutor(NULL)
                     {
                        m_symbol = _Symbol;
                     }
                    ~CTestTradeExecutor() {}
   
   // Test fixture setup/teardown
   void SetUp()
     {
        // Initialize test objects
        this.m_tradeExecutor = new CMockTradeExecutor();
        this.m_tradeExecutor.SetSymbol("EURUSD");
        this.m_tradeExecutor.SetSlippage(10.0);
     }
     
   void TearDown()
     {
        // Clean up
        delete this.m_tradeExecutor;
     }
   
   // Test methods
   ENUM_TEST_RESULT Test_OpenPosition_Buy()
     {
        double volume = 0.1;
        double price = 1.2500;
        double sl = 1.2000;
        double tp = 1.3000;
        string cmt = "Test Buy";
        
        // Test successful buy
        if(!this.m_tradeExecutor.OpenPosition(ORDER_TYPE_BUY, volume, price, sl, tp, cmt))
           return TEST_FAILED;
           
        // Verify trade history
        if(!this.AssertEqual(1, this.m_tradeExecutor.GetTradeHistoryCount(), 0, "Trade history count should be 1"))
           return TEST_FAILED;
           
        // Get the trade details
        STradeRecord trade;
        if(!this.m_tradeExecutor.GetLastTrade(trade))
           return TEST_FAILED;
           
        // Verify trade details using getter methods
        if(!this.AssertEqual((int)ORDER_TYPE_BUY, (int)trade.GetType(), 0, "Trade type should be BUY"))
           return TEST_FAILED;
           
        if(!this.AssertEqual(volume, trade.GetVolume(), 0.0001, "Volume mismatch"))
           return TEST_FAILED;
           
        if(!this.AssertEqual(sl, trade.GetStopLoss(), 0.0001, "Stop loss mismatch"))
           return TEST_FAILED;
           
        if(!this.AssertEqual(tp, trade.GetTakeProfit(), 0.0001, "Take profit mismatch"))
           return TEST_FAILED;
           
        if(!this.AssertStringEqual(cmt, trade.GetComment(), true, "Comment mismatch"))
           return TEST_FAILED;
           
        return TEST_PASSED;
     }
     
   ENUM_TEST_RESULT Test_OpenPosition_Sell()
     {
        double volume = 0.1;
        double price = 1.2500;
        double sl = 1.3000;
        double tp = 1.2000;
        string cmt = "Test Sell";
        
        // Test successful sell
        if(!this.m_tradeExecutor.OpenPosition(ORDER_TYPE_SELL, volume, price, sl, tp, cmt))
           return TEST_FAILED;
           
        // Get the trade details
        STradeRecord trade;
        if(!this.m_tradeExecutor.GetLastTrade(trade))
           return TEST_FAILED;
           
        // Verify trade details using getter methods
        if(!this.AssertEqual((int)ORDER_TYPE_SELL, (int)trade.GetType(), 0, "Trade type should be SELL"))
           return TEST_FAILED;
           
        if(!this.AssertEqual(volume, trade.GetVolume(), 0.0001, "Volume mismatch"))
           return TEST_FAILED;
           
        if(!this.AssertEqual(sl, trade.GetStopLoss(), 0.0001, "Stop loss mismatch"))
           return TEST_FAILED;
           
        if(!this.AssertEqual(tp, trade.GetTakeProfit(), 0.0001, "Take profit mismatch"))
           return TEST_FAILED;
           
        if(!this.AssertStringEqual(cmt, trade.GetComment(), true, "Comment mismatch"))
           return TEST_FAILED;
           
        return TEST_PASSED;
     }
     
   ENUM_TEST_RESULT Test_OpenPosition()
     {
        // Test opening a buy position
        if(!this.m_tradeExecutor.OpenPosition(ORDER_TYPE_BUY, 0.1, 1.2000, 1.1900, 1.3000, "Test Buy"))
           return TEST_FAILED;
           
        // Test opening a sell position
        if(!this.m_tradeExecutor.OpenPosition(ORDER_TYPE_SELL, 0.1, 1.2000, 1.2100, 1.1000, "Test Sell"))
           return TEST_FAILED;
           
        // Verify trade history count
        if(this.m_tradeExecutor.GetTradeHistoryCount() != 2)
           return TEST_FAILED;
           
        return TEST_PASSED;
     }
     
   ENUM_TEST_RESULT Test_OpenPosition_ErrorHandling()
     {
        // Force an error
        this.m_tradeExecutor.ForceError(true, "Test error message");
        
        // Test that opening a position fails when error is forced
        if(this.m_tradeExecutor.OpenPosition(ORDER_TYPE_BUY, 0.1, 1.2000, 1.1900, 1.3000, "Test Error"))
           return TEST_FAILED;
           
        // Verify error message
        if(StringLen(this.m_tradeExecutor.GetLastError()) == 0)
           return TEST_FAILED;
           
        return TEST_PASSED;
     }
     
   ENUM_TEST_RESULT Test_ClosePosition()
     {
        // First open a position to close
        if(!this.m_tradeExecutor.OpenPosition(ORDER_TYPE_BUY, 0.1, 1.2000, 1.1900, 1.3000, "Test Close"))
           return TEST_FAILED;
           
        // Test closing the position
        if(!this.m_tradeExecutor.ClosePosition(123, 0.1))
           return TEST_FAILED;
           
        // Test error handling
        this.m_tradeExecutor.ForceError(true);
        if(this.m_tradeExecutor.ClosePosition(123, 0.1))
           return TEST_FAILED;
           
        return TEST_PASSED;
     }
     
   ENUM_TEST_RESULT Test_ModifyPosition()
     {
        // First open a position to modify
        if(!this.m_tradeExecutor.OpenPosition(ORDER_TYPE_BUY, 0.1, 1.2000, 1.3000, "Test Modify"))
           return TEST_FAILED;
           
        // Test modifying the position
        if(!this.m_tradeExecutor.ModifyPosition(123, 1.2500, 1.3500))
           return TEST_FAILED;
           
        // Test error handling
        this.m_tradeExecutor.ForceError(true);
        if(this.m_tradeExecutor.ModifyPosition(123, 1.2500, 1.3500))
           return TEST_FAILED;
           
        return TEST_PASSED;
     }
     
   // Main test runner
   virtual ENUM_TEST_RESULT Run()
     {
        ENUM_TEST_RESULT result = TEST_PASSED;
        
        // Run all test methods
        result = (ENUM_TEST_RESULT)MathMax((int)result, (int)Test_OpenPosition_Buy());
        result = (ENUM_TEST_RESULT)MathMax((int)result, (int)Test_OpenPosition_Sell());
        result = (ENUM_TEST_RESULT)MathMax((int)result, (int)Test_OpenPosition());
        result = (ENUM_TEST_RESULT)MathMax((int)result, (int)Test_OpenPosition_ErrorHandling());
        result = (ENUM_TEST_RESULT)MathMax((int)result, (int)Test_ClosePosition());
        result = (ENUM_TEST_RESULT)MathMax((int)result, (int)Test_ModifyPosition());
        
        return result;
     }
  };

// CTestBase is already defined in TestBase.mqh, so we don't need to redefine it here

//+------------------------------------------------------------------+
//| Test Runner Class                                                |
//+------------------------------------------------------------------+
class CTestRunner
  {
private:
   CTestBase        *m_tests[];    // Array of test cases
   
public:
   // Constructor/destructor
                     CTestRunner() { ArrayResize(m_tests, 0); }
                    ~CTestRunner() { for(int i=0; i<ArraySize(m_tests); i++) delete m_tests[i]; }
   
   // Add a test to the runner
   void              AddTest(CTestBase *test) 
                     { 
                        if(test == NULL) return;
                        int size = ArraySize(m_tests);
                        if(ArrayResize(m_tests, size + 1) == -1) return;
                        m_tests[size] = test;
                     }
   
   // Run all tests
   void              RunTests()
                     {
                        int total = ArraySize(m_tests);
                        Print("\nRunning ", total, " test(s)...\n");
                        
                        for(int i = 0; i < total; i++)
                        {
                           if(CheckPointer(m_tests[i]) == POINTER_INVALID) continue;
                           
                           Print("Test: ", m_tests[i].Name());
                           m_tests[i].SetUp();
                           ENUM_TEST_RESULT result = m_tests[i].Run();
                           m_tests[i].TearDown();
                           
                           string status = (result == TEST_PASSED) ? "PASSED" : 
                                         ((result == TEST_FAILED) ? "FAILED" : "SKIPPED");
                           Print("  => ", status, "\n");
                        }
                     }
   
   // Print test summary
   void              PrintSummary()
                     {
                        int passed = 0, failed = 0, skipped = 0;
                        int total = ArraySize(m_tests);
                        
                        for(int i = 0; i < total; i++)
                        {
                           if(CheckPointer(m_tests[i]) == POINTER_INVALID) continue;
                           
                           m_tests[i].SetUp();
                           ENUM_TEST_RESULT result = m_tests[i].Run();
                           m_tests[i].TearDown();
                           
                           if(result == TEST_PASSED) passed++;
                           else if(result == TEST_FAILED) failed++;
                           else skipped++;
                        }
                        
                        Print("\n=== Test Summary ===");
                        Print("Total: ", total);
                        Print("Passed: ", passed);
                        Print("Failed: ", failed);
                        Print("Skipped: ", skipped);
                        Print("===================\n");
                     }
  };

//+------------------------------------------------------------------+
//| Test registration and execution                                  |
//+------------------------------------------------------------------+
void OnStart()
  {
   // Initialize the test runner
   CTestRunner *runner = new CTestRunner();
   if(CheckPointer(runner) == POINTER_INVALID)
     {
      Print("Error: Failed to create test runner");
      return;
     }
   
   // Add test cases
   CTestTradeExecutor *tradeExecutorTest = new CTestTradeExecutor();
   if(CheckPointer(tradeExecutorTest) != POINTER_INVALID)
     {
      runner.AddTest(tradeExecutorTest);
     }
   
   // Run tests if we have any
   bool hasTests = false;
   
   // Check if we have any tests by running a test
   CTestBase *test = new CTestTradeExecutor();
   if(test != NULL)
     {
      hasTests = true;
      Print("Running tests...");
      runner.RunTests();
      runner.PrintSummary();
      delete test;
     }
   else
     {
      Print("No tests to run!");
     }
   
   // Cleanup
   if(CheckPointer(runner) == POINTER_DYNAMIC)
      delete runner;
  }
//+------------------------------------------------------------------+
