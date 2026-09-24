#!/usr/bin/env python3
"""Preprocess every program the way Iris would (resolve #include, inject loader macros,
apply option overrides) and compile it with glslangValidator.

Usage:
    python3 tools/validate.py              # default options + every profile + toggle sweeps
    python3 tools/validate.py --quick      # default options only
    python3 tools/validate.py --dump DIR   # also write the flattened sources to DIR
"""
import argparse
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "shaders"
SETTINGS = ROOT / "lib" / "settings.glsl"
PROPERTIES = ROOT / "shaders.properties"

IRIS_MACROS = """#define MC_VERSION 12111
#define MC_GL_VERSION 460
#define MC_GLSL_VERSION 460
#define IRIS_VERSION 10800
#define IS_IRIS
#define MC_OS_LINUX
#define MC_GL_VENDOR_OTHER
#define MC_GL_RENDERER_OTHER
#define MC_RENDER_QUALITY 1.0
#define MC_SHADOW_QUALITY 1.0
#define MC_HAND_DEPTH 0.125
#define MC_RENDER_STAGE_NONE 0
#define MC_RENDER_STAGE_SKY 1
#define MC_RENDER_STAGE_SUNSET 2
#define MC_RENDER_STAGE_CUSTOM_SKY 3
#define MC_RENDER_STAGE_SUN 4
#define MC_RENDER_STAGE_MOON 5
#define MC_RENDER_STAGE_STARS 6
#define MC_RENDER_STAGE_VOID 7
"""

INCLUDE_RE = re.compile(r'^\s*#include\s+"([^"]+)"\s*$')
DEFINE_RE = re.compile(r"^(\s*)(//)?\s*#define\s+(\w+)(\s+[^/\s][^/]*?)?\s*(//.*)?$")
CONST_RE = re.compile(r"^(\s*const\s+\w+\s+(\w+)\s*=\s*)([^;]+)(;.*)$")


def apply_overrides(text: str, overrides: dict) -> str:
    out = []
    for line in text.splitlines():
        m = DEFINE_RE.match(line)
        c = CONST_RE.match(line)
        if m and m.group(3) in overrides:
            name, val = m.group(3), overrides[m.group(3)]
            if val is True:
                line = f"#define {name}"
            elif val is False:
                line = f"//#define {name}"
            else:
                line = f"#define {name} {val}"
        elif c and c.group(2) in overrides and not isinstance(overrides[c.group(2)], bool):
            line = f"{c.group(1)}{overrides[c.group(2)]}{c.group(4)}"
        out.append(line)
    return "\n".join(out)


def flatten(path: Path, overrides: dict, stack=()) -> str:
    if path in stack:
        raise RuntimeError(f"include cycle: {path}")
    text = path.read_text()
    if path == SETTINGS:
        text = apply_overrides(text, overrides)
    out = []
    for line in text.splitlines():
        m = INCLUDE_RE.match(line)
        if m:
            inc = m.group(1)
            target = ROOT / inc.lstrip("/") if inc.startswith("/") else path.parent / inc
            if not target.exists():
                raise RuntimeError(f"{path}: missing include {inc}")
            out.append(flatten(target, overrides, stack + (path,)))
        else:
            out.append(line)
    return "\n".join(out)


def preprocess(entry: Path, overrides: dict) -> str:
    src = flatten(entry, overrides)
    first, rest = src.split("\n", 1)
    assert first.startswith("#version"), entry
    return f"{first}\n{IRIS_MACROS}{rest}\n"


def parse_options():
    toggles, values = [], {}
    for line in SETTINGS.read_text().splitlines():
        m = DEFINE_RE.match(line)
        if not m:
            continue
        name, val, comment = m.group(3), m.group(4), m.group(5) or ""
        if val is None:
            toggles.append(name)
        elif "[" in comment:
            values[name] = comment[comment.index("[") + 1 : comment.index("]")].split()
    return toggles, values


def parse_profiles():
    profiles = {}
    for line in PROPERTIES.read_text().splitlines():
        m = re.match(r"^profile\.(\w+)\s*=\s*(.*)$", line.strip())
        if not m:
            continue
        ov = {}
        for tok in m.group(2).split():
            if tok.startswith("profile."):
                ov.update(profiles.get(tok.split(".", 1)[1], {}))
            elif tok.startswith("!"):
                ov[tok[1:]] = False
            elif "=" in tok:
                k, v = tok.split("=", 1)
                ov[k] = v
            else:
                ov[tok] = True
        profiles[m.group(1)] = ov
    return profiles


def entry_points():
    for p in sorted(ROOT.glob("*.[vf]sh")) + sorted(ROOT.glob("world*/*.[vf]sh")):
        yield p


def compile_all(label: str, overrides: dict, tmp: Path, dump: Path | None) -> int:
    failures = 0
    for entry in entry_points():
        src = preprocess(entry, overrides)
        stage = "vert" if entry.suffix == ".vsh" else "frag"
        rel = entry.relative_to(ROOT)
        out = tmp / f"{str(rel).replace('/', '__')}.{stage}"
        out.write_text(src)
        if dump:
            d = dump / label / rel
            d.parent.mkdir(parents=True, exist_ok=True)
            d.write_text(src)
        r = subprocess.run(["glslangValidator", str(out)], capture_output=True, text=True)
        if r.returncode != 0:
            failures += 1
            print(f"[{label}] FAIL {rel}")
            print("\n".join("    " + l for l in r.stdout.strip().splitlines()))
    status = "ok" if failures == 0 else f"{failures} failed"
    print(f"[{label}] {len(list(entry_points()))} stages: {status}")
    return failures


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--dump", type=Path)
    args = ap.parse_args()

    toggles, values = parse_options()
    variants = [("default", {})]
    if not args.quick:
        for name, ov in parse_profiles().items():
            variants.append((f"profile-{name}", ov))
        variants.append(("all-off", {t: False for t in toggles}))
        variants.append(("all-on", {t: True for t in toggles}))
        for name, opts in values.items():
            if name in ("CLOUD_QUALITY", "TONEMAP"):
                for v in opts:
                    variants.append((f"{name}={v}", {name: v}))

    failures = 0
    with tempfile.TemporaryDirectory() as t:
        for label, ov in variants:
            failures += compile_all(label, ov, Path(t), args.dump)
    print("ALL OK" if failures == 0 else f"{failures} failures")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
