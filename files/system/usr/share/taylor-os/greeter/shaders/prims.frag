#version 440
layout(location = 0) in vec2 vP;
layout(location = 1) in vec4 vA;
layout(location = 2) in vec4 vB;
layout(location = 3) in vec4 vC;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float first;
    float count;
    float cols;
    float cells;
};
void main() {
    float hw = vB.x, al = vB.y, type = vB.z, d;
    if (type > 0.5 && type < 1.5) {
        // an arc with round ends: from vB.w, vC.w round (clockwise on the screen, as her canvas draws it)
        vec2 q = vP - vA.xy;
        float r = vA.z, ln = length(q);
        float a = atan(q.y, q.x) - vB.w;
        a = a - 6.2831853 * floor(a / 6.2831853);
        if (a <= vC.w || vC.w >= 6.2831) d = abs(ln - r);
        else {
            vec2 e0 = vA.xy + r * vec2(cos(vB.w), sin(vB.w));
            vec2 e1 = vA.xy + r * vec2(cos(vB.w + vC.w), sin(vB.w + vC.w));
            d = min(length(vP - e0), length(vP - e1));
        }
    } else {
        vec2 pa = vP - vA.xy, ba = vA.zw - vA.xy;
        float bb = dot(ba, ba);
        float h = bb > 0.0 ? dot(pa, ba) / bb : 0.0;
        if (type > 1.5 && (h < 0.0 || h > 1.0)) discard;   // a flat-ended line (her waves)
        h = clamp(h, 0.0, 1.0);
        d = length(pa - ba * h);
    }
    float cov = clamp(hw + 0.5 - d, 0.0, 1.0) * min(1.0, hw * 2.0);
    if (cov <= 0.0) discard;
    float a = al * cov * qt_Opacity;
    fragColor = vec4(vC.rgb * a, a);
}
