#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface UIView (AnimationUtils)

+ (double)animationDurationFactor;

@end

CABasicAnimation * _Nonnull makeSpringAnimation(NSString * _Nonnull keyPath);
CGFloat springAnimationValueAt(CABasicAnimation * _Nonnull animation, CGFloat t);

