// Overlays blended onto the albedo buffer with vanilla blending (armor glint, block breaking).

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
    vec4 c = texture(gtexture, texcoord) * glcolor;
    if (c.a < 0.01) discard;
    outColor = c;
}
#endif
