#include "RuntimeStorage.mqh"
//+------------------------------------------------------------------+
//| UnifiedTradeLogger.mqh                                           |
//| Purpose: Comprehensive JSON logging for complete trade lifecycle |
//| Features: Execution + Close logging with gate journey details    |
//+------------------------------------------------------------------+
#ifndef __UNIFIEDTRADELOGGER_MQH__
#define __UNIFIEDTRADELOGGER_MQH__

#include "AdaptiveSignalOptimizer.mqh"
#include <Files/File.mqh>

// Complete trade record
struct UnifiedTradeRecord
{
   // Trade identification
   string trade_id;
   string signal_id;
   datetime execution_time;
   datetime close_time;
   
   // Strategy and market
   string strategy_name;
   string symbol;
   int timeframe;
   string market_regime;
   double volatility;
   
   // Execution details
   double entry_price;
   double exit_price;
   double sl;
   double tp;
   double volume;
   int order_type;
   
   // Gate journey
   GateJourneyStep gate_journey[24];
   int journey_length;
   
   // Optimization details
   bool was_adjusted;
   int adjustment_attempts;
   int blocking_gate;  // Which gate initially blocked (-1 if none)
   
   // Outcome
   bool is_closed;
   bool was_winner;
   double profit_pct;
   double profit_absolute;
   double hold_duration_minutes;
   
   // Learning metadata
   double confidence;
   string close_reason;  // "profit_target", "stop_loss", "signal_reversal", etc.
   
   // Position reviews
   int reviews_performed;
   string review_actions[];  // "HOLD", "ADJUST_SL", etc.

   // Execution callers populate only the fields they have. In particular,
   // an untouched journey length must never be interpreted as an array bound.
   UnifiedTradeRecord()
   {
      execution_time = 0;
      close_time = 0;
      timeframe = 0;
      volatility = 0.0;
      entry_price = 0.0;
      exit_price = 0.0;
      sl = 0.0;
      tp = 0.0;
      volume = 0.0;
      order_type = 0;
      journey_length = 0;
      was_adjusted = false;
      adjustment_attempts = 0;
      blocking_gate = -1;
      is_closed = false;
      was_winner = false;
      profit_pct = 0.0;
      profit_absolute = 0.0;
      hold_duration_minutes = 0.0;
      confidence = 0.0;
      reviews_performed = 0;
      ZeroMemory(gate_journey);
   }
};

//+------------------------------------------------------------------+
//| Unified Trade Logger - Complete lifecycle tracking              |
//+------------------------------------------------------------------+
class CUnifiedTradeLogger
{
private:
   string m_log_directory;
   string m_daily_log_file;
   datetime m_current_day;
   
   int m_trades_logged;
   int m_trades_closed;

   string EscapeJSON(string value)
   {
      string escaped = "";
      for(int i=0; i<StringLen(value); i++)
      {
         ushort ch = StringGetCharacter(value, i);
         if(ch == 92) escaped += "\\\\";
         else if(ch == 34) escaped += "\\\"";
         else if(ch == 13) escaped += "\\r";
         else if(ch == 10) escaped += "\\n";
         else if(ch == 9) escaped += "\\t";
         else if(ch < 32) escaped += StringFormat("\\u%04x", (int)ch);
         else escaped += StringSubstr(value, i, 1);
      }
      return escaped;
   }

   bool IsJSONSpace(ushort ch)
   {
      return ch == 32 || ch == 9 || ch == 10 || ch == 13;
   }

   // Extract complete trade objects without treating braces in strings as
   // structure. Never overwrite an existing log that cannot be read safely.
   bool ReadTrades(string &trades[])
   {
      ArrayResize(trades, 0);
      if(!FileIsExist(m_daily_log_file, DUALEA_FILE_COMMON)) return true;
      int handle = FileOpen(m_daily_log_file, FILE_READ|FILE_TXT|DUALEA_FILE_COMMON|FILE_ANSI|FILE_SHARE_READ, 0, CP_UTF8);
      if(handle == INVALID_HANDLE) return false;
      string document = "";
      while(!FileIsEnding(handle)) document += FileReadString(handle) + "\n";
      FileClose(handle);
      string trimmed = document;
      StringTrimLeft(trimmed);
      StringTrimRight(trimmed);
      if(trimmed == "") return true;
      int key = StringFind(document, "\"trades\"");
      if(key < 0) return false;
      int begin = StringFind(document, "[", key + 8);
      if(begin < 0) return false;
      bool quoted = false, escaped = false, need_comma = false;
      int depth = 0, start = -1;
      for(int i=begin+1; i<StringLen(document); i++)
      {
         ushort ch = StringGetCharacter(document, i);
         if(quoted)
         {
            if(escaped) escaped = false;
            else if(ch == 92) escaped = true;
            else if(ch == 34) quoted = false;
            continue;
         }
         if(depth > 0)
         {
            if(ch == 34) quoted = true;
            else if(ch == 123) depth++;
            else if(ch == 125)
            {
               depth--;
               if(depth == 0)
               {
                  int count = ArraySize(trades);
                  if(ArrayResize(trades, count+1) != count+1) return false;
                  trades[count] = StringSubstr(document, start, i-start+1);
                  need_comma = true;
               }
            }
            continue;
         }
         if(IsJSONSpace(ch)) continue;
         if(ch == 93)
         {
            // A comma must be followed by another object, not the array end.
            if(!need_comma && ArraySize(trades) > 0) return false;
            string suffix = StringSubstr(document, i+1);
            StringTrimLeft(suffix);
            StringTrimRight(suffix);
            return suffix == "}";
         }
         if(need_comma)
         {
            if(ch != 44) return false;
            need_comma = false;
            continue;
         }
         if(ch != 123) return false;
         start = i;
         depth = 1;
      }
      return false;
   }

   bool MatchesTradeId(const string trade, const string trade_id)
   {
      int key = StringFind(trade, "\"trade_id\"");
      if(key < 0) return false;
      int pos = key + 10;
      int length = StringLen(trade);
      while(pos < length && IsJSONSpace(StringGetCharacter(trade, pos))) pos++;
      if(pos >= length || StringGetCharacter(trade, pos++) != 58) return false;
      while(pos < length && IsJSONSpace(StringGetCharacter(trade, pos))) pos++;
      if(pos >= length || StringGetCharacter(trade, pos++) != 34) return false;
      int start = pos;
      bool escaped = false;
      for(; pos<length; pos++)
      {
         ushort ch = StringGetCharacter(trade, pos);
         if(escaped) escaped = false;
         else if(ch == 92) escaped = true;
         else if(ch == 34) return StringSubstr(trade, start, pos-start) == EscapeJSON(trade_id);
      }
      return false;
   }

   bool WriteTrades(const string &trades[], datetime log_date=0)
   {
      string document = "{\n";
      document += StringFormat("  \"date\": \"%s\",\n", TimeToString(log_date > 0 ? log_date : TimeCurrent(), TIME_DATE));
      document += "  \"trades\": [\n";
      for(int i=0; i<ArraySize(trades); i++)
      {
         if(i > 0) document += ",\n";
         document += trades[i];
      }
      document += "\n  ]\n}\n";
      string temporary = m_daily_log_file + ".tmp";
      uchar bytes[];
      int length = StringToCharArray(document, bytes, 0, WHOLE_ARRAY, CP_UTF8) - 1;
      if(length <= 0) return false;
      int handle = FileOpen(temporary, FILE_WRITE|FILE_BIN|DUALEA_FILE_COMMON);
      if(handle == INVALID_HANDLE) return false;
      uint written = FileWriteArray(handle, bytes, 0, length);
      FileFlush(handle);
      FileClose(handle);
      if(written != (uint)length || !FileMove(temporary, DUALEA_FILE_COMMON, m_daily_log_file, DUALEA_FILE_COMMON|FILE_REWRITE))
      {
         FileDelete(temporary, DUALEA_FILE_COMMON);
         return false;
      }
      return true;
   }
   
   // Get current day's log file
   string GetDailyLogFile()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      
      string date_str = StringFormat("%04d%02d%02d", dt.year, dt.mon, dt.day);
      return m_log_directory + "\\" + "trades_" + date_str + ".json";
   }
   
   // Check if day changed
   bool CheckDayChange()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      datetime today = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
      
      if(today != m_current_day)
      {
         m_current_day = today;
         m_daily_log_file = GetDailyLogFile();
         return true;
      }
      return false;
   }

public:
   CUnifiedTradeLogger(string directory="DualEA\\trade_logs")
   {
      m_log_directory = directory;
      FolderCreate("DualEA", DUALEA_FILE_COMMON);
      FolderCreate(m_log_directory, DUALEA_FILE_COMMON);
      m_current_day = 0;
      m_trades_logged = 0;
      m_trades_closed = 0;
      
      CheckDayChange();
      
      PrintFormat("📝 UnifiedTradeLogger initialized: %s", m_daily_log_file);
   }
   
   // Log trade at execution (preliminary record). Every successful write is
   // a complete JSON document; no fixed-offset tail overwrites are used.
   void LogTradeExecution(const UnifiedTradeRecord &record)
   {
      CheckDayChange();
      string trades[];
      if(!ReadTrades(trades))
      {
         Print("[TradeLogger] Existing log is unreadable or malformed; preserving it: ", m_daily_log_file);
         return;
      }
      int count = ArraySize(trades);
      if(ArrayResize(trades, count+1) != count+1) return;
      trades[count] = FormatTradeAsJSON(record, false);
      if(!WriteTrades(trades))
      {
         Print("[TradeLogger] Could not commit execution record: ", EscapeJSON(record.trade_id));
         return;
      }
      m_trades_logged++;
      PrintFormat("[TradeLogger] Execution logged: %s (Total: %d)", record.trade_id, m_trades_logged);
   }

   // Locate the execution-day file so a close after midnight updates the
   // original trade instead of searching only today's file.
   void LogTradeClose(const UnifiedTradeRecord &record)
   {
      CheckDayChange();
      string current_file = m_daily_log_file;
      if(record.execution_time > 0)
      {
         MqlDateTime dt;
         TimeToStruct(record.execution_time, dt);
         m_daily_log_file = m_log_directory + "\\trades_" + StringFormat("%04d%02d%02d", dt.year, dt.mon, dt.day) + ".json";
      }
      string trades[];
      bool committed = false;
      if(ReadTrades(trades))
      {
         for(int i=0; i<ArraySize(trades); i++)
         {
            if(!MatchesTradeId(trades[i], record.trade_id)) continue;
            trades[i] = FormatTradeAsJSON(record, true);
            committed = WriteTrades(trades, record.execution_time);
            break;
         }
      }
      m_daily_log_file = current_file;
      if(!committed)
      {
         Print("[TradeLogger] Close record not committed: ", EscapeJSON(record.trade_id));
         return;
      }
      m_trades_closed++;
      PrintFormat("[TradeLogger] Close logged: %s | PnL: %+.2f%% | Duration: %.1f min",
                  record.trade_id, record.profit_pct, record.hold_duration_minutes);
   }

   // Format trade as JSON
   string FormatTradeAsJSON(const UnifiedTradeRecord &record, bool is_final)
   {
      string json = "    {\n";
      
      // Basic info
      json += StringFormat("      \"trade_id\": \"%s\",\n", EscapeJSON(record.trade_id));
      json += StringFormat("      \"signal_id\": \"%s\",\n", EscapeJSON(record.signal_id));
      json += StringFormat("      \"execution_time\": \"%s\",\n", TimeToString(record.execution_time));
      json += StringFormat("      \"status\": \"%s\",\n", is_final ? "closed" : "open");
      
      // Strategy and market
      json += StringFormat("      \"strategy\": \"%s\",\n", EscapeJSON(record.strategy_name));
      json += StringFormat("      \"symbol\": \"%s\",\n", EscapeJSON(record.symbol));
      json += StringFormat("      \"timeframe\": %d,\n", record.timeframe);
      json += StringFormat("      \"market_regime\": \"%s\",\n", EscapeJSON(record.market_regime));
      json += StringFormat("      \"volatility\": %.4f,\n", record.volatility);
      
      // Execution details
      json += "      \"execution\": {\n";
      json += StringFormat("        \"entry_price\": %.5f,\n", record.entry_price);
      json += StringFormat("        \"sl\": %.5f,\n", record.sl);
      json += StringFormat("        \"tp\": %.5f,\n", record.tp);
      json += StringFormat("        \"volume\": %.2f,\n", record.volume);
      json += StringFormat("        \"order_type\": %d,\n", record.order_type);
      json += StringFormat("        \"confidence\": %.3f\n", record.confidence);
      json += "      },\n";
      
      // Gate journey
      json += "      \"gate_journey\": [\n";
      // Persisted or caller-supplied lengths may be invalid even when new
      // records are initialized correctly. Bound every access to capacity.
      int journey_count = MathMax(0, MathMin(record.journey_length, ArraySize(record.gate_journey)));
      for(int i = 0; i < journey_count; i++)
      {
         GateJourneyStep step = record.gate_journey[i];
         
         if(i > 0) json += ",\n";
         
         json += "        {\n";
         json += StringFormat("          \"gate\": \"%s\",\n", EscapeJSON(step.gate_name));
         json += StringFormat("          \"index\": %d,\n", step.gate_index);
         json += StringFormat("          \"passed\": %s,\n", step.passed ? "true" : "false");
         json += StringFormat("          \"reason\": \"%s\",\n", EscapeJSON(step.reason));
         json += StringFormat("          \"adjusted\": %s", step.was_adjusted ? "true" : "false");
         
         if(step.was_adjusted)
         {
            json += ",\n          \"adjustments\": {\n";
            json += StringFormat("            \"price\": [%.5f, %.5f],\n", step.price_before, step.price_after);
            json += StringFormat("            \"sl\": [%.5f, %.5f],\n", step.sl_before, step.sl_after);
            json += StringFormat("            \"tp\": [%.5f, %.5f],\n", step.tp_before, step.tp_after);
            json += StringFormat("            \"volume\": [%.2f, %.2f]\n", step.volume_before, step.volume_after);
            json += "          }\n";
         }
         else
         {
            json += "\n";
         }
         
         json += "        }";
      }
      json += "\n      ],\n";
      
      // Optimization info
      json += "      \"optimization\": {\n";
      json += StringFormat("        \"was_adjusted\": %s,\n", record.was_adjusted ? "true" : "false");
      json += StringFormat("        \"attempts\": %d,\n", record.adjustment_attempts);
      json += StringFormat("        \"blocking_gate\": %d\n", record.blocking_gate);
      json += "      }";
      
      // Final outcome (if closed)
      if(is_final)
      {
         json += ",\n      \"outcome\": {\n";
         json += StringFormat("        \"close_time\": \"%s\",\n", TimeToString(record.close_time));
         json += StringFormat("        \"exit_price\": %.5f,\n", record.exit_price);
         json += StringFormat("        \"profit_pct\": %.2f,\n", record.profit_pct);
         json += StringFormat("        \"profit_absolute\": %.2f,\n", record.profit_absolute);
         json += StringFormat("        \"duration_minutes\": %.1f,\n", record.hold_duration_minutes);
         json += StringFormat("        \"was_winner\": %s,\n", record.was_winner ? "true" : "false");
         json += StringFormat("        \"close_reason\": \"%s\",\n", EscapeJSON(record.close_reason));
         json += StringFormat("        \"reviews_performed\": %d\n", record.reviews_performed);
         json += "      }";
      }
      
      json += "\n    }";
      
      return json;
   }
   
   // Get statistics
   void GetStatistics(int &total_logged, int &total_closed)
   {
      total_logged = m_trades_logged;
      total_closed = m_trades_closed;
   }
   
   void PrintReport()
   {
      PrintFormat("\n📝 === Unified Trade Logger Report ===");
      PrintFormat("Trades Logged: %d", m_trades_logged);
      PrintFormat("Trades Closed: %d", m_trades_closed);
      PrintFormat("Current Log File: %s", m_daily_log_file);
      PrintFormat("=====================================\n");
   }
};

#endif
