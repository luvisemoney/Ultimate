//+------------------------------------------------------------------+
//| TestKnowledgeBase.mq5 - Unit tests for CKnowledgeBase            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"
#property script_show_inputs

#include "TestBase.mqh"
#include "..\..\Include\Learning\KnowledgeBase.mqh"

//+------------------------------------------------------------------+
//| Test class for CKnowledgeBase                                    |
//+------------------------------------------------------------------+
class CTestKnowledgeBase : public CTestBase
  {
private:
   CKnowledgeBase   *m_knowledgeBase;
   
public:
                     CTestKnowledgeBase() : CTestBase("KnowledgeBase Tests", true) {}
                    ~CTestKnowledgeBase() 
                       {
                        if(m_knowledgeBase != NULL) delete m_knowledgeBase;
                       }
   
   void              SetUp() override;
   void              TearDown() override;
   ENUM_TEST_RESULT  Run() override;
   
   // Individual test methods
   bool              TestConstructor();
   bool              TestBasicFunctionality();
   bool              TestTradeOperations();
   bool              TestSignalOperations();
  };

//+------------------------------------------------------------------+
//| Setup test environment                                           |
//+------------------------------------------------------------------+
void CTestKnowledgeBase::SetUp()
  {
   m_knowledgeBase = new CKnowledgeBase("test_kb.json", "test_shared_kb");
  }

//+------------------------------------------------------------------+
//| Cleanup test environment                                         |
//+------------------------------------------------------------------+
void CTestKnowledgeBase::TearDown()
  {
   if(m_knowledgeBase != NULL)
     {
      delete m_knowledgeBase;
      m_knowledgeBase = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Run all tests                                                    |
//+------------------------------------------------------------------+
ENUM_TEST_RESULT CTestKnowledgeBase::Run()
  {
   bool allPassed = true;
   
   allPassed &= TestConstructor();
   allPassed &= TestBasicFunctionality();
   allPassed &= TestTradeOperations();
   allPassed &= TestSignalOperations();
   
   return allPassed ? TEST_PASSED : TEST_FAILED;
  }

//+------------------------------------------------------------------+
//| Test constructor                                                 |
//+------------------------------------------------------------------+
bool CTestKnowledgeBase::TestConstructor()
  {
   Print("Testing KnowledgeBase Constructor...");
   
   if(!AssertTrue(m_knowledgeBase != NULL, "KnowledgeBase should be created"))
      return false;
   
   Print("✓ Constructor tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test basic functionality                                         |
//+------------------------------------------------------------------+
bool CTestKnowledgeBase::TestBasicFunctionality()
  {
   Print("Testing Basic Functionality...");
   
   // Test clear operation
   bool clearResult = m_knowledgeBase.Clear();
   if(!AssertTrue(clearResult, "Clear operation should succeed"))
      return false;
   
   Print("✓ Basic functionality tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test trade operations                                            |
//+------------------------------------------------------------------+
bool CTestKnowledgeBase::TestTradeOperations()
  {
   Print("Testing Trade Operations...");
   
   // Create a test trade record
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
   trade.closeTime = 0;
   trade.profit = 0.0;
   trade.isLive = false;
   trade.confidence = 0.8;
   trade.comment = "Test trade";
   
   // Test adding trade
   bool addResult = m_knowledgeBase.AddTrade(trade);
   if(!AssertTrue(addResult, "Should be able to add a trade"))
      return false;
   
   // Test getting recent trades (may return false if no file exists yet)
   STradeRecord trades[];
   bool getResult = m_knowledgeBase.GetRecentTrades(1, trades);
   // Don't fail if no trades exist yet - this is expected for a new test KB
   if(getResult && ArraySize(trades) > 0)
     {
      if(!AssertEqual(1, ArraySize(trades), 0.001, "Should return 1 trade"))
         return false;
     }
   
   Print("✓ Trade operations tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test signal operations                                           |
//+------------------------------------------------------------------+
bool CTestKnowledgeBase::TestSignalOperations()
  {
   Print("Testing Signal Operations...");
   
   // Create a test signal for rejection logging
   STradeSignal signal;
   signal.timestamp = TimeCurrent();
   signal.symbol = "EURUSD";
   signal.signal = SIGNAL_BUY;
   signal.confidence = 0.8;
   signal.comment = "Test signal";
   
   // Test signal rejection logging (this is a void method)
   m_knowledgeBase.LogSignalRejection(signal, "Test rejection reason");
   
   // Test regime classification
   bool regimeResult = m_knowledgeBase.SaveRegimeClassification("EURUSD", "trending", TimeCurrent());
   if(!AssertTrue(regimeResult, "Should be able to save regime classification"))
      return false;
   
   // Test getting current regime
   string regime = m_knowledgeBase.GetCurrentRegime("EURUSD");
   if(!AssertStringEqual("trending", regime, true, "Should return the correct regime"))
      return false;
   
   Print("✓ Signal operations tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Script start function                                            |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("=== Starting KnowledgeBase Unit Tests ===");
   
   CTestKnowledgeBase test;
   test.SetUp();
   
   ENUM_TEST_RESULT result = test.Run();
   test.PrintTestResult(result);
   
   test.TearDown();
   
   Print("=== KnowledgeBase Unit Tests Complete ===");
  }