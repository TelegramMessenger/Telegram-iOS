#import "UIControl+HitTestEdgeInsets.h"

#import <objc/runtime.h>

@implementation UIControl (HitTestEdgeInsets)

- (void)setHitTestEdgeInsets:(UIEdgeInsets)hitTestEdgeInsets
{
    NSValue *value = [NSValue value:&hitTestEdgeInsets withObjCType:@encode(UIEdgeInsets)];
    objc_setAssociatedObject(self, @selector(hitTestEdgeInsets), value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIEdgeInsets)hitTestEdgeInsets
{
    NSValue *value = objc_getAssociatedObject(self, @selector(hitTestEdgeInsets));
    if (value)
    {
        UIEdgeInsets edgeInsets;
        [value getValue:&edgeInsets];
        return edgeInsets;
    }
    return UIEdgeInsetsZero;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    if (UIEdgeInsetsEqualToEdgeInsets(self.hitTestEdgeInsets, UIEdgeInsetsZero) || !self.enabled || self.hidden)
        return [super pointInside:point withEvent:event];
    
    CGRect relativeFrame = self.bounds;
    CGRect hitFrame = UIEdgeInsetsInsetRect(relativeFrame, self.hitTestEdgeInsets);
    
    return CGRectContainsPoint(hitFrame, point);
}

@end
