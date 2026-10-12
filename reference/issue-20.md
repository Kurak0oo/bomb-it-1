# Issue 20 — iPhone configuration and external device gate

Configuration is implemented; ticket #20 remains partial. No iOS export, signed application, installation or cold launch has been performed. The available host is Windows, the user has no Mac, and a genuine Apple Team ID and owned bundle identifier have not been supplied. Existing desktop touch, inset and interruption evidence does not establish iPhone behavior.

## Configuration and preflight

`godot/export_presets.cfg` adds **iOS Development Project**: arm64, iPhone only, development export method, project-only output, and minimum iOS 15.0. The existing Compatibility renderer, 550×400 logical viewport, sensor-landscape orientation and 35 Hz physics remain unchanged. The development icon reuses `art/original/hud/portrait-1.png`, a recovered source portrait; no replacement artwork was generated. Godot scales this small source image for the icon slots; store-quality icon review is outside this development configuration. The Windows preset remains unchanged.

The [pinned iOS exporter header](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/platform/ios/export/export_plugin.h) specifies iOS 15.0. Its [implementation](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/platform/ios/export/export_plugin.cpp) maps device family 0 to iPhone and derives the required icon sizes from the configured base image. The [shared Apple exporter](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/editor/export/editor_export_platform_apple_embedded.cpp) maps sensor-landscape to both landscape orientations and requires a Team ID before its project-only path. Blank identities are intentional; no deployable placeholder is checked in.

```powershell
python tools/ios_preflight.py --godot C:/Users/Eiji/AppData/Local/Godot/Godot_v4.7.2-stable_win64_console.exe --output .artifacts/ios
python -m unittest tools.tests.test_ios_preflight tools.tests.test_package_commands -v
```

The public preflight checks the configuration, exact pinned engine, template version and presence, identity **format**, and macOS/Xcode/iPhoneOS SDK availability. It writes `preflight.json` and returns 2 if blocked; 0 means prerequisites for project export were found, never a signing or device pass. It records revision, source/instrumentation hashes, preset/tool hashes and the installed iOS template hash. It never exports, signs, installs, writes preference data, or prints supplied identity values. Hashing identifies the template; use the officially verified distribution described in [issue 19](issue-19.md) to establish its provenance.

Set `BOMB_IT_IOS_TEAM_ID` and `BOMB_IT_IOS_BUNDLE_ID` only to the actual account's values when available. These are preflight inputs, **not Godot export overrides**; Apple ownership, eligibility and provisioning are not validated by the command. The original preset remains blank. `--templates` can select a matching template directory; otherwise macOS uses `~/Library/Application Support/Godot/export_templates/4.7.2.stable`.

## Reproduction once Apple access exists

Godot requires macOS with Xcode, matching templates, a genuine 10-character Team ID and unique bundle identifier. Open Xcode, finish setup/license acceptance, and ensure `xcode-select -p` selects Xcode's developer directory and `xcrun --sdk iphoneos --show-sdk-version` succeeds. Use a space-free exported project name. These requirements and the export-to-Xcode procedure are documented in [Godot 4.7's iOS guide](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_ios.html).

1. Check out the exact committed candidate and install Godot 4.7.2 plus its verified templates on the Mac. Record `git rev-parse HEAD`, Godot version, macOS version, Xcode version and SDK version. Run the preflight with genuine identity environment values; retain its report.
2. Export a fresh source copy with `git archive HEAD godot | tar -x -C "$IOS_STAGE"`, where `IOS_STAGE` is a new empty directory outside the checkout. Open that copy in Godot. In the existing **iOS Development Project** preset, enter the genuine Team ID and owned bundle identifier. Keep credentials and provisioning assets outside version control. Do not edit the tracked blank identities.
3. Import the staged project, then export **Debug** to an empty output directory using project name `BombIt`. The equivalent command after configuring the staged preset is `"$GODOT" --headless --path "$IOS_STAGE/godot" --export-debug "iOS Development Project" "$IOS_OUTPUT/BombIt.ipa"`. Project-only mode should produce `BombIt.xcodeproj`; this is not a signed IPA. Keep the export log and hash the exported files. This Mac command is documented for reproduction and has not been executed here.
4. Open the project in Xcode, configure the real development team/signing and select the physical iPhone. Follow [Apple's device run procedure](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices), resolving actual account/provisioning/device prerequisites there. Build, sign and install. Record the signing method without secrets, build logs, application checksum, iPhone model, iOS version and deployment result.
5. Terminate the installed app and launch it from the phone's Home Screen. Record cold launch, a playable match, both landscape orientations, reachable controls/safe area, mute persistence, background/focus interruption and intentional match resume. A simulator, Xcode project, unsigned build or desktop capture cannot replace this gate. Broader device acceptance remains ticket #22.

An owned Mac is not the only future toolchain route: [GitHub provides standard macOS runners without runner-minute charges for public repositories](https://docs.github.com/en/actions/reference/runners/github-hosted-runners). A hosted project build would still need genuine identity inputs and a separate device installation path. No hosted workflow was dispatched or added, credentials acquired, signing configured or service purchased for this bounded slice.

## Validation and remaining evidence

TDD used the approved public-command seam. The missing-identity case first failed because no readiness report existed; the implemented command reports identity/toolchain blockers without creating an Xcode project. The configuration case first failed because no configuration report existed, then passed with the source-backed preset. Five focused iOS/Windows packaging tests pass. These tests are discovered by the existing public runner's tooling phase. No gameplay code changed and no shared screenshot delta is expected.

The actual Windows report in `issue-20-capture/preflight.json` recognizes engine `4.7.2.stable.official.ed1daf0bf` and templates `4.7.2.stable`. It reports only `team_id`, `bundle_identifier` and `macos_xcode` as missing prerequisites. The command exits 2 as intended. Its revision and fingerprints identify the tested configuration. The code was reviewed against starting revision `2b312f6`; no Apple export/signing/device result is inferred from these checks. **Do not close #20 until the signed real-device installation and cold-launch evidence above exists.**
