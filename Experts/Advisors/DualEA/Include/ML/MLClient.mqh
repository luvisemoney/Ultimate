#ifndef __DUALEA_MLCLIENT_MQH__
#define __DUALEA_MLCLIENT_MQH__

class CMLClient : public CObject
{
private:
  string   m_symbol;
  int      m_period;
  string   m_filepath;
  int      m_reload_secs;
  datetime m_last_load;
  // Data columns
  datetime m_ts[];
  double   m_score[];     // [-1..+1]
  double   m_prob_long[]; // [0..1]
  double   m_prob_short[];// [0..1]

  bool Load()
  {
    ArrayResize(m_ts, 0);
    ArrayResize(m_score, 0);
    ArrayResize(m_prob_long, 0);
    ArrayResize(m_prob_short, 0);

    int handle = FileOpen(m_filepath, FILE_READ|FILE_CSV|FILE_ANSI, ',');
    if(handle == INVALID_HANDLE)
    {
      PrintFormat("[ML] Failed to open signals file: %s", m_filepath);
      return false;
    }
    // Optional header skip if first token is non-numeric
    bool header_checked=false;
    while(!FileIsEnding(handle))
    {
      string s0 = FileReadString(handle);
      if(StringLen(s0)==0) { FileReadString(handle); FileReadString(handle); FileReadString(handle); continue; }
      // If header row, skip
      if(!header_checked)
      {
        header_checked = true;
        if(StringToTime(s0)==0 && StringFind(StringToUpper(s0), "TIME")>=0)
        {
          // consume rest of header line
          FileReadString(handle); FileReadString(handle); FileReadString(handle);
          continue;
        }
      }
      datetime ts = (StringToTime(s0)!=0? StringToTime(s0) : (datetime)StrToInteger(s0));
      string s1 = FileReadString(handle);
      string s2 = FileReadString(handle);
      string s3 = FileReadString(handle);
      double score = StrToDouble(s1);
      double pl = StrToDouble(s2);
      double ps = StrToDouble(s3);
      int k = ArraySize(m_ts);
      ArrayResize(m_ts, k+1);
      ArrayResize(m_score, k+1);
      ArrayResize(m_prob_long, k+1);
      ArrayResize(m_prob_short, k+1);
      m_ts[k]=ts; m_score[k]=score; m_prob_long[k]=pl; m_prob_short[k]=ps;
    }
    FileClose(handle);
    m_last_load = TimeCurrent();
    return (ArraySize(m_ts)>0);
  }

public:
  CMLClient(): m_symbol(""), m_period(0), m_filepath(""), m_reload_secs(60), m_last_load(0) {}

  void Configure(const string symbol, const int period, const string filepath, const int reload_secs)
  {
    m_symbol = symbol; m_period = period; m_filepath = filepath; m_reload_secs = (reload_secs>0? reload_secs:60);
  }

  bool LoadIfStale()
  {
    if(m_filepath=="" ) return false;
    if(m_last_load==0 || (TimeCurrent()-m_last_load)>=m_reload_secs)
      return Load();
    return true;
  }

  bool GetNearest(const datetime t, double &score_out, double &pl_out, double &ps_out)
  {
    if(ArraySize(m_ts)==0) return false;
    // Binary search nearest by time
    int lo=0, hi=ArraySize(m_ts)-1, mid;
    while(lo<=hi)
    {
      mid = (lo+hi)/2;
      if(m_ts[mid]==t) { score_out=m_score[mid]; pl_out=m_prob_long[mid]; ps_out=m_prob_short[mid]; return true; }
      if(m_ts[mid]<t) lo=mid+1; else hi=mid-1;
    }
    int idx = MathMax(0, MathMin(hi, ArraySize(m_ts)-1));
    score_out=m_score[idx]; pl_out=m_prob_long[idx]; ps_out=m_prob_short[idx];
    return true;
  }

  bool GetLatest(double &score_out, double &pl_out, double &ps_out)
  {
    if(ArraySize(m_ts)==0) return false;
    int k = ArraySize(m_ts)-1;
    score_out = m_score[k]; pl_out = m_prob_long[k]; ps_out = m_prob_short[k];
    return true;
  }
};

#endif // __DUALEA_MLCLIENT_MQH__
