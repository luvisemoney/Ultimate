"""Compatibility CLI for the supported real-history universal model pipeline.

Gate acceptance is not a financial outcome. The retired snapshot trainer used
fabricated single-class labels and preprocessing fitted before splitting.
This module delegates to the shared MQL5 pipeline, without Python ML packages.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import subprocess
import sys

TRAIN_SCRIPT = Path(__file__).resolve().with_name("Build-MarketModel.ps1")
DEFAULT_OUTPUT = Path(__file__).resolve().parent / "artifacts" / "universal"


def build_command(symbols: str | None, output_directory: str | Path) -> list[str]:
    command = ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass",
               "-File", str(TRAIN_SCRIPT), "-OutputDirectory",
               str(Path(output_directory).expanduser().resolve())]
    if symbols is not None:
        if any(ord(c) < 32 for c in symbols):
            raise ValueError("--symbols cannot contain control characters")
        names = [name.strip() for name in symbols.split(",")]
        if not names or any(not name for name in names):
            raise ValueError("--symbols must contain nonempty comma-separated broker symbols")
        if len({name.casefold() for name in names}) != len(names):
            raise ValueError("--symbols contains duplicate broker symbols")
        command.extend(["-Symbols", ",".join(names)])
    return command


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--symbols", help="Exact comma-separated broker symbols; omitted uses the supported default universe")
    parser.add_argument("--output-directory", "--out-dir", "--out_dir", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--dry-run", action="store_true", help="Print exact argv as JSON without training")
    args = parser.parse_args(argv)
    try:
        command = build_command(args.symbols, args.output_directory)
    except ValueError as error:
        parser.error(str(error))
    if args.dry_run:
        print(json.dumps(command, indent=2))
        return 0
    if not TRAIN_SCRIPT.is_file():
        parser.error(f"Training orchestrator is missing: {TRAIN_SCRIPT}")
    if sys.platform != "win32":
        parser.error("This pipeline requires Windows MetaTrader 5 and real broker history")
    try:
        return subprocess.run(command, check=False).returncode
    except OSError as error:
        parser.exit(1, f"Could not launch the real-history training pipeline: {error}\n")


if __name__ == "__main__":
    raise SystemExit(main())