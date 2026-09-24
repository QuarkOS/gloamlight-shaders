// Opaque geometry: writes albedo, normal + lightmap and material for the deferred pass.
// Variants: G_TERRAIN, G_BLOCK, G_ENTITIES.

#include "/lib/common.glsl"

#ifdef VSH
#include "/lib/waving.glsl"

#ifdef G_TERRAIN
in vec4 mc_Entity;
in vec2 mc_midTexCoord;
#endif

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 normalView;
flat out int blockId;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;
    normalView = normalize(gl_NormalMatrix * gl_Normal);

    #ifdef G_TERRAIN
    blockId = int(mc_Entity.x + 0.5);
    vec3 viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    vec3 playerPos = viewToPlayer(viewPos);
    bool isTop = texcoord.y < mc_midTexCoord.y;
    playerPos += wavingOffset(playerPos + cameraPosition, blockId, isTop);
    gl_Position = gl_ProjectionMatrix * (gbufferModelView * vec4(playerPos, 1.0));
    #else
    blockId = 0;
    gl_Position = ftransform();
    #endif
}
#endif

#ifdef FSH
uniform sampler2D gtexture;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normalView;
flat in int blockId;

/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 outAlbedo;
layout(location = 1) out vec4 outData;
layout(location = 2) out vec4 outMaterial;

void main() {
    vec4 tex = texture(gtexture, texcoord);
    vec4 albedo = tex * glcolor;
    #ifdef G_ENTITIES
    albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);
    #endif
    if (albedo.a < 0.1) discard;

    vec3 n = normalize(normalView);
    if (!gl_FrontFacing) n = -n;

    float material = MAT_DEFAULT;
    float emission = 0.0;
    #ifdef G_TERRAIN
    if (blockId == ID_PLANT || blockId == ID_PLANT_TOP) material = MAT_PLANT;
    else if (blockId == ID_LEAVES || blockId == ID_HANGING) material = MAT_LEAVES;
    else if (blockId == ID_EMISSIVE) {
        material = MAT_EMISSIVE;
        float peak = max(tex.r, max(tex.g, tex.b));
        emission = smoothstep(0.5, 0.9, peak) * (0.4 + 0.6 * peak);
    } else if (blockId == ID_LAVA) {
        material = MAT_LAVA;
        emission = 1.0;
    }
    #elif defined G_ENTITIES
    material = MAT_ENTITY;
    #endif

    outAlbedo = vec4(albedo.rgb, 1.0);
    outData = vec4(encodeNormal(n), lmcoord);
    outMaterial = vec4(material / 16.0, emission, 0.0, 1.0);
}
#endif
