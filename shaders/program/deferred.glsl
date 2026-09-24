// Deferred lighting of opaque geometry plus procedural sky, sun and clouds.

#include "/lib/common.glsl"
#include "/lib/buffers.glsl"
#include "/lib/atmosphere.glsl"
#include "/lib/dimension.glsl"

#ifdef VSH
out vec2 texcoord;
flat out vec3 lightCol;
flat out vec3 ambCol;

void main() {
    texcoord = gl_MultiTexCoord0.xy;
    getDimensionLight(lightCol, ambCol);
    gl_Position = ftransform();
}
#endif

#ifdef FSH
#ifndef DIM_NETHER
#include "/lib/shadows.glsl"
#endif
#include "/lib/lighting.glsl"
#include "/lib/clouds.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;

in vec2 texcoord;
flat in vec3 lightCol;
flat in vec3 ambCol;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

float screenSpaceAO(vec3 viewPos, vec3 nView, float dither) {
    #ifdef SSAO
    vec3 t = normalize(cross(nView, abs(nView.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
    vec3 b = cross(nView, t);
    float radius = 0.6;
    float occlusion = 0.0;
    for (int i = 0; i < SSAO_SAMPLES; i++) {
        vec2 disk = vogelDisk(i, SSAO_SAMPLES, dither * TAU);
        float h = sqrt(max(1.0 - dot(disk, disk), 0.0));
        float scale = mix(0.2, 1.0, fract(float(i) * 0.618 + dither));
        vec3 samplePos = viewPos + (t * disk.x + b * disk.y + nView * h) * radius * scale;
        vec3 scr = viewToScreen(samplePos);
        if (any(lessThan(scr.xy, vec2(0.0))) || any(greaterThan(scr.xy, vec2(1.0)))) continue;
        float sceneZ = screenToView(vec3(scr.xy, texture(depthtex0, scr.xy).r)).z;
        float range = smoothstep(0.0, 1.0, radius / abs(viewPos.z - sceneZ));
        occlusion += step(samplePos.z + 0.03, sceneZ) * range;
    }
    return pow(saturate(1.0 - occlusion / float(SSAO_SAMPLES)), SSAO_STRENGTH);
    #else
    return 1.0;
    #endif
}

vec3 renderSky(vec3 dir, vec3 skyObjects, float dither) {
    #if defined DIM_NETHER
    return toLinear(fogColor) * 0.5;
    #elif defined DIM_END
    return endSky(dir, lightDirWorld());
    #else
    vec3 sunDir = sunDirWorld();
    vec3 moonDir = moonDirWorld();
    vec3 viewT;
    vec3 sky = atmosphere(dir, sunDir, moonDir, SKY_STEPS, viewT);
    float aboveHorizon = smoothstep(-0.02, 0.01, dir.y);
    float clearSky = 1.0 - rainStrength * 0.9;
    sky += sunDisk(dir, sunDir) * viewT * 90.0 * SUN_BRIGHTNESS * aboveHorizon * clearSky;
    sky += toLinear(skyObjects) * viewT * 1.6 * MOON_BRIGHTNESS * aboveHorizon * clearSky;

    vec4 clouds = renderClouds(dir, lightDirWorld(), lightCol, ambCol, dither);
    sky = sky * clouds.a + clouds.rgb;
    return sky;
    #endif
}

void main() {
    float depth = texture(depthtex0, texcoord).r;
    vec3 viewPos = screenToView(vec3(texcoord, depth));
    vec3 playerPos = viewToPlayer(viewPos);
    float dither = interleavedGradientNoise(gl_FragCoord.xy);
    vec4 albedo = texture(colortex0, texcoord);

    if (depth >= 1.0) {
        outColor = vec4(renderSky(normalize(playerPos), albedo.rgb, dither), 1.0);
        return;
    }

    vec4 data = texture(colortex1, texcoord);
    vec4 mat = texture(colortex2, texcoord);
    vec3 nView = decodeNormal(data.xy);

    SurfaceData s;
    s.albedo = toLinear(albedo.rgb);
    s.normal = normalize(mat3(gbufferModelViewInverse) * nView);
    s.playerPos = playerPos;
    s.lightmap = normalizeLightmap(data.zw);
    s.material = floor(mat.r * 16.0 + 0.5);
    s.emission = mat.g;
    s.ao = screenSpaceAO(viewPos, nView, dither);

    outColor = vec4(shadeSurface(s, lightDirWorld(), lightCol, ambCol, dither), 1.0);
}
#endif
