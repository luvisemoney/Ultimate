#ifndef DUALEA_INDICATORS_KELTNER_MQH
#define DUALEA_INDICATORS_KELTNER_MQH

class CKeltner
  {
private:
   string           m_symbol;
   ENUM_TIMEFRAMES  m_tf;
   int              m_emaPeriod;
   int              m_atrPeriod;
   double           m_atrMult;
   int              m_hEMA;
   int              m_hATR;

public:
   CKeltner(): m_symbol(""), m_tf(PERIOD_CURRENT), m_emaPeriod(20), m_atrPeriod(10), m_atrMult(1.5), m_hEMA(-1), m_hATR(-1) {}

   bool Init(const string symbol, const ENUM_TIMEFRAMES tf, const int emaPeriod=20, const int atrPeriod=10, const double atrMult=1.5)
     {
      m_symbol = symbol; m_tf=tf; m_emaPeriod=emaPeriod; m_atrPeriod=atrPeriod; m_atrMult=atrMult;
      m_hEMA = iMA(m_symbol, m_tf, m_emaPeriod, 0, MODE_EMA, PRICE_TYPICAL);
      m_hATR = iATR(m_symbol, m_tf, m_atrPeriod);
      return (m_hEMA>0 && m_hATR>0);
     }

   double Middle(const int shift)
     {
      if(m_hEMA<=0) return 0.0; double b[1];
      if(CopyBuffer(m_hEMA, 0, shift, 1, b)==1) return b[0];
      return 0.0;
     }

   double BandWidth(const int shift)
     {
      if(m_hATR<=0) return 0.0; double b[1];
      if(CopyBuffer(m_hATR, 0, shift, 1, b)==1) return m_atrMult * b[0];
      return 0.0;
     }

   double Upper(const int shift)
     {
      double m = Middle(shift);
      double w = BandWidth(shift);
      if(m<=0 || w<=0) return 0.0;
      return m + w;
     }

   double Lower(const int shift)
     {
      double m = Middle(shift);
      double w = BandWidth(shift);
      if(m<=0 || w<=0) return 0.0;
      return m - w;
     }

   double MiddleSlope(const int shift)
     {
      double v0 = Middle(shift);
      double v1 = Middle(shift+1);
      return (v0 - v1);
     }
  };

#endif // DUALEA_INDICATORS_KELTNER_MQH
