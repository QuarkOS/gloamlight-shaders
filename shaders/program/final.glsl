// Bloom merge, exposure, tonemapping, color grading and vignette.

#include "/lib/common.glsl"
#include "/lib/buffers.glsl"
#include "/lib/bloom.glsl"
#include "/lib/tonemap.glsl"

#ifdef VSH
out vec2 texcoord;

void main() {
    texcoord = gl_MultiTexCoord0.xy;
    gl_Position = ftransform();
}
#endif

#ifdef FSH
uniform sampler2D colortex0;
uniform sampler2D colortex5;
uniform sampler2D colortex7;

in vec2 texcoord;

layout(location = 0) out vec4 fragColor;

vec3 gatherBloom(vec2 uv) {
    vec3 sum = vec3(0.0);
    float wSum = 0.0;
    vec2 halfTexel = 0.5 / vec2(viewWidth, viewHeight);
    for (int i = 0; i < BLOOM_TILES; i++) {
        float s = bloomTileScale(i);
        vec2 tileUV = clamp(bloomTileOffset(i) + uv * s, bloomTileOffset(i) + halfTexel, bloomTileOffset(i) + s - halfTexel);
        float w = 1.0 + float(i) * 0.25;
        sum += texture(colortex5, tileUV).rgb * w;
        wSum += w;
    }
    return sum / wSum;
}

void main() {
    vec3 color = texture(colortex0, texcoord).rgb;

    #ifdef BLOOM
    float bloomAmount = 0.07 * BLOOM_STRENGTH;
    bloomAmount *= 1.0 + rainStrength * 0.6 + float(isEyeInWater == 1) * 1.5;
    #ifdef DIM_NETHER
    bloomAmount *= 1.5;
    #endif
    color = mix(color, gatherBloom(texcoord), saturate(bloomAmount));
    #endif

    #ifdef AUTO_EXPOSURE
    float exposure = texelFetch(colortex7, ivec2(0), 0).r;
    #else
    float exposure = 1.0;
    #endif
    color *= exposure * exp2(EXPOSURE);

    color = whiteBalance(color, float(WHITE_BALANCE));
    color = tonemap(color);
    color = toGamma(color);
    color = colorGrade(color);

    #ifdef VIGNETTE
    vec2 v = texcoord - 0.5;
    v.x *= viewWidth / viewHeight * 0.75;
    color *= 1.0 - VIGNETTE_STRENGTH * smoothstep(0.2, 0.95, length(v) * 1.35);
    #endif

    color += (hash12(gl_FragCoord.xy + fract(frameTimeCounter) * 61.0) - 0.5) / 255.0;
    fragColor = vec4(color, 1.0);
}
#endif
