# #31 — grenade final-frame callback

The grenade callback now detonates after 18 timeline advances: input-created grenades on tick 18, grenades installed before tick 0 on tick 17. Its nested body starts on frame 1 and the original callback observes final frame 19 after those 18 advances. The only production change is this endpoint condition in `SpecialRules.tick_weapon`; the two-tile target, other ages, 35 Hz rate, numeric balance, charge/release gating, pulse duration, ownership, RNG and timer policy are unchanged. Starting revision: `f27fc93`.

## Independent execution and regression

`grenade-v1` reuses the original motion observer, adding initially installed grenades and owner allowance. Eighteen cases cover all four directions for both birth origins, solid/out-of-bounds rejection, breakable endpoint, a bomb at the endpoint, held Fire and release/refire. It observes 608 ticks × 27 fields (16,416 fields). The final capture is exact; before the endpoint correction it had 175 differing fields. Full source rows repeat unchanged before/after.

`grenadescore-v1` runs the original grenade/bomb interaction with real root score/life/allowance tables (32 ticks × 43 fields, 1,376 fields). Its 26 pre-fix differences are now zero. At tick 17 the initial grenade creates five pulses, chains actor 2's bomb, refunds actor 2 from 3 to 4, credits actor 2 with 1,000, and reduces victim 3 from three lives to two with shield 60. Grenade owner 1 receives no kill credit: the bomb overwrites the center energy owner before original parent damage polling. The next tick records shield 59 and growing bomb arms. These are captured source outcomes, not port-derived expectations.

Both profiles preserve the complete frame-2 polling/release bytecode (5,624 bytes; SHA-256 `b68c1872f3a1a9967dee94c3bae9d50ca9c52aab0caa357ea5d78de993e62a9b`) and original frame-1 function bodies inside Sprite 564 with a real root parent. The shared adapters only configure initial state, inject commands and observe public updates. Initial grenades use source `putSpecial`, with no shifted/trimmed ticks.

The public `special` runner now includes both independent reference gates. It failed at input tick 18 (`grenadeActive`: source false, rebuild true) before correction and passes afterward. Comparison tests perturb the real endpoint activity, tick-17 refund and an initial-grenade tick index; strict profile/configuration/provenance/case/field validation rejects malformed captures.

## Boundary and presentation

The source captures show the airborne body through frame 18, followed by removal and the five-cell cross on the next update. Rejected targets preserve charges. Successful placement consumes one charge and locks repeated held fire; release permits refire. Parent-created pulses exist at ticks 18–27 and clear at 28; initially installed grenade pulses exist at ticks 17–26 and clear at 27. The same ten-callback lifetime is retained after chain/brick interactions.

The public rendered phase `grenade_render` checks all four directions and both birth origins using the actual GameView: an airborne image precedes the endpoint, five pulses visibly replace it, and after ten more updates the image exactly returns to its empty-effect state. The former endpoint condition fails those checks; the correction passes (`GRENADE_RENDER_OK`). Six retained native screenshots show rightward before/endpoint/cleared states for both origins; the before and endpoint images were visually inspected. No shared baseline is updated here; the root owns the six new regression captures.

A supplemental source-only depth capture records input tick 8 / initial tick 7 at body frame 9 switching from origin depth 965 to target depth 1265. This means age 8. The GameView depth threshold correction belongs to concurrent #5 presentation work; #31 does not edit it. The supplemental observer/configuration/prelude and bytecode sidecar are retained under `depth`; these observations are not submitted as a strict main-profile parity pair.

## Checks and remaining limits

All 22 full headless phases pass, including source gates, original human/AI command controls, push/expiry, simulation, timeline, campaign, pacing and the 21,600-tick active soak (511 bombs / 149 specials; earlier impacts change subsequent play while seed/policy remain unchanged). Full motion is now exact (72 → 0 fields); interaction differences fall 132 → 106. Every non-grenade core/motion/interaction row is identical to the #29 control capture. CORE-01 retains six one-twip observations; #32 accounting, #33 gas/ice timing, and INTERACT-06 balanced-cleanup/source-runtime uncertainty remain unchanged.

One repeated browser capture rejected an extra sampled tick. Its failure log is retained; rerunning the identical source fixture passed, without accepting or shifting observations. Ruffle 0.7.1 executes source bytecode independently but does not certify Adobe Flash callback behavior.

Reproduce with `python tools/capture_core_reference.py --profile grenade-v1 --ffdec <FFDEC_HOME> --godot <Godot-4.7.2> --require-parity` and the same command using `grenadescore-v1`. The public runner's `--suite special` uses the preserved captures without browser dependencies. [Evidence](issue-31-evidence) retains original/rebuilt rows, pre/post comparisons, red logs, native captures, control comparisons and runner results.

Integration `4f27cc5` merged cleanly at `7b071f5`. All sixteen post-merge tooling/special/source/simulation/pacing phases pass. No shared baseline is modified.
