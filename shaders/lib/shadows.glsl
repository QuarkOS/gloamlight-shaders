#ifndef SHADOWS_GLSL
#define SHADOWS_GLSL

uniform sampler2DShadow shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

#include "/lib/shadows_distort.glsl"

vec3 distortShadowClip(vec3 clip) {
    return distortShadowClipVertex(clip);
}

vec3 playerToShadowClip(vec3 playerPos) {
    vec3 shadowView = (shadowModelView * vec4(playerPos, 1.0)).xyz;
    return (shadowProjection * vec4(shadowView, 1.0)).xyz;
}

// Sharp, single-tap visibility used by volumetric light.
float shadowVisibilityHard(vec3 playerPos) {
    vec3 clip = playerToShadowClip(playerPos);
    if (max(abs(clip.x), abs(clip.y)) > 0.999) return 1.0;
    vec3 s = distortShadowClip(clip) * 0.5 + 0.5;
    return texture(shadowtex0, vec3(s.xy, s.z - 0.0002));
}

// Soft (PCF / PCSS) shadow with optional translucent tint. Returns light transmittance.
vec3 getShadow(vec3 playerPos, vec3 normalWorld, float NdotL, float dither, bool isFoliage) {
    float res = float(shadowMapResolution);

    vec3 clip = playerToShadowClip(playerPos);
    float f = shadowDistortFactor(clip.xy);
    float texelBlocks = 2.0 * shadowDistance / res * f;
    float texelsPerBlock = 1.0 / texelBlocks;
    float blocksPerDepth = 1.0 / max(abs(shadowProjection[2][2]) * 0.1, 1e-6);

    vec3 biased = playerPos + normalWorld * texelBlocks * (isFoliage ? 0.5 : 1.6);
    clip = playerToShadowClip(biased);

    float edge = max(abs(clip.x), abs(clip.y));
    if (edge > 0.999) return vec3(1.0);

    vec3 s = distortShadowClip(clip) * 0.5 + 0.5;
    s.z -= texelBlocks * 0.5 / blocksPerDepth;
    float phi = dither * TAU;

    #ifdef PCSS
    float blockerSum = 0.0;
    float blockerCount = 0.0;
    float searchRadius = clamp(1.2 * texelsPerBlock, 2.0, 24.0) / res;
    for (int i = 0; i < 6; i++) {
        vec2 off = vogelDisk(i, 6, phi) * searchRadius;
        float d = texture(shadowtex1, s.xy + off).r;
        if (d < s.z) {
            blockerSum += d;
            blockerCount += 1.0;
        }
    }
    float penumbraBlocks = 0.03;
    if (blockerCount > 0.0) {
        float blockerDist = (s.z - blockerSum / blockerCount) * blocksPerDepth;
        penumbraBlocks += blockerDist * 0.022;
    }
    float radius = clamp(penumbraBlocks * SHADOW_SOFTNESS * texelsPerBlock, 0.6, 20.0) / res;
    #else
    float radius = clamp(0.06 * SHADOW_SOFTNESS * texelsPerBlock, 0.6, 8.0) / res;
    #endif

    float lit = 0.0;
    float litOpaque = 0.0;
    for (int i = 0; i < SHADOW_SAMPLES; i++) {
        vec2 off = vogelDisk(i, SHADOW_SAMPLES, phi) * radius;
        lit += texture(shadowtex0, vec3(s.xy + off, s.z));
        #ifdef COLORED_SHADOWS
        litOpaque += step(s.z, texture(shadowtex1, s.xy + off).r);
        #endif
    }
    lit /= float(SHADOW_SAMPLES);

    vec3 result = vec3(lit);
    #ifdef COLORED_SHADOWS
    litOpaque /= float(SHADOW_SAMPLES);
    vec4 tintSample = texture(shadowcolor0, s.xy);
    vec3 tint = toLinear(tintSample.rgb);
    result += max(litOpaque - lit, 0.0) * tint;
    #endif

    return mix(result, vec3(1.0), smoothstep(0.9, 0.999, edge));
}

#endif
