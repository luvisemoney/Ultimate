//+------------------------------------------------------------------+
//| TestRunner.mqh - Test runner for unit and integration tests      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include "Unit\TestBase.mqh"

// Test result structure
struct TestResult
  {
   string            testName;       // Name of the test
   string            className;      // Class name of the test
   ENUM_TEST_RESULT  result;         // Test result
   string            message;        // Test message
   long              durationMs;     // Test duration in milliseconds
   datetime          timestamp;      // When the test was run
  };

// Test suite statistics
struct TestSuiteStats
  {
   int               totalTests;     // Total number of tests
   int               passedTests;    // Number of passed tests
   int               failedTests;    // Number of failed tests
   int               skippedTests;   // Number of skipped tests
   long              totalDurationMs; // Total duration of all tests
   datetime          startTime;      // When the test suite started
   datetime          endTime;        // When the test suite finished
  };

//+------------------------------------------------------------------+
//| Test Runner Class                                                |
//+------------------------------------------------------------------+
class CTestRunner
  {
private:
   CTestBase        *m_tests[];      // Array of test cases
   TestResult        m_results[];     // Array of test results
   TestSuiteStats    m_stats;         // Test suite statistics
   bool              m_verbose;       // Verbose output flag
   string            m_reportPath;    // Path to save the HTML report
   
   // Private methods
   void              RunTest(CTestBase *test);
   string            GetResultText(ENUM_TEST_RESULT result) const;
   string            GetResultColor(ENUM_TEST_RESULT result) const;
   void              GenerateHtmlReport();
   void              PrintTestResult(const TestResult &result);
   
public:
   // Constructor/destructor
                     CTestRunner(bool verbose = false, string reportPath = "");
                    ~CTestRunner();
   
   // Public methods
   void              AddTest(CTestBase *test);
   void              RunAllTests();
   void              PrintSummary() const;
   
   // Getters
   int               TotalTests() const { return m_stats.totalTests; }
   int               PassedTests() const { return m_stats.passedTests; }
   int               FailedTests() const { return m_stats.failedTests; }
   int               SkippedTests() const { return m_stats.skippedTests; }
   double            PassRate() const { return m_stats.totalTests > 0 ? 
                                    (double)m_stats.passedTests / m_stats.totalTests * 100.0 : 0; }
   TestSuiteStats    GetStats() { return m_stats; }
   TestResult        GetTestResult(int index) 
   { 
      if(index >= 0 && index < ArraySize(m_results))
         return m_results[index]; 
      TestResult empty = {};
      return empty;
   }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTestRunner::CTestRunner(bool verbose = false, string reportPath = "") :
   m_verbose(verbose),
   m_reportPath(reportPath)
  {
   // Initialize statistics
   ZeroMemory(m_stats);
   ArrayResize(m_tests, 0, 100);
   ArrayResize(m_results, 0, 100);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTestRunner::~CTestRunner()
  {
   // Clean up test objects
   for(int i = 0; i < ArraySize(m_tests); i++)
     {
      if(CheckPointer(m_tests[i]) != POINTER_INVALID)
         delete m_tests[i];
     }
   ArrayFree(m_tests);
   ArrayFree(m_results);
  }

//+------------------------------------------------------------------+
//| Add a test to the test suite                                     |
//+------------------------------------------------------------------+
void CTestRunner::AddTest(CTestBase *test)
  {
   if(CheckPointer(test) == POINTER_INVALID)
     {
      Print("Error: Cannot add null test to test runner");
      return;
     }
   
   int size = ArraySize(m_tests);
   ArrayResize(m_tests, size + 1);
   m_tests[size] = test;
   m_stats.totalTests++;
   
   // Also resize results array
   ArrayResize(m_results, m_stats.totalTests);
  }

//+------------------------------------------------------------------+
//| Get text representation of test result                           |
//+------------------------------------------------------------------+
string CTestRunner::GetResultText(ENUM_TEST_RESULT result) const
  {
   switch(result)
     {
      case TEST_PASSED:  return "PASSED";
      case TEST_FAILED:  return "FAILED";
      case TEST_SKIPPED: return "SKIPPED";
      default:           return "UNKNOWN";
     }
  }

//+------------------------------------------------------------------+
//| Get HTML color for test result                                   |
//+------------------------------------------------------------------+
string CTestRunner::GetResultColor(ENUM_TEST_RESULT result) const
  {
   switch(result)
     {
      case TEST_PASSED:  return "#4CAF50"; // Green
      case TEST_FAILED:  return "#F44336"; // Red
      case TEST_SKIPPED: return "#FFC107"; // Amber
      default:           return "#9E9E9E"; // Grey
     }
  }

//+------------------------------------------------------------------+
//| Run a single test case                                           |
//+------------------------------------------------------------------+
void CTestRunner::RunTest(CTestBase *test)
  {
   if(CheckPointer(test) == POINTER_INVALID)
     {
      Print("Error: Cannot run null test");
      return;
     }
   
   // Calculate test index with explicit type conversion
   int testIndex = (int)ArraySize(m_results) - (m_stats.totalTests - m_stats.passedTests - m_stats.failedTests - m_stats.skippedTests) - 1;
   
   // Initialize test result with all fields set to appropriate defaults
   TestResult result;
   result.testName = test.Name();
   result.className = "";
   result.timestamp = TimeCurrent();
   result.result = TEST_SKIPPED;
   result.message = "Test was not executed";
   result.durationMs = 0;
   result.durationMs = 0;
   
   ulong startTime = GetTickCount();
   // Run the test
   bool error = false;
   
   // Run setup
   if(m_verbose) PrintFormat("Setting up test: %s", result.testName);
   test.SetUp(); // Setup doesn't return a value, just call it
   // Check if there was an error during setup
   if(GetLastError() != 0)
     {
      result.result = TEST_FAILED;
      result.message = "Setup failed with error: " + IntegerToString(GetLastError());
      PrintFormat("Setup failed for test %s: %s", result.testName, result.message);
      error = true;
     }
   
   // Run the test if setup was successful
   if(!error)
     {
      if(m_verbose) PrintFormat("Running test: %s", result.testName);
      result.result = test.Run();
      // Get test result message using the public interface
      result.message = "Test completed"; // Default message
      
      // Run teardown
      if(m_verbose) PrintFormat("Tearing down test: %s", result.testName);
      test.TearDown();
     }
   
   // Calculate test duration
   result.durationMs = (long)(GetTickCount64() - startTime);
   m_stats.totalDurationMs += result.durationMs;
   
   // Update statistics
   switch(result.result)
     {
      case TEST_PASSED:
         m_stats.passedTests++;
         break;
      case TEST_FAILED:
         m_stats.failedTests++;
         break;
      case TEST_SKIPPED:
         m_stats.skippedTests++;
         break;
     }
   
   // Store the result
   if(testIndex >= 0 && testIndex < ArraySize(m_results))
     {
      m_results[testIndex] = result;
      // Print test result
      PrintTestResult(result);
     }
   else
     {
      PrintFormat("Error: Invalid test index %d for result storage", testIndex);
     }
  }

//+------------------------------------------------------------------+
//| Print test result to console                                     |
//+------------------------------------------------------------------+
void CTestRunner::PrintTestResult(const TestResult &result)
  {
   string status = GetResultText(result.result);
   
   // Print test result with appropriate color
   if(result.result == TEST_PASSED)
      PrintFormat("[PASS] %s - %s (%.2f ms)", 
                 result.testName, result.message, 
                 result.durationMs / 1000.0);
   else if(result.result == TEST_FAILED)
      PrintFormat("[FAIL] %s - %s (%.2f ms)", 
                 result.testName, result.message, 
                 result.durationMs / 1000.0);
   else if(result.result == TEST_SKIPPED)
      PrintFormat("[SKIP] %s - %s (%.2f ms)", 
                 result.testName, result.message, 
                 result.durationMs / 1000.0);
   else
      PrintFormat("[UNKNOWN] %s - %s (%.2f ms)", 
                 result.testName, result.message, 
                 result.durationMs / 1000.0);
  }

//+------------------------------------------------------------------+
//| Generate HTML report of test results                             |
//+------------------------------------------------------------------+
void CTestRunner::GenerateHtmlReport()
  {
   if(m_reportPath == "")
      return;
      
   string html = "<!DOCTYPE html>\n";
   html += "<html><head>\n";
   html += "<title>EscapeEA Test Report</title>\n";
   html += "<style>\n";
   html += "body { font-family: Arial, sans-serif; line-height: 1.6; margin: 20px; }\n";
   html += "h1 { color: #333; }\n";
   html += ".summary { background: #f5f5f5; padding: 15px; border-radius: 5px; margin-bottom: 20px; }\n";
   html += ".test { margin-bottom: 10px; padding: 10px; border-left: 4px solid #ddd; }\n";
   html += ".passed { border-left-color: #4CAF50; }\n";
   html += ".failed { border-left-color: #F44336; }\n";
   html += ".skipped { border-left-color: #FFC107; }\n";
   html += ".test-name { font-weight: bold; }\n";
   html += ".test-message { color: #666; margin-left: 10px; }\n";
   html += ".test-duration { color: #999; font-size: 0.9em; }\n";
   html += "</style>\n";
   html += "</head><body>\n";
   
   // Report header
   string header, generated;
   StringFormat(header, "<h1>%s</h1>\n", "EscapeEA Test Report");
   StringFormat(generated, "<p>Generated: %s</p>\n", TimeToString(TimeCurrent()));
   html += header + generated;
   
   // Summary section
   html += "<div class='summary'>\n";
   html += "<h2>Summary</h2>\n";
   html += StringFormat("<p>Total Tests: %d</p>\n", m_stats.totalTests);
   // Format the passed tests with percentage
   string passedText, passedRate;
   StringFormat(passedText, "%d", m_stats.passedTests);
   StringFormat(passedRate, "%.1f%%", PassRate());
   html += "<p>Passed: <span style='color:#4CAF50'>" + passedText + " (" + passedRate + ")</span></p>\n";
   html += StringFormat("<p>Failed: <span style='color:#F44336'>%d</span></p>\n", m_stats.failedTests);
   html += StringFormat("<p>Skipped: <span style='color:#FFC107'>%d</span></p>\n", m_stats.skippedTests);
   html += StringFormat("<p>Duration: %.2f seconds</p>\n", m_stats.totalDurationMs / 1000.0);
   html += "</div>\n";
   
   // Test results section
   html += "<h2>Test Results</h2>\n";
   
   for(int i = 0; i < ArraySize(m_results); i++)
     {
      string resultClass = "";
      switch(m_results[i].result)
        {
         case TEST_PASSED:  resultClass = "passed"; break;
         case TEST_FAILED:  resultClass = "failed"; break;
         case TEST_SKIPPED: resultClass = "skipped"; break;
        }
      
      html += StringFormat("<div class='test %s'>\n", resultClass);
      html += StringFormat("<div class='test-name'>%s</div>\n", m_results[i].testName);
      html += StringFormat("<div class='test-message'>%s</div>\n", m_results[i].message);
      html += StringFormat("<div class='test-duration'>%.2f ms</div>\n", m_results[i].durationMs / 1000.0);
      html += "</div>\n";
     }
   
   html += "</body></html>";
   
   // Save to file
   int handle = FileOpen(m_reportPath, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(handle != INVALID_HANDLE)
     {
      FileWriteString(handle, html);
      FileClose(handle);
      Print("HTML report generated: ", m_reportPath);
     }
   else
     {
      Print("Failed to generate HTML report: ", GetLastError());
     }
  }

//+------------------------------------------------------------------+
//| Run all tests in the test suite                                  |
//+------------------------------------------------------------------+
void CTestRunner::RunAllTests()
  {
   // Initialize statistics
   ZeroMemory(m_stats);
   m_stats.totalTests = ArraySize(m_tests);
   m_stats.startTime = TimeCurrent();
   
   Print("\n=== Starting Test Suite ===");
   Print(StringFormat("Running %d test(s)...\n", m_stats.totalTests));
   
   // Run each test
   for(int i = 0; i < ArraySize(m_tests); i++)
     {
      RunTest(m_tests[i]);
     }
   
   // Update end time
   m_stats.endTime = TimeCurrent();
   
   // Print summary
   Print("\n=== Test Suite Complete ===\n");
   PrintSummary();
   
   // Generate HTML report
   if(m_reportPath != "")
      GenerateHtmlReport();
  }

//+------------------------------------------------------------------+
//| Print test summary                                               |
//+------------------------------------------------------------------+
void CTestRunner::PrintSummary() const
  {
   Print("\n=== Test Summary ===");
   Print("-------------------");
   Print(StringFormat("Total Tests:  %d", m_stats.totalTests));
   Print(StringFormat("Passed:       %d (%.1f%%)", m_stats.passedTests, PassRate()));
   Print(StringFormat("Failed:       %d", m_stats.failedTests));
   Print(StringFormat("Skipped:      %d", m_stats.skippedTests));
   Print(StringFormat("Duration:     %.2f seconds", m_stats.totalDurationMs / 1000.0));
   Print("===================\n");
   
   // Print detailed results for failed tests
   if(m_stats.failedTests > 0)
     {
      Print("Failed Tests:");
      Print("------------");
      
      int total = ArraySize(m_results);
      for(int i = 0; i < total; i++)
        {
         if(i < total && m_results[i].result == TEST_FAILED)
           {
            PrintFormat("\x1B[31m[FAILED] %s\x1B[0m - %s", 
                       m_results[i].testName, m_results[i].message);
           }
        }
      Print("");
     }
   
   // Print final status
   if(m_stats.failedTests == 0 && m_stats.skippedTests == 0)
     {
      Print("\x1B[32mALL TESTS PASSED!\x1B[0m\n");
     }
   else if(m_stats.failedTests > 0)
     {
      PrintFormat("\x1B[31m%d TEST(S) FAILED!\x1B[0m\n", m_stats.failedTests);
     }
  }
