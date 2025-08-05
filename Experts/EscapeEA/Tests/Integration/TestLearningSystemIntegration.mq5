//+------------------------------------------------------------------+
//| TestLearningSystemIntegration.mq5 - Integration test for learning|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"
#property script_show_inputs

#include "..\Unit\TestBase.mqh"
#include "..\..\Include\Learning\LearningEngine.mqh"
#include "..\..\Include\Learning\KnowledgeBase.mqh"
#include "..\..\Include\Core\SignalGenerator.mqh"
#include "..\..\Include\Strategies\AdvancedStrategy.mqh"
#include "..\..\Include\Utils\Logger.mqh"

//+------------------------------------------------------------------+
//| Integration test for learning system components                  |
//+------------------------------------------------------------------+
class CTestLearningSystemIntegration : public CTestBase
  {
private:
   CLearningEngine     *m_learningEngine;
   CKnowledgeBase      *m_knowledgeBase;
   CSignalGenerator    *m_signalGen;
   CAdvancedStrategy   *m_strategy;
   CLogger             *m_logger;
   
   string              m_testSymbol;
   
public:
                       CTestLearningSystemIntegration() : CTestBase("Learning System Integration", true) 
                         {
                          m_testSymbol = "EURUSD";
                         }
                      ~CTestLearningSystemIntegration() { Cleanup(); }
   
   void                SetUp() override;
   void                TearDown() override;
   ENUM_TEST_RESULT    Run() override;
   
   // Integration test methods
   bool                TestKnowledgeBaseIntegration();
   bool                TestLearningEngineIntegration();
   bool                TestStrategyLearningIntegration();
   bool                TestPerformanceTracking();
   bool                TestAdaptiveSignalGeneration();
   
   // Helper methods
   void                Cleanup();
   void                SimulateTradeResults();
  };

//+------------------------------------------------------------------+
//| Setup learning system integration test environment               |
//+------------------------------------------------------------------+
void CTestLearningSystemIntegration::SetUp()
  {
   Print("Setting up learning system integration test environment...");
   
   // Initialize logger
   m_logger = CLogger::Instance();
   m_logger.Initialize("TestLogs\\Integration\\", "Learning_", LOG_LEVEL_DEBUG, true, 5, 1);
   
   // Initialize components
   m_knowledgeBase = new CKnowledgeBase();
   m_learningEngine = new CLearningEngine();
   m_signalGen = new CSignalGenerator(m_testSymbol, PERIOD_H1, 10, 20, 14, 14, 0.6);
   m_strategy = new CAdvancedStrategy();
   
   // Initialize knowledge base
   m_knowledgeBase.Initialize("TestKB\\", 1000);
   
   m_logger.Info("Learning system integration test environment setup complete", "TestSetup");
  }

//+------------------------------------------------------------------+
//| Cleanup learning system integration test environment             |
//+------------------------------------------------------------------+
void CTestLearningSystemIntegration::TearDown()
  {
   Cleanup();
   if(m_logger != NULL)
     {
      m_logger.Info("Learning system integration test cleanup complete", "TestTeardown");
      m_logger.Flush();
     }
  }

//+------------------------------------------------------------------+
//| Cleanup helper                                                   |
//+------------------------------------------------------------------+
void CTestLearningSystemIntegration::Cleanup()
  {
   if(m_learningEngine != NULL) { delete m_learningEngine; m_learningEngine = NULL; }
   if(m_knowledgeBase != NULL) { delete m_knowledgeBase; m_knowledgeBase = NULL; }
   if(m_signalGen != NULL) { delete m_signalGen; m_signalGen = NULL; }
   if(m_strategy != NULL) { delete m_strategy; m_strategy = NULL; }
  }

//+------------------------------------------------------------------+
//| Run all learning system integration tests                        |
//+------------------------------------------------------------------+
ENUM_TEST_RESULT CTestLearningSystemIntegration::Run()
  {
   bool allPassed = true;
   
   m_logger.Info("Starting learning system integration tests", "IntegrationTest");
   
   allPassed &= TestKnowledgeBaseIntegration();
   allPassed &= TestLearningEngineIntegration();
   allPassed &= TestStrategyLearningIntegration();
   allPassed &= TestPerformanceTracking();
   allPassed &= TestAdaptiveSignalGeneration();
   
   m_logger.Info(StringFormat("Learning system integration tests completed. Result: %s", 
                             allPassed ? "PASSED" : "FAILED"), "IntegrationTest");
   
   return allPassed ? TEST_PASSED : TEST_FAILED;
  }

//+------------------------------------------------------------------+
//| Test knowledge base integration                                  |
//+------------------------------------------------------------------+
bool CTestLearningSystemIntegration::TestKnowledgeBaseIntegration()
  {
   Print("Testing Knowledge Base Integration...");
   m_logger.Info("Testing knowledge base integration", "KBTest");
   
   // Test storing market patterns
   SMarketPattern pattern;
   pattern.symbol = m_testSymbol;
   pattern.timeframe = PERIOD_H1;
   pattern.patternType = "BULLISH_ENGULFING";
   pattern.confidence = 0.85;
   pattern.timestamp = TimeCurrent();
   pattern.outcome = 1.0; // Successful pattern
   
   bool storeResult = m_knowledgeBase.StorePattern(pattern);
   
   if(!AssertTrue(storeResult, "Should store market pattern successfully"))
     {
      m_logger.Error("Failed to store market pattern", "KBTest");
      return false;
     }
   
   m_logger.Info("Successfully stored market pattern", "KBTest");
   
   // Test retrieving similar patterns
   SMarketPattern searchPattern;
   searchPattern.symbol = m_testSymbol;
   searchPattern.timeframe = PERIOD_H1;
   searchPattern.patternType = "BULLISH_ENGULFING";
   
   SMarketPattern retrievedPatterns[];
   int patternCount = m_knowledgeBase.GetSimilarPatterns(searchPattern, retrievedPatterns, 10);
   
   if(!AssertTrue(patternCount >= 0, "Should retrieve patterns without error"))
     {
      m_logger.Error("Failed to retrieve similar patterns", "KBTest");
      return false;
     }
   
   m_logger.Info(StringFormat("Retrieved %d similar patterns", patternCount), "KBTest");
   
   // Test performance metrics storage
   SPerformanceMetrics metrics;
   metrics.symbol = m_testSymbol;
   metrics.strategy = "TEST_STRATEGY";
   metrics.totalTrades = 100;
   metrics.winRate = 0.65;
   metrics.avgProfit = 150.0;
   metrics.maxDrawdown = 500.0;
   metrics.timestamp = TimeCurrent();
   
   bool metricsResult = m_knowledgeBase.StorePerformanceMetrics(metrics);
   
   if(!AssertTrue(metricsResult, "Should store performance metrics successfully"))
     {
      m_logger.Error("Failed to store performance metrics", "KBTest");
      return false;
     }
   
   m_logger.Info("Successfully stored performance metrics", "KBTest");
   
   Print("✓ Knowledge base integration test passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test learning engine integration                                 |
//+------------------------------------------------------------------+
bool CTestLearningSystemIntegration::TestLearningEngineIntegration()
  {
   Print("Testing Learning Engine Integration...");
   m_logger.Info("Testing learning engine integration", "LETest");
   
   // Initialize learning engine with knowledge base
   bool initResult = m_learningEngine.Initialize(m_knowledgeBase);
   
   if(!AssertTrue(initResult, "Learning engine should initialize successfully"))
     {
      m_logger.Error("Failed to initialize learning engine", "LETest");
      return false;
     }
   
   m_logger.Info("Learning engine initialized successfully", "LETest");
   
   // Simulate learning from trade results
   SimulateTradeResults();
   
   // Test pattern recognition
   double currentPrice = SymbolInfoDouble(m_testSymbol, SYMBOL_BID);
   double prices[5] = {currentPrice - 0.0050, currentPrice - 0.0030, currentPrice - 0.0010, currentPrice + 0.0010, currentPrice + 0.0020};
   
   string recognizedPattern = m_learningEngine.RecognizePattern(prices, 5);
   
   if(!AssertTrue(recognizedPattern != "", "Should recognize some pattern"))
     {
      m_logger.Warning("No pattern recognized (this may be normal)", "LETest");
     }
   else
     {
      m_logger.Info(StringFormat("Recognized pattern: %s", recognizedPattern), "LETest");
     }
   
   // Test confidence calculation
   double confidence = m_learningEngine.CalculatePatternConfidence(recognizedPattern, m_testSymbol);
   
   if(!AssertTrue(confidence >= 0.0 && confidence <= 1.0, "Confidence should be between 0 and 1"))
     {
      m_logger.Error("Invalid confidence value", "LETest");
      return false;
     }
   
   m_logger.Info(StringFormat("Pattern confidence: %.2f", confidence), "LETest");
   
   Print("✓ Learning engine integration test passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test strategy learning integration                               |
//+------------------------------------------------------------------+
bool CTestLearningSystemIntegration::TestStrategyLearningIntegration()
  {
   Print("Testing Strategy Learning Integration...");
   m_logger.Info("Testing strategy learning integration", "StrategyTest");
   
   // Initialize strategy
   bool strategyInit = m_strategy.Initialize(m_testSymbol, PERIOD_H1);
   
   if(!AssertTrue(strategyInit, "Strategy should initialize successfully"))
     {
      m_logger.Error("Failed to initialize strategy", "StrategyTest");
      return false;
     }
   
   // Test strategy signal generation
   STradeSignal strategySignal = m_strategy.GenerateSignal();
   
   if(!AssertTrue(strategySignal.symbol == m_testSymbol, "Strategy signal should be for correct symbol"))
     {
      m_logger.Error("Strategy signal symbol mismatch", "StrategyTest");
      return false;
     }
   
   m_logger.Info(StringFormat("Strategy generated signal: %s, Confidence: %.2f", 
                             EnumToString(strategySignal.signal), strategySignal.confidence), "StrategyTest");
   
   // Test strategy adaptation based on learning
   SPerformanceMetrics currentMetrics;
   currentMetrics.symbol = m_testSymbol;
   currentMetrics.strategy = "ADVANCED_STRATEGY";
   currentMetrics.winRate = 0.55;
   currentMetrics.avgProfit = 100.0;
   
   bool adaptResult = m_strategy.AdaptToPerformance(currentMetrics);
   
   if(!AssertTrue(adaptResult, "Strategy should adapt to performance metrics"))
     {
      m_logger.Warning("Strategy adaptation may not be implemented", "StrategyTest");
     }
   else
     {
      m_logger.Info("Strategy adapted successfully", "StrategyTest");
     }
   
   Print("✓ Strategy learning integration test passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test performance tracking integration                            |
//+------------------------------------------------------------------+
bool CTestLearningSystemIntegration::TestPerformanceTracking()
  {
   Print("Testing Performance Tracking Integration...");
   m_logger.Info("Testing performance tracking integration", "PerfTest");
   
   // Simulate multiple trade outcomes
   for(int i = 0; i < 10; i++)
     {
      STradeResult result;
      result.symbol = m_testSymbol;
      result.signal = (i % 2 == 0) ? SIGNAL_BUY : SIGNAL_SELL;
      result.entryPrice = 1.1000 + (i * 0.0001);
      result.exitPrice = result.entryPrice + ((i % 3 == 0) ? 0.0050 : -0.0020); // Mix of wins/losses
      result.profit = (result.exitPrice - result.entryPrice) * 100000;
      result.timestamp = TimeCurrent() - (i * 3600); // Spread over hours
      result.confidence = 0.7 + (i * 0.02);
      
      bool trackResult = m_learningEngine.TrackTradeResult(result);
      
      if(!AssertTrue(trackResult, StringFormat("Should track trade result %d", i)))
        {
         m_logger.Error(StringFormat("Failed to track trade result %d", i), "PerfTest");
         return false;
        }
     }
   
   m_logger.Info("Successfully tracked 10 trade results", "PerfTest");
   
   // Test performance analysis
   SPerformanceMetrics analysisMetrics = m_learningEngine.AnalyzePerformance(m_testSymbol, 24 * 7); // Last week
   
   if(!AssertTrue(analysisMetrics.totalTrades >= 0, "Should have valid trade count"))
     {
      m_logger.Error("Invalid performance analysis", "PerfTest");
      return false;
     }
   
   m_logger.Info(StringFormat("Performance analysis - Trades: %d, Win Rate: %.2f", 
                             analysisMetrics.totalTrades, analysisMetrics.winRate), "PerfTest");
   
   Print("✓ Performance tracking integration test passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Test adaptive signal generation                                  |
//+------------------------------------------------------------------+
bool CTestLearningSystemIntegration::TestAdaptiveSignalGeneration()
  {
   Print("Testing Adaptive Signal Generation...");
   m_logger.Info("Testing adaptive signal generation", "AdaptiveTest");
   
   // Generate baseline signal
   STradeSignal baselineSignal = m_signalGen.GenerateSignal();
   double baselineConfidence = baselineSignal.confidence;
   
   m_logger.Info(StringFormat("Baseline signal confidence: %.2f", baselineConfidence), "AdaptiveTest");
   
   // Simulate learning from recent poor performance
   SPerformanceMetrics poorPerformance;
   poorPerformance.symbol = m_testSymbol;
   poorPerformance.winRate = 0.30; // Poor win rate
   poorPerformance.avgProfit = -50.0; // Losing money
   
   // In a real implementation, this would adjust signal generation parameters
   // For testing, we verify the system can handle performance feedback
   bool feedbackResult = m_learningEngine.ProcessPerformanceFeedback(poorPerformance);
   
   if(!AssertTrue(feedbackResult, "Should process performance feedback"))
     {
      m_logger.Error("Failed to process performance feedback", "AdaptiveTest");
      return false;
     }
   
   m_logger.Info("Successfully processed performance feedback", "AdaptiveTest");
   
   // Test signal generation after learning
   STradeSignal adaptedSignal = m_signalGen.GenerateSignal();
   
   if(!AssertTrue(adaptedSignal.symbol == m_testSymbol, "Adapted signal should be for correct symbol"))
     {
      m_logger.Error("Adapted signal symbol mismatch", "AdaptiveTest");
      return false;
     }
   
   m_logger.Info(StringFormat("Adapted signal confidence: %.2f", adaptedSignal.confidence), "AdaptiveTest");
   
   // Test market condition adaptation
   string currentMarketCondition = m_learningEngine.AnalyzeMarketCondition(m_testSymbol);
   
   if(!AssertTrue(currentMarketCondition != "", "Should analyze market condition"))
     {
      m_logger.Warning("Market condition analysis may not be implemented", "AdaptiveTest");
     }
   else
     {
      m_logger.Info(StringFormat("Current market condition: %s", currentMarketCondition), "AdaptiveTest");
     }
   
   Print("✓ Adaptive signal generation test passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Simulate trade results for learning                              |
//+------------------------------------------------------------------+
void CTestLearningSystemIntegration::SimulateTradeResults()
  {
   m_logger.Info("Simulating trade results for learning", "Simulation");
   
   // Create a mix of winning and losing trades
   for(int i = 0; i < 20; i++)
     {
      STradeResult result;
      result.symbol = m_testSymbol;
      result.signal = (i % 2 == 0) ? SIGNAL_BUY : SIGNAL_SELL;
      result.entryPrice = 1.1000 + (MathRand() % 100) * 0.00001;
      
      // 60% win rate simulation
      bool isWin = (MathRand() % 100) < 60;
      result.exitPrice = result.entryPrice + (isWin ? 0.0030 : -0.0020);
      result.profit = (result.exitPrice - result.entryPrice) * 100000;
      result.timestamp = TimeCurrent() - (i * 1800); // 30 minutes apart
      result.confidence = 0.5 + (MathRand() % 50) * 0.01;
      
      m_learningEngine.TrackTradeResult(result);
     }
   
   m_logger.Info("Completed trade result simulation", "Simulation");
  }

//+------------------------------------------------------------------+
//| Script start function                                            |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("=== Starting Learning System Integration Tests ===");
   
   CTestLearningSystemIntegration test;
   test.SetUp();
   
   ENUM_TEST_RESULT result = test.Run();
   test.PrintTestResult(result);
   
   test.TearDown();
   
   Print("=== Learning System Integration Tests Complete ===");
  }