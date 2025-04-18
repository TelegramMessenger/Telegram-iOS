#include <metal_stdlib>

using namespace metal;

vertex float4 clearVertex(const device float2* vertexArray [[ buffer(0) ]], unsigned int vid [[ vertex_id ]]) {
    return float4(vertexArray[vid], 0.0, 1.0);
}

fragment half4 clearFragment(const device float4 &color [[ buffer(0) ]]) {
    return half4(color);
}
