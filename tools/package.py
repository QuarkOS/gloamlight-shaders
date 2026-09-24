#!/usr/bin/env python3
"""Build Gloamlight.zip (shaders/ at the archive root) ready for .minecraft/shaderpacks."""
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


def main() -> None:
    out = REPO / "Gloamlight.zip"
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for f in sorted((REPO / "shaders").rglob("*")):
            if f.is_file():
                z.write(f, f.relative_to(REPO))
        for extra in ("README.md", "LICENSE"):
            if (REPO / extra).exists():
                z.write(REPO / extra, extra)
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
