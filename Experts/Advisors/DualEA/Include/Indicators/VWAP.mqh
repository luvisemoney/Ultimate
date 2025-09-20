#ifndef DUALEA_INDICATORS_VWAP_MQH
#define DUALEA_INDICATORS_VWAP_MQH
// Simple rolling-window VWAP wrapper for MQL5
// Note: MT5 does not provide a native iVWAP handle; this computes a rolling VWAP over m_window bars.

class CVWAP
  {
private:
   string           m_symbol;
   ENUM_TIMEFRAMES  m_tf;
   int              m_window; // bars

   double TypicalPrice(const int shift)
     {
      double h = iHigh(m_symbol, m_tf, shift);
      double l = iLow(m_symbol,  m_tf, shift);
      double c = iClose(m_symbol,m_tf, shift);
      if(h==0.0 && l==0.0 && c==0.0) return 0.0;
      return (h + l + c) / 3.0;
     }

public:
   CVWAP(): m_symbol(""), m_tf(PERIOD_CURRENT), m_window(30) {}

   bool Init(const string symbol, const ENUM_TIMEFRAMES tf, const int window_bars=30)
     {
      m_symbol = symbol;
      m_tf     = tf;
      m_window = MathMax(1, window_bars);
      return true;
     }

   // Rolling VWAP over [shift .. shift+m_window-1]
   double Value(const int shift)
     {
      double sum_vp = 0.0;
      double sum_v  = 0.0;
      int    count  = 0;
      for(int i=shift; i<shift+m_window; ++i)
        {
         datetime t = iTime(m_symbol, m_tf, i);
         if(t==0) break;
         long v_raw = (long)iVolume(m_symbol, m_tf, i);
         double v = (double)v_raw;
         if(v<=0) continue;
         double tp = TypicalPrice(i);
         if(tp<=0) continue;
         sum_vp += tp * v;
         sum_v  += v;
         count++;
        }
      if(sum_v<=0.0 || count<=0) return 0.0;
      return sum_vp / sum_v;
     }

   double Slope(const int shift)
     {
      double v0 = Value(shift);
      double v1 = Value(shift+1);
      return (v0 - v1);
     }
  };

#endif // DUALEA_INDICATORS_VWAP_MQH
