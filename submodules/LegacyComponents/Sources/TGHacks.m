#import "TGHacks.h"

#import "LegacyComponentsInternal.h"
#import "TGAnimationBlockDelegate.h"

#import "FreedomUIKit.h"

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#import <objc/runtime.h>
#import <objc/message.h>

#import "TGViewController.h"
#import "TGNavigationBar.h"

static float animationDurationFactor = 1.0f;
static float secondaryAnimationDurationFactor = 1.0f;
static bool forceSystemCurve = false;

static bool forceMovieAnimatedScaleMode = false;

static bool forcePerformWithAnimationFlag = false;

void SwizzleClassMethod(Class c, SEL orig, SEL new)
{
    Method origMethod = class_getClassMethod(c, orig);
    Method newMethod = class_getClassMethod(c, new);
    
    c = object_getClass((id)c);
    
    if(class_addMethod(c, orig, method_getImplementation(newMethod), method_getTypeEncoding(newMethod)))
        class_replaceMethod(c, new, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    else
        method_exchangeImplementations(origMethod, newMethod);
}

void SwizzleInstanceMethod(Class c, SEL orig, SEL new)
{
    Method origMethod = nil, newMethod = nil;
    
    origMethod = class_getInstanceMethod(c, orig);
    newMethod = class_getInstanceMethod(c, new);
    if ((origMethod != nil) && (newMethod != nil))
    {
        if(class_addMethod(c, orig, method_getImplementation(newMethod), method_getTypeEncoding(newMethod)))
            class_replaceMethod(c, new, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
        else
            method_exchangeImplementations(origMethod, newMethod);
    }
    else
        NSLog(@"Attempt to swizzle nonexistent methods!");
}

void SwizzleInstanceMethodWithAnotherClass(Class c1, SEL orig, Class c2, SEL new)
{
    Method origMethod = nil, newMethod = nil;
    
    origMethod = class_getInstanceMethod(c1, orig);
    newMethod = class_getInstanceMethod(c2, new);
    if ((origMethod != nil) && (newMethod != nil))
    {
        if(class_addMethod(c1, orig, method_getImplementation(newMethod), method_getTypeEncoding(newMethod)))
            class_replaceMethod(c1, new, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
        else
            method_exchangeImplementations(origMethod, newMethod);
    }
    else
        NSLog(@"Attempt to swizzle nonexistent methods!");
}

void InjectClassMethodFromAnotherClass(Class toClass, Class fromClass, SEL fromSelector, SEL toSeletor)
{
    Method method = class_getClassMethod(fromClass, fromSelector);
    if (method != nil)
    {
        if (!class_addMethod(toClass, toSeletor, method_getImplementation(method), method_getTypeEncoding(method)))
            NSLog(@"Attempt to add method failed");
    }
    else
        NSLog(@"Attempt to add nonexistent method");
}

void InjectInstanceMethodFromAnotherClass(Class toClass, Class fromClass, SEL fromSelector, SEL toSeletor)
{
    Method method = class_getInstanceMethod(fromClass, fromSelector);
    if (method != nil)
    {
        if (!class_addMethod(toClass, toSeletor, method_getImplementation(method), method_getTypeEncoding(method)))
            NSLog(@"Attempt to add method failed");
    }
    else
        NSLog(@"Attempt to add nonexistent method");
}

@interface UIView (TGHacks)

+ (void)telegraph_setAnimationDuration:(NSTimeInterval)duration;
+ (void)TG_performWithoutAnimation:(void (^)(void))actionsWithoutAnimation;

- (UIView *)TG_snapshotViewAfterScreenUpdates:(BOOL)afterUpdates;

@end

@implementation UIView (TGHacks)

+ (void)telegraph_setAnimationDuration:(NSTimeInterval)duration
{
    [self telegraph_setAnimationDuration:(duration * animationDurationFactor)];
}

+ (void)telegraph_animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion
{
    if (forceSystemCurve) {
        options |= (7 << 16);
    }
    [self telegraph_animateWithDuration:duration * secondaryAnimationDurationFactor delay:delay options:options animations:animations completion:completion];
}

+ (void)TG_performWithoutAnimation:(void (^)(void))actionsWithoutAnimation
{
    float lastDurationFactor = animationDurationFactor;
    animationDurationFactor = 0.0f;
    
    bool animationsWereEnabled = [UIView areAnimationsEnabled];
    [UIView setAnimationsEnabled:false];
    
    if (actionsWithoutAnimation)
        actionsWithoutAnimation();
    
    [UIView setAnimationsEnabled:animationsWereEnabled];
    animationDurationFactor = lastDurationFactor;
}

+ (void)TG_performWithoutAnimation_maybeNot:(void (^)(void))actionsWithoutAnimation
{
    if (actionsWithoutAnimation)
    {
        if (forcePerformWithAnimationFlag)
            actionsWithoutAnimation();
        else
            [self TG_performWithoutAnimation_maybeNot:actionsWithoutAnimation];
    }
}

- (UIView *)TG_snapshotViewAfterScreenUpdates:(BOOL)__unused afterUpdates
{
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, self.opaque, 0.0f);
    
    [self.layer renderInContext:UIGraphicsGetCurrentContext()];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    if (image != nil)
        return [[UIImageView alloc] initWithImage:image];
    
    return nil;
}

@end

#pragma mark -

@implementation TGHacks

+ (void)hackSetAnimationDuration
{
    SwizzleClassMethod([UIView class], @selector(setAnimationDuration:), @selector(telegraph_setAnimationDuration:));
    SwizzleClassMethod([UIView class], @selector(animateWithDuration:delay:options:animations:completion:), @selector(telegraph_animateWithDuration:delay:options:animations:completion:));
    
    if (iosMajorVersion() >= 7)
    {
        if (iosMajorVersion() >= 8)
        {
            SwizzleClassMethod([UIView class], @selector(performWithoutAnimation:), @selector(TG_performWithoutAnimation_maybeNot:));
        }
    }
    else
    {
        InjectClassMethodFromAnotherClass(object_getClass([UIView class]), object_getClass([UIView class]), @selector(TG_performWithoutAnimation:), @selector(performWithoutAnimation:));
        InjectInstanceMethodFromAnotherClass([UIView class], [UIView class], @selector(TG_snapshotViewAfterScreenUpdates:), @selector(snapshotViewAfterScreenUpdates:));
    }
}

+ (void)setAnimationDurationFactor:(float)factor
{
    animationDurationFactor = factor;
}

+ (void)setSecondaryAnimationDurationFactor:(float)factor
{
    secondaryAnimationDurationFactor = factor;
}

+ (void)setForceSystemCurve:(bool)force {
    forceSystemCurve = force;
}

+ (CGFloat)applicationStatusBarAlpha
{
    CGFloat alpha = 1.0f;
    
    UIWindow *window = [[LegacyComponentsGlobals provider] applicationStatusBarWindow];
    if (window != nil) {
        alpha = window.alpha;
    }
    
    return alpha;
}

+ (void)setApplicationStatusBarAlpha:(CGFloat)alpha
{
    UIWindow *window = [[LegacyComponentsGlobals provider] applicationStatusBarWindow];
    window.alpha = alpha;
}

+ (bool)isKeyboardVisible
{
    return [self isKeyboardVisibleAlt];
}

static bool keyboardHidden = true;

+ (bool)isKeyboardVisibleAlt
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillHideNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *notification)
        {
            if (!freedomUIKitTest3())
                keyboardHidden = true;
        }];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillShowNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *notification)
        {
            keyboardHidden = false;
        }];
    });
    
    return !keyboardHidden;
}

+ (void)applyCurrentKeyboardAutocorrectionVariant:(UITextView *)textView
{
    [textView unmarkText];
}

+ (UIWindow *)applicationKeyboardWindow
{
    return [[LegacyComponentsGlobals provider] applicationKeyboardWindow];
}

+ (void)setApplicationKeyboardOffset:(CGFloat)offset
{
    UIWindow *keyboardWindow = [self applicationKeyboardWindow];
    keyboardWindow.frame = CGRectOffset(keyboardWindow.bounds, 0.0f, offset);
}

+ (void)setForceMovieAnimatedScaleMode:(bool)force
{
    forceMovieAnimatedScaleMode = force;
}

+ (void)forcePerformWithAnimation:(dispatch_block_t)block
{
    if (block)
    {
        bool flag = forcePerformWithAnimationFlag;
        forcePerformWithAnimationFlag = true;
        block();
        forcePerformWithAnimationFlag = flag;
    }
}

@end

#if TARGET_IPHONE_SIMULATOR
extern float UIAnimationDragCoefficient(void);
#endif

CGFloat TGAnimationSpeedFactor()
{
#if TARGET_IPHONE_SIMULATOR
    return UIAnimationDragCoefficient();
#endif
    
    return 1.0f;
}
