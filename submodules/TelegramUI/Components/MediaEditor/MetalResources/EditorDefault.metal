#include <metal_stdlib>
#include "EditorCommon.h"

using namespace metal;

typedef struct {
    float4 pos;
    float2 texCoord;
} VertexData;

vertex RasterizerData defaultVertexShader(uint vertexID [[vertex_id]],
                                          constant VertexData *vertices [[buffer(0)]]) {
    RasterizerData out;
    
    out.pos = vector_float4(0.0, 0.0, 0.0, 1.0);
    out.pos.xy = vertices[vertexID].pos.xy;
    
    out.texCoord = vertices[vertexID].texCoord;
    
    return out;
}

fragment half4 defaultFragmentShader(RasterizerData in [[stage_in]],
                                      constant float2 &texCoordScales [[buffer(0)]],
                                      texture2d<half, access::sample> texture [[texture(0)]]) {
    constexpr sampler samplr(filter::linear, mag_filter::linear, min_filter::linear);
    
    float scaleX = texCoordScales.x;
    float scaleY = texCoordScales.y;
    float x = (in.texCoord.x - (1.0 - scaleX) / 2.0) / scaleX;
    float y = (in.texCoord.y - (1.0 - scaleY) / 2.0) / scaleY;
    if (x < 0 || x > 1 || y < 0 || y > 1) {
        return half4(0.0, 0.0, 0.0, 1.0);
    }
    half3 color = texture.sample(samplr, float2(x, y)).rgb;
    return half4(color, 1.0);
}

fragment half histogramPrepareFragmentShader(RasterizerData in [[stage_in]],
                                              constant float2 &texCoordScales [[buffer(0)]],
                                              texture2d<half, access::sample> texture [[texture(0)]]) {
    constexpr sampler samplr(filter::linear, mag_filter::linear, min_filter::linear);
    
    float scaleX = texCoordScales.x;
    float scaleY = texCoordScales.y;
    float x = (in.texCoord.x - (1.0 - scaleX) / 2.0) / scaleX;
    float y = (in.texCoord.y - (1.0 - scaleY) / 2.0) / scaleY;
    if (x < 0 || x > 1 || y < 0 || y > 1) {
        return 0.0;
    }
    half3 color = texture.sample(samplr, float2(x, y)).rgb;
    half luma = color.r * 0.3 + color.g * 0.59 + color.b * 0.11;
    return luma;
}
