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
   CUnifiedTradeLogger()
   {
      m_log_directory = "DualEA\\trade_logs";
      m_current_day = 0;
      m_trades_logged = 0;
      m_trades_closed = 0;
      
      CheckDayChange();
      
      PrintFormat("📝 UnifiedTradeLogger initialized: %s", m_daily_log_file);
   }
   
   // Log trade at execution (preliminary record)
   void LogTradeExecution(const UnifiedTradeRecord &record)
   {
      CheckDayChange();
      
      int handle = FileOpen(m_daily_log_file, FILE_READ|FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_ANSI);
      if(handle == INVALID_HANDLE)
      {
         // Create new file
         handle = FileOpen(m_daily_log_file, FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_ANSI);
         if(handle == INVALID_HANDLE)
         {
            PrintFormat("❌ Failed to create trade log file (Error: %d)", GetLastError());
            return;
         }
         
         // Write JSON header
         FileWriteString(handle, "{\n");
         FileWriteString(handle, StringFormat("  \"date\": \"%s\",\n", TimeToString(TimeCurrent(), TIME_DATE)));
         FileWriteString(handle, "  \"trades\": [\n");
      }
      else
      {
         // Append to existing file
         FileSeek(handle, 0, SEEK_END);
         ulong file_size = FileSize(handle);
         
         if(file_size > 100)  // File has content
         {
            // Add comma for array continuation
            FileSeek(handle, file_size - 10, SEEK_SET);  // Go back a bit
            FileWriteString(handle, ",\n");
         }
      }
      
      // Write trade record
      string trade_json = FormatTradeAsJSON(record, false);
      FileWriteString(handle, trade_json);
      
      FileClose(handle);
      
      m_trades_logged++;
      
      PrintFormat("📝 Trade execution logged: %s (Total: %d)", record.trade_id, m_trades_logged);
   }
   
   // Update trade at close (final record)
   void LogTradeClose(const UnifiedTradeRecord &record)
   {
      // Implementation: Update the existing record in the file
      // For now, append as new entry (full implementation would update in place)
      
      CheckDayChange();
      
      int handle = FileOpen(m_daily_log_file, FILE_READ|FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_ANSI);
      if(handle != INVALID_HANDLE)
      {
         FileSeek(handle, 0, SEEK_END);
         FileWriteString(handle, ",\n");
         
         string trade_json = FormatTradeAsJSON(record, true);
         FileWriteString(handle, trade_json);
         
         FileClose(handle);
         
         m_trades_closed++;
         
         PrintFormat("📝 Trade close logged: %s | PnL: %+.2f%% | Duration: %.1f min",
                    record.trade_id, record.profit_pct, record.hold_duration_minutes);
      }
   }
   
   // Format trade as JSON
   string FormatTradeAsJSON(const UnifiedTradeRecord &record, bool is_final)
   {
      string json = "    {\n";
      
      // Basic info
      json += StringFormat("      \"trade_id\": \"%s\",\n", record.trade_id);
      json += StringFormat("      \"signal_id\": \"%s\",\n", record.signal_id);
      json += StringFormat("      \"execution_time\": \"%s\",\n", TimeToString(record.execution_time));
      json += StringFormat("      \"status\": \"%s\",\n", is_final ? "closed" : "open");
      
      // Strategy and market
      json += StringFormat("      \"strategy\": \"%s\",\n", record.strategy_name);
      json += StringFormat("      \"symbol\": \"%s\",\n", record.symbol);
      json += StringFormat("      \"timeframe\": %d,\n", record.timeframe);
      json += StringFormat("      \"market_regime\": \"%s\",\n", record.market_regime);
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
      for(int i = 0; i < record.journey_length; i++)
      {
         GateJourneyStep step = record.gate_journey[i];
         
         if(i > 0) json += ",\n";
         
         json += "        {\n";
         json += StringFormat("          \"gate\": \"%s\",\n", step.gate_name);
         json += StringFormat("          \"index\": %d,\n", step.gate_index);
         json += StringFormat("          \"passed\": %s,\n", step.passed ? "true" : "false");
         json += StringFormat("          \"reason\": \"%s\",\n", step.reason);
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
         json += StringFormat("        \"close_reason\": \"%s\",\n", record.close_reason);
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
