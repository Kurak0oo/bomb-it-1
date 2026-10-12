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

These reproduce the retained strict mismatches in [#2](issue-02.md), [#3](issue-03.md), [#4](issue-04.md) and [#5](issue-05.md). Independent source-input/component controls are separate evidence; explanations and remaining uncertainties are recorded in those tickets. They do not establish a complete cause for every differing pixel, particularly the 121/141 special-effect images. The special-effect check also compares the separate impact-smoke count. Ruffle execution is not Adobe Flash Player certification.

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

[Raw samples, complete reports and per-cycle analysis](issue-21-evidence/performance/) retain all endpoints and workload activity. Both runs observe every required weapon, six pickups and scores. Each measured window includes two complete workload cycles plus portions of the first and fourth cycles; the first ordinary phase partly falls inside warmup. Exactly 157/350 and 174/365 injected inputs respectively have no observed feedback endpoint; superseded, blocked and scene-ended observations remain in the denominator and records. Percentiles describe observed endpoints only, including legitimate source action waits (up to roughly 318 ms here). No feedback was borrowed from later inputs.

Submission intervals exceed the exact requested interval on 49.60% / 50.48% of samples, including small scheduler jitter; the maxima above show larger stalls. Thus uniform frame deadlines are not established. No physical touch, input-to-photon, scanout, mobile thermal or phone performance target is marked passed.

Static allocations grow from 56,571,783 to 58,948,295 bytes at 60 and 57,873,699 to 60,123,612 at 120; peaks are 60,379,132 / 61,278,243. This includes first-use assets, scene allocations and retained observer records. The same ordinary phase's last-two-second median changes from cycle 2 to cycle 4 by +0.40% / +0.51%; the phase records expose continuing small growth rather than claiming a flat plateau or proving no leak. These are Godot static allocations, not process working set or GPU memory. [Analysis command](issue-21-evidence/analyze_cycles.py) reconstructs phase timestamps from measured intervals and verifies the final timestamp within one microsecond.

## Actual portable release and close

The final ZIP was exported from clean committed `b9970e8bf4514c0334087f462131cf7c0541d852` (`source_tree_dirty: false`), with official pinned 4.7.2 Windows release templates. Later changes in this ticket only record evidence. It contains `BombIt.exe`, `README.txt` and `package.json`; the PCK is embedded, and no editor/project override is needed. The package is unsigned.

- ZIP: `bomb-it-windows-x64-b9970e8bf451.zip`, 43,654,901 bytes; SHA-256 `6c59683a16d4594f4cff074153c1416211c97efd06435d473c9b1b15edc94930`.
- Executable SHA-256: `a1cfa28eff02306bc43269d30ab6cf9985b13152c5edb6afe044359caaad1f87`.
- Complete exported-project source SHA-256: `681db9463aec743eee2d2d560012c70fb4b057dc37b453cdfef2b3fda9775bbf`.
- Persistent root location: `.artifacts/release/desktop-b9970e8bf451/package/bomb-it-windows-x64-b9970e8bf451.zip`. [Release index](issue-21-evidence/release-index.json) records copied-file hashes and verifies the copied ZIP against the build manifest. Smoke, close, performance/raw/cycle, native and reference evidence are copied alongside it before worktree cleanup.

[Actual release smoke](issue-21-evidence/smoke/smoke.json) reports `editor=false`, `debug_build=false`, and 35 Hz in two processes. The rendered original menu route starts a match; keyboard input moves the human from (3,3) to (5,3), places its bomb, pauses with no accepted updates, and resumes through the visible button. The second process restores the saved mute preference. Four screenshots and the isolated preference file are retained; the match and pause images were visually inspected. Package extraction and startup use the same executable verified by SHA-256, without an editor, source `--path`, or test-script override. The explicitly opted-in smoke hook runs after normal startup and is separate from ordinary close.

Normal and repeated `WM_CLOSE` requests to the package's own visible window pass with [Dummy](issue-21-evidence/close-dummy/report.json) and [WASAPI](issue-21-evidence/close-wasapi/report.json): exit zero, no stdout/stderr warnings/errors, 0.281 / 0.187 seconds. Fresh isolated user-data roots prevent altering the player's preferences. These cover ordinary packaged title startup with active menu music; the full integrated native audio checks and retained #10 close matrix cover playing, pause, background and mute behavior separately.

The forced `--quit-after 120` diagnostic was also rerun against this exact executable with isolated APPDATA/XDG paths. It still exits zero while reporting two leaked ObjectDB instances and one resource in use. [Exact command and complete stdout/stderr](issue-21-evidence/abrupt/report.json) are retained. That engine-forced termination bypasses normal close notification; it remains an explicit limitation, not a passing close result. No production sleep was added here.

The earlier #19 ZIP is historical. This candidate's desktop evidence is ready for root's final Standards/Spec review; any subsequent production fix requires appropriate revalidation and a rebuilt/re-smoked package. No signed install, physical iPhone test or final release approval is claimed.
