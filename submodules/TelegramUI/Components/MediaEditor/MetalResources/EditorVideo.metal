#include <metal_stdlib>
#include "EditorCommon.h"
#include "EditorUtils.h"

using namespace metal;

static inline float sRGBnonLinearNormToLinear(float normV) {
    if (normV <= 0.04045f) {
        normV *= (1.0f / 12.92f);
    } else {
        const float a = 0.055f;
        const float gamma = 2.4f;
        normV = (normV + a) * (1.0f / (1.0f + a));
        normV = pow(normV, gamma);
    }
    return normV;
}

static inline float4 sRGBGammaDecode(const float4 rgba) {
    float4 result = rgba;
    result.r = sRGBnonLinearNormToLinear(rgba.r);
    result.g = sRGBnonLinearNormToLinear(rgba.g);
    result.b = sRGBnonLinearNormToLinear(rgba.b);
    return rgba;
}

static inline float4 BT709Decode(const float Y, const float Cb, const float Cr) {
    float Yn = Y;

    float Cbn = (Cb - (128.0f/255.0f));
    float Crn = (Cr - (128.0f/255.0f));

    float3 YCbCr = float3(Yn, Cbn, Crn);

    const float3x3 kColorConversion709 = float3x3(float3(1.0, 1.0, 1.0),
                                                  float3(0.0f, -0.18732, 1.8556),
                                                  float3(1.5748, -0.46812, 0.0));

    float3 rgb = kColorConversion709 * YCbCr;

    rgb = saturate(rgb);

    return float4(rgb.r, rgb.g, rgb.b, 1.0f);
}

fragment float4 bt709ToRGBFragmentShader(RasterizerData in [[stage_in]],
                                          texture2d<half, access::sample>  inYTexture  [[texture(0)]],
                                          texture2d<half, access::sample>  inUVTexture [[texture(1)]]
                                          )
{
    constexpr sampler textureSampler (mag_filter::nearest, min_filter::nearest);
    
    float Y = float(inYTexture.sample(textureSampler, in.texCoord).r);
    half2 uvSamples = inUVTexture.sample(textureSampler, in.texCoord).rg;
    
    float Cb = float(uvSamples[0]);
    float Cr = float(uvSamples[1]);

    float4 pixel = BT709Decode(Y, Cb, Cr);
    pixel = sRGBGammaDecode(pixel);
    //pixel.rgb = pow(pixel.rgb, 1.0 / 2.2);
    return pixel;
}
