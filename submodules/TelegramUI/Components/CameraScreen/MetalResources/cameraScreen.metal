#include <metal_stdlib>
using namespace metal;

typedef struct {
    packed_float2 position;
} Vertex;

struct RasterizerData
{
    float4 position [[position]];
};

vertex RasterizerData cameraBlobVertex
(
    constant Vertex *vertexArray[[buffer(0)]],
    uint vertexID [[ vertex_id ]]
) {
    RasterizerData out;
    out.position = vector_float4(vertexArray[vertexID].position[0], vertexArray[vertexID].position[1], 0.0, 1.0);
    return out;
}

#define BindingDistance 0.25
#define AARadius 2.0

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (a - b) / k, 0.0, 1.0);
    return mix(a, b, h) - k * h * (1.0 - h);
}

float sdfRoundedRectangle(float2 uv, float2 position, float size, float radius) {
    float2 q = abs(uv - position) - size + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

float sdfCircle(float2 uv, float2 position, float radius) {
    return length(uv - position) - radius;
}

float map(float2 uv, float3 primaryParameters, float2 primaryOffset, float3 secondaryParameters, float2 secondaryOffset) {
    float primary = sdfRoundedRectangle(uv, primaryOffset, primaryParameters.x, primaryParameters.z);
    float secondary = sdfCircle(uv, secondaryOffset, secondaryParameters.x);
    float metaballs = 1.0;
    metaballs = smin(metaballs, primary, BindingDistance);
    metaballs = smin(metaballs, secondary, BindingDistance);
    return metaballs;
}

fragment half4 cameraBlobFragment(RasterizerData in[[stage_in]],
                              constant uint2 &resolution[[buffer(0)]],
                              constant float3 &primaryParameters[[buffer(1)]],
                              constant float2 &primaryOffset[[buffer(2)]],
                              constant float3 &secondaryParameters[[buffer(3)]],
                              constant float2 &secondaryOffset[[buffer(4)]])
{
    float2 R = float2(resolution.x, resolution.y);
    
    float2 uv;
    float offset;
    if (R.x > R.y) {
        uv = (2.0 * in.position.xy - R.xy) / R.y;
        offset = uv.x;
    } else {
        uv = (2.0 * in.position.xy - R.xy) / R.x;
        offset = uv.y;
    }
    
    float t = AARadius / resolution.y;
    
    float cAlpha = 1.0 - primaryParameters.y;
    float bound = primaryParameters.x + 0.05;
    if (abs(offset) > bound) {
        cAlpha = mix(0.0, 1.0, min(1.0, (abs(offset) - bound) * 2.4));
    }

    float c = smoothstep(t, -t, map(uv, primaryParameters, primaryOffset, secondaryParameters, secondaryOffset));
    
    return half4(c, max(cAlpha, 0.231), max(cAlpha, 0.188), c);
}
