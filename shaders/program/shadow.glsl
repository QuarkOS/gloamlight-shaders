// Shadow map pass with distortion; translucent casters write their tint to shadowcolor0.

#include "/lib/common.glsl"

#ifdef VSH
#include "/lib/shadows_distort.glsl"
#include "/lib/waving.glsl"

in vec4 mc_Entity;
in vec2 mc_midTexCoord;

out vec2 texcoord;
out vec4 glcolor;
flat out int blockId;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;
    blockId = int(mc_Entity.x + 0.5);

    #ifdef DIM_NETHER
    gl_Position = vec4(-10.0, -10.0, -10.0, 1.0);
    return;
    #endif

    vec3 shadowView = (gl_ModelViewMatrix * gl_Vertex).xyz;
    vec3 playerPos = mat3(shadowModelViewInverse) * shadowView + shadowModelViewInverse[3].xyz;
    bool isTop = texcoord.y < mc_midTexCoord.y;
    playerPos += wavingOffset(playerPos + cameraPosition, blockId, isTop);

    vec4 clip = gl_ProjectionMatrix * (shadowModelView * vec4(playerPos, 1.0));
    clip.xyz = distortShadowClipVertex(clip.xyz);
    gl_Position = clip;
}
#endif

#ifdef FSH
uniform sampler2D gtexture;

in vec2 texcoord;
in vec4 glcolor;
flat in int blockId;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {
    if (blockId == ID_WATER) discard;
    vec4 c = texture(gtexture, texcoord) * glcolor;
    if (c.a < 0.1) discard;
    // Weakly tinted glass lets more light through.
    outColor = vec4(mix(vec3(1.0), c.rgb, saturate(c.a * 1.4)), c.a);
}
#endif
