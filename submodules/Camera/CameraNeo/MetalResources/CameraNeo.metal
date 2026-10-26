#include <metal_stdlib>
using namespace metal;

struct FrameUniforms {
    float4 primaryRow0;
    float4 primaryRow1;
    float4 primaryRow2;
    float4 primaryOffset;
    float4 primarySource;

    float4 secondaryRow0;
    float4 secondaryRow1;
    float4 secondaryRow2;
    float4 secondaryOffset;
    float4 secondarySource;

    float4 blend;
    float4 decoration;
};

static float2 sourceCoordinate(float2 outputCoordinate, float4 source) {
    uint rotation = uint(source.z + 0.5);
    bool mirrored = source.w > 0.5;

    float2 orientedSize = (rotation == 1 || rotation == 3) ? source.yx : source.xy;
    float shortestSide = min(orientedSize.x, orientedSize.y);
    float2 coordinate = outputCoordinate;
    coordinate.x = 0.5 + (coordinate.x - 0.5) * shortestSide / orientedSize.x;
    coordinate.y = 0.5 + (coordinate.y - 0.5) * shortestSide / orientedSize.y;

    if (mirrored) {
        coordinate.x = 1.0 - coordinate.x;
    }

    switch (rotation) {
    case 1:
        return float2(coordinate.y, 1.0 - coordinate.x);
    case 2:
        return 1.0 - coordinate;
    case 3:
        return float2(1.0 - coordinate.y, coordinate.x);
    default:
        return coordinate;
    }
}

static float3 readRgb(
    texture2d<float, access::sample> yTexture,
    texture2d<float, access::sample> cbcrTexture,
    sampler textureSampler,
    float2 coordinate,
    float4 row0,
    float4 row1,
    float4 row2,
    float4 offset
) {
    float y = yTexture.sample(textureSampler, coordinate).r;
    float2 cbcr = cbcrTexture.sample(textureSampler, coordinate).rg;
    float3 yuv = float3(y, cbcr) + offset.xyz;
    return saturate(float3(
        dot(row0.xyz, yuv),
        dot(row1.xyz, yuv),
        dot(row2.xyz, yuv)
    ));
}

static float3 readCompositeRgb(
    texture2d<float, access::sample> primaryY,
    texture2d<float, access::sample> primaryCbCr,
    texture2d<float, access::sample> secondaryY,
    texture2d<float, access::sample> secondaryCbCr,
    sampler textureSampler,
    float2 outputCoordinate,
    constant FrameUniforms &uniforms
) {
    float2 primaryCoordinate = sourceCoordinate(outputCoordinate, uniforms.primarySource);
    float3 primaryRgb = readRgb(
        primaryY,
        primaryCbCr,
        textureSampler,
        primaryCoordinate,
        uniforms.primaryRow0,
        uniforms.primaryRow1,
        uniforms.primaryRow2,
        uniforms.primaryOffset
    );

    if (uniforms.blend.y > 0.5 && uniforms.blend.x > 0.0) {
        float2 secondaryCoordinate = sourceCoordinate(outputCoordinate, uniforms.secondarySource);
        float3 secondaryRgb = readRgb(
            secondaryY,
            secondaryCbCr,
            textureSampler,
            secondaryCoordinate,
            uniforms.secondaryRow0,
            uniforms.secondaryRow1,
            uniforms.secondaryRow2,
            uniforms.secondaryOffset
        );
        return mix(primaryRgb, secondaryRgb, saturate(uniforms.blend.x));
    }
    return primaryRgb;
}

static float3 sourceOver(float4 overlay, float3 background) {
    return saturate(overlay.rgb + background * (1.0 - overlay.a));
}

kernel void convertNV12(
    texture2d<float, access::sample> primaryY [[texture(0)]],
    texture2d<float, access::sample> primaryCbCr [[texture(1)]],
    texture2d<float, access::sample> secondaryY [[texture(2)]],
    texture2d<float, access::sample> secondaryCbCr [[texture(3)]],
    texture2d<float, access::write> output [[texture(4)]],
    constant FrameUniforms &uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }

    constexpr sampler textureSampler(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 outputSize = float2(output.get_width(), output.get_height());
    float2 pixelCoordinate = float2(gid) + 0.5;
    float2 outputCoordinate = pixelCoordinate / outputSize;

    float2 primaryCoordinate = sourceCoordinate(outputCoordinate, uniforms.primarySource);
    float3 primaryRgb = readRgb(
        primaryY,
        primaryCbCr,
        textureSampler,
        primaryCoordinate,
        uniforms.primaryRow0,
        uniforms.primaryRow1,
        uniforms.primaryRow2,
        uniforms.primaryOffset
    );

    float3 result = primaryRgb;
    if (uniforms.blend.y > 0.5 && uniforms.blend.x > 0.0) {
        float2 secondaryCoordinate = sourceCoordinate(outputCoordinate, uniforms.secondarySource);
        float3 secondaryRgb = readRgb(
            secondaryY,
            secondaryCbCr,
            textureSampler,
            secondaryCoordinate,
            uniforms.secondaryRow0,
            uniforms.secondaryRow1,
            uniforms.secondaryRow2,
            uniforms.secondaryOffset
        );
        result = mix(primaryRgb, secondaryRgb, saturate(uniforms.blend.x));
    }

    float radius = min(outputSize.x, outputSize.y) * 0.5 + 2.0;
    float circleMask = 1.0 - smoothstep(radius - 0.5, radius + 0.5, distance(pixelCoordinate, outputSize * 0.5));
    result = mix(float3(1.0), result, circleMask);

    output.write(float4(result, 1.0), gid);
}

kernel void downsampleNV12(
    texture2d<float, access::sample> primaryY [[texture(0)]],
    texture2d<float, access::sample> primaryCbCr [[texture(1)]],
    texture2d<float, access::sample> secondaryY [[texture(2)]],
    texture2d<float, access::sample> secondaryCbCr [[texture(3)]],
    texture2d<float, access::write> output [[texture(4)]],
    constant FrameUniforms &uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }

    constexpr sampler textureSampler(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 outputCoordinate = (float2(gid) + 0.5) / float2(output.get_width(), output.get_height());
    float3 result = readCompositeRgb(
        primaryY,
        primaryCbCr,
        secondaryY,
        secondaryCbCr,
        textureSampler,
        outputCoordinate,
        uniforms
    );
    output.write(float4(result, 1.0), gid);
}

kernel void compositeRoundVideo(
    texture2d<float, access::sample> primaryY [[texture(0)]],
    texture2d<float, access::sample> primaryCbCr [[texture(1)]],
    texture2d<float, access::sample> secondaryY [[texture(2)]],
    texture2d<float, access::sample> secondaryCbCr [[texture(3)]],
    texture2d<float, access::write> output [[texture(4)]],
    texture2d<float, access::sample> blurred [[texture(5)]],
    texture2d<float, access::sample> watermark [[texture(6)]],
    texture2d<float, access::sample> planeAtlas [[texture(7)]],
    constant FrameUniforms &uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }

    constexpr sampler textureSampler(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 outputSize = float2(output.get_width(), output.get_height());
    float2 pixelCoordinate = float2(gid) + 0.5;
    float2 outputCoordinate = pixelCoordinate / outputSize;

    float3 sharp = readCompositeRgb(
        primaryY,
        primaryCbCr,
        secondaryY,
        secondaryCbCr,
        textureSampler,
        outputCoordinate,
        uniforms
    );
    float3 darkenedBlur = blurred.sample(textureSampler, outputCoordinate).rgb * 0.25;
    float circleMask = 1.0 - smoothstep(201.5, 202.5, distance(pixelCoordinate, outputSize * 0.5));
    float3 result = mix(darkenedBlur, sharp, circleMask);

    constexpr float watermarkSize = 100.0;
    float2 watermarkOrigin = outputSize - float2(watermarkSize);
    if (pixelCoordinate.x >= watermarkOrigin.x && pixelCoordinate.y >= watermarkOrigin.y) {
        float2 watermarkCoordinate = (pixelCoordinate - watermarkOrigin) / watermarkSize;
        result = sourceOver(watermark.sample(textureSampler, watermarkCoordinate), result);
    }

    constexpr float planeSize = 68.0;
    float2 planeOrigin = float2(0.0, outputSize.y - planeSize);
    if (pixelCoordinate.x < planeSize && pixelCoordinate.y >= planeOrigin.y) {
        uint frameIndex = uint(uniforms.decoration.x + 0.5);
        uint columns = max(1u, uint(uniforms.decoration.y + 0.5));
        uint column = frameIndex % columns;
        uint row = frameIndex / columns;
        float2 localCoordinate = pixelCoordinate - planeOrigin;
        float2 atlasPixel = float2(float(column), float(row)) * planeSize + localCoordinate;
        float2 atlasCoordinate = atlasPixel / float2(planeAtlas.get_width(), planeAtlas.get_height());
        result = sourceOver(planeAtlas.sample(textureSampler, atlasCoordinate), result);
    }

    output.write(float4(result, 1.0), gid);
}
