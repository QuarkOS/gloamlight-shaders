// Water (refraction, absorption, reflections), translucent layer and fog / volumetric light.

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
#include "/lib/fog.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

in vec2 texcoord;
flat in vec3 lightCol;
flat in vec3 ambCol;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

vec3 skyRadiance(vec3 dirWorld, int steps) {
    #if defined DIM_OVERWORLD
    return atmosphere(dirWorld, sunDirWorld(), moonDirWorld(), steps);
    #elif defined DIM_END
    return endSky(dirWorld, lightDirWorld());
    #else
    return toLinear(fogColor) * 0.5;
    #endif
}

vec4 screenSpaceReflection(vec3 viewPos, vec3 R, float dither) {
    #ifdef WATER_SSR
    float stepLen = 0.4 + length(viewPos) * 0.03;
    vec3 stepV = R * stepLen;
    vec3 pos = viewPos + stepV * dither;
    for (int i = 0; i < SSR_STEPS; i++) {
        pos += stepV;
        if (pos.z > -near) break;
        vec3 scr = viewToScreen(pos);
        if (any(lessThan(scr.xy, vec2(0.0))) || any(greaterThan(scr.xy, vec2(1.0)))) break;
        float sceneDepth = texture(depthtex1, scr.xy).r;
        float sceneZ = screenToView(vec3(scr.xy, sceneDepth)).z;
        float diff = sceneZ - pos.z;
        if (diff > 0.0 && diff < max(length(stepV) * 2.5, 0.6) && sceneDepth < 1.0) {
            vec3 a = pos - stepV;
            vec3 b = pos;
            for (int j = 0; j < 5; j++) {
                vec3 mid = 0.5 * (a + b);
                vec3 ms = viewToScreen(mid);
                float mz = screenToView(vec3(ms.xy, texture(depthtex1, ms.xy).r)).z;
                if (mz > mid.z) b = mid; else a = mid;
            }
            scr = viewToScreen(b);
            vec2 edge = smoothstep(0.0, 0.08, scr.xy) * smoothstep(1.0, 0.92, scr.xy);
            float fade = edge.x * edge.y * (1.0 - smoothstep(0.7, 1.0, float(i) / float(SSR_STEPS)));
            return vec4(texture(colortex0, scr.xy).rgb, fade);
        }
        stepV *= 1.2;
    }
    #endif
    return vec4(0.0);
}

vec3 shadeWater(vec3 color, vec3 view0, vec3 nView, float skyLight, float dither) {
    vec3 V = normalize(view0);
    vec3 R = reflect(V, nView);
    float cosTheta = saturate(dot(-V, nView));
    bool underwater = isEyeInWater == 1;
    float F = underwater ? fresnelSchlick(cosTheta, 0.02) * 0.5 : fresnelSchlick(cosTheta, 0.02);
    float skyVis = skyLight * skyLight;

    vec3 reflection;
    if (underwater) {
        reflection = waterScatterColor(lightCol, ambCol, skyVis);
    } else {
        vec3 Rworld = mat3(gbufferModelViewInverse) * R;
        vec3 fallback = skyRadiance(normalize(vec3(Rworld.x, abs(Rworld.y), Rworld.z)), 8) * skyVis
                      + ambCol * 0.02;
        vec4 ssr = screenSpaceReflection(view0, R, dither);
        reflection = mix(fallback, ssr.rgb, ssr.a);

        #ifndef DIM_NETHER
        vec3 playerPos = viewToPlayer(view0);
        vec3 L = lightDirWorld();
        vec3 N = mat3(gbufferModelViewInverse) * nView;
        float vis = shadowVisibilityHard(playerPos + N * 0.05);
        #ifdef DIM_OVERWORLD
        vis *= smoothstep(0.3, 0.8, skyLight);
        #endif
        reflection += lightCol * vis * ggxSpecular(N, -normalize(playerPos), L, 0.04, 1.0) * 0.5;
        #endif
    }
    return mix(color, reflection, F);
}

void main() {
    float depth0 = texture(depthtex0, texcoord).r;
    float depth1 = texture(depthtex1, texcoord).r;
    vec3 view0 = screenToView(vec3(texcoord, depth0));
    float dither = interleavedGradientNoise(gl_FragCoord.xy);
    vec3 color = texture(colortex0, texcoord).rgb;

    vec4 water = texture(colortex3, texcoord);
    if (water.w > 0.75 && depth0 < depth1) {
        vec3 nView = decodeNormal(water.xy);
        vec2 skyLm = vec2(0.0, water.z);

        vec3 view1 = screenToView(vec3(texcoord, depth1));
        float thickness = distance(view0, view1);
        vec2 refrUV = texcoord;
        vec3 nFlat = normalize(mat3(gbufferModelView) * vec3(0.0, 1.0, 0.0));
        vec2 offset = (nView.xy - nFlat.xy * dot(nView, nFlat)) * 0.12 * WATER_REFRACTION;
        offset *= saturate(thickness * 0.35) / (1.0 + length(view0) * 0.08);
        vec2 candidate = texcoord + offset;
        float candDepth = texture(depthtex1, candidate).r;
        if (candDepth > depth0 && all(greaterThan(candidate, vec2(0.0))) && all(lessThan(candidate, vec2(1.0)))) {
            refrUV = candidate;
            view1 = screenToView(vec3(refrUV, candDepth));
            thickness = distance(view0, view1);
        }
        color = texture(colortex0, refrUV).rgb;

        if (isEyeInWater != 1) {
            if (texture(depthtex1, refrUV).r >= 1.0) thickness = 64.0;
            color = applyWaterFog(color, thickness, lightCol, ambCol, skyLm.y * skyLm.y);
        }
        color = shadeWater(color, view0, nView, skyLm.y, dither);
    }

    vec4 translucent = texture(colortex4, texcoord);
    color = color * (1.0 - translucent.a) + translucent.rgb;

    vec3 playerPos = viewToPlayer(view0);
    bool isSky = depth0 >= 1.0;
    float dist = isSky ? far * 1.5 : length(playerPos);

    if (isEyeInWater == 1) {
        float eyeSky = eyeSkyExposure();
        color = applyWaterFog(color, min(dist, 256.0), lightCol, ambCol, eyeSky * eyeSky);
    } else if (isEyeInWater == 2) {
        color = mix(vec3(1.2, 0.35, 0.05), color, exp(-dist * 1.2));
    } else if (isEyeInWater == 3) {
        color = mix(vec3(0.7, 0.8, 0.9) * 0.5, color, exp(-dist * 0.9));
    } else {
        #if defined DIM_NETHER
        color = applyNetherFog(color, playerPos, dist);
        #elif defined DIM_END
        FogParams fp = endFogParams(lightCol, ambCol);
        color = applyScatteringFog(color, playerPos, min(dist, far), fp, lightDirWorld(), dither);
        #else
        FogParams fp = overworldFogParams(sunDirWorld(), lightCol, ambCol);
        color = applyScatteringFog(color, playerPos, dist, fp, lightDirWorld(), dither);
        #ifdef BORDER_FOG
        if (!isSky) {
            float border = smoothstep(far * 0.72, far * 0.98, length(playerPos.xz));
            if (border > 0.0) color = mix(color, skyRadiance(normalize(playerPos), 8), border);
        }
        #endif
        #endif
    }

    color = applyStatusFog(color, dist);
    outColor = vec4(color, 1.0);
}
#endif
