# Audio behavior — ticket #10

Starting integration: `2b312f6`; initial synchronization: `8c04278`. Original MP3 files and artwork are unchanged. Simulation edits only append/clear an ephemeral `audio_cues` observation list; existing events, callback ordering, timer, damage, movement and gameplay RNG are preserved.

## Source audit and corrections

Sprite 564 frame 1 supplies these `vo_sound.attachSound/start` sites. [Original observations and exact mixed samples](issue-10-capture/report.json) retain the original function bytecode, nested parent scope and native Sound operations. The observer clears the prototype methods' read-only flags, logs calls, then delegates to their original implementations. [Read-back hashes](issue-10-capture/functions.json) verify all 21,432 function-prefix bytes unchanged; [provenance](issue-10-capture/provenance.json) identifies inputs.

| Event | Source cue / behavior | Port correction |
|---|---|---|
| Place ordinary bomb; explode ordinary bomb | `putBomb.wav`; `exp.wav` (lines 256, 762) | Preserve every start, including simultaneous duplicates |
| Successful push; collect accepted pickup | `pushBomb.mp3`; `tool.wav` (973, 1249) | Preserve existing triggers in the dedicated cue list |
| Place rocket / mine / grenade | `rocket.mp3` / `bibi.wav` / `grenade.mp3` (327, 401, 466) | Same source starts |
| Rocket hero/wall impact; mine trigger | One `exp.wav` (363, 379, 429, 444) | Preserve one start |
| Rocket brick/bomb impact | No direct cue (387) | Generic pulse events no longer invent a sound |
| Grenade endpoint | One `exp.wav` after all five pulse calls (500) | Five blast cells remain one sound |
| Fire hits brick | `exp.wav` after brick removal (681) | Restore missing cue |
| Gas, ice, unobstructed fire, hurt/death | No direct cue | No invented sound |

Source controls cover all six special weapons, two bomb placements/explosions, push, pickup, mute, and shared-Sound overlap. Cue sequence/multiplicity is compared; these isolated child fixtures are not a new gameplay-clock oracle. Accepted scheduling remains covered by the simulation/interaction suites.

The source double-start control has **15,908 nonzero-span samples**, each exactly twice the corresponding single-start sample: maximum error **0**, peaks **1.0000001192092896 / 2.000000238418579**. Only exact leading/trailing zeros are removed; no time shift or tolerance. [Compressed raw browser output](issue-10-capture/original.json.gz) retains every mixed sample. This supports removing per-tick deduplication and the eight-player stealing ring. Players now reuse idle voices and preserve active tails. The 32-active-instance ceiling follows the pinned [Ruffle audio implementation](https://github.com/ruffle-rs/ruffle/blob/v0.7.1/core/src/backend/audio.rs); [attached Sound.start](https://github.com/ruffle-rs/ruffle/blob/v0.7.1/core/src/avm1/globals/sound.rs) starts another instance rather than replacing the previous attached sound. That ceiling is an explicit Ruffle compatibility choice, not certification of Adobe Flash's mixer.

No source `setVolume` attenuates these sounds. The port's −15 dB music / −8 dB effects are removed. A same-backend native mixer control verifies unity gain without assuming equal decoder rounding across engines: Windows recovered-effect and direct-control peaks both **1.23222839832306**, whereas restoring −8 dB gives **0.490558952093124** and fails. These are capture-bus values before device clipping, not an exact Ruffle-versus-Godot PCM claim.

## Music, sound preference and interruption

Root frame 3 creates/loops menu music once; returning from help/selection now preserves its playback position. Root frame 9 stops it on entering gameplay. Each new stage advances the four-track playlist rather than indexing directly by stage. A retry enters Sprite 564 frame 2 directly and **restarts the same selected track without any music RNG draw**. Root frame 8 resets the ordered list/index for a new campaign; Sprite 564 frame 1 lines 1434–1443 shuffle at wrap. The literal `disorder` loop uses four draws with bound 4 and its final prior-last/new-first swap.

`GameAudio.music_rng` is an independent `OriginalRng` instance, seeded from presentation time. It never references the simulation's generator. A controlled full-original-timeline boundary case (`[3,1,2,3]` draws) independently produces `[1,2,3,4]`; the port selects those same tracks. Eight playlist selections leave both gameplay call count and generator state unchanged. This deliberately preserves the accepted gameplay RNG policy; Flash's globally shared audio/gameplay random stream is **not** claimed equivalent.

The [ticket #14 full-timeline controls copied here](issue-10-capture/music-control/summary.json) retain **500 unadapted** permutation/boundary observations with no differences, plus **505 adapted** controls including five forced boundary cases. Their raw bytes and original action hashes are retained. The earlier [truncated-function fixture](issue-10-capture/truncated-shuffle.json.gz) produced duplicated entries despite an unchanged function-prefix hash. It is scope-specific and **excluded as a shuffle oracle**; no duplicated-track corruption was implemented and no renderer cause is claimed.

Win/loss uses the recovered outcome track and retains the original `onSoundComplete` restart. Nonterminal scores stop it; terminal scores start menu music. Buttons 458/540 stop background music when muted and restart its current attachment on unmute. New effects are gated while muted; already-started tails continue. The saved preference still loads before the first music start and persists both values.

Source `pause()` (1302) does not pause sound. Ordinary pause now leaves music/effects running. The existing mobile/platform adaptation still suspends audio on focus/background interruption, preserves mute, and requires deliberate Resume for an interrupted match/outcome. A separate interruption latch prevents ordinary pause from changing that policy.

## Normal close and validation

The [before log](issue-10-capture/close/before-normal-dummy.log) reproduces #19's two leaked objects/one live MP3 resource using genuine Windows `WM_CLOSE`, not process termination. Godot's [AudioServer stop path](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/audio/audio_server.cpp) defers playback deletion through its mixing queue. Normal close now disables further application processing, stops streams, and yields until WeakRefs to **all started playbacks** expire before quitting. Repeated close requests are idempotent. A two-second failure deadline reports a warning rather than hanging; no fixed production sleep is used.

[Ten normal/repeated close probes](issue-10-capture/close/report.json) cover Dummy and WASAPI, each in menu, playing, ordinary pause, background suspension and mute. All exit 0 without teardown warnings/errors, in 0.187–0.360 seconds after the request. The input probe attempts new actions during draining and verifies unchanged game tick/no new voice. `--quit-after` bypasses normal window-close notification and remains an engine-forced teardown limitation; this change does not claim to repair that path.

Red/green records for mute, pause, cue emission, overlap, retry/outcome music, menu continuity and gain are in [checks](issue-10-capture/checks/). The first implementation incorrectly advanced music on retry; the full-source transition trace corrected that assumption before handoff. Its early music logs are marked superseded; `retry-red/green` verifies the corrected boundary, and the final application check also advances to a new stage. Public headless audio and native rendered audio checks are registered in `tools/run_checks.py`. Windows and pinned Linux checks exercise real stream playback; interruption coverage includes actual preference save/reload. Final synchronization/check results are recorded below. No new or changed shared screenshot captures are expected.

- [x] Cue triggers, order, overlap, music selection and transitions audited.
- [x] Missing/incorrect cues, mute, ordinary pause and saved preferences verified.
- [x] Presentation random selection is isolated from accepted gameplay state/RNG.
- [x] Source controls and bounded limitations retained; production diff reviewed against the starting integration.

Final synchronization is `f8d5a07`, containing integration `423b60e` (#32 accounting and #20 configuration). The public runner passes audio, simulation, bomb expiry/push motion, special/command order/grenade endpoint/accounting, campaign/accounting-session and tooling checks. Windows audio/interruption checks pass; pinned Linux image `0b22bba7bb7e` passes headless audio plus rendered audio/interruption, including the corrected same-track retry and next-stage transition. [Final run metadata](issue-10-capture/final.json) and logs are retained. Review confirms no asset/import metadata or shared baseline edits.
