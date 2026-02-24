//+------------------------------------------------------------------+
//| IncrementalInsightEngine.mqh - Real-time Statistics Engine      |
//| Replaces batch InsightsRebuild with O(1) incremental updates    |
//+------------------------------------------------------------------+
#ifndef __INCREMENTAL_INSIGHT_ENGINE_MQH__
#define __INCREMENTAL_INSIGHT_ENGINE_MQH__

#include <Files\File.mqh>

// Running statistics using Welford's algorithm for numerical stability
struct SRunningStats
{
   string key;
   string strategy;
   string symbol;
   int    timeframe;
   
   // Core counters
   int    n;
   int    wins;
   double sum_r;
   double sum_r_sq;
   
   // Running calculations
   double mean_r;
   double m2_r;
   double max_dd_r;
   double peak_equity_r;
   double current_equity_r;
   
   // EWMA for responsiveness
   double ewma_win_rate;
   double ewma_alpha;
   
   // State
   bool   auto_promoted;
   datetime last_update;
   
   SRunningStats() : n(0), wins(0), sum_r(0), sum_r_sq(0), mean_r(0), m2_r(0),
                     max_dd_r(0), peak_equity_r(0), current_equity_r(0),
                     ewma_win_rate(0.5), ewma_alpha(0.05), auto_promoted(false), last_update(0) {}
};

//+------------------------------------------------------------------+
//| Incremental Insight Engine - O(1) Real-time Updates             |
//+------------------------------------------------------------------+
class CIncrementalInsightEngine
{
private:
   SRunningStats m_stats[];
   int           m_stat_count;
   string        m_state_file;
   datetime      m_last_flush;
   int           m_flush_interval;
   bool          m_dirty;
   
   int           m_min_trades;
   double        m_min_win_rate;
   double        m_min_profit_factor;
   double        m_max_drawdown_r;
   
   int FindOrCreateStats(const string &strategy, const string &symbol, const int timeframe)
   {
      string key = strategy + "|" + symbol + "|" + IntegerToString(timeframe);
      for(int i = 0; i < m_stat_count; i++)
         if(m_stats[i].key == key) return i;
      
      ArrayResize(m_stats, m_stat_count + 1);
      m_stats[m_stat_count].key = key;
      m_stats[m_stat_count].strategy = strategy;
      m_stats[m_stat_count].symbol = symbol;
      m_stats[m_stat_count].timeframe = timeframe;
      m_stats[m_stat_count].last_update = TimeCurrent();
      m_stat_count++;
      return m_stat_count - 1;
   }
   
   int FindStats(const string &strategy, const string &symbol, const int timeframe)
   {
      string key = strategy + "|" + symbol + "|" + IntegerToString(timeframe);
      for(int i = 0; i < m_stat_count; i++)
         if(m_stats[i].key == key) return i;
      return -1;
   }
   
   void UpdateMeanVariance(SRunningStats &s, double r)
   {
      s.n++;
      double delta = r - s.mean_r;
      s.mean_r += delta / s.n;
      double delta2 = r - s.mean_r;
      s.m2_r += delta * delta2;
   }
   
   void UpdateDrawdown(SRunningStats &s, double r)
   {
      s.current_equity_r += r;
      if(s.current_equity_r > s.peak_equity_r)
         s.peak_equity_r = s.current_equity_r;
      double dd = s.peak_equity_r - s.current_equity_r;
      if(dd > s.max_dd_r) s.max_dd_r = dd;
   }
   
   void CheckPromotion(int idx)
   {
      if(m_stats[idx].auto_promoted) return;
      if(m_stats[idx].n < m_min_trades) return;
      
      double win_rate = (double)m_stats[idx].wins / m_stats[idx].n;
      double pf = CalculateProfitFactor(m_stats[idx]);
      
      if(win_rate >= m_min_win_rate && pf >= m_min_profit_factor && m_stats[idx].max_dd_r <= m_max_drawdown_r)
      {
         m_stats[idx].auto_promoted = true;
         PrintFormat("[AUTO-PROMOTE] %s on %s M%d: WR=%.1f%% PF=%.2f DD=%.2fR",
                     m_stats[idx].strategy, m_stats[idx].symbol, m_stats[idx].timeframe, win_rate*100, pf, m_stats[idx].max_dd_r);
         WritePromotionFlag(m_stats[idx]);
      }
   }
   
   double CalculateProfitFactor(SRunningStats &s)
   {
      if(s.n == 0) return 0;
      double gross_profit = s.wins * (s.mean_r > 0 ? s.mean_r * 1.5 : 1.0);
      double gross_loss = (s.n - s.wins) * (s.mean_r < 0 ? MathAbs(s.mean_r) * 0.5 : 0.5);
      if(gross_loss == 0) return gross_profit > 0 ? 999 : 0;
      return gross_profit / gross_loss;
   }
   
   void WritePromotionFlag(SRunningStats &s)
   {
      string flag_file = "DualEA\\promotions\\" + s.strategy + "_" + s.symbol + "_" + 
                        IntegerToString(s.timeframe) + ".promo";
      FolderCreate("DualEA\\promotions", FILE_COMMON);
      int h = FileOpen(flag_file, FILE_WRITE|FILE_TXT|FILE_COMMON);
      if(h != INVALID_HANDLE)
      {
         FileWriteString(h, TimeToString(TimeCurrent()) + ",APPROVED");
         FileClose(h);
      }
   }
   
public:
   CIncrementalInsightEngine()
   {
      m_stat_count = 0;
      m_state_file = "DualEA\\engine_state.bin";
      m_last_flush = 0;
      m_flush_interval = 300;
      m_dirty = false;
      m_min_trades = 30;
      m_min_win_rate = 0.52;
      m_min_profit_factor = 1.2;
      m_max_drawdown_r = 10.0;
      LoadState();
   }
   
   ~CIncrementalInsightEngine() { SaveState(); }
   
   // O(1) update - call from OnTradeTransaction
   void RecordTradeOutcome(const string &strategy, const string &symbol, 
                          const int timeframe, const double r_multiple)
   {
      int idx = FindOrCreateStats(strategy, symbol, timeframe);
      
      m_stats[idx].sum_r += r_multiple;
      m_stats[idx].sum_r_sq += r_multiple * r_multiple;
      if(r_multiple > 0) m_stats[idx].wins++;
      
      UpdateMeanVariance(m_stats[idx], r_multiple);
      UpdateDrawdown(m_stats[idx], r_multiple);
      
      bool is_win = r_multiple > 0;
      m_stats[idx].ewma_win_rate = m_stats[idx].ewma_alpha * (is_win ? 1.0 : 0.0) + (1.0 - m_stats[idx].ewma_alpha) * m_stats[idx].ewma_win_rate;
      m_stats[idx].last_update = TimeCurrent();
      m_dirty = true;
      
      CheckPromotion(idx);
   }
   
   // Instant query for LiveEA (no file I/O)
   bool GetStrategyMetrics(const string &strategy, const string &symbol, const int timeframe,
                          int &trade_count, double &win_rate, double &avg_r,
                          double &profit_factor, double &max_dd_r)
   {
      int idx = FindStats(strategy, symbol, timeframe);
      if(idx < 0) return false;
      
      trade_count = m_stats[idx].n;
      win_rate = m_stats[idx].n > 0 ? (double)m_stats[idx].wins / m_stats[idx].n : 0;
      avg_r = m_stats[idx].mean_r;
      profit_factor = CalculateProfitFactor(m_stats[idx]);
      max_dd_r = m_stats[idx].max_dd_r;
      return true;
   }
   
   bool IsStrategyApproved(const string &strategy, const string &symbol, const int timeframe)
   {
      int idx = FindStats(strategy, symbol, timeframe);
      if(idx < 0) return false;
      return m_stats[idx].auto_promoted;
   }
   
   void MaybeFlush()
   {
      if(!m_dirty) return;
      if(TimeCurrent() - m_last_flush < m_flush_interval) return;
      SaveState();
      m_last_flush = TimeCurrent();
      m_dirty = false;
   }

   void FlushNow()
   {
      if(!m_dirty && m_stat_count <= 0)
         return;
      SaveState();
      m_last_flush = TimeCurrent();
      m_dirty = false;
   }
   
   void SaveState()
   {
      FolderCreate("DualEA", FILE_COMMON);
      int h = FileOpen(m_state_file, FILE_WRITE|FILE_BIN|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE);
      if(h == INVALID_HANDLE)
      {
         PrintFormat("[InsightEngine] SaveState: cannot open %s (Common). err=%d", m_state_file, GetLastError());
         return;
      }
      
      FileWriteInteger(h, m_stat_count);
      for(int i = 0; i < m_stat_count; i++)
      {
         FileWriteString(h, m_stats[i].key);
         FileWriteString(h, m_stats[i].strategy);
         FileWriteString(h, m_stats[i].symbol);
         FileWriteInteger(h, m_stats[i].timeframe);
         FileWriteInteger(h, m_stats[i].n);
         FileWriteInteger(h, m_stats[i].wins);
         FileWriteDouble(h, m_stats[i].mean_r);
         FileWriteDouble(h, m_stats[i].m2_r);
         FileWriteDouble(h, m_stats[i].max_dd_r);
         FileWriteDouble(h, m_stats[i].peak_equity_r);
         FileWriteDouble(h, m_stats[i].ewma_win_rate);
         FileWriteInteger(h, m_stats[i].auto_promoted ? 1 : 0);
         FileWriteLong(h, m_stats[i].last_update);
      }
      FileClose(h);
      PrintFormat("[InsightEngine] Saved %d strategy records to %s (Common=%s)",
                  m_stat_count, m_state_file, TerminalInfoString(TERMINAL_COMMONDATA_PATH));
   }
   
   void LoadState()
   {
      FolderCreate("DualEA", FILE_COMMON);
      if(FileGetInteger(m_state_file, FILE_EXISTS, true) <= 0)
      {
         PrintFormat("[InsightEngine] State file NOT FOUND: %s (Common=%s) - cold start", m_state_file, TerminalInfoString(TERMINAL_COMMONDATA_PATH));
         return;
      }
      int h = FileOpen(m_state_file, FILE_READ|FILE_BIN|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE);
      if(h == INVALID_HANDLE)
      {
         PrintFormat("[InsightEngine] LoadState: cannot open %s (Common). err=%d", m_state_file, GetLastError());
         return;
      }
      
      m_stat_count = FileReadInteger(h);
      ArrayResize(m_stats, m_stat_count);
      
      for(int i = 0; i < m_stat_count; i++)
      {
         m_stats[i].key = FileReadString(h);
         m_stats[i].strategy = FileReadString(h);
         m_stats[i].symbol = FileReadString(h);
         m_stats[i].timeframe = FileReadInteger(h);
         m_stats[i].n = FileReadInteger(h);
         m_stats[i].wins = FileReadInteger(h);
         m_stats[i].mean_r = FileReadDouble(h);
         m_stats[i].m2_r = FileReadDouble(h);
         m_stats[i].max_dd_r = FileReadDouble(h);
         m_stats[i].peak_equity_r = FileReadDouble(h);
         m_stats[i].ewma_win_rate = FileReadDouble(h);
         m_stats[i].auto_promoted = (FileReadInteger(h) == 1);
         m_stats[i].last_update = (datetime)FileReadLong(h);
      }
      FileClose(h);
      PrintFormat("[InsightEngine] Loaded %d strategy records from %s (Common=%s)",
                  m_stat_count, m_state_file, TerminalInfoString(TERMINAL_COMMONDATA_PATH));
   }
   
   void SetPromotionCriteria(int min_trades, double min_wr, double min_pf, double max_dd)
   {
      m_min_trades = min_trades;
      m_min_win_rate = min_wr;
      m_min_profit_factor = min_pf;
      m_max_drawdown_r = max_dd;
   }
};

// Global singleton access - extern declaration (defined in EA files)
extern CIncrementalInsightEngine* g_insight_engine;

#endif
