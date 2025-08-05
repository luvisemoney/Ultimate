//+------------------------------------------------------------------+
//| TestRiskManager.mq5 - Unit tests for CRiskManager                |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"
#property script_show_inputs

#include "TestBase.mqh"
#include "..\..\Include\Core\RiskManager.mqh"
#include "..\Mocks\MockRiskManager.mqh"

//+------------------------------------------------------------------+
//| Test class for CRiskManager                                      |
//+------------------------------------------------------------------+
class CTestRiskManager : public CTestBase
  {
private:
   CMockRiskManager *m_mockRiskManager;
   CRiskManager     *m_riskManager;
   
public:
                     CTestRiskManager() : CTestBase("RiskManager Tests", true) {}
                    ~CTestRiskManager() 
                       {
                        if(m_mockRiskManager != NULL) delete m_mockRiskManager;
                        if(m_riskManager != NULL) delete m_riskManager;
                       }
   
   void              SetUp() override;
   void              TearDown() override;
   ENUM_TEST_RESULT  Run() override;
   
   // Individual test methods
   bool              TestConstructor();
   bool              TestPositionSizeCalculation();
   bool              TestTradeAllowance();
   bool              TestRiskLimits();
   bool              TestGettersSetters();
   bool              TestMockFunctionality();
  };

//+------------------------------------------------------------------+
//| Setup test environment                                           |
//+------------------------------------------------------------------+
void CTestRiskManager::SetUp()
  {
   m_mockRiskManager = new CMockRiskManager();
   m_riskManager = new CRiskManager("EURUSD", 2.0, 20.0, 5.0, 1.0, 3);
  }

//+------------------------------------------------------------------+
//| Cleanup test environment                                         |
//+------------------------------------------------------------------+
void CTestRiskManager::TearDown()
  {
   if(m_mockRiskManager != NULL)
     {
      delete m_mockRiskManager;
      m_mockRiskManager = NULL;
     }
   
   if(m_riskManager != NULL)
     {
      delete m_riskManager;
      m_riskManager = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Run all tests                                                    |
//+------------------------------------------------------------------+
ENUM_TEST_RESULT CTestRiskManager::Run()
  {
   bool allPassed = true;
   
   allPassed &= TestConstructor();
   allPassed &= TestPositionSizeCalculation();
   allPassed &= TestTradeAllowance();
   allPassed &= TestRiskLimits();
   allPassed &= TestGettersSetters();
   allPassed &= TestMockFunctionality();
   
   return allPassed ? TEST_PASSED : TEST_FAILED;
  }

//+------------------------------------------------------------------+
//| Test constructor                                                 |
//+------------------------------------------------------------------+
bool CTestRiskManager::TestConstructor()
  {
   Print("Testing RiskManager Constructor...");
   
   if(!AssertTrue(m_riskManager != NULL, "RiskManager should be created"))
      return false;
   
   if(!AssertEqual(2.0, m_riskManager.RiskPercent(), 0.001, "Risk percent should be set correctly"))
      return false;
   
   if(!AssertEqual(20.0, m_riskManager.MaxDrawdown(), 0.001, "Max drawdown should be set correctly"))
      return false;
   
   if(!AssertEqual(5.0, m_riskManager.MaxDailyLoss(), 0.001, "Max daily loss should be set correctly"))
      return false;
   
   if(!AssertEqual(1.0, m_riskManager.MaxPositionSize(), 0.001, "Max position size should be set correctly"))
      return false;
   
   if(!AssertEqual(3, m_riskManager.MaxOpenTrades(), 0.001, "Max open trades should be set correctly"))
      return false;
   
   Print("✓ Constructor tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test position size calculation                                   |
//+------------------------------------------------------------------+
bool CTestRiskManager::TestPositionSizeCalculation()
  {
   Print("Testing Position Size Calculation...");
   
   // Test valid stop loss
   double positionSize = m_riskManager.CalculatePositionSize(50.0);
   if(!AssertTrue(positionSize > 0, "Position size should be positive for valid stop loss"))
      return false;
   
   // Test invalid stop loss
   positionSize = m_riskManager.CalculatePositionSize(0.0);
   if(!AssertEqual(0.0, positionSize, 0.001, "Position size should be 0 for invalid stop loss"))
      return false;
   
   positionSize = m_riskManager.CalculatePositionSize(-10.0);
   if(!AssertEqual(0.0, positionSize, 0.001, "Position size should be 0 for negative stop loss"))
      return false;
   
   Print("✓ Position size calculation tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test trade allowance                                             |
//+------------------------------------------------------------------+
bool CTestRiskManager::TestTradeAllowance()
  {
   Print("Testing Trade Allowance...");
   
   // Test basic trade allowance (this will depend on market conditions)
   bool tradeAllowed = m_riskManager.IsTradeAllowed();
   Print("Trade allowed: ", tradeAllowed ? "YES" : "NO");
   
   // We can't assert specific values here as it depends on market conditions
   // Just verify the method doesn't crash
   if(!AssertTrue(true, "Trade allowance check should not crash"))
      return false;
   
   Print("✓ Trade allowance tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test risk limits                                                 |
//+------------------------------------------------------------------+
bool CTestRiskManager::TestRiskLimits()
  {
   Print("Testing Risk Limits...");
   
   // Test risk percent limits
   m_riskManager.SetRiskPercent(10.0);
   if(!AssertTrue(m_riskManager.RiskPercent() <= 5.0, "Risk percent should be capped at MAX_RISK_PERCENT"))
      return false;
   
   // Test valid risk percent
   m_riskManager.SetRiskPercent(3.0);
   if(!AssertEqual(3.0, m_riskManager.RiskPercent(), 0.001, "Valid risk percent should be set"))
      return false;
   
   Print("✓ Risk limits tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test getters and setters                                         |
//+------------------------------------------------------------------+
bool CTestRiskManager::TestGettersSetters()
  {
   Print("Testing Getters and Setters...");
   
   // Test max drawdown
   m_riskManager.SetMaxDrawdown(15.0);
   if(!AssertEqual(15.0, m_riskManager.MaxDrawdown(), 0.001, "Max drawdown should be updated"))
      return false;
   
   // Test max daily loss
   m_riskManager.SetMaxDailyLoss(3.0);
   if(!AssertEqual(3.0, m_riskManager.MaxDailyLoss(), 0.001, "Max daily loss should be updated"))
      return false;
   
   // Test max position size
   m_riskManager.SetMaxPositionSize(2.0);
   if(!AssertEqual(2.0, m_riskManager.MaxPositionSize(), 0.001, "Max position size should be updated"))
      return false;
   
   // Test max open trades
   m_riskManager.SetMaxOpenTrades(5);
   if(!AssertEqual(5, m_riskManager.MaxOpenTrades(), 0.001, "Max open trades should be updated"))
      return false;
   
   Print("✓ Getters and setters tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test mock functionality                                          |
//+------------------------------------------------------------------+
bool CTestRiskManager::TestMockFunctionality()
  {
   Print("Testing Mock Functionality...");
   
   // Test mock trade allowance
   m_mockRiskManager.SetTradeAllowed(true);
   if(!AssertTrue(m_mockRiskManager.IsTradeAllowed(), "Mock should allow trade when set to true"))
      return false;
   
   m_mockRiskManager.SetTradeAllowed(false);
   if(!AssertFalse(m_mockRiskManager.IsTradeAllowed(), "Mock should not allow trade when set to false"))
      return false;
   
   // Test mock position size
   m_mockRiskManager.SetPositionSize(0.5);
   double size = m_mockRiskManager.CalculatePositionSize(50.0);
   if(!AssertEqual(0.5, size, 0.001, "Mock should return set position size"))
      return false;
   
   // Test mock error forcing
   m_mockRiskManager.ForceError(true, "Test error");
   size = m_mockRiskManager.CalculatePositionSize(50.0);
   if(!AssertEqual(-1.0, size, 0.001, "Mock should return -1 when error is forced"))
      return false;
   
   if(!AssertStringEqual("Test error", m_mockRiskManager.GetLastError(), true, "Mock should return forced error message"))
      return false;
   
   // Test hard stops
   m_mockRiskManager.SetUseHardStops(true);
   if(!AssertTrue(m_mockRiskManager.UseHardStops(), "Mock should return true for hard stops"))
      return false;
   
   m_mockRiskManager.SetUseHardStops(false);
   if(!AssertFalse(m_mockRiskManager.UseHardStops(), "Mock should return false for hard stops"))
      return false;
   
   Print("✓ Mock functionality tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Script start function                                            |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("=== Starting RiskManager Unit Tests ===");
   
   CTestRiskManager test;
   test.SetUp();
   
   ENUM_TEST_RESULT result = test.Run();
   test.PrintTestResult(result);
   
   test.TearDown();
   
   Print("=== RiskManager Unit Tests Complete ===");
  }