#import "TGLocationPulseView.h"

#import "LegacyComponentsInternal.h"

@interface TGLocationPulseView ()
{
    CAShapeLayer *_circleLayer;
}
@end

@implementation TGLocationPulseView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.userInteractionEnabled = false;
        
        _circleLayer = [CAShapeLayer layer];
        _circleLayer.hidden = true;
        _circleLayer.opacity = 0.0f;
        _circleLayer.path = CGPathCreateWithEllipseInRect(CGRectMake(-60.0f, -60.0f, 120.0f, 120.0f), NULL);
        _circleLayer.fillColor = UIColorRGBA(0x007aff, 0.27f).CGColor;
        [self.layer addSublayer:_circleLayer];
    }
    return self;
}

- (void)start
{
    _circleLayer.hidden = false;
    
    if (_circleLayer.animationKeys.count > 0)
        return;
    
    CAKeyframeAnimation *scaleAnimation = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
    scaleAnimation.values = @[@0.0f, @0.72f, @1.0f, @1.0f];
    scaleAnimation.keyTimes = @[@0.0, @0.49f, @0.88f, @1.0f];
    scaleAnimation.duration = 3.0;
    scaleAnimation.repeatCount = INFINITY;
    scaleAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    [_circleLayer addAnimation:scaleAnimation forKey:@"circle-scale"];
    
    CAKeyframeAnimation *opacityAnimation = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    opacityAnimation.values = @[@1.0f, @0.2f, @0.0, @0.0f];
    opacityAnimation.keyTimes = @[@0.0, @0.4f, @0.62f, @1.0f];
    opacityAnimation.duration = 3.0;
    opacityAnimation.repeatCount = INFINITY;
    [_circleLayer addAnimation:opacityAnimation forKey:@"circle-opacity"];
}

- (void)stop
{
    _circleLayer.hidden = true;
    [_circleLayer removeAllAnimations];
}

@end
