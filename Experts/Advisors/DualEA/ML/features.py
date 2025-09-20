import os
from datetime import datetime, timedelta
from typing import Tuple, List, Optional

import numpy as np
import pandas as pd
try:
    import yfinance as yf
except Exception:
    yf = None
from sklearn.preprocessing import StandardScaler


FX_SUFFIX = "=X"
SYMBOL_MAP = {
    # Indices
    "US30": "^DJI",
    "DJI": "^DJI",
    "US500": "^GSPC",
    "SPX500": "^GSPC",
    "SPX": "^GSPC",
    "NAS100": "^IXIC",
    "NDX": "^NDX",
    "GER40": "^GDAXI",
    "DE40": "^GDAXI",
    "UK100": "^FTSE",
    "FR40": "^FCHI",
    "JP225": "^N225",
    # Crypto
    "BTCUSD": "BTC-USD",
    "ETHUSD": "ETH-USD",
    # Metals FX-style still use =X on Yahoo
    "XAUUSD": "XAUUSD=X",
    "XAGUSD": "XAGUSD=X",
}


def map_symbol_to_yahoo(symbol: str) -> str:
    # Map common indices/crypto, then fallback to FX mapping (EURUSD -> EURUSD=X)
    sym = symbol.replace("/", "").upper()
    if sym in SYMBOL_MAP:
        return SYMBOL_MAP[sym]
    if sym.endswith(FX_SUFFIX):
        return sym
    return f"{sym}{FX_SUFFIX}"


def _tf_to_interval_and_freq(tf_minutes: Optional[int]) -> Tuple[str, str]:
    """Map MT5 timeframe (minutes) to yfinance interval and pandas freq."""
    if tf_minutes is None or tf_minutes <= 0:
        return "1d", "1D"
    if tf_minutes <= 1:
        return "1m", "1min"
    if tf_minutes <= 5:
        return "5m", "5min"
    if tf_minutes <= 15:
        return "15m", "15min"
    if tf_minutes <= 30:
        return "30m", "30min"
    if tf_minutes <= 60:
        return "60m", "60min"
    if tf_minutes <= 240:
        return "60m", f"{tf_minutes}min"
    return "1d", "1D"


def enrich_with_yahoo(df: pd.DataFrame,
                      symbol_col: str = "symbol",
                      time_col: str = "close_time",
                      target_timeframe_minutes: Optional[int] = None,
                      tz: str = "UTC",
                      fill_holidays: bool = True) -> pd.DataFrame:
    if symbol_col not in df.columns:
        # fallback: try 'entry_symbol' or assume single symbol
        return df
    if time_col not in df.columns:
        # try alternate column names
        for alt in ("time", "timestamp", "entry_time"):
            if alt in df.columns:
                time_col = alt
                break
    if time_col not in df.columns:
        return df

    # If yfinance is unavailable, skip enrichment gracefully
    if yf is None:
        return df
    df = df.copy()
    df[time_col] = pd.to_datetime(df[time_col], utc=True, errors="coerce")
    if tz:
        # Normalize to UTC for stable asof joins
        try:
            df[time_col] = df[time_col].dt.tz_convert("UTC")
        except Exception:
            # If tz-naive after parsing, localize then convert
            try:
                df[time_col] = df[time_col].dt.tz_localize("UTC")
            except Exception:
                pass

    # For each symbol, fetch yahoo OHLCV over covered date range
    enriched_frames: List[pd.DataFrame] = []
    for sym, g in df.groupby(symbol_col):
        start = g[time_col].min() - timedelta(days=5)
        end = g[time_col].max() + timedelta(days=2)
        ysym = map_symbol_to_yahoo(sym)
        interval, freq = _tf_to_interval_and_freq(target_timeframe_minutes)
        try:
            y = yf.download(ysym, start=start.tz_convert("UTC").to_pydatetime(), end=end.tz_convert("UTC").to_pydatetime(), interval=interval)
        except Exception:
            y = pd.DataFrame()
        if y is None or y.empty:
            enriched_frames.append(g)
            continue
        # Flatten potential MultiIndex columns from yfinance
        if isinstance(y.columns, pd.MultiIndex):
            y.columns = ["_".join([str(c) for c in tup if c is not None and str(c) != ""]).strip("_") for tup in y.columns]
        # Standardize column names (case-insensitive)
        rename_map = {}
        for c in list(y.columns):
            cl = str(c).strip().lower()
            if cl == "open":
                rename_map[c] = "y_open"
            elif cl == "high":
                rename_map[c] = "y_high"
            elif cl == "low":
                rename_map[c] = "y_low"
            elif cl == "close":
                rename_map[c] = "y_close"
            elif cl in ("adj close", "adjclose", "adj_close"):
                rename_map[c] = "y_adj_close"
            elif cl == "volume":
                rename_map[c] = "y_volume"
        if rename_map:
            y = y.rename(columns=rename_map)
        # Ensure datetime index and then expose as a normal column in UTC
        if not isinstance(y.index, pd.DatetimeIndex):
            try:
                y.index = pd.to_datetime(y.index, utc=True)
            except Exception:
                y.index = pd.to_datetime(y.index, utc=True, errors="coerce")
        else:
            if y.index.tz is None:
                y.index = y.index.tz_localize("UTC")
            else:
                y.index = y.index.tz_convert("UTC")
        if fill_holidays and freq:
            # Reindex to continuous timeline at target frequency and ffill to bridge holidays/weekends
            try:
                full_idx = pd.date_range(start=y.index.min(), end=y.index.max(), freq=freq, tz="UTC")
                y = y.reindex(full_idx).ffill()
            except Exception:
                pass
        y = y.reset_index()
        # The reset index column is commonly named 'Date' or 'Datetime' for yfinance
        if "Date" in y.columns:
            y = y.rename(columns={"Date": time_col})
        elif "Datetime" in y.columns:
            y = y.rename(columns={"Datetime": time_col})
        else:
            # If the datetime column got a different name, coerce to target name
            y.columns = [time_col if str(c).lower() in ("date", "datetime", "index") else c for c in y.columns]

        # Ensure y_close exists (robust, case-insensitive)
        if "y_close" not in y.columns:
            lower_map = {str(c).lower(): c for c in y.columns}
            for cand in ("y_close", "close", "adj close", "adj_close", "y_adj_close"):
                if cand in lower_map:
                    y["y_close"] = y[lower_map[cand]]
                    break
            if "y_close" not in y.columns:
                # If still missing, create NaNs to keep pipeline running
                y["y_close"] = np.nan

        # Derived features
        y["y_ret_1d"] = y["y_close"].pct_change(1)
        y["y_vol_5"] = y["y_ret_1d"].rolling(5).std().fillna(0.0)
        y["y_vol_20"] = y["y_ret_1d"].rolling(20).std().fillna(0.0)

        # Ensure left frame doesn't carry a time index level
        gg = g.copy()
        if isinstance(gg.index, pd.MultiIndex) or (gg.index.name == time_col):
            gg = gg.reset_index()
        # Make sure no MultiIndex columns remain
        if isinstance(gg.columns, pd.MultiIndex):
            gg.columns = ["_".join([str(c) for c in tup if c is not None and str(c) != ""]).strip("_") for tup in gg.columns]
        if isinstance(y.columns, pd.MultiIndex):
            y.columns = ["_".join([str(c) for c in tup if c is not None and str(c) != ""]).strip("_") for tup in y.columns]
        merged = pd.merge_asof(
            gg.sort_values(time_col),
            y.sort_values(time_col),
            on=time_col,
            direction="backward",
            tolerance=pd.Timedelta(minutes=target_timeframe_minutes) if target_timeframe_minutes else None,
        )
        enriched_frames.append(merged)

    return pd.concat(enriched_frames, ignore_index=True)


def build_feature_matrix(df: pd.DataFrame,
                         drop_cols: Tuple[str, ...] = ("r_multiple", "close_event", "strategy", "order_id", "deal_id")) -> Tuple[np.ndarray, List[str]]:
    x = df.copy()
    for c in drop_cols:
        if c in x.columns:
            x = x.drop(columns=[c])
    # Remove non-numeric columns
    num = x.select_dtypes(include=[np.number]).copy()
    features = num.columns.tolist()
    return num.values.astype(float), features


def scale_features(x: np.ndarray) -> Tuple[np.ndarray, StandardScaler]:
    scaler = StandardScaler()
    xs = scaler.fit_transform(x)
    return xs, scaler
