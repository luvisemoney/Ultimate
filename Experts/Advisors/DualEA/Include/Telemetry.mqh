// Telemetry.mqh
// Buffered JSONL telemetry writer for PaperEA
#ifndef __DUALEA_TELEMETRY_MQH__
#define __DUALEA_TELEMETRY_MQH__
#property copyright "2025, Windsurf"
#property link      "https://windsurf.ai"

#include <Files/File.mqh>

class CTelemetry
  {
  private:
    string   m_base_dir;       // e.g. "DualEA\\telemetry"
    string   m_experiment;     // optional tag
    int      m_level;          // 0..2
    int      m_max_buf;        // flush threshold
    string   m_buffer[];       // pending JSONL lines (without trailing \n)

    string   JsonEscape(const string s)
      {
        string out = s;
        StringReplace(out, "\\", "\\\\");
        StringReplace(out, "\"", "\\\"");
        StringReplace(out, "\r", "\\r");
        StringReplace(out, "\n", "\\n");
        return out;
      }

    string   Quote(const string s) { return "\"" + JsonEscape(s) + "\""; }

    string   TodaySuffix()
      {
        datetime now = TimeCurrent();
        string d = TimeToString(now, TIME_DATE);
        // d format: YYYY.MM.DD -> YYYYMMDD
        StringReplace(d, ".", "");
        return d; // YYYYMMDD
      }

    string   ResolveFilePath()
      {
        string prefix = (m_experiment==""? "paper" : ("paper_" + m_experiment));
        string file = m_base_dir + "\\" + prefix + "_" + TodaySuffix() + ".jsonl";
        return file;
      }

    void     EnsureFolders()
      {
        // Ensure common folder structure exists
        FolderCreate("DualEA", FILE_COMMON);
        FolderCreate(m_base_dir, FILE_COMMON);
      }

    void     AppendLine(const string line)
      {
        int n = ArraySize(m_buffer);
        ArrayResize(m_buffer, n+1);
        m_buffer[n] = line;
        if(n+1 >= m_max_buf)
          Flush();
      }

    string   NowTs() { return TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS); }

  public:
    CTelemetry(string base_dir="DualEA\\telemetry", string experiment="", int level=1, int max_buf=256)
      {
        m_base_dir = base_dir;
        m_experiment = experiment;
        m_level = level;
        m_max_buf = (max_buf>0? max_buf : 64);
        ArrayResize(m_buffer, 0);
        EnsureFolders();
        string full = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\" + ResolveFilePath();
        PrintFormat("Telemetry: writing JSONL to %s (level=%d, max_buf=%d)", full, m_level, m_max_buf);
      }

    ~CTelemetry(){ Flush(); }

    void Flush()
      {
        if(ArraySize(m_buffer)==0) return;
        EnsureFolders();
        string path = ResolveFilePath();
        int h = FileOpen(path, FILE_READ|FILE_WRITE|FILE_TXT|FILE_SHARE_WRITE|FILE_ANSI|FILE_COMMON);
        if(h==INVALID_HANDLE)
          {
            PrintFormat("Telemetry: cannot open %s, err=%d", path, GetLastError());
            return;
          }
        FileSeek(h, 0, SEEK_END);
        for(int i=0;i<ArraySize(m_buffer);++i)
          FileWriteString(h, m_buffer[i] + "\n");
        FileClose(h);
        ArrayResize(m_buffer, 0);
      }

    // Generic event logger
    void LogEvent(const string symbol, const int timeframe, const string strategy, const string event, const string details)
      {
        if(m_level<=0) return;
        string line = StringFormat("{\"ts\":%s,\"symbol\":%s,\"timeframe\":%d,\"strategy\":%s,\"event\":%s,\"details\":%s}",
                                   Quote(NowTs()), Quote(symbol), timeframe, Quote(strategy), Quote(event), Quote(details));
        AppendLine(line);
      }

    // Gating decision (selector/insights/shadow)
    void LogGating(const string symbol, const int timeframe, const string strategy, const string stage, const bool allowed, const string reason)
      {
        if(m_level<=0) return;
        string line = StringFormat("{\"ts\":%s,\"symbol\":%s,\"timeframe\":%d,\"strategy\":%s,\"event\":%s,\"stage\":%s,\"allowed\":%s,\"reason\":%s}",
                                   Quote(NowTs()), Quote(symbol), timeframe, Quote(strategy), Quote("gating"), Quote(stage), (allowed?"true":"false"), Quote(reason));
        AppendLine(line);
      }

    // Shadow gating (evaluated even when NoConstraintsMode is active)
    void LogGatingShadow(const string strategy, const string symbol, const int timeframe, const string stage, const bool allowed, const string reason, const bool no_constraints_active)
      {
        if(m_level<=0) return;
        string line = StringFormat("{\"ts\":%s,\"symbol\":%s,\"timeframe\":%d,\"strategy\":%s,\"event\":%s,\"stage\":%s,\"mode\":%s,\"allowed\":%s,\"reason\":%s}",
                                   Quote(NowTs()), Quote(symbol), timeframe, Quote(strategy), Quote("shadow_gating"), Quote(stage), Quote(no_constraints_active?"no_constraints":"normal"), (allowed?"true":"false"), Quote(reason));
        AppendLine(line);
      }

    // Trade execution event
    void LogTradeExecuted(const string strategy, const string symbol, const int timeframe, const int retcode, const ulong deal, const ulong order_id)
      {
        if(m_level<=0) return;
        string line = StringFormat("{\"ts\":%s,\"symbol\":%s,\"timeframe\":%d,\"strategy\":%s,\"event\":%s,\"retcode\":%d,\"deal\":%I64u,\"order\":%I64u}",
                                   Quote(NowTs()), Quote(symbol), timeframe, Quote(strategy), Quote("trade_executed"), retcode, deal, order_id);
        AppendLine(line);
      }

    void LogTradeFailed(const string strategy, const string symbol, const int timeframe, const int error_code)
      {
        if(m_level<=0) return;
        string line = StringFormat("{\"ts\":%s,\"symbol\":%s,\"timeframe\":%d,\"strategy\":%s,\"event\":%s,\"error\":%d}",
                                   Quote(NowTs()), Quote(symbol), timeframe, Quote(strategy), Quote("trade_failed"), error_code);
        AppendLine(line);
      }
  };
 
#endif // __DUALEA_TELEMETRY_MQH__
