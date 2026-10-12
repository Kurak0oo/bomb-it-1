import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class ReferenceComparison(unittest.TestCase):
    def test_core_profile_rejects_truncated_observations(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name, source in [("original", "original-swf-bytecode"), ("rebuilt", "godot-rebuild")]:
                (root / f"{name}.json").write_text(json.dumps({
                    "source": source, "runtime": "fixture", "profile": "core-v1", "fps": 35,
                    "tick_origin": "after-first-fixed-update-from-controlled-setup",
                    "scenarios": {"move_tap": [{"tick": 0}]}}))
            run = subprocess.run([sys.executable, str(ROOT / "tools/compare_traces.py"),
                                  str(root / "original.json"), str(root / "rebuilt.json"),
                                  "--output", str(root / "report.json")], capture_output=True, text=True)
            self.assertEqual(run.returncode, 2, run.stdout + run.stderr)

    def test_malformed_json_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for payload in [
                '{"source":"original-swf-bytecode","source":"original-swf-bytecode","runtime":"fixture","scenarios":{"x":[{"tick":0,"energy":0}]}}',
                '{"source":"original-swf-bytecode","runtime":"fixture","scenarios":{"x":[{"tick":0,"energy":NaN}]}}',
            ]:
                with self.subTest(payload=payload):
                    (root / "original.json").write_text(payload)
                    (root / "rebuilt.json").write_text(payload.replace("original-swf-bytecode", "godot-rebuild"))
                    run = subprocess.run([sys.executable, str(ROOT / "tools/compare_traces.py"),
                                          str(root / "original.json"), str(root / "rebuilt.json"),
                                          "--output", str(root / "report.json")], capture_output=True, text=True)
                    self.assertEqual(run.returncode, 2, run.stdout + run.stderr)

    def compare_real(self, mutate=None):
        evidence = ROOT / "reference/issue-11-evidence"
        original = json.loads((evidence / "original-trace.json").read_text(encoding="utf-8"))
        rebuilt = json.loads((evidence / "rebuilt-trace.json").read_text(encoding="utf-8"))
        if mutate:
            mutate(original, rebuilt)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name, data in [("original", original), ("rebuilt", rebuilt)]:
                (root / f"{name}.json").write_text(json.dumps(data), encoding="utf-8")
            run = subprocess.run([sys.executable, str(ROOT / "tools/compare_traces.py"),
                                  str(root / "original.json"), str(root / "rebuilt.json"),
                                  "--output", str(root / "report.json")], capture_output=True, text=True)
            report = json.loads((root / "report.json").read_text()) if (root / "report.json").exists() else None
            return run, report

    def test_real_captures_retain_the_observed_differences(self):
        run, report = self.compare_real()
        self.assertEqual(run.returncode, 1, run.stdout + run.stderr)
        self.assertEqual(report["first_divergence"], {"scenario":"move_tap", "tick":1,
                         "field":"pixelXTwips", "original":4899, "rebuilt":4900})

    def test_real_capture_field_perturbation_reports_exact_location(self):
        def perturb(original, rebuilt):
            rebuilt["scenarios"]["move_tap"][0]["shieldTicks"] += 1
        run, report = self.compare_real(perturb)
        self.assertEqual(run.returncode, 1, run.stdout + run.stderr)
        self.assertEqual(report["first_divergence"], {"scenario":"move_tap", "tick":0,
                         "field":"shieldTicks", "original":998, "rebuilt":999})

    def test_real_movement_completion_delayed_one_tick_is_detected(self):
        def perturb(original, rebuilt):
            rows = rebuilt["scenarios"]["move_tap"]
            rows[6] = dict(rows[5], tick=6)
        run, report = self.compare_real(perturb)
        self.assertEqual(run.returncode, 1, run.stdout + run.stderr)
        self.assertIn({"scenario":"move_tap", "tick":6, "field":"moving",
                       "original":False, "rebuilt":True}, report["differences"])
        self.assertIn({"scenario":"move_tap", "tick":6, "field":"moveRemaining",
                       "original":0, "rebuilt":1}, report["differences"])

    def test_real_capture_one_tick_perturbation_is_rejected(self):
        def perturb(original, rebuilt):
            rebuilt["scenarios"]["move_tap"][6]["tick"] += 1
        run, report = self.compare_real(perturb)
        self.assertEqual(run.returncode, 2, run.stdout + run.stderr)
        self.assertIn("out-of-order tick 6", run.stderr)
        self.assertIsNone(report)

    def test_real_captures_fail_closed_when_both_are_incomplete_or_malformed(self):
        changes = {
            "scenario": lambda c: c["scenarios"].pop("damage_growth"),
            "row": lambda c: c["scenarios"]["move_tap"].pop(),
            "field": lambda c: c["scenarios"]["move_tap"][0].pop("moving"),
            "boolean": lambda c: c["scenarios"]["move_tap"][0].update(moving=1),
            "bombs": lambda c: c["scenarios"]["move_tap"][0].update(bombs="undefined"),
            "profile": lambda c: c.pop("profile"),
            "origin": lambda c: c.update(tick_origin="before-update"),
            "configuration": lambda c: c.update(configuration_sha256="unknown"),
        }
        for name, change in changes.items():
            with self.subTest(name=name):
                def perturb(original, rebuilt):
                    change(original)
                    change(rebuilt)
                run, report = self.compare_real(perturb)
                self.assertEqual(run.returncode, 2, run.stdout + run.stderr)
                self.assertIsNone(report)

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
