#include <metal_stdlib>
using namespace metal;

struct AmountQuad {
    float4 rect;
    float4 color;
    float4 uv;
    float2 viewport;
    float2 effect;
    float2 reveal;
};

struct AmountVertex {
    float4 position [[position]];
    float2 uv;
    float4 color;
    float threshold [[flat]];
    float localX;
    float2 reveal [[flat]];
};

vertex AmountVertex walletAmountVertex(uint index [[vertex_id]], uint instance [[instance_id]],
                                      constant AmountQuad *quads [[buffer(0)]]) {
    constant AmountQuad &quad = quads[instance];
    const float2 corners[] = {float2(0, 0), float2(1, 0), float2(0, 1), float2(1, 1)};
    float2 uv = corners[index];
    float2 point = quad.rect.xy + uv * quad.rect.zw;
    return {float4(point.x / quad.viewport.x * 2 - 1, 1 - point.y / quad.viewport.y * 2, 0, 1),
            quad.uv.xy + uv * quad.uv.zw, quad.color, quad.effect.x, point.x, quad.reveal};
}

vertex AmountVertex walletAmountLayerVertex(uint index [[vertex_id]], uint instance [[instance_id]],
                                           constant AmountQuad *quads [[buffer(0)]],
                                           constant float4 &placement [[buffer(1)]]) {
    constant AmountQuad &quad = quads[instance];
    const float2 corners[] = {float2(0, 0), float2(1, 0), float2(0, 1), float2(1, 1)};
    float2 uv = corners[index];
    float2 point = (quad.rect.xy + uv * quad.rect.zw) / quad.viewport;
    // MetalEngine's allocation is y-up; text and glyph UVs remain y-down.
    float2 surface = placement.xy + float2(point.x, 1 - point.y) * placement.zw;
    return {float4(surface * 2 - 1, 0, 1), quad.uv.xy + uv * quad.uv.zw, quad.color, quad.effect.x, point.x * quad.viewport.x, quad.reveal};
}

fragment float4 walletAmountFragment(AmountVertex in [[stage_in]],
                                    texture2d<float> mask [[texture(0)]]) {
    constexpr sampler sampleMask(coord::normalized, address::clamp_to_zero, filter::linear);
    float alpha = mask.sample(sampleMask, in.uv).r;
    if (in.threshold >= 0) {
        // The reference's alphaThreshold follows Gaussian blur. Smooth only
        // the pixel crossing the contour, keeping the interior fully opaque.
        float edge = max(fwidth(alpha) * 0.5, 1.0 / 1024.0);
        alpha = smoothstep(in.threshold - edge, in.threshold + edge, alpha);
    }
    if (in.reveal.y > in.reveal.x) {
        alpha *= saturate((in.localX - in.reveal.x) / (in.reveal.y - in.reveal.x));
    }
    alpha *= in.color.a;
    return float4(in.color.rgb * alpha, alpha);
}

struct AmountBlur {
    uint radius;
    uint horizontal;
};

kernel void walletAmountBlur(texture2d<float, access::read> source [[texture(0)]],
                             texture2d<float, access::write> target [[texture(1)]],
                             constant AmountBlur &blur [[buffer(0)]],
                             constant float *weights [[buffer(1)]],
                             uint2 pixel [[thread_position_in_grid]]) {
    if (pixel.x >= target.get_width() || pixel.y >= target.get_height()) { return; }
    int radius = int(blur.radius);
    float value = 0;
    for (int offset = -radius; offset <= radius; offset++) {
        float weight = weights[offset + radius];
        int2 at = int2(pixel) + (blur.horizontal ? int2(offset, 0) : int2(0, offset));
        if (at.x >= 0 && at.y >= 0 && at.x < int(source.get_width()) && at.y < int(source.get_height())) {
            value += source.read(uint2(at)).r * weight;
        }
    }
    target.write(float4(value), pixel);
}
