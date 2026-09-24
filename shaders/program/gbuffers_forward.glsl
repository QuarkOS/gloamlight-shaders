// Forward-shaded geometry that is drawn outside the deferred path (particles, hand,
// weather, beams, vanilla clouds). Output goes to the translucent layer (colortex4).
// Variants: G_BASIC, G_TEXTURED, G_HAND, G_WEATHER, G_EMISSIVE, G_CLOUDS.

#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
#include "/lib/dimension.glsl"

#ifdef VSH
out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 normalView;
out vec3 viewPos;
flat out vec3 lightCol;
flat out vec3 ambCol;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;
    normalView = normalize(gl_NormalMatrix * gl_Normal);
    viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    getDimensionLight(lightCol, ambCol);
    gl_Position = ftransform();
}
#endif

#ifdef FSH
#ifndef DIM_NETHER
#include "/lib/shadows.glsl"
#endif
#include "/lib/lighting.glsl"

uniform sampler2D gtexture;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normalView;
in vec3 viewPos;
flat in vec3 lightCol;
flat in vec3 ambCol;

/* RENDERTARGETS: 4 */
layout(location = 0) out vec4 outColor;

void main() {
    #if defined G_CLOUDS && !defined VANILLA_CLOUDS
    discard;
    #endif

    #ifdef G_BASIC
    vec4 albedo = glcolor;
    #else
    vec4 albedo = texture(gtexture, texcoord) * glcolor;
    #endif

    #ifdef G_WEATHER
    if (albedo.a < 0.01) discard;
    #else
    if (albedo.a < 0.1) discard;
    #endif

    vec3 linAlbedo = toLinear(albedo.rgb);
    vec2 lm = normalizeLightmap(lmcoord);
    vec3 color;

    #if defined G_EMISSIVE
    color = linAlbedo * 4.0 * EMISSIVE_BRIGHTNESS;
    #elif defined G_WEATHER
    color = linAlbedo * (ambCol * 0.5 + lightCol * 0.15) * (lm.y * 0.8 + 0.2);
    albedo.a *= 0.45;
    #elif defined G_CLOUDS
    color = linAlbedo * (ambCol * 0.45 + lightCol * 0.55);
    #else
    SurfaceData s;
    s.albedo = linAlbedo;
    s.playerPos = viewToPlayer(viewPos);
    #ifdef G_HAND
    vec3 n = normalize(normalView);
    s.normal = mat3(gbufferModelViewInverse) * n;
    s.material = MAT_DEFAULT;
    #else
    // Particles face the camera, so shade them like foliage (soft wrap, some translucency).
    s.normal = vec3(0.0, 1.0, 0.0);
    s.material = MAT_PLANT;
    #endif
    s.lightmap = lm;
    s.ao = 1.0;
    s.emission = 0.0;
    color = shadeSurface(s, lightDirWorld(), lightCol, ambCol, interleavedGradientNoise(gl_FragCoord.xy));
    #endif

    outColor = vec4(color, albedo.a);
}
#endif
