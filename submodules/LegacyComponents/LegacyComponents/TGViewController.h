#import <UIKit/UIKit.h>
#import <SSignalKit/SSignalKit.h>

#import <LegacyComponents/LegacyComponentsContext.h>

typedef enum {
    TGViewControllerStyleDefault = 0,
    TGViewControllerStyleBlack = 1
} TGViewControllerStyle;

@class TGLabel;
@class TGNavigationController;

typedef enum {
    TGViewControllerNavigationBarAnimationNone = 0,
    TGViewControllerNavigationBarAnimationSlide = 1,
    TGViewControllerNavigationBarAnimationFade = 2,
    TGViewControllerNavigationBarAnimationSlideFar = 3
} TGViewControllerNavigationBarAnimation;

@protocol TGViewControllerNavigationBarAppearance <NSObject>

- (UIBarStyle)requiredNavigationBarStyle;
- (bool)navigationBarShouldBeHidden;

@optional

- (bool)navigationBarHasAction;
- (void)navigationBarAction;
- (void)navigationBarSwipeDownAction;

@optional

- (bool)statusBarShouldBeHidden;
- (UIStatusBarStyle)preferredStatusBarStyle;

@end

@interface TGViewController : UIViewController <TGViewControllerNavigationBarAppearance>

+ (void)setDefaultContext:(id<LegacyComponentsContext>)defaultContext;

+ (UIFont *)titleFontForStyle:(TGViewControllerStyle)style landscape:(bool)landscape;
+ (UIFont *)titleTitleFontForStyle:(TGViewControllerStyle)style landscape:(bool)landscape;
+ (UIFont *)titleSubtitleFontForStyle:(TGViewControllerStyle)style landscape:(bool)landscape;
+ (UIColor *)titleTextColorForStyle:(TGViewControllerStyle)style;

+ (CGSize)screenSize:(UIDeviceOrientation)orientation;
+ (CGSize)screenSizeForInterfaceOrientation:(UIInterfaceOrientation)orientation;
+ (bool)isWidescreen;
+ (bool)hasLargeScreen;
+ (bool)hasVeryLargeScreen;
+ (bool)hasTallScreen;

+ (void)disableAutorotation;
+ (void)enableAutorotation;
+ (void)disableAutorotationFor:(NSTimeInterval)timeInterval;
+ (void)disableAutorotationFor:(NSTimeInterval)timeInterval reentrant:(bool)reentrant;
+ (bool)autorotationAllowed;
+ (void)attemptAutorotation;

+ (void)disableUserInteractionFor:(NSTimeInterval)timeInterval;

@property (nonatomic, strong) NSMutableArray *associatedWindowStack;

@property (nonatomic) TGViewControllerStyle style;

@property (nonatomic) bool doNotFlipIfRTL;

@property (nonatomic) bool viewControllerIsChangingInterfaceOrientation;
@property (nonatomic) bool viewControllerHasEverAppeared;
@property (nonatomic) bool viewControllerIsAnimatingAppearanceTransition;
@property (nonatomic) bool adjustControllerInsetWhenStartingRotation;
@property (nonatomic) bool dismissPresentedControllerWhenRemovedFromNavigationStack;
@property (nonatomic) bool viewControllerIsAppearing;
@property (nonatomic) bool viewControllerIsDisappearing;

@property (nonatomic, readonly) CGFloat controllerStatusBarHeight;
@property (nonatomic, readonly) UIEdgeInsets controllerCleanInset;
@property (nonatomic, readonly) UIEdgeInsets controllerInset;
@property (nonatomic, readonly) UIEdgeInsets controllerScrollInset;
@property (nonatomic, readonly) UIEdgeInsets controllerSafeAreaInset;
@property (nonatomic) UIEdgeInsets parentInsets;
@property (nonatomic) UIEdgeInsets explicitTableInset;
@property (nonatomic) UIEdgeInsets explicitScrollIndicatorInset;
@property (nonatomic) CGFloat additionalNavigationBarHeight;
@property (nonatomic) CGFloat additionalStatusBarHeight;

@property (nonatomic) bool navigationBarShouldBeHidden;
@property (nonatomic) bool ignoreAppearEvents;

@property (nonatomic) bool autoManageStatusBarBackground;
@property (nonatomic) bool automaticallyManageScrollViewInsets;
@property (nonatomic) bool ignoreKeyboardWhenAdjustingScrollViewInsets;
@property (nonatomic) bool alwaysUseTallNavigationBarHeight;

@property (nonatomic) bool customAppearanceMethodsForwarding;

@property (nonatomic, strong) NSArray *scrollViewsForAutomaticInsetsAdjustment;

@property (nonatomic, weak) UIViewController *customParentViewController;

@property (nonatomic, strong) TGNavigationController *customNavigationController;

@property (nonatomic) bool isFirstInStack;

@property (nonatomic, readonly) UIUserInterfaceSizeClass currentSizeClass;

@property (nonatomic) CGSize intrinsicSize;

@property (nonatomic, copy) NSArray<id<UIPreviewActionItem>> *(^externalPreviewActionItems)(void);
@property (nonatomic, copy) void (^customRemoveFromParentViewController)(void);
@property (nonatomic, copy) void (^customDismissSelf)(void);

@property (nonatomic, readonly) id<LegacyComponentsContext> context;

- (id)initWithContext:(id<LegacyComponentsContext>)context NS_DESIGNATED_INITIALIZER;

- (void)setExplicitTableInset:(UIEdgeInsets)explicitTableInset scrollIndicatorInset:(UIEdgeInsets)scrollIndicatorInset;

- (void)adjustToInterfaceOrientation:(UIInterfaceOrientation)orientation;
- (UIEdgeInsets)controllerInsetForInterfaceOrientation:(UIInterfaceOrientation)orientation;

- (bool)_updateControllerInset:(bool)force;
- (bool)_updateControllerInsetForOrientation:(UIInterfaceOrientation)orientation force:(bool)force notify:(bool)notify;
- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset;
- (bool)shouldAdjustScrollViewInsetsForInversedLayout;
- (bool)shouldIgnoreNavigationBar;
- (bool)shouldIgnoreStatusBar;

- (void)setNavigationBarHidden:(bool)navigationBarHidden animated:(BOOL)animated;
- (void)setNavigationBarHidden:(bool)navigationBarHidden withAnimation:(TGViewControllerNavigationBarAnimation)animation;
- (void)setNavigationBarHidden:(bool)navigationBarHidden withAnimation:(TGViewControllerNavigationBarAnimation)animation duration:(NSTimeInterval)duration;
- (CGFloat)statusBarBackgroundAlpha;

- (void)setTargetNavigationItem:(UINavigationItem *)targetNavigationItem titleController:(UIViewController *)titleController;
- (void)setLeftBarButtonItem:(UIBarButtonItem *)leftBarButtonItem;
- (void)setLeftBarButtonItem:(UIBarButtonItem *)leftBarButtonItem animated:(BOOL)animated;
- (void)setRightBarButtonItem:(UIBarButtonItem *)rightBarButtonItem;
- (void)setRightBarButtonItem:(UIBarButtonItem *)rightBarButtonItem animated:(BOOL)animated;
- (void)setRightBarButtonItems:(NSArray *)rightBarButtonItems animated:(BOOL)animated;
- (void)setTitleText:(NSString *)titleText;
- (void)setTitleView:(UIView *)titleView;

- (UIView *)statusBarBackgroundView;
- (void)setStatusBarBackgroundAlpha:(float)alpha;

- (bool)inPopover;
- (bool)inFormSheet;

- (bool)willCaptureInputShortly;

- (void)acquireRotationLock;
- (void)releaseRotationLock;

- (void)localizationUpdated;

- (UIEdgeInsets)calculatedSafeAreaInset;
+ (UIEdgeInsets)safeAreaInsetForOrientation:(UIInterfaceOrientation)orientation hasOnScreenNavigation:(bool)hasOnScreenNavigation;
+ (int)preferredAnimationCurve;

- (CGSize)referenceViewSizeForOrientation:(UIInterfaceOrientation)orientation;
- (UIInterfaceOrientation)currentInterfaceOrientation;

- (void)layoutControllerForSize:(CGSize)size duration:(NSTimeInterval)duration;

- (void)presentWithContext:(UIViewController *(^)(id<LegacyComponentsContext>))generator;

@end

@protocol TGDestructableViewController <NSObject>

- (void)cleanupBeforeDestruction;
- (void)cleanupAfterDestruction;

@optional

- (void)contentControllerWillBeDismissed;

@end

@interface TGAutorotationLock : NSObject

@property (nonatomic) int lockId;

@end

