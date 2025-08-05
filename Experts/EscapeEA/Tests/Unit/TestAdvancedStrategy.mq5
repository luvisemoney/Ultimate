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

#include "TestBase.mqh"
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
   MqlRates            m_rates[];         // Test market data (dynamic array)
   CMockLearningEngine *m_learningEngine; // Mock learning engine
   CMockAdvancedRiskManager *m_riskManager; // Mock risk manager
   
   // Test configuration
   enum { TEST_BARS = 100 };    // Number of test bars
   
   // Helper methods
   bool               InitializeTestData();
   void               SetUpMarketData();
   void               TearDownMarketData();
   void               ValidateTradeSignal(ENUM_TRADE_SIGNAL expectedSignal, 
                                        double expectedConfidence);
   ENUM_TEST_RESULT   AssertFailed(string message);
   ENUM_TEST_RESULT   AssertPassed(string message);
   
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
                        {
                           delete m_strategy;
                           m_strategy = NULL;
                        }
                           
                        if(CheckPointer(m_learningEngine) == POINTER_DYNAMIC)
                        {
                           delete m_learningEngine;
                           m_learningEngine = NULL;
                        }
                           
                        if(CheckPointer(m_riskManager) == POINTER_DYNAMIC)
                        {
                           delete m_riskManager;
                           m_riskManager = NULL;
                        }
                        
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
           
        // Reset mock strategy
        if(CheckPointer(m_strategy) == POINTER_DYNAMIC)
           m_strategy.Reset();
     }
     
   virtual void      TearDown()
     {
        // Clean up any resources specific to test cases
        // Note: Don't delete objects here as they are managed by destructor
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
           
        return AssertPassed("Strategy initialization works correctly");
     }
     
   ENUM_TEST_RESULT Test_SignalGeneration()
     {
        if(CheckPointer(m_strategy) != POINTER_DYNAMIC)
           return AssertFailed("Strategy not initialized");
           
        // Test 1: Test buy signal
        m_strategy.SetTestData(1.2100, 1.2000, 1.1900, 70.0, 0.0010, 0.0005, 1.2200, 1.2000, 1.1800, 0.0050);
        double confidence = 0.0;
        ENUM_TRADE_SIGNAL signal = m_strategy.GetSignal(m_rates, 0, confidence);
        
        if(signal != SIGNAL_BUY)
           return AssertFailed("Failed to generate BUY signal");
           
        if(confidence < 0.5)
           return AssertFailed("Confidence too low for BUY signal");
           
        // Test 2: Test sell signal
        m_strategy.SetTestData(1.1900, 1.2000, 1.2100, 30.0, -0.0010, -0.0005, 1.2200, 1.2000, 1.1800, 0.0050);
        signal = m_strategy.GetSignal(m_rates, 0, confidence);
        
        if(signal != SIGNAL_SELL)
           return AssertFailed("Failed to generate SELL signal");
           
        if(confidence > -0.5)
           return AssertFailed("Confidence too high for SELL signal");
           
        // Test 3: Test hold signal (neutral conditions)
        m_strategy.SetTestData(1.2000, 1.2000, 1.2000, 50.0, 0.0001, 0.0001, 1.2100, 1.2000, 1.1900, 0.0050);
        signal = m_strategy.GetSignal(m_rates, 0, confidence);
        
        if(signal != SIGNAL_HOLD)
           return AssertFailed("Failed to generate HOLD signal");
           
        return AssertPassed("Signal generation works correctly");
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
        if(ArraySize(m_rates) > 0) {
           m_rates[0].close = m_rates[0].low - 0.0100; // Price drops below stop
           if(!m_strategy.ShouldExitLong(m_rates, 0, confidence))
              return AssertFailed("Should exit long position when stop hit");
        } else {
           return AssertFailed("m_rates array is empty");
        }
           
        return TEST_PASSED;
     }
     
   ENUM_TEST_RESULT Test_ShouldEnterLong()
     {
        if(CheckPointer(m_strategy) != POINTER_DYNAMIC)
           return AssertFailed("Strategy not initialized");
           
        if(ArraySize(m_rates) < 2)
           return AssertFailed("Insufficient market data for testing");
           
        double confidence = 0.0;
        
        // Test 1: Should not enter long by default (no signals set)
        if(m_strategy.ShouldEnterLong(m_rates, 1, confidence))
           return AssertFailed("Should not enter long by default");
           
        // Set up test data for valid long entry
        m_strategy.SetTestData(1.2100, 1.2000, 1.1900, 70.0, 0.0010, 0.0005, 1.2200, 1.2000, 1.1800, 0.0050);
        
        // Test 2: Should enter long with valid conditions
        if(!m_strategy.ShouldEnterLong(m_rates, 1, confidence))
           return AssertFailed("Should enter long with valid conditions");
           
        if(confidence < 0.7 || confidence > 0.9)
           return AssertFailed(StringFormat("Confidence should be between 0.7-0.9, got: %f", confidence));
           
        // Test 3: Should not enter when RSI is overbought (>70)
        m_strategy.SetTestData(1.2100, 1.2000, 1.1900, 80.0, 0.0010, 0.0005, 1.2200, 1.2000, 1.1800, 0.0050);
        if(m_strategy.ShouldEnterLong(m_rates, 1, confidence))
           return AssertFailed("Should not enter long when RSI is overbought");
           
        // Test 4: Should not enter when price is too close to resistance
        m_strategy.SetTestData(1.2190, 1.2000, 1.1900, 70.0, 0.0010, 0.0005, 1.2200, 1.2000, 1.1800, 0.0050);
        if(m_strategy.ShouldEnterLong(m_rates, 1, confidence))
           return AssertFailed("Should not enter long too close to resistance");
           
        // Test 5: Error handling - force error state
        m_strategy.ForceError(true, "Test error");
        if(m_strategy.ShouldEnterLong(m_rates, 1, confidence))
           return AssertFailed("Should not enter long when in error state");
        m_strategy.ForceError(false, ""); // Reset error state
           
        // Test 6: Invalid index (should handle gracefully)
        if(m_strategy.ShouldEnterLong(m_rates, -1, confidence) || 
           m_strategy.ShouldEnterLong(m_rates, ArraySize(m_rates), confidence))
           return AssertFailed("Should handle invalid index gracefully");
           
        return TEST_PASSED;
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
        if(CheckPointer(m_strategy) != POINTER_DYNAMIC)
           return AssertFailed("Strategy not initialized");
           
        if(ArraySize(m_rates) < 2)
           return AssertFailed("Insufficient market data for testing");
           
        double confidence = 0.0;
        
        // Test 1: Should not exit long by default (no position)
        if(m_strategy.ShouldExitLong(m_rates, 1, confidence))
           return AssertFailed("Should not exit long by default (no position)");
           
        // Set up test data for a long position
        m_strategy.SetTestData(1.2100, 1.2000, 1.1900, 70.0, 0.0010, 0.0005, 1.2200, 1.2000, 1.1800, 0.0050);
        m_strategy.SetPositionInfo(1.2000, 1.1800, 1.2200, 0.1, ORDER_TYPE_BUY);
        
        // Test 2: Should not exit when conditions are good
        if(m_strategy.ShouldExitLong(m_rates, 1, confidence))
           return AssertFailed("Should not exit long when conditions are good");
           
        // Test 3: Should exit when stop loss is hit
        m_rates[1].close = 1.1790; // Below stop loss
        if(!m_strategy.ShouldExitLong(m_rates, 1, confidence))
           return AssertFailed("Should exit long when stop loss is hit");
        m_rates[1].close = 1.2100; // Reset
           
        // Test 4: Should exit when take profit is hit
        m_strategy.SetTestData(1.2210, 1.2000, 1.1900, 70.0, 0.0010, 0.0005, 1.2200, 1.2000, 1.1800, 0.0050);
        if(!m_strategy.ShouldExitLong(m_rates, 1, confidence))
           return AssertFailed("Should exit long when take profit is hit");
           
        // Test 5: Should exit when exit signal is received
        m_strategy.SetTradeSignals(false, false, true, false);
        if(!m_strategy.ShouldExitLong(m_rates, 1, confidence))
           return AssertFailed("Should exit long when exit signal is received");
        m_strategy.SetTradeSignals(false, false, false, false); // Reset
           
        // Test 6: Error handling - force error state
        m_strategy.ForceError(true, "Test error");
        if(m_strategy.ShouldExitLong(m_rates, 1, confidence))
           return AssertFailed("Should not exit long when in error state");
        m_strategy.ForceError(false, ""); // Reset error state
           
        // Test 7: Invalid index (should handle gracefully)
        if(m_strategy.ShouldExitLong(m_rates, -1, confidence) || 
           m_strategy.ShouldExitLong(m_rates, ArraySize(m_rates), confidence))
           return AssertFailed("Should handle invalid index gracefully");
           
        return TEST_PASSED;
     }
     
   ENUM_TEST_RESULT Test_ShouldExitShort()
     {
        if(CheckPointer(m_strategy) != POINTER_DYNAMIC)
           return AssertFailed("Strategy not initialized");
           
        if(ArraySize(m_rates) < 2)
           return AssertFailed("Insufficient market data for testing");
           
        double confidence = 0.0;
        
        // Test 1: Should not exit short by default (no position)
        if(m_strategy.ShouldExitShort(m_rates, 1, confidence))
           return AssertFailed("Should not exit short by default (no position)");
           
        // Set up test data for a short position
        m_strategy.SetTestData(1.1900, 1.2000, 1.2100, 30.0, -0.0010, -0.0005, 1.2200, 1.2000, 1.1800, 0.0050);
        m_strategy.SetPositionInfo(1.2000, 1.2200, 1.1800, 0.1, ORDER_TYPE_SELL);
        
        // Test 2: Should not exit when conditions are good
        if(m_strategy.ShouldExitShort(m_rates, 1, confidence))
           return AssertFailed("Should not exit short when conditions are good");
           
        // Test 3: Should exit when stop loss is hit (price moves above stop)
        m_rates[1].close = 1.2210; // Above stop loss
        if(!m_strategy.ShouldExitShort(m_rates, 1, confidence))
           return AssertFailed("Should exit short when stop loss is hit");
        m_rates[1].close = 1.1900; // Reset
           
        // Test 4: Should exit when take profit is hit
        m_strategy.SetTestData(1.1790, 1.2000, 1.2100, 30.0, -0.0010, -0.0005, 1.2200, 1.2000, 1.1800, 0.0050);
        if(!m_strategy.ShouldExitShort(m_rates, 1, confidence))
           return AssertFailed("Should exit short when take profit is hit");
           
        // Test 5: Should exit when exit signal is received
        m_strategy.SetTradeSignals(false, false, false, true);
        if(!m_strategy.ShouldExitShort(m_rates, 1, confidence))
           return AssertFailed("Should exit short when exit signal is received");
        m_strategy.SetTradeSignals(false, false, false, false); // Reset
           
        // Test 6: Error handling - force error state
        m_strategy.ForceError(true, "Test error");
        if(m_strategy.ShouldExitShort(m_rates, 1, confidence))
           return AssertFailed("Should not exit short when in error state");
        m_strategy.ForceError(false, ""); // Reset error state
           
        // Test 7: Invalid index (should handle gracefully)
        if(m_strategy.ShouldExitShort(m_rates, -1, confidence) || 
           m_strategy.ShouldExitShort(m_rates, ArraySize(m_rates), confidence))
           return AssertFailed("Should handle invalid index gracefully");
           
        return TEST_PASSED;
     }
     
   //+------------------------------------------------------------------+
   //| Test indicator values functionality                            |
   //+------------------------------------------------------------------+
   ENUM_TEST_RESULT Test_IndicatorValues()
     {
        // Test 1: Input validation
        if(CheckPointer(m_strategy) != POINTER_DYNAMIC)
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
        
        // Test 2: Verify normal operation
        bool result = m_strategy.SetIndicators(
           expectedMaFast, expectedMaMedium, expectedMaSlow,
           expectedRsi, expectedMacdMain, expectedMacdSignal,
           expectedBollingerUpper, expectedBollingerMiddle, expectedBollingerLower,
           expectedAtr
        );
        
        if(!result)
           return AssertFailed("Failed to set indicator values");
           
        // Verify indicator values were set correctly
        if(!AssertEqual(expectedMaFast, m_strategy.GetMaFast(), 0.0001, "MA Fast value mismatch") ||
           !AssertEqual(expectedMaMedium, m_strategy.GetMaMedium(), 0.0001, "MA Medium value mismatch") ||
           !AssertEqual(expectedMaSlow, m_strategy.GetMaSlow(), 0.0001, "MA Slow value mismatch") ||
           !AssertEqual(expectedRsi, m_strategy.GetRsi(), 0.1, "RSI value mismatch") ||
           !AssertEqual(expectedMacdMain, m_strategy.GetMacdMain(), 0.0001, "MACD Main value mismatch") ||
           !AssertEqual(expectedMacdSignal, m_strategy.GetMacdSignal(), 0.0001, "MACD Signal value mismatch") ||
           !AssertEqual(expectedBollingerUpper, m_strategy.GetBollingerUpper(), 0.0001, "Bollinger Upper value mismatch") ||
           !AssertEqual(expectedBollingerMiddle, m_strategy.GetBollingerMiddle(), 0.0001, "Bollinger Middle value mismatch") ||
           !AssertEqual(expectedBollingerLower, m_strategy.GetBollingerLower(), 0.0001, "Bollinger Lower value mismatch") ||
           !AssertEqual(expectedAtr, m_strategy.GetAtr(), 0.0001, "ATR value mismatch"))
        {
           return TEST_FAILED;
        }
           
        // Test 3: Verify error handling for invalid inputs
        m_strategy.ForceError(true, "Test error");
        result = m_strategy.SetIndicators(
           expectedMaFast, expectedMaMedium, expectedMaSlow,
           expectedRsi, expectedMacdMain, expectedMacdSignal,
           expectedBollingerUpper, expectedBollingerMiddle, expectedBollingerLower,
           expectedAtr
        );
        
        if(result)
           return AssertFailed("Should not set indicators when in error state");
           
        m_strategy.ForceError(false, ""); // Reset error state
        
        // Test 4: Verify boundary conditions
        // Test with RSI at upper boundary
        result = m_strategy.SetIndicators(
           expectedMaFast, expectedMaMedium, expectedMaSlow,
           100.0, // RSI at 100 (upper boundary)
           expectedMacdMain, expectedMacdSignal,
           expectedBollingerUpper, expectedBollingerMiddle, expectedBollingerLower,
           expectedAtr
        );
        
        if(!result || !AssertEqual(100.0, m_strategy.GetRsi(), 0.1, "RSI at upper boundary failed"))
           return AssertFailed("Failed to handle RSI at upper boundary");
           
        // Test with ATR at minimum valid value (must be > 0)
        result = m_strategy.SetIndicators(
           expectedMaFast, expectedMaMedium, expectedMaSlow,
           expectedRsi, expectedMacdMain, expectedMacdSignal,
           expectedBollingerUpper, expectedBollingerMiddle, expectedBollingerLower,
           0.0001  // Minimum valid ATR
        );
        
        if(!result || m_strategy.GetAtr() <= 0)
           return AssertFailed("Failed to handle minimum ATR value");
           
        // Test 5: Verify Bollinger Bands validation
        // Upper band should be >= middle band >= lower band
        result = m_strategy.SetIndicators(
           expectedMaFast, expectedMaMedium, expectedMaSlow,
           expectedRsi, expectedMacdMain, expectedMacdSignal,
           1.2000, 1.2000, 1.2000, // All bands equal (valid case)
           expectedAtr
        );
        
        if(!result)
           return AssertFailed("Failed to handle equal Bollinger Bands");
           
        // Invalid case: upper < middle or middle < lower
        result = m_strategy.SetIndicators(
           expectedMaFast, expectedMaMedium, expectedMaSlow,
           expectedRsi, expectedMacdMain, expectedMacdSignal,
           1.1900, 1.2000, 1.2100, // Invalid order: upper < middle < lower
           expectedAtr
        );
        
        if(result)
           return AssertFailed("Should not accept invalid Bollinger Bands order");
           
        // Reset error state
        m_strategy.ForceError(false);
        
        return AssertPassed("Indicator values functionality verified");
     }
     
   // Main test runner
   virtual ENUM_TEST_RESULT Run()
     {
        ENUM_TEST_RESULT result = TEST_PASSED;
        
        // Run all test methods with proper setup/teardown
        SetUp();
        result = (ENUM_TEST_RESULT)MathMax((int)result, (int)Test_Initialization());
        TearDown();
        
        SetUp();
        result = (ENUM_TEST_RESULT)MathMax((int)result, (int)Test_SignalGeneration());
        TearDown();
        
        SetUp();
        result = (ENUM_TEST_RESULT)MathMax((int)result, (int)Test_PositionManagement());
        TearDown();
        
        SetUp();
        result = (ENUM_TEST_RESULT)MathMax((int)result, (int)Test_ShouldEnterLong());
        TearDown();
        
        SetUp();
        result = (ENUM_TEST_RESULT)MathMax((int)result, (int)Test_ShouldEnterShort());
        TearDown();
        
        SetUp();
        result = (ENUM_TEST_RESULT)MathMax((int)result, (int)Test_ShouldExitLong());
        TearDown();
        
        SetUp();
        result = (ENUM_TEST_RESULT)MathMax((int)result, (int)Test_ShouldExitShort());
        TearDown();
        
        SetUp();
        result = (ENUM_TEST_RESULT)MathMax((int)result, (int)Test_IndicatorValues());
        TearDown();
        
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
   
   // Fill with realistic sample data
   datetime currentTime = TimeCurrent();
   double basePrice = 1.2000;
   double priceStep = 0.0005;
   
   for(int i = 0; i < TEST_BARS; i++)
     {
        // Set timestamp (most recent first)
        m_rates[i].time = currentTime - (TEST_BARS - 1 - i) * PeriodSeconds(PERIOD_H1);
        
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

//+------------------------------------------------------------------+
//| Set up market data for testing                                   |
//+------------------------------------------------------------------+
void CTestAdvancedStrategy::SetUpMarketData()
  {
   // Reset market data to default state
   InitializeTestData();
  }

//+------------------------------------------------------------------+
//| Clean up market data after testing                               |
//+------------------------------------------------------------------+
void CTestAdvancedStrategy::TearDownMarketData()
  {
   // No specific cleanup needed for static array
  }

//+------------------------------------------------------------------+
//| Validate trade signal against expected values                    |
//+------------------------------------------------------------------+
void CTestAdvancedStrategy::ValidateTradeSignal(ENUM_TRADE_SIGNAL expectedSignal, 
                                               double expectedConfidence)
  {
   // This method can be used for additional signal validation
   // Implementation depends on specific requirements
  }

//+------------------------------------------------------------------+
//| Helper method to return failed test result with message          |
//+------------------------------------------------------------------+
ENUM_TEST_RESULT CTestAdvancedStrategy::AssertFailed(string message)
  {
   if(m_verbose)
      Print("Test Failed: ", message);
   return TEST_FAILED;
  }

//+------------------------------------------------------------------+
//| Helper method to return passed test result with message          |
//+------------------------------------------------------------------+
ENUM_TEST_RESULT CTestAdvancedStrategy::AssertPassed(string message)
  {
   if(m_verbose)
      Print("Test Passed: ", message);
   return TEST_PASSED;
  }

//+------------------------------------------------------------------+
//| Main function to run the test                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   CTestAdvancedStrategy *test = new CTestAdvancedStrategy();
   
   if(CheckPointer(test) == POINTER_DYNAMIC)
     {
      ENUM_TEST_RESULT result = test.Run();
      
      string resultStr = (result == TEST_PASSED) ? "PASSED" : 
                        (result == TEST_FAILED) ? "FAILED" : "SKIPPED";
      
      Print("=== Test Results ===");
      Print("Test Suite: ", test.Name());
      Print("Result: ", resultStr);
      Print("===================");
      
      delete test;
     }
   else
     {
      Print("Error: Failed to create test instance");
     }
  }
//+------------------------------------------------------------------+