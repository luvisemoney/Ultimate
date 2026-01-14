import argparse
import datetime as dt
import hashlib
import json
import os
import pickle
from typing import Dict

import numpy as np
import xgboost as xgb
from skl2onnx import convert_sklearn
from skl2onnx.common.data_types import FloatTensorType


def _read_json(path: str) -> Dict:
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def _load_scaler(path: str):
    with open(path, "rb") as handle:
        scaler = pickle.load(handle)
    if not hasattr(scaler, "mean_") or not hasattr(scaler, "scale_"):
        raise ValueError("Scaler pickle is missing mean_/scale_ attributes")
    return scaler


def _write_json(dest: str, payload: Dict) -> None:
    with open(dest, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)


def _format_list(values) -> str:
    return "|".join(f"{float(v):.12g}" for v in values)


def _write_ini(dest: str, meta: Dict, scaler, input_name: str, output_name: str) -> None:
    feature_names = meta.get("features", [])
    lines = [
        "# DualEA ONNX Runtime configuration",
        f"created={dt.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')}",
        "version=1",
        f"feature_count={len(feature_names)}",
        f"feature_names={'|'.join(feature_names)}",
        f"scaler_mean={_format_list(getattr(scaler, 'mean_', np.zeros(len(feature_names))))}",
        f"scaler_scale={_format_list(getattr(scaler, 'scale_', np.ones(len(feature_names))))}",
        f"input_name={input_name}",
        f"output_name={output_name}",
        f"label_mode={meta.get('label_mode', 'status')}",
        f"positive_status={'|'.join(meta.get('positive_status', []))}",
    ]
    categorical = meta.get("categorical_mappings", {})
    for key, mapping in categorical.items():
        if isinstance(mapping, dict) and mapping:
            encoded = "|".join(f"{str(k)}:{int(v)}" for k, v in mapping.items())
            lines.append(f"cat_{key}={encoded}")
    with open(dest, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))


def convert_to_onnx(model: xgb.XGBClassifier, feature_count: int, opset: int):
    initial_type = [("input", FloatTensorType([None, feature_count]))]
    options = {id(model): {"zipmap": False, "raw_scores": False}}
    onnx_model = convert_sklearn(model, initial_types=initial_type, target_opset=opset, options=options)
    return (
        onnx_model.SerializeToString(),
        onnx_model.graph.input[0].name,
        onnx_model.graph.output[0].name,
    )


def main():
    parser = argparse.ArgumentParser(description="Convert trained XGBoost snapshot model to ONNX")
    parser.add_argument("--artifacts", type=str, default=os.path.join(os.getcwd(), "artifacts"))
    parser.add_argument("--model_json", type=str, default=None, help="Override path to xgb_model.json")
    parser.add_argument("--feature_meta", type=str, default=None, help="Override path to feature_meta.json")
    parser.add_argument("--scaler", type=str, default=None, help="Override path to scaler.pkl")
    parser.add_argument("--opset", type=int, default=17)
    parser.add_argument("--onnx_out", type=str, default=None, help="Destination ONNX path")
    parser.add_argument("--config_json", type=str, default=None, help="Destination JSON metadata path")
    parser.add_argument("--config_ini", type=str, default=None, help="Destination INI metadata path")
    args = parser.parse_args()

    artifacts = os.path.abspath(args.artifacts)
    model_path = args.model_json or os.path.join(artifacts, "xgb_model.json")
    feature_meta_path = args.feature_meta or os.path.join(artifacts, "feature_meta.json")
    scaler_path = args.scaler or os.path.join(artifacts, "scaler.pkl")
    onnx_path = args.onnx_out or os.path.join(artifacts, "signal_model.onnx")
    config_json_path = args.config_json or os.path.join(artifacts, "onnx_config.json")
    config_ini_path = args.config_ini or os.path.join(artifacts, "onnx_config.ini")

    os.makedirs(artifacts, exist_ok=True)

    meta = _read_json(feature_meta_path)
    feature_names = meta.get("features")
    if not feature_names:
        raise ValueError("feature_meta.json missing 'features'")
    feature_count = len(feature_names)

    scaler = _load_scaler(scaler_path)

    model = xgb.XGBClassifier()
    model.load_model(model_path)

    onnx_bytes, input_name, output_name = convert_to_onnx(model, feature_count, args.opset)
    with open(onnx_path, "wb") as handle:
        handle.write(onnx_bytes)

    payload = {
        "version": 1,
        "created": dt.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "onnx_model": {
            "path": onnx_path,
            "sha256": hashlib.sha256(onnx_bytes).hexdigest(),
            "input_name": input_name,
            "output_name": output_name,
            "opset": args.opset,
        },
        "features": feature_names,
        "categorical_mappings": meta.get("categorical_mappings", {}),
        "label_mode": meta.get("label_mode", "status"),
        "positive_status": meta.get("positive_status", []),
        "scaler": {
            "mean": getattr(scaler, "mean_", np.zeros(feature_count)).tolist(),
            "scale": getattr(scaler, "scale_", np.ones(feature_count)).tolist(),
        },
    }

    _write_json(config_json_path, payload)
    _write_ini(config_ini_path, meta, scaler, input_name, output_name)

    print(f"[OK] ONNX model written to {onnx_path}")
    print(f"[OK] Config JSON written to {config_json_path}")
    print(f"[OK] Config INI written to {config_ini_path}")


if __name__ == "__main__":
    main()
