#import "UIKitUtils.h"

#import <objc/runtime.h>

#if TARGET_IPHONE_SIMULATOR
UIKIT_EXTERN float UIAnimationDragCoefficient();
#endif

double animationDurationFactorImpl() {
#if TARGET_IPHONE_SIMULATOR
    return (double)UIAnimationDragCoefficient();
#endif   
    return 1.0f;
}

@interface CASpringAnimation ()

@end

@implementation CASpringAnimation (AnimationUtils)

- (CGFloat)valueAt:(CGFloat)t {
    static dispatch_once_t onceToken;
    static float (*impl)(id, float) = NULL;
    static double (*dimpl)(id, double) = NULL;
    dispatch_once(&onceToken, ^{
        Method method = class_getInstanceMethod([CASpringAnimation class], NSSelectorFromString([@"_" stringByAppendingString:@"solveForInput:"]));
        if (method) {
            const char *encoding = method_getTypeEncoding(method);
            NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:encoding];
            const char *argType = [signature getArgumentTypeAtIndex:2];
            if (strncmp(argType, "f", 1) == 0) {
                impl = (float (*)(id, float))method_getImplementation(method);
            } else if (strncmp(argType, "d", 1) == 0) {
                dimpl = (double (*)(id, double))method_getImplementation(method);
            }
        }
    });
    if (impl) {
        float result = impl(self, (float)t);
        return (CGFloat)result;
    } else if (dimpl) {
        double result = dimpl(self, (double)t);
        return (CGFloat)result;
    }
    return t;
}

@end

CABasicAnimation * _Nonnull makeSpringAnimationImpl(NSString * _Nonnull keyPath) {
    CASpringAnimation *springAnimation = [CASpringAnimation animationWithKeyPath:keyPath];
    springAnimation.mass = 3.0f;
    springAnimation.stiffness = 1000.0f;
    springAnimation.damping = 500.0f;
    springAnimation.duration = 0.5;
    springAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    return springAnimation;
}

CABasicAnimation * _Nonnull makeSpringBounceAnimationImpl(NSString * _Nonnull keyPath, CGFloat initialVelocity, CGFloat damping) {
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
    } else {
        springAnimation.duration = 0.1;
    }
    springAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    return springAnimation;
}

CGFloat springAnimationValueAtImpl(CABasicAnimation * _Nonnull animation, CGFloat t) {
    return [(CASpringAnimation *)animation valueAt:t];
}

@interface CustomBlurEffect : UIBlurEffect

/*@property (nonatomic) double blurRadius;
@property (nonatomic) double colorBurnTintAlpha;
@property (nonatomic) double colorBurnTintLevel;
@property (nonatomic, retain) UIColor *colorTint;
@property (nonatomic) double colorTintAlpha;
@property (nonatomic) bool darkenWithSourceOver;
@property (nonatomic) double darkeningTintAlpha;
@property (nonatomic) double darkeningTintHue;
@property (nonatomic) double darkeningTintSaturation;
@property (nonatomic) double grayscaleTintAlpha;
@property (nonatomic) double grayscaleTintLevel;
@property (nonatomic) bool lightenGrayscaleWithSourceOver;
@property (nonatomic) double saturationDeltaFactor;
@property (nonatomic) double scale;
@property (nonatomic) double zoom;*/

+ (id)effectWithStyle:(long long)arg1;

@end

static NSString *encodeText(NSString *string, int key) {
    NSMutableString *result = [[NSMutableString alloc] init];
    
    for (int i = 0; i < (int)[string length]; i++) {
        unichar c = [string characterAtIndex:i];
        c += key;
        [result appendString:[NSString stringWithCharacters:&c length:1]];
    }
    
    return result;
}

static void setField(CustomBlurEffect *object, NSString *name, double value) {
    SEL selector = NSSelectorFromString(name);
    NSMethodSignature *signature = [[object class] instanceMethodSignatureForSelector:selector];
    if (signature == nil) {
        return;
    }
    
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:signature];
    [inv setSelector:selector];
    [inv setArgument:&value atIndex:2];
    [inv setTarget:object];
    [inv invoke];
}

static void setNilField(CustomBlurEffect *object, NSString *name) {
    SEL selector = NSSelectorFromString(name);
    NSMethodSignature *signature = [[object class] instanceMethodSignatureForSelector:selector];
    if (signature == nil) {
        return;
    }
    
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:signature];
    [inv setSelector:selector];
    id value = nil;
    [inv setArgument:&value atIndex:2];
    [inv setTarget:object];
    [inv invoke];
}

static void setBoolField(CustomBlurEffect *object, NSString *name, BOOL value) {
    SEL selector = NSSelectorFromString(name);
    NSMethodSignature *signature = [[object class] instanceMethodSignatureForSelector:selector];
    if (signature == nil) {
        return;
    }
    
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:signature];
    [inv setSelector:selector];
    [inv setArgument:&value atIndex:2];
    [inv setTarget:object];
    [inv invoke];
}

UIBlurEffect *makeCustomZoomBlurEffectImpl() {
    if (@available(iOS 11.0, *)) {
        NSString *string = [@[@"_", @"UI", @"Custom", @"BlurEffect"] componentsJoinedByString:@""];
        CustomBlurEffect *result = (CustomBlurEffect *)[NSClassFromString(string) effectWithStyle:0];
        
        setField(result, encodeText(@"tfuCmvsSbejvt;", -1), 10.0);
        //setField(result, encodeText(@"tfu[ppn;", -1), 0.015);
        setNilField(result, encodeText(@"tfuDpmpsUjou;", -1));
        setField(result, encodeText(@"tfuDpmpsUjouBmqib;", -1), 0.0);
        setField(result, encodeText(@"tfuEbslfojohUjouBmqib;", -1), 0.0);
        setField(result, encodeText(@"tfuHsbztdbmfUjouBmqib;", -1), 0.0);
        setField(result, encodeText(@"tfuTbuvsbujpoEfmubGbdups;", -1), 1.0);
        
        if ([UIScreen mainScreen].scale > 2.5f) {
            setField(result, encodeText(@"setScale:", 0), 0.3);
        } else {
            setField(result, encodeText(@"setScale:", 0), 0.5);
        }
        
        return result;
    } else {
        return [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];
    }
}

void applySmoothRoundedCornersImpl(CALayer * _Nonnull layer) {
    if (@available(iOS 11.0, *)) {
        setBoolField(layer, encodeText(@"tfuDpoujovpvtDpsofst;", -1), true);
    }
}
