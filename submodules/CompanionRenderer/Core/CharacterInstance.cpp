#include "CharacterInstance.hpp"
#include "cgltf.h"
#include <fstream>
#include <set>
#include <stdexcept>
#include <sstream>

namespace gift {
namespace {
void require(bool ok,const std::string& message){if(!ok)throw std::runtime_error(message);}
std::map<std::string,int> nodeMap(const GiftModel& model) {
    std::map<std::string,int> out;
    for(size_t i=0;i<model.restNodes().size();i++) {
        const auto& id=model.restNodes()[i].id;if(id.empty())continue;
        require(out.emplace(id,int(i)).second,"Duplicate node identifier: "+id);
    }return out;
}
std::vector<BoundTrack> bindTracks(const GiftModel& model,const GiftModel& clip,bool embedded) {
    const auto ids=nodeMap(model);std::vector<BoundTrack> out;std::set<std::pair<int,int>> properties;
    const auto& animationRig=model.metadata.kind==AssetKind::Item && !model.metadata.localRig.empty()?model.metadata.localRig:model.metadata.rig;
    if(!embedded)require(!animationRig.empty() && clip.metadata.rig==animationRig,"Animation uses an incompatible rig");
    for(const auto& channel:clip.animationChannels()) {
        BoundTrack t;t.channel=&channel;
        if(embedded && channel.node>=0)t.node=channel.node;
        else {auto i=ids.find(channel.targetId);require(i!=ids.end(),"Animation node is missing: "+channel.targetId);t.node=i->second;}
        require(t.node>=0 && size_t(t.node)<model.restNodes().size(),"Animation node is out of range");
        const auto& node=model.restNodes()[t.node];
        require(node.externalJoint.empty(),"Item animations cannot change character bones");
        require(!node.hasMatrix || channel.path==cgltf_animation_path_type_weights,"Animated nodes require TRS transforms");
        require(properties.emplace(t.node,channel.path).second,"Duplicate animation property");
        if(channel.path==cgltf_animation_path_type_weights) {
            for(int k=0;k<channel.width;k++) {
                if(embedded && channel.morphIds.empty())t.morphs[k]=k;
                else {
                    require(size_t(k)<channel.morphIds.size(),"Animation is missing morph identifiers");
                    auto it=std::find(node.morphIds.begin(),node.morphIds.end(),channel.morphIds[k]);
                    require(it!=node.morphIds.end(),"Morph target is missing: "+channel.targetId+"/"+channel.morphIds[k]);
                    t.morphs[k]=int(it-node.morphIds.begin());
                }
                require(size_t(t.morphs[k])<node.weights.size(),"Animation morph target is out of range");
            }
        }out.push_back(t);
    }return out;
}
void resetLocal(const GiftModel& data,std::vector<LocalPose>& local) {
    for(size_t i=0;i<local.size();i++) {
        const auto& n=data.restNodes()[i];auto& p=local[i];
        p.translation=n.translation;p.rotation=n.rotation;p.scale=n.scale;p.weights.fill(0);
        std::copy(n.weights.begin(),n.weights.end(),p.weights.begin());
    }
}
void blend(LocalPose& target,const LocalPose& from,float t) {
    target.translation=from.translation*(1-t)+target.translation*t;
    target.scale=from.scale*(1-t)+target.scale*t;target.rotation=slerp(from.rotation,target.rotation,t);
    for(size_t i=0;i<target.weights.size();i++)target.weights[i]=from.weights[i]*(1-t)+target.weights[i]*t;
}
template<AssetKind K> std::shared_ptr<const ComponentAsset<K>> typed(AssetResource value) {
    auto result=std::make_shared<ComponentAsset<K>>();static_cast<AssetResource&>(*result)=std::move(value);return result;
}
}

AssetResource AssetLibrary::load(const std::string& path,AssetKind kind,bool subdivide) {
    std::ifstream stream(path,std::ios::binary|std::ios::ate);require(stream.good(),"Cannot open component GLB");
    auto size=stream.tellg();require(size>0 && size<=32*1024*1024,"Component must be smaller than 32 MB");
    std::string bytes(size_t(size),'\0');stream.seekg(0);stream.read(bytes.data(),bytes.size());require(bool(stream),"Cannot read component GLB");
    auto accepts=[&](const GiftModel& d){require(d.metadata.kind==kind || (kind==AssetKind::Model && d.metadata.kind==AssetKind::Legacy),"This file is a different component type");};
    for(auto it=entries.begin();it!=entries.end();) {
        auto data=it->data.lock();if(!data){it=entries.erase(it);continue;}
        if(it->subdivide==subdivide && it->bytes==bytes){accepts(*data);return {data,it->key,path,bytes.size()};}++it;
    }
    std::shared_ptr<const GiftModel> data=GiftModel::load(path,subdivide,true);accepts(*data);
    if(kind==AssetKind::Model || kind==AssetKind::Item) {
        require(!data->primitives.empty(),"Component has no supported meshes");nodeMap(*data);
        for(const auto& socket:data->metadata.sockets)require(nodeMap(*data).count(socket.node),"Socket node is missing: "+socket.node);
    }
    if(kind==AssetKind::Materials) {
        require(data->materials.size()>1 && data->primitives.empty(),"Material component must contain materials and no meshes");
        std::set<std::string> slots;
        for(size_t i=0;i+1<data->materials.size();i++)require(!data->materialSlots[i].empty() && slots.insert(data->materialSlots[i]).second,"Material slots must be nonempty and unique");
        for(const auto& material:data->materials)
            if((material.image>=0 && !material.matcap) || material.emissiveImage>=0)require(!data->metadata.uv.empty(),"Textured materials must declare a compatible UV layout");
    }
    if(kind==AssetKind::Scene)require(data->primitives.empty() && data->profile.enabled,"Scene component requires a render profile and no meshes");
    // A process-local identity for identical content, disambiguated by full bytes.
    AssetResource result{data,"asset-"+std::to_string(++serial),path,bytes.size()};
    entries.push_back({std::move(bytes),result.key,subdivide,data});recent.push_back(result);
    size_t cached=0;for(const auto& r:recent)cached+=r.fileBytes;
    while(recent.size()>8 || (cached>64*1024*1024 && recent.size()>1)){cached-=recent.front().fileBytes;recent.pop_front();}
    return result;
}
std::shared_ptr<const ModelAsset> AssetLibrary::model(const std::string& p,bool s){return typed<AssetKind::Model>(load(p,AssetKind::Model,s));}
std::shared_ptr<const ItemAsset> AssetLibrary::item(const std::string& p,bool s){return typed<AssetKind::Item>(load(p,AssetKind::Item,s));}
std::shared_ptr<const AnimationClip> AssetLibrary::animation(const std::string& p){return typed<AssetKind::Animation>(load(p,AssetKind::Animation,false));}
std::shared_ptr<const MaterialSet> AssetLibrary::materials(const std::string& p){return typed<AssetKind::Materials>(load(p,AssetKind::Materials,false));}
std::shared_ptr<const SceneAsset> AssetLibrary::scene(const std::string& p){return typed<AssetKind::Scene>(load(p,AssetKind::Scene,false));}

void RigInstance::initialize(const AssetResource& asset) {
    resource=asset;clip.reset();time=fadeElapsed=fadeDuration=0;
    const auto& d=*asset.data;local.resize(d.restNodes().size());transitionFrom.resize(local.size());externalNodes.assign(local.size(),-1);
    pose.world.resize(local.size());pose.normal.resize(local.size());pose.morphWeights.resize(local.size());pose.skinOffsets.clear();
    size_t offset=0;for(const auto& s:d.skinData()){pose.skinOffsets.push_back(uint32_t(offset));offset+=s.joints.size();}
    pose.joints.resize(std::max(size_t(1),offset));tracks=bindTracks(d,d,true);sample();resolve();
}
float RigInstance::duration()const {return clip?clip->data->duration:resource.data->duration;}
void RigInstance::selectClip(std::shared_ptr<const AnimationClip> value,float seconds) {
    auto next=bindTracks(*resource.data,value?*value->data:*resource.data,!value);
    transitionFrom=local;tracks=std::move(next);clip=std::move(value);time=fadeElapsed=0;fadeDuration=std::max(seconds,0.f);sample();
}
void RigInstance::advance(float seconds) {
    if(duration()>0)time=std::fmod(time+seconds,duration());
    fadeElapsed=std::min(fadeElapsed+seconds,fadeDuration);
}
void RigInstance::sample() {
    resetLocal(*resource.data,local);
    for(const auto& t:tracks) {
        const auto& c=*t.channel;auto value=GiftModel::sampleChannel(c,time);auto& p=local[t.node];
        switch(c.path) {
            case cgltf_animation_path_type_translation:p.translation={value[0],value[1],value[2]};break;
            case cgltf_animation_path_type_rotation:p.rotation={value[0],value[1],value[2],value[3]};break;
            case cgltf_animation_path_type_scale:p.scale={value[0],value[1],value[2]};break;
            case cgltf_animation_path_type_weights:for(int k=0;k<c.width;k++)p.weights[t.morphs[k]]=value[k];break;
            default:break;
        }
    }
    if(fadeDuration>0 && fadeElapsed<fadeDuration)for(size_t i=0;i<local.size();i++)blend(local[i],transitionFrom[i],fadeElapsed/fadeDuration);
}
void RigInstance::resolve(const Mat4& root,const Pose* character) {
    const auto& data=*resource.data;
    for(int i:data.nodeOrder()) {
        const auto& n=data.restNodes()[i];const auto& p=local[i];
        if(character && externalNodes[i]>=0)pose.world[i]=character->world[externalNodes[i]];
        else {
            Mat4 m=n.hasMatrix?n.matrix:trs(p.translation,p.rotation,p.scale);
            pose.world[i]=(n.parent<0?root:pose.world[n.parent])*m;
        }
        pose.normal[i]=normalMatrix(pose.world[i]);pose.morphWeights[i]=p.weights;
    }
    for(size_t i=0;i<data.skinData().size();i++) {
        const auto& skin=data.skinData()[i];
        for(size_t j=0;j<skin.joints.size();j++) {
            Mat4 m=pose.world[skin.joints[j]]*skin.inverseBind[j];pose.joints[pose.skinOffsets[i]+j]={m,normalMatrix(m)};
        }
    }
}

std::vector<std::string> CharacterInstance::setModel(std::shared_ptr<const ModelAsset> value) {
    require(bool(value),"Select a model first");std::vector<std::string> removed;auto oldClip=body.clip;float oldTime=body.time;
    model=std::move(value);body.initialize(*model);camera=model->data->camera;bounds=model->data->animationBounds;
    if(oldClip) {
        try{body.selectClip(oldClip,0);body.time=std::min(oldTime,body.duration());}
        catch(const std::exception&){removed.push_back("Animation removed: incompatible rig or morph targets.");}
    }
    if(materials)try{checkMaterials(*model->data,*materials);}catch(const std::exception&){materials.reset();removed.push_back("Materials removed: incompatible slots or UV layout.");}
    for(auto i=items.begin();i!=items.end();) {
        try{bindItem(*i);++i;}catch(const std::exception&){removed.push_back("Item removed from "+i->socket+": incompatible socket or rig.");i=items.erase(i);}
    }
    if(environment){camera=environment->data->camera;profile=environment->data->profile;}else profile=model->data->profile;
    evaluate();return removed;
}
void CharacterInstance::checkMaterials(const GiftModel& geometry,const MaterialSet& value)const {
    const auto& m=*value.data;
    if(!m.metadata.uv.empty())require(m.metadata.uv==geometry.metadata.uv,"Materials use an incompatible UV layout");
    for(const auto& p:geometry.primitives) {
        const auto& slots=m.materialSlots;
        require((!p.slot.empty() && std::find(slots.begin(),slots.end(),p.slot)!=slots.end()) || std::find(slots.begin(),slots.end(),"*")!=slots.end(),"Materials do not define slot: "+p.slot);
    }
}
MaterialBinding CharacterInstance::binding(const RigInstance& rig,const Primitive& mesh,const MaterialSet* override)const {
    if(!override)return {&rig.resource,size_t(mesh.material)};
    const auto& slots=override->data->materialSlots;auto it=std::find(slots.begin(),slots.end(),mesh.slot);
    if(mesh.slot.empty() || it==slots.end())it=std::find(slots.begin(),slots.end(),"*");
    require(it!=slots.end(),"Materials do not define slot: "+mesh.slot);return {override,size_t(it-slots.begin())};
}
void CharacterInstance::applyMaterials(std::shared_ptr<const MaterialSet> value) {
    require(bool(model),"Select a model first");if(value)checkMaterials(*model->data,*value);materials=std::move(value);
}
void CharacterInstance::bindItem(ItemInstance& item)const {
    require(bool(model),"Select a model first");const auto& data=*model->data;const auto& meta=item.asset->data->metadata;
    const auto ids=nodeMap(data);const auto& sockets=data.metadata.sockets;
    auto s=std::find_if(sockets.begin(),sockets.end(),[&](const AttachmentSocket& x){return x.id==item.socket;});
    require(s!=sockets.end(),"Model has no socket: "+item.socket);
    require(meta.attachment.empty() || meta.attachment==item.socket,"Item does not fit this socket");
    require(meta.rig.empty() || meta.rig==data.metadata.rig,"Item uses an incompatible rig");
    item.socketNode=ids.at(s->node);item.socketOffset=s->offset;
    for(size_t i=0;i<item.rig.externalNodes.size();i++) {
        const auto& id=item.asset->data->restNodes()[i].externalJoint;item.rig.externalNodes[i]=-1;
        if(!id.empty()){
            require(!meta.rig.empty(),"Items with shared bones must declare a character rig");
            auto b=ids.find(id);require(b!=ids.end(),"Item bone is missing: "+id);item.rig.externalNodes[i]=b->second;
        }
    }
}
void CharacterInstance::attach(const std::string& socket,std::shared_ptr<const ItemAsset> value) {
    require(bool(value),"Select an item");ItemInstance next;next.socket=socket;next.asset=std::move(value);next.rig.initialize(*next.asset);bindItem(next);
    auto old=std::find_if(items.begin(),items.end(),[&](const ItemInstance& i){return i.socket==socket;});
    if(old!=items.end()) {
        if(old->materials) {try{checkMaterials(*next.asset->data,*old->materials);next.materials=old->materials;}catch(const std::exception&) {}}
        *old=std::move(next);
    }else {require(items.size()<16,"Too many attached items");items.push_back(std::move(next));}
    evaluate();
}
void CharacterInstance::detach(const std::string& socket) {items.erase(std::remove_if(items.begin(),items.end(),[&](const ItemInstance& i){return i.socket==socket;}),items.end());}
void CharacterInstance::applyItemMaterials(const std::string& socket,std::shared_ptr<const MaterialSet> value) {
    for(auto& i:items)if(i.socket==socket){if(value)checkMaterials(*i.asset->data,*value);i.materials=std::move(value);return;}
    throw std::runtime_error("This socket has no item");
}
void CharacterInstance::play(std::shared_ptr<const AnimationClip> clip,bool playing,float fade) {
    require(bool(model),"Select a model first");body.selectClip(std::move(clip),playing?fade:0);evaluate();
}
void CharacterInstance::playItem(const std::string& socket,std::shared_ptr<const AnimationClip> clip,bool playing,float fade) {
    for(auto& i:items)if(i.socket==socket){i.rig.selectClip(std::move(clip),playing?fade:0);evaluate();return;}
    throw std::runtime_error("This socket has no item");
}
void CharacterInstance::setEnvironment(std::shared_ptr<const SceneAsset> value) {
    require(bool(model),"Select a model first");environment=std::move(value);
    profile=environment?environment->data->profile:model->data->profile;camera=environment?environment->data->camera:model->data->camera;
}
void CharacterInstance::advance(float dt) {if(!model)return;body.advance(dt);for(auto& i:items)i.rig.advance(dt);}
void CharacterInstance::seek(float seconds) {
    if(!model)return;body.time=std::clamp(seconds,0.f,body.duration());body.fadeDuration=0;
    for(auto& i:items){i.rig.time=i.rig.duration()>0?std::fmod(seconds,i.rig.duration()):0;i.rig.fadeDuration=0;}evaluate();
}
void CharacterInstance::evaluate() {
    if(!model)return;body.sample();body.resolve();
    for(auto& i:items){i.rig.sample();i.rig.resolve(body.pose.world[i.socketNode]*i.socketOffset,&body.pose);}
}
size_t CharacterInstance::fileBytes()const {
    std::map<std::string,size_t> unique;
    auto add=[&](const AssetResource* a){if(a)unique[a->key]=a->fileBytes;};
    add(model.get());add(materials.get());add(environment.get());add(body.clip.get());
    for(const auto& i:items){add(i.asset.get());add(i.materials.get());add(i.rig.clip.get());}
    size_t total=0;for(const auto& p:unique)total+=p.second;return total;
}
size_t CharacterInstance::triangleCount()const {size_t n=model?model->data->triangleCount:0;for(const auto& i:items)n+=i.asset->data->triangleCount;return n;}
size_t CharacterInstance::sourceVertexCount()const {size_t n=model?model->data->sourceVertexCount:0;for(const auto& i:items)n+=i.asset->data->sourceVertexCount;return n;}
}
