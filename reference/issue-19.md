# Issue 19 — portable Windows release

The repository now provides a pinned Windows x64 release export and a public smoke command for the actual exported executable. Packages contain `BombIt.exe` with embedded game data, `README.txt`, and `package.json`; Godot's editor, source checkout and import cache are not runtime dependencies. The executable is unsigned. Portable describes installation: preferences still use the player's per-user Godot directory.

## Build and smoke

Prerequisites: Python 3.11+, the exact engine in `tools/godot-version.txt` (4.7.2), and matching official non-Mono Windows x64 debug/release templates plus `version.txt`. Install templates under `%APPDATA%/Godot/export_templates/4.7.2.stable` or pass their directory with `--templates`. The supplied release preset uses the optimized release template, embeds its PCK and disables signing. [Godot's Windows export documentation](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_windows.html) describes the editor-free release template; the [command-line reference](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html) documents `--export-release`.

```powershell
python tools/package_windows.py --godot <Godot-4.7.2-executable> --output .artifacts/windows-package
python tools/smoke_windows.py .artifacts/windows-package/bomb-it-windows-x64-<revision>.zip --verify-only
python tools/smoke_windows.py .artifacts/windows-package/bomb-it-windows-x64-<revision>.zip --output .artifacts/windows-smoke
```

The package command stages a fresh source copy, imports it, exports release mode, validates the Windows x64 executable header and writes a ZIP plus `build.json`. It records revision, source-tree dirty status, complete exported-source fingerprint, engine/template/preset/tool fingerprints, per-file sizes/SHA-256 and ZIP size/SHA-256. Reproduction means a pinned procedure with inspectable inputs; byte-identical exports across operating systems or editor builds are not claimed. Generated files default to ignored `.artifacts`; build outputs inside the checkout are restricted to ignored artifact/scratch directories. Export excludes the general test scripts and preserves the JSON art manifests required by runtime loading.

The installed official template archive was independently SHA-512-verified during integration setup: `ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079`. [Official 4.7.2 release assets](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable) provide the matching archive and checksum manifest. Each package additionally records the exact installed release-template hash.

## Exported executable boundary

`--verify-only` validates the three-file archive and its manifest without launching it. The full smoke extracts into a new unique directory and starts the same release executable twice from that directory, with no editor invocation, `--path`, external script override or source mount. It sets isolated APPDATA/XDG paths. The opt-in `--package-smoke` hook runs only after the ordinary title-screen startup and verifies that Godot's actual user-data path is beneath the supplied isolated root before any preference-changing input. Invalid isolation fails with a nonzero exit even in release mode; checks do not rely on stripped assertions.

The first process toggles mute through actual keyboard input, follows the original title/player/difficulty/character menus, moves the human, places a human-owned bomb, pauses without consuming ticks, and clicks Resume. Automatic application physics remains at 35 Hz; no session seed, actor, timer or score is patched. The second process loads and observes the persisted mute setting. Screenshots and JSON record those outcomes, executable path, engine version and release/editor feature checks. Captures are visually inspected. This is a short playable-match smoke, not campaign completion or final sustained performance acceptance. Normal launches without the opt-in argument do not attach the smoke node.

Public-command tests reject a changed executable checksum, a debug package represented as release, and an unpinned engine. The debug-package regression failed before the release-metadata gate was added. An initial exported executable without the smoke hook timed out under the smoke command; the implemented release smoke then passed. Gameplay schedule invariance also passes with the startup hook absent during ordinary tests.

## Explicit shutdown limitation

A separate exploratory release, launched normally with `--quit-after 120`, returned exit code 0 but printed two leaked ObjectDB instances and one resource still in use during MP3 teardown. Both Dummy and normal WASAPI runs reproduced it. Exact stdout and that exploratory package's provenance are retained in [abrupt-quit evidence](issue-19-capture/abrupt-quit/). The artificial quit command is:

```powershell
# Set APPDATA to a fresh isolated artifact directory first.
BombIt.exe --audio-driver Dummy --quit-after 120 --log-file <absolute-log-path>
# Removing --audio-driver Dummy reproduced the same teardown message with WASAPI.
```

The engine log file closes before these final stderr/stdout messages; both streams must be inspected. The successful smoke deliberately retires its test scene and waits one second for the existing asynchronous audio cleanup, as other rendered tests do. It does not prove ordinary window-close cleanup, and no production exit delay was added here. This evidence is handed to #10's audio audit; #21 must reassess normal close behavior and rebuild/re-smoke the final integrated candidate. No native iPhone or release-signing claim is made.


## Committed artifact and retained smoke

The final #19 artifact was built from clean commit `7fcbdb4545c3d00d74c7396a14489d5cbfcc60d6` (`source_tree_dirty: false`), including integration's #31 correction. It remains outside tracked source at `.artifacts/issue19-final/bomb-it-windows-x64-7fcbdb4545c3.zip` (43,648,537 bytes).

- ZIP SHA-256: `d1596ab41945d53b0298afb6d57d196f8c7592e582d279be720f60ea6aa4825e`
- Embedded executable SHA-256: `7295d929986f52d15b548646d348cfca84e7cbc065d52c9e0d96436df55cb645`
- Complete exported-source SHA-256: `27a13a653aafa0ef311c2a5befa55caff6531481aa3093b57c57370498b46167`

[Final build manifest, runtime reports, screenshots and isolated preference file](issue-19-capture/final/) show the actual Windows release executable from that ZIP. Both processes report `editor: false`, `debug_build: false`, and 35 Hz. The human moved from cell (3,3) to (5,3), placed its own bomb, paused and resumed; the second process restored `muted=true`. Four rendered captures were retained. All runtime checks passed, and both stdout and engine log streams are checked by the public smoke command. The artifact was tested on Windows 11 build 26200 with the RTX 3080 Laptop GPU using Compatibility/OpenGL rendering.

A deliberately wrong isolated-root path was also tested against this exact executable: it exited 1 with the isolation guard message and created no preference file. The negative result, stdout and reproduction script are retained with the final evidence. The regular executable's abrupt-quit limitation above remains separate and was passed to #10. Final #21 will rebuild and smoke the final integrated revision, including later preservation changes.
