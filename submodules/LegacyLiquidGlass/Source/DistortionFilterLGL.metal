#include <metal_stdlib>
#include <CoreImage/CoreImage.h>

using namespace metal;

extern "C" {
    namespace coreimage {
        float2 distortionLGL(
            sampler src,
            destination dest,
            float2 center,
            float radius,
            float intensity
        ) {
            float2 uv = dest.coord();
            float2 d = uv - center;
            float distance = length(d);

            if (distance > radius) {
                return uv;
            }

            float t = distance / radius;

            float mirrorEffect = 1.0 - t;
            float wave = intensity * 5.0 * sin(mirrorEffect * 20.0) * mirrorEffect;

            float newDistance = distance * (1.0 + wave * 0.1);

            newDistance = min(newDistance, radius);

            float2 direction = normalize(d);
            float2 distortedUV = center + direction * newDistance;

            return distortedUV;
        }
    }
}
