#import "UIKitUtils.h"

#if TARGET_IPHONE_SIMULATOR
UIKIT_EXTERN float UIAnimationDragCoefficient(); // UIKit private drag coeffient, use judiciously
#endif

@implementation UIView (AnimationUtils)

+ (double)animationDurationFactor
{
#if TARGET_IPHONE_SIMULATOR
    return (double)UIAnimationDragCoefficient();
#endif
    
    return 1.0f;
}

@end

@interface CASpringAnimation ()

- (float)_solveForInput:(float)arg1;

@end

@implementation CASpringAnimation (AnimationUtils)

- (CGFloat)valueAt:(CGFloat)t {
    return [self _solveForInput:t];
}

@end

CABasicAnimation * _Nonnull makeSpringAnimation(NSString * _Nonnull keyPath) {
    CASpringAnimation *springAnimation = [CASpringAnimation animationWithKeyPath:keyPath];
    springAnimation.mass = 3.0f;
    springAnimation.stiffness = 1000.0f;
    springAnimation.damping = 500.0f;
    springAnimation.initialVelocity = 0.0f;
    springAnimation.duration = springAnimation.settlingDuration;
    return springAnimation;
}

CGFloat springAnimationValueAt(CABasicAnimation * _Nonnull animation, CGFloat t) {
    return [(CASpringAnimation *)animation _solveForInput:t];
}
