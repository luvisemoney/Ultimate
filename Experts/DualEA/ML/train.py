import argparse
import os
import json
import pickle
from typing import Optional

import numpy as np
import pandas as pd
from sklearn.metrics import f1_score, roc_auc_score
from sklearn.model_selection import TimeSeriesSplit

from dataset import load_features, make_label_from_r_multiple
from features import enrich_with_yahoo, build_feature_matrix, scale_features
from model import build_classifier, build_lstm, save_model
from policy import write_policy


def _resolve_cols(df: pd.DataFrame):
    strat = "strategy" if "strategy" in df.columns else None
    sym = "symbol" if "symbol" in df.columns else ("entry_symbol" if "entry_symbol" in df.columns else None)
    tf = "timeframe" if "timeframe" in df.columns else ("tf" if "tf" in df.columns else None)
    return strat, sym, tf


def _resolve_time_col(df: pd.DataFrame) -> Optional[str]:
    for c in ("close_time", "entry_time", "timestamp", "time"):
        if c in df.columns:
            return c
    return None


def make_sequences(df: pd.DataFrame,
                   X: np.ndarray,
                   y: pd.Series,
                   seq_len: int = 30,
                   group_cols: Optional[list] = None,
                   time_col: Optional[str] = None):
    """Build rolling window sequences per group, ordered by time.

    Returns (Xs, ys) with shapes (N_seq, seq_len, n_features) and (N_seq,).
    The label aligns to the end of each window.
    """
    if group_cols is None:
        group_cols = []
    if time_col is None:
        time_col = _resolve_time_col(df)

    # attach row indices to preserve alignment
    df_idx = df.reset_index(drop=True).copy()
    df_idx["__row__"] = np.arange(len(df_idx))
    # ensure time ordering within each group
    if time_col and time_col in df_idx.columns:
        try:
            df_idx = df_idx.sort_values([*group_cols, time_col]) if group_cols else df_idx.sort_values(time_col)
        except Exception:
            pass

    Xs, ys = [], []
    if group_cols:
        for _, g in df_idx.groupby(group_cols):
            idxs = g["__row__"].values.astype(int)
            if len(idxs) < seq_len:
                continue
            for start in range(0, len(idxs) - seq_len + 1):
                win = idxs[start:start + seq_len]
                Xs.append(X[win, :])
                ys.append(int(y.iloc[win[-1]]))
    else:
        idxs = df_idx["__row__"].values.astype(int)
        if len(idxs) >= seq_len:
            for start in range(0, len(idxs) - seq_len + 1):
                win = idxs[start:start + seq_len]
                Xs.append(X[win, :])
                ys.append(int(y.iloc[win[-1]]))
    if not Xs:
        return np.zeros((0, seq_len, X.shape[1]), dtype=float), np.zeros((0,), dtype=int)
    return np.stack(Xs, axis=0).astype(float), np.array(ys, dtype=int)


def train(common_dir: Optional[str],
          epochs: int,
          batch_size: int,
          val_splits: int,
          min_conf: Optional[float],
          model_type: str = "dense",
          seq_len: int = 30) -> None:
    df = load_features(common_dir)
    # Enrich with Yahoo using detected timeframe and UTC normalization
    tf_minutes = None
    if "timeframe" in df.columns:
        try:
            tf_series = pd.to_numeric(df["timeframe"], errors="coerce").dropna()
            if not tf_series.empty:
                tf_minutes = int(tf_series.mode().iloc[0])
        except Exception:
            tf_minutes = None
    df = enrich_with_yahoo(df, target_timeframe_minutes=tf_minutes, tz="UTC", fill_holidays=True)
    # Build labels
    df, y = make_label_from_r_multiple(df)
    # Build feature matrix
    X, feat_names = build_feature_matrix(df)
    X, scaler = scale_features(X)

    # Prepare data depending on model type
    use_lstm = str(model_type).lower() == "lstm"
    if use_lstm:
        s_col, y_col, _ = _resolve_cols(df)
        group_cols = [c for c in (s_col, y_col) if c is not None]
        t_col = _resolve_time_col(df)
        X_seq, y_seq = make_sequences(df, X, y, seq_len=seq_len, group_cols=group_cols, time_col=t_col)
        if X_seq.shape[0] == 0:
            raise RuntimeError("Insufficient data to build LSTM sequences — try reducing --seq_len or ensuring time columns exist")

    # Time-aware split
    tscv = TimeSeriesSplit(n_splits=max(2, val_splits))
    best_auc = -1.0
    best_model = None
    best_thresh = 0.5

    if use_lstm:
        # Split over sequence indices
        for fold, (tr_idx, va_idx) in enumerate(tscv.split(X_seq)):
            X_tr, X_va = X_seq[tr_idx], X_seq[va_idx]
            y_tr, y_va = y_seq[tr_idx], y_seq[va_idx]
            model = build_lstm(input_dim=X_seq.shape[2], seq_len=X_seq.shape[1])
            model.fit(X_tr, y_tr, epochs=epochs, batch_size=batch_size, validation_data=(X_va, y_va), verbose=0)
            p_va = model.predict(X_va, verbose=0).ravel()
            auc = roc_auc_score(y_va, p_va) if len(np.unique(y_va)) > 1 else 0.5
            ts = np.linspace(0.3, 0.8, num=21)
            f1s = []
            for t in ts:
                f1s.append(f1_score(y_va, (p_va >= t).astype(int)))
            t_star = float(ts[int(np.argmax(f1s))])
            if auc > best_auc:
                best_auc = auc
                best_model = model
                best_thresh = t_star
            print(f"Fold {fold+1}: AUC={auc:.3f} best_thresh={t_star:.2f}")
    else:
        for fold, (tr_idx, va_idx) in enumerate(tscv.split(X)):
            X_tr, X_va = X[tr_idx], X[va_idx]
            y_tr, y_va = y.iloc[tr_idx].values, y.iloc[va_idx].values
            model = build_classifier(X.shape[1])
            model.fit(X_tr, y_tr, epochs=epochs, batch_size=batch_size, validation_data=(X_va, y_va), verbose=0)
            p_va = model.predict(X_va, verbose=0).ravel()
            auc = roc_auc_score(y_va, p_va) if len(np.unique(y_va)) > 1 else 0.5
            # choose threshold by max F1
            ts = np.linspace(0.3, 0.8, num=21)
            f1s = []
            for t in ts:
                f1s.append(f1_score(y_va, (p_va >= t).astype(int)))
            t_star = float(ts[int(np.argmax(f1s))])
            if auc > best_auc:
                best_auc = auc
                best_model = model
                best_thresh = t_star
            print(f"Fold {fold+1}: AUC={auc:.3f} best_thresh={t_star:.2f}")
            best_thresh = t_star
        print(f"Fold {fold+1}: AUC={auc:.3f} best_thresh={t_star:.2f}")

    if best_model is None:
        raise RuntimeError("Training failed to produce a model")

    out_dir = os.path.join(os.getcwd(), "artifacts")
    os.makedirs(out_dir, exist_ok=True)
    save_model(best_model, out_dir)
    # Persist preprocessing artifacts
    with open(os.path.join(out_dir, "scaler.pkl"), "wb") as f:
        pickle.dump(scaler, f)
    with open(os.path.join(out_dir, "features.json"), "w", encoding="utf-8") as f:
        json.dump({"features": feat_names}, f, indent=2)

    # Compute per-slice probabilities using the full dataset predictions
    if use_lstm:
        # Build full sequences again to score consistently
        X_full_seq, _ = make_sequences(df, X, y, seq_len=seq_len,
                                       group_cols=[c for c in _resolve_cols(df)[:2] if c is not None],
                                       time_col=_resolve_time_col(df))
        # For mapping back to rows, approximate by using last timestep of each sequence
        p_seq = best_model.predict(X_full_seq, verbose=0).ravel()
        # Broadcast sequence score to last row of each window
        df_probs = df.copy()
        df_probs["p_win"] = np.nan
        # Compute indices of last rows per sequence
        # Reconstruct order the same way as make_sequences
        df_idx = df.reset_index(drop=True).copy()
        df_idx["__row__"] = np.arange(len(df_idx))
        s_col, y_col, _ = _resolve_cols(df)
        t_col = _resolve_time_col(df)
        seq_last_rows = []
        if s_col or y_col:
            group_cols = [c for c in (s_col, y_col) if c is not None]
            if t_col and t_col in df_idx.columns:
                try:
                    df_idx = df_idx.sort_values([*group_cols, t_col])
                except Exception:
                    pass
            for _, g in df_idx.groupby(group_cols):
                idxs = g["__row__"].values.astype(int)
                for start in range(0, max(0, len(idxs) - seq_len + 1)):
                    seq_last_rows.append(idxs[start + seq_len - 1])
        else:
            idxs = df_idx["__row__"].values.astype(int)
            for start in range(0, max(0, len(idxs) - seq_len + 1)):
                seq_last_rows.append(idxs[start + seq_len - 1])
        # Assign
        for idx, p in zip(seq_last_rows, p_seq):
            if 0 <= idx < len(df_probs):
                df_probs.at[idx, "p_win"] = float(p)
        # Fill remaining rows by ffill within group to get per-row probabilities
        if s_col or y_col:
            group_cols = [c for c in (s_col, y_col) if c is not None]
            df_probs = df_probs.sort_values(group_cols + ([t_col] if t_col else [])).groupby(group_cols).apply(lambda g: g.ffill()).reset_index(drop=True)
        else:
            df_probs = df_probs.ffill()
    else:
        p_all = best_model.predict(X, verbose=0).ravel()
        df_probs = df.copy()
        df_probs["p_win"] = p_all
    s_col, y_col, t_col = _resolve_cols(df_probs)
    slice_probs = []
    if all(c is not None for c in (s_col, y_col, t_col)):
        gb = df_probs.groupby([s_col, y_col, t_col])["p_win"].mean().reset_index()
        for _, row in gb.iterrows():
            slice_probs.append({
                "strategy": str(row[s_col]),
                "symbol": str(row[y_col]),
                "timeframe": int(row[t_col]) if not pd.isna(row[t_col]) else -1,
                "p_win": float(row["p_win"]),
            })

    # Write policy.json to Common Files (with optional slice_probs)
    threshold = float(min_conf) if min_conf is not None else float(best_thresh)
    path = write_policy(min_confidence=threshold, common_dir=common_dir, slice_probs=slice_probs if slice_probs else None)
    print(f"Saved model to {os.path.join(out_dir, 'tf_model.keras')}")
    print(f"Saved scaler to {os.path.join(out_dir, 'scaler.pkl')}")
    print(f"Saved feature list to {os.path.join(out_dir, 'features.json')}")
    print(f"Saved policy to {path} (min_confidence={threshold:.2f}, slices={len(slice_probs)})")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--common", type=str, default=None, help="Override Common Files DualEA dir")
    ap.add_argument("--epochs", type=int, default=15)
    ap.add_argument("--batch", type=int, default=256)
    ap.add_argument("--splits", type=int, default=3)
    ap.add_argument("--min_conf", type=float, default=None, help="Force min_confidence for policy.json")
    ap.add_argument("--model", type=str, default="dense", choices=["dense", "lstm"], help="Model type to train")
    ap.add_argument("--seq_len", type=int, default=30, help="Sequence length for LSTM")
    args = ap.parse_args()
    train(args.common, args.epochs, args.batch, args.splits, args.min_conf, args.model, args.seq_len)
