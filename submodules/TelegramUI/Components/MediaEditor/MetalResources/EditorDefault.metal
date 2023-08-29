#include <metal_stdlib>
#include "EditorCommon.h"

using namespace metal;

typedef struct {
    float4 pos;
    float2 texCoord;
    float2 localPos;
} VertexData;

vertex RasterizerData defaultVertexShader(uint vertexID [[vertex_id]],
                                          constant VertexData *vertices [[buffer(0)]]) {
    RasterizerData out;
    
    out.pos = vector_float4(0.0, 0.0, 0.0, 1.0);
    out.pos.xy = vertices[vertexID].pos.xy;
    out.localPos = vertices[vertexID].localPos.xy;
    
    out.texCoord = vertices[vertexID].texCoord;
    
    return out;
}

fragment half4 defaultFragmentShader(RasterizerData in [[stage_in]],
                                      texture2d<half, access::sample> texture [[texture(0)]]) {
    constexpr sampler samplr(filter::linear, mag_filter::linear, min_filter::linear);
    half3 color = texture.sample(samplr, in.texCoord).rgb;
    return half4(color, 1.0);
}

fragment half histogramPrepareFragmentShader(RasterizerData in [[stage_in]],
                                              texture2d<half, access::sample> texture [[texture(0)]]) {
    constexpr sampler samplr(filter::linear, mag_filter::linear, min_filter::linear);
    
    half3 color = texture.sample(samplr, in.texCoord).rgb;
    half luma = color.r * 0.3 + color.g * 0.59 + color.b * 0.11;
    return luma;
}
