#include <metal_stdlib>

using namespace metal;

typedef struct {
    packed_float2 position;
} Vertex;

struct RasterizerData
{
    float4 position [[position]];
};

vertex RasterizerData matrixVertex
(
    constant Vertex *vertexArray[[buffer(0)]],
    uint vertexID [[ vertex_id ]]
) {
    RasterizerData out;
    
    out.position = vector_float4(vertexArray[vertexID].position[0], vertexArray[vertexID].position[1], 0.0, 1.0);
            
    return out;
}

float text(float2 uvIn,
           texture2d<half> symbolTexture,
           texture2d<float> noiseTexture,
           float time)
{
    constexpr sampler textureSampler(min_filter::linear, mag_filter::linear, mip_filter::linear, address::repeat);
    
    float count = 32.0;
    
    float2 noiseResolution = float2(256.0, 256.0);

    float2 uv = fmod(uvIn, 1.0 / count) * count;
    float2 block = uvIn * count - uv;
    uv = uv * 0.8;
    uv += floor(noiseTexture.sample(textureSampler, block / noiseResolution + time * .00025).xy * 256.);
    uv *= -1.0;
    
    uv *= 0.25;
    
    return symbolTexture.sample(textureSampler, uv).g;
}

float4 rain(float2 uvIn,
            uint2 resolution,
            float time)
{
    float count = 32.0;
    uvIn.x -= fmod(uvIn.x, 1.0 / count);
    uvIn.y -= fmod(uvIn.y, 1.0 / count);
    
    float2 fragCoord = uvIn * float2(resolution);
    
    float offset = sin(fragCoord.x * 15.0);
    float speed = cos(fragCoord.x * 3.0) * 0.3 + 0.7;
    
    float y = fract(fragCoord.y / resolution.y + time * speed + offset);
    
    return float4(1.0, 1.0, 1.0, 1.0 / (y * 30.0) - 0.02);
}

fragment half4 matrixFragment(RasterizerData in[[stage_in]],
                              texture2d<half> symbolTexture [[ texture(0) ]],
                              texture2d<float> noiseTexture [[ texture(1) ]],
                              constant uint2 &resolution[[buffer(0)]],
                              constant float &time[[buffer(1)]])
{
    float2 uv = (in.position.xy / float2(resolution.xy) - float2(0.5, 0.5));
    uv.y -= 0.1;
    
    float2 lookup = float2(0.08 / (uv.x), (0.9 - abs(uv.x)) * uv.y * -1.0) * 2.0;
    
    float4 out = text(lookup, symbolTexture, noiseTexture, time) * rain(lookup, resolution, time);
    return half4(out);
}
