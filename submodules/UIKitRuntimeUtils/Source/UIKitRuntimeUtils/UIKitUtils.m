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

+ (id)effectWithStyle:(long long)arg1;

@end

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

static void setBoolField(NSObject *object, NSString *name, BOOL value) {
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

UIBlurEffect *makeCustomZoomBlurEffectImpl(bool isLight) {
    if (@available(iOS 13.0, *)) {
        if (isLight) {
            return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialLight];
        } else {
            return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
        }
    } else if (@available(iOS 11.0, *)) {
        NSString *string = [@[@"_", @"UI", @"Custom", @"BlurEffect"] componentsJoinedByString:@""];
        CustomBlurEffect *result = (CustomBlurEffect *)[NSClassFromString(string) effectWithStyle:0];
        
        setField(result, [@[@"set", @"BlurRadius", @":"] componentsJoinedByString:@""], 10.0);
        setNilField(result, [@[@"set", @"Color", @"Tint", @":"] componentsJoinedByString:@""]);
        setField(result, [@[@"set", @"Color", @"Tint", @"Alpha", @":"] componentsJoinedByString:@""], 0.0);
        setField(result, [@[@"set", @"Darkening", @"Tint", @"Alpha", @":"] componentsJoinedByString:@""], 0.0);
        setField(result, [@[@"set", @"Grayscale", @"Tint", @"Alpha", @":"] componentsJoinedByString:@""], 0.0);
        setField(result, [@[@"set", @"Saturation", @"Delta", @"Factor", @":"] componentsJoinedByString:@""], 1.0);
        
        if ([UIScreen mainScreen].scale > 2.5f) {
            setField(result, @"setScale:", 0.3);
        } else {
            setField(result, @"setScale:", 0.5);
        }
        
        return result;
    } else {
        return [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];
    }
}

void applySmoothRoundedCornersImpl(CALayer * _Nonnull layer) {
    if (@available(iOS 13.0, *)) {
        layer.cornerCurve = kCACornerCurveContinuous;
    } else {
        setBoolField(layer, [@[@"set", @"Continuous", @"Corners", @":"] componentsJoinedByString:@""], true);
    }
}

/*@interface _UIPortalView : UIView

@property(nonatomic, getter=_isGeometryFrozen, setter=_setGeometryFrozen:) _Bool _geometryFrozen; // @synthesize _geometryFrozen=__geometryFrozen;
@property(nonatomic) _Bool forwardsClientHitTestingToSourceView; // @synthesize forwardsClientHitTestingToSourceView=_forwardsClientHitTestingToSourceView;
@property(copy, nonatomic) NSString * _Nullable name; // @synthesize name=_name;
@property(nonatomic) __weak UIView * _Nullable sourceView; // @synthesize sourceView=_sourceView;
- (void)setCenter:(struct CGPoint)arg1;
- (void)setBounds:(struct CGRect)arg1;
- (void)setFrame:(struct CGRect)arg1;
- (void)setHidden:(_Bool)arg1;
@property(nonatomic) _Bool allowsHitTesting; // @dynamic allowsHitTesting;
@property(nonatomic) _Bool allowsBackdropGroups; // @dynamic allowsBackdropGroups;
@property(nonatomic) _Bool matchesPosition; // @dynamic matchesPosition;
@property(nonatomic) _Bool matchesTransform; // @dynamic matchesTransform;
@property(nonatomic) _Bool matchesAlpha; // @dynamic matchesAlpha;
@property(nonatomic) _Bool hidesSourceView; // @dynamic hidesSourceView;
- (instancetype _Nonnull)initWithFrame:(struct CGRect)arg1;
- (instancetype _Nonnull)initWithSourceView:(UIView * _Nullable)arg1;

@end*/

UIView<UIKitPortalViewProtocol> * _Nullable makePortalView() {
    static Class portalViewClass = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        portalViewClass = NSClassFromString([@[@"_", @"UI", @"Portal", @"View"] componentsJoinedByString:@""]);
    });
    if (!portalViewClass) {
        return nil;
    }
    UIView<UIKitPortalViewProtocol> *view = [[portalViewClass alloc] init];
    if (!view) {
        return nil;
    }
    
    view.forwardsClientHitTestingToSourceView = false;
    view.matchesPosition = true;
    view.matchesTransform = true;
    view.matchesAlpha = false;
    view.allowsHitTesting = false;
    
    return view;
}
