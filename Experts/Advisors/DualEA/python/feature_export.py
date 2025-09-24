import os
import pyarrow as pa
import pyarrow.parquet as pq
from google.protobuf.json_format import MessageToDict
from dual_ea_pb2 import FeatureBatchEnvelope

EXPORT_DIR = r"C:\DualEA_FeatureBatches"  # Change as needed
os.makedirs(EXPORT_DIR, exist_ok=True)

# Helper: recursively convert protobuf FeatureValue to Python native
# Supports scalar, array, or nested object

def feature_value_to_py(val):
    if val.HasField("number"):
        return val.number
    if val.HasField("text"):
        return val.text
    if val.HasField("bool_value"):
        return val.bool_value
    if val.HasField("array"):
        return [feature_value_to_py(x) for x in val.array.items]
    if val.HasField("object"):
        return {k: feature_value_to_py(v) for k, v in val.object.fields.items()}
    # Forward compatibility: unknown
    if val.HasField("unknown"):
        return val.unknown
    return None

def feature_batch_to_py(batch):
    return {
        "symbol": batch.symbol,
        "strategy": batch.strategy,
        "timestamp": batch.timestamp,
        "features": [
            {
                "feature_name": f.feature_name,
                "value": feature_value_to_py(f.value)
            } for f in batch.features
        ],
        "extra": {k: feature_value_to_py(v) for k, v in batch.extra.items()}
    }

def envelope_to_py(envelope):
    return [feature_batch_to_py(b) for b in envelope.batches]

def write_batches_to_parquet(pb_bytes, fname=None):
    """
    Accepts raw protobuf bytes (FeatureBatchEnvelope), writes Arrow/Parquet.
    Retries up to 3x, falls back to CSV if needed.
    """
    import dual_ea_pb2
    import time
    from google.protobuf.message import DecodeError
    for attempt in range(3):
        try:
            envelope = dual_ea_pb2.FeatureBatchEnvelope()
            envelope.ParseFromString(pb_bytes)
            py_batches = envelope_to_py(envelope)
            table = pa.Table.from_pylist(py_batches)
            fname = fname or f"feature_batch_{int(time.time())}.parquet"
            path = os.path.join(EXPORT_DIR, fname)
            pq.write_table(table, path)
            return path
        except Exception as e:
            if attempt == 2:
                # Fallback to CSV
                import csv
                csv_fname = fname or f"feature_batch_{int(time.time())}.csv"
                csv_path = os.path.join(EXPORT_DIR, csv_fname)
                with open(csv_path, "w", newline="", encoding="utf-8") as f:
                    writer = csv.writer(f)
                    writer.writerow(["symbol", "strategy", "timestamp", "features", "extra"])
                    for row in py_batches:
                        writer.writerow([
                            row["symbol"], row["strategy"], row["timestamp"],
                            str(row["features"]), str(row["extra"])
                        ])
                return csv_path
            time.sleep(0.2)
    raise RuntimeError("Failed to export feature batch after retries.")
