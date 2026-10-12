# #28 — Movement before special fire

Simultaneous direction and fire now follow the preserved original polling order: update facing/start movement, then attempt the selected weapon. A moving actor cannot place a special; ordinary bombs still use its current cell. This is a single scheduling change in `GameState._tick_hero`, with no weapon-specific exceptions or changes to speed, fuse, damage, scores, RNG or 35 Hz timing.

## Source evidence and regression

Original Sprite 564 frame-2 lines 215–236 call `movHero` before `putSpecial`/`putBomb`. Frame-1 `movHero` lines 1021–1029 changes facing before testing the destination; `putSpecial` rejects moving actors, while `putBomb` has no moving guard. We captured these original functions and the complete unchanged polling bytecode through the nested #13 harness, with a real root parent and controlled input/board state.

Before the correction, fresh core observations exactly reproduced the retained #11 source trace. Its `special_move_and_fire` scenario had 33 differences: the port spent a charge and placed at (8,6) on tick 0; the source retained readiness/charges and placed at (9,6) on arrival at tick 6. After the correction, all placement, readiness, count and arrival observations match; the single tick-1 coordinate observation remains 4,899 versus 4,900 twips (CORE-01).

The new strict `order-v1` profile independently observes 28 cases: ordinary bombs and all six special weapons, each with held fire during a single step, a one-tick simultaneous tap, continued movement through another arrival, and blocked movement with release/repress. Each has 14 contiguous updates and 12 fields, for 4,704 exact comparisons. Fields capture logical cell, facing, motion/countdown, pending fire/readiness, bomb allowance/fuses, special charges and live special origins/directions. They deliberately measure the command boundary; the existing core profile separately retains pixel quantization.

Source observations established the neighboring behavior before the fix:

- Held special fire starts no weapon at tick 0, queues while moving and places at (9,6) on tick 6. Continuing direction through tick 6 starts another step, delaying placement to (10,6), tick 12.
- A one-tick simultaneous direction/fire tap starts movement and rejects the special; releasing before a later moving poll leaves no queued placement. This matches all six specials.
- A solid cell at (9,6) blocks movement but turns the actor right. Rocket and grenade launch right from (8,6), mine/gas place at that cell, and fire/ice reject the adjacent wall without consuming a charge or readiness. Grenade's target beyond that adjacent wall remains valid.
- Holding a successful special does not repeat; release rearms it. A blocked rocket can fire again after removal and release/repress. Ordinary-bomb cases already matched the source and remain unchanged.

The original rows are stored in [order_original.json](../godot/tests/fixtures/order_original.json), including bytecode/runtime/configuration provenance. `tools/run_checks.py --suite special` executes a `command_order` phase comparing all new runtime observations against those independent rows. Before the change this public regression failed at `rocket_move_hold`, tick 0, readiness; afterward every field passes. The complete before comparison had 668 differing fields; the repeated original capture is identical and the after comparison has zero. Public comparison tests also perturb an actual arrival charge and tick, proving detection rather than testing hand-translated expectations.

## Preserved controls and remaining differences

Fresh original core captures before/after are identical to each other and #11. Core differences fall from 69 to 37: six CORE-01 one-twip coordinate observations plus 31 CORE-02 ordinary held-bomb expiry/refire/energy observations. No other core fields differ. CORE-01 remains unresolved Ruffle-versus-Flash quantization; CORE-02 belongs to #29.

All 480 motion and 784 interaction rebuild rows remain identical to their retained #12/#13 captures, including the still-open differences. #30 push, #31 grenade, #32 accounting and #33 local special callback work are untouched. INTERACT-06 residual pulse energy remains a source/runtime uncertainty; the rebuild's cleanup is retained and this fix does not reproduce invisible danger.

## Evidence and validation

[Before order comparison](issue-28-evidence/order-before/comparison.json), [after order comparison](issue-28-evidence/order-after/comparison.json), [after core comparison](issue-28-evidence/core-after/comparison.json), [red public regression](issue-28-evidence/order-red/command_order.log), [green checks](issue-28-evidence/green/summary.json), and [unchanged controls](issue-28-evidence/unchanged-controls.json) retain the results. The original and rebuilt traces accompany the comparisons. Initial focused validation passes all ten phases, including the new command-order phase; 20 trace-comparison tests also pass after adding profile perturbation checks.

```powershell
python tools/capture_core_reference.py --profile order-v1 --ffdec C:/Users/Eiji/AppData/Local/FFDec --godot C:/Users/Eiji/AppData/Local/Godot/Godot_v4.7.2-stable_win64_console.exe --output .artifacts/order-reference --require-parity
python tools/capture_core_reference.py --profile core-v1 --nested --ffdec C:/Users/Eiji/AppData/Local/FFDec --godot C:/Users/Eiji/AppData/Local/Godot/Godot_v4.7.2-stable_win64_console.exe --output .artifacts/core-reference
python tools/run_checks.py --godot C:/Users/Eiji/AppData/Local/Godot/Godot_v4.7.2-stable_win64_console.exe --suite tooling --suite sim --suite special
```

Order capture uses nested source execution and exits zero with `--require-parity`. Core collection retains its diagnostic differences. No tick shifting, field tolerance or original baseline rewriting is used.

## Review and limits

Review against starting integration `ca793d7` finds only the movement/fire block order changed in production. All six weapon implementations and ordinary placement remain unchanged. New tests/captures use the approved public runner, original comparison and simulation state seams. No shared rendered baseline changes are expected.

This is controlled Ruffle execution of original bytecode, not Adobe Flash certification. The new 14-update profile isolates command/placement boundaries; it does not certify later projectile endpoints, all collision pairs, every terrain arrangement, native keyboard delivery or full-round AI. Existing independent profiles retain those separately observed limits and differences. A single requested cardinal direction is supplied per update; host input arbitration is outside scope.
