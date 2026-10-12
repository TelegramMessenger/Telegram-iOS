#pragma once
#include "GiftModel.hpp"
#include <cstddef>
#include <type_traits>

namespace gift {
struct GPUInfluence { uint32_t joint;float weight; };
struct alignas(16) GPUMorphDelta { Vec4 position,normal; };
struct alignas(16) GPUDeformParams {
    Mat4 world,normal;
    std::array<float,16> morphWeights{};
    uint32_t vertexCount=0,influenceCount=0,morphCount=0,jointOffset=0;
    uint32_t skinned=0,padding[3]{};
};
struct alignas(16) GPUVertexUniforms { Mat4 viewProjection;GPUDeformParams deform; };
static_assert(sizeof(Vertex)==32 && offsetof(Vertex,normal)==12 && offsetof(Vertex,uv)==24);
static_assert(sizeof(Mat4)==64 && sizeof(JointTransform)==128 && alignof(JointTransform)==16);
static_assert(offsetof(JointTransform,normal)==64);
static_assert(sizeof(GPUInfluence)==8 && offsetof(GPUInfluence,weight)==4);
static_assert(sizeof(GPUMorphDelta)==32 && offsetof(GPUMorphDelta,normal)==16);
static_assert(sizeof(GPUDeformParams)==224 && offsetof(GPUDeformParams,morphWeights)==128);
static_assert(offsetof(GPUDeformParams,vertexCount)==192 && offsetof(GPUDeformParams,skinned)==208);
static_assert(sizeof(GPUVertexUniforms)==288 && std::is_standard_layout<GPUVertexUniforms>::value);
static_assert(alignof(GPUVertexUniforms)==16 && offsetof(GPUVertexUniforms,deform)==64);
inline GPUDeformParams deformationParams(const Primitive& p,const Pose& pose) {
    GPUDeformParams d;d.world=pose.world[p.node];d.normal=pose.normal[p.node];d.morphWeights=pose.morphWeights[p.node];
    d.vertexCount=uint32_t(p.base.size());d.influenceCount=uint32_t(p.influences);d.morphCount=uint32_t(p.morphPositions.size());
    d.skinned=p.skin>=0;d.jointOffset=p.skin>=0?pose.skinOffsets[p.skin]:0;return d;
}
// Only used at upload/validation time. Target-major morphs and compact per-mesh
// influences keep the 8-influence body without paying for 32 on every vertex.
inline std::vector<GPUInfluence> gpuInfluences(const Primitive& p) {
    std::vector<GPUInfluence> out;out.reserve(p.base.size()*p.influences);
    for(size_t v=0;v<p.joints.size();v++)for(int i=0;i<p.influences;i++)out.push_back({p.joints[v][i],p.weights[v][i]});
    if(out.empty())out.push_back({0,0});return out;
}
inline std::vector<GPUMorphDelta> gpuMorphs(const Primitive& p) {
    std::vector<GPUMorphDelta> out;out.reserve(p.base.size()*p.morphPositions.size());
    for(size_t t=0;t<p.morphPositions.size();t++)for(size_t v=0;v<p.base.size();v++) {
        auto a=p.morphPositions[t][v],b=p.morphNormals[t][v];out.push_back({{a.x,a.y,a.z,0},{b.x,b.y,b.z,0}});
    }
    if(out.empty())out.push_back({});return out;
}
}
