"""Readiness and refusal through the public iOS export command."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class IOSPreflightCommand(unittest.TestCase):
    def test_checked_in_configuration_is_ready_without_claiming_device_acceptance(self):
        with tempfile.TemporaryDirectory() as temporary:
            result = subprocess.run(
                [sys.executable, str(ROOT / "tools/ios_preflight.py"), "--godot", sys.executable,
                 "--output", temporary], capture_output=True, text=True, timeout=20)
            report = json.loads((Path(temporary) / "preflight.json").read_text())
            self.assertEqual(result.returncode, 2)
            self.assertTrue(report["configuration"]["valid"])
            self.assertEqual(report["configuration"]["orientation"], "both_landscape")
            self.assertEqual(report["configuration"]["physics_ticks_per_second"], 35)
            self.assertEqual(report["device_install"], "unverified")

    def test_missing_identity_refuses_readiness_and_reports_external_gates(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            environment = dict(os.environ)
            environment.pop("BOMB_IT_IOS_TEAM_ID", None)
            environment.pop("BOMB_IT_IOS_BUNDLE_ID", None)
            result = subprocess.run(
                [sys.executable, str(ROOT / "tools/ios_preflight.py"),
                 "--godot", sys.executable, "--output", str(output)],
                env=environment, capture_output=True, text=True, timeout=20)
            self.assertEqual(result.returncode, 2, result.stderr)
            report = json.loads((output / "preflight.json").read_text())
            self.assertIn("team_id", report["blockers"])
            self.assertIn("bundle_identifier", report["blockers"])
            self.assertIn("engine", report["blockers"])
            self.assertEqual(report["device_install"], "unverified")
            self.assertFalse(report["export_performed"])
            self.assertFalse(list(output.rglob("*.xcodeproj")))


if __name__ == "__main__":
    unittest.main()
