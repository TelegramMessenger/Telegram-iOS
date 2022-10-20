#import "UIViewController+Navigation.h"

#import <ObjCRuntimeUtils/RuntimeUtils.h>
#import <objc/runtime.h>

#import "NSWeakReference.h"


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

@implementation UIScrollView (FrameRateRangeOverride)

- (void)fixScrollDisplayLink {
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
        
        if (@available(iOS 15.0, *)) {
            [RuntimeUtils swizzleInstanceMethodOfClass:[CADisplayLink class] currentSelector:@selector(setPreferredFrameRateRange:) newSelector:@selector(_65087dc8_setPreferredFrameRateRange:)];
        }
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

- (UIWindow * _Nullable)internalGetKeyboard {
    Class windowClass = NSClassFromString(@"UIRemoteKeyboardWindow");
    if (!windowClass) {
        return nil;
    }
    UIWindow *result = [(id<UIRemoteKeyboardWindowProtocol>)windowClass remoteKeyboardWindowForScreen:[UIScreen mainScreen] create:false];
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
