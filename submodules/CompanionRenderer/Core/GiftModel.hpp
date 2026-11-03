#pragma once
#include "Math.hpp"
#include <array>
#include <cstdint>
#include <memory>
#include <string>
#include <vector>

namespace gift {
struct Vertex { Vec3 position,normal; Vec2 uv; };
struct Image { std::string name; std::vector<uint8_t> encoded; };
struct Material {
    Vec4 baseColor{1,1,1,1}; Vec3 emissive{};
    float metallic=1,roughness=1,alphaCutoff=.5f,ior=1.5f;
    int image=-1,emissiveImage=-1; bool doubleSided=false,unlit=false,alphaMask=false;
    int wrapS=10497,wrapT=10497; bool nearest=false;
    int emissiveWrapS=10497,emissiveWrapT=10497;bool emissiveNearest=false;
    // Optional giftMaterialProfile v1: authored Shader-to-RGB ramp and outline.
    std::vector<Vec4> toonRamp; // RGB + stop position, max 8 ordered stops.
    int toonInterpolation=0,lightMask=255; // 0 linear, 1 constant, 2 ease.
    Vec3 outlineColor{};float outlineWidth=0;
    bool matcap=false; // Base texture sampled by view-space normal, not mesh UV.
    float matcapScale=1; // Decode scale for the sRGB-encoded HDR MatCap.
};
struct AreaLight { Vec3 position,axisU,axisV,color;float power=0; };
struct Camera { bool orthographic=false;Mat4 world;float xmag=2,ymag=2,nearZ=.01f,farZ=100; };
struct RenderProfile {
    bool enabled=false,composite=false;std::vector<AreaLight> lights;
    Vec3 worldDiffuse{},worldSpecular{},background{};
    float exposure=0,gamma=1;Vec2 ramp{.8f,.99545455f},maskPosition{},maskSize{};
    float maskRotation=0;Vec3 tint{};
};
struct Primitive {
    std::string name,slot; int node=-1,skin=-1,material=0;
    std::vector<Vertex> base;
    std::vector<uint32_t> indices;
    int influences=0;
    std::vector<std::array<uint16_t,32>> joints;
    std::vector<std::array<float,32>> weights;
    std::vector<std::vector<Vec3>> morphPositions,morphNormals;
};
struct alignas(16) JointTransform { Mat4 position,normal; };
struct Pose {
    std::vector<Mat4> world,normal;
    std::vector<JointTransform> joints;
    std::vector<uint32_t> skinOffsets;
    std::vector<std::array<float,16>> morphWeights;
};
enum class AssetKind { Legacy,Model,Animation,Materials,Item,Scene };
struct AttachmentSocket { std::string id,node;Mat4 offset; };
struct AssetMetadata {
    AssetKind kind=AssetKind::Legacy;
    std::string id,rig,localRig,uv,attachment;
    std::vector<AttachmentSocket> sockets;
};
class GiftModel {
public:
    static std::unique_ptr<GiftModel> load(const std::string& path,bool applySubdivision=true,bool library=false);
    struct Node {
        int parent=-1;Vec3 translation{},scale{1,1,1};Vec4 rotation{0,0,0,1};
        Mat4 matrix{};bool hasMatrix=false;std::vector<float> weights;
        std::string id,externalJoint;std::vector<std::string> morphIds;
    };
    struct Skin { std::vector<int> joints;std::vector<Mat4> inverseBind; };
    struct Channel {
        int node=-1,path=0,width=0,interpolation=0;
        std::vector<float> times,values;
        std::string targetId;std::vector<std::string> morphIds;
    };
    const std::vector<Node>& restNodes() const {return rest;}
    const std::vector<Skin>& skinData() const {return skins;}
    const std::vector<Channel>& animationChannels() const {return channels;}
    const std::vector<int>& nodeOrder() const {return hierarchy;}
    static std::array<float,16> sampleChannel(const Channel& c,float seconds);
    void evaluatePose(float seconds);
    const Pose& pose() const { return currentPose; }
    std::vector<Primitive> primitives;
    std::vector<Material> materials;
    std::vector<Image> images;
    std::vector<std::string> materialSlots;
    AssetMetadata metadata;
    Camera camera;RenderProfile profile;
    Bounds animationBounds;
    float duration=0;
    bool hasSubdivision=false,controlCage=false;
    size_t sourceVertexCount=0;
    size_t jointCount=0,animationCount=0,triangleCount=0;
private:
    std::vector<Node> rest,nodes;
    std::vector<Skin> skins;
    std::vector<Channel> channels;
    std::vector<int> hierarchy;
    Pose currentPose;
    void calculateAnimationBounds();
};
}
