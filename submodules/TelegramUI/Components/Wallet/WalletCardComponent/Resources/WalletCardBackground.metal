#include <metal_stdlib>
using namespace metal;

struct WalletCardVertexOutput {
    float4 position [[position]];
    float2 uv;
    // Back-to-front edge depth is 0...1; the face uses 2.
    float layer [[flat]];
};

struct WalletCardShaderUniforms {
    float time;
    float reflectionRotation;
    float highlightTiltX;
    float highlightTiltY;
    float cornerRadius;
    float2 surfaceTilt;
    float2 cardSize;
    float4 qrRect;
    float4 qrEffects;
};

struct WalletCardLens {
    float2 center;
    float strength;
    float spin;
    int count;
    float4 bounds;
};

static inline float2 walletCardLensPoint(float2 position, constant WalletCardLens &lens,
                                       constant float2 *hull) {
    int n = lens.count;
    // Most of the card is outside the lens; avoid walking the hull for those pixels.
    if (n < 3 || lens.strength <= 0.001 || any(position < lens.bounds.xy) || any(position > lens.bounds.zw)) return position;
    bool inside = false;
    float best = 1e9;
    float radius = 0.0;
    for (int i = 0, j = n - 1; i < n; j = i++) {
        float2 a = hull[i];
        float2 b = hull[j];
        if (((a.y > position.y) != (b.y > position.y)) &&
            (position.x < (b.x - a.x) * (position.y - a.y) / (b.y - a.y) + a.x)) {
            inside = !inside;
        }
        float2 e = b - a;
        float h = clamp(dot(position - a, e) / max(dot(e, e), 1e-4), 0.0, 1.0);
        best = min(best, distance(position, a + e * h));
        radius = max(radius, distance(a, lens.center));
    }
    if (!inside) return position;
    float edge = smoothstep(0.0, 4.0, best) * lens.strength;
    float2 d = position - lens.center;
    float2 q = d / max(radius, 1.0);
    const float facet = M_PI_F / 4.0;
    float u = (asin(clamp(q.x, -0.999, 0.999)) - lens.spin) / facet;
    float wave = sin(M_PI_F * u);
    float prism = sign(wave) * pow(abs(wave), 0.6);
    float crown = 1.0 - smoothstep(-0.25, 0.05, q.y);
    float2 bend = float2(prism * 0.12, mix(-0.08 * q.y, 0.09, crown)) * radius;
    float zoom = mix(0.84, 0.72, crown * (1.0 - smoothstep(0.2, 0.6, abs(q.x))));
    return lens.center + d * mix(1.0, zoom, edge) + bend * edge;
}

struct WalletCardQuad {
    float4 bottomLeft;
    float4 bottomRight;
    float4 topLeft;
    float4 topRight;
};

struct WalletCardVertexUniforms {
    WalletCardQuad front;
    WalletCardQuad back;
    int slices;
};

static inline float walletRoundRect(float2 p, float2 halfSize, float r) {
    float2 q = abs(p) - (halfSize - r);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

static inline float2 walletRoundRectNormal(float2 p, float2 halfSize, float r) {
    float2 q = abs(p) - (halfSize - r);
    float2 n = (q.x > 0.0 && q.y > 0.0) ? normalize(q)
        : (q.x > q.y ? float2(1.0, 0.0) : float2(0.0, 1.0));
    return n * float2(p.x < 0.0 ? -1.0 : 1.0, p.y < 0.0 ? -1.0 : 1.0);
}

static inline float walletCardHash(float value) {
    return fract(sin(value * 127.1) * 43758.5453);
}

static inline float3 walletCardLinearToSrgb(float3 value) {
    value = max(value, float3(0.0));
    const float3 linear = value * 12.92;
    const float3 encoded = 1.055 * pow(value, float3(1.0 / 2.4)) - 0.055;
    return select(encoded, linear, value <= float3(0.0031308));
}

struct WalletCardStyle {
    float4 from0;   // старый цвет: оттенок, насыщенность, предел, темнота
    float4 from1;   // яркость края и середины фона, насыщенность тёмного, сдвиг яркости
    float4 to0;     // новый цвет — так же
    float4 to1;
    float4 wave;    // середина волны в пунктах карты, радиус, блик гребня
    float4 mode;    // x — старый не синий, y — новый не синий, z — растворение (< 0 — волна), w — яркость тёмной синей
    float4 stock;   // x — яркость светлой синей
};

static inline float3 walletSrgbToLinear(float3 c) {
    c = clamp(c, 0.0, 1.0);
    return select(pow((c + 0.055) / 1.055, float3(2.4)), c / 12.92, c <= float3(0.04045));
}

static inline float3 walletOklab(float3 srgb) {
    float3 lin = walletSrgbToLinear(srgb);
    float3 lms = float3(dot(lin, float3(0.4122214708, 0.5363325363, 0.0514459929)),
                        dot(lin, float3(0.2119034982, 0.6806995451, 0.1073969566)),
                        dot(lin, float3(0.0883024619, 0.2817188376, 0.6299787005)));
    lms = sign(lms) * pow(abs(lms), float3(1.0 / 3.0));
    return float3(dot(lms, float3(0.2104542553, 0.7936177850, -0.0040720468)),
                  dot(lms, float3(1.9779984951, -2.4285922050, 0.4505937099)),
                  dot(lms, float3(0.0259040371, 0.7827717662, -0.8086757660)));
}

static inline float3 walletOklchLinear(float l, float c, float h) {
    float a = c * cos(h), b = c * sin(h);
    float3 lms = float3(l + 0.3963377774 * a + 0.2158037573 * b,
                        l - 0.1055613458 * a - 0.0638541728 * b,
                        l - 0.0894841775 * a - 1.2914855480 * b);
    lms = lms * lms * lms;
    return float3(dot(lms, float3(4.0767416621, -3.3077115913, 0.2309699292)),
                  dot(lms, float3(-1.2684380046, 2.6097574011, -0.3413193965)),
                  dot(lms, float3(-0.0041960863, -0.7034186147, 1.7076147010)));
}

static inline float3 walletTint(float3 srgb, float4 p0, float4 p1, float stockDark, float stockLight) {
    float3 lab = walletOklab(srgb);
    float L = lab.x, C = length(lab.yz);
    float pos = clamp((L - stockDark) / max(stockLight - stockDark, 0.001), -2.0, 3.0);
    float own = p1.x - 0.02 + pos * (p1.y - p1.x);
    float l = clamp(L + (own - L) * p0.w + p1.w, 0.05, 0.97);
    float c = min(C * p0.y, p0.z * C / 0.173) * (1.0 - p0.w) + p1.z * p0.w;
    float3 lin = walletOklchLinear(l, c, p0.x);
    // Вне охвата — сбавляю насыщенность: яркость и оттенок те же.
    for (int i = 0; i < 12 && (any(lin < -0.001) || any(lin > 1.001)); i++) {
        c *= 0.85;
        lin = walletOklchLinear(l, c, p0.x);
    }
    return walletCardLinearToSrgb(clamp(lin, 0.0, 1.0));
}

// Цвет точки карты `p` (пункты от угла) в стиле этого кадра.
static inline float3 walletStyled(float3 srgb, float2 p, constant WalletCardStyle &s, bool material = false) {
    if (s.mode.x < 0.5 && s.mode.y < 0.5) return srgb;
    float inside;
    float dist = distance(p, s.wave.xy);
    if (s.mode.z >= 0.0) {
        inside = s.mode.z;
    } else {
        // Мягкий край волны — без резкой кромки.
        inside = 1.0 - smoothstep(s.wave.z - 18.0, s.wave.z, dist);
    }
    // The reference calibrates the blue material before tinting, but not the QR ring.
    float3 tintInput = material ? clamp(srgb * float3(1.05933, 0.912212, 0.968627), 0.0, 1.0) : srgb;
    float3 a = srgb, b = srgb;
    if (inside < 0.999 && s.mode.x > 0.5) a = walletTint(tintInput, s.from0, s.from1, s.mode.w, s.stock.x);
    if (inside > 0.001 && s.mode.y > 0.5) b = walletTint(tintInput, s.to0, s.to1, s.mode.w, s.stock.x);
    float3 color = mix(a, b, inside);
    // Гребень волны — тонкая светлая кромка, гаснет, пока волна доходит до краёв.
    if (s.mode.z < 0.0 && s.wave.w > 0.001) {
        const float width = 9.0;
        float rim = dist < s.wave.z ? smoothstep(s.wave.z - width, s.wave.z, dist)
                                    : 1.0 - smoothstep(s.wave.z, s.wave.z + width * 0.5, dist);
        color = mix(color, float3(1.0), 0.32 * s.wave.w * rim);
    }
    return color;
}

static inline float3 walletCardApplySaturation(float3 value) {
    const float luminance = dot(value, float3(0.2126, 0.7152, 0.0722));
    return clamp(mix(float3(luminance), value, 1.6), float3(0.0), float3(1.0));
}

// Moves a pale tinted color's hue toward the style hue, keeping its lightness and chroma.
static inline float3 walletHueShift(float3 srgb, float hue, float amount) {
    float3 lab = walletOklab(srgb);
    float C = length(lab.yz);
    float3 lin = walletOklchLinear(lab.x, C, hue);
    float3 shifted = walletCardLinearToSrgb(clamp(lin, 0.0, 1.0));
    return mix(srgb, shifted, amount);
}

static inline float3 walletHueStyled(float3 srgb, float2 p, constant WalletCardStyle &s, float amount) {
    if (s.mode.x < 0.5 && s.mode.y < 0.5) return srgb;
    float inside;
    if (s.mode.z >= 0.0) {
        inside = s.mode.z;
    } else {
        inside = 1.0 - smoothstep(s.wave.z - 18.0, s.wave.z, distance(p, s.wave.xy));
    }
    float3 a = s.mode.x > 0.5 ? walletHueShift(srgb, s.from0.x, amount) : srgb;
    float3 b = s.mode.y > 0.5 ? walletHueShift(srgb, s.to0.x, amount) : srgb;
    return mix(a, b, inside);
}

// Premultiplied chip and socket, in the reference's 50 x 38 point coordinates.
static inline float4 walletCardQRChip(float2 cp, float2 surface, float time,
                                     texture2d<float> noiseMap, texture2d<float> qrMap,
                                     float2 stylePoint, constant WalletCardStyle &style) {
    constexpr sampler cardSampler(filter::linear, address::clamp_to_edge);
    constexpr sampler noiseSampler(filter::linear, address::repeat);
    const float2 center = float2(293.5, 101.0);
    const float2 halfSize = float2(25.0, 19.0);
    const float radius = 9.0;
    float2 local = cp - center;
    float d = walletRoundRect(local, halfSize, radius);
    float aa = max(0.6 * fwidth(d), 0.001);
    float socket = (1.0 - smoothstep(0.0, 1.2, d)) * step(0.0, d) * 0.10;
    if (d >= 2.0) return float4(0.0, 0.0, 0.0, socket);

    float2 q = local / halfSize;
    float horizon = 0.10 + 0.55 * surface.y - 0.18 * surface.x;
    float sky = 1.0 - smoothstep(horizon - 0.55, horizon + 0.85, q.y + 0.18 * q.x);
    float3 metal = mix(float3(0.66, 0.78, 0.93), float3(0.955, 0.975, 1.0), sky);
    float brush = noiseMap.sample(noiseSampler, cp * float2(0.012, 1.4)).r;
    float brushFine = noiseMap.sample(noiseSampler, cp * float2(0.03, 3.1)).r;
    float grain = (brush - 0.5) * 0.020 + (brushFine - 0.5) * 0.014;
    metal *= 1.0 + grain;

    float slide = 0.10 + 0.95 * surface.x - 0.55 * surface.y + 0.12 * sin(time * 0.45);
    float across = dot(q, normalize(float2(1.0, -0.45)));
    float soft = exp(-pow((across - slide) / 0.55, 2.0));
    float sharp = exp(-pow((across - slide) / 0.10, 2.0));
    metal = mix(metal, float3(1.0), soft * 0.22 + sharp * (0.30 + grain * 6.0));

    float inner = walletRoundRect(local, halfSize - 1.0, radius - 1.0);
    float2 n = walletRoundRectNormal(local, halfSize - 1.0, radius - 1.0);
    float2 light = normalize(float2(-0.55 - 0.7 * surface.x, -0.85 + 0.6 * surface.y));
    float fresnel = smoothstep(-5.0, 0.0, inner);
    metal = mix(metal, float3(0.98, 0.99, 1.0), fresnel * 0.18);
    float chamfer = smoothstep(-1.3, -0.1, inner);
    metal -= chamfer * dot(n, light) * 0.12;
    metal = walletHueStyled(clamp(metal, 0.0, 1.0), stylePoint, style, 0.7);

    float2 qrUV = (cp - float2(282.5, 90.0)) / 22.0;
    float ink = qrMap.sample(cardSampler, qrUV).a;
    float lip = qrMap.sample(cardSampler, qrUV - float2(0.0, 1.0 / 22.0)).a;
    float upper = qrMap.sample(cardSampler, qrUV + float2(0.0, 0.55 / 22.0)).a;
    metal = mix(metal, float3(0.90, 0.93, 0.96), lip * (1.0 - ink));
    float3 inkColor = float3(0.459, 0.486, 0.514);
    inkColor = mix(inkColor * 0.80, inkColor, upper);
    metal = mix(metal, inkColor, ink);

    float ringMask = smoothstep(-1.0 - aa, -1.0 + aa, d);
    float3 ring = float3(0.047, 0.451, 0.835) * (0.92 + 0.16 * dot(n, light));
    ring = walletStyled(ring, stylePoint, style);
    float3 chip = mix(clamp(metal, 0.0, 1.0), ring, ringMask);
    float cover = 1.0 - smoothstep(-aa, aa, d);
    return float4(chip * cover, cover + socket * (1.0 - cover));
}

struct WalletChipVertex {
    float4 position [[position]];
    float2 uv;
};

vertex WalletChipVertex walletChipVertex(uint id [[vertex_id]]) {
    float2 uv = float2((id << 1) & 2, id & 2);
    return { float4(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0, 0.0, 1.0), uv };
}

fragment float4 walletChipFragment(WalletChipVertex input [[stage_in]],
    constant WalletCardShaderUniforms &uniforms [[buffer(0)]],
    constant WalletCardStyle &style [[buffer(1)]],
    constant float4 &rect [[buffer(2)]],
    texture2d<float> noiseMap [[texture(0)]], texture2d<float> qrMap [[texture(1)]]) {
    float2 point = rect.xy + input.uv * rect.zw;
    float2 scale = uniforms.qrRect.zw / float2(50.0, 38.0);
    float2 cp = (point - uniforms.qrRect.xy) / scale + float2(268.5, 82.0);
    float2 surface = clamp(float2(uniforms.surfaceTilt.y / 0.30, uniforms.surfaceTilt.x / 0.20),
        float2(-1.0), float2(1.0));
    return walletCardQRChip(cp, surface, uniforms.time, noiseMap, qrMap, point, style);
}

kernel void walletChipBlur(texture2d<float, access::read> source [[texture(0)]],
    texture2d<float, access::write> target [[texture(1)]],
    constant float &sigma [[buffer(0)]], constant int2 &direction [[buffer(1)]],
    uint2 position [[thread_position_in_grid]]) {
    if (position.x >= target.get_width() || position.y >= target.get_height()) return;
    int radius = int(ceil(3.0 * sigma));
    float4 result = float4(0.0);
    float total = 0.0;
    for (int i = -radius; i <= radius; i++) {
        float weight = exp(-0.5 * float(i * i) / max(sigma * sigma, 0.0001));
        int2 p = int2(position) + direction * i;
        if (all(p >= int2(0)) && p.x < int(source.get_width()) && p.y < int(source.get_height())) {
            result += source.read(uint2(p)) * weight;
        }
        total += weight;
    }
    target.write(result / total, position);
}

vertex WalletCardVertexOutput walletCardBackgroundVertex(
    constant float4 &rect [[buffer(0)]],
    constant WalletCardVertexUniforms &uniforms [[buffer(1)]],
    constant float4 &antialiasingParameters [[buffer(2)]],
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]]
) {
    const int slices = max(uniforms.slices, 0);
    const bool face = int(instanceID) >= slices;
    const float depth = face ? 1.0 : float(instanceID) / float(max(slices - 1, 1));
    const float4 positions[] = {
        mix(uniforms.back.bottomLeft, uniforms.front.bottomLeft, depth),
        mix(uniforms.back.bottomRight, uniforms.front.bottomRight, depth),
        mix(uniforms.back.topLeft, uniforms.front.topLeft, depth),
        mix(uniforms.back.topRight, uniforms.front.topRight, depth),
    };
    const float2 textureCoordinates[] = {
        float2(0.0, 1.0),
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(1.0, 0.0),
    };
    const float2 cornerDirections[] = {
        float2(-1.0, -1.0),
        float2(1.0, -1.0),
        float2(-1.0, 1.0),
        float2(1.0, 1.0),
    };

    WalletCardVertexOutput output;
    float4 localPosition = positions[vertexID];
    float2 localNdc = localPosition.xy / localPosition.w;
    const float edgeInsetPixels = 2.0;
    const float2 renderPixelSize = max(antialiasingParameters.xy, float2(1.0));
    const float2 cardPixelSize = max(antialiasingParameters.zw, float2(1.0));
    const float2 cornerDirection = cornerDirections[vertexID];
    localNdc += cornerDirection * edgeInsetPixels * 2.0 / renderPixelSize;
    float2 placementPosition = rect.xy + (localNdc * 0.5 + 0.5) * rect.zw;
    float2 placementClip = -1.0 + placementPosition * 2.0;
    output.position = float4(placementClip * localPosition.w, 0.0, localPosition.w);
    output.uv = textureCoordinates[vertexID]
        + float2(cornerDirection.x, -cornerDirection.y)
            * edgeInsetPixels / cardPixelSize;
    output.layer = face ? 2.0 : depth;
    return output;
}

fragment float4 walletCardBackgroundFragment(
    WalletCardVertexOutput input [[stage_in]],
    constant WalletCardShaderUniforms &uniforms [[buffer(0)]],
    constant WalletCardLens &lens [[buffer(1)]],
    constant float2 *hull [[buffer(2)]],
    constant WalletCardStyle &style [[buffer(3)]],
    texture2d<float> starsMap [[texture(0)]],
    texture2d<float> noiseMap [[texture(1)]],
    texture2d<float> qrMap [[texture(2)]],
    texture2d<float> blurredChip [[texture(3)]],
    constant float4 &chipTextureRect [[buffer(4)]]
) {
    constexpr sampler cardSampler(filter::linear, address::clamp_to_edge);
    constexpr sampler noiseSampler(filter::linear, address::repeat);

    float safeWidth = max(uniforms.cardSize.x, 1.0);
    float safeHeight = max(uniforms.cardSize.y, 1.0);
    float2 cardHalf = float2(safeWidth, safeHeight) * 0.5;
    float cardRadius = min(uniforms.cornerRadius, min(cardHalf.x, cardHalf.y));
    float2 surface = clamp(float2(uniforms.surfaceTilt.y / 0.30, uniforms.surfaceTilt.x / 0.20),
                           float2(-1.0), float2(1.0));

    // Edge instances never evaluate the face's material, lens or chip.
    if (input.layer < 1.5) {
        float t = input.layer;
        float2 p = input.uv * float2(safeWidth, safeHeight) - cardHalf;
        float d = walletRoundRect(p, cardHalf, cardRadius);
        if (d < -9.0) discard_fragment();
        float aa = max(0.5 * fwidth(d), 0.001);
        float cover = 1.0 - smoothstep(-aa, aa, d);
        float2 n = walletRoundRectNormal(p, cardHalf, cardRadius);
        float diffuse = 0.5 + 0.5 * dot(n, normalize(float2(-0.35, -1.0)));
        float lines = 1.0 + (walletCardHash(floor(t * 9.0) + 3.1) - 0.5) * 0.05;
        float3 edge = float3(0.014, 0.085, 0.40) * (0.62 + 0.62 * diffuse) * lines;
        float2 along = float2(-n.y, n.x);
        float run = dot(p, along) / max(cardHalf.x, 1.0);
        float streak = exp(-pow((run - (surface.x * 0.9 - surface.y * 0.7)) / 0.38, 2.0));
        edge += float3(0.30, 0.62, 1.0) * streak * 0.18 * (0.35 + 0.65 * diffuse);
        edge += float3(0.30, 0.62, 1.0) * step(0.88, t) * (0.18 + 0.40 * diffuse);
        float3 edgeColor = clamp(walletCardApplySaturation(walletCardLinearToSrgb(edge))
            * float3(1.05933, 0.912212, 0.968627), 0.0, 1.0);
        edgeColor = walletStyled(edgeColor, p + cardHalf, style, true);
        return float4(edgeColor * cover, cover);
    }
    float2 uv = walletCardLensPoint(input.uv * float2(safeWidth, safeHeight), lens, hull)
        / float2(safeWidth, safeHeight);

    float2 cardPosition = float2(
        (uv.x - 0.5) * 2.0,
        (0.5 - uv.y) * 2.0 * safeHeight / safeWidth
    );
    float radius = length(cardPosition);
    float centerFade = smoothstep(0.018, 0.090, radius);
    float2 radial = radius > 0.0001 ? cardPosition / radius : float2(1.0, 0.0);
    float2 tangent = float2(-radial.y, radial.x);

    constexpr float radialFrequencyScale = 0.65;
    constexpr float finishDetail = 0.05;
    float ringFrequency = 180.0 * radialFrequencyScale;
    float waveFrequency = 560.0 * radialFrequencyScale;
    float ringIndex = floor(radius * ringFrequency);
    float2 radialDerivatives = float2(dfdx(radius), dfdy(radius));
    float radialFootprint = length(radialDerivatives) * radialFrequencyScale;
    float ringFilter = 1.0 - smoothstep(0.35, 1.10, radialFootprint * 180.0);
    float waveFilter = 1.0 - smoothstep(1.15, 3.10, radialFootprint * 560.0);
    float fineFinish = mix(0.5, walletCardHash(ringIndex), ringFilter)
        + 0.35 * sin(
            radius * waveFrequency
                + walletCardHash(ringIndex * 0.37) * 6.2831853072
        ) * waveFilter;
    constexpr float finishVisibility = 0.5;
    float radialFinish = (fineFinish - 0.5)
        * finishDetail
        * finishVisibility
        * centerFade;

    float colorBlend = clamp(0.30 + uv.y * 0.50 + uv.x * 0.18, 0.0, 1.0);
    colorBlend = colorBlend * colorBlend * (3.0 - 2.0 * colorBlend);
    // Match Wallet/CardChatGradient's deep blue base and brighter azure reflections.
    // These linear values are encoded and saturated below before presentation.
    float3 gradient = mix(
        float3(0.025, 0.140, 0.885),
        float3(0.038, 0.180, 0.955),
        colorBlend
    );

    float brushedGrain = noiseMap.sample(noiseSampler, uv * float2(1.4, 8.0)).r;
    float mediumGrain = noiseMap.sample(noiseSampler, uv * float2(4.0, 3.0)).r;
    float fineGrain = noiseMap.sample(noiseSampler, uv * float2(19.0, 13.0)).r;
    float materialVariation =
        radialFinish * 0.48
        + (brushedGrain - 0.5) * 0.035
        + (mediumGrain - 0.5) * 0.035
        + (fineGrain - 0.5) * 0.018;
    gradient *= 1.0 + materialVariation;

    float2 normalizedTilt = clamp(
        float2(
            uniforms.highlightTiltY / 0.24,
            uniforms.highlightTiltX / 0.17
        ),
        float2(-1.0),
        float2(1.0)
    );
    float2 idleDiagonal = float2(1.0, -safeHeight / safeWidth);
    float2 idleDirection = normalize(idleDiagonal);
    float2 idlePerpendicular = float2(-idleDirection.y, idleDirection.x);
    float2 tiltDirection = float2(-normalizedTilt.x, -normalizedTilt.y);
    float rotationTurn = clamp(
        dot(tiltDirection, idlePerpendicular)
            / max(abs(idlePerpendicular.y), 0.0001),
        -1.0,
        1.0
    );
    // Device rotation is clockwise in UIKit; this material uses an upward Y axis.
    float reflectionAngle = rotationTurn * 1.5707963268 - uniforms.reflectionRotation;
    float sineAngle = sin(reflectionAngle);
    float cosineAngle = cos(reflectionAngle);
    float2 keyDirection = float2(
        idleDirection.x * cosineAngle - idleDirection.y * sineAngle,
        idleDirection.x * sineAngle + idleDirection.y * cosineAngle
    );
    float tangentAlignment = dot(tangent, keyDirection);
    float roughnessNoise =
        radialFinish * 0.18
        + (brushedGrain - 0.5) * 0.025
        + (mediumGrain - 0.5) * 0.025;
    float roughness = clamp(0.20 + roughnessNoise, 0.13, 0.30);
    float wedgeWidth = mix(0.30, 0.44, (roughness - 0.13) / 0.17);
    float reflectionCenterProgress = clamp(
        radius / 0.275,
        0.0,
        1.0
    );
    float reflectionCenterCurve = reflectionCenterProgress
        * reflectionCenterProgress
        * reflectionCenterProgress
        * (reflectionCenterProgress
            * (reflectionCenterProgress * 6.0 - 15.0)
            + 10.0);
    float reflectionCenterFade = mix(0.10, 1.0, reflectionCenterCurve);
    float coreWedge = exp(
        -(tangentAlignment * tangentAlignment)
            / max(2.0 * wedgeWidth * wedgeWidth, 0.0001)
    );
    float haloWidth = wedgeWidth * 1.70;
    float haloWedge = exp(
        -(tangentAlignment * tangentAlignment)
            / max(2.0 * haloWidth * haloWidth, 0.0001)
    );
    float radialWedge = mix(coreWedge, haloWedge, 0.42) * reflectionCenterFade;
    float signedLobe = dot(radial, keyDirection);
    float lobeBalance = mix(0.72, 1.0, 0.5 + 0.5 * signedLobe);
    float fibreReflection = smoothstep(0.47, 0.86, brushedGrain) * 0.58
        + smoothstep(0.56, 0.91, mediumGrain) * 0.42;
    float ringReflection = clamp(
        0.78 + radialFinish * 2.4 + fibreReflection * 0.28,
        0.42,
        1.30
    );
    float studioReflection = radialWedge * lobeBalance * ringReflection;
    constexpr float3 cyanReflection = float3(0.090, 0.565, 0.965);
    gradient += cyanReflection * studioReflection * 0.32;

    float2 normalizedSurfaceTilt = clamp(
        float2(
            uniforms.surfaceTilt.y / 0.24,
            uniforms.surfaceTilt.x / 0.17
        ),
        float2(-1.0),
        float2(1.0)
    );
    constexpr float starDepthPoints = 4.0;
    float2 inverseCardSize = 1.0 / float2(safeWidth, safeHeight);
    float2 starParallax = float2(
        normalizedSurfaceTilt.x,
        -normalizedSurfaceTilt.y
    ) * starDepthPoints * inverseCardSize;
    float4 star = starsMap.sample(cardSampler, uv + starParallax);
    float starPhase = star.g / max(star.a, 0.001);
    float twinkle = 0.6 + 0.4 * sin(uniforms.time * 1.7 + starPhase * 6.28318);
    float highlightCoverage = smoothstep(0.16, 0.58, radialWedge * lobeBalance);
    float starAlpha = 0.5
        * star.a
        * (0.72 + 0.28 * colorBlend)
        * twinkle
        * highlightCoverage;
    float3 lifted = select(
        sqrt(gradient),
        ((16.0 * gradient - 12.0) * gradient + 4.0) * gradient,
        gradient <= float3(0.25)
    );
    gradient = mix(gradient, lifted, starAlpha);
    float3 spark = float3(0.55, 0.8, 1.0)
        * starAlpha * starAlpha * (0.4 + 0.4 * colorBlend);

    gradient += (fineGrain - 0.5) * 0.014;
    gradient *= 1.0 - 0.14 * smoothstep(0.965, 1.0, uv.y);

    if (uniforms.qrEffects.z > 0.0) {
        float2 p = input.uv * float2(safeWidth, safeHeight) - cardHalf;
        float d = walletRoundRect(p, cardHalf, cardRadius);
        float2 n = walletRoundRectNormal(p, cardHalf, cardRadius);
        float band = smoothstep(-1.1, -0.35, d);
        float2 light = normalize(float2(-0.45 - 0.9 * surface.x, -0.9 + 0.7 * surface.y));
        gradient += float3(0.10, 0.36, 0.85) * band * (0.03 + 0.26 * max(dot(n, light), 0.0));
    }

    float2 halfSize = float2(safeWidth, safeHeight) * 0.5;
    float radiusPoints = min(uniforms.cornerRadius, min(halfSize.x, halfSize.y));
    float2 roundedPoint = abs(input.uv * float2(safeWidth, safeHeight) - halfSize)
        - (halfSize - radiusPoints);
    float roundedDistance = length(max(roundedPoint, 0.0))
        + min(max(roundedPoint.x, roundedPoint.y), 0.0)
        - radiusPoints;
    const float edgeWidth = max(0.5 * fwidth(roundedDistance), 0.001);
    float coverage = 1.0 - smoothstep(-edgeWidth, edgeWidth, roundedDistance);

    // MetalEngine renders into a bgra8Unorm IOSurface. The reference renderer
    // used an sRGB drawable, so encode the linear material color explicitly.
    float3 outputColor = walletCardApplySaturation(
        walletCardLinearToSrgb(gradient + spark)
    );
    outputColor = walletStyled(outputColor, input.uv * float2(safeWidth, safeHeight), style, true);
    if (uniforms.qrEffects.x > 0.0 && all(uniforms.qrRect.zw > 0.0)) {
        float2 position = uv * float2(safeWidth, safeHeight);
        float2 chipScale = uniforms.qrRect.zw / float2(50.0, 38.0);
        bool hasBlur = chipTextureRect.z > 0.0;
        float2 margin = hasBlur ? (chipTextureRect.zw - uniforms.qrRect.zw) * 0.5 : chipScale * 2.0;
        if (all(position >= uniforms.qrRect.xy - margin)
            && all(position <= uniforms.qrRect.xy + uniforms.qrRect.zw + margin)) {
            float4 chip;
            if (hasBlur) {
                constexpr sampler chipSampler(filter::linear, address::clamp_to_zero);
                chip = blurredChip.sample(chipSampler, (position - chipTextureRect.xy) / chipTextureRect.zw);
            } else {
                float2 cp = (position - uniforms.qrRect.xy) / chipScale + float2(268.5, 82.0);
                chip = walletCardQRChip(cp, surface, uniforms.time, noiseMap, qrMap, input.uv * float2(safeWidth, safeHeight), style);
            }
            chip *= uniforms.qrEffects.x;
            outputColor = outputColor * (1.0 - chip.a) + chip.rgb;
        }
    }
    return float4(outputColor * coverage, coverage);
}
