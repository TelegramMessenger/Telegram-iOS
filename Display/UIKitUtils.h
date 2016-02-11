#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface UIView (AnimationUtils)

+ (double)animationDurationFactor;

@end

@interface CASpringAnimation (AnimationUtils)

- (CGFloat)valueAt:(CGFloat)t;

@end

