#include <metal_stdlib>
#include "EditorCommon.h"
#include "EditorUtils.h"

using namespace metal;

kernel void morphologyMaximumFilter(texture2d<float, access::sample> inputTexture [[texture(0)]],
                                    texture2d<float, access::write> outputTexture [[texture(1)]],
                                    constant float& radius [[buffer(0)]],
                                    uint2 gid [[thread_position_in_grid]]) {
    uint2 size = uint2(inputTexture.get_width(), inputTexture.get_height());
    uint2 pos = gid;

    float maxIntensity = 0.0;
    int kernelRadius = int(radius);

    for (int y = -kernelRadius; y <= kernelRadius; ++y) {
        for (int x = -kernelRadius; x <= kernelRadius; ++x) {
            uint2 samplePos = pos + uint2(x, y);
            
            if (samplePos.x >= 0 && samplePos.y >= 0 && samplePos.x < size.x && samplePos.y < size.y) {
                float intensity = inputTexture.read(samplePos).a;
                if (intensity > maxIntensity) {
                    maxIntensity = intensity;
                }
            }
        }
    }
    outputTexture.write(maxIntensity, gid);
}

fragment half4 stickerOutlineFragmentShader(RasterizerData in [[stage_in]],
                                            texture2d<half, access::sample> sourceTexture [[texture(0)]],
                                            texture2d<half, access::sample> maskTexture [[texture(1)]]
                                            )
{
    constexpr sampler colorSampler(min_filter::linear, mag_filter::linear, address::clamp_to_zero);
    constexpr sampler maskSampler(min_filter::linear, mag_filter::linear, address::clamp_to_zero);
    
    half4 color = sourceTexture.sample(colorSampler, in.texCoord);
    half intensity = maskTexture.sample(maskSampler, in.texCoord).r;
    
    half4 result = half4(intensity, intensity, intensity, max(color.a, intensity));
    result.r = mix(result.r, color.r, color.a);
    result.g = mix(result.g, color.g, color.a);
    result.b = mix(result.b, color.b, color.a);
    
    return result;
}
