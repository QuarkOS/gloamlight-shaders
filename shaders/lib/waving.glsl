#ifndef WAVING_GLSL
#define WAVING_GLSL

vec3 windSway(vec3 worldPos, float strength) {
    float t = frameTimeCounter * WAVE_SPEED;
    float gust = 0.55 + 0.45 * sin(t * 0.35 + worldPos.x * 0.015 + worldPos.z * 0.01);
    gust += rainStrength * 0.9 + thunderStrength * 0.6;
    float phase = dot(worldPos.xz, vec2(0.67, 0.41));
    vec3 off = vec3(sin(t * 1.7 + phase), 0.0, sin(t * 1.35 + phase * 1.27 + 1.7));
    off.xz += vec2(sin(t * 3.9 + phase * 2.3), cos(t * 4.3 + phase * 2.1)) * 0.3;
    return off * strength * gust * WAVE_AMPLITUDE;
}

// isTop: vertex is at the upper edge of its texture (not anchored to the ground).
vec3 wavingOffset(vec3 worldPos, int id, bool isTop) {
    #ifdef WAVING_PLANTS
    if (id == ID_PLANT) return isTop ? windSway(worldPos, 0.07) : vec3(0.0);
    if (id == ID_PLANT_TOP) return windSway(worldPos, isTop ? 0.14 : 0.07);
    #endif
    #ifdef WAVING_LEAVES
    if (id == ID_LEAVES) {
        vec3 o = windSway(worldPos, 0.025);
        o.y = sin(frameTimeCounter * WAVE_SPEED * 2.1 + dot(worldPos, vec3(1.3, 0.7, 1.1))) * 0.012 * WAVE_AMPLITUDE;
        return o;
    }
    if (id == ID_HANGING) return windSway(worldPos, 0.04);
    #endif
    return vec3(0.0);
}

#endif
