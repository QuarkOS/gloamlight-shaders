// Translucent terrain. Water only writes its surface normal/mask (shaded in composite);
// glass, ice, slime etc. are forward shaded into the translucent layer.

#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
#include "/lib/dimension.glsl"

#ifdef VSH
in vec4 mc_Entity;

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 normalView;
out vec3 playerPos;
flat out int blockId;
flat out vec3 lightCol;
flat out vec3 ambCol;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;
    normalView = normalize(gl_NormalMatrix * gl_Normal);
    blockId = int(mc_Entity.x + 0.5);
    getDimensionLight(lightCol, ambCol);

    vec3 viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    playerPos = viewToPlayer(viewPos);

    #ifdef WATER_WAVES
    if (blockId == ID_WATER && gl_Normal.y > 0.5) {
        vec3 wp = playerPos + cameraPosition;
        float t = frameTimeCounter * WATER_WAVE_SPEED;
        playerPos.y += (sin(wp.x * 0.9 + t * 1.3) * sin(wp.z * 0.7 + t * 1.1)) * 0.035 * WATER_WAVE_HEIGHT - 0.035;
    }
    #endif

    gl_Position = gl_ProjectionMatrix * (gbufferModelView * vec4(playerPos, 1.0));
}
#endif

#ifdef FSH
#ifndef DIM_NETHER
#include "/lib/shadows.glsl"
#endif
#include "/lib/lighting.glsl"
#include "/lib/waves.glsl"

uniform sampler2D gtexture;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normalView;
in vec3 playerPos;
flat in int blockId;
flat in vec3 lightCol;
flat in vec3 ambCol;

/* RENDERTARGETS: 4,3 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outWater;

void main() {
    vec2 lm = normalizeLightmap(lmcoord);
    vec3 nView = normalize(normalView);
    if (!gl_FrontFacing) nView = -nView;

    if (blockId == ID_WATER) {
        vec3 nWorld = mat3(gbufferModelViewInverse) * nView;
        #ifdef WATER_WAVES
        if (abs(nWorld.y) > 0.5) {
            vec3 wn = waterNormal((playerPos + cameraPosition).xz, length(playerPos));
            nWorld = nWorld.y > 0.0 ? wn : vec3(wn.x, -wn.y, wn.z);
        }
        #endif
        nView = normalize(mat3(gbufferModelView) * nWorld);
        outColor = vec4(0.0);
        outWater = vec4(encodeNormal(nView), lm.y, 1.0);
        return;
    }

    vec4 albedo = texture(gtexture, texcoord) * glcolor;
    if (albedo.a < 0.02) discard;

    SurfaceData s;
    s.albedo = toLinear(albedo.rgb);
    s.normal = mat3(gbufferModelViewInverse) * nView;
    s.playerPos = playerPos;
    s.lightmap = lm;
    s.material = MAT_DEFAULT;
    s.ao = 1.0;
    s.emission = blockId == ID_PORTAL ? 0.6 : 0.0;
    vec3 color = shadeSurface(s, lightDirWorld(), lightCol, ambCol, interleavedGradientNoise(gl_FragCoord.xy));

    // Glass-like surfaces pick up a faint sky reflection toward grazing angles.
    vec3 V = normalize(-playerPos);
    float F = fresnelSchlick(saturate(dot(s.normal, V)), 0.04);
    float alpha = mix(albedo.a, 1.0, F * 0.6);
    #ifdef DIM_OVERWORLD
    color += ambCol / PI * lm.y * lm.y * F * 0.8 / max(alpha, 0.05);
    #endif

    outColor = vec4(color, alpha);
    outWater = vec4(encodeNormal(nView), lm.y, 0.5);
}
#endif
