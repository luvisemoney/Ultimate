#include <Files/File.mqh>

class CStrategySelector
  {
private:
   // Slice metrics
   string  m_strat[];
   string  m_sym[];
   int     m_tf[];
   int     m_cnt[];
   double  m_wr[];
   double  m_avgR[];
   double  m_pf[];
   double  m_dd[];

   // Data presence flag (for cold-start pass-through)
   bool    m_has_data;

   // Selector strictness: when true, apply hard thresholds inside Score(); otherwise gate in Insights_Allow only
   bool    strict_thresholds;

   // Thresholds
   int     th_min_trades;
   double  th_min_wr;
   double  th_min_exp;
   double  th_min_pf;
   double  th_max_dd;

   // Weights
   double  w_pf, w_exp, w_wr, w_dd;

   // Recency weighting
   bool    use_recency; int recent_days; double rec_alpha;
   // Recent overlays (parallel arrays to main slices)
   int     m_rc_cnt[]; double m_rc_wr[]; double m_rc_avgR[]; double m_rc_pf[];

   string TrimCopy(string s){ StringTrimLeft(s); StringTrimRight(s); return s; }

public:
   CStrategySelector()
     {
      th_min_trades = 20; th_min_wr = 0.50; th_min_exp = 0.0; th_min_pf = 2.0; th_max_dd = 6.0;
      w_pf = 1.0; w_exp = 1.0; w_wr = 0.5; w_dd = 0.3;
      use_recency=false; recent_days=14; rec_alpha=0.5;
      m_has_data=false;
      strict_thresholds=false;
     }

   void ConfigureThresholds(const int min_trades, const double min_wr, const double min_exp, const double min_pf, const double max_dd)
     { th_min_trades=min_trades; th_min_wr=min_wr; th_min_exp=min_exp; th_min_pf=min_pf; th_max_dd=max_dd; }
   void ConfigureWeights(const double wp, const double we, const double ww, const double wd)
     { w_pf=wp; w_exp=we; w_wr=ww; w_dd=wd; }
   void ConfigureRecency(const bool useRecency, const int lookbackDays, const double alpha)
      { use_recency=useRecency; recent_days=lookbackDays; rec_alpha=alpha; }

   bool Load()
     {
      int h = FileOpen("DualEA\\insights.json", FILE_READ|FILE_TXT|FILE_COMMON|FILE_ANSI);
      if(h==INVALID_HANDLE) return false;
      ArrayResize(m_strat,0); ArrayResize(m_sym,0); ArrayResize(m_tf,0);
      ArrayResize(m_cnt,0); ArrayResize(m_wr,0); ArrayResize(m_avgR,0); ArrayResize(m_pf,0); ArrayResize(m_dd,0);
      while(!FileIsEnding(h))
        {
         string line = FileReadString(h);
         if(line=="" && FileIsEnding(h)) break;
         if(StringFind(line, "\"strategy\"", 0) < 0) continue;
         // parse simple JSON line for slice fields
         string sname="", yname=""; int tfv=0, cnt=0; double wr=0, avgR=0, pf=0, dd=0;
         int p=0;
         p = StringFind(line, "\"strategy\":", 0); if(p>=0){ int q=StringFind(line, ",", p+1); string seg=(q>p? StringSubstr(line,p,q-p):StringSubstr(line,p)); int c=StringFind(seg, ":", 0); if(c>=0){ sname=TrimCopy(StringSubstr(seg, c+1)); StringReplace(sname, "\"", ""); } }
         p = StringFind(line, "\"symbol\":", 0);   if(p>=0){ int q=StringFind(line, ",", p+1); string seg=(q>p? StringSubstr(line,p,q-p):StringSubstr(line,p)); int c=StringFind(seg, ":", 0); if(c>=0){ yname=TrimCopy(StringSubstr(seg, c+1)); StringReplace(yname, "\"", ""); } }
         p = StringFind(line, "\"timeframe\":",0); if(p>=0){ int q=StringFind(line, ",", p+1); string seg=(q>p? StringSubstr(line,p,q-p):StringSubstr(line,p)); int c=StringFind(seg, ":", 0); if(c>=0){ string num=TrimCopy(StringSubstr(seg,c+1)); tfv=(int)StringToInteger(num);} }
         p = StringFind(line, "\"trade_count\":",0);if(p>=0){ int q=StringFind(line, ",", p+1); string seg=(q>p? StringSubstr(line,p,q-p):StringSubstr(line,p)); int c=StringFind(seg, ":", 0); if(c>=0){ string num=TrimCopy(StringSubstr(seg,c+1)); cnt=(int)StringToInteger(num);} }
         p = StringFind(line, "\"win_rate\":",0);   if(p>=0){ int q=StringFind(line, ",", p+1); string seg=(q>p? StringSubstr(line,p,q-p):StringSubstr(line,p)); int c=StringFind(seg, ":", 0); if(c>=0){ string num=TrimCopy(StringSubstr(seg,c+1)); wr=StringToDouble(num);} }
         p = StringFind(line, "\"avg_R\":",0);      if(p>=0){ int q=StringFind(line, ",", p+1); string seg=(q>p? StringSubstr(line,p,q-p):StringSubstr(line,p)); int c=StringFind(seg, ":", 0); if(c>=0){ string num=TrimCopy(StringSubstr(seg,c+1)); avgR=StringToDouble(num);} }
         p = StringFind(line, "\"profit_factor\":",0);if(p>=0){int q=StringFind(line, ",", p+1); string seg=(q>p? StringSubstr(line,p,q-p):StringSubstr(line,p)); int c=StringFind(seg, ":", 0); if(c>=0){ string num=TrimCopy(StringSubstr(seg,c+1)); pf=StringToDouble(num);} }
         p = StringFind(line, "\"max_drawdown_R\":",0);if(p>=0){int q=StringFind(line, ",", p+1); string seg=(q>p? StringSubstr(line,p,q-p):StringSubstr(line,p)); int c=StringFind(seg, ":", 0); if(c>=0){ string num=TrimCopy(StringSubstr(seg,c+1)); dd=StringToDouble(num);} }
         if(sname!="" && yname!="" && tfv>0)
           {
            int n = ArraySize(m_strat);
            ArrayResize(m_strat,n+1); ArrayResize(m_sym,n+1); ArrayResize(m_tf,n+1);
            ArrayResize(m_cnt,n+1); ArrayResize(m_wr,n+1); ArrayResize(m_avgR,n+1); ArrayResize(m_pf,n+1); ArrayResize(m_dd,n+1);
            m_strat[n]=sname; m_sym[n]=yname; m_tf[n]=tfv; m_cnt[n]=cnt; m_wr[n]=wr; m_avgR[n]=avgR; m_pf[n]=pf; m_dd[n]=dd;
           }
        }
      FileClose(h);
      // initialize recent arrays to defaults
      int n=ArraySize(m_strat);
      m_has_data = (n>0);
      ArrayResize(m_rc_cnt,n); ArrayInitialize(m_rc_cnt,0);
      ArrayResize(m_rc_wr,n);  ArrayInitialize(m_rc_wr,0.0);
      ArrayResize(m_rc_avgR,n);ArrayInitialize(m_rc_avgR,0.0);
      ArrayResize(m_rc_pf,n);  ArrayInitialize(m_rc_pf,0.0);
      return ArraySize(m_strat)>0;
     }

   bool LoadRecent()
     {
      if(!use_recency) return false;
      int h = FileOpen("DualEA\\features.csv", FILE_READ|FILE_TXT|FILE_COMMON|FILE_ANSI);
      if(h==INVALID_HANDLE) return false;
      datetime now = TimeCurrent();
      datetime cutoff = now - recent_days*24*60*60;
      // Build accumulators per slice index
      int n=ArraySize(m_strat);
      double pos_sum[]; double neg_sum[]; double total_trades[]; double wins[]; double sumR[];
      ArrayResize(pos_sum,n); ArrayInitialize(pos_sum,0.0);
      ArrayResize(neg_sum,n); ArrayInitialize(neg_sum,0.0);
      ArrayResize(total_trades,n); ArrayInitialize(total_trades,0.0);
      ArrayResize(wins,n); ArrayInitialize(wins,0.0);
      ArrayResize(sumR,n); ArrayInitialize(sumR,0.0);

      while(!FileIsEnding(h))
        {
         string line = FileReadString(h);
         if(line=="" && FileIsEnding(h)) break;
         // Expect CSV: ts,symbol,strategy,key,value
         int p0 = StringFind(line, ",", 0); if(p0<0) continue; string ts  = StringSubstr(line,0,p0);
         int p1 = StringFind(line, ",", p0+1); if(p1<0) continue; string sym = StringSubstr(line,p0+1,p1-p0-1);
         int p2 = StringFind(line, ",", p1+1); if(p2<0) continue; string strat = StringSubstr(line,p1+1,p2-p1-1);
         int p3 = StringFind(line, ",", p2+1); if(p3<0) continue; string key = StringSubstr(line,p2+1,p3-p2-1);
         string val = StringSubstr(line,p3+1);
         StringTrimLeft(sym); StringTrimRight(sym); StringTrimLeft(strat); StringTrimRight(strat); StringTrimLeft(key); StringTrimRight(key);
         datetime t = (datetime)StringToTime(ts);
         if(t<cutoff) continue;
         if(StringCompare(key,"r_multiple")!=0) continue;
         double r = StringToDouble(val);
         // find index of slice by symbol/strategy and timeframe is unknown in features.csv; approximate by current timeframe of EA symbol
         for(int i=0;i<n;++i)
           {
            if(m_sym[i]==sym && m_strat[i]==strat)
              {
               total_trades[i] += 1.0;
               sumR[i] += r;
               if(r>0) pos_sum[i]+=r; else if(r<0) neg_sum[i]+=r;
               if(r>0) wins[i]+=1.0;
              }
           }
        }
      FileClose(h);
      for(int i=0;i<n;++i)
        {
         if(total_trades[i]<=0) continue;
         double rc_wr   = wins[i]/total_trades[i];
         double rc_avgR = sumR[i]/total_trades[i];
         double rc_pf   = (pos_sum[i]>0 && neg_sum[i]<0? pos_sum[i]/MathAbs(neg_sum[i]) : 0.0);
         m_rc_cnt[i]  = (int)total_trades[i];
         m_rc_wr[i]   = rc_wr;
         m_rc_avgR[i] = rc_avgR;
         m_rc_pf[i]   = rc_pf;
        }
      return true;
     }

   double Score(const string symbol, const int timeframe, const string strategy)
     {
      // Cold-start: if no insights slices loaded, allow pass-through to generate data
      if(ArraySize(m_strat)==0 || !m_has_data)
        {
         return 1.0; // neutral positive score; no thresholds applied
        }
      for(int i=0;i<ArraySize(m_strat);++i)
        {
         if(m_strat[i]==strategy && m_sym[i]==symbol && m_tf[i]==timeframe)
           {
            if(strict_thresholds)
              {
               if(m_cnt[i] < th_min_trades) return 0.0;
               if(m_wr[i]  < th_min_wr)     return 0.0;
               if(m_avgR[i]< th_min_exp)    return 0.0;
               if(m_pf[i]  < th_min_pf)     return 0.0;
               if(m_dd[i]  > th_max_dd)     return 0.0;
              }
            double pf   = m_pf[i];
            double avgR = m_avgR[i];
            double wr   = m_wr[i];
            if(use_recency && i<ArraySize(m_rc_pf))
              {
               if(m_rc_cnt[i]>0)
                 {
                  pf   = (1.0-rec_alpha)*pf   + rec_alpha*m_rc_pf[i];
                  avgR = (1.0-rec_alpha)*avgR + rec_alpha*m_rc_avgR[i];
                  wr   = (1.0-rec_alpha)*wr   + rec_alpha*m_rc_wr[i];
                 }
              }
            double s = w_pf*pf + w_exp*avgR + w_wr*wr - w_dd*m_dd[i];
            if(!strict_thresholds && m_cnt[i] < th_min_trades)
              {
               double scale = (double)m_cnt[i] / (double)MathMax(1, th_min_trades);
               s *= scale;
              }
            return s;
           }
        }
      // Fallback 1: aggregate by strategy+symbol across all timeframes
      int total=0; double sumR=0.0, wins=0.0, gp=0.0, gl=0.0; double dd_series[];
      for(int j=0;j<ArraySize(m_strat);++j)
        if(m_strat[j]==strategy && m_sym[j]==symbol)
          {
           total += m_cnt[j];
           sumR  += m_avgR[j]*m_cnt[j];
           wins  += m_wr[j]*m_cnt[j];
           if(m_pf[j]>0 && m_pf[j]<9999){ // approximate gp/gl from pf and avgR if possible
             // Not exact; use pf as weighting only in final score. For thresholds use aggregated avg/wr only.
           }
           int k = ArraySize(dd_series); ArrayResize(dd_series,k+1); dd_series[k]=m_avgR[j]; // proxy for series; conservative
          }
      if(total>0)
        {
         double wr = wins/total;
         double avgR = sumR/total;
         double pf = 0.0; // unknown reliably from aggregates; approximate via weighted mean of pf
         double pf_sum=0.0; int pf_cnt=0; for(int q=0;q<ArraySize(m_strat);++q){ if(m_strat[q]==strategy && m_sym[q]==symbol){ pf_sum+=m_pf[q]; pf_cnt++; } }
         if(pf_cnt>0) pf = pf_sum/pf_cnt;
         double dd = 0.0; // drawdown proxy not reliable without series; use worst of slices
         for(int q=0;q<ArraySize(m_strat);++q){ if(m_strat[q]==strategy && m_sym[q]==symbol && m_dd[q]>dd) dd=m_dd[q]; }
         if(strict_thresholds)
           {
            if(total < th_min_trades) return 0.0;
            if(wr  < th_min_wr)       return 0.0;
            if(avgR< th_min_exp)      return 0.0;
            if(pf  < th_min_pf)       return 0.0;
            if(dd  > th_max_dd)       return 0.0;
           }
         double s = w_pf*pf + w_exp*avgR + w_wr*wr - w_dd*dd;
         if(!strict_thresholds && total < th_min_trades)
           {
            double scale = (double)total / (double)MathMax(1, th_min_trades);
            s *= scale;
           }
         return s;
        }

      // Fallback 2: aggregate by strategy across all symbols/timeframes
      total=0; sumR=0.0; wins=0.0; double pf_sum2=0.0; int pf_cnt2=0; double worst_dd=0.0;
      for(int j=0;j<ArraySize(m_strat);++j)
        if(m_strat[j]==strategy)
          {
           total += m_cnt[j];
           sumR  += m_avgR[j]*m_cnt[j];
           wins  += m_wr[j]*m_cnt[j];
           pf_sum2 += m_pf[j]; pf_cnt2++;
           if(m_dd[j]>worst_dd) worst_dd=m_dd[j];
          }
      if(total>0)
        {
         double wr = wins/total;
         double avgR = sumR/total;
         double pf = (pf_cnt2>0? pf_sum2/pf_cnt2 : 0.0);
         double dd = worst_dd;
         if(strict_thresholds)
           {
            if(total < th_min_trades) return 0.0;
            if(wr  < th_min_wr)       return 0.0;
            if(avgR< th_min_exp)      return 0.0;
            if(pf  < th_min_pf)       return 0.0;
            if(dd  > th_max_dd)       return 0.0;
           }
         double s = w_pf*pf + w_exp*avgR + w_wr*wr - w_dd*dd;
         if(!strict_thresholds && total < th_min_trades)
           {
            double scale = (double)total / (double)MathMax(1, th_min_trades);
            s *= scale;
           }
         return s;
        }

      return 0.0; // unknown slice
     }

   int PickBest(const string symbol, const int timeframe, string &strategies[], double &out_scores[])
     {
      int best=-1; double bestS=-1e9;
      ArrayResize(out_scores, ArraySize(strategies));
      for(int i=0;i<ArraySize(strategies);++i)
        {
         double s = Score(symbol, timeframe, strategies[i]);
         out_scores[i]=s;
         if(s>bestS){ bestS=s; best=i; }
        }
      return best;
     }
  };
