#include "Subdivision.hpp"
#include "../ThirdParty/opensubdiv/far/topologyDescriptor.h"
#include "../ThirdParty/opensubdiv/far/topologyRefinerFactory.h"
#include "../ThirdParty/opensubdiv/far/primvarRefiner.h"
#include "../ThirdParty/opensubdiv/far/patchTableFactory.h"
#include "../ThirdParty/opensubdiv/osd/patchBasis.h"
#include <stdexcept>
#include <set>

namespace gift {
using namespace OpenSubdiv;
namespace {
struct SurfacePatch {
    uint32_t type=0,field0=0,field1=0,segments=1;
    uint32_t controls[20]{};
    uint32_t uvType=0,uvField0=0,uvField1=0,influenceCount=0;
    uint32_t uvControls[20]{};
    uint32_t influenceOffset=0;
};
struct PatchInfluence { uint32_t joint=0;float weights[4]{}; };
struct SubdivisionSurface {
    uint32_t controlCount=0,morphCount=0;
    std::vector<Vec4> positions;
    std::vector<Vec2> uv;
    std::vector<SurfacePatch> patches;
    std::vector<PatchInfluence> influences;
};
template<int N> struct Value {
    float x[N]{};
    void Clear(){std::fill(x,x+N,0.f);}
    void AddWithWeight(const Value& v,float w){for(int k=0;k<N;k++)x[k]+=v.x[k]*w;}
};
void check(bool ok,const char* message){if(!ok)throw std::runtime_error(message);}
void validateCage(const Primitive& p,const SubdivisionCage& cage) {
    check(cage.level>=1 && cage.level<=4,"Subdivision level must be 1..4");
    check(p.base.size()<=4096 && cage.faceSizes.size()<=4096,"Subdivision cage exceeds limits");
    size_t corners=0;
    // Preserve polygon caps (including the 32-sided top hat) before subdivision.
    for(int n:cage.faceSizes){check(n>=3 && n<=32,"Invalid subdivision face");corners+=n;}
    check(corners==cage.faceIndices.size() && corners==cage.uvIndices.size(),"Invalid subdivision corners");
    for(int i:cage.faceIndices)check(i>=0 && size_t(i)<p.base.size(),"Invalid subdivision index");
    for(int i:cage.uvIndices)check(i>=0 && size_t(i)<cage.uvValues.size(),"Invalid subdivision UV index");
}
void basis(const SurfacePatch& p,float u,float v,float* w,float* du,float* dv,bool uv=false) {
    auto param=Osd::OsdPatchParamInit(uv?p.uvField0:p.field0,uv?p.uvField1:p.field1,0);
    Osd::OsdEvaluatePatchBasisNormalized(uv?p.uvType:p.type,param,u,v,w,du,dv,nullptr,nullptr,nullptr);
}
Vertex sample(const SubdivisionSurface& s,const SurfacePatch& p,float u,float v,int target) {
    float w[20]{},du[20]{},dv[20]{};basis(p,u,v,w,du,dv);
    Vec3 pos{},a{},b{};
    int count=p.type==6?16:20;
    for(int k=0;k<count;k++) {
        auto q=s.positions[target*s.controlCount+p.controls[k]];Vec3 x{q.x,q.y,q.z};
        pos=pos+x*w[k];a=a+x*du[k];b=b+x*dv[k];
    }
    auto normal=normalize(cross(a,b));
    basis(p,u,v,w,du,dv,true);Vec2 tex{};
    count=p.uvType==6?16:p.uvType==3?4:20;
    for(int k=0;k<count;k++){auto x=s.uv[p.uvControls[k]];tex.x+=x.x*w[k];tex.y+=x.y*w[k];}
    return {pos,normal,tex};
}
}
static std::unique_ptr<SubdivisionSurface> prepareSubdivision(const Primitive& p,const SubdivisionCage& cage) {
    validateCage(p,cage);
    Far::TopologyDescriptor desc;
    desc.numVertices=int(p.base.size());desc.numFaces=int(cage.faceSizes.size());
    desc.numVertsPerFace=cage.faceSizes.data();desc.vertIndicesPerFace=cage.faceIndices.data();
    Far::TopologyDescriptor::FVarChannel channel;
    channel.numValues=int(cage.uvValues.size());channel.valueIndices=cage.uvIndices.data();
    desc.numFVarChannels=1;desc.fvarChannels=&channel;
    Sdc::Options opts;opts.SetVtxBoundaryInterpolation(Sdc::Options::VTX_BOUNDARY_EDGE_AND_CORNER);
    opts.SetFVarLinearInterpolation(Sdc::Options::FVAR_LINEAR_BOUNDARIES);
    Far::TopologyRefinerFactory<Far::TopologyDescriptor>::Options factory(Sdc::SCHEME_CATMARK,opts);factory.validateFullTopology=true;
    auto ref=std::unique_ptr<Far::TopologyRefiner>(Far::TopologyRefinerFactory<Far::TopologyDescriptor>::Create(desc,factory));
    check(bool(ref),"Invalid Catmull-Clark topology");
    Far::PatchTableFactory::Options po(cage.level);
    po.generateFVarTables=true;po.generateFVarLegacyLinearPatches=false;
    ref->RefineAdaptive(po.GetRefineAdaptiveOptions());
    auto table=std::unique_ptr<Far::PatchTable>(Far::PatchTableFactory::Create(*ref,po));
    check(bool(table) && table->GetNumPatchesTotal()<=30000,"Subdivision patch budget exceeded");
    Far::PrimvarRefiner interp(*ref);
    auto out=std::make_unique<SubdivisionSurface>();
    int nc=ref->GetNumVerticesTotal(),nt=nc+table->GetNumLocalPoints();
    check(nt<=300000,"Subdivision control budget exceeded");
    out->controlCount=nt;out->morphCount=uint32_t(p.morphPositions.size());
    for(size_t t=0;t<=p.morphPositions.size();t++) {
        std::vector<Value<3>> values(nt);
        for(size_t i=0;i<p.base.size();i++) {
            auto v=p.base[i].position;if(t)v=v+p.morphPositions[t-1][i];
            values[i]={{v.x,v.y,v.z}};
        }
        int offset=0;
        for(int l=1;l<=ref->GetMaxLevel();l++) {
            auto* src=values.data()+offset;offset+=ref->GetLevel(l-1).GetNumVertices();auto* dst=values.data()+offset;
            interp.Interpolate(l,src,dst);
        }
        table->ComputeLocalPointValues(values.data(),values.data()+nc);
        for(auto v:values)out->positions.push_back({v.x[0],v.x[1],v.x[2],0});
    }
    int nu=ref->GetNumFVarValuesTotal(),ntu=nu+table->GetNumLocalPointsFaceVarying();
    std::vector<Value<2>> uv(ntu);
    for(size_t i=0;i<cage.uvValues.size();i++)uv[i]={{cage.uvValues[i].x,cage.uvValues[i].y}};
    int offset=0;
    for(int l=1;l<=ref->GetMaxLevel();l++) {
        auto* src=uv.data()+offset;offset+=ref->GetLevel(l-1).GetNumFVarValues();auto* dst=uv.data()+offset;
        interp.InterpolateFaceVarying(l,src,dst);
    }
    table->ComputeLocalPointValuesFaceVarying(uv.data(),uv.data()+nu);
    for(auto x:uv)out->uv.push_back({x.x[0],x.x[1]});
    std::set<int> jointSet;
    for(size_t v=0;v<p.joints.size();v++)for(int k=0;k<p.influences;k++)if(p.weights[v][k]>0)jointSet.insert(p.joints[v][k]);
    check(jointSet.size()<=256,"Too many subdivision joints");
    std::vector<int> joints(jointSet.begin(),jointSet.end());
    std::vector<Value<256>> weights(nc+table->GetNumLocalPointsVarying());
    if(p.skin>=0) {
        for(size_t v=0;v<p.base.size();v++)for(int k=0;k<p.influences;k++) {
            auto it=std::lower_bound(joints.begin(),joints.end(),p.joints[v][k]);
            if(it!=joints.end() && *it==p.joints[v][k])weights[v].x[it-joints.begin()]+=p.weights[v][k];
        }
        offset=0;
        for(int l=1;l<=ref->GetMaxLevel();l++) {
            auto* src=weights.data()+offset;offset+=ref->GetLevel(l-1).GetNumVertices();auto* dst=weights.data()+offset;
            interp.InterpolateVarying(l,src,dst);
        }
        table->ComputeLocalPointValuesVarying(weights.data(),weights.data()+nc);
    }
    for(int a=0;a<table->GetNumPatchArrays();a++)for(int i=0;i<table->GetNumPatches(a);i++) {
        SurfacePatch patch;patch.type=table->GetPatchArrayDescriptor(a).GetType();
        check(patch.type==6 || patch.type==9,"Unsupported subdivision patch type");
        auto param=table->GetPatchParam(a,i);patch.field0=param.field0;patch.field1=param.field1;
        int depth=param.GetDepth();patch.segments=1u<<std::max(0,cage.level-depth);
        auto vi=table->GetPatchVertices(a,i);std::copy(vi.begin(),vi.end(),patch.controls);
        auto up=table->GetPatchFVarPatchParam(a,i);patch.uvField0=up.field0;patch.uvField1=up.field1;
        patch.uvType=(up.IsRegular()?table->GetFVarPatchDescriptorRegular():table->GetFVarPatchDescriptorIrregular()).GetType();
        check(patch.uvType==6 || patch.uvType==9 || patch.uvType==3,"Unsupported UV patch");
        auto ui=table->GetPatchFVarValues(a,i);int un=patch.uvType==6?16:patch.uvType==3?4:20;
        std::copy_n(ui.begin(),un,patch.uvControls);
        if(p.skin>=0) {
            patch.influenceOffset=uint32_t(out->influences.size());auto wi=table->GetPatchVaryingVertices(a,i);
            check(wi.size()==4,"Unsupported varying patch");
            for(size_t j=0;j<joints.size();j++) {
                PatchInfluence inf;inf.joint=joints[j];float sum=0;
                for(int k=0;k<4;k++){inf.weights[k]=weights[wi[k]].x[j];sum+=inf.weights[k];}
                if(sum>0){out->influences.push_back(inf);patch.influenceCount++;}
            }
            check(patch.influenceCount<=32,"Subdivision exceeds 32 influences");
        }
        out->patches.push_back(patch);
    }
    if(out->influences.empty())out->influences.push_back({});
    return out;
}
void useControlCage(Primitive& p,const SubdivisionCage& cage) {
    validateCage(p,cage);
    auto base=std::move(p.base);auto joints=std::move(p.joints);auto weights=std::move(p.weights);
    auto positions=std::move(p.morphPositions);auto normals=std::move(p.morphNormals);
    p.base.clear();p.joints.clear();p.weights.clear();p.indices.clear();
    p.morphPositions.assign(positions.size(),{});p.morphNormals.assign(normals.size(),{});
    // Each corner keeps the UV stored for that original polygon, including seams.
    for(size_t corner=0;corner<cage.faceIndices.size();corner++) {
        int v=cage.faceIndices[corner];auto vertex=base[v];vertex.uv=cage.uvValues[cage.uvIndices[corner]];
        p.base.push_back(vertex);
        if(p.skin>=0) {
            auto w=weights[v];float sum=0;for(float x:w)sum+=x;
            for(float& x:w)x/=sum;p.joints.push_back(joints[v]);p.weights.push_back(w);
        }
        for(size_t t=0;t<positions.size();t++) {
            p.morphPositions[t].push_back(positions[t][v]);p.morphNormals[t].push_back(normals[t][v]);
        }
    }
    uint32_t start=0;
    for(int n:cage.faceSizes) {
        for(int k=1;k<n-1;k++)p.indices.insert(p.indices.end(),{start,start+uint32_t(k),start+uint32_t(k+1)});
        start+=n;
    }
}
void applySubdivision(Primitive& p,const SubdivisionCage& cage) {
    auto surface=prepareSubdivision(p,cage);const auto& s=*surface;
    p.base.clear();p.indices.clear();p.weights.clear();p.joints.clear();p.influences=0;
    p.morphPositions.assign(s.morphCount,{});p.morphNormals.assign(s.morphCount,{});
    size_t count=0;for(auto& q:s.patches)count+=(q.segments+1)*(q.segments+1);
    check(count<=200000,"Subdivision mesh exceeds vertex budget");p.base.reserve(count);
    for(auto& q:s.patches) {
        uint32_t start=uint32_t(p.base.size()),n=q.segments;
        p.influences=std::max(p.influences,int(q.influenceCount));
        for(uint32_t y=0;y<=n;y++)for(uint32_t x=0;x<=n;x++) {
            float u=float(x)/n,v=float(y)/n;auto vertex=sample(s,q,u,v,0);p.base.push_back(vertex);
            for(uint32_t t=0;t<s.morphCount;t++) {
                auto m=sample(s,q,u,v,t+1);p.morphPositions[t].push_back(m.position-vertex.position);p.morphNormals[t].push_back(m.normal-vertex.normal);
            }
            if(p.skin>=0) {
                std::array<uint16_t,32> ji{};std::array<float,32> we{};
                float basis[4]{(1-u)*(1-v),u*(1-v),u*v,(1-u)*v},sum=0;
                for(uint32_t k=0;k<q.influenceCount;k++) {
                    auto inf=s.influences[q.influenceOffset+k];ji[k]=uint16_t(inf.joint);
                    for(int c=0;c<4;c++)we[k]+=basis[c]*inf.weights[c];sum+=we[k];
                }
                for(auto& w:we)w/=std::max(sum,1e-12f);
                p.joints.push_back(ji);p.weights.push_back(we);
            }
        }
        for(uint32_t y=0;y<n;y++)for(uint32_t x=0;x<n;x++) {
            auto a=start+y*(n+1)+x,b=a+1,c=a+n+2,d=a+n+1;
            p.indices.insert(p.indices.end(),{a,b,c,a,c,d});
        }
    }
}
}
