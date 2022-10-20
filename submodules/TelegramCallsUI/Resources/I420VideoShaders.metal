#include <metal_stdlib>
using namespace metal;

typedef struct {
    packed_float2 position;
    packed_float2 texcoord;
} Vertex;

typedef struct {
    float4 position[[position]];
    float2 texcoord;
} Varyings;

vertex Varyings i420VertexPassthrough(constant Vertex *verticies[[buffer(0)]],
                                  unsigned int vid[[vertex_id]]) {
    Varyings out;
    constant Vertex &v = verticies[vid];
    out.position = float4(float2(v.position), 0.0, 1.0);
    out.texcoord = v.texcoord;

    return out;
}

fragment half4 i420FragmentColorConversion(
    Varyings in[[stage_in]],
    texture2d<float, access::sample> textureY[[texture(0)]],
    texture2d<float, access::sample> textureU[[texture(1)]],
    texture2d<float, access::sample> textureV[[texture(2)]]) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float y;
    float u;
    float v;
    float r;
    float g;
    float b;
    // Conversion for YUV to rgb from http://www.fourcc.org/fccyvrgb.php
    y = textureY.sample(s, in.texcoord).r;
    u = textureU.sample(s, in.texcoord).r;
    v = textureV.sample(s, in.texcoord).r;
    u = u - 0.5;
    v = v - 0.5;
    r = y + 1.403 * v;
    g = y - 0.344 * u - 0.714 * v;
    b = y + 1.770 * u;

    float4 out = float4(r, g, b, 1.0);

    return half4(out);
}