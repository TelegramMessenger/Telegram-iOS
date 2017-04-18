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
    springAnimation.duration = 0.5;
    springAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    return springAnimation;
}

CABasicAnimation * _Nonnull makeSpringBounceAnimation(NSString * _Nonnull keyPath, CGFloat initialVelocity, CGFloat damping) {
    CASpringAnimation *springAnimation = [CASpringAnimation animationWithKeyPath:keyPath];
    springAnimation.mass = 5.0f;
    springAnimation.stiffness = 900.0f;
    springAnimation.damping = damping;
    static bool canSetInitialVelocity = true;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        canSetInitialVelocity = [springAnimation respondsToSelector:@selector(setInitialVelocity:)];
    });
    if (canSetInitialVelocity) {
        springAnimation.initialVelocity = initialVelocity;
        springAnimation.duration = springAnimation.settlingDuration;
    }
    springAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    return springAnimation;
}

CGFloat springAnimationValueAt(CABasicAnimation * _Nonnull animation, CGFloat t) {
    return [(CASpringAnimation *)animation _solveForInput:t];
}
