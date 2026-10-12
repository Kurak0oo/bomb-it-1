import json
import hashlib
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]


class RngComparison(unittest.TestCase):
    def test_changed_topology_and_full_stream_gate_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder=Path(temporary)
            rebuilt=json.loads((ROOT/"reference/issue-14-evidence/rebuilt.json").read_text())
            cell=rebuilt["scenarios"]["0"]["snapshots"]["initial/topology"]["cells"][0]
            cell[2]=(cell[2]+1)%3
            (folder/"changed.json").write_text(json.dumps(rebuilt))
            command=[sys.executable,str(ROOT/"tools/compare_rng.py"),str(ROOT/"godot/tests/fixtures/rng_original.json")]
            changed=subprocess.run(command+[str(folder/"changed.json"),"--output",str(folder/"changed-report.json")],capture_output=True,text=True,timeout=15)
            self.assertEqual(changed.returncode,1,changed.stdout+changed.stderr)
            full=subprocess.run(command+[str(ROOT/"reference/issue-14-evidence/rebuilt.json"),"--require-full-stream","--output",str(folder/"full-report.json")],capture_output=True,text=True,timeout=15)
            self.assertEqual(full.returncode,1,full.stdout+full.stderr)

    def test_malformed_records_and_incomplete_paired_captures_fail_closed(self):
        original=json.loads((ROOT/"godot/tests/fixtures/rng_original.json").read_text(encoding="utf-8"))
        rebuilt=json.loads((ROOT/"reference/issue-14-evidence/rebuilt.json").read_text(encoding="utf-8"))
        def invalid_result(a,b): a["scenarios"]["0"]["calls"][0]["result"]=6
        def invalid_order(a,b): a["scenarios"]["0"]["calls"][0]["order"]=1
        def truncated(a,b):
            a["scenarios"].pop("4");b["scenarios"].pop("4")
        def missing_board(a,b):
            a["scenarios"]["0"]["snapshots"]["retry/population"]["cells"].pop()
            b["scenarios"]["0"]["snapshots"]["retry/population"]["cells"].pop()
        def missing_provenance(a,b): a.pop("bytecode_adapter")
        def failed_replay(a,b): b["scenarios"]["0"]["replay"][0]["passed"]=False
        def stale_valid_record(a,b):
            row=a["scenarios"]["0"]["calls"][0];row["result"]=(row["result"]+1)%row["bound"]
        for mutate in [invalid_result,invalid_order,truncated,missing_board,missing_provenance,failed_replay,stale_valid_record]:
            with self.subTest(mutation=mutate.__name__), tempfile.TemporaryDirectory() as temporary:
                a=json.loads(json.dumps(original));b=json.loads(json.dumps(rebuilt));mutate(a,b)
                folder=Path(temporary);(folder/"a.json").write_text(json.dumps(a))
                if mutate != stale_valid_record:
                    b["original_capture_sha256"]=hashlib.sha256((folder/"a.json").read_bytes()).hexdigest()
                (folder/"b.json").write_text(json.dumps(b))
                result=subprocess.run([sys.executable,str(ROOT/"tools/compare_rng.py"),str(folder/"a.json"),str(folder/"b.json"),
                                       "--output",str(folder/"report.json")],capture_output=True,text=True,timeout=15)
                self.assertEqual(result.returncode,2,result.stdout+result.stderr)

    def test_original_components_match_but_full_policy_is_explicitly_different(self):
        with tempfile.TemporaryDirectory() as temporary:
            report=Path(temporary)/"report.json"
            result=subprocess.run([sys.executable,str(ROOT/"tools/compare_rng.py"),
                                   str(ROOT/"godot/tests/fixtures/rng_original.json"),str(ROOT/"reference/issue-14-evidence/rebuilt.json"),
                                   "--output",str(report)],capture_output=True,text=True,timeout=15)
            self.assertEqual(result.returncode,0,result.stderr+result.stdout)
            data=json.loads(report.read_text())
            self.assertTrue(data["components_equal"])
            self.assertFalse(data["full_session_equal"])
            self.assertEqual(data["snapshots_compared"],45)
            self.assertEqual(data["drops_compared"],45)
            self.assertEqual(data["shuffle_controls_compared"],505)


if __name__=="__main__":
    unittest.main()
