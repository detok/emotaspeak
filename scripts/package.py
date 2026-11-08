#!/usr/bin/env python3
"""Build a clean, deterministic World of Warcraft: Forever addon archive."""
from __future__ import annotations

import re
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parent.parent
MANIFESTS = ("EmotaSpeak.toc", "EmotaSpeak_Camelot.toc")
ADDON_FILES = (
    "EmotaSpeak.toc",
    "EmotaSpeak_Camelot.toc",
    "EmotaSpeak.lua",
    "EmotaSpeak_Settings.lua",
    "assets/Icon.tga",
)


def version_for(path: Path) -> str:
    match = re.search(r"^## Version:\s*(\S+)\s*$", path.read_text(encoding="utf-8"), re.M)
    if not match:
        raise ValueError(f"Missing version in {path}")
    return match.group(1)


def build() -> Path:
    versions = {version_for(ROOT / name) for name in MANIFESTS}
    if len(versions) != 1:
        raise ValueError("The Forever and generic manifests must have identical versions")
    version = versions.pop()

    for name in ADDON_FILES:
        if not (ROOT / name).is_file():
            raise FileNotFoundError(f"Missing required release file: {name}")

    archive_dir = ROOT / "publish"
    archive_dir.mkdir(exist_ok=True)
    destination = archive_dir / f"EmotaSpeak-{version}.zip"
    with ZipFile(destination, "w", ZIP_DEFLATED) as package:
        for name in ADDON_FILES:
            content = (ROOT / name).read_bytes()
            entry = ZipInfo(f"EmotaSpeak/{name}", date_time=(2026, 1, 1, 0, 0, 0))
            entry.compress_type = ZIP_DEFLATED
            entry.external_attr = 0o644 << 16
            package.writestr(entry, content)
    print(f"Built {destination.name} ({destination.stat().st_size:,} bytes)")
    return destination


if __name__ == "__main__":
    build()
