#ifndef SHADOWS_DISTORT_GLSL
#define SHADOWS_DISTORT_GLSL

// Radial distortion concentrates shadow map texels near the player; depth is
// compressed so the ortho volume keeps precision. Must match between passes.
float shadowDistortFactor(vec2 clipXY) {
    return length(clipXY) * SHADOW_DISTORTION + (1.0 - SHADOW_DISTORTION);
}

vec3 distortShadowClipVertex(vec3 clip) {
    return vec3(clip.xy / shadowDistortFactor(clip.xy), clip.z * 0.2);
}

#endif
