//+------------------------------------------------------------------+
//| SessionManager.mqh                                               |
//| FR-02: Enhanced Session Filter with Gate Integration            |
//+------------------------------------------------------------------+
#property copyright "DualEA"
#property version   "1.00"

// Compile-time constant for daily window slots
#define SESSION_MAX_WIN 4

//+------------------------------------------------------------------+
//| Session management and filtering                                 |
//+------------------------------------------------------------------+
class CSessionManager
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   
   // Session configuration
   bool m_enabled;
   int m_session_start_hour;
   int m_session_end_hour;
   int m_max_trades_per_session;
   double m_max_daily_loss_pct;
   // FR-02 upgrade: timezone offset (minutes) and per-weekday windows
   int m_tz_offset_min;              // shift from server time to session local time
   string m_windows_spec;            // original spec string
   bool m_windows_parsed;            // true if weekly windows parsed successfully
   // Windows per weekday (0=Sun..6=Sat), up to 4 windows per day
   int  m_win_count[7];
   int  m_from_min[7][SESSION_MAX_WIN];      // minutes since 00:00 local
   int  m_to_min[7][SESSION_MAX_WIN];
   
   // Session state tracking
   datetime m_session_start_time;
   double m_session_baseline_equity;
   int m_session_trade_count;
   bool m_session_blocked;
   
public:
   CSessionManager(const string symbol, const ENUM_TIMEFRAMES timeframe) :
      m_symbol(symbol), m_timeframe(timeframe), m_enabled(false),
      m_session_start_hour(0), m_session_end_hour(24), m_max_trades_per_session(0),
      m_max_daily_loss_pct(0.0), m_tz_offset_min(0), m_windows_spec(""), m_windows_parsed(false),
      m_session_start_time(0), m_session_baseline_equity(0.0),
      m_session_trade_count(0), m_session_blocked(false)
      {
         for(int d2=0; d2<7; ++d2) m_win_count[d2]=0;
         for(int d=0; d<7; ++d)
           for(int i=0;i<SESSION_MAX_WIN;++i){ m_from_min[d][i]=0; m_to_min[d][i]=0; }
      }
   
   // Configuration
   void SetEnabled(const bool enabled) { m_enabled = enabled; }
   void SetSessionHours(const int start_hour, const int end_hour) 
   { 
      m_session_start_hour = start_hour; 
      m_session_end_hour = end_hour; 
   }
   void SetMaxTradesPerSession(const int max_trades) { m_max_trades_per_session = max_trades; }
   void SetMaxDailyLossPct(const double max_loss_pct) { m_max_daily_loss_pct = max_loss_pct; }
   void SetTimezoneOffsetMinutes(const int tz_offset_min) { m_tz_offset_min = tz_offset_min; }
   void SetWeeklyWindowsString(const string spec)
   {
      m_windows_spec = spec;
      m_windows_parsed = ParseWeeklyWindows(spec);
   }
   
   // Session boundary detection (resets baseline/trade counters on local day change)
   bool IsNewSession()
   {
      if(!m_enabled) return false;
      datetime now = TimeCurrent();
      datetime local_now = now + (m_tz_offset_min*60);
      MqlDateTime dt; TimeToStruct(local_now, dt);
      datetime current_session_start = StringToTime(StringFormat("%04d.%02d.%02d 00:00:00", dt.year, dt.mon, dt.day));
      
      if(m_session_start_time == 0 || current_session_start > m_session_start_time)
      {
         return true;
      }
      
      return false;
   }
   
   // Initialize new session
   void InitializeSession()
   {
      datetime local_now = TimeCurrent() + (m_tz_offset_min*60);
      MqlDateTime dt; TimeToStruct(local_now, dt);
      m_session_start_time = StringToTime(StringFormat("%04d.%02d.%02d 00:00:00", dt.year, dt.mon, dt.day));
      m_session_baseline_equity = AccountInfoDouble(ACCOUNT_EQUITY);
      m_session_trade_count = 0;
      m_session_blocked = false;
   }
   
   // Check if trading is allowed in current session
   bool IsSessionAllowed(string &reason)
   {
      reason = "ok";
      
      if(!m_enabled)
         return true;
      
      // Check if we're in a new session
      if(IsNewSession())
      {
         InitializeSession();
      }
      
      // Determine if we are inside configured time windows
      bool in_time_window = true; // default if no constraints
      datetime local_now = TimeCurrent() + (m_tz_offset_min*60);
      MqlDateTime dt; TimeToStruct(local_now, dt);
      if(m_windows_parsed)
      {
         int dow = dt.day_of_week; // 0=Sun..6=Sat
         int mins = dt.hour*60 + dt.min;
         in_time_window = IsWithinWindows(dow, mins);
      }
      else
      {
         // Backward compatibility: use simple start/end hour window (local)
         int current_hour = dt.hour;
         if(m_session_start_hour <= m_session_end_hour)
            in_time_window = (current_hour >= m_session_start_hour && current_hour < m_session_end_hour);
         else
            in_time_window = (current_hour >= m_session_start_hour || current_hour < m_session_end_hour);
      }
      
      if(!in_time_window)
      {
         reason = "outside_session_hours";
         return false;
      }
      
      // Check trade count limit
      if(m_max_trades_per_session > 0 && m_session_trade_count >= m_max_trades_per_session)
      {
         reason = "session_trade_limit_reached";
         return false;
      }
      
      // Check daily loss limit
      if(m_max_daily_loss_pct > 0.0 && m_session_baseline_equity > 0.0)
      {
         double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
         double loss_pct = 100.0 * (m_session_baseline_equity - current_equity) / m_session_baseline_equity;
         
         if(loss_pct > m_max_daily_loss_pct)
         {
            reason = StringFormat("daily_loss_limit_exceeded_%.2f_pct", loss_pct);
            m_session_blocked = true;
            return false;
         }
      }
      
      // Check if session was previously blocked
      if(m_session_blocked)
      {
         reason = "session_blocked";
         return false;
      }
      
      return true;
   }
   
   // Record a new trade
   void RecordTrade()
   {
      if(m_enabled)
      {
         m_session_trade_count++;
      }
   }
   
   // Get session statistics
   void GetSessionStats(int &trade_count, double &pnl_pct, bool &is_blocked)
   {
      trade_count = m_session_trade_count;
      is_blocked = m_session_blocked;
      
      if(m_session_baseline_equity > 0.0)
      {
         double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
         pnl_pct = 100.0 * (current_equity - m_session_baseline_equity) / m_session_baseline_equity;
      }
      else
      {
         pnl_pct = 0.0;
      }
   }
   
   // Reset session (for testing or manual reset)
   void ResetSession()
   {
      m_session_start_time = 0;
      m_session_baseline_equity = 0.0;
      m_session_trade_count = 0;
      m_session_blocked = false;
   }

private:
   int DayAbbrevToIndex(const string d)
   {
      string s=d; StringToLower(s);
      if(StringFind(s, "sun")==0) return 0;
      if(StringFind(s, "mon")==0) return 1;
      if(StringFind(s, "tue")==0) return 2;
      if(StringFind(s, "wed")==0) return 3;
      if(StringFind(s, "thu")==0) return 4;
      if(StringFind(s, "fri")==0) return 5;
      if(StringFind(s, "sat")==0) return 6;
      return -1;
   }
   bool ParseHHMM(const string hhmm, int &mins)
   {
      int pos = StringFind(hhmm, ":");
      if(pos<0) return false;
      string hh = StringSubstr(hhmm, 0, pos);
      string mm = StringSubstr(hhmm, pos+1);
      int h = (int)StringToInteger(hh);
      int m = (int)StringToInteger(mm);
      if(h<0||h>23||m<0||m>59) return false;
      mins = h*60 + m;
      return true;
   }
   bool ParseRange(const string range, int &from_min, int &to_min)
   {
      int pos = StringFind(range, "-");
      if(pos<0) return false;
      string a = StringSubstr(range, 0, pos);
      string b = StringSubstr(range, pos+1);
      int fm=0, tm=0;
      if(!ParseHHMM(a, fm)) return false;
      if(!ParseHHMM(b, tm)) return false;
      from_min=fm; to_min=tm; return true;
   }
   bool ParseWeeklyWindows(const string spec)
   {
      // reset counts and windows
      for(int d=0; d<7; ++d)
      {
         m_win_count[d]=0;
         for(int i=0;i<SESSION_MAX_WIN;++i){ m_from_min[d][i]=0; m_to_min[d][i]=0; }
      }
      if(spec=="" || StringLen(spec)<3) return false;
      // format example: "Mon=09:30-16:00;Tue=09:30-16:00;Sat=*;Sun=*"
      int start=0;
      while(start < StringLen(spec))
      {
         int sep = StringFind(spec, ";", start);
         string token = (sep<0? StringSubstr(spec, start) : StringSubstr(spec, start, sep-start));
         if(token!="")
         {
            int eq = StringFind(token, "=");
            if(eq>0)
            {
               string day = StringSubstr(token, 0, eq);
               string val = StringSubstr(token, eq+1);
               int di = DayAbbrevToIndex(day);
               if(di>=0)
               {
                  if(StringLen(val)>0 && val!="*")
                  {
                     // multiple ranges supported via comma
                     int st=0;
                     while(st < StringLen(val) && m_win_count[di] < SESSION_MAX_WIN)
                     {
                        int comma = StringFind(val, ",", st);
                        string r = (comma<0? StringSubstr(val, st) : StringSubstr(val, st, comma-st));
                        int fm=0, tm=0;
                        if(ParseRange(r, fm, tm))
                        {
                           int idx = m_win_count[di];
                           m_from_min[di][idx]=fm; m_to_min[di][idx]=tm; m_win_count[di]++;
                        }
                        if(comma<0) break; else st = comma+1;
                     }
                  }
                  else
                  {
                     // '*' means closed all day -> count=0 already
                     m_win_count[di]=0;
                  }
               }
            }
         }
         if(sep<0) break; else start = sep+1;
      }
      // success if at least one day has windows
      for(int d=0; d<7; ++d) if(m_win_count[d]>0) return true;
      return false;
   }
   bool IsWithinWindows(const int dow, const int minutes_local)
   {
      int d = (dow%7);
      int n = m_win_count[d];
      if(n<=0) return false; // closed day
      for(int i=0;i<n;++i)
      {
         int a = m_from_min[d][i];
         int b = m_to_min[d][i];
         if(a<=b)
         {
            if(minutes_local>=a && minutes_local<b) return true;
         }
         else
         {
            // overnight window within same day definition (e.g., 22:00-02:00)
            if(minutes_local>=a || minutes_local<b) return true;
         }
      }
      return false;
   }
};
