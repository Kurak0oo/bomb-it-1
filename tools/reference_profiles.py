"""Shared capture routing and validation policy for original gameplay profiles."""
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class ReferenceProfile:
    stem: str
    driver: str
    nested: bool
    argument: str | None = None
    require_polling_provenance: bool = False

    @property
    def config(self):
        return Path(__file__).resolve().parents[1] / f"godot/tests/fixtures/{self.stem}_scenarios.json"


# Capture nesting and strict polling provenance are deliberately separate:
# order retains its existing contract; ai_order records adapted polling bytes.
PROFILES = {profile.stem + "-v1": profile for profile in (
    ReferenceProfile("core", "core", False),
    ReferenceProfile("motion", "motion", False),
    ReferenceProfile("interaction", "interaction", True, require_polling_provenance=True),
    ReferenceProfile("order", "order", True),
    ReferenceProfile("expiry", "expiry", True, require_polling_provenance=True),
    ReferenceProfile("ai_order", "ai_order", True),
    ReferenceProfile("push", "motion", True, "--push-profile", True),
    ReferenceProfile("grenade", "motion", True, "--grenade-profile", True),
    ReferenceProfile("grenadescore", "interaction", True, "--grenade-account", True),
    ReferenceProfile("accounting", "interaction", True, "--accounting-profile", True),
    ReferenceProfile("contact", "interaction", True, "--contact-profile", True),
    ReferenceProfile("icewalk", "interaction", True, "--icewalk-profile", True),
    ReferenceProfile("dispatch", "interaction", True, "--dispatch-profile", True),
)}
