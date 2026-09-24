// Bloom downsample into the tile atlas, and temporal auto exposure.

#include "/lib/common.glsl"
#include "/lib/buffers.glsl"
#include "/lib/bloom.glsl"

#ifdef VSH
out vec2 texcoord;

void main() {
    texcoord = gl_MultiTexCoord0.xy;
    gl_Position = ftransform();
}
#endif

#ifdef FSH
const bool colortex0MipmapEnabled = true;

uniform sampler2D colortex0;
uniform sampler2D colortex7;

in vec2 texcoord;

/* RENDERTARGETS: 5,7 */
layout(location = 0) out vec4 outBloom;
layout(location = 1) out vec4 outExposure;

vec3 sampleLodSafe(vec2 uv, float lod) {
    vec3 c = textureLod(colortex0, uv, lod).rgb;
    return min(c, vec3(500.0));
}

float computeExposure() {
    float maxLod = floor(log2(max(viewWidth, viewHeight)));
    float lod = max(maxLod - 3.0, 0.0);
    float logSum = 0.0;
    float wSum = 0.0;
    for (int y = 0; y < 5; y++) {
        for (int x = 0; x < 5; x++) {
            vec2 uv = (vec2(x, y) + 0.5) / 5.0;
            float w = exp(-dot(uv - 0.5, uv - 0.5) * 6.0);
            logSum += log2(max(luminance(sampleLodSafe(uv, lod)), 1e-5)) * w;
            wSum += w;
        }
    }
    float avgLum = exp2(logSum / wSum);
    // Partial adaptation keeps nights and caves darker than a full "gray world" exposure.
    float target = clamp(pow(0.16 / avgLum, 0.72), 0.35, 4.0);
    #if !defined DIM_OVERWORLD
    target = min(target, 2.0);
    #endif

    float prev = texelFetch(colortex7, ivec2(0), 0).r;
    if (!(prev > 0.0) || prev > 100.0) prev = target;
    float speed = target > prev ? 1.2 : 2.5;
    return mix(prev, target, 1.0 - exp(-frameTime * speed));
}

void main() {
    vec3 bloom = vec3(0.0);
    #ifdef BLOOM
    if (inBloomRegion(texcoord)) {
        vec2 viewSize = vec2(viewWidth, viewHeight);
        for (int i = 0; i < BLOOM_TILES; i++) {
            float s = bloomTileScale(i);
            vec2 local = (texcoord - bloomTileOffset(i)) / s;
            vec2 margin = 3.0 / (s * viewSize);
            if (all(greaterThan(local, -margin)) && all(lessThan(local, 1.0 + margin))) {
                float lod = float(i + 2);
                vec2 texel = exp2(lod) / viewSize;
                vec2 uv = clamp(local, vec2(0.0), vec2(1.0));
                bloom = sampleLodSafe(uv, lod) * 0.5;
                bloom += sampleLodSafe(uv + vec2( texel.x, texel.y) * 0.5, lod) * 0.125;
                bloom += sampleLodSafe(uv + vec2(-texel.x, texel.y) * 0.5, lod) * 0.125;
                bloom += sampleLodSafe(uv + vec2( texel.x, -texel.y) * 0.5, lod) * 0.125;
                bloom += sampleLodSafe(uv + vec2(-texel.x, -texel.y) * 0.5, lod) * 0.125;
                break;
            }
        }
    }
    #endif

    #ifdef AUTO_EXPOSURE
    float exposure = computeExposure();
    #else
    float exposure = 1.0;
    #endif

    outBloom = vec4(bloom, 1.0);
    outExposure = vec4(exposure, 0.0, 0.0, 1.0);
}
#endif
