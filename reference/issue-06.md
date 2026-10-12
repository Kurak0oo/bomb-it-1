# #6: original menus and help acceptance

Audited from `f79737253316dc3d805dd56af1d2eea95a66033d` on 2026-10-12.
`integration/pre-iphone-completion` was an ancestor of the working branch.
The implementation already present in #24–#26 satisfies this ticket's navigation
and source-recovery scope. This pass adds current acceptance evidence, without
rewriting those menus or changing gameplay.

## Acceptance checklist

| Requirement | Evidence and disposition |
|---|---|
| Recover root menu states, typography, artwork, animation and button states | **Independently verified for the named menu fixture; exact pixels unverified.** Root frames 3/4/6/7 and their original display-list art supply title/player count/controls/power-up guide. The source uses stopped root frames, not a missing title animation. Button Up/Over/Down and sound states are recovered. See [source and route audit](menu-restoration.md#source-and-routes). |
| Original help plus actual platform controls; direct touch | **Implemented, with documented additions.** Original 1P/2P keyboard diagrams remain. The desktop line explains WASD/Esc/M; the touch line explains left stick/Bomb and special-shot release. [Current touch help](issue-06-evidence/touch-controls.png) shows the preserved composition and readable addition. Synthetic rendered touch enters and returns from help without hover. |
| Rendered entry/help/return navigation and original screenshots | **Independently verified for the fixture.** The current public runner passes mouse, keyboard and touch routes, release cancellation, mixed-device ownership, repeat suppression, sound/player-count retention, wide-window hit testing and no simulation behind help. [Original captures](menu-capture/original) and [current Windows captures](issue-06-evidence/rebuilt) are retained separately. |
| Focused checks, evidence, limitations and review | **Passed within the above scope.** All eight selected runner phases pass in [checks.json](issue-06-evidence/checks.json); [menu log](issue-06-evidence/menu-render.log) records `MENU_RENDER_OK`. The scope review below and the earlier [two-axis implementation review](menu-review.md) cover the change. |

## Source verification

`xfl/Bomb It 1/DOMDocument.xml` labels the four root frames `menu`, `menu2`,
`howtoplay` and `toolInstruction`. Root frame 3 calls `stop()`.
The extracted `DefineButton2_439`, `_440` and `_473` release actions call
`gotoAndStop("menu2")`, `gotoAndStop("howtoplay")` and
`gotoAndStop("toolInstruction")`. Thus release-based routing and static root
presentation have direct source support. `python tools/inspect_symbol.py 460
--frames 1 2` also confirms the sound clip's state selection. The committed menu
manifest retains source registration, transforms, layering and extraction scale.

The unchanged original SWF was recaptured through its real buttons in Ruffle
0.7.1 / Chromium 156.0.8078.4. All 11 fresh source images exactly match the
previously retained source images: [zero-tolerance source repeat report](issue-06-evidence/source-repeat.json).
The fresh provenance is [source-runtime.json](issue-06-evidence/source-runtime.json).
Identical source images are not duplicated. The current Windows rebuild used
Godot 4.7.2 and an NVIDIA GeForce RTX 3080 Laptop GPU, recorded in its own
[runtime metadata](issue-06-evidence/rebuilt/runtime.json).

All 11 paired source-versus-Windows images differ at zero tolerance, with every
count retained in [image-comparison.json](issue-06-evidence/image-comparison.json).
The [controls triptych](issue-06-evidence/controls-comparison.png) shows source,
rebuild and exact differences. Those failures are diagnostic evidence, not passes.
The source repeat pass establishes capture repeatability only. It does not turn
the cross-runtime failures into renderer-only differences.

## Reproduction

```powershell
node tools/reference/capture_menus.mjs 'Bomb It 1.swf' .artifacts/issue06/original
python tools/run_checks.py --godot <Godot-4.7.2> --suite view --visual --output .artifacts/issue06/checks
python tools/compare_images.py reference/menu-capture/original .artifacts/issue06/original --output .artifacts/issue06/source-repeat
python tools/compare_images.py reference/menu-capture/original reference/issue-06-evidence/rebuilt --output .artifacts/issue06/comparison
```

The final command intentionally exits 1 for the 11 image differences. The menu
fixture runs through the public rendered input boundary. Logs in `checks.json`
include the originating checkout paths; their retained summary and menu log do
not depend on those paths remaining available. On the shared Windows host, the
runner was serialized with the integration workflow's native-render lock.

## Review and limits

Review against the recorded starting revision found no missing #6 route or
source-backed presentation feature requiring another implementation. This change
contains evidence and documentation only. The prior implementation review fixed
mixed-device press ownership and retained its failing-before/passing-after
rendered regression. No new behavior was added, so no new red/green test was
invented for this documentation pass. The TDD skill and already approved public
runner/rendered-output seams were used for the audit.

Back/Escape, platform help text, enlarged touch targets, fixed BEST quality,
local scores and unavailable portal notices are deliberate platform differences.
Other color, edge, sampling and compositing differences remain incompletely
attributed; none is waived or proven to be renderer-only. The wide comparison
includes both applications' outer background. Original reference evidence stays
separate from Linux port regression baselines, which are unchanged.

This closes #6's implementation/evidence scope with documented deviations; it
does **not** establish exact visual parity, Adobe Flash Player equivalence,
physical iPhone touch behavior, or native release readiness. Selection, HUD and
outcomes remain owned by their separate tickets. The integration owner maintains
the parent completion checklist and final integration review.
