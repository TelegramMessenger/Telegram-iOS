#include <metal_stdlib>
using namespace metal;

typedef struct {
    packed_float2 position;
    packed_float2 localPosition;
} Vertex;

typedef struct {
    packed_float2 offset;
} Offset;

typedef struct {
    float4 position[[position]];
    float2 localPosition[[center_no_perspective]];
} Varyings;

float2 screenSpaceToRelative(float2 point, float2 viewSize) {
    float2 inverseViewSize = 1 / viewSize;
    float clipX = (2.0f * point.x * inverseViewSize.x) - 2.0f;
    float clipY = (2.0f * -point.y * inverseViewSize.y) + 2.0f;

    return float2(clipX, clipY);
}

vertex Varyings vertexPassthrough(
    constant Vertex *verticies[[buffer(0)]],
    constant float2 &offset[[buffer(1)]],
    unsigned int vid[[vertex_id]]
) {
    Varyings out;
    constant Vertex &v = verticies[vid];
    float2 viewSize(512.0f, 512.0f);
    out.position = float4(screenSpaceToRelative(float2(v.position) + offset, viewSize), 0.0, 1.0);
    out.localPosition = float2(v.localPosition);

    return out;
}

fragment half4 fragmentPassthrough(
    Varyings in[[stage_in]],
    constant float4 &color[[buffer(1)]]
) {
    float4 out = color;

    return half4(out);
}

template<int N>
half4 mixGradientColors(float dist, constant float4 *colors, constant float *steps) {
    float4 color = colors[0];
    for (int i = 1; i < N; i++) {
        color = mix(color, colors[i], smoothstep(steps[i - 1], steps[i], dist));
    }

    return half4(color);
}

#define radialGradientFunc(N) fragment half4 fragmentRadialGradient##N( \
    Varyings in[[stage_in]], \
    constant float2 &start[[buffer(1)]], \
    constant float2 &end[[buffer(2)]], \
    constant float4 *colors[[buffer(3)]], \
    constant float *steps[[buffer(4)]] \
) { \
    float centerDistance = distance(in.localPosition, start); \
    float endDistance = distance(start, end); \
    float dist = min(1.0, centerDistance / endDistance); \
    return mixGradientColors<N>(dist, colors, steps); \
}

radialGradientFunc(2)
radialGradientFunc(3)
radialGradientFunc(4)
radialGradientFunc(5)
radialGradientFunc(6)
radialGradientFunc(7)
radialGradientFunc(8)
radialGradientFunc(9)
radialGradientFunc(10)

/*fragment half4 fragmentRadialGradient3(
    Varyings in[[stage_in]],
    constant float2 &start[[buffer(1)]],
    constant float2 &end[[buffer(2)]]
) {
    float centerDistance = distance(in.localPosition, start);
    float endDistance = distance(start, end);
    float dist = min(1.0, centerDistance / endDistance);

    float4 colors[4] = {
        float4(1.0, 1.0, 1.0, 1.0),
        float4(1.0, 0.0, 0.0, 1.0),
        float4(0.0, 0.0, 1.0, 1.0),
        float4(0.0, 1.0, 0.0, 1.0)
    };
    float steps[4] = {
        0.0,
        0.33,
        0.66,
        1.0
    };

    float4 out = mixGradientColors<4>(dist, colors, steps);

    return half4(out);
}
*/
