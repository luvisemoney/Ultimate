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
                    ~CTestTradeExecutor() 
                     {
                        if(CheckPointer(m_tradeExecutor) == POINTER_DYNAMIC)
                           delete m_tradeExecutor;
                     }
   
   // Test fixture setup/teardown
   void SetUp() override
     {
        // Initialize test objects
        m_tradeExecutor = new CMockTradeExecutor();
        if(CheckPointer(m_tradeExecutor) != POINTER_INVALID)
          {
           m_tradeExecutor.SetSymbol("EURUSD");
           m_tradeExecutor.SetSlippage(10.0);
          }
     }
     
   void TearDown() override
     {
        // Clean up
        if(CheckPointer(m_tradeExecutor) == POINTER_DYNAMIC)
          {
           delete m_tradeExecutor;
           m_tradeExecutor = NULL;
          }
     }
   
   // Test methods
   ENUM_TEST_RESULT Test_OpenPosition_Buy()
     {
        Print("Test_OpenPosition_Buy: Starting test");
        
        if(CheckPointer(m_tradeExecutor) == POINTER_INVALID)
          {
           Print("Test_OpenPosition_Buy: m_tradeExecutor is invalid");
           return TEST_FAILED;
          }
           
        double volume = 0.1;
        double price = 1.2500;
        double sl = 1.2000;
        double tp = 1.3000;
        string cmt = "Test Buy";
        
        // Test successful buy
        Print("Test_OpenPosition_Buy: Opening position");
        if(!m_tradeExecutor.OpenPosition(ORDER_TYPE_BUY, volume, sl, tp, cmt))
          {
           Print("Test_OpenPosition_Buy: Failed to open position");
           return TEST_FAILED;
          }
           
        // Verify trade history
        int historyCount = m_tradeExecutor.GetTradeHistoryCount();
        Print("Test_OpenPosition_Buy: Trade history count = ", historyCount);
        if(!AssertEqual(1, historyCount, 0, "Trade history count should be 1"))
           return TEST_FAILED;
           
        // Get the trade details
        STradeRecord trade;
        if(!m_tradeExecutor.GetLastTrade(trade))
          {
           Print("Test_OpenPosition_Buy: Failed to get last trade");
           return TEST_FAILED;
          }
           
        // Debug print trade details
        Print("Test_OpenPosition_Buy: Trade details:");
        Print("Type: ", EnumToString((ENUM_TRADE_TYPE)trade.type));
        Print("Lots: ", trade.lots);
        Print("StopLoss: ", trade.stopLoss);
        Print("TakeProfit: ", trade.takeProfit);
        Print("Comment: '", trade.comment, "'");
        
        // Verify trade details using direct member access
        if(!AssertEqual((int)TRADE_TYPE_BUY, (int)trade.type, 0, "Trade type should be BUY"))
           return TEST_FAILED;
           
        if(!AssertEqual(volume, trade.lots, 0.0001, "Volume mismatch"))
           return TEST_FAILED;
           
        if(!AssertEqual(sl, trade.stopLoss, 0.0001, "Stop loss mismatch"))
           return TEST_FAILED;
           
        if(!AssertEqual(tp, trade.takeProfit, 0.0001, "Take profit mismatch"))
           return TEST_FAILED;
           
        if(!AssertStringEqual(cmt, trade.comment, true, "Comment mismatch"))
           return TEST_FAILED;
           
        Print("Test_OpenPosition_Buy: Test passed");
        return TEST_PASSED;
     }
     
   ENUM_TEST_RESULT Test_OpenPosition_Sell()
     {
        if(CheckPointer(m_tradeExecutor) == POINTER_INVALID)
           return TEST_FAILED;
           
        double volume = 0.1;
        double price = 1.2500;
        double sl = 1.3000;
        double tp = 1.2000;
        string cmt = "Test Sell";
        
        // Test successful sell
        if(!m_tradeExecutor.OpenPosition(ORDER_TYPE_SELL, volume, sl, tp, cmt))
           return TEST_FAILED;
           
        // Get the trade details
        STradeRecord trade;
        if(!m_tradeExecutor.GetLastTrade(trade))
           return TEST_FAILED;
           
        // Verify trade details using direct member access
        if(!AssertEqual((int)TRADE_TYPE_SELL, (int)trade.type, 0, "Trade type should be SELL"))
           return TEST_FAILED;
           
        if(!AssertEqual(volume, trade.lots, 0.0001, "Volume mismatch"))
           return TEST_FAILED;
           
        if(!AssertEqual(sl, trade.stopLoss, 0.0001, "Stop loss mismatch"))
           return TEST_FAILED;
           
        if(!AssertEqual(tp, trade.takeProfit, 0.0001, "Take profit mismatch"))
           return TEST_FAILED;
           
        if(!AssertStringEqual(cmt, trade.comment, true, "Comment mismatch"))
           return TEST_FAILED;
           
        return TEST_PASSED;
     }
     
   ENUM_TEST_RESULT Test_OpenPosition()
     {
        if(CheckPointer(m_tradeExecutor) == POINTER_INVALID)
           return TEST_FAILED;
           
        // Test opening a buy position
        if(!m_tradeExecutor.OpenPosition(ORDER_TYPE_BUY, 0.1, 1.1900, 1.3000, "Test Buy"))
           return TEST_FAILED;
           
        // Test opening a sell position
        if(!m_tradeExecutor.OpenPosition(ORDER_TYPE_SELL, 0.1, 1.2100, 1.1000, "Test Sell"))
           return TEST_FAILED;
           
        // Verify trade history count
        if(m_tradeExecutor.GetTradeHistoryCount() != 2)
           return TEST_FAILED;
           
        return TEST_PASSED;
     }
     
   ENUM_TEST_RESULT Test_OpenPosition_ErrorHandling()
     {
        if(CheckPointer(m_tradeExecutor) == POINTER_INVALID)
           return TEST_FAILED;
           
        // Force an error
        m_tradeExecutor.ForceError(true, "Test error message");
        
        // Test that opening a position fails when error is forced
        if(m_tradeExecutor.OpenPosition(ORDER_TYPE_BUY, 0.1, 1.1900, 1.3000, "Test Error"))
           return TEST_FAILED;
           
        // Verify error message
        if(StringLen(m_tradeExecutor.GetLastError()) == 0)
           return TEST_FAILED;
           
        // Reset error state
        m_tradeExecutor.ForceError(false);
           
        return TEST_PASSED;
     }
     
   ENUM_TEST_RESULT Test_ClosePosition()
     {
        if(CheckPointer(m_tradeExecutor) == POINTER_INVALID)
           return TEST_FAILED;
           
        // First open a position to close
        if(!m_tradeExecutor.OpenPosition(ORDER_TYPE_BUY, 0.1, 1.1900, 1.3000, "Test Close"))
           return TEST_FAILED;
           
        // Get the ticket number of the opened position
        STradeRecord trade;
        if(!m_tradeExecutor.GetLastTrade(trade))
           return TEST_FAILED;
           
        ulong ticket = trade.ticket;
        Print("Test_ClosePosition: Closing position with ticket ", ticket);
        
        // Test closing the position
        if(!m_tradeExecutor.ClosePosition(ticket, 0.1))
           return TEST_FAILED;
           
        // Verify position was closed (history count should be 0)
        if(m_tradeExecutor.GetTradeHistoryCount() != 0)
           return TEST_FAILED;
           
        // Test error handling - open another position first
        if(!m_tradeExecutor.OpenPosition(ORDER_TYPE_BUY, 0.1, 1.1900, 1.3000, "Test Close Error"))
           return TEST_FAILED;
           
        if(!m_tradeExecutor.GetLastTrade(trade))
           return TEST_FAILED;
           
        ticket = trade.ticket;
        m_tradeExecutor.ForceError(true);
        if(m_tradeExecutor.ClosePosition(ticket, 0.1))
           return TEST_FAILED;
           
        // Reset error state
        m_tradeExecutor.ForceError(false);
           
        return TEST_PASSED;
     }
     
   ENUM_TEST_RESULT Test_ModifyPosition()
     {
        if(CheckPointer(m_tradeExecutor) == POINTER_INVALID)
           return TEST_FAILED;
           
        // First open a position to modify
        if(!m_tradeExecutor.OpenPosition(ORDER_TYPE_BUY, 0.1, 1.1900, 1.3000, "Test Modify"))
           return TEST_FAILED;
           
        // Get the ticket number of the opened position
        STradeRecord trade;
        if(!m_tradeExecutor.GetLastTrade(trade))
           return TEST_FAILED;
           
        ulong ticket = trade.ticket;
        Print("Test_ModifyPosition: Modifying position with ticket ", ticket);
        
        // Test modifying the position
        if(!m_tradeExecutor.ModifyPosition(ticket, 1.1950, 1.3050))
           return TEST_FAILED;
           
        // Test error handling
        m_tradeExecutor.ForceError(true);
        if(m_tradeExecutor.ModifyPosition(ticket, 1.2500, 1.3500))
           return TEST_FAILED;
           
        // Reset error state
        m_tradeExecutor.ForceError(false);
           
        return TEST_PASSED;
     }
     
   // Main test runner - ALL TESTS WITH PROPER ISOLATION
   virtual ENUM_TEST_RESULT Run() override
     {
        ENUM_TEST_RESULT overallResult = TEST_PASSED;
        ENUM_TEST_RESULT testResult;
        
        Print("=== RUNNING ALL TESTS WITH PROPER ISOLATION ===");
        
        // Test 1: OpenPosition_Buy
        Print("Running Test_OpenPosition_Buy...");
        if(CheckPointer(m_tradeExecutor) == POINTER_DYNAMIC)
           m_tradeExecutor.ClearTradeHistory();
        testResult = Test_OpenPosition_Buy();
        Print("Test_OpenPosition_Buy result: ", (testResult == TEST_PASSED ? "PASSED" : "FAILED"));
        if(testResult != TEST_PASSED) overallResult = TEST_FAILED;
        
        // Test 2: OpenPosition_Sell
        Print("Running Test_OpenPosition_Sell...");
        if(CheckPointer(m_tradeExecutor) == POINTER_DYNAMIC)
           m_tradeExecutor.ClearTradeHistory();
        testResult = Test_OpenPosition_Sell();
        Print("Test_OpenPosition_Sell result: ", (testResult == TEST_PASSED ? "PASSED" : "FAILED"));
        if(testResult != TEST_PASSED) overallResult = TEST_FAILED;
        
        // Test 3: OpenPosition (multiple positions)
        Print("Running Test_OpenPosition...");
        if(CheckPointer(m_tradeExecutor) == POINTER_DYNAMIC)
           m_tradeExecutor.ClearTradeHistory();
        testResult = Test_OpenPosition();
        Print("Test_OpenPosition result: ", (testResult == TEST_PASSED ? "PASSED" : "FAILED"));
        if(testResult != TEST_PASSED) overallResult = TEST_FAILED;
        
        // Test 4: OpenPosition_ErrorHandling
        Print("Running Test_OpenPosition_ErrorHandling...");
        if(CheckPointer(m_tradeExecutor) == POINTER_DYNAMIC)
           m_tradeExecutor.ClearTradeHistory();
        testResult = Test_OpenPosition_ErrorHandling();
        Print("Test_OpenPosition_ErrorHandling result: ", (testResult == TEST_PASSED ? "PASSED" : "FAILED"));
        if(testResult != TEST_PASSED) overallResult = TEST_FAILED;
        
        // Test 5: ClosePosition
        Print("Running Test_ClosePosition...");
        if(CheckPointer(m_tradeExecutor) == POINTER_DYNAMIC)
           m_tradeExecutor.ClearTradeHistory();
        testResult = Test_ClosePosition();
        Print("Test_ClosePosition result: ", (testResult == TEST_PASSED ? "PASSED" : "FAILED"));
        if(testResult != TEST_PASSED) overallResult = TEST_FAILED;
        
        // Test 6: ModifyPosition
        Print("Running Test_ModifyPosition...");
        if(CheckPointer(m_tradeExecutor) == POINTER_DYNAMIC)
           m_tradeExecutor.ClearTradeHistory();
        testResult = Test_ModifyPosition();
        Print("Test_ModifyPosition result: ", (testResult == TEST_PASSED ? "PASSED" : "FAILED"));
        if(testResult != TEST_PASSED) overallResult = TEST_FAILED;
        
        Print("=== OVERALL TEST RESULT: ", (overallResult == TEST_PASSED ? "PASSED" : "FAILED"), " ===");
        return overallResult;
     }
  };

//+------------------------------------------------------------------+
//| Test Runner Class                                                |
//+------------------------------------------------------------------+
class CTestRunner
  {
private:
   CTestBase        *m_tests[];    // Array of test cases
   ENUM_TEST_RESULT  m_results[];  // Array to store test results
   
public:
   // Constructor/destructor
                     CTestRunner() 
                     { 
                        ArrayResize(m_tests, 0); 
                        ArrayResize(m_results, 0);
                     }
                    ~CTestRunner() 
                     { 
                        for(int i = 0; i < ArraySize(m_tests); i++) 
                          {
                           if(CheckPointer(m_tests[i]) == POINTER_DYNAMIC)
                              delete m_tests[i];
                          }
                     }
   
   // Add a test to the runner
   void              AddTest(CTestBase *test) 
                     { 
                        if(test == NULL) return;
                        int size = ArraySize(m_tests);
                        if(ArrayResize(m_tests, size + 1) == -1) return;
                        if(ArrayResize(m_results, size + 1) == -1) return;
                        m_tests[size] = test;
                        m_results[size] = TEST_SKIPPED; // Initialize as skipped
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
                           
                           // Store the result
                           m_results[i] = result;
                           
                           string status = (result == TEST_PASSED) ? "PASSED" : 
                                         ((result == TEST_FAILED) ? "FAILED" : "SKIPPED");
                           Print("=> ", status, "\n");
                        }
                     }
   
   // Print test summary
   void              PrintSummary()
                     {
                        int passed = 0, failed = 0, skipped = 0;
                        int total = ArraySize(m_tests);
                        
                        // Use stored results instead of re-running tests
                        for(int i = 0; i < total; i++)
                        {
                           if(m_results[i] == TEST_PASSED) passed++;
                           else if(m_results[i] == TEST_FAILED) failed++;
                           else skipped++;
                        }
                        
                        Print("\n=== Test Summary ===");
                        Print("Total: ", total);
                        Print("Passed: ", passed);
                        Print("Failed: ", failed);
                        Print("Skipped: ", skipped);
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
   
   // Run tests
   Print("Starting TradeExecutor unit tests...");
   runner.RunTests();
   runner.PrintSummary();
   
   // Cleanup
   if(CheckPointer(runner) == POINTER_DYNAMIC)
      delete runner;
  }
//+------------------------------------------------------------------+