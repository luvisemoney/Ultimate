//+------------------------------------------------------------------+
//|                                                 TestPaperTrading.mq5 |
//|                                  Copyright 2025, Your Company Name |
//|                                             https://www.yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company Name"
#property link      "https://www.yoursite.com"
#property version   "1.00"
#property strict
#property script_show_inputs

// Include PaperTrading component
#include <Escape\PaperTrading.mqh>

// Input parameters
input double InpInitialBalance = 10000.0;  // Initial paper balance
input int    InpNumTrades = 10;           // Number of test trades
input double InpLotSize = 0.1;             // Lot size for test trades
input int    InpStopLoss = 100;            // Stop loss in points
input int    InpTakeProfit = 200;          // Take profit in points
input bool   InpRandomEntries = true;      // Use random entry points

// Global variables
CPaperTrading paperTrading;
CSymbolInfo  *symbolInfo;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   // Initialize symbol info
   symbolInfo = new CSymbolInfo();
   if(symbolInfo == NULL) {
      Print("Failed to create symbol info");
      return;
   }
   
   if(!symbolInfo.Name(_Symbol)) {
      Print("Failed to set symbol");
      delete symbolInfo;
      return;
   }
   
   // Initialize paper trading
   if(!paperTrading.Initialize(symbolInfo, InpInitialBalance)) {
      Print("Failed to initialize paper trading");
      delete symbolInfo;
      return;
   }
   
   // Run tests
   RunPaperTradingTests();
   
   // Clean up
   paperTrading.Deinitialize();
   delete symbolInfo;
   
   Print("\n=== Paper Trading Test Complete ===");
}

//+------------------------------------------------------------------+
//| Run paper trading tests                                         |
//+------------------------------------------------------------------+
void RunPaperTradingTests()
{
   Print("\n=== Starting Paper Trading Tests ===");
   PrintFormat("Initial Balance: $%.2f", InpInitialBalance);
   PrintFormat("Number of Trades: %d", InpNumTrades);
   PrintFormat("Lot Size: %.2f", InpLotSize);
   Print("------------------------------------");
   
   // Test 1: Open and close trades
   Print("\nTest 1: Opening and Closing Trades");
   TestOpenCloseTrades();
   
   // Test 2: Test stop loss execution
   Print("\nTest 2: Stop Loss Execution");
   TestStopLossExecution();
   
   // Test 3: Test take profit execution
   Print("\nTest 3: Take Profit Execution");
   TestTakeProfitExecution();
   
   // Test 4: Test partial fills
   Print("\nTest 4: Partial Fills");
   TestPartialFills();
   
   // Test 5: Test margin requirements
   Print("\nTest 5: Margin Requirements");
   TestMarginRequirements();
   
   // Print final statistics
   Print("\n=== Test Results ===");
   PrintFormat("Final Balance: $%.2f", paperTrading.GetBalance());
   PrintFormat("Equity: $%.2f", paperTrading.GetEquity());
   PrintFormat("Total Trades: %d", paperTrading.GetTotalTrades());
   PrintFormat("Winning Trades: %d (%.1f%%)", 
              paperTrading.GetWinningTrades(),
              paperTrading.GetWinRate());
   PrintFormat("Losing Trades: %d", paperTrading.GetLosingTrades());
   PrintFormat("Max Drawdown: $%.2f (%.1f%%)",
              paperTrading.GetMaxDrawdown(),
              (InpInitialBalance - paperTrading.GetMaxDrawdown()) / InpInitialBalance * 100);
}

//+------------------------------------------------------------------+
//| Test opening and closing trades                                 |
//+------------------------------------------------------------------+
void TestOpenCloseTrades()
{
   Print("  Testing basic trade operations...");
   
   // Open a buy position
   double openPrice = symbolInfo.Ask();
   double sl = openPrice - InpStopLoss * _Point;
   double tp = openPrice + InpTakeProfit * _Point;
   
   if(paperTrading.OpenPosition(ORDER_TYPE_BUY, InpLotSize, openPrice, sl, tp)) {
      Print("  Buy order opened successfully");
      
      // Check position is open
      if(paperTrading.GetOpenPositions() > 0) {
         Print("  Position is open");
         
         // Close position
         if(paperTrading.CloseAllPositions(symbolInfo.Bid())) {
            Print("  Position closed successfully");
         } else {
            Print("  Failed to close position");
         }
      } else {
         Print("  No open positions found");
      }
   } else {
      Print("  Failed to open buy order");
   }
   
   // Test with sell order
   openPrice = symbolInfo.Bid();
   sl = openPrice + InpStopLoss * _Point;
   tp = openPrice - InpTakeProfit * _Point;
   
   if(paperTrading.OpenPosition(ORDER_TYPE_SELL, InpLotSize, openPrice, sl, tp)) {
      Print("  Sell order opened successfully");
      
      // Close position
      if(paperTrading.CloseAllPositions(symbolInfo.Ask())) {
         Print("  Position closed successfully");
      }
   } else {
      Print("  Failed to open sell order");
   }
}

//+------------------------------------------------------------------+
//| Test stop loss execution                                        |
//+------------------------------------------------------------------+
void TestStopLossExecution()
{
   Print("  Testing stop loss execution...");
   
   // Open a position with tight stop loss
   double openPrice = symbolInfo.Ask();
   double sl = openPrice - 10 * _Point;  // Very tight stop loss
   double tp = openPrice + 100 * _Point; // Far take profit
   
   if(paperTrading.OpenPosition(ORDER_TYPE_BUY, InpLotSize, openPrice, sl, tp)) {
      Print("  Position opened, waiting for stop loss...");
      
      // Simulate price moving down to trigger stop loss
      double currentPrice = openPrice - 15 * _Point;
      paperTrading.UpdatePrices(currentPrice);
      
      // Check if position was closed by stop loss
      if(paperTrading.GetOpenPositions() == 0) {
         Print("  Stop loss triggered successfully");
      } else {
         Print("  Stop loss not triggered");
      }
   }
}

//+------------------------------------------------------------------+
//| Test take profit execution                                      |
//+------------------------------------------------------------------+
void TestTakeProfitExecution()
{
   Print("  Testing take profit execution...");
   
   // Open a position with tight take profit
   double openPrice = symbolInfo.Ask();
   double sl = openPrice - 100 * _Point; // Far stop loss
   double tp = openPrice + 10 * _Point;  // Very tight take profit
   
   if(paperTrading.OpenPosition(ORDER_TYPE_BUY, InpLotSize, openPrice, sl, tp)) {
      Print("  Position opened, waiting for take profit...");
      
      // Simulate price moving up to trigger take profit
      double currentPrice = openPrice + 15 * _Point;
      paperTrading.UpdatePrices(currentPrice);
      
      // Check if position was closed by take profit
      if(paperTrading.GetOpenPositions() == 0) {
         Print("  Take profit triggered successfully");
      } else {
         Print("  Take profit not triggered");
      }
   }
}

//+------------------------------------------------------------------+
//| Test partial fills                                              |
//+------------------------------------------------------------------+
void TestPartialFills()
{
   Print("  Testing partial fills...");
   
   // Enable partial fills for this test
   paperTrading.EnablePartialFills(true);
   
   // Open a large position that might be partially filled
   double openPrice = symbolInfo.Ask();
   double sl = openPrice - 50 * _Point;
   double tp = openPrice + 100 * _Point;
   
   if(paperTrading.OpenPosition(ORDER_TYPE_BUY, 10.0, openPrice, sl, tp)) {
      Print("  Large order submitted, checking for partial fills...");
      
      // In a real test, we would check the order book and simulate partial fills
      // For now, we'll just check if the position was opened with reduced size
      if(paperTrading.GetOpenPositions() > 0) {
         Print("  Position opened (possibly with partial fill)");
      }
   }
   
   // Clean up
   paperTrading.CloseAllPositions(symbolInfo.Bid());
   paperTrading.EnablePartialFills(false);
}

//+------------------------------------------------------------------+
//| Test margin requirements                                        |
//+------------------------------------------------------------------+
void TestMarginRequirements()
{
   Print("  Testing margin requirements...");
   
   // Try to open a position that's too large for the account
   double balance = paperTrading.GetBalance();
   double marginRequired = 0.0;
   
   // Calculate required margin for a very large position
   double lotSize = 1000.0; // Very large lot size
   double openPrice = symbolInfo.Ask();
   
   // In a real implementation, we would calculate margin based on symbol specs
   marginRequired = lotSize * symbolInfo.MarginRequired();
   
   if(marginRequired > balance) {
      Print("  Testing margin rejection (expected to fail)...");
      
      if(!paperTrading.OpenPosition(ORDER_TYPE_BUY, lotSize, openPrice, 0, 0)) {
         Print("  Margin check passed: Position rejected due to insufficient margin");
      } else {
         Print("  WARNING: Position opened despite insufficient margin!");
      }
   }
}
