//+------------------------------------------------------------------+
//|                                               EscapeEA_WithPaperTrading.mq5 |
//|                                          Copyright 2025, EscapeEA |
//|                                             https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "2.10"  // Version bump for paper trading
#property strict

//--- Includes
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include "Escape\PaperTrading.mqh"

//--- Input Parameters
input group "=== Paper Trading ==="
input bool     InpEnablePaperTrading = true;       // Enable paper trading
input int      InpPaperTradesRequired = 5;         // Total paper trades to evaluate
input int      InpPaperWinsRequired = 3;           // Required wins for live trading
input double   InpPaperInitialBalance = 10000.0;   // Initial paper balance
input bool     InpSimulateSlippage = true;         // Simulate slippage in paper trading
input double   InpMaxSlippagePips = 1.0;           // Max slippage in pips

//--- Global Variables
CSymbolInfo    ExtSymbol;                          // Symbol info object
CPaperTrading *ExtPaperTrading = NULL;             // Paper trading system
bool           ExtPaperTradingActive = false;      // Paper trading mode flag

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize symbol info
   if(!ExtSymbol.Name(_Symbol)) {
      Print("Failed to initialize symbol info");
      return INIT_FAILED;
   }
   
   // Initialize paper trading if enabled
   if(InpEnablePaperTrading) {
      ExtPaperTrading = new CPaperTrading();
      if(ExtPaperTrading == NULL || !ExtPaperTrading.Initialize(&ExtSymbol, NULL, NULL)) {
         Print("Failed to initialize paper trading");
         return INIT_FAILED;
      }
      ExtPaperTradingActive = true;
      Print("Paper trading mode activated");
   }
   
   // Set up timer for periodic updates (1000ms)
   EventSetTimer(1);
   
   Print("EscapeEA with Paper Trading initialized successfully");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Stop the timer
   EventKillTimer();
   
   // Clean up paper trading
   if(ExtPaperTrading != NULL) {
      ExtPaperTrading.Deinitialize();
      delete ExtPaperTrading;
      ExtPaperTrading = NULL;
   }
   
   Print("EscapeEA deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Update market data
   ExtSymbol.RefreshRates();
   
   // Update paper trading system
   if(ExtPaperTrading != NULL) {
      ExtPaperTrading.Update();
      
      // Check if we can switch to live trading
      if(ExtPaperTradingActive && ExtPaperTrading.IsLiveTradingAllowed()) {
         ExtPaperTradingActive = false;
         Print("Switching to LIVE TRADING mode!");
      }
   }
   
   // Your trading strategy logic here
   // Example:
   // if(YourBuyCondition() && !HasOpenPosition(POSITION_TYPE_BUY)) {
   //    if(ExtPaperTradingActive) {
   //       ExtPaperTrading.OpenPosition(ORDER_TYPE_BUY, 0.1, ExtSymbol.Ask(), 0, 0, "Buy Signal");
   //    } else {
   //       // Execute live trade
   //    }
   // }
   
   // Update chart
   UpdateChart();
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Update chart periodically
   ChartRedraw();
   
   // Update paper trading display
   if(ExtPaperTrading != NULL) {
      ExtPaperTrading.UpdateChart();
   }
}

//+------------------------------------------------------------------+
//| Update chart with trading information                            |
//+------------------------------------------------------------------+
void UpdateChart()
{
   // Display current mode (Paper/Live)
   string modeText = ExtPaperTradingActive ? "PAPER TRADING" : "LIVE TRADING";
   string modeColor = ExtPaperTradingActive ? clrDodgerBlue : clrLime;
   
   // Create or update mode label
   string modeLabel = "EscapeEA_Mode";
   if(ObjectFind(0, modeLabel) < 0) {
      ObjectCreate(0, modeLabel, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, modeLabel, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, modeLabel, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, modeLabel, OBJPROP_YDISTANCE, 10);
      ObjectSetInteger(0, modeLabel, OBJPROP_COLOR, modeColor);
      ObjectSetInteger(0, modeLabel, OBJPROP_FONTSIZE, 12);
      ObjectSetString(0, modeLabel, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, modeLabel, OBJPROP_BACK, false);
   }
   ObjectSetString(0, modeLabel, OBJPROP_TEXT, modeText);
   ObjectSetInteger(0, modeLabel, OBJPROP_COLOR, modeColor);
   
   // Display paper trading info if active
   if(ExtPaperTradingActive && ExtPaperTrading != NULL) {
      string infoText = StringFormat("Paper Balance: %.2f\n" +
                                   "Equity: %.2f\n" +
                                   "Trades: %d (%dW/%dL)\n" +
                                   "Win Rate: %.1f%%",
                                   ExtPaperTrading.GetBalance(),
                                   ExtPaperTrading.GetEquity(),
                                   ExtPaperTrading.GetTotalTrades(),
                                   ExtPaperTrading.GetWinningTrades(),
                                   ExtPaperTrading.GetLosingTrades(),
                                   ExtPaperTrading.GetWinRate());
      
      string infoLabel = "EscapeEA_PaperInfo";
      if(ObjectFind(0, infoLabel) < 0) {
         ObjectCreate(0, infoLabel, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, infoLabel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, infoLabel, OBJPROP_XDISTANCE, 10);
         ObjectSetInteger(0, infoLabel, OBJPROP_YDISTANCE, 30);
         ObjectSetInteger(0, infoLabel, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, infoLabel, OBJPROP_FONTSIZE, 10);
         ObjectSetString(0, infoLabel, OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, infoLabel, OBJPROP_BACK, true);
      }
      ObjectSetString(0, infoLabel, OBJPROP_TEXT, infoText);
   }
   
   ChartRedraw();
}
//+------------------------------------------------------------------+
