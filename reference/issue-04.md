# Ordinary effects and normal pickups — ticket #4

Starting revision: integration `65692e0`. This slice changes presentation only. The accepted 35 Hz simulation, damage, energy, bomb inventory, item selection and callback order are unchanged.

## Acceptance evidence

- Bomb creation, the 40-frame animation loop, expiry and resulting flame creation agree with original execution. Creation is observed separately at tick −1; tick 0 remains the first update, without alignment shifts.
- All four character flame colours were compared through three growth updates, linger, four visible fade steps and removal. The source's successive alpha assignments are 256, 204, 152, 100 and 48 in 256-unit storage. The view now uses these presentation values while preserving simulation alpha and energy.
- Brick burst frames 1–10 and removal at source frame 11 agree. The port previously retained the already-transparent exported frame 11; it now hides that presentation node while authoritative lifetime stays unchanged.
- Life, glove, bomb allowance, shield, power and shoe pickup variants retain their source identities, transforms, depth and shadows. Their nested Symbol 293 frames select static shapes 280–285. Symbol 326 frame 80 jumps immediately to frame 1: the displayed idle period is **79**, corrected from 80. Removal begins at frame 81 and ends at 101.
- Pickup removal now applies the source colour transform to each recovered fill before overlap composition. Fading a flattened PNG incorrectly preserved bright highlights. `prepare_assets.py` reproduces six sets of 20 removal SVGs directly from the original paths, source alpha and full XFL gradient matrices. Idle assets remain unchanged. Textures load into a small lazy cache; no extra runtime drawing nodes are added.

All **305 creation/update observations** agree across seven original-bytecode scenarios. All **134 source-only drawing replays** exactly match original runtime screenshots. These are separate from actual port pixels: **94/134 actual comparisons still differ**, and every exact report remains failed. This is not a claim of Adobe Flash Player certification or renderer-wide pixel parity.

## What changed and how it was checked

The independent fixture retains the original `putBomb` and `bombExp` bytecode and every original symbol script. Brick and pickup clips are attached as controlled presentation fixtures; pickup removal is commanded at tick 85. Six normal variants appear together, so each pickup sample verifies all six icons and shadows. Browser clock advancement rejects skipped observations; the one rejected creation-barrier attempt is retained. No tick was discarded or shifted to obtain agreement.

Observed red → green checks at the public rendered boundary:

| Behaviour | Before | After / independent source |
| --- | --- | --- |
| Pickup image at ages 1 and 80 | Different | Identical after the 79-update period |
| Flame1 tick 16, pixel (247,187) | (251,217,232) | (252,219,234) |
| Life pickup tick 94, overlap pixel (76,180) | (240,251,254) | (199,237,246) |

The last check samples a fully covered highlight/body overlap. A nearby sample at (78,178) still differs by one quantum across rasterizers; it was not used to relax the image comparator. Exact whole-image differences, including that pixel, remain retained. The old Sprite-alpha-only assertion was replaced by the rendered overlap observation; creation/removal lifetime checks remain.

The native rendered regression adds `ordinary-pickup-loop`, `ordinary-pickup-fade` and `ordinary-flame-fade`. Their retained Windows captures are exact review artifacts. Shared Linux baselines remain root-owned and require their normal reviewed update. Expected shared deltas are pickup phase after 79 updates, normal pickup removal highlights, and small flame fade changes.

## Exact pixel differences and attribution

| Scenario | Actual images differing | Before changed pixels | After changed pixels | Source replay changed pixels |
| --- | ---: | ---: | ---: | ---: |
| Bomb and ensuing flame | 17/21 | 47,429 | 36,864 | 0 |
| Brick burst | 6/19 | 10,756 | 10,756 | 0 |
| Flame colour 1 | 14/19 | 52,705 | 42,140 | 0 |
| Flame colour 2 | 14/19 | 52,823 | 45,380 | 0 |
| Flame colour 3 | 14/19 | 52,952 | 42,211 | 0 |
| Flame colour 4 | 14/19 | 51,913 | 41,722 | 0 |
| Six normal pickups | 15/18 | 76,865 | 76,922 | 0 |
| Total | 94/134 | 345,443 | 295,995 | 0 |

The corrected pickup phase and fill composition need not monotonically reduce the number of changed edge pixels. [actual-counts.csv](issue-04-capture/actual-counts.csv) retains every actual before/after count, alongside the independent source-replay count. [Contact sheet](issue-04-capture/contact.png) shows original, before and after. Original and port captures are never substituted for one another.

Each differing bomb, flame and brick sample has an **exact source-input replay** using original bitmap channels, fill geometry, frame selection and placement. The pinned Ruffle Canvas path interprets premultiplied source channels through `ImageData` and disables bitmap smoothing for SWF 7; the port draws recovered straight-alpha PNGs through Godot. This same independently isolated bitmap path was established in [ticket #2](issue-02.md). No port artwork is darkened to emulate it. [Asset audit](issue-04-capture/asset-audit.json) verifies all 75 underlying PNGs byte-for-byte against the extraction and all four symbols' registration offsets against source bounds.

Each differing pickup sample likewise has an **exact source-path replay**, including separate shadow and icon layers, static nested variant, original matrices, every solid/gradient fill and source alpha. This exposed and corrected the real flattened-fade defect rather than classifying it as rasterization. Remaining pickup differences come from source paths rendered by Canvas versus recovered PNG/SVG rasterization and Godot texture sampling/compositing. The audit verifies unchanged path geometry for all 120 removal assets. Source gradients use full recovered matrices in production. The control additionally reproduces the pinned Canvas renderer's simple-gradient endpoint quantization to twips; that emulator-specific gradient construction is not baked into production art.

The relevant pinned Ruffle source is [bitmap/global alpha handling](https://github.com/ruffle-rs/ruffle/blob/89a7049965f3090e706265670df309a5128233ac/render/canvas/src/lib.rs#L310), [gradient construction](https://github.com/ruffle-rs/ruffle/blob/89a7049965f3090e706265670df309a5128233ac/render/canvas/src/lib.rs#L1023), and [fixed-point endpoint transformation](https://github.com/ruffle-rs/ruffle/blob/89a7049965f3090e706265670df309a5128233ac/swf/src/types/matrix.rs#L128). All 134 replay matches depend only on source inputs and original observations, not port screenshots or assets. No tolerance, masks or replacement artwork were introduced.

## Reproduction and retained evidence

```powershell
python tools/capture_effects.py --ffdec C:/Users/Eiji/AppData/Local/FFDec --godot C:/Users/Eiji/AppData/Local/Godot/Godot_v4.7.2-stable_win64_console.exe --output .artifacts/effects --replay
python tools/run_checks.py --godot C:/Users/Eiji/AppData/Local/Godot/Godot_v4.7.2-stable_win64_console.exe --suite timeline --suite view --suite sim --suite tooling --visual --output .artifacts/effects-checks
python tools/analyze_effects.py <before-capture> <after-capture> --output .artifacts/effects-analysis
```

Use the session `exclusive.py` wrapper for native rendered runs. `--replay` additionally requires the diagnostic Rust `wasm32-wasip1` target; the game and normal runner do not depend on Rust. `--require-parity` fails on retained actual differences. Control replay failures always fail the capture command.

Evidence is in [issue-04-capture](issue-04-capture/): `before`, `final`, source `controls`, exact reports, raw drawing inputs, provenance, traces and red/green logs. The initial baseline capture had a creation filename formatting mismatch; its completed images were relabelled consistently and re-compared without changing pixels or observations. The final public command succeeds without that harness defect. Reviewed against the starting revision: production changes are limited to source-backed presentation and reproducible recovered art preparation.
