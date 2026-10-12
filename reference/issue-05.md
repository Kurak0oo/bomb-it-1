# Special-weapon presentation — ticket #5

Starting integration: `d90a0cf`, synchronized to `e7e85e3` before implementation. Production changes are confined to `GameView`. No artwork, 35 Hz simulation callback, damage, energy, charge, timer or random-selection rule changes.

## Source-backed behaviour

All six recovered effects are exercised through original executable timelines: four rocket directions with nested exhaust, four grenade directions with nested bodies, mine blinking/stop, gas ascent/fade/stop, ice layers/shadow and fire growth/nested animation/removal. A separate scenario preserves original `putSpecial` bytecode and executes a rocket collision with a brick. The original SWF, source fixture, builder, browser script and scenario profile are hashed in [provenance](issue-05-capture/final/provenance.json).

The **447 creation/update presence observations match**, and all **28 independent rocket-smoke counts match**. Creation is tick −1 and the first callback is tick 0; no samples are shifted. At collision tick 4 the rocket is absent but all five smoke clips exist, including the sample emitted at `(255,180)` before collision. Their independent timelines retire successively: two remain at tick 23, one at tick 24, none at tick 25. Repeated view synchronization does not duplicate the final sample.

Source fire/ice controllers create independent clips in `brickArea` at controller ages 4, 8 and 12, then remove themselves at age 49. Each child removes itself on its own frame 40 (age 39). The view previously both retained ice's frame-40 shadow for one extra update and erased surviving children with their controller. It now preserves independent display ages: the last child remains through controller age 50 and disappears at 51. Fire's recovered nested eight-frame pattern already matches original playback; its existing art is retained.

The grenade depth transition now occurs at age 8, corresponding to source body frame 9. The independent [ticket #31 depth capture](issue-31-evidence/depth/) observes depth 965 at body frame 8 and 1265 at frame 9 for both creation conventions. The rendered regression observes those literal depths. Endpoint mechanics remain owned by #31; the isolated artwork fixture deliberately plays all 19 nested frames without a gameplay callback and is not an endpoint-parity claim.

Source `gameover` sets `pausing` and removes the parent game callback without stopping child movie timelines. Outcome presentation now completes fire, ice, pulse/brick bursts and mine/gas timelines, and continues the rocket/grenade nested loops. It does not advance movement/collision callbacks or emit new rocket smoke. Rendered checks verify unchanged game tick, weapon age and pulse energy, then repeat effect creation/outcome/scene teardown over three rounds. Every round returns to the same empty rendered scene.

An additional [original grenade loop control](issue-05-capture/outcome-loop-control/report.json) retains all four directions at creation and after 19 timeline updates: each image repeats exactly when its gameplay callback is absent. Mine's source stop frame 60 is invisible, as is gas's stop frame 101; those outcome boundaries are explicitly checked.

## Exact pixels remain diagnostic

There are **141 original/current image pairs; 121 still differ exactly**. This ticket does not claim cross-runtime pixel parity. No comparison tolerance, masks, baseline replacement or art darkening is introduced. The table and [all-image counts](issue-05-capture/actual-counts.csv) retain those failures rather than converting them into passes.

| Effect | Current images differing | Changed pixels |
| --- | ---: | ---: |
| Rockets, four directions | 48/48 | 28,633 |
| Grenades, four directions | 32/32 | 9,278 |
| Mine | 6/11 | 2,886 |
| Gas | 8/13 | 5,709 |
| Ice | 10/13 | 9,399 |
| Fire | 10/13 | 8,259 |
| Rocket impact and smoke | 7/11 | 6,641 |

The source/port sheet shows edge, gradient, bitmap and compositing differences in the unchanged recovered art. These differences are not all independently attributed by this ticket and remain an explicit limitation. The corrected ice removal sample at tick 38 improves from **219 differing pixels to zero**. All other 129 pre-existing static sample images are unchanged; the 11 impact samples are new coverage. The 130 repeated original static images are byte-identical across source runs. [Contact sheet](issue-05-capture/contact.png) labels original, previous port and current port separately, including the unsampled previous impact case.

## Validation and reproduction

The public rendered check recorded red → green for independent child survival, outcome completion, gas fade, brick-burst completion and grenade depth. It also verifies rocket impact smoke, source removal boundaries, continuing nested loops, and repeated-round cleanup. The focused view, timeline, special and tooling suites and all **13 native rendered phases** pass. The new rendered check also passes on pinned Linux Mesa llvmpipe, derived from integration image `7fba1b96af93`, as well as Windows/NVIDIA. Checks compare rendered behaviour or same-backend images, while original-image reports remain strict and separate.

```powershell
python tools/capture_special_effects.py --ffdec C:/Users/Eiji/AppData/Local/FFDec --godot C:/Users/Eiji/AppData/Local/Godot/Godot_v4.7.2-stable_win64_console.exe --output .artifacts/special-effects
python tools/run_checks.py --godot C:/Users/Eiji/AppData/Local/Godot/Godot_v4.7.2-stable_win64_console.exe --suite view --suite timeline --suite special --suite tooling --visual --output .artifacts/special-checks
python tools/analyze_special_effects.py <before-capture> <current-capture> --output .artifacts/special-analysis
```

Use the session's exclusive wrapper for native rendered commands. `--require-parity` makes the capture command fail on exact pixel/presence differences; harness errors always fail. [Retained evidence](issue-05-capture/) includes original/current images and traces, previous static images, exact difference reports, red/green logs and Linux/native output. An initial capture fixture failed to select JSON numeric capture ticks; the corrected complete run uses explicit numeric conversion, without changing any simulation tick.

Five new regression images require root review: `special-fire-parent-retired`, `special-ice-parent-retired`, `special-outcome-finished`, `special-rocket-impact` and `special-grenade-depth`. Existing shared baselines and the raw timeline contact sheet are untouched. Expected gameplay-image changes are the final ice-shadow boundary, ray children surviving controller retirement, grenade overlap at body frame 9, and effects completing during result presentation.

Post-merge validation includes integration `5366c86` (#31 endpoint) and the subsequent docs-only `6452f97`. View, timeline, special, tooling, grenade endpoint/accounting and all **14 native rendered phases** pass. All five special-effect PNGs are byte-identical to the pre-merge run. [Post-merge logs](issue-05-capture/checks/post-merge/) retain those results; production was reviewed against the integration tip, with no gameplay or asset changes in this slice.
