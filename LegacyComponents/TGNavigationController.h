#import <UIKit/UIKit.h>

typedef enum {
    TGNavigationControllerPresentationStyleDefault = 0,
    TGNavigationControllerPresentationStyleRootInPopover = 1,
    TGNavigationControllerPresentationStyleChildInPopover = 2,
    TGNavigationControllerPresentationStyleInFormSheet = 3
} TGNavigationControllerPresentationStyle;

@interface TGNavigationController : UINavigationController

@property (nonatomic) bool restrictLandscape;
@property (nonatomic) bool disableInteractiveKeyboardTransition;

@property (nonatomic) bool isInPopTransition;
@property (nonatomic) bool isInControllerTransition;

@property (nonatomic) TGNavigationControllerPresentationStyle presentationStyle;
@property (nonatomic) bool detachFromPresentingControllerInCompactMode;

@property (nonatomic, weak) UIPopoverController *parentPopoverController;

@property (nonatomic) bool displayPlayer;
@property (nonatomic) bool minimizePlayer;

@property (nonatomic) bool showCallStatusBar;

@property (nonatomic) CGFloat currentAdditionalNavigationBarHeight;
@property (nonatomic) bool forceAdditionalNavigationBarHeight;

+ (TGNavigationController *)navigationControllerWithControllers:(NSArray *)controllers;
+ (TGNavigationController *)navigationControllerWithControllers:(NSArray *)controllers navigationBarClass:(Class)navigationBarClass;
+ (TGNavigationController *)navigationControllerWithRootController:(UIViewController *)controller;

+ (TGNavigationController *)makeWithRootController:(UIViewController *)controller;

- (void)setupNavigationBarForController:(UIViewController *)viewController animated:(bool)animated;

- (void)updateControllerLayout:(bool)animated;
- (void)updatePlayerOnControllers;

- (void)acquireRotationLock;
- (void)releaseRotationLock;

@end

@protocol TGNavigationControllerItem <NSObject>

@required

- (bool)shouldBeRemovedFromNavigationAfterHiding;

@optional

- (bool)shouldRemoveAllPreviousControllers;

@end

@protocol TGNavigationControllerTabsController <NSObject>

@end
