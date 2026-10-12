#pragma once
#include "GiftModel.hpp"
#include <deque>
#include <map>

namespace gift {
// Decoded resources are shared and immutable. Only instances own a live pose.
struct AssetResource {
    std::shared_ptr<const GiftModel> data;
    std::string key,path;
    size_t fileBytes=0;
};
template<AssetKind Kind> struct ComponentAsset : AssetResource {};
using ModelAsset=ComponentAsset<AssetKind::Model>;
using AnimationClip=ComponentAsset<AssetKind::Animation>;
using MaterialSet=ComponentAsset<AssetKind::Materials>;
using ItemAsset=ComponentAsset<AssetKind::Item>;
using SceneAsset=ComponentAsset<AssetKind::Scene>;

class AssetLibrary {
public:
    std::shared_ptr<const ModelAsset> model(const std::string&,bool subdivide=true);
    std::shared_ptr<const ItemAsset> item(const std::string&,bool subdivide=true);
    std::shared_ptr<const AnimationClip> animation(const std::string&);
    std::shared_ptr<const MaterialSet> materials(const std::string&);
    std::shared_ptr<const SceneAsset> scene(const std::string&);
private:
    // Exact byte comparison resolves hash collisions; no path/mtime assumptions.
    struct Entry {std::string bytes,key;bool subdivide;std::weak_ptr<const GiftModel> data;};
    std::vector<Entry> entries;
    std::deque<AssetResource> recent;
    uint64_t serial=0;
    AssetResource load(const std::string&,AssetKind,bool);
};
struct LocalPose {
    Vec3 translation,scale{1,1,1};Vec4 rotation{0,0,0,1};
    std::array<float,16> weights{};
};
struct BoundTrack {
    const GiftModel::Channel* channel=nullptr;int node=-1;
    std::array<int,16> morphs{};
};
struct RigInstance {
    AssetResource resource;
    std::shared_ptr<const AnimationClip> clip;
    std::vector<BoundTrack> tracks;
    std::vector<LocalPose> local,transitionFrom;
    Pose pose;
    std::vector<int> externalNodes;
    float time=0,fadeElapsed=0,fadeDuration=0;
    void initialize(const AssetResource&);
    void selectClip(std::shared_ptr<const AnimationClip>,float fadeSeconds);
    void advance(float seconds);
    void sample();
    void resolve(const Mat4& root={},const Pose* character=nullptr);
    float duration()const;
};
struct ItemInstance {
    std::string socket;
    std::shared_ptr<const ItemAsset> asset;
    std::shared_ptr<const MaterialSet> materials;
    RigInstance rig;
    int socketNode=-1;Mat4 socketOffset;
};
struct MaterialBinding {const AssetResource* resource;size_t index;};
class CharacterInstance {
public:
    std::shared_ptr<const ModelAsset> model;
    std::shared_ptr<const MaterialSet> materials;
    std::shared_ptr<const SceneAsset> environment;
    RigInstance body;
    std::vector<ItemInstance> items;
    Camera camera;RenderProfile profile;Bounds bounds;

    // Renderer stages a copy, prepares GPU resources, then commits it atomically.
    std::vector<std::string> setModel(std::shared_ptr<const ModelAsset>);
    void applyMaterials(std::shared_ptr<const MaterialSet>);
    void attach(const std::string& socket,std::shared_ptr<const ItemAsset>);
    void detach(const std::string& socket);
    void applyItemMaterials(const std::string&,std::shared_ptr<const MaterialSet>);
    void play(std::shared_ptr<const AnimationClip>,bool playing,float fadeSeconds=.2f);
    void playItem(const std::string&,std::shared_ptr<const AnimationClip>,bool playing,float fadeSeconds=.2f);
    void setEnvironment(std::shared_ptr<const SceneAsset>);
    void advance(float seconds);
    void seek(float seconds);
    void evaluate();
    MaterialBinding binding(const RigInstance&,const Primitive&,const MaterialSet*)const;
    size_t fileBytes()const;
    size_t triangleCount()const;
    size_t sourceVertexCount()const;
private:
    void bindItem(ItemInstance&)const;
    void checkMaterials(const GiftModel&,const MaterialSet&)const;
};
}
