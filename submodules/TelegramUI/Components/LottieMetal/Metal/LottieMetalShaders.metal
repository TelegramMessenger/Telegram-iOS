#include <metal_stdlib>
using namespace metal;

typedef struct
{
    packed_float2 position;
    packed_float2 texCoord;
} QuadVertex;

typedef struct
{
    packed_float2 position;
} Vertex;

typedef struct
{
    float4 position [[position]];
    float2 texCoord;
    float2 transformedPosition;
} QuadOut;

typedef struct
{
    float4 position [[position]];
    float direction;
} FillVertexOut;

float calculateNormalDirection(float2 a, float2 b, float2 c) {
    float2 ab = b - a;
    float2 ac = c - a;
    
    return ab.x * ac.y - ab.y * ac.x;
}

vertex QuadOut quad_vertex_shader(
    device QuadVertex const *vertices [[buffer(0)]],
    uint vertexId [[vertex_id]],
    device matrix<float, 4> const &transform [[buffer(1)]]
) {
    QuadVertex in = vertices[vertexId];
    QuadOut out;
    float4 position = transform * float4(float2(in.position), 0.0, 1.0);
    out.position = position;
    out.texCoord = in.texCoord;
    out.transformedPosition = (transform * float4(float2(in.position), 0.0, 1.0)).xy;

    return out;
}

vertex FillVertexOut fill_vertex_shader(
    device Vertex const *vertices [[buffer(0)]],
    uint vertexId [[vertex_id]],
    device matrix<float, 4> const &transform [[buffer(1)]],
    device packed_float2 const &baseVertex [[buffer(2)]]
) {
    FillVertexOut out;
    uint triangleIndex = vertexId / 3;
    uint vertexInTriangleIndex = vertexId % 3;
    
    //[0, 1], [1, 2], [2, 3]...
    //0,      1,      2
    
    float2 sourcePosition;
    float2 v1 = float2(vertices[triangleIndex].position);
    float2 v2 = float2(vertices[triangleIndex + 1].position);
    
    sourcePosition = select(
        select(
            v2,
            v1,
            vertexInTriangleIndex == 1
        ),
        baseVertex,
        vertexInTriangleIndex == 0
    );
    
    float normalDirection = calculateNormalDirection(baseVertex, v1, v2);
    
    float4 position = transform * float4(sourcePosition, 0.0, 1.0);
    out.position = position;
    
    out.direction = sign(normalDirection);

    return out;
}

struct ShapeOut {
    half4 color [[color(1)]];
};

fragment ShapeOut fragment_shader(
    FillVertexOut in [[stage_in]],
    ShapeOut current,
    device const int32_t &mode [[buffer(1)]]
) {
    ShapeOut out = current;
    
    if (mode == 0) {
        half result = select(out.color.r, half(127.0 / 255.0), out.color.r == 0.0);
        result += half(in.direction) * 3.0 / 255.0;
        out.color.r = result;
    } else {
        out.color.r = out.color.r == 0.0 ? 1.0 : 0.0;
    }
    return out;
}

fragment ShapeOut clear_mask_fragment(
    QuadOut in [[stage_in]]
) {
    ShapeOut out;
    out.color = half4(0.0);
    return out;
}

struct ColorOut {
    half4 color [[color(0)]];
};

fragment ColorOut merge_color_fill_fragment_shader(
    ShapeOut colorIn,
    device const float4 &color [[buffer(0)]],
    device const int32_t &mode [[buffer(1)]]
) {
    ColorOut out;
    
    half4 sampledColor = half4(color);
    sampledColor.r = sampledColor.r * sampledColor.a;
    sampledColor.g = sampledColor.g * sampledColor.a;
    sampledColor.b = sampledColor.b * sampledColor.a;
    
    if (mode == 0) {
        half diff = abs(colorIn.color.r - 127.0 / 255.0);
        float diffSelect = select(0.0, 1.0, diff > (2.0 / 255.0));
        float outColorFactor = select(
            0.0,
            diffSelect,
            colorIn.color.r > 1.0 / 255.0
        );
        out.color = sampledColor * outColorFactor;
    } else {
        float outColorFactor = select(
            0.0,
            1.0,
            colorIn.color.r > 1.0 / 255.0
        );
        
        out.color = sampledColor * outColorFactor;
    }
    
    if (out.color.a == 0.0) {
        //discard_fragment();
    }

    return out;
}

typedef struct
{
    packed_float4 color;
    float location;
} GradientColorStop;

float linearGradientStep(float edge0, float edge1, float x) {
    float t = clamp((x - edge0) / (edge1 - edge0), float(0), float(1));
    return t;
}

fragment ColorOut merge_linear_gradient_fill_fragment_shader(
    QuadOut quadIn [[stage_in]],
    ShapeOut colorIn,
    device const GradientColorStop *colorStops [[buffer(0)]],
    device const int32_t &mode [[buffer(1)]],
    device const uint &numColorStops [[buffer(2)]],
    device const packed_float2 &localStartPosition [[buffer(3)]],
    device const packed_float2 &localEndPosition [[buffer(4)]]
) {
    ColorOut out;
    
    float4 sourceColor;
    
    if (numColorStops <= 1) {
        sourceColor = colorStops[0].color;
    } else {
        float2 localPixelPosition = quadIn.transformedPosition.xy;
        
        float2 gradientVector = normalize(localEndPosition - localStartPosition);
        float2 pointVector = localPixelPosition - localStartPosition;
        float pixelDistance = dot(pointVector, gradientVector) / dot(gradientVector, gradientVector);
        float gradientLength = length(localEndPosition - localStartPosition);
        float pixelValue = clamp(pixelDistance / gradientLength, 0.0, 1.0);
        
        sourceColor = mix(colorStops[0].color, colorStops[1].color, linearGradientStep(
            colorStops[0].location,
            colorStops[1].location,
            pixelValue
        ));
        for (int i = 1; i < (int)numColorStops - 1; i++) {
            sourceColor = mix(sourceColor, colorStops[i + 1].color, linearGradientStep(
                colorStops[i].location,
                colorStops[i + 1].location,
                pixelValue
            ));
        }
    }
    
    half4 sampledColor = half4(sourceColor);
    
    sampledColor.r = sampledColor.r * sampledColor.a;
    sampledColor.g = sampledColor.g * sampledColor.a;
    sampledColor.b = sampledColor.b * sampledColor.a;
    
    if (mode == 0) {
        half diff = abs(colorIn.color.r - 127.0 / 255.0);
        float diffSelect = select(0.0, 1.0, diff > (2.0 / 255.0));
        float outColorFactor = select(
            0.0,
            diffSelect,
            colorIn.color.r > 1.0 / 255.0
        );
        out.color = sampledColor * outColorFactor;
    } else {
        float outColorFactor = select(
            0.0,
            1.0,
            colorIn.color.r > 1.0 / 255.0
        );
        
        out.color = sampledColor * outColorFactor;
    }
    
    if (out.color.a == 0.0) {
        //discard_fragment();
    }

    return out;
}

fragment ColorOut merge_radial_gradient_fill_fragment_shader(
    QuadOut quadIn [[stage_in]],
    ShapeOut colorIn,
    device const GradientColorStop *colorStops [[buffer(0)]],
    device const int32_t &mode [[buffer(1)]],
    device const uint &numColorStops [[buffer(2)]],
    device const packed_float2 &localStartPosition [[buffer(3)]],
    device const packed_float2 &localEndPosition [[buffer(4)]]
) {
    ColorOut out;
    
    float4 sourceColor;
    
    if (numColorStops <= 1) {
        sourceColor = colorStops[0].color;
    } else {
        float pixelDistance = distance(quadIn.transformedPosition.xy, localStartPosition);
        float gradientLength = length(localEndPosition - localStartPosition);
        float pixelValue = clamp(pixelDistance / gradientLength, 0.0, 1.0);
        
        sourceColor = colorStops[0].color;
        for (int i = 0; i < (int)numColorStops - 1; i++) {
            float currentStopLocation = colorStops[i].location;
            float nextStopLocation = colorStops[i + 1].location;
            float4 nextStopColor = colorStops[i + 1].color;
            sourceColor = mix(sourceColor, nextStopColor, linearGradientStep(
                currentStopLocation,
                nextStopLocation,
                pixelValue
            ));
        }
    }
    
    half4 sampledColor = half4(sourceColor);
    
    sampledColor.r = sampledColor.r * sampledColor.a;
    sampledColor.g = sampledColor.g * sampledColor.a;
    sampledColor.b = sampledColor.b * sampledColor.a;
    
    if (mode == 0) {
        half diff = abs(colorIn.color.r - 127.0 / 255.0);
        float diffSelect = select(0.0, 1.0, diff > (2.0 / 255.0));
        float outColorFactor = select(
            0.0,
            diffSelect,
            colorIn.color.r > 1.0 / 255.0
        );
        out.color = sampledColor * outColorFactor;
    } else {
        float outColorFactor = select(
            0.0,
            1.0,
            colorIn.color.r > 1.0 / 255.0
        );
        
        out.color = sampledColor * outColorFactor;
    }
    
    if (out.color.a == 0.0) {
        //discard_fragment();
    }

    return out;
}

typedef struct {
    packed_float2 position;
} StrokePositionIn;

typedef struct {
    packed_float2 point;
} StrokePointIn;

typedef struct {
    float id;
} StrokeRoundJoinVertexIn;

typedef struct {
    packed_float4 position;
} StrokeMiterJoinVertexIn;

typedef struct {
    packed_float3 position;
} StrokeBevelJoinVertexIn;

typedef struct {
    packed_float2 position;
} StrokeCapVertexIn;

typedef struct
{
    float4 position [[position]];
} StrokeVertexOut;

fragment ColorOut stroke_fragment_shader(
    StrokeVertexOut in [[stage_in]],
    device const float4 &color [[buffer(0)]]
) {
    ColorOut out;
    
    half4 result = half4(color);
    result.r *= result.a;
    result.g *= result.a;
    result.b *= result.a;
    
    out.color = result;

    return out;
}

typedef struct {
    int32_t bufferOffset; // 4
    packed_float2 start; // 4 * 2
    packed_float2 end; // 4 * 2
    packed_float2 cp1; // 4 * 2
    packed_float2 cp2; // 4 * 2
    float offset; // 4
} BezierInputItem;

kernel void evaluateBezier(
    device BezierInputItem const *inputItems [[buffer(0)]],
    device float *vertexData [[buffer(1)]],
    device uint const &itemCount [[buffer(2)]],
    uint2 index [[ thread_position_in_grid ]]
) {
    if (index.x >= itemCount) {
        return;
    }
    BezierInputItem item = inputItems[index.x];
    
    float2 p0 = item.start;
    float2 p1 = item.cp1;
    float2 p2 = item.cp2;
    float2 p3 = item.end;
    
    float t = (((float)index.y) + 1.0) / (8.0);
    float oneMinusT = 1.0 - t;
    
    float2 value = oneMinusT * oneMinusT * oneMinusT * p0 + 3.0 * t * oneMinusT * oneMinusT * p1 + 3.0 * t * t * oneMinusT * p2 + t * t * t * p3;
    
    vertexData[item.bufferOffset + 2 * index.y] = value.x;
    vertexData[item.bufferOffset + 2 * index.y + 1] = value.y;
}

fragment half4 quad_offscreen_fragment(
    QuadOut in [[stage_in]],
    texture2d<half, access::sample> texture[[texture(0)]],
    device float const &opacity [[buffer(1)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    half4 color = texture.sample(s, float2(in.texCoord.x, 1.0 - in.texCoord.y));
    
    color *= half(opacity);
    
    return color;
}

fragment half4 quad_offscreen_fragment_with_mask(
    QuadOut in [[stage_in]],
    texture2d<half, access::sample> texture[[texture(0)]],
    texture2d<half, access::sample> maskTexture[[texture(1)]],
    device float const &opacity [[buffer(1)]],
    device uint const &maskMode [[buffer(2)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    half4 color = texture.sample(s, float2(in.texCoord.x, 1.0 - in.texCoord.y));
    half4 maskColor = maskTexture.sample(s, float2(in.texCoord.x, 1.0 - in.texCoord.y));
    
    if (maskMode == 0) {
        color *= maskColor.a;
    } else {
        color *= 1.0 - maskColor.a;
    }
    
    color *= half(opacity);
    
    return color;
}

bool myIsNan(float val) {
    return (val < 0.0 || 0.0 < val || val == 0.0) ? false : true;
}

bool isLinePointInvalid(float4 p) {
  return p.w == 0.0 || myIsNan(p.x);
}

// Adapted from https://github.com/rreusser/regl-gpu-lines

vertex StrokeVertexOut strokeTerminalVertex(
    uint instanceId [[instance_id]],
    uint index [[vertex_id]],
    device StrokePointIn const *points [[buffer(0)]],
    device matrix<float, 4> const &transform [[buffer(1)]],
    device packed_float2 const &_vertCnt2 [[buffer(2)]],
    device packed_float2 const &_capJoinRes2 [[buffer(3)]],
    device uint const &isJoinRound [[buffer(4)]],
    device uint const &isCapRound [[buffer(5)]],
    device float const &miterLimit [[buffer(6)]],
    device float const &width [[buffer(7)]]
) {
    const float2 ROUND_CAP_SCALE = float2(1.0, 1.0);
    const float2 SQUARE_CAP_SCALE = float2(2.0, 2.0 / sqrt(3.0));
    
    float2 _capScale = isCapRound ? ROUND_CAP_SCALE : SQUARE_CAP_SCALE;
    
    const float pi = 3.141592653589793;
    
    float2 xyB = points[instanceId * 3 + 0].point;
    float2 xyC = points[instanceId * 3 + 1].point;
    float2 xyD = points[instanceId * 3 + 2].point;
    
    StrokeVertexOut out;

    float4 pB = float4(xyB, 0.0, 1.0);
    float4 pC = float4(xyC, 0.0, 1.0);
    float4 pD = float4(xyD, 0.0, 1.0);

    // A sensible default for early returns
    out.position = pB;

    bool aInvalid = false;
    bool bInvalid = isLinePointInvalid(pB);
    bool cInvalid = isLinePointInvalid(pC);
    bool dInvalid = isLinePointInvalid(pD);

    // Vertex count for each part (first half of join, second (mirrored) half). Note that not all of
    // these vertices may be used, for example if we have enough for a round cap but only draw a miter
    // join.
    float2 v = _vertCnt2 + 3.0;

    // Total vertex count
    float N = dot(v, float2(1));

    // If we're past the first half-join and half of the segment, then we swap all vertices and start
    // over from the opposite end.
    bool mirror = index >= v.x;

    // When rendering dedicated endpoints, this allows us to insert an end cap *alone* (without the attached
    // segment and join)
    if (dInvalid && mirror) {
        return out;
    }

    // Convert to screen-pixel coordinates
    // Save w so we can perspective re-multiply at the end to get varyings depth-correct
    float pw = mirror ? pC.w : pB.w;
    pB = float4(float3(pB.xy, pB.z) / pB.w, 1);
    pC = float4(float3(pC.xy, pC.z) / pC.w, 1);
    pD = float4(float3(pD.xy, pD.z) / pD.w, 1);

    // If it's a cap, mirror A back onto C to accomplish a round
    float4 pA = pC;

    // Reject if invalid or if outside viewing planes
    if (bInvalid || cInvalid || max(abs(pB.z), abs(pC.z)) > 1.0) {
        return out;
    }

    // Swap everything computed so far if computing mirrored half
    if (mirror) {
        float4 vTmp = pC; pC = pB; pB = vTmp;
        vTmp = pD; pD = pA; pA = vTmp;
        bool bTmp = dInvalid; dInvalid = aInvalid; aInvalid = bTmp;
    }

    bool isCap = !mirror;

    // Either flip A onto C (and D onto B) to produce a 180 degree-turn cap, or extrapolate to produce a
    // degenerate (no turn) join, depending on whether we're inserting caps or just leaving ends hanging.
    if (aInvalid) { pA = 2.0 * pB - pC; }
    if (dInvalid) { pD = 2.0 * pC - pB; }
    bool roundOrCap = isJoinRound || isCap;

    // Tangent and normal vectors
    float2 tBC = pC.xy - pB.xy;
    float lBC = length(tBC);
    tBC /= lBC;
    float2 nBC = float2(-tBC.y, tBC.x);

    float2 tAB = pB.xy - pA.xy;
    float lAB = length(tAB);
    if (lAB > 0.0) tAB /= lAB;
    float2 nAB = float2(-tAB.y, tAB.x);

    float2 tCD = pD.xy - pC.xy;
    float lCD = length(tCD);
    if (lCD > 0.0) tCD /= lCD;
    float2 nCD = float2(-tCD.y, tCD.x);

    // Clamp for safety, since we take the arccos
    float cosB = clamp(dot(tAB, tBC), -1.0, 1.0);

    // This section is somewhat fragile. When lines are collinear, signs flip randomly and break orientation
    // of the middle segment. The fix appears straightforward, but this took a few hours to get right.
    const float tol = 1e-4;
    float mirrorSign = mirror ? -1.0 : 1.0;
    float dirB = -dot(tBC, nAB);
    float dirC = dot(tBC, nCD);
    bool bCollinear = abs(dirB) < tol;
    bool cCollinear = abs(dirC) < tol;
    bool bIsHairpin = bCollinear && cosB < 0.0;
    // bool cIsHairpin = cCollinear && dot(tBC, tCD) < 0.0;
    dirB = bCollinear ? -mirrorSign : sign(dirB);
    dirC = cCollinear ? -mirrorSign : sign(dirC);

    float2 miter = bIsHairpin ? -tBC : 0.5 * (nAB + nBC) * dirB;

    // Compute our primary "join index", that is, the index starting at the very first point of the join.
    // The second half of the triangle strip instance is just the first, reversed, and with vertices swapped!
    float i = mirror ? N - index : index;

    // Decide the resolution of whichever feature we're drawing. n is twice the number of points used since
    // that's the only form in which we use this number.
    float res = (isCap ? _capJoinRes2.x : _capJoinRes2.y);

    // Shift the index to send unused vertices to an index below zero, which will then just get clamped to
    // zero and result in repeated points, i.e. degenerate triangles.
    i -= max(0.0, (mirror ? _vertCnt2.y : _vertCnt2.x) - res);

    // Use the direction to offset the index by one. This has the effect of flipping the winding number so
    // that it's always consistent no matter which direction the join turns.
    i += (dirB < 0.0 ? -1.0 : 0.0);

    // Vertices of the second (mirrored) half of the join are offset by one to get it to connect correctly
    // in the middle, where the mirrored and unmirrored halves meet.
    i -= mirror ? 1.0 : 0.0;

    // Clamp to zero and repeat unused excess vertices.
    i = max(0.0, i);

    // Start with a default basis pointing along the segment with normal vector outward
    float2 xBasis = tBC;
    float2 yBasis = nBC * dirB;

    // Default point is 0 along the segment, 1 (width unit) normal to it
    float2 xy = float2(0);

    if (i == res + 1.0) {
        // pick off this one specific index to be the interior miter point
        // If not div-by-zero, then sinB / (1 + cosB)
        float m = cosB > -0.9999 ? (tAB.x * tBC.y - tAB.y * tBC.x) / (1.0 + cosB) : 0.0;
        xy = float2(min(abs(m), min(lBC, lAB) / width), -1);
    } else {
        // Draw half of a join
        float m2 = dot(miter, miter);
        float lm = sqrt(m2);
        yBasis = miter / lm;
        xBasis = dirB * float2(yBasis.y, -yBasis.x);
        bool isBevel = 1.0 > miterLimit * m2;
        
        if (((int)i) % 2 == 0) {
            // Outer joint points
            if (roundOrCap || i != 0.0) {
                // Round joins
                float theta = -0.5 * (acos(cosB) * (clamp(i, 0.0, res) / res) - pi) * (isCap ? 2.0 : 1.0);
                xy = float2(cos(theta), sin(theta));
                
                if (isCap) {
                    // A special multiplier factor for turning 3-point rounds into square caps (but leave the
                    // y == 0.0 point unaffected)
                    if (xy.y > 0.001) xy *= _capScale;
                }
            } else {
                // Miter joins
                yBasis = bIsHairpin ? float2(0) : miter;
                xy.y = isBevel ? 1.0 : 1.0 / m2;
            }
        } else {
            // Offset the center vertex position to get bevel SDF correct
            if (isBevel && !roundOrCap) {
                xy.y = -1.0 + sqrt((1.0 + cosB) * 0.5);
            }
        }
    }

    // Point offset from main vertex position
    float2 dP = float2x2(xBasis, yBasis) * xy;

    out.position = pB;
    out.position.xy += width * dP;
    out.position *= pw;
    out.position = transform * out.position;
    
    return out;
}

vertex StrokeVertexOut strokeInnerVertex(
    uint instanceId [[instance_id]],
    uint index [[vertex_id]],
    device StrokePointIn const *points [[buffer(0)]],
    device matrix<float, 4> const &transform [[buffer(1)]],
    device packed_float2 const &_vertCnt2 [[buffer(2)]],
    device packed_float2 const &_capJoinRes2 [[buffer(3)]],
    device uint const &isJoinRound [[buffer(4)]],
    device uint const &isCapRound [[buffer(5)]],
    device float const &miterLimit [[buffer(6)]],
    device float const &width [[buffer(7)]]
) {
    const float2 ROUND_CAP_SCALE = float2(1.0, 1.0);
    const float2 SQUARE_CAP_SCALE = float2(2.0, 2.0 / sqrt(3.0));
    
    float2 _capScale = isCapRound ? ROUND_CAP_SCALE : SQUARE_CAP_SCALE;
    
    const float pi = 3.141592653589793;
    
    float2 xyA = points[instanceId + 0].point;
    float2 xyB = points[instanceId + 1].point;
    float2 xyC = points[instanceId + 2].point;
    float2 xyD = points[instanceId + 3].point;
    
    StrokeVertexOut out;
    
    float4 pA = float4(xyA, 0.0, 1.0);
    float4 pB = float4(xyB, 0.0, 1.0);
    float4 pC = float4(xyC, 0.0, 1.0);
    float4 pD = float4(xyD, 0.0, 1.0);
    
    // A sensible default for early returns
    out.position = pB;
    
    bool aInvalid = isLinePointInvalid(pA);
    bool bInvalid = isLinePointInvalid(pB);
    bool cInvalid = isLinePointInvalid(pC);
    bool dInvalid = isLinePointInvalid(pD);
    
    // Vertex count for each part (first half of join, second (mirrored) half). Note that not all of
    // these vertices may be used, for example if we have enough for a round cap but only draw a miter
    // join.
    float2 v = _vertCnt2 + 3.0;
    
    // Total vertex count
    float N = dot(v, float2(1));
    
    // If we're past the first half-join and half of the segment, then we swap all vertices and start
    // over from the opposite end.
    bool mirror = index >= v.x;
    
    // When rendering dedicated endoints, this allows us to insert an end cap *alone* (without the attached
    // segment and join)
    
    
    // Convert to screen-pixel coordinates
    // Save w so we can perspective re-multiply at the end to get varyings depth-correct
    float pw = mirror ? pC.w : pB.w;
    pA = float4(float3(pA.xy, pA.z) / pA.w, 1);
    pB = float4(float3(pB.xy, pB.z) / pB.w, 1);
    pC = float4(float3(pC.xy, pC.z) / pC.w, 1);
    pD = float4(float3(pD.xy, pD.z) / pD.w, 1);
    
    // If it's a cap, mirror A back onto C to accomplish a round
    
    
    // Reject if invalid or if outside viewing planes
    if (bInvalid || cInvalid || max(abs(pB.z), abs(pC.z)) > 1.0) {
        return out;
    }
    
    // Swap everything computed so far if computing mirrored half
    if (mirror) {
        float4 vTmp = pC; pC = pB; pB = vTmp;
        vTmp = pD; pD = pA; pA = vTmp;
        bool bTmp = dInvalid; dInvalid = aInvalid; aInvalid = bTmp;
    }
    
    const bool isCap = false;
    
    // Either flip A onto C (and D onto B) to produce a 180 degree-turn cap, or extrapolate to produce a
    // degenerate (no turn) join, depending on whether we're inserting caps or just leaving ends hanging.
    if (aInvalid) { pA = 2.0 * pB - pC; }
    if (dInvalid) { pD = 2.0 * pC - pB; }
    bool roundOrCap = isJoinRound || isCap;
    
    // Tangent and normal vectors
    float2 tBC = pC.xy - pB.xy;
    float lBC = length(tBC);
    tBC /= lBC;
    float2 nBC = float2(-tBC.y, tBC.x);
    
    float2 tAB = pB.xy - pA.xy;
    float lAB = length(tAB);
    if (lAB > 0.0) tAB /= lAB;
    float2 nAB = float2(-tAB.y, tAB.x);
    
    float2 tCD = pD.xy - pC.xy;
    float lCD = length(tCD);
    if (lCD > 0.0) tCD /= lCD;
    float2 nCD = float2(-tCD.y, tCD.x);
    
    // Clamp for safety, since we take the arccos
    float cosB = clamp(dot(tAB, tBC), -1.0, 1.0);
    
    // This section is somewhat fragile. When lines are collinear, signs flip randomly and break orientation
    // of the middle segment. The fix appears straightforward, but this took a few hours to get right.
    const float tol = 1e-4;
    float mirrorSign = mirror ? -1.0 : 1.0;
    float dirB = -dot(tBC, nAB);
    float dirC = dot(tBC, nCD);
    bool bCollinear = abs(dirB) < tol;
    bool cCollinear = abs(dirC) < tol;
    bool bIsHairpin = bCollinear && cosB < 0.0;
    // bool cIsHairpin = cCollinear && dot(tBC, tCD) < 0.0;
    dirB = bCollinear ? -mirrorSign : sign(dirB);
    dirC = cCollinear ? -mirrorSign : sign(dirC);
    
    float2 miter = bIsHairpin ? -tBC : 0.5 * (nAB + nBC) * dirB;
    
    // Compute our primary "join index", that is, the index starting at the very first point of the join.
    // The second half of the triangle strip instance is just the first, reversed, and with vertices swapped!
    float i = mirror ? N - index : index;
    
    // Decide the resolution of whichever feature we're drawing. n is twice the number of points used since
    // that's the only form in which we use this number.
    float res = (isCap ? _capJoinRes2.x : _capJoinRes2.y);
    
    // Shift the index to send unused vertices to an index below zero, which will then just get clamped to
    // zero and result in repeated points, i.e. degenerate triangles.
    i -= max(0.0, (mirror ? _vertCnt2.y : _vertCnt2.x) - res);
    
    // Use the direction to offset the index by one. This has the effect of flipping the winding number so
    // that it's always consistent no matter which direction the join turns.
    i += (dirB < 0.0 ? -1.0 : 0.0);
    
    // Vertices of the second (mirrored) half of the join are offset by one to get it to connect correctly
    // in the middle, where the mirrored and unmirrored halves meet.
    i -= mirror ? 1.0 : 0.0;
    
    // Clamp to zero and repeat unused excess vertices.
    i = max(0.0, i);
    
    // Start with a default basis pointing along the segment with normal vector outward
    float2 xBasis = tBC;
    float2 yBasis = nBC * dirB;
    
    // Default point is 0 along the segment, 1 (width unit) normal to it
    float2 xy = float2(0);
    
    if (i == res + 1.0) {
        // pick off this one specific index to be the interior miter point
        // If not div-by-zero, then sinB / (1 + cosB)
        float m = cosB > -0.9999 ? (tAB.x * tBC.y - tAB.y * tBC.x) / (1.0 + cosB) : 0.0;
        xy = float2(min(abs(m), min(lBC, lAB) / width), -1);
    } else {
        // Draw half of a join
        float m2 = dot(miter, miter);
        float lm = sqrt(m2);
        yBasis = miter / lm;
        xBasis = dirB * float2(yBasis.y, -yBasis.x);
        bool isBevel = 1.0 > miterLimit * m2;
        
        if (((int)i) % 2 == 0) {
            // Outer joint points
            if (roundOrCap || i != 0.0) {
                // Round joins
                float theta = -0.5 * (acos(cosB) * (clamp(i, 0.0, res) / res) - pi) * (isCap ? 2.0 : 1.0);
                xy = float2(cos(theta), sin(theta));
                
                if (isCap) {
                    // A special multiplier factor for turning 3-point rounds into square caps (but leave the
                    // y == 0.0 point unaffected)
                    if (xy.y > 0.001) xy *= _capScale;
                }
            } else {
                // Miter joins
                yBasis = bIsHairpin ? float2(0) : miter;
                xy.y = isBevel ? 1.0 : 1.0 / m2;
            }
        } else {
            // Offset the center vertex position to get bevel SDF correct
            if (isBevel && !roundOrCap) {
                xy.y = -1.0 + sqrt((1.0 + cosB) * 0.5);
            }
        }
    }
    
    // Point offset from main vertex position
    float2 dP = float2x2(xBasis, yBasis) * xy;
    
    // The varying generation code handles clamping, if needed
    
    out.position = pB;
    out.position.xy += width * dP;
    out.position *= pw;
    out.position = transform * out.position;
    
    return out;
}

constant static float2 quadVertices[6] = {
    float2(0.0, 0.0),
    float2(1.0, 0.0),
    float2(0.0, 1.0),
    float2(1.0, 0.0),
    float2(0.0, 1.0),
    float2(1.0, 1.0)
};

struct MetalEngineRectangle {
    float2 origin;
    float2 size;
};

struct MetalEngineQuadVertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex MetalEngineQuadVertexOut blitVertex(
    const device MetalEngineRectangle &rect [[ buffer(0) ]],
    unsigned int vid [[ vertex_id ]]
) {
    float2 quadVertex = quadVertices[vid];
    
    MetalEngineQuadVertexOut out;
    
    out.position = float4(rect.origin.x + quadVertex.x * rect.size.x, rect.origin.y + quadVertex.y * rect.size.y, 0.0, 1.0);
    out.position.x = -1.0 + out.position.x * 2.0;
    out.position.y = -1.0 + out.position.y * 2.0;
    
    out.uv = float2(quadVertex.x, 1.0 - quadVertex.y);
    
    return out;
}

fragment half4 blitFragment(
    MetalEngineQuadVertexOut in [[stage_in]],
    texture2d<half> texture [[ texture(0) ]]
) {
    constexpr sampler sampler(coord::normalized, address::repeat, filter::linear);
    half4 color = texture.sample(sampler, in.uv);
    
    return half4(color.r, color.g, color.b, color.a);
}
