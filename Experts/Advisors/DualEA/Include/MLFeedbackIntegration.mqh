//+------------------------------------------------------------------+
//| MLFeedbackIntegration.mqh                                        |
//| Purpose: Bridge MQL5 trades to Python ML feedback loop           |
//| This file writes trade outcomes to DualEA\feedback\immediate\    |
//+------------------------------------------------------------------+
#ifndef __MLFEEDBACKINTEGRATION_MQH__
#define __MLFEEDBACKINTEGRATION_MQH__

#include <Files/File.mqh>
#include "IStrategy.mqh"

//+------------------------------------------------------------------+
//| Trade Feedback Structure                                         |
//+------------------------------------------------------------------+
struct STradeFeedback
{
   string            symbol;
   string            strategy;
   int               timeframe;
   ulong             ticket;
   datetime          entry_time;
   datetime          exit_time;
   double            entry_price;
   double            exit_price;
   double            volume;
   double            pnl;
   double            r_multiple;
   bool              won;
   string            regime;
   double            atr_at_entry;
   double            rsi_at_entry;
   double            gate_confidences[8];  // G1-G8 confidence scores
   
   void Init()
   {
      symbol = "";
      strategy = "";
      timeframe = 0;
      ticket = 0;
      entry_time = 0;
      exit_time = 0;
      entry_price = 0.0;
      exit_price = 0.0;
      volume = 0.0;
      pnl = 0.0;
      r_multiple = 0.0;
      won = false;
      regime = "";
      atr_at_entry = 0.0;
      rsi_at_entry = 0.0;
      ArrayInitialize(gate_confidences, 0.0);
   }
};

//+------------------------------------------------------------------+
//| Global State for ML Feedback                                     |
//+------------------------------------------------------------------+
string g_ml_feedback_dir = "DualEA\\feedback\\immediate\\";
int    g_ml_write_count = 0;

//+------------------------------------------------------------------+
//| Helper: Escape JSON String                                       |
//+------------------------------------------------------------------+
string EscapeJsonString(const string text)
{
   string result = text;
   StringReplace(result, "\\", "\\\\");
   StringReplace(result, "\"", "\\\"");
   StringReplace(result, "\n", "\\n");
   StringReplace(result, "\r", "\\r");
   StringReplace(result, "\t", "\\t");
   return result;
}

//+------------------------------------------------------------------+
//| Write Trade Feedback to JSON File                                |
//+------------------------------------------------------------------+
bool WriteTradeFeedback(const STradeFeedback &feedback)
{
   // Generate unique filename
   string filename = StringFormat("feedback_%I64d_%s_%s.json", 
                     feedback.ticket, feedback.symbol, 
                     IntegerToString((int)TimeCurrent()));
   string filepath = g_ml_feedback_dir + filename;
   
   int handle = FileOpen(filepath, FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_UNICODE);
   if(handle == INVALID_HANDLE)
   {
      // Try without FILE_COMMON
      handle = FileOpen(filepath, FILE_WRITE|FILE_TXT|FILE_UNICODE);
      if(handle == INVALID_HANDLE)
      {
         PrintFormat("[MLFeedback] ERROR: Cannot open feedback file %s (Error %d)", 
                    filepath, GetLastError());
         return false;
      }
   }
   
   // Build JSON manually (MQL5 doesn't have built-in JSON)
   string json = "{\n";
   json += StringFormat("  \"symbol\": \"%s\",\n", EscapeJsonString(feedback.symbol));
   json += StringFormat("  \"strategy\": \"%s\",\n", EscapeJsonString(feedback.strategy));
   json += StringFormat("  \"timeframe\": %d,\n", feedback.timeframe);
   json += StringFormat("  \"ticket\": %I64d,\n", feedback.ticket);
   json += StringFormat("  \"entry_time\": \"%s\",\n", TimeToString(feedback.entry_time, TIME_DATE|TIME_SECONDS));
   json += StringFormat("  \"exit_time\": \"%s\",\n", TimeToString(feedback.exit_time, TIME_DATE|TIME_SECONDS));
   json += StringFormat("  \"entry_price\": %.5f,\n", feedback.entry_price);
   json += StringFormat("  \"exit_price\": %.5f,\n", feedback.exit_price);
   json += StringFormat("  \"volume\": %.2f,\n", feedback.volume);
   json += StringFormat("  \"pnl\": %.2f,\n", feedback.pnl);
   json += StringFormat("  \"r_multiple\": %.2f,\n", feedback.r_multiple);
   json += StringFormat("  \"won\": %s,\n", feedback.won ? "true" : "false");
   json += StringFormat("  \"regime\": \"%s\",\n", EscapeJsonString(feedback.regime));
   
   // Features at entry
   json += "  \"features\": {\n";
   json += StringFormat("    \"atr_14\": %.5f,\n", feedback.atr_at_entry);
   json += StringFormat("    \"rsi_14\": %.2f\n", feedback.rsi_at_entry);
   json += "  },\n";
   
   // Gate confidences
   json += "  \"gate_confidences\": {\n";
   for(int i = 0; i < 8; i++)
   {
      json += StringFormat("    \"G%d\": %.3f%s\n", i+1, feedback.gate_confidences[i], 
                          (i < 7) ? "," : "");
   }
   json += "  },\n";
   
   // Policy slice identifier
   string policy_slice = StringFormat("%s_%s_%d", feedback.strategy, feedback.symbol, feedback.timeframe);
   json += StringFormat("  \"policy_slice\": \"%s\"\n", EscapeJsonString(policy_slice));
   json += "}\n";
   
   // Write to file
   FileWriteString(handle, json);
   FileClose(handle);
   
   g_ml_write_count = g_ml_write_count + 1;
   
   int mod_check = g_ml_write_count % 10;
   if(mod_check == 0)
      PrintFormat("[MLFeedback] Written %d feedback files", g_ml_write_count);
   
   return true;
}

//+------------------------------------------------------------------+
//| Helper: Get current market regime                               |
//+------------------------------------------------------------------+
string GetCurrentMarketRegime(const string symbol, const ENUM_TIMEFRAMES timeframe)
{
   // Simple regime detection using ADX
   int adx_handle = iADX(symbol, timeframe, 14);
   if(adx_handle == INVALID_HANDLE) return "unknown";
   
   double adx_buffer[1], di_plus[1], di_minus[1];
   bool copied = CopyBuffer(adx_handle, 0, 0, 1, adx_buffer) > 0 &&
                 CopyBuffer(adx_handle, 1, 0, 1, di_plus) > 0 &&
                 CopyBuffer(adx_handle, 2, 0, 1, di_minus) > 0;
   IndicatorRelease(adx_handle);
   
   if(!copied) return "unknown";
   
   double adx = adx_buffer[0];
   double dip = di_plus[0];
   double dim = di_minus[0];
   
   if(adx > 25)
   {
      if(dip > dim)
         return "trending_up";
      else
         return "trending_down";
   }
   else if(adx < 20)
   {
      return "ranging";
   }
   else
   {
      return "transitional";
   }
}

//+------------------------------------------------------------------+
//| Helper: Calculate R-Multiple for a trade                        |
//+------------------------------------------------------------------+
double CalculateRMultiple(const double pnl, const double risk_amount)
{
   if(risk_amount == 0) return 0.0;
   return pnl / risk_amount;
}

//+------------------------------------------------------------------+
//| Initialize feedback system                                      |
//+------------------------------------------------------------------+
void InitializeMLFeedback()
{
   // Ensure directory exists (best effort)
   long dummy = 0;
   string path = "DualEA";
   if(!FolderCreate(path, FILE_COMMON))
   {
      // Try alternate path
      path = "\\\" + path;
   }
   
   g_ml_write_count = 0;
   Print("[MLFeedback] Feedback system initialized");
}

//+------------------------------------------------------------------+
//| Shutdown feedback system                                        |
//+------------------------------------------------------------------+
void ShutdownMLFeedback()
{
   PrintFormat("[MLFeedback] Total feedback files written: %d", g_ml_write_count);
}

//+------------------------------------------------------------------+
//| Record trade closure for ML feedback                           |
//| Call this from OnTrade or position close handler                 |
//+------------------------------------------------------------------+
void RecordTradeForML(
   const ulong ticket,
   const string strategy,
   const double entry_price,
   const double exit_price,
   const double volume,
   const double pnl,
   const double sl_distance,
   const double gate_confidences[]
)
{
   // Get position details
   if(!PositionSelectByTicket(ticket))
      return;
   
   string symbol = PositionGetString(POSITION_SYMBOL);
   datetime entry_time = (datetime)PositionGetInteger(POSITION_TIME);
   
   // Build feedback structure
   STradeFeedback feedback;
   feedback.Init();
   
   feedback.symbol = symbol;
   feedback.strategy = strategy;
   feedback.timeframe = (int)_Period;
   feedback.ticket = ticket;
   feedback.entry_time = entry_time;
   feedback.exit_time = TimeCurrent();
   feedback.entry_price = entry_price;
   feedback.exit_price = exit_price;
   feedback.volume = volume;
   feedback.pnl = pnl;
   feedback.won = (pnl > 0);
   
   // Calculate R-Multiple
   double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double risk_amount = sl_distance * volume * tick_value;
   feedback.r_multiple = CalculateRMultiple(pnl, risk_amount);
   
   // Get regime
   feedback.regime = GetCurrentMarketRegime(symbol, _Period);
   
   // Get features at entry (current values as proxy)
   feedback.atr_at_entry = GetATR(14);
   
   int rsi_handle = iRSI(symbol, _Period, 14, PRICE_CLOSE);
   if(rsi_handle != INVALID_HANDLE)
   {
      double rsi_buffer[1];
      if(CopyBuffer(rsi_handle, 0, 0, 1, rsi_buffer) > 0)
         feedback.rsi_at_entry = rsi_buffer[0];
      IndicatorRelease(rsi_handle);
   }
   
   // Copy gate confidences
   for(int i = 0; i < 8 && i < ArraySize(gate_confidences); i++)
      feedback.gate_confidences[i] = gate_confidences[i];
   
   // Write to file
   if(WriteTradeFeedback(feedback))
   {
      // Also update policy immediately
      if(CheckPointer(g_learning_bridge) != POINTER_INVALID)
      {
         g_learning_bridge.RecordTradeOutcome(strategy, symbol, (int)_Period, feedback.won, pnl);
      }
   }
}

#endif // __MLFEEDBACKINTEGRATION_MQH__
