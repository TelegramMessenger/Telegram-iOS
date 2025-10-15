#include <metal_stdlib>

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
};

vertex QuadVertexOut callBackgroundVertex(
    const device Rectangle &rect [[ buffer(0) ]],
    unsigned int vid [[ vertex_id ]]
) {
    float2 quadVertex = quadVertices[vid];
    
    QuadVertexOut out;
    
    out.position = float4(rect.origin.x + quadVertex.x * rect.size.x, rect.origin.y + quadVertex.y * rect.size.y, 0.0, 1.0);
    out.position.x = -1.0 + out.position.x * 2.0;
    out.position.y = -1.0 + out.position.y * 2.0;
    
    out.uv = quadVertex;
    
    return out;
}

half4 rgb2hsv(half4 c) {
    half4 K = half4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    half4 p = mix(half4(c.bg, K.wz), half4(c.gb, K.xy), step(c.b, c.g));
    half4 q = mix(half4(p.xyw, c.r), half4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return half4(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x, c.a);
}

half4 hsv2rgb(half4 c) {
    half4 K = half4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    half3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return half4(c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y), c.a);
}

fragment half4 callBackgroundFragment(
    QuadVertexOut in [[stage_in]],
    const device float2 *positions [[ buffer(0) ]],
    const device float4 *colors [[ buffer(1) ]],
    const device float &brightness [[ buffer(2) ]],
    const device float &saturation [[ buffer(3) ]],
    const device float4 &overlay [[ buffer(4) ]]
) {
    half centerDistanceX = in.uv.x - 0.5;
    half centerDistanceY = in.uv.y - 0.5;
    half centerDistance = distance(half2(in.uv), half2(0.5, 0.5));
    half swirlFactor = 0.35 * centerDistance;
    half theta = swirlFactor * swirlFactor * 0.8 * 8.0;
    half sinTheta = sin(theta);
    half cosTheta = cos(theta);
    
    half pixelX = max(0.0, min(1.0, 0.5 + centerDistanceX * cosTheta - centerDistanceY * sinTheta));
    half pixelY = max(0.0, min(1.0, 0.5 + centerDistanceX * sinTheta + centerDistanceY * cosTheta));

    half distanceSum = 0.0;

    half r = 0.0;
    half g = 0.0;
    half b = 0.0;
    
    for (int i = 0; i < 4; i++) {
        half4 color = half4(colors[i]);
        
        half2 colorXY = half2(positions[i]);
        half2 distanceXY = half2(pixelX - colorXY.x, pixelY - colorXY.y);

        half distance = max(0.0, 0.92 - sqrt(distanceXY.x * distanceXY.x + distanceXY.y * distanceXY.y));
        distance = distance * distance * distance;
        distanceSum += distance;

        r = r + distance * color.r;
        g = g + distance * color.g;
        b = b + distance * color.b;
    }
    
    if (distanceSum < 0.00001) {
        distanceSum = 0.00001;
    }

    half pixelB = b / distanceSum;
    half pixelG = g / distanceSum;
    half pixelR = r / distanceSum;
    
    half4 color(pixelR, pixelG, pixelB, 1.0);
    color = rgb2hsv(color);
    color.b = clamp(color.b * brightness, 0.0, 1.0);
    color.g = clamp(color.g * saturation, 0.0, 1.0);
    color = hsv2rgb(color);
    color.rgb += half3(overlay.rgb * overlay.a);
    color.rgb = min(color.rgb, half3(1.0, 1.0, 1.0));
    
    return color;
}

struct BlobVertexOut {
    float4 position [[position]];
};

float2 blobVertex(float2 center, float angle, float radius) {
    return float2(center.x + radius * cos(angle), center.y + radius * sin(angle));
}

float2 mapPointInRect(Rectangle rect, half2 point) {
    half2 out(rect.origin.x + rect.size.x * point.x, rect.origin.y + rect.size.y * point.y);
    out.x = -1.0 + out.x * 2.0;
    out.y = -1.0 + out.y * 2.0;
    return float2(out);
}

struct SmoothPoint {
    half2 point;
    half inAngle;
    half inLength;
    half outAngle;
    half outLength;
    
    half2 smoothIn() {
        return smooth(inAngle, inLength);
    }
    
    half2 smoothOut() {
        return smooth(outAngle, outLength);
    }
    
private:
    half2 smooth(half angle, half length) {
        return half2(
            point.x + length * cos(angle),
            point.y + length * sin(angle)
        );
    }
};

half2 evaluateBlobPoint(const device Rectangle &rect, const device float *positions, int index, int count, int subdivisions) {
    float position = positions[index];
    float segmentAngle = float(index) / float(count) * 2.0 * 3.1415926;
    return half2(blobVertex(float2(0.5, 0.5), segmentAngle, 0.45 + 0.05 * position));
}

SmoothPoint evaluateSmoothBlobPoint(const device Rectangle &rect, const device float *positions, int index, int count, int subdivisions) {
    int prevIndex = (index - 1) < 0 ? (count - 1) : (index - 1);
    int nextIndex = (index + 1) % count;
    
    half2 prev = evaluateBlobPoint(rect, positions, prevIndex, count, subdivisions);
    half2 curr = evaluateBlobPoint(rect, positions, index, count, subdivisions);
    half2 next = evaluateBlobPoint(rect, positions, nextIndex, count, subdivisions);
    
    float dx = next.x - prev.x;
    float dy = -next.y + prev.y;
    float angle = atan2(dy, dx);
    if (angle < 0.0) {
        angle = abs(angle);
    } else {
        angle = 2 * 3.1415926 - angle;
    }
    
    float smoothAngle = (3.1415926 * 2.0) / float(count);
    float smoothness = ((4.0 / 3.0) * tan(smoothAngle / 4.0)) / sin(smoothAngle / 2.0) / 2.0;
    
    SmoothPoint point;
    point.point = curr;
    point.inAngle = angle + 3.1415926;
    point.inLength = smoothness * distance(curr, prev);
    point.outAngle = angle;
    point.outLength = smoothness * distance(curr, next);
    
    return point;
}

half2 evaluateBezierBlobPoint(thread SmoothPoint &curr, thread SmoothPoint &next, half t) {
    half oneMinusT = 1.0 - t;
    
    half2 p0 = curr.point;
    half2 p1 = curr.smoothOut();
    half2 p2 = next.smoothIn();
    half2 p3 = next.point;
    
    return oneMinusT * oneMinusT * oneMinusT * p0 + 3.0 * t * oneMinusT * oneMinusT * p1 + 3.0 * t * t * oneMinusT * p2 + t * t * t * p3;
}

vertex BlobVertexOut callBlobVertex(
    const device Rectangle &rect [[ buffer(0) ]],
    const device float *positions [[ buffer(1) ]],
    const device int &count [[ buffer(2) ]],
    unsigned int vid [[ vertex_id ]]
) {
    const int subdivisions = 8;
    
    int triangleIndex = vid / 3;
    
    int segmentIndex = triangleIndex / subdivisions;
    int nextIndex = (segmentIndex + 1) % count;
    
    half innerPosition = half(triangleIndex - segmentIndex * subdivisions) / half(subdivisions);
    half nextInnerPosition = half(triangleIndex + 1 - segmentIndex * subdivisions) / half(subdivisions);
    
    SmoothPoint curr = evaluateSmoothBlobPoint(rect, positions, segmentIndex, count, subdivisions);
    SmoothPoint next = evaluateSmoothBlobPoint(rect, positions, nextIndex, count, subdivisions);
    
    half2 triangle[3];
    triangle[0] = half2(0.5, 0.5);
    triangle[1] = evaluateBezierBlobPoint(curr, next, innerPosition);
    triangle[2] = evaluateBezierBlobPoint(curr, next, nextInnerPosition);
    
    BlobVertexOut out;
    out.position = float4(float2(mapPointInRect(rect, triangle[vid % 3])), 0.0, 1.0);
    
    return out;
}

fragment half4 callBlobFragment(
    BlobVertexOut in [[stage_in]],
    const device float4 &color [[ buffer(0) ]]
) {
    return half4(color.r * color.a, color.g * color.a, color.b * color.a, color.a);
}

kernel void videoBiPlanarToRGBA(
    texture2d<half, access::read> inTextureY [[ texture(0) ]],
    texture2d<half, access::read> inTextureUV [[ texture(1) ]],
    texture2d<half, access::write> outTexture [[ texture(2) ]],
    uint2 threadPosition [[ thread_position_in_grid ]]
) {
    half y = inTextureY.read(threadPosition).r;
    half2 uv = inTextureUV.read(uint2(threadPosition.x / 2, threadPosition.y / 2)).rg - half2(0.5, 0.5);
    
    half4 color(y + 1.403 * uv.y, y - 0.344 * uv.x - 0.714 * uv.y, y + 1.770 * uv.x, 1.0);
    outTexture.write(color, threadPosition);
}

kernel void videoTriPlanarToRGBA(
    texture2d<half, access::read> inTextureY [[ texture(0) ]],
    texture2d<half, access::read> inTextureU [[ texture(1) ]],
    texture2d<half, access::read> inTextureV [[ texture(2) ]],
    texture2d<half, access::write> outTexture [[ texture(3) ]],
    uint2 threadPosition [[ thread_position_in_grid ]]
) {
    half y = inTextureY.read(threadPosition).r;
    uint2 uvPosition = uint2(threadPosition.x / 2, threadPosition.y / 2);
    half2 inUV = (inTextureU.read(uvPosition).r, inTextureV.read(uvPosition).r);
    half2 uv = inUV - half2(0.5, 0.5);
    
    half4 color(y + 1.403 * uv.y, y - 0.344 * uv.x - 0.714 * uv.y, y + 1.770 * uv.x, 1.0);
    outTexture.write(color, threadPosition);
}

vertex QuadVertexOut mainVideoVertex(
    const device Rectangle &rect [[ buffer(0) ]],
    const device uint2 &mirror [[ buffer(1) ]],
    unsigned int vid [[ vertex_id ]]
) {
    float2 quadVertex = quadVertices[vid];
    
    QuadVertexOut out;
    
    out.position = float4(rect.origin.x + quadVertex.x * rect.size.x, rect.origin.y + quadVertex.y * rect.size.y, 0.0, 1.0);
    out.position.x = -1.0 + out.position.x * 2.0;
    out.position.y = -1.0 + out.position.y * 2.0;
    
    out.uv = float2(quadVertex.x, 1.0 - quadVertex.y);
    if (mirror.x == 1) {
        out.uv.x = 1.0 - out.uv.x;
    }
    if (mirror.y == 1) {
        out.uv.y = 1.0 - out.uv.y;
    }
    
    return out;
}

fragment half4 mainVideoFragment(
    QuadVertexOut in [[stage_in]],
    texture2d<half> texture [[ texture(0) ]],
    const device float &brightness [[ buffer(0) ]],
    const device float &saturation [[ buffer(1) ]],
    const device float4 &overlay [[ buffer(2) ]]
) {
    constexpr sampler sampler(coord::normalized, address::repeat, filter::linear);
    half4 color = texture.sample(sampler, in.uv);
    color = rgb2hsv(color);
    color.b = clamp(color.b * brightness, 0.0, 1.0);
    color.g = clamp(color.g * saturation, 0.0, 1.0);
    color = hsv2rgb(color);
    color.rgb += half3(overlay.rgb * overlay.a);
    color.rgb = min(color.rgb, half3(1.0, 1.0, 1.0));
    
    return half4(color.r, color.g, color.b, color.a);
}

constant int BLUR_SAMPLE_COUNT = 7;
constant float BLUR_OFFSETS[BLUR_SAMPLE_COUNT] = {
    -5.227545617192816,
    -3.3147990233346842,
    -1.4174297935376852,
    0.47225076494548685,
    2.364576440741639,
    4.268941421369995,
    6
};

constant float BLUR_WEIGHTS[BLUR_SAMPLE_COUNT] = {
    0.015167713616041436,
    0.10117053983645591,
    0.2894431725427234,
    0.3570581167968804,
    0.19014435646109845,
    0.0435647539906345,
    0.0034513467561660305
};

static void gaussianBlur(
    texture2d<half, access::sample> inTexture,
    texture2d<half, access::write> outTexture,
    float2 offset,
    uint2 gid
) {
    constexpr sampler sampler(coord::normalized, address::clamp_to_edge, filter::linear);
    
    uint2 textureDim(outTexture.get_width(), outTexture.get_height());
    if(all(gid < textureDim)) {
        float3 outColor(0.0);
        
        float2 size(inTexture.get_width(), inTexture.get_height());
        
        float2 baseTexCoord = float2(gid);
        
        for (int i = 0; i < BLUR_SAMPLE_COUNT; i++) {
            outColor += float3(inTexture.sample(sampler, (baseTexCoord + offset * BLUR_OFFSETS[i]) / size).rgb) * BLUR_WEIGHTS[i];
        }

        outTexture.write(half4(half3(outColor), 1.0), gid);
    }
}

kernel void gaussianBlurHorizontal(
    texture2d<half, access::sample> inTexture [[ texture(0) ]],
    texture2d<half,  access::write> outTexture [[ texture(1) ]],
    uint2 gid [[ thread_position_in_grid ]]
) {
    gaussianBlur(inTexture, outTexture, float2(1, 0), gid);
}

kernel void gaussianBlurVertical(
    texture2d<half, access::sample> inTexture [[ texture(0) ]],
    texture2d<half, access::write> outTexture [[ texture(1) ]],
    uint2 gid [[ thread_position_in_grid ]]
) {
    gaussianBlur(inTexture, outTexture, float2(0, 1), gid);
}

vertex QuadVertexOut edgeTestVertex(
    const device Rectangle &rect [[ buffer(0) ]],
    unsigned int vid [[ vertex_id ]]
) {
    float2 quadVertex = quadVertices[vid];
    
    QuadVertexOut out;
    
    out.position = float4(rect.origin.x + quadVertex.x * rect.size.x, rect.origin.y + quadVertex.y * rect.size.y, 0.0, 1.0);
    out.position.x = -1.0 + out.position.x * 2.0;
    out.position.y = -1.0 + out.position.y * 2.0;
    
    out.uv = quadVertex;
    
    return out;
}

fragment half4 edgeTestFragment(
    QuadVertexOut in [[stage_in]],
    const device float4 &colorIn
) {
    half4 color = half4(colorIn);
    return color;
}
