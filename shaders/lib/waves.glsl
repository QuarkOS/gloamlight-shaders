#ifndef WAVES_GLSL
#define WAVES_GLSL

// Sum of sharp directional waves plus noise ripples; heights in blocks.
float waterHeight(vec2 p, float t) {
    float h = 0.0;
    float amp = 0.055;
    float freq = 0.55;
    float angle = 0.4;
    for (int i = 0; i < 5; i++) {
        vec2 dir = vec2(cos(angle), sin(angle));
        float x = dot(p, dir) * freq + t * (1.0 + float(i) * 0.35);
        h += amp * (exp(sin(x) - 1.0) - 0.4);
        amp *= 0.62;
        freq *= 1.72;
        angle += 2.1;
    }
    h += (valueNoise2(p * 1.6 + t * 0.35) - 0.5) * 0.03;
    return h * WATER_WAVE_HEIGHT;
}

vec3 waterNormal(vec2 worldXZ, float viewDist) {
    float t = frameTimeCounter * 1.2 * WATER_WAVE_SPEED;
    float e = 0.04;
    float h0 = waterHeight(worldXZ, t);
    float hx = waterHeight(worldXZ + vec2(e, 0.0), t);
    float hz = waterHeight(worldXZ + vec2(0.0, e), t);
    vec3 n = normalize(vec3(-(hx - h0) / e, 1.0, -(hz - h0) / e));
    // Calm distant water to limit aliasing.
    return normalize(mix(n, vec3(0.0, 1.0, 0.0), smoothstep(24.0, 96.0, viewDist) * 0.7));
}

#endif
