//+------------------------------------------------------------------+
//| Timer function for periodic updates                              |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Update chart with current status
   UpdateChart();
   
   // Check for circuit breaker status
   if(ExtTradeExecutor.IsCircuitBreakerActive())
   {
      // Try to recover if circuit breaker was active
      if(ExtTradeExecutor.CheckCircuitBreaker())
      {
         Print("Circuit breaker has been reset. Trading resumed.");
      }
   }
   
   // Process paper trading checks if active
   if(ExtPaperTradingActive && ExtPaperTradeCount < InpPaperTotalTrades)
   {
      CheckPaperTrades();
   }
}

//+------------------------------------------------------------------+
//| Check paper trades for exits                                     |
//+------------------------------------------------------------------+
void CheckPaperTrades()
{
   for(int i = 0; i < ExtPaperTradeCount; i++)
   {
      if(!ExtPaperTrades[i].isClosed)
      {
         double currentBid = ExtSymbol.Bid();
         double currentAsk = ExtSymbol.Ask();
         
         // Check if stop loss or take profit was hit
         if((ExtPaperTrades[i].type == ORDER_TYPE_BUY && 
             currentBid <= ExtPaperTrades[i].stopLoss) ||
            (ExtPaperTrades[i].type == ORDER_TYPE_SELL && 
             currentAsk >= ExtPaperTrades[i].stopLoss))
         {
            // Stop loss hit
            ClosePaperTrade(i, ExtPaperTrades[i].stopLoss);
         }
         else if((ExtPaperTrades[i].type == ORDER_TYPE_BUY && 
                  currentBid >= ExtPaperTrades[i].takeProfit) ||
                 (ExtPaperTrades[i].type == ORDER_TYPE_SELL && 
                  currentAsk <= ExtPaperTrades[i].takeProfit))
         {
            // Take profit hit
            ClosePaperTrade(i, ExtPaperTrades[i].takeProfit);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Close a paper trade at the specified price                       |
//+------------------------------------------------------------------+
void ClosePaperTrade(int index, double closePrice)
{
   if(index < 0 || index >= ExtPaperTradeCount || ExtPaperTrades[index].isClosed)
      return;
      
   ExtPaperTrades[index].closePrice = closePrice;
   ExtPaperTrades[index].closeTime = TimeCurrent();
   ExtPaperTrades[index].isClosed = true;
   
   // Calculate profit/loss
   double profit = 0;
   if(ExtPaperTrades[index].type == ORDER_TYPE_BUY)
   {
      profit = closePrice - ExtPaperTrades[index].entryPrice;
   }
   else
   {
      profit = ExtPaperTrades[index].entryPrice - closePrice;
   }
   
   ExtPaperTrades[index].profit = profit * ExtPaperTrades[index].lotSize * ExtSymbol.LotsMultiplier();
   ExtPaperTrades[index].isWinner = (ExtPaperTrades[index].profit > 0);
   
   // Update win/loss counters
   if(ExtPaperTrades[index].isWinner)
      ExtPaperWins++;
   else
      ExtPaperLosses++;
      
   Print("Paper Trade #", index + 1, " - CLOSE at ", 
         DoubleToString(closePrice, _Digits), " | ",
         (ExtPaperTrades[index].isWinner ? "WIN" : "LOSS"), 
         " | P/L: ", DoubleToString(ExtPaperTrades[index].profit, 2), " ", 
         AccountInfoString(ACCOUNT_CURRENCY));
         
   // Check if we've completed the paper trading phase
   if(ExtPaperTradeCount >= InpPaperTotalTrades)
   {
      double winRate = (double)ExtPaperWins / InpPaperTotalTrades * 100.0;
      Print("\n=== PAPER TRADING COMPLETE ===");
      Print("Total Trades: ", ExtPaperTradeCount);
      Print("Winning Trades: ", ExtPaperWins, " (", DoubleToString(winRate, 1), "%)");
      Print("Losing Trades: ", ExtPaperLosses);
      
      if(winRate >= (double)InpPaperWinsRequired / InpPaperTotalTrades * 100.0)
      {
         Print("\nPAPER TRADING SUCCESSFUL! Ready for live trading.");
         ExtPaperTradingActive = false;
      }
      else
      {
         Print("\nPAPER TRADING FAILED. Strategy needs improvement before live trading.");
      }
   }
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // Handle chart events (e.g., mouse clicks, keyboard shortcuts)
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      // Handle button clicks or other interactive elements
      if(sparam == "btnCloseAll")
      {
         // Close all positions button clicked
         ExtTradeExecutor.CloseAllPositions();
      }
      else if(sparam == "btnPauseTrading")
      {
         // Pause trading button clicked
         ExtTradeExecutor.PauseTrading(3600); // Pause for 1 hour
         Print("Trading paused for 1 hour");
      }
   }
}

//+------------------------------------------------------------------+
//| Update chart with current status                                 |
//+------------------------------------------------------------------+
void UpdateChart()
{
   // Update chart with current status information
   string statusText = "EscapeEA v2.00 | ";
   statusText += ExtPaperTradingActive ? "PAPER TRADING" : "LIVE TRADING";
   statusText += " | " + StringFormat("Account: %s | Balance: %.2f %s | Equity: %.2f | Margin: %.2f", 
                     AccountInfoString(ACCOUNT_NAME), 
                     AccountInfoDouble(ACCOUNT_BALANCE), 
                     AccountInfoString(ACCOUNT_CURRENCY),
                     AccountInfoDouble(ACCOUNT_EQUITY),
                     AccountInfoDouble(ACCOUNT_MARGIN));
   
   // Update chart comment
   Comment(statusText);
   
   // Update chart objects for visualization
   UpdateChartObjects();
}

//+------------------------------------------------------------------+
//| Update chart objects for visualization                           |
//+------------------------------------------------------------------+
void UpdateChartObjects()
{
   // Update or create chart objects for visualization
   // This can include trend lines, arrows, or other visual indicators
   
   // Example: Update a label with paper trading status
   string objName = "PaperTradingStatus";
   if(ObjectFind(0, objName) < 0)
   {
      ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 20);
      ObjectSetString(0, objName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrWhite);
   }
   
   string statusText = "Paper Trading: " + (ExtPaperTradingActive ? "ACTIVE" : "INACTIVE");
   if(ExtPaperTradingActive)
   {
      statusText += StringFormat(" | Trades: %d/%d | Wins: %d | Losses: %d | Required: %d/%d",
                              ExtPaperTradeCount, InpPaperTotalTrades,
                              ExtPaperWins, ExtPaperLosses,
                              InpPaperWinsRequired, InpPaperTotalTrades);
   }
   
   ObjectSetString(0, objName, OBJPROP_TEXT, statusText);
   
   // Redraw the chart to show updates
   ChartRedraw();
}

//+------------------------------------------------------------------+
