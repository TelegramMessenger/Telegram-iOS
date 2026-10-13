#include <metal_stdlib>
using namespace metal;

struct GramDiamondCompositeRaster {
    float4 position [[position]];
    float2 uv;
};

vertex GramDiamondCompositeRaster gramDiamondCompositeVertex(
    constant float4 &rect [[buffer(0)]], uint vertexID [[vertex_id]]) {
    const float2 vertices[6] = {
        float2(0, 0), float2(1, 0), float2(0, 1),
        float2(1, 0), float2(0, 1), float2(1, 1)
    };
    float2 point = vertices[vertexID];
    GramDiamondCompositeRaster out;
    out.position = float4((rect.xy + point * rect.zw) * 2 - 1, 0, 1);
    out.uv = float2(point.x, 1 - point.y);
    return out;
}

fragment float4 gramDiamondCompositeFragment(GramDiamondCompositeRaster in [[stage_in]],
                                             texture2d<float> scene [[texture(0)]]) {
    constexpr sampler sceneSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);
    return scene.sample(sceneSampler, in.uv);
}

struct StarUniforms {
    float4x4 projection;
    float4 animation; // burst age, transport time, burst enabled, light background
    float4 layout; // viewport pixels, steady instance count, burst seed
    float4 appearance; // x: palette identifier, w: rightward fan
    float4 tint; // y: star opacity, z: emission radius, w: burst fade-in seconds
};
struct BackgroundStarRaster {
    float4 position [[position]];
    float2 uv;
    float4 color [[flat]];
    float haloOpacity [[flat]];
};

float starRandom(uint seed) {
    seed ^= seed >> 16; seed *= 0x7feb352du;
    seed ^= seed >> 15; seed *= 0x846ca68bu;
    seed ^= seed >> 16;
    return float(seed & 0x00ffffffu) / 16777216.0;
}

vertex BackgroundStarRaster backgroundStarVertex(uint vertexIndex [[vertex_id]], uint instance [[instance_id]],
                                                 constant StarUniforms &u [[buffer(0)]]) {
    const float2 corners[6] = {float2(-1,-1),float2(1,-1),float2(-1,1),
                              float2(-1,1),float2(1,-1),float2(1,1)};
    uint seed = instance*127u + 9137u;
    bool burst = instance >= uint(u.layout.z);
    if (burst) {
        seed += uint(u.layout.w)*104729u;
    }
    float lifetime = mix(4.5,7.5,starRandom(seed+1));
    float clock = u.animation.y + starRandom(seed+2)*lifetime;
    uint cycle = uint(floor(clock/lifetime));
    float age = fmod(clock,lifetime);
    if (burst) {
        const float burstDurationScale = 2.0;
        lifetime = mix(1.8,3.2,starRandom(seed+1));
        age = u.animation.x / burstDurationScale;
        cycle = 0;
    }
    seed += cycle*7919u;
    float progress = saturate(age/lifetime);
    float alive = float(age >= 0 && age < lifetime) * (burst ? u.animation.z : 1);
    float fadeIn = burst ? smoothstep(0.0,u.tint.w,u.animation.x) : smoothstep(0,0.10,progress);
    float fade = fadeIn * (1-smoothstep(0.62,1.0,progress)) * alive * u.tint.y;
    float depth = mix(0.60,1.0,starRandom(seed+3));
    float spread = starRandom(seed+14);
    const float verticalSpread = 0.78;
    float2 direction;
    if (u.appearance.w > 0.5) {
        // A single continuous fan to the right, with no separate vertical lobes.
        float elevation = mix(-M_PI_F/3.0,M_PI_F/3.0,spread);
        direction = float2(cos(elevation),sin(elevation));
    } else {
        float sector = starRandom(seed+4);
        float lowerFanAngle = atan(tan(-M_PI_F/6.0)/verticalSpread);
        float elevation = sector < 0.85 ? mix(lowerFanAngle,0.34,spread) : mix(0.52,1.40,spread);
        float side = starRandom(seed+15) < 0.5 ? -1.0 : 1.0;
        direction = float2(side*cos(elevation),sin(elevation));
    }
    float distance;
    if (burst) {
        float travelTime = max(age,0.0);
        float baseSpeed = mix(4.8,7.2,starRandom(seed+5));
        float initialSpeed = baseSpeed * 1.40;
        float cruiseSpeed = baseSpeed * 0.30;
        const float slowdownTime = 0.40;
        distance = mix(0.10,0.32,starRandom(seed+13)) + cruiseSpeed*travelTime
            + (initialSpeed-cruiseSpeed)*slowdownTime*(1-exp(-travelTime/slowdownTime));
    } else {
        distance = 0.32 + age*mix(0.38,0.63,starRandom(seed+5));
    }
    float drift = sin(age*0.85+starRandom(seed+6)*6.28) * (burst ? 0.06 : 0.16);
    float2 center = direction*distance + float2(-direction.y,direction.x)*drift;
    center *= float2(1,verticalSpread)*depth;
    const float emissionHeight = -0.10;
    center.y += emissionHeight + mix(-0.26,0.24,starRandom(seed+16))*depth;
    if (!burst) {
        float travel = length(direction*float2(1,verticalSpread))*distance*depth;
        float behavior = starRandom(seed+17);
        if (behavior < 0.34) {
            float dimStart = mix(0.76,0.90,starRandom(seed+18));
            float dimEnd = dimStart + mix(0.16,0.22,starRandom(seed+19));
            float returnStart = dimEnd + mix(0.04,0.09,starRandom(seed+20));
            float returnEnd = returnStart + mix(0.14,0.22,starRandom(seed+21));
            float endStart = returnEnd + mix(0.05,0.12,starRandom(seed+22));
            float end = endStart + mix(0.18,0.28,starRandom(seed+23));
            float firstGlow = 1-smoothstep(dimStart,dimEnd,travel);
            float secondGlow = smoothstep(returnStart,returnEnd,travel)
                * (1-smoothstep(endStart,end,travel));
            fade *= firstGlow + secondGlow;
        } else if (behavior < 0.62) {
            float revealStart = mix(0.86,1.10,starRandom(seed+18));
            float revealEnd = revealStart + mix(0.20,0.34,starRandom(seed+19));
            fade *= smoothstep(revealStart,revealEnd,travel);
        }
    }
    float breathPeriod = mix(2.0,3.4,starRandom(seed+24));
    float breathPhase = age*(2*M_PI_F/breathPeriod) + starRandom(seed+25)*2*M_PI_F;
    float breathWave = 0.5-0.5*cos(breathPhase);
    float shine = smoothstep(0.0,1.0,fade) * mix(0.12,1.0,breathWave);
    const float starSizeScale = 1.53;
    float radius = starSizeScale * mix(0.0228,0.084,pow(starRandom(seed+7),1.7))*depth * mix(0.87,1.0,shine);
    fade *= smoothstep(0.72 * u.tint.z, 1.02 * u.tint.z, length(center));
    float rotation = starRandom(seed+8)*1.57 + age*mix(-0.20,0.20,starRandom(seed+9));
    float2 uv = corners[vertexIndex]*1.45;
    float2 point = float2(cos(rotation)*uv.x-sin(rotation)*uv.y,
                          sin(rotation)*uv.x+cos(rotation)*uv.y)*radius;
    float choice = starRandom(seed+10);
    float3 darkColor = choice < 0.22 ? float3(0.045,0.36,1) :
                      (choice < 0.50 ? float3(0,0.451,1) :
                      (choice < 0.82 ? float3(0,0.639,1) : float3(0.145,0.792,1)));
    float iridescence = smoothstep(0.12,1.0,shine);
    darkColor = mix(darkColor,float3(0.247,0.894,1),iridescence*0.30);
    float3 lightColor = darkColor * 0.78;
    if (uint(u.appearance.x) == 1) {
        darkColor = lightColor = float3(1);
    } else if (uint(u.appearance.x) == 2) {
        darkColor = mix(float3(0.52,0.84,1),float3(1),choice*0.8+iridescence*0.2);
        lightColor = mix(float3(0.20,0.51,0.91),float3(0.58,0.80,1),choice);
    }
    BackgroundStarRaster out;
    out.position = u.projection*float4(center+point,-1.6-depth,1);
    out.uv = uv;
    out.color = float4(mix(darkColor,lightColor,u.animation.w) * u.tint.x,
                       fade*mix(0.52,0.95,starRandom(seed+11))*mix(0.80,1.0,depth));
    out.haloOpacity = mix(0.075,0.035,u.animation.w) * u.tint.x;
    return out;
}

fragment float4 backgroundStarFragment(BackgroundStarRaster in [[stage_in]]) {
    float2 p = abs(in.uv);
    float distance = sqrt(max(p.x,0.00001))+sqrt(max(p.y,0.00001))-1;
    float aa = max(fwidth(distance),0.04);
    float core = 1-smoothstep(-aa,aa,distance);
    float glow = exp(-dot(in.uv,in.uv)*4.5)*in.haloOpacity;
    float alpha = saturate(core+glow)*in.color.a;
    return float4(in.color.rgb*alpha,alpha);
}

struct Vertex { float4 position; float4 normal; float4 surface; };
struct Uniforms {
    float4x4 model;
    float4x4 projection;
    float4x4 inverseModel;
    float4 parameters; // time, refraction, brightness, sparkles
    float4 viewport;   // width, height, optical plane count, unused
    float4 sparkleShape; // main layer scale, contour morph, core scale, star glow scale
    float4 sparkleHalo;  // circular glow scale, main face rotation, horizontal correction, visibility
    float4 crownGradient;
    float4 pavilionGradient;
    float4 lightSweep; // diagonal position, environment phase, transmission, reserved
    float4 facetProjection; // reference pitch cosine/sine, source units, projected top
    float4 crownSweep;
    float4 rightCrownSweep;
    float4 leftCrownSweep;
    float4 pavilionSweep;
    float4 rightPavilionSweep;
    float4 leftPavilionSweep;
    float4 appearance; // palette identifier, reserved
    float4 referenceCrownFlash;
    float4 referencePavilionFlash;
};
struct Raster {
    float4 position [[position]];
    float3 localPosition;
    float3 normal;
    float3 worldPosition;
    float3 facetWeights; // table, crown, pavilion; interpolated across rounded edges
};

float3 referenceCrown(float2 p, float4 gradient) {
    const float stops[7] = {0, 0.162, 0.324, 0.501, 0.667, 0.833, 1};
    const float3 colors[7] = {float3(0.145,0.792,1), float3(0.373,0.875,1),
        float3(0.6,0.957,1), float3(0.3,0.798,1), float3(0,0.639,1),
        float3(0,0.545,1), float3(0,0.451,1)};
    float2 start = gradient.xy, direction = gradient.zw - start;
    float t = saturate(dot(p-start, direction) / dot(direction,direction));
    for (uint i = 1; i < 7; ++i) {
        if (t <= stops[i]) { return mix(colors[i-1], colors[i], (t-stops[i-1])/(stops[i]-stops[i-1])); }
    }
    return colors[6];
}

float3 lateralDepth(float3 color, float3 normal, float y, float3 facetWeights,
                    float opticalLuminance) {
    float horizontalNormal = length(normal.xz);
    float side = smoothstep(0.22, 0.80, abs(normal.x) / max(horizontalNormal, 0.001));
    float shoulder = smoothstep(0.06, 0.57, y);
    float lower = smoothstep(0.12, 0.90, -y);
    float reflectedLight = smoothstep(0.28, 0.78, color.g);
    // A restrained blue-violet shadow keeps the sides distinct without
    // swallowing their cyan gradients and moving reflections.
    float3 deepBlue = mix(float3(0.017, 0.035, 0.90),
                          float3(0.006, 0.11, 1), reflectedLight);
    float3 sideColor = mix(deepBlue, float3(0.22, 0.86, 1), shoulder * 0.69);
    sideColor = mix(sideColor, float3(0.018, 0.39, 1), lower * 0.52);
    float reflectionDetail = 0.105 + opticalLuminance * 0.14
                           + smoothstep(0.70, 0.95, color.g) * 0.26;
    sideColor = mix(sideColor, color, reflectionDetail);
    float weight = side * 0.96 * (1.0 - facetWeights.x);
    return mix(color, sideColor, weight);
}

float3 facetBarycentric(float2 p, float2 a, float2 b, float2 c) {
    float2 v = b-a, w = c-a, q = p-a;
    float determinant = v.x*w.y - v.y*w.x;
    float y = (q.x*w.y - q.y*w.x) / determinant;
    float z = (v.x*q.y - v.y*q.x) / determinant;
    return float3(1-y-z, y, z);
}

float facetCoverage(float3 barycentric) {
    float edge = min(barycentric.x, min(barycentric.y, barycentric.z));
    float aa = max(fwidth(edge), 0.004);
    return smoothstep(-aa, aa, edge);
}

float2 sourceFacetPoint(float3 localPosition, float2 outward, constant Uniforms &u) {
    float across = dot(localPosition.xz, float2(outward.y,-outward.x));
    float depth = dot(localPosition.xz,outward);
    float c = u.facetProjection.x, s = u.facetProjection.y;
    float y = c*localPosition.y-s*depth;
    float z = s*localPosition.y+c*depth;
    float w = u.projection[2].w*z+u.projection[3].w;
    return float2(257.6+across/w*u.facetProjection.z,
                  103.8+(u.facetProjection.w-y/w)*u.facetProjection.z);
}

float3 illustratedFacets(float3 color, Raster in, constant Uniforms &u) {
    float3 localNormal = normalize((u.inverseModel * float4(normalize(in.normal), 0)).xyz);
    // Fixed material coordinates on each broad face. The same reference camera
    // maps the authored facets and the sparkle anchors onto the current cut.
    float2 outward = abs(localNormal.x) > abs(localNormal.z)
        ? float2(sign(localNormal.x),0) : float2(0,sign(localNormal.z));
    float3 tangent = float3(outward.y,0,-outward.x);
    float2 p = sourceFacetPoint(in.localPosition,outward,u);
    // Fade the drawing before the diagonal facets, where the next face's
    // coordinate system takes over. No duplicated motifs along rounded edges.
    float2 normalXZ = abs(localNormal.xz);
    float broad = 1-smoothstep(0.20,0.65,min(normalXZ.x,normalXZ.y)/max(max(normalXZ.x,normalXZ.y),0.0001));
    float3 worldTangent = (u.model * float4(tangent, 0)).xyz;
    float3 n = normalize(in.normal);
    float3 light = normalize(float3(0.6*sin(u.lightSweep.y), 0.5, 1));
    float leftLight = pow(saturate(dot(normalize(n - worldTangent*0.38), light)), 5.0);
    float rightLight = pow(saturate(dot(normalize(n + worldTangent*0.38), light)), 5.0);
    if (in.facetWeights.y > 0) {
        // Both crown triangles meet at the same upper junction.
        const float2 crownJunction = float2(258.8,128.9);
        // Authored lower corners now share the same projection as the mesh.
        const float2 crownBaseLeft = float2(108.8,240.8);
        const float2 crownBaseRight = float2(406.8,240.8);
        float3 left = facetBarycentric(p, float2(142.1,106.3), crownJunction, crownBaseLeft);
        float leftStrength = facetCoverage(left) * (0.18 + 0.40*leftLight) * saturate(1-left.y);
        color = mix(color, float3(0.79,0.988,1), leftStrength * in.facetWeights.y * broad);
        float3 right = facetBarycentric(p, crownBaseRight, crownJunction, float2(378.5,108.2));
        // The source is light at the left junction and dark at the right edge.
        // Use horizontal facet coordinates so the gradient turns with the gem.
        float gradient = smoothstep(crownJunction.x,crownBaseRight.x,p.x);
        float3 tint = mix(float3(0.28,0.83,1),float3(0.025,0.43,1),gradient);
        tint = mix(tint,float3(0.57,0.95,1),rightLight*0.24);
        color = mix(color, tint, facetCoverage(right) * 0.90 * in.facetWeights.y * broad);
    }
    if (in.facetWeights.z > 0) {
        // A translucent kite belongs to each broad pavilion face. Material-space
        // edges stay attached to the surface throughout a complete rotation.
        float2 kite = float2(dot(in.localPosition,tangent),in.localPosition.y);
        const float halfWidth = 0.245, top = -0.61, shoulder = -0.70, bottom = -1.075;
        const float upperHeight = top-shoulder, lowerHeight = shoulder-bottom;
        float upperEdge = ((top-kite.y)*halfWidth-abs(kite.x)*upperHeight)
            / length(float2(halfWidth,upperHeight));
        float lowerEdge = ((kite.y-bottom)*halfWidth-abs(kite.x)*lowerHeight)
            / length(float2(halfWidth,lowerHeight));
        float edge = min(upperEdge,lowerEdge);
        float aa = max(fwidth(edge),0.0015);
        float coverage = smoothstep(-aa,aa,edge);
        float illumination = saturate(dot(n,normalize(float3(-0.65,0.5,1))));
        float3 tint = mix(float3(0.48,0.96,1),float3(0.70,1,1),illumination);
        float across = saturate(0.5+kite.x/(2*halfWidth));
        tint *= mix(float3(1),float3(0.88,0.97,1),across);
        color = mix(color,tint,coverage*0.28*in.facetWeights.z*broad);
    }

    return color;
}

vertex Raster diamondVertex(uint id [[vertex_id]], const device Vertex *vertices [[buffer(0)]],
                            constant Uniforms &u [[buffer(1)]]) {
    Vertex v = vertices[id];
    float4 world = u.model * v.position;
    Raster out;
    out.position = u.projection * world;
    out.localPosition = v.position.xyz;
    out.normal = normalize((u.model * v.normal).xyz);
    out.worldPosition = world.xyz;
    out.facetWeights = v.surface.z == 3 ? float3(v.surface.xy, 1-v.surface.x-v.surface.y)
        : float3(v.surface.z == 0, v.surface.z == 1, v.surface.z == 2);
    return out;
}

float3 studio(float3 d, float phase) {
    float angle = 0.85 * sin(phase);
    d.xz = float2(cos(angle)*d.x - sin(angle)*d.z, sin(angle)*d.x + cos(angle)*d.z);
    float up = smoothstep(-0.65, 0.85, d.y);
    float3 c = mix(float3(0.002, 0.075, 0.88), float3(0.19, 0.78, 1.0), up);
    float key = pow(saturate(dot(d, normalize(float3(-0.6, 0.8, 0.7)))), 10.0);
    float stripPosition = 0.12 + 0.48 * sin(phase);
    float strip = exp(-pow((d.x + d.y * 0.42 - stripPosition) * 9.0, 2.0));
    float side = pow(saturate(dot(d, normalize(float3(0.8, 0.2, -0.5)))), 18.0);
    c = mix(c, float3(0.68, 0.98, 1.0), key * 0.94);
    c = mix(c, float3(0.80, 0.99, 1.0), strip * 0.64);
    c += side * float3(0.1, 0.3, 0.38);
    return c;
}

float2 facetEdgeRoll(float2 p, float2 a, float2 b) {
    float2 segment = b-a;
    float edgeLength = length(segment);
    float2 along = segment/edgeLength;
    float2 across = float2(-along.y,along.x);
    float distance = dot(p-a,across);
    float progress = dot(p-a,along);
    float width = max(1.6,fwidth(distance));
    float q = distance/width;
    float ends = smoothstep(0.0,5.0,progress)*(1-smoothstep(edgeLength-5.0,edgeLength,progress));
    return across*(q*exp(-q*q)*0.22*ends);
}

float3 polishedNormal(Raster in, float3 localNormal, constant Uniforms &u) {
    // Only the two surface crown diagonals get this tiny optical fillet.
    // The actual outline and the internal optical hull stay unchanged.
    if (in.facetWeights.y <= 0) { return normalize(in.normal); }
    float2 outward = abs(localNormal.x) > abs(localNormal.z)
        ? float2(sign(localNormal.x),0) : float2(0,sign(localNormal.z));
    float2 normalXZ = abs(localNormal.xz);
    float broad = 1-smoothstep(0.20,0.65,min(normalXZ.x,normalXZ.y)/max(max(normalXZ.x,normalXZ.y),0.0001));
    float2 p = sourceFacetPoint(in.localPosition,outward,u);
    float2 roll = facetEdgeRoll(p,float2(258.8,128.9),float2(108.8,240.8))
                + facetEdgeRoll(p,float2(258.8,128.9),float2(406.8,240.8));
    float3 across = float3(outward.y,0,-outward.x);
    float3 up = normalize(cross(localNormal,across));
    float3 normal = normalize(localNormal-(across*roll.x-up*roll.y)*broad*in.facetWeights.y);
    return normalize((u.model*float4(normal,0)).xyz);
}

float studioPanel(float3 reflected, float3 direction, float2 size) {
    float alignment = dot(reflected,direction);
    float3 horizontal = normalize(cross(float3(0,1,0),direction));
    float3 vertical = cross(direction,horizontal);
    float2 point = float2(dot(reflected,horizontal),dot(reflected,vertical))/max(alignment,0.15);
    // Filter the narrow reflection at small sizes and grazing angles.
    float2 dx = dfdx(point), dy = dfdy(point);
    float2 variance = size*size+dx*dx+dy*dy;
    float energy = size.x*size.y/sqrt(variance.x*variance.y);
    return exp(-dot(point*point,1/variance))*energy*smoothstep(0.15,0.40,alignment);
}

float3 surfaceFinish(float3 color, float3 normal, float3 view, constant Uniforms &u) {
    float3 reflected = reflect(-view,normal);
    float phase = u.lightSweep.y;
    float key = studioPanel(reflected,normalize(float3(-0.36+0.14*sin(phase),0.90,0.72)),float2(0.16,0.48));
    float rim = studioPanel(reflected,normalize(float3(0.72,-0.52+0.10*cos(phase),0.18)),float2(0.10,0.60));
    float fresnel = pow(1-saturate(dot(normal,view)),4.0);
    float strength = key*(0.35+0.35*fresnel)+rim*(0.16+0.30*fresnel);
    return mix(color,float3(0.87,0.99,1),strength);
}

float nearestExit(float3 origin, float3 ray, const device float4 *planes, uint count,
                  thread float3 &normal) {
    float nearest = 1e5;
    float second = 1e5;
    float3 secondNormal = normal;
    for (uint i = 0; i < count; ++i) {
        float denominator = dot(planes[i].xyz, ray);
        if (denominator > 0.0001) {
            float t = -(dot(planes[i].xyz, origin) + planes[i].w) / denominator;
            if (t > 0.001 && t < nearest) {
                second = nearest; secondNormal = normal;
                nearest = t; normal = planes[i].xyz;
            } else if (t > 0.001 && t < second) {
                second = t; secondNormal = planes[i].xyz;
            }
        }
    }
    if (second < 1e5) {
        // The optical hull inherits a tiny edge fillet. This also filters its
        // reflected boundaries when they become thinner than a screen pixel.
        float width = max(0.008,min(0.035,fwidth(second-nearest)));
        float blend = 0.5*(1-smoothstep(0.0,width,second-nearest));
        normal = normalize(mix(normal,secondNormal,blend));
    }
    return nearest;
}

float4 oppositeFacets(float3 p, float3 ray, constant Uniforms &u,
                      const device float4 *planes) {
    float3 origin = p + ray*0.004;
    float3 normal = float3(0,1,0);
    float distance = nearestExit(origin,ray,planes,uint(u.viewport.z),normal);
    if (distance > 100 || normal.y > 0.95) { return 0; }
    float3 hit = origin + ray*distance;
    float3 worldNormal = (u.model*float4(normal,0)).xyz;
    float3 tangent = normalize(float3(normal.z+0.00001,0,-normal.x));
    float across = dot(hit,tangent);
    float2 authored = float2(across*225.8, (normal.y > 0 ? 0.3065-hit.y : -0.54-hit.y)*239);
    float3 color;
    if (normal.y > 0) {
        color = referenceCrown(authored,u.crownGradient);
        float response = pow(saturate(dot(worldNormal, normalize(float3(0.7*sin(u.lightSweep.y),0.55,-1)))),4.0);
        color = mix(color*float3(0.45,0.70,0.98), float3(0.60,0.94,1), response*0.55);
    } else {
        // The pavilion is one connected eight-facet hull. Looking through its
        // front reveals the actual opposite facet, without view-switched motifs.
        float3 reflected = normalize((u.model*float4(reflect(ray,normal),0)).xyz);
        float3 environment = studio(reflected,u.lightSweep.y);
        float response = pow(saturate(dot(worldNormal,normalize(float3(-0.4,-0.55,-1)))),2.0);
        color = mix(float3(0.012,0.38,1),float3(0.27,0.94,1),response*0.65+environment.g*0.35);
        color = mix(color,environment,0.28);
        float panel = studioPanel(reflected,normalize(float3(-0.36,0.90,0.72)),float2(0.20,0.52));
        color = mix(color,float3(0.72,0.98,1),panel*0.48);
    }
    float coverage = smoothstep(0.03,0.35,distance) * exp(-distance*0.16);
    return float4(color,coverage);
}

float sourceBand(float2 p, float4 gradient) {
    float2 direction = gradient.zw-gradient.xy;
    float t = dot(p-gradient.xy,direction)/dot(direction,direction);
    return saturate(1-abs(t-0.49)/0.49);
}

float facetSweep(Raster in, float3 localNormal, constant Uniforms &u) {
    float3 tangent = normalize(float3(localNormal.z+0.00001,0,-localNormal.x));
    float across = dot(in.localPosition,tangent)*225.8;
    float side = smoothstep(0.20,0.50,abs(normalize(in.normal).x));
    bool right = in.normal.x > 0;
    float4 crown = mix(u.crownSweep, right ? u.rightCrownSweep : u.leftCrownSweep, side);
    float4 pavilion = mix(u.pavilionSweep, right ? u.rightPavilionSweep : u.leftPavilionSweep, side);
    return sourceBand(float2(across,(0.3065-in.localPosition.y)*239),crown)*in.facetWeights.y
         + sourceBand(float2(across,(-0.54-in.localPosition.y)*235),pavilion)*in.facetWeights.z;
}

float3 internalEnvironment(float3 position, float3 direction, float pavilion, constant Uniforms &u) {
    float3 worldPosition = (u.model*float4(position,1)).xyz;
    float3 worldDirection = normalize((u.model*float4(direction,0)).xyz);
    // A finite studio gives each reflected facet a spatial gradient, rather
    // than a flat swatch. The lights and the optical hull share one 3D space.
    float along = dot(worldPosition,worldDirection);
    float distance = -along+sqrt(max(0.0,along*along+3.2*3.2-dot(worldPosition,worldPosition)));
    float3 sample = normalize(worldPosition+worldDirection*distance);
    if (pavilion <= 0) { return studio(sample,u.lightSweep.y); }
    // Keep a uniform blue surround below the crown. A bright upper hemisphere
    // reflected in the pavilion reads as a filled tip with a horizontal meniscus.
    // Narrow studio panels retain moving reflections without filling whole facets.
    float phase = u.lightSweep.y;
    float key = studioPanel(sample,normalize(float3(-0.12+0.035*sin(phase),-0.60,0.79)),float2(0.055,0.52));
    float rim = studioPanel(sample,normalize(float3(0.12,0.75+0.035*cos(phase),-0.65)),float2(0.055,0.50));
    float3 lower = mix(float3(0.015,0.41,1),float3(0.58,0.94,1),key*0.95);
    lower = mix(lower,float3(0.24,0.78,1),rim*0.82);
    return pavilion < 1 ? mix(studio(sample,u.lightSweep.y),lower,pavilion) : lower;
}

float reflectionTriangle(float3 origin, float3 ray, float3 a, float3 b, float3 c,
                         thread float3 &coordinates) {
    float3 ab = b-a, ac = c-a, crossRay = cross(ray,ac);
    float determinant = dot(ab,crossRay);
    if (abs(determinant) < 0.00001) { return 1e5; }
    float3 offset = origin-a;
    float u = dot(offset,crossRay)/determinant;
    float3 q = cross(offset,ab);
    float v = dot(ray,q)/determinant;
    float t = dot(ac,q)/determinant;
    coordinates = float3(1-u-v,u,v);
    return min(min(coordinates.x,coordinates.y),coordinates.z) >= 0 && t > 0.001 ? t : 1e5;
}

float3 pavilionReflections(float3 color, float3 origin, float3 ray, constant Uniforms &u) {
    if (u.parameters.y <= 0) { return color; }
    const float2 ring[8] = {float2(0,1),float2(0.70710678,0.70710678),
        float2(1,0),float2(0.70710678,-0.70710678),float2(0,-1),
        float2(-0.70710678,-0.70710678),float2(-1,0),float2(-0.70710678,0.70710678)};
    // One convex fan of reflected facets, shared by every camera orientation.
    // Clip the whole volume so adjoining facets never acquire dark seams.
    const float3 top = float3(0,-0.28,0), tip = float3(0,-1.06,0);
    float entry = 0, exit = 1e5;
    float3 entryNormal = float3(0,1,0);
    float3 worldRay = normalize((u.model*float4(ray,0)).xyz);
    float3 illumination = normalize(float3(-0.55,0.65,1));
    float3 sideColor = 0;
    float sideWeight = 0;
    float3 veilColor = 0;
    float veilWeight = 0;
    for (uint i = 0; i < 8; ++i) {
        float2 current = ring[i], next = ring[(i+1)%8];
        float3 a = float3(current.x*0.28,-0.68,current.y*0.28);
        float3 b = float3(next.x*0.28,-0.68,next.y*0.28);
        for (uint part = 0; part < 2; ++part) {
            float3 peak = part == 0 ? top : tip;
            float3 n = normalize(cross(a-peak,b-peak));
            if (dot(n,(a+b+peak)/3-float3(0,-0.68,0)) < 0) { n = -n; }
            float denominator = dot(n,ray);
            float side = dot(n,origin-peak);
            if (abs(denominator) < 0.00001) {
                if (side > 0) { exit = -1; }
            } else {
                float t = -side/denominator;
                if (denominator < 0 && t > entry) { entry = t; entryNormal = n; }
                if (denominator > 0) { exit = min(exit,t); }
            }
        }
        float3 radial = float3(current.x,0,current.y);
        float3 tangent = float3(current.y,0,-current.x);
        // Broad, low-contrast echoes of the crown stretch through the volume
        // towards the same lower junction. Adjacent planes meet without dark gaps.
        // Continue the same planes above the girdle so their top fade stays
        // hidden behind the crown, including the deeper, opposite reflections.
        const float upperY = 0.20;
        const float extension = (upperY+0.12)/0.65;
        const float upperRadius = 0.64+(0.64-0.19)*extension;
        const float upperWidth = 0.265097+(0.265097-0.078701)*extension;
        float3 upperLeft = radial*upperRadius - tangent*upperWidth + float3(0,upperY,0);
        float3 upperRight = radial*upperRadius + tangent*upperWidth + float3(0,upperY,0);
        float3 lowerLeft = radial*0.19 - tangent*0.078701 + float3(0,-0.77,0);
        float3 lowerRight = radial*0.19 + tangent*0.078701 + float3(0,-0.77,0);
        float3 ribbonCoordinates;
        float ribbon = reflectionTriangle(origin,ray,upperLeft,upperRight,lowerLeft,ribbonCoordinates);
        if (ribbon > 100) {
            ribbon = reflectionTriangle(origin,ray,upperRight,lowerRight,lowerLeft,ribbonCoordinates);
        }
        if (ribbon < 100) {
            float3 hit = origin+ray*ribbon;
            float depth = (-0.12-hit.y)/0.65;
            float across = dot(hit,tangent);
            float right = mix(0.265097,0.078701,depth), left = -right;
            float3 worldRadial = normalize((u.model*float4(radial,0)).xyz);
            float facing = saturate(-dot(worldRadial,worldRay));
            float fade = smoothstep(0.0,0.065,upperY-hit.y)*(1-smoothstep(0.70,1.0,depth));
            float opacity = fade*(0.16+0.84*facing);
            float light = saturate(0.5+0.5*dot(worldRadial,illumination));
            // Broad reflected facets fill the middle with restrained diagonal
            // changes in tone, expressed in the fixed plane's own coordinates.
            float acrossPlane = saturate((across-left)/(right-left));
            float diagonal = smoothstep(-0.045,0.045,acrossPlane-0.35-depth*0.55);
            float middle = smoothstep(0.12,0.24,depth)*(1-smoothstep(0.50,0.64,depth));
            float3 tint = mix(float3(0.015,0.56,1),float3(0.33,0.97,1),light);
            tint = mix(tint,float3(0.42,0.97,1),middle*(0.32-0.20*diagonal));
            tint = mix(tint,float3(0.015,0.46,1),diagonal*0.24);
            veilColor += tint*opacity;
            veilWeight += opacity;
        }
        float3 aSide = radial*0.72 + tangent*0.055 + float3(0,-0.30,0);
        float3 bSide = radial*0.49 - tangent*0.105 + float3(0,-0.60,0);
        float3 cSide = radial*0.15 + tangent*0.020 + float3(0,-0.93,0);
        float3 coordinates;
        float t = reflectionTriangle(origin,ray,aSide,bSide,cSide,coordinates);
        if (t < 100) {
            float3 worldRadial = normalize((u.model*float4(radial,0)).xyz);
            // Long glints read at the sides; a front-facing sector must not
            // become an opaque needle in the middle of the stone.
            float sideFacing = 1-abs(dot(worldRadial,worldRay));
            float edge = min(coordinates.y,coordinates.z);
            float opacity = smoothstep(0.20,0.75,sideFacing)
                * smoothstep(0.0,0.085,edge) * smoothstep(0.0,0.035,coordinates.x);
            float light = 0.5+0.5*dot(worldRadial,illumination);
            float3 tint = mix(float3(0.16,0.80,1),float3(0.85,1,1),light);
            sideColor += tint*opacity;
            sideWeight += opacity;
        }
    }
    float strength = saturate(u.parameters.y/0.72);
    if (veilWeight > 0) {
        color = mix(color,veilColor/veilWeight,(1-exp(-veilWeight*0.46))*strength);
    }
    if (sideWeight > 0) {
        color = mix(color,sideColor/sideWeight,(1-exp(-sideWeight*1.4))*strength);
    }
    if (entry < exit) {
        float3 hit = origin+ray*entry;
        float3 worldNormal = normalize((u.model*float4(entryNormal,0)).xyz);
        float light = saturate(dot(worldNormal,normalize(float3(-0.65,0.15,1))));
        float gleam = studioPanel(reflect(worldRay,worldNormal),
            normalize(float3(-0.35+0.15*sin(u.lightSweep.y),0.60,0.75)),float2(0.25,0.65));
        float3 tint = mix(float3(0.025,0.54,1),float3(0.40,0.92,1),light);
        tint = mix(tint,float3(0.72,0.99,1),gleam*0.16);
        float thickness = smoothstep(0.0,0.18,exit-entry);
        float fade = smoothstep(-1.07,-0.93,hit.y);
        color = mix(color,tint,0.28*thickness*fade*strength);
    }
    return color;
}

float3 interior(float3 p, float3 direction, float pavilion, constant Uniforms &u,
                const device float4 *planes) {
    float3 accumulated = 0;
    float weight = 0.60;
    float3 origin = p + direction * 0.004;
    for (uint bounce = 0; bounce < 0; ++bounce) {
        float3 n = float3(0, 1, 0);
        float distance = nearestExit(origin, direction, planes, uint(u.viewport.z), n);
        if (distance > 100) { break; }
        float3 hit = origin + direction * distance;
        float3 outgoing = refract(direction, -n, 1.62);
        float3 reflection = reflect(direction, n);
        float3 color = internalEnvironment(hit,reflection,pavilion,u);
        if (dot(outgoing,outgoing) > 0.01) {
            // Fresnel approaches total internal reflection continuously; a hard
            // switch between the two rays made whole patches change abruptly.
            float incident = saturate(dot(direction,n));
            float transmitted = saturate(dot(outgoing,n));
            float rs = (1.62*incident-transmitted)/(1.62*incident+transmitted);
            float rp = (incident-1.62*transmitted)/(incident+1.62*transmitted);
            float reflectance = 0.5*(rs*rs+rp*rp);
            color = mix(internalEnvironment(hit,outgoing,pavilion,u),color,reflectance);
        }
        color *= exp(-float3(0.30, 0.07, 0.006) * distance);
        accumulated += weight * color;
        weight *= 0.52;
        direction = reflection;
        origin = hit + direction * 0.004;
    }
    return accumulated;
}

float3 materialPalette(float3 color, float3 facetWeights, uint appearance) {
    switch (appearance) {
        case 1: {
            // Keep the authored icy blue in the middle values: interpolating
            // directly to white desaturates the crown into a cold grey.
            float tone = smoothstep(0.0,0.92,saturate(dot(color.rg,float2(0.22,0.78))));
            float3 shadow = mix(float3(0.63,0.77,0.95),float3(0.733,0.859,1),facetWeights.y*0.25);
            const float3 ice = float3(207,241,253) / 255.0; // #cff1fd
            float3 upper = mix(shadow,ice,smoothstep(0.0,0.62,tone));
            upper = mix(upper,float3(1),smoothstep(0.58,1.0,tone)*0.92);
            // Lift the pavilion while retaining a distinct shadow range below
            // the white crown, with a little more blue in its lighter facets.
            float3 lower = mix(float3(0.59,0.71,0.865),float3(0.96,0.985,1),pow(tone,1.10));
            return mix(upper,lower,facetWeights.z);
        }
        case 2: {
            float tone = smoothstep(0.035,0.90,saturate(dot(color.rg,float2(0.20,0.80))));
            float3 cool = mix(float3(0.025,0.29,0.83),float3(0.38,0.78,1),smoothstep(0.0,0.65,tone));
            float3 upper = mix(cool,float3(0.94,0.99,1),smoothstep(0.45,1.0,tone));
            float3 lower = mix(float3(0.025,0.34,0.92),float3(0.90,0.99,1),pow(tone,2.35));
            return mix(upper,lower,facetWeights.z);
        }
        default: return color;
    }
}

float3 coolInnerGlow(float3 color, float3 position, float3 ray, float3 normal, float3 localNormal, float3 view,
                     constant Uniforms &u, const device float4 *planes) {
    // Thin parts transmit a white light band into the stone. The optical chord
    // follows the 3D cut under every rotation, without expanding the silhouette.
    float thickness = 1e5;
    float planeAlignment = 0;
    for (uint i = 0; i < uint(u.viewport.z); ++i) {
        planeAlignment = max(planeAlignment,dot(planes[i].xyz,localNormal));
        float denominator = dot(planes[i].xyz,ray);
        if (denominator > 0.0001) {
            float exit = -(dot(planes[i].xyz,position)+planes[i].w) / denominator;
            thickness = min(thickness,max(0.0,exit));
        }
    }
    // Scale the penetration with the taper: the tip gets a narrow rim,
    // rather than filling with a solid white pool as its whole depth shrinks.
    float crossSection = clamp((position.y+1.09)/0.98,0.07,1.0);
    float inner = 1-smoothstep(0.01,0.80*crossSection,thickness);
    float grazing = 1-saturate(dot(normal,view));
    float roundedEdge = smoothstep(0.0015,0.028,1-planeAlignment);
    float bevel = pow(grazing,3.0);
    float glow = saturate(inner*0.85 + bevel*0.85 + roundedEdge*smoothstep(0.18,0.80,grazing));
    return mix(color,float3(0.96,1,1),glow);
}

// With an EDR target, lifts the brightest parts above SDR white ("light HDR"). Applied as the last
// step of each stone fragment, on the premultiplied output; a no-op when boost is 0.
static float4 withHighlightBoost(float4 color, float boost) {
    if (boost <= 0.0 || color.a <= 0.0) return color;
    float3 straight = color.rgb / color.a;
    float luminance = dot(straight, float3(0.2126, 0.7152, 0.0722));
    return float4(straight * (1.0 + boost * smoothstep(0.55, 1.0, luminance)) * color.a, color.a);
}

float4 diamondSurface(Raster in, constant Uniforms &u, const device float4 *planes) {
    float3 n = normalize(in.normal);
    float cameraDistance = -u.projection[3].w / u.projection[2].w;
    float3 view = normalize(float3(0, 0, cameraDistance) - in.worldPosition);
    float3 localView = (u.inverseModel * float4(-view, 0)).xyz;
    float3 localNormal = normalize((u.inverseModel * float4(n, 0)).xyz);
    float3 transmitted = refract(localView, localNormal, 1.0 / 1.62);
    float3 optical = interior(in.localPosition, transmitted, in.facetWeights.z, u, planes);
    float3 reflection = studio(reflect(-view, n), u.lightSweep.y);
    float fresnel = 0.08 + 0.46 * pow(1.0 - saturate(dot(n, view)), 4.0);

    float height = saturate((in.localPosition.y + 1.05) / 1.65);
    float key = saturate(dot(n, normalize(float3(-0.65, 0.85, 1.0))));
    float left = saturate(0.52 - in.worldPosition.x * 0.43);
    float3 blue = float3(0.008, 0.22, 1.0);
    float3 cyan = float3(0.29, 0.87, 1.0);
    float3 body = mix(blue, cyan, saturate(key * 0.60 + left * 0.38));
    float verticalBand = mix(0.5 + 0.5 * sin(height * 18.0 + n.x * 3.0),1.0,in.facetWeights.z);
    body *= mix(float3(0.24, 0.48, 0.96), float3(1), verticalBand * 0.5 + 0.5);
    float opticalLuminance = smoothstep(0.25, 0.85, optical.g);
    // Give the pavilion a cyan body tone without changing reflection contrast
    // or the subdued lower motif. Crown and table keep their existing palette.
    float3 opticalShadow = mix(float3(0.005,0.13,1),float3(0.015,0.36,1),in.facetWeights.z);
    float3 opticalLight = mix(float3(0.58,0.97,1),float3(0.45,0.99,1),in.facetWeights.z);
    optical = mix(opticalShadow,opticalLight,opticalLuminance);
    float opticalWeight = u.parameters.y * mix(0.90, 0.08, in.facetWeights.y);
    float3 color = mix(body, optical, opticalWeight);
    color = mix(color, reflection, fresnel);

    float crownGlow = smoothstep(0.10, 0.60, in.localPosition.y) * left;
    color = mix(color, float3(0.70, 0.99, 1.0), crownGlow * 0.58);
    float crownLight = pow(saturate(dot(n, normalize(float3(-0.38, 0.55, 1.0)))), 9.0);
    crownLight *= smoothstep(-0.03, 0.28, in.localPosition.y);
    color = mix(color, float3(0.65, 0.98, 1.0), crownLight * 0.35);
    float3 facetBase = color;
    if (in.facetWeights.y > 0) {
        float softbox = exp(-pow((in.worldPosition.x + 0.42) * 1.6, 2.0)
                           -pow((in.worldPosition.y - 0.32) * 2.2, 2.0));
        color = mix(color, float3(0.71, 0.99, 1.0), softbox * crownLight * 0.36);
        float shadow = pow(saturate(1.0 - key), 1.4);
        color = mix(color, float3(0.015, 0.08, 1.0), shadow * 0.7);
        float3 tangent = normalize(float3(localNormal.z, 0, -localNormal.x));
        float2 authoredPosition = float2(dot(in.localPosition, tangent) * 225.8 + n.x * 65,
                                         (0.3065 - in.localPosition.y) * 244);
        color = mix(referenceCrown(authoredPosition, u.crownGradient), color, 0.28);
        color = mix(facetBase, color, in.facetWeights.y);
    }
    if (in.facetWeights.z > 0) {
        color = mix(color,mix(float3(0.008,0.32,1),optical,0.86),in.facetWeights.z*u.parameters.y);
    }
    float facetFlash = smoothstep(0.20, 0.78, opticalLuminance);
    float flashWeight = mix(0.24,0.08,in.facetWeights.y);
    color *= mix(float3(1),mix(float3(0.76, 0.82, 0.99), float3(1), facetFlash),flashWeight);
    color = mix(color, float3(0.66, 0.98, 1), pow(facetFlash, 2.0) * 0.24 * flashWeight);
    color = lateralDepth(color, n, in.localPosition.y, in.facetWeights, opticalLuminance);
    color = mix(color,optical,in.facetWeights.z*u.parameters.y*0.48);
    color = mix(color,body,in.facetWeights.z*pow(saturate(n.z),2.0)*0.32);
    float3 rearRay = normalize(mix(localView,transmitted,mix(0.68,0.18,in.facetWeights.y)));
    float4 rear = oppositeFacets(in.localPosition,rearRay,u,planes);
    float transmission = mix(0.34,0.12+u.lightSweep.z*0.65,in.facetWeights.y) * u.parameters.y;
    float facing = smoothstep(0.12,0.65,n.z);
    color = mix(color,rear.rgb,rear.a*transmission*facing*mix(1.0,0.12,in.facetWeights.y));
    if (in.facetWeights.z > 0) {
        float3 detailRay = normalize(mix(localView,transmitted,0.16));
        color = mix(color,pavilionReflections(color,in.localPosition,detailRay,u),in.facetWeights.z);
    }
    float tipGlow = pow(saturate((-in.localPosition.y - 0.55) / 0.50), 2.0);
    color = mix(color, float3(0.57, 0.96, 1.0), tipGlow * 0.20);
    // A shallow, translucent image of the table, like Layer 36 in Lottie.
    // Its optical footprint is smaller than the rounded outer shoulder.
    float3 tableRay = localView;
    tableRay.y *= 0.72;
    if (tableRay.y > 0.001) {
        float tableHeight = -planes[0].w / planes[0].y;
        float distance = (tableHeight-in.localPosition.y)/tableRay.y;
        float2 hit = (in.localPosition + tableRay*distance).xz;
        const float extent = 0.632;
        const float corner = 0.285;
        float2 q = abs(hit);
        float edge = max(max(q.x,q.y)-extent, (q.x+q.y-extent-corner)*0.70710678);
        float aa = max(fwidth(edge),0.001);
        float coverage = 1-smoothstep(-aa,aa,edge);
        float2 direction = tableRay.xz / max(length(tableRay.xz),0.0001);
        float depth = saturate(0.5+dot(hit,direction)/(2*extent));
        // Source opacity: 80% group opacity times a 49...65% fill gradient.
        float opacity = mix(0.39,0.52,depth);
        color = mix(color,float3(0.765,0.988,1),coverage*opacity
                    *saturate(u.parameters.y/0.72)*in.facetWeights.y);
    }
    color = illustratedFacets(color, in, u);
    color = mix(color, float3(0.63, 0.96, 1), 0.58 * in.facetWeights.x);
    float sweep = facetSweep(in,localNormal,u);
    float sweepCore = smoothstep(0.35,1.0,sweep);
    color = mix(color,float3(0.592,0.953,1),sweep*0.20+sweepCore*sweepCore*0.62);
    color = surfaceFinish(color,polishedNormal(in,localNormal,u),view,u);
    color = materialPalette(color,in.facetWeights,uint(u.appearance.x));
    if (uint(u.appearance.x) == 2) {
        color = coolInnerGlow(color,in.localPosition,localView,n,localNormal,view,u,planes);
    }
    if (uint(u.appearance.x) == 1) {
        // Source facet flashes stay on the physical front/side planes, including
        // their rounded transitions. They never become screen-space overlays.
        float2 direction = normalize(localNormal.xz + float2(0,0.00001));
        float side = smoothstep(0.18,0.65,abs(direction.x));
        float front = smoothstep(0.02,0.32,direction.y);
        float3 regions = float3(1-side, side*step(0.0,direction.x), side*(1-step(0.0,direction.x))) * front;
        float alpha = dot(regions,u.referenceCrownFlash.xyz)*in.facetWeights.y
                    + dot(regions,u.referencePavilionFlash.xyz)*in.facetWeights.z;
        float referenceFacing = smoothstep(0.0,0.2,(u.model * float4(0,0,1,0)).z);
        color = mix(color,float3(1),alpha*referenceFacing);
    }
    float whiten = u.appearance.y;
    if (whiten > 0) {
        float w = pow(whiten, 0.7);
        float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
        float lift = smoothstep(0.32, 0.62, luma);
        float3 glass = mix(float3(0.07, 0.33, 0.95), float3(1.0), lift);
        float rim = pow(1.0 - saturate(abs(n.z)), 2.2);
        glass = mix(glass, float3(1.0), rim * 0.8);
        float seam = saturate(length(fwidth(n)) * 5.5);
        glass = mix(glass, float3(1.0), seam * 0.85);
        glass = max(glass, float3(smoothstep(0.62, 0.95, luma)));
        color = mix(color, glass, w);
        float alpha = mix(1.0, mix(0.34, 0.94, max(lift, max(rim, seam))), w);
        return float4(saturate(color * u.parameters.z) * alpha, alpha);
    }
    return float4(saturate(color * u.parameters.z), 1);
}

fragment float4 diamondFragment(Raster in [[stage_in]], constant Uniforms &u [[buffer(1)]],
                                const device float4 *planes [[buffer(2)]]) {
    return withHighlightBoost(diamondSurface(in, u, planes), u.appearance.z);
}

struct DiamondLensUniforms {
    float4 rect;
    float4 uv;
    float4 viewport; // pixel center, pixels per point, edge count
    float4 parameters; // strength, yaw, radius in points, light background
    float4 center; // lens center in points, preserves source colors, reserved
};

fragment float4 diamondLensFragment(Raster in [[stage_in]], constant Uniforms &u [[buffer(1)]],
                                    const device float4 *planes [[buffer(2)]],
                                    constant DiamondLensUniforms &lens [[buffer(3)]],
                                    constant float4 *edges [[buffer(4)]],
                                    texture2d<float> source [[texture(0)]]) {
    float4 stone = diamondSurface(in, u, planes);
    float2 position = (in.position.xy - lens.viewport.xy) / lens.viewport.z;
    float distanceToEdge = 1e9;
    for (uint i = 0; i < uint(lens.viewport.w); ++i) {
        distanceToEdge = min(distanceToEdge, dot(edges[i].xy, position) + edges[i].z);
    }
    if (distanceToEdge <= 0.0) return withHighlightBoost(stone, u.appearance.z);

    // The reference's faceted lens, in screen points and on the gem's own frame.
    float strength = lens.parameters.x;
    float edge = smoothstep(0.0, 5.0, distanceToEdge) * strength;
    float radius = max(lens.parameters.z, 1.0);
    float2 local = position - lens.center.xy;
    float2 q = local / radius;
    float facet = (asin(clamp(q.x, -0.999, 0.999)) - lens.parameters.y) / (M_PI_F / 4.0);
    float wave = sin(M_PI_F * facet);
    float prism = sign(wave) * pow(abs(wave), 0.6);
    float crown = 1.0 - smoothstep(-0.25, 0.05, q.y);
    float2 bend = float2(prism * 0.12, mix(-0.08 * q.y, 0.09, crown)) * radius;
    float zoom = mix(0.84, 0.72, crown * (1.0 - smoothstep(0.2, 0.6, abs(q.x))));
    float2 samplePosition = lens.center.xy + local * mix(1.0, zoom, edge) + bend * edge;
    float2 sourcePosition = (samplePosition - lens.rect.xy) / lens.rect.zw;
    if (any(sourcePosition < 0.0) || any(sourcePosition > 1.0)) return withHighlightBoost(stone, u.appearance.z);

    // Keep sampling within the source, including when it is a tile in the amount's mask atlas.
    constexpr sampler sourceSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);
    float2 halfTexel = 0.5 / float2(source.get_width(), source.get_height());
    float2 uv = clamp(lens.uv.xy + sourcePosition * lens.uv.zw,
                      lens.uv.xy + halfTexel, lens.uv.xy + lens.uv.zw - halfTexel);
    float4 sampledColor = source.sample(sourceSampler, uv);
    // The model is pitch * yaw, so its up axis measures vertical tilt independently of yaw.
    // Fade only the sampled image into the existing facets, preserving the lens distortion.
    float verticalTilt = asin(clamp(abs(u.model[1].z), 0.0, 1.0));
    float lensVisibility = 1.0 - smoothstep(20.0 * M_PI_F / 180.0, M_PI_F / 4.0, verticalTilt);
    float coverage = strength * smoothstep(0.0, 1.5, distanceToEdge) * lensVisibility;
    if (lens.center.z > 0.5) {
        // The card snapshot contains premultiplied color, including antialiased edges.
        float opacity = 0.7 * coverage;
        stone.rgb = stone.rgb * (1.0 - sampledColor.a * opacity) + sampledColor.rgb * stone.a * opacity;
        return withHighlightBoost(stone, u.appearance.z);
    }
    float opacity = sampledColor.r * 0.55 * coverage;
    float3 tint = lens.parameters.w > 0.5 ? float3(0.02, 0.13, 0.48) : float3(1.0);
    stone.rgb = mix(stone.rgb, tint * stone.a, opacity);
    return withHighlightBoost(stone, u.appearance.z);
}

struct SparkleVertex { float4 contours; float4 material; };
struct SparkleRaster {
    float4 position [[position]];
    float2 sourcePoint;
    float strength [[flat]];
    uint layer [[flat]];
};

struct SparkleAnchor { float4 position; float4 normal; };

vertex SparkleRaster sparkleVertex(uint id [[vertex_id]], uint instance [[instance_id]],
                                   const device SparkleVertex *vertices [[buffer(0)]],
                                   constant Uniforms &u [[buffer(1)]],
                                   const device SparkleAnchor *anchors [[buffer(3)]]) {
    SparkleVertex v = vertices[id];
    uint layer = uint(v.material.x);
    const float authoringToWorld = 2.0 / 447.9;
    float3 local = anchors[instance].position.xyz;
    float3 normal = anchors[instance].normal.xyz;
    if (instance == 0) {
        float c = cos(u.sparkleHalo.y), s = sin(u.sparkleHalo.y);
        local.xz = float2(c*local.x + s*local.z, -s*local.x + c*local.z);
        normal.xz = float2(c*normal.x + s*normal.z, -s*normal.x + c*normal.z);
    }
    if (instance != 0) { local += normal * 0.008; }
    float3 worldNormal = (u.model * float4(normal, 0)).xyz;
    float pulse = pow(max(0.0, sin(u.parameters.x * 2.1 + float(instance) * 2.37 + 1.5)), 16.0);
    float front = instance == 0 ? u.sparkleHalo.w : smoothstep(0.15, 0.55, worldNormal.z);
    float strength = front * u.parameters.w;
    float4 center = u.projection * u.model * float4(local, 1);
    if (u.viewport.w > 0) {
        center = float4(0, 0, 0.5, 1);
        strength = instance == 0 ? u.parameters.w : 0;
    }
    float morph = instance == 0 ? u.sparkleShape.y : 0;
    float2 sourcePoint = mix(v.contours.xy, v.contours.zw, morph);
    float groupScale = 1;
    float2 offset = 0;
    if (layer == 0) { groupScale = u.sparkleHalo.x; offset.y = 5.9; }
    if (layer == 1) { groupScale = u.sparkleShape.w; offset.y = -0.8; }
    if (layer == 2) { groupScale = u.sparkleShape.z; offset.y = -0.9; }
    if (layer == 3) { groupScale = 0.309; offset = float2(0.6, -0.4); }
    float mainEnvelope = u.viewport.w > 0 ? 1.0 : u.sparkleHalo.w;
    float scale = instance == 0 ? u.sparkleShape.x * mainEnvelope : (0.632 / 0.75) * pulse;
    float2 point = (sourcePoint * groupScale + offset) * authoringToWorld * scale;
    SparkleRaster out;
    // Correct the anchor with the gem, but keep the authored flare proportions.
    out.position = center + center.w * float4(point.x * u.projection[0][0] / u.sparkleHalo.z,
                                  -point.y * u.projection[1][1], 0, 0);
    out.sourcePoint = sourcePoint;
    out.strength = strength;
    out.layer = layer;
    return out;
}

struct ReferenceHighlight {
    float4 position;
    float4 facing;
    float4 axisX;
    float4 axisY;
};

vertex SparkleRaster referenceHighlightVertex(uint id [[vertex_id]], uint instance [[instance_id]],
                                              const device SparkleVertex *vertices [[buffer(0)]],
                                              constant Uniforms &u [[buffer(1)]],
                                              constant ReferenceHighlight *highlights [[buffer(3)]]) {
    SparkleVertex v = vertices[id];
    ReferenceHighlight h = highlights[instance];
    uint layer = uint(v.material.x);
    float3 facing = (u.model * float4(h.facing.xyz, 0)).xyz;
    SparkleRaster out;
    out.layer = layer;
    out.sourcePoint = v.contours.xy;
    out.strength = h.facing.w * u.parameters.w * smoothstep(0.05, 0.35, facing.z);
    if (layer == 5) {
        float4 point = h.position + h.axisX * v.contours.x + h.axisY * v.contours.y;
        out.position = u.projection * u.model * point;
    } else {
        float2 point = v.contours.xy;
        if (layer == 3) { point = point * 0.309 + float2(0.6, -0.4); }
        point *= (2.0 / 447.9) * h.axisX.x;
        float4 center = u.projection * u.model * h.position;
        out.position = center + center.w * float4(point.x * u.projection[0][0] / u.sparkleHalo.z,
                                      -point.y * u.projection[1][1], 0, 0);
    }
    return out;
}

float radialOpacity(float radius, float first, float middle) {
    if (radius <= first) { return 1; }
    if (radius <= middle) { return mix(1.0, 0.5, (radius-first)/(middle-first)); }
    return 0.5 * saturate((1-radius)/(1-middle));
}

fragment float4 sparkleFragment(SparkleRaster in [[stage_in]], constant Uniforms &u [[buffer(1)]]) {
    float alpha = 1;
    float3 color = 1;
    if (in.layer == 0) {
        float r = length(in.sourcePoint - float2(-0.5, 0.2)) / 108.5;
        alpha = radialOpacity(r, 0.312, 0.624) * 0.60;
    } else if (in.layer == 1) {
        float r = length(in.sourcePoint - float2(-0.5, 0.9)) / 113.1;
        alpha = radialOpacity(r, 0.297, 0.503) * 0.60;
        color = float3(0.82, 1, 0.902);
    } else if (in.layer == 2) {
        alpha = 0.96;
    } else if (in.layer == 3) {
        float r = saturate(length(in.sourcePoint) / length(float2(176, -170)));
        alpha = 1 - r;
        color = mix(float3(0.694, 0.969, 1), float3(0.663, 0.957, 1), r);
    } else if (in.layer == 5) {
        alpha = radialOpacity(length(in.sourcePoint) / length(float2(228.9, 3.9)), 0.237, 0.623);
    }
    if (uint(u.appearance.x) == 1) {
        color = in.layer == 0 ? float3(0.635,0.749,1) : float3(1);
        // The white source retains only the circular halo, without the extra
        // star-shaped glow used by the blue material.
        if (in.layer == 1) { alpha = 0; }
    } else if (uint(u.appearance.x) == 2) {
        color = in.layer == 1 ? float3(0.82,0.96,1) : float3(1);
    }
    // Keep premultiplied alpha valid when HDR exposes values above SDR white.
    alpha = saturate(alpha * in.strength);
    // Match the stone's HDR brightness so SDR-white flares do not darken its highlights.
    return withHighlightBoost(float4(color * alpha, alpha), u.appearance.z);
}
