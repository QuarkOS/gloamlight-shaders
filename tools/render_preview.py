#!/usr/bin/env python3
"""Offline approximation of the Iris pipeline for eyeballing the pack without Minecraft.

Draws a small procedural block scene (grass, lake, trees, pillars, a lamp) through the
pack's own shadow, gbuffers, deferred, water, composite and final programs on whatever
GL driver is available (Mesa llvmpipe works) and writes PNGs.

    python3 tools/render_preview.py --out out/previews
"""
import argparse
import math
import sys
from pathlib import Path

import glfw
import numpy as np
from OpenGL.GL import *  # noqa: F403
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import mesa_check  # noqa: E402
import validate  # noqa: E402

W, H = 960, 540
SHADOW_RES = 2048
FAR = 192.0
NEAR = 0.05
CAMERA = np.array([0.5, 68.62, 0.5])


# ---------------------------------------------------------------------------- math
def perspective(fovy, aspect, n, f):
    t = 1.0 / math.tan(math.radians(fovy) / 2)
    m = np.zeros((4, 4))
    m[0, 0] = t / aspect
    m[1, 1] = t
    m[2, 2] = (f + n) / (n - f)
    m[2, 3] = 2 * f * n / (n - f)
    m[3, 2] = -1
    return m


def ortho(l, r, b, t, n, f):
    m = np.identity(4)
    m[0, 0] = 2 / (r - l)
    m[1, 1] = 2 / (t - b)
    m[2, 2] = -2 / (f - n)
    m[0, 3] = -(r + l) / (r - l)
    m[1, 3] = -(t + b) / (t - b)
    m[2, 3] = -(f + n) / (f - n)
    return m


def look_at(eye, target, up):
    f = target - eye
    f = f / np.linalg.norm(f)
    s = np.cross(f, up)
    s = s / np.linalg.norm(s)
    u = np.cross(s, f)
    m = np.identity(4)
    m[0, :3], m[1, :3], m[2, :3] = s, u, -f
    m[:3, 3] = -m[:3, :3] @ eye
    return m


def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def sun_direction(celestial, path_rotation_deg=-30.0):
    # Celestial angle 0 = noon, 0.25 = sunset (west, -X), 0.75 = sunrise (east, +X).
    a = celestial * 2 * math.pi
    d = rot_x(math.radians(path_rotation_deg)) @ np.array([-math.sin(a), math.cos(a), 0.0])
    return d / np.linalg.norm(d)


# ---------------------------------------------------------------------------- scene
class Scene:
    def __init__(self, nether=False, end=False):
        self.quads = []  # (verts[4], normal, color, id, lm)
        rng = np.random.default_rng(7)
        R = 40
        ground = (0.36, 0.5, 0.22) if not (nether or end) else ((0.45, 0.16, 0.14) if nether else (0.86, 0.85, 0.62))
        lake = lambda x, z: (x - 12) ** 2 / 90 + (z + 8) ** 2 / 50 < 1.0 and not (nether or end)
        for x in range(-R, R):
            for z in range(-R, R):
                h = 64
                if lake(x, z):
                    self.cube(x, 60, z, (0.45, 0.42, 0.35), top_only=True)
                    self.quad_top(x, 63.9, z, (0.2, 0.35, 0.8), 10005, water=True)
                    continue
                near_lake = any(lake(x + dx, z + dz) for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if near_lake:
                    for y in range(60, h):
                        self.cube(x, y, z, (0.45, 0.42, 0.35))
                self.cube(x, h, z, ground, top_only=not near_lake)
                if not (nether or end) and rng.random() < 0.12:
                    self.cross(x, h + 1, z, (0.3, 0.55, 0.2), 10001)
        # trees
        for tx, tz in [(-6, 9), (4, 14), (-14, -4), (20, 6), (-3, -16)]:
            if nether or end:
                break
            for y in range(65, 70):
                self.cube(tx, y, tz, (0.38, 0.27, 0.16))
            for dx in range(-2, 3):
                for dz in range(-2, 3):
                    for dy in range(0, 3):
                        if abs(dx) + abs(dz) + dy < 5 and not (dx == 0 and dz == 0 and dy < 1):
                            self.cube(tx + dx, 69 + dy, tz + dz, (0.22, 0.42, 0.15), bid=10002)
        # stone pillars / obsidian towers
        pillar = (0.5, 0.5, 0.52) if not end else (0.09, 0.05, 0.14)
        for px, pz, ph in [(10, -2, 5), (-10, 6, 3), (6, 4, 2), (26, -12, 12)]:
            for y in range(65, 65 + ph):
                self.cube(px, y, pz, pillar)
        # a lamp near the camera
        self.cube(3, 65, 2, (1.0, 0.8, 0.45), bid=10004, lm=(240, 240))

    def cube(self, x, y, z, col, bid=0, top_only=False, lm=None):
        faces = [
            ((0, 1, 0), [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)]),
            ((0, -1, 0), [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)]),
            ((1, 0, 0), [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)]),
            ((-1, 0, 0), [(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)]),
            ((0, 0, 1), [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)]),
            ((0, 0, -1), [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)]),
        ]
        for n, vs in faces[:1] if top_only else faces:
            shade = {1: 1.0, -1: 0.5}.get(n[1], 0.8 if n[0] else 0.65)
            c = tuple(ch * shade for ch in col)
            self.quads.append(([(x + a, y + b, z + cc) for a, b, cc in vs], n, c, bid, lm or (0, 240)))

    def quad_top(self, x, y, z, col, bid, water=False):
        vs = [(x, y, z), (x, y, z + 1), (x + 1, y, z + 1), (x + 1, y, z)]
        self.quads.append((vs, (0, 1, 0), col + ((0.7,) if water else (1.0,)), bid, (0, 240)))

    def cross(self, x, y, z, col, bid):
        for a, b in [((0.1, 0.1), (0.9, 0.9)), ((0.1, 0.9), (0.9, 0.1))]:
            p0 = (x + a[0], y, z + a[1])
            p1 = (x + b[0], y, z + b[1])
            vs = [p0, p1, (p1[0], y + 0.8, p1[2]), (p0[0], y + 0.8, p0[2])]
            self.quads.append((vs, (0, 1, 0), col, bid, (0, 240)))

    def draw(self, prog, water_pass):
        a_ent = glGetAttribLocation(prog, "mc_Entity")
        a_mid = glGetAttribLocation(prog, "mc_midTexCoord")
        glBegin(GL_QUADS)
        for vs, n, c, bid, lm in self.quads:
            is_water = bid == 10005
            if water_pass is not None and is_water != water_pass:
                continue
            glColor4f(*(c if len(c) == 4 else c + (1.0,)))
            glNormal3f(*n)
            for i, v in enumerate(vs):
                uv = [(0, 1), (1, 1), (1, 0), (0, 0)][i]
                if a_ent >= 0:
                    glVertexAttrib4f(a_ent, bid, 0, 0, 0)
                if a_mid >= 0:
                    glVertexAttrib2f(a_mid, 0.5, 0.5)
                glMultiTexCoord2f(GL_TEXTURE0, *uv)
                glMultiTexCoord2f(GL_TEXTURE1, *lm)
                glVertex3f(v[0] - CAMERA[0], v[1] - CAMERA[1], v[2] - CAMERA[2])
        glEnd()


# ---------------------------------------------------------------------------- GL helpers
def tex2d(w, h, internal, fmt=GL_RGBA, typ=GL_FLOAT, mips=False):
    t = glGenTextures(1)
    glBindTexture(GL_TEXTURE_2D, t)
    glTexImage2D(GL_TEXTURE_2D, 0, internal, w, h, 0, fmt, typ, None)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR if mips else GL_LINEAR)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
    if mips:
        glGenerateMipmap(GL_TEXTURE_2D)
    return t


def fbo(colors, depth=None):
    f = glGenFramebuffers(1)
    glBindFramebuffer(GL_FRAMEBUFFER, f)
    for i, c in enumerate(colors):
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0 + i, GL_TEXTURE_2D, c, 0)
    if depth:
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, depth, 0)
    glDrawBuffers(len(colors), [GL_COLOR_ATTACHMENT0 + i for i in range(len(colors))])
    assert glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE
    return f


class Pipeline:
    def __init__(self, folder):
        self.programs = {}
        self.folder = folder

    def prog(self, name):
        if name not in self.programs:
            d = validate.ROOT / self.folder
            vs = validate.preprocess(d / f"{name}.vsh", {})
            fs = validate.preprocess(d / f"{name}.fsh", {})
            p, log = mesa_check.build(vs, fs)
            if not p:
                raise SystemExit(f"{name}: {log}")
            self.programs[name] = p
        return self.programs[name]


def set_uniforms(p, u, samplers):
    glUseProgram(p)
    for name, val in u.items():
        loc = glGetUniformLocation(p, name)
        if loc < 0:
            continue
        if isinstance(val, np.ndarray) and val.shape == (4, 4):
            glUniformMatrix4fv(loc, 1, GL_TRUE, val.astype(np.float32))
        elif isinstance(val, (tuple, list, np.ndarray)):
            val = [float(x) for x in val]
            [glUniform2f, glUniform3f, glUniform4f][len(val) - 2](loc, *val)
        elif isinstance(val, int) and not isinstance(val, bool):
            glUniform1i(loc, val)
        else:
            glUniform1f(loc, float(val))
    loc = glGetUniformLocation(p, "eyeBrightnessSmooth")
    if loc >= 0:
        glUniform2i(loc, 0, 240)
    for unit, (name, tex, sampler) in enumerate(samplers):
        loc = glGetUniformLocation(p, name)
        if loc < 0:
            continue
        glActiveTexture(GL_TEXTURE0 + unit)
        glBindTexture(GL_TEXTURE_2D, tex)
        glBindSampler(unit, sampler or 0)
        glUniform1i(loc, unit)
    glActiveTexture(GL_TEXTURE0)


def fullscreen():
    glMatrixMode(GL_PROJECTION)
    glLoadMatrixf(ortho(0, 1, 0, 1, -1, 1).T.astype(np.float32))
    glMatrixMode(GL_MODELVIEW)
    glLoadIdentity()
    glBegin(GL_QUADS)
    for x, y in [(0, 0), (1, 0), (1, 1), (0, 1)]:
        glMultiTexCoord2f(GL_TEXTURE0, x, y)
        glVertex3f(x, y, 0)
    glEnd()


DEBUG = False


def dump(tex, path, scale=None):
    glBindTexture(GL_TEXTURE_2D, tex)
    a = np.frombuffer(glGetTexImage(GL_TEXTURE_2D, 0, GL_RGBA, GL_FLOAT), np.float32).reshape(H, W, 4)[::-1, :, :3]
    print(path.name, "nan", int(np.isnan(a).any(axis=2).sum()), "min", a.reshape(-1, 3).min(0), "mean", a.reshape(-1, 3).mean(0), "max", a.reshape(-1, 3).max(0))
    img = a * scale if scale else a / (1 + a)
    Image.fromarray((np.clip(img, 0, 1) ** (1 / 2.2) * 255).astype(np.uint8)).save(path)


def load_matrix(mode, m):
    glMatrixMode(mode)
    glLoadMatrixf(m.T.astype(np.float32))


def render(scene, folder, celestial, yaw, pitch, rain=0.0, eye_in_water=0, out=None, frame_time=12.0):
    pipe = Pipeline(folder)
    fwd = np.array([math.cos(yaw) * math.cos(math.radians(pitch)), math.sin(math.radians(pitch)),
                    math.sin(yaw) * math.cos(math.radians(pitch))])
    view = look_at(np.zeros(3), fwd, np.array([0, 1.0, 0]))
    proj = perspective(70, W / H, NEAR, FAR * 4)

    sun = sun_direction(celestial)
    light = sun if sun[1] > 0 else -sun
    if folder == "world1":
        sun = light = sun_direction(0.0)
    shadow_view = look_at(light * 100.0, np.zeros(3), np.array([0, 0, 1.0]) if abs(light[1]) > 0.99 else np.array([0, 1, 0.0]))
    shadow_proj = ortho(-128, 128, -128, 128, 0.05, 256)
    to_view = lambda d: (view[:3, :3] @ d) * 100.0

    u = {
        "gbufferModelView": view, "gbufferModelViewInverse": np.linalg.inv(view),
        "gbufferProjection": proj, "gbufferProjectionInverse": np.linalg.inv(proj),
        "shadowModelView": shadow_view, "shadowModelViewInverse": np.linalg.inv(shadow_view),
        "shadowProjection": shadow_proj,
        "cameraPosition": CAMERA, "sunPosition": to_view(sun), "moonPosition": to_view(-sun),
        "shadowLightPosition": to_view(light), "upPosition": to_view(np.array([0, 1.0, 0])),
        "fogColor": (0.33, 0.07, 0.05) if folder == "world-1" else (0.6, 0.7, 0.9),
        "skyColor": (0.5, 0.7, 1.0),
        "entityColor": (0, 0, 0, 0),
        "frameTimeCounter": frame_time, "frameTime": 0.016, "rainStrength": rain, "wetness": rain,
        "thunderStrength": 0.0, "viewWidth": float(W), "viewHeight": float(H), "near": NEAR, "far": FAR,
        "sunAngle": celestial, "nightVision": 0.0, "blindness": 0.0, "darknessFactor": 0.0,
        "worldTime": 0, "isEyeInWater": eye_in_water, "frameCounter": 1, "heldBlockLightValue": 0,
        "heldBlockLightValue2": 0, "renderStage": 0,
    }

    white = tex2d(1, 1, GL_RGBA8, GL_RGBA, GL_UNSIGNED_BYTE)
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, bytes([255, 255, 255, 255]))

    glMatrixMode(GL_TEXTURE)
    glActiveTexture(GL_TEXTURE1)
    glLoadIdentity()
    glTranslatef(1 / 32, 1 / 32, 0)
    glScalef(1 / 256, 1 / 256, 1)
    glActiveTexture(GL_TEXTURE0)
    glLoadIdentity()

    # --- shadow pass
    sh_depth = tex2d(SHADOW_RES, SHADOW_RES, GL_DEPTH_COMPONENT32F, GL_DEPTH_COMPONENT, GL_FLOAT)
    sh_color = tex2d(SHADOW_RES, SHADOW_RES, GL_RGBA8, GL_RGBA, GL_UNSIGNED_BYTE)
    sh_fbo = fbo([sh_color], sh_depth)
    glViewport(0, 0, SHADOW_RES, SHADOW_RES)
    glClearColor(1, 1, 1, 1)
    glClearDepth(1.0)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    glEnable(GL_DEPTH_TEST)
    glDisable(GL_CULL_FACE)
    if folder != "world-1":
        p = pipe.prog("shadow")
        set_uniforms(p, u, [("gtexture", white, 0)])
        load_matrix(GL_PROJECTION, shadow_proj)
        load_matrix(GL_MODELVIEW, shadow_view)
        scene.draw(p, None)

    cmp_sampler, raw_sampler = glGenSamplers(2)
    for s, cmp in ((cmp_sampler, True), (raw_sampler, False)):
        glSamplerParameteri(s, GL_TEXTURE_MIN_FILTER, GL_LINEAR if cmp else GL_NEAREST)
        glSamplerParameteri(s, GL_TEXTURE_MAG_FILTER, GL_LINEAR if cmp else GL_NEAREST)
        glSamplerParameteri(s, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
        glSamplerParameteri(s, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
        if cmp:
            glSamplerParameteri(s, GL_TEXTURE_COMPARE_MODE, GL_COMPARE_REF_TO_TEXTURE)
            glSamplerParameteri(s, GL_TEXTURE_COMPARE_FUNC, GL_LEQUAL)
    shadow_samplers = [("shadowtex0", sh_depth, cmp_sampler), ("shadowtex1", sh_depth, raw_sampler),
                       ("shadowcolor0", sh_color, 0)]

    # --- gbuffers (opaque)
    ct = {i: tex2d(W, H, GL_RGBA16F, mips=(i == 0)) for i in range(8)}
    alt0 = tex2d(W, H, GL_RGBA16F, mips=True)
    depth0 = tex2d(W, H, GL_DEPTH_COMPONENT32F, GL_DEPTH_COMPONENT, GL_FLOAT)
    depth1 = tex2d(W, H, GL_DEPTH_COMPONENT32F, GL_DEPTH_COMPONENT, GL_FLOAT)
    glViewport(0, 0, W, H)
    g_fbo = fbo([ct[0], ct[1], ct[2]], depth0)
    glClearColor(0, 0, 0, 0)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    p = pipe.prog("gbuffers_terrain")
    set_uniforms(p, u, [("gtexture", white, 0)])
    load_matrix(GL_PROJECTION, proj)
    load_matrix(GL_MODELVIEW, view)
    scene.draw(p, False)
    for i in (3, 4, 5, 6):
        glBindFramebuffer(GL_FRAMEBUFFER, fbo([ct[i]]))
        glClear(GL_COLOR_BUFFER_BIT)

    # --- deferred (colortex0 albedo -> lit, ping-pong)
    glDisable(GL_DEPTH_TEST)
    glBindFramebuffer(GL_FRAMEBUFFER, fbo([alt0]))
    p = pipe.prog("deferred")
    set_uniforms(p, u, [("colortex0", ct[0], 0), ("colortex1", ct[1], 0), ("colortex2", ct[2], 0),
                        ("depthtex0", depth0, 0)] + shadow_samplers)
    fullscreen()
    ct[0], alt0 = alt0, ct[0]

    # --- translucent (water)
    glCopyImageSubData(depth0, GL_TEXTURE_2D, 0, 0, 0, 0, depth1, GL_TEXTURE_2D, 0, 0, 0, 0, W, H, 1)
    glEnable(GL_DEPTH_TEST)
    glBindFramebuffer(GL_FRAMEBUFFER, fbo([ct[4], ct[3]], depth0))
    glEnablei(GL_BLEND, 0)
    glBlendFuncSeparatei(0, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE_MINUS_SRC_ALPHA)
    glDisablei(GL_BLEND, 1)
    p = pipe.prog("gbuffers_water")
    set_uniforms(p, u, [("gtexture", white, 0)] + shadow_samplers)
    load_matrix(GL_PROJECTION, proj)
    load_matrix(GL_MODELVIEW, view)
    scene.draw(p, True)
    glDisable(GL_BLEND)
    glDisable(GL_DEPTH_TEST)

    def pass_(name, outs, reads):
        nonlocal alt0
        targets = [alt0 if o == 0 else ct[o] for o in outs]
        scratch = {}
        # write to fresh textures when a pass reads and writes the same buffer
        for idx, o in enumerate(outs):
            if o != 0 and o in [r for r in reads]:
                scratch[o] = tex2d(W, H, GL_RGBA16F)
                targets[idx] = scratch[o]
        glBindFramebuffer(GL_FRAMEBUFFER, fbo(targets))
        samplers = [(f"colortex{r}", ct[r], 0) for r in reads]
        samplers += [("depthtex0", depth0, 0), ("depthtex1", depth1, 0)] + shadow_samplers
        set_uniforms(pipe.prog(name), u, samplers)
        fullscreen()
        if 0 in outs:
            ct[0], alt0 = alt0, ct[0]
        for o, t in scratch.items():
            ct[o] = t

    if DEBUG:
        dump(alt0, out.with_suffix(".albedo.png"), 1.0)
        dump(ct[0], out.with_suffix(".deferred.png"))
        dump(ct[1], out.with_suffix(".data.png"), 1.0)
    pass_("composite", [0], [0, 3, 4])
    if DEBUG:
        dump(ct[0], out.with_suffix(".composite.png"))
    glBindTexture(GL_TEXTURE_2D, ct[0])
    glGenerateMipmap(GL_TEXTURE_2D)
    pass_("composite1", [5, 7], [0, 7])
    pass_("composite2", [6], [5])
    pass_("composite3", [5], [6])

    final_tex = tex2d(W, H, GL_RGBA8, GL_RGBA, GL_UNSIGNED_BYTE)
    glBindFramebuffer(GL_FRAMEBUFFER, fbo([final_tex]))
    set_uniforms(pipe.prog("final"), u, [("colortex0", ct[0], 0), ("colortex5", ct[5], 0), ("colortex7", ct[7], 0)])
    fullscreen()
    data = glReadPixels(0, 0, W, H, GL_RGB, GL_UNSIGNED_BYTE)
    img = Image.frombytes("RGB", (W, H), data).transpose(Image.FLIP_TOP_BOTTOM)
    if out:
        img.save(out)
    return img


SHOTS = [
    # name, folder, celestial angle (0 = noon), yaw (radians, 0 = +X/east), pitch, rain, eye in water
    ("noon", "", 0.03, 0.9, -8, 0.0, 0),
    ("sunset", "", 0.235, math.pi + 0.35, -4, 0.0, 0),
    ("sunrise-lake", "", 0.77, 0.25, -10, 0.0, 0),
    ("night", "", 0.5, 0.6, -6, 0.0, 0),
    ("lake-noon", "", 0.02, -0.55, -28, 0.0, 0, (0.5, 72.0, 0.5)),
    ("underwater", "", 0.04, 2.6, 18, 0.0, 1, (12.5, 62.2, -8.5)),
    ("rain", "", 0.08, 0.9, -8, 1.0, 0),
    ("nether", "world-1", 0.5, 0.9, -8, 0.0, 0),
    ("end", "world1", 0.0, 0.9, -4, 0.0, 0),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, default=Path("out/previews"))
    ap.add_argument("--only", nargs="*")
    ap.add_argument("--debug", action="store_true")
    args = ap.parse_args()
    global DEBUG
    DEBUG = args.debug
    args.out.mkdir(parents=True, exist_ok=True)
    mesa_check.make_context()
    overworld, nether, end = Scene(), Scene(nether=True), Scene(end=True)
    images = []
    global CAMERA
    for name, folder, cel, yaw, pitch, rain, water, *cam in SHOTS:
        if args.only and name not in args.only:
            continue
        CAMERA = np.array(cam[0] if cam else (0.5, 68.62, 0.5))
        scene = {"": overworld, "world-1": nether, "world1": end}[folder]
        img = render(scene, folder, cel, yaw, pitch, rain, water, args.out / f"{name}.png")
        images.append(img)
        print("rendered", name)
    if len(images) > 1:
        cols = 2
        rows = (len(images) + 1) // 2
        sheet = Image.new("RGB", (W // 2 * cols, H // 2 * rows))
        for i, im in enumerate(images):
            sheet.paste(im.resize((W // 2, H // 2)), ((i % cols) * W // 2, (i // cols) * H // 2))
        sheet.save(args.out / "contact-sheet.png")


if __name__ == "__main__":
    main()
