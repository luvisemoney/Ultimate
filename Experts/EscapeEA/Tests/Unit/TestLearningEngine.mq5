//+------------------------------------------------------------------+
//|                                            TestLearningEngine.mq5 |
//|                                      Copyright 2025, EscapeEA     |
//|                                          https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include "TestBase.mqh"
#include "..\\Mocks\\MockLearningEngine.mqh"
#include "..\\..\\Include\\Common\\Structs.mqh"
#include "..\\TestRunner.mqh"

//+------------------------------------------------------------------+
//| Test class for CLearningEngine                                   |
//+------------------------------------------------------------------+
class CTestLearningEngine : public CTestBase
  {
private:
   CMockLearningEngine *m_learningEngine;
   
public:
   // Constructor/destructor
                     CTestLearningEngine() : CTestBase("CLearningEngine Tests") {}
                    ~CTestLearningEngine() {}
   
   // Override methods
   virtual void      SetUp()
     {
        m_learningEngine = new CMockLearningEngine();
     }
     
   virtual void      TearDown()
     {
        if(CheckPointer(m_learningEngine) == POINTER_DYNAMIC)
           delete m_learningEngine;
     }
   
   // Test methods
   bool Test_Initialization(string &message)
     {
        // Test default initialization
        if(!m_learningEngine.Initialize())
        {
           message = "Failed to initialize learning engine";
           return false;
        }
           
        // Test initialization flag
        m_learningEngine.SetInitialized(false);
        if(m_learningEngine.Initialize())
        {
           message = "Should not initialize when set to false";
           return false;
        }
           
        message = "Initialization works correctly";
        return true;
     }
     
   bool Test_UpdateModel(string &message)
     {
        // Create a test trade
        STradeRecord trade;
        trade.ticket = 12345;
        trade.profit = 10.0;
        trade.lots = 0.1;
        trade.symbol = _Symbol;
        trade.type = TRADE_TYPE_BUY;
        trade.openPrice = 1.1000;
        trade.closePrice = 1.1010;
        trade.openTime = TimeCurrent();
        trade.closeTime = TimeCurrent() + 3600;
        
        // Test successful update
        if(!m_learningEngine.UpdateModel(trade))
        {
           message = "Failed to update model with valid trade";
           return false;
        }
           
        // Test error case
        m_learningEngine.ForceError(true, "Test error");
        if(m_learningEngine.UpdateModel(trade))
        {
           message = "Should fail when error is forced";
           return false;
        }
           
        message = "Model update works correctly";
        return true;
     }
     
   bool Test_ShouldEnterTrade(string &message)
     {
        double features[5] = {1.0, 2.0, 3.0, 4.0, 5.0};
        double confidence = 0.0;
        
        // Test enter trade (should enter by default)
        if(!m_learningEngine.ShouldEnterTrade(features, confidence))
        {
           message = "Should enter trade by default";
           return false;
        }
           
        if(!AssertEqual(0.8, confidence, 0.0001, "Confidence should be 0.8"))
        {
           message = "Confidence value mismatch";
           return false;
        }
           
        // Test don't enter
        m_learningEngine.SetShouldEnter(false);
        if(m_learningEngine.ShouldEnterTrade(features, confidence))
        {
           message = "Should not enter when set to false";
           return false;
        }
           
        // Test error case
        m_learningEngine.ForceError(true, "Test error");
        if(m_learningEngine.ShouldEnterTrade(features, confidence))
        {
           message = "Should fail when error is forced";
           return false;
        }
           
        message = "Trade entry decision works correctly";
        return true;
     }
     
   bool Test_PerformanceMetrics(string &message)
     {
        // Test win rate
        double expectedWinRate = 0.75;
        m_learningEngine.SetWinRate(expectedWinRate);
        double winRate = m_learningEngine.GetWinRate();
        
        if(!AssertEqual(expectedWinRate, winRate, 0.0001, "Win rate mismatch"))
        {
           message = "Win rate mismatch";
           return false;
        }
           
        // Test profit factor
        double expectedProfitFactor = 1.8;
        m_learningEngine.SetProfitFactor(expectedProfitFactor);
        double profitFactor = m_learningEngine.GetProfitFactor();
        
        if(!AssertEqual(expectedProfitFactor, profitFactor, 0.0001, "Profit factor mismatch"))
        {
           message = "Profit factor mismatch";
           return false;
        }
           
        // Test max drawdown
        double expectedMaxDrawdown = 15.0;
        m_learningEngine.SetMaxDrawdown(expectedMaxDrawdown);
        double maxDrawdown = m_learningEngine.GetMaxDrawdown();
        
        if(!AssertEqual(expectedMaxDrawdown, maxDrawdown, 0.0001, "Max drawdown mismatch"))
        {
           message = "Max drawdown mismatch";
           return false;
        }
           
        // Test error cases
        m_learningEngine.ForceError(true, "Test error");
        
        if(m_learningEngine.GetWinRate() >= 0)
        {
           message = "Should return -1 on error for win rate";
           return false;
        }
           
        if(m_learningEngine.GetProfitFactor() >= 0)
        {
           message = "Should return -1 on error for profit factor";
           return false;
        }
           
        if(m_learningEngine.GetMaxDrawdown() >= 0)
        {
           message = "Should return -1 on error for max drawdown";
           return false;
        }
           
        message = "Performance metrics work correctly";
        return true;
     }
     
   // Helper methods for assertions
   ENUM_TEST_RESULT AssertPassed(string msg) { PrintTestResult(TEST_PASSED, msg); return TEST_PASSED; }
   ENUM_TEST_RESULT AssertFailed(string msg) { PrintTestResult(TEST_FAILED, msg); return TEST_FAILED; }
   
   // Main test runner
   virtual ENUM_TEST_RESULT Run()
     {
        ENUM_TEST_RESULT result = TEST_PASSED;
        string message = "";
        
        // Run all test methods with proper result handling
        if(!Test_Initialization(message))
        {
           PrintTestResult(TEST_FAILED, message);
           result = TEST_FAILED;
        }
        else
        {
           PrintTestResult(TEST_PASSED, message);
        }
        
        if(!Test_UpdateModel(message))
        {
           PrintTestResult(TEST_FAILED, message);
           result = TEST_FAILED;
        }
        else
        {
           PrintTestResult(TEST_PASSED, message);
        }
        
        if(!Test_ShouldEnterTrade(message))
        {
           PrintTestResult(TEST_FAILED, message);
           result = TEST_FAILED;
        }
        else
        {
           PrintTestResult(TEST_PASSED, message);
        }
        
        if(!Test_PerformanceMetrics(message))
        {
           PrintTestResult(TEST_FAILED, message);
           result = TEST_FAILED;
        }
        else
        {
           PrintTestResult(TEST_PASSED, message);
        }
        
        return result;
     }
  };

//+------------------------------------------------------------------+
//| Test registration and execution                                  |
//+------------------------------------------------------------------+
void OnStart()
  {
   // Create test instance
   CTestLearningEngine *test = new CTestLearningEngine();
   if(test == NULL)
   {
      Print("Error: Failed to create test instance");
      return;
   }
   
   // Create test runner and add test
   CTestRunner runner;
   runner.AddTest(test);
   
   // Run tests
   runner.RunAllTests();
   
   // Print summary
   runner.PrintSummary();
   
   // Clean up (runner will delete the test object)
   delete test;
  }
//+------------------------------------------------------------------+
