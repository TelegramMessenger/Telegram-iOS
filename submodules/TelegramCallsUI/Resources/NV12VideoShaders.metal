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

vertex Varyings nv12VertexPassthrough(
    constant Vertex *verticies[[buffer(0)]],
    unsigned int vid[[vertex_id]]
) {
    Varyings out;
    constant Vertex &v = verticies[vid];
    out.position = float4(float2(v.position), 0.0, 1.0);
    out.texcoord = v.texcoord;
    return out;
}

float4 samplePoint(texture2d<float, access::sample> textureY, texture2d<float, access::sample> textureCbCr, sampler s, float2 texcoord) {
    float y;
    float2 uv;
    y = textureY.sample(s, texcoord).r;
    uv = textureCbCr.sample(s, texcoord).rg - float2(0.5, 0.5);

    // Conversion for YUV to rgb from http://www.fourcc.org/fccyvrgb.php
    float4 out = float4(y + 1.403 * uv.y, y - 0.344 * uv.x - 0.714 * uv.y, y + 1.770 * uv.x, 1.0);
    return out;
}

fragment half4 nv12FragmentColorConversion(
    Varyings in[[stage_in]],
    texture2d<float, access::sample> textureY[[texture(0)]],
    texture2d<float, access::sample> textureCbCr[[texture(1)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float4 out = samplePoint(textureY, textureCbCr, s, in.texcoord);

    return half4(out);
}

fragment half4 blitFragmentColorConversion(
    Varyings in[[stage_in]],
    texture2d<float, access::sample> texture[[texture(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float4 out = texture.sample(s, in.texcoord);

    return half4(out);
}
