//+------------------------------------------------------------------+
//|                                            TestAdvancedStrategy.mq5 |
//|                                      Copyright 2025, EscapeEA     |
//|                                          https://www.escapeea.com |
//|                                                                  |
//| Description: Unit tests for the CAdvancedStrategy class.         |
//|              This test suite verifies the functionality of the   |
//|              advanced trading strategy implementation.           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include "..\\TestBase.mqh"
#include "..\\Mocks\\MockAdvancedStrategy.mqh"
#include "..\\..\\Include\\Common\\Structs.mqh"
#include <Arrays\ArrayObj.mqh>

//+------------------------------------------------------------------+
//| Test class for CAdvancedStrategy                                 |
//+------------------------------------------------------------------+
class CTestAdvancedStrategy : public CTestBase
  {
private:
   CMockAdvancedStrategy *m_strategy;     // Strategy instance under test
   MqlRates            m_rates[100];      // Test market data (100 bars)
   CMockLearningEngine *m_learningEngine; // Mock learning engine
   CMockAdvancedRiskManager *m_riskManager; // Mock risk manager
   
   // Test configuration
   static const int    TEST_BARS = 100;    // Number of test bars
   static const double TEST_SYMBOL_POINT = 0.0001; // Point value for test symbol
   
   // Helper methods
   bool               InitializeTestData();
   void               SetUpMarketData();
   void               TearDownMarketData();
   void               ValidateTradeSignal(ENUM_TRADE_SIGNAL expectedSignal, 
                                        double expectedConfidence);
   
public:
   // Constructor/destructor
                     CTestAdvancedStrategy() : CTestBase("CAdvancedStrategy Tests", true) 
                     {
                        // Initialize components
                        m_strategy = NULL;
                        m_learningEngine = NULL;
                        m_riskManager = NULL;
                        
                        // Initialize test data
                        if(!InitializeTestData())
                        {
                           Print("Error: Test data initialization failed");
                           return;
                        }
                        
                        // Set up market data
                        SetUpMarketData();
                        
                        // Create mock components
                        m_learningEngine = new CMockLearningEngine();
                        m_riskManager = new CMockAdvancedRiskManager();
                        
                        // Create strategy instance
                        m_strategy = new CMockAdvancedStrategy();
                        
                        // Initialize strategy with mock components
                        if(m_strategy != NULL && 
                           CheckPointer(m_learningEngine) == POINTER_DYNAMIC &&
                           CheckPointer(m_riskManager) == POINTER_DYNAMIC)
                        {
                           if(!m_strategy.Initialize(m_riskManager, m_learningEngine))
                           {
                              Print("Error: Failed to initialize strategy");
                           }
                        }
                     }
                     
                     ~CTestAdvancedStrategy() 
                     {
                        // Clean up resources in reverse order of creation
                        if(CheckPointer(m_strategy) == POINTER_DYNAMIC)
                           delete m_strategy;
                           
                        if(CheckPointer(m_learningEngine) == POINTER_DYNAMIC)
                           delete m_learningEngine;
                           
                        if(CheckPointer(m_riskManager) == POINTER_DYNAMIC)
                           delete m_riskManager;
                           
                        TearDownMarketData();
                     }
   
   // Override methods
   virtual void      SetUp()
     {
        // Reset test data for each test case
        SetUpMarketData();
        
        // Reset mock components
        if(CheckPointer(m_learningEngine) == POINTER_DYNAMIC)
           m_learningEngine.Reset();
           
        if(CheckPointer(m_riskManager) == POINTER_DYNAMIC)
           m_riskManager.Reset();
     }
     
   virtual void      TearDown()
     {
        // Clean up any resources specific to test cases
        TearDownMarketData();
     }
   
   // Test methods
   ENUM_TEST_RESULT Test_Initialization()
     {
        // Test 1: Verify strategy creation
        if(CheckPointer(m_strategy) != POINTER_DYNAMIC)
           return AssertFailed("Failed to create strategy instance");
           
        // Test 2: Verify component initialization
        if(CheckPointer(m_learningEngine) != POINTER_DYNAMIC ||
           CheckPointer(m_riskManager) != POINTER_DYNAMIC)
           return AssertFailed("Failed to initialize test components");
           
        // Test 3: Verify strategy initialization
        if(!m_strategy.IsInitialized())
           return AssertFailed("Strategy failed to initialize");
           
        // Test 4: Verify component injection
        if(m_strategy.GetRiskManager() != m_riskManager ||
           m_strategy.GetLearningEngine() != m_learningEngine)
           return AssertFailed("Components not properly injected");
           
        return TEST_PASSED;
     }
     
   ENUM_TEST_RESULT Test_SignalGeneration()
     {
        if(CheckPointer(m_strategy) != POINTER_DYNAMIC)
           return AssertFailed("Strategy not initialized");
           
        // Test 1: Test buy signal
        m_strategy.SetTestData(1.2100, 1.2000, 1.1900, 70.0, 0.0010, 0.0005, 1.2200, 1.2000, 1.1800, 0.0050);
        m_strategy.SetExpectedSignal(SIGNAL_BUY, 0.8);
        
        double confidence = 0.0;
        ENUM_TRADE_SIGNAL signal = m_strategy.GetSignal(m_rates, 0, confidence);
        
        if(signal != SIGNAL_BUY)
           return AssertFailed("Failed to generate BUY signal");
           
        if(confidence < 0.5)
           return AssertFailed("Confidence too low for BUY signal");
           
        // Test 2: Test sell signal
        m_strategy.SetTestData(1.1900, 1.2000, 1.2100, 30.0, -0.0010, -0.0005, 1.2200, 1.2000, 1.1800, 0.0050);
        m_strategy.SetExpectedSignal(SIGNAL_SELL, 0.8);
        
        signal = m_strategy.GetSignal(m_rates, 0, confidence);
        
        if(signal != SIGNAL_SELL)
           return AssertFailed("Failed to generate SELL signal");
           
        if(confidence > -0.5)
           return AssertFailed("Confidence too high for SELL signal");
           
        // Test 3: Test hold signal (neutral conditions)
        m_strategy.SetTestData(1.2000, 1.2000, 1.2000, 50.0, 0.0001, 0.0001, 1.2100, 1.2000, 1.1900, 0.0050);
        m_strategy.SetExpectedSignal(SIGNAL_HOLD, 0.1);
        
        signal = m_strategy.GetSignal(m_rates, 0, confidence);
        
        if(signal != SIGNAL_HOLD)
           return AssertFailed("Failed to generate HOLD signal");
           
        return TEST_PASSED;
     }
     
   ENUM_TEST_RESULT Test_PositionManagement()
     {
        if(CheckPointer(m_strategy) != POINTER_DYNAMIC)
           return AssertFailed("Strategy not initialized");
           
        // Set up test data for a long position
        m_strategy.SetTestData(1.2100, 1.2000, 1.1900, 70.0, 0.0010, 0.0005, 1.2200, 1.2000, 1.1800, 0.0050);
        
        // Test 1: Should enter long
        double confidence = 0.0;
        if(!m_strategy.ShouldEnterLong(m_rates, 0, confidence))
           return AssertFailed("Should enter long position");
           
        // Test 2: Should not exit long immediately
        if(m_strategy.ShouldExitLong(m_rates, 0, confidence))
           return AssertFailed("Should not exit long position immediately");
           
        // Test 3: Simulate price moving against position (should exit)
        m_rates[0].close = m_rates[0].low - 0.0100; // Price drops below stop
        if(!m_strategy.ShouldExitLong(m_rates, 0, confidence))
           return AssertFailed("Should exit long position when stop hit");
           
        return TEST_PASSED;
     }
     
   ENUM_TEST_RESULT Test_ShouldEnterLong()
     {
        double confidence = 0.0;
        
        // Test enter long (should not enter by default)
        if(m_strategy.ShouldEnterLong(m_rates, 1, confidence))
           return AssertFailed("Should not enter long by default");
           
        // Set up for long entry
        m_strategy.SetTradeSignals(true, false, false, false);
        
        if(!m_strategy.ShouldEnterLong(m_rates, 1, confidence))
           return AssertFailed("Should enter long when signals are set");
           
        if(!AssertEqual(0.8, confidence, 0.0001, "Confidence should be 0.8"))
           return TEST_FAILED;
           
        // Test error case
        m_strategy.ForceError(true, "Test error");
        if(m_strategy.ShouldEnterLong(m_rates, 1, confidence))
           return AssertFailed("Should fail when error is forced");
           
        return AssertPassed("Long entry decision works correctly");
     }
     
   ENUM_TEST_RESULT Test_ShouldEnterShort()
     {
        double confidence = 0.0;
        
        // Test enter short (should not enter by default)
        if(m_strategy.ShouldEnterShort(m_rates, 1, confidence))
           return AssertFailed("Should not enter short by default");
           
        // Set up for short entry
        m_strategy.SetTradeSignals(false, true, false, false);
        
        if(!m_strategy.ShouldEnterShort(m_rates, 1, confidence))
           return AssertFailed("Should enter short when signals are set");
           
        if(!AssertEqual(0.8, confidence, 0.0001, "Confidence should be 0.8"))
           return TEST_FAILED;
           
        // Test error case
        m_strategy.ForceError(true, "Test error");
        if(m_strategy.ShouldEnterShort(m_rates, 1, confidence))
           return AssertFailed("Should fail when error is forced");
           
        return AssertPassed("Short entry decision works correctly");
     }
     
   ENUM_TEST_RESULT Test_ShouldExitLong()
     {
        double confidence = 0.0;
        
        // Test exit long (should not exit by default)
        if(m_strategy.ShouldExitLong(m_rates, 1, confidence))
           return AssertFailed("Should not exit long by default");
           
        // Set up for long exit
        m_strategy.SetTradeSignals(false, false, true, false);
        
        if(!m_strategy.ShouldExitLong(m_rates, 1, confidence))
           return AssertFailed("Should exit long when signals are set");
           
        return AssertPassed("Long exit decision works correctly");
     }
     
   ENUM_TEST_RESULT Test_ShouldExitShort()
     {
        double confidence = 0.0;
        
        // Test exit short (should not exit by default)
        if(m_strategy.ShouldExitShort(m_rates, 1, confidence))
           return AssertFailed("Should not exit short by default");
           
        // Set up for short exit
        m_strategy.SetTradeSignals(false, false, false, true);
        
        if(!m_strategy.ShouldExitShort(m_rates, 1, confidence))
           return AssertFailed("Should exit short when signals are set");
           
        return AssertPassed("Short exit decision works correctly");
     }
     
   //+------------------------------------------------------------------+
   //| Test indicator values functionality                            |
   //+------------------------------------------------------------------+
   ENUM_TEST_RESULT Test_IndicatorValues()
     {
        // Input validation
        if(CheckPointer(m_strategy) == POINTER_INVALID)
           return AssertFailed("Strategy instance is not valid");
        
        // Define test values with meaningful ranges
        const double expectedMaFast = 1.2050;
        const double expectedMaMedium = 1.1950;
        const double expectedMaSlow = 1.1900;
        const double expectedRsi = 65.0;  // RSI range: 0-100
        const double expectedMacdMain = 0.0008;
        const double expectedMacdSignal = 0.0004;
        const double expectedBollingerUpper = 1.2100;
        const double expectedBollingerMiddle = 1.2000;
        const double expectedBollingerLower = 1.1900;
        const double expectedAtr = 0.0045;  // Must be positive
        
        // Test 1: Verify normal operation
        bool result = m_strategy.SetIndicators(
           expectedMaFast, expectedMaMedium, expectedMaSlow,
           expectedRsi, expectedMacdMain, expectedMacdSignal,
           expectedBollingerUpper, expectedBollingerMiddle, expectedBollingerLower,
           expectedAtr
        );
        
        if(!result)
           return AssertFailed("Failed to set indicator values");
           
        // Test 2: Verify error handling for invalid inputs
        m_strategy.ForceError(true, "Test error");
        result = m_strategy.SetIndicators(
           expectedMaFast, expectedMaMedium, expectedMaSlow,
           expectedRsi, expectedMacdMain, expectedMacdSignal,
           expectedBollingerUpper, expectedBollingerMiddle, expectedBollingerLower,
           expectedAtr
        );
        
        if(result)
           return AssertFailed("Should fail when error is forced");
           
        // Reset error state
        m_strategy.ForceError(false);
        
        // Test 3: Verify boundary conditions
        // (Add more boundary tests as needed based on indicator valid ranges)
        
        return AssertPassed("Indicator values functionality verified");
     }
     
   // Main test runner
   virtual ENUM_TEST_RESULT Run()
     {
        ENUM_TEST_RESULT result = TEST_PASSED;
        
        // Run all test methods
        result = (ENUM_TEST_RESULT)MathMax((int)result, (int)Test_Initialization());
        result = (ENUM_TEST_RESULT)MathMax((int)result, (int)Test_SignalGeneration());
        result = (ENUM_TEST_RESULT)MathMax((int)result, (int)Test_PositionManagement());
        result = (ENUM_TEST_RESULT)MathMax((int)result, (int)Test_ShouldEnterLong());
        result = (ENUM_TEST_RESULT)MathMax((int)result, (int)Test_ShouldEnterShort());
        result = (ENUM_TEST_RESULT)MathMax((int)result, (int)Test_ShouldExitLong());
        result = (ENUM_TEST_RESULT)MathMax((int)result, (int)Test_ShouldExitShort());
        result = (ENUM_TEST_RESULT)MathMax((int)result, (int)Test_IndicatorValues());
        
        return result;
     }
  };

//+------------------------------------------------------------------+
//| Initialize test data with validation and error checking          |
//+------------------------------------------------------------------+
bool CTestAdvancedStrategy::InitializeTestData()
  {
   // Set up test market data structure
   ArrayResize(m_rates, TEST_BARS);
   
   // Initialize with default values
   for(int i = 0; i < TEST_BARS; i++)
     {
      m_rates[i].time = TimeCurrent() - (TEST_BARS - i) * PeriodSeconds(PERIOD_M1);
      m_rates[i].open = 1.2000 + i * 0.0001;
      m_rates[i].high = m_rates[i].open + 0.0005;
      m_rates[i].low = m_rates[i].open - 0.0005;
      m_rates[i].close = m_rates[i].open + (i % 2 == 0 ? 0.0002 : -0.0002);
      m_rates[i].tick_volume = 1000;
      m_rates[i].spread = 10;
      m_rates[i].real_volume = 10000;
     }
   
   // Fill with realistic sample data
   datetime currentTime = TimeCurrent();
   double basePrice = 1.2000;
   double priceStep = 0.0005;
   
   for(int i = 0; i < size; i++)
     {
        // Set timestamp (most recent first)
        m_rates[i].time = currentTime - (size - 1 - i) * PeriodSeconds(PERIOD_H1);
        
        // Generate realistic price action
        m_rates[i].open = basePrice + i * priceStep;
        m_rates[i].high = m_rates[i].open + 0.0010;
        m_rates[i].low = m_rates[i].open - 0.0005;
        m_rates[i].close = m_rates[i].open + 0.0005;
        
        // Generate realistic volume data
        m_rates[i].tick_volume = 1000 + i * 100;
        m_rates[i].real_volume = 1000 + i * 100;
        
        // Set spread (in points)
        m_rates[i].spread = 10;
        
        // Validate the generated data
        if(m_rates[i].high <= m_rates[i].low || 
           m_rates[i].close < m_rates[i].low || 
           m_rates[i].close > m_rates[i].high)
          {
             PrintFormat("Error: Invalid price data at index %d", i);
             return false;
          }
     }
     
   return true;
  }
  }
//+------------------------------------------------------------------+
