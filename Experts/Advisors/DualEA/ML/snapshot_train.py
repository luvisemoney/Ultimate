import argparse
import json
import os
import pickle
from typing import List, Optional, Sequence

import numpy as np
import pandas as pd
from sklearn.metrics import f1_score, roc_auc_score
from sklearn.model_selection import TimeSeriesSplit
from sklearn.preprocessing import StandardScaler
import xgboost as xgb

from snapshot_dataset import (
    FeatureMatrix,
    build_feature_matrix,
    describe_dataframe,
    label_from_status,
    labels_from_future_prices,
    load_snapshot_dataframe,
)


def _determine_labels(
    df: pd.DataFrame,
    mode: str,
    price_csv: Optional[str],
    horizon_minutes: int,
    target_r_multiple: float,
    positive_status: Optional[Sequence[str]],
) -> pd.Series:
    mode = mode.lower()
    if mode == "status":
        return label_from_status(df, positive_status)
    if mode == "future_price":
        if not price_csv:
            raise ValueError("--price_csv required when --label_mode future_price")
        labels = labels_from_future_prices(
            df,
            price_csv=price_csv,
            horizon_minutes=horizon_minutes,
            target_r_multiple=target_r_multiple,
        )
        aligned = labels.reindex(df.index)
        aligned = aligned.fillna(0).astype(int)
        return aligned
    raise ValueError(f"Unsupported label_mode {mode}")


def _evaluate_predictions(y_true: np.ndarray, proba: np.ndarray) -> dict:
    preds = (proba >= 0.5).astype(int)
    auc = roc_auc_score(y_true, proba) if len(np.unique(y_true)) > 1 else 0.5
    f1 = f1_score(y_true, preds)
    return {"auc": float(auc), "f1": float(f1)}


def _train_with_timeseries_split(
    X: np.ndarray,
    y: np.ndarray,
    n_splits: int,
    params: dict,
) -> tuple[xgb.XGBClassifier, dict]:
    splitter = TimeSeriesSplit(n_splits=max(2, n_splits))
    best_model: Optional[xgb.XGBClassifier] = None
    best_auc = -1.0
    metrics = []
    for fold, (tr_idx, va_idx) in enumerate(splitter.split(X)):
        model = xgb.XGBClassifier(
            **params,
            eval_metric="logloss",
            use_label_encoder=False,
        )
        model.fit(X[tr_idx], y[tr_idx])
        proba = model.predict_proba(X[va_idx])[:, 1]
        fold_metrics = _evaluate_predictions(y[va_idx], proba)
        fold_metrics["fold"] = fold + 1
        metrics.append(fold_metrics)
        if fold_metrics["auc"] > best_auc:
            best_auc = fold_metrics["auc"]
            best_model = model
        print(f"[Fold {fold+1}] AUC={fold_metrics['auc']:.3f} F1={fold_metrics['f1']:.3f}")
    if best_model is None:
        raise RuntimeError("Training failed to produce a model")
    return best_model, {"folds": metrics, "best_auc": best_auc}


def save_artifacts(
    out_dir: str,
    model: xgb.XGBClassifier,
    scaler: StandardScaler,
    feature_matrix: FeatureMatrix,
    label_mode: str,
    positive_status: Optional[Sequence[str]],
) -> None:
    os.makedirs(out_dir, exist_ok=True)
    model_path = os.path.join(out_dir, "xgb_model.json")
    model.save_model(model_path)
    with open(os.path.join(out_dir, "scaler.pkl"), "wb") as handle:
        pickle.dump(scaler, handle)
    meta = {
        "features": feature_matrix.feature_names,
        "categorical_mappings": feature_matrix.categorical_mappings,
        "label_mode": label_mode,
        "positive_status": list(positive_status) if positive_status else ["passed", "executed"],
    }
    with open(os.path.join(out_dir, "feature_meta.json"), "w", encoding="utf-8") as handle:
        json.dump(meta, handle, indent=2)
    print(f"[OK] Saved artifacts to {out_dir}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Train XGBoost model from signal snapshot exports")
    parser.add_argument("--snapshot_dir", type=str, default=None, help="Directory containing feature_batch_*.txt files (defaults to MT5 Common Files)")
    parser.add_argument("--limit", type=int, default=None, help="Limit number of snapshots (most recent)")
    parser.add_argument("--label_mode", type=str, default="status", choices=("status", "future_price"))
    parser.add_argument("--price_csv", type=str, default=None, help="Price CSV for future_price labeling mode")
    parser.add_argument("--horizon_minutes", type=int, default=60, help="Minutes ahead for future_price labeling")
    parser.add_argument("--target_r_multiple", type=float, default=0.0, help="R multiple threshold for positive label in future_price mode")
    parser.add_argument("--positive_status", type=str, nargs="*", default=("passed", "executed"), help="Statuses treated as positive in status label mode")
    parser.add_argument("--n_splits", type=int, default=4, help="TimeSeriesSplit folds")
    parser.add_argument("--max_depth", type=int, default=6)
    parser.add_argument("--learning_rate", type=float, default=0.1)
    parser.add_argument("--n_estimators", type=int, default=300)
    parser.add_argument("--subsample", type=float, default=0.9)
    parser.add_argument("--colsample_bytree", type=float, default=0.8)
    parser.add_argument("--out_dir", type=str, default=os.path.join(os.getcwd(), "artifacts"))
    return parser.parse_args()


def main():
    args = parse_args()
    df = load_snapshot_dataframe(args.snapshot_dir, limit=args.limit)
    print("[DATA]", describe_dataframe(df))
    labels = _determine_labels(
        df,
        mode=args.label_mode,
        price_csv=args.price_csv,
        horizon_minutes=args.horizon_minutes,
        target_r_multiple=args.target_r_multiple,
        positive_status=args.positive_status,
    )
    if labels.sum() == 0:
        raise RuntimeError("All labels are negative—need at least some positives to train")
    feature_matrix = build_feature_matrix(df)
    scaler = StandardScaler()
    X = scaler.fit_transform(feature_matrix.X)
    y = labels.values.astype(int)
    model, metrics = _train_with_timeseries_split(
        X,
        y,
        n_splits=args.n_splits,
        params={
            "max_depth": args.max_depth,
            "learning_rate": args.learning_rate,
            "n_estimators": args.n_estimators,
            "subsample": args.subsample,
            "colsample_bytree": args.colsample_bytree,
            "objective": "binary:logistic",
        },
    )
    save_artifacts(
        out_dir=args.out_dir,
        model=model,
        scaler=scaler,
        feature_matrix=feature_matrix,
        label_mode=args.label_mode,
        positive_status=args.positive_status,
    )
    metrics_path = os.path.join(args.out_dir, "metrics.json")
    with open(metrics_path, "w", encoding="utf-8") as handle:
        json.dump(metrics, handle, indent=2)
    print(f"[OK] Metrics written to {metrics_path}")


if __name__ == "__main__":
    main()
