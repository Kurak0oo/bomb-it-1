# Game completion checklist

Spec: [#1](https://github.com/Kurak0oo/bomb-it-1/issues/1). Implementation and
source-backed correction tickets have native blocking relationships. This is a progress
ledger, not a release or exact-parity certification.

Initial visual/input pass review baseline: `47be5ea18698ce94e94d39c91855022dbb37310a`.
The menu/help follow-up uses `0d3b2d18b67db1dcffc5c8468c110e0976748c25`; see
[menu restoration](menu-restoration.md) and [review](menu-review.md).
Earlier game changes are excluded from each pass. The accepted 35 Hz gameplay,
seeded RNG backend and deterministic timer policy remain unchanged.

The active pre-iPhone integration pass uses baseline `f79737253316dc3d805dd56af1d2eea95a66033d`.
Its task graph and current frontier are in [pre-iPhone integration](pre-iphone-integration.md).

## Eight-area completion matrix

Implementation, independently verified fixtures, deviations and external blockers
are separate claims. Passing a port regression does not certify the entire area.

| Original plan area | Verified evidence | Remaining implementation or verification | Deviations / external limits |
|---|---|---|---|
| Fixed core and four actors | Explicit 35 Hz, pure state and ownership regressions | Broader independent integration traces (#11–#13) | Accepted rules are preserved; no full-match equivalence claim |
| Core mechanics verification | Original-bytecode death, level-one blast and brick fixtures | Movement, damage coordinates, firing, pushing and grenade boundaries (#11–#12) | Ruffle evidence is not Adobe Flash Player certification |
| Original map generation | Recovered algorithm and seeded connectivity regressions | Strict bound/order replay across setup, drops, retry and stage continuation (#14) | Godot seeded RNG and deterministic timer remain explicit policies |
| AI and actor behavior | Four actors, difficulty regressions; 259 actor-presentation observations agree (#3) | Mixed interactions and full-match callback evidence (#13, #21) | Named fixtures do not establish every AI/game interaction |
| Items and special weapons | Existing item/weapon regressions and final rocket-smoke fix | Complete effect lifetimes and independent collision/ownership evidence (#4–#5, #12–#13) | Existing port tests are not an independent oracle |
| Visual timelines, depth and audio | #3 placement/timing/depth; #8 five-theme composition and source depth audit | Death difference isolation, ordinary/special effects and audio audit (#2, #4–#5, #10) | Exact image differences remain; HUD level/timer font substitution is documented |
| Game flow | Original menu/help (#6), independent 2P selection (#7), HUD counters/status (#8), twelve-route outcome matrix and source win timing (#9) | Integrated desktop flow (#21), broader independent outcome playback | Local high scores; source/port images and selection animation phases differ |
| Smooth display and phone experience | Rendered input delivery/cancellation (#15) | Safe areas, lifecycle, schedule invariance, packaging and desktop acceptance (#16–#21) | No Mac/Xcode; native signing/install and real-iPhone performance remain unverified (#20, #22) |

## Tickets

| Ticket | Status and remaining evidence |
|---|---|
| [#2 Deaths](https://github.com/Kurak0oo/bomb-it-1/issues/2) | Partial: all four source-bytecode death fixtures and separate eye/body compositing. Timing traces agree; 28/36 reference images still differ. |
| [#3 Actor feedback](https://github.com/Kurak0oo/bomb-it-1/issues/3) | Integrated: required placement/depth/timing/visibility fixtures pass; 259 independent observations agree. All 56 exact pixel differences remain unwaived. See [actor evidence](issue-03.md). |
| [#4 Ordinary effects](https://github.com/Kurak0oo/bomb-it-1/issues/4) | Pending expanded source captures and boundary comparison. |
| [#5 Special effects](https://github.com/Kurak0oo/bomb-it-1/issues/5) | Partial: impact-tick rocket smoke restored and rendered regression passes. Other effect comparisons remain. |
| [#6 Menu/help](https://github.com/Kurak0oo/bomb-it-1/issues/6) | Integrated acceptance audit: original title/player/help/power-up artwork and input checks pass; 11 source captures reproduce exactly, while all 11 source/port pairs still differ. See [menu evidence](issue-06.md). |
| [#7 Selection](https://github.com/Kurak0oo/bomb-it-1/issues/7) | Integrated: original difficulty/selection art and independent 2P confirmation; merged rendered checks pass. Six source/port pairs differ and are not tick-aligned animation claims. See [selection evidence](issue-07.md). |
| [#8 HUD/arena](https://github.com/Kurak0oo/bomb-it-1/issues/8) | Integrated: original panels/icons/counters/status, five-theme native/enlarged and controlled-depth captures. Exact pixels and source level/timer font remain documented differences. See [HUD evidence](issue-08.md). |
| [#9 Outcomes](https://github.com/Kurak0oo/bomb-it-1/issues/9) | Integrated: source 5.5-second delay, banners, immediate score fields (no source count-up), button states and time-up death visuals. Twelve 1P/2P routes pass. Named source win fixtures agree on delay and awards; broader pixel/playback parity remains unverified. See [outcome evidence](issue-09.md). |
| [#10 Audio](https://github.com/Kurak0oo/bomb-it-1/issues/10) | Pending independent cue/ordering comparison. Existing recovered samples remain. |
| [#11 Core traces](https://github.com/Kurak0oo/bomb-it-1/issues/11) | Integrated: original frame-2 callback, ten scenarios / 252 ticks / 20 fields, strict malformed/perturbation checks. 69 differences remain explicit; CORE-02/03 have separate correction tickets. See [core evidence](issue-11.md). |
| [#12 Endpoints](https://github.com/Kurak0oo/bomb-it-1/issues/12) | Integrated: 15 independent scenarios / 480 ticks / 26 fields, strict validation and per-scenario first divergences. 309 differences remain as MOTION-01–04; no speculative gameplay changes. See [motion evidence](issue-12.md). |
| [#13 Interactions](https://github.com/Kurak0oo/bomb-it-1/issues/13) | Pending mixed weapons, shields, surviving lives and ownership reference traces. |
| [#14 Random replay](https://github.com/Kurak0oo/bomb-it-1/issues/14) | Pending strict bound/order recording and fail-closed replay. Current fallback is not a parity oracle. |
| [#15 Input delivery](https://github.com/Kurak0oo/bomb-it-1/issues/15) | Implemented; rendered event tests cover brief keyboard/touch taps, ordered release/repress, held ordinary bombs, special release gating, simultaneous fingers, unrelated IDs, cancellation, hiding, disabling, pause and scene changes. Review's stale keyboard-direction finding is fixed and regression-tested. |
| [#16 Safe areas](https://github.com/Kurak0oo/bomb-it-1/issues/16) | Integrated: complete 550×400 content, safe side gutters or bottom dock, window/stretch conversion and transformed input. Nine desktop synthetic layouts and before-draw/resize checks pass; actual phone insets/comfort remain #22. See [layout evidence](issue-16.md). |
| [#17 Lifecycle](https://github.com/Kurak0oo/bomb-it-1/issues/17) | Partial: application background notification now pauses and clears fire; foreground waits for intentional resume. Native audio/focus/input matrix remains. |
| [#18 Smoothness](https://github.com/Kurak0oo/bomb-it-1/issues/18) | Pending measured 35/60/120 Hz frame pacing, latency and sustained runs. Existing interpolation remains. |
| [#19 Windows release](https://github.com/Kurak0oo/bomb-it-1/issues/19) | Pending standalone export and installation evidence. |
| [#20 iOS build](https://github.com/Kurak0oo/bomb-it-1/issues/20) | Native build/install externally blocked: user has iPhones but no Mac/Xcode access. Export configuration remains pending; signing and model/refresh inventory are unconfirmed. |
| [#21 Desktop acceptance](https://github.com/Kurak0oo/bomb-it-1/issues/21) | Pending prerequisite fidelity and packaging work. |
| [#22 iPhone acceptance](https://github.com/Kurak0oo/bomb-it-1/issues/22) | Blocked by native build plus remaining phone work. Simulator/Windows results cannot satisfy it. |
| [#23 Release evidence](https://github.com/Kurak0oo/bomb-it-1/issues/23) | Pending both integrated release gates; no completion claim. |
| [#28 Move/special ordering](https://github.com/Kurak0oo/bomb-it-1/issues/28) | Pending source-backed CORE-03 correction, separately from visual work. |
| [#29 Bomb expiry/refire](https://github.com/Kurak0oo/bomb-it-1/issues/29) | Pending source-backed CORE-02 correction after pushed-bomb and interaction evidence. |

## Evidence for the initial visual/input pass

- Source: Sprite 564 `hurtHero` (surviving hit starts smoke at frame 20),
  `putSpecial` rocket branch (smoke precedes impact/removal), pickup branches
  (attach `specialToolViewer` and select the equipped item).
- Source: XFL Symbols 236/237 (separate eyes/body and fade), 279 (smoke),
  299 (indicator placement and text), 293 (weapon labels), 313/312 (rocket smoke).
  Inspect with `python tools/inspect_symbol.py <id> --json`.
- Red/green rendered failures were observed for white death eyes, absent
  surviving-hit smoke, absent indicator, missing final rocket smoke, lost brief
  Bomb taps and missing background pause. Each passes after its corresponding fix.
- `python tools/run_checks.py --visual` includes the new rendered checks through
  the approved public runner. Input tests deliver platform events through Godot's
  input/viewport boundary; gameplay remains in the fixed simulation callback.
- `.artifacts/completion-reference-final/trace-comparison.json`: six scenarios, 40 updates each,
  exact observation-field agreement. `death-comparison/report.json`: 28 differing
  images out of 36. Remaining differences are unresolved; they have not been
  waived as renderer-only. No tolerance or tick shifting was introduced.
- `.artifacts/linux-completion`: fresh container import and rendered checks pass.
  Eight existing captures are unchanged. The death sheet and new feedback image
  were visually inspected before updating the Linux regression baselines. These
  baselines represent the port, separately from the original-bytecode comparison.
- `.artifacts/completion-final-checks`: all 16 phases pass on a fresh Windows
  project import, including nine tooling tests and the 21,600-tick soak.
- `.artifacts/linux-completion-final`: fresh Linux import, rendered input and
  exact comparison of all ten reviewed regression images pass.
- `.artifacts/linux-completion-reviewed`: the same focused Linux gate passes
  after the keyboard-cancellation review fix, including the extended input test.
- Review found keyboard movement could survive cancellation. A rendered-input
  regression failed before release gating was added to `KeyboardInput`; it now
  passes for both pause/resume and a new match. Focused checks after that fix are
  in `.artifacts/completion-review-fix`.
- [Machine-readable evidence](completion-evidence.json) retains test results,
  original-runtime hashes and exact image differences. Review is recorded in
  [completion-review.md](completion-review.md).

## Device constraint

The user reports a few phones, likely iPhone 12 or newer, and no Mac devices.
Exact models, iOS versions, refresh modes and signing access must be recorded
before the native matrix runs.
No cloud Mac purchase, credential handling, signed build, installed-device pass,
latency measurement or thermal test is implied by the Windows work.
