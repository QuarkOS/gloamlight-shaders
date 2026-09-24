// Vanilla sky geometry. The sky itself is rendered procedurally in deferred; only stars
// and the moon are kept (written into colortex0, which is empty for sky pixels).
// Variants: G_SKYBASIC, G_SKYTEXTURED.

#include "/lib/common.glsl"

#ifdef VSH
out vec2 texcoord;
out vec4 glcolor;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;
    gl_Position = ftransform();
}
#endif

#ifdef FSH
uniform sampler2D gtexture;

in vec2 texcoord;
in vec4 glcolor;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {
    #if !defined DIM_OVERWORLD
    discard;
    #endif

    #ifdef G_SKYBASIC
    if (renderStage != MC_RENDER_STAGE_STARS) discard;
    outColor = vec4(glcolor.rgb * 0.5 * STAR_BRIGHTNESS, glcolor.a);
    #else
    if (renderStage != MC_RENDER_STAGE_MOON) discard;
    vec4 tex = texture(gtexture, texcoord) * glcolor;
    outColor = vec4(tex.rgb, tex.a);
    #endif
}
#endif
