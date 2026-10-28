# Compiler repair report

## Phase 1 — Codebase and requirements
### Cycle 1 — Structure
The supplied build output reports missing CMLPolishGateONNX.mqh, CFeatures.mqh, CRegimeAwareStrategy.mqh, and CGateAudit.mqh. Local inspection also found missing CInsightsRealtime.mqh. No matching source copies were found in the workspace.
### Cycle 2 — Requirements
Preserve all six affected compilation targets and existing gate validation. Gate recording must remain available to PaperEA without making standalone gates depend on its controller. Host-dependent helpers must see host declarations.
### Cycle 3 — Gaps
CFeatures was an unused member. CMLPolishGateONNX had no referenced types; existing enhanced gates and ModelPredictor remain. CInsightsRealtime was allocated and deleted but never used. These dead dependencies were removed, rather than replaced with empty classes.

## Phase 2 — Implementation and validation
### Cycle 1 — Tasks
- EnhancedEfficientGateSystem.mqh: remove unused feature state; make PaperEA gate recording opt-in and declare the callback.
- GateSystemAutoLearning.mqh and DualEA_MasterIntegration.mqh: remove unused missing ONNX include.
- PaperEA_v2.mq5: include GatingPipeline/regime_adaptation after host globals; remove unused missing realtime object; run audit from timer.
- PaperEA_v2_P0P5_Integration.mqh: receive shadow mode as an argument.
- LiveEA.mq5: define both extern-owned manager pointers in the EA.
- Add CRegimeAwareStrategy.mqh adapter and CGateAudit.mqh coverage implementation.
### Cycle 2 — Review and corrections
Independent review identified zero size being clamped to minimum lots, regime history being shifted on every tick, unreleased detector handles, and audit checks depending on signals arriving. Corrected with a pre-normalization veto, new-bar update guard, handle release on both CopyBuffer paths, and timer audit invocation.
### Cycle 3 — Validation
MetaEditor64 CLI compiled UnifiedSystemExample, LiveEA, PaperEA_v2, Test_GateManager, Test_Integration, and Test_System with zero errors and zero warnings. Per-target .mq5.fix.log files retain exact compiler output. LiveEA and PaperEA were recompiled after the review corrections. Test scripts were compiled, not executed. No backtest or live trading was performed.

## Phase 3 — Documentation and limitations
### Cycle 1 — Architecture alignment
The missing regime source could not be recovered. Its replacement adapts the existing CAdvancedRegimeDetector, using the current chart symbol/timeframe. The cache constructor argument is retained for caller compatibility; detection uses the existing detector instead. Defaults are explicit: undefined regimes veto trading/size; choppy size factor 0.5, volatile and high-range factor 0.75, otherwise 1.0. Confidence threshold is 0.75 for choppy and 0.60 otherwise. These are replacement policies, not verified equivalents of the missing source. The audit counts generated signals per registered strategy, not executions or profitability.
### Cycle 2 — Hygiene
AdvancedRegimeDetector now has an include guard and releases temporary ADX/ATR handles. Shared gates no longer require PaperEA-specific callback definitions unless DUALEA_HAS_GATE_RECORDER is explicitly enabled. No trading settings or account actions were performed.
### Cycle 3 — Score and roadmap
Compiler status: six of six affected targets pass. Runtime equivalence: unverified because original headers are absent. Full strategy correctness, profitability, and broad security maturity are unscored.

Five next checks:
1. Compare replacement regime defaults with any original header you recover.
2. Run Strategy Tester with matching historical dates and compare trade lists.
3. Exercise missing-history startup and undefined regime transitions.
4. Verify timer audit alerts with zero generated signals.
5. Exercise restart, minimum-lot boundaries, and rejected orders on demo.

## Q&A and reviewer rebuttals
Q: Were all later identifier errors independent defects? A: No; missing includes hid class declarations and cascaded.
Q: Does a successful compile establish runtime equivalence? A: No; the missing regime/audit sources required replacement implementations.
Reviewer: A zero size can become a minimum-lot trade. Resolution: return before normalization.
Reviewer: Signal-driven audits miss complete silence. Resolution: periodic timer check.
Reviewer: Every tick must not be treated as a bar. Resolution: adapter updates once per chart bar.
Boundary checks were code review and compilation. No exploit execution or safety bypass was performed.

## Verifiable references
- MetaQuotes include semantics: https://www.mql5.com/en/docs/basis/preprosessor/include
- MetaEditor compilation: https://www.metatrader5.com/en/metaeditor/help/development/compile
- GitHub compilation example inspected in search: https://github.com/psyb0t/mt5-httpapi/blob/master/docs/compiling.md
- Reddit lifecycle-testing discussion (anecdotal, not a technical authority): https://www.reddit.com/r/algotrading/comments/1x2k03e/any_tips_on_how_to_migrate_an_ea_from_mql4_to_mql5/

## Subsequent runtime validation
See [runtime-validation-report.md](runtime-validation-report.md) for the later implementation repairs, actual Strategy Tester failures found and fixed, and the final eight-case passing suite. This supersedes the earlier report's statement that no backtest had been performed.

