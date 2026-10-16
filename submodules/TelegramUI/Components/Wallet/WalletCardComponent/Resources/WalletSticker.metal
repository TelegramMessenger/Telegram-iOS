#include <metal_stdlib>
using namespace metal;
struct StickerVertex { float4 position [[position]]; float2 uv; };
vertex StickerVertex walletStickerVertex(constant float4 &rect [[buffer(0)]], uint id [[vertex_id]]) {
    const float2 points[4] = { float2(-1, 1), float2(-1, -1), float2(1, 1), float2(1, -1) };
    const float2 uv[4] = { float2(0, 0), float2(0, 1), float2(1, 0), float2(1, 1) };
    float2 placement = rect.xy + (points[id] * 0.5 + 0.5) * rect.zw;
    return {float4(-1.0 + placement * 2.0, 0, 1), uv[id]};
}
struct StickerUniforms { float4 frame; float4 effect; };



// Наклейка отрывается и ложится волной. Поперёк неё — линия сгиба: выше
// неё наклейка лежит, ниже — приподнята. У сгиба она загибается дугой до
// угла `angle`, дальше идёт прямо. Глаз — над серединой наклейки: поднятая
// часть ближе к нему и крупнее, к свету сверху повёрнута — светлее, на
// загибе ловит блик плёнки. Под поднятой частью на поверхность ложится её
// тень: чем выше над поверхностью, тем дальше и мягче.
//
// `frame`: угол наклейки в слое (x, y), её сторона (z) и высота слоя (w) —
// вокруг наклейки поля под рост и тень. `front` — линия сгиба, доля
// стороны от верха: отрыв гонит её снизу вверх, приклеивание — сверху
// вниз. `shadow` — сила тени поднятой части.

// Точка поднятой части в `t` от сгиба (по самой наклейке): её сдвиг вдоль
// поверхности и высота над ней.
static float2 stickerArc(float t, float angle, float curl) {
    float r = curl / max(angle, 0.001);
    if (t <= curl) {
        float a = t / r;
        return float2(r * sin(a), r * (1.0 - cos(a)));
    }
    return float2(r * sin(angle), r * (1.0 - cos(angle))) + (t - curl) * float2(cos(angle), sin(angle));
}

fragment half4 walletStickerFragment(StickerVertex in [[stage_in]],
    texture2d<half> layer [[texture(0)]], texture2d<half> art [[texture(1)]], constant StickerUniforms &u [[buffer(0)]]) {
    constexpr sampler sampleFilter(coord::normalized, address::clamp_to_zero, filter::linear);
    float4 frame = u.frame;
    float front = u.effect.x, angle = u.effect.y, shadow = u.effect.z;
    float2 position = in.uv * frame.w;
    #define stickerSample(p) mix(art.sample(sampleFilter, p), layer.sample(sampleFilter, p), half(u.effect.w))
    float side = frame.z;
    float hinge = frame.y + front * side;
    if (position.y <= hinge || angle <= 0.0005) return stickerSample((position - frame.xy) / frame.z);

    float2 center = frame.xy + 0.5 * side;
    float camera = 2.8 * side;
    float curl = 0.3 * side;
    float reach = max(frame.w - hinge, 0.0);
    float2 tip = stickerArc(reach, angle, curl);

    // Поднятая часть: какая её точка видна здесь. Экранная высота растёт
    // вместе с `t` — ищу делением пополам.
    half4 color = half4(0.0h);
    float tipY = center.y + (hinge + tip.x - center.y) * camera / (camera - tip.y);
    if (position.y <= tipY) {
        float lo = 0.0, hi = reach;
        for (int i = 0; i < 18; i++) {
            float mid = 0.5 * (lo + hi);
            float2 a = stickerArc(mid, angle, curl);
            float y = center.y + (hinge + a.x - center.y) * camera / (camera - a.y);
            if (y < position.y) { lo = mid; } else { hi = mid; }
        }
        float t = 0.5 * (lo + hi);
        float2 a = stickerArc(t, angle, curl);
        float m = camera / (camera - a.y);
        color = stickerSample((float2(center.x + (position.x - center.x) / m, hinge + t) - frame.xy) / frame.z);
        float theta = angle * min(t / curl, 1.0);
        float lambert = (0.45 * sin(theta) + 0.89 * cos(theta)) / 0.89;
        float gloss = exp(-pow((theta - 0.26) / 0.09, 2.0)) * smoothstep(0.2, 0.4, angle) * 0.5;
        color.rgb = half3(min(float3(color.rgb) * lambert + gloss * float(color.a), float3(color.a)));
    }

    // Тень: точка `t` поднятой части бросает её на поверхность ниже себя —
    // на k её высот. Размыта тем сильнее, чем выше точка.
    if (shadow > 0.001) {
        const float k = 0.5;
        if (position.y < hinge + tip.x + k * tip.y) {
            float lo = 0.0, hi = reach;
            for (int i = 0; i < 18; i++) {
                float mid = 0.5 * (lo + hi);
                float2 a = stickerArc(mid, angle, curl);
                if (hinge + a.x + k * a.y < position.y) { lo = mid; } else { hi = mid; }
            }
            float t = 0.5 * (lo + hi);
            float z = stickerArc(t, angle, curl).y;
            float blur = 0.5 + 0.16 * z;
            // Размытие — отсчёты по спирали, повёрнутой на каждом пикселе
            // по-своему: ровный край без ступенек и двоения.
            float spin = 6.2831853 * fract(52.9829189 * fract(dot(position * 3.0, float2(0.06711056, 0.00583715))));
            float alpha = 0.0;
            for (int i = 0; i < 16; i++) {
                float r = sqrt((float(i) + 0.5) / 16.0) * blur;
                float a = float(i) * 2.3999632 + spin;
                alpha += float(stickerSample((float2(position.x, hinge + t) + r * float2(cos(a), sin(a)) - frame.xy) / frame.z).a);
            }
            alpha *= shadow * 0.5 / 16.0 * smoothstep(0.0, 4.0, z);
            color += (1.0h - color.a) * half4(0.0h, 0.0h, 0.0h, half(alpha));
        }
    }
    return color;
}
