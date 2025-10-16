#ifndef __DUALEA_VOLATILITYEXIT_MQH__
#define __DUALEA_VOLATILITYEXIT_MQH__

#include <Trade/PositionInfo.mqh>
#include "..\LogMiddleware.mqh"

class CVolatilityExit
{
public:
  // Evaluate ATR-based trailing exit. Returns true when exit is advised,
  // and fills close_price_out/reason_out.
  static bool Evaluate(const string symbol,
                       const int atr_period,
                       const double atr_mult,
                       const ENUM_POSITION_TYPE ptype,
                       const double bid,
                       const double ask,
                       const double current_sl,
                       double &close_price_out,
                       string &reason_out)
  {
    close_price_out = 0.0; reason_out = "";
    if(atr_mult<=0.0 || atr_period<=0) return false;

    int handle = iATR(symbol, PERIOD_CURRENT, atr_period);
    if(handle==INVALID_HANDLE) return false;
    double buf[]; int copied = CopyBuffer(handle, 0, 0, 1, buf);
    IndicatorRelease(handle);
    if(copied!=1) return false;
    double atr = buf[0]; if(atr<=0.0) return false;

    if(ptype==POSITION_TYPE_BUY)
    {
      double trail = bid - (atr * atr_mult);
      if(current_sl>0.0 && trail<=current_sl) return false; // SL already protective
      if(trail>0.0 && bid <= trail - _Point)
      {
        close_price_out = bid; reason_out = "VolatilityExit"; return true;
      }
    }
    else if(ptype==POSITION_TYPE_SELL)
    {
      double trail = ask + (atr * atr_mult);
      if(current_sl>0.0 && trail>=current_sl) return false;
      if(trail>0.0 && ask >= trail + _Point)
      {
        close_price_out = ask; reason_out = "VolatilityExit"; return true;
      }
    }
    return false;
  }
};

#endif // __DUALEA_VOLATILITYEXIT_MQH__
