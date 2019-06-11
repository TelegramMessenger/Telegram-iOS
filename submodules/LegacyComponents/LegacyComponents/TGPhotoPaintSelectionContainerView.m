#import "TGPhotoPaintSelectionContainerView.h"

@implementation TGPhotoPaintSelectionContainerView

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    bool pointInside = [super pointInside:point withEvent:event];
    if (!pointInside)
    {
        for (UIView *subview in self.subviews)
        {
            CGPoint convertedPoint = [self convertPoint:point toView:subview];
            if ([subview pointInside:convertedPoint withEvent:event])
                pointInside = true;
        }
    }
    return pointInside;
}

@end
