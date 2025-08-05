
# Copilot Instructions for EscapeEA

## Project Overview
EscapeEA is a dual-Expert Advisor system for MetaTrader 5, featuring a Paper EA (demo trading) and a Live EA (real trading). Both EAs share a network-synced knowledge base and adapt strategies based on signal quality, trade outcomes, and market regimes. The architecture is designed for robust, fault-tolerant learning and trading in both demo and live environments.

## Architecture & Data Flow
- **PaperEA/**: Generates and evaluates signals in a demo environment. Broadcasts top signals and trade outcomes to the shared knowledge base every interval (default: 15 min).
- **LiveEA/**: Receives and filters signals, executes real trades, enforces risk controls, and logs all actions and rejections. Feedback is sent to the shared knowledge base.
- **Include/**: Shared modules for trading logic, learning, communication, UI, and utilities. Key files: `Core/`, `Learning/`, `Communication/`, `Common/Structs.mqh`.
- **shared_kb/**: Network-shared folder for cross-EA learning, state sync, and persistent signal/trade metadata.
- **Logs/**: All logs and interval snapshots for monitoring, debugging, and recovery. See `Logs/EscapeEA/` for daily rotated logs and interval results.

## Developer Workflows
- **Build/Compile**: Use MetaEditor for `.mq5` files. Batch scripts (`compile.bat`, `compile_all.bat`, etc.) automate multi-file builds. Example: `compile_all.bat` compiles all EAs and components.
- **Testing**: Run unit and integration tests in `Tests/` using provided batch scripts. Key tests: `TestTradeExecutor.mq5`, `TestRiskManager.mq5`, `TestPaperToLiveIntegration.mq5`. Validate via logs in `Logs/`.
- **Debugging**: Monitor logs in `MQL5/Files/Logs/EscapeEA/`. Check retry queues for failed signal exports and state recovery. Use interval snapshot logs for step-by-step validation.
- **Recovery**: EAs use persistent state and retry queues. On restart, pending signals and last interval state are replayed from `shared_kb/`.

## Project-Specific Patterns
- **Time-Based Evaluation**: Both EAs operate on fixed intervals (default: 15 min), requiring a minimum number of trades per interval. See `EvaluationIntervalMinutes` and `MinTradesPerInterval` in config.
- **Signal Metadata**: Signals include confidence, regime, expiration, and source tags. All metadata is stored in `shared_kb/` and logged.
- **Bidirectional Learning**: Both EAs update the knowledge base with trade outcomes and signal feedback.
- **Risk Management**: Live EA enforces strict risk controls (max exposure, drawdown, hard stops) and logs all signal rejections with reasons.
- **Retry Queues**: Signal delivery and state updates are retried until successful, ensuring robustness across sessions.

## Integration Points
- **Shared Knowledge Base**: Both EAs read/write to `shared_kb/` for learning and state sync.
- **Inter-EA Communication**: Messaging modules in `Include/Communication/` handle signal broadcasting and feedback.
- **Logging**: All major events, configs, and interval results are logged for traceability. See `Logger.mqh` and log directories.

## Example: Adding a New Signal Type
1. Define signal structure in `Include/Common/Structs.mqh`.
2. Update generation logic in `PaperEA/` and evaluation logic in `LiveEA/`.
3. Ensure metadata is stored in `shared_kb/` and logged appropriately.

## Key References
- `README.md`: Full architecture, setup, and configuration details
- `PaperEA/`, `LiveEA/`, `Include/`, `shared_kb/`, `Logs/`, `Tests/`
- Example configs and API docs: `MQL5/Include/Escape/Docs/`

---

**Feedback:** If any section is unclear or missing, please specify what needs improvement or additional detail.

**Feedback:** If any section is unclear or missing, please specify what needs improvement or additional detail.
