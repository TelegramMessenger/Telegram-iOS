#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

double animationDurationFactorImpl();

CABasicAnimation * _Nonnull makeSpringAnimationImpl(NSString * _Nonnull keyPath);
CABasicAnimation * _Nonnull makeSpringBounceAnimationImpl(NSString * _Nonnull keyPath, CGFloat initialVelocity, CGFloat damping);
CGFloat springAnimationValueAtImpl(CABasicAnimation * _Nonnull animation, CGFloat t);

UIBlurEffect * _Nonnull makeCustomZoomBlurEffectImpl(bool isLight);
void applySmoothRoundedCornersImpl(CALayer * _Nonnull layer);
