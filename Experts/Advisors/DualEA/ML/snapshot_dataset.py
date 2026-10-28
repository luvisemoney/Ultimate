"""Inspect raw legacy snapshots or audit the supported real-history dataset.

Inspection never turns status/gate acceptance or missing outcomes into labels.
Training is provided by Build-MarketModel.ps1 and Train_MarketModel.mq5 only.
"""
from __future__ import annotations
import argparse
from collections import Counter, defaultdict
import csv
from datetime import datetime
import json
import math
import os
from pathlib import Path
from typing import Any

COMMON_FILES_DIR = Path(os.environ.get("APPDATA", "")) / "MetaQuotes" / "Terminal" / "Common" / "Files"
SNAPSHOT_PATTERN = "feature_batch_*.txt"
MARKET_BASE_FEATURES = (
    "mm_signed_logret1", "mm_signed_logret3", "mm_signed_logret12", "mm_signed_zscore12",
    "mm_return_std12", "mm_range", "mm_signed_body", "mm_spread",
    "mm_hour_sin", "mm_hour_cos", "mm_direction", "mm_atr14",
)
ACTIVE_FEATURES = ("active_symbol_flag", "active_ret1", "active_ret3", "active_zscore")
RETIRED_TRAINING_MESSAGE = (
    "Legacy snapshot-label training is retired. Gate/status acceptance is not "
    "profitability, and absent future outcomes must stay unknown. Run "
    "ML/Build-MarketModel.ps1 (or snapshot_train.py) for the supported real-history "
    "universal ONNX model with causal shared features, train-only scaling, and "
    "chronological horizon-purged evaluation."
)


def _read_text_lines_with_fallback(path: str | Path) -> list[str]:
    data = Path(path).read_bytes()
    if data.startswith((b"\xff\xfe", b"\xfe\xff")):
        return data.decode("utf-16").splitlines()
    candidates = ("utf-16-le", "utf-16-be") if b"\x00" in data else ("utf-8-sig", "cp1252")
    for encoding in candidates:
        try:
            text = data.decode(encoding)
        except UnicodeDecodeError:
            continue
        if "\x00" not in text:
            return text.splitlines()
    raise ValueError(f"Snapshot has unsupported or malformed encoding: {path}")


def parse_snapshot_file(path: str | Path) -> dict[str, str]:
    record: dict[str, str] = {}
    for raw in _read_text_lines_with_fallback(path):
        line = raw.strip()
        if not line:
            continue
        if ":" not in line:
            raise ValueError(f"Malformed snapshot key/value line in {path}")
        key, value = line.split(":", 1)
        key = key.strip().lower()
        if not key or key in record:
            raise ValueError(f"Empty or duplicate snapshot field {key!r} in {path}")
        record[key] = value.strip()
    record["__source_file"] = Path(path).name
    record["__source_path"] = str(Path(path).resolve())
    return record


def list_snapshot_files(snapshot_dir: str | Path | None = None, pattern: str = SNAPSHOT_PATTERN) -> list[str]:
    return [str(path) for path in sorted(Path(snapshot_dir or COMMON_FILES_DIR).glob(pattern)) if path.is_file()]


def inspect_snapshots(snapshot_dir: str | Path | None = None, limit: int | None = None) -> dict[str, Any]:
    files = list_snapshot_files(snapshot_dir)
    if limit is not None:
        if limit <= 0:
            raise ValueError("limit must be positive")
        files = files[-limit:]
    records = [parse_snapshot_file(path) for path in files]
    return {
        "records": len(records),
        "symbols": sorted({record.get("symbol", "unknown") for record in records}),
        "status_counts_for_diagnostics_only": dict(Counter(record.get("status", "unknown") for record in records)),
        "training_supported": False,
        "training_path": "ML/Build-MarketModel.ps1",
        "reason": RETIRED_TRAINING_MESSAGE,
    }


def audit_market_dataset(path: str | Path, train_end: str | None = None,
                         validation_end: str | None = None, test_end: str | None = None,
                         model_data: str | Path | None = None) -> dict[str, Any]:
    """Verify observed labels, paired timestamps and purged chronological splits.

    The CSV is sparse: twelve causal base features plus the active symbol's
    four interactions. It is an audit, not an alternative trainer or imputer.
    All timestamps use the broker-native MQL bar-time coordinate consistently.
    """
    # Artifact metadata is authoritative unless a caller explicitly overrides
    # a boundary. Historical fixture defaults apply only without a manifest.
    metadata_path = Path(model_data) if model_data is not None else Path(path).resolve().with_name("model_data.json")
    metadata = {}
    if model_data is not None or metadata_path.is_file():
        with metadata_path.open("r", encoding="utf-8-sig") as handle:
            metadata = json.load(handle)
        if not isinstance(metadata, dict):
            raise ValueError("model_data.json must contain a metadata object")
    keys = ("training_end", "validation_end", "test_end")
    fallback = ("2025.07.01", "2025.10.01", "2026.01.01")
    resolved = []
    for explicit, key, default in zip((train_end, validation_end, test_end), keys, fallback):
        if explicit is not None:
            value = explicit
        elif metadata:
            if not isinstance(metadata.get(key), str) or not metadata[key]:
                raise ValueError(f"Model metadata is missing a valid {key} split boundary")
            value = metadata[key]
        else:
            value = default
        resolved.append(value)
    boundaries = [datetime.strptime(value, "%Y.%m.%d") for value in resolved]
    if not boundaries[0] < boundaries[1] < boundaries[2]:
        raise ValueError("Split boundaries must increase chronologically")
    required = {"decision_time", "target_end", "split", "symbol", "direction", "label", "net_log_return", "entry_spread_points", "exit_spread_points"}
    counts: Counter[str] = Counter()
    classes: dict[str, Counter[int]] = defaultdict(Counter)
    groups: dict[tuple[str, datetime], set[int]] = defaultdict(set)
    timestamp_splits: dict[datetime, str] = {}
    symbols: set[str] = set()
    rows = 0
    with Path(path).open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        fields = set(reader.fieldnames or ())
        if not required <= fields:
            raise ValueError(f"Market dataset missing columns: {sorted(required - fields)}")
        feature_fields = [field for field in fields if field.startswith("mm_") or field.startswith("active_")]
        if not set(MARKET_BASE_FEATURES + ACTIVE_FEATURES) <= fields or set(field for field in feature_fields if field.startswith("mm_")) != set(MARKET_BASE_FEATURES):
            raise ValueError("Market dataset must include the twelve shared causal base features")
        for line, row in enumerate(reader, start=2):
            try:
                decision = datetime.strptime(row["decision_time"], "%Y.%m.%d %H:%M")
                target_end = datetime.strptime(row["target_end"], "%Y.%m.%d %H:%M")
                split = row["split"]
                symbol = row["symbol"].strip()
                direction = int(row["direction"])
                label = int(row["label"])
                net_return = float(row["net_log_return"])
                numbers = [float(row[field]) for field in feature_fields]
                spreads = [float(row[field]) for field in ("entry_spread_points", "exit_spread_points")]
            except (KeyError, TypeError, ValueError) as error:
                raise ValueError(f"Unknown/malformed observed value on line {line}: {error}") from error
            if not symbol or direction not in (0, 1) or label not in (0, 1):
                raise ValueError(f"Invalid symbol/direction/label on line {line}")
            if not all(math.isfinite(value) for value in [net_return, *numbers, *spreads]) or min(spreads) < 0:
                raise ValueError(f"Nonfinite feature/outcome or negative spread on line {line}")
            if label != int(net_return > 0):
                raise ValueError(f"Label is inconsistent with observed spread-adjusted return on line {line}")
            direction_value = 1.0 if direction == 0 else -1.0
            if float(row["mm_direction"]) != direction_value or float(row["active_symbol_flag"]) != 1.0:
                raise ValueError(f"Direction or active-symbol feature contract violated on line {line}")
            volatility = float(row["mm_return_std12"])
            if volatility < 0.0:
                raise ValueError(f"Negative return volatility on line {line}")
            expected = (float(row["mm_signed_logret1"]) / max(volatility, 1e-8),
                        float(row["mm_signed_logret3"]) / max(volatility, 1e-8),
                        float(row["mm_signed_zscore12"]))
            actual = tuple(float(row[name]) for name in ACTIVE_FEATURES[1:])
            if any(not math.isclose(left, right, rel_tol=1e-9, abs_tol=1e-9) for left, right in zip(actual, expected)):
                raise ValueError(f"Sparse symbol interactions mismatch causal base features on line {line}")
            if target_end <= decision:
                raise ValueError(f"Future outcome must end after decision on line {line}")
            if split == "train":
                valid = decision < boundaries[0] and target_end < boundaries[0]
            elif split == "validation":
                valid = boundaries[0] <= decision < boundaries[1] and target_end < boundaries[1]
            elif split == "test":
                valid = boundaries[1] <= decision < boundaries[2] and target_end < boundaries[2]
            else:
                valid = False
            if not valid:
                raise ValueError(f"Unknown split or outcome crossing a split boundary on line {line}")
            if decision in timestamp_splits and timestamp_splits[decision] != split:
                raise ValueError(f"A decision timestamp is split across partitions on line {line}")
            timestamp_splits[decision] = split
            group = groups[(symbol, decision)]
            if direction in group:
                raise ValueError(f"Duplicate symbol/time/direction on line {line}")
            group.add(direction)
            counts[split] += 1
            classes[split][label] += 1
            symbols.add(symbol)
            rows += 1
    if not rows:
        raise ValueError("No real-history rows to audit")
    if any(directions != {0, 1} for directions in groups.values()):
        raise ValueError("Each symbol/decision group must retain both BUY and SELL observations")
    if any(set(classes[split]) != {0, 1} for split in ("train", "validation", "test")):
        raise ValueError("Each chronological split must contain observed positive and negative outcomes")
    return {"rows": rows, "symbols": sorted(symbols), "split_counts": dict(counts),
            "class_counts": {key: dict(value) for key, value in classes.items()},
            "split_boundaries": dict(zip(keys, resolved)),
            "model_data": str(metadata_path.resolve()) if metadata else None,
            "audit_passed": True}


# Old import callers fail clearly instead of changing return types silently.
def label_from_status(*args: Any, **kwargs: Any) -> None:
    raise RuntimeError(RETIRED_TRAINING_MESSAGE)


def labels_from_future_prices(*args: Any, **kwargs: Any) -> None:
    raise RuntimeError(RETIRED_TRAINING_MESSAGE)


def load_snapshot_dataframe(*args: Any, **kwargs: Any) -> None:
    raise RuntimeError(RETIRED_TRAINING_MESSAGE)


def build_feature_matrix(*args: Any, **kwargs: Any) -> None:
    raise RuntimeError(RETIRED_TRAINING_MESSAGE)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group()
    source.add_argument("--snapshot_dir")
    source.add_argument("--market-csv")
    parser.add_argument("--limit", type=int)
    parser.add_argument("--model-data", help="Model metadata JSON; defaults to model_data.json beside --market-csv")
    parser.add_argument("--train-end", help="Override the model metadata training boundary")
    parser.add_argument("--validation-end", help="Override the model metadata validation boundary")
    parser.add_argument("--test-end", help="Override the model metadata test boundary")
    args = parser.parse_args(argv)
    try:
        report = audit_market_dataset(args.market_csv, args.train_end, args.validation_end, args.test_end, args.model_data) if args.market_csv else inspect_snapshots(args.snapshot_dir, args.limit)
        print(json.dumps(report, indent=2))
    except (OSError, ValueError) as error:
        parser.exit(1, f"Dataset audit failed: {error}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
