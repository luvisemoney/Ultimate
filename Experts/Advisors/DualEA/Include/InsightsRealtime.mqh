//+------------------------------------------------------------------+
//| InsightsRealtime.mqh                                            |
//| Realtime slice aggregator and snapshot writer for DualEA        |
//| Produces NDJSON at DualEA\insights.snap.json with the same      |
//| fields consumed by InsightsLoader (strategy/symbol/timeframe).   |
//+------------------------------------------------------------------+
#property copyright "2025"
#property version   "1.00"

#include <Files/File.mqh>

class CInsightsRealtime
  {
  private:
    // Slice keys and stats
    string m_strat[];
    string m_sym[];
    int    m_tf[];
    int    m_cnt[];
    int    m_wins[];
    double m_sumR[];
    double m_gp[];   // gross profit (sum of positive R)
    double m_gl[];   // gross loss (sum of |negative R|)
    double m_cumR[]; // cumulative R path
    double m_peakR[];// peak cumulative R
    double m_dd[];   // max drawdown in R

    int Find(const string strat, const string sym, const int tf)
      {
        for(int i=0;i<ArraySize(m_strat);++i)
          if(m_strat[i]==strat && m_sym[i]==sym && m_tf[i]==tf)
            return i;
        return -1;
      }

    void EnsureDir()
      {
        FolderCreate("DualEA", FILE_COMMON);
      }

  public:
    CInsightsRealtime(){}
    ~CInsightsRealtime(){}

    void Update(const string strat, const string sym, const int tf, const double r)
      {
        int i = Find(strat, sym, tf);
        if(i<0)
          {
            i = ArraySize(m_strat);
            ArrayResize(m_strat, i+1); ArrayResize(m_sym, i+1); ArrayResize(m_tf, i+1);
            ArrayResize(m_cnt, i+1); ArrayResize(m_wins, i+1); ArrayResize(m_sumR, i+1);
            ArrayResize(m_gp, i+1);  ArrayResize(m_gl, i+1);
            ArrayResize(m_cumR, i+1); ArrayResize(m_peakR, i+1); ArrayResize(m_dd, i+1);
            m_strat[i]=strat; m_sym[i]=sym; m_tf[i]=tf;
            m_cnt[i]=0; m_wins[i]=0; m_sumR[i]=0.0; m_gp[i]=0.0; m_gl[i]=0.0; m_cumR[i]=0.0; m_peakR[i]=0.0; m_dd[i]=0.0;
          }
        // update stats
        m_cnt[i] += 1;
        if(r>0.0) { m_wins[i]+=1; m_gp[i]+=r; } else if(r<0.0) { m_gl[i]+= -r; }
        m_sumR[i] += r;
        // update drawdown path
        m_cumR[i] += r;
        if(m_cumR[i] > m_peakR[i]) m_peakR[i] = m_cumR[i];
        double dd_now = m_peakR[i] - m_cumR[i];
        if(dd_now > m_dd[i]) m_dd[i] = dd_now;
      }

    bool SaveSnapshot()
      {
        EnsureDir();
        string tmp = "DualEA\\insights.snap.tmp";
        string out = "DualEA\\insights.snap.json";
        int h = FileOpen(tmp, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
        if(h==INVALID_HANDLE)
          {
            PrintFormat("[RT] snapshot open failed err=%d", GetLastError());
            return false;
          }
        // one JSON object per line
        for(int i=0;i<ArraySize(m_strat);++i)
          {
            double wr = (m_cnt[i]>0? (double)m_wins[i]/(double)m_cnt[i] : 0.0);
            double avgR = (m_cnt[i]>0? m_sumR[i]/(double)m_cnt[i] : 0.0);
            double pf = (m_gl[i]>0.0? m_gp[i]/m_gl[i] : (m_gp[i]>0.0? 9999.0 : 0.0));
            string line = StringFormat("{\"strategy\":\"%s\",\"symbol\":\"%s\",\"timeframe\":%d,\"trade_count\":%d,\"win_rate\":%.8f,\"avg_R\":%.8f,\"profit_factor\":%.8f,\"max_drawdown_R\":%.8f}\n",
                                       m_strat[i], m_sym[i], m_tf[i], m_cnt[i], wr, avgR, pf, m_dd[i]);
            FileWriteString(h, line);
          }
        FileClose(h);
        // atomic move
        if(FileIsExist(out, FILE_COMMON)) FileDelete(out, FILE_COMMON);
        bool moved = FileMove(tmp, FILE_COMMON, out, FILE_COMMON);
        if(!moved)
          {
            PrintFormat("[RT] snapshot move failed err=%d", GetLastError());
            return false;
          }
        return true;
      }

    void SignalReady()
      {
        EnsureDir();
        string rdy = "DualEA\\insights.ready";
        if(FileIsExist(rdy, FILE_COMMON)) FileDelete(rdy, FILE_COMMON);
        int hr = FileOpen(rdy, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
        if(hr!=INVALID_HANDLE)
          {
            FileWrite(hr, IntegerToString((int)TimeCurrent()));
            FileClose(hr);
          }
      }
  };
