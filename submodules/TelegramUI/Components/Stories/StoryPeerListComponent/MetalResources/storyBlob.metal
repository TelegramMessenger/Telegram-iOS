#include <metal_stdlib>
using namespace metal;

struct QuadVertexOut {
    float4 position [[position]];
    float2 uv;
};

constant static float2 quadVertices[6] = {
    float2(0.0, 0.0),
    float2(1.0, 0.0),
    float2(0.0, 1.0),
    float2(1.0, 0.0),
    float2(0.0, 1.0),
    float2(1.0, 1.0)
};

vertex QuadVertexOut cameraBlobVertex(
    constant float4 &rect [[ buffer(0) ]],
    uint vid [[ vertex_id ]]
) {
    float2 quadVertex = quadVertices[vid];
    
    QuadVertexOut out;
    out.position = float4(rect.x + quadVertex.x * rect.z, rect.y + quadVertex.y * rect.w, 0.0, 1.0);
    out.position.x = -1.0 + out.position.x * 2.0;
    out.position.y = -1.0 + out.position.y * 2.0;
    
    out.uv = quadVertex;

    return out;
}

#define BindingDistance 0.45
#define AARadius 2.0
#define PersistenceFactor 1.1

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (a - b) / k, 0.0, 1.0);
    h = pow(h, 0.6);
    return mix(a, b, h) - k * h * (1.0 - h) * 1.0;
}

float sdfCircle(float2 uv, float2 position, float radius) {
    return length(uv - position) - radius;
}

float dynamicBinding(float2 primaryPos, float2 secondaryPos) {
    float distance = length(primaryPos - secondaryPos);
    return BindingDistance * (1.0 + PersistenceFactor * smoothstep(0.0, 2.0, distance));
}

float map(float2 uv, float2 primaryParameters, float2 primaryOffset, float2 secondaryParameters, float2 secondaryOffset) {
    float primary = sdfCircle(uv, primaryOffset, primaryParameters.x);
    float secondary = sdfCircle(uv, secondaryOffset, secondaryParameters.x);
    
    float bindDist = dynamicBinding(primaryOffset, secondaryOffset);
    
    float metaballs = 1.0;
    metaballs = smin(metaballs, primary, bindDist);
    metaballs = smin(metaballs, secondary, bindDist);
    return metaballs;
}

fragment half4 cameraBlobFragment(
    QuadVertexOut in [[stage_in]],
    constant float2 &primaryParameters [[buffer(0)]],
    constant float2 &primaryOffset [[buffer(1)]],
    constant float2 &secondaryParameters [[buffer(2)]],
    constant float2 &secondaryOffset [[buffer(3)]],
    constant float2 &resolution [[buffer(4)]]
) {
    float aspectRatio = resolution.x / resolution.y;
    float2 uv = in.uv * 2.0 - 1.0;
    uv.x *= aspectRatio;
    
    float t = AARadius / resolution.y;
    
    float c = smoothstep(t, -t, map(uv, primaryParameters, primaryOffset, secondaryParameters, secondaryOffset));
    
    if (primaryParameters.y > 0) {
        float innerHoleRadius = primaryParameters.y;
        float hole = smoothstep(-t, t, length(uv - primaryOffset) - innerHoleRadius);
        float primaryInfluence = smoothstep(t, -t, sdfCircle(uv, primaryOffset, primaryParameters.x * 1.2));
        
        c *= mix(1.0, hole, primaryInfluence);
    } else if (primaryParameters.y < 0) {
        float cutRadius = abs(primaryParameters.y);
        float2 primaryFeatheredOffset = primaryOffset;
        primaryFeatheredOffset.x *= 1.131;
        
        float distFromCenter = length(uv - primaryFeatheredOffset);
        
        float gradientWidth = 0.21;
        float featheredEdge = smoothstep(cutRadius - gradientWidth, cutRadius + gradientWidth, distFromCenter);
        
        float primaryInfluence = smoothstep(t, -t, sdfCircle(uv, primaryOffset, primaryParameters.x * 1.2));
        
        float horizontalFade = 1.0;
        float rightEdgePosition = 0.94 * aspectRatio;
        if (uv.x > rightEdgePosition) {
            horizontalFade = 1.0 - smoothstep(0.0, 0.22, uv.x - rightEdgePosition);
        }

        c *= mix(1.0, featheredEdge, primaryInfluence) * horizontalFade;
    }
    
    return half4(0.0, 0.0, 0.0, c);
}
