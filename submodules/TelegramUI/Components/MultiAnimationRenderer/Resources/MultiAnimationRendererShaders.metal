#include <metal_stdlib>
using namespace metal;

typedef struct {
    packed_float2 position;
    packed_float2 texCoord;
} Vertex;

typedef struct {
    float4 position[[position]];
    float2 texCoord;
} Varyings;

vertex Varyings multiAnimationVertex(
    unsigned int vid[[vertex_id]],
    constant Vertex *verticies[[buffer(0)]],
    constant uint2 &resolution[[buffer(1)]],
    constant uint2 &slotSize[[buffer(2)]],
    constant uint2 &slotPosition[[buffer(3)]]
) {
    Varyings out;
    constant Vertex &v = verticies[vid];

    

    out.position = float4(float2(v.position), 0.0, 1.0);
    out.texCoord = v.texCoord;

    return out;
}

fragment half4 multiAnimationFragment(
    Varyings in[[stage_in]],
    texture2d<float, access::sample> texture[[texture(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    return half4(texture.sample(s, in.texCoord));
}
