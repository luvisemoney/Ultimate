class CDonchian
  {
private:
   string   m_symbol;
   ENUM_TIMEFRAMES m_tf;
   int      m_period;
public:
   CDonchian(): m_symbol(""), m_tf(PERIOD_CURRENT), m_period(20) {}
   bool Init(const string symbol, const ENUM_TIMEFRAMES tf, const int period)
     {
      m_symbol = symbol; m_tf = tf; m_period = MathMax(1, period);
      return true;
     }
   double Upper(const int shift)
     {
      int count = m_period;
      double maxH = -DBL_MAX;
      for(int i=0;i<count;i++)
        {
         double h = iHigh(m_symbol, m_tf, shift+i);
         if(h>maxH) maxH=h;
        }
      return maxH;
     }
   double Lower(const int shift)
     {
      int count = m_period;
      double minL = DBL_MAX;
      for(int i=0;i<count;i++)
        {
         double l = iLow(m_symbol, m_tf, shift+i);
         if(l<minL) minL=l;
        }
      return minL;
     }
  };
