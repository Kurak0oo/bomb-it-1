# Game completion checklist

Spec: [#1](https://github.com/Kurak0oo/bomb-it-1/issues/1). All 22 implementation
tickets are published with native blocking relationships. This is a progress
ledger, not a release or exact-parity certification.

Initial visual/input pass review baseline: `47be5ea18698ce94e94d39c91855022dbb37310a`.
The menu/help follow-up uses `0d3b2d18b67db1dcffc5c8468c110e0976748c25`; see
[menu restoration](menu-restoration.md) and [review](menu-review.md).
Earlier game changes are excluded from each pass. The accepted 35 Hz gameplay,
seeded RNG backend and deterministic timer policy remain unchanged.

## Tickets

| Ticket | Status and remaining evidence |
|---|---|
| [#2 Deaths](https://github.com/Kurak0oo/bomb-it-1/issues/2) | Partial: all four source-bytecode death fixtures and separate eye/body compositing. Timing traces agree; 28/36 reference images still differ. |
| [#3 Actor feedback](https://github.com/Kurak0oo/bomb-it-1/issues/3) | Partial: surviving-hit smoke, weapon indicator and rendered regressions. Nested idle clips and independent indicator/depth captures remain. |
| [#4 Ordinary effects](https://github.com/Kurak0oo/bomb-it-1/issues/4) | Pending expanded source captures and boundary comparison. |
| [#5 Special effects](https://github.com/Kurak0oo/bomb-it-1/issues/5) | Partial: impact-tick rocket smoke restored and rendered regression passes. Other effect comparisons remain. |
| [#6 Menu/help](https://github.com/Kurak0oo/bomb-it-1/issues/6) | Title/player count/controls/power-up slices #24–#26 implemented with source artwork and input checks. All 11 original-playback image pairs still differ; see [menu restoration](menu-restoration.md). Parent remains open for fidelity review. |
| [#7 Selection](https://github.com/Kurak0oo/bomb-it-1/issues/7) | Pending original selection presentation. |
| [#8 HUD/arena](https://github.com/Kurak0oo/bomb-it-1/issues/8) | Pending composition, depth and theme reference matrix. |
| [#9 Outcomes](https://github.com/Kurak0oo/bomb-it-1/issues/9) | Pending original transitions, counting and score presentation. |
| [#10 Audio](https://github.com/Kurak0oo/bomb-it-1/issues/10) | Pending independent cue/ordering comparison. Existing recovered samples remain. |
| [#11 Core traces](https://github.com/Kurak0oo/bomb-it-1/issues/11) | Pending movement, damage-coordinate and fire-input bytecode fixtures. |
| [#12 Endpoints](https://github.com/Kurak0oo/bomb-it-1/issues/12) | Pending pushed-bomb and grenade endpoint fixtures. |
| [#13 Interactions](https://github.com/Kurak0oo/bomb-it-1/issues/13) | Pending mixed weapons, shields, surviving lives and ownership reference traces. |
| [#14 Random replay](https://github.com/Kurak0oo/bomb-it-1/issues/14) | Pending strict bound/order recording and fail-closed replay. Current fallback is not a parity oracle. |
| [#15 Input delivery](https://github.com/Kurak0oo/bomb-it-1/issues/15) | Implemented; rendered event tests cover brief keyboard/touch taps, ordered release/repress, held ordinary bombs, special release gating, simultaneous fingers, unrelated IDs, cancellation, hiding, disabling, pause and scene changes. Review's stale keyboard-direction finding is fixed and regression-tested. |
| [#16 Safe areas](https://github.com/Kurak0oo/bomb-it-1/issues/16) | Partial preparation: layout no longer depends on drawing; resize cancels input. Actual safe-area layout and orientation matrix remain. |
| [#17 Lifecycle](https://github.com/Kurak0oo/bomb-it-1/issues/17) | Partial: application background notification now pauses and clears fire; foreground waits for intentional resume. Native audio/focus/input matrix remains. |
| [#18 Smoothness](https://github.com/Kurak0oo/bomb-it-1/issues/18) | Pending measured 35/60/120 Hz frame pacing, latency and sustained runs. Existing interpolation remains. |
| [#19 Windows release](https://github.com/Kurak0oo/bomb-it-1/issues/19) | Pending standalone export and installation evidence. |
| [#20 iOS build](https://github.com/Kurak0oo/bomb-it-1/issues/20) | Native build/install externally blocked: user has iPhones but no Mac/Xcode access. Export configuration remains pending; signing and model/refresh inventory are unconfirmed. |
| [#21 Desktop acceptance](https://github.com/Kurak0oo/bomb-it-1/issues/21) | Pending prerequisite fidelity and packaging work. |
| [#22 iPhone acceptance](https://github.com/Kurak0oo/bomb-it-1/issues/22) | Blocked by native build plus remaining phone work. Simulator/Windows results cannot satisfy it. |
| [#23 Release evidence](https://github.com/Kurak0oo/bomb-it-1/issues/23) | Pending both integrated release gates; no completion claim. |

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
