# DualEA Build System

This directory contains the build system for the DualEA project, which helps compile all MQL5 files and analyze build logs.

## Prerequisites

- Windows operating system
- PowerShell 5.1 or later
- MetaTrader 5 with MetaEditor installed

## Files

- `build_all.ps1`: The main PowerShell build script
- `build_all.bat`: Batch wrapper for easy execution
- `build_logs/`: Directory containing build logs and error reports

## Usage

### Basic Usage

```bash
# Run a full build of all MQL5 files
.\build_all.bat

# Clean build logs and run a full build
.\build_all.bat -Clean
```

### Build Modes

```bash
# Build only include files (.mqh)
.\build_all.bat -Mode includes

# Build specific files (comma-separated)
.\build_all.bat -Mode specific -Files "PaperEA/PaperEA_v2.mq5,Include/PolicyEngine.mqh"

# Clean and build
.\build_all.bat -Clean -Mode all
```

### Viewing Logs

After building, check the following log files in the `build_logs` directory:

- `build_YYYYMMDD_HHMMSS.log`: Full build log
- `errors_YYYYMMDD_HHMMSS.log`: All errors from the build
- `warnings_YYYYMMDD_HHMMSS.log`: All warnings from the build

## Error Resolution

1. Check the error log for the specific file and line number
2. Fix the issue in your code
3. Re-run the build
4. Repeat until no errors remain

## Common Issues

### MetaEditor Not Found
Ensure MetaTrader 5 is installed in one of these locations:
- `C:\Program Files\MetaTrader 5\`
- `C:\Program Files (x86)\MetaTrader 5\`
- `C:\Program Files\new mt5\`

### PowerShell Execution Policy
If you get a PowerShell execution policy error, run this command as Administrator:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## License

This build system is part of the DualEA project.
