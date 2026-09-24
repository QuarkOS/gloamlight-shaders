// Separable gaussian over the bloom atlas. BLUR_H: colortex5 -> colortex6, else colortex6 -> colortex5.

#include "/lib/common.glsl"
#include "/lib/buffers.glsl"
#include "/lib/bloom.glsl"

#ifdef VSH
out vec2 texcoord;

void main() {
    texcoord = gl_MultiTexCoord0.xy;
    gl_Position = ftransform();
}
#endif

#ifdef FSH
#ifdef BLUR_H
uniform sampler2D colortex5;
#define BLUR_SRC colortex5
/* RENDERTARGETS: 6 */
#else
uniform sampler2D colortex6;
#define BLUR_SRC colortex6
/* RENDERTARGETS: 5 */
#endif

in vec2 texcoord;

layout(location = 0) out vec4 outColor;

void main() {
    vec3 sum = vec3(0.0);
    #ifdef BLOOM
    if (inBloomRegion(texcoord)) {
        #ifdef BLUR_H
        vec2 dir = vec2(1.0 / viewWidth, 0.0);
        #else
        vec2 dir = vec2(0.0, 1.0 / viewHeight);
        #endif
        const float w[5] = float[5](0.2270270, 0.1945946, 0.1216216, 0.0540541, 0.0162162);
        sum = texture(BLUR_SRC, texcoord).rgb * w[0];
        for (int i = 1; i < 5; i++) {
            sum += texture(BLUR_SRC, texcoord + dir * float(i) * 1.5).rgb * w[i];
            sum += texture(BLUR_SRC, texcoord - dir * float(i) * 1.5).rgb * w[i];
        }
    }
    #endif
    outColor = vec4(sum, 1.0);
}
#endif
