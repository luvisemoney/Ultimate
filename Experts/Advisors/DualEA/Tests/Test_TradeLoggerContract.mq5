#property strict
#include "../Include/UnifiedTradeLogger.mqh"

int checks = 0;
int failures = 0;
void Check(bool passed, string label)
{
   checks++;
   if(!passed) { failures++; Print("[LOGGER FAIL] ", label); }
}

string ReadLog(string path)
{
   int file = FileOpen(path, FILE_READ|FILE_TXT|FILE_ANSI|DUALEA_FILE_COMMON, 0, CP_UTF8);
   if(file == INVALID_HANDLE) return "";
   string result = "";
   while(!FileIsEnding(file)) result += FileReadString(file) + "\n";
   FileClose(file);
   return result;
}

int Occurrences(string text, string token)
{
   int count=0, pos=0;
   while((pos=StringFind(text, token, pos)) >= 0) { count++; pos+=StringLen(token); }
   return count;
}

bool BalancedJSON(string text)
{
   bool quoted=false, escaped=false;
   string stack="";
   for(int i=0; i<StringLen(text); i++)
   {
      ushort ch=StringGetCharacter(text,i);
      if(quoted)
      {
         if(escaped) escaped=false;
         else if(ch==92) escaped=true;
         else if(ch==34) quoted=false;
         else if(ch<32) return false;
         continue;
      }
      if(ch==34) quoted=true;
      else if(ch==123 || ch==91) stack+=ShortToString(ch);
      else if(ch==125 || ch==93)
      {
         int size=StringLen(stack);
         if(size==0) return false;
         ushort opening=StringGetCharacter(stack,size-1);
         if((ch==125 && opening!=123) || (ch==93 && opening!=91)) return false;
         stack=StringSubstr(stack,0,size-1);
      }
   }
   StringTrimLeft(text);
   StringTrimRight(text);
   return !quoted && stack=="" && StringLen(text)>1 && StringGetCharacter(text,0)==123 && StringGetCharacter(text,StringLen(text)-1)==125;
}

int OnInit()
{
   if(!MQLInfoInteger(MQL_TESTER)) return INIT_FAILED;
   // Each run uses its own tester-local directory, never the live trade log.
   string directory="DualEA\\logger_contract_"+IntegerToString((long)GetTickCount64());
   CUnifiedTradeLogger logger(directory);
   UnifiedTradeRecord record;
   Check(record.journey_length == 0, "new record has an empty journey");
   Check(record.blocking_gate == -1, "new record has no blocking gate");
   Check(record.reviews_performed == 0 && !record.is_closed, "new lifecycle state is initialized");
   string json = logger.FormatTradeAsJSON(record, false);
   Check(StringFind(json, "\"gate\":") < 0, "empty journey formats without indexing entries");

   for(int i=0; i<ArraySize(record.gate_journey); i++)
   {
      record.gate_journey[i].gate_name = "test_" + IntegerToString(i);
      record.gate_journey[i].gate_index = i;
   }
   record.journey_length = 1;
   json = logger.FormatTradeAsJSON(record, false);
   Check(StringFind(json, "test_0") >= 0 && StringFind(json, "test_1") < 0, "one-step journey stays one step");
   record.journey_length = 2147483647;
   json = logger.FormatTradeAsJSON(record, false);
   Check(StringFind(json, "test_23") >= 0, "oversized journey clamps to fixed capacity");
   record.journey_length = -1;
   json = logger.FormatTradeAsJSON(record, true);
   Check(StringFind(json, "\"gate\":") < 0, "negative journey formats as empty");
   Check(StringFind(json, "\"outcome\":") >= 0, "close formatting remains available");

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(),dt);
   string path=directory+"\\trades_"+StringFormat("%04d%02d%02d",dt.year,dt.mon,dt.day)+".json";
   record.journey_length=1;
   record.trade_id="trade-a";
   record.execution_time=TimeCurrent();
   record.strategy_name="quoted \"strategy\" with \\ slash\nbrace }";
   logger.LogTradeExecution(record);
   string first=ReadLog(path);
   Check(BalancedJSON(first) && Occurrences(first,"\"trade_id\":")==1, "first write is a complete document");
   record.trade_id="trade-b";
   logger.LogTradeExecution(record);
   string second=ReadLog(path);
   Check(BalancedJSON(second) && Occurrences(second,"\"trade_id\":")==2, "second append preserves both records and balanced arrays");
   Check(Occurrences(second,"\"status\": \"open\"")==2, "both executions are open");
   Check(StringFind(second,"quoted \\\"strategy\\\" with \\\\ slash\\nbrace }")>=0, "string quotes, slashes and newlines are escaped");
   record.trade_id="trade-a";
   record.close_time=TimeCurrent();
   record.profit_absolute=12.5;
   logger.LogTradeClose(record);
   string closed=ReadLog(path);
   Check(BalancedJSON(closed) && Occurrences(closed,"\"trade_id\":")==2, "closing preserves two complete records");
   Check(Occurrences(closed,"\"status\": \"closed\"")==1 && Occurrences(closed,"\"status\": \"open\"")==1, "only matching trade is closed");
   Check(Occurrences(closed,"\"outcome\":")==1 && StringFind(closed,"\"profit_absolute\": 12.50")>=0, "close outcome persisted");
   int logged, total_closed;
   logger.GetStatistics(logged,total_closed);
   Check(logged==2 && total_closed==1, "statistics reflect committed writes");
   record.trade_id="missing";
   logger.LogTradeClose(record);
   Check(ReadLog(path)==closed, "unknown close leaves log unchanged");
   Print("[LOGGER ARTIFACT] ",path);
   PrintFormat("[LOGGER-CONTRACT] RESULT checks=%d failures=%d", checks, failures);
   return failures == 0 ? INIT_SUCCEEDED : INIT_FAILED;
}
void OnTick() { ExpertRemove(); }
double OnTester() { return failures == 0 ? checks : -failures; }
