# Issue 8 — original HUD and arena composition

Starting revision: `f79737253316dc3d805dd56af1d2eea95a66033d`.
The accepted simulation, board generation, 35 Hz timer and gameplay RNG are unchanged.

## Implemented presentation

`OriginalHud` replaces the reconstructed text panels with the source root-frame-9
background, four character portraits and eliminated-panel overlay. `ExportHudArt.java`
reads the preserved SWF and rasterizes those display-list elements at 2x; it does not
execute or rewrite gameplay. The manifest records the source SHA-256.

- Symbol 537 positions the four Symbol 536 panels at `(43.95, 47.4)`,
  `(43.95, 114.4)`, `(43.95, 181.45)`, `(43.95, 248.5)`.
- Symbol 537 `upDate()` binds **round score**, lives and available bombs. The old
  reconstructed HUD incorrectly displayed accumulated campaign totals. Numeric
  fields now use the recovered sizes/alignment and the embedded Arial Black font.
- Shield, glove and shoe slots use the source Symbol 326 transformations and
  item variants; the bomb icon uses Symbol 371. Their timelines follow the
  simulation's 35 Hz presentation sampling. Stat increases reproduce Symbol 537's
  35-frame, modulo-10 visibility feedback. Eliminated panels use Symbol 533 frame 2.
- Level and four timer digits occupy their source fields. The accepted deterministic
  timer remains unchanged. Pause, sound and touch buttons retain the existing
  reachable 550×400 controls; they are intentional platform additions.
- HUD filtering is explicitly linear. Newly exported assets are 2x with lossless
  texture import and no mipmaps. Existing arena assets and their explicit linear
  filtering remain unchanged.

## Source and depth audit

Evidence: `xfl/Bomb It 1/DOMDocument.xml` root frame 9; `Symbol 536.xml`,
`Symbol 537.xml`, `Symbol 527.xml`; extracted Sprite 537 frame-1 actions;
Sprite 564 frame-1 `calDepth`, `putBomb`, `putSpecial`, `movHero`, `brickBreak`.
The public inspector reproduces the placements:

```powershell
python tools/inspect_symbol.py 537 --frames 1
python tools/inspect_symbol.py 536 --frames 1 2 3 4
python tools/inspect_symbol.py 527 --frames 1
```

The arena origin already correctly equals `(93.1, 5.2)`. All themes retain 15×13
30-pixel cells and the source 2×2 center obstruction. The depth audit found no
correction needed: `(y * 15 + (15 - x)) * 10`, scenery offset 0, actor offset
`-(id+1)`, bomb/projectile -5, pickup -6, fire -7 and ice 0. Center scenery registers
at `(6,5)` and sorts using `(6,6)`, as in source. Floor/flame/rocket smoke remain
in the lower background plane; surviving-hit smoke remains above scenery.

The controlled crossing captures place hero 1 at `(6,4)` (depth 689), hero 2 at
`(6,7)` (1138), the center at depth 990, bombs at `(7,4)` (675) and `(7,7)` (1125),
with fire and ice alongside the center. These make rear occlusion, front overlap,
and source registration reviewable for every center/floor family. This is a
static crossing composition, not an independent callback-order or motion trace.

## Verification and retained evidence

The approved public runner includes `hud_render_check.gd`. Red: the original HUD
failed the check that changing campaign totals must not change its round-score
field. Green checks cover that behavior, original round-score location, shield
slot visibility and zero-life panel dimming, then capture every theme at native
550×400 and enlarged 1600×800, plus controlled scenery crossings.

```powershell
java --class-path '<ffdec>/ffdec.jar;<ffdec>/lib/*' tools/ExportHudArt.java 'Bomb It 1.swf' godot/art/original/hud
node tools/reference/capture_hud.mjs 'Bomb It 1.swf' .artifacts/issue08-original
python tools/run_checks.py --godot <godot-executable> --suite view --visual --output .artifacts/issue08-checks
```

Use the shared exclusive wrapper for native rendered runs as described in the
integration workflow. The source browser follows original Start, 1P, Normal and
Space confirmation; it captures the **unmodified original SWF**, not port art.

Retained under [issue-08-capture](issue-08-capture/): the original full-screen
capture and provenance; rebuilt HUD/status/enlarged images; all-theme contact
sheet; and the exact HUD diagnostic comparison. The comparison region is explicitly
`(0,0)-(88,360)`, covering the complete HUD above the platform buttons. Full original
and rebuilt images are also retained. The different random boards are not treated
as a matching arena fixture.

```powershell
python tools/compare_images.py reference/issue-08-capture/source-hud reference/issue-08-capture/rebuilt-hud --output .artifacts/issue08-hud-diff
```

This diagnostic command intentionally returns nonzero: original Ruffle and Godot
pixels differ. No tolerance or approved baseline was changed. Common Linux arena,
pause, result and touch regression baselines are owned by integration, because
other presentation tickets also change those images.

## Completion and limits

| Slice | Status |
|---|---|
| Recovered panel/icon layout and visible counter/status updates | Implemented; source data and rendered behavior verified |
| Five theme native/enlarged composition and controlled depth placements | Source-audited; rebuilt captures inspected |
| Original HUD playback comparison | Independently captured; exact pixel parity remains unverified |
| Full-match scenery crossing callback order | Not established by this static fixture |

Text differences remain visible: the original uses device-font dynamic fields
(Arial Black; Bookman Old Style Bold for level/timer), while only the source's
embedded Arial Black subset is distributable in the extraction. Level/timer use
that recovered font as an explicit substitution. FFDec 2x extraction and Ruffle/
Godot sampling also differ. The comparison retains all differing pixels; it is
**not** a proven renderer-only exception or an exact-original-parity claim.
Arena raster assets retain their existing finite resolution at enlarged sizes.
Physical iPhone legibility is outside this desktop capture evidence.
