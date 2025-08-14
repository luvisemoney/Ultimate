import argparse
import os
import json
import pickle
from typing import Optional, List, Dict

import numpy as np
import pandas as pd

from dataset import load_features
from features import enrich_with_yahoo, build_feature_matrix, scale_features
from model import load_model
from policy import write_policy


def _resolve_cols(df: pd.DataFrame):
    strat = "strategy" if "strategy" in df.columns else None
    sym = "symbol" if "symbol" in df.columns else ("entry_symbol" if "entry_symbol" in df.columns else None)
    tf = "timeframe" if "timeframe" in df.columns else ("tf" if "tf" in df.columns else None)
    return strat, sym, tf


# Heuristic mapping from probability to scaling multipliers.
# Note: MQL5 policy parser commits after reading p_win, so we must output
# sl_scale/tp_scale/trail_atr_mult BEFORE p_win in each slice object.
def compute_scales(p: float, min_conf: float, neutral: bool = False):
    if neutral or p is None:
        return 1.0, 1.0, 1.0
    try:
        import math
        if math.isnan(p):
            return 1.0, 1.0, 1.0
    except Exception:
        pass
    hi = max(0.80, float(min_conf) + 0.20)
    mid = max(0.60, float(min_conf) + 0.10)
    if p >= hi:
        return 0.85, 1.35, 1.15
    if p >= mid:
        return 0.90, 1.20, 1.10
    if p >= float(min_conf):
        return 1.00, 1.00, 1.00
    return 1.00, 1.00, 1.00


def export_policy(common_dir: Optional[str], model_dir: str, min_conf: float, enrich: bool = True, neutral_scales: bool = False) -> str:
    # Load features from Common Files
    df = load_features(common_dir)
    if enrich:
        tf_minutes = None
        if "timeframe" in df.columns:
            try:
                tf_series = pd.to_numeric(df["timeframe"], errors="coerce").dropna()
                if not tf_series.empty:
                    tf_minutes = int(tf_series.mode().iloc[0])
            except Exception:
                tf_minutes = None
        df = enrich_with_yahoo(df, target_timeframe_minutes=tf_minutes, tz="UTC", fill_holidays=True)

    # Build features matrix with the same preprocessing as training
    X, feat_names = build_feature_matrix(df)
    # Try to load persisted scaler and feature order
    scaler_path = os.path.join(model_dir, "scaler.pkl")
    feats_path = os.path.join(model_dir, "features.json")
    scaler = None
    feature_order: List[str] = feat_names
    if os.path.exists(scaler_path):
        try:
            with open(scaler_path, "rb") as f:
                scaler = pickle.load(f)
        except Exception:
            scaler = None
    if os.path.exists(feats_path):
        try:
            with open(feats_path, "r", encoding="utf-8") as f:
                d = json.load(f)
                if isinstance(d, dict) and "features" in d and isinstance(d["features"], list):
                    feature_order = [str(x) for x in d["features"]]
        except Exception:
            pass
    # Align current X to training feature order if possible
    try:
        import numpy as np
        # Build a mapping from current feature list to desired order
        col_to_idx = {c: i for i, c in enumerate(feat_names)}
        idxs = [col_to_idx[c] for c in feature_order if c in col_to_idx]
        X = X[:, idxs]
    except Exception:
        pass
    if scaler is not None:
        Xs = scaler.transform(X)
    else:
        # Fallback: fit a fresh scaler (not ideal, but functional)
        Xs, _ = scale_features(X)

    # Load model and predict probabilities
    model = load_model(model_dir)
    p_all = model.predict(Xs, verbose=0).ravel()

    df_probs = df.copy()
    df_probs["p_win"] = p_all

    s_col, y_col, t_col = _resolve_cols(df_probs)
    slice_probs: List[Dict] = []
    if all(c is not None for c in (s_col, y_col, t_col)):
        # Exact slices: strat+symbol+timeframe
        gb = df_probs.groupby([s_col, y_col, t_col])["p_win"].mean().reset_index()
        for _, row in gb.iterrows():
            p = float(row["p_win"])
            sl_s, tp_s, tr_s = compute_scales(p, min_conf, neutral_scales)
            # Ensure scales come before p_win for the EA parser
            slice_probs.append({
                "strategy": str(row[s_col]),
                "symbol": str(row[y_col]),
                "timeframe": int(row[t_col]) if not pd.isna(row[t_col]) else -1,
                "sl_scale": float(sl_s),
                "tp_scale": float(tp_s),
                "trail_atr_mult": float(tr_s),
                "p_win": p,
            })

        # Aggregated by strat+symbol across all timeframes (timeframe = -1)
        gb_sym = df_probs.groupby([s_col, y_col])["p_win"].mean().reset_index()
        for _, row in gb_sym.iterrows():
            p = float(row["p_win"])
            sl_s, tp_s, tr_s = compute_scales(p, min_conf, neutral_scales)
            # Skip if an exact slice with tf=-1 already exists (shouldn't) — just add
            slice_probs.append({
                "strategy": str(row[s_col]),
                "symbol": str(row[y_col]),
                "timeframe": -1,
                "sl_scale": float(sl_s),
                "tp_scale": float(tp_s),
                "trail_atr_mult": float(tr_s),
                "p_win": p,
            })

        # Aggregated by strategy across all symbols/timeframes (symbol = "*", timeframe = -1)
        gb_strat = df_probs.groupby([s_col])["p_win"].mean().reset_index()
        for _, row in gb_strat.iterrows():
            p = float(row["p_win"])
            sl_s, tp_s, tr_s = compute_scales(p, min_conf, neutral_scales)
            slice_probs.append({
                "strategy": str(row[s_col]),
                "symbol": "*",
                "timeframe": -1,
                "sl_scale": float(sl_s),
                "tp_scale": float(tp_s),
                "trail_atr_mult": float(tr_s),
                "p_win": p,
            })

    # Ensure trainer-side default coverage for known EA strategies
    KNOWN_EA_STRATS = [
        "BollAveragesStrategy",
        "MeanReversionBBStrategy",
        "SuperTrendADXKamaStrategy",
        "RSI2BBReversionStrategy",
        "DonchianATRBreakoutStrategy",
    ]
    existing = set()
    for r in slice_probs:
        key = (str(r.get("strategy","")), str(r.get("symbol","")), int(r.get("timeframe", -1)))
        existing.add(key)
    # Add neutral strat-only aggregates where missing
    for strat in KNOWN_EA_STRATS:
        key = (strat, "*", -1)
        if key not in existing:
            # Emit neutral scales explicitly and ensure they appear before p_win
            slice_probs.append({
                "strategy": strat,
                "symbol": "*",
                "timeframe": -1,
                "sl_scale": 1.0,
                "tp_scale": 1.0,
                "trail_atr_mult": 1.0,
                "p_win": 0.50,
            })

    path = write_policy(min_confidence=float(min_conf), common_dir=common_dir, slice_probs=slice_probs if slice_probs else None)
    return path


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Export DualEA policy.json from trained model and features.csv")
    ap.add_argument("--common", type=str, default=None, help="Override Common Files DualEA dir")
    ap.add_argument("--model_dir", type=str, default=os.path.join(os.getcwd(), "artifacts"), help="Directory containing tf_model.keras")
    ap.add_argument("--min_conf", type=float, default=0.55, help="Minimum confidence threshold to enforce in policy.json")
    ap.add_argument("--no_enrich", action="store_true", help="Disable Yahoo enrichment for speed")
    ap.add_argument("--neutral_scales", action="store_true", help="Emit neutral scale fields (1.0)")
    args = ap.parse_args()

    out = export_policy(args.common, args.model_dir, args.min_conf, enrich=(not args.no_enrich), neutral_scales=args.neutral_scales)
    print(f"Saved policy to {out} (min_confidence={args.min_conf:.2f})")
