//+------------------------------------------------------------------+
//|                                            TestTradeExecutor.mq5 |
//|                                  Copyright 2025, EscapeEA        |
//|                                             https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include <..\Include\Core\TradeExecutor.mqh>

//--- Input parameters
input bool   InpTestLiveMode = false;  // Test in live mode
input string InpTestSymbol = "EURUSD";  // Test symbol
input double InpTestLots = 0.1;         // Test volume
input int    InpTestMagic = 12345;      // Test magic number

//--- Global variables
CTradeExecutor *executor;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Create trade executor instance
   executor = new CTradeExecutor(InpTestMagic, InpTestLiveMode, InpTestSymbol);
   
   if(executor == NULL)
     {
      Print("Failed to create trade executor");
      return INIT_FAILED;
     }
   
   Print("Trade Executor Test Initialized");
   Print("Symbol: ", executor.Symbol());
   Print("Magic: ", executor.Magic());
   Print("Live Mode: ", executor.IsLive() ? "Yes" : "No");
   Print("Slippage: ", executor.Slippage());
   
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(executor) != POINTER_INVALID)
      delete executor;
      
   Print("Trade Executor Test Deinitialized");
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   static bool tested = false;
   
   // Run test once
   if(!tested)
     {
      TestTradeExecutor();
      tested = true;
     }
  }

//+------------------------------------------------------------------+
//| Test trade executor functionality                                |
//+------------------------------------------------------------------+
void TestTradeExecutor()
  {
   Print("\n=== Starting Trade Executor Tests ===");
   
   // Test 1: Open a position
   double ask = SymbolInfoDouble(InpTestSymbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(InpTestSymbol, SYMBOL_BID);
   double sl = bid - 100 * _Point;
   double tp = ask + 200 * _Point;
   
   Print("\nTest 1: Opening BUY position");
   if(executor.OpenPosition(ORDER_TYPE_BUY, InpTestLots, sl, tp, "Test Buy"))
      Print("  - OpenPosition: SUCCESS");
   else
      Print("  - OpenPosition: FAILED");
   
   // Test 2: Get open positions count
   int count = executor.GetOpenPositionsCount();
   Print("\nTest 2: Open positions count = ", count);
   
   // Test 3: Get open positions profit
   double profit = executor.GetOpenPositionsProfit();
   Print("Test 3: Open positions profit = ", profit);
   
   // Test 4: Modify position
   if(count > 0)
     {
      // Get position ticket
      CPositionInfo pos;
      if(pos.SelectByIndex(0))
        {
         ulong ticket = pos.Ticket();
         double newSl = pos.PriceOpen() - 50 * _Point;
         double newTp = pos.PriceOpen() + 150 * _Point;
         
         Print("\nTest 4: Modifying position ", ticket);
         if(executor.ModifyPosition(ticket, newSl, newTp))
            Print("  - ModifyPosition: SUCCESS");
         else
            Print("  - ModifyPosition: FAILED");
            
         // Test 5: Close position
         Print("\nTest 5: Closing position ", ticket);
         if(executor.ClosePosition(ticket))
            Print("  - ClosePosition: SUCCESS");
         else
            Print("  - ClosePosition: FAILED");
        }
     }
   
   // Test 6: Close all positions
   Print("\nTest 6: Closing all positions");
   if(executor.CloseAllPositions())
      Print("  - CloseAllPositions: SUCCESS");
   else
      Print("  - CloseAllPositions: FAILED");
   
   Print("\n=== Trade Executor Tests Complete ===\n");
  }
//+------------------------------------------------------------------+
