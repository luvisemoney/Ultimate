class CRSI
  {
private:
   string m_symbol; ENUM_TIMEFRAMES m_tf; int m_period; int m_price; int m_handle;
public:
   CRSI(): m_symbol(""), m_tf(PERIOD_CURRENT), m_period(14), m_price(PRICE_CLOSE), m_handle(-1) {}
   bool Init(const string symbol, const ENUM_TIMEFRAMES tf, const int period=14, const int applied_price=PRICE_CLOSE)
     { m_symbol=symbol; m_tf=tf; m_period=period; m_price=applied_price; m_handle=iRSI(m_symbol,m_tf,m_period,m_price); return (m_handle>0); }
   double Value(const int shift)
     {
      if(m_handle<=0) return 0.0; double b[1];
      if(CopyBuffer(m_handle,0,shift,1,b)==1) return b[0];
      return 0.0;
     }
  };
