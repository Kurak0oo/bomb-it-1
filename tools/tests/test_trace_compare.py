import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class ReferenceComparison(unittest.TestCase):
    def test_port_generated_reference_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            capture = root / "capture.json"
            capture.write_text(json.dumps({"source":"godot-rebuild", "runtime":"fixture", "scenarios":{}}))
            run = subprocess.run([sys.executable, str(ROOT / "tools/compare_traces.py"), str(capture), str(capture),
                                  "--output", str(root / "report.json")], capture_output=True, text=True)
            self.assertEqual(run.returncode, 2)
            self.assertIn("original-swf-bytecode", run.stderr)

    def test_reports_first_divergent_tick_and_field(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            original = {"source": "original-swf-bytecode", "runtime": "fixture",
                        "scenarios": {"explosion": [{"tick":0,"armEnergy":0}, {"tick":1,"armEnergy":1}]}}
            rebuilt = {"source": "godot-rebuild", "runtime": "fixture",
                       "scenarios": {"explosion": [{"tick":0,"armEnergy":1}, {"tick":1,"armEnergy":1}]}}
            for name, data in [("original", original), ("rebuilt", rebuilt)]:
                (root / f"{name}.json").write_text(json.dumps(data))
            run = subprocess.run([sys.executable, str(ROOT / "tools/compare_traces.py"),
                                  str(root / "original.json"), str(root / "rebuilt.json"),
                                  "--output", str(root / "report.json")], capture_output=True, text=True)
            self.assertEqual(run.returncode, 1, run.stdout + run.stderr)
            report = json.loads((root / "report.json").read_text())
            self.assertEqual(report["first_divergence"], {"scenario":"explosion", "tick":0,
                             "field":"armEnergy", "original":0, "rebuilt":1})


if __name__ == "__main__":
    unittest.main()
