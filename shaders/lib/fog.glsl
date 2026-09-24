#ifndef FOG_GLSL
#define FOG_GLSL

// Requires common.glsl, atmosphere.glsl and (except in the Nether) shadows.glsl.

float eyeSkyExposure() {
    return saturate(float(eyeBrightnessSmooth.y) / 240.0);
}

struct FogParams {
    float density;     // per block at the reference height
    float refHeight;
    float falloff;     // height scale in blocks
    float mieG;
    vec3 lightCol;
    vec3 ambient;
};

FogParams overworldFogParams(vec3 sunDir, vec3 lightCol, vec3 ambCol) {
    FogParams p;
    float lowSun = 1.0 - smoothstep(0.0, 0.3, abs(sunDir.y));
    float morning = lowSun * (sunDir.x > 0.0 ? 1.0 : 0.45) * MORNING_FOG;
    float night = smoothstep(0.05, -0.15, sunDir.y) * 0.5;
    p.density = (0.0014 + morning * 0.0045 + night * 0.001) * FOG_DENSITY
              + rainStrength * 0.011 * RAIN_FOG;
    p.refHeight = 63.0;
    p.falloff = 26.0 + rainStrength * 40.0;
    p.mieG = 0.72 - rainStrength * 0.3;
    float eyeSky = eyeSkyExposure();
    p.lightCol = lightCol * VL_STRENGTH;
    p.ambient = ambCol / PI * mix(0.12, 1.0, eyeSky);
    return p;
}

FogParams endFogParams(vec3 lightCol, vec3 ambCol) {
    FogParams p;
    p.density = 0.0035 * END_FOG_DENSITY;
    p.refHeight = 50.0;
    p.falloff = 60.0;
    p.mieG = 0.6;
    p.lightCol = lightCol * VL_STRENGTH * 1.5;
    p.ambient = ambCol * 0.6;
    return p;
}

float fogDensityAt(FogParams p, float worldY) {
    return p.density * exp(-max(worldY - p.refHeight, 0.0) / p.falloff);
}

// Exact optical depth of exponential height fog along a straight segment.
float fogOpticalDepth(FogParams p, vec3 dir, float dist) {
    float y0 = cameraPosition.y - p.refHeight;
    float dy = dir.y;
    if (abs(dy) < 1e-3) return fogDensityAt(p, cameraPosition.y + dir.y * dist * 0.5) * dist;
    float y0c = max(y0, 0.0);
    float y1c = max(y0 + dy * dist, 0.0);
    float k = p.falloff / dy;
    return p.density * k * (exp(-y0c / p.falloff) - exp(-y1c / p.falloff)) + p.density * max(0.0, dist - (abs(y1c - y0c) / abs(dy)));
}

vec3 applyScatteringFog(vec3 color, vec3 playerEnd, float dist, FogParams p, vec3 lightDir, float dither) {
    vec3 dir = playerEnd / max(length(playerEnd), 1e-4);
    float mu = dot(dir, lightDir);
    float phase = (0.65 * henyeyGreenstein(mu, p.mieG) + 0.35 / (4.0 * PI)) * 4.0 * PI;

    #if defined VOLUMETRIC_LIGHT && !defined DIM_NETHER
    float T = 1.0;
    vec3 S = vec3(0.0);
    float caveSun = mix(0.0, 1.0, eyeSkyExposure());
    for (int i = 0; i < VL_STEPS; i++) {
        float a = (float(i) + dither) / float(VL_STEPS);
        float b = min((float(i) + 1.0 + dither) / float(VL_STEPS), 1.0);
        float t0 = dist * a * a;
        float t1 = dist * b * b;
        float ds = t1 - t0;
        vec3 pos = dir * (0.5 * (t0 + t1));
        float dens = fogDensityAt(p, pos.y + cameraPosition.y);
        float vis = length(pos) < shadowDistance ? shadowVisibilityHard(pos) : caveSun;
        float stepT = exp(-dens * ds);
        S += T * (1.0 - stepT) * (p.lightCol * phase * vis + p.ambient);
        T *= stepT;
    }
    return color * T + S;
    #else
    float od = fogOpticalDepth(p, dir, dist);
    float T = exp(-od);
    float sunVis = 0.6 * eyeSkyExposure();
    #ifdef DIM_NETHER
    sunVis = 0.0;
    #endif
    return color * T + (1.0 - T) * (p.lightCol * phase * sunVis + p.ambient);
    #endif
}

vec3 waterAbsorption() {
    return vec3(0.34, 0.085, 0.055) / WATER_CLARITY;
}

vec3 waterScatterColor(vec3 lightCol, vec3 ambCol, float skyVis) {
    vec3 albedo = vec3(0.04, 0.32, 0.38);
    return albedo * (lightCol * 0.25 + ambCol / PI) * (skyVis * 0.9 + 0.1);
}

vec3 applyWaterFog(vec3 color, float dist, vec3 lightCol, vec3 ambCol, float skyVis) {
    vec3 sigma = waterAbsorption() * UNDERWATER_FOG + 0.015;
    vec3 T = exp(-sigma * dist);
    vec3 scatter = waterScatterColor(lightCol, ambCol, skyVis);
    return color * T + scatter * (1.0 - T);
}

vec3 applyNetherFog(vec3 color, vec3 playerEnd, float dist) {
    vec3 fogCol = toLinear(fogColor) * 0.3 + vec3(0.01, 0.004, 0.002);
    float y = cameraPosition.y + playerEnd.y * 0.5;
    float lavaHaze = 1.0 + 1.2 * smoothstep(48.0, 28.0, y);
    float dens = 0.0065 * NETHER_FOG_DENSITY * lavaHaze;
    float T = exp(-dens * dist);
    // Smoky, slowly drifting density variation.
    vec3 wp = cameraPosition + playerEnd * 0.35;
    float n = valueNoise3(wp * 0.03 + vec3(0.0, frameTimeCounter * 0.05, 0.0));
    T = pow(T, 0.75 + n * 0.5);
    return mix(fogCol, color, T);
}

vec3 applyStatusFog(vec3 color, float dist) {
    float b = max(blindness, darknessFactor * 0.9);
    return color * exp(-dist * b * 0.35);
}

#endif
