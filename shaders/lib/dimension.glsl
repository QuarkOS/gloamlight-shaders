#ifndef DIMENSION_GLSL
#define DIMENSION_GLSL

// Requires common.glsl and atmosphere.glsl.

const vec3 END_LIGHT_COLOR = vec3(0.62, 0.46, 0.9);
const vec3 END_AMBIENT = vec3(0.06, 0.045, 0.1);

void getDimensionLight(out vec3 lightCol, out vec3 ambCol) {
    #if defined DIM_NETHER
    lightCol = vec3(0.0);
    ambCol = toLinear(fogColor) * 0.4 + vec3(0.07, 0.04, 0.03);
    ambCol *= AMBIENT_BRIGHTNESS;
    #elif defined DIM_END
    lightCol = END_LIGHT_COLOR * 0.9 * SUN_BRIGHTNESS;
    ambCol = END_AMBIENT * AMBIENT_BRIGHTNESS;
    #else
    vec3 sunDir = sunDirWorld();
    vec3 moonDir = moonDirWorld();
    lightCol = getDirectLightColor(sunDir, moonDir);
    ambCol = getSkyAmbient(sunDir, moonDir);
    #endif
}

vec3 endSky(vec3 dir, vec3 lightDir) {
    float h = dir.y;
    vec3 col = mix(vec3(0.012, 0.008, 0.02), vec3(0.045, 0.022, 0.07), smoothstep(-0.4, 0.7, h));

    vec3 q = dir * 3.0 + vec3(0.0, frameTimeCounter * 0.004, 0.0);
    float n = valueNoise3(q) * 0.55 + valueNoise3(q * 2.3 + 7.1) * 0.3 + valueNoise3(q * 5.1 - 3.3) * 0.15;
    float band = exp(-sq(dir.y * 2.2 + (n - 0.5) * 1.6));
    vec3 nebulaCol = mix(vec3(0.3, 0.07, 0.42), vec3(0.04, 0.22, 0.32), valueNoise3(dir * 1.7 + 2.0));
    col += nebulaCol * smoothstep(0.35, 0.95, n) * band * 0.35;

    vec3 cell = floor(dir * 160.0);
    float starSeed = hash13(cell);
    float star = step(0.9965, starSeed) * smoothstep(0.35, 0.0, length(fract(dir * 160.0) - 0.5));
    star *= 0.6 + 0.4 * sin(frameTimeCounter * (1.0 + starSeed * 3.0) + starSeed * 100.0);
    col += star * vec3(0.9, 0.8, 1.0) * 1.5 * STAR_BRIGHTNESS;

    float mu = saturate(dot(dir, lightDir));
    col += END_LIGHT_COLOR * (pow(mu, 18.0) * 0.35 + pow(mu, 400.0) * 3.0);
    return col;
}

#endif
