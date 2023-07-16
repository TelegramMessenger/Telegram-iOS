#include <metal_stdlib>

#pragma once

half getLuma(half3 color);

half3 rgbToHsv(half3 c);

half3 hsvToRgb(half3 c);

half3 rgbToHsl(half3 color);

half hueToRgb(half f1, half f2, half hue);

half3 hslToRgb(half3 hsl);

half3 rgbToYuv(half3 inP);

half3 yuvToRgb(half3 inP);

half easeInOutSigmoid(half value, half strength);

half powerCurve(half inVal, half mag);

float pnoise3D(float3 p);
float2 coordRot(float2 tc, float angle);
