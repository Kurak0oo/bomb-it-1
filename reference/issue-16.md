# Issue 16 — landscape safe areas

Starting revision: `f26207e`. This is layout/input work; 35 Hz simulation, timers,
RNG and award policies are unchanged.

## Coordinate contract and layout

The game remains a complete 550×400 surface. With touch controls visible, layout
reserves either two 140-unit side gutters or a 140-unit bottom strip, selecting
the arrangement that preserves the larger game image. The complete stick and
Bomb hit circles stay outside the game, with space between targets and content.
The narrow fallback scales the complete HUD and arena together; it does not cover
or crop either. Controls remain at their logical size independently of game scale.

Native Android/iOS safe rectangles come from
[`DisplayServer.get_display_safe_area`](https://docs.godotengine.org/en/stable/classes/class_displayserver.html#class-displayserver-method-get-display-safe-area).
Desktop uses the full viewport, avoiding desktop taskbar bounds masquerading as
phone insets. An optional provider represents this OS boundary for desktop
fixtures; its contract is a physical rectangle in absolute display coordinates.

Conversion accounts for the native Window origin, then inverts the viewport
screen/stretch transform. The public viewport transform is relative to its
containing window: [Godot Window implementation](https://github.com/godotengine/godot/blob/master/scene/main/window.cpp)
only includes native window position when its internal absolute-position flag is
set. This matters in the nonzero-window-origin fixtures. Logical bounds are
intersected with the viewport before arranging the content. Size changes update
layout synchronously; inset-only changes are consumed before the next draw.

Touch controls initialize their geometry before drawing, convert delivered points
through their inverse canvas transform, and cancel captured input when layout
changes. Project orientation is sensor-landscape (4), permitting both landscape
orientations; [official orientation enum](https://docs.godotengine.org/en/stable/classes/class_displayserver.html#enum-displayserver-screenorientation).

## Evidence boundary

The approved public runner executes rendered viewport input and records geometry,
images and runtime metadata. These are **desktop synthetic safe-area tests**, not
native iPhone evidence. Physical rotation delivery, actual notch/home-indicator
insets, thumb comfort and on-device HUD readability remain device acceptance work.
No desktop fixture is labeled as a tested iPhone model.

The red/green cases cover old controls overlapping the arena, clipped content and
targets under insets, and held touch surviving a same-aspect physical resize.
A strengthened nonzero-window-origin fixture distinguishes display coordinates
from window-local pixels. Matrix cases span native/narrow, compact landscape,
mirrored asymmetric insets, four-edge insets, and an additional content-scale factor.

Reproduction:

```powershell
python C:/Users/Eiji/.codex/bomb-it-integration-20261012/exclusive.py python tools/run_checks.py --godot <godot-executable> --suite sim --visual --output .artifacts/issue16-checks
```

Shared Linux baselines remain integration-owned; `qa-touch.png` and new layout
captures require root review. Existing arena/HUD artwork is unchanged.

## Validation and review

The final matrix delivers touch, drag and mouse events as physical window pixels
via `Viewport.push_input(event, false)`. Godot converts them to viewport coordinates
before the scene handles them. Stick/Bomb input succeeds before drawing and after
rendering. Real Window resizes are checked synchronously without invoking a layout
helper or a process callback first; the same-size mirrored-inset case exercises
pre-draw inset polling. Scaled HUD Pause and overlay Resume buttons also receive
physical input before drawing. A deliberately scaled/translated touch Control
checks the inverse transform for both press and drag. Layout changes do not tick
gameplay. Geometry containment permits only 0.01 physical pixel for float rounding;
no image-comparison tolerance changed.

[Rendered matrix](issue-16-capture/matrix.png), individual captures,
[physical geometry trace](issue-16-capture/layout-trace.json), runtime metadata,
four red logs and the green runner summary are retained. Simulation and all ten
rendered phases passed in `issue16-physical-input` (`e556ac7e25fc`).

Reviewed against the starting revision for full-content bounds, retained original
art, OS/window/stretch coordinate ownership, input reset on resize, before-draw
initialization, and scene/touch-toggle lifecycle. Review strengthened the initial
window-local test fixtures to absolute display coordinates and exposed the missing
native-window-origin subtraction before handoff. Desktop Godot screenshots and the
narrow/asymmetric contact sheet were visually inspected; no real-device acceptance
is inferred from them.

After merging integration (including issue 12), tooling, source-capture parse
checks and simulation passed again; retained in `post-merge-summary.json`.
