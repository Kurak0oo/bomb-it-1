# Issue 14 — strict random recordings and original generation observations

The port now has an opt-in strict random boundary. Normal play still uses the existing Godot seeded generator and round-seed policy; this work does not claim that an equal seed reproduces Flash. Controlled recordings agree on **45 original board snapshots, 45 item drops and 505 shuffle controls**. Whole-session call streams remain different and are reported separately.

## Public checks

```powershell
python tools/run_checks.py --godot <Godot-4.7.2> --suite rng --suite campaign --suite pacing
python tools/capture_rng_reference.py --ffdec C:/Users/Eiji/AppData/Local/FFDec --godot <Godot-4.7.2> --output .artifacts/rng-reference
python tools/compare_rng.py godot/tests/fixtures/rng_original.json reference/issue-14-evidence/rebuilt.json --output .artifacts/rng-comparison.json
python tools/check_rng_release.py --godot <Godot-4.7.2> --templates C:/Users/Eiji/AppData/Roaming/Godot/export_templates/4.7.2.stable --output .artifacts/rng-release
```

The regular runner includes `rng`: boundary checks, replay of the retained original recording, and comparison. The independent capture command rebuilds the original SWF fixture, runs it in pinned Ruffle/Chromium, captures the port, and compares. `--require-full-stream` on the comparison command intentionally fails the currently different complete session stream. Malformed/incomplete captures return 2; actual component differences return 1. Rebuilt reports include the exact input recording SHA-256, preventing comparison of stale replay output against an edited tape.

## Boundary and source evidence

`OriginalRng.begin_recording()` records zero-based order, requested bound and returned integer. `begin_replay()` validates every entry; `next()` checks the requested bound before consuming it; `finish_replay()` rejects leftover entries. Invalid bounds/results/order, exhaustion and extra calls leave a terminal error and never reach the seeded backend. Failure returns a placeholder only to permit diagnostics; callers must check completion, and the public replay command fails explicitly. None of these guards relies on `assert`. The valid legacy integer-prefix interface remains available for existing fixtures. `GameState.setup_round` accepts an optional random source, and `GameSession.start` accepts an optional per-round factory; their default behavior is unchanged.

`BuildRngReference.java` retains the complete original Sprite 564 frame-1 and frame-2 action blocks and all character definitions. Its only changes within those blocks replace 27 `RandomNumber` sites with a recording call; FFDec's action-list insertion/removal preserves branch/function destinations, following the established #28 adapter. Each recording includes the original site address, global order, bound and result. The wrapper normally delegates to a real native random opcode; it controls only the five requested scene styles, explicit drop thresholds, and one shuffle boundary case. The original map, population, shuffle and drop algorithms execute as SWF bytecode, rather than translations in the source harness. Before/adapted hashes and patched addresses are retained in the source fixture.

The fixture observes initial topology and population for all five themes, enters original frame 2 for retry, and original frame 1 for stages 2–4. It compares 195 cells per snapshot, styles, weapon rotation, stage/index metadata and four spawn shields. Drop controls cover no drop, all six ordinary item branches and both selected specials. The drop comparison isolates a breakable cell from preceding geometry so it can expose an independent drop discrepancy. The source controller supplies idle parent UI/timer endpoints and disables polling after population; these are generation observations, not a full interactive campaign recording.

An additional `BuildRngReference.java ... --raw-control` run leaves both original action byte arrays unchanged. Across five complete timeline runs, 500 subsequent native source shuffles preserve all four values. The adapted capture reproduces another 500 shuffles and five forced `[3,1,2,3]` draw sequences from `[1,2,3,4]`, exercising the final prior-last/new-first swap and returning `[1,2,3,4]`. `issue-14-evidence/raw-control.json` retains all observations, original/adapted hashes and capture fingerprints. This full-timeline control distinguishes the #10 function-only fixture's duplicate-value anomaly; it does not certify Adobe Flash Player behavior. Ruffle runtime/browser details are retained with the recordings.

## Preserved policy differences

The complete source recording includes presentation randomness. Initially, six weapon-shuffle calls are followed by four music-shuffle calls before scene selection. The port's gameplay generator proceeds from weapon shuffle to scene selection; #10 owns an independent presentation generator for audio. The comparison retains the source music calls and reports the first requested-bound divergence, rather than silently removing them from a whole-session parity claim.

Source retry enters population directly, preserving topology, stage, weapon index and music index. The port currently constructs a fresh seeded round before restoring previous topology and repopulating with the previous generator. That discarded setup is retained in the observed session call stream. Subsequent port rounds restart from incremented seeds and perform setup shuffles; source continuation retains its stream and rotates existing arrays. Component replay explicitly selects the generation/weapon/drop segments for comparison while leaving all original calls in the fixture. No padding draws, timer changes, RNG retuning or session-policy correction was introduced to force agreement. The original retry music index remains unchanged; this concrete observation was supplied to #10.

## Validation

Red/green checks first exposed absent recording APIs, missing strict failures, absent session injection, missing comparison, malformed paired captures, and stale-tape acceptance. Negative controls cover invalid result/order/type, changed bound, exhaustion/extra calls, unconsumed records, missing source provenance, truncated paired boards/themes, failed completion reports, and changed topology. The full-stream gate also fails as intended. Retained source fixtures require exact original frame hashes and complete theme/phase/cell/control inventories.

The standalone release probe exports the production simulation classes and the same public RNG boundary checks into the actual Windows release template. Its tiny scene adapts only the test runner's SceneTree/quit entry point; it checks that editor/debug features are absent. It passes the strict negative cases with assertions unavailable. This is a release-runtime guard check, not a game package, performance result or phone pass. Release logs, hashes, source controls, comparison and runner summaries are retained in `issue-14-evidence`.

Focused RNG, campaign/accounting and pacing checks plus all 46 tooling tests pass after syncing integration. The four source `60 + random(4)` initial shields are included in every population comparison; the port's existing `BoardGenerator.populate` already performs these draws. Normal seeded generation and pacing remain unchanged. Reviewed scope starts at `c2383e0`; generated `.import` rewrites are excluded. No shared visual baseline change is expected.
