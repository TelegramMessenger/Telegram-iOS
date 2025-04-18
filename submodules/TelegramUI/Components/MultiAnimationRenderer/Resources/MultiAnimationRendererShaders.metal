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
    texture2d<float, access::sample> textureY[[texture(0)]],
    texture2d<float, access::sample> textureU[[texture(1)]],
    texture2d<float, access::sample> textureV[[texture(2)]],
    texture2d<float, access::sample> textureA[[texture(3)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    half y = textureY.sample(s, in.texCoord).r;
    half u = textureU.sample(s, in.texCoord).r - 0.5;
    half v = textureV.sample(s, in.texCoord).r - 0.5;
    half a = textureA.sample(s, in.texCoord).r;

    half4 out = half4(1.5748 * v + y, -0.1873 * v + y, 1.8556 * u + y, a);
    return half4(out.b, out.g, out.r, out.a);
}
