#import "UIViewController+Navigation.h"

#import <ObjCRuntimeUtils/RuntimeUtils.h>
#import <objc/runtime.h>

#import "NSWeakReference.h"
#import <UIKitRuntimeUtils/UIKitUtils.h>

@interface UIViewControllerPresentingProxy : UIViewController

@property (nonatomic, copy) void (^dismiss)();
@property (nonatomic, strong, readonly) UIViewController *rootController;

@end

@implementation UIViewControllerPresentingProxy

- (instancetype)initWithRootController:(UIViewController *)rootController {
    _rootController = rootController;
    return self;
}

- (void)dismissViewControllerAnimated:(BOOL)__unused flag completion:(void (^)(void))completion {
    if (_dismiss) {
        _dismiss();
    }
    if (completion) {
        completion();
    }
}

@end

static const void *UIViewControllerIgnoreAppearanceMethodInvocationsKey = &UIViewControllerIgnoreAppearanceMethodInvocationsKey;
static const void *UIViewControllerNavigationControllerKey = &UIViewControllerNavigationControllerKey;
static const void *UIViewControllerPresentingControllerKey = &UIViewControllerPresentingControllerKey;
static const void *UIViewControllerPresentingProxyControllerKey = &UIViewControllerPresentingProxyControllerKey;
static const void *disablesInteractiveTransitionGestureRecognizerKey = &disablesInteractiveTransitionGestureRecognizerKey;
static const void *disablesInteractiveKeyboardGestureRecognizerKey = &disablesInteractiveKeyboardGestureRecognizerKey;
static const void *disablesInteractiveTransitionGestureRecognizerNowKey = &disablesInteractiveTransitionGestureRecognizerNowKey;
static const void *disableAutomaticKeyboardHandlingKey = &disableAutomaticKeyboardHandlingKey;
static const void *setNeedsStatusBarAppearanceUpdateKey = &setNeedsStatusBarAppearanceUpdateKey;
static const void *inputAccessoryHeightProviderKey = &inputAccessoryHeightProviderKey;
static const void *interactiveTransitionGestureRecognizerTestKey = &interactiveTransitionGestureRecognizerTestKey;
static const void *UIViewControllerHintWillBePresentedInPreviewingContextKey = &UIViewControllerHintWillBePresentedInPreviewingContextKey;
static const void *disablesInteractiveModalDismissKey = &disablesInteractiveModalDismissKey;
static const void *forceFullRefreshRateKey = &forceFullRefreshRateKey;

static bool notyfyingShiftState = false;

@interface UIKeyboardImpl_65087dc8: UIView

@end

@implementation UIKeyboardImpl_65087dc8

- (void)notifyShiftState {
    static void (*impl)(id, SEL) = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method m = class_getInstanceMethod([UIKeyboardImpl_65087dc8 class], @selector(notifyShiftState));
        impl = (typeof(impl))method_getImplementation(m);
    });
    if (impl) {
        notyfyingShiftState = true;
        impl(self, @selector(notifyShiftState));
        notyfyingShiftState = false;
    }
}

@end

@interface UIInputWindowController_65087dc8: UIViewController

@end

@implementation UIInputWindowController_65087dc8

- (void)updateViewConstraints {
    static void (*impl)(id, SEL) = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method m = class_getInstanceMethod([UIInputWindowController_65087dc8 class], @selector(updateViewConstraints));
        impl = (typeof(impl))method_getImplementation(m);
    });
    if (impl) {
        if (!notyfyingShiftState) {
            impl(self, @selector(updateViewConstraints));
        }
    }
}

@end

@interface CADisplayLink (FrameRateRangeOverride)

- (void)_65087dc8_setPreferredFrameRateRange:(CAFrameRateRange)range API_AVAILABLE(ios(15.0));

@end

@implementation CADisplayLink (FrameRateRangeOverride)

- (void)_65087dc8_setPreferredFrameRateRange:(CAFrameRateRange)range API_AVAILABLE(ios(15.0)) {
    if ([self associatedObjectForKey:forceFullRefreshRateKey] != nil) {
        float maxFps = [UIScreen mainScreen].maximumFramesPerSecond;
        if (maxFps > 61.0f) {
            range = CAFrameRateRangeMake(maxFps, maxFps, maxFps);
        }
    }
    
    [self _65087dc8_setPreferredFrameRateRange:range];
}

@end

@implementation CALayerSpringParametersOverrideParameters

- (instancetype _Nonnull)init {
    self = [super init];
    if (self != nil) {
    }
    return self;
}

@end

@implementation CALayerSpringParametersOverrideParametersSpring

- (instancetype _Nonnull)initWithStiffness:(CGFloat)stiffness damping:(CGFloat)damping duration:(double)duration {
    self = [super init];
    if (self != nil) {
        _stiffness = stiffness;
        _damping = damping;
        _duration = duration;
    }
    return self;
}

@end

@implementation CALayerSpringParametersOverrideParametersCustomCurve

- (instancetype _Nonnull)initWithCp1:(CGPoint)cp1 cp2:(CGPoint)cp2 {
    self = [super init];
    if (self != nil) {
        _cp1 = cp1;
        _cp2 = cp2;
    }
    return self;
}

@end


@implementation CALayerSpringParametersOverride

- (instancetype _Nonnull)initWithParameters:(CALayerSpringParametersOverrideParameters * _Nullable)parameters {
    self = [super init];
    if (self != nil) {
        _parameters = parameters;
    }
    return self;
}

@end

static NSMutableArray<CALayerSpringParametersOverride *> *currentSpringParametersOverrideStack() {
    static NSMutableArray *array = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        array = [[NSMutableArray alloc] init];
    });
    return array;
}

@implementation CALayer (TelegramAddAnimation)

+ (void)pushSpringParametersOverride:(CALayerSpringParametersOverride * _Nonnull)springParametersOverride {
    if (springParametersOverride) {
        [currentSpringParametersOverrideStack() addObject:springParametersOverride];
    }
}

+ (void)popSpringParametersOverride {
    if (currentSpringParametersOverrideStack().count != 0) {
        [currentSpringParametersOverrideStack() removeLastObject];
    }
}

- (void)_65087dc8_addAnimation:(CAAnimation *)anim forKey:(NSString *)key {
    CAAnimation *updatedAnimation = anim;
    if (currentSpringParametersOverrideStack().count != 0 && [anim isKindOfClass:[CASpringAnimation class]]) {
        CALayerSpringParametersOverride *overrideData = [currentSpringParametersOverrideStack() lastObject];
        if (overrideData) {
            if ([overrideData.parameters isKindOfClass:[CALayerSpringParametersOverrideParametersSpring class]]) {
                CALayerSpringParametersOverrideParametersSpring *parameters = (CALayerSpringParametersOverrideParametersSpring *)overrideData.parameters;
                CABasicAnimation *sourceAnimation = (CABasicAnimation *)anim;
                
                CASpringAnimation *animation = makeSpringBounceAnimationImpl(sourceAnimation.keyPath, 0.0, parameters.damping);
                
                animation.stiffness = parameters.stiffness;
                animation.fromValue = sourceAnimation.fromValue;
                animation.toValue = sourceAnimation.toValue;
                animation.byValue = sourceAnimation.byValue;
                animation.additive = sourceAnimation.additive;
                animation.removedOnCompletion = sourceAnimation.isRemovedOnCompletion;
                animation.fillMode = sourceAnimation.fillMode;
                animation.beginTime = sourceAnimation.beginTime;
                animation.timeOffset = sourceAnimation.timeOffset;
                animation.repeatCount = sourceAnimation.repeatCount;
                animation.autoreverses = sourceAnimation.autoreverses;
                
                float k = animationDurationFactorImpl();
                __unused float speed = 1.0f;
                if (k != 0.0 && k != 1.0) {
                    speed = 1.0f / k;
                }
                animation.speed = sourceAnimation.speed * (float)(animation.duration / parameters.duration);
                
                updatedAnimation = animation;
            } else if ([overrideData.parameters isKindOfClass:[CALayerSpringParametersOverrideParametersCustomCurve class]]) {
                CALayerSpringParametersOverrideParametersCustomCurve *parameters = (CALayerSpringParametersOverrideParametersCustomCurve *)overrideData.parameters;
                CABasicAnimation *sourceAnimation = (CABasicAnimation *)anim;
                
                CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:sourceAnimation.keyPath];
                animation.fromValue = sourceAnimation.fromValue;
                animation.toValue = sourceAnimation.toValue;
                animation.byValue = sourceAnimation.byValue;
                animation.additive = sourceAnimation.additive;
                animation.duration = sourceAnimation.duration;
                animation.timingFunction = [[CAMediaTimingFunction alloc] initWithControlPoints:parameters.cp1.x :parameters.cp1.y :parameters.cp2.x :parameters.cp2.y];
                animation.removedOnCompletion = sourceAnimation.isRemovedOnCompletion;
                animation.fillMode = sourceAnimation.fillMode;
                animation.speed = sourceAnimation.speed;
                animation.beginTime = sourceAnimation.beginTime;
                animation.timeOffset = sourceAnimation.timeOffset;
                animation.repeatCount = sourceAnimation.repeatCount;
                animation.autoreverses = sourceAnimation.autoreverses;
                
                float k = animationDurationFactorImpl();
                float speed = 1.0f;
                if (k != 0.0 && k != 1.0) {
                    speed = 1.0f / k;
                }
                animation.speed = speed * sourceAnimation.speed;
                
                updatedAnimation = animation;
            } else {
                bool isNativeGlass = false;
                if (@available(iOS 26.0, *)) {
                    isNativeGlass = true;
                }
                if (isNativeGlass && ABS(anim.duration - 0.3832) <= 0.0001) {
                } else if (ABS(anim.duration - 0.5) <= 0.0001) {
                } else {
                    CABasicAnimation *sourceAnimation = (CABasicAnimation *)anim;
                    
                    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:sourceAnimation.keyPath];
                    animation.fromValue = sourceAnimation.fromValue;
                    animation.toValue = sourceAnimation.toValue;
                    animation.byValue = sourceAnimation.byValue;
                    animation.additive = sourceAnimation.additive;
                    animation.duration = sourceAnimation.duration;
                    animation.timingFunction = [[CAMediaTimingFunction alloc] initWithControlPoints:0.380 :0.700 :0.125 :1.000];
                    animation.removedOnCompletion = sourceAnimation.isRemovedOnCompletion;
                    animation.fillMode = sourceAnimation.fillMode;
                    animation.speed = sourceAnimation.speed;
                    animation.beginTime = sourceAnimation.beginTime;
                    animation.timeOffset = sourceAnimation.timeOffset;
                    animation.repeatCount = sourceAnimation.repeatCount;
                    animation.autoreverses = sourceAnimation.autoreverses;
                    
                    float k = animationDurationFactorImpl();
                    float speed = 1.0f;
                    if (k != 0.0 && k != 1.0) {
                        speed = 1.0f / k;
                    }
                    animation.speed = speed * sourceAnimation.speed;
                    
                    updatedAnimation = animation;
                }
            }
        }
    }
    [self _65087dc8_addAnimation:updatedAnimation forKey:key];
}

@end

@implementation UIScrollView (FrameRateRangeOverride)

- (void)fixScrollDisplayLink {
    if (@available(iOS 16.0, *)) {
        return;
    }
    static NSString *scrollHeartbeatKey = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        scrollHeartbeatKey = [NSString stringWithFormat:@"_%@", @"scrollHeartbeat"];
    });
    
    id value = [self valueForKey:scrollHeartbeatKey];
    if ([value isKindOfClass:[CADisplayLink class]]) {
        CADisplayLink *displayLink = (CADisplayLink *)value;
        if ([displayLink associatedObjectForKey:forceFullRefreshRateKey] == nil) {
            [displayLink setAssociatedObject:@true forKey:forceFullRefreshRateKey];
            
            if (@available(iOS 15.0, *)) {
                float maxFps = [UIScreen mainScreen].maximumFramesPerSecond;
                if (maxFps > 61.0f) {
                    [displayLink setPreferredFrameRateRange:CAFrameRateRangeMake(maxFps, maxFps, maxFps)];
                }
            }
        }
    }
}

@end

@interface UIWindow (Telegram)

@end

@implementation UIWindow (Telegram)

- (instancetype)_65087dc8_initWithFrame:(CGRect)frame {
    return [self _65087dc8_initWithFrame:frame];
}

@end

@protocol UIRemoteKeyboardWindowProtocol

+ (UIWindow * _Nullable)remoteKeyboardWindowForScreen:(UIScreen * _Nullable)screen create:(BOOL)create;

@end

@interface UIFocusSystem (Telegram)

@end

@implementation UIFocusSystem (Telegram)

- (void)_65087dc8_updateFocusIfNeeded {
    //TODO:Re-enable
}

@end

static EffectSettingsContainerView *findTopmostEffectSuperview(UIView *view, int depth) {
    if (depth > 10) {
        return nil;
    }
    if ([view isKindOfClass:[EffectSettingsContainerView class]]) {
        return (EffectSettingsContainerView *)view;
    }
    if (view.superview != nil) {
        return findTopmostEffectSuperview(view.superview, depth + 1);
    } else {
        return nil;
    }
}

static id (*original_backdropLayerDidChangeLuma)(UIView *, SEL, CALayer *, double) = NULL;
static void replacement_backdropLayerDidChangeLuma(UIView *self, SEL selector, CALayer *layer, double luma) {
    EffectSettingsContainerView *topmostSuperview = findTopmostEffectSuperview(self, 0);
    if (topmostSuperview) {
        luma = MIN(MAX(luma, topmostSuperview.lumaMin), topmostSuperview.lumaMax);
    }
    original_backdropLayerDidChangeLuma(self, selector, layer, luma);
}

static NSString *TGEncodeText(NSString *string, int key) {
    NSMutableString *result = [[NSMutableString alloc] init];
    
    for (int i = 0; i < (int)[string length]; i++) {
        unichar c = [string characterAtIndex:i];
        c += key;
        [result appendString:[NSString stringWithCharacters:&c length:1]];
    }
    
    return result;
}

static void registerEffectViewOverrides(void) {
    NSMutableArray<NSString *> *nameList = [[NSMutableArray alloc] init];
    [nameList addObject:TGEncodeText(@"_TtC5UIKitP33_ACD4A08F4BE9D00246F2A9C24A80CA8817UISDFBackdropView", 0)];
    NSString *selectorString = [@"backdropLayer" stringByAppendingString:@":didChangeLuma:"];
    
    for (NSString *name in nameList) {
        Class classValue = NSClassFromString(name);
        if (classValue == nil) {
            continue;
        }
        
        Method method = (Method)[RuntimeUtils getMethodOfClass:classValue selector:NSSelectorFromString(selectorString)];
        if (method) {
            const char *typeEncoding = method_getTypeEncoding(method);
            if (strcmp(typeEncoding, "v32@0:8@16d24") == 0) {
                original_backdropLayerDidChangeLuma = (id (*)(id, SEL, CALayer *, double))method_getImplementation(method);
                [RuntimeUtils replaceMethodImplementationOfClass:classValue selector:NSSelectorFromString(selectorString) replacement:(IMP)&replacement_backdropLayerDidChangeLuma];
            }
        }
        break;
    }
}

@implementation UIViewController (Navigation)

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        [RuntimeUtils swizzleInstanceMethodOfClass:[UIViewController class] currentSelector:@selector(viewWillAppear:) newSelector:@selector(_65087dc8_viewWillAppear:)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UIViewController class] currentSelector:@selector(viewDidAppear:) newSelector:@selector(_65087dc8_viewDidAppear:)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UIViewController class] currentSelector:@selector(viewWillDisappear:) newSelector:@selector(_65087dc8_viewWillDisappear:)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UIViewController class] currentSelector:@selector(viewDidDisappear:) newSelector:@selector(_65087dc8_viewDidDisappear:)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UIViewController class] currentSelector:@selector(navigationController) newSelector:@selector(_65087dc8_navigationController)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UIViewController class] currentSelector:@selector(presentingViewController) newSelector:@selector(_65087dc8_presentingViewController)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UIViewController class] currentSelector:@selector(presentViewController:animated:completion:) newSelector:@selector(_65087dc8_presentViewController:animated:completion:)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UIViewController class] currentSelector:@selector(setNeedsStatusBarAppearanceUpdate) newSelector:@selector(_65087dc8_setNeedsStatusBarAppearanceUpdate)];
        
        [RuntimeUtils swizzleInstanceMethodOfClass:[UIWindow class] currentSelector:@selector(initWithFrame:) newSelector:@selector(_65087dc8_initWithFrame:)];
        
        if (@available(iOS 16.0, *)) {
        } else if (@available(iOS 15.0, *)) {
            [RuntimeUtils swizzleInstanceMethodOfClass:[CADisplayLink class] currentSelector:@selector(setPreferredFrameRateRange:) newSelector:@selector(_65087dc8_setPreferredFrameRateRange:)];
        }
        
        [RuntimeUtils swizzleInstanceMethodOfClass:[CALayer class] currentSelector:@selector(addAnimation:forKey:) newSelector:@selector(_65087dc8_addAnimation:forKey:)];
        
        [RuntimeUtils swizzleInstanceMethodOfClass:[UIFocusSystem class] currentSelector:@selector(updateFocusIfNeeded) newSelector:@selector(_65087dc8_updateFocusIfNeeded)];
        
        if (@available(iOS 26.0, *)) {
            registerEffectViewOverrides();
        }
        
        /*#if DEBUG
        Class cls = NSClassFromString(@"WKBrowsingContextController");
        SEL sel = NSSelectorFromString(@"registerSchemeForCustomProtocol:");
        if ([cls respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [cls performSelector:sel withObject:@"http"];
            [cls performSelector:sel withObject:@"https"];
#pragma clang diagnostic pop
        }
        #endif*/
    });
}

- (void)setHintWillBePresentedInPreviewingContext:(BOOL)value {
    [self setAssociatedObject:@(value) forKey:UIViewControllerHintWillBePresentedInPreviewingContextKey];
}

- (BOOL)isPresentedInPreviewingContext {
    if ([[self associatedObjectForKey:UIViewControllerHintWillBePresentedInPreviewingContextKey] boolValue]) {
        return true;
    } else {
        return false;
    }
}

- (void)setIgnoreAppearanceMethodInvocations:(BOOL)ignoreAppearanceMethodInvocations
{
    [self setAssociatedObject:@(ignoreAppearanceMethodInvocations) forKey:UIViewControllerIgnoreAppearanceMethodInvocationsKey];
}

- (BOOL)ignoreAppearanceMethodInvocations
{
    return [[self associatedObjectForKey:UIViewControllerIgnoreAppearanceMethodInvocationsKey] boolValue];
}

- (void)_65087dc8_viewWillAppear:(BOOL)animated
{
    if (![self ignoreAppearanceMethodInvocations])
        [self _65087dc8_viewWillAppear:animated];
}

- (void)_65087dc8_viewDidAppear:(BOOL)animated
{
    if (![self ignoreAppearanceMethodInvocations])
        [self _65087dc8_viewDidAppear:animated];
}

- (void)_65087dc8_viewWillDisappear:(BOOL)animated
{
    if (![self ignoreAppearanceMethodInvocations])
        [self _65087dc8_viewWillDisappear:animated];
}

- (void)_65087dc8_viewDidDisappear:(BOOL)animated
{
    if (![self ignoreAppearanceMethodInvocations])
        [self _65087dc8_viewDidDisappear:animated];
}

- (void)navigation_setNavigationController:(UINavigationController * _Nullable)navigationControlller {
    [self setAssociatedObject:[[NSWeakReference alloc] initWithValue:navigationControlller] forKey:UIViewControllerNavigationControllerKey];
}

- (UINavigationController *)_65087dc8_navigationController {
    UINavigationController *navigationController = self._65087dc8_navigationController;
    if (navigationController != nil) {
        return navigationController;
    }
    
    UIViewController *parentController = self.parentViewController;
    
    navigationController = parentController.navigationController;
    if (navigationController != nil) {
        return navigationController;
    }
    
    return ((NSWeakReference *)[self associatedObjectForKey:UIViewControllerNavigationControllerKey]).value;
}

- (void)navigation_setPresentingViewController:(UIViewController *)presentingViewController {
    [self setAssociatedObject:[[NSWeakReference alloc] initWithValue:presentingViewController] forKey:UIViewControllerPresentingControllerKey];
}

- (void)navigation_setDismiss:(void (^_Nullable)())dismiss rootController:(UIViewController *)rootController {
    UIViewControllerPresentingProxy *proxy = [[UIViewControllerPresentingProxy alloc] initWithRootController:rootController];
    proxy.dismiss = dismiss;
    [self setAssociatedObject:proxy forKey:UIViewControllerPresentingProxyControllerKey];
}

- (UIViewController *)_65087dc8_presentingViewController {
    UINavigationController *navigationController = self.navigationController;
    if (navigationController.presentingViewController != nil) {
        return navigationController.presentingViewController;
    }
    
    UIViewController *controller = ((NSWeakReference *)[self associatedObjectForKey:UIViewControllerPresentingControllerKey]).value;
    if (controller != nil) {
        return controller;
    }
    
    UIViewController *result = [self associatedObjectForKey:UIViewControllerPresentingProxyControllerKey];
    if (result != nil) {
        return result;
    }
    
    return [self _65087dc8_presentingViewController];
}

- (void)_65087dc8_presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    [self _65087dc8_presentViewController:viewControllerToPresent animated:flag completion:completion];
}

- (void)_65087dc8_setNeedsStatusBarAppearanceUpdate {
    [self _65087dc8_setNeedsStatusBarAppearanceUpdate];
    
    void (^block)() = [self associatedObjectForKey:setNeedsStatusBarAppearanceUpdateKey];
    if (block) {
        block();
    }
}

- (void)state_setNeedsStatusBarAppearanceUpdate:(void (^_Nullable)())block {
    [self setAssociatedObject:[block copy] forKey:setNeedsStatusBarAppearanceUpdateKey];
}

@end

@implementation UIApplication (Additions)

- (void)internalSetStatusBarStyle:(UIStatusBarStyle)style animated:(BOOL)animated {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [self setStatusBarStyle:style animated:animated];
#pragma clang diagnostic pop
}

- (void)internalSetStatusBarHidden:(BOOL)hidden animation:(UIStatusBarAnimation)animation {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [self setStatusBarHidden:hidden withAnimation:animation];
#pragma clang diagnostic pop
}

/*static void dumpViews(UIView *view, NSString *indent) {
    NSLog(@"%@%@", indent, [view debugDescription]);
    NSString *nextIndent = [indent stringByAppendingString:@"-"];
    
    if ([view isKindOfClass:[UIVisualEffectView class]]) {
        UIVisualEffectView *effectView = (UIVisualEffectView *)view;
        if (@available(iOS 26.0, *)) {
            if ([effectView.effect isKindOfClass:[UIGlassEffect class]]) {
                UIGlassEffect *effect = (UIGlassEffect *)effectView.effect;
                NSObject *glass = [effect valueForKey:@"glass"];
                NSLog(@"glass %@", glass.debugDescription);
            }
        }
    }
    
    for (UIView *subview in view.subviews) {
        dumpViews(subview, nextIndent);
    }
}*/

- (UIWindow * _Nullable)internalGetKeyboard {
    Class windowClass = NSClassFromString(@"UIRemoteKeyboardWindow");
    if (!windowClass) {
        return nil;
    }
    UIWindow *result = [(id<UIRemoteKeyboardWindowProtocol>)windowClass remoteKeyboardWindowForScreen:[UIScreen mainScreen] create:false];
    
    if (result) {
        //dumpViews(result, @"");
    }
    
    return result;
}

@end

@implementation UIView (Navigation)

- (bool)disablesInteractiveTransitionGestureRecognizer {
    return [[self associatedObjectForKey:disablesInteractiveTransitionGestureRecognizerKey] boolValue];
}

- (void)setDisablesInteractiveTransitionGestureRecognizer:(bool)disablesInteractiveTransitionGestureRecognizer {
    [self setAssociatedObject:@(disablesInteractiveTransitionGestureRecognizer) forKey:disablesInteractiveTransitionGestureRecognizerKey];
}

- (bool)disablesInteractiveKeyboardGestureRecognizer {
    return [[self associatedObjectForKey:disablesInteractiveKeyboardGestureRecognizerKey] boolValue];
}

- (void)setDisablesInteractiveKeyboardGestureRecognizer:(bool)disablesInteractiveKeyboardGestureRecognizer {
    [self setAssociatedObject:@(disablesInteractiveKeyboardGestureRecognizer) forKey:disablesInteractiveKeyboardGestureRecognizerKey];
}

- (bool (^)())disablesInteractiveTransitionGestureRecognizerNow {
    return [self associatedObjectForKey:disablesInteractiveTransitionGestureRecognizerNowKey];
}

- (void)setDisablesInteractiveTransitionGestureRecognizerNow:(bool (^)())disablesInteractiveTransitionGestureRecognizerNow {
    [self setAssociatedObject:[disablesInteractiveTransitionGestureRecognizerNow copy] forKey:disablesInteractiveTransitionGestureRecognizerNowKey];
}

- (bool)disablesInteractiveModalDismiss {
    return [self associatedObjectForKey:disablesInteractiveModalDismissKey];
}

- (void)setDisablesInteractiveModalDismiss:(bool)disablesInteractiveModalDismiss {
    [self setAssociatedObject:@(disablesInteractiveModalDismiss) forKey:disablesInteractiveModalDismissKey];
}

- (BOOL (^)(CGPoint))interactiveTransitionGestureRecognizerTest {
    return [self associatedObjectForKey:interactiveTransitionGestureRecognizerTestKey];
}

- (void)setInteractiveTransitionGestureRecognizerTest:(BOOL (^)(CGPoint))block {
    [self setAssociatedObject:[block copy] forKey:interactiveTransitionGestureRecognizerTestKey];
}

- (UIResponderDisableAutomaticKeyboardHandling)disableAutomaticKeyboardHandling {
    return (UIResponderDisableAutomaticKeyboardHandling)[[self associatedObjectForKey:disableAutomaticKeyboardHandlingKey] unsignedIntegerValue];
}

- (void)setDisableAutomaticKeyboardHandling:(UIResponderDisableAutomaticKeyboardHandling)disableAutomaticKeyboardHandling {
    [self setAssociatedObject:@(disableAutomaticKeyboardHandling) forKey:disableAutomaticKeyboardHandlingKey];
}

- (void)input_setInputAccessoryHeightProvider:(CGFloat (^_Nullable)())block {
    [self setAssociatedObject:[block copy] forKey:inputAccessoryHeightProviderKey];
}

- (CGFloat)input_getInputAccessoryHeight {
    CGFloat (^block)() = [self associatedObjectForKey:inputAccessoryHeightProviderKey];
    if (block) {
        return block();
    }
    return 0.0f;
}

@end

void applyKeyboardAutocorrection(UITextView * _Nonnull textView) {
    NSRange rangeCopy = textView.selectedRange;
    NSRange fakeRange = rangeCopy;
    if (fakeRange.location != 0) {
        fakeRange.location--;
    }
    [textView unmarkText];
    [textView setSelectedRange:fakeRange];
    [textView setSelectedRange:rangeCopy];
}

@interface AboveStatusBarWindowController : UIViewController

@property (nonatomic, copy) UIInterfaceOrientationMask (^ _Nullable supportedOrientations)(void);

@end

@implementation AboveStatusBarWindowController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nil bundle:nil];
    if (self != nil) {
        self.extendedLayoutIncludesOpaqueBars = true;
    }
    return self;
}

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:CGRectZero];
    self.view.opaque = false;
    self.view.backgroundColor = nil;
    [self viewDidLoad];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

@end

@implementation AboveStatusBarWindow

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        self.windowLevel = UIWindowLevelStatusBar + 1.0f;
        self.rootViewController = [[AboveStatusBarWindowController alloc] initWithNibName:nil bundle:nil];
        if (self.gestureRecognizers != nil) {
            for (UIGestureRecognizer *recognizer in self.gestureRecognizers) {
                recognizer.delaysTouchesBegan = false;
            }
        }
    }
    return self;
}

- (void)setSupportedOrientations:(UIInterfaceOrientationMask (^)(void))supportedOrientations {
    _supportedOrientations = [supportedOrientations copy];
    ((AboveStatusBarWindowController *)self.rootViewController).supportedOrientations = _supportedOrientations;
}

- (BOOL)shouldAffectStatusBarAppearance {
    return false;
}

- (BOOL)canBecomeKeyWindow {
    return false;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *result = [super hitTest:point withEvent:event];
    if (result == self || result == self.rootViewController.view) {
        return nil;
    }
    return result;
}

+ (void)initialize {
    NSString *canAffectSelectorString = [@[@"_can", @"Affect", @"Status", @"Bar", @"Appearance"] componentsJoinedByString:@""];
    SEL canAffectSelector = NSSelectorFromString(canAffectSelectorString);
    Method shouldAffectMethod = class_getInstanceMethod(self, @selector(shouldAffectStatusBarAppearance));
    IMP canAffectImplementation = method_getImplementation(shouldAffectMethod);
    class_addMethod(self, canAffectSelector, canAffectImplementation, method_getTypeEncoding(shouldAffectMethod));
    
    NSString *canBecomeKeySelectorString = [NSString stringWithFormat:@"_%@", NSStringFromSelector(@selector(canBecomeKeyWindow))];
    SEL canBecomeKeySelector = NSSelectorFromString(canBecomeKeySelectorString);
    Method canBecomeKeyMethod = class_getInstanceMethod(self, @selector(canBecomeKeyWindow));
    IMP canBecomeKeyImplementation = method_getImplementation(canBecomeKeyMethod);
    class_addMethod(self, canBecomeKeySelector, canBecomeKeyImplementation, method_getTypeEncoding(canBecomeKeyMethod));
}

@end

void snapshotViewByDrawingInContext(UIView * _Nonnull view) {
    [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:false];
}

@implementation EffectSettingsContainerView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        _lumaMin = 0.0;
        _lumaMax = 0.0;
    }
    return self;
}

@end
