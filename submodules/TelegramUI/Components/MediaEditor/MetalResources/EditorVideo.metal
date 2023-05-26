#include <metal_stdlib>
#include "EditorCommon.h"
#include "EditorUtils.h"

using namespace metal;

static inline float4 BT709_decode(const float Y, const float Cb, const float Cr) {
    float Yn = Y;

    float Cbn = (Cb - (128.0f/255.0f));
    float Crn = (Cr - (128.0f/255.0f));

    float3 YCbCr = float3(Yn, Cbn, Crn);

    const float3x3 kColorConversion709 = float3x3(float3(1.0, 1.0, 1.0),
                                                  float3(0.0f, -0.1873, 1.8556),
                                                  float3(1.5748, -0.4681, 0.0));

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

    float4 pixel = BT709_decode(Y, Cb, Cr);
    return pixel;
}
