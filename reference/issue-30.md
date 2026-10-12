# #30 — pushed-bomb acceptance audit

The #29 callback scheduler already resolves MOTION-01/03. This ticket adds independent acceptance coverage and a permanent public regression; it changes no production code, numeric values, 35 Hz timing, RNG policy or special phases. Starting revision: `822b806`.

`push-v1` reuses the seven established motion setups and source/rebuild adapters, adding owner bomb allowance because the earlier motion profile did not observe it. All 224 ticks × 27 fields (6,048 fields) match. The 26 existing fields exactly reproduce the #12 original rows. Source execution retains the unchanged original frame-1 functions and 5,624-byte frame-2 polling tag inside Sprite 564 with a real root parent; its provenance is validated by the public comparison command. Setup gives the owner allowance/capacity 3 and places one bomb, leaving allowance 2 before observation.

| Acceptance | Independently observed boundary |
| --- | --- |
| Activation/reservation | `push_corridor` tick 0 reserves (9,6), retains pixel x=240/logical (8,6), slideRemaining=2; tick 1 is the first half-step x=255, remaining=1. |
| Alignment rejection/perpendicular entry | `push_alignment` starts pre-pushed. At tick 0 the half-aligned reservation rejects downward entry; tick 1 completes/vacates (9,6), reserves (10,6), and the hero begins entering (9,6) in that same update. |
| Paused fuse | Normal fuse reaches 59 before push and stays 59 throughout sliding. `push_short_fuse` reaches 1 before push and stays 1 through tick 5. |
| Obstruction/detonation | Corridor bomb meets the wall after completing (11,6), detonates at tick 6 and refunds once to 3. Pre-pushed alignment reaches the same boundary at tick 5. |
| Blocked push | `push_blocked` remains stationary at (8,6), hero remains stationary, and its original fuse continues 59,58,… while allowance stays 2. |
| Expiry/chain before push | `push_expiring_fuse` and `push_energy_source` remove the bomb/refund to 3 at tick 0 before movement polling; the hero can begin entering the vacated cell. |
| Reserved-cell energy | `push_energy_reserved` crosses energy without replacing the installed movement callback with fuse/energy polling; its fuse remains 59 until obstruction detonation. |
| Normal movement/inventories | Hero movement/state observations match every push row; allowance stays within 0–3 and returns exactly once on detonation. Fresh full core and motion captures are identical to #29. |

The regression was replayed against the actual pre-#29 simulation files at `772802f`, preserving the #28 AI repair. The public capture script fails at `push_corridor` tick 0 (source x=240, rebuild x=255); the strict comparison reports 250 differing fields, including the newly observed allowance. Restoring the unchanged #30 starting implementation makes every row exact. No observation is shifted and no expected state is calculated from the port.

`tools/run_checks.py --suite sim` now includes `push_motion` beside expiry validation. Public comparison tests perturb the real first half-step, shift an alignment tick, remove a case from both captures, and remove original execution scope; all are detected. Fifteen focused phases pass, including tooling, simulation, expiry, push, actors/AI, specials/human ordering and the active 21,600-tick soak (508 bombs/151 specials). [Evidence](issue-30-evidence) retains source/rebuild rows, pre-correction differences, the red log, comparisons and runner results.

Reproduce source observation with `python tools/capture_core_reference.py --profile push-v1 --ffdec <FFDEC_HOME> --godot <Godot-4.7.2> --require-parity`. The public sim runner uses the preserved source reference without a browser dependency.

Retained limits: original bytecode is executed by Ruffle 0.7.1, not certified Adobe Flash. The fresh full core comparison retains six CORE-01 one-twip observations; full motion retains 72 grenade endpoint fields for #31. This audit changes neither #32/#33 accounting/local timing nor INTERACT-06's explicitly retained balanced cleanup deviation. Shared visual baselines are unchanged.

Latest integration `e7e85e3` was merged cleanly at `d246693`. All ten post-merge tooling/simulation phases pass, including the exact expiry and push gates. The ticket diff contains no production script changes.

Before integration merge, `f9f2538` (#18 performance runner/HUD animation correction) was synchronized at `4c68b3f`. All twelve combined tooling, simulation, expiry, push and pacing phases pass; both runner additions are retained.
