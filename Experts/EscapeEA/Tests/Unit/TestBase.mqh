//+------------------------------------------------------------------+
//| TestBase.mqh - Base class for all unit tests                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Test Result Enum                                                 |
//+------------------------------------------------------------------+
enum ENUM_TEST_RESULT
  {
   TEST_PASSED,    // Test passed
   TEST_FAILED,    // Test failed
   TEST_SKIPPED    // Test was skipped
  };

//+------------------------------------------------------------------+
//| Test Base Class                                                  |
//+------------------------------------------------------------------+
class CTestBase
  {
protected:
   string            m_testName;    // Name of the test
   bool              m_verbose;     // Verbose output flag
   
   // Protected methods for assertions
   bool              AssertTrue(bool condition, string message = "");
   bool              AssertFalse(bool condition, string message = "");
   bool              AssertEqual(double expected, double actual, double epsilon = 0.0001, string message = "");
   bool              AssertNotEqual(double expected, double actual, double epsilon = 0.0001, string message = "");
   bool              AssertStringEqual(string expected, string actual, bool caseSensitive = true, string message = "");
   bool              AssertArrayEqual(double &expected[], double &actual[], double epsilon = 0.0001, string message = "");
   
public:
   // Constructor/destructor
                     CTestBase(string name, bool verbose = false);
                    ~CTestBase();
   
   // Public interface
   string            Name() const { return m_testName; }
   virtual void      SetUp() {}
   virtual void      TearDown() {}
   virtual ENUM_TEST_RESULT Run() = 0;
   
   // Test utilities
   void              PrintTestResult(ENUM_TEST_RESULT result, string details = "");
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTestBase::CTestBase(string name, bool verbose = false) : 
   m_testName(name),
   m_verbose(verbose)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTestBase::~CTestBase()
  {
  }

//+------------------------------------------------------------------+
//| Assert that a condition is true                                  |
//+------------------------------------------------------------------+
bool CTestBase::AssertTrue(bool condition, string message = "")
  {
   if(!condition)
     {
      if(m_verbose) Print("AssertTrue failed: ", message);
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Assert that a condition is false                                 |
//+------------------------------------------------------------------+
bool CTestBase::AssertFalse(bool condition, string message = "")
  {
   if(condition)
     {
      if(m_verbose) Print("AssertFalse failed: ", message);
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Assert that two doubles are equal within a tolerance             |
//+------------------------------------------------------------------+
bool CTestBase::AssertEqual(double expected, double actual, double epsilon = 0.0001, string message = "")
  {
   if(MathAbs(expected - actual) > epsilon)
     {
      if(m_verbose) PrintFormat("AssertEqual failed: expected=%.5f, actual=%.5f, %s", 
                              expected, actual, message);
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Assert that two doubles are not equal within a tolerance         |
//+------------------------------------------------------------------+
bool CTestBase::AssertNotEqual(double expected, double actual, double epsilon = 0.0001, string message = "")
  {
   if(MathAbs(expected - actual) <= epsilon)
     {
      if(m_verbose) PrintFormat("AssertNotEqual failed: expected!=%.5f, actual=%.5f, %s", 
                              expected, actual, message);
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Assert that two strings are equal                                |
//+------------------------------------------------------------------+
bool CTestBase::AssertStringEqual(string expected, string actual, bool caseSensitive = true, string message = "")
  {
   if(caseSensitive ? (expected != actual) : (StringToLower(expected) != StringToLower(actual)))
     {
      if(m_verbose) PrintFormat("AssertStringEqual failed: expected='%s', actual='%s', %s", 
                              expected, actual, message);
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Assert that two double arrays are equal                          |
//+------------------------------------------------------------------+
bool CTestBase::AssertArrayEqual(double &expected[], double &actual[], double epsilon = 0.0001, string message = "")
  {
   if(ArraySize(expected) != ArraySize(actual))
     {
      if(m_verbose) PrintFormat("AssertArrayEqual failed: array size mismatch, expected=%d, actual=%d, %s",
                              ArraySize(expected), ArraySize(actual), message);
      return false;
     }
   
   for(int i = 0; i < ArraySize(expected); i++)
     {
      if(MathAbs(expected[i] - actual[i]) > epsilon)
        {
         if(m_verbose) PrintFormat("AssertArrayEqual failed at index %d: expected=%.5f, actual=%.5f, %s",
                                 i, expected[i], actual[i], message);
         return false;
        }
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Print test result with formatting                                |
//+------------------------------------------------------------------+
void CTestBase::PrintTestResult(ENUM_TEST_RESULT result, string details = "")
  {
   string resultStr = (result == TEST_PASSED) ? "PASSED" : 
                     (result == TEST_FAILED) ? "FAILED" : "SKIPPED";
   string output = StringFormat("%-50s [%s]", m_testName, resultStr);
   
   if(details != "")
      output += " - " + details;
      
   Print(output);
  }
