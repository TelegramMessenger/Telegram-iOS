#import "CATracingLayer.h"

#import "RuntimeUtils.h"

static void *CATracingLayerInvalidatedKey = &CATracingLayerInvalidatedKey;
static void *CATracingLayerIsInvalidatedBlock = &CATracingLayerIsInvalidatedBlock;
static void *CATracingLayerTraceablInfoKey = &CATracingLayerTraceablInfoKey;

@implementation CALayer (Tracing)

- (void)setInvalidateTracingSublayers:(void (^_Nullable)())block {
    [self setAssociatedObject:[block copy] forKey:CATracingLayerIsInvalidatedBlock];
}

- (void (^_Nullable)())invalidateTracingSublayers {
    return [self associatedObjectForKey:CATracingLayerIsInvalidatedBlock];
}

- (bool)isTraceable {
    return [self associatedObjectForKey:CATracingLayerTraceablInfoKey] != nil || [self isKindOfClass:[CATracingLayer class]];
}

- (id _Nullable)traceableInfo {
    return [self associatedObjectForKey:CATracingLayerTraceablInfoKey];
}

- (void)setTraceableInfo:(id _Nullable)info {
    [self setAssociatedObject:info forKey:CATracingLayerTraceablInfoKey];
}

- (bool)hasPositionOrOpacityAnimations {
    return [self animationForKey:@"position"] != nil || [self animationForKey:@"bounds"] != nil || [self animationForKey:@"sublayerTransform"] != nil || [self animationForKey:@"opacity"] != nil;
}

static void traceLayerSurfaces(int depth, CALayer * _Nonnull layer, NSMutableDictionary<NSNumber *, NSMutableArray<CALayer *> *> *layersByDepth) {
    NSMutableArray<CALayer *> *result = nil;
    
    bool hadTraceableSublayers = false;
    for (CALayer *sublayer in layer.sublayers.reverseObjectEnumerator) {
        if ([sublayer traceableInfo] != nil) {
            NSMutableArray *array = layersByDepth[@(depth)];
            if (array == nil) {
                array = [[NSMutableArray alloc] init];
                layersByDepth[@(depth)] = array;
            }
            [array addObject:sublayer];
            hadTraceableSublayers = true;
        }
    }
    
    if (!hadTraceableSublayers) {
        for (CALayer *sublayer in layer.sublayers.reverseObjectEnumerator) {
            if ([sublayer isKindOfClass:[CATracingLayer class]]) {
                traceLayerSurfaces(depth + 1, sublayer, layersByDepth);
            }
        }
    }
}

- (NSArray<NSArray<CALayer *> *> *)traceableLayerSurfaces {
    NSMutableDictionary<NSNumber *, NSMutableArray<CALayer *> *> *layersByDepth = [[NSMutableDictionary alloc] init];
    
    traceLayerSurfaces(0, self, layersByDepth);
    
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
        if ([sublayer traceableInfo] != nil) {
            sublayer.sublayerTransform = CATransform3DMakeTranslation(-sublayerOffset.width, -sublayerOffset.height, 0.0f);
        } else if ([sublayer isKindOfClass:[CATracingLayer class]]) {
            [(CATracingLayer *)sublayer adjustTraceableLayerTransforms:sublayerOffset];
        }
    }
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
        if ([key isEqualToString:@"position"]) {
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
            
            [self invalidateUpTheTree];
            
            [self mirrorAnimationDownTheTree:animCopy key:@"sublayerTransform"];
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

- (void)mirrorAnimationDownTheTree:(CAAnimation *)animation key:(NSString *)key {
    for (CALayer *sublayer in self.sublayers) {
        if ([sublayer traceableInfo] != nil) {
            [sublayer addAnimation:[animation copy] forKey:key];
        } else if ([sublayer isKindOfClass:[CATracingLayer class]]) {
            [(CATracingLayer *)sublayer mirrorAnimationDownTheTree:animation key:key];
        }
    }
}

@end

@interface UITracingLayerView () {
    void (^_scheduledWithLayout)();
}

@end

@implementation UITracingLayerView

+ (Class)layerClass {
    return [CATracingLayer class];
}

- (void)scheduleWithLayout:(void (^_Nonnull)())block {
    _scheduledWithLayout = [block copy];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (_scheduledWithLayout) {
        void (^block)() = [_scheduledWithLayout copy];
        _scheduledWithLayout = nil;
        block();
    }
}

@end
