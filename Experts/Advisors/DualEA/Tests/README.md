# DualEA Comprehensive Test Suite

## Overview
This suite covers unit, integration, and system-level tests for all major modules of the DualEA architecture, ensuring every feature works both independently and together. All tests are implemented as MQL5 scripts in the `Tests/` directory and can be run from MetaEditor or via batch.

## Test Coverage Matrix

| Module/Class         | Unit Test                | Integration Test      | System Test            |
|--------------------- |-------------------------|----------------------|------------------------|
| StrategySelector     | Test_StrategySelector    | Test_Integration     | Test_System            |
| SessionManager       | Test_SessionManager      | Test_Integration     | Test_System            |
| CorrelationManager   | Test_CorrelationManager  | Test_Integration     | Test_System            |
| VolatilitySizer      | Test_VolatilitySizer     | Test_Integration     | Test_System            |
| GateManager         | Test_GateManager         | Test_Integration     | Test_System            |
| PolicyEngine         | (in Test_System)         | (in Test_System)     | Test_System            |
| LearningBridge       | (in Test_System)         | (in Test_System)     | Test_System            |
| CFeaturesKB          | (in Test_System)         | (in Test_System)     | Test_System            |
| KnowledgeBase        | (in Test_System)         | (in Test_System)     | Test_System            |

## How to Run
1. Open MetaEditor.
2. Open any test script in `Tests/` (e.g., `Test_StrategySelector.mq5`).
3. Press F5 to run. Output will be in the MetaTrader log.
4. For full system validation, run `Test_System.mq5`.

## Expected Output
- Each test prints PASS/FAIL for every feature and scenario.
- System/integration tests print info about cross-feature behavior, logs, and file output (CSV, etc).
- All failures are explicit in the log.

## Extending the Suite
- For new features/modules, create `Test_<Feature>.mq5` in `Tests/`.
- Add the new test to the coverage matrix above.
- Use the same pattern: setup, simulate, assert, log.

## Edge Cases & Fault Injection
- Integration and system tests simulate pointer faults, file I/O errors, and invalid configs.
- All modules are tested for error handling as well as normal operation.

## CI/CD (Recommended)
- Add a batch script to run all tests nightly and parse logs for failures.
- Export coverage results for dashboard display.

---

_Last updated: 2025-09-25_
