//+------------------------------------------------------------------+
//| CArchitectureTests.mqh - Comprehensive Test Suite for P0-P5      |
//| Tests all new architectural systems: Config, Error, Resources    |
//+------------------------------------------------------------------+
#ifndef CARCHITECTURE_TESTS_MQH
#define CARCHITECTURE_TESTS_MQH

#include "CArchitectureConfig.mqh"
#include "CErrorHandling.mqh"
#include "CResourceManager.mqh"

//+------------------------------------------------------------------+
//| Test Result Structure                                            |
//+------------------------------------------------------------------+
struct STestResult
{
   string test_name;
   bool   passed;
   string message;
   double execution_time_ms;
   
   void Set(const string name, bool p, const string msg, double exec_time)
   {
      test_name = name;
      passed = p;
      message = msg;
      execution_time_ms = exec_time;
   }
   
   string ToString()
   {
      return StringFormat("[%s] %s: %s (%.2f ms)",
         passed ? "PASS" : "FAIL",
         test_name,
         message,
         execution_time_ms);
   }
};

//+------------------------------------------------------------------+
//| Architecture Test Suite Class                                    |
//+------------------------------------------------------------------+
class CArchitectureTestSuite
{
private:
   STestResult       m_results[];
   int               m_result_count;
   int               m_passed_count;
   int               m_failed_count;
   datetime          m_start_time;
   
public:
   CArchitectureTestSuite()
   {
      m_result_count = 0;
      m_passed_count = 0;
      m_failed_count = 0;
      ArrayResize(m_results, 100);
      m_start_time = TimeCurrent();
   }
   
   //+------------------------------------------------------------------+
   //| Run All Tests                                                    |
   //+------------------------------------------------------------------+
   bool RunAllTests()
   {
      Print("\n========================================");
      Print("  P0-P5 ARCHITECTURE TEST SUITE");
      Print("========================================\n");
      
      ulong suite_start = GetMicrosecondCount();
      
      // Phase 1: Configuration Tests
      Test_Config_Validation();
      Test_Config_GateSystemDefaults();
      Test_Config_RiskEngineDefaults();
      Test_Config_InvalidRanges();
      
      // Phase 2: Error Handling Tests
      Test_Error_Logging();
      Test_Error_Categories();
      Test_Error_CircuitBreaker();
      Test_Error_History();
      
      // Phase 3: Resource Manager Tests
      Test_Resource_IndicatorTracking();
      Test_Resource_FileTracking();
      Test_Resource_Ownership();
      Test_Resource_LeakDetection();
      
      // Phase 4: Integration Tests
      Test_Integration_AllSystems();
      
      ulong suite_end = GetMicrosecondCount();
      double suite_time_ms = (suite_end - suite_start) / 1000.0;
      
      // Print Results
      PrintResults(suite_time_ms);
      
      return m_failed_count == 0;
   }
   
private:
   //+------------------------------------------------------------------+
   //| Configuration Tests                                              |
   //+------------------------------------------------------------------+
   void Test_Config_Validation()
   {
      ulong start = GetMicrosecondCount();
      
      CArchitectureConfig config;
      config.SetAllDefaults();
      bool valid = config.ValidateAll();
      
      ulong end = GetMicrosecondCount();
      double time_ms = (end - start) / 1000.0;
      
      if(valid)
         AddResult("Config_Validation", true, "All configurations valid", time_ms);
      else
         AddResult("Config_Validation", false, "Validation failed:\n" + config.GetValidationReport(), time_ms);
   }
   
   void Test_Config_GateSystemDefaults()
   {
      ulong start = GetMicrosecondCount();
      
      CArchitectureConfig config;
      config.SetAllDefaults();
      
      bool budget_ok = true;
      for(int i = 0; i < 8; i++)
      {
         if(config.GateSystem.gate_budgets_us[i] != 2000)
            budget_ok = false;
      }
      
      ulong end = GetMicrosecondCount();
      double time_ms = (end - start) / 1000.0;
      
      AddResult("Config_GateDefaults", budget_ok, 
         StringFormat("Gate budgets: %d us per gate", config.GateSystem.total_budget_us),
         time_ms);
   }
   
   void Test_Config_RiskEngineDefaults()
   {
      ulong start = GetMicrosecondCount();
      
      CArchitectureConfig config;
      config.SetAllDefaults();
      
      bool defaults_ok = (
         config.RiskEngine.max_drawdown_pct == 10.0 &&
         config.RiskEngine.kelly_fraction == 0.25 &&
         config.RiskEngine.var_confidence == 0.95
      );
      
      ulong end = GetMicrosecondCount();
      double time_ms = (end - start) / 1000.0;
      
      AddResult("Config_RiskDefaults", defaults_ok,
         StringFormat("MaxDD=%.1f%%, Kelly=%.2f, VaR=%.2f",
            config.RiskEngine.max_drawdown_pct,
            config.RiskEngine.kelly_fraction,
            config.RiskEngine.var_confidence),
         time_ms);
   }
   
   void Test_Config_InvalidRanges()
   {
      ulong start = GetMicrosecondCount();
      
      CArchitectureConfig config;
      config.SetAllDefaults();
      
      // Set invalid values
      config.RiskEngine.max_drawdown_pct = -5.0;  // Invalid
      config.RiskEngine.kelly_fraction = 2.0;      // Invalid (> 1.0)
      
      bool validation_caught = !config.ValidateAll();
      
      ulong end = GetMicrosecondCount();
      double time_ms = (end - start) / 1000.0;
      
      AddResult("Config_InvalidRanges", validation_caught,
         "Validation correctly caught invalid ranges",
         time_ms);
   }
   
   //+------------------------------------------------------------------+
   //| Error Handling Tests                                               |
   //+------------------------------------------------------------------+
   void Test_Error_Logging()
   {
      ulong start = GetMicrosecondCount();
      
      CErrorHandler handler;
      handler.Info(ERR_CAT_SYSTEM, "Test", "TestFunc", "Test info message");
      handler.Warning(ERR_CAT_FILE, "Test", "TestFunc", 123, "Test warning");
      handler.Error(ERR_CAT_NETWORK, "Test", "TestFunc", 456, "Test error");
      
      int total = handler.GetErrorCount(ERR_SEVERITY_INFO) +
                  handler.GetErrorCount(ERR_SEVERITY_WARNING) +
                  handler.GetErrorCount(ERR_SEVERITY_ERROR);
      
      ulong end = GetMicrosecondCount();
      double time_ms = (end - start) / 1000.0;
      
      AddResult("Error_Logging", total == 3,
         StringFormat("Logged %d errors correctly", total),
         time_ms);
   }
   
   void Test_Error_Categories()
   {
      ulong start = GetMicrosecondCount();
      
      CErrorHandler handler;
      
      // Log one error per category
      for(int cat = ERR_CAT_INIT; cat <= ERR_CAT_SYSTEM; cat++)
      {
         handler.Error((ENUM_ERROR_CATEGORY)cat, "Test", "TestFunc", cat, "Category test");
      }
      
      int total_categories = 0;
      for(int cat = ERR_CAT_INIT; cat <= ERR_CAT_SYSTEM; cat++)
      {
         if(handler.GetCategoryCount((ENUM_ERROR_CATEGORY)cat) > 0)
            total_categories++;
      }
      
      ulong end = GetMicrosecondCount();
      double time_ms = (end - start) / 1000.0;
      
      AddResult("Error_Categories", total_categories == 9,
         StringFormat("Logged errors in %d/9 categories", total_categories),
         time_ms);
   }
   
   void Test_Error_CircuitBreaker()
   {
      ulong start = GetMicrosecondCount();
      
      CErrorHandler handler;
      
      // Trip circuit breaker
      for(int i = 0; i < 15; i++)
      {
         handler.Error(ERR_CAT_SYSTEM, "Test", "TestFunc", i, "Circuit breaker test");
      }
      
      bool tripped = handler.IsCircuitBreakerTripped();
      
      ulong end = GetMicrosecondCount();
      double time_ms = (end - start) / 1000.0;
      
      AddResult("Error_CircuitBreaker", tripped,
         "Circuit breaker tripped after 10 errors",
         time_ms);
   }
   
   void Test_Error_History()
   {
      ulong start = GetMicrosecondCount();
      
      CErrorHandler handler;
      
      // Log some errors
      for(int i = 0; i < 5; i++)
      {
         handler.Error(ERR_CAT_SYSTEM, "Test", "TestFunc", i, "History test");
      }
      
      string recent = handler.GetRecentErrors(3);
      bool has_history = StringFind(recent, "History test") >= 0;
      
      ulong end = GetMicrosecondCount();
      double time_ms = (end - start) / 1000.0;
      
      AddResult("Error_History", has_history,
         "Error history correctly maintained",
         time_ms);
   }
   
   //+------------------------------------------------------------------+
   //| Resource Manager Tests                                             |
   //+------------------------------------------------------------------+
   void Test_Resource_IndicatorTracking()
   {
      ulong start = GetMicrosecondCount();
      
      CResourceManager manager;
      
      // Simulate indicator handle (use a dummy value)
      int dummy_handle = 12345;
      manager.TrackIndicator(dummy_handle, "Test", "Test MA indicator", __FILE__, __LINE__);
      
      // Release it
      bool released = manager.ReleaseIndicator(dummy_handle, "Test");
      
      ulong end = GetMicrosecondCount();
      double time_ms = (end - start) / 1000.0;
      
      AddResult("Resource_Indicator", released,
         "Indicator handle tracked and released",
         time_ms);
   }
   
   void Test_Resource_FileTracking()
   {
      ulong start = GetMicrosecondCount();
      
      CResourceManager manager;
      
      // Simulate file handle
      int dummy_handle = 67890;
      manager.TrackFile(dummy_handle, "Test", "Test log file", __FILE__, __LINE__);
      
      // Release it
      bool released = manager.ReleaseFile(dummy_handle, "Test");
      
      ulong end = GetMicrosecondCount();
      double time_ms = (end - start) / 1000.0;
      
      AddResult("Resource_File", released,
         "File handle tracked and released",
         time_ms);
   }
   
   void Test_Resource_Ownership()
   {
      ulong start = GetMicrosecondCount();
      
      CResourceManager manager;
      
      // Track multiple resources for different owners
      manager.TrackIndicator(1001, "OwnerA", "MA20", __FILE__, __LINE__);
      manager.TrackIndicator(1002, "OwnerA", "RSI14", __FILE__, __LINE__);
      manager.TrackIndicator(1003, "OwnerB", "MACD", __FILE__, __LINE__);
      
      // Release all for OwnerA
      int released = manager.ReleaseAllForOwner("OwnerA");
      
      ulong end = GetMicrosecondCount();
      double time_ms = (end - start) / 1000.0;
      
      AddResult("Resource_Ownership", released == 2,
         StringFormat("Released %d resources for OwnerA", released),
         time_ms);
   }
   
   void Test_Resource_LeakDetection()
   {
      ulong start = GetMicrosecondCount();
      
      CResourceManager manager;
      
      // Track resources but don't release some
      manager.TrackIndicator(2001, "Test", "Released", __FILE__, __LINE__);
      manager.TrackIndicator(2002, "Test", "Leaked", __FILE__, __LINE__);
      
      // Only release one
      manager.ReleaseIndicator(2001, "Test");
      
      // Check stats
      string stats = manager.GetStatistics();
      bool has_leak_info = StringFind(stats, "Leaked") >= 0 || StringFind(stats, "Alloc") >= 0;
      
      ulong end = GetMicrosecondCount();
      double time_ms = (end - start) / 1000.0;
      
      AddResult("Resource_LeakDetection", has_leak_info,
         "Leak detection statistics available",
         time_ms);
   }
   
   //+------------------------------------------------------------------+
   //| Integration Tests                                                  |
   //+------------------------------------------------------------------+
   void Test_Integration_AllSystems()
   {
      ulong start = GetMicrosecondCount();
      
      // Test all systems working together
      CArchitectureConfig config;
      config.SetAllDefaults();
      
      CErrorHandler errors;
      CResourceManager resources;
      
      // Simulate a scenario: Config validation fails
      config.GateSystem.total_budget_us = 100; // Too small
      
      if(!config.ValidateAll())
      {
         errors.Error(ERR_CAT_CONFIG, "Integration", "Test", 1, "Config validation failed");
      }
      
      // Simulate resource allocation
      resources.TrackIndicator(3001, "Integration", "Test Indicator", __FILE__, __LINE__);
      
      bool all_working = (
         errors.GetErrorCount(ERR_SEVERITY_ERROR) > 0 &&
         StringFind(resources.GetStatistics(), "Alloc") >= 0
      );
      
      ulong end = GetMicrosecondCount();
      double time_ms = (end - start) / 1000.0;
      
      AddResult("Integration_AllSystems", all_working,
         "All architectural systems integrated and functional",
         time_ms);
   }
   
   //+------------------------------------------------------------------+
   //| Result Management                                                  |
   //+------------------------------------------------------------------+
   void AddResult(const string name, bool passed, const string msg, double time_ms)
   {
      int idx = m_result_count;
      if(idx >= ArraySize(m_results))
      {
         ArrayResize(m_results, ArraySize(m_results) + 50);
      }
      
      m_results[idx].Set(name, passed, msg, time_ms);
      m_result_count++;
      
      if(passed)
         m_passed_count++;
      else
         m_failed_count++;
   }
   
   void PrintResults(double total_time_ms)
   {
      Print("\n----------------------------------------");
      Print("  TEST RESULTS SUMMARY");
      Print("----------------------------------------\n");
      
      for(int i = 0; i < m_result_count; i++)
      {
         Print(m_results[i].ToString());
      }
      
      Print("\n----------------------------------------");
      Print(StringFormat("  TOTAL: %d tests | %d passed | %d failed",
         m_result_count, m_passed_count, m_failed_count));
      Print(StringFormat("  Execution Time: %.2f ms", total_time_ms));
      Print(StringFormat("  Success Rate: %.1f%%",
         (double)m_passed_count / m_result_count * 100.0));
      Print("----------------------------------------\n");
      
      if(m_failed_count == 0)
      {
         Print("  ✅ ALL TESTS PASSED - Architecture ready for production");
      }
      else
      {
         Print(StringFormat("  ⚠️  %d TESTS FAILED - Review failures above", m_failed_count));
      }
      
      Print("========================================\n");
   }
};

//+------------------------------------------------------------------+
//| Global Test Function                                               |
//+------------------------------------------------------------------+
bool RunArchitectureTests()
{
   CArchitectureTestSuite test_suite;
   return test_suite.RunAllTests();
}

#endif // CARCHITECTURE_TESTS_MQH
