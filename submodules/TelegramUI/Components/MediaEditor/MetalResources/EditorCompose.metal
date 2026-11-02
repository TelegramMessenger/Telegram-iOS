#include <metal_stdlib>

using namespace metal;

typedef struct {
    float4 position;
    float2 texCoord;
} EditorComposeVertex;

typedef struct {
    float4 position [[position]];
    float2 texCoord;
} EditorComposeRasterizerData;

typedef struct {
    float4 range;
    float4 coefficients;
} EditorComposeYuvParameters;

constexpr sampler editorComposeSampler(filter::linear, address::clamp_to_zero, coord::normalized);

vertex EditorComposeRasterizerData editorComposeVertexShader(uint vertexID [[vertex_id]],
                                                            constant EditorComposeVertex *vertices [[buffer(0)]]) {
    EditorComposeRasterizerData out;
    out.position = vertices[vertexID].position;
    out.texCoord = vertices[vertexID].texCoord;
    return out;
}

fragment float4 editorComposeLayerFragmentShader(EditorComposeRasterizerData in [[stage_in]],
                                                 texture2d<float, access::sample> texture [[texture(0)]],
                                                 constant float4 &sampleBounds [[buffer(0)]]) {
    float2 texCoord = clamp(in.texCoord, sampleBounds.xy, sampleBounds.zw);
    return texture.sample(editorComposeSampler, texCoord);
}

fragment float4 editorComposeMaskedLayerFragmentShader(EditorComposeRasterizerData in [[stage_in]],
                                                       texture2d<float, access::sample> texture [[texture(0)]],
                                                       texture2d<float, access::sample> mask [[texture(1)]],
                                                       constant float4 &sampleBounds [[buffer(0)]]) {
    float2 texCoord = clamp(in.texCoord, sampleBounds.xy, sampleBounds.zw);
    int2 size = int2(texture.get_width(), texture.get_height());
    int2 maskSize = int2(mask.get_width(), mask.get_height());
    float2 position = texCoord * float2(size) - 0.5;
    int2 origin = int2(floor(position));
    float2 fraction = position - floor(position);
    float4 taps[4];
    for (int index = 0; index < 4; index++) {
        int2 coordinate = origin + int2(index & 1, index >> 1);
        if (coordinate.x < 0 || coordinate.y < 0 || coordinate.x >= size.x || coordinate.y >= size.y || coordinate.x >= maskSize.x || coordinate.y >= maskSize.y) {
            taps[index] = float4(0.0);
        } else {
            taps[index] = texture.read(uint2(coordinate)) * mask.read(uint2(coordinate)).a;
        }
    }
    return mix(mix(taps[0], taps[1], fraction.x), mix(taps[2], taps[3], fraction.x), fraction.y);
}

fragment float4 editorComposeResolveFragmentShader(EditorComposeRasterizerData in [[stage_in]],
                                                   texture2d<float, access::read> source [[texture(0)]]) {
    float4 color = source.read(uint2(in.position.xy));
    float alpha = saturate(color.a);
    return float4(clamp(color.rgb, float3(0.0), float3(alpha)), alpha);
}

fragment float4 editorComposeColorFragmentShader(EditorComposeRasterizerData in [[stage_in]],
                                                 constant float4 &color [[buffer(0)]]) {
    return color;
}

fragment float4 editorComposeFinalMaskFragmentShader(EditorComposeRasterizerData in [[stage_in]],
                                                     texture2d<float, access::sample> mask [[texture(0)]]) {
    float value = mask.sample(editorComposeSampler, in.texCoord).g;
    return float4(value);
}

fragment float4 editorComposeClipFragmentShader(EditorComposeRasterizerData in [[stage_in]],
                                                constant float4 &clip [[buffer(0)]]) {
    float2 pixel = floor(in.position.xy);
    float x = clamp(min(pixel.x + 1.0, clip.z) - max(pixel.x, clip.x), 0.0, 1.0);
    float y = clamp(min(pixel.y + 1.0, clip.w) - max(pixel.y, clip.y), 0.0, 1.0);
    return float4(x * y);
}

typedef struct {
    float4 column0;
    float4 column1;
    float4 column2;
    float4 domain;
} EditorComposeColorConversion;

static inline float3 editorComposeYuvToRgb(texture2d<float, access::sample> yTexture, texture2d<float, access::sample> cbcrTexture, constant EditorComposeYuvParameters &parameters, float2 coordinate) {
    constexpr sampler nearestSampler(filter::nearest, address::clamp_to_edge, coord::normalized);
    constexpr sampler chromaSampler(filter::linear, address::clamp_to_edge, coord::normalized);
    float y = (yTexture.sample(nearestSampler, coordinate).r - parameters.range.x) * parameters.range.y;
    float2 cbcr = (cbcrTexture.sample(chromaSampler, coordinate).rg - parameters.range.z) * parameters.range.w;
    return float3(
        y + parameters.coefficients.x * cbcr.y,
        y + parameters.coefficients.y * cbcr.x + parameters.coefficients.z * cbcr.y,
        y + parameters.coefficients.w * cbcr.x
    );
}

static inline float editorComposeLinearize(constant float *curve, constant EditorComposeColorConversion &conversion, float value) {
    float size = conversion.domain.z;
    float position = (clamp(value, conversion.domain.x, conversion.domain.y) - conversion.domain.x) / (conversion.domain.y - conversion.domain.x) * (size - 1.0);
    uint index = min(uint(position), uint(size) - 2);
    return mix(curve[index], curve[index + 1], position - float(index));
}

static inline float editorComposeEncodeSrgb(float value) {
    float magnitude = abs(value);
    float encoded = magnitude <= 0.0031308 ? magnitude * 12.92 : 1.055 * pow(magnitude, 1.0 / 2.4) - 0.055;
    return sign(value) * encoded;
}

kernel void editorComposeYuvToRgbKernel(texture2d<float, access::sample> yTexture [[texture(0)]],
                                        texture2d<float, access::sample> cbcrTexture [[texture(1)]],
                                        texture2d<float, access::write> output [[texture(2)]],
                                        constant EditorComposeYuvParameters &parameters [[buffer(0)]],
                                        uint2 gid [[thread_position_in_grid]]) {
    uint width = output.get_width();
    uint height = output.get_height();
    if (gid.x >= width || gid.y >= height) {
        return;
    }
    float2 coordinate = (float2(gid) + 0.5) / float2(width, height);
    output.write(float4(saturate(editorComposeYuvToRgb(yTexture, cbcrTexture, parameters, coordinate)), 1.0), gid);
}

static inline float3 editorComposeConvertColor(constant float *curve, constant EditorComposeColorConversion &conversion, float3 rgb) {
    float3 linear = float3(editorComposeLinearize(curve, conversion, rgb.r), editorComposeLinearize(curve, conversion, rgb.g), editorComposeLinearize(curve, conversion, rgb.b));
    float3 converted = conversion.column0.xyz * linear.r + conversion.column1.xyz * linear.g + conversion.column2.xyz * linear.b;
    return float3(editorComposeEncodeSrgb(converted.r), editorComposeEncodeSrgb(converted.g), editorComposeEncodeSrgb(converted.b));
}

kernel void editorComposeYuvToRgbColorConvertedKernel(texture2d<float, access::sample> yTexture [[texture(0)]],
                                                      texture2d<float, access::sample> cbcrTexture [[texture(1)]],
                                                      texture2d<float, access::write> output [[texture(2)]],
                                                      constant EditorComposeYuvParameters &parameters [[buffer(0)]],
                                                      constant float *curve [[buffer(1)]],
                                                      constant EditorComposeColorConversion &conversion [[buffer(2)]],
                                                      uint2 gid [[thread_position_in_grid]]) {
    uint width = output.get_width();
    uint height = output.get_height();
    if (gid.x >= width || gid.y >= height) {
        return;
    }
    float2 coordinate = (float2(gid) + 0.5) / float2(width, height);
    float3 rgb = editorComposeYuvToRgb(yTexture, cbcrTexture, parameters, coordinate);
    output.write(float4(editorComposeConvertColor(curve, conversion, rgb), 1.0), gid);
}

kernel void editorComposeColorConvertKernel(texture2d<float, access::read> input [[texture(0)]],
                                            texture2d<float, access::write> output [[texture(1)]],
                                            constant float *curve [[buffer(0)]],
                                            constant EditorComposeColorConversion &conversion [[buffer(1)]],
                                            uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }
    float4 color = input.read(gid);
    if (color.a <= 0.0) {
        output.write(float4(0.0), gid);
        return;
    }
    float3 converted = editorComposeConvertColor(curve, conversion, color.rgb / color.a);
    if (conversion.domain.w > 0.5) {
        converted = saturate(converted);
    }
    output.write(float4(converted * color.a, color.a), gid);
}
