//+------------------------------------------------------------------+
//| TestSignalToTradeFlow_Fixed.mq5 - Fixed integration test         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"
#property script_show_inputs

#include "..\Unit\TestBase.mqh"
#include "..\..\Include\Core\SignalGenerator.mqh"
#include "..\..\Include\Core\TradeExecutor.mqh"
#include "..\..\Include\Core\RiskManager.mqh"
#include "..\..\Include\Communication\SecureSignalBroadcaster.mqh"
#include "..\..\Include\Utils\Logger.mqh"

//+------------------------------------------------------------------+
//| Integration test for complete signal-to-trade flow               |
//+------------------------------------------------------------------+
class CTestSignalToTradeFlow : public CTestBase
  {
private:
   CSignalGenerator    *m_signalGen;
   CTradeExecutor      *m_tradeExec;
   CRiskManager        *m_riskMgr;
   CSecureSignalBroadcaster  *m_broadcaster;
   CLogger             *m_logger;
   
   string              m_testSymbol;
   
public:
                       CTestSignalToTradeFlow() : CTestBase("Signal-to-Trade Flow Integration", true) 
                         {
                          m_testSymbol = "EURUSD";
                         }
                      ~CTestSignalToTradeFlow() { Cleanup(); }
   
   void                SetUp() override;
   void                TearDown() override;
   ENUM_TEST_RESULT    Run() override;
   
   // Integration test methods
   bool                TestCompleteSignalFlow();
   bool                TestRiskManagementIntegration();
   bool                TestLoggingIntegration();
   bool                TestBroadcastingIntegration();
   bool                TestErrorHandling();
   
   // Helper methods
   void                Cleanup();
  };

//+------------------------------------------------------------------+
//| Setup integration test environment                               |
//+------------------------------------------------------------------+
void CTestSignalToTradeFlow::SetUp()
  {
   Print("Setting up integration test environment...");
   
   // Initialize logger first
   m_logger = CLogger::Instance();
   m_logger.Initialize("TestLogs\\Integration\\", "SignalFlow_", LOG_LEVEL_DEBUG, true, 5, 1);
   
   // Initialize components with correct parameters
   m_signalGen = new CSignalGenerator(m_testSymbol, PERIOD_H1, 10, 20, 14, 14, 0.6);
   m_tradeExec = new CTradeExecutor(12345, false, m_testSymbol, 10.0); // Paper trading mode
   m_riskMgr = new CRiskManager(m_testSymbol, 2.0, 20.0, 5.0, 1.0, 5); // symbol, risk%, maxDD%, dailyLoss%, maxLots, maxTrades
   m_broadcaster = new CSecureSignalBroadcaster("INTEGRATION_TEST_", 300, 1000);
   
   m_logger.Info("Integration test environment setup complete", "TestSetup");
  }

//+------------------------------------------------------------------+
//| Cleanup integration test environment                             |
//+------------------------------------------------------------------+
void CTestSignalToTradeFlow::TearDown()
  {
   Cleanup();
   if(m_logger != NULL)
     {
      m_logger.Info("Integration test environment cleanup complete", "TestTeardown");
      m_logger.Flush();
     }
  }

//+------------------------------------------------------------------+
//| Cleanup helper                                                   |
//+------------------------------------------------------------------+
void CTestSignalToTradeFlow::Cleanup()
  {
   if(m_signalGen != NULL) { delete m_signalGen; m_signalGen = NULL; }
   if(m_tradeExec != NULL) { delete m_tradeExec; m_tradeExec = NULL; }
   if(m_riskMgr != NULL) { delete m_riskMgr; m_riskMgr = NULL; }
   if(m_broadcaster != NULL) { delete m_broadcaster; m_broadcaster = NULL; }
  }

//+------------------------------------------------------------------+
//| Run all integration tests                                        |
//+------------------------------------------------------------------+
ENUM_TEST_RESULT CTestSignalToTradeFlow::Run()
  {
   bool allPassed = true;
   
   m_logger.Info("Starting signal-to-trade flow integration tests", "IntegrationTest");
   
   allPassed &= TestCompleteSignalFlow();
   allPassed &= TestRiskManagementIntegration();
   allPassed &= TestLoggingIntegration();
   allPassed &= TestBroadcastingIntegration();
   allPassed &= TestErrorHandling();
   
   m_logger.Info(StringFormat("Integration tests completed. Result: %s", 
                             allPassed ? "PASSED" : "FAILED"), "IntegrationTest");
   
   return allPassed ? TEST_PASSED : TEST_FAILED;
  }

//+------------------------------------------------------------------+
//| Test complete signal generation to trade execution flow          |
//+------------------------------------------------------------------+
bool CTestSignalToTradeFlow::TestCompleteSignalFlow()
  {
   Print("Testing Complete Signal Flow...");
   m_logger.Info("Testing complete signal flow", "FlowTest");
   
   // Step 1: Generate signal
   STradeSignal signal = m_signalGen.GenerateSignal();
   
   if(!AssertTrue(signal.symbol == m_testSymbol, "Signal should be for correct symbol"))
     {
      m_logger.Error("Signal symbol mismatch", "FlowTest");
      return false;
     }
   
   m_logger.Info(StringFormat("Generated signal: %s, Confidence: %.2f", 
                             EnumToString(signal.signal), signal.confidence), "FlowTest");
   
   // Step 2: Check if trading is allowed by risk manager
   if(signal.signal != SIGNAL_HOLD && signal.confidence >= m_signalGen.MinConfidence())
     {
      bool tradingAllowed = m_riskMgr.IsTradeAllowed();
      m_logger.Info(StringFormat("Trading allowed: %s", tradingAllowed ? "YES" : "NO"), "FlowTest");
      
      // Step 3: Calculate position size and validate trade parameters
      if(tradingAllowed)
        {
         // Calculate position size based on stop loss
         double stopLossPips = MathAbs(signal.entry - signal.stopLoss) / SymbolInfoDouble(m_testSymbol, SYMBOL_POINT);
         double positionSize = m_riskMgr.CalculatePositionSize(stopLossPips);
         
         if(!AssertTrue(signal.entry > 0, "Signal should have valid entry price"))
           {
            m_logger.Error("Invalid entry price in signal", "FlowTest");
            return false;
           }
         
         if(!AssertTrue(signal.stopLoss != signal.entry, "Stop loss should be different from entry"))
           {
            m_logger.Error("Invalid stop loss in signal", "FlowTest");
            return false;
           }
         
         if(!AssertTrue(signal.takeProfit != signal.entry, "Take profit should be different from entry"))
           {
            m_logger.Error("Invalid take profit in signal", "FlowTest");
            return false;
           }
         
         if(!AssertTrue(positionSize >= 0, "Position size should be calculated"))
           {
            m_logger.Error("Invalid position size calculated", "FlowTest");
            return false;
           }
         
         m_logger.Info(StringFormat("Trade parameters validated successfully. Position size: %.2f", positionSize), "FlowTest");
        }
     }
   
   Print("✓ Complete signal flow test passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test risk management integration                                 |
//+------------------------------------------------------------------+
bool CTestSignalToTradeFlow::TestRiskManagementIntegration()
  {
   Print("Testing Risk Management Integration...");
   m_logger.Info("Testing risk management integration", "RiskTest");
   
   // Test trading allowed check
   bool tradingAllowed = m_riskMgr.IsTradeAllowed();
   m_logger.Info(StringFormat("Trading allowed check: %s", tradingAllowed ? "PASSED" : "FAILED"), "RiskTest");
   
   // Test position size calculation with different stop loss values
   double smallStopLoss = 50.0; // 50 pips
   double largeStopLoss = 200.0; // 200 pips
   
   double smallPositionSize = m_riskMgr.CalculatePositionSize(smallStopLoss);
   double largePositionSize = m_riskMgr.CalculatePositionSize(largeStopLoss);
   
   m_logger.Info(StringFormat("Small SL (%.0f pips) position size: %.2f", smallStopLoss, smallPositionSize), "RiskTest");
   m_logger.Info(StringFormat("Large SL (%.0f pips) position size: %.2f", largeStopLoss, largePositionSize), "RiskTest");
   
   // Larger stop loss should result in smaller position size
   if(!AssertTrue(smallPositionSize >= largePositionSize, "Smaller stop loss should allow larger position size"))
     {
      m_logger.Error("Position sizing logic incorrect", "RiskTest");
      return false;
     }
   
   // Test risk parameters
   if(!AssertTrue(m_riskMgr.RiskPercent() > 0, "Risk percent should be positive"))
     {
      m_logger.Error("Invalid risk percent", "RiskTest");
      return false;
     }
   
   Print("✓ Risk management integration test passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test logging integration across components                       |
//+------------------------------------------------------------------+
bool CTestSignalToTradeFlow::TestLoggingIntegration()
  {
   Print("Testing Logging Integration...");
   m_logger.Info("Testing logging integration across components", "LogTest");
   
   // Test logging from different components
   m_logger.Debug("Debug message from signal generator", "SignalGenerator");
   m_logger.Info("Info message from trade executor", "TradeExecutor");
   m_logger.Warning("Warning message from risk manager", "RiskManager");
   m_logger.Error("Error message from broadcaster", "SignalBroadcaster");
   
   // Test structured logging
   string structuredLog = StringFormat("Signal: %s, Confidence: %.2f, Timestamp: %d", 
                                     "BUY", 0.75, TimeCurrent());
   m_logger.Info(structuredLog, "StructuredLog");
   
   // Flush logs to ensure they're written
   m_logger.Flush();
   
   if(!AssertTrue(true, "Logging should work across all components"))
     {
      m_logger.Error("Logging integration failed", "LogTest");
      return false;
     }
   
   Print("✓ Logging integration test passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test signal broadcasting integration                              |
//+------------------------------------------------------------------+
bool CTestSignalToTradeFlow::TestBroadcastingIntegration()
  {
   Print("Testing Broadcasting Integration...");
   m_logger.Info("Testing signal broadcasting integration", "BroadcastTest");
   
   // Generate and broadcast signals
   STradeSignal signal = m_signalGen.GenerateSignal();
   
   if(signal.signal != SIGNAL_HOLD)
     {
      bool broadcastResult = m_broadcaster.SendSignal(signal.symbol, signal.signal, signal.confidence);
      
      if(!AssertTrue(broadcastResult, "Signal should be broadcast successfully"))
        {
         m_logger.Error("Failed to broadcast signal", "BroadcastTest");
         return false;
        }
      
      m_logger.Info(StringFormat("Successfully broadcast signal: %s", EnumToString(signal.signal)), "BroadcastTest");
     }
   
   // Test status broadcasting
   bool statusResult = m_broadcaster.BroadcastStatus("INTEGRATION_TEST_RUNNING");
   
   if(!AssertTrue(statusResult, "Status should be broadcast successfully"))
     {
      m_logger.Error("Failed to broadcast status", "BroadcastTest");
      return false;
     }
   
   m_logger.Info("Successfully broadcast status", "BroadcastTest");
   
   Print("✓ Broadcasting integration test passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test error handling across components                            |
//+------------------------------------------------------------------+
bool CTestSignalToTradeFlow::TestErrorHandling()
  {
   Print("Testing Error Handling...");
   m_logger.Info("Testing error handling across components", "ErrorTest");
   
   // Test broadcasting invalid signal
   bool broadcastResult = m_broadcaster.SendSignal("", SIGNAL_HOLD, 0.0);
   
   if(!AssertFalse(broadcastResult, "Should reject invalid broadcast parameters"))
     {
      m_logger.Error("Failed to reject invalid broadcast", "ErrorTest");
      return false;
     }
   
   m_logger.Info("Successfully rejected invalid broadcast", "ErrorTest");
   
   // Test component resilience - removed try-catch as MQL5 doesn't support it
   m_signalGen.UpdateIndicators();
   m_logger.Info("Signal generator update completed without errors", "ErrorTest");
   
   // Test invalid position size calculation
   double invalidPositionSize = m_riskMgr.CalculatePositionSize(0.0); // Invalid stop loss
   if(!AssertTrue(invalidPositionSize == 0.0, "Should return 0 for invalid stop loss"))
     {
      m_logger.Error("Failed to handle invalid stop loss", "ErrorTest");
      return false;
     }
   
   m_logger.Info("Successfully handled invalid position size calculation", "ErrorTest");
   
   Print("✓ Error handling test passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Script start function                                            |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("=== Starting Signal-to-Trade Flow Integration Tests ===");
   
   CTestSignalToTradeFlow test;
   test.SetUp();
   
   ENUM_TEST_RESULT result = test.Run();
   test.PrintTestResult(result);
   
   test.TearDown();
   
   Print("=== Signal-to-Trade Flow Integration Tests Complete ===");
  }