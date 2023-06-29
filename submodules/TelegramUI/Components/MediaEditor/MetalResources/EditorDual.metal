#include <metal_stdlib>
#include "EditorCommon.h"

using namespace metal;

typedef struct {
    float4 pos;
    float2 texCoord;
    float4 localPos;
} VertexData;


float sdfRoundedRectangle(float2 uv, float2 position, float2 size, float radius) {
    float2 q = abs(uv - position) - size + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

fragment half4 dualFragmentShader(RasterizerData in [[stage_in]],
                                    texture2d<half, access::sample> texture [[texture(0)]],
                                    constant uint2 &resolution[[buffer(0)]],
                                    constant float &roundness[[buffer(1)]],
                                    constant float &alpha[[buffer(2)]]
                                ) {
    float2 R = float2(resolution.x, resolution.y);
    
    float2 uv = (in.localPos - float2(0.5, 0.5)) * 2.0;
    if (R.x > R.y) {
        uv.y = uv.y * R.y / R.x;
    } else {
        uv.x = uv.x * R.x / R.y;
    }
    float aspectRatio = R.x / R.y;
    
    constexpr sampler samplr(filter::linear, mag_filter::linear, min_filter::linear);
    half3 color = texture.sample(samplr, in.texCoord).rgb;
    
    float t = 1.0 / resolution.y;
    float side = 1.0 * aspectRatio;
    float distance = smoothstep(t, -t, sdfRoundedRectangle(uv, float2(0.0, 0.0), float2(side, mix(1.0, side, roundness)), side * roundness));
    
    return mix(half4(color, 0.0), half4(color, 1.0 * alpha), distance);
}
