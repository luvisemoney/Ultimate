//+------------------------------------------------------------------+
//| TestSignalBroadcaster.mq5 - Unit tests for CSignalBroadcaster    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"
#property script_show_inputs

#include "TestBase.mqh"
#include "..\..\Include\Communication\SignalBroadcaster.mqh"

//+------------------------------------------------------------------+
//| Test class for CSignalBroadcaster                                |
//+------------------------------------------------------------------+
class CTestSignalBroadcaster : public CTestBase
  {
private:
   CSignalBroadcaster *m_broadcaster;
   string            m_testPrefix;
   
public:
                     CTestSignalBroadcaster() : CTestBase("SignalBroadcaster Tests", true) 
                       {
                        m_testPrefix = "TEST_";
                       }
                    ~CTestSignalBroadcaster() 
                       {
                        if(m_broadcaster != NULL) delete m_broadcaster;
                       }
   
   void              SetUp() override;
   void              TearDown() override;
   ENUM_TEST_RESULT  Run() override;
   
   // Individual test methods
   bool              TestConstructor();
   bool              TestSignalSending();
   bool              TestStatusBroadcast();
   bool              TestGettersSetters();
   bool              TestInvalidSignals();
   bool              TestGlobalVariables();
   
   // Helper methods
   void              CleanupTestVariables();
  };

//+------------------------------------------------------------------+
//| Setup test environment                                           |
//+------------------------------------------------------------------+
void CTestSignalBroadcaster::SetUp()
  {
   CleanupTestVariables();
   m_broadcaster = new CSignalBroadcaster(m_testPrefix, 300);
  }

//+------------------------------------------------------------------+
//| Cleanup test environment                                         |
//+------------------------------------------------------------------+
void CTestSignalBroadcaster::TearDown()
  {
   if(m_broadcaster != NULL)
     {
      delete m_broadcaster;
      m_broadcaster = NULL;
     }
   CleanupTestVariables();
  }

//+------------------------------------------------------------------+
//| Clean up test global variables                                   |
//+------------------------------------------------------------------+
void CTestSignalBroadcaster::CleanupTestVariables()
  {
   // Clean up any test global variables
   string varName;
   for(int i = GlobalVariablesTotal() - 1; i >= 0; i--)
     {
      varName = GlobalVariableName(i);
      // Clean up variables with original test prefix and any NEW_PREFIX_ variables
      if(StringFind(varName, m_testPrefix) == 0 || StringFind(varName, "NEW_PREFIX_") == 0)
        {
         GlobalVariableDel(varName);
        }
     }
  }

//+------------------------------------------------------------------+
//| Run all tests                                                    |
//+------------------------------------------------------------------+
ENUM_TEST_RESULT CTestSignalBroadcaster::Run()
  {
   bool allPassed = true;
   
   allPassed &= TestConstructor();
   allPassed &= TestSignalSending();
   allPassed &= TestStatusBroadcast();
   allPassed &= TestGettersSetters();
   allPassed &= TestInvalidSignals();
   allPassed &= TestGlobalVariables();
   
   return allPassed ? TEST_PASSED : TEST_FAILED;
  }

//+------------------------------------------------------------------+
//| Test constructor                                                 |
//+------------------------------------------------------------------+
bool CTestSignalBroadcaster::TestConstructor()
  {
   Print("Testing SignalBroadcaster Constructor...");
   
   if(!AssertTrue(m_broadcaster != NULL, "SignalBroadcaster should be created"))
      return false;
   
   if(!AssertStringEqual(m_testPrefix, m_broadcaster.GetSignalPrefix(), true, "Prefix should be set correctly"))
      return false;
   
   if(!AssertEqual(300, m_broadcaster.GetSignalLifetime(), 0.001, "Lifetime should be set correctly"))
      return false;
   
   // Test default constructor
   CSignalBroadcaster *defaultBroadcaster = new CSignalBroadcaster();
   if(!AssertTrue(defaultBroadcaster != NULL, "Default constructor should work"))
     {
      delete defaultBroadcaster;
      return false;
     }
   delete defaultBroadcaster;
   
   Print("✓ Constructor tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test signal sending                                              |
//+------------------------------------------------------------------+
bool CTestSignalBroadcaster::TestSignalSending()
  {
   Print("Testing Signal Sending...");
   
   // Test valid BUY signal
   bool result = m_broadcaster.SendSignal("EURUSD", SIGNAL_BUY, 0.75);
   if(!AssertTrue(result, "Should successfully send BUY signal"))
      return false;
   
   // Test valid SELL signal
   result = m_broadcaster.SendSignal("GBPUSD", SIGNAL_SELL, 0.85);
   if(!AssertTrue(result, "Should successfully send SELL signal"))
      return false;
   
   // Test with different confidence levels
   result = m_broadcaster.SendSignal("USDJPY", SIGNAL_BUY, 0.1);
   if(!AssertTrue(result, "Should send signal with low confidence"))
      return false;
   
   result = m_broadcaster.SendSignal("AUDUSD", SIGNAL_SELL, 1.0);
   if(!AssertTrue(result, "Should send signal with maximum confidence"))
      return false;
   
   Print("✓ Signal sending tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test status broadcasting                                          |
//+------------------------------------------------------------------+
bool CTestSignalBroadcaster::TestStatusBroadcast()
  {
   Print("Testing Status Broadcast...");
   
   bool result = m_broadcaster.BroadcastStatus("RUNNING");
   if(!AssertTrue(result, "Should successfully broadcast status"))
      return false;
   
   result = m_broadcaster.BroadcastStatus("STOPPED");
   if(!AssertTrue(result, "Should successfully broadcast different status"))
      return false;
   
   result = m_broadcaster.BroadcastStatus("");
   if(!AssertTrue(result, "Should handle empty status"))
      return false;
   
   Print("✓ Status broadcast tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test getters and setters                                         |
//+------------------------------------------------------------------+
bool CTestSignalBroadcaster::TestGettersSetters()
  {
   Print("Testing Getters and Setters...");
   
   // Test prefix setter/getter
   m_broadcaster.SetSignalPrefix("NEW_PREFIX_");
   if(!AssertStringEqual("NEW_PREFIX_", m_broadcaster.GetSignalPrefix(), true, "Prefix should be updated"))
      return false;
   
   // Test lifetime setter/getter
   m_broadcaster.SetSignalLifetime(600);
   if(!AssertEqual(600, m_broadcaster.GetSignalLifetime(), 0.001, "Lifetime should be updated"))
      return false;
   
   // Test boundary values
   m_broadcaster.SetSignalLifetime(0);
   if(!AssertEqual(0, m_broadcaster.GetSignalLifetime(), 0.001, "Should accept 0 lifetime"))
      return false;
   
   m_broadcaster.SetSignalLifetime(86400); // 24 hours
   if(!AssertEqual(86400, m_broadcaster.GetSignalLifetime(), 0.001, "Should accept large lifetime"))
      return false;
   
   Print("✓ Getters and setters tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test invalid signal handling                                     |
//+------------------------------------------------------------------+
bool CTestSignalBroadcaster::TestInvalidSignals()
  {
   Print("Testing Invalid Signals...");
   
   // Test HOLD signal (should be rejected)
   bool result = m_broadcaster.SendSignal("EURUSD", SIGNAL_HOLD, 0.75);
   if(!AssertFalse(result, "Should reject HOLD signal"))
      return false;
   
   // Test zero confidence
   result = m_broadcaster.SendSignal("EURUSD", SIGNAL_BUY, 0.0);
   if(!AssertFalse(result, "Should reject zero confidence"))
      return false;
   
   // Test negative confidence
   result = m_broadcaster.SendSignal("EURUSD", SIGNAL_BUY, -0.5);
   if(!AssertFalse(result, "Should reject negative confidence"))
      return false;
   
   // Test confidence > 1.0
   result = m_broadcaster.SendSignal("EURUSD", SIGNAL_BUY, 1.5);
   if(!AssertFalse(result, "Should reject confidence > 1.0"))
      return false;
   
   Print("✓ Invalid signals tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test global variable creation                                    |
//+------------------------------------------------------------------+
bool CTestSignalBroadcaster::TestGlobalVariables()
  {
   Print("Testing Global Variables...");
   
   int initialVarCount = GlobalVariablesTotal();
   
   // Send a signal and check if global variables are created
   bool result = m_broadcaster.SendSignal("TESTPAIR", SIGNAL_BUY, 0.8);
   if(!AssertTrue(result, "Should send test signal"))
      return false;
   
   // Check if global variables increased
   int newVarCount = GlobalVariablesTotal();
   if(!AssertTrue(newVarCount > initialVarCount, "Global variables should be created"))
      return false;
   
   // Get the current prefix from the broadcaster (it may have been changed in previous tests)
   string currentPrefix = m_broadcaster.GetSignalPrefix();
   
   // Check for specific test variables
   bool foundTestVar = false;
   for(int i = 0; i < GlobalVariablesTotal(); i++)
     {
      string varName = GlobalVariableName(i);
      if(StringFind(varName, currentPrefix) == 0 && StringFind(varName, "TESTPAIR") > 0)
        {
         foundTestVar = true;
         break;
        }
     }
   
   if(!AssertTrue(foundTestVar, "Should find test signal variable"))
      return false;
   
   // Test status variable creation
   result = m_broadcaster.BroadcastStatus("TEST_STATUS");
   if(!AssertTrue(result, "Should broadcast test status"))
      return false;
   
   bool foundStatusVar = false;
   for(int i = 0; i < GlobalVariablesTotal(); i++)
     {
      string varName = GlobalVariableName(i);
      if(StringFind(varName, currentPrefix + "STATUS") == 0)
        {
         foundStatusVar = true;
         break;
        }
     }
   
   if(!AssertTrue(foundStatusVar, "Should find status variable"))
      return false;
   
   Print("✓ Global variables tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Script start function                                            |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("=== Starting SignalBroadcaster Unit Tests ===");
   
   CTestSignalBroadcaster test;
   test.SetUp();
   
   ENUM_TEST_RESULT result = test.Run();
   test.PrintTestResult(result);
   
   test.TearDown();
   
   Print("=== SignalBroadcaster Unit Tests Complete ===");
  }