#include <metal_stdlib>
using namespace metal;

#define EPS 1e-4
#define EPS2 1e-4
#define NEAR 1.0
#define FAR 10.0
#define NEAR2 0.02
#define ITER 96
#define ITER2 48
#define RI1 2.40
#define RI2 2.44
#define PI 3.14159265359

float3 hsv(float h, float s, float v) {
    float3 k = float3(1.0, 2.0 / 3.0, 1.0 / 3.0);
    float3 p = abs(fract(h + k.xyz) * 6.0 - 3.0);
    return v * mix(float3(1.0), clamp(p - 1.0, 0.0, 1.0), s);
}

float2x2 rot(float a) {
    float s = sin(a), c = cos(a);
    return float2x2(c, s, -s, c);
}

float sdTable(float3 p) {
    float2 d = abs(float2(length(p.xz), (p.y + 0.159) * 1.650)) - float2(1.0);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

float sdCut(float3 p, float a, float h) {
    p.y *= a;
    p.y -= (abs(p.x) + abs(p.z)) * h;
    p = abs(p);
    return (p.x + p.y + p.z - 1.0) * 0.5;
}

constant float2x2 ROT4 = float2x2(0.70710678, 0.70710678, -0.70710678, 0.70710678);
constant float2x2 ROT3 = float2x2(0.92387953, 0.38268343, -0.38268343, 0.92387953);
constant float2x2 ROT2 = float2x2(0.38268343, 0.92387953, -0.92387953, 0.38268343);
constant float2x2 ROT1 = float2x2(0.19509032, 0.98078528, -0.98078528, 0.19509032);

float map(float3 p, float time, float3 cameraRotation) {
    p.y *= 0.72;
    
    p.yz = p.yz;
    p.xz = rot(time * 0.45) * p.xz;

    float d = sdTable(p);

    float3 q = p * 0.3000;
    q.y += 0.0808;
    q.xz = ROT2 * q.xz;
    q.xz = abs(q.xz);
    q.xz = ROT4 * q.xz;
    q.xz = abs(q.xz);
    q.xz = ROT2 * q.xz;
    d = max(d, sdCut(q, 3.700, 0.0000));

    q = p * 0.691;
    q.xz = abs(q.xz);
    q.xz = ROT4 * q.xz;
    q.xz = abs(q.xz);
    q.xz = ROT2 * q.xz;
    d = max(d, sdCut(q, 1.868, 0.1744));

    q *= 1.022;
    q.y -= 0.034;
    q.xz = ROT1 * q.xz;
    d = max(d, sdCut(q, 1.650, 0.1000));
    q.xz = ROT3 * q.xz;
    d = max(d, sdCut(q, 1.650, 0.1000));

    return d;
}

float3 normal(float3 p, float time, float3 cameraRotation) {
    float2 e = float2(EPS, 0);
    return normalize(float3(
        map(p + e.xyy, time, cameraRotation) - map(p - e.xyy, time, cameraRotation),
        map(p + e.yxy, time, cameraRotation) - map(p - e.yxy, time, cameraRotation),
        map(p + e.yyx, time, cameraRotation) - map(p - e.yyx, time, cameraRotation)
    ));
}

float trace(float3 ro, float3 rd, thread float3 &p, thread float3 &n, float time, float3 cameraRotation) {
    float t = NEAR, d;
    for (int i = 0; i < ITER; i++) {
        p = ro + rd * t;
        d = map(p, time, cameraRotation);
        if (abs(d) < EPS || t > FAR) break;
        t += step(d, 1.0) * d * 0.5 + d * 0.5;
    }
    n = normal(p, time, cameraRotation);
    return min(t, FAR);
}

float trace2(float3 ro, float3 rd, thread float3 &p, thread float3 &n, float time, float3 cameraRotation) {
    float t = NEAR2, d;
    for (int i = 0; i < ITER2; i++) {
        p = ro + rd * t;
        d = -map(p, time, cameraRotation);
        if (abs(d) < EPS2 || d < EPS2) break;
        t += d;
    }
    n = -normal(p, time, cameraRotation);
    return t;
}

float schlickFresnel(float ri, float co) {
    float r = (1.0 - ri) / (1.0 + ri);
    r = r * r;
    return r + (1.0 - r) * pow(1.0 - co, 5.0);
}

float3 lightPath(float3 p, float3 rd, float ri, float time, float3 cameraRotation) {
    float3 n;
    float3 r0 = -rd;
    trace2(p, rd, p, n, time, cameraRotation);
    rd = reflect(rd, n);
    float3 r1 = refract(rd, n, ri);
    r1 = length(r1) < EPS ? r0 : r1;
    trace2(p, rd, p, n, time, cameraRotation);
    rd = reflect(rd, n);
    float3 r2 = refract(rd, n, ri);
    r2 = length(r2) < EPS ? r1 : r2;
    trace2(p, rd, p, n, time, cameraRotation);
    float3 r3 = refract(rd, n, ri);
    return length(r3) < EPS ? r2 : r3;
}

float3 material(float3 p, float3 rd, float3 n, texturecube<float> cubemap, float time, float3 cameraRotation) {
    float3 l0 = reflect(rd, n);
    float co = max(0.0, dot(-rd, n));
    float f1 = schlickFresnel(RI1, co);
    float3 l1 = lightPath(p, refract(rd, n, 1.0 / RI1), RI1, time, cameraRotation);
    float f2 = schlickFresnel(RI2, co);
    float3 l2 = lightPath(p, refract(rd, n, 1.0 / RI2), RI2, time, cameraRotation);
    
    float a = 0.0;
    float3 dc = float3(0.0);
    float3 r = cubemap.sample(sampler(mag_filter::linear, min_filter::linear), l0).rgb;
    
    for (int i = 0; i < 10; i++) {
        float3 l = normalize(mix(l1, l2, a));
        float f = mix(f1, f2, a);
        dc += cubemap.sample(sampler(mag_filter::linear, min_filter::linear), l).rgb * hsv(a + 0.9, 1.0, 1.0) * (1.0 - f) + r * f;
        a += 0.1;
    }
    dc *= 0.19;
            
    return dc;
}

kernel void compute_main(texture2d<float, access::write> outputTexture [[texture(0)]],
                        texturecube<float> cubemap [[texture(1)]],
                        constant float &iTime [[buffer(0)]],
                        constant float2 &iResolution [[buffer(1)]],
                        constant float3 &cameraRotation [[buffer(2)]],
                        uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= uint(iResolution.x) || gid.y >= uint(iResolution.y)) {
        return;
    }
    
    float2 fragCoord = float2(gid.x, gid.y);
    float2 uv = (fragCoord - 0.5 * iResolution) / iResolution.y;
    
    float3 ro = float3(0.0, 0.0, -4.0);
    float3 rd = normalize(float3(uv, 1.1));

    float2x2 ry = rot(cameraRotation.y); // Yaw
    ro.yz = ry * ro.yz;
    rd.yz = ry * rd.yz;

    float2x2 rx = rot(cameraRotation.x); // Pitch
    ro.xz = rx * ro.xz;
    rd.xz = rx * rd.xz;

    float2x2 rz = rot(0.0); // cameraRotation.z); // Roll
    ro.xy = rz * ro.xy;
    rd.xy = rz * rd.xy;

    float3 p, n;
    float t = trace(ro, rd, p, n, iTime, cameraRotation);

    float3 c = float3(0.0);
    float w = 0.0;
    if (t > 9.0) {
        c = float3(1.0, 0.0, 0.0);
        //c = cubemap.sample(sampler(mag_filter::linear, min_filter::linear), rd).rgb;
    } else {
        c = material(p, rd, n, cubemap, iTime, cameraRotation);
        w = smoothstep(1.60, 1.61, length(c));
    }
    
    outputTexture.write(float4(c, w), gid);
}

#define POST_ITER 36.0
#define RADIUS 0.05

struct QuadVertexOut {
    float4 position [[position]];
    float2 uv;
};

constant static float2 quadVertices[6] = {
    float2(0.0, 0.0),
    float2(1.0, 0.0),
    float2(0.0, 1.0),
    float2(1.0, 0.0),
    float2(0.0, 1.0),
    float2(1.0, 1.0)
};

vertex QuadVertexOut post_vertex_main(
    constant float4 &rect [[ buffer(0) ]],
    uint vid [[ vertex_id ]]
) {
    float2 quadVertex = quadVertices[vid];
    
    QuadVertexOut out;
    out.position = float4(rect.x + quadVertex.x * rect.z, rect.y + quadVertex.y * rect.w, 0.0, 1.0);
    out.position.x = -1.0 + out.position.x * 2.0;
    out.position.y = -1.0 + out.position.y * 2.0;
    
    out.uv = quadVertex;

    return out;
}

fragment float4 post_fragment_main(QuadVertexOut in [[stage_in]],
                                   constant float &iTime [[buffer(0)]],
                                   constant float2 &iResolution [[buffer(1)]],
                                   texture2d<float> inputTexture [[texture(0)]]) {
    
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);
    
    float2 uv = in.uv;
    float2 m = float2(1.0, iResolution.x / iResolution.y);
    
    float4 co = inputTexture.sample(textureSampler, uv);
    float4 c = co;
    
    float a = sin(iTime * 0.1) * 6.283;
    float v = 0.0;
    float b = 1.0 / POST_ITER;
    
    for (int j = 0; j < 6; j++) {
        float r = RADIUS / POST_ITER;
        float2 d = float2(cos(a), sin(a)) * m;
        
        for (int i = 0; i < int(POST_ITER); i++) {
            float4 sample = inputTexture.sample(textureSampler, uv + d * r * RADIUS);
            v += sample.w * (1.0 - r);
            r += b;
        }
        a += 1.047;
    }
    
    v *= 0.01;
    c += float4(v, v, v, 0.0);
    c.w = 1.0;
    if (co.r == 1.0 && co.g == 0.0 && co.b == 0.0) {
        c.w = 0.0;
    } else {
        c.w = 1.0;
    }
        
    return c;
}
