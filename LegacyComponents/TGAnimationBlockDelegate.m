#import "TGAnimationBlockDelegate.h"

@implementation TGAnimationBlockDelegate

- (instancetype)initWithLayer:(CALayer *)layer
{
    self = [super init];
    if (self != nil)
    {
        _layer = layer;
    }
    return self;
}

- (void)animationDidStart:(CAAnimation *)__unused anim
{
}

- (void)animationDidStop:(CAAnimation *)__unused anim finished:(BOOL)flag
{
    CALayer *layer = _layer;
    
    if (flag)
    {
        if (_opacityOnCompletion != nil)
            layer.opacity = [_opacityOnCompletion floatValue];
    }
    if (_removeLayerOnCompletion)
        [layer removeFromSuperlayer];
    
    if (_completion)
        _completion(flag);
    
    _completion = nil;
}

@end
