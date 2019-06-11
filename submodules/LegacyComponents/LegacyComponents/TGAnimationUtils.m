#import "TGAnimationUtils.h"

#import <LegacyComponents/LegacyComponents.h>

NSString *kCAMediaTimingFunctionSpring = @"kCAMediaTimingFunctionSpring";

@interface TGLayerAnimationDelegate : NSObject <CAAnimationDelegate> {
    void (^_completion)(bool);
}

@end

@implementation TGLayerAnimationDelegate

- (instancetype)initWithCompletion:(void (^)(bool))completion {
    self = [super init];
    if (self != nil) {
        _completion = [completion copy];
    }
    return self;
}

- (void)animationDidStop:(__unused CAAnimation *)anim finished:(BOOL)flag {
    if (_completion) {
        _completion(flag);
    }
}

@end

@interface CAAnimation (AnimationUtils)

@end

@implementation CAAnimation (AnimationUtils)

- (void)setCompletionBlock:(void (^)(bool))block {
    self.delegate = [[TGLayerAnimationDelegate alloc] initWithCompletion:block];
}

@end


static CABasicAnimation * _Nonnull makeSpringAnimation(NSString * _Nonnull keyPath) {
    CASpringAnimation *springAnimation = [CASpringAnimation animationWithKeyPath:keyPath];
    springAnimation.mass = 3.0f;
    springAnimation.stiffness = 1000.0f;
    springAnimation.damping = 500.0f;
    springAnimation.duration = 0.5;//springAnimation.settlingDuration;
    springAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    return springAnimation;
}

static CABasicAnimation * _Nonnull makeExtendedSpringAnimation(NSString * _Nonnull keyPath, CGFloat damping) {
    CASpringAnimation *springAnimation = [CASpringAnimation animationWithKeyPath:keyPath];
    springAnimation.mass = 3.0f;
    springAnimation.stiffness = 1000.0f;
    springAnimation.damping = damping;
    springAnimation.duration = 0.5;//springAnimation.settlingDuration;
    springAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    return springAnimation;
}

@implementation CALayer (AnimationUtils)

- (void)animateFrom:(id)from to:(id)to keyPath:(NSString *)keyPath timingFunction:(NSString *)timingFunction duration:(NSTimeInterval)duration removeOnCompletion:(bool)removeOnCompletion completion:(void (^)(bool))completion {
    if ([timingFunction isEqualToString:kCAMediaTimingFunctionSpring]) {
        CABasicAnimation *animation = makeSpringAnimation(keyPath);
        animation.fromValue = from;
        animation.toValue = to;
        animation.removedOnCompletion = removeOnCompletion;
        animation.fillMode = kCAFillModeForwards;
        if (completion != nil) {
            [animation setCompletionBlock:completion];
        }
        
        float k = (float)TGAnimationSpeedFactor();
        float speed = 1.0f;
        if (k != 0 && k != 1) {
            speed = 1.0f / k;
        }
        
        animation.speed = speed * (float)(animation.duration / duration);
        
        [self addAnimation:animation forKey:keyPath];
    } else {
        float k = (float)TGAnimationSpeedFactor();
        float speed = 1.0f;
        if (k != 0 && k != 1) {
            speed = 1.0f / k;
        }
        
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:keyPath];
        animation.fromValue = from;
        animation.toValue = to;
        animation.duration = duration;
        animation.timingFunction = [CAMediaTimingFunction functionWithName: timingFunction];
        animation.removedOnCompletion = removeOnCompletion;
        animation.fillMode = kCAFillModeForwards;
        animation.speed = speed;
        if (completion != nil) {
            [animation setCompletionBlock:completion];
        }
        
        [self addAnimation:animation forKey:keyPath];
    }
}

- (void)animateSpringFrom:(id)from to:(id)to keyPath:(NSString *)keyPath duration:(NSTimeInterval)duration removeOnCompletion:(bool)removeOnCompletion completion:(void (^)(bool))completion {
    CABasicAnimation *animation = makeExtendedSpringAnimation(keyPath, 75.0f);
    animation.fromValue = from;
    animation.toValue = to;
    animation.removedOnCompletion = removeOnCompletion;
    animation.fillMode = kCAFillModeForwards;
    if (completion != nil) {
        [animation setCompletionBlock:completion];
    }
    
    float k = (float)TGAnimationSpeedFactor();
    float speed = 1.0f;
    if (k != 0 && k != 1) {
        speed = 1.0f / k;
    }
    
    animation.speed = speed * (float)(animation.duration / duration);
    
    [self addAnimation:animation forKey:keyPath];
}

- (void)animateAlphaFrom:(CGFloat)from to:(CGFloat)to duration:(NSTimeInterval)duration timingFunction:(NSString *)timingFunction removeOnCompletion:(bool)removeOnCompletion completion:(void (^)(bool))completion {
    [self animateFrom:@(from) to:@(to) keyPath:@"opacity" timingFunction:timingFunction duration:duration removeOnCompletion:removeOnCompletion completion:completion];
}

- (void)animateScaleFrom:(CGFloat)from to:(CGFloat)to duration:(NSTimeInterval)duration timingFunction:(NSString *)timingFunction removeOnCompletion:(bool)removeOnCompletion completion:(void (^)(bool))completion {
    [self animateFrom:@(from) to:@(to) keyPath:@"transform.scale" timingFunction:timingFunction duration:duration removeOnCompletion:removeOnCompletion completion:completion];
}

- (void)animateSpringScaleFrom:(CGFloat)from to:(CGFloat)to duration:(NSTimeInterval)duration removeOnCompletion:(bool)removeOnCompletion completion:(void (^)(bool))completion {
    [self animateSpringFrom:@(from) to:@(to) keyPath:@"transform.scale" duration:duration removeOnCompletion:removeOnCompletion completion:completion];
}

- (void)animatePositionFrom:(CGPoint)from to:(CGPoint)to duration:(NSTimeInterval)duration timingFunction:(NSString *)timingFunction removeOnCompletion:(bool)removeOnCompletion completion:(void (^)(bool))completion {
    [self animateFrom:[NSValue valueWithCGPoint:from] to:[NSValue valueWithCGPoint:to] keyPath:@"position" timingFunction:timingFunction duration:duration removeOnCompletion:removeOnCompletion completion:completion];
}

@end
