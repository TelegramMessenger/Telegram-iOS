#include <metal_stdlib>
using namespace metal;

typedef struct {
    packed_float2 position;
} Vertex;

typedef struct {
    float4 position[[position]];
} Varyings;

vertex Varyings wallpaperVertex(constant Vertex *verticies[[buffer(0)]], unsigned int vid[[vertex_id]]) {
    Varyings out;
    constant Vertex &v = verticies[vid];
    out.position = float4(float2(v.position), 0.0, 1.0);

    return out;
}

fragment half4 wallpaperFragment1(Varyings in[[stage_in]]) {
    float4 out = float4(0.0, 1.0, 0.0, 1.0);

    return half4(out);
}

fragment half4 wallpaperFragment(Varyings in[[stage_in]], constant uint2 &resolution[[buffer(0)]], constant float &time[[buffer(1)]]) {
    half4 p = half4(in.position);
    p.y = -p.y;

    p.y /= resolution.y;
    p.y += tan(time + tan(p.x) + sin(.2 * p.x));
    float4 out = float4(0.0, (0.3 + (p.y < 0.0 ? 0.0 : 1.0 - p.y * 3.0)) * 0.2, 0.0, 1.0);

    return half4(out);
}
