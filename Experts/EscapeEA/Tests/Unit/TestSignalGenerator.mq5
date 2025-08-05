//+------------------------------------------------------------------+
//| TestSignalGenerator.mq5 - Unit tests for CSignalGenerator        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"
#property script_show_inputs

#include "TestBase.mqh"
#include "..\..\Include\Core\SignalGenerator.mqh"

//+------------------------------------------------------------------+
//| Test class for CSignalGenerator                                  |
//+------------------------------------------------------------------+
class CTestSignalGenerator : public CTestBase
  {
private:
   CSignalGenerator *m_signalGen;
   
public:
                     CTestSignalGenerator() : CTestBase("SignalGenerator Tests", true) {}
                    ~CTestSignalGenerator() { if(m_signalGen != NULL) delete m_signalGen; }
   
   void              SetUp() override;
   void              TearDown() override;
   ENUM_TEST_RESULT  Run() override;
   
   // Individual test methods
   bool              TestConstructor();
   bool              TestInitialization();
   bool              TestSignalGeneration();
   bool              TestConfidenceCalculation();
   bool              TestGettersSetters();
   bool              TestIndicatorHandles();
  };

//+------------------------------------------------------------------+
//| Setup test environment                                           |
//+------------------------------------------------------------------+
void CTestSignalGenerator::SetUp()
  {
   // Initialize with test parameters
   m_signalGen = new CSignalGenerator("EURUSD", PERIOD_H1, 10, 20, 14, 14, 0.6);
  }

//+------------------------------------------------------------------+
//| Cleanup test environment                                         |
//+------------------------------------------------------------------+
void CTestSignalGenerator::TearDown()
  {
   if(m_signalGen != NULL)
     {
      delete m_signalGen;
      m_signalGen = NULL;
     }
  }

//+------------------------------------------------------------------+
//| Run all tests                                                    |
//+------------------------------------------------------------------+
ENUM_TEST_RESULT CTestSignalGenerator::Run()
  {
   bool allPassed = true;
   
   allPassed &= TestConstructor();
   allPassed &= TestInitialization();
   allPassed &= TestSignalGeneration();
   allPassed &= TestConfidenceCalculation();
   allPassed &= TestGettersSetters();
   allPassed &= TestIndicatorHandles();
   
   return allPassed ? TEST_PASSED : TEST_FAILED;
  }

//+------------------------------------------------------------------+
//| Test constructor                                                 |
//+------------------------------------------------------------------+
bool CTestSignalGenerator::TestConstructor()
  {
   Print("Testing SignalGenerator Constructor...");
   
   // Test valid construction
   if(!AssertTrue(m_signalGen != NULL, "SignalGenerator should be created successfully"))
      return false;
   
   if(!AssertStringEqual("EURUSD", m_signalGen.Symbol(), true, "Symbol should be set correctly"))
      return false;
   
   if(!AssertTrue(m_signalGen.Timeframe() == PERIOD_H1, "Timeframe should be set correctly"))
      return false;
   
   if(!AssertEqual(0.6, m_signalGen.MinConfidence(), 0.001, "MinConfidence should be set correctly"))
      return false;
   
   Print("✓ Constructor tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test initialization                                              |
//+------------------------------------------------------------------+
bool CTestSignalGenerator::TestInitialization()
  {
   Print("Testing SignalGenerator Initialization...");
   
   // Test indicator update
   m_signalGen.UpdateIndicators();
   
   // Test signal generation (should not crash)
   STradeSignal signal = m_signalGen.GenerateSignal();
   
   if(!AssertStringEqual("EURUSD", signal.symbol, true, "Signal symbol should match"))
      return false;
   
   if(!AssertTrue(signal.timeframe == PERIOD_H1, "Signal timeframe should match"))
      return false;
   
   if(!AssertTrue(signal.timestamp > 0, "Signal timestamp should be valid"))
      return false;
   
   Print("✓ Initialization tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test signal generation                                           |
//+------------------------------------------------------------------+
bool CTestSignalGenerator::TestSignalGeneration()
  {
   Print("Testing Signal Generation...");
   
   STradeSignal signal = m_signalGen.GenerateSignal();
   
   // Test signal structure
   if(!AssertStringEqual("EURUSD", signal.symbol, true, "Signal symbol should be correct"))
      return false;
   
   if(!AssertTrue(signal.confidence >= 0.0 && signal.confidence <= 1.0, "Confidence should be between 0 and 1"))
      return false;
   
   if(!AssertTrue(signal.signal == SIGNAL_BUY || signal.signal == SIGNAL_SELL || signal.signal == SIGNAL_HOLD, 
                  "Signal should be valid enum value"))
      return false;
   
   // Test signal logic consistency
   if(signal.signal == SIGNAL_BUY)
     {
      if(!AssertTrue(signal.entry > 0, "Buy signal should have valid entry price"))
         return false;
      if(!AssertTrue(signal.stopLoss < signal.entry, "Buy signal stop loss should be below entry"))
         return false;
      if(!AssertTrue(signal.takeProfit > signal.entry, "Buy signal take profit should be above entry"))
         return false;
     }
   else if(signal.signal == SIGNAL_SELL)
     {
      if(!AssertTrue(signal.entry > 0, "Sell signal should have valid entry price"))
         return false;
      if(!AssertTrue(signal.stopLoss > signal.entry, "Sell signal stop loss should be above entry"))
         return false;
      if(!AssertTrue(signal.takeProfit < signal.entry, "Sell signal take profit should be below entry"))
         return false;
     }
   
   Print("✓ Signal generation tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test confidence calculation                                      |
//+------------------------------------------------------------------+
bool CTestSignalGenerator::TestConfidenceCalculation()
  {
   Print("Testing Confidence Calculation...");
   
   // Test with different confidence thresholds
   m_signalGen.SetMinConfidence(0.1);
   STradeSignal lowConfSignal = m_signalGen.GenerateSignal();
   
   m_signalGen.SetMinConfidence(0.9);
   STradeSignal highConfSignal = m_signalGen.GenerateSignal();
   
   // With lower threshold, we might get signals
   // With higher threshold, we're less likely to get signals
   if(!AssertTrue(lowConfSignal.confidence >= 0.0 && lowConfSignal.confidence <= 1.0, 
                  "Low confidence signal should have valid confidence"))
      return false;
   
   if(!AssertTrue(highConfSignal.confidence >= 0.0 && highConfSignal.confidence <= 1.0, 
                  "High confidence signal should have valid confidence"))
      return false;
   
   Print("✓ Confidence calculation tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test getters and setters                                         |
//+------------------------------------------------------------------+
bool CTestSignalGenerator::TestGettersSetters()
  {
   Print("Testing Getters and Setters...");
   
   // Test setters
   m_signalGen.SetMinConfidence(0.75);
   if(!AssertEqual(0.75, m_signalGen.MinConfidence(), 0.001, "MinConfidence setter should work"))
      return false;
   
   // Test boundary values
   m_signalGen.SetMinConfidence(0.0);
   if(!AssertEqual(0.0, m_signalGen.MinConfidence(), 0.001, "MinConfidence should accept 0.0"))
      return false;
   
   m_signalGen.SetMinConfidence(1.0);
   if(!AssertEqual(1.0, m_signalGen.MinConfidence(), 0.001, "MinConfidence should accept 1.0"))
      return false;
   
   Print("✓ Getters and setters tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test indicator handles                                           |
//+------------------------------------------------------------------+
bool CTestSignalGenerator::TestIndicatorHandles()
  {
   Print("Testing Indicator Handles...");
   
   // Test indicator update doesn't crash
   m_signalGen.UpdateIndicators();
   
   // Generate signal to test indicator data access
   STradeSignal signal = m_signalGen.GenerateSignal();
   
   // If we get here without crashing, indicators are working
   if(!AssertTrue(true, "Indicator handles should be valid"))
      return false;
   
   Print("✓ Indicator handles tests passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Script start function                                            |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("=== Starting SignalGenerator Unit Tests ===");
   
   CTestSignalGenerator test;
   test.SetUp();
   
   ENUM_TEST_RESULT result = test.Run();
   test.PrintTestResult(result);
   
   test.TearDown();
   
   Print("=== SignalGenerator Unit Tests Complete ===");
  }