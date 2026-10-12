# Pre-iPhone integration review

Baseline: `f79737253316dc3d805dd56af1d2eea95a66033d`.
Full review: `1b483b14f8349facb82d9fcbc87593cd8cc629f9` using the three-dot diff and its commit list.
Fix review: `f1be5971413b8811505c45582105dd4450d98f77`, merged as `20178f6`.
Earlier accepted changes carried by the PR retain their previous reviews and were excluded from this pass.

Standards and Spec were reviewed independently in parallel. All findings were assigned to one implementer, then rechecked by their respective reviewers. [Fix evidence](final-review-fixes.md) retains public red/green results, 52 tooling checks and unchanged original-comparison reports.

## Standards

No documented standards breach or new runtime defect was established. Root `AGENTS.md` supplies navigation and validation rules, with the Fowler smell baseline applied as judgement rather than mandatory style.

One nonblocking P3 judgement finding identified duplicated profile registration in `capture_core_reference.py`, `compare_traces.py` and `core_trace_schema.py`. Separate thirteen-profile catalogs and driver/nesting lists required coordinated edits and could drift.

Resolved: `reference_profiles.py` now supplies the shared descriptors to all three consumers. The reviewer confirmed unchanged routing, distinct capture-nesting versus strict polling-provenance policies, and malformed-profile diagnostics. Engine-guard changes introduced no additional Standards concern. No tests were repeated by this reviewer.

**Standards: zero open findings; one maintenance finding resolved.**

## Spec

One P2 reproducibility finding identified missing engine-version enforcement in both `capture_special_effects.py` and `capture_death_controls.py`. Parent #1 requires preserving “import-first execution, engine pinning, phase timeouts”. Both commands could previously capture using an unsupported engine. The retained evidence itself used 4.7.2 and was not invalidated.

Resolved: both commands now verify successful `--version` output against the shared engine pin before capture work. Public-command negative checks fail before the fix and pass afterward. The Spec reviewer independently reran the rejection test and confirmed closure; shared profile routing/provenance remains intact.

No further concrete missing requirement, unintended scope or production defect was found. The 35 Hz rules, numerical values, accepted seeded RNG and deterministic timer remain preserved. Original pixel/runtime uncertainties remain explicit, independently from exact port baselines. #20 remains partial configuration with external signing/install requirements; #22/#23 and parent #1 remain open.

**Spec: zero open findings; one P2 finding, affecting two capture commands, resolved.**

## Candidate coverage

The tested Windows candidate and sustained measurements remain valid because the fixes changed no game, asset, fixture, source adapter or performance instrumentation. [Desktop acceptance](issue-21.md) records the clean export revision, hashes, actual executable tests, 60/120-cap observations and preserved ZIP. This review does not turn documented original differences or unavailable iPhone evidence into passing claims.
