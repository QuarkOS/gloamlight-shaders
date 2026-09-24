#ifndef SETTINGS_GLSL
#define SETTINGS_GLSL

// ---------------------------------------------------------------------------
// Iris/OptiFine engine constants (parsed by the loader, also usable in code)
// ---------------------------------------------------------------------------
const int shadowMapResolution = 2048; // [1024 1536 2048 3072 4096]
const float shadowDistance = 128.0; // [64.0 96.0 128.0 160.0 192.0 256.0]
const float shadowDistanceRenderMul = 1.0;
const float shadowIntervalSize = 2.0;
const bool shadowHardwareFiltering0 = true;
const bool shadowtex1Nearest = true;
const float sunPathRotation = -30.0; // [-45.0 -40.0 -35.0 -30.0 -25.0 -20.0 -15.0 -10.0 -5.0 0.0 5.0 10.0 15.0 20.0 25.0 30.0 35.0 40.0 45.0]
const float ambientOcclusionLevel = 1.0; // [0.0 0.25 0.5 0.75 1.0]
const float wetnessHalflife = 300.0;
const float drynessHalflife = 60.0;
const float eyeBrightnessHalflife = 8.0;
const int noiseTextureResolution = 256;

// ---------------------------------------------------------------------------
// Shadows
// ---------------------------------------------------------------------------
#define SHADOW_SAMPLES 12 // [4 8 12 16 24 32]
#define SHADOW_SOFTNESS 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0 3.0 4.0]
#define PCSS
#define COLORED_SHADOWS
#define SHADOW_DISTORTION 0.85 // [0.7 0.75 0.8 0.85 0.9 0.95]

// ---------------------------------------------------------------------------
// Lighting
// ---------------------------------------------------------------------------
#define SUN_BRIGHTNESS 1.0 // [0.5 0.75 1.0 1.25 1.5 2.0]
#define MOON_BRIGHTNESS 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0 3.0]
#define AMBIENT_BRIGHTNESS 1.0 // [0.5 0.75 1.0 1.25 1.5 2.0]
#define BLOCKLIGHT_BRIGHTNESS 1.0 // [0.5 0.75 1.0 1.25 1.5 2.0 3.0]
#define BLOCKLIGHT_WARMTH 0.7 // [0.0 0.2 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define MIN_LIGHT 0.5 // [0.0 0.25 0.5 1.0 2.0 4.0]
#define EMISSIVE_BRIGHTNESS 1.0 // [0.0 0.5 1.0 1.5 2.0 3.0]
#define HANDHELD_LIGHT
#define FOLIAGE_SSS 1.0 // [0.0 0.25 0.5 0.75 1.0 1.5 2.0]
#define SSAO
#define SSAO_STRENGTH 1.0 // [0.25 0.5 0.75 1.0 1.25 1.5 2.0]
#define SSAO_SAMPLES 8 // [4 6 8 12 16]
#define RAIN_WETNESS
#define PUDDLES

// ---------------------------------------------------------------------------
// Sky & atmosphere
// ---------------------------------------------------------------------------
#define SKY_STEPS 12 // [6 8 12 16 24]
#define SUN_SIZE 1.0 // [0.5 0.75 1.0 1.5 2.0 3.0]
#define STAR_BRIGHTNESS 1.0 // [0.0 0.5 1.0 1.5 2.0 3.0]
#define CLOUD_QUALITY 2 // [0 1 2 3]
#define CLOUD_COVERAGE 0.5 // [0.2 0.3 0.4 0.5 0.6 0.7 0.8]
#define CLOUD_ALTITUDE 280 // [192 220 250 280 320 360 420]
#define CLOUD_THICKNESS 140 // [60 100 140 180 240]
#define CLOUD_SPEED 1.0 // [0.0 0.25 0.5 1.0 2.0 4.0]
//#define VANILLA_CLOUDS

// ---------------------------------------------------------------------------
// Fog & volumetrics
// ---------------------------------------------------------------------------
#define VOLUMETRIC_LIGHT
#define VL_STEPS 12 // [4 6 8 12 16 24 32]
#define VL_STRENGTH 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0 3.0]
#define FOG_DENSITY 1.0 // [0.0 0.25 0.5 0.75 1.0 1.5 2.0 3.0]
#define MORNING_FOG 1.0 // [0.0 0.5 1.0 1.5 2.0 3.0]
#define RAIN_FOG 1.0 // [0.0 0.5 1.0 1.5 2.0 3.0]
#define BORDER_FOG
#define NETHER_FOG_DENSITY 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0]
#define END_FOG_DENSITY 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0]

// ---------------------------------------------------------------------------
// Water
// ---------------------------------------------------------------------------
#define WATER_WAVES
#define WATER_WAVE_HEIGHT 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0]
#define WATER_WAVE_SPEED 1.0 // [0.25 0.5 1.0 1.5 2.0]
#define WATER_REFRACTION 1.0 // [0.0 0.25 0.5 1.0 1.5 2.0]
#define WATER_SSR
#define SSR_STEPS 20 // [8 12 16 20 24 32 48]
#define WATER_CLARITY 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0 3.0]
#define UNDERWATER_FOG 1.0 // [0.5 0.75 1.0 1.5 2.0]

// ---------------------------------------------------------------------------
// Waving geometry
// ---------------------------------------------------------------------------
#define WAVING_PLANTS
#define WAVING_LEAVES
#define WAVE_AMPLITUDE 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0]
#define WAVE_SPEED 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0]

// ---------------------------------------------------------------------------
// Post processing
// ---------------------------------------------------------------------------
#define BLOOM
#define BLOOM_STRENGTH 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0 3.0]
#define AUTO_EXPOSURE
#define EXPOSURE 0.0 // [-2.0 -1.5 -1.0 -0.5 0.0 0.5 1.0 1.5 2.0]
#define TONEMAP 0 // [0 1 2]
#define WHITE_BALANCE 6500 // [4500 5000 5500 6000 6500 7000 7500 8000 9000]
#define SATURATION 1.05 // [0.6 0.7 0.8 0.9 1.0 1.05 1.1 1.2 1.3 1.5]
#define VIBRANCE 1.1 // [0.8 0.9 1.0 1.1 1.2 1.3 1.5]
#define CONTRAST 1.05 // [0.8 0.9 0.95 1.0 1.05 1.1 1.2 1.3]
#define SHADOW_TINT 1.0 // [0.0 0.5 1.0 1.5 2.0]
#define VIGNETTE
#define VIGNETTE_STRENGTH 0.35 // [0.1 0.2 0.25 0.35 0.45 0.6 0.8]

#endif
