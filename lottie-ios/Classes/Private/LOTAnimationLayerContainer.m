#import "LOTAnimationLayerContainer.h"
#import "LOTCompositionContainer.h"

@implementation LOTAnimationLayerContainer

- (instancetype)initWithModel:(LOTComposition *)model size:(CGSize)size {
    self = [super init];
    if (self != nil) {
        _layer = [[LOTCompositionContainer alloc] initWithModel:nil inLayerGroup:nil withLayerGroup:model.layerGroup withAssestGroup:model.assetGroup];
        _layer.bounds = model.compBounds;
        ((LOTCompositionContainer *)_layer).viewportBounds = model.compBounds;
        
        CGFloat compAspect = model.compBounds.size.width / model.compBounds.size.height;
        CGFloat viewAspect = size.width / size.height;
        BOOL scaleWidth = compAspect > viewAspect;
        CGFloat dominantDimension = scaleWidth ? size.width : size.height;
        CGFloat compDimension = scaleWidth ? model.compBounds.size.width : model.compBounds.size.height;
        CGFloat scale = dominantDimension / compDimension;
        CATransform3D xform = CATransform3DMakeScale(scale, scale, 1);
        
        _layer.transform = xform;
        _layer.position = CGPointMake(size.width / 2.0, size.height / 2.0);
        
    }
    return self;
}

- (void)renderFrame:(int32_t)frame inContext:(CGContextRef)context {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    ((LOTCompositionContainer *)_layer).currentFrame = @(frame);
    [_layer setNeedsDisplay];
    [CATransaction commit];
    
    [_layer renderInContext:context];
}

@end
