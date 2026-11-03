#include "GiftModel.hpp"
#include "Subdivision.hpp"
#define CGLTF_IMPLEMENTATION
#include "cgltf.h"
#include <cstring>
#include <fstream>
#include <functional>
#include <set>
#include <stdexcept>

namespace gift {
namespace {
void require(bool condition,const char* message) { if(!condition) throw std::runtime_error(message); }
std::vector<float> floats(const cgltf_accessor* a,size_t width=0) {
    require(a!=nullptr,"Missing accessor");
    size_t components=cgltf_num_components(a->type);
    require(!width || components==width,"Unexpected accessor type");
    require(a->count<=1000000 && components<=16,"Accessor exceeds prototype limits");
    std::vector<float> result(a->count*components);
    require(cgltf_accessor_unpack_floats(a,result.data(),result.size())==result.size(),"Cannot decode accessor");
    for(float v:result) require(std::isfinite(v),"Non-finite value in asset");
    return result;
}
const cgltf_accessor* attribute(const cgltf_attribute* attrs,size_t count,cgltf_attribute_type type,int index=0) {
    for(size_t i=0;i<count;i++) if(attrs[i].type==type && attrs[i].index==index) return attrs[i].data;
    return nullptr;
}
Vec3 vec3(const std::vector<float>& v,size_t i) { return {v[i*3],v[i*3+1],v[i*3+2]}; }
// Reuse the JSON tokenizer already vendored with cgltf. Keep the private profile
// parser here so the public C++ interface has no platform/JSON dependencies.
struct ProfileJSON {
    const char* text;std::vector<jsmntok_t> tokens;
    explicit ProfileJSON(const char* s):text(s),tokens(2048) {
        require(std::strlen(s)<32768,"Render profile is too large");
        jsmn_parser parser;jsmn_init(&parser);
        int n=jsmn_parse(&parser,s,std::strlen(s),tokens.data(),tokens.size());
        require(n>0,"Invalid render profile JSON");tokens.resize(n);
    }
    // The document chunk is length-delimited, not necessarily NUL-terminated.
    ProfileJSON(const char* s,size_t size):text(s) {
        require(s && size<=32*1024*1024,"Invalid GLB JSON chunk");
        jsmn_parser parser;jsmn_init(&parser);
        int count=jsmn_parse(&parser,s,size,nullptr,0);
        require(count>0 && count<=2*1024*1024,"GLB JSON exceeds token limit");
        tokens.resize(count);jsmn_init(&parser);
        require(jsmn_parse(&parser,s,size,tokens.data(),tokens.size())==count,"Invalid GLB JSON chunk");
    }
    std::string value(int i)const {require(i>=0 && size_t(i)<tokens.size(),"Missing profile field");return {text+tokens[i].start,size_t(tokens[i].end-tokens[i].start)};}
    int next(int i)const {
        require(i>=0 && size_t(i)<tokens.size(),"Missing profile value");
        auto end=tokens[i].end;do{++i;}while(size_t(i)<tokens.size() && tokens[i].start<end);return i;
    }
    int field(int parent,const char* name,bool required=true)const {
        require(parent>=0 && size_t(parent)<tokens.size() && tokens[parent].type==JSMN_OBJECT,"Invalid profile object");
        for(int i=parent+1;size_t(i)<tokens.size() && tokens[i].start<tokens[parent].end;) {
            require(tokens[i].type==JSMN_STRING && size_t(i+1)<tokens.size() && tokens[i+1].end<=tokens[parent].end,"Invalid profile field");
            if(value(i)==name)return i+1;i=next(i+1);
        }
        require(!required,"Missing render profile field");return -1;
    }
    float number(int i)const {
        auto s=value(i);char* end=nullptr;float f=std::strtof(s.c_str(),&end);
        require(tokens[i].type==JSMN_PRIMITIVE && end==s.c_str()+s.size() && std::isfinite(f),"Invalid profile number");return f;
    }
    std::vector<float> array(int p,const char* name,int count)const {
        int a=field(p,name);require(tokens[a].type==JSMN_ARRAY && tokens[a].size==count,"Invalid profile vector");
        std::vector<float> v;for(int j=0;j<count;j++)v.push_back(number(a+j+1));return v;
    }
    Vec3 v3(int p,const char* n)const {auto v=array(p,n,3);return {v[0],v[1],v[2]};}
    Vec2 v2(int p,const char* n)const {auto v=array(p,n,2);return {v[0],v[1]};}
    std::string string(int p,const char* n,bool required=true)const {
        int i=field(p,n,required);if(i<0)return {};
        require(tokens[i].type==JSMN_STRING,"Expected a string identifier");
        auto s=value(i);require(!s.empty() && s.size()<=256 && s.find('\\')==std::string::npos,"Invalid asset identifier");return s;
    }
    std::vector<std::string> strings(int p,const char* n)const {
        int a=field(p,n,false);if(a<0)return {};
        require(tokens[a].type==JSMN_ARRAY && tokens[a].size<=16,"Invalid morph identifiers");
        std::vector<std::string> out;std::set<std::string> unique;
        for(int i=a+1;i<next(a);i=next(i)) {
            require(tokens[i].type==JSMN_STRING,"Invalid morph identifier");auto s=value(i);
            require(!s.empty() && unique.insert(s).second,"Duplicate morph identifier");out.push_back(s);
        }return out;
    }
};
std::vector<std::vector<std::string>> readChannelBindings(const cgltf_data& data) {
    std::vector<std::vector<std::string>> bindings(data.animations_count);
    if(!data.animations_count)return bindings;
    // cgltf exposes target.extensions through cgltf_animation_channel, but
    // skips channel.extensions, where GIFT_animation_binding v1 is authored.
    // Read that field from the original JSON without modifying vendored cgltf
    // or requiring existing component files to be re-exported.
    ProfileJSON json(data.json,data.json_size);
    int animations=json.field(0,"animations");
    require(json.tokens[animations].type==JSMN_ARRAY && size_t(json.tokens[animations].size)==data.animations_count,"Invalid animation array");
    int animation=animations+1;
    for(size_t i=0;i<data.animations_count;i++,animation=json.next(animation)) {
        int channels=json.field(animation,"channels");
        require(json.tokens[channels].type==JSMN_ARRAY && size_t(json.tokens[channels].size)==data.animations[i].channels_count,"Invalid animation channels");
        bindings[i].resize(data.animations[i].channels_count);
        int channel=channels+1;
        for(size_t j=0;j<bindings[i].size();j++,channel=json.next(channel)) {
            int extensions=json.field(channel,"extensions",false);if(extensions<0)continue;
            int binding=json.field(extensions,"GIFT_animation_binding",false);
            if(binding>=0)bindings[i][j]=json.value(binding);
        }
    }
    return bindings;
}
AssetMetadata readMetadata(const char* extras) {
    AssetMetadata m;if(!extras)return m;ProfileJSON j(extras);int a=j.field(0,"giftAsset",false);if(a<0)return m;
    require(j.number(j.field(a,"version"))==1,"Unsupported component version");
    auto kind=j.string(a,"kind");
    if(kind=="model")m.kind=AssetKind::Model;else if(kind=="animation")m.kind=AssetKind::Animation;
    else if(kind=="materials")m.kind=AssetKind::Materials;else if(kind=="item")m.kind=AssetKind::Item;
    else if(kind=="scene")m.kind=AssetKind::Scene;else require(false,"Unknown component kind");
    m.id=j.string(a,"id");m.rig=j.string(a,"rig",false);m.localRig=j.string(a,"localRig",false);
    m.uv=j.string(a,"uv",false);m.attachment=j.string(a,"attachment",false);
    int sockets=j.field(a,"sockets",false);
    if(sockets>=0) {
        require(j.tokens[sockets].type==JSMN_ARRAY && j.tokens[sockets].size<=16,"Too many attachment sockets");std::set<std::string> ids;
        for(int i=sockets+1;i<j.next(sockets);i=j.next(i)) {
            AttachmentSocket s;s.id=j.string(i,"id");s.node=j.string(i,"node");
            require(ids.insert(s.id).second,"Duplicate attachment socket");
            auto v=j.array(i,"offset",16);std::copy(v.begin(),v.end(),s.offset.m);m.sockets.push_back(s);
        }
    }return m;
}
RenderProfile readProfile(const char* extras) {
    RenderProfile p;if(!extras)return p;ProfileJSON j(extras);
    int root=j.field(0,"giftRenderProfile",false);if(root<0)return p;
    require(j.number(j.field(root,"version"))==1,"Unsupported giftRenderProfile version");
    require(j.value(j.field(root,"viewTransform"))=="Standard","Unsupported output transform");
    p.enabled=true;p.worldDiffuse=j.v3(root,"worldDiffuse");p.worldSpecular=j.v3(root,"worldSpecular");p.background=j.v3(root,"background");
    p.exposure=j.number(j.field(root,"exposure"));p.gamma=j.number(j.field(root,"gamma"));
    require(std::abs(p.exposure)<=20 && p.gamma>0 && p.gamma<=10,"Invalid display settings");
    int lights=j.field(root,"areaLights");require(j.tokens[lights].type==JSMN_ARRAY && j.tokens[lights].size<=8,"Too many area lights");
    for(int i=lights+1;size_t(i)<j.tokens.size() && j.tokens[i].start<j.tokens[lights].end;) {
        AreaLight l{j.v3(i,"position"),j.v3(i,"axisU"),j.v3(i,"axisV"),j.v3(i,"color"),j.number(j.field(i,"power"))};
        require(length(cross(l.axisU,l.axisV))>1e-6f && l.power>=0 && l.power<1e7f,"Invalid area light");
        p.lights.push_back(l);i=j.next(i);
    }
    int c=j.field(root,"compositor");auto enabled=j.value(j.field(c,"enabled"));require(enabled=="true" || enabled=="false","Invalid compositor state");
    p.composite=enabled=="true";p.ramp=j.v2(c,"ramp");p.tint=j.v3(c,"tint");p.maskPosition=j.v2(c,"position");p.maskSize=j.v2(c,"size");p.maskRotation=j.number(j.field(c,"rotation"));
    require(p.ramp.y>p.ramp.x && p.maskSize.x>0 && p.maskSize.y>0,"Invalid compositor mask");return p;
}
}

std::unique_ptr<GiftModel> GiftModel::load(const std::string& path,bool applySubdivision,bool library) {
    std::ifstream file(path,std::ios::binary|std::ios::ate);
    require(file.good(),"Cannot open GLB file");auto size=file.tellg();
    require(size>0 && size<=32*1024*1024,"GLB must be smaller than 32 MB");
    cgltf_options options{};cgltf_data* raw=nullptr;
    require(cgltf_parse_file(&options,path.c_str(),&raw)==cgltf_result_success,"Invalid glTF/GLB data");
    std::unique_ptr<cgltf_data,decltype(&cgltf_free)> data(raw,cgltf_free);
    require(raw->file_type==cgltf_file_type_glb,"Select a self-contained .glb file");
    require(raw->nodes_count<=2048,"Unsupported scene size");
    for(size_t i=0;i<raw->buffers_count;i++) require(!raw->buffers[i].uri,"External buffers are not supported");
    for(size_t i=0;i<raw->extensions_required_count;i++)
        require(std::strcmp(raw->extensions_required[i],"GIFT_subdivision")==0 || std::strcmp(raw->extensions_required[i],"GIFT_animation_binding")==0 || std::strcmp(raw->extensions_required[i],"KHR_materials_unlit")==0 || std::strcmp(raw->extensions_required[i],"KHR_materials_ior")==0 || std::strcmp(raw->extensions_required[i],"KHR_materials_emissive_strength")==0,"A required glTF extension is not supported");
    for(size_t i=0;i<raw->buffer_views_count;i++) require(!raw->buffer_views[i].has_meshopt_compression,"Compressed geometry is not supported yet");
    require(cgltf_load_buffers(&options,raw,path.c_str())==cgltf_result_success,"Cannot load GLB buffers");
    require(cgltf_validate(raw)==cgltf_result_success,"glTF validation failed");
    auto model=std::make_unique<GiftModel>();
    model->metadata=readMetadata(raw->extras.data);
    require(library || model->metadata.kind==AssetKind::Legacy || model->metadata.kind==AssetKind::Model,"Select a model GLB, or import this component in Customize");
    model->profile=readProfile(raw->extras.data);
    auto nodeIndex=[&](const cgltf_node* n){ return n?int(n-raw->nodes):-1; };

    require(raw->images_count<=64 && raw->materials_count<=128,"Too many textures or materials");
    for(size_t i=0;i<raw->images_count;i++) {
        const auto& image=raw->images[i];
        require(image.buffer_view && !image.uri,"Only embedded PNG/JPEG textures are supported");
        require(image.mime_type && (std::strcmp(image.mime_type,"image/png")==0 || std::strcmp(image.mime_type,"image/jpeg")==0),"Texture must be PNG or JPEG");
        const auto* bytes=cgltf_buffer_view_data(image.buffer_view);
        require(bytes!=nullptr,"Missing embedded image");
        model->images.push_back({image.name?image.name:"Texture",{bytes,bytes+image.buffer_view->size}});
    }
    for(size_t i=0;i<raw->materials_count;i++) {
        const auto& src=raw->materials[i];Material m;
        require(src.alpha_mode!=cgltf_alpha_mode_blend,"Transparent BLEND materials are not supported by this prototype");
        require(!src.has_pbr_specular_glossiness && !src.has_clearcoat && !src.has_transmission && !src.has_volume && !src.has_specular && !src.has_sheen && !src.has_iridescence && !src.has_diffuse_transmission && !src.has_anisotropy && !src.has_dispersion,"Material extension is not supported by this prototype");
        require(!src.normal_texture.texture && !src.occlusion_texture.texture,"Normal and occlusion texture maps are not supported yet");
        m.ior=src.has_ior?src.ior.ior:1.5f;
        require(std::isfinite(m.ior) && m.ior>=1,"Unsupported IOR");
        const auto& em=src.emissive_texture;
        if(em.texture) {
            require(!em.has_transform && em.texcoord==0 && em.texture->image && !em.texture->has_basisu && !em.texture->has_webp,"Unsupported emissive texture");
            m.emissiveImage=int(em.texture->image-raw->images);
            if(auto* s=em.texture->sampler) {m.emissiveWrapS=s->wrap_s;m.emissiveWrapT=s->wrap_t;m.emissiveNearest=s->mag_filter==cgltf_filter_type_nearest;}
        }
        m.doubleSided=src.double_sided;m.unlit=src.unlit;m.alphaMask=src.alpha_mode==cgltf_alpha_mode_mask;m.alphaCutoff=src.alpha_cutoff;
        float strength=src.has_emissive_strength?src.emissive_strength.emissive_strength:1.f;
        m.emissive={src.emissive_factor[0]*strength,src.emissive_factor[1]*strength,src.emissive_factor[2]*strength};
        if(src.has_pbr_metallic_roughness) {
            const auto& p=src.pbr_metallic_roughness;
            require(!p.metallic_roughness_texture.texture,"Metallic/roughness textures are not supported yet");
            m.baseColor={p.base_color_factor[0],p.base_color_factor[1],p.base_color_factor[2],p.base_color_factor[3]};
            m.metallic=p.metallic_factor;m.roughness=p.roughness_factor;
            const auto& t=p.base_color_texture;
            require(!t.has_transform && t.texcoord==0,"Only untransformed TEXCOORD_0 is supported");
            if(t.texture) {
                require(t.texture->image && !t.texture->has_basisu && !t.texture->has_webp,"Unsupported texture encoding");
                m.image=int(t.texture->image-raw->images);
                if(t.texture->sampler) {
                    auto* s=t.texture->sampler;m.wrapS=s->wrap_s;m.wrapT=s->wrap_t;m.nearest=s->mag_filter==cgltf_filter_type_nearest;
                }
            }
        }
        if(src.extras.data) {
            ProfileJSON j(src.extras.data);int root=j.field(0,"giftMaterialProfile",false);
            if(root>=0) {
                require(j.number(j.field(root,"version"))==1,"Unsupported material profile version");
                float mask=j.number(j.field(root,"lightMask"));require(mask>=0 && mask<=255 && mask==std::floor(mask),"Invalid material light mask");m.lightMask=int(mask);
                m.outlineColor=j.v3(root,"outlineColor");m.outlineWidth=j.number(j.field(root,"outlineWidth"));
                require(m.outlineWidth>=0 && m.outlineWidth<=.2f,"Invalid outline width");
                int shading=j.field(root,"shading",false);
                if(shading>=0) {
                    require(j.value(shading)=="MATCAP","Unsupported material shading mode");
                    require(m.image>=0 && m.emissiveImage<0 && !m.alphaMask,"MatCap requires an opaque base texture");
                    m.matcap=true;
                    int scale=j.field(root,"matcapScale",false);
                    if(scale>=0)m.matcapScale=j.number(scale);
                    require(m.matcapScale>0 && m.matcapScale<=16,"Invalid MatCap decode scale");
                }
                int ramp=j.field(root,"ramp",false);
                if(ramp>=0) {
                    require(j.tokens[ramp].type==JSMN_ARRAY && j.tokens[ramp].size>=2 && j.tokens[ramp].size<=8,"Invalid toon ramp");
                    float previous=-1;
                    for(int i=ramp+1;size_t(i)<j.tokens.size() && j.tokens[i].start<j.tokens[ramp].end;i=j.next(i)) {
                        Vec3 c=j.v3(i,"color");float t=j.number(j.field(i,"position"));
                        require(t>=0 && t<=1 && t>previous,"Toon ramp stops must increase");previous=t;m.toonRamp.push_back({c.x,c.y,c.z,t});
                    }
                    auto interpolation=j.value(j.field(root,"interpolation"));
                    require(interpolation=="LINEAR" || interpolation=="CONSTANT" || interpolation=="EASE","Unsupported toon ramp interpolation");
                    m.toonInterpolation=interpolation=="CONSTANT"?1:interpolation=="EASE"?2:0;
                }
            }
        }
        std::string slot;
        if(src.extras.data){ProfileJSON j(src.extras.data);slot=j.string(0,"giftSlot",false);}
        model->materialSlots.push_back(slot);model->materials.push_back(m);
    }
    model->materials.emplace_back(); // glTF default material
    model->materialSlots.emplace_back();

    model->rest.resize(raw->nodes_count);
    for(size_t i=0;i<raw->nodes_count;i++) {
        const auto& src=raw->nodes[i];auto& n=model->rest[i];n.parent=nodeIndex(src.parent);
        n.translation={src.translation[0],src.translation[1],src.translation[2]};
        n.rotation={src.rotation[0],src.rotation[1],src.rotation[2],src.rotation[3]};
        n.scale={src.scale[0],src.scale[1],src.scale[2]};n.hasMatrix=src.has_matrix;
        if(n.hasMatrix) std::copy(src.matrix,src.matrix+16,n.matrix.m);
        if(src.weights_count) n.weights.assign(src.weights,src.weights+src.weights_count);
        else if(src.mesh && src.mesh->weights_count) n.weights.assign(src.mesh->weights,src.mesh->weights+src.mesh->weights_count);
        else if(src.mesh && src.mesh->primitives_count) n.weights.resize(src.mesh->primitives[0].targets_count,0);
        require(n.weights.size()<=16,"Too many morph weights");
        if(src.extras.data) {
            ProfileJSON j(src.extras.data);int a=j.field(0,"giftNode",false);
            if(a>=0){n.id=j.string(a,"id");n.externalJoint=j.string(a,"externalJoint",false);n.morphIds=j.strings(a,"morphs");}
        }
        if(model->metadata.kind==AssetKind::Model || model->metadata.kind==AssetKind::Item) {
            require(!n.id.empty(),"Component nodes require stable identifiers");
            require(n.morphIds.size()==n.weights.size(),"Morph identifiers do not match the mesh");
        }
    }
    std::vector<uint8_t> visited(raw->nodes_count);
    std::function<void(int,int)> visit=[&](int index,int depth) {
        require(depth<128,"Node hierarchy is too deep");
        require(visited[index]!=1,"Cycle in node hierarchy");if(visited[index]==2) return;
        visited[index]=1;if(model->rest[index].parent>=0) visit(model->rest[index].parent,depth+1);
        visited[index]=2;model->hierarchy.push_back(index);
    };
    for(size_t i=0;i<raw->nodes_count;i++) visit(int(i),0);
    std::vector<bool> active(raw->nodes_count,false);
    const cgltf_scene* scene=raw->scene?raw->scene:(raw->scenes_count?raw->scenes:nullptr);
    std::function<void(cgltf_node*)> mark=[&](cgltf_node* n) { if(active[nodeIndex(n)])return;active[nodeIndex(n)]=true;for(size_t i=0;i<n->children_count;i++)mark(n->children[i]); };
    if(scene) for(size_t i=0;i<scene->nodes_count;i++) mark(scene->nodes[i]);
    else std::fill(active.begin(),active.end(),true);
    for(size_t i=0;i<raw->nodes_count;i++)if(active[i] && raw->nodes[i].camera && raw->nodes[i].camera->type==cgltf_camera_type_orthographic) {
        auto& c=model->camera;auto& src=raw->nodes[i].camera->data.orthographic;c.orthographic=true;
        cgltf_node_transform_world(&raw->nodes[i],c.world.m);c.xmag=src.xmag;c.ymag=src.ymag;c.nearZ=src.znear;c.farZ=src.zfar;
        require(c.xmag>0 && c.ymag>0 && c.farZ>c.nearZ,"Invalid orthographic camera");break;
    }

    for(size_t i=0;i<raw->skins_count;i++) {
        const auto& src=raw->skins[i];Skin skin;
        require(src.joints_count<=256,"Skeleton exceeds 256 joints");
        auto binds=src.inverse_bind_matrices?floats(src.inverse_bind_matrices,16):std::vector<float>{};
        for(size_t j=0;j<src.joints_count;j++) {
            skin.joints.push_back(nodeIndex(src.joints[j]));Mat4 bind;
            if(!binds.empty()) std::copy_n(binds.data()+j*16,16,bind.m);
            skin.inverseBind.push_back(bind);
        }
        model->jointCount+=skin.joints.size();model->skins.push_back(std::move(skin));
    }
    size_t totalVertices=0;
    for(size_t i=0;i<raw->nodes_count;i++) {
        const auto& n=raw->nodes[i];if(!n.mesh || !active[i])continue;
        require(!n.has_mesh_gpu_instancing,"GPU instancing extension is not supported");
        for(size_t j=0;j<n.mesh->primitives_count;j++) {
            const auto& src=n.mesh->primitives[j];Primitive p;
            const char* subdivision=nullptr;
            for(size_t e=0;e<src.extensions_count;e++)if(std::strcmp(src.extensions[e].name,"GIFT_subdivision")==0)subdivision=src.extensions[e].data;
            require(src.type==cgltf_primitive_type_triangles && !src.has_draco_mesh_compression,"Only uncompressed triangle meshes are supported");
            p.name=n.name?n.name:"Mesh";p.node=int(i);p.skin=n.skin?int(n.skin-raw->skins):-1;
            if(src.extras.data){ProfileJSON j(src.extras.data);p.slot=j.string(0,"giftSlot",false);}
            if(model->metadata.kind==AssetKind::Model || model->metadata.kind==AssetKind::Item)require(!p.slot.empty(),"Mesh requires a material slot");
            p.material=src.material?int(src.material-raw->materials):int(model->materials.size()-1);
            auto* pos=attribute(src.attributes,src.attributes_count,cgltf_attribute_type_position);
            auto* norm=attribute(src.attributes,src.attributes_count,cgltf_attribute_type_normal);
            auto* uv=attribute(src.attributes,src.attributes_count,cgltf_attribute_type_texcoord);
            require(pos && norm,"Meshes must have positions and normals");
            require(!attribute(src.attributes,src.attributes_count,cgltf_attribute_type_color),"Vertex colors are not supported yet");
            auto positions=floats(pos,3),normals=floats(norm,3),uvs=uv?floats(uv,2):std::vector<float>(pos->count*2,0);
            require(normals.size()==positions.size() && uvs.size()==pos->count*2,"Mismatched vertex attribute counts");
            totalVertices+=pos->count;require(totalVertices<=200000,"Model exceeds prototype vertex limit");
            model->sourceVertexCount+=pos->count;
            p.base.resize(pos->count);
            for(size_t v=0;v<pos->count;v++)p.base[v]={vec3(positions,v),vec3(normals,v),{uvs[v*2],uvs[v*2+1]}};
            size_t indexCount=src.indices?src.indices->count:pos->count;
            require(indexCount<=1200000 && indexCount%3==0,"Invalid triangle index count");
            for(size_t v=0;v<indexCount;v++) {
                size_t ix=src.indices?cgltf_accessor_read_index(src.indices,v):v;
                require(ix<pos->count,"Triangle index out of range");p.indices.push_back(uint32_t(ix));
            }
            if(p.skin>=0) {
                std::vector<std::vector<float>> js,ws;
                for(int set=0;set<8;set++) {
                    auto* ja=attribute(src.attributes,src.attributes_count,cgltf_attribute_type_joints,set);
                    auto* wa=attribute(src.attributes,src.attributes_count,cgltf_attribute_type_weights,set);
                    if(!ja && !wa)break;
                    js.push_back(floats(ja,4));ws.push_back(floats(wa,4));
                    require(js.back().size()==pos->count*4 && ws.back().size()==js.back().size(),"Invalid skin attributes");
                }
                require(!js.empty() && !attribute(src.attributes,src.attributes_count,cgltf_attribute_type_joints,8),"Unsupported skin influence count");
                p.influences=int(js.size()*4);
                for(size_t v=0;v<pos->count;v++) {
                    std::array<uint16_t,32> joints{};std::array<float,32> weights{};float sum=0;
                    for(size_t set=0;set<js.size();set++)for(int k=0;k<4;k++) {
                        float j=js[set][v*4+k],w=ws[set][v*4+k];
                        require(j>=0 && j<n.skin->joints_count && j==std::floor(j) && w>=0,"Invalid skin joint or weight");
                        joints[set*4+k]=uint16_t(j);weights[set*4+k]=w;sum+=w;
                    }
                    require(sum>1e-8f,"Vertex has no skin weights");if(!subdivision)for(float& w:weights)w/=sum;
                    p.joints.push_back(joints);p.weights.push_back(weights);
                }
            }
            require(src.targets_count<=16,"Too many morph targets");
            for(size_t t=0;t<src.targets_count;t++) {
                const auto& target=src.targets[t];std::vector<Vec3> dp(pos->count),dn(pos->count);
                for(auto type:{cgltf_attribute_type_position,cgltf_attribute_type_normal}) {
                    if(auto* a=attribute(target.attributes,target.attributes_count,type)) {
                        auto values=floats(a,3);require(values.size()==positions.size(),"Invalid morph target size");
                        auto& dest=type==cgltf_attribute_type_position?dp:dn;for(size_t v=0;v<pos->count;v++)dest[v]=vec3(values,v);
                    }
                }
                p.morphPositions.push_back(std::move(dp));p.morphNormals.push_back(std::move(dn));
            }
            require(model->rest[i].weights.size()==src.targets_count,"Morph weights do not match targets");
            if(subdivision) {
                ProfileJSON j(subdivision);SubdivisionCage cage;
                require(j.number(j.field(0,"version"))==1,"Unsupported subdivision version");
                require(j.value(j.field(0,"scheme"))=="catmullClark" && j.value(j.field(0,"boundary"))=="edgeAndCorner" && j.value(j.field(0,"uvInterpolation"))=="boundaries" && j.value(j.field(0,"weights"))=="varying","Unsupported subdivision settings");
                float level=j.number(j.field(0,"level"));require(level==std::floor(level) && level>=1 && level<=4,"Invalid subdivision level");cage.level=int(level);
                auto read=[&](const char* name,int width) {
                    float a=j.number(j.field(0,name));require(a>=0 && a<raw->accessors_count && a==std::floor(a),"Invalid subdivision accessor");return floats(&raw->accessors[int(a)],width);
                };
                if(p.skin>=0) {
                    auto sums=read("weightSums",1);require(sums.size()==p.base.size(),"Invalid subdivision weight sums");
                    for(size_t v=0;v<sums.size();v++) {require(sums[v]>1e-8f && sums[v]<256,"Invalid subdivision weight sum");for(float& w:p.weights[v])w*=sums[v];}
                }
                auto integers=[&](const char* name,std::vector<int>& out) {
                    auto a=read(name,1);require(a.size()<=65536,"Subdivision topology too large");
                    for(float x:a){require(x>=0 && x<=65535 && x==std::floor(x),"Invalid subdivision topology index");out.push_back(int(x));}
                };
                integers("faceSizes",cage.faceSizes);integers("faceIndices",cage.faceIndices);integers("uvIndices",cage.uvIndices);
                auto uv=read("uvValues",2);require(uv.size()<=131072,"Subdivision UVs too large");
                for(size_t k=0;k<uv.size();k+=2)cage.uvValues.push_back({uv[k],uv[k+1]});
                model->hasSubdivision=true;model->controlCage=!applySubdivision;
                if(applySubdivision)gift::applySubdivision(p,cage);
                else useControlCage(p,cage);
                totalVertices+=p.base.size()-pos->count;require(totalVertices<=200000,"Subdivided model exceeds vertex limit");
            }
            model->triangleCount+=p.indices.size()/3;model->primitives.push_back(std::move(p));
        }
    }
    require((library || !model->primitives.empty()) && model->primitives.size()<=128,"No supported meshes, or too many mesh parts");
    if(model->metadata.kind==AssetKind::Animation)require(raw->animations_count==1 && model->primitives.empty(),"An animation component must contain exactly one clip and no meshes");
    const auto channelBindings=readChannelBindings(*raw);
    std::set<std::pair<std::string,int>> animatedProperties;
    for(size_t i=0;i<raw->animations_count;i++) {
        const auto& animation=raw->animations[i];
        for(size_t j=0;j<animation.channels_count;j++) {
            const auto& src=animation.channels[j];
            Channel c;c.node=nodeIndex(src.target_node);c.path=int(src.target_path);c.interpolation=int(src.sampler->interpolation);
            const char* binding=channelBindings[i][j].empty()?nullptr:channelBindings[i][j].c_str();
            for(size_t e=0;e<src.extensions_count;e++)if(std::strcmp(src.extensions[e].name,"GIFT_animation_binding")==0) {
                require(!binding,"Animation channel has duplicate bindings");binding=src.extensions[e].data;
            }
            if(binding) {
                require(!src.target_node,"External animation targets must omit node indices");ProfileJSON j(binding);
                require(j.number(j.field(0,"version"))==1,"Unsupported animation binding version");
                c.targetId=j.string(0,"node");c.morphIds=j.strings(0,"morphs");
                require(src.sampler->input->component_type==cgltf_component_type_r_32f && src.sampler->output->component_type==cgltf_component_type_r_32f,"Animation components require float32 samplers");
            }else {
                require(src.target_node,"Animation channel is missing a supported binding");
                c.targetId=model->rest[c.node].id;c.morphIds=model->rest[c.node].morphIds;
            }
            require(animatedProperties.emplace(binding?c.targetId:std::to_string(c.node),c.path).second,"Overlapping animation clips: export active actions as one clip");
            c.width=c.path==cgltf_animation_path_type_rotation?4:c.path==cgltf_animation_path_type_weights?(binding?int(c.morphIds.size()):int(model->rest[c.node].weights.size())):3;
            require(c.width>0 && c.width<=16 && c.path!=cgltf_animation_path_type_invalid,"Invalid animation target");
            require(c.interpolation==cgltf_interpolation_type_linear || c.interpolation==cgltf_interpolation_type_step || c.interpolation==cgltf_interpolation_type_cubic_spline,"Unsupported animation interpolation");
            c.times=floats(src.sampler->input,1);c.values=floats(src.sampler->output);
            require(!c.times.empty(),"Empty animation track");
            require(c.times.front()>=0,"Animation times cannot be negative");
            for(size_t k=1;k<c.times.size();k++)require(c.times[k]>c.times[k-1],"Animation times must increase");
            size_t multiplier=c.interpolation==cgltf_interpolation_type_cubic_spline?3:1;
            require(c.values.size()==c.times.size()*c.width*multiplier,"Animation output size mismatch");
            model->duration=std::max(model->duration,c.times.back());model->channels.push_back(std::move(c));
        }
    }
    model->animationCount=raw->animations_count;model->nodes=model->rest;
    auto& pose=model->currentPose;pose.world.resize(model->rest.size());pose.normal.resize(model->rest.size());pose.morphWeights.resize(model->rest.size());
    size_t offset=0;for(const auto& skin:model->skins){pose.skinOffsets.push_back(uint32_t(offset));offset+=skin.joints.size();}
    pose.joints.resize(std::max(size_t(1),offset)); // Valid identity palette for unskinned scenes.
    if(!model->primitives.empty() && std::none_of(model->channels.begin(),model->channels.end(),[](const Channel& c){return c.node<0;})) {
        model->calculateAnimationBounds();model->evaluatePose(0);
    }
    return model;
}

std::array<float,16> GiftModel::sampleChannel(const Channel& c,float seconds) {
        auto next=std::upper_bound(c.times.begin(),c.times.end(),seconds);
        size_t b=next==c.times.end()?c.times.size()-1:size_t(next-c.times.begin());
        size_t a=b?b-1:0;
        if(seconds>=c.times.back())a=b;
        float dt=c.times[b]-c.times[a];float t=dt>0?std::clamp((seconds-c.times[a])/dt,0.f,1.f):0;
        std::array<float,16> value{};
        bool cubic=c.interpolation==cgltf_interpolation_type_cubic_spline;
        for(int k=0;k<c.width;k++) {
            if(cubic) {
                float x=c.values[(a*3+1)*c.width+k],y=c.values[(b*3+1)*c.width+k];
                float out=c.values[(a*3+2)*c.width+k]*dt,in=c.values[(b*3)*c.width+k]*dt;
                value[k]=(2*t*t*t-3*t*t+1)*x+(t*t*t-2*t*t+t)*out+(-2*t*t*t+3*t*t)*y+(t*t*t-t*t)*in;
            } else {
                float x=c.values[a*c.width+k],y=c.values[b*c.width+k];
                value[k]=c.interpolation==cgltf_interpolation_type_step?x:x+(y-x)*t;
            }
        }
    if(c.path==cgltf_animation_path_type_rotation) {
        Vec4 q;
        if(c.interpolation==cgltf_interpolation_type_linear) {
            const float* x=c.values.data()+a*4;const float* y=c.values.data()+b*4;
            q=slerp({x[0],x[1],x[2],x[3]},{y[0],y[1],y[2],y[3]},t);
        }else q=normalize(Vec4{value[0],value[1],value[2],value[3]});
        value[0]=q.x;value[1]=q.y;value[2]=q.z;value[3]=q.w;
    }
    return value;
}

void GiftModel::evaluatePose(float seconds) {
    nodes=rest;
    for(const auto& c:channels) {
        auto value=sampleChannel(c,seconds);
        auto& n=nodes[c.node];
        if(c.path==cgltf_animation_path_type_translation)n.translation={value[0],value[1],value[2]};
        else if(c.path==cgltf_animation_path_type_scale)n.scale={value[0],value[1],value[2]};
        else if(c.path==cgltf_animation_path_type_weights)std::copy_n(value.data(),c.width,n.weights.data());
        else if(c.path==cgltf_animation_path_type_rotation)n.rotation={value[0],value[1],value[2],value[3]};
    }
    auto& pose=currentPose;
    for(int index:hierarchy) {
        const auto& n=nodes[index];Mat4 local=n.hasMatrix?n.matrix:trs(n.translation,n.rotation,n.scale);
        pose.world[index]=n.parent<0?local:pose.world[n.parent]*local;
        pose.normal[index]=normalMatrix(pose.world[index]);
        pose.morphWeights[index].fill(0);std::copy_n(n.weights.begin(),std::min(n.weights.size(),size_t(16)),pose.morphWeights[index].begin());
    }
    for(size_t i=0;i<skins.size();i++)for(size_t j=0;j<skins[i].joints.size();j++) {
        Mat4 m=pose.world[skins[i].joints[j]]*skins[i].inverseBind[j];pose.joints[pose.skinOffsets[i]+j]={m,normalMatrix(m)};
    }
}
void GiftModel::calculateAnimationBounds() {
    // Framing uses per-joint envelopes, not deformed vertices. A normalized
    // skin blend stays inside the AABB enclosing its transformed joint envelopes.
    // As before, sample the clip once on load; framing stays fixed in playback.
    struct Envelope { int node,joint;Bounds base;std::vector<Bounds> morphs; };
    std::vector<Envelope> envelopes;
    for(const auto& p:primitives) {
        size_t count=p.skin>=0?skins[p.skin].joints.size():1;
        size_t first=envelopes.size();
        for(size_t j=0;j<count;j++)envelopes.push_back({p.node,p.skin>=0?int(currentPose.skinOffsets[p.skin]+j):-1,{},std::vector<Bounds>(p.morphPositions.size())});
        for(size_t v=0;v<p.base.size();v++) {
            auto add=[&](size_t j) {
                auto& e=envelopes[first+j];e.base.add(p.base[v].position);
                for(size_t t=0;t<e.morphs.size();t++)e.morphs[t].add(p.morphPositions[t][v]);
            };
            if(p.skin>=0){for(int k=0;k<p.influences;k++)if(p.weights[v][k]>0)add(p.joints[v][k]);}
            else add(0);
        }
    }
    animationBounds={};
    for(int frame=0;frame<=30;frame++) {
        evaluatePose(duration*frame/30.f);
        for(const auto& e:envelopes) {
            if(e.base.min.x>e.base.max.x)continue;
            Bounds b=e.base;
            for(size_t t=0;t<e.morphs.size();t++) {
                float w=currentPose.morphWeights[e.node][t];const auto& delta=e.morphs[t];
                b.min=b.min+(w>=0?delta.min:delta.max)*w;
                b.max=b.max+(w>=0?delta.max:delta.min)*w;
            }
            const Mat4& matrix=e.joint>=0?currentPose.joints[e.joint].position:currentPose.world[e.node];
            for(int corner=0;corner<8;corner++)animationBounds.add(point(matrix,{
                corner&1?b.max.x:b.min.x,corner&2?b.max.y:b.min.y,corner&4?b.max.z:b.min.z}));
        }
    }
}
}
