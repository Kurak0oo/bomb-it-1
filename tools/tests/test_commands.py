import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class Commands(unittest.TestCase):
    def test_symbol_reports_original_removal_script_and_dependencies(self):
        result = subprocess.run([sys.executable, str(ROOT / "tools/inspect_symbol.py"),
                                 "237", "--frames", "6", "36", "--json"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(report["dependencies"], [232, 236])
        self.assertEqual(report["scripts"][-1], {"frame": 36, "source": "this.removeMovieClip();"})
        invalid = subprocess.run([sys.executable, str(ROOT / "tools/inspect_symbol.py"), "999999"],
                                 capture_output=True, text=True)
        self.assertNotEqual(invalid.returncode, 0)
        self.assertIn("Cannot inspect symbol", invalid.stderr)

    def check_runner(self, behavior):
        with tempfile.TemporaryDirectory(prefix="bomb it checks ") as directory:
            root = Path(directory)
            fake = root / "fake.py"
            fake.write_text("import sys,time\n"
                            "if '--version' in sys.argv: print('4.7.2.stable.fixture')\n"
                            "elif '--import' in sys.argv: print('imported')\n"
                            f"else: {behavior}\n", encoding="utf-8")
            if os.name == "nt":
                executable = root / "engine.cmd"
                executable.write_text(f'@"{sys.executable}" "{fake}" %*\n', encoding="utf-8")
            else:
                executable = root / "engine"
                executable.write_text(f'#!/bin/sh\nexec "{sys.executable}" "{fake}" "$@"\n')
                executable.chmod(0o755)
            result = subprocess.run([sys.executable, str(ROOT / "tools/run_checks.py"),
                                     "--godot", str(executable), "--suite", "sim", "--timeout", "2",
                                     "--output", str(root / "output")], capture_output=True, text=True, timeout=20)
            summary = json.loads((root / "output/summary.json").read_text())
            return result, summary

    def test_runner_imports_before_selected_suite(self):
        result, summary = self.check_runner("print('SIM_OK'); print('CORE_REFERENCE_CAPTURE_OK')")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual([phase["name"] for phase in summary], ["import", "sim", "bomb_expiry", "push_motion"])

    def test_runner_rejects_engine_error_even_with_zero_exit(self):
        result, summary = self.check_runner("print('SCRIPT ERROR: fixture'); print('SIM_OK')")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(summary[-1]["passed"])

    def test_runner_kills_a_stalled_suite(self):
        result, summary = self.check_runner("print('started', flush=True); time.sleep(30)")
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(summary[-1]["timeout"])


if __name__ == "__main__":
    unittest.main()
