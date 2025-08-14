// InsightsLoader.mqh
// Shared loader for DualEA insights.json used by PaperEA and LiveEA
// Parses one-JSON-object-per-line and populates gating arrays.

// Helper: trim copy
string __ins_trim_copy(string s){ StringTrimLeft(s); StringTrimRight(s); return s; }

// Parse insights from a file path under FILE_COMMON. Returns number of slices loaded, or -1 on error.
int Insights_Load_File(
   const string path,
   string &out_strat[], string &out_sym[], int &out_tf[],
   int &out_cnt[], double &out_wr[], double &out_avgR[],
   double &out_pf[], double &out_dd[])
{
   // Reset outputs
   ArrayResize(out_strat,0); ArrayResize(out_sym,0); ArrayResize(out_tf,0);
   ArrayResize(out_cnt,0); ArrayResize(out_wr,0); ArrayResize(out_avgR,0);
   ArrayResize(out_pf,0);  ArrayResize(out_dd,0);

   int h = FileOpen(path, FILE_READ|FILE_TXT|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_COMMON|FILE_ANSI);
   if(h==INVALID_HANDLE)
      return -1;

   while(!FileIsEnding(h))
   {
      string line = FileReadString(h);
      if(line=="" && FileIsEnding(h)) break;
      // Quick guard: require presence of "strategy"
      if(StringFind(line, "\"strategy\"", 0) < 0) continue;

      string sname="", yname=""; int tfv=0, cnt=0; double wr=0.0, avgR=0.0, pf=0.0, dd=0.0;
      int p=0;
      // strategy
      p = StringFind(line, "\"strategy\":", 0); if(p>=0){ int q=StringFind(line, ",", p+1); string seg=(q>p? StringSubstr(line,p,q-p):StringSubstr(line,p)); int c=StringFind(seg, ":", 0); if(c>=0){ sname=__ins_trim_copy(StringSubstr(seg, c+1)); StringReplace(sname, "\"", ""); } }
      // symbol
      p = StringFind(line, "\"symbol\":", 0);   if(p>=0){ int q=StringFind(line, ",", p+1); string seg=(q>p? StringSubstr(line,p,q-p):StringSubstr(line,p)); int c=StringFind(seg, ":", 0); if(c>=0){ yname=__ins_trim_copy(StringSubstr(seg, c+1)); StringReplace(yname, "\"", ""); } }
      // timeframe
      p = StringFind(line, "\"timeframe\":",0); if(p>=0){ int q=StringFind(line, ",", p+1); string seg=(q>p? StringSubstr(line,p,q-p):StringSubstr(line,p)); int c=StringFind(seg, ":", 0); if(c>=0){ string num=__ins_trim_copy(StringSubstr(seg,c+1)); tfv=(int)StringToInteger(num);} }
      // trade_count
      p = StringFind(line, "\"trade_count\":",0);if(p>=0){ int q=StringFind(line, ",", p+1); string seg=(q>p? StringSubstr(line,p,q-p):StringSubstr(line,p)); int c=StringFind(seg, ":", 0); if(c>=0){ string num=__ins_trim_copy(StringSubstr(seg,c+1)); cnt=(int)StringToInteger(num);} }
      // win_rate
      p = StringFind(line, "\"win_rate\":",0);   if(p>=0){ int q=StringFind(line, ",", p+1); string seg=(q>p? StringSubstr(line,p,q-p):StringSubstr(line,p)); int c=StringFind(seg, ":", 0); if(c>=0){ string num=__ins_trim_copy(StringSubstr(seg,c+1)); wr=StringToDouble(num);} }
      // avg_R
      p = StringFind(line, "\"avg_R\":",0);      if(p>=0){ int q=StringFind(line, ",", p+1); string seg=(q>p? StringSubstr(line,p,q-p):StringSubstr(line,p)); int c=StringFind(seg, ":", 0); if(c>=0){ string num=__ins_trim_copy(StringSubstr(seg,c+1)); avgR=StringToDouble(num);} }
      // profit_factor
      p = StringFind(line, "\"profit_factor\":",0);if(p>=0){int q=StringFind(line, ",", p+1); string seg=(q>p? StringSubstr(line,p,q-p):StringSubstr(line,p)); int c=StringFind(seg, ":", 0); if(c>=0){ string num=__ins_trim_copy(StringSubstr(seg,c+1)); pf=StringToDouble(num);} }
      // max_drawdown_R
      p = StringFind(line, "\"max_drawdown_R\":",0);if(p>=0){int q=StringFind(line, ",", p+1); string seg=(q>p? StringSubstr(line,p,q-p):StringSubstr(line,p)); int c=StringFind(seg, ":", 0); if(c>=0){ string num=__ins_trim_copy(StringSubstr(seg,c+1)); dd=StringToDouble(num);} }

      if(sname!="" && yname!="" && tfv>0)
      {
         int n = ArraySize(out_strat);
         ArrayResize(out_strat,n+1); ArrayResize(out_sym,n+1); ArrayResize(out_tf,n+1);
         ArrayResize(out_cnt,n+1); ArrayResize(out_wr,n+1); ArrayResize(out_avgR,n+1);
         ArrayResize(out_pf,n+1);  ArrayResize(out_dd,n+1);
         out_strat[n]=sname; out_sym[n]=yname; out_tf[n]=tfv; out_cnt[n]=cnt; out_wr[n]=wr; out_avgR[n]=avgR; out_pf[n]=pf; out_dd[n]=dd;
      }
   }
   FileClose(h);
   return ArraySize(out_strat);
}

// Convenience wrapper for default DualEA insights path
int Insights_Load_Default(
   string &out_strat[], string &out_sym[], int &out_tf[],
   int &out_cnt[], double &out_wr[], double &out_avgR[],
   double &out_pf[], double &out_dd[])
{
   return Insights_Load_File("DualEA\\insights.json",
      out_strat, out_sym, out_tf,
      out_cnt, out_wr, out_avgR,
      out_pf, out_dd);
}
