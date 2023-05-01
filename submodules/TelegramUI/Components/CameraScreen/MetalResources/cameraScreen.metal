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

float map(float2 uv, float4 primaryParameters, float2 secondaryParameters) {
    float primary = sdfRoundedRectangle(uv, float2(primaryParameters.y, 0.0), primaryParameters.x, primaryParameters.w);
    float secondary = sdfCircle(uv, float2(secondaryParameters.y, 0.0), secondaryParameters.x);
    float metaballs = 1.0;
    metaballs = smin(metaballs, primary, BindingDistance);
    metaballs = smin(metaballs, secondary, BindingDistance);
    return metaballs;
}

fragment half4 cameraBlobFragment(RasterizerData in[[stage_in]],
                              constant uint2 &resolution[[buffer(0)]],
                              constant float4 &primaryParameters[[buffer(1)]],
                              constant float2 &secondaryParameters[[buffer(2)]])
{
    float2 R = float2(resolution.x, resolution.y);
    float2 uv = (2.0 * in.position.xy - R.xy) / R.y;
    
    float t = AARadius / resolution.y;
    
    float cAlpha = 1.0 - primaryParameters.z;
    float bound = primaryParameters.x + 0.05;
    if (abs(uv.x) > bound) {
        cAlpha = mix(0.0, 1.0, min(1.0, (abs(uv.x) - bound) * 2.4));
        
    }

    float c = smoothstep(t, -t, map(uv, primaryParameters, secondaryParameters));
    
    return half4(c, max(cAlpha, 0.231), max(cAlpha, 0.188), c);
}
