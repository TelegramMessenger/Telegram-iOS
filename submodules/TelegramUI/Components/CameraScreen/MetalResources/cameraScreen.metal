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
    
    float cAlpha = min(1.0, 1.0 - primaryParameters.y);
    float minColor = min(1.0, 1.0 + primaryParameters.y);
    float bound = primaryParameters.x + 0.05;
    if (abs(offset) > bound) {
        cAlpha = mix(0.0, 1.0, min(1.0, (abs(offset) - bound) * 2.4));
    }

    float c = smoothstep(t, -t, map(uv, primaryParameters, primaryOffset, secondaryParameters, secondaryOffset));
    
    return half4(min(minColor, c), min(minColor, max(cAlpha, 0.231)), min(minColor, max(cAlpha, 0.188)), c);
}

struct Rectangle {
    float2 origin;
    float2 size;
};

constant static float2 quadVertices[6] = {
    float2(0.0, 0.0),
    float2(1.0, 0.0),
    float2(0.0, 1.0),
    float2(1.0, 0.0),
    float2(0.0, 1.0),
    float2(1.0, 1.0)
};

struct QuadVertexOut {
    float4 position [[position]];
    float2 uv;
};

kernel void videoBiPlanarToRGBA(
    texture2d<half, access::read> inTextureY [[ texture(0) ]],
    texture2d<half, access::read> inTextureUV [[ texture(1) ]],
    texture2d<half, access::write> outTexture [[ texture(2) ]],
    uint2 threadPosition [[ thread_position_in_grid ]]
) {
    half y = inTextureY.read(threadPosition).r;
    half2 uv = inTextureUV.read(uint2(threadPosition.x / 2, threadPosition.y / 2)).rg - half2(0.5, 0.5);
    
    half4 color(y + 1.403 * uv.y, y - 0.344 * uv.x - 0.714 * uv.y, y + 1.770 * uv.x, 1.0);
    outTexture.write(color, threadPosition);
}

kernel void videoTriPlanarToRGBA(
    texture2d<half, access::read> inTextureY [[ texture(0) ]],
    texture2d<half, access::read> inTextureU [[ texture(1) ]],
    texture2d<half, access::read> inTextureV [[ texture(2) ]],
    texture2d<half, access::write> outTexture [[ texture(3) ]],
    uint2 threadPosition [[ thread_position_in_grid ]]
) {
    half y = inTextureY.read(threadPosition).r;
    uint2 uvPosition = uint2(threadPosition.x / 2, threadPosition.y / 2);
    half2 inUV = (inTextureU.read(uvPosition).r, inTextureV.read(uvPosition).r);
    half2 uv = inUV - half2(0.5, 0.5);
    
    half4 color(y + 1.403 * uv.y, y - 0.344 * uv.x - 0.714 * uv.y, y + 1.770 * uv.x, 1.0);
    outTexture.write(color, threadPosition);
}

vertex QuadVertexOut mainVideoVertex(
    const device Rectangle &rect [[ buffer(0) ]],
    const device uint2 &mirror [[ buffer(1) ]],
    unsigned int vid [[ vertex_id ]]
) {
    float2 quadVertex = quadVertices[vid];
    
    QuadVertexOut out;
    
    out.position = float4(rect.origin.x + quadVertex.x * rect.size.x, rect.origin.y + quadVertex.y * rect.size.y, 0.0, 1.0);
    out.position.x = -1.0 + out.position.x * 2.0;
    out.position.y = -1.0 + out.position.y * 2.0;
    
    float2 uv = float2(quadVertex.x, 1.0 - quadVertex.y);
    out.uv = float2(uv.y, 1.0 - uv.x);
    if (mirror.x == 1) {
        out.uv.x = 1.0 - out.uv.x;
    }
    if (mirror.y == 1) {
        out.uv.y = 1.0 - out.uv.y;
    }
    
    return out;
}

half4 rgb2hsv(half4 c) {
    half4 K = half4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    half4 p = mix(half4(c.bg, K.wz), half4(c.gb, K.xy), step(c.b, c.g));
    half4 q = mix(half4(p.xyw, c.r), half4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return half4(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x, c.a);
}

half4 hsv2rgb(half4 c) {
    half4 K = half4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    half3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return half4(c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y), c.a);
}

fragment half4 mainVideoFragment(
    QuadVertexOut in [[stage_in]],
    texture2d<half> texture [[ texture(0) ]],
    const device float &brightness [[ buffer(0) ]],
    const device float &saturation [[ buffer(1) ]],
    const device float4 &overlay [[ buffer(2) ]]
) {
    constexpr sampler sampler(coord::normalized, address::repeat, filter::linear);
    half4 color = texture.sample(sampler, in.uv);
    color = rgb2hsv(color);
    color.b = clamp(color.b * brightness, 0.0, 1.0);
    color.g = clamp(color.g * saturation, 0.0, 1.0);
    color = hsv2rgb(color);
    color.rgb += half3(overlay.rgb * overlay.a);
    color.rgb = min(color.rgb, half3(1.0, 1.0, 1.0));
    
    return half4(color.r, color.g, color.b, color.a);
}

constant int BLUR_SAMPLE_COUNT = 7;
constant float BLUR_OFFSETS[BLUR_SAMPLE_COUNT] = {
    1.489585,
    3.475713,
    5.461880,
    7.448104,
    9.434408,
    11.420812,
    13.407332
};

constant float BLUR_WEIGHTS[BLUR_SAMPLE_COUNT] = {
    0.130498886,
    0.113685958,
    0.0886923522,
    0.0619646012,
    0.0387683809,
    0.0217213109,
    0.0108984858
};

static void gaussianBlur(
    texture2d<half, access::sample> inTexture,
    texture2d<half, access::write> outTexture,
    float2 offset,
    uint2 gid
) {
    constexpr sampler sampler(coord::normalized, address::clamp_to_edge, filter::linear);
    
    uint2 textureDim(outTexture.get_width(), outTexture.get_height());
    if(all(gid < textureDim)) {
        float3 outColor(0.0);
        
        float2 size(inTexture.get_width(), inTexture.get_height());
        
        float2 baseTexCoord = float2(gid);
        
        for (int i = 0; i < BLUR_SAMPLE_COUNT; i++) {
            outColor += float3(inTexture.sample(sampler, (baseTexCoord + offset * BLUR_OFFSETS[i]) / size).rgb) * BLUR_WEIGHTS[i];
        }

        outTexture.write(half4(half3(outColor), 1.0), gid);
    }
}

kernel void gaussianBlurHorizontal(
    texture2d<half, access::sample> inTexture [[ texture(0) ]],
    texture2d<half,  access::write> outTexture [[ texture(1) ]],
    uint2 gid [[ thread_position_in_grid ]]
) {
    gaussianBlur(inTexture, outTexture, float2(1, 0), gid);
}

kernel void gaussianBlurVertical(
    texture2d<half, access::sample> inTexture [[ texture(0) ]],
    texture2d<half, access::write> outTexture [[ texture(1) ]],
    uint2 gid [[ thread_position_in_grid ]]
) {
    gaussianBlur(inTexture, outTexture, float2(0, 1), gid);
}
