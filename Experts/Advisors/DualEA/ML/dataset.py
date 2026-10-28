import os
import pandas as pd
from typing import Tuple

# Default MT5 Common Files path on Windows
DEFAULT_COMMON = os.path.join(os.environ.get("APPDATA", ""), "MetaQuotes", "Terminal", "Common", "Files", "DualEA")
FEATURES_NAME = "features.csv"


def resolve_features_path(common_dir: str = None) -> str:
    base = common_dir or DEFAULT_COMMON
    return os.path.join(base, FEATURES_NAME)


def _read_csv_robust(path: str) -> pd.DataFrame:
    encodings = [
        "utf-8",
        "utf-8-sig",
        "utf-16",
        "utf-16-le",
        "utf-16-be",
        "cp1252",
        "latin1",
    ]
    last_exc = None
    for enc in encodings:
        try:
            return pd.read_csv(path, encoding=enc)
        except UnicodeDecodeError as e:
            last_exc = e
            continue
        except Exception as e:
            # If it's not a decode error, bubble up immediately
            raise
    # Fallback with python engine ignoring bad lines if all decodes failed
    return pd.read_csv(path, encoding="latin1", engine="python")


def load_features(common_dir: str = None) -> pd.DataFrame:
    path = resolve_features_path(common_dir)
    if not os.path.exists(path):
        raise FileNotFoundError(f"features.csv not found at {path}")
    # Comma-delimited, result of EA writes (encoding may vary depending on MT5 settings)
    df = _read_csv_robust(path)
    # Normalize columns to lower snake-case (handles header casing/spacing)
    df.columns = [str(c).strip().lower().replace(" ", "_").replace("-", "_") for c in df.columns]
    # Basic cleaning
    df = df.dropna(how="all")
    # Ensure timestamp is parsed if present
    for col in ("time", "timestamp", "entry_time", "close_time"):
        if col in df.columns:
            try:
                df[col] = pd.to_datetime(df[col])
            except Exception:
                pass
    # If long format (feature/value), pivot to wide
    if {"feature", "value"}.issubset(set(df.columns)):
        # Coerce value to numeric
        df["value"] = pd.to_numeric(df["value"], errors="coerce")
        # Candidate keys to keep identity and slices stable
        key_priority = [
            ["position_id"],
            ["deal_id"],
            ["order_id"],
            ["position_id", "deal_id", "order_id"],
            ["strategy", "symbol", "timeframe", "entry_time", "close_time"],
            ["strategy", "symbol", "entry_time", "close_time"],
            ["symbol", "entry_time", "close_time"],
        ]
        keys = []
        for cand in key_priority:
            kk = [c for c in cand if c in df.columns]
            if len(kk) == len(cand):
                keys = kk
                break
        # Always try to include context columns for downstream use
        for c in ("strategy", "symbol", "timeframe", "entry_time", "close_time"):
            if c in df.columns and c not in keys:
                keys.append(c)
        if not keys:
            # Fallback: use all non-feature columns except 'value' as keys to avoid data loss
            keys = [c for c in df.columns if c not in ("feature", "value")]
        # Pivot
        wide = df.pivot_table(index=keys, columns="feature", values="value", aggfunc="last")
        wide = wide.reset_index()
        # Flatten columns after pivot
        wide.columns = [str(c).strip().lower().replace(" ", "_") for c in wide.columns]
        return wide
    return df


def make_label_from_r_multiple(df: pd.DataFrame, threshold: float = 0.0) -> Tuple[pd.DataFrame, pd.Series]:
    """Return labels only for explicitly closed, finite realized outcomes.

    This diagnostic helper never joins Common Files implicitly, fills missing
    outcomes with zero, or interprets a gate/status flag as an outcome. The
    standard training entry point is the shared real-history MQL5 pipeline.
    """
    import math

    if not math.isfinite(float(threshold)):
        raise ValueError("Outcome threshold must be finite")
    outcome = next((name for name in ("r_multiple", "r", "rmultiple") if name in df.columns), None)
    if outcome is None:
        if "profit" not in df.columns:
            raise ValueError("Realized R multiple or profit is required; no implicit file merge or unknown-label fallback")
        if threshold != 0.0:
            raise ValueError("A nonzero R-multiple threshold cannot be applied to currency profit")
        outcome = "profit"

    if "is_closed" in df.columns:
        closed = df["is_closed"].astype(str).str.strip().str.lower().isin({"true", "1", "1.0", "yes", "closed"})
    elif "close_event" in df.columns:
        closed = df["close_event"].astype(str).str.strip().str.lower().isin({"true", "1", "1.0", "yes", "close", "closed"})
    elif "close_time" in df.columns:
        values = pd.to_numeric(df["close_time"], errors="coerce")
        nonempty = df["close_time"].notna()
        if nonempty.any() and values[nonempty].notna().all():
            times = pd.to_datetime(values, unit="s", errors="coerce", utc=True)
        else:
            times = pd.to_datetime(df["close_time"], errors="coerce", utc=True)
        closed = times.notna() & (times > pd.Timestamp("1970-01-02", tz="UTC"))
    else:
        raise ValueError("Explicit is_closed/close_event/close_time evidence is required; open trades cannot be labeled")

    realized = pd.to_numeric(df[outcome], errors="coerce")
    finite = realized.map(lambda value: bool(pd.notna(value) and math.isfinite(float(value))))
    observed = closed & finite
    selected = df.loc[observed].copy()
    if selected.empty:
        raise ValueError("No explicitly closed trades with finite observed outcomes; collect real outcomes instead of bootstrapping labels")
    labels = (realized.loc[observed] > float(threshold)).astype(int)
    return selected, labels
