#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface UIView (AnimationUtils)

+ (double)animationDurationFactor;

@end

CABasicAnimation * _Nonnull makeSpringAnimation(NSString * _Nonnull keyPath);
CABasicAnimation * _Nonnull makeSpringBounceAnimation(NSString * _Nonnull keyPath, CGFloat initialVelocity, CGFloat damping);
CGFloat springAnimationValueAt(CABasicAnimation * _Nonnull animation, CGFloat t);

void testZoomBlurEffect(UIVisualEffect *effect);
UIBlurEffect *makeCustomZoomBlurEffect();
void applySmoothRoundedCorners(CALayer * _Nonnull layer);
