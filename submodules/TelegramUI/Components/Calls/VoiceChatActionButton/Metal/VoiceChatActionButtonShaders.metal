#include <metal_stdlib>

using namespace metal;

struct Rectangle {
    float2 origin;
    float2 size;
};

struct QuadVertexOut {
    float4 position [[position]];
    float2 uv;
};
