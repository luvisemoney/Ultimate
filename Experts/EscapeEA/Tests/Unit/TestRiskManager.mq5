//+------------------------------------------------------------------+
//|                                            TestRiskManager.mq5 |
//|                                      Copyright 2025, EscapeEA     |
//|                                          https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

// Include necessary files
#include <Object.mqh>
#include "TestBase.mqh"
#include "..\\TestRunner.mqh"
#include "..\\Mocks\\MockRiskManager.mqh"

//+------------------------------------------------------------------+
//| Test class for CRiskManager                                      |
//+------------------------------------------------------------------+
class CTestRiskManager : public CTestBase
  {
private:
   CMockRiskManager *m_riskManager;  // Mock risk manager instance
   
   // Private test methods
   bool Test_IsTradeAllowed(string &message);
   bool Test_CalculatePositionSize(string &message);
   bool Test_UseHardStops(string &message);
   bool Test_MaxPositionSize(string &message);
   
public:
   // Constructor/destructor
   CTestRiskManager() : CTestBase("CRiskManager Tests"), m_riskManager(NULL) {}
   ~CTestRiskManager() { if(CheckPointer(m_riskManager) == POINTER_DYNAMIC) delete m_riskManager; }
   
   // Override methods from CTestBase
   virtual void      SetUp() override;
   virtual void      TearDown() override;
   virtual ENUM_TEST_RESULT Run() override;
   
   // Helper methods for assertions
   ENUM_TEST_RESULT AssertPassed(string message) { PrintTestResult(TEST_PASSED, message); return TEST_PASSED; }
   ENUM_TEST_RESULT AssertFailed(string message) { PrintTestResult(TEST_FAILED, message); return TEST_FAILED; }
  };

//+------------------------------------------------------------------+
//| Set up test environment                                          |
//+------------------------------------------------------------------+
void CTestRiskManager::SetUp()
  {
   if(m_riskManager == NULL)
      m_riskManager = new CMockRiskManager();
  }

//+------------------------------------------------------------------+
//| Clean up test environment                                        |
//+------------------------------------------------------------------+
void CTestRiskManager::TearDown()
  {
   if(CheckPointer(m_riskManager) == POINTER_DYNAMIC)
     {
      delete m_riskManager;
      m_riskManager = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Test if trade is allowed                                         |
//+------------------------------------------------------------------+
bool CTestRiskManager::Test_IsTradeAllowed(string &message)
  {
   if(m_riskManager == NULL) 
   {
      message = "Risk manager not initialized";
      return false;
   }
   
   m_riskManager.SetTradeAllowed(true);
   if(!m_riskManager.IsTradeAllowed())
   {
      message = "Trade should be allowed";
      return false;
   }
      
   m_riskManager.SetTradeAllowed(false);
   if(m_riskManager.IsTradeAllowed())
   {
      message = "Trade should not be allowed";
      return false;
   }
      
   message = "Trade allowance works correctly";
   return true;
  }

//+------------------------------------------------------------------+
//| Test position size calculation                                   |
//+------------------------------------------------------------------+
bool CTestRiskManager::Test_CalculatePositionSize(string &message)
  {
   if(m_riskManager == NULL) 
   {
      message = "Risk manager not initialized";
      return false;
   }
   
   double size = 0.5;
   m_riskManager.SetPositionSize(size);
   
   double result = m_riskManager.CalculatePositionSize(1.0);
   if(!AssertEqual(size, result, 0.0001, "Position size calculation failed"))
   {
      message = "Position size calculation failed";
      return false;
   }
      
   // Test error case
   m_riskManager.ForceError(true, "Test error");
   result = m_riskManager.CalculatePositionSize(1.0);
   if(!AssertEqual(-1.0, result, 0.0001, "Should return -1 on error"))
   {
      message = "Error case handling failed";
      return false;
   }
      
   message = "Position size calculation works correctly";
   return true;
  }

//+------------------------------------------------------------------+
//| Test hard stops configuration                                    |
//+------------------------------------------------------------------+
bool CTestRiskManager::Test_UseHardStops(string &message)
  {
   if(m_riskManager == NULL) 
   {
      message = "Risk manager not initialized";
      return false;
   }
   
   m_riskManager.SetUseHardStops(true);
   if(!m_riskManager.UseHardStops())
   {
      message = "Hard stops should be enabled";
      return false;
   }
      
   m_riskManager.SetUseHardStops(false);
   if(m_riskManager.UseHardStops())
   {
      message = "Hard stops should be disabled";
      return false;
   }
      
   message = "Hard stops configuration works correctly";
   return true;
  }

//+------------------------------------------------------------------+
//| Test maximum position size                                       |
//+------------------------------------------------------------------+
bool CTestRiskManager::Test_MaxPositionSize(string &message)
  {
   if(m_riskManager == NULL) 
   {
      message = "Risk manager not initialized";
      return false;
   }
   
   double maxSize = 10.0;
   m_riskManager.SetMaxPositionSize(maxSize);
   
   if(!AssertEqual(maxSize, m_riskManager.MaxPositionSize(), 0.0001, "Max position size getter failed"))
   {
      message = "Max position size getter failed";
      return false;
   }
      
   message = "Max position size works correctly";
   return true;
  }

//+------------------------------------------------------------------+
//| Main test runner                                                 |
//+------------------------------------------------------------------+
ENUM_TEST_RESULT CTestRiskManager::Run()
  {
   ENUM_TEST_RESULT result = TEST_PASSED;
   string message = "";
   
   // Run all test methods
   if(!Test_IsTradeAllowed(message))
   {
      PrintTestResult(TEST_FAILED, message);
      result = TEST_FAILED;
   }
   else
   {
      PrintTestResult(TEST_PASSED, message);
   }
   
   if(!Test_CalculatePositionSize(message))
   {
      PrintTestResult(TEST_FAILED, message);
      result = TEST_FAILED;
   }
   else
   {
      PrintTestResult(TEST_PASSED, message);
   }
   
   if(!Test_UseHardStops(message))
   {
      PrintTestResult(TEST_FAILED, message);
      result = TEST_FAILED;
   }
   else
   {
      PrintTestResult(TEST_PASSED, message);
   }
   
   if(!Test_MaxPositionSize(message))
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

//+------------------------------------------------------------------+
//| Test registration and execution                                  |
//+------------------------------------------------------------------+
void OnStart()
  {
   // Create test runner
   CTestRunner runner;
   
   // Create and add test
   CTestRiskManager *test = new CTestRiskManager();
   if(test == NULL)
     {
      Print("Error: Failed to create test instance");
      return;
     }
   
   runner.AddTest(test);
   
   // Run tests
   runner.RunAllTests();
   
   // Print summary
   runner.PrintSummary();
   
   // Optional: Save report to file
   // runner.GenerateReport("TestReport.html");
   
   // Clean up (runner will delete the test object)
   delete test;
  }
//+------------------------------------------------------------------+
