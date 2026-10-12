# Issue 21 — integrated desktop candidate

The integrated desktop behavior gates pass. Original-runtime exact parity remains false at the explicitly retained diagnostic boundaries below. Signed iPhone installation and physical device acceptance remain external (#20/#22); this desktop work does not satisfy them.

## Candidate and boundaries

Validation began at `af67fc49510de6ac9e9473c70b4fcb464305080a`, containing #2–#19 and corrections #28–#33. Integration `4e3b3c3` adds only the final Linux/CI evidence and ledgers. The normalized production fingerprint throughout this validation is `7a7ee81d9aa9511256aae99a2524813b5ed223b43df1acc141f58ae452d5e472`; performance instrumentation is `1e06833c310e17c0aa84f197d69e94b601542ba49668cd1b6653bd0ba65574d5`.

This ticket changes validation tooling only: the normal-close probe accepts a packaged executable without `--path` or test-script overrides, records its SHA-256, isolates preferences, and still requires clean stdout/stderr as well as exit zero. Its public `--package` invocation failed before that extension. The final executable invocation supplies the green evidence below. Fixture-only modes remain unavailable for packaged startup.

## Functional and reference results

- All **30 headless phases** pass, including 50 Python tooling tests, simulation, actors, campaigns, special weapons, audio, soak, schedule invariance and strict RNG replay.
- All **18 native phases** pass: import, view/timeline, and 15 rendered checks covering audio, grenade endpoint, interruptions, layout, selection, death, ordinary/special effects, results, HUD, actor feedback, input, menus, UI and visual timelines. These exercise 1P/2P transitions, source outcome timing, repeated routes, input isolation and saved audio behavior.
- Root's independent Linux gate passes **108/108 exact images**, plus all 19 phases. [Retained integration evidence](integration-screen-review/final-desktop/review.json) identifies image `8f52756b2528`, capture `3fd0e778e103`, and source `af67fc4`. Hosted CI run `38254723921` passes both jobs at docs-only `3855896`.
- Ten regenerated original gameplay comparisons are exact: motion, command order, bomb expiry, AI order, pushed bombs, grenade endpoints, grenade scoring, hit accounting, special contact and ice movement. Core retains six twip differences; interaction retains 14 residual-energy differences; dispatch retains 28 residual-energy differences. No tolerance, source timing, rule or RNG retuning was introduced.
- Strict RNG replay matches 45 board snapshots, 45 drops and 505 shuffle controls. Whole-session equality remains false: the accepted seeded backend and independent presentation RNG have different call order/results across initial setup, retries and stages. [Issue 14](issue-14.md) records the complete policy distinction.

The source SWF SHA-256 remains `a780f395a61bae8d0ddf9c0dfc1b75780046461c4197d949523c6eedf5969b0b`. [Recheck command](issue-21-evidence/recheck.py) regenerates current port output against the retained independent original captures, checks source identity, and retains each source fixture hash and exact comparator output. It does not regenerate or alter original observations. Existing source bytecode/control provenance remains in the linked ticket evidence.

| Original visual comparison | State observations matched | Images differing at zero tolerance |
| --- | ---: | ---: |
| Death | 240 | 32 / 40 |
| Actor feedback | 259 | 56 / 56 |
| Ordinary effects | 305 | 94 / 134 |
| Special effects | 447 | 121 / 141 |

These reproduce the established renderer/font/compositor differences in [#2](issue-02.md), [#3](issue-03.md), [#4](issue-04.md) and [#5](issue-05.md), including independent geometry/bitmap/fill controls. The special-effect check also compares the separate impact-smoke count. Ruffle execution is not Adobe Flash Player certification.

## Reproduction

Use the pinned Godot 4.7.2 console executable as `<godot>`. Native commands were serialized through the session's external `exclusive.py`; performance additionally reserved the host against Docker/browser rendering.

```powershell
python tools/run_checks.py --godot <godot> --timeout 600 --output .artifacts/issue21/headless
python tools/run_checks.py --godot <godot> --suite view --suite timeline --visual --timeout 600 --output .artifacts/issue21/native
python reference/issue-21-evidence/recheck.py --godot <godot> --output .artifacts/issue21/reference
python tools/run_checks.py --godot <godot> --suite pacing --performance --performance-seconds 180 --performance-warmup 5 --performance-rates 60 120 --timeout 600 --output .artifacts/issue21/performance
python tools/package_windows.py --godot <godot> --output .artifacts/issue21/package
python tools/smoke_windows.py <zip> --output .artifacts/issue21/smoke
python tools/probe_audio_close.py --package <extracted-BombIt.exe> --driver WASAPI --output .artifacts/issue21/close-wasapi
```

## Sustained desktop measurement

Host: Lenovo 82N6, Windows 11 Home 64-bit build 26200, Ryzen 7 5800H (8 cores/16 threads), 34,221,649,920 bytes installed RAM, RTX 3080 Laptop GPU, NVIDIA driver 32.0.15.5585. WMI reports 2560×1600 at 165 Hz; Godot reports approximately 165.019 Hz. Neither is an independent measurement of scanout. Compatibility/OpenGL 3.3 rendering, VSync requested disabled, audio Dummy. No competing local native, container or browser rendering ran during these captures.

The engine-hosted harness at `21a0bfc` uses the unchanged production fingerprint above. Each fresh process warms for five seconds, then measures 180 seconds. Six eight-second phases repeat: ordinary bombs, rocket/grenade, mine/gas, fire/ice, original outcome/scores and six pickups. Two humans receive actual injected keyboard events and two AIs run. Controlled long shields and inventories sustain load; this is a diagnostic fixture, not an ordinary campaign or the release executable's physical presentation measurement.

The deterministic schedule gate separately matches all authoritative checkpoints and random observations across four active weapon scenarios × five schedules: 35/60/120 callbacks and bounded stalls, at equal accepted simulation tick counts. It does not promise equivalent accepted ticks after arbitrary wall-time stalls.

| Cap | Measured seconds / submissions | Submission p99 / max | Dispatch → simulation p95 | Observed feedback submission p95 | Static-memory change |
| --- | ---: | ---: | ---: | ---: | ---: |
| 60 | 180.003 / 10,800 | 18.616 / 58.668 ms | 33.551 ms | 184.332 ms | +4.20% |
| 120 | 180.006 / 21,575 | 10.044 / 48.863 ms | 33.405 ms | 176.665 ms | +3.89% |

[Raw samples, complete reports and per-cycle analysis](issue-21-evidence/performance/) retain all endpoints and workload activity. Both runs observe every required weapon, six pickups and scores across three complete workload cycles and a partial fourth. Exactly 157/350 and 174/365 injected inputs respectively have no observed feedback endpoint; superseded, blocked and scene-ended observations remain in the denominator and records. Percentiles describe observed endpoints only, including legitimate source action waits (up to roughly 318 ms here). No feedback was borrowed from later inputs.

Submission intervals exceed the exact requested interval on 49.60% / 50.48% of samples, including small scheduler jitter; the maxima above show larger stalls. Thus uniform frame deadlines are not established. No physical touch, input-to-photon, scanout, mobile thermal or phone performance target is marked passed.

Static allocations grow from 56,571,783 to 58,948,295 bytes at 60 and 57,873,699 to 60,123,612 at 120; peaks are 60,379,132 / 61,278,243. This includes first-use assets, scene allocations and retained observer records. The same ordinary phase's last-two-second median changes from cycle 2 to cycle 4 by +0.40% / +0.51%; the phase records expose continuing small growth rather than claiming a flat plateau or proving no leak. These are Godot static allocations, not process working set or GPU memory. [Analysis command](issue-21-evidence/analyze_cycles.py) reconstructs phase timestamps from measured intervals and verifies the final timestamp within one microsecond.

Final package fingerprints and normal-close results follow after export. The earlier #19 ZIP is historical and is not the integrated candidate.
