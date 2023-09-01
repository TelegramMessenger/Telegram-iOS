#include <metal_stdlib>
#include "EditorCommon.h"
#include "EditorUtils.h"

using namespace metal;

typedef struct {
    float2      dimensions;
    float2      position;
    float       aspectRatio;
    float       size;
    float       falloff;
    float       rotation;
} MediaEditorBlur;

fragment half4 blurRadialFragmentShader(RasterizerData in [[stage_in]],
                                        texture2d<half, access::sample> sourceTexture [[texture(0)]],
                                        texture2d<half, access::sample> blurTexture [[texture(1)]],
                                        constant MediaEditorBlur& values [[ buffer(0) ]]
                                        )
{
    constexpr sampler sourceSampler(min_filter::linear, mag_filter::linear, address::clamp_to_zero);
    constexpr sampler blurSampler(min_filter::linear, mag_filter::linear, address::clamp_to_zero);
    
    half4 sourceColor = sourceTexture.sample(sourceSampler, in.texCoord);
    half4 blurredColor = blurTexture.sample(blurSampler, in.texCoord);
    
    float2 texCoord = float2(in.texCoord.x, (in.texCoord.y * values.aspectRatio + 0.5 - 0.5 * values.aspectRatio));
    half distanceFromCenter = distance(values.position, texCoord);
    
    half3 result = mix(blurredColor.rgb, sourceColor.rgb, smoothstep(1.0, values.falloff, clamp(distanceFromCenter / values.size, 0.0, 1.0)));
    return half4(result, sourceColor.a);
}


fragment half4 blurLinearFragmentShader(RasterizerData in [[stage_in]],
                                        texture2d<half, access::sample> sourceTexture [[texture(0)]],
                                        texture2d<half, access::sample> blurTexture [[texture(1)]],
                                        constant MediaEditorBlur& values [[ buffer(0) ]]
                                        )
{
    constexpr sampler sourceSampler(min_filter::linear, mag_filter::linear, address::clamp_to_zero);
    constexpr sampler blurSampler(min_filter::linear, mag_filter::linear, address::clamp_to_zero);
    
    half4 sourceColor = sourceTexture.sample(sourceSampler, in.texCoord);
    half4 blurredColor = blurTexture.sample(blurSampler, in.texCoord);
    
    float2 texCoord = float2(in.texCoord.x, (in.texCoord.y * values.aspectRatio + 0.5 - 0.5 * values.aspectRatio));
    half distanceFromCenter = abs((texCoord.x - values.position.x) * sin(-values.rotation) + (texCoord.y - values.position.y) * cos(-values.rotation));
    
    half3 result = mix(blurredColor.rgb, sourceColor.rgb, smoothstep(1.0, values.falloff, clamp(distanceFromCenter / values.size, 0.0, 1.0)));
    return half4(result, sourceColor.a);
}

fragment half4 blurPortraitFragmentShader(RasterizerData in [[stage_in]],
                                        texture2d<half, access::sample> sourceTexture [[texture(0)]],
                                        texture2d<half, access::sample> blurTexture [[texture(1)]],
                                        texture2d<half, access::sample> maskTexture [[texture(2)]],
                                        constant MediaEditorBlur& values [[ buffer(0) ]]
                                        )
{
    constexpr sampler sourceSampler(min_filter::linear, mag_filter::linear, address::clamp_to_zero);
    constexpr sampler blurSampler(min_filter::linear, mag_filter::linear, address::clamp_to_zero);
    constexpr sampler maskSampler(min_filter::linear, mag_filter::linear, address::clamp_to_zero);
    
    half4 sourceColor = sourceTexture.sample(sourceSampler, in.texCoord);
    half4 blurredColor = blurTexture.sample(blurSampler, in.texCoord);
    half4 maskColor = maskTexture.sample(maskSampler, in.texCoord);
    
    half3 result = mix(blurredColor.rgb, sourceColor.rgb, maskColor.r);
    return half4(result, sourceColor.a);
}
