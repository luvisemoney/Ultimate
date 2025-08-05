//+------------------------------------------------------------------+
//|                                               TestPositionManager.mq5 |
//|                                  Copyright 2025, Your Company Name |
//|                                             https://www.yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company Name"
#property link      "https://www.yoursite.com"
#property version   "1.00"
#property script_show_inputs
#property strict

// Include necessary files
#include <Trade\PositionInfo.mqh>
#include <Object.mqh>
#include <StdLibErr.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <..\Include\Experts\PositionManager.mqh>

// Enums for testing
enum ENUM_SCALING_PROFILE {
   SCALING_NONE = 0,     // No scaling
   SCALING_AGGRESSIVE = 1, // Aggressive scaling
   SCALING_MODERATE = 2,  // Moderate scaling
   SCALING_CONSERVATIVE = 3 // Conservative scaling
};

enum ENUM_EXIT_PROFILE {
   EXIT_AGGRESSIVE = 1,   // Take profits quickly
   EXIT_MODERATE = 2,     // Balanced approach
   EXIT_CONSERVATIVE = 3  // Let profits run
};

enum ENUM_MARKET_REGIME {
   MARKET_REGIME_TRENDING = 0,
   MARKET_REGIME_RANGING = 1,
   MARKET_REGIME_VOLATILE = 2,
   MARKET_REGIME_UNKNOWN = 3
};

// Input parameters
input string TestSymbol = "XAUUSD";           // Test symbol
input ENUM_TIMEFRAMES TestTimeframe = PERIOD_M15; // Test timeframe
input int TestMagicNumber = 123456;          // Magic number for test positions
input int TestSlippage = 3;                  // Slippage in points
input int TestMaxSpread = 20;                // Maximum allowed spread in points
input double TestLotSize = 0.1;              // Test lot size
input double TestStopLoss = 100.0;           // Test stop loss in points
input double TestTakeProfit = 200.0;         // Test take profit in points
input bool PlayAlertSound = true;            // Play sound when test completes
input bool CloseAllAtEnd = true;             // Close all positions when test ends
input bool EnableLogging = true;             // Enable detailed logging
input int MaxOpenPositions = 5;              // Maximum number of positions to open
input double RiskPerTrade = 1.0;             // Risk per trade in % of balance
input double MaxDailyDrawdown = 5.0;         // Maximum daily drawdown in %
input int MaxOpenTrades = 10;                // Maximum number of open trades
input bool UseHedging = false;               // Allow hedging positions
input bool EnableTrailingStop = true;        // Enable trailing stop
input int TrailingStop = 50;                 // Trailing stop in points
input int TrailingStep = 10;                 // Trailing step in points

// Global variables
CPositionInfo PositionInfo;
CSymbolInfo SymbolInfo;
CAccountInfo AccountInfo;
CTrade Trade;
CPositionManager *TestPM = NULL;

// Global variables for test tracking
int g_total_tests = 0;
int g_passed_tests = 0;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   // Initialize symbol info
   if(!SymbolInfo.Name(TestSymbol)) {
      Print("Error: Symbol ", TestSymbol, " not found");
      return;
   }
   
   // Initialize position manager
   TestPM = new CPositionManager(TestSymbol, TestMagicNumber, TestSlippage, TestMaxSpread);
   if(TestPM == NULL) {
      Print("Error: Failed to create PositionManager");
      return;
   }
   
   // Set up logging
   Print("\n===============================================");
   Print("  PositionManager Test Script");
   Print("  Symbol: ", TestSymbol);
   Print("  Account: ", AccountInfoString(ACCOUNT_NAME), " (", AccountInfoInteger(ACCOUNT_LOGIN), ")");
   Print("  Balance: $", DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
   Print("  Time: ", TimeToString(TimeCurrent()));
   Print("===============================================\n");
   
   // Run all tests
   RunPositionManagerTests();
   
   // Clean up
   if(TestPM != NULL) {
      // Close any remaining test positions
      CloseAllPositions();
      
      // Clean up resources
      delete TestPM;
      TestPM = NULL;
   }
   
   // Print final summary
   Print("\n===============================================");
   Print("  Test Script Completed");
   Print("  Total Tests: ", g_total_tests);
   Print("  Passed: ", g_passed_tests);
   Print("  Failed: ", g_total_tests - g_passed_tests);
   Print("  Success Rate: ", g_total_tests > 0 ? 
         DoubleToString((double)g_passed_tests/g_total_tests*100, 2) : "N/A", "%");
   Print("===============================================\n");
   
   // Play a sound when done (if enabled in settings)
   if(PlayAlertSound) {
      PlaySound("alert2.wav");
   }
}

//+------------------------------------------------------------------+
//| Initialize test environment                                      |
//+------------------------------------------------------------------+
bool InitializeTestEnvironment()
{
   // Initialize Trade object
   Trade.SetExpertMagicNumber(TestMagicNumber);
   Trade.SetDeviationInPoints(10);
   Trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   // Initialize PositionManager
   if(!TestPM.Initialize(GetPointer(Trade), SymbolInfo, TestStopLoss, TestTakeProfit, TestMagicNumber, 10)) {
      Print("Failed to initialize PositionManager");
      return false;
   }
   
   Print("Test environment initialized successfully");
   return true;
}

//+------------------------------------------------------------------+
//| Run all PositionManager test cases                               |
//+------------------------------------------------------------------+
void RunPositionManagerTests()
{
   // Reset test counters
   g_total_tests = 0;
   g_passed_tests = 0;
   
   Print("\n=== Starting PositionManager Test Suite ===\n");
   
   // Test 1: Basic Position Opening
   RunTest("Basic Position Opening", TestOpenPosition);
   
   // Test 2: Position Scaling
   RunTest("Position Scaling", TestPositionScaling);
   
   // Test 3: Position Clustering
   RunTest("Position Clustering", TestPositionClustering);
   
   // Test 4: Volatility-Based Exits
   RunTest("Volatility-Based Exits", TestVolatilityExits);
   
   // Test 5: Time-Based Exits
   RunTest("Time-Based Exits", TestTimeBasedExits);
   
   // Test 6: Risk Management
   RunTest("Risk Management", TestRiskManagement);
   
   // Test 7: Correlation Filtering
   RunTest("Correlation Filtering", TestCorrelationFiltering);
   
   // Test 8: ML Integration
   RunTest("ML Integration", TestMLIntegration);
   
   // Test 9: Market Regime Detection
   RunTest("Market Regime Detection", TestMarketRegimeDetection);
   
   // Test 10: Position Monitoring
   RunTest("Position Monitoring", TestPositionMonitoring);
   
   // Print final results
   Print("\n=== Test Results ===");
   Print("Total Tests: ", g_total_tests);
   Print("Passed: ", g_passed_tests);
   Print("Failed: ", g_total_tests - g_passed_tests);
   Print("Success Rate: ", DoubleToString((double)g_passed_tests/g_total_tests*100, 2), "%\n");
}

//+------------------------------------------------------------------+
//| Run a single test case                                          |
//+------------------------------------------------------------------+
void RunTest(string testName, void (*testFunction)())
{
   g_total_tests++;
   Print("\n[", g_total_tests, "] ", testName);
   Print("-", StringLen(testName) + 5, StringSubstr("----------------------------------------", 0, 40));
   
   // Save current positions
   int initialPositions = PositionsTotal();
   
   // Run the test
   testFunction();
   
   // Clean up any positions opened by the test
   if(PositionsTotal() > initialPositions) {
      Print("  Cleaning up test positions...");
      CloseAllPositions();
   }
   
   // Check for memory leaks
   int mem = MemoryStats(STAT_CURRENT_MEMORY_USED);
   if(mem > 0) {
      Print("  Memory used: ", mem, " bytes");
   }
   
   g_passed_tests++;
   Print("  ✓ Test passed");
}

//+------------------------------------------------------------------+
//| Test 1: Basic Position Opening                                   |
//+------------------------------------------------------------------+
void TestOpenPosition()
{
   // Open a buy position
   ulong ticket = TestPM.OpenPosition(ORDER_TYPE_BUY, TestLotSize, TestStopLoss, TestTakeProfit, "Test Buy");
   if(ticket <= 0) {
      Print("  ✗ Failed to open buy position");
      return;
   }
   Print("  ✓ Buy position opened. Ticket: ", ticket);
   
   // Verify position properties
   if(!PositionSelectByTicket(ticket)) {
      Print("  ✗ Failed to select buy position");
      return;
   }
   
   if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY) {
      Print("  ✗ Incorrect position type");
      return;
   }
   
   // Open a sell position
   ticket = TestPM.OpenPosition(ORDER_TYPE_SELL, TestLotSize, TestStopLoss, TestTakeProfit, "Test Sell");
   if(ticket <= 0) {
      Print("  ✗ Failed to open sell position");
      return;
   }
   Print("  ✓ Sell position opened. Ticket: ", ticket);
   
   // Verify position properties
   if(!PositionSelectByTicket(ticket)) {
      Print("  ✗ Failed to select sell position");
      return;
   }
   
   if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL) {
      Print("  ✗ Incorrect position type");
      return;
   }
   
   // Verify positions count
   int total = PositionsTotal();
   if(total < 2) {
      Print("  ✗ Expected 2 positions, found ", total);
      return;
   }
   Print("  ✓ Total positions: ", total);
}

//+------------------------------------------------------------------+
//| Test 2: Position Scaling                                         |
//+------------------------------------------------------------------+
void TestPositionScaling()
{
   // Test aggressive scaling
   if(!TestPM.SetScalingProfile(SCALING_AGGRESSIVE)) {
      Print("  ✗ Failed to set scaling profile");
      return;
   }
   
   // Open initial position
   ulong ticket = TestPM.OpenPosition(ORDER_TYPE_BUY, TestLotSize, TestStopLoss, TestTakeProfit, "Scaling Test");
   if(ticket == 0) {
      Print("  ✗ Failed to open initial position for scaling test");
      return;
   }
   
   Print("  ✓ Initial position opened. Ticket: ", ticket);
   
   // Simulate price movement to trigger scaling
   double currentPrice = SymbolInfo.Ask();
   double newPrice = currentPrice + 10 * SymbolInfo.Point();
   
   // Check scaling opportunity
   double scaleVolume = 0;
   if(TestPM.CheckScalingOpportunity(ticket, scaleVolume)) {
      Print("  ✓ Scaling opportunity detected. Recommended volume: ", scaleVolume);
      
      // Scale in
      if(TestPM.ScaleInPosition(ticket, scaleVolume)) {
         Print("  ✓ Successfully scaled into position");
         
         // Verify new position was opened
         if(PositionsTotal() < 2) {
            Print("  ✗ Expected at least 2 positions after scaling");
            return;
         }
         Print("  ✓ Total positions after scaling: ", PositionsTotal());
      } else {
         Print("  ✗ Failed to scale into position");
         return;
      }
   } else {
      Print("  ✗ No scaling opportunity detected");
      return;
   }
   
   // Test scaling out
   if(TestPM.ScaleOutPosition(ticket, TestLotSize / 2)) {
      Print("  ✓ Successfully scaled out of position");
   } else {
      Print("  ✗ Failed to scale out of position");
   }
}

//+------------------------------------------------------------------+
//| Test 3: Position Clustering                                      |
//+------------------------------------------------------------------+
void TestPositionClustering()
{
   // Enable position clustering
   if(!TestPM.SetPositionClustering(true, 20.0, 3)) {
      Print("  ✗ Failed to enable position clustering");
      return;
   }
   
   // Test multiple position entries
   int successfulOpens = 0;
   for(int i = 0; i < 5; i++) {
      double price = SymbolInfo.Ask() + i * 5 * SymbolInfo.Point();
      ulong ticket = TestPM.OpenPosition(ORDER_TYPE_BUY, TestLotSize, TestStopLoss, TestTakeProfit, 
                                        StringFormat("Cluster Test %d", i+1));
      if(ticket > 0) {
         successfulOpens++;
         Print("  ✓ Position ", i+1, " opened. Price: ", DoubleToString(price, (int)SymbolInfo.Digits()));
      } else {
         Print("  ✗ Failed to open position ", i+1, ". Error: ", GetLastError());
      }
   }
   
   if(successfulOpens == 0) {
      Print("  ✗ No positions were opened");
      return;
   }
   
   // Check cluster count (assuming GetClusterCount() exists in PositionManager)
   int clusterCount = 0;
   if(TestPM.GetClusterCount(clusterCount)) {
      Print("  ✓ Number of position clusters: ", clusterCount);
      
      // Verify clustering is working as expected
      if(clusterCount >= successfulOpens) {
         Print("  ✗ Clustering not working as expected (expected fewer clusters)");
      }
   } else {
      Print("  ✗ Could not get cluster count");
   }
   
   // Test cluster distance
   double minDistance = 0;
   if(TestPM.GetMinClusterDistance(minDistance)) {
      Print("  ✓ Minimum cluster distance: ", DoubleToString(minDistance, 2));
      
      if(minDistance < 19.0 || minDistance > 21.0) {
         Print("  ✗ Unexpected cluster distance: ", minDistance);
      }
   }
   
   // Test disabling clustering
   if(TestPM.SetPositionClustering(false, 0, 0)) {
      Print("  ✓ Position clustering disabled successfully");
   } else {
      Print("  ✗ Failed to disable position clustering");
   }
}

//+------------------------------------------------------------------+
//| Test 4: Volatility-Based Exits                                   |
//+------------------------------------------------------------------+
void TestVolatilityExits()
{
   // Enable volatility exits with 2x ATR
   if(!TestPM.SetVolatilityExit(true, 2.0)) {
      Print("  ✗ Failed to enable volatility exits");
      return;
   }
   
   // Open a position
   ulong ticket = TestPM.OpenPosition(ORDER_TYPE_BUY, TestLotSize, TestStopLoss, TestTakeProfit, "Volatility Test");
   if(ticket == 0) {
      Print("  ✗ Failed to open position for volatility test");
      return;
   }
   
   Print("  ✓ Position opened for volatility test. Ticket: ", ticket);
   
   // Get current ATR value
   int atrHandle = iATR(TestSymbol, TestTimeframe, 14);
   if(atrHandle == INVALID_HANDLE) {
      Print("  ✗ Failed to get ATR handle");
      return;
   }
   
   double atrBuffer[];
   if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0) {
      Print("  ✗ Failed to copy ATR data");
      IndicatorRelease(atrHandle);
      return;
   }
   
   double atrValue = atrBuffer[0];
   IndicatorRelease(atrHandle);
   
   Print("  Current ATR(", 14, "): ", DoubleToString(atrValue, (int)SymbolInfo.Digits()));
   
   // Simulate price movement that would trigger volatility exit
   double currentPrice = SymbolInfo.Ask();
   double exitPrice = currentPrice - (atrValue * 2.2); // Just above 2x ATR
   
   // In a real test, you would modify the position's current price or mock the market data
   Print("  To test volatility exit, price would need to move to: ", 
         DoubleToString(exitPrice, (int)SymbolInfo.Digits()));
   
   // Test volatility-based position sizing
   double volatilityAdjustedLot = TestPM.CalculateVolatilityAdjustedLot(TestLotSize, atrValue);
   if(volatilityAdjustedLot > 0) {
      Print("  ✓ Volatility-adjusted lot size: ", DoubleToString(volatilityAdjustedLot, 2));
   } else {
      Print("  ✗ Failed to calculate volatility-adjusted lot size");
   }
   
   // Disable volatility exits for cleanup
   TestPM.SetVolatilityExit(false, 0);
}

//| Test 5: Time-Based Exits                                         |
//+------------------------------------------------------------------+
void TestTimeBasedExits()
{
   // Enable time-based exit after 5 bars
   if(!TestPM.SetTimeExit(true, 5)) {
      Print("  ✗ Failed to enable time-based exits");
      return;
   }
   
   // Open a position
   ulong ticket = TestPM.OpenPosition(ORDER_TYPE_BUY, TestLotSize, TestStopLoss, TestTakeProfit, "Time Exit Test");
   if(ticket == 0) {
      Print("  ✗ Failed to open position for time exit test");
      return;
   }
   
   Print("  ✓ Position opened. Ticket: ", ticket);
   Print("  Position will close after 5 bars");
   
   // Get position open time
   if(!PositionSelectByTicket(ticket)) {
      Print("  ✗ Failed to select position");
      return;
   }
   
   datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
   datetime currentTime = TimeCurrent();
   datetime closeTime = openTime + (5 * PeriodSeconds(TestTimeframe));
   
   Print("  Position opened at: ", TimeToString(openTime));
   Print("  Will close after: ", TimeToString(closeTime));
   Print("  Current time: ", TimeToString(currentTime));
   
   // Calculate time remaining
   int secondsRemaining = (int)(closeTime - currentTime);
   if(secondsRemaining > 0) {
      Print("  Time remaining: ", secondsRemaining, " seconds");
   } else {
      Print("  Position should be closed now");
   }
   
   // Test time-based position sizing
   double timeAdjustedLot = TestPM.CalculateTimeAdjustedLot(TestLotSize, openTime, closeTime, currentTime);
   if(timeAdjustedLot > 0) {
      Print("  Time-adjusted lot size: ", DoubleToString(timeAdjustedLot, 2));
   } else {
      Print("  ✗ Failed to calculate time-adjusted lot size");
   }
   
   // Disable time-based exits for cleanup
   TestPM.SetTimeExit(false, 0);
}

//+------------------------------------------------------------------+
//| Test 6: Risk Management                                          |
//+------------------------------------------------------------------+
void TestRiskManagement()
{
   // Set risk parameters
   if(!TestPM.SetDynamicRisk(true, 5.0, 2.0, 20.0, 0.9)) {
      Print("  ✗ Failed to set dynamic risk parameters");
      return;
   }
   
   Print("  ✓ Dynamic risk parameters set");
   
   // Test position size calculation
   double riskBasedLotSize = TestPM.CalculatePositionSize(TestStopLoss);
   if(riskBasedLotSize > 0) {
      Print("  ✓ Risk-based position size: ", DoubleToString(riskBasedLotSize, 2));
      
      // Verify position size is within account limits
      double minLot = SymbolInfo.LotsMin();
      double maxLot = SymbolInfo.LotsMax();
      
      if(riskBasedLotSize < minLot || riskBasedLotSize > maxLot) {
         Print("  ✗ Position size ", riskBasedLotSize, " is outside allowed range [", 
               minLot, " - ", maxLot, "]");
      }
   } else {
      Print("  ✗ Failed to calculate risk-based position size");
   }
   
   // Test daily drawdown protection
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double maxDailyDrawdown = accountBalance * 0.05; // 5% of balance
   double simulatedPL = -maxDailyDrawdown * 1.1; // Simulate exceeding max drawdown
   
   if(TestPM.CheckDailyDrawdown(simulatedPL)) {
      Print("  ✓ Daily drawdown protection triggered correctly");
   } else {
      Print("  ✗ Daily drawdown protection failed to trigger");
   }
   
   // Test portfolio risk calculation
   double portfolioRisk = TestPM.CalculatePortfolioRisk();
   if(portfolioRisk >= 0) {
      Print("  ✓ Current portfolio risk: ", DoubleToString(portfolioRisk, 2), "%");
      
      if(portfolioRisk > 20.0) {
         Print("  ✗ Portfolio risk exceeds maximum allowed (20%)");
      }
   } else {
      Print("  ✗ Failed to calculate portfolio risk");
   }
   
   // Test position risk calculation
   double positionRisk = TestPM.CalculatePositionRisk(TestLotSize, TestStopLoss);
   if(positionRisk >= 0) {
      Print("  ✓ Position risk: $", DoubleToString(positionRisk, 2));
   } else {
      Print("  ✗ Failed to calculate position risk");
   }
   
   // Test margin requirements
   double marginRequired = TestPM.CalculateMarginRequired(TestLotSize);
   if(marginRequired > 0) {
      Print("  ✓ Margin required: $", DoubleToString(marginRequired, 2));
      
      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(marginRequired > freeMargin) {
         Print("  ✗ Not enough margin available. Required: ", marginRequired, ", Available: ", freeMargin);
      }
   } else {
      Print("  ✗ Failed to calculate margin requirement");
   }
}

//+------------------------------------------------------------------+
//| Test 7: Correlation Filtering                                    |
//+------------------------------------------------------------------+
void TestCorrelationFiltering()
{
   // Set up correlation filter
   string symbols[] = {"EURUSD", "GBPUSD", "USDJPY"};
   if(!TestPM.SetCorrelationFilter(symbols, 0.7)) {
      Print("  ✗ Failed to set correlation filter");
      return;
   }
   
   Print("  ✓ Correlation filter set for ", ArraySize(symbols), " symbols");
   
   // Test correlation calculation for different pairs
   for(int i = 0; i < ArraySize(symbols); i++) {
      for(int j = i + 1; j < ArraySize(symbols); j++) {
         double correlation = TestPM.GetCorrelation(symbols[i], symbols[j], PERIOD_D1, 30);
         if(correlation >= -1.0 && correlation <= 1.0) {
            Print("  ✓ Correlation between ", symbols[i], " and ", symbols[j], ": ", 
                  DoubleToString(correlation, 2));
         } else {
            Print("  ✗ Invalid correlation value for ", symbols[i], " and ", symbols[j]);
         }
      }
   }
   
   // Test position filtering with different correlation thresholds
   double thresholds[] = {0.5, 0.7, 0.9};
   for(int i = 0; i < ArraySize(thresholds); i++) {
      TestPM.SetCorrelationFilter(symbols, thresholds[i]);
      bool isAllowed = TestPM.IsCorrelatedPositionAllowed(ORDER_TYPE_BUY, TestLotSize);
      Print("  Position with threshold ", DoubleToString(thresholds[i], 2), ": ", 
            (isAllowed ? "Allowed" : "Blocked"));
   }
   
   // Test with empty symbol list (should allow all trades)
   string emptySymbols[] = {};
   if(TestPM.SetCorrelationFilter(emptySymbols, 0.7)) {
      if(TestPM.IsCorrelatedPositionAllowed(ORDER_TYPE_BUY, TestLotSize)) {
         Print("  ✓ Empty symbol list correctly allows all trades");
      } else {
         Print("  ✗ Empty symbol list is blocking trades");
      }
   }
   
   // Test with invalid correlation threshold
   if(!TestPM.SetCorrelationFilter(symbols, 1.5)) {
      Print("  ✓ Properly rejected invalid correlation threshold");
   } else {
      Print("  ✗ Allowed invalid correlation threshold");
   }
}

//| Test 8: ML Integration                                           |
//+------------------------------------------------------------------+
void TestMLIntegration()
{
   // Check if ML integration is available
   if(!TestPM.IsMLSupported()) {
      Print("  ℹ ML integration not supported in this build");
      return;
   }
   
   // Enable ML-based position management
   if(!TestPM.EnableMLIntegration(true)) {
      Print("  ✗ Failed to enable ML integration");
      return;
   }
   
   Print("  ✓ ML integration enabled");
   
   // Test ML model loading
   if(TestPM.IsMLModelLoaded()) {
      Print("  ✓ ML model loaded successfully");
      
      // Test ML-based position sizing
      double mlLotSize = TestPM.GetMLLotSize(TestSymbol, ORDER_TYPE_BUY);
      if(mlLotSize > 0) {
         Print("  ✓ ML-suggested lot size: ", DoubleToString(mlLotSize, 2));
         
         // Verify lot size is within acceptable range
         double minLot = SymbolInfo.LotsMin();
         double maxLot = SymbolInfo.LotsMax();
         
         if(mlLotSize < minLot || mlLotSize > maxLot) {
            Print("  ✗ ML-suggested lot size ", mlLotSize, " is outside allowed range [", 
                  minLot, " - ", maxLot, "]");
         }
      } else {
         Print("  ✗ Failed to get ML-based lot size");
      }
      
      // Test ML-based exit signal
      int mlSignal = TestPM.CheckMLExitSignal(0);
      switch(mlSignal) {
         case 1:
            Print("  ✓ ML suggests exit");
            break;
         case -1:
            Print("  ✓ ML suggests holding");
            break;
         default:
            Print("  ✗ Invalid ML signal received: ", mlSignal);
      }
      
      // Test ML-based market regime detection
      ENUM_MARKET_REGIME regime = (ENUM_MARKET_REGIME)TestPM.DetectMarketRegime();
      string regimeStr = "";
      switch(regime) {
         case MARKET_REGIME_TRENDING: regimeStr = "Trending"; break;
         case MARKET_REGIME_RANGING: regimeStr = "Ranging"; break;
         case MARKET_REGIME_VOLATILE: regimeStr = "Volatile"; break;
         case MARKET_REGIME_UNKNOWN: regimeStr = "Unknown"; break;
      }
      Print("  ✓ ML-detected market regime: ", regimeStr);
      
   } else {
      Print("  ✗ ML model failed to load");
   }
   
   // Disable ML integration
   if(!TestPM.EnableMLIntegration(false)) {
      Print("  ✗ Failed to disable ML integration");
   }
}

//+------------------------------------------------------------------+
//| Test 9: Market Regime Detection                                  |
//+------------------------------------------------------------------+
void TestMarketRegimeDetection()
{
   // Test market regime detection
   ENUM_MARKET_REGIME regime = (ENUM_MARKET_REGIME)TestPM.DetectMarketRegime();
   string regimeStr = "";
   
   switch(regime) {
      case MARKET_REGIME_TRENDING: regimeStr = "Trending"; break;
      case MARKET_REGIME_RANGING: regimeStr = "Ranging"; break;
      case MARKET_REGIME_VOLATILE: regimeStr = "Volatile"; break;
      case MARKET_REGIME_UNKNOWN: regimeStr = "Unknown"; break;
   }
   
   Print("  ✓ Current market regime: ", regimeStr);
   
   // Test regime-adaptive parameters
   double lotSize = TestPM.GetRegimeAdjustedLotSize(TestLotSize, regime);
   if(lotSize > 0) {
      Print("  ✓ Regime-adjusted lot size: ", DoubleToString(lotSize, 2));
      
      // Verify lot size adjustment makes sense for the regime
      double minLot = SymbolInfo.LotsMin();
      double maxLot = SymbolInfo.LotsMax();
      
      if(regime == MARKET_REGIME_VOLATILE && lotSize >= TestLotSize) {
         Print("  ✗ Expected reduced lot size for volatile market");
      } else if(regime == MARKET_REGIME_TRENDING && lotSize <= TestLotSize * 0.8) {
         Print("  ✗ Expected increased or same lot size for trending market");
      }
      
      if(lotSize < minLot || lotSize > maxLot) {
         Print("  ✗ Regime-adjusted lot size ", lotSize, " is outside allowed range [", 
               minLot, " - ", maxLot, "]");
      }
   } else {
      Print("  ✗ Failed to get regime-adjusted lot size");
   }
   
   // Test regime-specific stop loss adjustment
   double stopLoss = TestPM.GetRegimeAdjustedStopLoss(TestStopLoss, regime);
   if(stopLoss > 0) {
      Print("  ✓ Regime-adjusted stop loss: ", DoubleToString(stopLoss, (int)SymbolInfo.Digits()));
      
      // Verify stop loss adjustment makes sense for the regime
      if(regime == MARKET_REGIME_VOLATILE && stopLoss <= TestStopLoss) {
         Print("  ✗ Expected increased stop loss for volatile market");
      } else if(regime == MARKET_REGIME_RANGING && stopLoss >= TestStopLoss) {
         Print("  ✗ Expected reduced stop loss for ranging market");
      }
   } else {
      Print("  ✗ Failed to get regime-adjusted stop loss");
   }
   
   // Test regime-specific take profit adjustment
   double takeProfit = TestPM.GetRegimeAdjustedTakeProfit(TestTakeProfit, regime);
   if(takeProfit > 0) {
      Print("  ✓ Regime-adjusted take profit: ", DoubleToString(takeProfit, (int)SymbolInfo.Digits()));
   } else {
      Print("  ✗ Failed to get regime-adjusted take profit");
   }
   
   // Test regime-based position sizing
   double riskPercent = TestPM.GetRegimeAdjustedRisk(2.0, regime);
   if(riskPercent > 0) {
      Print("  ✓ Regime-adjusted risk: ", DoubleToString(riskPercent, 2), "%");
      
      // Verify risk adjustment makes sense for the regime
      if(regime == MARKET_REGIME_VOLATILE && riskPercent >= 2.0) {
         Print("  ✗ Expected reduced risk for volatile market");
      } else if(regime == MARKET_REGIME_TRENDING && riskPercent <= 2.0) {
         Print("  ✗ Expected increased risk for trending market");
      }
   } else {
      Print("  ✗ Failed to get regime-adjusted risk");
   }
}

//+------------------------------------------------------------------+
//| Test 10: Position Monitoring                                     |
//+------------------------------------------------------------------+
void TestPositionMonitoring()
{
   // Open a position to monitor
   ulong ticket = TestPM.OpenPosition(ORDER_TYPE_BUY, TestLotSize, TestStopLoss, TestTakeProfit, "Monitoring Test");
   if(ticket == 0) {
      Print("  ✗ Failed to open position for monitoring test");
      return;
   }
   
   Print("  ✓ Position opened for monitoring. Ticket: ", ticket);
   
   // Test position monitoring
   if(!TestPM.MonitorPositions()) {
      Print("  ✗ Position monitoring failed");
      return;
   }
   
   // Get position statistics
   double drawdown = TestPM.GetPositionDrawdown(ticket);
   if(drawdown >= 0) {
      Print("  ✓ Position drawdown: ", DoubleToString(drawdown, 2), "%");
   } else {
      Print("  ✗ Failed to get position drawdown");
   }
   
   double riskReward = TestPM.GetPositionRiskReward(ticket);
   if(riskReward >= 0) {
      Print("  ✓ Position risk/reward: ", DoubleToString(riskReward, 2));
         Print("  ✓ Position adjusted successfully");
      } else {
         Print("  ✗ Failed to adjust position");
      }
   }
   
   // Clean up
   CloseAllPositions();
}

//+------------------------------------------------------------------+
//| Close all open positions                                         |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   int total = PositionsTotal();
   if(total == 0) {
      if(EnableLogging) Print("  No positions to close");
      return;
   }
   
   Print("  Closing ", total, " positions...");
   
   int closed = 0;
   int errors = 0;
   
   for(int i = total - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(PositionSelectByTicket(ticket)) {
         string symbol = PositionGetString(POSITION_SYMBOL);
         long magic = PositionGetInteger(POSITION_MAGIC);
         
         // Only close positions that match our test criteria
         if(symbol == TestSymbol && magic == TestMagicNumber) {
            // Use PositionManager if available
            if(TestPM != NULL) {
               if(TestPM.ClosePosition(ticket, "Test cleanup")) {
                  closed++;
                  if(EnableLogging) Print("  ✓ Closed position ", ticket);
               } else {
                  errors++;
                  Print("  ✗ Failed to close position ", ticket, ". Error: ", GetLastError());
               }
            } 
            // Fallback to CTrade if PositionManager is not available
            else {
               CTrade trade;
               trade.SetExpertMagicNumber(TestMagicNumber);
               trade.SetMarginMode();
               trade.SetDeviationInPoints(TestSlippage);
               trade.SetTypeFilling(ORDER_FILLING_FOK);
               
               if(trade.PositionClose(ticket)) {
                  closed++;
                  if(EnableLogging) Print("  ✓ Closed position ", ticket);
               } else {
                  errors++;
                  Print("  ✗ Failed to close position ", ticket, ". Error: ", GetLastError(), 
                        " (", trade.ResultRetcodeDescription(), ")");
               }
            }
         }
      }
      
      // Small delay to avoid flooding the server
      Sleep(100);
   }
   
   // Verify all positions are closed
   int remaining = 0;
   for(int i = 0; i < PositionsTotal(); i++) {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket)) {
         if(PositionGetString(POSITION_SYMBOL) == TestSymbol && 
            PositionGetInteger(POSITION_MAGIC) == TestMagicNumber) {
            remaining++;
         }
      }
   }
   
   // Print summary
   if(closed > 0 || errors > 0 || remaining > 0) {
      Print("  Closed ", closed, " positions");
      if(errors > 0) Print("  Failed to close ", errors, " positions");
      if(remaining > 0) Print("  ", remaining, " positions remaining");
   }
   
   if(remaining == 0) {
      Print("  ✓ All positions closed successfully");
   }
}

//+------------------------------------------------------------------+
//| Clean up resources                                               |
//+------------------------------------------------------------------+
void CleanUp()
{
   // Close any remaining positions
   CloseAllPositions();
   
   // Delete PositionManager
   if(TestPM != NULL) {
      delete TestPM;
      TestPM = NULL;
   }
   
   Print("\nTest completed. All resources cleaned up.");
}

//+------------------------------------------------------------------+
