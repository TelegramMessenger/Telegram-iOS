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

fragment half4 wallpaperFragment(Varyings in[[stage_in]]) {
    float4 out = float4(0.0, 1.0, 0.0, 1.0);

    return half4(out);
}
