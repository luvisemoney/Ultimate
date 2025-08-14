# CascadeGreepEA (MT5) — FX Majors & Gold

Educational, not financial advice. This EA implements ATR-based risk management with simple RSI mean-reversion plus optional trend filter. It enforces max open positions across the account and a kill-switch at a configured drawdown.

## Features
- ATR-based stop; optional ATR trailing stop and ATR take profit.
- Risk-based position sizing by percent of equity (default 1%).
- Max open positions cap (default 5) across the account.
- Kill-switch: stop trading (and optionally close EA positions) if equity drawdown from start hits threshold (default 2%).
- Signals: RSI(2) extremes on M15 with optional 200 SMA trend filter.
 - Optional Master EA: dynamic auto-adjust on News, Volatility (ATR regime), and Equity regime (no blocking; scales risk/SL/cooldown instead).

## Hard Constraints & Red-Team Notes
- With $25 equity and 2% risk cap, intended per-trade risk is ~$0.50. On most brokers the minimum lot is 0.01, which risks about $1.00 per 10 pips on EURUSD, often exceeding the 2% limit for typical ATR stops. The EA will skip trades if computed size is below min lot unless you set `InpAllowTradeIfBelowMinLot = true`. This EA enables it by default but caps effective risk when forcing min lot (see Execution Safety).
- Achieving +$1,000 in 30 days from $25 with 2% max drawdown is effectively infeasible. Expect skipped trades or constraint violations without a cent account (or 0.001 lot broker) and/or more capital/time/risk.
- "No commission/slippage" is not realistic. Spreads still apply, and slippage can occur.

## Installation (MT5)
1. Open MetaTrader 5 → File → Open Data Folder.
2. Navigate to `MQL5/Experts/` and create a folder `CascadeGreepEA/` (optional).
3. Copy `CascadeGreepEA.mq5` into `MQL5/Experts/CascadeGreepEA/`.
4. Open MetaEditor, compile `CascadeGreepEA.mq5` (F7). Fix any broker-specific warnings if shown.
5. In MT5, enable AutoTrading (Ctrl+E) and allow algo trading in Tools → Options → Expert Advisors.
6. Attach the EA to charts for your chosen instruments (EURUSD, AUDUSD, USDCAD, USDJPY, XAUUSD; verify symbol suffixes). One chart per instrument.

## Recommended Inputs
- Risk Management
  - `InpRiskPercent`: 1.0–2.0
  - `InpKillSwitchDDPercent`: 2.0
  - `InpMaxOpenPositions`: 5
  - `InpAllowTradeIfBelowMinLot`: true (enabled by default; guarded by caps below)
  - `InpCloseOnKillSwitch`: true
- Signals
  - `InpSignalTF`: M15 (tunable)
  - `InpSMAPeriod`: 200, `InpUseTrendFilter`: true
  - `InpRSIPeriod`: 2, `InpRSILow`: 5, `InpRSIHigh`: 95
- Stops/Targets
  - `InpATRPeriod`: 14
  - `InpATRMultiplierSL`: 2.0
  - `InpUseTrailing`: true, `InpTrailATRMultiplier`: 1.0
  - `InpTP_ATR_Mult`: 0.0 (disabled) or 2.0–3.0

## Execution Safety Inputs (tune per broker/symbol)
- `InpMaxSpreadPoints`: 15–25 for EURUSD-type majors; 30–80 for XAUUSD (points depend on broker digits).
- `InpMaxATRPoints`: 0 to disable; else cap extreme volatility days (e.g., 300–800 for majors; higher for XAUUSD per broker digits).
- `InpDailyLossLimitPercent`: 2.0 (matches your max-DD tolerance); `InpCloseOnDailyLoss`: true.
- `InpMinBarsBetweenTrades`: 3–5 to reduce clustering/overtrading per symbol/TF.
- `InpMaxRiskPctWhenForcingMinLot`: 2.0 recommended (non-XAU); `InpMaxRiskPctWhenForcingMinLot_XAU`: 1.0 recommended. If min-lot risk exceeds cap, EA skips the trade.

### Master Adjustments (Worker EA)
- `InpUseMasterAdjust` (bool): if true, the EA reads dynamic factors published by the Master EA via terminal Global Variables.
- `InpGVNamespaceEA` (string): namespace prefix to read from (default `CGreep`). Must match the Master EA.
- Auto-adjust behavior (no blocking):
  - Risk percent is scaled by `risk_mult` (0.2–1.0 typical). Only scales down, never up beyond your `InpRiskPercent`.
  - Stop/take-profit and trailing ATR distances are multiplied by `sl_mult` (wider under stress).
  - Cooldown bars are multiplied by `cooldown_mult` (longer under stress).
  - Min-lot risk cap is tightened proportionally to `risk_mult` (cap is never loosened).

## How it trades
- On new bar of `InpSignalTF`, if no position is open for the chart symbol and total open positions < cap:
  - Long: RSI <= `InpRSILow` and price above SMA(200) if trend filter on.
  - Short: RSI >= `InpRSIHigh` and price below SMA(200) if trend filter on.
- SL set to ATR * `InpATRMultiplierSL` from entry.
- Position size chosen so SL loss ≈ `InpRiskPercent` of equity, respecting broker min lot and lot step.
- Trailing stop moves by `InpTrailATRMultiplier` ATR behind price.

## Multi-Symbol & Timeframes Setup
- Attach the EA to one chart per symbol you want to trade and set `InpSignalTF` to M15, M30, H1, or D1 as desired.
- The EA enforces one open position per symbol across the account; attaching multiple timeframes for the same symbol will not stack exposures.
- For unified risk control across all instances, set the same `InpMagic` on every chart so daily-loss/kill-switch closures act on all EA trades.

## Master EA (Optional) — News/Volatility/Equity Auto-Adjust
File: `CascadeGreepMasterEA.mq5`

Run this EA on a single chart to compute regime-aware adjustments per symbol and publish them as Global Variables. The worker EA (`CascadeGreepEA.mq5`) reads and applies them without blocking trades.

### How it works
- News factor: uses MT5 Economic Calendar to derive a risk multiplier around upcoming/just occurred events for the symbol currencies (e.g., `EURUSD` → EUR and USD). Near high-impact events, `risk_mult` slides toward `InpNewsWeightHigh` (e.g., 0.30). Outside news windows, factor is 1.0.
- Volatility factor: compares current ATR to an H1 ATR average and reduces risk under elevated volatility. Optionally allows slight upsize in very low volatility if desired (off by default).
- Equity factor: reduces risk after daily soft drawdown; optionally allows a tiny boost after daily profit (off by default).
- Composition: final `risk_mult = min(news, vol, equity)`, then derives `sl_mult` and `cooldown_mult` from `(1 - risk_mult)`.

### Master EA Inputs (key)
- `InpSymbols`: semicolon-separated list (e.g., `EURUSD;AUDUSD;USDCAD;USDJPY;XAUUSD`).
- `InpGVNamespace`: must match worker `InpGVNamespaceEA` (default `CGreep`).
- `InpUpdateSeconds`: publish cadence.
- News: `InpNewsWindowBeforeMin`, `InpNewsWindowAfterMin`, weights for low/medium/high.
- Volatility: `InpVolTF`, `InpATRPeriod`, `InpATRAvgLookback`, `InpVolMinRiskFactor`, `InpVolAllowUpsize`.
- Equity: `InpDailyLossSoftPercent`, `InpEquityMinRiskFactor`, `InpEquityAllowUpsize`, `InpDailyWinBoostCap`.
- Composition: `InpMinRiskFactor`, `InpMaxRiskFactor`, `InpSLMultGainOnCut`, `InpCooldownGainOnCut`.

### Setup Steps
1) Compile and attach `CascadeGreepMasterEA.mq5` to one chart (any symbol). Ensure the Economic Calendar is available in your terminal.
2) Set `InpSymbols` to match the symbols you trade and keep the namespace as `CGreep` unless you change it in the worker.
3) On each traded symbol chart, attach `CascadeGreepEA.mq5` with `InpUseMasterAdjust = true` and `InpGVNamespaceEA = CGreep`.
4) Watch the Experts log for lines like `[MASTER] EURUSD rf=0.62 sl_mult=1.76 cd_mult=2.38` and worker logs confirming adjusted cooldown and risk.

## Kill-switch behavior
- If equity drawdown from EA start >= `InpKillSwitchDDPercent`:
  - Trading is disabled until EA is re-initialized.
  - If `InpCloseOnKillSwitch = true`, EA attempts to close its own positions.

## Live-Use Checklist
- Broker supports the instruments and symbol names you use (e.g., `XAUUSD` may be suffixed).
- Broker min lot and lot step allow sizing within your risk limits, or use a cent account / nano-lot broker.
- MarketWatch includes all symbols you plan to trade; charts are open and EA attached.
- AutoTrading enabled; account hedging settings compatible with EA.
- `InpMagic`: use the same value across charts if you want all EA positions closed together on kill-switch/daily loss.
- `InpMaxOpenPositions`: this cap is account-wide (includes manual and other EA trades). If you prefer an EA-only cap, ask to switch to magic-filtered counting.

## Notes
- The EA limits to one position per symbol for safety. Attach to multiple charts for multi-symbol trading. The total open positions cap is enforced across the account.
- Logs will explain skipped trades (e.g., size below min lot, position cap reached, kill-switch).

## Disclaimer
This software is provided "as is", for educational purposes only. Trading involves risk, including loss of principal. Use at your own risk.
