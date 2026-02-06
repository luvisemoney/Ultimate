//+------------------------------------------------------------------+
//| InsightsLoader.mqh - Load insights from JSON for LiveEA gating  |
//+------------------------------------------------------------------+
#ifndef INSIGHTSLOADER_MQH
#define INSIGHTSLOADER_MQH

//+------------------------------------------------------------------+
//| Load insights from insights.json in Common Files                  |
//+------------------------------------------------------------------+
int Insights_Load_Default(
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
   // Reset arrays
   ArrayResize(out_strat, 0);
   ArrayResize(out_sym, 0);
   ArrayResize(out_tf, 0);
   ArrayResize(out_cnt, 0);
   ArrayResize(out_wr, 0);
   ArrayResize(out_avgR, 0);
   ArrayResize(out_pf, 0);
   ArrayResize(out_dd, 0);
   
   string path = "DualEA\\insights.json";
   int h = FileOpen(path, FILE_READ|FILE_TXT|FILE_COMMON|FILE_ANSI);
   if(h == INVALID_HANDLE)
   {
      PrintFormat("[InsightsLoader] Cannot open %s (Common). Err=%d", path, GetLastError());
      return 0;  // No insights file is ok - cold start
   }
   
   string cur_s = "", cur_y = "";
   int cur_tf = -1, cur_cnt = 0;
   double cur_wr = 0.0, cur_avgR = 0.0, cur_pf = 0.0, cur_dd = 0.0;
   
   while(!FileIsEnding(h))
   {
      string line = FileReadString(h);
      if(line == "" && FileIsEnding(h)) break;
      
      int p;
      
      // strategy
      p = StringFind(line, "\"strategy\"", 0);
      if(p >= 0)
      {
         int q = StringFind(line, ",", p+1);
         string seg = (q > p ? StringSubstr(line, p, q-p) : StringSubstr(line, p));
         int c3 = StringFind(seg, "\"", 0);
         c3 = StringFind(seg, "\"", c3+1);
         int c4 = StringFind(seg, "\"", c3+1);
         int c5 = StringFind(seg, "\"", c4+1);
         if(c4 > 0 && c5 > c4)
            cur_s = StringSubstr(seg, c4+1, c5-c4-1);
      }
      
      // symbol
      p = StringFind(line, "\"symbol\"", 0);
      if(p >= 0)
      {
         int q = StringFind(line, ",", p+1);
         string seg = (q > p ? StringSubstr(line, p, q-p) : StringSubstr(line, p));
         int c3 = StringFind(seg, "\"", 0);
         c3 = StringFind(seg, "\"", c3+1);
         int c4 = StringFind(seg, "\"", c3+1);
         int c5 = StringFind(seg, "\"", c4+1);
         if(c4 > 0 && c5 > c4)
            cur_y = StringSubstr(seg, c4+1, c5-c4-1);
      }
      
      // timeframe
      p = StringFind(line, "\"timeframe\"", 0);
      if(p >= 0)
      {
         int c = StringFind(line, ":", p);
         if(c >= 0)
         {
            string num = StringSubstr(line, c+1);
            StringTrimLeft(num);
            cur_tf = (int)StringToInteger(num);
         }
      }
      
      // trade_count
      p = StringFind(line, "\"trade_count\"", 0);
      if(p >= 0)
      {
         int c = StringFind(line, ":", p);
         if(c >= 0)
         {
            string num = StringSubstr(line, c+1);
            StringTrimLeft(num);
            cur_cnt = (int)StringToInteger(num);
         }
      }
      
      // win_rate
      p = StringFind(line, "\"win_rate\"", 0);
      if(p >= 0)
      {
         int c = StringFind(line, ":", p);
         if(c >= 0)
         {
            string num = StringSubstr(line, c+1);
            StringTrimLeft(num);
            cur_wr = StringToDouble(num);
         }
      }
      
      // avg_R
      p = StringFind(line, "\"avg_R\"", 0);
      if(p >= 0)
      {
         int c = StringFind(line, ":", p);
         if(c >= 0)
         {
            string num = StringSubstr(line, c+1);
            StringTrimLeft(num);
            cur_avgR = StringToDouble(num);
         }
      }
      
      // profit_factor
      p = StringFind(line, "\"profit_factor\"", 0);
      if(p >= 0)
      {
         int c = StringFind(line, ":", p);
         if(c >= 0)
         {
            string num = StringSubstr(line, c+1);
            StringTrimLeft(num);
            cur_pf = StringToDouble(num);
         }
      }
      
      // max_drawdown_R
      p = StringFind(line, "\"max_drawdown_R\"", 0);
      if(p >= 0)
      {
         int c = StringFind(line, ":", p);
         if(c >= 0)
         {
            string num = StringSubstr(line, c+1);
            StringTrimLeft(num);
            cur_dd = StringToDouble(num);
         }
      }
      
      // Commit when we have strategy and symbol
      if(cur_s != "" && cur_y != "" && cur_tf >= 0)
      {
         int n = ArraySize(out_strat);
         ArrayResize(out_strat, n+1);
         ArrayResize(out_sym, n+1);
         ArrayResize(out_tf, n+1);
         ArrayResize(out_cnt, n+1);
         ArrayResize(out_wr, n+1);
         ArrayResize(out_avgR, n+1);
         ArrayResize(out_pf, n+1);
         ArrayResize(out_dd, n+1);
         
         out_strat[n] = cur_s;
         out_sym[n] = cur_y;
         out_tf[n] = cur_tf;
         out_cnt[n] = cur_cnt;
         out_wr[n] = cur_wr;
         out_avgR[n] = cur_avgR;
         out_pf[n] = cur_pf;
         out_dd[n] = cur_dd;
         
         // Reset for next slice
         cur_s = "";
         cur_y = "";
         cur_tf = -1;
         cur_cnt = 0;
         cur_wr = 0.0;
         cur_avgR = 0.0;
         cur_pf = 0.0;
         cur_dd = 0.0;
      }
   }
   
   FileClose(h);
   
   int loaded = ArraySize(out_strat);
   if(loaded > 0)
      PrintFormat("[InsightsLoader] Loaded %d insight slices", loaded);
   else
      Print("[InsightsLoader] No slices loaded (cold start mode)");
   
   return loaded;
}

#endif // INSIGHTSLOADER_MQH
