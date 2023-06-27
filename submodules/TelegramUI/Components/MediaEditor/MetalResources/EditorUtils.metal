#include <metal_stdlib>
#include "EditorUtils.h"

using namespace metal;

half getLuma(half3 color) {
    return (0.299 * color.r) + (0.587 * color.g) + (0.114 * color.b);
}

half3 rgbToHsv(half3 c) {
    half4 K = half4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    half4 p = c.g < c.b ? half4(c.bg, K.wz) : half4(c.gb, K.xy);
    half4 q = c.r < p.x ? half4(p.xyw, c.r) : half4(c.r, p.yzx);
    half d = q.x - min(q.w, q.y);
    half e = 1.0e-10;
    return half3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

half3 hsvToRgb(half3 c) {
    half4 K = half4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    half3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

half3 rgbToHsl(half3 color) {
    half3 hsl;
    half fMin = min(min(color.r, color.g), color.b);
    half fMax = max(max(color.r, color.g), color.b);
    half delta = fMax - fMin;
    hsl.z = (fMax + fMin) / 2.0;
    if (delta == 0.0) {
        hsl.x = 0.0;
        hsl.y = 0.0;
    } else {
        if (hsl.z < 0.5) {
            hsl.y = delta / (fMax + fMin);
        } else {
            hsl.y = delta / (2.0 - fMax - fMin);
        }
        half deltaR = (((fMax - color.r) / 6.0) + (delta / 2.0)) / delta;
        half deltaG = (((fMax - color.g) / 6.0) + (delta / 2.0)) / delta;
        half deltaB = (((fMax - color.b) / 6.0) + (delta / 2.0)) / delta;
        if (color.r == fMax) {
            hsl.x = deltaB - deltaG;
        } else if (color.g == fMax) {
            hsl.x = (1.0 / 3.0) + deltaR - deltaB;
        } else if (color.b == fMax) {
            hsl.x = (2.0 / 3.0) + deltaG - deltaR;
        }
        if (hsl.x < 0.0) {
            hsl.x += 1.0;
        } else if (hsl.x > 1.0) {
            hsl.x -= 1.0;
        }
    }
    return hsl;
}

half hueToRgb(half f1, half f2, half hue) {
    if (hue < 0.0) {
        hue += 1.0;
    } else if (hue > 1.0) {
        hue -= 1.0;
    }
    half res;
    if ((6.0 * hue) < 1.0) {
        res = f1 + (f2 - f1) * 6.0 * hue;
    } else if ((2.0 * hue) < 1.0) {
        res = f2;
    } else if ((3.0 * hue) < 2.0) {
        res = f1 + (f2 - f1) * ((2.0 / 3.0) - hue) * 6.0;
    } else {
        res = f1;
    }
    return res;
}

half3 hslToRgb(half3 hsl) {
    half3 rgb;
    if (hsl.y == 0.0) {
        rgb = half3(hsl.z);
    } else {
        half f2;
        if (hsl.z < 0.5) {
            f2 = hsl.z * (1.0 + hsl.y);
        } else {
            f2 = (hsl.z + hsl.y) - (hsl.y * hsl.z);
        }
        half f1 = 2.0 * hsl.z - f2;
        rgb.r = hueToRgb(f1, f2, hsl.x + (1.0 / 3.0));
        rgb.g = hueToRgb(f1, f2, hsl.x);
        rgb.b = hueToRgb(f1, f2, hsl.x - (1.0 / 3.0));
    }
    return rgb;
}

half3 rgbToYuv(half3 inP) {
    half3 outP;
    outP.r = getLuma(inP);
    outP.g = (1.0 / 1.772) * (inP.b - outP.r);
    outP.b = (1.0 / 1.402) * (inP.r - outP.r);
    return outP;
}

half3 yuvToRgb(half3 inP) {
    float y = inP.r;
    float u = inP.g;
    float v = inP.b;
    half3 outP;
    outP.r = 1.402 * v + y;
    outP.g = (y - (0.299 * 1.402 / 0.587) * v - (0.114 * 1.772 / 0.587) * u);
    outP.b = 1.772 * u + y;
    return outP;
}

half easeInOutSigmoid(half value, half strength) {
    float t = 1.0 / (1.0 - strength);
    if (value > 0.5) {
        return 1.0 - pow(2.0 - 2.0 * value, t) * 0.5;
    } else {
        return pow(2.0 * value, t) * 0.5;
    }
}

half powerCurve(half inVal, half mag) {
    half outVal;
    float power = 1.0 + abs(mag);
    if (mag > 0.0) {
        power = 1.0 / power;
    }
    inVal = 1.0 - inVal;
    outVal = pow((1.0 - inVal), power);
    return outVal;
}

float4 rnm(float2 tc) {
    float noise = sin(dot(tc, float2(12.9898, 78.233))) * 43758.5453;
    
    float noiseR = fract(noise) * 2.0-1.0;
    float noiseG = fract(noise * 1.2154) * 2.0-1.0;
    float noiseB = fract(noise * 1.3453) * 2.0-1.0;
    float noiseA = fract(noise * 1.3647) * 2.0-1.0;
    
    return float4(noiseR,noiseG,noiseB,noiseA);
}

float fade(float t) {
    return t*t*t*(t*(t*6.0-15.0)+10.0);
}

float pnoise3D(float3 p) {
    const half permTexUnit = 1.0 / 256.0;
    const half permTexUnitHalf = 0.5 / 256.0;
    
    float3 pi = permTexUnit * floor(p) + permTexUnitHalf;
    float3 pf = fract(p);
    
    // Noise contributions from (x=0, y=0), z=0 and z=1
    float perm00 = rnm(pi.xy).a ;
    float3  grad000 = rnm(float2(perm00, pi.z)).rgb * 4.0 - 1.0;
    float n000 = dot(grad000, pf);
    float3  grad001 = rnm(float2(perm00, pi.z + permTexUnit)).rgb * 4.0 - 1.0;
    float n001 = dot(grad001, pf - float3(0.0, 0.0, 1.0));
    
    // Noise contributions from (x=0, y=1), z=0 and z=1
    float perm01 = rnm(pi.xy + float2(0.0, permTexUnit)).a ;
    float3  grad010 = rnm(float2(perm01, pi.z)).rgb * 4.0 - 1.0;
    float n010 = dot(grad010, pf - float3(0.0, 1.0, 0.0));
    float3  grad011 = rnm(float2(perm01, pi.z + permTexUnit)).rgb * 4.0 - 1.0;
    float n011 = dot(grad011, pf - float3(0.0, 1.0, 1.0));
    
    // Noise contributions from (x=1, y=0), z=0 and z=1
    float perm10 = rnm(pi.xy + float2(permTexUnit, 0.0)).a ;
    float3  grad100 = rnm(float2(perm10, pi.z)).rgb * 4.0 - 1.0;
    float n100 = dot(grad100, pf - float3(1.0, 0.0, 0.0));
    float3  grad101 = rnm(float2(perm10, pi.z + permTexUnit)).rgb * 4.0 - 1.0;
    float n101 = dot(grad101, pf - float3(1.0, 0.0, 1.0));
    
    // Noise contributions from (x=1, y=1), z=0 and z=1
    float perm11 = rnm(pi.xy + float2(permTexUnit, permTexUnit)).a ;
    float3  grad110 = rnm(float2(perm11, pi.z)).rgb * 4.0 - 1.0;
    float n110 = dot(grad110, pf - float3(1.0, 1.0, 0.0));
    float3  grad111 = rnm(float2(perm11, pi.z + permTexUnit)).rgb * 4.0 - 1.0;
    float n111 = dot(grad111, pf - float3(1.0, 1.0, 1.0));
    
    // Blend contributions along x
    float4 n_x = mix(float4(n000, n001, n010, n011), float4(n100, n101, n110, n111), fade(pf.x));
    
    // Blend contributions along y
    float2 n_xy = mix(n_x.xy, n_x.zw, fade(pf.y));
    
    // Blend contributions along z
    float n_xyz = mix(n_xy.x, n_xy.y, fade(pf.z));
    
    return n_xyz;
}

float2 coordRot(float2 tc, float angle) {
  float rotX = ((tc.x * 2.0 - 1.0) * cos(angle)) - ((tc.y * 2.0 - 1.0) * sin(angle));
  float rotY = ((tc.y * 2.0 - 1.0) * cos(angle)) + ((tc.x * 2.0 - 1.0) * sin(angle));
  rotX = rotX * 0.5 + 0.5;
  rotY = rotY * 0.5 + 0.5;
  return float2(rotX, rotY);
}
