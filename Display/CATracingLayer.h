#import <UIKit/UIKit.h>

@interface CATracingLayer : CALayer

@end

@interface UITracingLayerView : UIView

- (void)scheduleWithLayout:(void (^_Nonnull)())block;

@end

@interface CALayer (Tracing)

- (id _Nullable)traceableInfo;
- (void)setTraceableInfo:(id _Nullable)info;

- (bool)hasPositionOrOpacityAnimations;

- (void)setInvalidateTracingSublayers:(void (^_Nullable)())block;
- (NSArray<NSArray<CALayer *> *> * _Nonnull)traceableLayerSurfaces;
- (void)adjustTraceableLayerTransforms:(CGSize)offset;

- (void)invalidateUpTheTree;

@end
