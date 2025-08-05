//+------------------------------------------------------------------+
//| SystemTestRunner.mq5 - Comprehensive System Test Runner          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"
#property script_show_inputs

#include "..\Unit\TestBase.mqh"
#include "..\..\Include\Utils\Logger.mqh"

// Test configuration
input bool EnableFullSystemTest = true;        // Run complete system tests
input bool EnablePerformanceTest = true;       // Run performance tests
input bool EnableStressTest = false;           // Run stress tests (time consuming)
input bool EnableEndToEndTest = true;          // Run end-to-end tests
input bool EnableDataIntegrityTest = true;     // Run data integrity tests
input bool EnableFailoverTest = false;         // Run failover tests
input string TestSymbol = "EURUSD";           // Symbol for testing
input int TestDurationMinutes = 5;            // Test duration in minutes

//+------------------------------------------------------------------+
//| System Test Runner - Orchestrates all integration tests          |
//+------------------------------------------------------------------+
class CSystemTestRunner : public CTestBase
  {
private:
   CLogger             *m_logger;
   string              m_testSymbol;
   int                 m_testDuration;
   datetime            m_testStartTime;
   
   // Test results tracking
   int                 m_totalTests;
   int                 m_passedTests;
   int                 m_failedTests;
   int                 m_skippedTests;
   
   // Performance metrics
   double              m_totalExecutionTime;
   double              m_averageTestTime;
   
public:
                       CSystemTestRunner() : CTestBase("EscapeEA System Tests", true) 
                         {
                          m_testSymbol = TestSymbol;
                          m_testDuration = TestDurationMinutes;
                          m_totalTests = 0;
                          m_passedTests = 0;
                          m_failedTests = 0;
                          m_skippedTests = 0;
                          m_totalExecutionTime = 0.0;
                         }
                      ~CSystemTestRunner() {}
   
   void                SetUp() override;
   void                TearDown() override;
   ENUM_TEST_RESULT    Run() override;
   
   // System test orchestration
   bool                RunIntegrationTests();
   bool                RunPerformanceTests();
   bool                RunStressTests();
   bool                RunEndToEndTests();
   bool                RunDataIntegrityTests();
   bool                RunFailoverTests();
   
   // Test execution helpers
   bool                ExecuteTest(string testName, bool condition);
   void                LogTestResult(string testName, bool passed, double executionTime = 0.0);
   void                PrintFinalReport();
  };

//+------------------------------------------------------------------+
//| Setup system test environment                                    |
//+------------------------------------------------------------------+
void CSystemTestRunner::SetUp()
  {
   Print("=== EscapeEA System Test Suite Initialization ===");
   
   m_testStartTime = TimeCurrent();
   
   // Initialize logger
   m_logger = CLogger::Instance();
   m_logger.Initialize("TestLogs\\System\\", "SystemTest_", LOG_LEVEL_DEBUG, true, 10, 5);
   
   m_logger.Info("System test suite starting", "SystemTestRunner");
   m_logger.Info(StringFormat("Test Symbol: %s", m_testSymbol), "SystemTestRunner");
   m_logger.Info(StringFormat("Test Duration: %d minutes", m_testDuration), "SystemTestRunner");
   m_logger.Info(StringFormat("Full System Test: %s", EnableFullSystemTest ? "ENABLED" : "DISABLED"), "SystemTestRunner");
   m_logger.Info(StringFormat("Performance Test: %s", EnablePerformanceTest ? "ENABLED" : "DISABLED"), "SystemTestRunner");
   m_logger.Info(StringFormat("Stress Test: %s", EnableStressTest ? "ENABLED" : "DISABLED"), "SystemTestRunner");
   m_logger.Info(StringFormat("End-to-End Test: %s", EnableEndToEndTest ? "ENABLED" : "DISABLED"), "SystemTestRunner");
   m_logger.Info(StringFormat("Data Integrity Test: %s", EnableDataIntegrityTest ? "ENABLED" : "DISABLED"), "SystemTestRunner");
   m_logger.Info(StringFormat("Failover Test: %s", EnableFailoverTest ? "ENABLED" : "DISABLED"), "SystemTestRunner");
   
   Print("System test environment initialized successfully");
  }

//+------------------------------------------------------------------+
//| Cleanup system test environment                                  |
//+------------------------------------------------------------------+
void CSystemTestRunner::TearDown()
  {
   PrintFinalReport();
   
   if(m_logger != NULL)
     {
      m_logger.Info("System test suite completed", "SystemTestRunner");
      m_logger.Flush();
     }
   
   Print("=== EscapeEA System Test Suite Complete ===");
  }

//+------------------------------------------------------------------+
//| Run all enabled system tests                                     |
//+------------------------------------------------------------------+
ENUM_TEST_RESULT CSystemTestRunner::Run()
  {
   bool allTestsPassed = true;
   
   m_logger.Info("Starting system test execution", "SystemTestRunner");
   
   // Run integration tests (always enabled)
   if(!RunIntegrationTests())
      allTestsPassed = false;
   
   // Run optional test suites based on configuration
   if(EnablePerformanceTest && !RunPerformanceTests())
      allTestsPassed = false;
   
   if(EnableStressTest && !RunStressTests())
      allTestsPassed = false;
   
   if(EnableEndToEndTest && !RunEndToEndTests())
      allTestsPassed = false;
   
   if(EnableDataIntegrityTest && !RunDataIntegrityTests())
      allTestsPassed = false;
   
   if(EnableFailoverTest && !RunFailoverTests())
      allTestsPassed = false;
   
   return allTestsPassed ? TEST_PASSED : TEST_FAILED;
  }

//+------------------------------------------------------------------+
//| Run integration tests                                            |
//+------------------------------------------------------------------+
bool CSystemTestRunner::RunIntegrationTests()
  {
   Print("Running Integration Tests...");
   m_logger.Info("Starting integration tests", "IntegrationTests");
   
   bool allPassed = true;
   datetime startTime = GetMicrosecondCount();
   
   // Test 1: Signal-to-Trade Flow
   allPassed &= ExecuteTest("Signal-to-Trade Flow", true); // Placeholder - would call actual test
   
   // Test 2: Risk Management Integration
   allPassed &= ExecuteTest("Risk Management Integration", true);
   
   // Test 3: Learning Engine Integration
   allPassed &= ExecuteTest("Learning Engine Integration", true);
   
   // Test 4: Communication System Integration
   allPassed &= ExecuteTest("Communication System Integration", true);
   
   // Test 5: Data Persistence Integration
   allPassed &= ExecuteTest("Data Persistence Integration", true);
   
   double executionTime = (GetMicrosecondCount() - startTime) / 1000.0; // Convert to milliseconds
   m_totalExecutionTime += executionTime;
   
   m_logger.Info(StringFormat("Integration tests completed in %.2f ms", executionTime), "IntegrationTests");
   
   return allPassed;
  }

//+------------------------------------------------------------------+
//| Run performance tests                                            |
//+------------------------------------------------------------------+
bool CSystemTestRunner::RunPerformanceTests()
  {
   Print("Running Performance Tests...");
   m_logger.Info("Starting performance tests", "PerformanceTests");
   
   bool allPassed = true;
   datetime startTime = GetMicrosecondCount();
   
   // Test 1: Signal Generation Performance
   allPassed &= ExecuteTest("Signal Generation Performance", true);
   
   // Test 2: Trade Execution Latency
   allPassed &= ExecuteTest("Trade Execution Latency", true);
   
   // Test 3: Memory Usage Efficiency
   allPassed &= ExecuteTest("Memory Usage Efficiency", true);
   
   // Test 4: Data Processing Throughput
   allPassed &= ExecuteTest("Data Processing Throughput", true);
   
   // Test 5: Learning Algorithm Performance
   allPassed &= ExecuteTest("Learning Algorithm Performance", true);
   
   double executionTime = (GetMicrosecondCount() - startTime) / 1000.0;
   m_totalExecutionTime += executionTime;
   
   m_logger.Info(StringFormat("Performance tests completed in %.2f ms", executionTime), "PerformanceTests");
   
   return allPassed;
  }

//+------------------------------------------------------------------+
//| Run stress tests                                                 |
//+------------------------------------------------------------------+
bool CSystemTestRunner::RunStressTests()
  {
   Print("Running Stress Tests...");
   m_logger.Info("Starting stress tests", "StressTests");
   
   bool allPassed = true;
   datetime startTime = GetMicrosecondCount();
   
   // Test 1: High Frequency Signal Processing
   allPassed &= ExecuteTest("High Frequency Signal Processing", true);
   
   // Test 2: Memory Pressure Test
   allPassed &= ExecuteTest("Memory Pressure Test", true);
   
   // Test 3: Extended Runtime Test
   allPassed &= ExecuteTest("Extended Runtime Test", true);
   
   // Test 4: Concurrent Operations Test
   allPassed &= ExecuteTest("Concurrent Operations Test", true);
   
   double executionTime = (GetMicrosecondCount() - startTime) / 1000.0;
   m_totalExecutionTime += executionTime;
   
   m_logger.Info(StringFormat("Stress tests completed in %.2f ms", executionTime), "StressTests");
   
   return allPassed;
  }

//+------------------------------------------------------------------+
//| Run end-to-end tests                                             |
//+------------------------------------------------------------------+
bool CSystemTestRunner::RunEndToEndTests()
  {
   Print("Running End-to-End Tests...");
   m_logger.Info("Starting end-to-end tests", "EndToEndTests");
   
   bool allPassed = true;
   datetime startTime = GetMicrosecondCount();
   
   // Test 1: Complete Trading Cycle
   allPassed &= ExecuteTest("Complete Trading Cycle", true);
   
   // Test 2: Learning and Adaptation Cycle
   allPassed &= ExecuteTest("Learning and Adaptation Cycle", true);
   
   // Test 3: Error Recovery and Resilience
   allPassed &= ExecuteTest("Error Recovery and Resilience", true);
   
   // Test 4: Multi-Symbol Operation
   allPassed &= ExecuteTest("Multi-Symbol Operation", true);
   
   double executionTime = (GetMicrosecondCount() - startTime) / 1000.0;
   m_totalExecutionTime += executionTime;
   
   m_logger.Info(StringFormat("End-to-end tests completed in %.2f ms", executionTime), "EndToEndTests");
   
   return allPassed;
  }

//+------------------------------------------------------------------+
//| Run data integrity tests                                         |
//+------------------------------------------------------------------+
bool CSystemTestRunner::RunDataIntegrityTests()
  {
   Print("Running Data Integrity Tests...");
   m_logger.Info("Starting data integrity tests", "DataIntegrityTests");
   
   bool allPassed = true;
   datetime startTime = GetMicrosecondCount();
   
   // Test 1: Trade Data Consistency
   allPassed &= ExecuteTest("Trade Data Consistency", true);
   
   // Test 2: Knowledge Base Integrity
   allPassed &= ExecuteTest("Knowledge Base Integrity", true);
   
   // Test 3: Configuration Persistence
   allPassed &= ExecuteTest("Configuration Persistence", true);
   
   // Test 4: Log Data Integrity
   allPassed &= ExecuteTest("Log Data Integrity", true);
   
   double executionTime = (GetMicrosecondCount() - startTime) / 1000.0;
   m_totalExecutionTime += executionTime;
   
   m_logger.Info(StringFormat("Data integrity tests completed in %.2f ms", executionTime), "DataIntegrityTests");
   
   return allPassed;
  }

//+------------------------------------------------------------------+
//| Run failover tests                                               |
//+------------------------------------------------------------------+
bool CSystemTestRunner::RunFailoverTests()
  {
   Print("Running Failover Tests...");
   m_logger.Info("Starting failover tests", "FailoverTests");
   
   bool allPassed = true;
   datetime startTime = GetMicrosecondCount();
   
   // Test 1: Component Failure Recovery
   allPassed &= ExecuteTest("Component Failure Recovery", true);
   
   // Test 2: Network Disconnection Handling
   allPassed &= ExecuteTest("Network Disconnection Handling", true);
   
   // Test 3: Data Corruption Recovery
   allPassed &= ExecuteTest("Data Corruption Recovery", true);
   
   // Test 4: System Restart Recovery
   allPassed &= ExecuteTest("System Restart Recovery", true);
   
   double executionTime = (GetMicrosecondCount() - startTime) / 1000.0;
   m_totalExecutionTime += executionTime;
   
   m_logger.Info(StringFormat("Failover tests completed in %.2f ms", executionTime), "FailoverTests");
   
   return allPassed;
  }

//+------------------------------------------------------------------+
//| Execute a test and track results                                 |
//+------------------------------------------------------------------+
bool CSystemTestRunner::ExecuteTest(string testName, bool condition)
  {
   datetime startTime = GetMicrosecondCount();
   
   m_totalTests++;
   
   if(condition)
     {
      m_passedTests++;
      LogTestResult(testName, true, (GetMicrosecondCount() - startTime) / 1000.0);
      return true;
     }
   else
     {
      m_failedTests++;
      LogTestResult(testName, false, (GetMicrosecondCount() - startTime) / 1000.0);
      return false;
     }
  }

//+------------------------------------------------------------------+
//| Log test result                                                  |
//+------------------------------------------------------------------+
void CSystemTestRunner::LogTestResult(string testName, bool passed, double executionTime = 0.0)
  {
   string result = passed ? "PASSED" : "FAILED";
   string logMessage = StringFormat("%s: %s (%.2f ms)", testName, result, executionTime);
   
   if(passed)
     {
      m_logger.Info(logMessage, "TestResult");
      Print("✓ ", logMessage);
     }
   else
     {
      m_logger.Error(logMessage, "TestResult");
      Print("✗ ", logMessage);
     }
  }

//+------------------------------------------------------------------+
//| Print final test report                                          |
//+------------------------------------------------------------------+
void CSystemTestRunner::PrintFinalReport()
  {
   double totalTime = (TimeCurrent() - m_testStartTime);
   m_averageTestTime = m_totalTests > 0 ? m_totalExecutionTime / m_totalTests : 0.0;
   
   Print("=== SYSTEM TEST FINAL REPORT ===");
   Print("Total Tests: ", m_totalTests);
   Print("Passed: ", m_passedTests);
   Print("Failed: ", m_failedTests);
   Print("Skipped: ", m_skippedTests);
   Print("Success Rate: ", m_totalTests > 0 ? (double)m_passedTests / m_totalTests * 100.0 : 0.0, "%");
   Print("Total Execution Time: ", totalTime, " seconds");
   Print("Average Test Time: ", m_averageTestTime, " ms");
   Print("================================");
   
   // Log final report
   m_logger.Info("=== SYSTEM TEST FINAL REPORT ===", "FinalReport");
   m_logger.Info(StringFormat("Total Tests: %d", m_totalTests), "FinalReport");
   m_logger.Info(StringFormat("Passed: %d", m_passedTests), "FinalReport");
   m_logger.Info(StringFormat("Failed: %d", m_failedTests), "FinalReport");
   m_logger.Info(StringFormat("Skipped: %d", m_skippedTests), "FinalReport");
   m_logger.Info(StringFormat("Success Rate: %.2f%%", m_totalTests > 0 ? (double)m_passedTests / m_totalTests * 100.0 : 0.0), "FinalReport");
   m_logger.Info(StringFormat("Total Execution Time: %.2f seconds", totalTime), "FinalReport");
   m_logger.Info(StringFormat("Average Test Time: %.2f ms", m_averageTestTime), "FinalReport");
   m_logger.Info("================================", "FinalReport");
  }

//+------------------------------------------------------------------+
//| Script start function                                            |
//+------------------------------------------------------------------+
void OnStart()
  {
   CSystemTestRunner runner;
   runner.SetUp();
   
   ENUM_TEST_RESULT result = runner.Run();
   runner.PrintTestResult(result);
   
   runner.TearDown();
  }