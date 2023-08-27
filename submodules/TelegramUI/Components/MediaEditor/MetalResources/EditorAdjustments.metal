#include <metal_stdlib>
#include "EditorCommon.h"
#include "EditorUtils.h"

using namespace metal;

typedef struct {
    float2      dimensions;
    float       aspectRatio;
    float       shadows;
    float       highlights;
    float       contrast;
    float       fade;
    float       saturation;
    float       shadowsTintIntensity;
    float3      shadowsTintColor;
    float       highlightsTintIntensity;
    float3      highlightsTintColor;
    float       exposure;
    float       warmth;
    float       grain;
    float       vignette;
    float       hasCurves;
    float2      empty;
} MediaEditorAdjustments;

half3 fade(half3 color, float fadeAmount) {
    half3 comp1 = half3(-0.9772) * half3(pow(float3(color), float3(3.0)));
    half3 comp2 = half3(1.708) * half3(pow(float3(color), float3(2.0)));
    half3 comp3 = half3(-0.1603) * color;
    half3 comp4 = half3(0.2878);
    half3 finalComponent = comp1 + comp2 + comp3 + comp4;
    half3 difference = finalComponent - color;
    half3 scalingValue = half3(0.9);
    half3 faded = color + (difference * scalingValue);
    return (color * (1.0 - fadeAmount)) + (faded * fadeAmount);
}

float3 tintRaiseShadowsCurve(half3 color) {
    float3 comp1 = float3(-0.003671) * pow(float3(color), float3(3.0));
    float3 comp2 = float3(0.3842) * pow(float3(color), float3(2.0));
    float3 comp3 = float3(0.3764) * float3(color);
    float3 comp4 = float3(0.2515);
    return comp1 + comp2 + comp3 + comp4;
}

half3 tintShadows(half3 color, float3 tintColor, float tintAmount) {
    float3 raisedShadows = tintRaiseShadowsCurve(color);
    float3 tintedShadows = mix(float3(color), raisedShadows, tintColor);
    float3 tintedShadowsWithAmount = mix(float3(color), tintedShadows, tintAmount);
    return half3(clamp(tintedShadowsWithAmount, 0.0, 1.0));
}

half3 tintHighlights(half3 color, float3 tintColor, float tintAmount) {
    float3 loweredHighlights = float3(1.0) - tintRaiseShadowsCurve(half3(1.0) - color);
    float3 tintedHighlights = mix(float3(color), loweredHighlights, (float3(1.0) - tintColor));
    float3 tintedHighlightsWithAmount = mix(float3(color), tintedHighlights, tintAmount);
    return half3(clamp(tintedHighlightsWithAmount, 0.0, 1.0));
}

half3 applyLuminanceCurve(half3 pixel, constant float allCurve[200]) {
    int index = int(clamp(pixel.z / (1.0 / 200.0), 0.0, 199.0));
    float value = allCurve[index];

    float grayscale = (smoothstep(0.0, 0.1, float(pixel.z)) * (1.0 - smoothstep(0.8, 1.0, float(pixel.z))));
    half saturation = mix(0.0, float(pixel.y), grayscale);
    pixel.y = saturation;
    pixel.z = value;
    return pixel;
}

half3 applyRGBCurve(half3 pixel, constant float redCurve[200], constant float greenCurve[200], constant float blueCurve[200]) {
    int index = int(clamp(pixel.r / (1.0 / 200.0), 0.0, 199.0));
    float value = redCurve[index];
    pixel.r = value;

    index = int(clamp(pixel.g / (1.0 / 200.0), 0.0, 199.0));
    value = greenCurve[index];
    pixel.g = clamp(value, 0.0, 1.0);

    index = int(clamp(pixel.b / (1.0 / 200.0), 0.0, 199.0));
    value = blueCurve[index];
    pixel.b = clamp(value, 0.0, 1.0);

    return pixel;
}

fragment half4 adjustmentsFragmentShader(RasterizerData in [[stage_in]],
                                          texture2d<half, access::sample> sourceImage [[texture(0)]],
                                          constant MediaEditorAdjustments& adjustments [[buffer(0)]],
                                         constant float allCurve [[buffer(1)]][200],
                                         constant float redCurve [[buffer(2)]][200],
                                         constant float greenCurve [[buffer(3)]][200],
                                         constant float blueCurve [[buffer(4)]][200]
                                         ) {
    constexpr sampler samplr(filter::linear, mag_filter::linear, min_filter::linear);
    const float epsilon = 0.005;
    
    half4 source = sourceImage.sample(samplr, float2(in.texCoord.x, in.texCoord.y));
    half4 result = source;
        
    if (adjustments.hasCurves > epsilon) {
        result = half4(applyRGBCurve(hslToRgb(applyLuminanceCurve(rgbToHsl(result.rgb), allCurve)), redCurve, greenCurve, blueCurve), result.a);
    }
    
    if (abs(adjustments.highlights) > epsilon || abs(adjustments.shadows) > epsilon) {
        const float3 hsLuminanceWeighting = float3(0.3, 0.3, 0.3);
        float mappedHighlights = adjustments.highlights * 0.75 + 1.0;
        float mappedShadows = adjustments.shadows * 0.55 + 1.0;
        
        float hsLuminance = dot(float3(result.rgb), hsLuminanceWeighting);
        float shadow = clamp((pow(hsLuminance, 1.0 / mappedShadows) - 0.76 * pow(hsLuminance, 2.0 / mappedShadows)) - hsLuminance, 0.0, 1.0);
        float highlight = clamp((1.0 - (pow(1.0 - hsLuminance, 1.0 / (2.0 - mappedHighlights)) - 0.8 * pow(1.0 - hsLuminance, 2.0 / (2.0 - mappedHighlights)))) - hsLuminance, -1.0, 0.0);
        float3 hsResult = float3(0.0, 0.0, 0.0) + ((hsLuminance + shadow + highlight) - 0.0) * ((float3(result.rgb) - float3(0.0, 0.0, 0.0)) / (hsLuminance - 0.0));
        
        float contrastedLuminance = ((hsLuminance - 0.5) * 1.5) + 0.5;
        float whiteInterp = contrastedLuminance * contrastedLuminance * contrastedLuminance;
        half whiteTarget = clamp(mappedHighlights, 1.0, 2.0) - 1.0;
        hsResult = mix(hsResult, float3(1.0), whiteInterp * whiteTarget);
        float invContrastedLuminance = 1.0 - contrastedLuminance;
        float blackInterp = invContrastedLuminance * invContrastedLuminance * invContrastedLuminance;
        half blackTarget = 1.0 - clamp(mappedShadows, 0.0, 1.0);
        
        result.rgb = half3(mix(hsResult, float3(0.0), blackInterp * blackTarget));
    }
    
    if (abs(adjustments.contrast) > epsilon) {
        half mappedContrast = half(adjustments.contrast) * 0.3 + 1.0;
        result.rgb = clamp(((result.rgb - half3(0.5)) * mappedContrast + half3(0.5)), 0.0, 1.0);
    }
    
    if (abs(adjustments.fade) > epsilon) {
        result.rgb = fade(result.rgb, adjustments.fade);
    }
    
    if (abs(adjustments.saturation) > epsilon) {
        float mappedSaturation = adjustments.saturation;
        if (mappedSaturation > 0.0) {
            mappedSaturation *= 1.05;
        }
        mappedSaturation += 1.0;
        half satLuminance = dot(result.rgb, half3(0.2126, 0.7152, 0.0722));
        half3 greyScaleColor = half3(satLuminance);
        result.rgb = clamp(mix(greyScaleColor, result.rgb, mappedSaturation), 0.0, 1.0);
    }
    
    if (abs(adjustments.shadowsTintIntensity) > epsilon) {
        result.rgb = tintShadows(result.rgb, adjustments.shadowsTintColor, adjustments.shadowsTintIntensity * 2.0);
    }

    if (abs(adjustments.highlightsTintIntensity) > epsilon) {
        result.rgb = tintHighlights(result.rgb, adjustments.highlightsTintColor, adjustments.highlightsTintIntensity * 2.0);
    }
    
    if (abs(adjustments.exposure) > epsilon) {
        float mag = adjustments.exposure * 1.045;
        float power = 1.0 + abs(mag);
        if (mag < 0.0) {
            power = 1.0 / power;
        }
        result.r = 1.0 - pow((1.0 - result.r), power);
        result.g = 1.0 - pow((1.0 - result.g), power);
        result.b = 1.0 - pow((1.0 - result.b), power);
    }
    
    if (abs(adjustments.warmth) > epsilon) {
        half3 yuvVector;
        if (adjustments.warmth > 0.0) {
            yuvVector = half3(0.1765, -0.1255, 0.0902);
        } else {
            yuvVector = -half3(0.0588, 0.1569, -0.1255);
        }
        half3 yuvColor = rgbToYuv(result.rgb);
        half luma = yuvColor.r;
        half curveScale = sin(luma * 3.14159);
        yuvColor += 0.375 * adjustments.warmth * curveScale * yuvVector;
        result.rgb = yuvToRgb(yuvColor);
    }
    
    if (abs(adjustments.vignette) > epsilon) {
        const float midpoint = 0.7;
        const float fuzziness = 0.62;
        float radDist = length(in.texCoord - 0.5) / sqrt(0.5);
        float mag = easeInOutSigmoid(radDist * midpoint, fuzziness) * adjustments.vignette * 0.645;
        result.rgb = half3(mix(pow(float3(result.rgb), float3(1.0 / (1.0 - mag))), float3(0.0), mag * mag));
    }
    
    if (abs(adjustments.grain) > epsilon) {
        const float grainSize = 2.3;
        float3 rotOffset = float3(1.425, 3.892, 5.835);
        float2 rotCoordsR = coordRot(in.texCoord, rotOffset.x);
        half3 noise = half3(pnoise3D(float3(rotCoordsR * float2(adjustments.dimensions.x / grainSize, adjustments.dimensions.y / grainSize), 0.0)));
        
        half3 lumcoeff = half3(0.299, 0.587, 0.114);
        float luminance = dot(result.rgb, lumcoeff);
        float lum = smoothstep(0.2, 0.0, luminance);
        lum += luminance;
        
        noise = mix(noise, half3(0.0), pow(lum, 4.0));
        result.rgb = result.rgb + noise * adjustments.grain * 0.04;
    }
    
    return result;
}
