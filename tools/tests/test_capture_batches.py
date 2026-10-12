"""Replay actual collector batch diagnostics through its public audit command."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

@unittest.skipUnless(shutil.which("node"), "Optional source browser collector requires Node")
class CaptureBatches(unittest.TestCase):
    def audit(self, tick, rows, attempt=1):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "batch.json"
            path.write_text(json.dumps({"expected_tick":tick,"observed":rows,"attempt":attempt}))
            return subprocess.run(["node",str(ROOT/"tools/reference/capture_core.mjs"),"--audit-sample-batch",str(path)],capture_output=True,text=True)

    def test_only_fresh_startup_double_dispatch_can_retry(self):
        run=self.audit(0,[{"tick":0},{"tick":1}])
        self.assertEqual(run.returncode,3,run.stdout+run.stderr)
        self.assertEqual(json.loads(run.stdout)["decision"],"retry-startup")
        for tick,rows,attempt in [(0,[{"tick":0},{"tick":1}],3),(1,[{"tick":0},{"tick":2}],1),(1,[{"tick":0},{"tick":1},{"tick":2}],1),(0,[{"tick":1}],1)]:
            run=self.audit(tick,rows,attempt)
            self.assertEqual(run.returncode,2,run.stdout+run.stderr)
            self.assertEqual(json.loads(run.stdout)["decision"],"reject")
        run=self.audit(2,[{"tick":0},{"tick":1},{"tick":2}])
        self.assertEqual(run.returncode,0,run.stdout+run.stderr)
        self.assertEqual(json.loads(run.stdout)["decision"],"accept")
