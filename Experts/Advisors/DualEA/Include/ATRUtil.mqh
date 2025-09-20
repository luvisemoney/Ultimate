// ATR utility for all strategies
#ifndef DUALEA_INCLUDE_ATR_UTIL_MQH
#define DUALEA_INCLUDE_ATR_UTIL_MQH

#include <Trade\Trade.mqh>

// Returns ATR value for the current symbol/period/shift
inline double GetATR(int period=14, int shift=0) {
    int handle = iATR(_Symbol, _Period, period);
    if(handle==INVALID_HANDLE) return -1.0;
    double buf[];
    if(CopyBuffer(handle, 0, shift, 1, buf)==1) {
        IndicatorRelease(handle);
        return buf[0];
    }
    IndicatorRelease(handle);
    return -1.0;
}

#endif // DUALEA_INCLUDE_ATR_UTIL_MQH
