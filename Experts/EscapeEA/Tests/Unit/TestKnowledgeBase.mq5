//+------------------------------------------------------------------+
//|                                           TestKnowledgeBase.mq5 |
//|                                      Copyright 2025, EscapeEA     |
//|                                          https://www.escapeea.com |
//+------------------------------------------------------------------+

#include <Object.mqh>
#include "..\TestRunner.mqh"
#include "..\Mocks\MockKnowledgeBase.mqh"
#include "..\..\Include\Common\Enums.mqh"
#include "..\..\Include\Common\Structs.mqh"

// Helper macros for assertions
#define ASSERT_EQUAL(expected, actual, message) \
    if ((expected) != (actual)) \
    { \
        Print("Assertion failed: ", message, ". Expected: ", expected, ", Actual: ", actual); \
        return false; \
    }

#define ASSERT_TRUE(condition, message) \
    if (!(condition)) \
    { \
        Print("Assertion failed: ", message); \
        return false; \
    }

#define ASSERT_FALSE(condition, message) ASSERT_TRUE(!(condition), message)

//+------------------------------------------------------------------+
//| Test class for CKnowledgeBase                                    |
//+------------------------------------------------------------------+
class CTestKnowledgeBase : public CTestBase
  {
private:
   CMockKnowledgeBase *m_knowledgeBase;
   
public:
   // Constructor/destructor
                     CTestKnowledgeBase() : CTestBase("CKnowledgeBase Tests") { m_knowledgeBase = NULL; }
                    ~CTestKnowledgeBase() { if (m_knowledgeBase != NULL) delete m_knowledgeBase; }
   
   // Override methods
   virtual void      SetUp()
     {
        m_knowledgeBase = new CMockKnowledgeBase("test_kb.db", "test_shared_kb");
        m_knowledgeBase.Initialize();
     }
     
   virtual void      TearDown()
     {
        if(CheckPointer(m_knowledgeBase) == POINTER_DYNAMIC)
           delete m_knowledgeBase;
     }
   
   // Test methods
   bool TestInitialization()
     {
        // Test initialization
        ASSERT_TRUE(m_knowledgeBase.Initialize(), "KnowledgeBase should initialize successfully");
        ASSERT_TRUE(m_knowledgeBase.IsInitialized(), "KnowledgeBase should be initialized");
        
        // Test error handling
        m_knowledgeBase.SetLastError("Test error");
        m_knowledgeBase.SetForceError(true);
        ASSERT_FALSE(m_knowledgeBase.Initialize(), "KnowledgeBase should fail to initialize when forced");
        ASSERT_FALSE(m_knowledgeBase.IsInitialized(), "KnowledgeBase should not be initialized when forced error");
        
        // Reset error state
        m_knowledgeBase.SetForceError(false);
        
        return true;
     }
     
   bool TestAddTrade()
     {
        // Add a test trade
        STradeRecord trade;
        ZeroMemory(trade);
        trade.ticket = 12345;
        trade.symbol = "EURUSD";
        trade.type = TRADE_TYPE_BUY;
        trade.lots = 0.1;
        trade.openPrice = 1.12345;
        trade.stopLoss = 1.12000;
        trade.takeProfit = 1.13000;
        trade.openTime = TimeCurrent();
        
        ASSERT_TRUE(m_knowledgeBase.AddTrade(trade), "Should be able to add a trade");
        
        // Test error handling
        m_knowledgeBase.SetLastError("Test error");
        m_knowledgeBase.SetForceError(true);
        
        // Manually copy fields to avoid deprecation warning for struct assignment
        STradeRecord trade2;
        ZeroMemory(trade2);
        trade2.ticket = 67890;
        trade2.symbol = trade.symbol;
        trade2.type = trade.type;
        trade2.lots = trade.lots;  // Using 'lots' instead of 'volume' to match struct definition
        trade2.openPrice = trade.openPrice;
        trade2.stopLoss = trade.stopLoss;
        trade2.takeProfit = trade.takeProfit;
        trade2.openTime = trade.openTime;
        ASSERT_FALSE(m_knowledgeBase.AddTrade(trade2), "Should fail to add trade when forced error");
        
        m_knowledgeBase.SetForceError(false);
        
        return true;
     }
     
   bool TestGetRecentTrades()
     {
        // Add some test trades
        STradeRecord trade1, trade2;
        ZeroMemory(trade1);
        ZeroMemory(trade2);
        trade1.ticket = 12345;
        trade2.ticket = 67890;
        
        m_knowledgeBase.AddTrade(trade1);
        m_knowledgeBase.AddTrade(trade2);
        
        // Get recent trades
        int trades[];
        int count = 0;
        ASSERT_TRUE(m_knowledgeBase.GetRecentTrades(2, trades, count), "Should get recent trades");
        ASSERT_EQUAL(2, count, "Should return 2 trades");
        
        // Test error handling
        m_knowledgeBase.SetLastError("Test error");
        m_knowledgeBase.SetForceError(true);
        int tempTrades[];
        int tempCount = 0;
        ASSERT_FALSE(m_knowledgeBase.GetRecentTrades(2, tempTrades, tempCount), "Should fail to get trades when forced error");
        m_knowledgeBase.SetForceError(false);
        
        return true;
     }
     
   bool TestLogSignalRejection()
     {
        // Log a signal rejection
        ASSERT_TRUE(m_knowledgeBase.LogSignalRejection(123, "Test rejection"), "Should log signal rejection");
        
        // Test error handling
        m_knowledgeBase.SetLastError("Test error");
        m_knowledgeBase.SetForceError(true);
        ASSERT_FALSE(m_knowledgeBase.LogSignalRejection(456, "Test rejection"), "Should fail to log rejection when forced error");
        m_knowledgeBase.SetForceError(false);
        
        return true;
     }
     
   bool TestErrorHandling()
     {
        // Force an error
        m_knowledgeBase.SetLastError("Test error");
        m_knowledgeBase.SetForceError(true);
        
        // Test adding a trade with forced error
        STradeRecord trade;
        ZeroMemory(trade);
        trade.ticket = 12345;
        trade.symbol = "EURUSD";
        trade.type = TRADE_TYPE_BUY;
        trade.lots = 0.1;
        trade.openPrice = 1.12345;
        trade.stopLoss = 1.12000;
        trade.takeProfit = 1.13000;
        trade.openTime = TimeCurrent();
        
        // Should fail to add trade when error is forced
        if (m_knowledgeBase.AddTrade(trade))
        {
           Print("Error: Should fail to add trade when forced error");
           return false;
        }
        
        // Test retrieving trades with forced error
        int dummyTrades[];
        int count = 0;
        if (m_knowledgeBase.GetRecentTrades(10, dummyTrades, count))
        {
           Print("Error: Should fail to get trades when forced error");
           return false;
        }
        
        // Reset error state
        m_knowledgeBase.SetForceError(false);
        
        return true; // "Error handling works correctly"
     }
     
   // Override Run method to execute all tests
   virtual ENUM_TEST_RESULT Run()
     {
        Print("Running ", Name(), "...");
        
        // Run all test methods
        if (!TestInitialization()) 
        {
           Print("TestInitialization failed");
           return TEST_FAILED;
        }
           
        if (!TestAddTrade()) 
        {
           Print("TestAddTrade failed");
           return TEST_FAILED;
        }
           
        if (!TestGetRecentTrades()) 
        {
           Print("TestGetRecentTrades failed");
           return TEST_FAILED;
        }
           
        if (!TestLogSignalRejection()) 
        {
           Print("TestLogSignalRejection failed");
           return TEST_FAILED;
        }
           
        if (!TestErrorHandling())
        {
           Print("TestErrorHandling failed");
           return TEST_FAILED;
        }
        
        Print("All tests passed!");
        return TEST_PASSED;
     }
  };

//+------------------------------------------------------------------+
//| Run all tests and return the number of failures                  |
//+------------------------------------------------------------------+
int RunTests()
  {
   CTestRunner runner;
   runner.AddTest(new CTestKnowledgeBase());
   
   // Run all tests
   runner.RunAllTests();
   
   // Print summary
   runner.PrintSummary();
   
   // Print summary to journal (using only public methods)
   Print("\n=== Test Execution Summary ===");
   
   // Just print a simple summary since we don't have access to detailed test methods
   Print("Tests completed. Check the Experts tab for detailed results.");
   
   // Save a simple report to a file
   string reportPath = "TestResults_" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + ".txt";
   StringReplace(reportPath, ":", "-");
   
   int file_handle = FileOpen(reportPath, FILE_WRITE|FILE_TXT);
   if(file_handle != INVALID_HANDLE)
     {
      FileWriteString(file_handle, "=== Test Execution Summary ===\n");
      FileWriteString(file_handle, "Timestamp: " + TimeToString(TimeCurrent()) + "\n");
      FileWriteString(file_handle, "Test run completed. Check the Experts tab for detailed results.\n");
      FileClose(file_handle);
      Print("Test results summary saved to: ", reportPath);
     }
   else
     {
      Print("Warning: Could not save test results summary to file");
     }
   
   return runner.FailedTests();
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Run tests and return the number of failures
   int failures = RunTests();
   
   // Return success (0) if no failures, otherwise return the number of failures
   return(failures == 0 ? INIT_SUCCEEDED : INIT_FAILED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // Clean up any resources if needed
  }

//+------------------------------------------------------------------+
//| Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Not used for testing
  }
//+------------------------------------------------------------------+
