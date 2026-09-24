#!/usr/bin/env python3
"""Compile and link every program pair with a real OpenGL driver (e.g. Mesa llvmpipe)
in a compatibility-profile context. Needs a display (or Xvfb), glfw and PyOpenGL."""
import sys
from pathlib import Path

import glfw
from OpenGL.GL import *  # noqa: F403

sys.path.insert(0, str(Path(__file__).resolve().parent))
import validate  # noqa: E402


def make_context():
    if not glfw.init():
        raise SystemExit("glfw init failed")
    glfw.window_hint(glfw.VISIBLE, glfw.FALSE)
    glfw.window_hint(glfw.CONTEXT_VERSION_MAJOR, 4)
    glfw.window_hint(glfw.CONTEXT_VERSION_MINOR, 5)
    glfw.window_hint(glfw.OPENGL_PROFILE, glfw.OPENGL_COMPAT_PROFILE)
    win = glfw.create_window(64, 64, "check", None, None)
    glfw.make_context_current(win)
    return win


def _text(v) -> str:
    return (v.decode(errors="replace") if isinstance(v, bytes) else str(v)).strip()


def compile_stage(src: str, kind) -> tuple[int, str]:
    sh = glCreateShader(kind)
    glShaderSource(sh, src)
    glCompileShader(sh)
    log = _text(glGetShaderInfoLog(sh))
    if not glGetShaderiv(sh, GL_COMPILE_STATUS):
        return 0, log
    return sh, log


def build(vs_src: str, fs_src: str) -> tuple[int, str]:
    vs, vlog = compile_stage(vs_src, GL_VERTEX_SHADER)
    fs, flog = compile_stage(fs_src, GL_FRAGMENT_SHADER)
    if not vs or not fs:
        return 0, f"VS: {vlog}\nFS: {flog}"
    prog = glCreateProgram()
    glAttachShader(prog, vs)
    glAttachShader(prog, fs)
    glLinkProgram(prog)
    log = _text(glGetProgramInfoLog(prog))
    if not glGetProgramiv(prog, GL_LINK_STATUS):
        return 0, f"LINK: {log}"
    return prog, "\n".join(l for l in (vlog, flog, log) if l)


def main(overrides=None) -> int:
    make_context()
    print(glGetString(GL_RENDERER).decode(), glGetString(GL_VERSION).decode())
    failures = 0
    folders = [validate.ROOT] + sorted(validate.ROOT.glob("world*"))
    for folder in folders:
        for vsh in sorted(folder.glob("*.vsh")):
            fsh = vsh.with_suffix(".fsh")
            vs = validate.preprocess(vsh, overrides or {})
            fs = validate.preprocess(fsh, overrides or {})
            prog, log = build(vs, fs)
            rel = vsh.relative_to(validate.ROOT).with_suffix("")
            if not prog:
                failures += 1
                print(f"FAIL {rel}\n{log}")
            elif log:
                print(f"warn {rel}: {log}")
    print("MESA ALL OK" if failures == 0 else f"{failures} failures")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
