#import "TGOverlayControllerWindow.h"

#import "LegacyComponentsInternal.h"
#import "TGHacks.h"

#import "TGViewController.h"
#import "TGOverlayController.h"

@implementation TGOverlayWindowViewController

- (UIViewController *)statusBarAppearanceSourceController
{
    UIViewController *rootController = [[LegacyComponentsGlobals provider] applicationWindows].firstObject.rootViewController;
    UIViewController *topViewController = nil;
    if ([rootController respondsToSelector:@selector(viewControllers)]) {
        topViewController = [(UINavigationController *)rootController viewControllers].lastObject;
    }
    
    if ([topViewController isKindOfClass:[UITabBarController class]])
        topViewController = [(UITabBarController *)topViewController selectedViewController];
    if ([topViewController isKindOfClass:[TGViewController class]])
    {
        TGViewController *concreteTopViewController = (TGViewController *)topViewController;
        if (concreteTopViewController.presentedViewController != nil)
        {
            topViewController = concreteTopViewController.presentedViewController;
        }
        else if (concreteTopViewController.associatedWindowStack.count != 0)
        {
            for (UIWindow *window in concreteTopViewController.associatedWindowStack.reverseObjectEnumerator)
            {
                if (window.rootViewController != nil && window.rootViewController != self)
                {
                    topViewController = window.rootViewController;
                    break;
                }
            }
        }
    }
    
    return topViewController;
}

- (UIViewController *)autorotationSourceController
{
    UIViewController *rootController = [[LegacyComponentsGlobals provider] applicationWindows].firstObject.rootViewController;
    UIViewController *topViewController = nil;
    if ([rootController respondsToSelector:@selector(viewControllers)]) {
        topViewController = [(UINavigationController *)rootController viewControllers].lastObject;
    }
    
    if ([topViewController isKindOfClass:[UITabBarController class]])
        topViewController = [(UITabBarController *)topViewController selectedViewController];
    
    return topViewController;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    UIStatusBarStyle style = [[self statusBarAppearanceSourceController] preferredStatusBarStyle];
    return style;
}

- (BOOL)prefersStatusBarHidden
{
    bool value = self.forceStatusBarHidden || [[self statusBarAppearanceSourceController] prefersStatusBarHidden];
    return value;
}

- (BOOL)shouldAutorotate
{    
    UIViewController *rootController = [[LegacyComponentsGlobals provider] applicationWindows].firstObject.rootViewController;
    
    if (rootController.presentedViewController != nil)
        return [rootController.presentedViewController shouldAutorotate];
    
    if ([self autorotationSourceController] != nil)
        return [[self autorotationSourceController] shouldAutorotate];
    
    return true;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    [self.view.window.layer removeAnimationForKey:@"backgroundColor"];
    [CATransaction begin];
    [CATransaction setDisableActions:true];
    self.view.window.layer.backgroundColor = [UIColor clearColor].CGColor;
    [CATransaction commit];
    
    for (UIView *view in self.view.window.subviews)
    {
        if (view != self.view)
        {
            [view removeFromSuperview];
            break;
        }
    }
}

- (void)loadView
{
    [super loadView];
    
    self.view.userInteractionEnabled = false;
    self.view.opaque = false;
    self.view.backgroundColor = [UIColor clearColor];
}

@end


@interface TGOverlayControllerWindow ()
{
    __weak TGViewController *_parentController;
    id<LegacyComponentsOverlayWindowManager> _manager;
    bool _managedIsHidden;
    TGOverlayController *_contentController;
}

@end

@implementation TGOverlayControllerWindow

- (instancetype)initWithManager:(id<LegacyComponentsOverlayWindowManager>)manager parentController:(TGViewController *)parentController contentController:(TGOverlayController *)contentController
{
    return [self initWithManager:manager parentController:parentController contentController:contentController keepKeyboard:false];
}

- (instancetype)initWithManager:(id<LegacyComponentsOverlayWindowManager>)manager parentController:(TGViewController *)parentController contentController:(TGOverlayController *)contentController keepKeyboard:(bool)keepKeyboard
{
    assert(manager != nil);
    
    if (self != nil) {
        _keepKeyboard = keepKeyboard;
        _manager = manager;
        _managedIsHidden = true;
    }
    
    self = [super initWithFrame:[[_manager context] fullscreenBounds]];
    if (self != nil)
    {
        self.frame = [[_manager context] fullscreenBounds];
        self.windowLevel = UIWindowLevelStatusBar - 0.001f;
        
        _parentController = parentController;
        [parentController.associatedWindowStack addObject:self];
        
        if ([_manager managesWindow]) {
            _contentController = contentController;
            __weak TGOverlayControllerWindow *weakSelf = self;
            __weak TGViewController *weakParentController = parentController;
            contentController.customDismissBlock = ^{
                __strong TGOverlayControllerWindow *strongSelf = weakSelf;
                __strong TGViewController *strongParentController = weakParentController;
                [strongParentController.associatedWindowStack removeObject:strongSelf];
                [manager setHidden:true window:strongSelf];
            };
            [_manager bindController:contentController];
        } else {
            contentController.overlayWindow = self;
            self.rootViewController = contentController;
        }
    }
    return self;
}

- (void)dealloc
{
    _manager = nil;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    return [super hitTest:point withEvent:event];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    if (iosMajorVersion() < 8 && !self.hidden)
        return true;
    
    return [super pointInside:point withEvent:event];
}

- (void)dismiss
{
    TGViewController *parentController = _parentController;
    [parentController.associatedWindowStack removeObject:self];
    [self.rootViewController viewWillDisappear:false];
    self.hidden = true;
    [self.rootViewController viewDidDisappear:false];
    self.rootViewController = nil;
}

- (BOOL)isHidden {
    if ([_manager managesWindow]) {
        return _managedIsHidden;
    } else {
        return [super isHidden];
    }
}

- (void)setHidden:(BOOL)hidden {
    if ([_manager managesWindow]) {
        if (![super isHidden]) {
            [super setHidden:true];
        }
        
        if (_managedIsHidden != hidden) {
            _managedIsHidden = hidden;
            [_manager setHidden:hidden window:self];
        }
    } else {
        [super setHidden:hidden];
        
        if (!hidden && !_keepKeyboard) {
            [[[LegacyComponentsGlobals provider] applicationWindows].firstObject endEditing:true];
        }
    }
}

@end
