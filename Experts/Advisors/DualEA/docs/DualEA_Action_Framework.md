# DualEA Action Framework

## 3 Phases × 3 Cycles = 9 Iterative Layers

This framework operationalizes the red-team engineering process for the DualEA trading system.

---

## Phase 1: Codebase & Requirements Deep Dive

### Cycle 1: Structural Audit (Jailbreak Permitted)

**Purpose**: Full inspection of architecture, files, and components. Challenge structure, spot contradictions, uncover fragility.

**Deliverables**:
- Inventory gating paths: `strategy → selector → policy → insights → execution`
- Trace file I/O and timers: `CheckPolicyReload()`, `CheckInsightsReload()`, staleness checks
- Identify insertion points: circuit breakers, session/news filters, PositionManager, correlation, vol sizing, regime
- Audit map + risk log

**Key Questions**:
1. Does every strategy have a registered signal generator?
2. Are all file I/O operations non-blocking in `OnTick()`?
3. Is there a single source of truth for configuration?
4. Are risk gates (G1, G4, G7, G8) truly never skipped?

**Jailbreak Traces**:
- Challenge: "What if `insights.json` is corrupted mid-read?"
- Challenge: "What if `policy.json` is updated during execution?"
- Challenge: "What if two EAs write to `knowledge_base.csv` simultaneously?"

### Cycle 2: Requirements Mapping

**Purpose**: Trace every requirement to real code. Flag mismatches, absences, or unnecessary constraints.

**Deliverables**:
- Spec one-pagers per feature with inputs, data flow, telemetry, failure/rollback
- FR-01..FR-10 feature specification matrix
- Gap analysis: documented vs implemented

**Feature Specification Template**:
```
FR-XX: Feature Name
- Inputs: [list with types/defaults]
- Data Flow: [diagram or path]
- Telemetry: [event keys, severity]
- Failure Mode: [what happens on error]
- Rollback: [how to disable/revert]
- Acceptance: [test criteria]
```

### Cycle 3: Risk & Gaps Closure

**Purpose**: Uncover technical debt, overlaps, or unsafe abstractions. Redesign modules based on jailbreak findings.

**Deliverables**:
- Threat model: file races, stale artifacts, partial reloads
- Mitigations + rollback levers
- Updated lifecycle gates

**Known Risks**:
| Risk | Impact | Mitigation |
|------|--------|------------|
| Stale `insights.json` | Wrong gating decisions | Auto-reload with freshness check |
| Corrupt `policy.json` | Crash or wrong scaling | JSON validation + fallback |
| File lock on CSV | Write failure | FILE_SHARE_READ/WRITE |
| Memory leak | EA slowdown/crash | Destructor audit, smart pointers |
| Race condition | Duplicate trades | Per-minute de-duplication |

---

## Phase 2: Design, Build, Validate

### Cycle 1: Task Decomposition

**Purpose**: Translate all findings and objectives into granular engineering tasks.

**Deliverables**:
- Backlog with effort/risk/owner/sequence for FR-01..FR-10
- Definition of Ready checklist for each feature

**Acceptance Criteria**:
- [ ] Inputs defined with types, defaults, validation
- [ ] Data flow documented with telemetry points
- [ ] Failure modes identified with rollback behavior
- [ ] Test plan with deterministic validation

### Cycle 2: Code + Peer Review

**Purpose**: Implement fixes and improvements. Subject code to red team reviews and adversarial edge-case attacks.

**Review Checklist**:
- [ ] Feature flags (`Use*`) present and functional
- [ ] Shared includes under `Include/` (no duplication)
- [ ] Telemetry events match schema
- [ ] Memory management (no leaks, proper destructors)
- [ ] Error handling (graceful degradation)

**Peer Review Questions**:
1. "Can this be disabled without breaking other systems?"
2. "What happens if this file is missing/corrupt/locked?"
3. "Is this I/O on timer or tick? Should it be?"
4. "Does this respect CPU budgeting (P3)?"

### Cycle 3: QA + Fuzzing

**Purpose**: Extend test coverage, apply fuzzing, and simulate attack paths.

**Test Types**:
- Unit-like stubs for gate logic
- Deterministic sims for file I/O
- Log assertions for telemetry
- Fuzz: missing files, reload storms, high-tick

**Fuzz Scenarios**:
```python
# Example fuzz test patterns
fuzz_cases = [
    ("empty_policy_json", ""),
    ("truncated_insights", '{"version": "2.0",'),  # incomplete
    ("locked_knowledge_base", "FILE_LOCKED"),
    ("high_tick_rate", 1000),  # 1000 ticks/second
    ("stale_insights", "48_hours_old"),
    ("corrupt_csv", "malformed,row,here"),
]
```

---

## Phase 3: Polish, Lockdown, Final Scoring

### Cycle 1: Docs & Architecture Alignment

**Purpose**: Sync documentation with reality—including all discovered and undocumented logic.

**Deliverables**:
- README.md updated with current architecture
- KB-Schemas.md with all CSV formats
- PolicySchema.md with current JSON structure
- Operations.md with runbook procedures

**Documentation Checklist**:
- [ ] All inputs documented with defaults
- [ ] All telemetry events in schema
- [ ] File paths correct (Common Files)
- [ ] Build instructions tested
- [ ] Troubleshooting section covers known issues

### Cycle 2: Code Hygiene & Consistency

**Purpose**: Clean up the codebase: refactor names, eliminate dead weight, and harden modules against jailbreaks.

**Refactoring Targets**:
- Input naming consistency (`UseXxx` vs `EnableXxx`)
- Enum/log tag standardization
- Dead code elimination
- Include path cleanup

**Hardening Tasks**:
- Add `const` correctness where missing
- Validate all array bounds
- Replace magic numbers with constants
- Add assertions for invariants

### Cycle 3: Final Scoring + Roadmap

**Purpose**: Score components for completeness and quality. Debate priorities using insights from red-team cycles.

**Scoring Matrix**:
| Component | Completeness | Safety | Performance | Maintainability | Priority |
|-----------|-------------|--------|-------------|-----------------|----------|
| GateSystem | 90% | 85% | 80% | 75% | P1 |
| PolicyEngine | 85% | 80% | 85% | 70% | P2 |
| PositionManager | 75% | 70% | 75% | 65% | P3 |
| Telemetry | 80% | 90% | 85% | 80% | P1 |
| InsightsLoader | 85% | 85% | 80% | 75% | P2 |

**Roadmap to 100% Maturity**:
1. **Wave 1** (risk first): Circuit breakers, session filters, promotion gate
2. **Wave 2** (positioning): PositionManager, correlation caps, vol sizing
3. **Wave 3** (performance): Timer cadence, batching, caching
4. **Wave 4** (ML): Drift detection, A/B testing, auto-retrain

---

## Action Backlog (FR-01..FR-10)

### FR-01: Circuit Breakers
- **Inputs**: `UseCircuitBreakers`, `DailyLossLimit`, `DailyDrawdownLimit`, `CooldownMinutes`
- **Behavior**: Block entries, allow exits; cooldown after trigger
- **Telemetry**: `cb:*` events
- **DoD**: Day rollover sims pass

### FR-02: Session/Window Filter
- **Inputs**: `UseSessionFilter`, `SessionTZ`, `SessionWindows`
- **Behavior**: Pre-gate block outside trading hours
- **DoD**: DST/tz edge cases handled

### FR-03: News Filter
- **Inputs**: `UseNewsFilter`, `ImpactLevelMin`, `PreLockoutMin`, `PostLockoutMin`
- **Behavior**: Block around high-impact events
- **DoD**: Replay test with historical events

### FR-04: Position Manager (v1)
- **Inputs**: `UsePositionManager`, `ExitProfile`, `ClusterMinPts`, `PerSymbolMax`
- **Behavior**: Centralized exits/scaling hooks
- **DoD**: Backtest diffs acceptable

### FR-05: Correlation Exposure Caps
- **Inputs**: `UseCorrelationCaps`, `CorrLookbackDays`, `MaxGroupExposure`
- **Behavior**: Cap grouped exposure
- **DoD**: Deterministic calculation verified

### FR-06: Volatility Position Sizing
- **Inputs**: `UseVolSizing`, `ATRPeriod`, `RiskPerTrade`
- **Behavior**: ATR-adaptive lots
- **DoD**: Regime consistency, caps respected

### FR-07: Regime Detector Stub
- **Inputs**: `UseRegime`, `RegimeMethod`
- **Behavior**: Tag regime; optional gating modifier
- **DoD**: Stable tags across timeframes

### FR-08: Promotion Gate & Evaluator
- **Inputs**: Min trades/hit-rate/expectancy/DD/Sharpe thresholds
- **Artifact**: `Scripts/DualEA/AssessPromotion.mq5`
- **DoD**: Reproducible promotion decisions

### FR-09: Telemetry Standardization & Ops Views
- **Event Schema**: Standardized fields/severity
- **Rotation**: Size/time bounds
- **DoD**: Operator can diagnose from logs alone

### FR-10: Performance
- **Event Batching**: Reduce I/O pressure
- **Log Throttling**: Prevent spam
- **Timer Cadence**: Consistent scan intervals
- **DoD**: CPU/mem profile under stress

---

## Control Gates (Before Coding)

### Gate A: Specs Complete
- [ ] Inputs, flow, telemetry, rollback defined for FR-01..FR-10
- [ ] Security review complete
- [ ] Test plan approved

### Gate B: Test Plans Defined
- [ ] Unit stubs ready
- [ ] Deterministic sims configured
- [ ] Log assertions defined

### Gate C: Security + Fail-Safe Review
- [ ] LiveEA defaults conservative
- [ ] Rollback levers identified
- [ ] Circuit breakers in place

---

## Ownership & Sequencing

### Wave 1 (Risk First)
1. FR-01 Circuit Breakers
2. FR-02 Session Filter
3. FR-08 Promotion Gate

### Wave 2 (Exposure/Positioning)
4. FR-04 Position Manager
5. FR-05 Correlation Caps
6. FR-06 Volatility Sizing

### Wave 3 (Context/Performance)
7. FR-03 News Filter
8. FR-07 Regime Detector
9. FR-09 Telemetry
10. FR-10 Performance

**Note**: Features default-off in LiveEA until validated in PaperEA.

---

## Q&A Log Template

```markdown
## Q1: [Question]
- Context: [module(s)]
- Hypothesis: [expected behavior]
- Answer: [observed behavior]
- Evidence: [file refs, line ranges, logs]
- Outcome: pass | fail | needs-followup
```

## Rebuttal Template

```json
{
  "id": "rb_XXXX",
  "claim": "[red-team claim]",
  "rebuttal": "[concise counterargument]",
  "evidence_files": ["path/to/file.mqh"],
  "decision_paths": ["Gate->Insights->Execute"],
  "status": "open | resolved | needs-work",
  "timestamp": "2026-01-15T00:00:00Z"
}
```

## Jailbreak Trace Template

```json
{
  "ts": "2026-01-15T00:00:00Z",
  "module": "[component]",
  "file": "[path]",
  "symbol": "[symbol]",
  "timeframe": 60,
  "case": "[test case]",
  "mutation": "[input mutation]",
  "expected": "[expected behavior]",
  "observed": "[observed behavior]",
  "outcome": "safe | unsafe | inconclusive",
  "severity": "low | medium | high",
  "artifacts": ["related files"],
  "notes": "[free-form]"
}
```

---

## Related Documentation
- [README.md](README.md) - System overview
- [Phase3.md](Phase3.md) - LiveEA implementation
- [Operations.md](Operations.md) - Operational runbook
