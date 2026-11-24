#version 440
// The login sky (scene_engine.js drawLogin): her gradient #090B0E, #0E1716 at 0.7, #14261F, coming in with K.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float kk;
};
void main() {
    float f = qt_TexCoord0.y;
    vec3 c = f < 0.7 ? mix(vec3(9.0, 11.0, 14.0), vec3(14.0, 23.0, 22.0), f / 0.7)
                     : mix(vec3(14.0, 23.0, 22.0), vec3(20.0, 38.0, 31.0), (f - 0.7) / 0.3);
    fragColor = vec4(c / 255.0, 1.0) * kk * qt_Opacity;
}
