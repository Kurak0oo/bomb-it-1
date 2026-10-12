"""Public report command: measured intervals are never labelled photons."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class PerformanceReportTest(unittest.TestCase):
    def test_known_submission_intervals_and_input_clock_boundaries(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "raw.json"
            output = Path(directory) / "report.json"
            source.write_text(json.dumps({
                "target_hz": 60, "metadata": {"revision": "fixture"},
                "frames": [{"submission_interval_ms": n, "process_delta_ms": n,
                            "physics_cpu_ms": 1, "static_memory_bytes": 100}
                           for n in [10, 16, 20, 40]],
                "inputs": [{"kind": "move", "dispatch_us": 1000,
                            "delivered_us": 6000, "feedback_submission_us": 21000,
                            "source_wait_ticks": 0}],
            }))
            run = subprocess.run([sys.executable, str(ROOT / "tools/performance_report.py"),
                                  str(source), "--output", str(output)], capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
            report = json.loads(output.read_text())
            self.assertEqual(report["submission_intervals"]["p99_ms"], 40)
            self.assertEqual(report["submission_intervals"]["over_target_percent"], 50)
            self.assertEqual(report["input_dispatch_to_simulation"]["p95_ms"], 5)
            self.assertEqual(report["input_dispatch_to_feedback_submission"]["p95_ms"], 20)
            self.assertIsNone(report["physical_input_to_photon"])
            self.assertIsNone(report["presented_frame_intervals"])
            self.assertFalse(report["device_performance_signoff"])
            self.assertFalse(report["full_scenario_sequence_observed"])

    def test_rejects_feedback_before_simulation_delivery(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "raw.json"
            output = Path(directory) / "report.json"
            source.write_text(json.dumps({
                "target_hz": 60, "metadata": {}, "frames": [],
                "inputs": [{"dispatch_us": 1000, "delivered_us": 6000,
                            "feedback_submission_us": 5000}],
            }))
            run = subprocess.run([sys.executable, str(ROOT / "tools/performance_report.py"),
                                  str(source), "--output", str(output)], capture_output=True, text=True)
            self.assertNotEqual(run.returncode, 0)
            self.assertIn("clock endpoints", run.stderr)


if __name__ == "__main__":
    unittest.main()
