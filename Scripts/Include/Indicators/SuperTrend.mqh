class CSuperTrend
  {
private:
   string m_symbol; ENUM_TIMEFRAMES m_tf; int m_atrPeriod; double m_mult; int m_hATR;
public:
   CSuperTrend(): m_symbol(""), m_tf(PERIOD_CURRENT), m_atrPeriod(10), m_mult(3.0), m_hATR(-1) {}
   bool Init(const string symbol, const ENUM_TIMEFRAMES tf, const int atrPeriod=10, const double mult=3.0)
     { m_symbol=symbol; m_tf=tf; m_atrPeriod=MathMax(1,atrPeriod); m_mult=mult; m_hATR=iATR(m_symbol,m_tf,m_atrPeriod); return (m_hATR>0); }
   // Returns +1 uptrend, -1 downtrend at shift
   int Direction(const int shift)
     {
      double atr=0.0; double b[1];
      if(m_hATR>0 && CopyBuffer(m_hATR,0,shift,1,b)==1) atr=b[0];
      if(atr<=0) return 0;
      double hl2 = (iHigh(m_symbol,m_tf,shift)+iLow(m_symbol,m_tf,shift))/2.0;
      // Simplified supertrend: compare close to hl2 band +/- m_mult*atr
      double upBand = hl2 - m_mult*atr;
      double dnBand = hl2 + m_mult*atr;
      double close = iClose(m_symbol,m_tf,shift);
      if(close>=dnBand) return +1;
      if(close<=upBand) return -1;
      // fallback to prev direction
      int prev = 0; if(shift+1<1000) prev = Direction(shift+1); return prev;
     }
  };
