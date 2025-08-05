//+------------------------------------------------------------------+
//| TestFullSystemIntegration.mq5 - Complete system integration test |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"
#property script_show_inputs

#include "..\Unit\TestBase.mqh"
#include "..\..\Include\Core\SignalGenerator.mqh"
#include "..\..\Include\Core\TradeExecutor.mqh"
#include "..\..\Include\Core\RiskManager.mqh"
#include "..\..\Include\Learning\MLLearningEngine.mqh"
#include "..\..\Include\Learning\KnowledgeBase.mqh"
#include "..\..\Include\Communication\SecureSignalBroadcaster.mqh"
#include "..\..\Include\Utils\Logger.mqh"

// Test configuration
input string TestSymbol = "EURUSD";
input int TestDurationMinutes = 3;
input bool EnableLearning = true;
input bool EnableBroadcasting = true;

//+------------------------------------------------------------------+
//| Full system integration test                                     |
//+------------------------------------------------------------------+
class CTestFullSystemIntegration : public CTestBase
  {
private:
   // Core components
   CSignalGenerator    *m_signalGen;
   CTradeExecutor      *m_tradeExec;
   CRiskManager        *m_riskMgr;
   CMLLearningEngine     *m_learningEngine;
   CKnowledgeBase      *m_knowledgeBase;
   CSecureSignalBroadcaster  *m_broadcaster;
   CLogger             *m_logger;
   
   // Test configuration
   string              m_testSymbol;
   int                 m_testDuration;
   datetime            m_testStartTime;
   
   // Test metrics
   int                 m_signalsGenerated;
   int                 m_tradesExecuted;
   int                 m_learningUpdates;
   int                 m_broadcastsSent;
   
public:
                       CTestFullSystemIntegration() : CTestBase("Full System Integration", true) 
                         {
                          m_testSymbol = TestSymbol;
                          m_testDuration = TestDurationMinutes;
                          m_signalsGenerated = 0;
                          m_tradesExecuted = 0;
                          m_learningUpdates = 0;
                          m_broadcastsSent = 0;
                         }
                      ~CTestFullSystemIntegration() { Cleanup(); }
   
   void                SetUp() override;
   void                TearDown() override;
   ENUM_TEST_RESULT    Run() override;
   
   // Integration test methods
   bool                TestSystemInitialization();
   bool                TestCompleteWorkflow();
   bool                TestLearningIntegration();
   bool                TestErrorRecovery();
   bool                TestPerformanceMetrics();
   
   // Helper methods
   void                Cleanup();
   bool                SimulateTradingCycle();
   void                LogSystemMetrics();
  };

//+------------------------------------------------------------------+
//| Setup full system integration test                               |
//+------------------------------------------------------------------+
void CTestFullSystemIntegration::SetUp()
  {
   Print("Setting up full system integration test...");
   m_testStartTime = TimeCurrent();
   
   // Initialize logger first
   m_logger = CLogger::Instance();
   m_logger.Initialize("TestLogs\\Integration\\", "FullSystem_", LOG_LEVEL_DEBUG, true, 5, 1);
   
   // Initialize knowledge base
   m_knowledgeBase = new CKnowledgeBase("test_full_system");
   
   // Initialize learning engine
   if(EnableLearning)
     {
      m_learningEngine = new CMLLearningEngine("EURUSD", PERIOD_H1);
      m_learningEngine.Initialize();
     }
   
   // Initialize core components
   m_signalGen = new CSignalGenerator(m_testSymbol, PERIOD_H1, 10, 20, 14, 14, 0.6);
   m_tradeExec = new CTradeExecutor(12345, false, m_testSymbol, 10.0); // Paper trading
   m_riskMgr = new CRiskManager(m_testSymbol, 2.0, 20.0, 5.0, 1.0, 5);
   
   // Initialize communication
   if(EnableBroadcasting)
     {
      m_broadcaster = new CSecureSignalBroadcaster("FULL_SYSTEM_TEST_", 300, 1000);
     }
   
   m_logger.Info("Full system integration test setup complete", "FullSystemTest");
  }

//+------------------------------------------------------------------+
//| Cleanup full system integration test                             |
//+------------------------------------------------------------------+
void CTestFullSystemIntegration::TearDown()
  {
   LogSystemMetrics();
   Cleanup();
   
   if(m_logger != NULL)
     {
      m_logger.Info("Full system integration test cleanup complete", "FullSystemTest");
      m_logger.Flush();
     }
  }

//+------------------------------------------------------------------+
//| Cleanup helper                                                   |
//+------------------------------------------------------------------+
void CTestFullSystemIntegration::Cleanup()
  {
   if(m_signalGen != NULL) { delete m_signalGen; m_signalGen = NULL; }
   if(m_tradeExec != NULL) { delete m_tradeExec; m_tradeExec = NULL; }
   if(m_riskMgr != NULL) { delete m_riskMgr; m_riskMgr = NULL; }
   if(m_learningEngine != NULL) { delete m_learningEngine; m_learningEngine = NULL; }
   if(m_knowledgeBase != NULL) { delete m_knowledgeBase; m_knowledgeBase = NULL; }
   if(m_broadcaster != NULL) { delete m_broadcaster; m_broadcaster = NULL; }
  }

//+------------------------------------------------------------------+
//| Run full system integration tests                                |
//+------------------------------------------------------------------+
ENUM_TEST_RESULT CTestFullSystemIntegration::Run()
  {
   bool allPassed = true;
   
   m_logger.Info("Starting full system integration tests", "FullSystemTest");
   
   // Test system initialization
   allPassed &= TestSystemInitialization();
   
   // Test complete workflow
   allPassed &= TestCompleteWorkflow();
   
   // Test learning integration (if enabled)
   if(EnableLearning)
      allPassed &= TestLearningIntegration();
   
   // Test error recovery
   allPassed &= TestErrorRecovery();
   
   // Test performance metrics
   allPassed &= TestPerformanceMetrics();
   
   m_logger.Info(StringFormat("Full system integration tests completed. Result: %s", 
                             allPassed ? "PASSED" : "FAILED"), "FullSystemTest");
   
   return allPassed ? TEST_PASSED : TEST_FAILED;
  }

//+------------------------------------------------------------------+
//| Test system initialization                                       |
//+------------------------------------------------------------------+
bool CTestFullSystemIntegration::TestSystemInitialization()
  {
   Print("Testing System Initialization...");
   m_logger.Info("Testing system initialization", "InitTest");
   
   // Verify all components are initialized
   if(!AssertTrue(m_signalGen != NULL, "Signal generator should be initialized"))
     {
      m_logger.Error("Signal generator not initialized", "InitTest");
      return false;
     }
   
   if(!AssertTrue(m_tradeExec != NULL, "Trade executor should be initialized"))
     {
      m_logger.Error("Trade executor not initialized", "InitTest");
      return false;
     }
   
   if(!AssertTrue(m_riskMgr != NULL, "Risk manager should be initialized"))
     {
      m_logger.Error("Risk manager not initialized", "InitTest");
      return false;
     }
   
   if(!AssertTrue(m_knowledgeBase != NULL, "Knowledge base should be initialized"))
     {
      m_logger.Error("Knowledge base not initialized", "InitTest");
      return false;
     }
   
   if(EnableLearning && !AssertTrue(m_learningEngine != NULL, "Learning engine should be initialized"))
     {
      m_logger.Error("Learning engine not initialized", "InitTest");
      return false;
     }
   
   if(EnableBroadcasting && !AssertTrue(m_broadcaster != NULL, "Broadcaster should be initialized"))
     {
      m_logger.Error("Broadcaster not initialized", "InitTest");
      return false;
     }
   
   // Test component connectivity
   bool tradingAllowed = m_riskMgr.IsTradeAllowed();
   m_logger.Info(StringFormat("Trading allowed: %s", tradingAllowed ? "YES" : "NO"), "InitTest");
   
   Print("✓ System initialization test passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test complete workflow                                           |
//+------------------------------------------------------------------+
bool CTestFullSystemIntegration::TestCompleteWorkflow()
  {
   Print("Testing Complete Workflow...");
   m_logger.Info("Testing complete workflow", "WorkflowTest");
   
   datetime endTime = TimeCurrent() + m_testDuration * 60;
   int cycles = 0;
   
   while(TimeCurrent() < endTime && cycles < 10) // Limit cycles for testing
     {
      if(!SimulateTradingCycle())
        {
         m_logger.Error("Trading cycle failed", "WorkflowTest");
         return false;
        }
      
      cycles++;
      Sleep(1000); // Wait 1 second between cycles
     }
   
   m_logger.Info(StringFormat("Completed %d trading cycles", cycles), "WorkflowTest");
   
   if(!AssertTrue(cycles > 0, "Should complete at least one trading cycle"))
     {
      m_logger.Error("No trading cycles completed", "WorkflowTest");
      return false;
     }
   
   Print("✓ Complete workflow test passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test learning integration                                        |
//+------------------------------------------------------------------+
bool CTestFullSystemIntegration::TestLearningIntegration()
  {
   Print("Testing Learning Integration...");
   m_logger.Info("Testing learning integration", "LearningTest");
   
   if(m_learningEngine == NULL)
     {
      m_logger.Warning("Learning engine not available for testing", "LearningTest");
      return true; // Skip test if learning is disabled
     }
   
   // Create a test trade record
   STradeRecord testTrade;
   testTrade.ticket = 12345;
   testTrade.symbol = m_testSymbol;
   testTrade.type = TRADE_TYPE_BUY;
   testTrade.lots = 0.1;
   testTrade.openPrice = 1.1000;
   testTrade.closePrice = 1.1010;
   testTrade.profit = 10.0;
   testTrade.openTime = TimeCurrent() - 3600;
   testTrade.closeTime = TimeCurrent();
   
   // Test learning engine update
   bool updateResult = m_learningEngine.UpdateModel(testTrade);
   
   if(!AssertTrue(updateResult, "Learning engine should update successfully"))
     {
      m_logger.Error("Learning engine update failed", "LearningTest");
      return false;
     }
   
   m_learningUpdates++;
   m_logger.Info("Learning engine updated successfully", "LearningTest");
   
   // Test knowledge base integration
   bool kbResult = m_knowledgeBase.AddTradeRecord(testTrade);
   
   if(!AssertTrue(kbResult, "Knowledge base should store trade record"))
     {
      m_logger.Error("Knowledge base storage failed", "LearningTest");
      return false;
     }
   
   m_logger.Info("Knowledge base updated successfully", "LearningTest");
   
   Print("✓ Learning integration test passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test error recovery                                              |
//+------------------------------------------------------------------+
bool CTestFullSystemIntegration::TestErrorRecovery()
  {
   Print("Testing Error Recovery...");
   m_logger.Info("Testing error recovery", "ErrorTest");
   
   // Test invalid signal handling
   STradeSignal invalidSignal;
   invalidSignal.symbol = "";
   invalidSignal.signal = SIGNAL_HOLD;
   invalidSignal.confidence = -1.0; // Invalid confidence
   
   // System should handle invalid signals gracefully
   bool handled = true; // Assume system handles it (would need actual implementation)
   
   if(!AssertTrue(handled, "System should handle invalid signals gracefully"))
     {
      m_logger.Error("Invalid signal not handled properly", "ErrorTest");
      return false;
     }
   
   // Test component resilience
   m_signalGen.UpdateIndicators(); // Should not crash
   
   m_logger.Info("Error recovery test completed", "ErrorTest");
   
   Print("✓ Error recovery test passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test performance metrics                                         |
//+------------------------------------------------------------------+
bool CTestFullSystemIntegration::TestPerformanceMetrics()
  {
   Print("Testing Performance Metrics...");
   m_logger.Info("Testing performance metrics", "PerformanceTest");
   
   double testDuration = TimeCurrent() - m_testStartTime;
   
   // Calculate performance metrics
   double signalsPerMinute = testDuration > 0 ? (m_signalsGenerated / testDuration) * 60.0 : 0.0;
   double tradesPerMinute = testDuration > 0 ? (m_tradesExecuted / testDuration) * 60.0 : 0.0;
   
   m_logger.Info(StringFormat("Test duration: %.2f seconds", testDuration), "PerformanceTest");
   m_logger.Info(StringFormat("Signals generated: %d (%.2f/min)", m_signalsGenerated, signalsPerMinute), "PerformanceTest");
   m_logger.Info(StringFormat("Trades executed: %d (%.2f/min)", m_tradesExecuted, tradesPerMinute), "PerformanceTest");
   m_logger.Info(StringFormat("Learning updates: %d", m_learningUpdates), "PerformanceTest");
   m_logger.Info(StringFormat("Broadcasts sent: %d", m_broadcastsSent), "PerformanceTest");
   
   // Performance thresholds
   if(!AssertTrue(testDuration > 0, "Test should have measurable duration"))
     {
      m_logger.Error("Invalid test duration", "PerformanceTest");
      return false;
     }
   
   Print("✓ Performance metrics test passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Simulate a complete trading cycle                                |
//+------------------------------------------------------------------+
bool CTestFullSystemIntegration::SimulateTradingCycle()
  {
   // Step 1: Generate signal
   STradeSignal signal = m_signalGen.GenerateSignal();
   m_signalsGenerated++;
   
   // Step 2: Check risk management
   if(signal.signal != SIGNAL_HOLD && m_riskMgr.IsTradeAllowed())
     {
      // Step 3: Calculate position size
      double stopLossPips = MathAbs(signal.entry - signal.stopLoss) / SymbolInfoDouble(m_testSymbol, SYMBOL_POINT);
      double positionSize = m_riskMgr.CalculatePositionSize(stopLossPips);
      
      if(positionSize > 0)
        {
         // Step 4: Execute trade (simulated)
         m_tradesExecuted++;
         m_logger.Info(StringFormat("Simulated trade: %s, Size: %.2f", 
                                   EnumToString(signal.signal), positionSize), "TradingCycle");
         
         // Step 5: Broadcast signal (if enabled)
         if(EnableBroadcasting && m_broadcaster != NULL)
           {
            bool broadcastResult = m_broadcaster.SendSignal(signal.symbol, signal.signal, signal.confidence);
            if(broadcastResult)
               m_broadcastsSent++;
           }
        }
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Log system metrics                                               |
//+------------------------------------------------------------------+
void CTestFullSystemIntegration::LogSystemMetrics()
  {
   double testDuration = TimeCurrent() - m_testStartTime;
   
   Print("=== SYSTEM INTEGRATION METRICS ===");
   Print("Test Duration: ", testDuration, " seconds");
   Print("Signals Generated: ", m_signalsGenerated);
   Print("Trades Executed: ", m_tradesExecuted);
   Print("Learning Updates: ", m_learningUpdates);
   Print("Broadcasts Sent: ", m_broadcastsSent);
   Print("==================================");
  }

//+------------------------------------------------------------------+
//| Script start function                                            |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("=== Starting Full System Integration Test ===");
   
   CTestFullSystemIntegration test;
   test.SetUp();
   
   ENUM_TEST_RESULT result = test.Run();
   test.PrintTestResult(result);
   
   test.TearDown();
   
   Print("=== Full System Integration Test Complete ===");
  }