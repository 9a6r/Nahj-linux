// A band of light that sweeps across the glass silhouette it is given (the Equalizer's wave), left to right, every few seconds.
// The group holds a copy of the glass's shape in a light colour; this keeps only a soft diagonal band of it, brightest in the middle of the crossing.
//
// s.a.x  how far across it is: 0 not started, 1 gone
// s.a.y  how bright the band is (0 to 1)

fn shade(s: Shader) -> vec4<f32> {
    let c = inside(s, s.pos);
    let t = s.a.x;
    // The position along the sweep, a little slanted: the band leans like light on a pane.
    let w = (s.pos.x + s.pos.y * 0.35) / (s.size.x + s.size.y * 0.35);
    let band = exp(-pow((w - (t * 1.5 - 0.25)) / 0.09, 2.0)) * sin(clamp(t, 0.0, 1.0) * 3.14159);
    let a = c.a * clamp(band * s.a.y, 0.0, 1.0);
    return vec4<f32>(mix(c.rgb, vec3<f32>(1.0, 1.0, 1.0), 0.55), a);
}
