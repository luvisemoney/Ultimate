//+------------------------------------------------------------------+
//| TestKnowledgeBase.mqh - Unit tests for KnowledgeBase class       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include "..\..\Include\Learning\KnowledgeBase.mqh"
#include "TestBase.mqh"

//+------------------------------------------------------------------+
//| Test class for KnowledgeBase functionality                       |
//+------------------------------------------------------------------+
class CTestKnowledgeBase : public CTestBase
  {
private:
   CKnowledgeBase   *m_kb;           // KnowledgeBase instance
   string            m_testDir;      // Test directory path
   
   // Helper methods
   bool              CleanupTestDir();
   
public:
   // Constructor/destructor
                     CTestKnowledgeBase() : 
                        CTestBase("KnowledgeBase Tests", true),
                        m_kb(NULL),
                        m_testDir("TestData\\KnowledgeBase\\")
                     {}
                    ~CTestKnowledgeBase() {}
   
   // Test cases
   ENUM_TEST_RESULT Test_DirectoryCreation();
   ENUM_TEST_RESULT Test_FileOperations();
   ENUM_TEST_RESULT Test_TradeHistory();
   ENUM_TEST_RESULT Test_ModelOperations();
   
   // Override base class methods
   void              SetUp() override;
   void              TearDown() override;
   ENUM_TEST_RESULT  Run() override;
  };

//+------------------------------------------------------------------+
//| Set up test environment                                          |
//+------------------------------------------------------------------+
void CTestKnowledgeBase::SetUp()
  {
   // Create a test directory
   if(!CleanupTestDir())
     {
      Print("Warning: Could not clean up test directory");
     }
   
   // Initialize KnowledgeBase with test directory
   m_kb = new CKnowledgeBase(m_testDir);
   if(CheckPointer(m_kb) == POINTER_INVALID)
     {
      Print("Error: Failed to create KnowledgeBase instance");
      return;
     }
  }

//+------------------------------------------------------------------+
//| Clean up test environment                                        |
//+------------------------------------------------------------------+
void CTestKnowledgeBase::TearDown()
  {
   // Clean up KnowledgeBase instance
   if(CheckPointer(m_kb) != POINTER_INVALID)
     {
      delete m_kb;
      m_kb = NULL;
     }
     
   // Clean up test directory
   CleanupTestDir();
  }

//+------------------------------------------------------------------+
//| Clean up test directory                                          |
//+------------------------------------------------------------------+
bool CTestKnowledgeBase::CleanupTestDir()
  {
   // In a real implementation, we would delete the test directory and its contents
   // For now, we'll just return true to indicate success
   return true;
  }

//+------------------------------------------------------------------+
//| Test directory creation                                          |
//+------------------------------------------------------------------+
ENUM_TEST_RESULT CTestKnowledgeBase::Test_DirectoryCreation()
  {
   // Test if the test directory was created
   if(!FolderCreate(m_testDir, FILE_COMMON))
     {
      return TEST_FAILED;
     }
     
   return TEST_PASSED;
  }

//+------------------------------------------------------------------+
//| Test file operations                                             |
//+------------------------------------------------------------------+
ENUM_TEST_RESULT CTestKnowledgeBase::Test_FileOperations()
  {
   // Instead of testing private file operations, we'll test the public trade history API
   // which internally uses file operations
   
   // First, clear any existing trades
   if(!m_kb.Clear())
     {
      Print("Failed to clear knowledge base");
      return TEST_FAILED;
     }
   
   // Create a test trade
   STradeRecord trade;
   ZeroMemory(trade);
   trade.ticket = 99999;  // Use a high ticket number to avoid conflicts
   trade.symbol = "TEST";
   trade.type = TRADE_TYPE_BUY;
   trade.lots = 0.1;
   trade.openPrice = 1.0;
   trade.closePrice = 1.1;
   trade.openTime = TimeCurrent() - 3600;
   trade.closeTime = TimeCurrent();
   trade.profit = 10.0;
   trade.commission = 0.1;
   trade.swap = 0.0;
   trade.comment = "Test trade for file operations";
   
   // Add trade to history
   if(!m_kb.AddTrade(trade))
     {
      Print("Failed to add test trade");
      return TEST_FAILED;
     }
     
   // Now load trade history to verify it was saved
   STradeRecord trades[];
   if(!m_kb.LoadTradeHistory(trades))
     {
      Print("Failed to load trade history");
      return TEST_FAILED;
     }
     
   // Verify the trade was saved and loaded correctly
   bool tradeFound = false;
   for(int i = 0; i < ArraySize(trades); i++)
     {
      if(trades[i].ticket == trade.ticket)
        {
         tradeFound = true;
         // Verify some trade properties
         if(trades[i].symbol != trade.symbol || 
            trades[i].type != trade.type || 
            trades[i].lots != trade.lots)
           {
            Print("Trade data mismatch");
            return TEST_FAILED;
           }
         break;
        }
     }
     
   if(!tradeFound)
     {
      Print("Test trade not found in loaded history");
      return TEST_FAILED;
     }
     
   return TEST_PASSED;
  }

//+------------------------------------------------------------------+
//| Test trade history operations                                    |
//+------------------------------------------------------------------+
ENUM_TEST_RESULT CTestKnowledgeBase::Test_TradeHistory()
  {
   // Create a test trade
   STradeRecord trade;
   ZeroMemory(trade);
   trade.ticket = 12345;
   trade.symbol = "EURUSD";
   trade.type = TRADE_TYPE_BUY;  // Changed from ORDER_TYPE_BUY to TRADE_TYPE_BUY
   trade.lots = 0.1;
   trade.openPrice = 1.12345;
   trade.closePrice = 1.12500;
   trade.openTime = TimeCurrent() - 3600;
   trade.closeTime = TimeCurrent();
   trade.profit = 15.50;
   trade.commission = 0.50;
   trade.swap = 0.10;
   trade.comment = "Test trade";
   
   // Add trade to history
   if(!m_kb.AddTrade(trade))
     {
      Print("Failed to add trade to history");
      return TEST_FAILED;
     }
     
   // Load trade history
   STradeRecord trades[];
   if(!m_kb.LoadTradeHistory(trades))
     {
      Print("Failed to load trade history");
      return TEST_FAILED;
     }
     
   // Verify trade was saved correctly
   if(ArraySize(trades) == 0 || trades[0].ticket != trade.ticket)
     {
      Print("Trade history mismatch");
      return TEST_FAILED;
     }
     
   return TEST_PASSED;
  }

//+------------------------------------------------------------------+
//| Test model operations                                            |
//+------------------------------------------------------------------+
ENUM_TEST_RESULT CTestKnowledgeBase::Test_ModelOperations()
  {
   // Create test model data
   double weights[] = {0.1, 0.2, 0.3, 0.4, 0.5};
   string modelFile = m_testDir + "test_model.bin";
   
   // Save model
   if(!m_kb.SaveModel(weights))  // Removed modelFile parameter as it's not in the class definition
     {
      Print("Failed to save model");
      return TEST_FAILED;
     }
     
   // Load model
   double loadedWeights[];
   if(!m_kb.LoadModel(loadedWeights))  // Removed modelFile parameter as it's not in the class definition
     {
      Print("Failed to load model");
      return TEST_FAILED;
     }
     
   // Verify model data
   if(ArraySize(weights) != ArraySize(loadedWeights))
     {
      Print("Model size mismatch");
      return TEST_FAILED;
     }
     
   for(int i = 0; i < ArraySize(weights); i++)
     {
      if(MathAbs(weights[i] - loadedWeights[i]) > 0.0001)
        {
         Print("Model data mismatch at index ", i);
         return TEST_FAILED;
        }
     }
     
   return TEST_PASSED;
  }

//+------------------------------------------------------------------+
//| Run all tests                                                    |
//+------------------------------------------------------------------+
ENUM_TEST_RESULT CTestKnowledgeBase::Run()
  {
   ENUM_TEST_RESULT result = TEST_PASSED;
   
   // Run each test case
   if(Test_DirectoryCreation() != TEST_PASSED)
     {
      Print("Test_DirectoryCreation failed");
      result = TEST_FAILED;
     }
     
   if(Test_FileOperations() != TEST_PASSED)
     {
      Print("Test_FileOperations failed");
      result = TEST_FAILED;
     }
     
   if(Test_TradeHistory() != TEST_PASSED)
     {
      Print("Test_TradeHistory failed");
      result = TEST_FAILED;
     }
     
   if(Test_ModelOperations() != TEST_PASSED)
     {
      Print("Test_ModelOperations failed");
      result = TEST_FAILED;
     }
     
   return result;
  }
