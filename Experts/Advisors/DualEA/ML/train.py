"""Compatibility entry point for the audited real-history universal ONNX builder.

The former Keras pipeline fit preprocessing before chronological splitting.
All supported training now delegates to the same causal MQL5 implementation.
"""
from snapshot_train import main

if __name__ == "__main__":
    main()