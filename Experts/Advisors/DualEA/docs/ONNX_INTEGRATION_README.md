# PaperEA ONNX Integration Guide

This guide explains how to integrate ONNX Runtime inference into your PaperEA MQL5 Expert Advisor.

## Overview

The ONNX integration consists of:
- **Python Pipeline**: Trains XGBoost models and exports them to ONNX format
- **C++ Bridge DLL**: `PaperEA_OnnxBridge.dll` provides MQL5-compatible interface
- **ONNX Runtime**: Microsoft's high-performance inference engine

## Quick Start

### 1. Build the ONNX Bridge DLL

Run the build script:
```batch
cd "c:\Users\echuk\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\Advisors\DualEA"
build_onnx_bridge.bat
```

This will:
- Download ONNX Runtime v1.15.1
- Compile `PaperEA_OnnxBridge.dll`
- Copy DLL and dependencies to MQL5 Libraries folder

### 2. Train and Export ONNX Model

Run the ML pipeline:
```batch
cd "c:\Users\echuk\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\Advisors\DualEA\ML"
run_train_and_export.bat
```

This creates:
- `artifacts/signal_model.onnx` - ONNX model file
- `artifacts/onnx_config.ini` - Configuration with feature scaling
- `artifacts/onnx_config.json` - Metadata in JSON format

### 3. Copy ONNX Model to Libraries

Copy the generated ONNX model to your MQL5 Libraries:
```batch
copy "artifacts\signal_model.onnx" "%APPDATA%\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Libraries\"
copy "artifacts\onnx_config.ini" "%APPDATA%\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Libraries\"
```

## Manual Build Instructions

If the automated build fails, you can build manually:

### Prerequisites
- Visual Studio 2019/2022 with C++ development tools
- ONNX Runtime SDK

### Steps

1. **Download ONNX Runtime**:
   ```
   https://github.com/microsoft/onnxruntime/releases/download/v1.15.1/onnxruntime-win-x64-1.15.1.zip
   ```
   Extract to `onnxruntime/` directory

2. **Compile with Visual Studio**:
   ```cmd
   cl /LD /EHsc /MD /O2 ^
      /I"onnxruntime\include" ^
      PaperEA_OnnxBridge.cpp ^
      onnxruntime\lib\onnxruntime.lib ^
      /Fe:PaperEA_OnnxBridge.dll
   ```

3. **Copy files to MQL5 Libraries**:
   - `PaperEA_OnnxBridge.dll`
   - `onnxruntime\onnxruntime.dll`

## MQL5 Integration

### Function Declarations

Add these imports to your MQL5 code:

```mql5
#import "PaperEA_OnnxBridge.dll"
    int InitializeModel(string modelPath, string configPath);
    int PredictSignal(const double &features[], int featureCount, double &probability);
    void Cleanup();
    string GetLastError();
#import
```

### Usage Example

```mql5
// Global variables
int g_modelInitialized = 0;
string g_modelPath = "signal_model.onnx";
string g_configPath = "onnx_config.ini";

// Initialize model
int OnInit() {
    string modelPath = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Libraries\\" + g_modelPath;
    string configPath = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Libraries\\" + g_configPath;
    
    g_modelInitialized = InitializeModel(modelPath, configPath);
    if (g_modelInitialized == 0) {
        Print("ONNX Model initialization failed: ", GetLastError());
        return INIT_FAILED;
    }
    
    Print("ONNX Model initialized successfully");
    return INIT_SUCCEEDED;
}

// Predict signal
void PredictWithONNX(double &features[], double &probability) {
    if (g_modelInitialized == 0) {
        probability = 0.5; // Default neutral
        return;
    }
    
    int result = PredictSignal(features, ArraySize(features), probability);
    if (result == 0) {
        Print("ONNX Prediction failed: ", GetLastError());
        probability = 0.5; // Default neutral
    }
}

// Cleanup
void OnDeinit(const int reason) {
    if (g_modelInitialized == 1) {
        Cleanup();
        g_modelInitialized = 0;
    }
}
```

## File Locations

After setup, your files should be located at:

```
%APPDATA%\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Libraries\
├── PaperEA_OnnxBridge.dll      # Bridge DLL
├── onnxruntime.dll             # ONNX Runtime
├── signal_model.onnx            # Trained model
└── onnx_config.ini              # Configuration
```

## Troubleshooting

### Common Issues

1. **DLL Load Failed**:
   - Ensure Visual C++ Redistributable is installed
   - Check that both DLLs are in the Libraries folder
   - Verify Windows Defender isn't blocking the DLLs

2. **Model Initialization Failed**:
   - Check file paths are correct
   - Verify ONNX model file exists and is valid
   - Check config file format and content

3. **Prediction Failed**:
   - Ensure feature count matches model expectations
   - Check for NaN or infinite values in features
   - Verify model input/output names

### Debug Mode

Enable debug logging by modifying the C++ code:
```cpp
// In PaperEA_OnnxBridge.cpp, change this line:
g_env = std::make_unique<Ort::Env>(ORT_LOGGING_LEVEL_WARNING, "PaperEA_OnnxBridge");
// To:
g_env = std::make_unique<Ort::Env>(ORT_LOGGING_LEVEL_VERBOSE, "PaperEA_OnnxBridge");
```

### Performance Notes

- First inference may be slower (model loading overhead)
- Subsequent inferences are typically <1ms
- Consider batching predictions if high frequency needed
- Memory usage is minimal (~50MB for model + runtime)

## Configuration Format

The `onnx_config.ini` file contains:

```ini
# DualEA ONNX Runtime configuration
created=2024-01-22T14:30:00Z
version=1
feature_count=45
feature_names=feature1|feature2|...|featureN
scaler_mean=0.123|0.456|...|0.789
scaler_scale=1.234|0.567|...|1.890
input_name=input
output_name=output
label_mode=status
positive_status=PROFIT|CLOSE_PROFIT
```

This ensures consistent feature scaling between training and inference.

## Next Steps

1. Test the integration with your EA
2. Monitor prediction accuracy and performance
3. Set up automated model retraining pipeline
4. Consider model versioning for production deployment
