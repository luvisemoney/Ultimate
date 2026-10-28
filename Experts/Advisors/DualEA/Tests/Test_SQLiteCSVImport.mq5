#property strict
#include "../Include/CSQLiteKnowledgeBase.mqh"

int g_failures=0;

void Check(bool passed, string message)
{
   Print(passed ? "[CSV-TEST PASS] " : "[CSV-TEST FAIL] ", message);
   if(!passed) g_failures++;
}

int OnInit()
{
   // Unique files prevent mutation of the user's KB/database.
   string token = StringFormat("csv_regression_%I64u", GetMicrosecondCount());
   string db_name = token + ".db";
   string fixture = "DualEA\\" + token + ".csv";
   FolderCreate("DualEA", DUALEA_FILE_COMMON);
   if(FileIsExist(fixture, DUALEA_FILE_COMMON) || FileIsExist("DualEA\\Database\\"+db_name, DUALEA_FILE_COMMON))
      return INIT_FAILED;

   CSQLiteKnowledgeBase kb(db_name);
   if(!kb.Initialize()) return INIT_FAILED;

   int file = FileOpen(fixture, FILE_WRITE|FILE_TXT|DUALEA_FILE_COMMON|FILE_UNICODE);
   if(file == INVALID_HANDLE) return INIT_FAILED;
   FileWriteString(file, "timestamp,symbol,type,entry_price,stop_loss,take_profit,close_price,profit,strategy_id\r\n");
   FileWriteString(file, "2026.10.01 10:00:00,USDCHF,0,0.8,0.79,0.82,0.81,20,Test'Strategy\r\n");
   FileWriteString(file, "2026.10.01 11:00:00,USDCHF,0,0.8,0.79,0.82,0.79,-10,Test'Strategy\r\n");
   FileClose(file);

   Check(kb.ImportFromCSV(fixture)==2, "UTF-16 native KB schema imports both closed trades");
   Check(kb.ImportFromCSV(fixture)==0, "Repeated preload does not double-count matching CSV records");
   double wr=0, pf=0, pnl=0;
   int total=0;
   // Imported names must work in both insertion and downstream queries.
   STradeRecord rows[];
   int count=kb.GetRecentTrades("Test'Strategy", "USDCHF", rows, 10);
   Check(count==2, "Quoted strategy names survive insertion");
   if(count==2)
   {
      Check(rows[0].timestamp==D'2026.10.01 11:00:00', "Formatted timestamps retain their date and time");
      Check(MathAbs(rows[0].pnl+10.0)<0.00001, "Imported close P&L is preserved");
   }

   // Switch to UTF-8 and canonical names, including a malformed timestamp.
   file=FileOpen(fixture, FILE_WRITE|FILE_TXT|DUALEA_FILE_COMMON|FILE_ANSI, 0, CP_UTF8);
   if(file == INVALID_HANDLE) return INIT_FAILED;
   FileWriteString(file, "timestamp,symbol,strategy,order_type,entry_price,volume,sl,tp,pnl,close_price\r\n");
   FileWriteString(file, "1790848800,USDCHF,Canonical,0,0.8,0.1,0.79,0.82,30,0.81\r\n");
   FileWriteString(file, "bad,USDCHF,Canonical,0,0.8,0.1,0.79,0.82,30,0.81\r\n");
   FileClose(file);
   Check(kb.ImportFromCSV(fixture)==1, "UTF-8 canonical schema imports valid row and rejects invalid date");
   Check(kb.GetStrategyStats("Canonical", "USDCHF", wr,pf,pnl,total), "Canonical statistics are queryable");
   Check(total==1 && MathAbs(pnl-30.0)<0.00001 && MathAbs(wr-1.0)<0.00001, "Closed outcomes contribute to statistics");
   kb.Close();
   FileDelete(fixture, DUALEA_FILE_COMMON);
   FileDelete("DualEA\\Database\\"+db_name, DUALEA_FILE_COMMON);
   PrintFormat("[CSV-TEST RESULT] failures=%d", g_failures);
   return g_failures==0 ? INIT_SUCCEEDED : INIT_FAILED;
}
void OnTick() {}
double OnTester() { return g_failures==0 ? 1.0 : -1.0; }
