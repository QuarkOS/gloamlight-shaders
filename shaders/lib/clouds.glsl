#ifndef CLOUDS_GLSL
#define CLOUDS_GLSL

// Raymarched cumulus slab in world space (block units).

#if CLOUD_QUALITY == 1
    #define CLOUD_STEPS 8
    #define CLOUD_LIGHT_STEPS 2
#elif CLOUD_QUALITY == 2
    #define CLOUD_STEPS 14
    #define CLOUD_LIGHT_STEPS 3
#else
    #define CLOUD_STEPS 24
    #define CLOUD_LIGHT_STEPS 4
#endif

const float CLOUD_SIGMA = 0.045;

vec2 cloudWind() {
    return vec2(1.0, 0.35) * frameTimeCounter * 2.5 * CLOUD_SPEED;
}

float cloudCoverage() {
    return saturate(CLOUD_COVERAGE + rainStrength * 0.3 + thunderStrength * 0.1);
}

float cloudDensity(vec3 p, bool detail) {
    float h = (p.y - float(CLOUD_ALTITUDE)) / float(CLOUD_THICKNESS);
    if (h < 0.0 || h > 1.0) return 0.0;

    vec2 q = (p.xz + cloudWind()) * 0.0018;
    float n = valueNoise2(q) * 0.5;
    n += valueNoise2(q * 2.03 + 11.7) * 0.25;
    n += valueNoise2(q * 4.11 - 3.1) * 0.125;
    n += valueNoise2(q * 8.27 + 5.3) * 0.0625;
    n /= 0.9375;

    // Flat base, billowing top.
    float profile = smoothstep(0.0, 0.12, h) * smoothstep(1.0, 0.35, h);
    float cov = cloudCoverage();
    float d = n * mix(0.55, 1.0, profile) - (1.0 - cov);
    d *= profile;

    #if CLOUD_QUALITY >= 2
    if (detail && d > 0.0) {
        vec3 dq = vec3(p.x + cloudWind().x * 1.3, p.y, p.z + cloudWind().y * 1.3) * 0.035;
        d -= (valueNoise3(dq) * 0.6 + valueNoise3(dq * 2.7) * 0.4) * 0.22 * (1.2 - h);
    }
    #endif

    return saturate(d * 3.0);
}

// Returns scattered light (rgb) and transmittance (a) of the cloud layer along rd.
vec4 renderClouds(vec3 rd, vec3 lightDir, vec3 lightCol, vec3 ambient, float dither) {
    #if CLOUD_QUALITY == 0
    return vec4(0.0, 0.0, 0.0, 1.0);
    #else
    float camY = cameraPosition.y;
    float lo = float(CLOUD_ALTITUDE);
    float hi = lo + float(CLOUD_THICKNESS);
    if (abs(rd.y) < 1e-4) return vec4(0.0, 0.0, 0.0, 1.0);

    float t0 = (lo - camY) / rd.y;
    float t1 = (hi - camY) / rd.y;
    float tEnter = max(min(t0, t1), 0.0);
    float tExit = max(t0, t1);
    if (tExit <= 0.0 || tEnter > 14000.0) return vec4(0.0, 0.0, 0.0, 1.0);
    tExit = min(tExit, tEnter + float(CLOUD_THICKNESS) * 6.0);

    float ds = (tExit - tEnter) / float(CLOUD_STEPS);
    float mu = dot(rd, lightDir);
    float phase = 0.7 * henyeyGreenstein(mu, 0.65) + 0.3 * henyeyGreenstein(mu, -0.25);
    float lightStep = float(CLOUD_THICKNESS) * 0.18;
    vec3 origin = vec3(cameraPosition.x, camY, cameraPosition.z);

    float T = 1.0;
    vec3 S = vec3(0.0);
    for (int i = 0; i < CLOUD_STEPS; i++) {
        vec3 p = origin + rd * (tEnter + (float(i) + dither) * ds);
        float d = cloudDensity(p, true);
        if (d <= 0.005) continue;

        float od = 0.0;
        for (int j = 0; j < CLOUD_LIGHT_STEPS; j++) {
            od += cloudDensity(p + lightDir * ((float(j) + 0.5) * lightStep), false);
        }
        od *= lightStep * CLOUD_SIGMA;

        float h = saturate((p.y - lo) / float(CLOUD_THICKNESS));
        float beer = exp(-od) + exp(-od * 0.25) * 0.35;
        float powder = 1.0 - exp(-d * CLOUD_SIGMA * ds * 2.0);
        vec3 direct = lightCol * beer * (phase * 4.0 * PI * 0.55 + 0.2) * mix(0.6, 1.0, powder);
        vec3 amb = ambient * (0.25 + 0.55 * h) * 0.35;

        float stepT = exp(-d * CLOUD_SIGMA * ds);
        S += T * (1.0 - stepT) * (direct + amb);
        T *= stepT;
        if (T < 0.02) break;
    }

    float fade = 1.0 - smoothstep(5000.0, 14000.0, tEnter);
    return vec4(S * fade, mix(1.0, T, fade));
    #endif
}

#endif
