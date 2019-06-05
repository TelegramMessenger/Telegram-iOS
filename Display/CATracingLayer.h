#import <UIKit/UIKit.h>

@interface CATracingLayer : CALayer

@end

@interface CATracingLayerInfo : NSObject

@property (nonatomic, readonly) bool shouldBeAdjustedToInverseTransform;
@property (nonatomic, weak, readonly) id _Nullable userData;
@property (nonatomic, readonly) int32_t tracingTag;
@property (nonatomic, readonly) int32_t disableChildrenTracingTags;

- (instancetype _Nonnull)initWithShouldBeAdjustedToInverseTransform:(bool)shouldBeAdjustedToInverseTransform userData:(id _Nullable)userData tracingTag:(int32_t)tracingTag disableChildrenTracingTags:(int32_t)disableChildrenTracingTags;

@end

@interface CALayer (Tracing)

- (CATracingLayerInfo * _Nullable)traceableInfo;
- (void)setTraceableInfo:(CATracingLayerInfo * _Nullable)info;

- (bool)hasPositionOrOpacityAnimations;
- (bool)hasPositionAnimations;

- (void)setInvalidateTracingSublayers:(void (^_Nullable)())block;
- (NSArray<NSArray<CALayer *> *> * _Nonnull)traceableLayerSurfacesWithTag:(int32_t)tracingTag;
- (void)adjustTraceableLayerTransforms:(CGSize)offset;

- (void)setPositionAnimationMirrorTarget:(CALayer * _Nullable)animationMirrorTarget;

- (void)invalidateUpTheTree;

@end
