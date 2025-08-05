//+------------------------------------------------------------------+
//|                                              TestMarketAnalyzer.mq5 |
//|                                  Copyright 2025, Your Company Name |
//|                                             https://www.yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company Name"
#property link      "https://www.yoursite.com"
#property version   "1.00"
#property script_show_inputs
#property strict

//--- Include required files
#include <Escape\MarketAnalyzer.mqh>
#include <Escape\NewsFeedHandler.mqh>
#include <Escape\VolatilityManager.mqh>

//--- Test configuration
input string InpTestSymbol = "XAUUSD";  // Symbol to test
input int    InpTestPeriod = 14;        // Period for volatility calculation
input int    InpTestShift = 0;          // Shift for volatility calculation

//--- Global variables
CVolatilityManager *volatilityManager = NULL;
CNewsFeedHandler *newsHandler = NULL;
CMarketAnalyzer *marketAnalyzer = NULL;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("=== Starting News Impact Analysis System Tests ===");
   
   // Initialize components
   if(!InitializeComponents())
   {
      Print("Failed to initialize test components");
      return;
   }
   
   // Run tests
   RunVolatilityTests();
   RunNewsFeedTests();
   RunMarketAnalyzerTests();
   
   // Clean up
   CleanUp();
   
   Print("=== News Impact Analysis System Tests Completed ===");
}

//+------------------------------------------------------------------+
//| Initialize test components                                       |
//+------------------------------------------------------------------+
bool InitializeComponents()
{
   // Initialize Volatility Manager
   volatilityManager = new CVolatilityManager();
   if(CheckPointer(volatilityManager) == POINTER_INVALID)
   {
      Print("Failed to create VolatilityManager");
      return false;
   }
   
   // Initialize News Feed Handler
   newsHandler = new CNewsFeedHandler();
   if(CheckPointer(newsHandler) == POINTER_INVALID)
   {
      Print("Failed to create NewsFeedHandler");
      return false;
   }
   
   // Initialize Market Analyzer with dependencies
   marketAnalyzer = new CMarketAnalyzer(newsHandler, volatilityManager);
   if(CheckPointer(marketAnalyzer) == POINTER_INVALID)
   {
      Print("Failed to create MarketAnalyzer");
      return false;
   }
   
   // Configure test symbol
   marketAnalyzer.AddAffectedSymbol(InpTestSymbol);
   
   return true;
}

//+------------------------------------------------------------------+
//| Run volatility-related tests                                     |
//+------------------------------------------------------------------+
void RunVolatilityTests()
{
   Print("\n--- Running Volatility Tests ---");
   
   // Test 1: Basic volatility calculation
   double volatility = volatilityManager.GetVolatility(InpTestSymbol, PERIOD_CURRENT, InpTestPeriod, InpTestShift);
   PrintFormat("Volatility for %s: %.5f", InpTestSymbol, volatility);
   
   // Test 2: Volatility state
   ENUM_VOLATILITY_STATE state = volatilityManager.GetVolatilityState(InpTestSymbol);
   PrintFormat("Volatility state: %s", EnumToString(state));
   
   // Test 3: Volatility-based position sizing
   double positionSize = volatilityManager.GetVolatilityAdjustedPositionSize(InpTestSymbol, 1.0);
   PrintFormat("Volatility-adjusted position size: %.2f lots", positionSize);
}

//+------------------------------------------------------------------+
//| Run news feed tests                                              |
//+------------------------------------------------------------------+
void RunNewsFeedTests()
{
   Print("\n--- Running News Feed Tests ---");
   
   // Test 1: Get upcoming news
   datetime from = TimeCurrent();
   datetime to = from + 86400; // Next 24 hours
   int count = newsHandler.GetUpcomingNewsCount(from, to);
   PrintFormat("Found %d news events in the next 24 hours", count);
   
   // Test 2: Check for high-impact news
   bool hasHighImpactNews = newsHandler.HasHighImpactNews(from, to, InpTestSymbol);
   PrintFormat("High impact news for %s: %s", InpTestSymbol, hasHighImpactNews ? "Yes" : "No");
   
   // Test 3: Get news impact score
   double impactScore = newsHandler.GetNewsImpactScore(InpTestSymbol, from, to);
   PrintFormat("News impact score for %s: %.2f", InpTestSymbol, impactScore);
}

//+------------------------------------------------------------------+
//| Run market analyzer tests                                        |
//+------------------------------------------------------------------+
void RunMarketAnalyzerTests()
{
   Print("\n--- Running Market Analyzer Tests ---");
   
   // Test 1: Check if trading is allowed
   bool isTradingAllowed = marketAnalyzer.IsTradingAllowed(InpTestSymbol);
   PrintFormat("Trading allowed for %s: %s", InpTestSymbol, isTradingAllowed ? "Yes" : "No");
   
   // Test 2: Get market condition
   ENUM_MARKET_CONDITION condition = marketAnalyzer.GetMarketCondition(InpTestSymbol);
   PrintFormat("Market condition: %s", EnumToString(condition));
   
   // Test 3: Get recommended position size
   double riskPercent = 1.0; // 1% risk
   double positionSize = marketAnalyzer.GetRecommendedPositionSize(InpTestSymbol, riskPercent);
   PrintFormat("Recommended position size (%.1f%% risk): %.2f lots", riskPercent, positionSize);
   
   // Test 4: Get news impact analysis
   string analysis = marketAnalyzer.GetNewsImpactAnalysis(InpTestSymbol);
   Print("News Impact Analysis:", analysis);
}

//+------------------------------------------------------------------+
//| Clean up test resources                                          |
//+------------------------------------------------------------------+
void CleanUp()
{
   if(CheckPointer(marketAnalyzer) != POINTER_INVALID)
      delete marketAnalyzer;
      
   if(CheckPointer(newsHandler) != POINTER_INVALID)
      delete newsHandler;
      
   if(CheckPointer(volatilityManager) != POINTER_INVALID)
      delete volatilityManager;
      
   marketAnalyzer = NULL;
   newsHandler = NULL;
   volatilityManager = NULL;
}

//+------------------------------------------------------------------+
//| Custom assertion function                                        |
//+------------------------------------------------------------------+
bool Assert(bool condition, string message)
{
   if(!condition)
   {
      Print("ASSERTION FAILED: ", message);
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Custom test function                                             |
//+------------------------------------------------------------------+
void RunTest(string testName, void (*testFunction)())
{
   PrintFormat("\nRunning test: %s", testName);
   testFunction();
   PrintFormat("Test %s completed", testName);
}
//+------------------------------------------------------------------+
