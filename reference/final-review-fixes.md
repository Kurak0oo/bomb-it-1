# Final review fixes

Starting revision: `1b483b14f8349facb82d9fcbc87593cd8cc629f9`. These changes resolve the Spec P2 engine-pin finding (including its death-control follow-up) and the Standards P3 profile-registration maintenance finding. No production game, asset, fixture, source adapter, package or performance instrumentation changed.

`capture_special_effects.py` and `capture_death_controls.py` now check the resolved engine's successful `--version` response against the shared 4.7.2 pin before fixture construction, browser capture, import or rendering. Verification has the existing phase timeout and rejects execution errors. Public-command tests pass Python as an unsupported engine, require the pin diagnostic and verify that no capture-phase artifacts were produced. Both missing guards were observed red before their fixes, then green.

`reference_profiles.py` now owns all 13 gameplay profile names, configuration paths, capture drivers, nesting defaults and optional port flags. Capture routing, comparator acceptance and schema validation consume it. Strict original polling provenance remains a separate descriptor field: the existing `order` and adapted `ai_order` policies were preserved. No command order or profile semantics changed. List/dict profile values retain the normal incompatible-profile diagnostic and exit 2; a public negative test was red after the initial refactor and green after explicit string validation.

[Retained checks and captures](final-review-fixes-evidence/) establish:

- All **52 tooling tests** pass, including collector startup rejection, malformed/truncated captures and exact field/tick perturbations.
- All **13 public retained-profile comparisons** produce reports identical to the integrated candidate's reports: ten exact, with core 6 / interaction 14 / dispatch 28 diagnostic differences unchanged.
- The real pinned-engine special-effect command completes all phases: **447 visibility observations match**, and **121/141 images differ at zero tolerance**, as previously documented. One initial source startup batch was rejected and a fresh retry accepted; both logs remain.
- A fresh `dispatch-v1` command verifies shared driver/flag/nesting routing and retains the same **28 residual-energy differences**.

The first positive special-effect invocation completed capture phases but its APPDATA isolation hid user-installed Pillow from the comparison subprocess. The final command used the normal installed Python dependency environment and completed. This was an invocation-environment failure; no comparator tolerance or game behavior changed. The large death-component controls were not recaptured because their retained evidence already used 4.7.2.

```powershell
python -m unittest discover -s tools/tests -v
python tools/capture_special_effects.py --godot <Godot-4.7.2> --ffdec <FFDec> --output .artifacts/final-review/special-effects-final
python tools/capture_core_reference.py --godot <Godot-4.7.2> --ffdec <FFDec> --profile dispatch-v1 --output .artifacts/final-review/dispatch
```

Native capture commands used the session's exclusive wrapper. The previously tested ZIP and sustained measurements remain valid for the unchanged production fingerprint; no repackage or performance rerun was needed. Final reviewer confirmation remains root-owned.
