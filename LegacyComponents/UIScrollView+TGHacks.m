#import "UIScrollView+TGHacks.h"

#import <objc/message.h>

@implementation UIScrollView (TGHacks)

- (void)stopScrollingAnimation
{
    UIView *superview = self.superview;
    NSUInteger index = [self.superview.subviews indexOfObject:self];
    [self removeFromSuperview];
    [superview insertSubview:self atIndex:index];
}

@end
