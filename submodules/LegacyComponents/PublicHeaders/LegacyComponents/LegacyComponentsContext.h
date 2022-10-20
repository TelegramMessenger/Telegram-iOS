#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class TGKeyCommandController;
@class SSignal;
@class TGOverlayControllerWindow;

@class TGNavigationBarPallete;
@class TGMenuSheetPallete;
@class TGMediaAssetsPallete;
@class TGImageBorderPallete;
@class TGCheckButtonPallete;

typedef enum {
    LegacyComponentsActionSheetActionTypeGeneric,
    LegacyComponentsActionSheetActionTypeDestructive,
    LegacyComponentsActionSheetActionTypeCancel
} LegacyComponentsActionSheetActionType;

@interface LegacyComponentsActionSheetAction : NSObject

@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, strong, readonly) NSString *action;
@property (nonatomic, readonly) LegacyComponentsActionSheetActionType type;

- (instancetype)initWithTitle:(NSString *)title action:(NSString *)action;
- (instancetype)initWithTitle:(NSString *)title action:(NSString *)action type:(LegacyComponentsActionSheetActionType)type;

@end


@protocol LegacyComponentsContext;

@protocol LegacyComponentsOverlayWindowManager <NSObject>

- (id<LegacyComponentsContext>)context;
- (void)bindController:(UIViewController *)controller;
- (bool)managesWindow;
- (void)setHidden:(bool)hidden window:(UIWindow *)window;

@end

@protocol LegacyComponentsContext <NSObject>

- (UIEdgeInsets)safeAreaInset;
- (CGRect)fullscreenBounds;
- (TGKeyCommandController *)keyCommandController;
- (CGRect)statusBarFrame;
- (bool)isStatusBarHidden;
- (void)setStatusBarHidden:(BOOL)hidden withAnimation:(UIStatusBarAnimation)animation;
- (void)forceSetStatusBarHidden:(BOOL)hidden withAnimation:(UIStatusBarAnimation)animation;
- (UIStatusBarStyle)statusBarStyle;
- (void)setStatusBarStyle:(UIStatusBarStyle)statusBarStyle animated:(BOOL)animated;
- (void)forceStatusBarAppearanceUpdate;
- (bool)prefersLightStatusBar;

- (TGNavigationBarPallete *)navigationBarPallete;
- (TGMenuSheetPallete *)menuSheetPallete;
- (TGMenuSheetPallete *)darkMenuSheetPallete;
- (TGMediaAssetsPallete *)mediaAssetsPallete;
- (TGCheckButtonPallete *)checkButtonPallete;

@required

- (CGFloat)applicationStatusBarAlpha;
- (void)setApplicationStatusBarAlpha:(CGFloat)alpha;

- (void)animateApplicationStatusBarAppearance:(int)statusBarAnimation delay:(NSTimeInterval)delay duration:(NSTimeInterval)duration completion:(void (^)())completion;
- (void)animateApplicationStatusBarAppearance:(int)statusBarAnimation duration:(NSTimeInterval)duration completion:(void (^)())completion;

- (void)animateApplicationStatusBarStyleTransitionWithDuration:(NSTimeInterval)duration;

- (bool)rootCallStatusBarHidden;

- (bool)currentlyInSplitView;

- (UIUserInterfaceSizeClass)currentSizeClass;
- (UIUserInterfaceSizeClass)currentHorizontalSizeClass;
- (UIUserInterfaceSizeClass)currentVerticalSizeClass;
- (SSignal *)sizeClassSignal;

- (bool)canOpenURL:(NSURL *)url;
- (void)openURL:(NSURL *)url;

- (NSDictionary *)serverMediaDataForAssetUrl:(NSString *)url;

- (void)presentActionSheet:(NSArray<LegacyComponentsActionSheetAction *> *)actions view:(UIView *)view completion:(void (^)(LegacyComponentsActionSheetAction *))completion;
- (void)presentActionSheet:(NSArray<LegacyComponentsActionSheetAction *> *)actions view:(UIView *)view sourceRect:(CGRect (^)(void))sourceRect completion:(void (^)(LegacyComponentsActionSheetAction *))completion ;

- (id<LegacyComponentsOverlayWindowManager>)makeOverlayWindowManager;

@end
