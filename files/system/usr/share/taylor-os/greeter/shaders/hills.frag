#version 440
// Her two dark hills (scene_engine.js hills()): the same curves, the back one #0E1512, the front one #080B0A.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float kk;      // K: how far in the login sky is
    float k;       // screen height / 380
    vec2 size;
};
void main() {
    vec2 p = qt_TexCoord0 * size;
    float u = p.x / k;
    float y1 = (338.0 + sin(u * 0.008 + 1.2) * 14.0 + sin(u * 0.021) * 6.0) * k;
    float y2 = (356.0 + sin(u * 0.006 + 3.1) * 12.0 + sin(u * 0.017 + 0.6) * 5.0) * k;
    float c1 = clamp(p.y - y1 + 0.5, 0.0, 1.0) * kk, c2 = clamp(p.y - y2 + 0.5, 0.0, 1.0) * kk;
    vec4 o = vec4(vec3(14.0, 21.0, 18.0) / 255.0 * c1, c1);
    o = vec4(vec3(8.0, 11.0, 10.0) / 255.0 * c2, c2) + o * (1.0 - c2);
    fragColor = o * qt_Opacity;
}
