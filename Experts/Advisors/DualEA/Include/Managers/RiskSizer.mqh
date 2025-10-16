#ifndef __DUALEA_RISKSIZER_MQH__
#define __DUALEA_RISKSIZER_MQH__

#include "..\LogMiddleware.mqh"

class CRiskSizer
{
public:
  // Cap additional volume relative to current position size.
  // Example policy: limit to +50% of current volume.
  static double CapAdditionalVolume(const double current_volume, const double proposed)
  {
    if(current_volume<=0.0) return proposed;
    double max_add = current_volume * 0.5;
    if(proposed > max_add) return max_add;
    return proposed;
  }
};

#endif // __DUALEA_RISKSIZER_MQH__
