# #11 — Independent movement, damage and firing observations

The `core-v1` harness captures 10 scenarios, 252 fixed updates and 20 typed fields per update from original SWF bytecode and the accepted GameState. Three discrepancy groups remain explicit below. No production gameplay, timer, RNG or 35 Hz policy changed.

## Source independence and tick contract

`BuildReference.java` still preserves the 16 original Sprite 564 frame-1 functions (21,432 bytes). Its optional fourth argument also preserves the entire frame-2 DoAction block unchanged: 5,624 bytes, SHA-256 `b68c1872f3a1a9967dee94c3bae9d50ca9c52aab0caa357ea5d78de993e62a9b`. That original block installs `onKeyUp` and the polling/damage `onEnterFrame`; neither callback is translated into fixture logic. A prelude runs initialization on an empty stage, then `core_scenario.as` installs controlled cells, one human actor and an inert enemy that keeps outcome handling inactive. Existing three-argument builder callers are unchanged.

The fixture supplies Key.isDown/getCode values and invokes the original release callback on held-to-released edges before polling. It invokes the preserved parent callback once per sample. Original movHero, putBomb, putSpecial, hurtHero and bombExp install and execute their original child callbacks; their runtime dispatch order is not recreated in an expected trace. Sampling occurs after the original parent callback returns. Browser virtual time advances in 16 ms steps and pauses on every observation; the collector rejects skipped/extra ticks.

Configuration hashes normalize CRLF to LF so Windows and Linux checkouts share the same contract. Both sides read the same checked-in [input configuration](../godot/tests/fixtures/core_scenarios.json). Tick 0 means the first fixed update after controlled setup; no trace shifting, trimming or tolerance is applied. For explosion fixtures, setup ends immediately after detonation creates center energy, before the first growth update. The port reaches that setup through public bomb commands/ticks. Positions are recorded in integer twips (1/20 pixel), alongside cell, rounded cell, movement remaining, fire latch/readiness, bombs/fuses, mines, charges, life, armor, immunity and origin/probe energy.

## Observations

| Boundary | Observed result |
|---|---|
| Movement tap/hold | Starts at tick 0 with six updates remaining; tap completes at tick 6. Holding starts the next tile at tick 6. Cell and completion fields agree. |
| Buffered ordinary fire | Press during movement at ticks 2–3, release at 4; original prevFire survives release and places a bomb on arrival at tick 6. Port agrees. |
| Special hold/release | Mine at tick 0, movement at 1, no repeat while held. Release at 8 restores readiness; pressing at 9 places the second mine. Port agrees except the position quantization below. |
| Damage on growth | Adjacent armor is consumed at tick 0 after level-one growth, with 60 immunity ticks. All 20 fields agree through all 20 updates. |
| Rounded damage | Moving from x=8 toward energized x=9 consumes armor at tick 3 while logical cell remains 8; rounded cell becomes 9. Port agrees apart from one earlier twip. |
| Damage before expiry | Initial immunity 9 reaches zero at tick 8; armor is consumed at 9, before energy disappears at 10. All fields agree. |
| Damage at expiry | Initial immunity 10 reaches zero at 9; energy disappears at 10 before damage, so armor remains. All fields agree. |

### Separately identified correction candidates (not applied)

- **CORE-01, coordinate quantization:** movement's first interpolation from x=8 records 4,899 twips in Ruffle versus 4,900 in Godot. Six scenarios show this one-field difference; later positions and rounded damage agree. This may reflect AVM1/display-coordinate quantization. Adobe Flash behavior is unverified; do not round or shift the reference to hide it.
- **CORE-02, held ordinary bomb at expiry:** at ordinary_hold tick 60, the original child bomb has expired before parent fire polling and a replacement bomb already has fuse 60. The port has refunded the bomb but will poll replacement fire on tick 61. Continued held fire in active energy produces different subsequent bomb/energy counts. The original trace has 31 differing fields in this case. Any change to accepted update ordering needs its own reviewed correction, including chain-reaction consequences.
- **CORE-03, simultaneous movement and special fire:** original polling starts movement before calling putSpecial, whose moving guard rejects the placement. At tick 0 it retains three charges/readiness and no mine; it places at x=9 on arrival at tick 6. The port places at x=8 before movement, spending a charge and closing readiness immediately. This case has 33 field differences, including one CORE-01 coordinate difference. Preserve the evidence for a separate reviewed ordering correction.

[Original capture](issue-11-evidence/original-trace.json), [rebuilt capture](issue-11-evidence/rebuilt-trace.json), and [full comparison](issue-11-evidence/comparison.json) retain all 69 differing fields across 5,040 compared fields. Original metadata includes source SWF, fixture, source harness, builder, prelude, FFDec and Ruffle provenance. A second independent run produced exactly the same 252 observations for each runtime.

## Reproduction and validation

```powershell
python tools/capture_core_reference.py --ffdec C:/Users/Eiji/AppData/Local/FFDec --godot C:/Users/Eiji/AppData/Local/Godot/Godot_v4.7.2-stable_win64_console.exe --output .artifacts/core-reference
python tools/compare_traces.py reference/issue-11-evidence/original-trace.json reference/issue-11-evidence/rebuilt-trace.json --output .artifacts/core-comparison.json
python tools/run_checks.py --godot C:/Users/Eiji/AppData/Local/Godot/Godot_v4.7.2-stable_win64_console.exe --suite tooling --suite sim --suite special
```

The capture command exits 0 when collection and validation succeed, 2 on harness/contract errors, or 1 for observed differences when `--require-parity` is supplied. The comparison command exits 1 for these known differences; this is not an exact-parity pass. The repeat run with `--require-parity` exited 1 as intended.

The public comparison tests use these real captures. A one-field mutation of tick-0 immunity is reported at that exact location; delaying the movement completion observation by one tick reports movement/remaining differences at tick 6. A shifted tick number is rejected. Missing scenario/row/field/profile, wrong field types, malformed bomb serialization, mismatched origin/configuration, duplicate JSON keys and NaN are rejected, including when both inputs have the same defect. Truncated capture, duplicate-key/NaN and missing-profile tests were observed red before their fixes. The tooling runner also parses the new Godot capture script. The unchanged legacy builder/capture path produced all six 40-update scenarios successfully.

## Limits and review

These are controlled Ruffle 0.7.1 observations, not Adobe Flash Player certification or full-round parity. Source callbacks are relocated onto a controlled root with fixture inputs; UI/audio side effects and initial random map/actor generation are outside this observation boundary. Key injection tests polling/release semantics, not operating-system keyboard event delivery. Damage cases consume armor to avoid death RNG; special firing uses mines, not every weapon. No AI, score, campaign, map RNG or whole-game callback ordering is inferred from these fixtures. The three discrepancy groups are evidence, not authorization to alter accepted rules in this ticket.

The change is isolated to capture tooling, shared inputs, command-level tests and evidence. Review against starting integration `07e2919` confirms no production simulation files changed. Merged integration `d089de1` into this branch as `c32083c`; the seven focused phases (import, Python compile, tooling, legacy/core capture parse, simulation and special weapons) all passed afterward. [Check summary](issue-11-evidence/checks/summary.json) and command logs retain that evidence, including the initial truncated-capture red test.
