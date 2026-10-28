#version 440
// The greeter's glass (GlassPane.qml): a rounded rectangle of glass over the picture. Its shape is worked out here (a rounded box's distance
// field), so no mask or height map is needed. Inside a band along the edge (`bevel`) the glass curves: the picture is bent outwards there, as a
// thick edge shows what lies just beyond it, red and blue a little apart; the middle is frosted (the blurred copy of the picture), the edge stays
// clearer. The edge that faces the light (top left) shines, with a thin bright line at the very rim, and the far edge sits in a touch of shade.
// Build: `qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o glass.frag.qsb glass.frag` (the .qsb is what the greeter loads).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 bgRect;        // the pane in the picture's texture coordinates (x, y, w, h)
    vec2 paneSize;      // the pane in pixels
    float radius;       // its corners, in pixels
    float bevel;        // how far in from the edge the glass curves, in pixels
    float refraction;   // how far the edge bends the picture, in pixels
    float dispersion;   // 0..1: how far red and blue part where it bends
    float frost;        // 0..1: how much of the blurred picture fills the middle
    float rimLight;     // the light on the edge
    vec4 tint;          // premultiplied colour over what is seen through it
};
layout(binding = 1) uniform sampler2D backdrop;
layout(binding = 2) uniform sampler2D frosted;

float box(vec2 p) {
    vec2 h = paneSize * 0.5;
    float r = min(radius, min(h.x, h.y));
    vec2 q = abs(p - h) - (h - vec2(r));
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 p = qt_TexCoord0 * paneSize;
    float d = box(p);                                        // < 0 inside
    float cover = clamp(0.5 - d, 0.0, 1.0);
    if (cover <= 0.0) { fragColor = vec4(0.0); return; }

    vec2 e = vec2(1.0, 0.0);
    vec2 n = vec2(box(p + e.xy) - box(p - e.xy), box(p + e.yx) - box(p - e.yx));
    float nl = length(n);
    n = nl > 1e-4 ? n / nl : vec2(0.0);                      // outwards
    float t = clamp(1.0 + d / max(bevel, 1.0), 0.0, 1.0);    // 1 at the rim, 0 past the bevel
    float bend = t * t;

    vec2 bg = bgRect.xy + qt_TexCoord0 * bgRect.zw;
    vec2 o = n * refraction * bend / paneSize * bgRect.zw;   // pixels of the pane to the picture's coordinates
    vec3 sharp = vec3(texture(backdrop, bg + o * (1.0 + dispersion)).r,
                      texture(backdrop, bg + o).g,
                      texture(backdrop, bg + o * (1.0 - dispersion)).b);
    vec3 soft = texture(frosted, bg + o).rgb;
    vec3 c = mix(sharp, soft, frost * (1.0 - 0.6 * bend));
    c = c * (1.0 - tint.a) + tint.rgb;

    float facing = dot(n, normalize(vec2(-0.6, -0.8)));
    c *= 1.0 - 0.16 * bend * max(-facing, 0.0);
    float line = clamp(1.5 + d, 0.0, 1.0);                   // the outermost pixel and a half
    c += rimLight * (max(facing, 0.0) * (0.35 * bend + 0.8 * line) + 0.18 * line);

    fragColor = vec4(c, 1.0) * cover * qt_Opacity;
}
