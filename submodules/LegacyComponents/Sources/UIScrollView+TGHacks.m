#import "UIScrollView+TGHacks.h"

#import <objc/message.h>

@implementation UIScrollView (TGHacks)

- (void)stopScrollingAnimation
{
    CGPoint offset = self.contentOffset;
    [self setContentOffset:offset animated:false];
    self.scrollEnabled = false;
    self.scrollEnabled = true;
    
//    UIView *superview = self.superview;
//    NSUInteger index = [self.superview.subviews indexOfObject:self];
//    [self removeFromSuperview];
//    [superview insertSubview:self atIndex:index];
}

@end
