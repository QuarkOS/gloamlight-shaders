#!/usr/bin/env python3
"""Generate the thin per-dimension program entry points (shaders/*.vsh|fsh).

Every entry point only sets the stage, dimension and variant macros and includes the
shared implementation from shaders/program/. Re-run after editing PROGRAMS.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "shaders"

# program name -> (implementation file, extra defines)
PROGRAMS = {
    "gbuffers_basic": ("gbuffers_forward", ["G_BASIC"]),
    "gbuffers_textured": ("gbuffers_forward", ["G_TEXTURED"]),
    "gbuffers_textured_lit": ("gbuffers_forward", ["G_TEXTURED"]),
    "gbuffers_hand": ("gbuffers_forward", ["G_HAND"]),
    "gbuffers_hand_water": ("gbuffers_forward", ["G_HAND"]),
    "gbuffers_weather": ("gbuffers_forward", ["G_WEATHER"]),
    "gbuffers_clouds": ("gbuffers_forward", ["G_CLOUDS"]),
    "gbuffers_beaconbeam": ("gbuffers_forward", ["G_EMISSIVE"]),
    "gbuffers_spidereyes": ("gbuffers_forward", ["G_EMISSIVE"]),
    "gbuffers_lightning": ("gbuffers_forward", ["G_EMISSIVE"]),
    "gbuffers_terrain": ("gbuffers_solid", ["G_TERRAIN"]),
    "gbuffers_block": ("gbuffers_solid", ["G_BLOCK"]),
    "gbuffers_entities": ("gbuffers_solid", ["G_ENTITIES"]),
    "gbuffers_water": ("gbuffers_water", []),
    "gbuffers_skybasic": ("gbuffers_sky", ["G_SKYBASIC"]),
    "gbuffers_skytextured": ("gbuffers_sky", ["G_SKYTEXTURED"]),
    "gbuffers_armor_glint": ("gbuffers_overlay", []),
    "gbuffers_damagedblock": ("gbuffers_overlay", []),
    "shadow": ("shadow", []),
    "deferred": ("deferred", []),
    "composite": ("composite", []),
    "composite1": ("composite1", []),
    "composite2": ("bloom_blur", ["BLUR_H"]),
    "composite3": ("bloom_blur", ["BLUR_V"]),
    "final": ("final", []),
}

DIMENSIONS = {
    "": "DIM_OVERWORLD",
    "world-1": "DIM_NETHER",
    "world1": "DIM_END",
}

STAGES = {"vsh": "VSH", "fsh": "FSH"}


def render(stage_macro: str, dim_macro: str, impl: str, defines: list[str]) -> str:
    lines = ["#version 330 compatibility", "", f"#define {stage_macro}", f"#define {dim_macro}"]
    lines += [f"#define {d}" for d in defines]
    lines += ["", f'#include "/program/{impl}.glsl"', ""]
    return "\n".join(lines)


def main() -> None:
    count = 0
    for folder, dim_macro in DIMENSIONS.items():
        out_dir = ROOT / folder if folder else ROOT
        out_dir.mkdir(parents=True, exist_ok=True)
        for name, (impl, defines) in PROGRAMS.items():
            for ext, stage_macro in STAGES.items():
                (out_dir / f"{name}.{ext}").write_text(render(stage_macro, dim_macro, impl, defines))
                count += 1
    print(f"wrote {count} entry points")


if __name__ == "__main__":
    main()
