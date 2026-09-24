#ifndef UNIFORMS_GLSL
#define UNIFORMS_GLSL

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;

uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 shadowLightPosition;
uniform vec3 upPosition;
uniform vec3 fogColor;
uniform vec3 skyColor;
uniform vec4 entityColor;

uniform float frameTimeCounter;
uniform float frameTime;
uniform float rainStrength;
uniform float wetness;
uniform float thunderStrength;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;
uniform float sunAngle;
uniform float nightVision;
uniform float blindness;
uniform float darknessFactor;
uniform float screenBrightness;

uniform int worldTime;
uniform int isEyeInWater;
uniform int frameCounter;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform int renderStage;
uniform ivec2 eyeBrightnessSmooth;

// Iris injects these; fallbacks keep standalone validation working.
#ifndef MC_RENDER_STAGE_SUN
#define MC_RENDER_STAGE_NONE 0
#define MC_RENDER_STAGE_SKY 1
#define MC_RENDER_STAGE_SUNSET 2
#define MC_RENDER_STAGE_CUSTOM_SKY 3
#define MC_RENDER_STAGE_SUN 4
#define MC_RENDER_STAGE_MOON 5
#define MC_RENDER_STAGE_STARS 6
#define MC_RENDER_STAGE_VOID 7
#endif

#endif
