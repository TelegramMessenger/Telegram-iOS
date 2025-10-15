#include <metal_stdlib>

#include "loki_header.metal"

using namespace metal;

struct Rectangle {
    float2 origin;
    float2 size;
};

constant static float2 quadVertices[6] = {
    float2(0.0, 0.0),
    float2(1.0, 0.0),
    float2(0.0, 1.0),
    float2(1.0, 0.0),
    float2(0.0, 1.0),
    float2(1.0, 1.0)
};

struct QuadVertexOut {
    float4 position [[position]];
    float2 uv;
    float alpha;
};

float2 mapLocalToScreenCoordinates(const device Rectangle &rect, const device float2 &size, float2 position) {
    float2 result = float2(rect.origin.x + position.x / size.x * rect.size.x, rect.origin.y + position.y / size.y * rect.size.y);
    result.x = -1.0 + result.x * 2.0;
    result.y = -1.0 + result.y * 2.0;
    
    return result;
}

struct Particle {
    packed_float2 offsetFromBasePosition;
    packed_float2 velocity;
    float lifetime;
};

kernel void dustEffectInitializeParticle(
    device Particle *particles [[ buffer(0) ]],
    uint gid [[ thread_position_in_grid ]]
) {
    Loki rng = Loki(gid);
    
    Particle particle;
    particle.offsetFromBasePosition = packed_float2(0.0, 0.0);
    
    float direction = rng.rand() * (3.14159265 * 2.0);
    float velocity = (0.1 + rng.rand() * (0.2 - 0.1)) * 420.0;
    particle.velocity = packed_float2(cos(direction) * velocity, sin(direction) * velocity);
    
    particle.lifetime = 0.7 + rng.rand() * (1.5 - 0.7);
    
    particles[gid] = particle;
}

float particleEaseInWindowFunction(float t) {
    return t;
}

float particleEaseInValueAt(float fraction, float t) {
    float windowSize = 0.8;

    float effectiveT = t;
    float windowStartOffset = -windowSize;
    float windowEndOffset = 1.0;

    float windowPosition = (1.0 - fraction) * windowStartOffset + fraction * windowEndOffset;
    float windowT = max(0.0, min(windowSize, effectiveT - windowPosition)) / windowSize;
    float localT = 1.0 - particleEaseInWindowFunction(windowT);

    return localT;
}

float2 grad(float2 z ) {
    // 2D to 1D  (feel free to replace by some other)
    int n = z.x + z.y * 11111.0;

    // Hugo Elias hash (feel free to replace by another one)
    n = (n << 13) ^ n;
    n = (n * (n * n * 15731 + 789221) + 1376312589) >> 16;

    // Perlin style vectors
    n &= 7;
    float2 gr = float2(n & 1, n >> 1) * 2.0 - 1.0;
    return ( n>=6 ) ? float2(0.0, gr.x) :
           ( n>=4 ) ? float2(gr.x, 0.0) :
                              gr;
}

float noise(float2 p ) {
    float2 i = float2(floor(p));
    float2 f = fract(p);
    
    float2 u = f*f*(3.0-2.0*f); // feel free to replace by a quintic smoothstep instead

    return mix( mix( dot( grad( i+float2(0,0) ), f-float2(0.0,0.0) ),
                     dot( grad( i+float2(1,0) ), f-float2(1.0,0.0) ), u.x),
                mix( dot( grad( i+float2(0,1) ), f-float2(0.0,1.0) ),
                     dot( grad( i+float2(1,1) ), f-float2(1.0,1.0) ), u.x), u.y);
}

kernel void dustEffectUpdateParticle(
    device Particle *particles [[ buffer(0) ]],
    const device uint2 &size [[ buffer(1) ]],
    const device float &phase [[ buffer(2) ]],
    const device float &timeStep [[ buffer(3) ]],
    uint gid [[ thread_position_in_grid ]]
) {
    uint count = size.x * size.y;
    if (gid >= count) {
        return;
    }
    
    constexpr float easeInDuration = 0.8;
    float effectFraction = max(0.0, min(easeInDuration, phase)) / easeInDuration;
    
    uint particleX = gid % size.x;
    float particleXFraction = float(particleX) / float(size.x);
    float particleFraction = particleEaseInValueAt(effectFraction, particleXFraction);
    
    Particle particle = particles[gid];
    particle.offsetFromBasePosition += (particle.velocity * timeStep) * particleFraction;
    
    particle.velocity += float2(0.0, timeStep * 120.0) * particleFraction;
    particle.lifetime = max(0.0, particle.lifetime - timeStep * particleFraction);
    particles[gid] = particle;
}

vertex QuadVertexOut dustEffectVertex(
    const device Rectangle &rect [[ buffer(0) ]],
    const device float2 &size [[ buffer(1) ]],
    const device uint2 &particleResolution [[ buffer(2) ]],
    const device Particle *particles [[ buffer(3) ]],
    unsigned int vid [[ vertex_id ]],
    unsigned int particleId [[ instance_id ]]
) {
    QuadVertexOut out;
    
    float2 quadVertex = quadVertices[vid];
    
    uint particleIndexX = particleId % particleResolution.x;
    uint particleIndexY = particleId / particleResolution.x;
    
    Particle particle = particles[particleId];
    
    float2 particleSize = size / float2(particleResolution);
    
    float2 topLeftPosition = float2(float(particleIndexX) * particleSize.x, float(particleIndexY) * particleSize.y);
    out.uv = (topLeftPosition + quadVertex * particleSize) / size;
    
    topLeftPosition += particle.offsetFromBasePosition;
    float2 position = topLeftPosition + quadVertex * particleSize;
    
    out.position = float4(mapLocalToScreenCoordinates(rect, size, position), 0.0, 1.0);
    out.alpha = max(0.0, min(0.3, particle.lifetime) / 0.3);
    
    return out;
}

fragment half4 dustEffectFragment(
    QuadVertexOut in [[stage_in]],
    texture2d<half, access::sample> inTexture [[ texture(0) ]]
) {
    constexpr sampler sampler(coord::normalized, address::clamp_to_edge, filter::linear);
    
    half4 color = inTexture.sample(sampler, float2(in.uv.x, 1.0 - in.uv.y));
    
    return color * in.alpha;
}
