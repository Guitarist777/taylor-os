#version 440
// TAYLOR OS login scene: her dots, lines and arcs drawn by the graphics card. Each shape is 6 texels of the data
// texture (gpu_draw.js writes them); each shape gets 4 columns of the GridMesh, so its quad stands alone (the
// cells between shapes have no area).
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 vP;
layout(location = 1) out vec4 vA;   // capsule: x0 y0 x1 y1 | arc: cx cy r -
layout(location = 2) out vec4 vB;   // half width, alpha, type, arc start
layout(location = 3) out vec4 vC;   // r g b, arc sweep
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float first;      // the first shape this layer draws
    float count;      // how many
    float cols;       // the data texture's width in texels
    float cells;      // the GridMesh's width in cells (4 x the most shapes, less one)
};
layout(binding = 1) uniform sampler2D prims;
vec3 tx(int i, int j) { int n = i * 6 + j; return texelFetch(prims, ivec2(n % int(cols), n / int(cols)), 0).rgb * 255.0; }
float w16(float hi, float lo) { return floor(hi + 0.5) * 256.0 + floor(lo + 0.5); }
void main() {
    int c = int(floor(qt_MultiTexCoord0.x * cells + 0.5));
    int row = int(floor(qt_MultiTexCoord0.y + 0.5));
    int j = c / 4, sub = c - j * 4;
    vec2 pos = vec2(-64.0, -64.0);
    vA = vec4(0.0); vB = vec4(0.0); vC = vec4(0.0);
    if (float(j) < count) {
        int i = j + int(first);
        vec3 t0 = tx(i, 0), t1 = tx(i, 1), t2 = tx(i, 2), t3 = tx(i, 3), t4 = tx(i, 4), t5 = tx(i, 5);
        float type = floor(t0.b + 0.5);
        float x0 = w16(t0.r, t0.g) / 8.0 - 2048.0, y0 = w16(t1.r, t1.g) / 8.0 - 2048.0;
        float x1 = w16(t2.r, t2.g) / 8.0 - 2048.0, y1 = w16(t3.r, t3.g) / 8.0 - 2048.0;
        float hw = t2.b / 4.0;
        float start = w16(t5.r, t5.g) / 65535.0 * 6.2831853, sweep = w16(t5.b, t3.b) / 65535.0 * 6.2831853;
        vec2 lo, hi;
        if (type > 0.5 && type < 1.5) {          // an arc: x1 is its radius (no offset)
            float r = w16(t2.r, t2.g) / 8.0;
            x1 = r; y1 = 0.0;
            lo = vec2(x0, y0) - vec2(r + hw + 1.5); hi = vec2(x0, y0) + vec2(r + hw + 1.5);
        } else {
            lo = min(vec2(x0, y0), vec2(x1, y1)) - vec2(hw + 1.5); hi = max(vec2(x0, y0), vec2(x1, y1)) + vec2(hw + 1.5);
        }
        if (sub == 0) pos = lo;
        else if (sub == 1) pos = vec2(lo.x, row == 0 ? lo.y : hi.y);
        else if (sub == 2) pos = vec2(hi.x, row == 0 ? lo.y : hi.y);
        else pos = vec2(hi.x, lo.y);
        vA = vec4(x0, y0, x1, y1);
        vB = vec4(hw, t1.b / 255.0, type, start);
        vC = vec4(t4 / 255.0, sweep);
    }
    vP = pos;
    gl_Position = qt_Matrix * vec4(pos, 0.0, 1.0);
}
