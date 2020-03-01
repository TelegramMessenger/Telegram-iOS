#import "CATracingLayer.h"

#import "RuntimeUtils.h"

static void *CATracingLayerInvalidatedKey = &CATracingLayerInvalidatedKey;
static void *CATracingLayerIsInvalidatedBlock = &CATracingLayerIsInvalidatedBlock;
static void *CATracingLayerTraceableInfoKey = &CATracingLayerTraceableInfoKey;
static void *CATracingLayerPositionAnimationMirrorTarget = &CATracingLayerPositionAnimationMirrorTarget;

@implementation CALayer (Tracing)

- (void)setInvalidateTracingSublayers:(void (^_Nullable)())block {
    [self setAssociatedObject:[block copy] forKey:CATracingLayerIsInvalidatedBlock];
}

- (void (^_Nullable)())invalidateTracingSublayers {
    return [self associatedObjectForKey:CATracingLayerIsInvalidatedBlock];
}

- (bool)isTraceable {
    return [self associatedObjectForKey:CATracingLayerTraceableInfoKey] != nil || [self isKindOfClass:[CATracingLayer class]];
}

- (CATracingLayerInfo * _Nullable)traceableInfo {
    return [self associatedObjectForKey:CATracingLayerTraceableInfoKey];
}

- (void)setTraceableInfo:(CATracingLayerInfo * _Nullable)info {
    [self setAssociatedObject:info forKey:CATracingLayerTraceableInfoKey];
}

- (bool)hasPositionOrOpacityAnimations {
    return [self animationForKey:@"position"] != nil || [self animationForKey:@"bounds"] != nil || [self animationForKey:@"sublayerTransform"] != nil || [self animationForKey:@"opacity"] != nil;
}

- (bool)hasPositionAnimations {
    return [self animationForKey:@"position"] != nil || [self animationForKey:@"bounds"] != nil;
}

static void traceLayerSurfaces(int32_t tracingTag, int depth, CALayer * _Nonnull layer, NSMutableDictionary<NSNumber *, NSMutableArray<CALayer *> *> *layersByDepth, bool skipIfNoTraceableSublayers) {
    bool hadTraceableSublayers = false;
    for (CALayer *sublayer in layer.sublayers.reverseObjectEnumerator) {
        CATracingLayerInfo *sublayerTraceableInfo = [sublayer traceableInfo];
        if (sublayerTraceableInfo != nil && sublayerTraceableInfo.tracingTag == tracingTag) {
            NSMutableArray *array = layersByDepth[@(depth)];
            if (array == nil) {
                array = [[NSMutableArray alloc] init];
                layersByDepth[@(depth)] = array;
            }
            [array addObject:sublayer];
            hadTraceableSublayers = true;
        }
        if (sublayerTraceableInfo.disableChildrenTracingTags & tracingTag) {
            return;
        }
    }
    
    if (!skipIfNoTraceableSublayers || !hadTraceableSublayers) {
        for (CALayer *sublayer in layer.sublayers.reverseObjectEnumerator) {
            if ([sublayer isKindOfClass:[CATracingLayer class]]) {
                traceLayerSurfaces(tracingTag, depth + 1, sublayer, layersByDepth, hadTraceableSublayers);
            }
        }
    }
}

- (NSArray<NSArray<CALayer *> *> * _Nonnull)traceableLayerSurfacesWithTag:(int32_t)tracingTag {
    NSMutableDictionary<NSNumber *, NSMutableArray<CALayer *> *> *layersByDepth = [[NSMutableDictionary alloc] init];
    
    traceLayerSurfaces(tracingTag, 0, self, layersByDepth, false);
    
    NSMutableArray<NSMutableArray<CALayer *> *> *result = [[NSMutableArray alloc] init];
    
    for (id key in [[layersByDepth allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
        [result addObject:layersByDepth[key]];
    }
    
    return result;
}

- (void)adjustTraceableLayerTransforms:(CGSize)offset {
    CGRect frame = self.frame;
    CGSize sublayerOffset = CGSizeMake(frame.origin.x + offset.width, frame.origin.y + offset.height);
    for (CALayer *sublayer in self.sublayers) {
        CATracingLayerInfo *sublayerTraceableInfo = [sublayer traceableInfo];
        if (sublayerTraceableInfo != nil && sublayerTraceableInfo.shouldBeAdjustedToInverseTransform) {
            sublayer.sublayerTransform = CATransform3DMakeTranslation(-sublayerOffset.width, -sublayerOffset.height, 0.0f);
        } else if ([sublayer isKindOfClass:[CATracingLayer class]]) {
            [(CATracingLayer *)sublayer adjustTraceableLayerTransforms:sublayerOffset];
        }
    }
}

- (CALayer * _Nullable)animationMirrorTarget {
    return [self associatedObjectForKey:CATracingLayerPositionAnimationMirrorTarget];
}

- (void)setPositionAnimationMirrorTarget:(CALayer * _Nullable)animationMirrorTarget {
    [self setAssociatedObject:animationMirrorTarget forKey:CATracingLayerPositionAnimationMirrorTarget associationPolicy:NSObjectAssociationPolicyRetain];
}

- (void)invalidateUpTheTree {
    CALayer *superlayer = self;
    while (true) {
        if (superlayer == nil) {
            break;
        }
        
        void (^block)() = [superlayer invalidateTracingSublayers];
        if (block != nil) {
            block();
        }
        
        superlayer = superlayer.superlayer;
    }
}

@end

@interface CATracingLayerAnimationDelegate : NSObject <CAAnimationDelegate> {
    id<CAAnimationDelegate> _delegate;
    void (^_animationStopped)();
}

@end

@implementation CATracingLayerAnimationDelegate

- (instancetype)initWithDelegate:(id<CAAnimationDelegate>)delegate animationStopped:(void (^_Nonnull)())animationStopped {
    _delegate = delegate;
    _animationStopped = [animationStopped copy];
    return self;
}

- (void)animationDidStart:(CAAnimation *)anim {
    if ([_delegate respondsToSelector:@selector(animationDidStart:)]) {
        [(id)_delegate animationDidStart:anim];
    }
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    if ([_delegate respondsToSelector:@selector(animationDidStop:finished:)]) {
        [(id)_delegate animationDidStop:anim finished:flag];
    }
    
    if (_animationStopped) {
        _animationStopped();
    }
}

@end

@interface CATracingLayer ()

@property (nonatomic) bool isInvalidated;

@end

@implementation CATracingLayer

- (void)setNeedsDisplay {
}

- (void)displayIfNeeded {
}

- (bool)isInvalidated {
    return [[self associatedObjectForKey:CATracingLayerInvalidatedKey] intValue] != 0;
}

- (void)setIsInvalidated:(bool)isInvalidated {
    [self setAssociatedObject: isInvalidated ? @1 : @0 forKey:CATracingLayerInvalidatedKey];
}

- (void)setPosition:(CGPoint)position {
    [super setPosition:position];
    
    [self invalidateUpTheTree];
}

- (void)setOpacity:(float)opacity {
    [super setOpacity:opacity];
    
    [self invalidateUpTheTree];
}

- (void)addSublayer:(CALayer *)layer {
    [super addSublayer:layer];
    
    if ([layer isTraceable] || [layer isKindOfClass:[CATracingLayer class]]) {
        [self invalidateUpTheTree];
    }
}

- (void)insertSublayer:(CALayer *)layer atIndex:(unsigned)idx {
    [super insertSublayer:layer atIndex:idx];
    
    if ([layer isTraceable] || [layer isKindOfClass:[CATracingLayer class]]) {
        [self invalidateUpTheTree];
    }
}

- (void)insertSublayer:(CALayer *)layer below:(nullable CALayer *)sibling {
    [super insertSublayer:layer below:sibling];
    
    if ([layer isTraceable] || [layer isKindOfClass:[CATracingLayer class]]) {
        [self invalidateUpTheTree];
    }
}

- (void)insertSublayer:(CALayer *)layer above:(nullable CALayer *)sibling {
    [super insertSublayer:layer above:sibling];
    
    if ([layer isTraceable] || [layer isKindOfClass:[CATracingLayer class]]) {
        [self invalidateUpTheTree];
    }
}

- (void)replaceSublayer:(CALayer *)layer with:(CALayer *)layer2 {
    [super replaceSublayer:layer with:layer2];
    
    if ([layer isTraceable] || [layer2 isTraceable]) {
        [self invalidateUpTheTree];
    }
}

- (void)removeFromSuperlayer {
    if ([self isTraceable]) {
        [self invalidateUpTheTree];
    }
    
    [super removeFromSuperlayer];
}

- (void)addAnimation:(CAAnimation *)anim forKey:(NSString *)key {
    if ([anim isKindOfClass:[CABasicAnimation class]]) {
        if (false && [key isEqualToString:@"bounds.origin.y"]) {
            CABasicAnimation *animCopy = [anim copy];
            CGFloat from = [animCopy.fromValue floatValue];
            CGFloat to = [animCopy.toValue floatValue];
            
            animCopy.fromValue = [NSValue valueWithCATransform3D:CATransform3DMakeTranslation(0.0, to - from, 0.0f)];
            animCopy.toValue = [NSValue valueWithCATransform3D:CATransform3DIdentity];
            animCopy.keyPath = @"sublayerTransform";
            
            __weak CATracingLayer *weakSelf = self;
            anim.delegate = [[CATracingLayerAnimationDelegate alloc] initWithDelegate:anim.delegate animationStopped:^{
                __strong CATracingLayer *strongSelf = weakSelf;
                if (strongSelf != nil) {
                    [strongSelf invalidateUpTheTree];
                }
            }];
            
            [super addAnimation:anim forKey:key];
            
            CABasicAnimation *positionAnimCopy = [animCopy copy];
            positionAnimCopy.fromValue = [NSValue valueWithCATransform3D:CATransform3DMakeTranslation(0.0, 0.0, 0.0f)];
            positionAnimCopy.toValue = [NSValue valueWithCATransform3D:CATransform3DIdentity];
            positionAnimCopy.additive = true;
            positionAnimCopy.delegate = [[CATracingLayerAnimationDelegate alloc] initWithDelegate:anim.delegate animationStopped:^{
                __strong CATracingLayer *strongSelf = weakSelf;
                if (strongSelf != nil) {
                    [strongSelf invalidateUpTheTree];
                }
            }];
            
            [self invalidateUpTheTree];
            
            [self mirrorAnimationDownTheTree:animCopy key:@"sublayerTransform"];
            [self mirrorPositionAnimationDownTheTree:positionAnimCopy key:@"sublayerTransform"];
        } else if ([key isEqualToString:@"position"]) {
            CABasicAnimation *animCopy = [anim copy];
            CGPoint from = [animCopy.fromValue CGPointValue];
            CGPoint to = [animCopy.toValue CGPointValue];
            
            animCopy.fromValue = [NSValue valueWithCATransform3D:CATransform3DMakeTranslation(to.x - from.x, to.y - from.y, 0.0f)];
            animCopy.toValue = [NSValue valueWithCATransform3D:CATransform3DIdentity];
            animCopy.keyPath = @"sublayerTransform";
            
            __weak CATracingLayer *weakSelf = self;
            anim.delegate = [[CATracingLayerAnimationDelegate alloc] initWithDelegate:anim.delegate animationStopped:^{
                __strong CATracingLayer *strongSelf = weakSelf;
                if (strongSelf != nil) {
                    [strongSelf invalidateUpTheTree];
                }
            }];
            
            [super addAnimation:anim forKey:key];
            
            CABasicAnimation *positionAnimCopy = [animCopy copy];
            positionAnimCopy.fromValue = [NSValue valueWithCATransform3D:CATransform3DMakeTranslation(-to.x + from.x, 0.0, 0.0f)];
            positionAnimCopy.toValue = [NSValue valueWithCATransform3D:CATransform3DIdentity];
            positionAnimCopy.additive = true;
            positionAnimCopy.delegate = [[CATracingLayerAnimationDelegate alloc] initWithDelegate:anim.delegate animationStopped:^{
                __strong CATracingLayer *strongSelf = weakSelf;
                if (strongSelf != nil) {
                    [strongSelf invalidateUpTheTree];
                }
            }];
            
            [self invalidateUpTheTree];
            
            [self mirrorAnimationDownTheTree:animCopy key:@"sublayerTransform"];
            [self mirrorPositionAnimationDownTheTree:positionAnimCopy key:@"sublayerTransform"];
        } else if ([key isEqualToString:@"opacity"]) {
            __weak CATracingLayer *weakSelf = self;
            anim.delegate = [[CATracingLayerAnimationDelegate alloc] initWithDelegate:anim.delegate animationStopped:^{
                __strong CATracingLayer *strongSelf = weakSelf;
                if (strongSelf != nil) {
                    [strongSelf invalidateUpTheTree];
                }
            }];
            
            [super addAnimation:anim forKey:key];
            
            [self invalidateUpTheTree];
        } else {
            [super addAnimation:anim forKey:key];
        }
    } else {
        [super addAnimation:anim forKey:key];
    }
}

- (void)mirrorPositionAnimationDownTheTree:(CAAnimation *)animation key:(NSString *)key {
    if ([animation isKindOfClass:[CABasicAnimation class]]) {
        if ([((CABasicAnimation *)animation).keyPath isEqualToString:@"sublayerTransform"]) {
            CALayer *positionAnimationMirrorTarget = [self animationMirrorTarget];
            if (positionAnimationMirrorTarget != nil) {
                [positionAnimationMirrorTarget addAnimation:[animation copy] forKey:key];
            }
        }
    }
}

- (void)mirrorAnimationDownTheTree:(CAAnimation *)animation key:(NSString *)key {
    for (CALayer *sublayer in self.sublayers) {
        CATracingLayerInfo *traceableInfo = [sublayer traceableInfo];
        if (traceableInfo != nil && traceableInfo.shouldBeAdjustedToInverseTransform) {
            [sublayer addAnimation:[animation copy] forKey:key];
        }
        
        if ([sublayer isKindOfClass:[CATracingLayer class]]) {
            [(CATracingLayer *)sublayer mirrorAnimationDownTheTree:animation key:key];
        }
    }
}

@end

@implementation CATracingLayerInfo

- (instancetype _Nonnull)initWithShouldBeAdjustedToInverseTransform:(bool)shouldBeAdjustedToInverseTransform userData:(id _Nullable)userData tracingTag:(int32_t)tracingTag disableChildrenTracingTags:(int32_t)disableChildrenTracingTags {
    self = [super init];
    if (self != nil) {
        _shouldBeAdjustedToInverseTransform = shouldBeAdjustedToInverseTransform;
        _userData = userData;
        _tracingTag = tracingTag;
        _disableChildrenTracingTags = disableChildrenTracingTags;
    }
    return self;
}

@end
