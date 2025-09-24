import os
import pyarrow as pa
import pyarrow.dataset as ds
import deltalake as dl

# Directory where Arrow/Parquet feature batches are written
FEATURE_DIR = r"C:\DualEA_FeatureBatches"
DELTA_DIR = r"C:\DualEA_DeltaLake"
os.makedirs(DELTA_DIR, exist_ok=True)

def ingest_to_delta():
    # Discover all Parquet files in the feature batch directory
    files = [os.path.join(FEATURE_DIR, f) for f in os.listdir(FEATURE_DIR) if f.endswith('.parquet')]
    if not files:
        print("No Parquet files found for ingestion.")
        return
    # Read all Parquet files into a single Arrow Table
    tables = [pa.parquet.read_table(f) for f in files]
    batch_table = pa.concat_tables(tables)
    # Write to Delta Lake
    dl.write_deltalake(DELTA_DIR, batch_table, mode="append")
    print(f"Ingested {len(files)} files to Delta Lake at {DELTA_DIR}")

if __name__ == "__main__":
    ingest_to_delta()
