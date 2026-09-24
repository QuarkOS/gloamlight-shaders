#ifndef TONEMAP_GLSL
#define TONEMAP_GLSL

// ACES fitted (RRT + ODT) by Stephen Hill, sRGB primaries.
vec3 acesFitted(vec3 c) {
    const mat3 inputMat = mat3(0.59719, 0.07600, 0.02840,
                               0.35458, 0.90834, 0.13383,
                               0.04823, 0.01566, 0.83777);
    const mat3 outputMat = mat3(1.60475, -0.10208, -0.00327,
                                -0.53108, 1.10813, -0.07276,
                                -0.07367, -0.00605, 1.07602);
    c = inputMat * c;
    vec3 a = c * (c + 0.0245786) - 0.000090537;
    vec3 b = c * (0.983729 * c + 0.4329510) + 0.238081;
    return saturate(outputMat * (a / b));
}

vec3 acesApprox(vec3 c) {
    c *= 0.6;
    return saturate((c * (2.51 * c + 0.03)) / (c * (2.43 * c + 0.59) + 0.14));
}

vec3 reinhardLuma(vec3 c) {
    float l = luminance(c);
    vec3 tc = c / (1.0 + c);
    return saturate(mix(c / (1.0 + l), tc, tc));
}

vec3 tonemap(vec3 c) {
    #if TONEMAP == 0
    return acesFitted(c * 1.6);
    #elif TONEMAP == 1
    return acesApprox(c);
    #else
    return reinhardLuma(c);
    #endif
}

// Approximate blackbody color for a temperature in Kelvin, normalized to max = 1.
vec3 blackbody(float k) {
    float t = k / 100.0;
    vec3 c;
    c.r = t <= 66.0 ? 1.0 : saturate(1.29294 * pow(t - 60.0, -0.1332047));
    c.g = t <= 66.0 ? saturate(0.39008 * log(t) - 0.63184) : saturate(1.12989 * pow(t - 60.0, -0.0755148));
    c.b = t >= 66.0 ? 1.0 : (t <= 19.0 ? 0.0 : saturate(0.54320 * log(t - 10.0) - 1.19625));
    return c;
}

vec3 whiteBalance(vec3 c, float kelvin) {
    vec3 ref = blackbody(6500.0);
    vec3 target = blackbody(kelvin);
    return c * (ref / max(target, 1e-3)) * (luminance(target) / luminance(ref));
}

vec3 colorGrade(vec3 c) {
    float l = luminance(c);
    // Vibrance boosts muted colors more than saturated ones.
    float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
    c = mix(vec3(l), c, SATURATION * (1.0 + (VIBRANCE - 1.0) * (1.0 - sat)));
    c = saturate(c);

    c = saturate((c - 0.5) * CONTRAST + 0.5);

    // Split toning: cool shadows, warm highlights.
    l = luminance(c);
    vec3 shadowCol = vec3(0.92, 0.98, 1.08);
    vec3 highCol = vec3(1.05, 1.0, 0.94);
    #ifdef DIM_NETHER
    shadowCol = vec3(1.06, 0.96, 0.92);
    #elif defined DIM_END
    shadowCol = vec3(1.02, 0.94, 1.1);
    #endif
    vec3 tint = mix(shadowCol, highCol, smoothstep(0.1, 0.7, l));
    c *= mix(vec3(1.0), tint, SHADOW_TINT);
    return saturate(c);
}

#endif
