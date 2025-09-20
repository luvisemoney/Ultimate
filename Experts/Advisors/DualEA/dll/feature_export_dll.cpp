// feature_export_dll.cpp
// Full C++ DLL implementation (stdcall, Python embedding, raw protobuf bytes)
// Compile with: cl /LD feature_export_dll.cpp /I<python_include> /link /LIBPATH:<python_lib> python3x.lib
#include <windows.h>
#include <Python.h>
#include <string>

// Helper: Convert UTF-8 std::string to wide string
std::wstring utf8_to_wide(const std::string& str) {
    int size_needed = MultiByteToWideChar(CP_UTF8, 0, str.c_str(), (int)str.size(), NULL, 0);
    std::wstring wstrTo(size_needed, 0);
    MultiByteToWideChar(CP_UTF8, 0, str.c_str(), (int)str.size(), &wstrTo[0], size_needed);
    return wstrTo;
}

extern "C" __declspec(dllexport) int __stdcall ExportFeatureBatch(const void* pb_bytes, int pb_len, char* out_path, int out_path_len) {
    int result = 0;
    Py_Initialize();
    try {
        PyObject* sys_path = PySys_GetObject("path");
        PyList_Append(sys_path, PyUnicode_FromString("./python")); // or absolute path
        PyObject* module = PyImport_ImportModule("feature_export");
        if (!module) throw std::runtime_error("Could not import feature_export.py");
        PyObject* func = PyObject_GetAttrString(module, "write_batches_to_parquet");
        if (!func || !PyCallable_Check(func)) throw std::runtime_error("No write_batches_to_parquet");
        PyObject* py_bytes = PyBytes_FromStringAndSize((const char*)pb_bytes, pb_len);
        PyObject* args = PyTuple_Pack(1, py_bytes);
        PyObject* ret = PyObject_CallObject(func, args);
        if (!ret) throw std::runtime_error("Python call failed");
        const char* path = PyUnicode_AsUTF8(ret);
        if (!path) throw std::runtime_error("Return value not string");
        strncpy(out_path, path, out_path_len - 1);
        out_path[out_path_len - 1] = '\0';
        Py_XDECREF(ret);
        Py_XDECREF(args);
        Py_XDECREF(py_bytes);
        Py_XDECREF(func);
        Py_XDECREF(module);
    } catch (...) {
        result = -1;
    }
    Py_Finalize();
    return result;
}

BOOL APIENTRY DllMain(HMODULE hModule, DWORD ul_reason_for_call, LPVOID lpReserved) {
    return TRUE;
}
