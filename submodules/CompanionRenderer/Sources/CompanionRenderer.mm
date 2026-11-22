#import "CompanionRenderer.h"
#import <ImageIO/ImageIO.h>
#import <QuartzCore/QuartzCore.h>
#include "GPUDeformation.hpp"
#include "CharacterInstance.hpp"
#include "ComponentCatalog.hpp"
#include <stdexcept>
#include <tuple>
#include <cmath>
using namespace gift;
namespace {
void check(bool ok,const char *message) { if(!ok) throw std::runtime_error(message); }
NSError *errorFor(const std::string &message) { return [NSError errorWithDomain:@"Companion" code:1 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithUTF8String:message.c_str()]}]; }
struct GPUPrimitive { id<MTLBuffer> vertex,index,influences,morphs; };
struct GPUGeometry { AssetResource resource; std::vector<GPUPrimitive> primitives; };
struct SharedTexture { id<MTLTexture> image; };
struct GPUDraw {
    std::shared_ptr<GPUGeometry> geometry; size_t primitive=0,instance=0;
    std::shared_ptr<SharedTexture> base,emission;
    id<MTLSamplerState> baseSampler,emissionSampler;
    Material material;
};
struct GPUScene { std::vector<GPUDraw> draws; };
struct LightUniform {Vec4 position,axisU,axisV,radiance;};
struct FragmentUniforms {Vec4 base,emissiveMetallic,eyeRoughness,flags,settings,worldDiffuse,worldSpecular,viewDirection;LightUniform lights[8];Vec4 toonSettings,toonRamp[8],viewRight,viewUp;};
static_assert(sizeof(FragmentUniforms)==816);
struct PostUniforms {Vec4 display,ramp,mask,tint;};
Vec4 v4(Vec3 v,float w=0){return {v.x,v.y,v.z,w};}
MTLSamplerAddressMode wrap(int value) {return value==33071?MTLSamplerAddressModeClampToEdge:value==33648?MTLSamplerAddressModeMirrorRepeat:MTLSamplerAddressModeRepeat;}
}
@implementation CompanionRenderer {
    id<MTLDevice> _device;
    id<MTLLibrary> _shaders;
    id<MTLRenderPipelineState> _pipeline,_outlinePipeline,_postPipeline;
    id<MTLDepthStencilState> _depthState,_outlineDepthState;
    id<MTLSamplerState> _linearSampler;
    id<MTLTexture> _ltc[2],_color,_resolve,_depth,_output;
    AssetLibrary _library; CharacterInstance _character; const GiftModel *_model;
    GPUScene _gpu;
    std::map<std::string,std::weak_ptr<GPUGeometry>> _geometryCache;
    std::deque<std::shared_ptr<GPUGeometry>> _recentGeometry;
    std::map<std::vector<uint8_t>,std::weak_ptr<SharedTexture>> _textureCache;
    std::deque<std::shared_ptr<SharedTexture>> _recentTextures;
    std::shared_ptr<SharedTexture> _white;
    std::map<std::tuple<int,int,bool>,id<MTLSamplerState>> _samplerCache;
    NSString *_resources,*_customizationNotice;
    float _yaw,_pitch,_zoom;
    bool _returningOrbit;
    float _returnYaw,_returnPitch,_returnElapsed;
}
- (instancetype)initWithDevice:(id<MTLDevice>)device resourceDirectory:(NSString *)directory error:(NSError **)error {
    self=[super init];if(!self)return nil; _device=device;_resources=directory;
    try {
        NSError *shaderError=nil;
        NSString *source=[NSString stringWithContentsOfFile:[directory stringByAppendingPathComponent:@"GiftShaders.metal.txt"] encoding:NSUTF8StringEncoding error:&shaderError];
        NSString *ltc=[NSString stringWithContentsOfFile:[directory stringByAppendingPathComponent:@"LTC.metal.txt"] encoding:NSUTF8StringEncoding error:&shaderError];
        NSString *deform=[NSString stringWithContentsOfFile:[directory stringByAppendingPathComponent:@"GiftDeform.metal.txt"] encoding:NSUTF8StringEncoding error:&shaderError];
        check(source && ltc && deform,"Companion shaders are missing");
        source=[[source stringByReplacingOccurrencesOfString:@"// LTC_IMPLEMENTATION" withString:ltc] stringByReplacingOccurrencesOfString:@"// GPU_DEFORMATION" withString:deform];
        _shaders=[device newLibraryWithSource:source options:nil error:&shaderError];
        if(!_shaders){if(error)*error=shaderError;return nil;}
        MTLVertexDescriptor *vertices=[MTLVertexDescriptor vertexDescriptor];
        for(int i=0;i<3;i++) { vertices.attributes[i].bufferIndex=2; vertices.attributes[i].format=i==2?MTLVertexFormatFloat2:MTLVertexFormatFloat3; }
        vertices.attributes[0].offset=offsetof(Vertex,position);vertices.attributes[1].offset=offsetof(Vertex,normal);vertices.attributes[2].offset=offsetof(Vertex,uv);vertices.layouts[2].stride=sizeof(Vertex);
        for(int outline=0;outline<2;outline++) {
            MTLRenderPipelineDescriptor *p=[MTLRenderPipelineDescriptor new];p.vertexDescriptor=vertices;p.rasterSampleCount=4;
            p.colorAttachments[0].pixelFormat=MTLPixelFormatRGBA16Float;p.depthAttachmentPixelFormat=p.stencilAttachmentPixelFormat=MTLPixelFormatDepth32Float_Stencil8;
            p.vertexFunction=[_shaders newFunctionWithName:outline?@"gift_outline_gpu_vertex":@"gift_gpu_vertex"];
            p.fragmentFunction=[_shaders newFunctionWithName:outline?@"gift_outline_fragment":@"gift_fragment"];
            id<MTLRenderPipelineState> state=[device newRenderPipelineStateWithDescriptor:p error:&shaderError];
            if(!state){if(error)*error=shaderError;return nil;} if(outline)_outlinePipeline=state;else _pipeline=state;
            MTLDepthStencilDescriptor *ds=[MTLDepthStencilDescriptor new];ds.depthCompareFunction=MTLCompareFunctionLessEqual;ds.depthWriteEnabled=!outline;
            MTLStencilDescriptor *st=[MTLStencilDescriptor new];st.stencilCompareFunction=outline?MTLCompareFunctionNotEqual:MTLCompareFunctionAlways;
            st.depthStencilPassOperation=outline?MTLStencilOperationKeep:MTLStencilOperationReplace;st.readMask=255;st.writeMask=outline?0:255;ds.frontFaceStencil=ds.backFaceStencil=st;
            if(outline)_outlineDepthState=[device newDepthStencilStateWithDescriptor:ds];else _depthState=[device newDepthStencilStateWithDescriptor:ds];
        }
        MTLRenderPipelineDescriptor *post=[MTLRenderPipelineDescriptor new];post.colorAttachments[0].pixelFormat=MTLPixelFormatBGRA8Unorm;
        post.vertexFunction=[_shaders newFunctionWithName:@"post_vertex"];post.fragmentFunction=[_shaders newFunctionWithName:@"post_fragment"];
        _postPipeline=[device newRenderPipelineStateWithDescriptor:post error:&shaderError];if(!_postPipeline){if(error)*error=shaderError;return nil;}
        _linearSampler=[self samplerU:33071 v:33071 nearest:false];
        for(int i=0;i<2;i++) {
            NSData *data=[NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:[NSString stringWithFormat:@"ltc_%d.rgba16f",i+1]]];
            check(data.length==64*64*8,"Invalid LTC table");
            MTLTextureDescriptor *t=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float width:64 height:64 mipmapped:NO];
            _ltc[i]=[device newTextureWithDescriptor:t];check(_ltc[i]!=nil,"Cannot allocate LTC texture");
            [_ltc[i] replaceRegion:MTLRegionMake2D(0,0,64,64) mipmapLevel:0 withBytes:data.bytes bytesPerRow:64*8];
        }
        [self resetCamera];return self;
    } catch(const std::exception &e) {if(error)*error=errorFor(e.what());return nil;}
}
- (std::shared_ptr<SharedTexture>)textureFor:(const Image*)image {
    if(image) { auto it=_textureCache.find(image->encoded);if(it!=_textureCache.end())if(auto cached=it->second.lock())return cached; }
    else if(_white)return _white;
    std::vector<uint8_t> pixels;size_t width=1,height=1;
    if(image) {
        NSData *data=[NSData dataWithBytes:image->encoded.data() length:image->encoded.size()];
        CGImageSourceRef source=CGImageSourceCreateWithData((__bridge CFDataRef)data,nullptr);check(source,"Invalid image");
        NSDictionary *props=CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source,0,nullptr));
        width=[props[(id)kCGImagePropertyPixelWidth] unsignedIntegerValue];height=[props[(id)kCGImagePropertyPixelHeight] unsignedIntegerValue];
        if(!width || !height || width>4096 || height>4096){CFRelease(source);throw std::runtime_error("Image exceeds 4096 pixels");}
        CGImageRef cg=CGImageSourceCreateImageAtIndex(source,0,nullptr);CFRelease(source);check(cg,"Cannot decode image");pixels.resize(width*height*4);
        CGColorSpaceRef space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        CGContextRef context=CGBitmapContextCreate(pixels.data(),width,height,8,width*4,space,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);CGColorSpaceRelease(space);
        if(!context){CGImageRelease(cg);throw std::runtime_error("Cannot allocate image");}
        CGContextSetBlendMode(context,kCGBlendModeCopy);CGContextDrawImage(context,CGRectMake(0,0,width,height),cg);CGContextRelease(context);CGImageRelease(cg);
        for(size_t i=0;i<pixels.size();i+=4)if(pixels[i+3]>0 && pixels[i+3]<255)for(int k=0;k<3;k++)pixels[i+k]=uint8_t(std::min(255,(int(pixels[i+k])*255+pixels[i+3]/2)/pixels[i+3]));
    }else pixels={255,255,255,255};
    auto result=std::make_shared<SharedTexture>();
    MTLTextureDescriptor *t=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm_sRGB width:width height:height mipmapped:NO];
    result->image=[_device newTextureWithDescriptor:t];check(result->image!=nil,"Cannot allocate texture");
    [result->image replaceRegion:MTLRegionMake2D(0,0,width,height) mipmapLevel:0 withBytes:pixels.data() bytesPerRow:width*4];
    if(image) {
        for(auto i=_textureCache.begin();i!=_textureCache.end();)if(i->second.expired())i=_textureCache.erase(i);else ++i;
        _textureCache[image->encoded]=result;_recentTextures.push_back(result);
        size_t bytes=0;for(const auto &t:_recentTextures)bytes+=t->image.width*t->image.height*4;
        while(_recentTextures.size()>16 || (bytes>16*1024*1024 && _recentTextures.size()>1)){auto t=_recentTextures.front();bytes-=t->image.width*t->image.height*4;_recentTextures.pop_front();}
    }else _white=result;
    return result;
}
- (id<MTLSamplerState>)samplerU:(int)u v:(int)v nearest:(bool)nearest {
    auto key=std::make_tuple(u,v,nearest);auto found=_samplerCache.find(key);if(found!=_samplerCache.end())return found->second;
    MTLSamplerDescriptor *d=[MTLSamplerDescriptor new];d.minFilter=d.magFilter=nearest?MTLSamplerMinMagFilterNearest:MTLSamplerMinMagFilterLinear;d.sAddressMode=wrap(u);d.tAddressMode=wrap(v);
    auto result=[_device newSamplerStateWithDescriptor:d];check(result!=nil,"Cannot allocate sampler");_samplerCache[key]=result;return result;
}
- (std::shared_ptr<GPUGeometry>)geometryFor:(const AssetResource&)asset {
    if(auto cached=_geometryCache[asset.key].lock())return cached;
    for(auto i=_geometryCache.begin();i!=_geometryCache.end();)if(i->second.expired())i=_geometryCache.erase(i);else ++i;
    auto result=std::make_shared<GPUGeometry>();result->resource=asset;
    auto buffer=[&](const void *bytes,size_t size){auto b=[_device newBufferWithBytes:bytes length:size options:MTLResourceStorageModeShared];check(b!=nil,"Cannot allocate mesh buffer");return b;};
    for(const auto &mesh:asset.data->primitives) {
        GPUPrimitive p;p.vertex=buffer(mesh.base.data(),mesh.base.size()*sizeof(Vertex));p.index=buffer(mesh.indices.data(),mesh.indices.size()*sizeof(uint32_t));
        auto influences=gpuInfluences(mesh);auto morphs=gpuMorphs(mesh);p.influences=buffer(influences.data(),influences.size()*sizeof(GPUInfluence));p.morphs=buffer(morphs.data(),morphs.size()*sizeof(GPUMorphDelta));result->primitives.push_back(p);
    }
    _geometryCache[asset.key]=result;_recentGeometry.push_back(result);while(_recentGeometry.size()>4)_recentGeometry.pop_front();return result;
}
- (void)prepareScene:(GPUScene&)next character:(const CharacterInstance&)character {
    auto add=[&](const RigInstance &rig,const MaterialSet *materials,size_t instance) {
        auto geometry=[self geometryFor:rig.resource];
        for(size_t i=0;i<rig.resource.data->primitives.size();i++) {
            check(next.draws.size()<128,"Composition exceeds 128 mesh parts");auto binding=character.binding(rig,rig.resource.data->primitives[i],materials);const auto &data=*binding.resource->data;const auto &m=data.materials[binding.index];
            GPUDraw d;d.geometry=geometry;d.primitive=i;d.instance=instance;d.material=m;
            d.base=[self textureFor:m.image>=0?&data.images[m.image]:nullptr];d.emission=[self textureFor:m.emissiveImage>=0?&data.images[m.emissiveImage]:nullptr];
            d.baseSampler=[self samplerU:m.wrapS v:m.wrapT nearest:m.nearest];d.emissionSampler=[self samplerU:m.emissiveWrapS v:m.emissiveWrapT nearest:m.emissiveNearest];next.draws.push_back(d);
        }
    };
    add(character.body,character.materials.get(),0);size_t index=1;for(const auto &item:character.items)add(item.rig,item.materials.get(),index++);
}
- (void)commitCharacter:(CharacterInstance&)character scene:(GPUScene&)scene {
    _character=std::move(character);_gpu=std::move(scene);_model=_character.model->data.get();
}
- (BOOL)loadDefault:(NSError **)error {
    try {
        auto path=[&](const char *name){return std::string([_resources stringByAppendingPathComponent:[NSString stringWithUTF8String:name]].UTF8String);};
        CharacterInstance next;next.setModel(_library.model(path("catalog_classic.model.glb"),true));
        next.applyMaterials(_library.materials(path("catalog_classic.materials.glb")));next.play(_library.animation(path("catalog_classic_wave.animation.glb")),false);next.setEnvironment(_library.scene(path("catalog_classic.scene.glb")));
        GPUScene gpu;[self prepareScene:gpu character:next];[self commitCharacter:next scene:gpu];[self resetCamera];return YES;
    }catch(const std::exception &e){if(error)*error=errorFor(e.what());return NO;}
}
- (BOOL)setComponentAtURL:(NSURL *)url kind:(CompanionComponentKind)kind socket:(NSString *)socket error:(NSError **)error {
    try {
        CharacterInstance next=_character;std::vector<std::string> notices;std::string slot=socket?socket.UTF8String:"";
        switch(kind) {
            case CompanionComponentModel:check(url!=nil,"Select a model");notices=next.setModel(_library.model(url.path.UTF8String,true));break;
            case CompanionComponentAnimation:next.play(url?_library.animation(url.path.UTF8String):nullptr,true);break;
            case CompanionComponentMaterials:next.applyMaterials(url?_library.materials(url.path.UTF8String):nullptr);break;
            case CompanionComponentItem:if(url)next.attach(slot,_library.item(url.path.UTF8String,true));else next.detach(slot);break;
            case CompanionComponentItemMaterials:next.applyItemMaterials(slot,url?_library.materials(url.path.UTF8String):nullptr);break;
            case CompanionComponentScene:next.setEnvironment(url?_library.scene(url.path.UTF8String):nullptr);break;
            case CompanionComponentItemAnimation:next.playItem(slot,url?_library.animation(url.path.UTF8String):nullptr,true);break;
            default:throw std::runtime_error("Unknown component type");
        }
        GPUScene gpu;[self prepareScene:gpu character:next];[self commitCharacter:next scene:gpu];
        NSMutableArray* messages=[NSMutableArray new];for(const auto& message:notices)[messages addObject:[NSString stringWithUTF8String:message.c_str()]];
        _customizationNotice=[messages componentsJoinedByString:@"\n"];return YES;
    }catch(const std::exception& ex){if(error)*error=errorFor(ex.what());return NO;}
}
+ (NSArray<NSDictionary *> *)presets {
    NSMutableArray *result=[NSMutableArray new];
    for(const auto &preset:componentExamples()) {
        NSMutableOrderedSet *files=[NSMutableOrderedSet new];
        for(const char *file:{preset.model,preset.animation,preset.materials,preset.scene})
            if(file && *file)[files addObject:[NSString stringWithUTF8String:file]];
        for(const auto &item:preset.items) {
            [files addObject:[NSString stringWithUTF8String:item.file]];
            if(item.materials && *item.materials)[files addObject:[NSString stringWithUTF8String:item.materials]];
        }
        [result addObject:@{@"id":[NSString stringWithUTF8String:preset.id],@"title":[NSString stringWithUTF8String:preset.title],@"files":files.array}];
    }
    return result;
}
- (BOOL)applyPreset:(NSString *)identifier files:(NSDictionary<NSString *,NSURL *> *)files error:(NSError **)error {
    try {
        const auto &presets=componentExamples();
        auto it=std::find_if(presets.begin(),presets.end(),[&](const CatalogExample &p){return identifier.UTF8String==std::string(p.id);});
        check(it!=presets.end(),"Unknown Companion preset");
        auto path=[&](const char *name) {
            NSURL *url=files[[NSString stringWithUTF8String:name]];
            check(url!=nil && url.isFileURL,"Missing preset component");
            return std::string(url.path.UTF8String);
        };
        CharacterInstance next;
        next.setModel(_library.model(path(it->model),true));
        next.applyMaterials(_library.materials(path(it->materials)));
        next.play(_library.animation(path(it->animation)),false);
        next.setEnvironment(_library.scene(path(it->scene)));
        for(const auto &item:it->items) {
            next.attach(item.socket,_library.item(path(item.file),true));
            if(item.materials && *item.materials)next.applyItemMaterials(item.socket,_library.materials(path(item.materials)));
        }
        // A preset replaces the whole character only after every component is ready.
        GPUScene gpu;[self prepareScene:gpu character:next];[self commitCharacter:next scene:gpu];
        _customizationNotice=@"";[self resetCamera];return YES;
    }catch(const std::exception &ex){if(error)*error=errorFor(ex.what());return NO;}
}
- (NSArray<NSDictionary *> *)componentRows {
    NSMutableArray* rows=[NSMutableArray new];
    auto title=[](const AssetResource* r,NSString* fallback)->NSString* {return r?[NSString stringWithUTF8String:r->path.c_str()].lastPathComponent:fallback;};
    auto add=[&](CompanionComponentKind kind,NSString* name,const AssetResource* r,NSString* fallback,NSString* socket) {
        [rows addObject:@{@"kind":@(kind),@"title":name,@"value":title(r,fallback),@"socket":socket?:@""}];
    };
    add(CompanionComponentModel,@"Model",_character.model.get(),@"None",nil);
    add(CompanionComponentAnimation,@"Animation",_character.body.clip.get(),@"Embedded / Rest pose",nil);
    add(CompanionComponentMaterials,@"Materials",_character.materials.get(),@"Embedded / Default",nil);
    if(_model)for(const auto& socket:_model->metadata.sockets) {
        NSString* name=[NSString stringWithUTF8String:socket.id.c_str()];
        auto it=std::find_if(_character.items.begin(),_character.items.end(),[&](const ItemInstance& i){return i.socket==socket.id;});
        const ItemInstance* item=it==_character.items.end()?nullptr:&*it;
        add(CompanionComponentItem,[NSString stringWithFormat:@"Items · %@",name],item?item->asset.get():nullptr,@"None",name);
        if(item) {
            add(CompanionComponentItemMaterials,[NSString stringWithFormat:@"Item Materials · %@",name],item->materials.get(),@"Embedded / Default",name);
            add(CompanionComponentItemAnimation,[NSString stringWithFormat:@"Item Animation · %@",name],item->rig.clip.get(),@"Embedded / Rest pose",name);
        }
    }
    add(CompanionComponentScene,@"Scene",_character.environment.get(),@"Embedded / Default",nil);return rows;
}
- (NSString *)customizationNotice {return _customizationNotice?:@"";}
- (void)orbitX:(float)x y:(float)y {_returningOrbit=false;_yaw-=x*.009f;_pitch=std::clamp(_pitch+y*.009f,-1.3f,1.3f);}
- (void)returnToInitialOrbit {
    _yaw=std::remainder(_yaw,6.28318530718f);
    _returnYaw=_yaw;_returnPitch=_pitch;_returnElapsed=0;_returningOrbit=true;
}
- (void)zoomBy:(float)factor {_zoom=std::clamp(_zoom/factor,.6f,3.f);}
- (void)resetCamera {_returningOrbit=false;_yaw=0;_pitch=_model && _character.camera.orthographic?0:.12f;_zoom=1;}
- (id<MTLTexture>)encodeFrame:(id<MTLCommandBuffer>)commandBuffer width:(NSUInteger)width height:(NSUInteger)height deltaTime:(float)deltaTime {
    if(!_model || width<1 || height<1 || width>2048 || height>2048)return nil;
    const float dt=std::clamp(deltaTime,0.f,.1f);
    if(_returningOrbit) {
        _returnElapsed+=dt;
        const float t=std::min(_returnElapsed/.35f,1.f);
        const float remaining=(1.f-t)*(1.f-t)*(1.f-t);
        const float initialPitch=_character.camera.orthographic?0.f:.12f;
        _yaw=_returnYaw*remaining;
        _pitch=initialPitch+(_returnPitch-initialPitch)*remaining;
        if(t>=1.f)_returningOrbit=false;
    }
    _character.advance(dt);_character.evaluate();
    if(_output.width!=width || _output.height!=height) {
        auto target=[&](MTLPixelFormat format,NSUInteger samples){
            MTLTextureDescriptor *d=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:format width:width height:height mipmapped:NO];
            d.storageMode=MTLStorageModePrivate;d.usage=MTLTextureUsageRenderTarget|MTLTextureUsageShaderRead;
            if(samples>1){d.textureType=MTLTextureType2DMultisample;d.sampleCount=samples;}
            return [_device newTextureWithDescriptor:d];
        };
        _color=target(MTLPixelFormatRGBA16Float,4);_resolve=target(MTLPixelFormatRGBA16Float,1);_depth=target(MTLPixelFormatDepth32Float_Stencil8,4);_output=target(MTLPixelFormatBGRA8Unorm,1);
    }
    if(!_color || !_resolve || !_depth || !_output)return nil;
    auto rigAt=[&](size_t i)->const RigInstance& {return i==0?_character.body:_character.items[i-1].rig;};
    // Fresh immutable palettes are retained by the command buffer, so frames in flight never race.
    NSMutableArray<id<MTLBuffer>> *palettes=[NSMutableArray new];
    for(size_t i=0;i<=_character.items.size();i++) {
        const auto &joints=rigAt(i).pose.joints;
        id<MTLBuffer> buffer=[_device newBufferWithBytes:joints.data() length:joints.size()*sizeof(JointTransform) options:MTLResourceStorageModeShared];
        if(!buffer)return nil;[palettes addObject:buffer];
    }
    float aspect=float(width)/height,radius=_character.bounds.radius();Vec3 center=_character.bounds.center(),eye,viewDirection;Mat4 vp;
    const auto& camera=_character.camera;
    if(camera.orthographic) {
        Vec3 originalEye=point(camera.world,{}),back=normalize(direction(camera.world,{0,0,1}));
        // Keep the authored viewing direction and scale, but center the character
        // in its viewport instead of retaining the scene camera's framing offset.
        float distance=std::max(length(originalEye-center),radius*2);Vec3 pivot=center;
        Mat4 rotation=trs({}, {0,std::sin(_yaw*.5f),0,std::cos(_yaw*.5f)}, {1,1,1})*trs({}, {std::sin(-_pitch*.5f),0,0,std::cos(_pitch*.5f)}, {1,1,1});
        viewDirection=normalize(direction(rotation,back));eye=pivot+viewDirection*distance;
        float halfY=camera.ymag*_zoom*std::max(1.f,(camera.xmag/camera.ymag)/aspect);
        vp=orthographic(halfY*aspect,halfY,camera.nearZ,camera.farZ)*lookAt(eye,pivot);
    }else {
        float distance=radius/std::sin(.65f*.5f)*1.12f*_zoom/std::min(aspect,1.f);
        eye=center+Vec3{std::sin(_yaw)*std::cos(_pitch),std::sin(_pitch),std::cos(_yaw)*std::cos(_pitch)}*distance;
        viewDirection=normalize(eye-center);vp=perspective(.65f,aspect,std::max(radius*.01f,.0001f),radius*100)*lookAt(eye,center);
    }

    const auto &profile=_character.profile;
    MTLRenderPassDescriptor *pass=[MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture=_color;pass.colorAttachments[0].resolveTexture=_resolve;pass.colorAttachments[0].loadAction=MTLLoadActionClear;pass.colorAttachments[0].storeAction=MTLStoreActionMultisampleResolve;pass.colorAttachments[0].clearColor=MTLClearColorMake(0,0,0,0);
    pass.depthAttachment.texture=_depth;pass.depthAttachment.loadAction=MTLLoadActionClear;pass.depthAttachment.clearDepth=1;pass.depthAttachment.storeAction=MTLStoreActionDontCare;
    pass.stencilAttachment.texture=_depth;pass.stencilAttachment.loadAction=MTLLoadActionClear;pass.stencilAttachment.clearStencil=0;pass.stencilAttachment.storeAction=MTLStoreActionDontCare;
    id<MTLRenderCommandEncoder> encoder=[commandBuffer renderCommandEncoderWithDescriptor:pass];if(!encoder)return nil;
    [encoder setFrontFacingWinding:MTLWindingCounterClockwise];
    for(int outline=0;outline<2;outline++) {
        [encoder setRenderPipelineState:outline?_outlinePipeline:_pipeline];[encoder setDepthStencilState:outline?_outlineDepthState:_depthState];
        unsigned reference=0;
        for(const auto &draw:_gpu.draws) {
            ++reference;const auto &m=draw.material;if(outline && m.outlineWidth<=0)continue;
            const auto &rig=rigAt(draw.instance);const auto &mesh=rig.resource.data->primitives[draw.primitive];const auto &gpu=draw.geometry->primitives[draw.primitive];
            [encoder setCullMode:outline?MTLCullModeFront:m.doubleSided?MTLCullModeNone:MTLCullModeBack];[encoder setStencilReferenceValue:reference];
            [encoder setVertexBuffer:gpu.vertex offset:0 atIndex:2];[encoder setVertexBuffer:gpu.influences offset:0 atIndex:8];[encoder setVertexBuffer:gpu.morphs offset:0 atIndex:9];[encoder setVertexBuffer:palettes[draw.instance] offset:0 atIndex:10];
            GPUVertexUniforms u{vp,deformationParams(mesh,rig.pose)};[encoder setVertexBytes:&u length:sizeof(u) atIndex:0];
            [encoder setFragmentTexture:draw.base->image atIndex:0];[encoder setFragmentTexture:draw.emission->image atIndex:1];[encoder setFragmentTexture:_ltc[0] atIndex:2];[encoder setFragmentTexture:_ltc[1] atIndex:3];
            [encoder setFragmentSamplerState:draw.baseSampler atIndex:0];[encoder setFragmentSamplerState:draw.emissionSampler atIndex:1];[encoder setFragmentSamplerState:_linearSampler atIndex:2];
        FragmentUniforms fs{};fs.base=m.baseColor;fs.emissiveMetallic=v4(m.emissive,m.metallic);fs.eyeRoughness=v4(eye,m.roughness);
        fs.flags={float(m.unlit),float(m.doubleSided),float(m.alphaMask),m.alphaCutoff};fs.settings={m.ior,float(profile.enabled),float(profile.lights.size()),float(camera.orthographic)};
        fs.worldDiffuse=v4(profile.worldDiffuse);fs.worldSpecular=v4(profile.worldSpecular);fs.viewDirection=v4(viewDirection);
        fs.toonSettings={float(m.toonRamp.size()),float(m.toonInterpolation),float(m.lightMask),float(m.matcap)};
        Vec3 right=normalize(cross({0,1,0},viewDirection));fs.viewRight=v4(right,m.matcapScale);fs.viewUp=v4(cross(viewDirection,right));
        std::copy(m.toonRamp.begin(),m.toonRamp.end(),fs.toonRamp);
        for(size_t j=0;j<profile.lights.size();j++) {
            const auto& l=profile.lights[j];float area=float(M_PI)*length(cross(l.axisU,l.axisV));
            fs.lights[j]={v4(l.position),v4(l.axisU),v4(l.axisV),v4(l.color*(l.power/(float(M_PI)*area)))};
        }

            if(outline){Vec4 o=v4(m.outlineColor,m.outlineWidth);[encoder setVertexBytes:&o length:sizeof(o) atIndex:1];fs.base=o;}
            [encoder setFragmentBytes:&fs length:sizeof(fs) atIndex:0];[encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:mesh.indices.size() indexType:MTLIndexTypeUInt32 indexBuffer:gpu.index indexBufferOffset:0];
        }
    }
    [encoder endEncoding];
    MTLRenderPassDescriptor *post=[MTLRenderPassDescriptor renderPassDescriptor];post.colorAttachments[0].texture=_output;post.colorAttachments[0].loadAction=MTLLoadActionDontCare;post.colorAttachments[0].storeAction=MTLStoreActionStore;
    encoder=[commandBuffer renderCommandEncoderWithDescriptor:post];if(!encoder)return nil;
    [encoder setRenderPipelineState:_postPipeline];[encoder setFragmentTexture:_resolve atIndex:0];[encoder setFragmentSamplerState:_linearSampler atIndex:0];
    const auto &p=_character.profile;PostUniforms u{{p.exposure,p.gamma,float(p.enabled && p.composite),float(width)/height},{p.ramp.x,p.ramp.y,p.maskRotation,0},{p.maskPosition.x,p.maskPosition.y,p.maskSize.x,p.maskSize.y},v4(p.tint)};
    [encoder setFragmentBytes:&u length:sizeof(u) atIndex:0];[encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];[encoder endEncoding];return _output;
}
@end
