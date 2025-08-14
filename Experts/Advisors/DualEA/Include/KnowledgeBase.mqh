// KnowledgeBase.mqh
// Shared functions for reading from and writing to the knowledge base.

#property copyright "2025, Windsurf Engineering"
#property link      "https://www.windsurf.ai"

#include <Files\File.mqh>
// Centralized default strategy names
#include <Strategies\Registry.mqh>

// --- Defines the structure for a single trade record
struct TradeRecord
  {
   datetime          timestamp;        // Trade execution timestamp
   string            symbol;           // Trading symbol
   ENUM_ORDER_TYPE   type;             // Order type (e.g., ORDER_TYPE_BUY, ORDER_TYPE_SELL)
   double            entry_price;      // Price at which the trade was opened
   double            stop_loss;        // Stop loss level
   double            take_profit;      // Take profit level
   double            close_price;      // Price at which the trade was closed
   double            profit;           // Profit or loss from the trade
   string            strategy_id;      // ID of the strategy that generated the trade
  };
// Uncomment to enable verbose parsing diagnostics
//#define INSIGHTS_DEBUG

// --- Class to manage knowledge base operations
class CKnowledgeBase
  {
private:
   string            m_file_path;      // Path to the knowledge base file
   int               m_file_handle;    // File handle
   string            m_csv_delimiter;  // CSV delimiter

public:
                     CKnowledgeBase(string file_name="DualEA\\knowledge_base.csv", string delimiter=",");
                     ~CKnowledgeBase();

   // --- Methods for data handling
   bool              WriteRecord(const TradeRecord &record);
   bool              LogTrade(const string strategy_name, const int retcode, const ulong deal, const ulong order_id);

private:
   bool              OpenFile(int flags=FILE_WRITE|FILE_READ|FILE_CSV);
   void              CloseFile();
  };

// --- Class to manage features.csv logging (long format: one feature per row)
class CFeaturesKB
  {
 private:
    string m_file_path;
    int    m_file_handle;
    string m_csv_delim;
    void   EnsureHeader()
      {
       // Ensure folder exists and header is present
       FolderCreate("DualEA", FILE_COMMON);
       int h = FileOpen(m_file_path, FILE_READ|FILE_CSV|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_COMMON);
       if(h==INVALID_HANDLE)
         {
          h = FileOpen(m_file_path, FILE_WRITE|FILE_CSV|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_COMMON);
          if(h!=INVALID_HANDLE)
            {
             FileWriteString(h, "timestamp,symbol,strategy,feature,value\n");
             FileClose(h);
            }
         }
       else
         {
          if(FileSize(h)==0)
            {
             FileClose(h);
             h = FileOpen(m_file_path, FILE_WRITE|FILE_CSV|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_COMMON);
             if(h!=INVALID_HANDLE)
                FileWriteString(h, "timestamp,symbol,strategy,feature,value\n");
            }
          if(h!=INVALID_HANDLE) FileClose(h);
         }
       string full = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\" + m_file_path;
       PrintFormat("KnowledgeBase: writing features CSV to Common Files: %s", full);
      }
 public:
                  CFeaturesKB(string file_name="DualEA\\features.csv", string delimiter=",")
                    {
                     m_file_path = file_name;
                     m_csv_delim = delimiter;
                     m_file_handle = INVALID_HANDLE;
                     EnsureHeader();
                    }
                  ~CFeaturesKB() {}
    bool          WriteKV(const datetime ts, const string symbol, const string strategy, const string feature, const double value)
                    {
                     int h = INVALID_HANDLE;
                     // Retry open to mitigate transient locks from readers/writers
                     for(int attempt=0; attempt<10 && h==INVALID_HANDLE; ++attempt)
                       {
                        h = FileOpen(m_file_path, FILE_READ|FILE_WRITE|FILE_CSV|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_COMMON);
                        if(h==INVALID_HANDLE) Sleep(25);
                       }
                     if(h==INVALID_HANDLE)
                       {
                        PrintFormat("Error opening features file '%s'. Error: %d", m_file_path, GetLastError());
                        return false;
                       }
                     if(FileSize(h)==0)
                        FileWriteString(h, "timestamp,symbol,strategy,feature,value\n");
                     FileSeek(h, 0, SEEK_END);
                     string line = TimeToString(ts) + m_csv_delim + symbol + m_csv_delim + strategy + m_csv_delim + feature + m_csv_delim + DoubleToString(value, 8);
                     FileWriteString(h, line + "\n");
                     FileClose(h);
                     return true;
                    }
  };

// --- Insights builder: reads KB and emits insights.json (basic counts scaffold)
class CInsightsBuilder
  {
 private:
    string m_kb_path;
    string m_features_path;
    string m_out_path;
    string m_delim;
    // --- helpers
    string Trim(string s)
      {
       StringTrimLeft(s);
        StringTrimRight(s);
        return s;
      }
    string StripQuotes(string s)
      {
       s = Trim(s);
       // strip BOM if present (U+FEFF or UTF-8 BOM 0xEF 0xBB 0xBF)
       if(StringLen(s)>0)
         {
          int c0 = StringGetCharacter(s,0);
          // U+FEFF
          if(c0==65279)
             s = StringSubstr(s,1);
          else if(StringLen(s)>=3)
            {
             int b0 = c0;
             int b1 = StringGetCharacter(s,1);
             int b2 = StringGetCharacter(s,2);
             if(b0==239 && b1==187 && b2==191)
                s = StringSubstr(s,3);
            }
         }
       // remove surrounding quotes
       if(StringLen(s)>=2 && StringSubstr(s,0,1)=="\"" && StringSubstr(s,StringLen(s)-1,1)=="\"")
          s = StringSubstr(s,1,StringLen(s)-2);
       // remove stray quotes
       StringReplace(s, "\"", "");
       // remove CR/LF and NBSP
       StringReplace(s, "\r", "");
        StringReplace(s, "\n", "");
        // remove non-breaking space (char code 160)
        for(int i=0;i<StringLen(s);++i){ if(StringGetCharacter(s,i)==160){ s = StringSubstr(s,0,i)+StringSubstr(s,i+1); i--; } }
       return s;
      }
    string NormalizeToken(string s)
      {
       s = StripQuotes(s);
       // StringToLower modifies in place; do not assign its return value
       StringToLower(s);
       string out="";
       for(int i=0;i<StringLen(s);++i)
         {
          int ch = StringGetCharacter(s,i);
          bool ok = (ch>='a' && ch<='z') || (ch>='0' && ch<='9') || (ch=='_');
          if(ok)
             out = out + StringSubstr(s,i,1);
         }
       return out;
      }
    int    FindIndexString(string &arr[], const string key)
      {
       for(int i=0;i<ArraySize(arr);++i)
         if(arr[i]==key) return i;
       return -1;
      }
    void   PushUnique(string &arr[], const string key)
      {
       if(FindIndexString(arr,key)<0)
         {
          int n = ArraySize(arr);
          ArrayResize(arr, n+1);
          arr[n] = key;
         }
      }
    double SafeDiv(const double a, const double b)
      {
       if(b==0.0) return 0.0;
       return a/b;
      }
    double Median(double &values[])
      {
       int n = ArraySize(values);
       if(n==0) return 0.0;
       // Work on a copy to avoid side effects
       double tmp[];
       ArrayResize(tmp, n);
       for(int i=0;i<n;++i) tmp[i]=values[i];
       ArraySort(tmp);
       if((n % 2)==1)
          return tmp[n/2];
       return 0.5*(tmp[n/2-1] + tmp[n/2]);
      }
    double MaxDrawdownR(double &r_series[])
      {
       // Computes max peak-to-trough drawdown on cumulative R
       int n = ArraySize(r_series);
       if(n==0) return 0.0;
       double cum=0.0, peak=0.0, maxdd=0.0;
       for(int i=0;i<n;++i)
         {
          cum += r_series[i];
          if(cum>peak) peak=cum;
          double dd = peak - cum; // in R
          if(dd>maxdd) maxdd=dd;
         }
       return maxdd;
      }
  public:
                  CInsightsBuilder(string kb_path="DualEA\\knowledge_base.csv", string features_path="DualEA\\features.csv", string out_path="DualEA\\insights.json", string delim=",")
                    {
                     m_kb_path = kb_path;
                     m_features_path = features_path;
                     m_out_path = out_path;
                     m_delim = delim;
                    }
    bool          Build()
                    {
                    // Build insights from features.csv using r_multiple rows
                    // Open features.csv with explicit comma delimiter
                    int hf = FileOpen(m_features_path, FILE_READ|FILE_CSV|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_COMMON, (ushort)',');
                    if(hf==INVALID_HANDLE)
                      {
                       PrintFormat("InsightsBuilder: cannot open features '%s'. Err=%d", m_features_path, GetLastError());
                       return false;
                      }

                    // Storage of r-multiples with metadata (plus optional timeframe)
                    datetime ts_list[]; string sym_list[]; string strat_list[]; double r_list[]; int tf_list[];
                    // Map (symbol|strategy) -> timeframe (last seen)
                    string tf_keys[]; int tf_vals[];
                    // Collect all observed (symbol|strategy) pairs to support synthesis when timeframe is absent
                    string all_keys[];

                    // Robust CSV scan: 5 fields per row, skip header if present
                    bool header_checked=false;
                    int parsed_rows=0;
                    while(!FileIsEnding(hf))
                      {
                       string ts = FileReadString(hf);
                       if(ts=="" && FileIsEnding(hf)) break;
                       string sym = FileReadString(hf);
                       string strat = FileReadString(hf);
                       string feat = FileReadString(hf);
                       string val  = FileReadString(hf);

                       // Trim all fields to avoid CR/whitespace issues
                       ts    = StripQuotes(ts);
                       sym   = StripQuotes(sym);
                       strat = StripQuotes(strat);
                       feat  = StripQuotes(feat);
                       val   = StripQuotes(val);

                       if(feat=="") { continue; }
                       if(!header_checked)
                         {
                          header_checked=true;
                          string ts_norm = NormalizeToken(ts);
                          string feat_norm_dbg = NormalizeToken(feat);
                          int c0 = (StringLen(ts)>0? StringGetCharacter(ts,0) : -1);
                          #ifdef INSIGHTS_DEBUG
                          PrintFormat("InsightsBuilder: header-check ts_raw='%s' ts_norm='%s' c0=%d feat_raw='%s' feat_norm='%s'", ts, ts_norm, c0, feat, feat_norm_dbg);
                          #endif
                          if(ts_norm=="timestamp")
                              continue; // skip header row
                         }

                       // Count this parsed data row (post header)
                       parsed_rows++;
                       if(parsed_rows<=5)
                         {
                          string feat_norm = NormalizeToken(feat);
                          #ifdef INSIGHTS_DEBUG
                          PrintFormat("InsightsBuilder: sample row %d feat='%s' feat_norm='%s' val='%s'", parsed_rows-1, feat, feat_norm, val);
                          #endif
                         }

                       // Track (symbol|strategy) pairs from any feature rows
                       if(sym!="" && strat!="")
                         {
                          string key_any = sym + "|" + strat;
                          PushUnique(all_keys, key_any);
                         }

                       string feat_norm_main = NormalizeToken(feat);
                       if(feat_norm_main=="timeframe")
                         {
                          // record latest timeframe for (symbol,strategy)
                          int tfv = (int)StringToInteger(val);
                          string key = sym+"|"+strat;
                          bool updated=false;
                          for(int i=0;i<ArraySize(tf_keys);++i){ if(tf_keys[i]==key){ tf_vals[i]=tfv; updated=true; break; } }
                          if(!updated){ int k=ArraySize(tf_keys); ArrayResize(tf_keys,k+1); ArrayResize(tf_vals,k+1); tf_keys[k]=key; tf_vals[k]=tfv; }
                         }
                       else if(feat_norm_main=="r_multiple")
                         {
                          int n = ArraySize(r_list);
                          ArrayResize(ts_list, n+1);
                          ArrayResize(sym_list, n+1);
                          ArrayResize(strat_list, n+1);
                          ArrayResize(r_list, n+1);
                          ArrayResize(tf_list, n+1);
                          ts_list[n]    = StringToTime(ts);
                          sym_list[n]   = sym;
                          strat_list[n] = strat;
                          r_list[n]     = StringToDouble(val);
                          // lookup timeframe if available
                          int tfv=-1; string key2 = sym_list[n]+"|"+strat_list[n];
                          for(int j=0;j<ArraySize(tf_keys);++j){ if(tf_keys[j]==key2){ tfv=tf_vals[j]; break; } }
                          tf_list[n]    = tfv;
                          #ifdef INSIGHTS_DEBUG
                          if(n<5)
                            PrintFormat("InsightsBuilder: captured r_multiple row ts=%s sym=%s strat=%s r=%f", ts, sym, strat, r_list[n]);
                          #endif
                         }
                      }
                    FileClose(hf);

                    int total = ArraySize(r_list);
                    PrintFormat("InsightsBuilder: scanned rows=%d, r_multiple rows=%d from features '%s'", parsed_rows, total, m_features_path);
                    // --- Fallback: if no r_multiple labels were found, derive metrics from knowledge_base.csv using profit as surrogate
                    if(total==0)
                      {
                       // Secondary fallback: parse features.csv as raw text lines and split by comma
                       int ht = FileOpen(m_features_path, FILE_READ|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_COMMON|FILE_ANSI);
                       if(ht!=INVALID_HANDLE)
                         {
                          int added=0; bool header_seen=false;
                          while(!FileIsEnding(ht))
                            {
                             string line = FileReadString(ht);
                              line = Trim(line);
                              if(line=="") continue;
                              string parts[];
                              ushort sep = (ushort)StringGetCharacter(",",0);
                              int cnt = StringSplit(line, sep, parts);
                              if(cnt<5) continue;
                              // parts: 0 ts,1 sym,2 strat,3 feat,4 val
                              string ts_s = StripQuotes(parts[0]);
                             if(!header_seen)
                               {
                                header_seen=true;
                                if(NormalizeToken(ts_s)=="timestamp") continue; // skip header
                               }
                             // Track (symbol|strategy) pairs from any feature rows (text fallback)
                             string sy0 = StripQuotes(parts[1]);
                             string st0 = StripQuotes(parts[2]);
                             if(sy0!="" && st0!="") PushUnique(all_keys, sy0+"|"+st0);
                             string f_s  = StripQuotes(parts[3]);
                             string f_norm = NormalizeToken(f_s);
                             if(f_norm=="timeframe")
                               {
                                int tfv = (int)StringToInteger(StripQuotes(parts[4]));
                                string sy = StripQuotes(parts[1]); string st = StripQuotes(parts[2]);
                                string key = sy+"|"+st; bool updated=false;
                                for(int i2=0;i2<ArraySize(tf_keys);++i2){ if(tf_keys[i2]==key){ tf_vals[i2]=tfv; updated=true; break; } }
                                if(!updated){ int k2=ArraySize(tf_keys); ArrayResize(tf_keys,k2+1); ArrayResize(tf_vals,k2+1); tf_keys[k2]=key; tf_vals[k2]=tfv; }
                               }
                              else if(f_norm=="r_multiple")
                                {
                                 int n = ArraySize(r_list);
                                 ArrayResize(ts_list, n+1);
                                 ArrayResize(sym_list, n+1);
                                 ArrayResize(strat_list, n+1);
                                 ArrayResize(r_list, n+1);
                                 ArrayResize(tf_list, n+1);
                                 ts_list[n]    = StringToTime(ts_s);
                                 sym_list[n]   = StripQuotes(parts[1]);
                                 strat_list[n] = StripQuotes(parts[2]);
                                 r_list[n]     = StringToDouble(StripQuotes(parts[4]));
                                 // lookup timeframe if available
                                 int tfv=-1; string key2 = sym_list[n]+"|"+strat_list[n];
                                 for(int j2=0;j2<ArraySize(tf_keys);++j2){ if(tf_keys[j2]==key2){ tfv=tf_vals[j2]; break; } }
                                 tf_list[n]    = tfv;
                                 added++;
                                }
                            }
                          FileClose(ht);
                          if(added>0)
                            {
                             total = ArraySize(r_list);
                             PrintFormat("InsightsBuilder: text-fallback collected %d r_multiple rows from features.csv", added);
                            }
                         }
                       
                       Print("InsightsBuilder: no r_multiple rows found in features.csv; falling back to knowledge_base.csv using profit as surrogate");
                       // Open knowledge_base.csv with explicit comma delimiter
                       int hk = FileOpen(m_kb_path, FILE_READ|FILE_CSV|FILE_SHARE_READ|FILE_COMMON, (ushort)',' );
                       if(hk!=INVALID_HANDLE)
                         {
                          // No header expected in knowledge_base.csv
                          // Columns: ts,symbol,type,entry,sl,tp,close,profit,strategy
                          string sym_list2[]; string strat_list2[]; double r_list2[]; // use profit as R substitute
                          while(!FileIsEnding(hk))
                            {
                             string ts = FileReadString(hk); if(ts=="" && FileIsEnding(hk)) break;
                             string sym = FileReadString(hk);
                             string type= FileReadString(hk);
                             string entry=FileReadString(hk);
                             string sl  = FileReadString(hk);
                             string tp  = FileReadString(hk);
                             string close=FileReadString(hk);
                             string profit=FileReadString(hk);
                             string strat = FileReadString(hk);

                             // Trim fields
                             ts=Trim(ts); sym=Trim(sym); type=Trim(type); entry=Trim(entry); sl=Trim(sl); tp=Trim(tp); close=Trim(close); profit=Trim(profit); strat=Trim(strat);
                             if(profit=="") continue;
                             // consider only rows that look like closures (close price present OR profit non-zero)
                             double pr = StringToDouble(profit);
                             double cp = StringToDouble(close);
                             if(cp>0.0 || pr!=0.0)
                               {
                                int n = ArraySize(r_list2);
                                ArrayResize(r_list2, n+1);
                                ArrayResize(sym_list2, n+1);
                                ArrayResize(strat_list2, n+1);
                                r_list2[n] = pr;
                                sym_list2[n] = sym;
                                strat_list2[n] = strat;
                               }
                            }
                          FileClose(hk);
                          // replace primary arrays for aggregation below
                          ArraySwap(r_list, r_list2);
                          ArraySwap(strat_list, strat_list2);
                          ArraySwap(sym_list, sym_list2);
                          total = ArraySize(r_list);
                          PrintFormat("InsightsBuilder: fallback collected %d rows from knowledge_base.csv", total);
                          // Initialize tf_list for KB-fallback rows using timeframe map from features
                          ArrayResize(tf_list, total);
                          for(int i3=0;i3<total;++i3)
                            {
                             tf_list[i3] = -1;
                             string key3 = sym_list[i3] + "|" + strat_list[i3];
                             for(int j3=0;j3<ArraySize(tf_keys);++j3)
                               {
                                if(tf_keys[j3]==key3){ tf_list[i3]=tf_vals[j3]; break; }
                               }
                             }
                          // If still no rows after KB fallback, synthesize dummy rows from timeframe features
                          if(total==0)
                            {
                             int combos = ArraySize(tf_keys);
                             for(int c=0;c<combos;++c)
                               {
                                int sep = StringFind(tf_keys[c], "|", 0);
                                if(sep<0) continue;
                                int n2 = ArraySize(r_list);
                                ArrayResize(r_list, n2+1);
                                ArrayResize(strat_list, n2+1);
                                ArrayResize(sym_list, n2+1);
                                ArrayResize(tf_list, n2+1);
                                sym_list[n2]   = StringSubstr(tf_keys[c], 0, sep);
                                strat_list[n2] = StringSubstr(tf_keys[c], sep+1);
                                r_list[n2]     = 0.0; // scaffold count only
                                tf_list[n2]    = tf_vals[c];
                               }
                             total = ArraySize(r_list);
                             if(total>0)
                                PrintFormat("InsightsBuilder: synthesized %d dummy rows from timeframe features (no r_multiple/profit found)", total);
                            }
                          }
                         }
                    // Final synthesis: if still no rows and no timeframe entries, synthesize from symbol/strategy pairs using default chart timeframe
                     if(total==0 && ArraySize(all_keys)>0)
                      {
                       int tf_def = (int)Period();
                       for(int c=0; c<ArraySize(all_keys); ++c)
                         {
                          int sep = StringFind(all_keys[c], "|", 0);
                          if(sep<0) continue;
                          int n2 = ArraySize(r_list);
                          ArrayResize(r_list, n2+1);
                          ArrayResize(strat_list, n2+1);
                          ArrayResize(sym_list, n2+1);
                          ArrayResize(tf_list, n2+1);
                          sym_list[n2]   = StringSubstr(all_keys[c], 0, sep);
                          strat_list[n2] = StringSubstr(all_keys[c], sep+1);
                          r_list[n2]     = 0.0; // scaffold count only
                          tf_list[n2]    = tf_def;
                         }
                       total = ArraySize(r_list);
                       if(total>0)
                          PrintFormat("InsightsBuilder: synthesized %d dummy rows from symbol/strategy pairs (default timeframe=%d)", total, tf_def);
                      }
                    // Ensure general coverage on current chart symbol across multiple timeframes for all default strategies
                    {
                     string def_strats[]; GetDefaultStrategyNames(def_strats);
                     string csym = Symbol();
                     int ctf = (int)Period();
                     // Small TF set including current
                     int tf_opts[]; ArrayResize(tf_opts, 5);
                     tf_opts[0]=ctf; tf_opts[1]=PERIOD_M5; tf_opts[2]=PERIOD_M10; tf_opts[3]=PERIOD_M15; tf_opts[4]=PERIOD_M30;
                     int added_before = ArraySize(r_list);
                     for(int t=0; t<ArraySize(tf_opts); ++t)
                       {
                        int tfc = tf_opts[t];
                        for(int ds=0; ds<ArraySize(def_strats); ++ds)
                          {
                           bool exists=false;
                           for(int i=0;i<total;++i)
                             {
                              if(sym_list[i]==csym && strat_list[i]==def_strats[ds] && tf_list[i]==tfc)
                                { exists=true; break; }
                             }
                           if(!exists)
                             {
                              int n3 = ArraySize(r_list);
                              ArrayResize(r_list, n3+1);
                              ArrayResize(strat_list, n3+1);
                              ArrayResize(sym_list, n3+1);
                              ArrayResize(tf_list, n3+1);
                              sym_list[n3]   = csym;
                              strat_list[n3] = def_strats[ds];
                              r_list[n3]     = 0.0;
                              tf_list[n3]    = tfc;
                             }
                          }
                       }
                     int added_after = ArraySize(r_list);
                     if(added_after>added_before)
                        PrintFormat("InsightsBuilder: ensured multi-TF chart coverage by adding %d rows for symbol=%s across %d TFs and %d strategies", added_after-added_before, csym, ArraySize(tf_opts), ArraySize(def_strats));
                    }
                    // Unique strategies and symbols
                    string uniq_strats[]; string uniq_syms[];
                    for(int i=0;i<total;++i){ PushUnique(uniq_strats, strat_list[i]); PushUnique(uniq_syms, sym_list[i]); }

                    // Overall aggregates
                    double wins=0.0, sumR=0.0, gp=0.0, gl=0.0;
                    double r_all[];
                    ArrayResize(r_all, total);
                    for(int i=0;i<total;++i)
                      {
                       double r = r_list[i];
                       r_all[i]=r;
                       sumR += r;
                       if(r>0){ wins+=1.0; gp+=r; }
                       else if(r<0){ gl += -r; }
                      }
                    double win_rate       = SafeDiv(wins, (double)total);
                    double avg_R          = SafeDiv(sumR, (double)total);
                    double pf             = (gl>0.0)? gp/gl : (gp>0.0? 9999.0 : 0.0);
                    double median_R       = Median(r_all);
                    double maxdd_R        = MaxDrawdownR(r_all);

                    // Prepare output
                    FolderCreate("DualEA", FILE_COMMON);
                    int out = FileOpen(m_out_path, FILE_WRITE|FILE_COMMON|FILE_TXT|FILE_ANSI);
                    if(out==INVALID_HANDLE)
                      {
                       PrintFormat("InsightsBuilder: cannot open output '%s'. Err=%d", m_out_path, GetLastError());
                       return false;
                      }
                    string now = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
                    FileWriteString(out, "{\n");
                    FileWriteString(out, "  \"schema_version\": \"1.0\",\n");
                    FileWriteString(out, "  \"generated_at\": \"" + now + "\",\n");
                    FileWriteString(out, "  \"totals\": {\n");
                    FileWriteString(out, "    \"trade_count\": " + IntegerToString(total) + ",\n");
                    FileWriteString(out, "    \"win_rate\": " + DoubleToString(win_rate, 6) + ",\n");
                    FileWriteString(out, "    \"avg_R\": " + DoubleToString(avg_R, 6) + ",\n");
                    FileWriteString(out, "    \"median_R\": " + DoubleToString(median_R, 6) + ",\n");
                    FileWriteString(out, "    \"profit_factor\": " + DoubleToString(pf, 6) + ",\n");
                    FileWriteString(out, "    \"expectancy\": " + DoubleToString(avg_R, 6) + ",\n");
                    FileWriteString(out, "    \"max_drawdown_R\": " + DoubleToString(maxdd_R, 6) + "\n");
                    
                    FileWriteString(out, "  },\n");

                    // by_strategy breakdown
                    FileWriteString(out, "  \"by_strategy\": [\n");
                    for(int s=0; s<ArraySize(uniq_strats); ++s)
                      {
                       string sname = uniq_strats[s];
                       // collect r for this strategy in file order
                       double rs[]; int cnt=0; double s_sum=0.0, s_wins=0.0, s_gp=0.0, s_gl=0.0;
                       for(int i=0;i<total;++i)
                         if(strat_list[i]==sname)
                           {
                            int k = ArraySize(rs); ArrayResize(rs, k+1); rs[k]=r_list[i];
                            double rr = r_list[i]; s_sum+=rr; if(rr>0){s_wins+=1.0; s_gp+=rr;} else if(rr<0){s_gl+=-rr;}
                            cnt++;
                           }
                       double s_wr = SafeDiv(s_wins, (double)cnt);
                       double s_avg= SafeDiv(s_sum, (double)cnt);
                       double s_pf = (s_gl>0.0)? s_gp/s_gl : (s_gp>0.0? 9999.0 : 0.0);
                       double s_med= Median(rs);
                       double s_dd = MaxDrawdownR(rs);
                       string comma = (s<ArraySize(uniq_strats)-1)?",":"";
                       FileWriteString(out, StringFormat("    {\"strategy\": \"%s\", \"trade_count\": %d, \"win_rate\": %.6f, \"avg_R\": %.6f, \"median_R\": %.6f, \"profit_factor\": %.6f, \"expectancy\": %.6f, \"max_drawdown_R\": %.6f}%s\n",
                                                      sname, cnt, s_wr, s_avg, s_med, s_pf, s_avg, s_dd, comma));
                      }
                    FileWriteString(out, "  ],\n");

                    // by_timeframe breakdown (if available)
                    // collect unique timeframes present in tf_list (>=0)
                    int uniq_tf[]; for(int i=0;i<total;++i){ if(tf_list[i]>=0){ bool seen=false; for(int j=0;j<ArraySize(uniq_tf);++j){ if(uniq_tf[j]==tf_list[i]){seen=true;break;} } if(!seen){ int k=ArraySize(uniq_tf); ArrayResize(uniq_tf,k+1); uniq_tf[k]=tf_list[i]; } } }
                    FileWriteString(out, "  \"by_timeframe\": [\n");
                    for(int t=0;t<ArraySize(uniq_tf);++t)
                      {
                       int tfv = uniq_tf[t];
                       double rs[]; int cnt=0; double s_sum=0.0, s_wins=0.0, s_gp=0.0, s_gl=0.0;
                       for(int i=0;i<total;++i)
                         if(tf_list[i]==tfv)
                           { int k=ArraySize(rs); ArrayResize(rs,k+1); rs[k]=r_list[i]; double rr=r_list[i]; s_sum+=rr; if(rr>0){s_wins+=1.0; s_gp+=rr;} else if(rr<0){s_gl+=-rr;} cnt++; }
                       double wr = (cnt>0? s_wins/cnt : 0.0);
                       double avg = (cnt>0? s_sum/cnt : 0.0);
                       double pf = (s_gl>0.0? s_gp/s_gl : (s_gp>0.0? 9999.0 : 0.0));
                       double med= Median(rs);
                       double dd = MaxDrawdownR(rs);
                       string comma = (t<ArraySize(uniq_tf)-1)?",":"";
                       FileWriteString(out, StringFormat("    {\"timeframe\": %d, \"trade_count\": %d, \"win_rate\": %.6f, \"avg_R\": %.6f, \"median_R\": %.6f, \"profit_factor\": %.6f, \"expectancy\": %.6f, \"max_drawdown_R\": %.6f}%s\n", tfv, cnt, wr, avg, med, pf, avg, dd, comma));
                      }
                    FileWriteString(out, "  ],\n");

                    // by_symbol_strategy_timeframe breakdown
                    FileWriteString(out, "  \"by_symbol_strategy_timeframe\": [\n");
                    for(int s=0; s<ArraySize(uniq_strats); ++s)
                      {
                       string sname = uniq_strats[s];
                       for(int y=0; y<ArraySize(uniq_syms); ++y)
                         {
                          string yname = uniq_syms[y];
                          // collect unique tf for this (s,y)
                          int tf_set_sy[];
                          for(int i=0;i<total;++i) if(strat_list[i]==sname && sym_list[i]==yname && tf_list[i]>=0)
                            { bool seen=false; for(int j=0;j<ArraySize(tf_set_sy);++j){ if(tf_set_sy[j]==tf_list[i]){seen=true;break;} } if(!seen){ int k=ArraySize(tf_set_sy); ArrayResize(tf_set_sy,k+1); tf_set_sy[k]=tf_list[i]; } }
                          for(int t=0;t<ArraySize(tf_set_sy);++t)
                            {
                             int tfv = tf_set_sy[t];
                             double rs[]; int cnt=0; double s_sum=0.0, s_wins=0.0, s_gp=0.0, s_gl=0.0;
                             for(int i=0;i<total;++i)
                               if(strat_list[i]==sname && sym_list[i]==yname && tf_list[i]==tfv)
                                 { int k=ArraySize(rs); ArrayResize(rs,k+1); rs[k]=r_list[i]; double rr=r_list[i]; s_sum+=rr; if(rr>0){s_wins+=1.0; s_gp+=rr;} else if(rr<0){s_gl+=-rr;} cnt++; }
                             double wr = (cnt>0? s_wins/cnt : 0.0);
                             double avg = (cnt>0? s_sum/cnt : 0.0);
                             double pf = (s_gl>0.0? s_gp/s_gl : (s_gp>0.0? 9999.0 : 0.0));
                             double med= Median(rs);
                             double dd = MaxDrawdownR(rs);
                             // determine trailing comma: last item overall
                             bool lastBlock = (s==ArraySize(uniq_strats)-1) && (y==ArraySize(uniq_syms)-1) && (t==ArraySize(tf_set_sy)-1);
                             string comma = (lastBlock?"":",");
                             FileWriteString(out, StringFormat("    {\"strategy\": \"%s\", \"symbol\": \"%s\", \"timeframe\": %d, \"trade_count\": %d, \"win_rate\": %.6f, \"avg_R\": %.6f, \"median_R\": %.6f, \"profit_factor\": %.6f, \"expectancy\": %.6f, \"max_drawdown_R\": %.6f}%s\n",
                                                        sname, yname, tfv, cnt, wr, avg, med, pf, avg, dd, comma));
                            }
                         }
                      }
                    FileWriteString(out, "  ],\n");

                    // by_symbol breakdown
                    FileWriteString(out, "  \"by_symbol\": [\n");
                    for(int y=0; y<ArraySize(uniq_syms); ++y)
                      {
                       string yname = uniq_syms[y];
                       double rs2[]; int cnt2=0; double s_sum2=0.0, s_wins2=0.0, s_gp2=0.0, s_gl2=0.0;
                       for(int i=0;i<total;++i)
                         if(sym_list[i]==yname)
                           {
                            int k = ArraySize(rs2); ArrayResize(rs2, k+1); rs2[k]=r_list[i];
                            double rr = r_list[i]; s_sum2+=rr; if(rr>0){s_wins2+=1.0; s_gp2+=rr;} else if(rr<0){s_gl2+=-rr;}
                            cnt2++;
                           }
                       double y_wr = SafeDiv(s_wins2, (double)cnt2);
                       double y_avg= SafeDiv(s_sum2, (double)cnt2);
                       double y_pf = (s_gl2>0.0)? s_gp2/s_gl2 : (s_gp2>0.0? 9999.0 : 0.0);
                       double y_med= Median(rs2);
                       double y_dd = MaxDrawdownR(rs2);
                       string comma2 = (y<ArraySize(uniq_syms)-1)?",":"";
                       FileWriteString(out, StringFormat("    {\"symbol\": \"%s\", \"trade_count\": %d, \"win_rate\": %.6f, \"avg_R\": %.6f, \"median_R\": %.6f, \"profit_factor\": %.6f, \"expectancy\": %.6f, \"max_drawdown_R\": %.6f}%s\n",
                                                      yname, cnt2, y_wr, y_avg, y_med, y_pf, y_avg, y_dd, comma2));
                      }
                    FileWriteString(out, "  ]\n");

                    FileWriteString(out, "}\n");
                    FileClose(out);
                    string full = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\" + m_out_path;
                    PrintFormat("InsightsBuilder: wrote %s", full);
                    return true;
                    }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CKnowledgeBase::CKnowledgeBase(string file_name="DualEA\\knowledge_base.csv", string delimiter=",")
  {
   m_csv_delimiter = delimiter;
   m_file_path = file_name; // Use subfolder under Common Files: DualEA\

   // Ensure target subfolder exists in Common files
   // Common files base: TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files"
   // Create "DualEA" if missing
   FolderCreate("DualEA", FILE_COMMON);

   // Debug: show resolved common file path
   string full_main_path = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\" + m_file_path;
   PrintFormat("KnowledgeBase: writing main CSV to Common Files: %s", full_main_path);

   // --- Ensure the header exists (use direct FileOpen to avoid noisy error on first run)
   int h = FileOpen(m_file_path, FILE_READ|FILE_CSV|FILE_COMMON);
   if(h == INVALID_HANDLE)
     {
      // Create new file with header
      h = FileOpen(m_file_path, FILE_WRITE|FILE_CSV|FILE_COMMON);
      if(h != INVALID_HANDLE)
        {
         FileWriteString(h, "timestamp,symbol,type,entry_price,stop_loss,take_profit,close_price,profit,strategy_id\n");
         FileClose(h);
        }
     }
   else
     {
      // File exists; if empty, write header
      if(FileSize(h) == 0)
        {
         FileClose(h);
         h = FileOpen(m_file_path, FILE_WRITE|FILE_CSV|FILE_COMMON);
         if(h != INVALID_HANDLE)
           {
            FileWriteString(h, "timestamp,symbol,type,entry_price,stop_loss,take_profit,close_price,profit,strategy_id\n");
           }
        }
      if(h != INVALID_HANDLE)
         FileClose(h);
     }
  }
//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CKnowledgeBase::~CKnowledgeBase()
  {
  }

//+------------------------------------------------------------------+
//| Writes a trade record to the CSV file                            |
//+------------------------------------------------------------------+
bool CKnowledgeBase::WriteRecord(const TradeRecord &record)
  {
   if(!OpenFile(FILE_WRITE|FILE_CSV|FILE_SHARE_WRITE))
      return(false);

   FileSeek(m_file_handle, 0, SEEK_END);

   string record_string = TimeToString(record.timestamp) + m_csv_delimiter +
                          record.symbol + m_csv_delimiter +
                          IntegerToString(record.type) + m_csv_delimiter +
                          DoubleToString(record.entry_price, _Digits) + m_csv_delimiter +
                          DoubleToString(record.stop_loss, _Digits) + m_csv_delimiter +
                          DoubleToString(record.take_profit, _Digits) + m_csv_delimiter +
                          DoubleToString(record.close_price, _Digits) + m_csv_delimiter +
                          DoubleToString(record.profit, 2) + m_csv_delimiter +
                          record.strategy_id;

   FileWriteString(m_file_handle, record_string + "\n");

   CloseFile();
   return(true);
  }

//+------------------------------------------------------------------+
//| Logs a trade event with basic MT5 result info                     |
//+------------------------------------------------------------------+
bool CKnowledgeBase::LogTrade(const string strategy_name, const int retcode, const ulong deal, const ulong order_id)
  {
   // Derive an events file from the main path, e.g., knowledge_base_events.csv
   string events_path = m_file_path;
   int dot = StringFind(events_path, ".", 0);
   if(dot > 0)
      events_path = StringSubstr(events_path, 0, dot) + "_events.csv";
   else
      events_path = events_path + "_events.csv";

   // Ensure folder exists in Common files
   FolderCreate("DualEA", FILE_COMMON);

   // Debug: show resolved events file path
   string full_events_path = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\" + events_path;
   PrintFormat("KnowledgeBase: writing events CSV to Common Files: %s", full_events_path);

   int handle = FileOpen(events_path, FILE_READ|FILE_WRITE|FILE_CSV|FILE_SHARE_WRITE|FILE_COMMON);
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("Error opening knowledge base events file '%s'. Error code: %d", events_path, GetLastError());
      return(false);
     }

   // Write header if file is empty
   if(FileSize(handle) == 0)
     {
      FileWriteString(handle, "timestamp,strategy,retcode,deal,order\n");
     }

   FileSeek(handle, 0, SEEK_END);
   string line = TimeToString(TimeCurrent()) + m_csv_delimiter +
                 strategy_name + m_csv_delimiter +
                 IntegerToString(retcode) + m_csv_delimiter +
                 IntegerToString((int)deal) + m_csv_delimiter +
                 IntegerToString((int)order_id);
   FileWriteString(handle, line + "\n");
   FileClose(handle);
   return(true);
  }

//+------------------------------------------------------------------+
//| Opens the file                                                   |
//+------------------------------------------------------------------+
bool CKnowledgeBase::OpenFile(int flags=FILE_WRITE|FILE_READ|FILE_CSV)
  {
   // Always target the Common files area so results are shared across Tester, Paper, and Live
   // The path m_file_path should include the subfolder, e.g. "DualEA\\knowledge_base.csv"
   m_file_handle = FileOpen(m_file_path, flags | FILE_COMMON);
   if(m_file_handle == INVALID_HANDLE)
     {
      PrintFormat("Error opening knowledge base file '%s'. Error code: %d", m_file_path, GetLastError());
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| Closes the file                                                  |
//+------------------------------------------------------------------+
void CKnowledgeBase::CloseFile()
  {
   if(m_file_handle != INVALID_HANDLE)
      FileClose(m_file_handle);
  }
