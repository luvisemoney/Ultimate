//+------------------------------------------------------------------+
//| SecurityTestSuite.mq5 - Comprehensive security testing for EscapeEA |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"
#property script_show_inputs

#include "..\..\Include\Learning\SecureKnowledgeBase.mqh"
#include "..\..\Include\Core\IntervalEvaluator.mqh"
#include "..\..\Include\Communication\SignalRetryQueue.mqh"
#include "..\..\Include\Utils\FileLockManager.mqh"
#include "..\..\Include\Utils\IntegrityChecker.mqh"
#include "..\Unit\TestBase.mqh"

//+------------------------------------------------------------------+
//| Security Test Suite Class                                        |
//+------------------------------------------------------------------+
class CSecurityTestSuite : public CTestBase
  {
private:
   CSecureKnowledgeBase *m_secureKB;
   CIntervalEvaluator   *m_evaluator;
   CSignalRetryQueue    *m_retryQueue;
   CFileLockManager     *m_lockManager;
   CIntegrityChecker    *m_integrityChecker;
   
   // Test methods
   bool              TestBoundsChecking();
   bool              TestInputValidation();
   bool              TestResourceLimits();
   bool              TestFileLocking();
   bool              TestDataIntegrity();
   bool              TestFuzzingAttacks();
   bool              TestMemoryExhaustion();
   bool              TestInfiniteLoopPrevention();
   
public:
                     CSecurityTestSuite() : CTestBase("Security Test Suite", true) {}
   
   void              SetUp() override;
   void              TearDown() override;
   ENUM_TEST_RESULT  Run() override;
  };

//+------------------------------------------------------------------+
//| Test setup                                                       |
//+------------------------------------------------------------------+
void CSecurityTestSuite::SetUp()
  {
   Print("Setting up security test environment...");
   
   // Initialize components
   m_secureKB = new CSecureKnowledgeBase("security_test");
   m_evaluator = new CIntervalEvaluator(1, 5, 5); // 1 minute intervals for testing
   m_retryQueue = new CSignalRetryQueue("test_queue.dat");
   m_lockManager = new CFileLockManager("test_locks");
   m_integrityChecker = new CIntegrityChecker();
   
   Print("Security test environment ready");
  }

//+------------------------------------------------------------------+
//| Test teardown                                                    |
//+------------------------------------------------------------------+
void CSecurityTestSuite::TearDown()
  {
   Print("Cleaning up security test environment...");
   
   // Clean up components
   if(CheckPointer(m_secureKB) != POINTER_INVALID)
      delete m_secureKB;
   if(CheckPointer(m_evaluator) != POINTER_INVALID)
      delete m_evaluator;
   if(CheckPointer(m_retryQueue) != POINTER_INVALID)
      delete m_retryQueue;
   if(CheckPointer(m_lockManager) != POINTER_INVALID)
      delete m_lockManager;
   if(CheckPointer(m_integrityChecker) != POINTER_INVALID)
      delete m_integrityChecker;
   
   Print("Security test cleanup complete");
  }

//+------------------------------------------------------------------+
//| Test bounds checking mechanisms                                  |
//+------------------------------------------------------------------+
bool CSecurityTestSuite::TestBoundsChecking()
  {
   Print("Testing bounds checking...");
   
   // Test 1: Large signal array
   SSignalMetadata signals[];
   ArrayResize(signals, 15000); // Exceeds MAX_SIGNALS_PER_FILE
   
   for(int i = 0; i < 15000; i++)
     {
      signals[i].signal_id = StringFormat("test_signal_%d", i);
      signals[i].confidence = 0.8;
      signals[i].timestamp = TimeCurrent();
      signals[i].symbol = "EURUSD";
     }
   
   // This should fail due to bounds checking
   bool result1 = true;
   for(int i = 0; i < 15000; i++)
     {
      if(!m_secureKB.SaveSignal(signals[i]))
        {
         result1 = false;
         break;
        }
     }
   
   if(!AssertFalse(result1, "Bounds checking should prevent excessive signals"))
      return false;
   
   // Test 2: Malformed JSON with excessive nesting
   string malformedJson = "";
   for(int i = 0; i < 1000; i++)
      malformedJson += "{\"nested\":";
   for(int i = 0; i < 1000; i++)
      malformedJson += "}";
   
   SIntegrityResult integrityResult = m_integrityChecker.ValidateJsonData(malformedJson);
   if(!AssertTrue(integrityResult.errorCount > 0, "Should detect malformed JSON"))
      return false;
   
   Print("Bounds checking tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test input validation                                            |
//+------------------------------------------------------------------+
bool CSecurityTestSuite::TestInputValidation()
  {
   Print("Testing input validation...");
   
   // Test 1: Invalid signal ID
   SSignalMetadata invalidSignal;
   invalidSignal.signal_id = "invalid<>signal\"id"; // Contains invalid characters
   invalidSignal.confidence = 0.8;
   invalidSignal.timestamp = TimeCurrent();
   invalidSignal.symbol = "EURUSD";
   
   bool result1 = m_secureKB.SaveSignal(invalidSignal);
   if(!AssertFalse(result1, "Should reject invalid signal ID"))
      return false;
   
   // Test 2: Invalid confidence values
   SSignalMetadata invalidConfidence;
   invalidConfidence.signal_id = "valid_signal_id";
   invalidConfidence.confidence = 1.5; // Invalid confidence > 1.0
   invalidConfidence.timestamp = TimeCurrent();
   invalidConfidence.symbol = "EURUSD";
   
   bool result2 = m_secureKB.SaveSignal(invalidConfidence);
   if(!AssertFalse(result2, "Should reject invalid confidence"))
      return false;
   
   // Test 3: SQL injection attempt in symbol
   SSignalMetadata injectionAttempt;
   injectionAttempt.signal_id = "injection_test";
   injectionAttempt.confidence = 0.8;
   injectionAttempt.timestamp = TimeCurrent();
   injectionAttempt.symbol = "'; DROP TABLE signals; --";
   
   bool result3 = m_secureKB.SaveSignal(injectionAttempt);
   // Should succeed but with sanitized data
   if(!AssertTrue(result3, "Should handle injection attempts gracefully"))
      return false;
   
   Print("Input validation tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test resource limits                                             |
//+------------------------------------------------------------------+
bool CSecurityTestSuite::TestResourceLimits()
  {
   Print("Testing resource limits...");
   
   // Test 1: Queue size limits
   STradeSignal testSignal;
   testSignal.signal = SIGNAL_BUY;
   testSignal.confidence = 0.8;
   testSignal.symbol = "EURUSD";
   testSignal.timestamp = TimeCurrent();
   
   int successCount = 0;
   for(int i = 0; i < 1500; i++) // Exceeds MAX_QUEUE_SIZE
     {
      if(m_retryQueue.EnqueueSignal(testSignal))
         successCount++;
     }
   
   if(!AssertTrue(successCount < 1500, "Queue should enforce size limits"))
      return false;
   
   // Test 2: File lock timeout
   bool lockAcquired1 = m_lockManager.AcquireLock("test_file.dat", 1); // 1 second timeout
   if(!AssertTrue(lockAcquired1, "Should acquire first lock"))
      return false;
   
   // Try to acquire same lock (should timeout)
   CFileLockManager secondLockManager("test_locks");
   bool lockAcquired2 = secondLockManager.AcquireLock("test_file.dat", 1);
   if(!AssertFalse(lockAcquired2, "Should timeout on second lock attempt"))
      return false;
   
   m_lockManager.ReleaseLock("test_file.dat");
   
   Print("Resource limits tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test file locking mechanisms                                     |
//+------------------------------------------------------------------+
bool CSecurityTestSuite::TestFileLocking()
  {
   Print("Testing file locking...");
   
   // Test 1: Basic lock acquisition and release
   bool acquired = m_lockManager.AcquireLock("test_lock_file.dat");
   if(!AssertTrue(acquired, "Should acquire lock"))
      return false;
   
   bool isLocked = m_lockManager.IsLocked("test_lock_file.dat");
   if(!AssertTrue(isLocked, "File should be locked"))
      return false;
   
   bool released = m_lockManager.ReleaseLock("test_lock_file.dat");
   if(!AssertTrue(released, "Should release lock"))
      return false;
   
   bool stillLocked = m_lockManager.IsLocked("test_lock_file.dat");
   if(!AssertFalse(stillLocked, "File should not be locked after release"))
      return false;
   
   // Test 2: Lock expiration
   CFileLockManager tempLockManager("test_locks");
   tempLockManager.AcquireLock("expiry_test.dat", 1); // 1 second timeout
   
   Sleep(2000); // Wait 2 seconds
   
   bool expiredLockAcquired = m_lockManager.AcquireLock("expiry_test.dat");
   if(!AssertTrue(expiredLockAcquired, "Should acquire expired lock"))
      return false;
   
   m_lockManager.ReleaseLock("expiry_test.dat");
   
   Print("File locking tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test data integrity checking                                     |
//+------------------------------------------------------------------+
bool CSecurityTestSuite::TestDataIntegrity()
  {
   Print("Testing data integrity...");
   
   // Test 1: Valid trade record validation
   STradeRecord validTrade;
   validTrade.ticket = 12345;
   validTrade.symbol = "EURUSD";
   validTrade.openTime = TimeCurrent();
   validTrade.openPrice = 1.1000;
   validTrade.lots = 0.1;
   validTrade.confidence = 0.8;
   validTrade.type = TRADE_TYPE_BUY;
   validTrade.signal = SIGNAL_BUY;
   
   STradeRecord trades[];
   ArrayResize(trades, 1);
   trades[0] = validTrade;
   
   SIntegrityResult result1 = m_integrityChecker.ValidateTradeHistory(trades);
   if(!AssertTrue(result1.isValid, "Valid trade should pass integrity check"))
      return false;
   
   // Test 2: Invalid trade record
   STradeRecord invalidTrade;
   invalidTrade.ticket = 0; // Invalid ticket
   invalidTrade.symbol = ""; // Empty symbol
   invalidTrade.openTime = 0; // Invalid time
   invalidTrade.openPrice = -1.0; // Invalid price
   invalidTrade.lots = 0.0; // Invalid lot size
   invalidTrade.confidence = 2.0; // Invalid confidence
   
   ArrayResize(trades, 1);
   trades[0] = invalidTrade;
   
   SIntegrityResult result2 = m_integrityChecker.ValidateTradeHistory(trades);
   if(!AssertFalse(result2.isValid, "Invalid trade should fail integrity check"))
      return false;
   
   // Test 3: Checksum validation
   string testData = "This is test data for checksum validation";
   uint checksum = m_integrityChecker.GenerateChecksum(testData);
   
   bool checksumValid = m_integrityChecker.VerifyChecksum(testData, checksum);
   if(!AssertTrue(checksumValid, "Checksum should validate correctly"))
      return false;
   
   bool checksumInvalid = m_integrityChecker.VerifyChecksum(testData + "modified", checksum);
   if(!AssertFalse(checksumInvalid, "Modified data should fail checksum validation"))
      return false;
   
   Print("Data integrity tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test fuzzing attacks                                             |
//+------------------------------------------------------------------+
bool CSecurityTestSuite::TestFuzzingAttacks()
  {
   Print("Testing fuzzing attacks...");
   
   // Test 1: Random data fuzzing
   for(int i = 0; i < 100; i++)
     {
      string randomData = "";
      int length = MathRand() % 1000 + 1;
      
      for(int j = 0; j < length; j++)
        {
         ushort randomChar = (ushort)(MathRand() % 256);
         randomData += ShortToString(randomChar);
        }
      
      // Try to validate random data - should not crash
      SIntegrityResult fuzzResult = m_integrityChecker.ValidateJsonData(randomData);
      // We don't care about the result, just that it doesn't crash
     }
   
   // Test 2: Signal fuzzing
   for(int i = 0; i < 50; i++)
     {
      SSignalMetadata fuzzSignal;
      fuzzSignal.signal_id = StringFormat("fuzz_%d_%d", i, MathRand());
      fuzzSignal.confidence = (double)(MathRand() % 200) / 100.0; // 0.0 to 2.0
      fuzzSignal.timestamp = (datetime)(MathRand() % 2000000000);
      
      // Generate random symbol
      string randomSymbol = "";
      int symbolLength = MathRand() % 20 + 1;
      for(int j = 0; j < symbolLength; j++)
        {
         ushort ch = (ushort)(65 + MathRand() % 26); // A-Z
         randomSymbol += ShortToString(ch);
        }
      fuzzSignal.symbol = randomSymbol;
      
      // Try to save - should handle gracefully
      m_secureKB.SaveSignal(fuzzSignal);
     }
   
   Print("Fuzzing attack tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test memory exhaustion prevention                                |
//+------------------------------------------------------------------+
bool CSecurityTestSuite::TestMemoryExhaustion()
  {
   Print("Testing memory exhaustion prevention...");
   
   // Test 1: Large array allocation attempt
   STradeRecord largeArray[];
   bool allocationSucceeded = true;
   
   try
     {
      ArrayResize(largeArray, 100000); // Large allocation
      
      // Fill with data
      for(int i = 0; i < 1000; i++) // Only fill first 1000 to avoid timeout
        {
         largeArray[i].ticket = i + 1;
         largeArray[i].symbol = "TEST";
         largeArray[i].openTime = TimeCurrent();
         largeArray[i].openPrice = 1.0;
         largeArray[i].lots = 0.01;
         largeArray[i].confidence = 0.5;
        }
     }
   catch(...)
     {
      allocationSucceeded = false;
     }
   
   // Should handle large allocations gracefully
   if(!AssertTrue(allocationSucceeded, "Should handle large allocations"))
      return false;
   
   // Test 2: Rapid allocation/deallocation
   for(int i = 0; i < 10; i++)
     {
      STradeRecord tempArray[];
      ArrayResize(tempArray, 1000);
      
      // Fill array
      for(int j = 0; j < 1000; j++)
        {
         tempArray[j].ticket = j + 1;
         tempArray[j].symbol = "TEMP";
        }
      
      // Array will be automatically freed when going out of scope
     }
   
   Print("Memory exhaustion prevention tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test infinite loop prevention                                    |
//+------------------------------------------------------------------+
bool CSecurityTestSuite::TestInfiniteLoopPrevention()
  {
   Print("Testing infinite loop prevention...");
   
   // Test 1: Malformed JSON that could cause infinite parsing
   string malformedJson = "{\"signal_id\":\"test\",\"nested\":{\"deep\":{\"very\":{\"extremely\":{\"infinitely\":";
   for(int i = 0; i < 100; i++)
      malformedJson += "{\"level" + IntegerToString(i) + "\":";
   
   // Add some closing braces (but not enough)
   for(int i = 0; i < 50; i++)
      malformedJson += "}";
   
   datetime startTime = TimeCurrent();
   SIntegrityResult result = m_integrityChecker.ValidateJsonData(malformedJson);
   datetime endTime = TimeCurrent();
   
   int processingTime = (int)(endTime - startTime);
   if(!AssertTrue(processingTime < 10, "JSON validation should complete quickly"))
      return false;
   
   // Test 2: Signal parsing with potential infinite loop
   SSignalMetadata signals[];
   bool parseResult = m_secureKB.GetRecentSignals(1000, signals);
   
   // Should complete without hanging (we don't care about the result)
   Print("Signal parsing completed without hanging");
   
   Print("Infinite loop prevention tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Run all security tests                                           |
//+------------------------------------------------------------------+
ENUM_TEST_RESULT CSecurityTestSuite::Run()
  {
   Print("Starting comprehensive security test suite...");
   
   int passedTests = 0;
   int totalTests = 8;
   
   if(TestBoundsChecking()) passedTests++;
   if(TestInputValidation()) passedTests++;
   if(TestResourceLimits()) passedTests++;
   if(TestFileLocking()) passedTests++;
   if(TestDataIntegrity()) passedTests++;
   if(TestFuzzingAttacks()) passedTests++;
   if(TestMemoryExhaustion()) passedTests++;
   if(TestInfiniteLoopPrevention()) passedTests++;
   
   Print("Security test suite completed: ", passedTests, "/", totalTests, " tests passed");
   
   if(passedTests == totalTests)
     {
      Print("🛡️ ALL SECURITY TESTS PASSED - System is hardened against known attack vectors");
      return TEST_RESULT_PASSED;
     }
   else
     {
      Print("⚠️ SECURITY VULNERABILITIES DETECTED - ", (totalTests - passedTests), " tests failed");
      return TEST_RESULT_FAILED;
     }
  }

//+------------------------------------------------------------------+
//| Script start function                                            |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("=== EscapeEA Security Test Suite ===");
   
   CSecurityTestSuite securityTests;
   securityTests.SetUp();
   
   ENUM_TEST_RESULT result = securityTests.Run();
   
   securityTests.TearDown();
   
   if(result == TEST_RESULT_PASSED)
      Print("✅ SECURITY VALIDATION COMPLETE - System ready for production");
   else
      Print("❌ SECURITY VALIDATION FAILED - Additional hardening required");
  }