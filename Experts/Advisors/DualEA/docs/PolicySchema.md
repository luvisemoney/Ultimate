# Policy JSON Schema (DualEA)

This document defines the expected structure of `policy.json` consumed by both `PaperEA_v2` and `LiveEA`.

> **Implementation Note:** LiveEA has full per-slice policy parsing with scaling support. PaperEA_v2 has minimal policy parsing (checks `min_confidence` string presence only).

## Location
- MT5 Common Files: typically `C:\Users\<you>\AppData\Roaming\MetaQuotes\Terminal\Common\Files\DualEA\policy.json`
- Reload signal: `Common\Files\DualEA\policy.reload`
  - **PaperEA_v2**: Hot-reload supported via timer polling + optional HTTP
  - **LiveEA**: Policy loaded on init only; restart required for updates

## Top-level Fields
- `min_confidence` (number): gating threshold; trades require `p_win >= min_confidence` unless a fallback path is taken.
  - Note: Policy is considered "loaded" when there is at least one slice (`slices.length > 0`). `min_confidence` does not determine loaded state.
- `slices` (array of objects): per-slice policy entries.

## Slice Fields
Each slice object supports:
- `strategy` (string): strategy identifier matching EA strategies.
- `symbol` (string): normalized symbol, e.g. `"EURUSD"`. Special case: `"*"` to indicate strategy-only aggregate.
- `timeframe` (integer): MT5 timeframe constant number; `-1` indicates aggregate across timeframes for a symbol.
- `p_win` (number): probability/confidence used by gating.
- `sl_scale` (number): stop-loss scale multiplier.
- `tp_scale` (number): take-profit scale multiplier.
- `trail_atr_mult` (number): trailing policy multiplier (ATR-based or treated as generic trailing scale by the EA).

## Aggregation & Lookup
`PaperEA` uses the following lookup order (see `GetPolicyProb()`):
1. Exact match: `(strategy, symbol, timeframe)`
2. Strategy + symbol aggregate: `(strategy, symbol, timeframe=-1)`
3. Strategy-only aggregate: `(strategy, symbol="*", timeframe=-1)`

If no slice is found, `GetPolicyProb()` returns `-1.0` and the EA may use the default policy fallback path if enabled.

## Example
```json
{
  "min_confidence": 0.45,
  "slices": [
    { "strategy": "BollAverages", "symbol": "EURUSD", "timeframe": 60,  "p_win": 0.52, "sl_scale": 1.0, "tp_scale": 1.2, "trail_atr_mult": 1.0 },
    { "strategy": "BollAverages", "symbol": "EURUSD", "timeframe": -1, "p_win": 0.50, "sl_scale": 1.0, "tp_scale": 1.0, "trail_atr_mult": 1.0 },
    { "strategy": "BollAverages", "symbol": "*",       "timeframe": -1, "p_win": 0.48, "sl_scale": 1.0, "tp_scale": 1.0, "trail_atr_mult": 1.0 }
  ]
}
```

## Notes
- Scaling is applied only when a valid slice is found and policy gating is active. Fallback trades (no policy or slice miss) use neutral scaling.
- Trainer/export scripts should ensure symbols/timeframes align with EA normalization and MT5 constants.
