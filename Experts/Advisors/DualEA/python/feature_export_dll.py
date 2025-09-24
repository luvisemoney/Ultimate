import ctypes
import os

# Define the argument and result types for the DLL
# Assume DLL is built as ExportFeatureBatch(void* pb_bytes, int pb_len, char* out_path, int out_path_len)

DLL_PATH = r"C:\DualEA_FeatureBatches\feature_export.dll"  # Adjust as needed

dll = ctypes.CDLL(DLL_PATH)

ExportFeatureBatch = dll.ExportFeatureBatch
ExportFeatureBatch.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_int]
ExportFeatureBatch.restype = ctypes.c_int

def export_feature_batch(pb_bytes: bytes) -> str:
    out_path_buf = ctypes.create_string_buffer(512)
    result = ExportFeatureBatch(
        ctypes.c_char_p(pb_bytes),
        len(pb_bytes),
        out_path_buf,
        ctypes.sizeof(out_path_buf)
    )
    if result != 0:
        raise RuntimeError(f"DLL ExportFeatureBatch failed with code {result}")
    return out_path_buf.value.decode('utf-8')

# Usage example (assuming you have pb_bytes):
# path = export_feature_batch(pb_bytes)
# print("Exported to:", path)
