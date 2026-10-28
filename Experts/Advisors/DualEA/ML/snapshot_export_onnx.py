"""Export an audited universal model through its single native ONNX exporter.

Legacy pickle/XGBoost/status-label artifacts are intentionally unsupported.
The exporter consumes the real-history model_data.json training audit bundle.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import subprocess
import sys

EXPORT_SCRIPT = Path(__file__).resolve().with_name("Export-MarketModel.ps1")
DEFAULT_OUTPUT = Path(__file__).resolve().parent / "artifacts" / "universal"


def build_command(artifacts: str | Path, output_directory: str | Path) -> list[str]:
    return ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass",
            "-File", str(EXPORT_SCRIPT), "-InputDirectory",
            str(Path(artifacts).expanduser().resolve()), "-OutputDirectory",
            str(Path(output_directory).expanduser().resolve())]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifacts", required=True, help="MQL training output directory containing model_data.json")
    parser.add_argument("--output-directory", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--dry-run", action="store_true", help="Print exact argv as JSON without exporting")
    args = parser.parse_args(argv)
    command = build_command(args.artifacts, args.output_directory)
    if args.dry_run:
        print(json.dumps(command, indent=2))
        return 0
    if not EXPORT_SCRIPT.is_file():
        parser.error(f"Native ONNX exporter is missing: {EXPORT_SCRIPT}")
    model_data = Path(args.artifacts).expanduser().resolve() / "model_data.json"
    if not model_data.is_file():
        parser.error(f"Audited trained model_data.json is required: {model_data}")
    if sys.platform != "win32":
        parser.error("This entry point requires Windows PowerShell; no legacy Python export is performed")
    try:
        return subprocess.run(command, check=False).returncode
    except OSError as error:
        parser.exit(1, f"Could not launch the native ONNX exporter: {error}\n")


if __name__ == "__main__":
    raise SystemExit(main())