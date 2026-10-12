# Issue 2 — all four death animations

Starting revision: `0dc29e1` (the integrated issue 3 result). Accepted 35 Hz simulation and original artwork are preserved.

## Changes and acceptance

- **Creation, swap, fade, removal:** original and port now capture 40 images: literal creation plus the existing nine observations for each character. Creation has a separate name and pause barrier; the existing tick origin is unchanged. All six original/port traces still agree for 40 updates each.
- **Correctable input differences:** the silhouette now quantizes the opaque vector fill's alpha through the source 8-bit color transform before blending. Original frame six is gray 205 over white, frame seven gray 175; the previous port produced 204 and 174. The shadow gradient retains the full source fixed-point matrix instead of the SVG export's four-decimal rounding. Geometry, depth, visibility, clip lifetime and authoritative state are unchanged.
- **Remaining image differences:** independently attributed through original drawing controls, rather than visual resemblance. Exact port/reference pixel parity remains false; the diagnostic diffs are retained at zero tolerance.
- **Checklist:** the parent already initialized the eight-area completion checklist and owns its updates. This document supplies the death slice's verified behavior and limits.

## Independent renderer controls

`tools/capture_death_controls.py --replay` preserves original bytecode, matrices, clip timelines and color transforms. `IsolateDeath.java` replaces only unrelated drawing definitions with empty clips. It captures body, burst, silhouette, eyes, shadow and smoke separately in the original runtime and port.

`DeathInputs.java` separately reads drawing inputs from the original SWF. A Canvas control draws those inputs from source bitmap channels, SVG paths and original display-list matrices; it never reads a screenshot or a port asset. All **360 isolated source images match the control exactly** (six components, plus black-backed eye/smoke/burst controls, × four characters × ten observations). Black backgrounds expose white fills that disappear in a white-backed comparison. This establishes registration, geometry, sampling inputs, source alpha and timing separately from Godot's rasterization.

The full independent composite matches 32/40 source images exactly. The other eight differ only at burst/silhouette overlap pixels by one channel level. `controls/replay/composite-attribution.json` retains every coordinate, original/control value, isolated burst value and isolated silhouette value. These are composite rounding differences between otherwise exact component inputs. The exact comparison remains failed; there is no shifted capture, exclusion mask or relaxed tolerance.

The **actual Godot/source** comparison still differs in 32/40 images, totaling 35,236 pixels. [Actual attribution](issue-02-capture/actual-attribution.json) maps every sample's before/after count and actual differing coordinates to its component evidence. Of those pixels, 34,724 occur at independently differing component pixels. The remaining 512 differ by exactly one channel level where independently identical eye/silhouette (500 pixels) or shadow/silhouette (12 pixels) inputs overlap; their original/port component values and full composite values are retained individually. This is distinct from the 152 one-level overlap differences in the source-only replay. Both exact reports remain failed.

| Component | Demonstrated rendering path |
| --- | --- |
| Body | Original per-layer bitmap matrices; JPEG3 decode and alpha, plus raw lossless feet. WASM JPEG decoding reproduces the original component exactly. Godot renders recovered PNG frames with linear sampling. |
| Burst | Original bitmap bytes and matrices. Ruffle's bitmap conversion applies alpha again to premultiplied channels; the raw-channel control reproduces every source sample exactly. |
| Silhouette / eyes | Identical source paths, transforms and quantized alpha reproduce the source exactly. Godot rasterizes the SVG texture and samples that raster at the recovered scale. |
| Shadow | Raw original bitmap before swap; source radial path and full-precision gradient after swap. The full-precision source replay is exact. |
| Smoke | Source paths, scale, position, alpha and drawing order reproduce the source exactly. The port samples its recovered flattened timeline PNGs. |

### Bitmap encoding and runtime provenance

The captured runtime is Ruffle 0.7.1, commit `89a7049965f3090e706265670df309a5128233ac`, Chromium 156.0.8078.4, Canvas renderer. Original SWF version is 7. The pinned [SWF reader](https://github.com/ruffle-rs/ruffle/blob/89a7049965f3090e706265670df309a5128233ac/swf/src/read.rs#L1629) disables bitmap smoothing for versions below 8, even when fill type is 0x41. The control preserves that runtime behavior; production art is not changed to emulate it.

[Adobe's SWF 19 specification, printed page 143](https://open-flash.github.io/mirrors/swf-spec-19.pdf#page=145) defines the lossless RGB channels as already multiplied by alpha. Bitmap 238 pixel (35,13) contains raw `(126,101,0,128)`. Its recovered straight-alpha PNG is `(251,201,0,128)`. Over white, the recovered PNG gives `(253,228,127)`; Ruffle's original output is `(190,178,127)`. Feeding the raw premultiplied channels to Canvas `ImageData` reproduces that darker value. This is an emulator conversion difference, not a reason to darken the preserved bitmap.

The pinned [Canvas backend](https://github.com/ruffle-rs/ruffle/blob/89a7049965f3090e706265670df309a5128233ac/render/canvas/src/lib.rs#L162) passes the bitmap bytes to `ImageData`; the [bitmap type](https://github.com/ruffle-rs/ruffle/blob/89a7049965f3090e706265670df309a5128233ac/render/src/bitmap.rs#L389) declares those bytes premultiplied. Source-over composition is `Cout = Csrc × alpha + Cdst × (1 − alpha)` when Canvas treats input channels as straight. The control preserves this conversion, including its quantization, solely for attribution.

JPEG3 controls use the original compressed JPEG and alpha bytes, the runtime's [jpeg-decoder 0.3.2 dependency](https://github.com/ruffle-rs/ruffle/blob/89a7049965f3090e706265670df309a5128233ac/Cargo.lock#L2929), WASM SIMD, and its [alpha clamping rule](https://github.com/ruffle-rs/ruffle/blob/89a7049965f3090e706265670df309a5128233ac/render/src/utils.rs#L224). Native JPEG decoding differs slightly; using the same WASM path makes all body/burst components exact. No decoded control image is used by the game.

## Evidence and reproduction

Evidence: [issue-02-capture](issue-02-capture/). `before` and `final` retain full original/port images, exact differences and traces. `controls` retains all component captures, exact comparisons, original decoded input controls and replay reports. `checks` retains the observed alpha red/green logs and focused checks.

```powershell
python tools/capture_reference.py --ffdec C:/Users/Eiji/AppData/Local/FFDec --godot C:/Users/Eiji/AppData/Local/Godot/Godot_v4.7.2-stable_win64_console.exe --output .artifacts/death-final
rustup target add wasm32-wasip1
python tools/capture_death_controls.py --ffdec C:/Users/Eiji/AppData/Local/FFDec --godot C:/Users/Eiji/AppData/Local/Godot/Godot_v4.7.2-stable_win64_console.exe --output .artifacts/death-controls-final --replay
python tools/run_checks.py --godot C:/Users/Eiji/AppData/Local/Godot/Godot_v4.7.2-stable_win64_console.exe --suite timeline --suite view --visual --output .artifacts/death-alpha-green-final
```

Use the session's `exclusive.py` wrapper for native rendered commands. Source replay additionally needs Cargo with the `wasm32-wasip1` target; its only Rust dependency is locked. The normal game and check runner do not acquire a Rust dependency.

Reviewed against the starting revision: production changes are confined to presentation alpha and recovered gradient precision; source control tooling never changes game state. The old internal float-alpha assertion was replaced by exact observed rendered pixels, retaining timing and removal checks. Timeline/view and all rendered phases pass; simulation/tooling checks pass. Shared Linux screenshot baselines remain root-owned. Expected shared changes are small death fade/shadow pixels only.

Adobe Flash Player certification and renderer-wide pixel parity are not claimed. The remaining exact image failures are preserved with specific source/renderer controls.

## Actual zero-tolerance difference counts

| Sample | Hero 1 before → after | Hero 2 | Hero 3 | Hero 4 | Active component evidence |
| --- | ---: | ---: | ---: | ---: | --- |
| creation | new → 1895 | new → 1908 | new → 1942 | new → 1839 | body, burst, shadow |
| frame-00 | 1895 → 1895 | 1908 → 1908 | 1942 → 1942 | 1839 → 1839 | body, burst, shadow |
| frame-04 | 2025 → 1633 | 2025 → 1633 | 2038 → 1644 | 2038 → 1644 | burst, silhouette, eyes, shadow |
| frame-05 | 2289 → 1920 | 2289 → 1920 | 2305 → 1931 | 2305 → 1931 | burst, silhouette, eyes, shadow |
| frame-10 | 366 → 371 | 366 → 371 | 389 → 393 | 389 → 393 | silhouette, eyes, shadow |
| frame-11 | 425 → 428 | 425 → 428 | 450 → 454 | 450 → 454 | silhouette, eyes, shadow |
| frame-19 | 317 → 316 | 317 → 316 | 317 → 316 | 317 → 316 | shadow, smoke |
| frame-20 | 314 → 314 | 314 → 314 | 314 → 314 | 314 → 314 | shadow, smoke |
| frame-34 | 0 → 0 | 0 → 0 | 0 → 0 | 0 → 0 | removed; exact |
| frame-35 | 0 → 0 | 0 → 0 | 0 → 0 | 0 → 0 | removed; exact |
