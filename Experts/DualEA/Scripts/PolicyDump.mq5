//+------------------------------------------------------------------+
//|                                                PolicyDump.mq5    |
//| Purpose: Dump DualEA policy.json summary to Journal              |
//| Location: FILE_COMMON/DualEA/policy.json                         |
//+------------------------------------------------------------------+
#property script_show_inputs

input string InPolicyPath   = "DualEA\\policy.json";  // FILE_COMMON path
input int    MaxPrintSlices  = 20;                      // how many slices to print

// Trim helpers
string TrimCopy(string s)
{
   StringTrimLeft(s);
   StringTrimRight(s);
   return s;
}

void OnStart()
{
   string path = InPolicyPath;
   int h = FileOpen(path, FILE_READ|FILE_TXT|FILE_COMMON|FILE_ANSI);
   if(h==INVALID_HANDLE)
   {
      PrintFormat("PolicyDump: cannot open %s (Common). Err=%d", path, GetLastError());
      return;
   }

   double min_conf = 0.0;
   // current object fields
   string cur_s = "";
   string cur_y = "";
   int    cur_tf = -1;
   double cur_p  = -1.0;
   double cur_sl = 1.0, cur_tp = 1.0, cur_tr = 1.0;

   // storage for first MaxPrintSlices
   string s_list[]; string y_list[]; int tf_list[]; double p_list[]; double sl_list[]; double tp_list[]; double tr_list[];
   int total = 0;

   while(!FileIsEnding(h))
   {
      string line = FileReadString(h);
      if(line=="" && FileIsEnding(h)) break;

      int p;
      // min_confidence
      p = StringFind(line, "\"min_confidence\"", 0);
      if(p>=0)
      {
         int c = StringFind(line, ":", p);
         if(c>=0)
         {
            string num = TrimCopy(StringSubstr(line, c+1));
            double v = StringToDouble(num);
            if(v>0.0) min_conf = v;
         }
      }
      // strategy
      p = StringFind(line, "\"strategy\"", 0);
      if(p>=0)
      {
         int q = StringFind(line, ",", p+1); string seg = (q>p? StringSubstr(line, p, q-p) : StringSubstr(line, p));
         int c3=StringFind(seg, "\"", 0); c3 = StringFind(seg, "\"", c3+1); int c4=StringFind(seg, "\"", c3+1); int c5=StringFind(seg, "\"", c4+1);
         if(c4>0 && c5>c4) cur_s = StringSubstr(seg, c4+1, c5-c4-1);
      }
      // symbol
      p = StringFind(line, "\"symbol\"", 0);
      if(p>=0)
      {
         int q = StringFind(line, ",", p+1); string seg = (q>p? StringSubstr(line, p, q-p) : StringSubstr(line, p));
         int c3=StringFind(seg, "\"", 0); c3 = StringFind(seg, "\"", c3+1); int c4=StringFind(seg, "\"", c3+1); int c5=StringFind(seg, "\"", c4+1);
         if(c4>0 && c5>c4) cur_y = StringSubstr(seg, c4+1, c5-c4-1);
      }
      // timeframe
      p = StringFind(line, "\"timeframe\"", 0);
      if(p>=0)
      {
         int c = StringFind(line, ":", p);
         if(c>=0){ string num = TrimCopy(StringSubstr(line, c+1)); cur_tf = (int)StringToInteger(num); }
      }
      // p_win
      p = StringFind(line, "\"p_win\"", 0);
      if(p>=0)
      {
         int c = StringFind(line, ":", p);
         if(c>=0){ string num = TrimCopy(StringSubstr(line, c+1)); cur_p = StringToDouble(num); }
      }
      // sl_scale
      p = StringFind(line, "\"sl_scale\"", 0);
      if(p>=0)
      {
         int c = StringFind(line, ":", p); if(c>=0){ string num = TrimCopy(StringSubstr(line, c+1)); double v = StringToDouble(num); if(v>0) cur_sl = v; }
      }
      // tp_scale
      p = StringFind(line, "\"tp_scale\"", 0);
      if(p>=0)
      {
         int c = StringFind(line, ":", p); if(c>=0){ string num = TrimCopy(StringSubstr(line, c+1)); double v = StringToDouble(num); if(v>0) cur_tp = v; }
      }
      // trail_atr_mult
      p = StringFind(line, "\"trail_atr_mult\"", 0);
      if(p>=0)
      {
         int c = StringFind(line, ":", p); if(c>=0){ string num = TrimCopy(StringSubstr(line, c+1)); double v = StringToDouble(num); if(v>0) cur_tr = v; }
      }

      // Commit object when complete
      if(cur_s!="" && cur_y!="" && cur_tf!=-1 && cur_p>=0.0)
      {
         total++;
         if(ArraySize(s_list) < MaxPrintSlices)
         {
            int n = ArraySize(s_list);
            ArrayResize(s_list,n+1); ArrayResize(y_list,n+1); ArrayResize(tf_list,n+1);
            ArrayResize(p_list,n+1); ArrayResize(sl_list,n+1); ArrayResize(tp_list,n+1); ArrayResize(tr_list,n+1);
            s_list[n]=cur_s; y_list[n]=cur_y; tf_list[n]=cur_tf;
            p_list[n]=cur_p; sl_list[n]=cur_sl; tp_list[n]=cur_tp; tr_list[n]=cur_tr;
         }
         // Reset current
         cur_s=""; cur_y=""; cur_tf=-1; cur_p=-1.0; cur_sl=1.0; cur_tp=1.0; cur_tr=1.0;
      }
   }
   FileClose(h);

   PrintFormat("PolicyDump: min_confidence=%.3f, slices=%d", min_conf, total);
   int N = ArraySize(s_list);
   for(int i=0;i<N;++i)
   {
      PrintFormat("PolicyDump: [%d] %s | %s | tf=%d | p=%.3f | sl=%.2f tp=%.2f tr=%.2f",
                  i+1, s_list[i], y_list[i], tf_list[i], p_list[i], sl_list[i], tp_list[i], tr_list[i]);
   }
   if(total>N)
      PrintFormat("PolicyDump: (only first %d slices shown)", N);
}
