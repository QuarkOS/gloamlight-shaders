#ifndef BLOOM_GLSL
#define BLOOM_GLSL

// Bloom pyramid packed into one buffer: tile i holds mip level i + 2, laid out left to right.
#define BLOOM_TILES 6

float bloomTileScale(int i) {
    return exp2(-float(i + 2));
}

vec2 bloomTileOffset(int i) {
    float pad = 12.0 / viewWidth;
    float x = pad;
    for (int k = 0; k < i; k++) x += bloomTileScale(k) + pad;
    return vec2(x, 12.0 / viewHeight);
}

bool inBloomRegion(vec2 uv) {
    return uv.x < 0.62 && uv.y < 0.3;
}

#endif
