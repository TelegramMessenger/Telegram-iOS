#include <metal_stdlib>
#include "EditorCommon.h"
#include "EditorUtils.h"

using namespace metal;

typedef struct {
    uint histogramBins;
    uint clipLimit;
    uint totalPixelCountPerTile;
    uint numberOfLUTs;
} MediaEditorEnhanceLUTGeneratorParameters;

METAL_FUNC half3 rgb2hsl(half3 inputColor) {
    half3 color = saturate(inputColor);
    
    //Compute min and max component values
    half MAX = max(color.r, max(color.g, color.b));
    half MIN = min(color.r, min(color.g, color.b));
    
    //Make sure MAX > MIN to avoid division by zero later
    MAX = max(MIN + 1e-6h, MAX);
    
    //Compute luminosity
    half l = (MIN + MAX) / 2.0h;
    
    //Compute saturation
    half s = (l < 0.5h ? (MAX - MIN) / (MIN + MAX) : (MAX - MIN) / (2.0h - MAX - MIN));
    
    //Compute hue
    half h = (MAX == color.r ? (color.g - color.b) / (MAX - MIN) : (MAX == color.g ? 2.0h + (color.b - color.r) / (MAX - MIN) : 4.0h + (color.r - color.g) / (MAX - MIN)));
    h /= 6.0h;
    h = (h < 0.0h ? 1.0h + h : h);
    
    return half3(h, s, l);
}

fragment half rgbToLightnessFragmentShader(RasterizerData in [[ stage_in ]],
                                           texture2d<half, access::sample> sourceTexture [[ texture(0) ]],
                                           sampler colorSampler [[ sampler(0) ]],
                                           constant float2 & scale [[buffer(0)]])
{
    half4 color = sourceTexture.sample(colorSampler, in.texCoord * scale);
    half3 hsl = rgbToHsl(color.rgb);
    return hsl.b;
}

kernel void CLAHEGenerateLUT(texture2d<float, access::write> outTexture [[texture(0)]],
                             device uint * histogramBuffer [[buffer(0)]],
                             constant MediaEditorEnhanceLUTGeneratorParameters & parameters [[buffer(1)]],
                             uint gid [[thread_position_in_grid]])
{
    if (gid >= parameters.numberOfLUTs) {
        return;
    }
    
    device uint *l = histogramBuffer + gid * parameters.histogramBins;
    const uint histSize = parameters.histogramBins;
    
    uint clipped = 0;
    for (uint i = 0; i < histSize; ++i) {
        if(l[i] > parameters.clipLimit) {
            clipped += (l[i] - parameters.clipLimit);
            l[i] = parameters.clipLimit;
        }
    }
    
    const uint redistBatch = clipped / histSize;
    uint residual = clipped - redistBatch * histSize;
    
    for (uint i = 0; i < histSize; ++i) {
        l[i] += redistBatch;
    }
    
    if (residual != 0) {
        const uint residualStep = max(histSize / residual, (uint)1);
        for (uint i = 0; i < histSize && residual > 0; i += residualStep, residual--) {
            l[i]++;
        }
    }
    
    uint sum = 0;
    const float lutScale = (histSize - 1) / float(parameters.totalPixelCountPerTile);
    for (uint index = 0; index < histSize; ++index) {
        sum += l[index];
        outTexture.write(round(sum * lutScale)/255.0, uint2(index, gid));
    }
}

half CLAHELookup(texture2d<half, access::sample> lutTexture, sampler lutSamper, float index, float x) {
    return lutTexture.sample(lutSamper, float2(x, (index + 0.5)/lutTexture.get_height())).r;
}

fragment half4 enhanceColorLookupFragmentShader(RasterizerData in [[stage_in]],
                                                texture2d<half, access::sample> sourceTexture [[texture(0)]],
                                                texture2d<half, access::sample> lutTexture [[texture(1)]],
                                                constant float2 & tileGridSize [[ buffer(0) ]],
                                                constant float & intensity [[ buffer(1) ]]
                                                )
{
    constexpr sampler colorSampler(min_filter::linear, mag_filter::linear, address::clamp_to_zero);
    constexpr sampler lutSampler(min_filter::linear, mag_filter::linear, address::clamp_to_zero);
    
    float2 sourceCoord = in.texCoord;
    half4 color = sourceTexture.sample(colorSampler,sourceCoord);
    half3 hslColor = rgbToHsl(color.rgb);
    
    float txf = sourceCoord.x * tileGridSize.x - 0.5;
    
    float tx1 = floor(txf);
    float tx2 = tx1 + 1.0;
    
    float xa_p = txf - tx1;
    float xa1_p = 1.0 - xa_p;
    
    tx1 = max(tx1, 0.0);
    tx2 = min(tx2, tileGridSize.x - 1.0);
    
    float tyf = sourceCoord.y * tileGridSize.y - 0.5;
    
    float ty1 = floor(tyf);
    float ty2 = ty1 + 1.0;
    
    float ya = tyf - ty1;
    float ya1 = 1.0 - ya;
    
    ty1 = max(ty1, 0.0);
    ty2 = min(ty2, tileGridSize.y - 1.0);
    
    float srcVal = hslColor.b;
    float x = (srcVal * 255.0 + 0.5) / lutTexture.get_width();
    
    half lutPlane1_ind1 = CLAHELookup(lutTexture, lutSampler, ty1 * tileGridSize.x + tx1, x);
    half lutPlane1_ind2 = CLAHELookup(lutTexture, lutSampler, ty1 * tileGridSize.x + tx2, x);
    half lutPlane2_ind1 = CLAHELookup(lutTexture, lutSampler, ty2 * tileGridSize.x + tx1, x);
    half lutPlane2_ind2 = CLAHELookup(lutTexture, lutSampler, ty2 * tileGridSize.x + tx2, x);
    
    half res = (lutPlane1_ind1 * xa1_p + lutPlane1_ind2 * xa_p) * ya1 + (lutPlane2_ind1 * xa1_p + lutPlane2_ind2 * xa_p) * ya;
    
    half3 r = half3(hslColor.r, min(1.0, hslColor.g * 1.25), min(1.0, res * 1.1));
    half3 rgbResult = hslToRgb(r);
    return half4(mix(color.rgb, rgbResult, half(intensity)), color.a);
}
