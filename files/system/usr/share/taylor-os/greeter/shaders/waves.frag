#version 440
// Her nine faint waves (scene_engine.js waves()), drawn per pixel: the same sums of sines, the same colours.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float al;      // how much of the waves is left (1 in the opening, 1 - K on the login)
    float vt;      // her clock for what sways (0 with less motion)
    float sc;      // S, her size factor
    vec2 size;
};
void main() {
    vec2 p = qt_TexCoord0 * size;
    float lw = max(1.0, sc * 0.8), un = p.x / sc;
    vec4 o = vec4(0.0);
    for (int j = 0; j < 9; j++) {
        float fj = float(j);
        float base = size.y * (0.1 + fj * 0.105), amp = (5.0 + fj * 1.1) * sc, sp = 0.3 + fj * 0.04;
        float a1 = un * 0.009 + vt * sp + fj * 1.7, a2 = un * 0.023 - vt * sp * 0.7 + fj * 0.9;
        float y = base + sin(a1) * amp + sin(a2) * amp * 0.45;
        float dy = (cos(a1) * amp * 0.009 + cos(a2) * amp * 0.45 * 0.023) / sc;
        float d = abs(p.y - y) / sqrt(1.0 + dy * dy);
        float cov = clamp(lw * 0.5 + 0.5 - d, 0.0, 1.0);
        float a = cov * (0.035 + fj * 0.006) * al;
        o = vec4(vec3(165.0, 172.0, 168.0) / 255.0 * a, a) + o * (1.0 - a);
    }
    fragColor = o * qt_Opacity;
}
