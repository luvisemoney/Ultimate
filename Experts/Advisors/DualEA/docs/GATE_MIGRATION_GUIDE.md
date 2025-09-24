# Gate System Migration Guide

## Current State Analysis

### Legacy Gate System (`PaperEA.mq5`)
Uses `GatingPipeline.mqh` with these gates:
- Circuit breaker gates
- News filtering gates  
- Promotion gates
- Regime gates
- Position manager gates
- Correlation gates

### New 8-Stage Gate System (`PaperEA_v2.mq5`)
Uses `GateManager.mqh` with these gates:
1. Signal Rinse (pre-filter)
2. Market Soap (market context)
3. Strategy Scrub (strategy validation)
4. Risk Wash (risk assessment)
5. Performance Wax (historical validation)
6. ML Polish (ML model review)
7. Live Clean (real-time checks)
8. Final Verify (pre-execution)

## Migration Strategy

### Phase 1: Parallel Testing (Current)
- Keep `PaperEA.mq5` running as production
- Run `PaperEA_v2.mq5` in parallel for testing
- Compare gate decisions and performance

### Phase 2: Gradual Integration
- Implement gates 4-7 (Risk Wash through Final Verify)
- Add ML integration for gates 5-6
- Test paper-to-live signal pipeline

### Phase 3: Full Migration
- Replace `PaperEA.mq5` with `PaperEA_v2.mq5`
- Implement `LiveEA_v2.mq5` with enhanced gates
- Activate bidirectional learning

## Gate Mapping

| Legacy Gate | New Gate Equivalent | Migration Notes |
|-------------|---------------------|-----------------|
| CircuitBreakerAllowed() | Signal Rinse + Live Clean | Enhanced with market conditions |
| NewsAllowed() | Market Soap | Integrated with regime detection |
| PromotionAllowed() | Strategy Scrub | Strategy-specific validation |
| RegimeAllowed() | Market Soap | Enhanced regime detection |
| PositionManager | Risk Wash + Final Verify | Enhanced position sizing |
| CorrelationManager | Market Soap | Multi-pair correlation |

## Implementation Checklist

### Paper EA Migration
- [ ] Test Signal Rinse gate
- [ ] Test Market Soap gate  
- [ ] Test Strategy Scrub gate
- [ ] Implement Risk Wash gate
- [ ] Implement Performance Wax gate
- [ ] Implement ML Polish gate
- [ ] Implement Live Clean gate
- [ ] Implement Final Verify gate

### Live EA Migration
- [ ] Create LiveEA_v2.mq5
- [ ] Implement stricter gate thresholds
- [ ] Add paper trade review system
- [ ] Test signal transfer pipeline

### Data Pipeline
- [ ] Set up learning data directories
- [ ] Configure signal transfer timing
- [ ] Test bidirectional feedback loop
- [ ] Implement performance monitoring
