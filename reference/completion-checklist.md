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
| Fixed core and four actors | Explicit 35 Hz, pure state, ownership regressions and independent traces (#11–#13) | Source-backed callback/accounting corrections (#33) and integrated acceptance | No full-match equivalence claim |
| Core mechanics verification | Original-bytecode death/blast/brick, movement/damage/firing, pushing/grenade and mixed-interaction fixtures; movement/fire correction (#28) | Remaining bounded corrections (#33) | One-twip and residual-energy uncertainties remain; Ruffle is not Adobe Flash Player certification |
| Original map generation | Recovered algorithm and seeded connectivity regressions | Strict bound/order replay across setup, drops, retry and stage continuation (#14) | Godot seeded RNG and deterministic timer remain explicit policies |
| AI and actor behavior | Four actors, difficulty regressions, nested ownership/accounting fixtures (#13); 259 actor-presentation observations agree (#3) | Integrated desktop acceptance (#21) | Named fixtures do not establish every AI/game interaction |
| Items and special weapons | Existing regressions, final rocket-smoke fix and independent endpoint/collision/ownership evidence (#12–#13) | Remaining bounded corrections (#33) | Existing port tests are not an independent oracle |
| Visual timelines, depth and audio | #2 death corrections and component attribution; #3 placement/timing/depth; #8 five-theme composition and source depth audit | Audio audit (#10) | Exact image differences remain; HUD level/timer font substitution is documented |
| Game flow | Original menu/help (#6), independent 2P selection (#7), HUD counters/status (#8), twelve-route outcome matrix and source win timing (#9) | Integrated desktop flow (#21), broader independent outcome playback | Local high scores; source/port images and selection animation phases differ |
| Smooth display and phone experience | Rendered input delivery/cancellation (#15), synthetic safe-area layouts (#16), lifecycle/resume (#17) | Packaging and desktop acceptance (#19–#21) | No Mac/Xcode; native signing/install and real-iPhone performance remain unverified (#20, #22) |

## Tickets

| Ticket | Status and remaining evidence |
|---|---|
| [#2 Deaths](https://github.com/Kurak0oo/bomb-it-1/issues/2) | Integrated: source alpha/shadow fixes, all four creation/removal boundaries and per-sample component/compositor attribution. Actual source/port comparison still differs in 32/40 images (35,236 pixels), separately from 360 exact source-input controls. No tolerance or tick changes. See [death evidence](issue-02.md). |
| [#3 Actor feedback](https://github.com/Kurak0oo/bomb-it-1/issues/3) | Integrated: required placement/depth/timing/visibility fixtures pass; 259 independent observations agree. All 56 exact pixel differences remain unwaived. See [actor evidence](issue-03.md). |
| [#4 Ordinary effects](https://github.com/Kurak0oo/bomb-it-1/issues/4) | Integrated: 305 lifecycle observations agree; corrected pickup loop, per-fill removal fade, flame alpha and brick visibility. All 134 source drawing controls agree, separately from 94/134 differing actual images. See [ordinary effects](issue-04.md). |
| [#5 Special effects](https://github.com/Kurak0oo/bomb-it-1/issues/5) | Integrated: all 447 source presence and 28 smoke observations agree; independent fire/ice lifetimes, grenade depth and outcome completion corrected. Actual exact pixels still differ in 121/141 pairs. See [special effects](issue-05.md). |
| [#6 Menu/help](https://github.com/Kurak0oo/bomb-it-1/issues/6) | Integrated acceptance audit: original title/player/help/power-up artwork and input checks pass; 11 source captures reproduce exactly, while all 11 source/port pairs still differ. See [menu evidence](issue-06.md). |
| [#7 Selection](https://github.com/Kurak0oo/bomb-it-1/issues/7) | Integrated: original difficulty/selection art and independent 2P confirmation; merged rendered checks pass. Six source/port pairs differ and are not tick-aligned animation claims. See [selection evidence](issue-07.md). |
| [#8 HUD/arena](https://github.com/Kurak0oo/bomb-it-1/issues/8) | Integrated: original panels/icons/counters/status, five-theme native/enlarged and controlled-depth captures. Exact pixels and source level/timer font remain documented differences. See [HUD evidence](issue-08.md). |
| [#9 Outcomes](https://github.com/Kurak0oo/bomb-it-1/issues/9) | Integrated: source 5.5-second delay, banners, immediate score fields (no source count-up), button states and time-up death visuals. Twelve 1P/2P routes pass. Named source win fixtures agree on delay and awards; broader pixel/playback parity remains unverified. See [outcome evidence](issue-09.md). |
| [#10 Audio](https://github.com/Kurak0oo/bomb-it-1/issues/10) | Pending independent cue/ordering comparison. Existing recovered samples remain. |
| [#11 Core traces](https://github.com/Kurak0oo/bomb-it-1/issues/11) | Integrated: original frame-2 callback, ten scenarios / 252 ticks / 20 fields, strict malformed/perturbation checks. Initial 69 differences are retained; #28/#29 reduce the current count to six (CORE-01). See [core evidence](issue-11.md) and [correction](issue-28.md). |
| [#12 Endpoints](https://github.com/Kurak0oo/bomb-it-1/issues/12) | Integrated: 15 independent scenarios / 480 ticks / 26 fields, strict validation and per-scenario first divergences. Initial 309 differences are retained as MOTION-01–04; after #31 the full motion profile agrees. See [motion evidence](issue-12.md). |
| [#13 Interactions](https://github.com/Kurak0oo/bomb-it-1/issues/13) | Integrated: 17 scenarios / 784 ticks / 43 fields with original parent accounting; Initial 134 differences retained; 47 remain after #32 (33 gas/ice fields and 14 residual-energy observations). Nested controls reproduce prior core/motion findings. Corrections #30–#33 are separately identified; residual pulse energy remains uncertain. See [interaction evidence](issue-13.md). |
| [#14 Random replay](https://github.com/Kurak0oo/bomb-it-1/issues/14) | Pending strict bound/order recording and fail-closed replay. Current fallback is not a parity oracle. |
| [#15 Input delivery](https://github.com/Kurak0oo/bomb-it-1/issues/15) | Implemented; rendered event tests cover brief keyboard/touch taps, ordered release/repress, held ordinary bombs, special release gating, simultaneous fingers, unrelated IDs, cancellation, hiding, disabling, pause and scene changes. Review's stale keyboard-direction finding is fixed and regression-tested. |
| [#16 Safe areas](https://github.com/Kurak0oo/bomb-it-1/issues/16) | Integrated: complete 550×400 content, safe side gutters or bottom dock, window/stretch conversion and transformed input. Nine desktop synthetic layouts and before-draw/resize checks pass; actual phone insets/comfort remain #22. See [layout evidence](issue-16.md). |
| [#17 Lifecycle](https://github.com/Kurak0oo/bomb-it-1/issues/17) | Integrated: overlapping focus/background suspension, deliberate match/outcome resume, cleared stale input, stable interpolation and persisted mute preference. Eleven rendered phases pass; Dummy-driver/synthetic desktop evidence does not certify native iPhone behavior. See [interruption evidence](issue-17.md). |
| [#18 Smoothness](https://github.com/Kurak0oo/bomb-it-1/issues/18) | Integrated: 20 schedule runs preserve authoritative state, including bounded stalls; active desktop frame/input reports and measured HUD caching improvement retained. HUD status icons now follow the 79-update source loop. Final integrated sustained desktop and physical phone criteria remain #21/#22. See [smoothness evidence](issue-18.md). |
| [#19 Windows release](https://github.com/Kurak0oo/bomb-it-1/issues/19) | Integrated: pinned portable release ZIP built from committed source; actual executable passes menu/movement/bomb/pause and separate-process persisted-mute checks. Abrupt-quit audio diagnostic remains explicit; final candidate rebuild belongs to #21. See [Windows package](issue-19.md). |
| [#20 iOS build](https://github.com/Kurak0oo/bomb-it-1/issues/20) | Partial: iPhone/arm64 development preset, public readiness preflight and exact Mac/export/device instructions integrated. Actual preflight reports missing genuine identity and Apple toolchain; signing, installation and cold launch remain unverified. See [iPhone configuration](issue-20.md). |
| [#21 Desktop acceptance](https://github.com/Kurak0oo/bomb-it-1/issues/21) | Pending prerequisite fidelity and packaging work. |
| [#22 iPhone acceptance](https://github.com/Kurak0oo/bomb-it-1/issues/22) | Blocked by native build plus remaining phone work. Simulator/Windows results cannot satisfy it. |
| [#23 Release evidence](https://github.com/Kurak0oo/bomb-it-1/issues/23) | Pending both integrated release gates; no completion claim. |
| [#28 Move/special ordering](https://github.com/Kurak0oo/bomb-it-1/issues/28) | Integrated: human direction/movement precedes fire; all 28 independent cases / 4,704 fields match. A separate [AI repair](issue-28-ai.md) restores source fire-before-move and adds seven independent cases plus an active soak assertion. See [ordering evidence](issue-28.md). |
| [#29 Bomb expiry/refire](https://github.com/Kurak0oo/bomb-it-1/issues/29) | Integrated: creation-ordered child callbacks precede commands; 11 expiry cases / 4,840 fields match. Core retains only six CORE-01 differences. All existing push cases now match; remaining grenade/accounting/special differences stay explicit. See [expiry evidence](issue-29.md). |
| [#30 Push lifecycle](https://github.com/Kurak0oo/bomb-it-1/issues/30) | Integrated: seven source cases / 224 total ticks / 6,048 fields agree, including allowance. Pre-#29 replay fails; current public push regression passes. No further production change needed. See [push evidence](issue-30.md). |
| [#31 Grenade endpoint](https://github.com/Kurak0oo/bomb-it-1/issues/31) | Integrated: 18 endpoint cases and real-parent chain accounting match all 17,792 fields. Full motion profile now agrees; source callbacks detonate after 18 advances to body frame 19. See [grenade evidence](issue-31.md). |
| [#32 Hit/refund accounting](https://github.com/Kurak0oo/bomb-it-1/issues/32) | Integrated: source hit credit before shield consumption and live-owner-only refund; all 24,816 independent fields match. Self-credit, invulnerability, multi-life outcomes and retry/progression controls pass. See [accounting evidence](issue-32.md). |
| [#33 Special callback order](https://github.com/Kurak0oo/bomb-it-1/issues/33) | Pending gas timer, new ice-cell eligibility and dependent rocket/mine dispatch corrections; balanced cleanup retained. |

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
