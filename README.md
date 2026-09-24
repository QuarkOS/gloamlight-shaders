# Gloamlight

An atmospheric shader pack for **Minecraft Java 1.21.11** on **Iris**, written from scratch. It uses the OptiFine-compatible `shaders/` format, so it may also load on OptiFine, but it is built and tuned against Iris.

Gloamlight aims for mood over spectacle: warm light at the ends of the day, cool blue nights, mist that collects in valleys, and torchlit caves that feel warm next to the cold ambient light.

## Features

**Sky and atmosphere**
- Rayleigh, Mie and ozone single scattering is ray-marched for every sky pixel. Sunrise and sunset tones, blue twilight and the dark band after sunset come out of the scattering model itself rather than from painted gradients.
- Sunlight color and sky ambient are derived from the same atmosphere model, so the light on the ground always matches the sky above it.
- The sun disc has limb darkening. The vanilla moon (including its phases) and the stars are kept and blended into the sky.
- Ray-marched volumetric cumulus clouds have a flat base and a billowing top, with self-shadowing, forward scattering (silver linings), a powder effect and wind drift. Rain makes the sky more overcast.

**Lighting**
- Deferred lighting uses a warm blackbody-style torch color against cool sky ambient, with a configurable minimum light level for caves and a light radius around you when you hold a light source.
- Shadows use a distorted shadow map with Vogel-disk PCF. Contact-hardening (PCSS) keeps shadows sharp at the base of an object and softens them further away, and stained glass tints the light that passes through it.
- Foliage has subsurface translucency: leaves and grass glow when you look toward the sun.
- Screen-space AO stacks on top of vanilla AO.
- Torches, lanterns, glowstone, froglights, lava, fire and other light sources glow, driven by block IDs in `block.properties`.
- In rain, surfaces exposed to the sky darken and turn glossy, and mirror-like puddles form on flat ground.

**Fog and volumetrics**
- Height fog is ray-marched through the shadow map, so light shafts appear through trees and cave openings and around the sun.
- Mist collects in valleys around sunrise, and fog thickens in rain.
- Terrain fades into the sky at the edge of render distance (border fog). Blindness and Darkness have their own fog.
- Underwater, lava and powder snow each have their own fog.

**Water**
- Waves are procedural, combining sharp directional swells with ripples, plus a small vertex displacement.
- Water refracts what is beneath it, with a depth check so objects in front of the water never smear into the refraction.
- Light is absorbed and scattered according to how much water it travels through, so shallow water is clear and deep water turns blue-green.
- Reflections use Schlick fresnel, screen-space reflections of the terrain with a fallback to the sky, and a sun or moon highlight that respects shadows.

**Waving geometry**: grass, flowers, crops, both halves of double-tall plants, leaves and vines sway in gusty wind that strengthens during storms. Shadows wave with them.

**Post-processing**
- Physically-based bloom built from a 6-level mip pyramid.
- Temporal auto exposure with partial adaptation, so nights and caves stay dark instead of being pushed to gray.
- Choice of tonemapper: ACES fitted (RRT+ODT), approximate ACES, or soft Reinhard.
- Color grading: white balance in Kelvin, saturation, vibrance, contrast and split toning. Plus a subtle vignette and dithering to prevent banding.

**Dimensions**
- **Nether** (`world-1`): no sky light or shadow pass. Thick, smoky haze tinted by the biome fog color, which gets heavier near lava-sea height. Warm grading and stronger bloom.
- **End** (`world1`): a procedural void sky with a drifting nebula band and twinkling stars. A fixed violet light casts shadows and volumetric shafts through purple fog.

## Install

1. Install [Iris](https://irisshaders.dev) for Minecraft 1.21.11 (with Fabric, or bundled with Sodium).
2. Build the zip:
   ```bash
   python3 tools/package.py   # writes Gloamlight.zip containing shaders/ + README.md
   ```
   Alternatively, zip the `shaders/` folder yourself so that `shaders/` sits at the root of the archive.
3. Drop `Gloamlight.zip` into `.minecraft/shaderpacks/`. The unzipped repository folder also works if you put it in `shaderpacks/`.
4. In game, go to **Options → Video Settings → Shader Packs** and select **Gloamlight**.

## Options

Open **Shader Pack Settings** in the shader pack screen. The **Quality Profile** selector at the top switches all performance-relevant options at once:

| Profile | Shadows | Filtering | Volumetrics | Clouds | Reflections | Other |
| --- | --- | --- | --- | --- | --- | --- |
| Low | 1024 px, 96 blocks | 4 samples | analytic fog only | 8 steps | sky only | no SSAO, static leaves |
| Medium (default) | 2048 px, 128 blocks | 12 samples + PCSS | 12 steps | 14 steps | SSR, 20 steps | SSAO ×8 |
| High | 4096 px, 192 blocks | 24 samples + PCSS | 24 steps | 24 steps + detail | SSR, 32 steps | SSAO ×12 |

The option screens are:

- **Lighting**: sun, moon, ambient, torch brightness and warmth, emissive glow, handheld light, foliage translucency, vanilla AO and SSAO, rain wetness, puddles.
- **Shadows**: resolution, distance, filter samples, softness, PCSS, colored shadows, distortion, sun path angle.
- **Sky & Clouds**: sky quality, sun size, stars, cloud quality, coverage, altitude, thickness and speed, and optional vanilla clouds.
- **Fog & Volumetrics**: volumetric light on/off, quality and strength, overall fog density, morning mist, rain fog, border fog, Nether haze, End fog.
- **Water**: waves (height, speed), refraction, screen-space reflections (on/off, quality), clarity, underwater fog.
- **Waving Foliage**: plants, leaves, strength, speed.
- **Camera & Color**: bloom (on/off, strength), auto exposure, exposure bias, tonemapper, white balance, saturation, vibrance, contrast, split toning, vignette.

## Layout

```
shaders/
  shaders.properties      profiles, option screens, blend modes, pass toggles
  block.properties        block ids for waving plants, leaves, light sources, water, glass
  lang/en_US.lang         option names and tooltips
  *.vsh / *.fsh           overworld entry points (generated)
  world-1/, world1/       Nether / End entry points (generated)
  program/                stage implementations shared by all dimensions
  lib/                    settings, atmosphere, clouds, shadows, lighting, fog, waves, tonemapping
tools/
  gen_programs.py         regenerates the entry points
  validate.py             Iris-style preprocessing + glslangValidator for every stage and option set
  mesa_check.py           compiles and links every program with a real GL driver
  render_preview.py       offline approximation of the pipeline on a toy block scene
  package.py              builds Gloamlight.zip
```

Every entry point is a few lines long. It sets the stage (`VSH`/`FSH`), the dimension (`DIM_OVERWORLD`/`DIM_NETHER`/`DIM_END`) and a variant macro, then includes the shared implementation from `program/`. Edit `tools/gen_programs.py` to add programs, then run it.

### Render pipeline

| Pass | Work |
| --- | --- |
| `shadow` | Distorted shadow map (waving geometry included); translucent tint written to `shadowcolor0` |
| `gbuffers_terrain/block/entities` | Albedo → `colortex0`, normal + lightmap → `colortex1`, material → `colortex2` |
| `gbuffers_water` | Water normal and mask → `colortex3`; glass and other translucents forward-shaded → `colortex4` |
| `gbuffers_hand/textured/weather/...` | Forward-shaded into the translucent layer `colortex4` |
| `deferred` | Sky, sun, stars and clouds; full lighting of opaque surfaces (shadows, SSAO, wetness) |
| `composite` | Water refraction, absorption and reflections; translucent blend; volumetric and dimension fog |
| `composite1–3` | Bloom pyramid and gaussian blur; auto exposure (stored in `colortex7`, which persists between frames) |
| `final` | Bloom merge, exposure, tonemap, grading, vignette, dither |

## Development

```bash
sudo apt-get install glslang-tools          # glslangValidator
python3 tools/validate.py                   # every stage × default, Low/Medium/High, all toggles on/off, cloud/tonemap variants
pip install glfw PyOpenGL numpy pillow      # optional, for the driver check and previews
python3 tools/mesa_check.py                 # compile + link with the local GL driver (needs a display, e.g. Xvfb)
python3 tools/render_preview.py --out out/previews
```

`render_preview.py` is not Minecraft. It draws cubes with flat colors through the pack's own programs and uses matrices and uniforms that approximate Iris's. It is good for catching broken passes and judging the overall tone, but it is not a substitute for testing in game.

## Known limitations

- The pack is validated by glslang, by a Mesa compile and link, and by the offline preview only. It has **not yet been tested inside Minecraft with Iris**, and some Iris-specific behavior (hand and particle ordering, the `program.world-1/shadow.enabled` directive) is implemented according to Iris's documented semantics but not verified in game.
- There is no temporal anti-aliasing. Volumetric fog and clouds use static per-pixel dithering, which can show fine noise on low step counts.
- Water uses a fixed blue-green absorption color instead of the biome's water tint. Reflections do not include clouds.
- There is no LabPBR or normal-map support; surfaces use vertex normals.
- Clouds do not cast shadows on terrain.
