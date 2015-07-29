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
