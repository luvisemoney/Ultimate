// include guard for MQL5
#ifndef __GATINGPIPELINE_FIXED_MQH__
#define __GATINGPIPELINE_FIXED_MQH__

#include <Trade/Trade.mqh>

// Fallback stubs for optional manager variables
#ifndef UseSessionManager
  static bool UseSessionManager = false;
#endif
#ifndef UseCorrelationManager
  static bool UseCorrelationManager = false;
#endif
#ifndef UsePositionManager
  static bool UsePositionManager = false;
#endif
#ifndef TelemetryEnabled
  static bool TelemetryEnabled = false;
#endif
#ifndef NoConstraintsMode
  static bool NoConstraintsMode = false;
#endif
#ifndef PMMaxOpenPositions
  #define PMMaxOpenPositions 0
#endif

// Default stubs for logging functions if not provided by the host EA
#ifndef LogGate
  inline void LogGate(const string gate, const bool allow, const string phase, const ulong start_time) {}
#endif
#ifndef NowMs
  inline ulong NowMs() { return (ulong)(GetTickCount64()); }
#endif

// Macro to get the position manager cap safely within other macros
#define GP_GET_PM_CAP() (UsePositionManager && CheckPointer(g_position_manager)!=POINTER_INVALID ? (*g_position_manager).ComputeDynamicMaxOpenPositions(PMMaxOpenPositions) : PMMaxOpenPositions)

#define GP_EARLY_GATES_BLOCK \
  { \
    string __gp_reason; ulong __gp_t0; \
    __gp_t0=NowMs(); \
    bool __cb_ok = CircuitBreakerAllowed(__gp_reason); LogGate("cb", __cb_ok, "early", __gp_t0); if(!__cb_ok) return false; \
    __gp_t0=NowMs(); \
    bool __news_ok = NewsAllowed(__gp_reason); LogGate("news", __news_ok, "early", __gp_t0); if(!__news_ok) return false; \
    if(UseSessionManager && CheckPointer(g_session_manager)!=POINTER_INVALID) \
      { \
        __gp_t0=NowMs(); \
        bool __sess_ok = (*g_session_manager).IsSessionAllowed(__gp_reason); LogGate("session", __sess_ok, "early", __gp_t0); if(!__sess_ok) return false; \
      } \
    if(UseCorrelationManager && CheckPointer(g_correlation_manager)!=POINTER_INVALID) \
      { \
        double __max_corr; \
        __gp_t0=NowMs(); \
        bool __corr_ok = (*g_correlation_manager).CheckCorrelationLimits(__gp_reason, __max_corr); LogGate("corr", __corr_ok, "early", __gp_t0); if(!__corr_ok) return false; \
      } \
    return true; \
  }

#define GP_RISK4_GATES_BLOCK                  \
  {                                           \
    string __gp_reason; ulong __gp_t0;        \
    __gp_t0=NowMs();                          \
    bool __cb_ok = CircuitBreakerAllowed(__gp_reason); LogGate("risk4_cb", __cb_ok, "risk4", __gp_t0); if(!__cb_ok) return false; \
    if(UsePositionManager && CheckPointer(g_position_manager)!=POINTER_INVALID) \
      {                                       \
        int __open_positions = PositionsTotal(); \
        int __pm_cap = GP_GET_PM_CAP(); \
        if(TelemetryEnabled && CheckPointer(g_tel_standard)!=POINTER_INVALID) \
          { \
            string __pm_det = StringFormat("open=%d cap=%d", __open_positions, __pm_cap); \
            (*g_tel_standard).LogGateParams(_Symbol, (int)_Period, "pm", __pm_det); \
          } \
        bool __pm_ok = (__pm_cap<=0 ? true : (__open_positions < __pm_cap)); \
        __gp_t0=NowMs(); LogGate("pm", __pm_ok, "risk4", __gp_t0); if(!__pm_ok) return false; \
      }                                       \
    return true;                              \
  }

#endif // __GATINGPIPELINE_FIXED_MQH__
