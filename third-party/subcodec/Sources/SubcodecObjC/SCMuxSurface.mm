// Sources/SubcodecObjC/SCMuxSurface.mm
#import "SCMuxSurface.h"

#include "mux_surface.h"

#include <optional>

using namespace subcodec;

static NSError* makeError(NSString* msg) {
    return [NSError errorWithDomain:@"SCMuxSurface" code:-1
                           userInfo:@{NSLocalizedDescriptionKey: msg}];
}

@implementation SCCompactionInfo

- (instancetype)initWithActiveSprites:(int)active
                             maxSlots:(int)max
                       currentGridMbs:(int)current
                          minGridMbs:(int)min {
    self = [super init];
    if (self) {
        _activeSprites = active;
        _maxSlots = max;
        _currentGridMbs = current;
        _minGridMbs = min;
    }
    return self;
}

@end

@implementation SCResizeResult

- (instancetype)initWithRegions:(NSArray<SCSpriteRegion *> *)regions {
    self = [super init];
    if (self) {
        _regions = [regions copy];
    }
    return self;
}

@end

@implementation SCMuxSurface {
    std::optional<MuxSurface> _surface;
}

+ (nullable SCMuxSurface *)createWithSpriteWidth:(int)width
                                    spriteHeight:(int)height
                                        maxSlots:(int)slots
                                              qp:(int)qp
                                            sink:(void (^)(NSData *))sink
                                           error:(NSError **)error {
    MuxSurface::Params params;
    params.sprite_width = width;
    params.sprite_height = height;
    params.max_slots = slots;
    params.qp = qp;
    params.qp_delta_idr = 0;
    params.qp_delta_p = 0;

    auto result = MuxSurface::create(params, [sink](std::span<const uint8_t> data) {
        NSData* nsData = [NSData dataWithBytesNoCopy:(void*)data.data()
                                              length:data.size()
                                        freeWhenDone:NO];
        sink(nsData);
    });
    if (!result) {
        if (error) *error = makeError(@"MuxSurface::create failed");
        return nil;
    }

    SCMuxSurface* obj = [[SCMuxSurface alloc] init];
    obj->_surface.emplace(std::move(*result));
    return obj;
}

- (int)widthMbs {
    return _surface ? _surface->width_mbs() : 0;
}

- (int)heightMbs {
    return _surface ? _surface->height_mbs() : 0;
}

- (nullable SCSpriteRegion *)addSpriteAtPath:(NSString *)path
                                       error:(NSError **)error {
    if (!_surface) {
        if (error) *error = makeError(@"Surface not initialized");
        return nil;
    }

    auto result = _surface->add_sprite(path.UTF8String);
    if (!result) {
        if (error) *error = makeError(@"add_sprite failed");
        return nil;
    }

    auto& region = *result;
    CGRect colorRect = CGRectMake(region.color.x, region.color.y,
                                  region.color.width, region.color.height);
    CGRect alphaRect = CGRectMake(region.alpha.x, region.alpha.y,
                                  region.alpha.width, region.alpha.height);
    return [[SCSpriteRegion alloc] initWithSlot:region.slot
                                     colorRect:colorRect
                                     alphaRect:alphaRect];
}

- (void)removeSpriteAtSlot:(int)slot {
    if (_surface) {
        _surface->remove_sprite(slot);
    }
}

- (void)advanceSpriteAtSlot:(int)slot {
    if (_surface) {
        _surface->advance_sprite(slot);
    }
}

- (BOOL)emitFrameIfNeededWithSink:(void (^)(NSData *))sink
                            error:(NSError **)error {
    if (!_surface) {
        if (error) *error = makeError(@"Surface not initialized");
        return NO;
    }

    auto result = _surface->emit_frame_if_needed([sink](std::span<const uint8_t> data) {
        NSData* nsData = [NSData dataWithBytesNoCopy:(void*)data.data()
                                              length:data.size()
                                        freeWhenDone:NO];
        sink(nsData);
    });
    if (!result) {
        if (error) *error = makeError(@"emit_frame_if_needed failed");
        return NO;
    }
    return YES;
}

- (BOOL)advanceFrameWithSink:(void (^)(NSData *))sink
                       error:(NSError **)error {
    if (!_surface) {
        if (error) *error = makeError(@"Surface not initialized");
        return NO;
    }

    auto result = _surface->advance_frame([sink](std::span<const uint8_t> data) {
        NSData* nsData = [NSData dataWithBytesNoCopy:(void*)data.data()
                                              length:data.size()
                                        freeWhenDone:NO];
        sink(nsData);
    });
    if (!result) {
        if (error) *error = makeError(@"advance_frame failed");
        return NO;
    }
    return YES;
}

- (nullable SCResizeResult *)resizeToMaxSlots:(int)newMaxSlots
                                       yPlane:(NSData *)yPlane
                                      cbPlane:(NSData *)cbPlane
                                      crPlane:(NSData *)crPlane
                                 decodedWidth:(int)decodedWidth
                                decodedHeight:(int)decodedHeight
                                      strideY:(int)strideY
                                     strideCb:(int)strideCb
                                     strideCr:(int)strideCr
                                     withSink:(void (^)(NSData *))sink
                                        error:(NSError **)error {
    if (!_surface) {
        if (error) *error = makeError(@"Surface not initialized");
        return nil;
    }

    auto result = _surface->resize(
        newMaxSlots,
        {(const uint8_t*)yPlane.bytes, yPlane.length},
        {(const uint8_t*)cbPlane.bytes, cbPlane.length},
        {(const uint8_t*)crPlane.bytes, crPlane.length},
        decodedWidth, decodedHeight,
        strideY, strideCb, strideCr,
        [sink](std::span<const uint8_t> data) {
            NSData* nsData = [NSData dataWithBytesNoCopy:(void*)data.data()
                                                  length:data.size()
                                            freeWhenDone:NO];
            sink(nsData);
        });

    if (!result) {
        if (error) *error = makeError(@"resize failed");
        return nil;
    }

    NSMutableArray<SCSpriteRegion *> *regions = [NSMutableArray array];
    
    for (auto& region : result->regions) {
        CGRect colorRect = CGRectMake(region.color.x, region.color.y,
                                      region.color.width, region.color.height);
        CGRect alphaRect = CGRectMake(region.alpha.x, region.alpha.y,
                                      region.alpha.width, region.alpha.height);
        [regions addObject:[[SCSpriteRegion alloc] initWithSlot:region.slot
                                                     colorRect:colorRect
                                                     alphaRect:alphaRect]];
    }

    return [[SCResizeResult alloc] initWithRegions:regions];
}

- (SCCompactionInfo *)checkCompactionOpportunity {
    if (!_surface) {
        return [[SCCompactionInfo alloc] initWithActiveSprites:0
                                                     maxSlots:0
                                               currentGridMbs:0
                                                  minGridMbs:0];
    }

    auto info = _surface->check_compaction_opportunity();
    return [[SCCompactionInfo alloc] initWithActiveSprites:info.active_sprites
                                                 maxSlots:info.max_slots
                                           currentGridMbs:info.current_grid_mbs
                                              minGridMbs:info.min_grid_mbs];
}

@end
