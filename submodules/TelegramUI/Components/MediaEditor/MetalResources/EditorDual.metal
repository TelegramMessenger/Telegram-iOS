#include <metal_stdlib>
#include "EditorCommon.h"
#include "EditorUtils.h"

using namespace metal;

typedef struct {
    float2      dimensions;
    float       roundness;
    float       alpha;
    float       isOpaque;
    float       empty;
} VideoEncodeParameters;

typedef struct {
    float4 pos;
    float2 texCoord;
    float4 localPos;
} VertexData;


fragment half4 dualFragmentShader(RasterizerData in [[stage_in]],
                                    texture2d<half, access::sample> texture [[texture(0)]],
                                    texture2d<half, access::sample> mask [[texture(1)]],
                                    constant VideoEncodeParameters& adjustments [[buffer(0)]]
                                ) {
    float2 R = float2(adjustments.dimensions.x, adjustments.dimensions.y);
    
    float2 uv = (in.localPos - float2(0.5, 0.5)) * 2.0;
    if (R.x > R.y) {
        uv.y = uv.y * R.y / R.x;
    } else {
        uv.x = uv.x * R.x / R.y;
    }
    float aspectRatio = R.x / R.y;
    
    constexpr sampler samplr(filter::linear, mag_filter::linear, min_filter::linear);
    half4 color = texture.sample(samplr, in.texCoord);
    float colorAlpha = min(1.0, adjustments.isOpaque * color.a + mask.sample(samplr, in.texCoord).r);
    
    float t = 1.0 / adjustments.dimensions.y;
    float side = 1.0 * aspectRatio;
    float distance = smoothstep(t, -t, sdfRoundedRectangle(uv, float2(0.0, 0.0), float2(side, mix(1.0, side, adjustments.roundness)), side * adjustments.roundness));
    
    return mix(half4(color.rgb, 0.0), half4(color.rgb, colorAlpha * adjustments.alpha), distance);
}
