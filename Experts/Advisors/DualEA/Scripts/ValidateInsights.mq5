// #property script_show_inputs  // disabled for headless runs (kb_check)
#property strict

// DualEA Scripts/ValidateInsights.mq5
// Validates DualEA\insights.json schema presence and slice coverage in Common Files.
// Also checks staleness against features.csv and knowledge_base.csv.
// Writes a compact report to DualEA\insights_validation.txt

input string RequireSymbolsCSV      = "";    // e.g. "USDCNH,EURUSD"
input string RequireTimeframesCSV   = "";    // e.g. "10,15,60"
input string RequireStrategiesCSV   = "";    // e.g. "BollAverages,DonchianATRBreakout"
input bool   FailOnStale            = false;  // non-zero return code via Print/Alert pattern
input bool   FailOnEmptySlices      = false;  // non-zero return code via Print/Alert pattern
input bool   WriteReport            = true;
input string ReportFile             = "DualEA\\insights_validation.txt"; // Common Files
input bool   FailOnMissingRequired  = false;  // fail if any required symbol/strategy/timeframe missing
input string RequirementsConfig     = "DualEA\\validate_requirements.txt"; // Common Files config

// --- small utils ---
string TrimCopy(const string s)
{
   string r = s;
   StringTrimLeft(r);
   StringTrimRight(r);
   return r;
}
string StripQuotes(const string s)
{
   string r = TrimCopy(s);
   int n = StringLen(r);
   if(n>=2 && StringGetCharacter(r,0)=='"' && StringGetCharacter(r,n-1)=='"')
      return StringSubstr(r,1,n-2);
   return r;
}
void PushUniqueS(string &arr[], const string v)
{
   for(int i=0;i<ArraySize(arr);++i) if(arr[i]==v) return;
   int k=ArraySize(arr); ArrayResize(arr,k+1); arr[k]=v;
}
void PushUniqueI(int &arr[], const int v)
{
   for(int i=0;i<ArraySize(arr);++i) if(arr[i]==v) return;
   int k=ArraySize(arr); ArrayResize(arr,k+1); arr[k]=v;
}
void SplitCSVList(const string csv, string &out[])
{
   ArrayResize(out,0);
   if(StringLen(TrimCopy(csv))==0) return;
   ushort sep = (ushort)StringGetCharacter(",",0);
   string parts[]; int cnt = StringSplit(csv, sep, parts);
   for(int i=0;i<cnt;++i)
   {
      string t = TrimCopy(parts[i]);
      if(StringLen(t)>0) PushUniqueS(out, t);
   }
}

string JoinStrings(const string &arr[], const string sep)
{
   string out="";
   for(int i=0;i<ArraySize(arr);++i){ if(i>0) out+=sep; out+=arr[i]; }
   return out;
}
string JoinInts(const int &arr[], const string sep)
{
   string out="";
   for(int i=0;i<ArraySize(arr);++i){ if(i>0) out+=sep; out+=IntegerToString(arr[i]); }
   return out;
}

void LoadRequirementsFromConfig(const string path,
                                 string &symsCSV,
                                 string &tfsCSV,
                                 string &stratsCSV,
                                 bool &failMissing)
{
   int h = FileOpen(path, FILE_READ|FILE_COMMON|FILE_TXT|FILE_ANSI);
   if(h==INVALID_HANDLE) return;
   while(!FileIsEnding(h))
   {
      string line = FileReadString(h);
      if(line=="" && FileIsEnding(h)) break;
      string t = TrimCopy(line);
      if(StringLen(t)==0) continue;
      if(StringGetCharacter(t,0)=='#') continue;
      int eq = StringFind(t, "=", 0);
      if(eq<0) continue;
      string key = TrimCopy(StringSubstr(t,0,eq));
      string val = TrimCopy(StringSubstr(t,eq+1));
      if(key=="RequireSymbolsCSV") symsCSV = val;
      else if(key=="RequireTimeframesCSV") tfsCSV = val;
      else if(key=="RequireStrategiesCSV") stratsCSV = val;
      else if(key=="FailOnMissingRequired")
      {
         failMissing = (val=="1" || val=="true" || val=="yes" || val=="y");
      }
   }
   FileClose(h);
}

int CountOccurrencesInSection(const string path, const string section_key, const string field_key)
{
   int h = FileOpen(path, FILE_READ|FILE_COMMON|FILE_TXT|FILE_ANSI);
   if(h==INVALID_HANDLE) return 0;
   bool in_section=false; int count=0;
   while(!FileIsEnding(h))
   {
      string line = FileReadString(h);
      if(line=="" && FileIsEnding(h)) break;
      if(StringFind(line, section_key, 0)>=0) { in_section=true; continue; }
      if(in_section)
      {
         if(StringFind(line, "]", 0)>=0) { in_section=false; continue; }
         if(StringFind(line, field_key, 0)>=0) count++;
      }
   }
   FileClose(h);
   return count;
}

void Validate()
{
   string INS = "DualEA\\insights.json";
   string FEAT= "DualEA\\features.csv";
   string KB  = "DualEA\\knowledge_base.csv";

   bool ins_exists = (FileGetInteger(INS, FILE_EXISTS, true)>0);
   bool feat_exists= (FileGetInteger(FEAT, FILE_EXISTS, true)>0);
   bool kb_exists  = (FileGetInteger(KB, FILE_EXISTS, true)>0);

   if(!ins_exists)
   {
      Print("[VALIDATE] insights.json: NOT FOUND in Common Files/DualEA");
      return;
   }

   datetime t_ins = (datetime)FileGetInteger(INS, FILE_MODIFY_DATE, true);
   datetime t_feat= (feat_exists? (datetime)FileGetInteger(FEAT, FILE_MODIFY_DATE, true) : 0);
   datetime t_kb  = (kb_exists?   (datetime)FileGetInteger(KB,   FILE_MODIFY_DATE, true) : 0);
   bool is_stale = (feat_exists && t_feat>t_ins) || (kb_exists && t_kb>t_ins);

   // Totals presence check
   int h = FileOpen(INS, FILE_READ|FILE_COMMON|FILE_TXT|FILE_ANSI);
   if(h==INVALID_HANDLE)
   {
      Print("[VALIDATE] ERROR: cannot open insights.json (encoding?)");
      return;
   }
   bool has_schema=false, has_generated=false, has_totals=false;
   int total_trade_count=-1;
   while(!FileIsEnding(h))
   {
      string line = FileReadString(h);
      if(line=="" && FileIsEnding(h)) break;
      if(StringFind(line, "schema_version", 0)>=0) has_schema=true;
      if(StringFind(line, "generated_at", 0)>=0) has_generated=true;
      if(StringFind(line, "totals", 0)>=0) has_totals=true;
      int p = StringFind(line, "trade_count", 0);
      if(p>=0)
      {
         int c = StringFind(line, ":", p);
         if(c>=0) total_trade_count = (int)StringToInteger(TrimCopy(StringSubstr(line, c+1)));
      }
   }
   FileClose(h);

   // Section counts
   int cnt_by_strategy = CountOccurrencesInSection(INS, "by_strategy", "strategy");
   int cnt_by_tf       = CountOccurrencesInSection(INS, "by_timeframe", "timeframe");

   // Slice coverage with uniques
   int hs = FileOpen(INS, FILE_READ|FILE_COMMON|FILE_TXT|FILE_ANSI);
   bool in_slice=false; string cur_s="", cur_y=""; int cur_tf=-1; int slice_count=0;
   string uniq_syms[]; string uniq_strats[]; int uniq_tfs[];
   if(hs!=INVALID_HANDLE)
   {
      while(!FileIsEnding(hs))
      {
         string line = FileReadString(hs);
         if(line=="" && FileIsEnding(hs)) break;
         if(StringFind(line, "by_symbol_strategy_timeframe", 0)>=0) { in_slice=true; continue; }
         if(in_slice)
         {
            if(StringFind(line, "]", 0)>=0) { in_slice=false; continue; }
            int p;
            // Robust extraction: find ':' after key, then take the next quoted value
            int ps = StringFind(line, "strategy", 0);
            if(ps>=0)
            {
               int colon = StringFind(line, ":", ps);
               if(colon>=0)
               {
                  int q1 = StringFind(line, "\"", colon);
                  int q2 = StringFind(line, "\"", q1+1);
                  if(q1>=0 && q2>q1) cur_s = StringSubstr(line, q1+1, q2-q1-1);
               }
            }
            int py = StringFind(line, "symbol", 0);
            if(py>=0)
            {
               int colon2 = StringFind(line, ":", py);
               if(colon2>=0)
               {
                  int q1 = StringFind(line, "\"", colon2);
                  int q2 = StringFind(line, "\"", q1+1);
                  if(q1>=0 && q2>q1) cur_y = StringSubstr(line, q1+1, q2-q1-1);
               }
            }
            p = StringFind(line, "timeframe", 0);
            if(p>=0)
            {
               int c = StringFind(line, ":", p); if(c>=0){ string num = TrimCopy(StringSubstr(line, c+1)); cur_tf = (int)StringToInteger(num); }
            }
            // Commit object when we see closing brace on its line
            if(StringFind(line, "}", 0)>=0)
            {
               if(cur_s!="" && cur_y!="" && cur_tf!=-1)
               {
                  slice_count++;
                  PushUniqueS(uniq_syms, cur_y);
                  PushUniqueS(uniq_strats, cur_s);
                  PushUniqueI(uniq_tfs, cur_tf);
               }
               cur_s=""; cur_y=""; cur_tf=-1;
            }
         }
      }
      FileClose(hs);
   }

   // Fallback: if parser failed (e.g., formatting nuances), fall back to simple token counting inside section
   if(slice_count==0)
   {
      int hf = FileOpen(INS, FILE_READ|FILE_COMMON|FILE_TXT|FILE_ANSI);
      bool in_section=false; 
      if(hf!=INVALID_HANDLE)
      {
         while(!FileIsEnding(hf))
         {
            string line = FileReadString(hf);
            if(line=="" && FileIsEnding(hf)) break;
            if(StringFind(line, "by_symbol_strategy_timeframe", 0)>=0) { in_section=true; continue; }
            if(in_section)
            {
               if(StringFind(line, "]", 0)>=0) { in_section=false; continue; }
               if(StringFind(line, "\"strategy\"", 0)>=0)
               {
                  // count as one slice; best-effort unique extraction
                  slice_count++;
                  // strategy
                  int ks = StringFind(line, "\"strategy\"", 0);
                  if(ks>=0){ int cs=StringFind(line, ":", ks); int q1=StringFind(line, "\"", cs); int q2=StringFind(line, "\"", q1+1); if(q1>=0 && q2>q1) PushUniqueS(uniq_strats, StringSubstr(line, q1+1, q2-q1-1)); }
                  // symbol
                  int ky = StringFind(line, "\"symbol\"", 0);
                  if(ky>=0){ int cs2=StringFind(line, ":", ky); int q1=StringFind(line, "\"", cs2); int q2=StringFind(line, "\"", q1+1); if(q1>=0 && q2>q1) PushUniqueS(uniq_syms, StringSubstr(line, q1+1, q2-q1-1)); }
                  // timeframe
                  int kt = StringFind(line, "timeframe", 0);
                  if(kt>=0){ int ct=StringFind(line, ":", kt); if(ct>=0){ string num=TrimCopy(StringSubstr(line, ct+1)); int tf=(int)StringToInteger(num); PushUniqueI(uniq_tfs, tf); } }
               }
            }
         }
         FileClose(hf);
      }
   }

   // Optional expected coverage
   string reqSyms[]; string reqStrats[]; string reqTFsS[]; SplitCSVList(RequireSymbolsCSV, reqSyms); SplitCSVList(RequireStrategiesCSV, reqStrats); SplitCSVList(RequireTimeframesCSV, reqTFsS);
   int reqTFs[]; for(int i=0;i<ArraySize(reqTFsS);++i) { int v=(int)StringToInteger(reqTFsS[i]); PushUniqueI(reqTFs, v);} 

   // Merge requirements from optional Common Files config
   string cfgSymsCSV="", cfgTFsCSV="", cfgStratsCSV=""; bool cfgFail=false;
   LoadRequirementsFromConfig(RequirementsConfig, cfgSymsCSV, cfgTFsCSV, cfgStratsCSV, cfgFail);
   string cfgSyms[]; string cfgStrats[]; string cfgTFsS[];
   SplitCSVList(cfgSymsCSV, cfgSyms); SplitCSVList(cfgStratsCSV, cfgStrats); SplitCSVList(cfgTFsCSV, cfgTFsS);
   int cfgTFs[]; for(int i=0;i<ArraySize(cfgTFsS);++i){ int v=(int)StringToInteger(cfgTFsS[i]); PushUniqueI(cfgTFs, v);} 
   for(int i=0;i<ArraySize(cfgSyms);++i) PushUniqueS(reqSyms, cfgSyms[i]);
   for(int i=0;i<ArraySize(cfgStrats);++i) PushUniqueS(reqStrats, cfgStrats[i]);
   for(int i=0;i<ArraySize(cfgTFs);++i) PushUniqueI(reqTFs, cfgTFs[i]);
   bool fail_missing_required = (FailOnMissingRequired || cfgFail);

   // Build report
   string report="";
   string common_path = TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\DualEA";
   report += "parser_version: 2\n";
   report += "common_path: "+common_path+"\n";
   report += "insights.json mtime : "+TimeToString(t_ins, TIME_DATE|TIME_MINUTES|TIME_SECONDS)+"\n";
   if(feat_exists) report += "features.csv  mtime : "+TimeToString(t_feat, TIME_DATE|TIME_MINUTES|TIME_SECONDS)+"\n";
   if(kb_exists)   report += "knowledge_base.csv mtime : "+TimeToString(t_kb, TIME_DATE|TIME_MINUTES|TIME_SECONDS)+"\n";
   report += "stale: "+(is_stale?"true":"false")+"\n";
   report += "totals.trade_count: "+IntegerToString(total_trade_count)+"\n";
   report += "by_strategy.count: "+IntegerToString(cnt_by_strategy)+"\n";
   report += "by_timeframe.count: "+IntegerToString(cnt_by_tf)+"\n";
   report += "by_symbol_strategy_timeframe.count: "+IntegerToString(slice_count)+"\n";
   report += "uniques: symbols="+IntegerToString(ArraySize(uniq_syms))+" strategies="+IntegerToString(ArraySize(uniq_strats))+" timeframes="+IntegerToString(ArraySize(uniq_tfs))+"\n";
   report += "uniques.symbols: "+JoinStrings(uniq_syms, ",")+"\n";
   report += "uniques.strategies: "+JoinStrings(uniq_strats, ",")+"\n";
   report += "uniques.timeframes: "+JoinInts(uniq_tfs, ",")+"\n";

   // Alerts
   bool has_errors=false;
   if(is_stale) { report += "ALERT: insights.json is STALE vs sources\n"; if(FailOnStale) has_errors=true; }
   if(slice_count==0) { report += "ALERT: no slices in by_symbol_strategy_timeframe\n"; if(FailOnEmptySlices) has_errors=true; }

   bool missing_required=false;
   for(int i=0;i<ArraySize(reqSyms);++i)
   {
      bool present=false; for(int j=0;j<ArraySize(uniq_syms);++j) if(uniq_syms[j]==reqSyms[i]) { present=true; break; }
      if(!present) { report += "WARN: required symbol missing: "+reqSyms[i]+"\n"; missing_required=true; }
   }
   for(int i=0;i<ArraySize(reqStrats);++i)
   {
      bool present=false; for(int j=0;j<ArraySize(uniq_strats);++j) if(uniq_strats[j]==reqStrats[i]) { present=true; break; }
      if(!present) { report += "WARN: required strategy missing: "+reqStrats[i]+"\n"; missing_required=true; }
   }
   for(int i=0;i<ArraySize(reqTFs);++i)
   {
      bool present=false; for(int j=0;j<ArraySize(uniq_tfs);++j) if(uniq_tfs[j]==reqTFs[i]) { present=true; break; }
      if(!present) { report += "WARN: required timeframe missing: "+IntegerToString(reqTFs[i])+"\n"; missing_required=true; }
   }
   if(missing_required && fail_missing_required) { report += "ALERT: required coverage missing\n"; has_errors=true; }

   if(WriteReport)
   {
      int w = FileOpen(ReportFile, FILE_WRITE|FILE_COMMON|FILE_TXT|FILE_ANSI);
      if(w!=INVALID_HANDLE) { FileWriteString(w, report); FileClose(w); }
      else { PrintFormat("[VALIDATE] cannot write report '%s' (err=%d)", ReportFile, GetLastError()); }
   }

   if(has_errors) Print("[VALIDATE] FAILED"); else Print("[VALIDATE] OK");
   Print("[VALIDATE] Summary:\n"+report);
}

void OnStart()
{
   Print("ValidateInsights: starting");
   Validate();
   Print("ValidateInsights: done");
}
