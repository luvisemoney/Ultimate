"""Stdlib-only tests for safe wrapper argv and observed-outcome audits.

Run with a Python installation: python -m unittest discover -s ML -p test_legacy_entrypoints.py
These tests never train, connect to a broker, or install packages.
"""
import contextlib
import csv
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import snapshot_dataset
import snapshot_export_onnx
import snapshot_train


class LegacyEntrypointTests(unittest.TestCase):
    def test_training_command_is_argument_vector_with_symbols(self):
        command = snapshot_train.build_command("USDCHF, EURUSD", "artifacts/universal")
        self.assertEqual(command[0], "powershell.exe")
        self.assertIn("Build-MarketModel.ps1", command[5])
        self.assertEqual(command[-2:], ["-Symbols", "USDCHF,EURUSD"])

    def test_empty_duplicate_and_control_character_symbols_rejected(self):
        for value in ("", "USDCHF,,EURUSD", "USDCHF,usdchf", "USDCHF,\nEURUSD"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                snapshot_train.build_command(value, "output")

    def test_dry_run_does_not_launch_training(self):
        output = io.StringIO()
        with patch.object(snapshot_train.subprocess, "run") as run, contextlib.redirect_stdout(output):
            self.assertEqual(snapshot_train.main(["--dry-run", "--symbols", "USDCHF"]), 0)
        run.assert_not_called()
        self.assertIn("-Symbols", json.loads(output.getvalue()))

    def test_status_training_argument_is_not_supported(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
            snapshot_train.main(["--label_mode", "status"])
        self.assertEqual(error.exception.code, 2)

    def test_old_label_and_feature_apis_fail_explicitly(self):
        for function in (snapshot_dataset.label_from_status,
                         snapshot_dataset.labels_from_future_prices,
                         snapshot_dataset.load_snapshot_dataframe,
                         snapshot_dataset.build_feature_matrix):
            with self.subTest(function=function.__name__), self.assertRaisesRegex(RuntimeError, "retired"):
                function(None)

    def test_export_uses_single_native_exporter(self):
        command = snapshot_export_onnx.build_command("input directory", "output directory")
        self.assertIn("Export-MarketModel.ps1", command[5])
        self.assertEqual(command[6], "-InputDirectory")
        self.assertEqual(command[8], "-OutputDirectory")

    def test_legacy_pickle_override_is_rejected(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
            snapshot_export_onnx.main(["--artifacts", "old", "--scaler", "scaler.pkl"])
        self.assertEqual(error.exception.code, 2)

    def test_unicode_snapshots_are_inspected_without_labels(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "feature_batch_test.txt"
            path.write_text("timestamp:2025.01.01 00:00:00\nsymbol:USDCHF\nstatus:executed\n", encoding="utf-16")
            report = snapshot_dataset.inspect_snapshots(directory)
            self.assertEqual(report["records"], 1)
            self.assertEqual(report["symbols"], ["USDCHF"])
            self.assertFalse(report["training_supported"])
            self.assertNotIn("label", snapshot_dataset.parse_snapshot_file(path))

    def test_duplicate_snapshot_fields_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "feature_batch_bad.txt"
            path.write_text("symbol:USDCHF\nsymbol:EURUSD\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "duplicate"):
                snapshot_dataset.parse_snapshot_file(path)

    def _write_market_fixture(self, path, mutation=None):
        features = list(snapshot_dataset.MARKET_BASE_FEATURES + snapshot_dataset.ACTIVE_FEATURES)
        fields = ["decision_time", "target_end", "split", "symbol", "direction", "label",
                  "net_log_return", "entry_spread_points", "exit_spread_points", *features]
        rows = []
        for split, month in (("train", "01"), ("validation", "07"), ("test", "10")):
            for direction in (0, 1):
                rows.append(dict(decision_time=f"2025.{month}.02 00:00", target_end=f"2025.{month}.02 04:00",
                                 split=split, symbol="USDCHF", direction=direction, label=direction,
                                 net_log_return=0.001 if direction else -0.001,
                                 entry_spread_points=7, exit_spread_points=8,
                                 **{feature: 0.0 for feature in features}))
        for row in rows:
            row["mm_direction"] = 1.0 if row["direction"] == 0 else -1.0
            row["active_symbol_flag"] = 1.0
        if mutation:
            mutation(rows)
        with path.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=fields)
            writer.writeheader()
            writer.writerows(rows)

    def test_market_audit_accepts_observed_paired_purged_rows(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "dataset.csv"
            self._write_market_fixture(path)
            report = snapshot_dataset.audit_market_dataset(path)
            self.assertTrue(report["audit_passed"])
            self.assertEqual(report["rows"], 6)

    def test_unknown_labels_are_rejected_never_filled(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "dataset.csv"
            self._write_market_fixture(path, lambda rows: rows[0].update(label=""))
            with self.assertRaisesRegex(ValueError, "Unknown/malformed"):
                snapshot_dataset.audit_market_dataset(path)

    def test_split_boundaries_inferred_from_sibling_model_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "dataset.csv"
            self._write_market_fixture(path)
            content = path.read_text(encoding="utf-8")
            content = content.replace("2025.01.02", "2026.01.02").replace("2025.07.02", "2026.07.02").replace("2025.10.02", "2026.09.02")
            path.write_text(content, encoding="utf-8")
            metadata = {"training_end": "2026.07.01", "validation_end": "2026.09.01", "test_end": "2026.10.01"}
            (Path(directory) / "model_data.json").write_text(json.dumps(metadata), encoding="utf-8")
            report = snapshot_dataset.audit_market_dataset(path)
            self.assertTrue(report["audit_passed"])
            self.assertEqual(report["split_boundaries"], metadata)

    def test_explicit_boundaries_override_supplied_metadata_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "dataset.csv"
            self._write_market_fixture(path)
            metadata = Path(directory) / "alternate-model.json"
            metadata.write_text(json.dumps({"training_end": "2026.07.01", "validation_end": "2026.09.01", "test_end": "2026.10.01"}), encoding="utf-8")
            report = snapshot_dataset.audit_market_dataset(path, "2025.07.01", "2025.10.01", "2026.01.01", model_data=metadata)
            self.assertTrue(report["audit_passed"])
            self.assertEqual(report["split_boundaries"]["training_end"], "2025.07.01")

    def test_partial_metadata_does_not_silently_use_legacy_dates(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "dataset.csv"
            self._write_market_fixture(path)
            (Path(directory) / "model_data.json").write_text('{"training_end":"2026.07.01"}', encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "validation_end"):
                snapshot_dataset.audit_market_dataset(path)

    def test_horizon_crossing_split_boundary_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "dataset.csv"
            self._write_market_fixture(path, lambda rows: rows[0].update(target_end="2025.07.01 00:00"))
            with self.assertRaisesRegex(ValueError, "split boundary"):
                snapshot_dataset.audit_market_dataset(path)

    def test_duplicate_symbol_time_direction_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "dataset.csv"
            self._write_market_fixture(path, lambda rows: rows[1].update(rows[0]))
            with self.assertRaisesRegex(ValueError, "Duplicate"):
                snapshot_dataset.audit_market_dataset(path)


if __name__ == "__main__":
    unittest.main()
