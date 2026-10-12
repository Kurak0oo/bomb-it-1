# Issue 18 — rendering schedules and desktop instrumentation

The public runner now compares authoritative state at equal accepted 35 Hz ticks under 35, 60, and 120 Hz presentation schedules, including 120 ms bounded stalls. Four active scenarios record and replay the same human commands and random-call values/bounds; checkpoints include every script-owned session/state field, timer, scores, actors, bombs, specials and RNG state. Source outcome presentation runs another six seconds without changing awards or authoritative state. This is schedule invariance, not equivalent wall-time behavior under arbitrarily long stalls.

The `pacing` suite is part of the default public checks. A deliberately injected per-display timer decrement (`BOMB_IT_PACING_MUTATION=timer`) fails the unequal-schedule comparisons. Nonzero event assertions also caught an ice scenario whose original scripted inputs never fired: alternating stationary fire with movement now exercises ordinary placement/explosion and all six named weapons.

## Reproduction

```powershell
python tools/run_checks.py --godot <Godot-4.7.2> --suite pacing --output .artifacts/pacing
python tools/run_checks.py --godot <Godot-4.7.2> --suite pacing --performance --performance-rates 60 120 --performance-seconds 48 --performance-warmup 3 --output .artifacts/performance
python tools/performance_report.py .artifacts/performance/performance-60-raw.json --output .artifacts/performance/recomputed.json
```

`tools/run_checks.ps1 -Performance -PerformanceSeconds 48 -PerformanceRates 60,120` exposes the same report. Run native measurements without competing capture processes. The integration workflow uses its external `exclusive.py` lock; no workstation-specific path is required by the repository tools.

Each fresh process runs ordinary bombs, rocket/grenade, mine/gas, fire/ice, the original outcome/score transition, and a six-item normal pickup trail, in eight-second phases. Two humans use real injected keyboard events through the application input seam; the second alternates movement/fire to maintain actual weapon activity. The existing AIs also run, but explicit human actions establish activity independently. Long shields and large special inventories are controlled load fixtures, not gameplay changes. The pickup trail clears one lane and supplies bomb/power/shoe/glove/shield/life items for normal movement collection. Actual event counts, peak live objects, setup CPU time, screen phases, and complete-sequence coverage are reported; short diagnostic runs are explicitly incomplete.

## Measurement boundary

Frame intervals are `RenderingServer.frame_post_draw` callback intervals; process deltas and summed physics CPU time between these callbacks are separate columns. The harness calls the real application's fixed-step path from real `SceneTree.physics_frame` callbacks with main automatic physics disabled. It requests an engine FPS cap and disabled vsync; it does not change simulation speed. Requested caps and reported monitor refresh are not proof of physical presentation cadence. The report deliberately leaves presented-frame timing and physical input-to-photon null, and device signoff false. The percentage exceeding the requested cap interval is engine callback jitter, not the phone missed-presentation-deadline criterion.

Input begins at synthetic dispatch and ends separately at the first accepted simulation update and first submission after observable movement/placement. Source movement completion, capacity, blocked tiles and freezing may defer feedback. A newer injected command closes a pending probe; it cannot receive credit for a later command's action. Unobserved samples remain in the report with a reason. This boundary excludes physical touch hardware and scanout.

Frame columns are preallocated before warmup; observer input records and application caches still contribute to Godot static-memory observations. Static memory is not process RSS. Raw data, revision, production-source and instrumentation SHA-256 fingerprints make comparisons reproducible. The final integrated desktop soak and native phone thermal/memory/presentation criteria remain later acceptance work (#21/#22).

## Measured change and validation

A fixed-state diagnostic outside measured frame collection found HUD synchronization at a median 135.67 microseconds per call before this change and 33.005 after (ten batches of 100 calls, same Windows host). Four portrait textures are retained after initialization and invisible status icons skip redundant composition. Revealing an icon still samples the absolute original source phase; the rendered HUD check compares it with a continuously visible icon at the same tick. No gameplay, RNG, timer or 35 Hz constants changed. Source icon timelines only compose visual layers, so omitted hidden composition has no script side effects.

The public report command was developed red/green against known literal intervals/input timestamps, and rejects feedback timestamps preceding simulation delivery. Schedule invariance, the non-empty weapon scenarios, and HUD rendered behavior pass. Final integrated reports and host details will be recorded below after the synchronized run.

## Retained desktop run

[Raw samples, summaries and replay checkpoints](issue-18-capture/) are from revision `298bd073627ff01fb8efeb583a94154a9c5d3b72` (this implementation plus integration `e12f8b0`, including #4 pickup art), Godot 4.7.2, Windows 11 build 26200, Ryzen 7 5800H, RTX 3080 Laptop GPU. The monitor reports 165.019 Hz; actual scanout timing was not measured. Each process warmed for three seconds and measured 48 seconds. An earlier briefly contended attempt was stopped/discarded; retained samples ran after the other capture process stopped.

| Requested cap | Submissions | Submission p99 / max | Dispatch → simulation p95 | Dispatch → feedback submission p95 | Static-memory change |
| --- | ---: | ---: | ---: | ---: | ---: |
| 60 Hz | 2,880 | 31.717 / 53.918 ms | 44.180 ms | 296.471 ms | +3.65% |
| 120 Hz | 5,498 | 17.481 / 52.798 ms | 31.205 ms | 326.377 ms | +3.77% |

Both reports mark all activity coverage true, including the six pickup trail and original score screen. Feedback samples include observed source waits of up to 11 additional accepted ticks; 45/40 inputs respectively remained unobserved or were superseded, and are retained rather than silently dropped from the record. Feedback percentiles summarize observed endpoints only. Static memory includes cache warmup across newly visited scenes and the bounded observer; this short run cannot establish a leak or sustained stability. The engine cap did not produce uniformly spaced submission callbacks, particularly at 120 Hz; no physical deadline or latency target is marked passed.

The included AI behavior is the pre-#29 revision, whose source correction is in progress. These reports establish active controlled human/weapon/pickup loads, not representative corrected AI activity. #21 must rerun the same public command on the final integrated candidate and perform its longer desktop sequence; #22 owns physical phone evidence. No iPhone, thermal, physical touch, or photon measurement was performed here.

Validated: four scenarios × five schedules, all authoritative checkpoints equal; active placement/explosion and six weapon assertions; rendered HUD absolute-phase reveal; six Python public-command tests. The injected display-dependent timer defect fails the checker as intended. Shared regression images are owned by integration; HUD caching alone has no visible image changes. The source loop correction below changes upgraded HUD icon phases.

After the timing run, integration `822b806` landed the #29 callback-order correction and AI repair. It was merged into this branch at `d331efe`; all 20 deterministic schedule runs still pass with the new callback registry included in authoritative checkpoints. [Post-#29 fingerprints and replay evidence](issue-18-capture/post-29/) are retained separately so the earlier timing data cannot be mistaken for measurements of that newer production build.

## Shared Symbol 326 HUD loop correction

Merger review traced the #4 pickup-loop correction into the HUD: XFL Symbol 536 places three Symbol 326 clips for shield/shoe/glove, and Symbol 326 frame 80 executes `gotoAndPlay(1)`. HUD sampling now uses the same 79 displayed updates as ordinary pickups. A rendered regression compares the three icon slots at ages 1 and 80, fails with the old modulo 80, and passes with modulo 79. The hidden/revealed icon comparison at absolute age 137 continues to pass, preserving the optimization's phase behavior. [Source inspection, exact screenshots and red/green logs](issue-18-capture/hud-period/) are retained. The repeat comparison covers rectangle (65,29,19,30), excluding the adjacent bomb icon whose separate loop legitimately differs between those ages.

This presentation correction followed the retained timing sample; no new timing claim is made for it. Expected visual differences are upgraded HUD icon phases after a completed 79-update loop; basic HUD/theme captures without upgrades should remain unchanged. Gameplay and authoritative 35 Hz behavior remain untouched.

## Source-only runner portability correction

The pinned Linux image contains neither Git nor `.git`; unconditional revision lookup initially stopped the runner before import. `build_metadata` now treats missing/unusable Git metadata as an explicit `revision: "unknown"`, retaining production and instrumentation SHA-256 fingerprints. It only accepts a complete hexadecimal Git object ID from a successful lookup; no substitute identity or Git installation is required.

A public-command regression copies the runner and source inputs outside the repository, then exercises both available-Git/no-repository and no-Git-PATH cases. Before the correction these failed with an empty revision and missing executable respectively; after it both pass. Seven Windows public-command tests pass, the new regression passes in pinned Linux image `db3a93d964a2`, and the real engine import plus all 20 schedule runs pass there with the corrected runner mounted into that unchanged image. [Linux metadata and logs](issue-18-capture/no-git-linux/) retain the explicit unknown revision and fingerprints.
