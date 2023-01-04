#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float4 position [[position]];
    float2 tex_coord;
};

struct Uniforms {
    float4x4 scaleMatrix;
};

struct Point {
    float4 position [[position]];
    float4 color;
    float angle;
    float size [[point_size]];
};

vertex Vertex vertex_render_target(constant Vertex *vertexes [[ buffer(0) ]],
                                   constant Uniforms &uniforms [[ buffer(1) ]],
                                   uint vid [[vertex_id]])
{
    Vertex out = vertexes[vid];
    out.position = uniforms.scaleMatrix * out.position;
    return out;
};

fragment float4 fragment_render_target(Vertex vertex_data [[ stage_in ]],
                                       texture2d<float> tex2d [[ texture(0) ]])
{
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    float4 color = float4(tex2d.sample(textureSampler, vertex_data.tex_coord));
    return color;
};

float2 transformPointCoord(float2 pointCoord, float a, float2 anchor) {
    float2 point20 = pointCoord - anchor;
    float x = point20.x * cos(a) - point20.y * sin(a);
    float y = point20.x * sin(a) + point20.y * cos(a);
    return float2(x, y) + anchor;
}

vertex Point vertex_point_func(constant Point *points [[ buffer(0) ]],
                               constant Uniforms &uniforms [[ buffer(1) ]],
                               uint vid [[ vertex_id ]])
{
    Point out = points[vid];
    float2 pos = float2(out.position.x, out.position.y);
    out.position = uniforms.scaleMatrix * float4(pos, 0, 1);
    out.size = out.size;
    return out;
};

fragment float4 fragment_point_func(Point point_data [[ stage_in ]],
                                    texture2d<float> tex2d [[ texture(0) ]],
                                    float2 pointCoord  [[ point_coord ]])
{
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    float2 tex_coord = transformPointCoord(pointCoord, point_data.angle, float2(0.5));
    float4 color = float4(tex2d.sample(textureSampler, tex_coord));
    return float4(point_data.color.rgb, color.a * point_data.color.a);
};
