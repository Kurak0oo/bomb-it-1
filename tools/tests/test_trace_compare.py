import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class ReferenceComparison(unittest.TestCase):
    def test_accounting_capture_reports_credit_and_removed_owner_refund(self):
        run, report = self.compare_real(evidence_name="issue-32-evidence")
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
        def credit(original, rebuilt):
            rebuilt["scenarios"]["shield_bomb"][1]["hero1KillScore"] = 0
        run, report = self.compare_real(credit, "issue-32-evidence")
        self.assertEqual(run.returncode, 1, run.stdout + run.stderr)
        self.assertEqual(report["first_divergence"], {"scenario":"shield_bomb", "tick":1,
                         "field":"hero1KillScore", "original":1000, "rebuilt":0})
        def refund(original, rebuilt):
            rebuilt["scenarios"]["dead_owner_refund"][4]["hero1Bombs"] = 4
        run, report = self.compare_real(refund, "issue-32-evidence")
        self.assertEqual(run.returncode, 1, run.stdout + run.stderr)
        self.assertEqual(report["first_divergence"], {"scenario":"dead_owner_refund", "tick":4,
                         "field":"hero1Bombs", "original":3, "rebuilt":4})

    def test_accounting_capture_rejects_missing_score_and_shifted_immunity_tick(self):
        def missing(original, rebuilt):
            for capture in (original, rebuilt):
                capture["scenarios"]["shield_bomb"][1].pop("hero1KillScore")
        run, report = self.compare_real(missing, "issue-32-evidence")
        self.assertEqual(run.returncode, 2, run.stdout + run.stderr)
        def shift(original, rebuilt):
            rebuilt["scenarios"]["shield_invulnerability_boundary"][62]["tick"] = 63
        run, report = self.compare_real(shift, "issue-32-evidence")
        self.assertEqual(run.returncode, 2, run.stdout + run.stderr)
        self.assertIn("out-of-order tick 62", run.stderr)

    def test_grenade_endpoint_and_accounting_captures_are_exact(self):
        for evidence in ("issue-31-evidence", "issue-31-evidence/accounting"):
            run, report = self.compare_real(evidence_name=evidence)
            self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
        def endpoint(original, rebuilt):
            rebuilt["scenarios"]["grenade_right"][18]["grenadeActive"] = True
        run, report = self.compare_real(endpoint, "issue-31-evidence")
        self.assertEqual(run.returncode, 1, run.stdout + run.stderr)
        self.assertEqual(report["first_divergence"], {"scenario":"grenade_right", "tick":18,
                         "field":"grenadeActive", "original":False, "rebuilt":True})
        def refund(original, rebuilt):
            rebuilt["scenarios"]["grenade_bomb"][17]["hero2Bombs"] -= 1
        run, report = self.compare_real(refund, "issue-31-evidence/accounting")
        self.assertEqual(run.returncode, 1, run.stdout + run.stderr)
        self.assertEqual(report["first_divergence"], {"scenario":"grenade_bomb", "tick":17,
                         "field":"hero2Bombs", "original":4, "rebuilt":3})

    def test_grenade_capture_rejects_shifted_initial_endpoint(self):
        def shift(original, rebuilt):
            for capture in (original, rebuilt):
                capture["scenarios"]["initial_grenade_down"][17]["tick"] = 18
        run, report = self.compare_real(shift, "issue-31-evidence")
        self.assertEqual(run.returncode, 2, run.stdout + run.stderr)
        self.assertIn("out-of-order tick 17", run.stderr)

    def test_push_capture_reports_half_step_and_rejects_tick_shift(self):
        run, report = self.compare_real(evidence_name="issue-30-evidence")
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
        def half_step(original, rebuilt):
            rebuilt["scenarios"]["push_corridor"][0]["bombPixelXTwips"] += 300
        run, report = self.compare_real(half_step, "issue-30-evidence")
        self.assertEqual(run.returncode, 1, run.stdout + run.stderr)
        self.assertEqual(report["first_divergence"], {"scenario":"push_corridor", "tick":0,
                         "field":"bombPixelXTwips", "original":4800, "rebuilt":5100})
        def tick(original, rebuilt):
            rebuilt["scenarios"]["push_alignment"][1]["tick"] = 2
        run, report = self.compare_real(tick, "issue-30-evidence")
        self.assertEqual(run.returncode, 2, run.stdout + run.stderr)
        self.assertIn("out-of-order tick 1", run.stderr)

    def test_push_capture_requires_all_cases_and_original_scope(self):
        def missing(original, rebuilt):
            for capture in (original, rebuilt):
                capture["scenarios"].pop("push_alignment")
        run, report = self.compare_real(missing, "issue-30-evidence")
        self.assertEqual(run.returncode, 2, run.stdout + run.stderr)
        def scope(original, rebuilt):
            original["execution_scope"] = "controlled-root"
        run, report = self.compare_real(scope, "issue-30-evidence")
        self.assertEqual(run.returncode, 2, run.stdout + run.stderr)

    def test_expiry_capture_parity_and_exact_perturbations(self):
        run, report = self.compare_real(evidence_name="issue-29-evidence")
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
        def field(original, rebuilt):
            rebuilt["scenarios"]["ordinary_hold"][60]["bombsAvailable"] += 1
        run, report = self.compare_real(field, "issue-29-evidence")
        self.assertEqual(run.returncode, 1, run.stdout + run.stderr)
        self.assertEqual(report["first_divergence"], {"scenario":"ordinary_hold", "tick":60,
                         "field":"bombsAvailable", "original":2, "rebuilt":3})
        def tick(original, rebuilt):
            rebuilt["scenarios"]["ordinary_hold"][60]["tick"] = 61
        run, report = self.compare_real(tick, "issue-29-evidence")
        self.assertEqual(run.returncode, 2, run.stdout + run.stderr)
        self.assertIn("out-of-order tick 60", run.stderr)

    def test_expiry_rejects_missing_source_provenance(self):
        def perturb(original, rebuilt):
            original.pop("preserved_bytecode")
        run, report = self.compare_real(perturb, "issue-29-evidence")
        self.assertEqual(run.returncode, 2, run.stdout + run.stderr)

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

    def compare_real(self, mutate=None, evidence_name="issue-11-evidence"):
        evidence = ROOT / "reference" / evidence_name
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

    def test_motion_profile_rejects_incomplete_capture(self):
        def perturb(original, rebuilt):
            for capture in (original, rebuilt):
                capture["profile"] = "motion-v1"
        run, report = self.compare_real(perturb)
        self.assertEqual(run.returncode, 2, run.stdout + run.stderr)
        self.assertIn("motion-v1: incompatible configuration", run.stderr)

    def test_motion_capture_reports_first_divergence_for_each_scenario(self):
        run, report = self.compare_real(evidence_name="issue-12-evidence")
        self.assertEqual(run.returncode, 1, run.stdout + run.stderr)
        first = report["scenario_first_divergences"]
        self.assertEqual(first["push_corridor"], {"scenario":"push_corridor", "tick":0,
                         "field":"bombFuse", "original":59, "rebuilt":60})
        self.assertEqual(first["grenade_right"]["tick"], 18)
        self.assertEqual(first["grenade_right"]["field"], "energies")
        self.assertIsNone(first["push_blocked"])
        self.assertIsNone(first["grenade_edge"])

    def test_motion_real_field_and_tick_perturbations_are_detected(self):
        def field(original, rebuilt):
            rebuilt["scenarios"]["grenade_right"][0]["grenadeTargetX"] += 1
        run, report = self.compare_real(field, "issue-12-evidence")
        self.assertEqual(run.returncode, 1, run.stdout + run.stderr)
        self.assertIn({"scenario":"grenade_right", "tick":0, "field":"grenadeTargetX",
                       "original":10, "rebuilt":11}, report["differences"])
        def tick(original, rebuilt):
            rebuilt["scenarios"]["push_alignment"][1]["tick"] += 1
        run, report = self.compare_real(tick, "issue-12-evidence")
        self.assertEqual(run.returncode, 2, run.stdout + run.stderr)
        self.assertIn("out-of-order tick 1", run.stderr)
        self.assertIsNone(report)

    def test_motion_captures_reject_shared_truncation_and_malformed_cells(self):
        changes = {
            "scenario": lambda c: c["scenarios"].pop("push_alignment"),
            "row": lambda c: c["scenarios"]["grenade_right"].pop(),
            "field": lambda c: c["scenarios"]["grenade_right"][0].pop("grenadeFrame"),
            "cells": lambda c: c["scenarios"]["grenade_right"][0].update(energies="undefined"),
            "activity": lambda c: c["scenarios"]["grenade_right"][0].update(grenadeActive=1),
        }
        for name, change in changes.items():
            with self.subTest(name=name):
                def perturb(original, rebuilt):
                    change(original)
                    change(rebuilt)
                run, report = self.compare_real(perturb, "issue-12-evidence")
                self.assertEqual(run.returncode, 2, run.stdout + run.stderr)
                self.assertIsNone(report)

    def test_interaction_original_requires_real_parent_scope(self):
        def perturb(original, rebuilt):
            original["execution_scope"] = "controlled-root"
        run, report = self.compare_real(perturb, "issue-13-evidence")
        self.assertEqual(run.returncode, 2, run.stdout + run.stderr)
        self.assertIn("real root parent", run.stderr)
        self.assertIsNone(report)

    def test_interaction_capture_requires_bytecode_provenance(self):
        changes = [lambda c: c.pop("original_swf_sha256"),
                   lambda c: c["preserved_bytecode"].update(preserved_sha256="0"*64)]
        for change in changes:
            def perturb(original, rebuilt):
                change(original)
            run, report = self.compare_real(perturb, "issue-13-evidence")
            self.assertEqual(run.returncode, 2, run.stdout + run.stderr)
            self.assertIn("provenance", run.stderr)
            self.assertIsNone(report)

    def test_interaction_captures_report_damage_refund_and_overlap_boundaries(self):
        run, report = self.compare_real(evidence_name="issue-13-evidence")
        self.assertEqual(run.returncode, 1, run.stdout + run.stderr)
        first = report["scenario_first_divergences"]
        self.assertEqual(first["shield_bomb"], {"scenario":"shield_bomb", "tick":1,
                         "field":"hero1Score", "original":1000, "rebuilt":0})
        self.assertEqual(first["dead_owner_refund"]["tick"], 4)
        for name in ("overlap_ab", "overlap_ba", "ai_three_hits", "human_multi_life", "self_damage"):
            self.assertIsNone(first[name])

    def test_interaction_real_field_and_tick_perturbations_are_detected(self):
        def field(original, rebuilt):
            rebuilt["scenarios"]["overlap_ba"][1]["hero1Score"] -= 1000
        run, report = self.compare_real(field, "issue-13-evidence")
        self.assertEqual(run.returncode, 1, run.stdout + run.stderr)
        self.assertIn({"scenario":"overlap_ba", "tick":1, "field":"hero1Score",
                       "original":1000, "rebuilt":0}, report["differences"])
        def tick(original, rebuilt):
            rebuilt["scenarios"]["ai_three_hits"][66]["tick"] += 1
        run, report = self.compare_real(tick, "issue-13-evidence")
        self.assertEqual(run.returncode, 2, run.stdout + run.stderr)
        self.assertIn("out-of-order tick 66", run.stderr)
        self.assertIsNone(report)

    def test_interaction_captures_reject_shared_truncation_and_malformed_ownership(self):
        changes = {
            "scenario": lambda c: c["scenarios"].pop("dead_owner_refund"),
            "row": lambda c: c["scenarios"]["shield_bomb"].pop(),
            "field": lambda c: c["scenarios"]["shield_bomb"][0].pop("hero1Score"),
            "owners": lambda c: c["scenarios"]["shield_bomb"][0].update(owners="undefined"),
            "energy": lambda c: c["scenarios"]["shield_bomb"][0].update(energies="7,6,1;"),
            "alive": lambda c: c["scenarios"]["shield_bomb"][0].update(hero1Alive=1),
        }
        for name, change in changes.items():
            with self.subTest(name=name):
                def perturb(original, rebuilt):
                    change(original)
                    change(rebuilt)
                run, report = self.compare_real(perturb, "issue-13-evidence")
                self.assertEqual(run.returncode, 2, run.stdout + run.stderr)
                self.assertIsNone(report)

    def test_order_profile_matches_all_original_weapon_command_paths(self):
        run, report = self.compare_real(evidence_name="issue-28-evidence")
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
        self.assertTrue(report["passed"])
        self.assertIsNone(report["first_divergence"])

    def test_order_profile_detects_actual_charge_and_tick_changes(self):
        def field(original, rebuilt):
            rebuilt["scenarios"]["mine_move_hold"][6]["specialCount"] += 1
        run, report = self.compare_real(field, "issue-28-evidence")
        self.assertEqual(run.returncode, 1, run.stdout + run.stderr)
        self.assertEqual(report["first_divergence"], {"scenario":"mine_move_hold", "tick":6,
                         "field":"specialCount", "original":2, "rebuilt":3})
        def tick(original, rebuilt):
            rebuilt["scenarios"]["fire_blocked"][0]["tick"] = 1
        run, report = self.compare_real(tick, "issue-28-evidence")
        self.assertEqual(run.returncode, 2, run.stdout + run.stderr)
        self.assertIn("out-of-order tick 0", run.stderr)

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
