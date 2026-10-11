# Menu implementation review

Fixed point: `0d3b2d18b67db1dcffc5c8468c110e0976748c25`.
Implementation: `197bc1c`; reviewed correction: `ee82468`.
Diff: `git diff 0d3b2d18b67db1dcffc5c8468c110e0976748c25...ee82468`.

Two independent agents reviewed Standards and Spec in parallel. The spec sources
were the published #24–#26 ticket bodies; root `AGENTS.md` supplied repository
guidance. No nested coding standards were found. Earlier game changes were
excluded from this review.

## Standards

No documented-standard violations found.

The initial review identified one possible Primitive Obsession / Data Clump with
a concrete input failure: shared `captured`, `finger` and `pressed_key` fields
did not establish exclusive ownership. Holding Enter, pressing the mouse over
Help, then releasing Enter activated Help before mouse release. Touch and
keyboard could similarly overwrite one another.

The finding is resolved in `ee82468`. `PressOwner` prevents another input device
from replacing or completing an active press, and cancellation clears ownership.
Rendered regressions failed before the correction and pass afterward, covering
both interference paths and stale releases. The follow-up review found no
further actionable standards issues.

Standards: **0 hard violations; 1 finding fixed; 0 unresolved heuristic findings.**

## Spec

No actionable Spec findings. The three tickets' navigation, original artwork,
button states, player-count handoff, sound retention, platform instructions and
independent reference captures are implemented within scope. Input suppresses
key echo, orphan releases, emulated mouse events and double-click/tap follow-ups;
cancellation clears pending activation.

All 11 source-versus-port comparison pairs still differ, with unexplained
differences retained explicitly. This satisfies the requirement to report
differences rather than manufacture parity. Selection, HUD and results remain
outside this slice; no unrelated gameplay changes were found.

The follow-up review confirmed that explicit press ownership and its regressions
remain within the approved input/navigation scope, with no further Spec issues.

Spec: **0 actionable findings; exact visual parity remains unverified.**

## Verification after review

The full Windows suite had passed all 17 phases before review. Focused public
runner checks passed after the ownership correction. Fresh Linux import,
view/timeline and rendered checks, and exact comparison of all 23 reviewed port
regression images also pass after the correction. Machine-readable results are
in [validation.json](menu-capture/validation.json). Original-playback comparison
remains a separate failing diagnostic, recorded without tolerance changes.

Final totals: Standards **0 unresolved** (1 fixed); Spec **0 actionable**.
