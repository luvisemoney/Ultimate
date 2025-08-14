import os
from typing import Optional

import tensorflow as tf


def build_classifier(input_dim: int,
                     hidden: Optional[list[int]] = None,
                     dropout: float = 0.1) -> tf.keras.Model:
    """Build a simple binary classifier for win-probability.

    Args:
        input_dim: number of input features
        hidden: list of hidden layer sizes
        dropout: dropout rate between dense layers
    """
    if hidden is None:
        hidden = [64, 32]

    inputs = tf.keras.Input(shape=(input_dim,), name="features")
    x = inputs
    for i, h in enumerate(hidden):
        x = tf.keras.layers.Dense(h, activation="relu", name=f"dense_{i}")(x)
        if dropout and dropout > 0:
            x = tf.keras.layers.Dropout(dropout, name=f"dropout_{i}")(x)
    outputs = tf.keras.layers.Dense(1, activation="sigmoid", name="p_win")(x)
    model = tf.keras.Model(inputs=inputs, outputs=outputs, name="dualEA_win_classifier")
    model.compile(optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
                  loss="binary_crossentropy",
                  metrics=[tf.keras.metrics.AUC(name="auc"), tf.keras.metrics.BinaryAccuracy(name="acc")])
    return model


def build_lstm(input_dim: int,
               seq_len: int = 30,
               lstm_units: Optional[list[int]] = None,
               dense: Optional[list[int]] = None,
               dropout: float = 0.1) -> tf.keras.Model:
    """Build an LSTM-based binary classifier for win-probability.

    Args:
        input_dim: number of per-timestep features
        seq_len: sequence length (timesteps)
        lstm_units: list of LSTM hidden sizes for stacked LSTMs
        dense: list of dense layer sizes after LSTM
        dropout: dropout rate applied after LSTM and dense layers
    """
    if lstm_units is None:
        lstm_units = [64]
    if dense is None:
        dense = [32]

    inputs = tf.keras.Input(shape=(seq_len, input_dim), name="seq_features")
    x = inputs
    for i, u in enumerate(lstm_units):
        # Use return_sequences=True for all but last LSTM
        return_seq = (i < len(lstm_units) - 1)
        x = tf.keras.layers.LSTM(u, return_sequences=return_seq, name=f"lstm_{i}")(x)
        if dropout and dropout > 0:
            x = tf.keras.layers.Dropout(dropout, name=f"lstm_dropout_{i}")(x)
    for j, h in enumerate(dense):
        x = tf.keras.layers.Dense(h, activation="relu", name=f"post_dense_{j}")(x)
        if dropout and dropout > 0:
            x = tf.keras.layers.Dropout(dropout, name=f"post_dropout_{j}")(x)
    outputs = tf.keras.layers.Dense(1, activation="sigmoid", name="p_win")(x)
    model = tf.keras.Model(inputs=inputs, outputs=outputs, name="dualEA_win_lstm")
    model.compile(optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
                  loss="binary_crossentropy",
                  metrics=[tf.keras.metrics.AUC(name="auc"), tf.keras.metrics.BinaryAccuracy(name="acc")])
    return model


def save_model(model: tf.keras.Model, out_dir: str) -> str:
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, "tf_model.keras")
    model.save(path)
    return path


def load_model(model_dir: str) -> tf.keras.Model:
    path = os.path.join(model_dir, "tf_model.keras")
    return tf.keras.models.load_model(path)

