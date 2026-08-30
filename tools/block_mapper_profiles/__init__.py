"""Profile loader for the Gen1→Gen2 block mapper GUI."""

from __future__ import annotations

import importlib
import importlib.util
import os
import sys
from types import ModuleType
from typing import Any

_PROFILE_PACKAGE = "block_mapper_profiles"

KNOWN_PROFILES = (
    "safari_kanto",
    "forest_kanto",
    "cavern_cave",
    "legend_mythical_overworld",
)


def profiles_dir() -> str:
    return os.path.dirname(os.path.abspath(__file__))


def list_profiles() -> list[str]:
    found = []
    for name in KNOWN_PROFILES:
        path = os.path.join(profiles_dir(), f"{name}.py")
        if os.path.isfile(path):
            found.append(name)
    for fname in sorted(os.listdir(profiles_dir())):
        if not fname.endswith(".py") or fname.startswith("_") or fname == "common.py":
            continue
        stem = fname[:-3]
        if stem not in found:
            found.append(stem)
    return found


def _ensure_package_on_path() -> None:
    tools_dir = os.path.dirname(profiles_dir())
    if tools_dir not in sys.path:
        sys.path.insert(0, tools_dir)
    # Ensure parent package is registered so relative imports work
    if _PROFILE_PACKAGE not in sys.modules:
        pkg = ModuleType(_PROFILE_PACKAGE)
        pkg.__path__ = [profiles_dir()]  # type: ignore[attr-defined]
        pkg.__file__ = os.path.join(profiles_dir(), "__init__.py")
        sys.modules[_PROFILE_PACKAGE] = pkg


def load_profile(profile_id: str) -> dict[str, Any]:
    """Import tools/block_mapper_profiles/<id>.py and return its PROFILE dict."""
    if not profile_id:
        raise ValueError("profile_id is required")

    stem = os.path.basename(profile_id).removesuffix(".py")
    _ensure_package_on_path()

    mod_name = f"{_PROFILE_PACKAGE}.{stem}"
    try:
        if mod_name in sys.modules:
            mod = importlib.reload(sys.modules[mod_name])
        else:
            mod = importlib.import_module(mod_name)
    except Exception:
        path = os.path.join(profiles_dir(), f"{stem}.py")
        if not os.path.isfile(path):
            raise FileNotFoundError(
                f"Unknown profile '{profile_id}'. Known: {', '.join(list_profiles())}"
            ) from None
        # Load as package submodule so relative imports resolve
        if "common" not in sys.modules.get(_PROFILE_PACKAGE, ModuleType("x")).__dict__:
            common_path = os.path.join(profiles_dir(), "common.py")
            common_name = f"{_PROFILE_PACKAGE}.common"
            cspec = importlib.util.spec_from_file_location(
                common_name, common_path, submodule_search_locations=[profiles_dir()]
            )
            if cspec and cspec.loader:
                cmod = importlib.util.module_from_spec(cspec)
                sys.modules[common_name] = cmod
                cspec.loader.exec_module(cmod)

        spec = importlib.util.spec_from_file_location(
            mod_name, path, submodule_search_locations=[profiles_dir()]
        )
        if not spec or not spec.loader:
            raise ImportError(f"Cannot load profile file: {path}")
        mod = importlib.util.module_from_spec(spec)
        sys.modules[mod_name] = mod
        spec.loader.exec_module(mod)

    if not hasattr(mod, "PROFILE"):
        raise AttributeError(f"Profile module '{stem}' has no PROFILE dict")

    profile = dict(mod.PROFILE)
    profile.setdefault("id", stem)
    synth = profile.get("synthesize")
    if isinstance(synth, str) and hasattr(mod, synth):
        profile["synthesize"] = getattr(mod, synth)
    elif synth is None and hasattr(mod, "synthesize"):
        profile["synthesize"] = mod.synthesize

    return profile
