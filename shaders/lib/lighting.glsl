#ifndef LIGHTING_GLSL
#define LIGHTING_GLSL

// Requires common.glsl and (outside the Nether) shadows.glsl.

vec3 blockLightColor() {
    vec3 neutral = vec3(1.0, 0.86, 0.72);
    vec3 warm = vec3(1.0, 0.52, 0.2);
    return mix(neutral, warm, BLOCKLIGHT_WARMTH);
}

float blockLightFalloff(float x) {
    return pow(x, 4.5) * 1.6 + pow(x, 1.6) * 0.1;
}

float handLightLevel(vec3 playerPos) {
    #ifdef HANDHELD_LIGHT
    float held = float(max(heldBlockLightValue, heldBlockLightValue2));
    return saturate((held - length(playerPos) - 0.5) / 15.0);
    #else
    return 0.0;
    #endif
}

float ggxSpecular(vec3 N, vec3 V, vec3 L, float roughness, float F0) {
    vec3 H = normalize(V + L);
    float NdotH = saturate(dot(N, H));
    float NdotL = saturate(dot(N, L));
    float NdotV = saturate(dot(N, V)) + 1e-4;
    float a2 = sq(roughness * roughness);
    float d = a2 / (PI * sq(NdotH * NdotH * (a2 - 1.0) + 1.0));
    float k = sq(roughness + 1.0) / 8.0;
    float g = (NdotL / (NdotL * (1.0 - k) + k)) * (NdotV / (NdotV * (1.0 - k) + k));
    float F = F0 + (1.0 - F0) * pow(1.0 - saturate(dot(H, V)), 5.0);
    return d * g * F / (4.0 * NdotV) * NdotL;
}

float fresnelSchlick(float cosTheta, float F0) {
    return F0 + (1.0 - F0) * pow(1.0 - saturate(cosTheta), 5.0);
}

struct SurfaceData {
    vec3 albedo;    // linear
    vec3 normal;    // world space
    vec3 playerPos; // relative to the camera
    vec2 lightmap;  // normalized block/sky light
    float material;
    float ao;
    float emission;
};

float puddleMask(vec3 worldPos, vec3 normal, float skyLight) {
    #if defined PUDDLES && defined RAIN_WETNESS && defined DIM_OVERWORLD
    float up = smoothstep(0.7, 0.95, normal.y);
    float n = valueNoise2(worldPos.xz * 0.12) * 0.65 + valueNoise2(worldPos.xz * 0.45) * 0.35;
    return up * smoothstep(0.52, 0.66, n + wetness * 0.12) * wetness * smoothstep(0.88, 0.97, skyLight);
    #else
    return 0.0;
    #endif
}

vec3 shadeSurface(inout SurfaceData s, vec3 lightDir, vec3 lightCol, vec3 ambCol, float dither) {
    vec3 N = s.normal;
    vec3 V = -normalize(s.playerPos);
    bool plant = s.material == MAT_PLANT;
    bool leaves = s.material == MAT_LEAVES;
    float skyL = s.lightmap.y;
    float blockL = max(s.lightmap.x, handLightLevel(s.playerPos));

    float roughness = 0.85;
    float F0 = 0.02;

    #if defined RAIN_WETNESS && defined DIM_OVERWORLD
    float wet = wetness * smoothstep(0.85, 0.96, skyL) * mix(0.5, 1.0, saturate(N.y));
    float puddle = puddleMask(s.playerPos + cameraPosition, N, skyL);
    wet = max(wet, puddle);
    s.albedo *= mix(1.0, 0.55, wet * (1.0 - float(plant || leaves) * 0.6));
    s.albedo = pow(s.albedo, vec3(1.0 + wet * 0.35));
    roughness = mix(roughness, 0.32, wet);
    roughness = mix(roughness, 0.06, puddle);
    F0 = mix(F0, 0.03, wet);
    if (puddle > 0.0) N = normalize(mix(N, vec3(0.0, 1.0, 0.0), puddle));
    #endif

    vec3 color = vec3(0.0);

    // Sky + ambient
    float skyVis = skyL * skyL;
    float upness = N.y * 0.3 + 0.7;
    #ifdef DIM_OVERWORLD
    vec3 ambient = ambCol * skyVis * upness;
    #else
    vec3 ambient = ambCol * upness;
    #endif
    ambient += vec3(0.55, 0.65, 1.0) * 0.004 * MIN_LIGHT;
    ambient += vec3(0.25) * nightVision;
    color += ambient * s.ao;

    // Block light
    vec3 torch = blockLightColor() * blockLightFalloff(blockL) * 2.2 * BLOCKLIGHT_BRIGHTNESS;
    color += torch * mix(1.0, s.ao, 0.6);

    #ifndef DIM_NETHER
    // Direct sun / moon / End light
    float NdotL = dot(N, lightDir);
    float diffuse;
    if (plant) diffuse = 0.55 + 0.25 * abs(NdotL);
    else if (leaves) diffuse = saturate(NdotL * 0.6 + 0.4);
    else diffuse = saturate(NdotL);

    if (diffuse > 0.0 || plant || leaves) {
        vec3 shadow = getShadow(s.playerPos, N, NdotL, dither, plant || leaves);
        #ifdef DIM_OVERWORLD
        shadow *= smoothstep(0.02, 0.3, skyL);
        #endif
        vec3 direct = lightCol * shadow;
        color += direct * diffuse * s.ao;

        if (plant || leaves) {
            float sss = henyeyGreenstein(dot(-V, lightDir), 0.55) * 2.5 * FOLIAGE_SSS;
            color += direct * sss * (leaves ? 0.6 : 0.8);
        }

        vec3 spec = direct * ggxSpecular(N, V, lightDir, roughness, F0);
        s.albedo = max(s.albedo, vec3(0.0));
        color = color * s.albedo + spec;
    } else {
        color *= s.albedo;
    }
    #else
    color *= s.albedo;
    #endif

    #if defined RAIN_WETNESS && defined DIM_OVERWORLD
    float fres = fresnelSchlick(saturate(dot(N, V)), F0);
    color += ambCol * skyVis * fres * wet * 0.35;
    #endif

    color += s.albedo * s.emission * 4.0 * EMISSIVE_BRIGHTNESS;
    return color;
}

#endif
