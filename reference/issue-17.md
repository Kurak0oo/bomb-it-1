# Issue 17 — interruption and resume

Starting revision: `200706f`. Approved seams: public check runner, rendered
viewport input and screenshots, lifecycle notifications delivered through the
SceneTree, and meaningful state/audio-stream observations. Simulation remains
35 Hz; timer, RNG, scoring and collision policies are unchanged.

## Behavior and source boundary

Focus loss and application backgrounding are independent reasons for suspension.
An active match pauses, cancels both players' pending/held input and touch
captures, suspends music and effect streams, and waits for deliberate Resume.
Both platform reasons must clear before Resume or Main Menu can act. Repeated
notifications are idempotent. An already paused match stays paused on return.

An interrupted outcome also waits for Resume: its banner/score delay and death
presentation stop while away. This preserves the outcome for the returning
player. A key release held across the interruption cannot skip it. Fresh source
key-up skip and Continue still work after resume. The first display delta after
return/resume is discarded, preventing background wall time from entering the
outcome clock. Idle menus cancel their captured press and suspend while away,
then become usable directly on return; they gain no extra Resume screen.

Suspension is separate from the saved mute preference. Scene boundaries reset
shortcut ownership; released fire sources re-arm even when their old release
is discarded. Hidden controls still cancel pending touch. Freezing/unfreezing
the view aligns hero, moving bomb and projectile interpolation endpoints with
the last accepted position, preventing a backward render before the next tick.

Original source [`pause()` in Sprite 564](../extracted/scripts-as/scripts/DefineSprite_564/frame_1/DoAction.as#L1302)
only toggles `pausing` and the parent music button's enabled state. It does not
suspend the music. Audio suspension and the interruption overlay are documented
platform adaptations, not a claim about Flash pause audio. Music selection,
effect pooling/deduplication and mute playback semantics remain the #10 audit;
this ticket does not change them.

## Verification

`interruption_render_check.gd` exercises actual menu, keyboard, mouse and touch
delivery, with platform notifications at the OS boundary. Retained red logs
show active effects continuing, premature resume while still backgrounded,
outcome time advancing while away, a backward interpolated hero, a stale key-up
skipping the restored outcome, and the new scene's first fire tap being lost.

The green checks cover overlapping notifications in both orders, deliberate
resume, idle menu cancellation/return, actual source-ready outcome skip after
resume, two simultaneous players, hidden touch controls, scene changes, and both
mute values surviving fresh application instances in isolated `user://` data.
Only accepted simulation ticks consume the round clock. Audio observations use
real AudioStreamPlayers with the Dummy driver; they verify stream suspension,
not speaker output or native audio-session recovery.

The existing UI result snapshot now explicitly samples Symbol 563 frame 70
(settled banner and source skip readiness) with automatic presentation updates
disabled. It no longer captures a host-speed-dependent point in the bounce.
Elapsed-time behavior remains covered separately by the interruption test.

Reproduce with the public runner:

```powershell
python tools/run_checks.py --godot <godot-executable> --suite sim --suite view --suite tooling --visual --output .artifacts/issue17-checks
```

Native rendered runs in the shared Windows workspace additionally use the
integration `exclusive.py` wrapper. Ticket evidence is in
[`issue-17-capture`](issue-17-capture/). Integration owns shared Linux baselines:
`qa-result.png` changes to a deterministic settled banner and
`qa-interruption-paused-2p.png` is new. No image tolerance was relaxed.

## Limits

These are Windows desktop synthetic lifecycle notifications and rendered input,
not native iPhone evidence. Physical home/background transitions, calls, locks,
audio-route changes, OS suspension/termination and device restore remain #22
acceptance work. No Mac/Xcode/device run is claimed. The parent integration
review owns the overall completion ledger and final baseline approval.
