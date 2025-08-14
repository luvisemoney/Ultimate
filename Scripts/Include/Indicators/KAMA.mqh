class CKAMA
  {
private:
   string m_symbol; ENUM_TIMEFRAMES m_tf; int m_period; int m_fast; int m_slow; int m_handle;
public:
   CKAMA(): m_symbol(""), m_tf(PERIOD_CURRENT), m_period(10), m_fast(2), m_slow(30), m_handle(-1) {}
   bool Init(const string symbol, const ENUM_TIMEFRAMES tf, const int period=10, const int fast=2, const int slow=30)
     {
      m_symbol=symbol; m_tf=tf; m_period=MathMax(1,period); m_fast=fast; m_slow=slow;
      // iAMA signature requires 7 params in MQL5: add shift=0 before applied price
      m_handle = iAMA(m_symbol, m_tf, m_period, m_fast, m_slow, 0, PRICE_CLOSE);
      return (m_handle>0);
     }
   double Value(const int shift)
     {
      double out[1];
      if(m_handle<=0) return 0.0;
      if(CopyBuffer(m_handle, 0, shift, 1, out)==1) return out[0];
      return 0.0;
     }
   double Slope(const int shift)
     {
      double v0 = Value(shift);
      double v1 = Value(shift+1);
      return (v0 - v1);
     }
  };
