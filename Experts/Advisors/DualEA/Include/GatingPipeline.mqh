// include guard for MQL5
#ifndef __GATINGPIPELINE_MQH__
#define __GATINGPIPELINE_MQH__

//+------------------------------------------------------------------+
//| GatingPipeline.mqh                                              |
//| Purpose: Centralize gate orchestration (macro-based)             |
//| Status: Used by EAs via macros; preserves existing behavior      |
//+------------------------------------------------------------------+

// These macros expand inline inside the EA translation unit and call the
// EA-local functions/variables (e.g., NewsAllowed, LogGate, g_session_manager).
// This avoids forward-declaration issues and preserves existing telemetry tags.

// Helper: compute dynamic PM cap if PositionManager is available; otherwise use static input
int GP_GetPMCap()
  {
   // PMMaxOpenPositions semantics: 0 = disabled/unlimited
   int cap = PMMaxOpenPositions;
   // When a PositionManager is present, allow it to adjust the cap adaptively
   if(UsePositionManager && CheckPointer(g_position_manager)!=POINTER_INVALID)
     {
      // ComputeDynamicMaxOpenPositions() returns a possibly adjusted cap; values <=0 mean 'unlimited'
      int dyn = (*g_position_manager).ComputeDynamicMaxOpenPositions(cap);
      // Only adopt positive values; otherwise keep existing semantics
      if(dyn!=cap) cap = dyn;
     }
   return cap;
  }

#define GP_EARLY_GATES_BLOCK \
  { \
    string __gp_reason; ulong __gp_t0; \
    __gp_t0=NowMs(); \
    bool __cb_ok = CircuitBreakerAllowed(__gp_reason); LogGate("cb", __cb_ok, "early", __gp_t0); if(!__cb_ok) return false; \
    __gp_t0=NowMs(); \
    bool __news_ok = NewsAllowed(__gp_reason); LogGate("news", __news_ok, "early", __gp_t0); if(!__news_ok) return false; \
    __gp_t0=NowMs(); \
    bool __promo_ok= PromotionAllowed(__gp_reason); LogGate("promotion", __promo_ok, "early", __gp_t0); if(!__promo_ok) return false; \
    __gp_t0=NowMs(); \
    bool __reg_ok  = RegimeAllowed(__gp_reason); LogGate("regime", __reg_ok, "early", __gp_t0); if(!__reg_ok) return false; \
    bool __circ_ok = CircuitCooldownAllowed(__gp_reason); LogGate("circuit_cooldown", __circ_ok, "early", __gp_t0); if(!__circ_ok) return false; \
    /* FR-02 Session gate */ \
    if(UseSessionManager && CheckPointer(g_session_manager)!=POINTER_INVALID) \
      { \
        __gp_t0=NowMs(); \
        bool __sess_ok = g_session_manager.IsSessionAllowed(__gp_reason); LogGate("session", __sess_ok, "early", __gp_t0); if(!__sess_ok) return false; \
      } \
    /* FR-05 Correlation gate */ \
    if(UseCorrelationManager && CheckPointer(g_correlation_manager)!=POINTER_INVALID) \
      { \
        double __max_corr; \
        __gp_t0=NowMs(); \
        bool __corr_ok = g_correlation_manager.CheckCorrelationLimits(__gp_reason, __max_corr); LogGate("corr", __corr_ok, "early", __gp_t0); if(!__corr_ok) return false; \
      } \
    return true; \
  }
  
  // include guard end is at file bottom

  #define GP_RISK4_GATES_BLOCK                  \
  {                                           \
    string __gp_reason; ulong __gp_t0;        \
    __gp_t0=NowMs();                          \
    bool __cb_ok = CircuitBreakerAllowed(__gp_reason); LogGate("risk4_cb", __cb_ok, "risk4", __gp_t0); if(!__cb_ok) return false; \
    __gp_t0=NowMs();                          \
    bool __news_ok = NewsAllowed(__gp_reason);    LogGate("news",   __news_ok, "risk4", __gp_t0); if(!__news_ok) return false; \
    __gp_t0=NowMs();                          \
    bool __promo_ok= PromotionAllowed(__gp_reason);LogGate("promotion",  __promo_ok,"risk4", __gp_t0); if(!__promo_ok) return false; \
    __gp_t0=NowMs();                          \
    bool __reg_ok  = RegimeAllowed(__gp_reason);  LogGate("regime", __reg_ok,  "risk4", __gp_t0); if(!__reg_ok) return false; \
    __gp_t0=NowMs();                          \
    bool __circ_ok = CircuitCooldownAllowed(__gp_reason); LogGate("circuit_cooldown", __circ_ok, "risk4", __gp_t0); if(!__circ_ok) return false; \
    /* FR-02 Session gate */                  \
    if(UseSessionManager && CheckPointer(g_session_manager)!=POINTER_INVALID) \
      {                                       \
        __gp_t0=NowMs();                      \
        bool __sess_ok = g_session_manager.IsSessionAllowed(__gp_reason); LogGate("session", __sess_ok, "risk4", __gp_t0); if(!__sess_ok) return false; \
      }                                       \
    /* FR-05 Correlation gate */              \
    if(UseCorrelationManager && CheckPointer(g_correlation_manager)!=POINTER_INVALID) \
      {                                       \
        double __max_corr;                    \
        __gp_t0=NowMs();                      \
        bool __corr_ok = g_correlation_manager.CheckCorrelationLimits(__gp_reason, __max_corr); LogGate("corr", __corr_ok, "risk4", __gp_t0); if(!__corr_ok) return false; \
      }                                       \
    /* FR-04 Position Manager gate */         \
    if(UsePositionManager && CheckPointer(g_position_manager)!=POINTER_INVALID) \
      {                                       \
        int __open_positions = PositionsTotal(); \
        int __pm_cap = GP_GetPMCap(); \
        /* Telemetry for PM gate params */ \
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
 
#endif // __GATINGPIPELINE_MQH__

// Variants for LiveEA semantics (no CB in early; early uses NoConstraintsMode to shadow-bypass blocks)
#define GP_EARLY_GATES_BLOCK_NO_CB_SHADOW      \
  {                                           \
    string __gp_reason; ulong __gp_t0;        \
    __gp_t0=NowMs();                          \
    bool __news_ok = NewsAllowed(__gp_reason);    LogGate("news",   __news_ok, "early", __gp_t0); if(!__news_ok && !NoConstraintsMode) return false; \
    __gp_t0=NowMs();                          \
    bool __promo_ok= PromotionAllowed(__gp_reason);LogGate("promotion",  __promo_ok,"early", __gp_t0); if(!__promo_ok && !NoConstraintsMode) return false; \
    __gp_t0=NowMs();                          \
    bool __reg_ok  = RegimeAllowed(__gp_reason);  LogGate("regime", __reg_ok,  "early", __gp_t0); if(!__reg_ok && !NoConstraintsMode) return false; \
    __gp_t0=NowMs();                          \
    bool __circ_ok = CircuitCooldownAllowed(__gp_reason); LogGate("circuit_cooldown", __circ_ok, "early", __gp_t0); /* early only logs circ in Live; honor NoConstraints */ if(!__circ_ok && !NoConstraintsMode) return false; \
    /* FR-02 Session gate (diagnostic unless constraints enabled) */ \
    if(UseSessionManager && CheckPointer(g_session_manager)!=POINTER_INVALID) \
      {                                       \
        __gp_t0=NowMs();                      \
        bool __sess_ok = g_session_manager.IsSessionAllowed(__gp_reason); LogGate("session", __sess_ok, "early", __gp_t0); if(!__sess_ok && !NoConstraintsMode) return false; \
      }                                       \
    /* FR-05 Correlation gate */              \
    if(UseCorrelationManager && CheckPointer(g_correlation_manager)!=POINTER_INVALID) \
      {                                       \
        double __max_corr;                    \
        __gp_t0=NowMs();                      \
        bool __corr_ok = g_correlation_manager.CheckCorrelationLimits(__gp_reason, __max_corr); LogGate("corr", __corr_ok, "early", __gp_t0); if(!__corr_ok && !NoConstraintsMode) return false; \
      }                                       \
    return true;                              \
  }

// Variant for LiveEA risk4 (no CB; strict fail-closed)
  #define GP_RISK4_GATES_BLOCK_NO_CB             \
    {                                           \
      string __gp_reason; ulong __gp_t0;        \
      __gp_t0=NowMs();                          \
      bool __news_ok = NewsAllowed(__gp_reason);    LogGate("news",   __news_ok, "risk4", __gp_t0); if(!__news_ok) return false; \
    __gp_t0=NowMs();                          \
    bool __promo_ok= PromotionAllowed(__gp_reason);LogGate("promotion",  __promo_ok,"risk4", __gp_t0); if(!__promo_ok) return false; \
    __gp_t0=NowMs();                          \
    bool __reg_ok  = RegimeAllowed(__gp_reason);  LogGate("regime", __reg_ok,  "risk4", __gp_t0); if(!__reg_ok) return false; \
    __gp_t0=NowMs();                          \
    bool __circ_ok = CircuitCooldownAllowed(__gp_reason); LogGate("circuit_cooldown", __circ_ok, "risk4", __gp_t0); if(!__circ_ok) return false; \
    if(UseSessionManager && CheckPointer(g_session_manager)!=POINTER_INVALID) \
      {                                       \
        __gp_t0=NowMs();                      \
        bool __sess_ok = g_session_manager.IsSessionAllowed(__gp_reason); LogGate("session", __sess_ok, "risk4", __gp_t0); if(!__sess_ok) return false; \
      }                                       \
    if(UseCorrelationManager && CheckPointer(g_correlation_manager)!=POINTER_INVALID) \
      {                                       \
        double __max_corr;                    \
        __gp_t0=NowMs();                      \
        bool __corr_ok = g_correlation_manager.CheckCorrelationLimits(__gp_reason, __max_corr); LogGate("corr", __corr_ok, "risk4", __gp_t0); if(!__corr_ok) return false; \
      }                                       \
    if(UsePositionManager && CheckPointer(g_position_manager)!=POINTER_INVALID) \
      {                                       \
        int __open_positions = PositionsTotal(); \
        int __pm_cap = GP_GetPMCap(); \
        bool __pm_ok = (__pm_cap<=0 ? true : (__open_positions < __pm_cap)); \
        __gp_t0=NowMs(); LogGate("pm", __pm_ok, "risk4", __gp_t0); if(!__pm_ok) return false; \
      }                                       \
    return true;                              \
  }
