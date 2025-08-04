# Copilot Instructions for EscapeEA

## Project Overview
EscapeEA is a dual-Expert Advisor system for MetaTrader 5, consisting of a Paper EA (demo trading) and a Live EA (real trading). Both EAs share a knowledge base and adapt strategies based on signal quality, trade outcomes, and market regimes.

## Architecture & Key Components
- **PaperEA/**: Demo trading logic, signal generation, and evaluation.
- **LiveEA/**: Real trading logic, risk management, and signal filtering.
- **Include/**: Shared modules for core logic, learning, communication, UI, and utilities.
- **shared_kb/**: Network-shared folder for cross-EA learning and state.
- **Logs/**: All logs and interval snapshots for monitoring and debugging.

## Developer Workflows
- **Build/Compile**: Use MetaEditor to compile `.mq5` files. Batch scripts (e.g., `compile.bat`, `compile_all.bat`) automate multi-file builds.
- **Testing**: Test EAs in MetaTrader 5 demo/live environments. Use log files in `Logs/` and interval snapshots for validation.
- **Debugging**: Monitor logs in `MQL5/Files/Logs/EscapeEA/` and check retry queues for failed signal exports.
- **Recovery**: EAs use persistent state and retry queues for fault tolerance. On restart, pending signals and last interval state are replayed.

## Project-Specific Patterns
- **Time-Based Evaluation**: Both EAs operate on fixed intervals (default: 15 min), requiring a minimum number of trades per interval.
- **Signal Metadata**: Signals include confidence, regime, expiration, and source tags. All metadata is stored in the shared knowledge base.
- **Bidirectional Learning**: Both EAs update the knowledge base with trade outcomes and signal feedback.
- **Risk Management**: Live EA enforces strict risk controls (max exposure, drawdown, hard stops) and logs all signal rejections with reasons.
- **Retry Queues**: Signal delivery and state updates are retried until successful, ensuring robustness across sessions.

## Integration Points
- **Shared Knowledge Base**: Both EAs read/write to `shared_kb/` for learning and state sync.
- **Inter-EA Communication**: Messaging modules in `Include/Communication/` handle signal broadcasting and feedback.
- **Logging**: All major events, configs, and interval results are logged for traceability.

## Example: Adding a New Signal Type
1. Define signal structure in `Include/Common/Structs.mqh`.
2. Update generation logic in `PaperEA/` and evaluation logic in `LiveEA/`.
3. Ensure metadata is stored in `shared_kb/` and logged appropriately.

## References
- See `README.md` for full architecture, setup, and configuration details.
- Key directories: `PaperEA/`, `LiveEA/`, `Include/`, `shared_kb/`, `Logs/`.

---

**Feedback:** If any section is unclear or missing, please specify what needs improvement or additional detail.
