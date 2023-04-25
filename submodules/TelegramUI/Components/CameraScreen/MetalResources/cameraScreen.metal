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

#define BINDING_DIST .15
#define AA_RADIUS 2.

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (a - b) / k, 0.0, 1.0);
    return mix(a, b, h) - k * h * (1.0 - h);
}

float sdist_disk(float2 uv, float2 position, float radius) {
    return length(uv - position) - radius;
}

float sdist_rect(float2 uv, float2 position, float size, float radius){
    float2 q = abs(uv - position) - size + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

float map(float2 uv, float2 diskPos, float2 rectPos) {
    float disk = sdist_disk(uv, diskPos, 0.2);
    float rect = sdist_rect(uv, rectPos, 0.15, 0.15);
    float metaballs = 1.0;
    metaballs = smin(metaballs, disk, BINDING_DIST);
    metaballs = smin(metaballs, rect, BINDING_DIST);
    return metaballs;
}

float mod(float x, float y) {
    return x - y * floor(x / y);
}

fragment half4 cameraBlobFragment(RasterizerData in[[stage_in]],
                              constant uint2 &resolution[[buffer(0)]],
                              constant float &time[[buffer(1)]])
{
    float finalTime = mod(time * 1.5, 3.0);
    
    float2 R = float2(resolution.x, resolution.y);
    float2 uv = (2.0 * in.position.xy - R.xy) / R.y;
    
    float t = AA_RADIUS / resolution.y;
    
    float2 diskPos = float2(0.1, 0.4);
    float2 rectPos = float2(0.2 - 0.3 * finalTime, 0.4);
    
    float cAlpha = 0.0;
    if (finalTime > 1.5) {
        cAlpha = min(1.0, (finalTime - 1.5) * 1.75);
    }
    
    float c = smoothstep(t, -t, map(uv, diskPos, rectPos));
    return half4(c, cAlpha * c, cAlpha * c, c);
}
