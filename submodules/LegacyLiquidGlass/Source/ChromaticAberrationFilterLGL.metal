#include <metal_stdlib>
#include <CoreImage/CoreImage.h>

using namespace metal;

extern "C" {
    namespace coreimage {
        float4 chromaticAberrationLGL(
            sampler src,
            coreimage::destination dest,
            float2 center,
            float radius,
            float redShiftX,
            float redShiftY,
            float greenShiftX,
            float greenShiftY,
            float blueShiftX,
            float blueShiftY
        ) {
            float2 uv = dest.coord();
            float2 offset = uv - center;
            float distance = length(offset);

            float strength = 0.0;
            if (distance > radius * 0.7) {
                strength = smoothstep(radius * 0.7, radius, distance);
            }

            float2 direction = normalize(offset);

            float2 perpendicular = float2(-direction.y, direction.x);

            float2 redUV = uv + perpendicular * float2(redShiftX, redShiftY) * strength;
            float2 greenUV = uv + direction * float2(greenShiftX, greenShiftY) * strength;
            float2 blueUV = uv - perpendicular * float2(blueShiftX, blueShiftY) * strength;

            float red = src.sample(redUV).r;
            float green = src.sample(greenUV).g;
            float blue = src.sample(blueUV).b;

            float alpha = src.sample(uv).a;

            return float4(red, green, blue, alpha);
        }
    }
}
