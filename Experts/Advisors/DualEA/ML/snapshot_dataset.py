import glob
import os
from dataclasses import dataclass
from typing import Dict, List, Optional, Sequence, Tuple

import numpy as np
import pandas as pd

COMMON_FILES_DIR = os.path.join(
    os.environ.get("APPDATA", ""),
    "MetaQuotes",
    "Terminal",
    "Common",
    "Files",
)
SNAPSHOT_PATTERN = "feature_batch_*.txt"

NUMERIC_FIELDS: Sequence[str] = [
    "price",
    "volume",
    "sl",
    "tp",
    "confidence",
    "volatility",
    "correlation",
    "hour",
    "timeframe",
    "order_type",
    "gate_passed_count",
    "adjustment_attempts",
    "volume_change_pct",
    "price_change_pct",
    "sl_scale",
    "tp_scale",
]

BINARY_FIELDS: Sequence[str] = [
    "executed",
    "is_adjusted",
    "gate1_pass",
    "gate2_pass",
    "gate3_pass",
    "gate4_pass",
    "gate5_pass",
    "gate6_pass",
    "gate7_pass",
    "gate8_pass",
]

CATEGORICAL_FIELDS: Sequence[str] = [
    "strategy",
    "symbol",
    "status",
    "regime",
    "market_regime",
    "reason",
]

TIMESTAMP_FIELD = "timestamp"


def list_snapshot_files(
    snapshot_dir: Optional[str] = None,
    pattern: str = SNAPSHOT_PATTERN,
) -> List[str]:
    base = snapshot_dir or COMMON_FILES_DIR
    search_path = os.path.join(base, pattern)
    files = sorted(glob.glob(search_path))
    return files


def _parse_snapshot_line(line: str, idx: int) -> Tuple[str, str]:
    line = line.strip()
    if not line:
        return (f"empty_{idx}", "")
    if ":" not in line:
        return (f"field_{idx}", line)
    key, value = line.split(":", 1)
    return key.strip().lower(), value.strip()


def parse_snapshot_file(path: str) -> Dict[str, str]:
    record: Dict[str, str] = {}
    with open(path, "r", encoding="utf-8") as handle:
        for idx, raw in enumerate(handle):
            key, value = _parse_snapshot_line(raw, idx)
            record[key] = value
    record["__source_file"] = os.path.basename(path)
    record["__source_path"] = path
    return record


def load_snapshot_dataframe(
    snapshot_dir: Optional[str] = None,
    limit: Optional[int] = None,
) -> pd.DataFrame:
    files = list_snapshot_files(snapshot_dir)
    if not files:
        raise RuntimeError(
            f"No snapshot files found in {(snapshot_dir or COMMON_FILES_DIR)!r}"
        )
    if limit:
        files = files[-limit:]
    records: List[Dict[str, str]] = []
    for path in files:
        try:
            rec = parse_snapshot_file(path)
            records.append(rec)
        except Exception as exc:  # pragma: no cover - diagnostic path
            print(f"[WARN] Failed to parse snapshot {path}: {exc}")
    if not records:
        raise RuntimeError("Snapshot parsing produced zero records")
    df = pd.DataFrame(records)
    df = normalize_snapshot_dataframe(df)
    return df


def _to_binary(value: object) -> float:
    if value is None:
        return 0.0
    if isinstance(value, (int, float)):
        return float(1.0 if value != 0 else 0.0)
    s = str(value).strip().lower()
    if s in {"1", "true", "yes", "y", "passed", "executed"}:
        return 1.0
    if s in {"0", "false", "no", "n", ""}:
        return 0.0
    try:
        return float(1.0 if float(s) != 0 else 0.0)
    except Exception:
        return 0.0


def normalize_snapshot_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    if TIMESTAMP_FIELD in df.columns:
        df[TIMESTAMP_FIELD] = pd.to_datetime(
            df[TIMESTAMP_FIELD], errors="coerce", utc=True
        )
    else:
        df[TIMESTAMP_FIELD] = pd.NaT
    for field in NUMERIC_FIELDS:
        df[field] = pd.to_numeric(df.get(field), errors="coerce")
    for field in BINARY_FIELDS:
        df[field] = df.get(field, np.nan).apply(_to_binary).astype(float)
    for field in CATEGORICAL_FIELDS:
        df[field] = (
            df.get(field, "unknown")
            .fillna("unknown")
            .astype(str)
            .str.strip()
            .str.lower()
        )
    df["status"] = df.get("status", "unknown").fillna("unknown").astype(str).str.lower()
    return df


def label_from_status(
    df: pd.DataFrame,
    positive_status: Optional[Sequence[str]] = None,
) -> pd.Series:
    if positive_status is None:
        positive_status = ("passed", "executed")
    positives = {s.lower() for s in positive_status}
    labels = df["status"].isin(positives).astype(int)
    return labels


def _load_price_frame(price_csv: str) -> pd.DataFrame:
    price_df = pd.read_csv(price_csv)
    price_df.columns = [
        str(c).strip().lower().replace(" ", "_") for c in price_df.columns
    ]
    if "timestamp" not in price_df.columns:
        raise ValueError("price_csv must contain a 'timestamp' column")
    price_df["timestamp"] = pd.to_datetime(price_df["timestamp"], errors="coerce", utc=True)
    if "symbol" not in price_df.columns:
        price_df["symbol"] = "*"
    if "close" not in price_df.columns:
        raise ValueError("price_csv must contain a 'close' column")
    price_df = price_df.dropna(subset=["timestamp", "close"])
    price_df = price_df.sort_values(["symbol", "timestamp"]).reset_index(drop=True)
    return price_df


def _future_price_for_symbol(
    price_df: pd.DataFrame,
    symbol: str,
    target_time: pd.Timestamp,
) -> Optional[float]:
    subset = price_df[price_df["symbol"] == symbol]
    if subset.empty:
        return None
    future = subset[subset["timestamp"] >= target_time]
    if future.empty:
        return None
    return float(future.iloc[0]["close"])


def labels_from_future_prices(
    df: pd.DataFrame,
    price_csv: str,
    horizon_minutes: int = 60,
    target_r_multiple: float = 0.0,
) -> pd.Series:
    """
    Compute labels based on future price movement relative to SL distance.
    Label = 1 if future R multiple >= target_r_multiple, else 0.
    """
    price_df = _load_price_frame(price_csv)
    labels = pd.Series(index=df.index, dtype=float)
    for idx, row in df.iterrows():
        ts = row.get(TIMESTAMP_FIELD)
        symbol = row.get("symbol", "*")
        price = row.get("price")
        sl = row.get("sl")
        order_type = row.get("order_type", 0)
        if pd.isna(ts) or pd.isna(price) or pd.isna(sl):
            labels.loc[idx] = np.nan
            continue
        target_time = ts + pd.Timedelta(minutes=horizon_minutes)
        future_price = _future_price_for_symbol(price_df, symbol, target_time)
        if future_price is None:
            labels.loc[idx] = np.nan
            continue
        risk = abs(price - sl)
        if risk <= 0:
            labels.loc[idx] = np.nan
            continue
        if int(order_type) == 1:  # sell
            reward = price - future_price
        else:  # buy default
            reward = future_price - price
        r_multiple = reward / risk
        labels.loc[idx] = 1 if r_multiple >= target_r_multiple else 0
    labels = labels.dropna()
    return labels.astype(int)


@dataclass
class FeatureMatrix:
    X: np.ndarray
    feature_names: List[str]
    categorical_mappings: Dict[str, Dict[str, int]]


def build_feature_matrix(
    df: pd.DataFrame,
    numeric_fields: Sequence[str] = NUMERIC_FIELDS,
    binary_fields: Sequence[str] = BINARY_FIELDS,
    categorical_fields: Sequence[str] = CATEGORICAL_FIELDS,
) -> FeatureMatrix:
    working = df.copy()
    for field in numeric_fields:
        if field not in working.columns:
            working[field] = np.nan
    for field in binary_fields:
        if field not in working.columns:
            working[field] = 0.0
    numeric_matrix = working[list(numeric_fields)].fillna(0.0).astype(float)
    binary_matrix = working[list(binary_fields)].fillna(0.0).astype(float)
    categorical_mappings: Dict[str, Dict[str, int]] = {}
    categorical_columns: List[pd.Series] = []
    for field in categorical_fields:
        values = (
            working.get(field, "unknown")
            .fillna("unknown")
            .astype(str)
            .str.strip()
            .str.lower()
        )
        unique_vals = sorted(values.unique())
        mapping = {val: idx + 1 for idx, val in enumerate(unique_vals)}
        categorical_mappings[field] = mapping
        categorical_columns.append(values.map(mapping).fillna(0).astype(float))
    arrays = [numeric_matrix.values, binary_matrix.values]
    feature_names = list(numeric_fields) + list(binary_fields)
    for field, series in zip(categorical_fields, categorical_columns):
        arrays.append(series.values.reshape(-1, 1))
        feature_names.append(f"{field}_code")
    X = np.hstack(arrays).astype(np.float32)
    return FeatureMatrix(X=X, feature_names=feature_names, categorical_mappings=categorical_mappings)


def describe_dataframe(df: pd.DataFrame) -> str:
    total = len(df)
    symbols = sorted(df["symbol"].dropna().unique())
    strategies = sorted(df["strategy"].dropna().unique())
    statuses = df["status"].value_counts().to_dict()
    return (
        f"records={total} symbols={symbols} "
        f"strategies={strategies} status_counts={statuses}"
    )


def main():  # pragma: no cover - convenience CLI
    import argparse

    parser = argparse.ArgumentParser(description="Inspect snapshot dataset")
    parser.add_argument("--snapshot_dir", type=str, default=None)
    parser.add_argument("--limit", type=int, default=None)
    args = parser.parse_args()
    df = load_snapshot_dataframe(args.snapshot_dir, args.limit)
    print(describe_dataframe(df))
    print(df.head())


if __name__ == "__main__":  # pragma: no cover
    main()
