#ifndef BUFFERS_GLSL
#define BUFFERS_GLSL

/*
 colortex0  RGBA16F  gbuffer albedo -> lit HDR scene
 colortex1  RGBA16   octahedral normal (xy), lightmap (zw)
 colortex2  RGBA8    material id, emission
 colortex3  RGBA16   translucent normal (xy), sky light (z), mask (w: 1 water, 0.5 other)
 colortex4  RGBA16F  forward-shaded translucent layer (premultiplied)
 colortex5  RGBA16F  bloom tiles
 colortex6  RGBA16F  bloom blur scratch
 colortex7  RGBA16F  persistent auto-exposure

const int colortex0Format = RGBA16F;
const int colortex1Format = RGBA16;
const int colortex2Format = RGBA8;
const int colortex3Format = RGBA16;
const int colortex4Format = RGBA16F;
const int colortex5Format = RGBA16F;
const int colortex6Format = RGBA16F;
const int colortex7Format = RGBA16F;
const int shadowcolor0Format = RGBA8;

const vec4 colortex0ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 colortex1ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 colortex2ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 colortex3ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 colortex4ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 shadowcolor0ClearColor = vec4(1.0, 1.0, 1.0, 1.0);
const bool colortex5Clear = false;
const bool colortex6Clear = false;
const bool colortex7Clear = false;
*/

#endif
