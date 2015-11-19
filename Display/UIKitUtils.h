#import <UIKit/UIKit.h>

@interface UIView (AnimationUtils)

+ (double)animationDurationFactor;

@end

@interface CASpringAnimation (AnimationUtils)

- (CGFloat)valueAt:(CGFloat)t;

@end