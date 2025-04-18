#import "TGPaintingWrapperView.h"

@implementation TGPaintingWrapperView

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    bool receiveTouch = true;
    if (self.shouldReceiveTouch != nil)
        receiveTouch = self.shouldReceiveTouch();
    
    if (receiveTouch)
        return [self.superview pointInside:[self convertPoint:point toView:self.superview] withEvent:event];
    
    return false;
}

@end
