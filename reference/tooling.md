# Validation and reference tooling

## Local checks

Use Python 3.11+ and the Godot version in `tools/godot-version.txt`:

```powershell
python -m pip install -r tools/requirements.txt
python tools/run_checks.py --godot <godot-executable>
```

The runner verifies the engine version, imports the project, compiles Python,
runs tooling tests, checks the reference script's GDScript types, and runs the
seven existing Godot suites. Each phase has a timeout and a separate log; engine
errors fail a phase even when its process exits zero. `summary.json` records the
result. Logs default to `.artifacts/checks`.

Use `--suite sim` (or another named suite) for a focused iteration. `--project`
can point to a fresh project copy without an import cache. `--timeout` sets the
per-phase limit. The PowerShell wrapper retains `-Godot` and `-Visual` support.

`--visual` adds rendered UI and animation checks. Every run writes screenshots
to a new capture directory, printed by the runner, with engine/renderer metadata.
Tests ignore saved game preferences. Screenshot write failures are failures, and
button bounds are checked across screens after layout has settled.

## Visual baselines and CI

The workflow runs headless checks on pull requests and pushes to main. A separate
job builds `tools/ci/Dockerfile` and runs the rendered checks with Linux Mesa
llvmpipe. The same container is usable locally:

```powershell
docker build -t bomb-it-checks -f tools/ci/Dockerfile .
docker run --rm --init -v "${PWD}/.artifacts/linux-checks:/artifacts" bomb-it-checks
```

The image uses the pinned Godot release and verifies its download against the
release's SHA-512 manifest. Pillow and reference-browser packages are pinned.
The container keeps GPU and operating-system differences out of normal screenshot
review. Its Ubuntu package versions are recorded with the approved baselines;
rebuilding against updated system packages may require a reviewed baseline update.

`reference/visual-baselines` contains approved images. Captures never overwrite
them. The comparator fails on missing images, size changes, and changed pixels:

```powershell
python tools/compare_images.py reference/visual-baselines <capture-directory> --output .artifacts/visual-diff
```

It writes a JSON report and baseline/current/difference triptychs. The default is
exact comparison; explicit tolerance options are available for diagnostic use.
CI uses exact comparison. A baseline update means inspecting the new captures and
comparison images, then explicitly copying the approved PNGs and runtime metadata
into the baseline directory. Include those changes in review. The command has no
automatic baseline-approval mode. CI uploads logs and comparison artifacts even
when a suite fails.

## Original SWF reference capture

Prerequisites: Java 22+, FFDec 26.3, Node 22+, the pinned Godot, and the image tools
above. Install the browser harness once:

```powershell
npm ci --prefix tools/reference
$env:PLAYWRIGHT_SKIP_BROWSER_GC = '1'
Push-Location tools/reference
npx playwright install chromium
Pop-Location
python tools/capture_reference.py --ffdec <ffdec-directory> --godot <godot-executable>
```

The builder creates an instrumented copy under `.artifacts/reference`; the
original SWF is read-only. It retains original character definitions, JPEG tables,
and the first-frame function bytecode from Sprite 564. Scene setup is replaced
with a small fixed fixture. Original `hurtHero`, `bombExp`, and `brickBreak` execute
in Ruffle 0.7.1; their bodies are not translated from the Godot port or rewritten
as test expectations. The SWF stays version 7 at 35 fps.

Fixtures: one character death; a level-one explosion on an empty board; the same
explosion with a brick in its right arm. AI, map generation and player input are
excluded. Random item appearance is outside the sampled state. The observer uses
Flash `trace`, available in SWF 7, and pauses Ruffle after each observed tick.
Death images export the game canvas, excluding Ruffle's pause controls.

Tick zero is the first update after fixture creation. The original and rebuilt
fixtures each record 40 updates. Nine death images cover the hero/silhouette swap,
fade and removal boundaries. Traces include death frame/visibility, center and arm
energy, brick blocking, and explosion visibility. The comparator requires identical
scenario sets, contiguous ticks, and matching observation fields. It never shifts
ticks to manufacture agreement. It reports the first divergent tick and every
field difference.

Metadata includes SWF/fixture/harness hashes, Ruffle package integrity, Chromium
version and Godot version. This is **original bytecode running in Ruffle**, not a
claim of Adobe Flash Player equivalence. The controlled fixtures do not establish
full-match callback ordering, RNG parity, damage coordinates or native phone behavior.

The capture command exits zero when the harness completes, even if comparison
reports contain differences. `--require-parity` also makes observed differences a
nonzero exit. Harness errors always fail. These distinctions keep diagnostic
evidence separate from the game's regression gate; accepted gameplay is untouched.

## Source navigation

```powershell
python tools/inspect_symbol.py 237 --frames 1 6 36
python tools/inspect_symbol.py 326 --json
```

The inspector reports 1-based frames, held-placement durations, labels, scripts,
transforms, opacity and direct dependencies. Graphic matrices are reported in their
original XFL units; this command does not silently normalize them. Unknown symbols
exit nonzero. Geometry is omitted to keep output useful.

The optional CodeGraph database under `godot` currently reports no indexed code.
Use normal source search in that case; these tools do not create an index.
