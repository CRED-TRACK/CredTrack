#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
};

struct Uniforms {
    float2 resolution;
    float time;
    float xScale;
    float yScale;
    float distortion;
};

// Full-screen triangle — no vertex buffer needed, generated from vertex_id
vertex VertexOut waveVertex(uint vid [[vertex_id]]) {
    float2 positions[3] = {
        float2(-1.0, -3.0),
        float2(-1.0,  1.0),
        float2( 3.0,  1.0)
    };
    VertexOut out;
    out.position = float4(positions[vid], 0.0, 1.0);
    return out;
}

// Port of the original GLSL fragment shader.
// Renders a glowing sine wave line with RGB chromatic aberration.
fragment float4 waveFragment(VertexOut in [[stage_in]],
                              constant Uniforms &u [[buffer(0)]]) {
    // Flip Y: Metal origin is top-left, GLSL is bottom-left
    float2 fragCoord = float2(in.position.x, u.resolution.y - in.position.y);

    // Normalise to [-1, 1] with aspect correction
    float2 p = (fragCoord * 2.0 - u.resolution) / min(u.resolution.x, u.resolution.y);

    // Chromatic aberration — each channel gets a slightly different x
    float d  = length(p) * u.distortion;
    float rx = p.x * (1.0 + d);
    float gx = p.x;
    float bx = p.x * (1.0 - d);

    // Inverse-distance glow on a sine curve per channel
    float r = 0.05 / abs(p.y + sin((rx + u.time) * u.xScale) * u.yScale);
    float g = 0.05 / abs(p.y + sin((gx + u.time) * u.xScale) * u.yScale);
    float b = 0.05 / abs(p.y + sin((bx + u.time) * u.xScale) * u.yScale);

    return float4(r, g, b, 1.0);
}
