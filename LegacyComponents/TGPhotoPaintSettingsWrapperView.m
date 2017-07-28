#import "TGPhotoPaintSettingsWrapperView.h"

@implementation TGPhotoPaintSettingsWrapperView

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *view = [super hitTest:point withEvent:event];
    if (view == self)
    {
        CGPoint location = [self convertPoint:point toView:nil];
        
        if (self.pressed != nil)
            self.pressed(location);
        
        if (self.suppressTouchAtPoint != nil && self.suppressTouchAtPoint(location))
            return view;
        
        return nil;
    }

    return view;
}

@end
