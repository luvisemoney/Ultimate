//+------------------------------------------------------------------+
//|                                              TestRiskManager.mq5 |
//|                                      Copyright 2025, EscapeEA     |
//|                                          https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"
#property script_show_inputs
#property script_show_confirm

// Required includes
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Math\Stat\Math.mqh>
#include "..\Include\Core\AdvancedRiskManager.mqh"
#include "..\Include\Common\Enums.mqh"

// Test configuration
#define TEST_MAGIC_NUMBER 12345
#define TEST_INITIAL_BALANCE 10000.0
#define TEST_SYMBOL1 "EURUSD"
#define TEST_SYMBOL2 "GBPUSD"

// Input parameters
input string InpSymbol = TEST_SYMBOL1;          // Symbol to test
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_D1; // Timeframe for testing
input double InpRiskPerTrade = 1.0;            // Risk per trade (% of balance)
input double InpMaxDailyDrawdown = 5.0;        // Max daily drawdown (%)
input double InpMaxPositionRisk = 2.0;         // Max position risk (%)
input double InpMaxCorrelation = 0.7;          // Max allowed correlation
input double InpVolatilityThreshold = 0.02;    // Volatility threshold
input int InpTestBars = 100;                   // Number of bars to test
input bool InpVerbose = true;                  // Show detailed output

// Global variables
CAdvancedRiskManager *riskManager = NULL;
CTrade trade;
CPositionInfo positionInfo;
double initialBalance = TEST_INITIAL_BALANCE;  // Starting balance for testing

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("\n=== Starting Risk Manager Test ===\n");
   
   // Check if symbol is available
   if(!SymbolSelect(InpSymbol, true))
     {
      PrintFormat("Symbol %s is not available in Market Watch", InpSymbol);
      return;
     }

   // Initialize risk manager
   riskManager = new CAdvancedRiskManager();
   if(riskManager == NULL || !riskManager.Initialize(InpRiskPerTrade, InpMaxDailyDrawdown, 
                                                   InpMaxPositionRisk, InpMaxCorrelation, 
                                                   InpVolatilityThreshold))
     {
      Print("Failed to initialize risk manager");
      SafeDelete(riskManager);
      return;
     }
   
   // Set up trading environment
   trade.SetExpertMagicNumber(TEST_MAGIC_NUMBER);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(InpSymbol);
   
   // Verify symbol properties
   if(!SymbolInfoInteger(InpSymbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_DISABLED)
     {
      PrintFormat("Trading is disabled for symbol %s", InpSymbol);
      SafeDelete(riskManager);
      return;
     }
   
   // Run tests
   TestPositionSizing();
   TestDrawdownProtection();
   TestVolatilityProtection();
   TestCorrelationProtection();
   
   // Clean up
   SafeDelete(riskManager);
   
   Print("\n=== Risk Manager Test Complete ===\n");
  }

//+------------------------------------------------------------------+
//| Test position sizing functionality                              |
//+------------------------------------------------------------------+
void TestPositionSizing()
  {
   Print("\n=== Testing Position Sizing ===");
   
   double entryPrice = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
   double stopLoss = entryPrice * 0.99;  // 1% stop loss
   
   double lots = riskManager.GetOptimalLots(InpSymbol, stopLoss, entryPrice);
   double positionValue = lots * SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_CONTRACT_SIZE) * entryPrice;
   double riskAmount = initialBalance * (InpRiskPerTrade / 100.0);
   
   PrintFormat("Entry Price: %.5f, Stop Loss: %.5f", entryPrice, stopLoss);
   PrintFormat("Optimal Lots: %.2f, Position Value: $%.2f", lots, positionValue);
   PrintFormat("Risk Amount: $%.2f (%.1f%% of balance)", riskAmount, InpRiskPerTrade);
   
   // Verify position size is within expected range
   double expectedLots = riskAmount / (entryPrice - stopLoss) / 
                        SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_CONTRACT_SIZE);
   expectedLots = NormalizeDouble(expectedLots, 2);
   
   if(MathAbs(lots - expectedLots) < 0.01)
      Print("Position Sizing: \x1B[32mPASSED\x1B[0m");
   else
      PrintFormat("Position Sizing: \x1B[31mFAILED\x1B[0m (Expected: %.2f, Got: %.2f)", 
                 expectedLots, lots);
  }

//+------------------------------------------------------------------+
//| Test drawdown protection                                        |
//+------------------------------------------------------------------+
void TestDrawdownProtection()
  {
   Print("\n=== Testing Drawdown Protection ===");
   
   // Simulate a series of losing trades to trigger drawdown protection
   double currentBalance = initialBalance;
   double dailyHigh = initialBalance;
   bool drawdownTriggered = false;
   
   for(int i = 0; i < 10; i++)
     {
      // Simulate a losing trade (1% of balance)
      double loss = currentBalance * 0.01;
      currentBalance -= loss;
      
      // Update daily high
      if(currentBalance > dailyHigh)
         dailyHigh = currentBalance;
      
      // Check drawdown
      double drawdown = (dailyHigh - currentBalance) / dailyHigh * 100.0;
      
      if(drawdown > InpMaxDailyDrawdown)
        {
         drawdownTriggered = true;
         PrintFormat("Drawdown protection triggered at %.2f%% (Max: %.2f%%)", 
                    drawdown, InpMaxDailyDrawdown);
         break;
        }
     }
   
   if(drawdownTriggered)
      Print("Drawdown Protection: \x1B[32mPASSED\x1B[0m");
   else
      Print("Drawdown Protection: \x1B[31mFAILED\x1B[0m (Drawdown not triggered)");
  }

//+------------------------------------------------------------------+
//| Test volatility protection                                      |
//+------------------------------------------------------------------+
void TestVolatilityProtection()
  {
   Print("\n=== Testing Volatility Protection ===");
   
   // Check if symbol is selected
   if(!SymbolSelect(InpSymbol, true))
     {
      PrintFormat("Symbol %s is not available in Market Watch", InpSymbol);
      return;
     }
   
   // Get ATR for volatility measurement
   double atr[];
   int atrHandle = iATR(InpSymbol, InpTimeframe, 14);
   
   if(atrHandle == INVALID_HANDLE)
     {
      Print("Failed to get ATR handle");
      return;
     }
   
   // Ensure we have enough data
   int barsNeeded = 14 + 1; // ATR period + 1 for calculation
   if(Bars(InpSymbol, InpTimeframe) < barsNeeded)
     {
      PrintFormat("Not enough bars for ATR calculation. Need %d, have %d", 
                 barsNeeded, Bars(InpSymbol, InpTimeframe));
      IndicatorRelease(atrHandle);
      return;
     }
   
   // Copy ATR values with error checking
   int copied = CopyBuffer(atrHandle, 0, 0, InpTestBars, atr);
   
   // Always release the indicator handle when done
   IndicatorRelease(atrHandle);
   
   if(copied <= 0)
     {
      Print("Failed to copy ATR data. Error: ", GetLastError());
      return;
     }
   
   // Check if we have valid ATR data
   if(ArraySize(atr) == 0 || atr[0] <= 0)
     {
      Print("Invalid ATR data");
      return;
     }
   
   // Get current price with error checking
   double currentPrice = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
   if(currentPrice <= 0)
     {
      Print("Invalid current price");
      return;
     }
   
   // Calculate volatility (ATR as percentage of price)
   double volatility = atr[0] / currentPrice;
   
   // Print results with color coding
   string volatilityStr = StringFormat("%.4f", volatility);
   string thresholdStr = StringFormat("%.4f", InpVolatilityThreshold);
   
   PrintFormat("Current Volatility (ATR/Price): %s (Threshold: %s)", 
              volatilityStr, thresholdStr);
   
   if(volatility > InpVolatilityThreshold)
      Print("Volatility Protection: \x1B[32mPASSED\x1B[0m (High volatility detected)");
   else
      Print("Volatility Protection: \x1B[33mWARNING\x1B[0m (Low volatility, test may not be conclusive)");
  }

//+------------------------------------------------------------------+
//| Test correlation protection                                     |
//+------------------------------------------------------------------+
void TestCorrelationProtection()
  {
   Print("\n=== Testing Correlation Protection ===");
   
   // Use input symbol as first symbol, and a correlated pair as second
   string symbol1 = InpSymbol;
   string symbol2 = (StringSubstr(symbol1, 0, 3) == "EUR") ? "GBPUSD" : "EURUSD";
   
   // Ensure symbols are selected in Market Watch
   if(!SymbolSelect(symbol1, true) || !SymbolSelect(symbol2, true))
     {
      PrintFormat("One or both symbols (%s, %s) are not available in Market Watch", symbol1, symbol2);
      return;
     }
   
   // Determine how many bars to use (minimum of available bars for both symbols)
   int bars1 = Bars(symbol1, InpTimeframe);
   int bars2 = Bars(symbol2, InpTimeframe);
   int barsToUse = MathMin(MathMin(bars1, bars2), InpTestBars);
   
   if(barsToUse < 10)
     {
      PrintFormat("Not enough data for correlation test. Need at least 10 bars, have %d", barsToUse);
      return;
     }
   
   // Get close prices for correlation calculation
   double close1[], close2[];
   ArraySetAsSeries(close1, true);
   ArraySetAsSeries(close2, true);
   
   int copied1 = CopyClose(symbol1, InpTimeframe, 0, barsToUse, close1);
   int copied2 = CopyClose(symbol2, InpTimeframe, 0, barsToUse, close2);
   
   if(copied1 != copied2 || copied1 < 10)
     {
      PrintFormat("Data copy failed. %s: %d bars, %s: %d bars", 
                 symbol1, copied1, symbol2, copied2);
      return;
     }
   
   // Calculate correlation
   double correlation = CalculateCorrelation(close1, close2, copied1);
   
   // Print results with color coding
   string corrStr = StringFormat("%.4f", correlation);
   string maxCorrStr = StringFormat("%.2f", InpMaxCorrelation);
   
   PrintFormat("Correlation between %s and %s: %s (Max allowed: %s)", 
              symbol1, symbol2, corrStr, maxCorrStr);
   
   if(correlation > InpMaxCorrelation)
      Print("Correlation Protection: \x1B[32mPASSED\x1B[0m (High correlation detected)");
   else
      Print("Correlation Protection: \x1B[33mWARNING\x1B[0m (Low correlation, test may not be conclusive)");
  }

//+------------------------------------------------------------------+
//| Calculate correlation between two price series                  |
//+------------------------------------------------------------------+
double CalculateCorrelation(const double &series1[], const double &series2[], int count)
  {
   // Use the minimum of array sizes to prevent out-of-bounds access
   int minCount = MathMin(MathMin(ArraySize(series1), ArraySize(series2)), count);
   
   if(minCount < 2)
     {
      if(InpVerbose) Print("Not enough data points for correlation calculation");
      return 0.0;
     }
   
   // Calculate means
   double mean1 = 0.0, mean2 = 0.0;
   for(int i = 0; i < minCount; i++)
     {
      mean1 += series1[i];
      mean2 += series2[i];
     }
   mean1 /= minCount;
   mean2 /= minCount;
   
   // Calculate covariance and variances
   double cov = 0.0, var1 = 0.0, var2 = 0.0;
   for(int i = 0; i < minCount; i++)
     {
      double diff1 = series1[i] - mean1;
      double diff2 = series2[i] - mean2;
      cov += diff1 * diff2;
      var1 += diff1 * diff1;
      var2 += diff2 * diff2;
     }
   
   // Calculate correlation coefficient
   if(var1 == 0.0 || var2 == 0.0)
     {
      if(InpVerbose) Print("Variance is zero, cannot calculate correlation");
      return 0.0;
     }
   
   double correlation = cov / MathSqrt(var1 * var2);
   return NormalizeDouble(correlation, 4); // Return normalized correlation
  }

//+------------------------------------------------------------------+
//| Safely delete a pointer and set it to NULL                      |
//+------------------------------------------------------------------+
void SafeDelete(CObject *&obj)
  {
   if(CheckPointer(obj) != POINTER_INVALID)
     {
      delete obj;
      obj = NULL;
     }
  }
//+------------------------------------------------------------------+
