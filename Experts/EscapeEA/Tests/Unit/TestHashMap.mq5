//+------------------------------------------------------------------+
//| TestHashMap.mq5 - Unit tests for CHashMap                        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"
#property script_show_inputs

#include "TestBase.mqh"
#include "..\..\Include\Common\HashMap.mqh"

//+------------------------------------------------------------------+
//| Test class for CHashMap                                          |
//+------------------------------------------------------------------+
class CTestHashMap : public CTestBase
  {
private:
   CHashMap<int,string> *m_intStringMap;
   CHashMap<double,int> *m_doubleIntMap;
   
public:
                     CTestHashMap() : CTestBase("HashMap Tests", true) {}
                    ~CTestHashMap() 
                       {
                        if(m_intStringMap != NULL) delete m_intStringMap;
                        if(m_doubleIntMap != NULL) delete m_doubleIntMap;
                       }
   
   void              SetUp() override;
   void              TearDown() override;
   ENUM_TEST_RESULT  Run() override;
   
   // Individual test methods
   bool              TestConstructor();
   bool              TestAddAndGet();
   bool              TestContainsKey();
   bool              TestRemove();
   bool              TestClear();
   bool              TestCount();
   bool              TestUpdateExisting();
   bool              TestDifferentTypes();
  };

//+------------------------------------------------------------------+
//| Setup test environment                                           |
//+------------------------------------------------------------------+
void CTestHashMap::SetUp()
  {
   m_intStringMap = new CHashMap<int,string>();
   m_doubleIntMap = new CHashMap<double,int>();
  }

//+------------------------------------------------------------------+
//| Cleanup test environment                                         |
//+------------------------------------------------------------------+
void CTestHashMap::TearDown()
  {
   if(m_intStringMap != NULL)
     {
      delete m_intStringMap;
      m_intStringMap = NULL;
     }
   if(m_doubleIntMap != NULL)
     {
      delete m_doubleIntMap;
      m_doubleIntMap = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Run all tests                                                    |
//+------------------------------------------------------------------+
ENUM_TEST_RESULT CTestHashMap::Run()
  {
   bool allPassed = true;
   
   // Run each test with proper setup/teardown for isolation
   SetUp(); allPassed &= TestConstructor(); TearDown();
   SetUp(); allPassed &= TestAddAndGet(); TearDown();
   SetUp(); allPassed &= TestContainsKey(); TearDown();
   SetUp(); allPassed &= TestRemove(); TearDown();
   SetUp(); allPassed &= TestClear(); TearDown();
   SetUp(); allPassed &= TestCount(); TearDown();
   SetUp(); allPassed &= TestUpdateExisting(); TearDown();
   SetUp(); allPassed &= TestDifferentTypes(); TearDown();
   
   return allPassed ? TEST_PASSED : TEST_FAILED;
  }

//+------------------------------------------------------------------+
//| Test constructor                                                 |
//+------------------------------------------------------------------+
bool CTestHashMap::TestConstructor()
  {
   Print("Testing HashMap Constructor...");
   
   if(!AssertTrue(m_intStringMap != NULL, "IntString HashMap should be created"))
      return false;
   
   if(!AssertTrue(m_doubleIntMap != NULL, "DoubleInt HashMap should be created"))
      return false;
   
   if(!AssertEqual(0, m_intStringMap.Count(), 0.001, "New HashMap should be empty"))
      return false;
   
   Print("✓ Constructor tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test add and get operations                                      |
//+------------------------------------------------------------------+
bool CTestHashMap::TestAddAndGet()
  {
   Print("Testing Add and Get operations...");
   
   // Add some key-value pairs
   m_intStringMap.Add(1, "One");
   m_intStringMap.Add(2, "Two");
   m_intStringMap.Add(3, "Three");
   
   // Test retrieval
   string value;
   if(!AssertTrue(m_intStringMap.TryGetValue(1, value), "Should find key 1"))
      return false;
   
   if(!AssertStringEqual("One", value, true, "Value for key 1 should be 'One'"))
      return false;
   
   if(!AssertTrue(m_intStringMap.TryGetValue(2, value), "Should find key 2"))
      return false;
   
   if(!AssertStringEqual("Two", value, true, "Value for key 2 should be 'Two'"))
      return false;
   
   // Test non-existent key
   if(!AssertFalse(m_intStringMap.TryGetValue(99, value), "Should not find key 99"))
      return false;
   
   Print("✓ Add and Get tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test ContainsKey method                                          |
//+------------------------------------------------------------------+
bool CTestHashMap::TestContainsKey()
  {
   Print("Testing ContainsKey...");
   
   m_intStringMap.Add(10, "Ten");
   m_intStringMap.Add(20, "Twenty");
   
   if(!AssertTrue(m_intStringMap.ContainsKey(10), "Should contain key 10"))
      return false;
   
   if(!AssertTrue(m_intStringMap.ContainsKey(20), "Should contain key 20"))
      return false;
   
   if(!AssertFalse(m_intStringMap.ContainsKey(30), "Should not contain key 30"))
      return false;
   
   Print("✓ ContainsKey tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test Remove method                                               |
//+------------------------------------------------------------------+
bool CTestHashMap::TestRemove()
  {
   Print("Testing Remove...");
   
   m_intStringMap.Add(100, "Hundred");
   m_intStringMap.Add(200, "TwoHundred");
   
   int initialCount = m_intStringMap.Count();
   
   // Remove existing key
   if(!AssertTrue(m_intStringMap.Remove(100), "Should successfully remove key 100"))
      return false;
   
   if(!AssertFalse(m_intStringMap.ContainsKey(100), "Should not contain key 100 after removal"))
      return false;
   
   if(!AssertEqual(initialCount - 1, m_intStringMap.Count(), 0.001, "Count should decrease by 1"))
      return false;
   
   // Try to remove non-existent key
   if(!AssertFalse(m_intStringMap.Remove(999), "Should not remove non-existent key 999"))
      return false;
   
   Print("✓ Remove tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test Clear method                                                |
//+------------------------------------------------------------------+
bool CTestHashMap::TestClear()
  {
   Print("Testing Clear...");
   
   m_intStringMap.Add(1, "One");
   m_intStringMap.Add(2, "Two");
   m_intStringMap.Add(3, "Three");
   
   if(!AssertTrue(m_intStringMap.Count() > 0, "HashMap should have items before clear"))
      return false;
   
   m_intStringMap.Clear();
   
   if(!AssertEqual(0, m_intStringMap.Count(), 0.001, "HashMap should be empty after clear"))
      return false;
   
   if(!AssertFalse(m_intStringMap.ContainsKey(1), "Should not contain any keys after clear"))
      return false;
   
   Print("✓ Clear tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test Count method                                                |
//+------------------------------------------------------------------+
bool CTestHashMap::TestCount()
  {
   Print("Testing Count...");
   
   m_intStringMap.Clear();
   if(!AssertEqual(0, m_intStringMap.Count(), 0.001, "Empty HashMap should have count 0"))
      return false;
   
   m_intStringMap.Add(1, "One");
   if(!AssertEqual(1, m_intStringMap.Count(), 0.001, "HashMap with 1 item should have count 1"))
      return false;
   
   m_intStringMap.Add(2, "Two");
   m_intStringMap.Add(3, "Three");
   if(!AssertEqual(3, m_intStringMap.Count(), 0.001, "HashMap with 3 items should have count 3"))
      return false;
   
   m_intStringMap.Remove(2);
   if(!AssertEqual(2, m_intStringMap.Count(), 0.001, "HashMap should have count 2 after removal"))
      return false;
   
   Print("✓ Count tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test updating existing keys                                      |
//+------------------------------------------------------------------+
bool CTestHashMap::TestUpdateExisting()
  {
   Print("Testing Update Existing...");
   
   // Start with a fresh HashMap (should already be clean from SetUp)
   m_intStringMap.Add(1, "Original");
   
   string value;
   m_intStringMap.TryGetValue(1, value);
   if(!AssertStringEqual("Original", value, true, "Initial value should be 'Original'"))
      return false;
   
   // Update the same key
   m_intStringMap.Add(1, "Updated");
   
   m_intStringMap.TryGetValue(1, value);
   if(!AssertStringEqual("Updated", value, true, "Updated value should be 'Updated'"))
      return false;
   
   // Count should remain the same
   if(!AssertEqual(1, m_intStringMap.Count(), 0.001, "Count should remain 1 after update"))
      return false;
   
   Print("✓ Update existing tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test different data types                                        |
//+------------------------------------------------------------------+
bool CTestHashMap::TestDifferentTypes()
  {
   Print("Testing Different Types...");
   
   // Test double-int map
   m_doubleIntMap.Add(1.5, 15);
   m_doubleIntMap.Add(2.7, 27);
   m_doubleIntMap.Add(3.14, 314);
   
   int intValue;
   if(!AssertTrue(m_doubleIntMap.TryGetValue(1.5, intValue), "Should find key 1.5"))
      return false;
   
   if(!AssertEqual(15, intValue, 0.001, "Value for key 1.5 should be 15"))
      return false;
   
   if(!AssertTrue(m_doubleIntMap.ContainsKey(3.14), "Should contain key 3.14"))
      return false;
   
   if(!AssertEqual(3, m_doubleIntMap.Count(), 0.001, "DoubleInt map should have 3 items"))
      return false;
   
   Print("✓ Different types tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Script start function                                            |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("=== Starting HashMap Unit Tests ===");
   
   CTestHashMap test;
   
   ENUM_TEST_RESULT result = test.Run();
   test.PrintTestResult(result);
   
   Print("=== HashMap Unit Tests Complete ===");
  }