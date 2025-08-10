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
    # Accept common variants
    candidates = [
        "r_multiple",
        "r",
        "rmultiple",
    ]
    col = None
    for c in candidates:
        if c in df.columns:
            col = c
            break
    if col is None:
        # Try fuzzy search for any col containing both 'r' and 'multiple'
        for c in df.columns:
            s = str(c)
            if "r" in s and "multiple" in s:
                col = c
                break
    if col is None:
        # Fallback 1: profit column present in the same frame
        if "profit" in df.columns:
            vals = pd.to_numeric(df["profit"], errors="coerce").fillna(0.0)
            y = (vals > 0.0).astype(int)
            return df, y
        # Fallback 2: try to read knowledge_base.csv and merge
        kb_path = os.path.join(os.path.dirname(resolve_features_path()), "knowledge_base.csv")
        if os.path.exists(kb_path):
            try:
                kb = pd.read_csv(kb_path)
                kb.columns = [str(c).strip().lower().replace(" ", "_").replace("-", "_") for c in kb.columns]
                # Candidate join keys
                join_keys_priority = [
                    ["order_id"],
                    ["deal_id"],
                    ["position_id"],
                    ["symbol", "close_time"],
                ]
                for keys in join_keys_priority:
                    if all(k in df.columns for k in keys) and all(k in kb.columns for k in keys):
                        merged = pd.merge(df, kb[[*keys, "profit"]], on=keys, how="left")
                        vals = pd.to_numeric(merged["profit"], errors="coerce").fillna(0.0)
                        y = (vals > 0.0).astype(int)
                        return merged, y
            except Exception:
                pass
        raise ValueError("features.csv must contain r_multiple (or 'r'); profit-based fallback also unavailable")
    vals = pd.to_numeric(df[col], errors="coerce")
    y = (vals > threshold).astype(int)
    return df, y
