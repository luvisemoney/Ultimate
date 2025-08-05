//+------------------------------------------------------------------+
//| TestConfig.mqh - Configuration for integration and system tests  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Test Configuration Constants                                     |
//+------------------------------------------------------------------+

// Test Environment Configuration
#define TEST_SYMBOL_PRIMARY     "EURUSD"
#define TEST_SYMBOL_SECONDARY   "GBPUSD"
#define TEST_SYMBOL_TERTIARY    "USDJPY"
#define TEST_TIMEFRAME          PERIOD_H1
#define TEST_MAGIC_NUMBER       12345

// Test Duration Settings
#define TEST_DURATION_SHORT     1    // 1 minute
#define TEST_DURATION_MEDIUM    5    // 5 minutes
#define TEST_DURATION_LONG      10   // 10 minutes
#define TEST_DURATION_EXTENDED  30   // 30 minutes

// Performance Test Thresholds
#define PERF_SIGNALS_PER_SECOND_MIN     100
#define PERF_TRADES_PER_SECOND_MIN      500
#define PERF_LEARNING_UPDATES_PER_SEC   50
#define PERF_MAX_RESPONSE_TIME_MS       100.0
#define PERF_MAX_MEMORY_LEAK_KB         1

// Stress Test Configuration
#define STRESS_HIGH_FREQUENCY_ITERATIONS    10000
#define STRESS_MEMORY_PRESSURE_ITERATIONS   5000
#define STRESS_CONCURRENT_OPERATIONS        100
#define STRESS_MAX_ERROR_RATE_PERCENT       1.0
#define STRESS_MAX_ALLOCATION_FAILURES      50

// Integration Test Settings
#define INTEGRATION_TEST_CYCLES             100
#define INTEGRATION_LEARNING_ENABLED        true
#define INTEGRATION_BROADCASTING_ENABLED    true
#define INTEGRATION_PAPER_TRADING           true

// System Test Configuration
#define SYSTEM_TEST_FULL_ENABLED            true
#define SYSTEM_TEST_PERFORMANCE_ENABLED     true
#define SYSTEM_TEST_STRESS_ENABLED          false
#define SYSTEM_TEST_ENDTOEND_ENABLED        true
#define SYSTEM_TEST_DATA_INTEGRITY_ENABLED  true
#define SYSTEM_TEST_FAILOVER_ENABLED        false

// Logging Configuration
#define LOG_LEVEL_TESTS         LOG_LEVEL_DEBUG
#define LOG_RETENTION_DAYS      7
#define LOG_MAX_FILE_SIZE_MB    10
#define LOG_MAX_FILES           20

// Risk Management Test Settings
#define TEST_RISK_PERCENT       2.0
#define TEST_MAX_DRAWDOWN       20.0
#define TEST_DAILY_LOSS_LIMIT   5.0
#define TEST_MAX_POSITION_SIZE  1.0
#define TEST_MAX_TRADES         5

// Signal Generation Test Settings
#define TEST_MA_FAST_PERIOD     10
#define TEST_MA_SLOW_PERIOD     20
#define TEST_RSI_PERIOD         14
#define TEST_MACD_PERIOD        14
#define TEST_MIN_CONFIDENCE     0.6

// Learning Engine Test Settings
#define TEST_LEARNING_LOOKBACK      100
#define TEST_LEARNING_MIN_TRADES    10
#define TEST_LEARNING_UPDATE_FREQ   5

//+------------------------------------------------------------------+
//| Test Configuration Structure                                     |
//+------------------------------------------------------------------+
struct STestConfiguration
  {
   // Environment settings
   string            primarySymbol;
   string            secondarySymbol;
   string            tertiarySymbol;
   ENUM_TIMEFRAMES   timeframe;
   int               magicNumber;
   
   // Duration settings
   int               shortDuration;
   int               mediumDuration;
   int               longDuration;
   int               extendedDuration;
   
   // Performance thresholds
   int               minSignalsPerSecond;
   int               minTradesPerSecond;
   int               minLearningUpdatesPerSecond;
   double            maxResponseTimeMs;
   int               maxMemoryLeakKB;
   
   // Stress test limits
   int               highFrequencyIterations;
   int               memoryPressureIterations;
   int               concurrentOperations;
   double            maxErrorRatePercent;
   int               maxAllocationFailures;
   
   // Feature flags
   bool              enableLearning;
   bool              enableBroadcasting;
   bool              enablePaperTrading;
   bool              enableFullSystemTest;
   bool              enablePerformanceTest;
   bool              enableStressTest;
   bool              enableEndToEndTest;
   bool              enableDataIntegrityTest;
   bool              enableFailoverTest;
   
   // Logging settings
   ENUM_LOG_LEVEL    logLevel;
   int               logRetentionDays;
   int               logMaxFileSizeMB;
   int               logMaxFiles;
   
   // Trading parameters
   double            riskPercent;
   double            maxDrawdown;
   double            dailyLossLimit;
   double            maxPositionSize;
   int               maxTrades;
   
   // Technical analysis parameters
   int               maFastPeriod;
   int               maSlowPeriod;
   int               rsiPeriod;
   int               macdPeriod;
   double            minConfidence;
   
   // Learning parameters
   int               learningLookback;
   int               learningMinTrades;
   int               learningUpdateFreq;
  };

//+------------------------------------------------------------------+
//| Default Test Configuration                                       |
//+------------------------------------------------------------------+
STestConfiguration GetDefaultTestConfig()
  {
   STestConfiguration config;
   
   // Environment settings
   config.primarySymbol = TEST_SYMBOL_PRIMARY;
   config.secondarySymbol = TEST_SYMBOL_SECONDARY;
   config.tertiarySymbol = TEST_SYMBOL_TERTIARY;
   config.timeframe = TEST_TIMEFRAME;
   config.magicNumber = TEST_MAGIC_NUMBER;
   
   // Duration settings
   config.shortDuration = TEST_DURATION_SHORT;
   config.mediumDuration = TEST_DURATION_MEDIUM;
   config.longDuration = TEST_DURATION_LONG;
   config.extendedDuration = TEST_DURATION_EXTENDED;
   
   // Performance thresholds
   config.minSignalsPerSecond = PERF_SIGNALS_PER_SECOND_MIN;
   config.minTradesPerSecond = PERF_TRADES_PER_SECOND_MIN;
   config.minLearningUpdatesPerSecond = PERF_LEARNING_UPDATES_PER_SEC;
   config.maxResponseTimeMs = PERF_MAX_RESPONSE_TIME_MS;
   config.maxMemoryLeakKB = PERF_MAX_MEMORY_LEAK_KB;
   
   // Stress test limits
   config.highFrequencyIterations = STRESS_HIGH_FREQUENCY_ITERATIONS;
   config.memoryPressureIterations = STRESS_MEMORY_PRESSURE_ITERATIONS;
   config.concurrentOperations = STRESS_CONCURRENT_OPERATIONS;
   config.maxErrorRatePercent = STRESS_MAX_ERROR_RATE_PERCENT;
   config.maxAllocationFailures = STRESS_MAX_ALLOCATION_FAILURES;
   
   // Feature flags
   config.enableLearning = INTEGRATION_LEARNING_ENABLED;
   config.enableBroadcasting = INTEGRATION_BROADCASTING_ENABLED;
   config.enablePaperTrading = INTEGRATION_PAPER_TRADING;
   config.enableFullSystemTest = SYSTEM_TEST_FULL_ENABLED;
   config.enablePerformanceTest = SYSTEM_TEST_PERFORMANCE_ENABLED;
   config.enableStressTest = SYSTEM_TEST_STRESS_ENABLED;
   config.enableEndToEndTest = SYSTEM_TEST_ENDTOEND_ENABLED;
   config.enableDataIntegrityTest = SYSTEM_TEST_DATA_INTEGRITY_ENABLED;
   config.enableFailoverTest = SYSTEM_TEST_FAILOVER_ENABLED;
   
   // Logging settings
   config.logLevel = LOG_LEVEL_TESTS;
   config.logRetentionDays = LOG_RETENTION_DAYS;
   config.logMaxFileSizeMB = LOG_MAX_FILE_SIZE_MB;
   config.logMaxFiles = LOG_MAX_FILES;
   
   // Trading parameters
   config.riskPercent = TEST_RISK_PERCENT;
   config.maxDrawdown = TEST_MAX_DRAWDOWN;
   config.dailyLossLimit = TEST_DAILY_LOSS_LIMIT;
   config.maxPositionSize = TEST_MAX_POSITION_SIZE;
   config.maxTrades = TEST_MAX_TRADES;
   
   // Technical analysis parameters
   config.maFastPeriod = TEST_MA_FAST_PERIOD;
   config.maSlowPeriod = TEST_MA_SLOW_PERIOD;
   config.rsiPeriod = TEST_RSI_PERIOD;
   config.macdPeriod = TEST_MACD_PERIOD;
   config.minConfidence = TEST_MIN_CONFIDENCE;
   
   // Learning parameters
   config.learningLookback = TEST_LEARNING_LOOKBACK;
   config.learningMinTrades = TEST_LEARNING_MIN_TRADES;
   config.learningUpdateFreq = TEST_LEARNING_UPDATE_FREQ;
   
   return config;
  }

//+------------------------------------------------------------------+
//| Performance Test Configuration                                   |
//+------------------------------------------------------------------+
STestConfiguration GetPerformanceTestConfig()
  {
   STestConfiguration config = GetDefaultTestConfig();
   
   // Optimize for performance testing
   config.enableLearning = false;           // Disable learning for pure performance
   config.enableBroadcasting = false;      // Disable broadcasting for pure performance
   config.logLevel = LOG_LEVEL_WARNING;    // Reduce logging overhead
   
   // Increase iterations for better performance measurement
   config.highFrequencyIterations = 50000;
   config.memoryPressureIterations = 10000;
   
   return config;
  }

//+------------------------------------------------------------------+
//| Stress Test Configuration                                        |
//+------------------------------------------------------------------+
STestConfiguration GetStressTestConfig()
  {
   STestConfiguration config = GetDefaultTestConfig();
   
   // Maximize stress testing
   config.enableStressTest = true;
   config.extendedDuration = 60;            // 1 hour for extended stress
   config.highFrequencyIterations = 100000;
   config.memoryPressureIterations = 20000;
   config.concurrentOperations = 200;
   config.maxErrorRatePercent = 5.0;        // Allow higher error rate under stress
   
   return config;
  }

//+------------------------------------------------------------------+
//| Production-like Test Configuration                               |
//+------------------------------------------------------------------+
STestConfiguration GetProductionTestConfig()
  {
   STestConfiguration config = GetDefaultTestConfig();
   
   // Enable all features for production-like testing
   config.enableLearning = true;
   config.enableBroadcasting = true;
   config.enableFullSystemTest = true;
   config.enablePerformanceTest = true;
   config.enableEndToEndTest = true;
   config.enableDataIntegrityTest = true;
   
   // Use production-like parameters
   config.riskPercent = 1.0;                // Lower risk for production
   config.maxDrawdown = 10.0;               // Stricter drawdown limit
   config.dailyLossLimit = 2.0;             // Stricter daily loss limit
   config.minConfidence = 0.7;              // Higher confidence threshold
   
   return config;
  }

//+------------------------------------------------------------------+
//| Quick Test Configuration (for development)                       |
//+------------------------------------------------------------------+
STestConfiguration GetQuickTestConfig()
  {
   STestConfiguration config = GetDefaultTestConfig();
   
   // Minimize test duration for quick feedback
   config.shortDuration = 1;
   config.mediumDuration = 2;
   config.longDuration = 3;
   config.extendedDuration = 5;
   
   // Reduce iterations for quick testing
   config.highFrequencyIterations = 1000;
   config.memoryPressureIterations = 500;
   config.concurrentOperations = 10;
   
   // Disable time-consuming tests
   config.enableStressTest = false;
   config.enableFailoverTest = false;
   
   return config;
  }

//+------------------------------------------------------------------+
//| Test Environment Validation                                      |
//+------------------------------------------------------------------+
bool ValidateTestEnvironment(const STestConfiguration &config)
  {
   // Check if test symbol is available
   if(!SymbolSelect(config.primarySymbol, true))
     {
      Print("ERROR: Primary test symbol not available: ", config.primarySymbol);
      return false;
     }
   
   // Check if secondary symbol is available (if needed)
   if(config.enableEndToEndTest && !SymbolSelect(config.secondarySymbol, true))
     {
      Print("WARNING: Secondary test symbol not available: ", config.secondarySymbol);
      // Don't fail - just warn
     }
   
   // Validate timeframe
   if(config.timeframe < PERIOD_M1 || config.timeframe > PERIOD_MN1)
     {
      Print("ERROR: Invalid timeframe specified");
      return false;
     }
   
   // Validate risk parameters
   if(config.riskPercent <= 0 || config.riskPercent > 10.0)
     {
      Print("ERROR: Invalid risk percent: ", config.riskPercent);
      return false;
     }
   
   if(config.maxDrawdown <= 0 || config.maxDrawdown > 50.0)
     {
      Print("ERROR: Invalid max drawdown: ", config.maxDrawdown);
      return false;
     }
   
   // Validate technical analysis parameters
   if(config.maFastPeriod >= config.maSlowPeriod)
     {
      Print("ERROR: Fast MA period must be less than slow MA period");
      return false;
     }
   
   if(config.minConfidence < 0.0 || config.minConfidence > 1.0)
     {
      Print("ERROR: Invalid confidence threshold: ", config.minConfidence);
      return false;
     }
   
   Print("Test environment validation passed");
   return true;
  }

//+------------------------------------------------------------------+
//| Print Test Configuration                                         |
//+------------------------------------------------------------------+
void PrintTestConfiguration(const STestConfiguration &config)
  {
   Print("=== TEST CONFIGURATION ===");
   Print("Primary Symbol: ", config.primarySymbol);
   Print("Timeframe: ", EnumToString(config.timeframe));
   Print("Magic Number: ", config.magicNumber);
   Print("Risk Percent: ", config.riskPercent, "%");
   Print("Max Drawdown: ", config.maxDrawdown, "%");
   Print("Min Confidence: ", config.minConfidence);
   Print("Learning Enabled: ", config.enableLearning ? "YES" : "NO");
   Print("Broadcasting Enabled: ", config.enableBroadcasting ? "YES" : "NO");
   Print("Paper Trading: ", config.enablePaperTrading ? "YES" : "NO");
   Print("Performance Test: ", config.enablePerformanceTest ? "YES" : "NO");
   Print("Stress Test: ", config.enableStressTest ? "YES" : "NO");
   Print("End-to-End Test: ", config.enableEndToEndTest ? "YES" : "NO");
   Print("==========================");
  }

//+------------------------------------------------------------------+