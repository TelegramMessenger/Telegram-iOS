#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif
    
void SwizzleClassMethod(Class c, SEL orig, SEL newSel);
void SwizzleInstanceMethod(Class c, SEL orig, SEL newSel);
void SwizzleInstanceMethodWithAnotherClass(Class c1, SEL origSel, Class c2, SEL newSel);
void InjectClassMethodFromAnotherClass(Class toClass, Class fromClass, SEL fromSelector, SEL toSeletor);
void InjectInstanceMethodFromAnotherClass(Class toClass, Class fromClass, SEL fromSelector, SEL toSeletor);
    
#ifdef __cplusplus
}
#endif

typedef void (^TGAlertHandler)(UIAlertView *alertView);

typedef enum {
    TGStatusBarAppearanceAnimationSlideDown = 1,
    TGStatusBarAppearanceAnimationSlideUp = 2,
    TGStatusBarAppearanceAnimationFadeOut = 4,
    TGStatusBarAppearanceAnimationFadeIn = 8
} TGStatusBarAppearanceAnimation;

@interface TGHacks : NSObject

+ (void)hackSetAnimationDuration;
+ (void)setAnimationDurationFactor:(float)factor;
+ (void)setSecondaryAnimationDurationFactor:(float)factor;
+ (void)setForceSystemCurve:(bool)forceSystemCurve;

+ (CGFloat)applicationStatusBarOffset;
+ (void)setApplicationStatusBarOffset:(CGFloat)offset;
+ (void)animateApplicationStatusBarStyleTransitionWithDuration:(NSTimeInterval)duration;
+ (CGFloat)statusBarHeightForOrientation:(UIInterfaceOrientation)orientation;

+ (bool)isKeyboardVisible;
+ (CGFloat)keyboardHeightForOrientation:(UIInterfaceOrientation)orientation;
+ (void)applyCurrentKeyboardAutocorrectionVariant;
+ (UIWindow *)applicationKeyboardWindow;
+ (UIView *)applicationKeyboardView;
+ (void)setApplicationKeyboardOffset:(CGFloat)offset;

+ (void)forcePerformWithAnimation:(dispatch_block_t)block;

@end

#ifdef __cplusplus
extern "C" {
#endif

CGFloat TGAnimationSpeedFactor();

#ifdef __cplusplus
}
#endif
