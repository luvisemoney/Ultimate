import os
from typing import Optional

import tensorflow as tf


def build_classifier(input_dim: int,
                     hidden: Optional[list[int]] = None,
                     dropout: float = 0.1,
                     use_batch_norm: bool = True,
                     use_residual: bool = True) -> tf.keras.Model:
    """Build an optimized binary classifier with BatchNorm and Residual connections.

    Neurobook Chapter 6 optimizations:
    - Batch Normalization: accelerates convergence, allows higher learning rates
    - Residual connections: enables deeper networks without vanishing gradients

    Args:
        input_dim: number of input features
        hidden: list of hidden layer sizes (default: [128, 64, 32])
        dropout: dropout rate between dense layers
        use_batch_norm: enable Batch Normalization (recommended)
        use_residual: enable residual connections (recommended for deep nets)
    """
    if hidden is None:
        hidden = [128, 64, 32]

    inputs = tf.keras.Input(shape=(input_dim,), name="features")
    x = inputs

    # Initial projection if needed for residual
    prev_units = input_dim

    for i, h in enumerate(hidden):
        # Store input for residual connection
        residual = x

        # Dense layer with He initialization (Neurobook Chapter 1)
        x = tf.keras.layers.Dense(
            h,
            activation=None,  # Linear before BN
            kernel_initializer='he_normal',
            name=f"dense_{i}"
        )(x)

        # Batch Normalization (Neurobook Chapter 6)
        if use_batch_norm:
            x = tf.keras.layers.BatchNormalization(name=f"bn_{i}")(x)

        # Activation after BN (best practice)
        x = tf.keras.layers.Activation('relu', name=f"relu_{i}")(x)

        # Dropout for regularization
        if dropout and dropout > 0:
            x = tf.keras.layers.Dropout(dropout, name=f"dropout_{i}")(x)

        # Residual connection (Neurobook Chapter 6)
        if use_residual and prev_units == h:
            x = tf.keras.layers.Add(name=f"residual_{i}")([x, residual])

        prev_units = h

    outputs = tf.keras.layers.Dense(1, activation='sigmoid', name="p_win")(x)

    model = tf.keras.Model(inputs=inputs, outputs=outputs, name="dualEA_optimized_classifier")

    # Higher learning rate possible with BatchNorm (Neurobook Chapter 6)
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=3e-3),  # 3x higher with BN
        loss='binary_crossentropy',
        metrics=[
            tf.keras.metrics.AUC(name="auc"),
            tf.keras.metrics.BinaryAccuracy(name="acc"),
            tf.keras.metrics.Precision(name="precision"),
            tf.keras.metrics.Recall(name="recall")
        ]
    )
    return model


def build_attention_lstm(input_dim: int,
                         seq_len: int = 30,
                         lstm_units: Optional[list[int]] = None,
                         attention_heads: int = 4,
                         dense: Optional[list[int]] = None,
                         dropout: float = 0.1,
                         use_bidirectional: bool = True) -> tf.keras.Model:
    """Build Attention-based LSTM with Bidirectional processing.

    Neurobook Chapter 5 (Attention) + Chapter 4 (RNN) optimizations:
    - Self-Attention: captures long-range dependencies better than LSTM alone
    - Bidirectional: captures past AND future context
    - 2-3x better pattern recognition for time series

    Args:
        input_dim: number of per-timestep features
        seq_len: sequence length (timesteps)
        lstm_units: list of LSTM hidden sizes (default: [128, 64])
        attention_heads: number of attention heads (default: 4)
        dense: list of dense layer sizes after LSTM
        dropout: dropout rate applied after LSTM and dense layers
        use_bidirectional: enable bidirectional processing (recommended)
    """
    if lstm_units is None:
        lstm_units = [128, 64]
    if dense is None:
        dense = [32]

    inputs = tf.keras.Input(shape=(seq_len, input_dim), name="seq_features")
    x = inputs

    # Bidirectional LSTM layers (Neurobook Chapter 4)
    for i, u in enumerate(lstm_units):
        return_seq = True  # Keep sequences for attention

        lstm_layer = tf.keras.layers.LSTM(
            u,
            return_sequences=return_seq,
            kernel_initializer='he_normal',
            name=f"lstm_{i}"
        )

        if use_bidirectional and i == 0:  # Bidirectional on first layer
            x = tf.keras.layers.Bidirectional(
                lstm_layer,
                name=f"bilstm_{i}"
            )(x)
        else:
            x = lstm_layer(x)

        if dropout and dropout > 0:
            x = tf.keras.layers.Dropout(dropout, name=f"lstm_dropout_{i}")(x)

    # Multi-Head Self-Attention (Neurobook Chapter 5)
    # Captures which time steps are most relevant
    attention_output = tf.keras.layers.MultiHeadAttention(
        num_heads=attention_heads,
        key_dim=lstm_units[-1] // attention_heads,
        name="self_attention"
    )(x, x)

    # Global average pooling across time dimension
    x = tf.keras.layers.GlobalAveragePooling1D(name="temporal_pooling")(attention_output)

    # Dense layers with Batch Normalization
    for j, h in enumerate(dense):
        x = tf.keras.layers.Dense(h, activation=None, name=f"post_dense_{j}")(x)
        x = tf.keras.layers.BatchNormalization(name=f"post_bn_{j}")(x)
        x = tf.keras.layers.Activation('relu', name=f"post_relu_{j}")(x)
        if dropout and dropout > 0:
            x = tf.keras.layers.Dropout(dropout, name=f"post_dropout_{j}")(x)

    outputs = tf.keras.layers.Dense(1, activation='sigmoid', name="p_win")(x)

    model = tf.keras.Model(inputs=inputs, outputs=outputs, name="dualEA_attention_lstm")
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
        loss='binary_crossentropy',
        metrics=[
            tf.keras.metrics.AUC(name="auc"),
            tf.keras.metrics.BinaryAccuracy(name="acc"),
            tf.keras.metrics.Precision(name="precision"),
            tf.keras.metrics.Recall(name="recall")
        ]
    )
    return model


def build_gru(input_dim: int,
              seq_len: int = 30,
              gru_units: Optional[list[int]] = None,
              dense: Optional[list[int]] = None,
              dropout: float = 0.1) -> tf.keras.Model:
    """Build GRU-based model - 25-30% faster than LSTM with similar accuracy.

    Neurobook Chapter 4: GRU is a lighter alternative to LSTM
    - Fewer parameters (no cell state)
    - Faster training and inference
    - Similar performance on most time series tasks

    Args:
        input_dim: number of per-timestep features
        seq_len: sequence length (timesteps)
        gru_units: list of GRU hidden sizes (default: [128, 64])
        dense: list of dense layer sizes after GRU
        dropout: dropout rate applied after GRU and dense layers
    """
    if gru_units is None:
        gru_units = [128, 64]
    if dense is None:
        dense = [32]

    inputs = tf.keras.Input(shape=(seq_len, input_dim), name="seq_features")
    x = inputs

    for i, u in enumerate(gru_units):
        return_seq = (i < len(gru_units) - 1)

        x = tf.keras.layers.GRU(
            u,
            return_sequences=return_seq,
            kernel_initializer='he_normal',
            name=f"gru_{i}"
        )(x)

        if dropout and dropout > 0:
            x = tf.keras.layers.Dropout(dropout, name=f"gru_dropout_{i}")(x)

    # Dense layers with Batch Normalization
    for j, h in enumerate(dense):
        x = tf.keras.layers.Dense(h, activation=None, name=f"post_dense_{j}")(x)
        x = tf.keras.layers.BatchNormalization(name=f"post_bn_{j}")(x)
        x = tf.keras.layers.Activation('relu', name=f"post_relu_{j}")(x)
        if dropout and dropout > 0:
            x = tf.keras.layers.Dropout(dropout, name=f"post_dropout_{j}")(x)

    outputs = tf.keras.layers.Dense(1, activation='sigmoid', name="p_win")(x)

    model = tf.keras.Model(inputs=inputs, outputs=outputs, name="dualEA_gru")
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
        loss='binary_crossentropy',
        metrics=[
            tf.keras.metrics.AUC(name="auc"),
            tf.keras.metrics.BinaryAccuracy(name="acc")
        ]
    )
    return model


def build_lstm(input_dim: int,
               seq_len: int = 30,
               lstm_units: Optional[list[int]] = None,
               dense: Optional[list[int]] = None,
               dropout: float = 0.1,
               use_batch_norm: bool = True) -> tf.keras.Model:
    """Build an optimized LSTM-based binary classifier.

    Legacy wrapper with Neurobook Chapter 6 improvements (BatchNorm).

    Args:
        input_dim: number of per-timestep features
        seq_len: sequence length (timesteps)
        lstm_units: list of LSTM hidden sizes (default: [128, 64])
        dense: list of dense layer sizes after LSTM
        dropout: dropout rate applied after LSTM and dense layers
        use_batch_norm: enable Batch Normalization
    """
    if lstm_units is None:
        lstm_units = [128, 64]
    if dense is None:
        dense = [32]

    inputs = tf.keras.Input(shape=(seq_len, input_dim), name="seq_features")
    x = inputs

    for i, u in enumerate(lstm_units):
        return_seq = (i < len(lstm_units) - 1)

        x = tf.keras.layers.LSTM(
            u,
            return_sequences=return_seq,
            kernel_initializer='he_normal',
            name=f"lstm_{i}"
        )(x)

        if dropout and dropout > 0:
            x = tf.keras.layers.Dropout(dropout, name=f"lstm_dropout_{i}")(x)

    for j, h in enumerate(dense):
        x = tf.keras.layers.Dense(h, activation=None, name=f"post_dense_{j}")(x)
        if use_batch_norm:
            x = tf.keras.layers.BatchNormalization(name=f"post_bn_{j}")(x)
        x = tf.keras.layers.Activation('relu', name=f"post_relu_{j}")(x)
        if dropout and dropout > 0:
            x = tf.keras.layers.Dropout(dropout, name=f"post_dropout_{j}")(x)

    outputs = tf.keras.layers.Dense(1, activation='sigmoid', name="p_win")(x)

    model = tf.keras.Model(inputs=inputs, outputs=outputs, name="dualEA_win_lstm")
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
        loss='binary_crossentropy',
        metrics=[
            tf.keras.metrics.AUC(name="auc"),
            tf.keras.metrics.BinaryAccuracy(name="acc"),
            tf.keras.metrics.Precision(name="precision"),
            tf.keras.metrics.Recall(name="recall")
        ]
    )
    return model


def build_model(model_type: str = "classifier", **kwargs) -> tf.keras.Model:
    """Factory function to build any model type by name.

    Available models (per Neurobook recommendations):
    - "classifier": Fast feed-forward with BatchNorm + Residual (Chapter 6)
    - "attention_lstm": Best accuracy with Self-Attention (Chapter 5)
    - "gru": 25-30% faster than LSTM (Chapter 4)
    - "lstm": Optimized LSTM with BatchNorm (Chapter 6)

    Args:
        model_type: one of ["classifier", "attention_lstm", "gru", "lstm"]
        **kwargs: passed to the specific builder function

    Returns:
        Compiled tf.keras.Model
    """
    builders = {
        "classifier": build_classifier,
        "attention_lstm": build_attention_lstm,
        "gru": build_gru,
        "lstm": build_lstm,
    }

    if model_type not in builders:
        raise ValueError(f"Unknown model_type: {model_type}. Choose from {list(builders.keys())}")

    return builders[model_type](**kwargs)


def export_to_onnx(model: tf.keras.Model, out_dir: str, opset: int = 13) -> str:
    """Export Keras model to ONNX format for MQL5 integration.

    Neurobook Chapter 3: ONNX Runtime integration for MQL5
    - Use opset 13+ for best compatibility
    - Dynamic batch size for inference flexibility

    Args:
        model: trained tf.keras.Model
        out_dir: output directory
        opset: ONNX opset version (default 13)

    Returns:
        Path to exported .onnx file
    """
    import tf2onnx
    import onnx

    os.makedirs(out_dir, exist_ok=True)
    onnx_path = os.path.join(out_dir, "model.onnx")

    # Convert to ONNX
    spec = (tf.TensorSpec((None,) + model.input_shape[1:], tf.float32, name="input"),)
    model_proto, _ = tf2onnx.convert.from_keras(model, input_signature=spec, opset=opset)

    # Save
    onnx.save(model_proto, onnx_path)

    return onnx_path


def save_model(model: tf.keras.Model, out_dir: str) -> str:
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, "tf_model.keras")
    model.save(path)
    return path


def load_model(model_dir: str) -> tf.keras.Model:
    path = os.path.join(model_dir, "tf_model.keras")
    return tf.keras.models.load_model(path)

