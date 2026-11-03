#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif
    
extern NSString *kCAMediaTimingFunctionSpring;

#ifdef __cplusplus
}
#endif

@interface CALayer (AnimationUtils)

- (void)animateAlphaFrom:(CGFloat)from to:(CGFloat)to duration:(NSTimeInterval)duration timingFunction:(NSString *)timingFunction removeOnCompletion:(bool)removeOnCompletion completion:(void (^)(bool))completion;

- (void)animateScaleFrom:(CGFloat)from to:(CGFloat)to duration:(NSTimeInterval)duration timingFunction:(NSString *)timingFunction removeOnCompletion:(bool)removeOnCompletion completion:(void (^)(bool))completion;
- (void)animateSpringScaleFrom:(CGFloat)from to:(CGFloat)to duration:(NSTimeInterval)duration removeOnCompletion:(bool)removeOnCompletion completion:(void (^)(bool))completion;

- (void)animatePositionFrom:(CGPoint)from to:(CGPoint)to duration:(NSTimeInterval)duration timingFunction:(NSString *)timingFunction removeOnCompletion:(bool)removeOnCompletion completion:(void (^)(bool))completion;

@end
