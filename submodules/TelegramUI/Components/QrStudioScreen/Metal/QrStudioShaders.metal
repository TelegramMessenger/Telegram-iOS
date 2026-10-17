#include <metal_stdlib>

using namespace metal;

struct QrRect {
    float2 origin;
    float2 size;
};

struct QrMeshVertexOut {
    float4 position [[position]];
    float3 lab;
};

constant static int qrMeshSegments = 48;

constant static int qrMeshCorners[6] = {0, 1, 2, 1, 2, 3};

static float3 qrSpline3(float3 p0, float3 p1, float3 p2, float t) {
    float u = clamp(t, 0.0, 1.0) * 2.0;
    float3 m0 = p1 - p0;
    float3 m1 = (p2 - p0) * 0.5;
    float3 m2 = p2 - p1;
    float3 a = p0;
    float3 b = p1;
    float3 ma = m0;
    float3 mb = m1;
    if (u >= 1.0) {
        a = p1;
        b = p2;
        ma = m1;
        mb = m2;
        u -= 1.0;
    }
    float u2 = u * u;
    float u3 = u2 * u;
    return (2.0 * u3 - 3.0 * u2 + 1.0) * a + (u3 - 2.0 * u2 + u) * ma + (-2.0 * u3 + 3.0 * u2) * b + (u3 - u2) * mb;
}

static float3 qrSurface(const device float4 *values, float s, float t) {
    float3 r0 = qrSpline3(values[0].xyz, values[1].xyz, values[2].xyz, s);
    float3 r1 = qrSpline3(values[3].xyz, values[4].xyz, values[5].xyz, s);
    float3 r2 = qrSpline3(values[6].xyz, values[7].xyz, values[8].xyz, s);
    return qrSpline3(r0, r1, r2, t);
}

static float3 qrOklabToSrgb(float3 lab) {
    float l = lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z;
    float m = lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z;
    float s = lab.x - 0.0894841775 * lab.y - 1.2914855480 * lab.z;
    l = l * l * l;
    m = m * m * m;
    s = s * s * s;
    float3 linear = float3(
        4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    );
    linear = clamp(linear, 0.0, 1.0);
    float3 low = linear * 12.92;
    float3 high = 1.055 * pow(linear, float3(1.0 / 2.4)) - 0.055;
    return mix(high, low, step(linear, float3(0.0031308)));
}

vertex QrMeshVertexOut qrMeshVertex(
    const device QrRect &rect [[ buffer(0) ]],
    const device float4 *points [[ buffer(1) ]],
    const device float4 *colors [[ buffer(2) ]],
    unsigned int vid [[ vertex_id ]]
) {
    int quad = int(vid) / 6;
    int corner = qrMeshCorners[int(vid) % 6];
    int qx = quad % qrMeshSegments;
    int qy = quad / qrMeshSegments;
    float s = float(qx + (corner & 1)) / float(qrMeshSegments);
    float t = float(qy + (corner >> 1)) / float(qrMeshSegments);

    float3 point = qrSurface(points, s, t);
    QrMeshVertexOut out;
    float2 position = rect.origin + float2(point.x, 1.0 - point.y) * rect.size;
    out.position = float4(position.x * 2.0 - 1.0, position.y * 2.0 - 1.0, 0.0, 1.0);
    out.lab = qrSurface(colors, s, t);
    return out;
}

fragment half4 qrMeshFragment(QrMeshVertexOut in [[stage_in]]) {
    float3 color = qrOklabToSrgb(in.lab);
    float noise = fract(sin(dot(in.position.xy, float2(12.9898, 78.233))) * 43758.5453);
    color += (noise - 0.5) / 255.0;
    return half4(half3(color), 1.0h);
}

constant static float2 qrQuadVertices[6] = {
    float2(0.0, 0.0),
    float2(1.0, 0.0),
    float2(0.0, 1.0),
    float2(1.0, 0.0),
    float2(0.0, 1.0),
    float2(1.0, 1.0)
};

struct QrGiftUniforms {
    float4 patternColor;
    float4 lightColor;
    float2 size;
    float2 revealCenter;
    float time;
    float since;
    float bandAt;
    float bandStrength;
};

struct QrGiftInstance {
    float2 position;
    float side;
    float rotation;
    float alpha;
    float hash;
};

struct QrGiftSymbolOut {
    float4 position [[position]];
    float2 uv;
    float alpha;
    float shine;
};

vertex QrGiftSymbolOut qrGiftSymbolVertex(
    const device QrRect &rect [[ buffer(0) ]],
    const device QrGiftUniforms &uniforms [[ buffer(1) ]],
    const device QrGiftInstance *instances [[ buffer(2) ]],
    unsigned int vid [[ vertex_id ]],
    unsigned int iid [[ instance_id ]]
) {
    QrGiftInstance instance = instances[iid];
    float h = instance.hash;
    float h2 = fract(h * 7.31);
    float twinkle = pow(0.5 + 0.5 * sin(uniforms.time * (0.35 + 0.55 * h2) + h * 6.283), 2.0);
    float across = instance.position.x / max(uniforms.size.x, 1.0) * 0.55 + instance.position.y / max(uniforms.size.y, 1.0) * 0.45;
    float band = uniforms.bandStrength * exp(-pow((across - uniforms.bandAt) / 0.11, 2.0));
    float d = distance(instance.position, uniforms.revealCenter);
    float u = (uniforms.since - d / 620.0 - 0.18) / 0.14;
    float shine = min(1.0, band + exp(-u * u));

    float side = instance.side * (1.0 + 0.35 * shine + 0.1 * twinkle);
    float2 quad = qrQuadVertices[vid];
    float2 local = (quad - 0.5) * side;
    float c = cos(instance.rotation);
    float s = sin(instance.rotation);
    float2 point = instance.position + float2(local.x * c - local.y * s, local.x * s + local.y * c);
    float2 unit = point / uniforms.size;

    QrGiftSymbolOut out;
    float2 position = rect.origin + float2(unit.x, 1.0 - unit.y) * rect.size;
    out.position = float4(position.x * 2.0 - 1.0, position.y * 2.0 - 1.0, 0.0, 1.0);
    out.uv = quad;
    out.alpha = instance.alpha * (0.55 + 0.45 * twinkle);
    out.shine = shine * instance.alpha;
    return out;
}

fragment half4 qrGiftSymbolFragment(
    QrGiftSymbolOut in [[stage_in]],
    const device QrGiftUniforms &uniforms [[ buffer(1) ]],
    const device float &textureMix [[ buffer(2) ]],
    texture2d<half> symbol [[ texture(0) ]],
    texture2d<half> placeholder [[ texture(1) ]]
) {
    constexpr sampler linearSampler(mag_filter::linear, min_filter::linear, mip_filter::linear);
    half mask = mix(placeholder.sample(linearSampler, in.uv).a, symbol.sample(linearSampler, in.uv).a, half(textureMix));
    half base = mask * half(in.alpha) * 0.42h;
    half3 color = half3(uniforms.patternColor.rgb) * base;
    half3 light = half3(uniforms.lightColor.rgb) * mask * half(in.shine) * 0.85h;
    return half4(color + light, base);
}

struct QrAshUniforms {
    float2 size;
    float2 origin;
    float unit;
    float since;
    float side;
    float fade;
    float4 tones[3];
};

struct QrAshParticle {
    float2 cell;
    float born;
    float seed;
};

struct QrAshOut {
    float4 position [[position]];
    float2 uv;
    float4 color;
    float glow;
};

static float qrAshHash(float seed, float salt) {
    return fract(sin(seed * 12.9898 + salt * 78.233) * 43758.5453);
}

vertex QrAshOut qrAshVertex(
    const device QrRect &rect [[ buffer(0) ]],
    const device QrAshUniforms &uniforms [[ buffer(1) ]],
    const device QrAshParticle *particles [[ buffer(2) ]],
    unsigned int vid [[ vertex_id ]],
    unsigned int iid [[ instance_id ]]
) {
    QrAshParticle particle = particles[iid];
    float seed = particle.seed;
    float kind = qrAshHash(seed, 10.0);
    bool spark = kind > 0.86;
    bool flake = !spark && kind < 0.12;
    float life = spark ? 0.4 + 0.35 * qrAshHash(seed, 3.0) : 0.42 + 0.4 * qrAshHash(seed, 3.0);
    float tau = uniforms.since - particle.born - qrAshHash(seed, 4.0) * 0.06;
    float k = tau / life;

    QrAshOut out;
    if (tau < 0.0 || k >= 1.0) {
        out.position = float4(-2.0, -2.0, 0.0, 1.0);
        out.uv = float2(0.0);
        out.color = float4(0.0);
        out.glow = 0.0;
        return out;
    }

    float2 start = (particle.cell + float2(qrAshHash(seed, 5.0), qrAshHash(seed, 6.0))) * uniforms.unit;
    float angle = -1.5707963 + (qrAshHash(seed, 7.0) - 0.5) * 3.6;
    float speedHash = qrAshHash(seed, 8.0);
    float speed = spark ? 480.0 + 520.0 * speedHash : (flake ? 120.0 + 160.0 * speedHash : 220.0 + 420.0 * speedHash);
    float drag = spark ? 2.0 : 2.7;
    float travel = speed * (1.0 - exp(-drag * tau)) / drag;
    float2 point = start + float2(cos(angle), sin(angle)) * travel;
    point.x += 3.0 * sin(7.0 * tau + 6.283 * qrAshHash(seed, 9.0)) * tau;
    point.y += 34.0 * tau * tau;

    float halfSide = uniforms.side * 0.5;
    float outside = max(abs(point.x - halfSide), abs(point.y - halfSide)) - halfSide;
    float edge = clamp((uniforms.origin.x - outside) / 40.0, 0.0, 1.0);

    float sizeHash = qrAshHash(seed, 2.0);
    float radius = (spark ? 0.9 + 0.7 * sizeHash : (flake ? 2.2 + 2.0 * sizeHash : 0.6 + 1.3 * sizeHash)) * (1.0 - 0.4 * k);
    float halo = (spark && k < 0.7) ? max(1.0, 3.4 * edge) : 1.0;
    float toneHash = qrAshHash(seed, 11.0);
    int tone = (spark || toneHash < 0.5) ? 0 : (toneHash < 0.72 ? 1 : 2);

    float2 quad = qrQuadVertices[vid];
    float2 local = (quad - 0.5) * 2.0 * radius * halo;
    float2 unit = (uniforms.origin + point + local) / uniforms.size;
    float2 position = rect.origin + float2(unit.x, 1.0 - unit.y) * rect.size;
    out.position = float4(position.x * 2.0 - 1.0, position.y * 2.0 - 1.0, 0.0, 1.0);
    out.uv = (quad - 0.5) * 2.0 * halo;
    out.color = float4(uniforms.tones[tone].rgb, pow(1.0 - k, 1.2) * edge);
    out.glow = halo > 1.0 ? 0.3 * uniforms.fade * edge : 0.0;
    return out;
}

fragment half4 qrAshFragment(QrAshOut in [[stage_in]]) {
    float d = length(in.uv);
    float core = 1.0 - smoothstep(0.85, 1.0, d);
    float halo = in.glow * (1.0 - smoothstep(1.0, 3.4, d));
    float alpha = in.color.a * core;
    float3 rgb = in.color.rgb * alpha + float3(halo);
    return half4(half3(rgb), half(alpha));
}
