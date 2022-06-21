#import <UIKit/UIKit.h>

typedef NS_OPTIONS(NSUInteger, UIResponderDisableAutomaticKeyboardHandling) {
    UIResponderDisableAutomaticKeyboardHandlingForward = 1 << 0,
    UIResponderDisableAutomaticKeyboardHandlingBackward = 1 << 1
};

@interface UIViewController (Navigation)

- (void)setHintWillBePresentedInPreviewingContext:(BOOL)value;
- (BOOL)isPresentedInPreviewingContext;
- (void)setIgnoreAppearanceMethodInvocations:(BOOL)ignoreAppearanceMethodInvocations;
- (BOOL)ignoreAppearanceMethodInvocations;
- (void)navigation_setNavigationController:(UINavigationController * _Nullable)navigationControlller;
- (void)navigation_setPresentingViewController:(UIViewController * _Nullable)presentingViewController;
- (void)navigation_setDismiss:(void (^_Nullable)())dismiss rootController:( UIViewController * _Nullable )rootController;
- (void)state_setNeedsStatusBarAppearanceUpdate:(void (^_Nullable)())block;

@end

@interface UIApplication (Additions)

- (void)internalSetStatusBarStyle:(UIStatusBarStyle)style animated:(BOOL)animated;
- (void)internalSetStatusBarHidden:(BOOL)hidden animation:(UIStatusBarAnimation)animation;

@end

@interface UIView (Navigation)

@property (nonatomic) bool disablesInteractiveTransitionGestureRecognizer;
@property (nonatomic) bool disablesInteractiveKeyboardGestureRecognizer;
@property (nonatomic) bool disablesInteractiveModalDismiss;
@property (nonatomic, copy) bool (^ _Nullable disablesInteractiveTransitionGestureRecognizerNow)();

@property (nonatomic) UIResponderDisableAutomaticKeyboardHandling disableAutomaticKeyboardHandling;

@property (nonatomic, copy) BOOL (^_Nullable interactiveTransitionGestureRecognizerTest)(CGPoint);

- (void)input_setInputAccessoryHeightProvider:(CGFloat (^_Nullable)())block;
- (CGFloat)input_getInputAccessoryHeight;

@end

void applyKeyboardAutocorrection(UITextView * _Nonnull textView);

@interface AboveStatusBarWindow : UIWindow

@property (nonatomic, copy) UIInterfaceOrientationMask (^ _Nullable supportedOrientations)(void);

@end
