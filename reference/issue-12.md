# #12 — Pushed bombs and grenade endpoints

The `motion-v1` profile independently captures 15 scenarios, 480 fixed updates and 26 fields per update. The comparison retains 309 field differences. No production gameplay, timer, RNG or 35 Hz rule changed.

## Independent source and observation contract

This extends the [#11 bytecode harness](issue-11.md). The original 16 Sprite 564 frame-1 functions and complete frame-2 polling/release action block are still preserved unchanged. `motion_scenario.as` installs controlled board/actor/input state and observes the original `putBomb`, `pushBomb`, `movHero`, `putSpecial`, `addBrickExp` and child callbacks. Original grenade symbols 310 and nested bodies 307/308/309 remain executable timeline definitions; the observer reads `body._currentframe`, rather than calculating source grenade age.

Both runtimes use [the same configuration](../godot/tests/fixtures/motion_scenarios.json), at 35 Hz, with tick 0 the first update after setup. Samples are taken after original parent polling or a complete GameState tick. Original child dispatch remains native to Ruffle. No samples are shifted, trimmed, rounded to whole pixels or tolerated away. Provenance includes runtime/browser, original SWF, fixture, unchanged frame-2 action bytes, FFDec, source fixture, builder, collector, prelude and normalized configuration hashes.

Fixtures include a corridor push, short/expiring fuse, energy on the starting/reserved cell, blocked push, an already-moving bomb alignment attempt, four grenade directions, solid/out-of-bounds targets, a breakable target and a bomb at the grenade endpoint. Each runs for 32 updates. Source setup uses original placement/push/pulse functions. The port places bombs through public commands; the already-moving fixture explicitly initializes the corresponding public BombState fields before tick 0. It supplies no expected trace or callback implementation.

Fields distinguish the bomb's logical completed cell, forward cell reservation, fixed-update pixel position in twips, fuse, slide remainder and activity. Port positions use the interpolation GameView displays from public BombState fields. Grenade observations distinguish origin, target, root position, nested timeline frame and activity; root position is not a measurement of the drawn airborne arc. Sorted full-board energy, occupancy and blocked-cell strings retain relevant cells, including chain/expiry effects. Absent objects have explicit sentinel fields. Profile validation requires every named case, all 32 contiguous rows, exact fields/types, matching configuration/tick origin and valid cell serialization.

## Observed boundaries and separate correction candidates

| Finding | Original bytecode versus accepted rebuild |
|---|---|
| **MOTION-01: push start/update order** | In push_corridor tick 0, both reserve (9,6) while the completed cell is (8,6). Original remains at 4,800 twips with two slide updates remaining; port is already at 5,100 with one remaining. Original fuse first decrements to 59; port retains 60. The bomb stops against x=12 and detonates at (11,6) on tick 6 versus tick 5. |
| **MOTION-02: expiry/chain before a push** | With initial fuse 1, or energy at the original (8,6) cell, the source bomb detonates before parent movement polling at tick 0. The port's hero pushes first and the bomb survives until it stops at (11,6), tick 5. These are different detonation cells as well as timing. |
| **MOTION-03: cell entry after alignment** | A pre-pushed bomb starts with the same reservation and state on both sides. At tick 0 it is halfway between cells; both reject a perpendicular push into its reservation. All bomb movement, fuse, occupancy and explosion fields then agree. At tick 1 the source bomb has vacated (9,6) before hero polling, allowing movement; the port starts the hero at tick 2. Only three hero fields differ. |
| **MOTION-04: grenade timeline endpoint** | All four directions agree on target, origin, root position, active frame progression and charge/release behavior through tick 17 (body frame 18). Original callback observes its final body frame and removes/detonates at tick 18; port stays active at frame 19 and detonates at tick 19. The five-cell pulse expires at tick 28 versus 29. Brick clearing and the grenade-triggered bomb chain have the same one-tick boundary difference. |

Other established observations:

- Once sliding, the original callback does not decrement the fuse or inspect chain energy. A short fuse remains at 1 until obstruction; energy in the forward reservation also does not interrupt the slide. The port follows that rule, with MOTION-01's start offset.
- A blocked push never starts motion; fuse/activity and all other fields agree across all 32 ticks.
- Solid and out-of-bounds grenade targets reject placement, keep charges and produce no pulse; all fields agree.
- Valid grenade endpoints are two tiles away and affect the endpoint plus eligible cardinal neighbors. Their eventual cell sets agree. Source breakable-target clearing introduces no random drop in these fixtures.

These are bounded, evidence-backed correction candidates, not changes applied in this ticket. They require separate reviewed ordering/timeline fixes. In particular, moving the whole bomb pass or adjusting all projectile ages from one fixture would be unjustified.

## Evidence and reproduction

[Original trace](issue-12-evidence/original-trace.json), [rebuilt trace](issue-12-evidence/rebuilt-trace.json), and [comparison](issue-12-evidence/comparison.json) retain all observations. Reports now include the first differing tick/field for every scenario, with null for exact matches, as well as the complete differences. Two independent executions produced identical 480-sample observations for each runtime. The 309 differences are retained across 12,480 compared fields; exact parity is not claimed. The repeated `--require-parity` run exited 1 as intended.

```powershell
python tools/capture_core_reference.py --profile motion-v1 --ffdec C:/Users/Eiji/AppData/Local/FFDec --godot C:/Users/Eiji/AppData/Local/Godot/Godot_v4.7.2-stable_win64_console.exe --output .artifacts/motion-reference
python tools/compare_traces.py reference/issue-12-evidence/original-trace.json reference/issue-12-evidence/rebuilt-trace.json --output .artifacts/motion-comparison.json
python tools/run_checks.py --godot C:/Users/Eiji/AppData/Local/Godot/Godot_v4.7.2-stable_win64_console.exe --suite tooling --suite sim --suite special
```

The capture command defaults to the existing core-v1 profile. Collection/validation succeeds with exit 0; `--require-parity` returns 1 for the observed differences. Malformed captures or harness failures return 2. Comparison itself returns 1 here.

Public command tests retain the observed first divergences, detect a one-cell grenade endpoint mutation and shifted tick, and reject shared missing cases/rows/fields, malformed energy strings and nonboolean activity. Existing core-profile validation/perturbation tests remain. The per-scenario report test was observed red before adding the report field. The public runner now parses the motion capture script as well as the existing scripts.

## Limits and review

This is controlled Ruffle 0.7.1 execution, not Adobe Flash certification. Source callbacks run in the preserved controlled-root setup described in #11; native keyboard delivery, whole-round maps/AI, sound, hit reactions and random drops are outside scope. There is one tracked bomb per fixture. The already-moving fixture tests alignment/entry from explicitly matched state; normal corridor cases separately exercise actual input-driven pushing. Grenade root/target/timeline observations do not certify the visual arc, z-order transition or every terrain arrangement. Display interpolation between 35 Hz updates is not measured.

Review against starting integration `6d28b66` confirms no production simulation or view edits. Final repeated-capture, integration-sync and focused-check evidence follows in the retained check records.
