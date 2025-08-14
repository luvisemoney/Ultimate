//+------------------------------------------------------------------+
//| InsightsLoader.mqh                                               |
//| Shared loader for DualEA insights.json                           |
//+------------------------------------------------------------------+
#ifndef __INSIGHTSLOADER_MQH__
#define __INSIGHTSLOADER_MQH__

// Clear and load insights slices from a JSON-lines file located in Common Files.
// Returns the number of slices loaded (>=0) or -1 on error.
int Insights_Load_File(
   const string path,                       // e.g. "DualEA\\insights.json"
   string &out_strat[],
   string &out_sym[],
   int    &out_tf[],
   int    &out_cnt[],
   double &out_wr[],
   double &out_avgR[],
   double &out_pf[],
   double &out_dd[]
)
{
   int h = FileOpen(path, FILE_READ|FILE_TXT|FILE_COMMON|FILE_ANSI);
   if(h==INVALID_HANDLE)
   {
      PrintFormat("Insights gating: cannot open %s (Common). Err=%d", path, GetLastError());
      return -1;
   }
   // clear arrays
   ArrayResize(out_strat,0); ArrayResize(out_sym,0); ArrayResize(out_tf,0);
   ArrayResize(out_cnt,0);   ArrayResize(out_wr,0);  ArrayResize(out_avgR,0);
   ArrayResize(out_pf,0);    ArrayResize(out_dd,0);

   while(!FileIsEnding(h))
   {
      string line = FileReadString(h);
      if(line=="" && FileIsEnding(h)) break;
      // Only parse lines from by_symbol_strategy_timeframe blocks
      if(StringFind(line, "\"strategy\"", 0) < 0) continue;
      // Extract fields with simple token searches (mirrors LiveEA)
      string sname="", yname=""; int tfv=-1, cnt=0; double wr=0, avgR=0, pf=0, dd=0;
      int p;
      // strategy
      p = StringFind(line, "\"strategy\":", 0);
      if(p>=0)
      {
         int q = StringFind(line, ",", p+1);
         string seg = (q>p? StringSubstr(line, p, q-p) : StringSubstr(line, p));
         int c1=StringFind(seg, "\"", 0);
         int c2=StringFind(seg, "\"", c1+1);
         int c3=StringFind(seg, "\"", c2+1);
         int c4=StringFind(seg, "\"", c3+1);
         if(c3>0 && c4>c3) sname = StringSubstr(seg, c3+1, c4-c3-1);
      }
      // symbol
      p = StringFind(line, "\"symbol\":", 0);
      if(p>=0)
      {
         int q = StringFind(line, ",", p+1);
         string seg = (q>p? StringSubstr(line, p, q-p) : StringSubstr(line, p));
         int c3=StringFind(seg, "\"", 0);
         c3 = StringFind(seg, "\"", c3+1);
         int c4=StringFind(seg, "\"", c3+1);
         int c5=StringFind(seg, "\"", c4+1);
         if(c4>0 && c5>c4) yname = StringSubstr(seg, c4+1, c5-c4-1);
      }
      // timeframe
      p = StringFind(line, "\"timeframe\":", 0);
      if(p>=0)
      {
         int q = StringFind(line, ",", p+1);
         string seg = (q>p? StringSubstr(line, p, q-p) : StringSubstr(line, p));
         int c = StringFind(seg, ":", 0);
         if(c>=0){ string num = line; num = StringSubstr(seg, c+1); StringTrimLeft(num); StringTrimRight(num); tfv = (int)StringToInteger(num); }
      }
      // trade_count
      p = StringFind(line, "\"trade_count\":", 0);
      if(p>=0)
      {
         int q = StringFind(line, ",", p+1);
         string seg = (q>p? StringSubstr(line, p, q-p) : StringSubstr(line, p));
         int c = StringFind(seg, ":", 0);
         if(c>=0){ string num = StringSubstr(seg, c+1); StringTrimLeft(num); StringTrimRight(num); cnt = (int)StringToInteger(num); }
      }
      // win_rate
      p = StringFind(line, "\"win_rate\":", 0);
      if(p>=0)
      {
         int q = StringFind(line, ",", p+1);
         string seg = (q>p? StringSubstr(line, p, q-p) : StringSubstr(line, p));
         int c = StringFind(seg, ":", 0);
         if(c>=0){ string num = StringSubstr(seg, c+1); StringTrimLeft(num); StringTrimRight(num); wr = StringToDouble(num); }
      }
      // avg_R
      p = StringFind(line, "\"avg_R\":", 0);
      if(p>=0)
      {
         int q = StringFind(line, ",", p+1);
         string seg = (q>p? StringSubstr(line, p, q-p) : StringSubstr(line, p));
         int c = StringFind(seg, ":", 0);
         if(c>=0){ string num = StringSubstr(seg, c+1); StringTrimLeft(num); StringTrimRight(num); avgR = StringToDouble(num); }
      }
      // profit_factor
      p = StringFind(line, "\"profit_factor\":", 0);
      if(p>=0)
      {
         int q = StringFind(line, ",", p+1);
         string seg = (q>p? StringSubstr(line, p, q-p) : StringSubstr(line, p));
         int c = StringFind(seg, ":", 0);
         if(c>=0){ string num = StringSubstr(seg, c+1); StringTrimLeft(num); StringTrimRight(num); pf = StringToDouble(num); }
      }
      // max_drawdown_R
      p = StringFind(line, "\"max_drawdown_R\":", 0);
      if(p>=0)
      {
         string seg = StringSubstr(line, p);
         int c = StringFind(seg, ":", 0);
         if(c>=0){ string num = StringSubstr(seg, c+1); StringTrimLeft(num); StringTrimRight(num); dd = StringToDouble(num); }
      }

      if(sname!="" && yname!="" && tfv>=0)
      {
         int n = ArraySize(out_strat);
         ArrayResize(out_strat,n+1); ArrayResize(out_sym,n+1); ArrayResize(out_tf,n+1);
         ArrayResize(out_cnt,n+1);   ArrayResize(out_wr,n+1);  ArrayResize(out_avgR,n+1);
         ArrayResize(out_pf,n+1);    ArrayResize(out_dd,n+1);
         out_strat[n]=sname; out_sym[n]=yname; out_tf[n]=tfv;
         out_cnt[n]=cnt; out_wr[n]=wr; out_avgR[n]=avgR; out_pf[n]=pf; out_dd[n]=dd;
      }
   }
   FileClose(h);
   return ArraySize(out_strat);
}

// Convenience wrapper for default path
int Insights_Load_Default(
   string &out_strat[], string &out_sym[], int &out_tf[], int &out_cnt[],
   double &out_wr[], double &out_avgR[], double &out_pf[], double &out_dd[])
{
   return Insights_Load_File("DualEA\\insights.json", out_strat, out_sym, out_tf, out_cnt, out_wr, out_avgR, out_pf, out_dd);
}

#endif // __INSIGHTSLOADER_MQH__
