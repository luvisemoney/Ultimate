//+------------------------------------------------------------------+
//|                                             TestRiskManager.mq5 |
//|                                          Copyright 2025, EscapeEA |
//|                                             https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "2.10"
#property script_show_inputs
#property strict

// Include necessary headers
#include <Escape/RiskManager.mqh>
#include <Trade/Trade.mqh>
#include <Arrays/ArrayObj.mqh>

// Test configuration
input string   InpSymbol = "";              // Test symbol (empty for current)
input double   InpAccountBalance = 10000.0;  // Test account balance
input int      InpTestIterations = 100;      // Number of test iterations

// Test results structure
struct TestResult {
   string testName;
   bool   passed;
   string message;
   double executionTime; // in milliseconds
};

// Global variables
CRiskManager *riskManager = NULL;
CArrayObj    *testResults = NULL;
CTrade       *trade = NULL;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   string symbol = (InpSymbol == "") ? _Symbol : InpSymbol;
   
   // Initialize test environment
   if(!InitializeTestEnvironment(symbol)) {
      Print("Failed to initialize test environment");
      return;
   }
   
   // Run test suites
   RunPositionSizingTests(symbol);
   RunRiskManagementTests(symbol);
   RunIntegrationTests(symbol);
   
   // Print test summary
   PrintTestSummary();
   
   // Clean up
   CleanUp();
}

//+------------------------------------------------------------------+
//| Initialize test environment                                      |
//+------------------------------------------------------------------+
bool InitializeTestEnvironment(const string symbol)
{
   // Initialize test results collection
   testResults = new CArrayObj();
   if(testResults == NULL) {
      Print("Failed to create test results collection");
      return false;
   }
   
   // Initialize trade object
   trade = new CTrade();
   if(trade == NULL) {
      Print("Failed to create CTrade instance");
      return false;
   }
   
   // Initialize risk manager with test parameters
   riskManager = new CRiskManager();
   if(riskManager == NULL) {
      Print("Failed to create RiskManager instance");
      return false;
   }
   
   // Configure risk parameters
   riskManager.SetRiskParameters(2.0, 5.0, 10, 50);
   riskManager.SetPositionSizingMethod(POSITION_SIZING_RISK_BASED);
   riskManager.SetPositionScaling(SCALING_NONE);
   riskManager.SetPositionSizeLimits(0.01, 10.0, 0.01);
   
   // Set test account balance
   AccountInfoDouble(ACCOUNT_BALANCE, InpAccountBalance);
   
   Print("Test Environment Initialized");
   Print("Symbol: ", symbol);
   Print("Account Balance: $", DoubleToString(InpAccountBalance, 2));
   Print("Test Iterations: ", InpTestIterations);
   Print("\nStarting Tests...\n");
   
   return true;
}

//+------------------------------------------------------------------+
//| Run position sizing tests                                        |
//+------------------------------------------------------------------+
void RunPositionSizingTests(const string symbol)
{
   double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double stopLoss = price * 0.99; // 1% stop loss
   double riskAmount = InpAccountBalance * 0.01; // 1% of account
   
   // Test 1: Basic position sizing
   riskManager.SetPositionSizingMethod(POSITION_SIZING_RISK_BASED);
   double lotSize = riskManager.CalculatePositionSize(symbol, price, stopLoss, riskAmount);
   
   TestResult result = {"Basic Position Sizing", 
                       lotSize > 0, 
                       StringFormat("Lot size: %.2f", lotSize), 
                       0};
   AddTestResult(result);
   
   // Test 2: Volatility-based sizing
   riskManager.SetPositionSizingMethod(POSITION_SIZING_VOLATILITY);
   lotSize = riskManager.CalculatePositionSize(symbol, price, stopLoss, riskAmount);
   
   result = {"Volatility-Based Sizing", 
            lotSize > 0, 
            StringFormat("Lot size: %.2f", lotSize), 
            0};
   AddTestResult(result);
   
   // Test 3: Kelly Criterion
   riskManager.SetPositionSizingMethod(POSITION_SIZING_KELLY);
   riskManager.SetKellyFraction(0.5); // Use half-Kelly for safety
   lotSize = riskManager.CalculatePositionSize(symbol, price, stopLoss, riskAmount);
   
   result = {"Kelly Criterion Sizing", 
            lotSize >= 0, 
            StringFormat("Lot size: %.2f", lotSize), 
            0};
   AddTestResult(result);
   
   // Test 4: Position size limits
   riskManager.SetPositionSizingMethod(POSITION_SIZING_RISK_BASED);
   riskManager.SetPositionSizeLimits(0.1, 1.0);
   lotSize = riskManager.CalculatePositionSize(symbol, price, stopLoss * 0.5, riskAmount * 10);
   
   result = {"Position Size Limits", 
            lotSize >= 0.1 && lotSize <= 1.0, 
            StringFormat("Lot size: %.2f (should be between 0.1 and 1.0)", lotSize), 
            0};
   AddTestResult(result);
}

//+------------------------------------------------------------------+
//| Run risk management tests                                        |
//+------------------------------------------------------------------+
void RunRiskManagementTests(const string symbol)
{
   double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double stopLoss = price * 0.99;
   double takeProfit = price * 1.02;
   
   // Test 1: Daily loss limit
   riskManager.ResetDailyMetrics();
   double dailyLoss = InpAccountBalance * 0.06; // 6% loss
   
   // Simulate a losing trade
   if(riskManager.CheckTradeRisk(symbol, 1.0, price, stopLoss, takeProfit, ORDER_TYPE_BUY)) {
      // Process the trade
      riskManager.OnTradeOpen(12345, symbol, ORDER_TYPE_BUY, 1.0, price, stopLoss, takeProfit);
      riskManager.OnTradeClose(12345, symbol, ORDER_TYPE_BUY, 1.0, stopLoss, 0, 0);
   }
   
   bool dailyLimitHit = !riskManager.CheckDailyLossLimit();
   
   TestResult result = {"Daily Loss Limit", 
                       dailyLimitHit, 
                       dailyLimitHit ? "Daily loss limit triggered" : "Daily loss limit not triggered", 
                       0};
   AddTestResult(result);
   
   // Test 2: Maximum open trades
   riskManager.ResetDailyMetrics();
   int maxTrades = 5;
   riskManager.SetMaxOpenTrades(maxTrades);
   
   // Open max trades
   for(int i = 0; i < maxTrades; i++) {
      riskManager.OnTradeOpen(1000 + i, symbol, ORDER_TYPE_BUY, 0.1, price, stopLoss, takeProfit);
   }
   
   bool maxTradesEnforced = !riskManager.CheckTradeRisk(symbol, 0.1, price, stopLoss, takeProfit, ORDER_TYPE_BUY);
   
   result = {"Max Open Trades", 
            maxTradesEnforced, 
            maxTradesEnforced ? "Max trades limit enforced" : "Max trades limit not enforced", 
            0};
   AddTestResult(result);
}

//+------------------------------------------------------------------+
//| Run integration tests                                            |
//+------------------------------------------------------------------+
void RunIntegrationTests(const string symbol)
{
   // Test 1: Position sizing with different account balances
   double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double stopLoss = price * 0.99;
   double riskAmount = InpAccountBalance * 0.02; // 2% risk
   
   double size1 = riskManager.CalculatePositionSize(symbol, price, stopLoss, riskAmount);
   
   // Double the account balance
   AccountInfoDouble(ACCOUNT_BALANCE, InpAccountBalance * 2);
   double size2 = riskManager.CalculatePositionSize(symbol, price, stopLoss, riskAmount * 2);
   
   bool scalingCorrect = MathAbs(size2 - size1 * 2) < 0.01; // Allow small floating point differences
   
   TestResult result = {"Position Size Scaling", 
                       scalingCorrect, 
                       StringFormat("Size1: %.2f, Size2: %.2f (expected ~2x)", size1, size2), 
                       0};
   AddTestResult(result);
   
   // Reset account balance
   AccountInfoDouble(ACCOUNT_BALANCE, InpAccountBalance);
}

//+------------------------------------------------------------------+
//| Add test result to collection                                    |
//+------------------------------------------------------------------+
void AddTestResult(const TestResult &result)
{
   CObject *obj = new TestResult();
   if(obj == NULL) return;
   
   TestResult *res = obj;
   res.testName = result.testName;
   res.passed = result.passed;
   res.message = result.message;
   res.executionTime = result.executionTime;
   
   testResults.Add(obj);
   
   // Print immediate result
   string status = result.passed ? "PASSED" : "FAILED";
   PrintFormat("[%s] %s - %s", status, result.testName, result.message);
}

//+------------------------------------------------------------------+
//| Print test summary                                               |
//+------------------------------------------------------------------+
void PrintTestSummary()
{
   int total = testResults.Total();
   int passed = 0;
   
   Print("\n=== Test Summary ===");
   
   for(int i = 0; i < total; i++) {
      TestResult *result = testResults.At(i);
      if(result == NULL) continue;
      
      if(result.passed) passed++;
      
      PrintFormat("%d. %-30s: %s", 
                 i + 1, 
                 result.testName, 
                 result.passed ? "PASSED" : "FAILED");
   }
   
   double passRate = (double)passed / total * 100.0;
   PrintFormat("\nTests: %d, Passed: %d, Failed: %d, Success Rate: %.1f%%", 
              total, passed, total - passed, passRate);
   
   if(passRate < 100.0) {
      Print("\nFailed tests:");
      for(int i = 0; i < total; i++) {
         TestResult *result = testResults.At(i);
         if(result == NULL || result.passed) continue;
         PrintFormat("- %s: %s", result.testName, result.message);
      }
   }
}

//+------------------------------------------------------------------+
//| Clean up test environment                                        |
//+------------------------------------------------------------------+
void CleanUp()
{
   if(riskManager != NULL) {
      delete riskManager;
      riskManager = NULL;
   }
   
   if(trade != NULL) {
      delete trade;
      trade = NULL;
   }
   
   if(testResults != NULL) {
      testResults.Clear();
      delete testResults;
      testResults = NULL;
   }
}
