#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

double animationDurationFactorImpl();

CABasicAnimation * _Nonnull makeSpringAnimationImpl(NSString * _Nonnull keyPath);
CABasicAnimation * _Nonnull makeSpringBounceAnimationImpl(NSString * _Nonnull keyPath, CGFloat initialVelocity, CGFloat damping);
CGFloat springAnimationValueAtImpl(CABasicAnimation * _Nonnull animation, CGFloat t);

UIBlurEffect * _Nonnull makeCustomZoomBlurEffectImpl(bool isLight);
void applySmoothRoundedCornersImpl(CALayer * _Nonnull layer);

@protocol UIKitPortalViewProtocol <NSObject>

@property(nonatomic) __weak UIView * _Nullable sourceView;
@property(nonatomic) _Bool forwardsClientHitTestingToSourceView;
@property(nonatomic) _Bool allowsHitTesting; // @dynamic allowsHitTesting;
@property(nonatomic) _Bool allowsBackdropGroups; // @dynamic allowsBackdropGroups;
@property(nonatomic) _Bool matchesPosition; // @dynamic matchesPosition;
@property(nonatomic) _Bool matchesTransform; // @dynamic matchesTransform;
@property(nonatomic) _Bool matchesAlpha; // @dynamic matchesAlpha;
@property(nonatomic) _Bool hidesSourceView; // @dynamic hidesSourceView;

@end

UIView<UIKitPortalViewProtocol> * _Nullable makePortalView(bool matchPosition);
