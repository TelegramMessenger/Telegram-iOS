#import "TGNavigationController.h"

#import <UIKit/UIGestureRecognizerSubclass.h>

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"
#import "TGStringUtils.h"
#import "Freedom.h"

#import "TGNavigationBar.h"
#import "TGViewController.h"

#import "TGHacks.h"

#import <QuickLook/QuickLook.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>

@interface TGDelegateProxy<__covariant DelegateType:NSObject<NSObject> *> : NSObject

@property(nonatomic, weak) DelegateType delegate;

@end

@interface TGNavigationPanGestureRecognizer : UIPanGestureRecognizer

@property (nonatomic, readonly) CGFloat _edgeRegionSize;

@end

@interface TGNavigationGestureDelegateProxy : TGDelegateProxy<UIGestureRecognizerDelegate>

@property (nonatomic, copy) bool (^shouldBegin)(TGNavigationPanGestureRecognizer *);
@property (nonatomic, copy) bool (^shouldRecognizeWith)(TGNavigationPanGestureRecognizer *, UIGestureRecognizer *);

@end

@interface TGNavigationPercentTransition : UIPercentDrivenInteractiveTransition

@end

@interface TGNavigationController () <UINavigationControllerDelegate, UIGestureRecognizerDelegate, UINavigationBarDelegate>
{
    UITapGestureRecognizer *_dimmingTapRecognizer;
    CGSize _preferredContentSize;
    
    id<SDisposable> _playerStatusDisposable;
    CGFloat _currentAdditionalStatusBarHeight;
    
    TGNavigationGestureDelegateProxy *_gestureDelegate;
    bool _animatingControllerPush;
    bool _fixNextInteractiveTransition;
    
    id _enterBackgroundObserver;
    id _becomeActiveObserver;
    
    bool _didFirstLayout;
}

@property (nonatomic) bool wasShowingNavigationBar;

@property (nonatomic, strong) TGAutorotationLock *autorotationLock;

@end

@implementation TGNavigationController

+ (TGNavigationController *)navigationControllerWithRootController:(UIViewController *)controller
{
    return [self navigationControllerWithControllers:[NSArray arrayWithObject:controller]];
}

+ (TGNavigationController *)navigationControllerWithControllers:(NSArray *)controllers
{
    return [self navigationControllerWithControllers:controllers navigationBarClass:[TGNavigationBar class]];
}

+ (TGNavigationController *)navigationControllerWithControllers:(NSArray *)controllers navigationBarClass:(Class)navigationBarClass
{
    return [self navigationControllerWithControllers:controllers navigationBarClass:navigationBarClass inhibitPresentation:false];
}

+ (TGNavigationController *)navigationControllerWithControllers:(NSArray *)controllers navigationBarClass:(Class)navigationBarClass inhibitPresentation:(bool)inhibitPresentation
{
    TGNavigationController *navigationController = [[TGNavigationController alloc] initWithNavigationBarClass:navigationBarClass toolbarClass:[UIToolbar class]];
    
    if (!inhibitPresentation && [[LegacyComponentsGlobals provider] respondsToSelector:@selector(navigationBarPallete)])
        [((TGNavigationBar *)navigationController.navigationBar) setPallete:[[LegacyComponentsGlobals provider] navigationBarPallete]];
    
    bool first = true;
    for (id controller in controllers) {
        if ([controller isKindOfClass:[TGViewController class]]) {
            [(TGViewController *)controller setIsFirstInStack:first];
        }
        first = false;
    }
    [navigationController setViewControllers:controllers];
    
    ((TGNavigationBar *)navigationController.navigationBar).navigationController = navigationController;
    
    return navigationController;
}

+ (TGNavigationController *)makeWithRootController:(UIViewController *)controller {
    return [self navigationControllerWithControllers:[NSArray arrayWithObject:controller]];
}

- (instancetype)initWithNavigationBarClass:(Class)navigationBarClass toolbarClass:(Class)toolbarClass
{
    self = [super initWithNavigationBarClass:navigationBarClass toolbarClass:toolbarClass];
    if (self != nil)
    {
        
    }
    return self;
}

- (void)dealloc
{
    [_playerStatusDisposable dispose];
    self.delegate = nil;
    [_dimmingTapRecognizer.view removeGestureRecognizer:_dimmingTapRecognizer];
    
    if (_becomeActiveObserver != nil)
        [[NSNotificationCenter defaultCenter] removeObserver:_becomeActiveObserver];
}

- (void)loadView
{
    [super loadView];
    
    if (@available(iOS 11.0, *)) {
        self.navigationBar.prefersLargeTitles = false;
    }
    
    if (iosMajorVersion() >= 8 && !TGIsRTL())
    {
        object_setClass(self.interactivePopGestureRecognizer, [TGNavigationPanGestureRecognizer class]);
        self.interactivePopGestureRecognizer.delaysTouchesBegan = false;
        self.interactivePopGestureRecognizer.delaysTouchesEnded = true;
        self.interactivePopGestureRecognizer.cancelsTouchesInView = true;
        
        _gestureDelegate = [[TGNavigationGestureDelegateProxy alloc] init];
        _gestureDelegate.delegate = self.interactivePopGestureRecognizer.delegate;
        
        __weak TGNavigationController *weakSelf = self;
        _gestureDelegate.shouldBegin = ^bool(TGNavigationPanGestureRecognizer *gestureRecognizer)
        {
            __strong TGNavigationController *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                bool shouldBegin = [strongSelf _gestureRecognizerShouldBegin:gestureRecognizer];
                if (shouldBegin)
                {
                    CGPoint location = [gestureRecognizer locationInView:nil];
                    CGPoint velocity = [gestureRecognizer velocityInView:nil];
                    if (strongSelf->_fixNextInteractiveTransition)
                    {
                        bool fixableLocation = (!TGIsRTL() && location.x > 44.0f) || (TGIsRTL() && location.x < gestureRecognizer.view.frame.size.width - 44.0f);
                        bool fixableVelovity = TGIsRTL() ? velocity.x <= -150 : velocity.x >= 150;

                        if (fixableLocation && fixableVelovity)
                        {
                            [strongSelf popViewControllerAnimated:true];
                            shouldBegin = false;
                        }
                    }
                    strongSelf->_fixNextInteractiveTransition = false;
                }
                return shouldBegin;
            }
            return false;
        };
        _gestureDelegate.shouldRecognizeWith = ^bool(TGNavigationPanGestureRecognizer *gestureRecognizer, UIGestureRecognizer *otherGestureRecognizer)
        {
            __strong TGNavigationController *strongSelf = weakSelf;
            if (strongSelf != nil)
                return [strongSelf _gestureRecognizer:gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:otherGestureRecognizer];
            return false;
        };
        self.interactivePopGestureRecognizer.delegate = _gestureDelegate;
        
        if ([TGViewController hasTallScreen] && _becomeActiveObserver == nil && _enterBackgroundObserver == nil)
        {
            __weak TGNavigationController *weakSelf = self;
            _enterBackgroundObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:nil usingBlock:^(__unused NSNotification * _Nonnull note)
            {
                __strong TGNavigationController *strongSelf = weakSelf;
                if (strongSelf != nil) {
                    [[NSNotificationCenter defaultCenter] removeObserver:strongSelf->_enterBackgroundObserver];
                    strongSelf->_enterBackgroundObserver = nil;
                    
                    if (strongSelf->_becomeActiveObserver == nil)
                    {
                        strongSelf->_becomeActiveObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
                            __strong TGNavigationController *strongSelf = weakSelf;
                            if (strongSelf != nil) {
                                if ([TGViewController hasTallScreen])
                                    strongSelf->_fixNextInteractiveTransition = true;
                            }
                        }];
                    }
                }
            }];
        }
    }
}

- (bool)_gestureRecognizerShouldBegin:(UIPanGestureRecognizer *)gestureRecognizer
{
    if (_animatingControllerPush)
        return false;
        
    CGPoint velocity = [gestureRecognizer velocityInView:gestureRecognizer.view];
    if (fabs(velocity.y) > fabs(velocity.x))
        return false;
    
    if ((!TGIsRTL() && velocity.x < FLT_EPSILON) || (TGIsRTL() && velocity.x > FLT_EPSILON))
        return false;
    
    CGPoint location = [gestureRecognizer locationInView:gestureRecognizer.view];
    if (location.y < CGRectGetMaxY([self.navigationBar convertRect:self.navigationBar.bounds toView:gestureRecognizer.view]))
        return false;
    
    UIView *view = [gestureRecognizer.view hitTest:location withEvent:nil];
    if (view.tag == 0xdead || ([view isKindOfClass:[UIControl class]] && ![view isKindOfClass:[UIButton class]]))
        return false;
    
    return self.viewControllers.count > 1;
}

- (bool)_gestureRecognizer:(UIPanGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if (_animatingControllerPush)
        return false;
    
    CGPoint location = [gestureRecognizer locationInView:gestureRecognizer.view];
    
    if (self.viewControllers.count == 1)
        return false;
    
    bool (^isEdgePan)(void) = ^bool
    {
        if ((!TGIsRTL() && location.x < 44.0f) || (TGIsRTL() && location.x > gestureRecognizer.view.frame.size.width - 44.0f))
        {
            CGPoint velocity = [gestureRecognizer velocityInView:gestureRecognizer.view];
            if (fabs(velocity.x) >= fabs(velocity.y))
            {
                otherGestureRecognizer.enabled = false;
                otherGestureRecognizer.enabled = true;
                return true;
            }
        }
        return false;
    };
    
    if (otherGestureRecognizer.view.tag == 0xdead)
    {
        return false;
    }
    else if ([otherGestureRecognizer.view isKindOfClass:[UIScrollView class]])
    {
        UIScrollView *scrollView = (UIScrollView *)otherGestureRecognizer.view;
        bool viewIsHorizontalScrollView = !TGIsRTL() && scrollView.contentSize.height > FLT_EPSILON && scrollView.contentSize.width > scrollView.contentSize.height && fabs(scrollView.contentOffset.x + scrollView.contentInset.left) < FLT_EPSILON && scrollView.tag != 0xbeef;
        bool viewIsDeceleratingScrollView = scrollView.contentSize.height > scrollView.contentSize.width && scrollView.isDecelerating;
        if (viewIsHorizontalScrollView || viewIsDeceleratingScrollView)
        {
            if (viewIsHorizontalScrollView)
            {
                CGPoint velocity = [gestureRecognizer velocityInView:gestureRecognizer.view];
                if ((!TGIsRTL() && velocity.x < FLT_EPSILON) || (TGIsRTL() && velocity.x > FLT_EPSILON))
                    return false;
                
                otherGestureRecognizer.enabled = false;
                otherGestureRecognizer.enabled = true;
            }
            return true;
        }
        else
        {
            if (isEdgePan())
                return true;
        }
    }
    else
    {
        if (isEdgePan())
            return true;
    }
    return false;
}

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    _animatingControllerPush = false;
}

- (void)setDisplayPlayer:(bool)displayPlayer
{
    _displayPlayer = displayPlayer;
    
    if (_displayPlayer && [self.navigationBar isKindOfClass:[TGNavigationBar class]])
    {
        __weak TGNavigationController *weakSelf = self;
        [_playerStatusDisposable dispose];
        _playerStatusDisposable = [[[TGNavigationBar musicPlayerProvider].musicPlayerIsActive deliverOn:[SQueue mainQueue]] startWithNext:^(NSNumber *nIsActive)
        {
            __strong TGNavigationController *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                bool isActive = [nIsActive boolValue];
                
                if (isActive && strongSelf->_currentAdditionalNavigationBarHeight < FLT_EPSILON)
                {
                    strongSelf->_minimizePlayer = false;
                    [(TGNavigationBar *)self.navigationBar setMinimizedMusicPlayer:_minimizePlayer];
                }
                
                CGFloat currentAdditionalNavigationBarHeight = !isActive ? 0.0f : (strongSelf->_minimizePlayer ? 2.0f : 37.0f);
                if (ABS(strongSelf->_currentAdditionalNavigationBarHeight - currentAdditionalNavigationBarHeight) > FLT_EPSILON)
                {
                    strongSelf->_currentAdditionalNavigationBarHeight = currentAdditionalNavigationBarHeight;
                    [((TGNavigationBar *)strongSelf.navigationBar) showMusicPlayerView:isActive animation:^
                    {
                        [strongSelf updatePlayerOnControllers];
                    }];
                }
            }
        }];
    }
    else
    {
        [_playerStatusDisposable dispose];
    }
}

- (void)setMinimizePlayer:(bool)minimizePlayer
{
    if (_minimizePlayer != minimizePlayer)
    {
        _minimizePlayer = minimizePlayer;
        
        if (_currentAdditionalNavigationBarHeight > FLT_EPSILON)
            _currentAdditionalNavigationBarHeight = _minimizePlayer ? 2.0f : 37.0f;
        [(TGNavigationBar *)self.navigationBar setMinimizedMusicPlayer:_minimizePlayer];
        
        [UIView animateWithDuration:0.25 animations:^
        {
            [self updatePlayerOnControllers];
        }];
    }
}

- (void)setupStatusBarOnControllers:(NSArray *)controllers
{
    if ([[self navigationBar] isKindOfClass:[TGNavigationBar class]])
    {
        for (id maybeController in controllers)
        {
            if ([maybeController isKindOfClass:[TGViewController class]])
            {
                TGViewController *controller = maybeController;
                [controller setAdditionalStatusBarHeight:_currentAdditionalStatusBarHeight];
            }
            else if ([maybeController isKindOfClass:[UITabBarController class]] && [maybeController conformsToProtocol:@protocol(TGNavigationControllerTabsController)])
            {
                [self setupPlayerOnControllers:((UITabBarController *)maybeController).viewControllers];
            }
        }
    }
}

- (void)updateStatusBarOnControllers
{
    if ([[self navigationBar] isKindOfClass:[TGNavigationBar class]])
    {
        for (id maybeController in [self viewControllers])
        {
            if ([maybeController isKindOfClass:[TGViewController class]])
            {
                TGViewController *viewController = (TGViewController *)maybeController;
                [viewController setAdditionalStatusBarHeight:_currentAdditionalStatusBarHeight];
                [viewController setNeedsStatusBarAppearanceUpdate];
            }
            else if ([maybeController isKindOfClass:[UITabBarController class]] && [maybeController conformsToProtocol:@protocol(TGNavigationControllerTabsController)])
            {
                for (id controller in ((UITabBarController *)maybeController).viewControllers)
                {
                    if ([controller isKindOfClass:[TGViewController class]])
                    {
                        [((TGViewController *)controller) setAdditionalStatusBarHeight:_currentAdditionalStatusBarHeight];
                    }
                }
                if (iosMajorVersion() >= 7)
                    [((UIViewController *)maybeController) setNeedsStatusBarAppearanceUpdate];
            }
        }
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)dimmingViewTapped:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        [self.presentingViewController dismissViewControllerAnimated:true completion:nil];
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    CGSize screenSize = TGScreenSize();
    
    static Class containerClass = nil;
    
    if (freedomInitialized())
    {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            containerClass = freedomClass(0xf045e5dfU);
        });
    }
    
    for (UIView *view in self.view.subviews)
    {
        bool isContainerView = false;
        if (freedomInitialized())
            isContainerView = [view isKindOfClass:containerClass];
        else
            isContainerView = [NSStringFromClass(view.class) rangeOfString:@"TransitionView"].location != NSNotFound;
        
        if (isContainerView)
        {
            CGRect frame = view.frame;
            
            if (ABS(frame.size.width - screenSize.width) < FLT_EPSILON)
            {
                if (ABS(frame.size.height - screenSize.height + 20) < FLT_EPSILON)
                {
                    frame.origin.y = frame.size.height - screenSize.height;
                    frame.size.height = screenSize.height;
                }
                else if (frame.size.height > screenSize.height + FLT_EPSILON)
                {
                    frame.origin.y = 0;
                    frame.size.height = screenSize.height;
                }
            }
            else if (ABS(frame.size.width - screenSize.height) < FLT_EPSILON)
            {
                if (frame.size.height > screenSize.width + FLT_EPSILON)
                {
                    frame.origin.y = 0;
                    frame.size.height = screenSize.width;
                }
            }
            
            if (ABS(frame.size.height) < FLT_EPSILON)
            {
                frame.size.height = screenSize.height;
            }
            
            if (!CGRectEqualToRect(view.frame, frame))
                view.frame = frame;
            
            break;
        }
    }
    
    _didFirstLayout = true;
}

- (void)viewDidLoad
{   
    self.delegate = self;
    
    [super viewDidLoad];
}

- (void)updateControllerLayout:(bool)__unused animated
{
}

- (void)setupNavigationBarForController:(UIViewController *)viewController animated:(bool)animated
{
    UIBarStyle barStyle = UIBarStyleDefault;
    bool navigationBarShouldBeHidden = false;
    UIStatusBarStyle statusBarStyle = UIStatusBarStyleLightContent;
    bool statusBarShouldBeHidden = false;
    
    if ([viewController conformsToProtocol:@protocol(TGViewControllerNavigationBarAppearance)])
    {
        id<TGViewControllerNavigationBarAppearance> appearance = (id<TGViewControllerNavigationBarAppearance>)viewController;
        
        barStyle = [appearance requiredNavigationBarStyle];
        navigationBarShouldBeHidden = [appearance navigationBarShouldBeHidden];
        if ([appearance respondsToSelector:@selector(preferredStatusBarStyle)])
            statusBarStyle = [appearance preferredStatusBarStyle];
        if ([appearance respondsToSelector:@selector(statusBarShouldBeHidden)])
            statusBarShouldBeHidden = [appearance statusBarShouldBeHidden];
    }
    
    if (navigationBarShouldBeHidden != self.navigationBarHidden)
    {
        [self setNavigationBarHidden:navigationBarShouldBeHidden animated:animated];
    }
    
    if ([[LegacyComponentsGlobals provider] isStatusBarHidden] != statusBarShouldBeHidden)
        [[LegacyComponentsGlobals provider] setStatusBarHidden:statusBarShouldBeHidden withAnimation:animated ? UIStatusBarAnimationFade : UIStatusBarAnimationNone];
    if ([[LegacyComponentsGlobals provider] statusBarStyle] != statusBarStyle)
        [[LegacyComponentsGlobals provider] setStatusBarStyle:statusBarStyle animated:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (_restrictLandscape)
        return interfaceOrientation == UIInterfaceOrientationPortrait;
    
    if (self.topViewController != nil)
        return [self.topViewController shouldAutorotateToInterfaceOrientation:interfaceOrientation];
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (BOOL)shouldAutorotate
{
    if (_restrictLandscape)
        return false;
    
    if (self.topViewController != nil)
    {
        if ([self.topViewController respondsToSelector:@selector(shouldAutorotate)])
        {
            if (![self.topViewController shouldAutorotate])
                return false;
        }
    }
    
    bool result = [super shouldAutorotate];
    if (!result)
        return false;
    
    if ([self respondsToSelector:@selector(interactivePopGestureRecognizer)])
    {
        UIGestureRecognizerState state = self.interactivePopGestureRecognizer.state;
        if (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged)
            return false;
    }
    
    return true;
}

- (void)acquireRotationLock
{
    if (_autorotationLock == nil)
        _autorotationLock = [[TGAutorotationLock alloc] init];
}

- (void)releaseRotationLock
{
    _autorotationLock = nil;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    if (_restrictLandscape)
        return UIInterfaceOrientationMaskPortrait;
    
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)setNavigationBarHidden:(BOOL)hidden animated:(BOOL)animated
{
    if (!hidden)
        self.navigationBar.alpha = 1.0f;
    
    [(TGNavigationBar *)self.navigationBar setHiddenState:hidden animated:animated];
    
    [super setNavigationBarHidden:hidden animated:animated];
}

- (void)setupPlayerOnControllers:(NSArray *)controllers
{
    if ((_displayPlayer || _forceAdditionalNavigationBarHeight) && [[self navigationBar] isKindOfClass:[TGNavigationBar class]])
    {
        for (id maybeController in controllers)
        {
            if ([maybeController isKindOfClass:[TGViewController class]])
            {
                TGViewController *controller = maybeController;
                [controller setAdditionalNavigationBarHeight:_currentAdditionalNavigationBarHeight];
            }
            else if (_displayPlayer && [maybeController isKindOfClass:[UITabBarController class]] && [maybeController conformsToProtocol:@protocol(TGNavigationControllerTabsController)])
            {
                [self setupPlayerOnControllers:((UITabBarController *)maybeController).viewControllers];
            }
        }
    }
}

- (void)updatePlayerOnControllers
{
    if ((_displayPlayer || _forceAdditionalNavigationBarHeight) && [[self navigationBar] isKindOfClass:[TGNavigationBar class]])
    {
        for (id maybeController in [self viewControllers])
        {
            if ([maybeController isKindOfClass:[TGViewController class]])
            {
                [((TGViewController *)maybeController) setAdditionalNavigationBarHeight:_currentAdditionalNavigationBarHeight];
            }
            else if (_displayPlayer && [maybeController isKindOfClass:[UITabBarController class]] && [maybeController conformsToProtocol:@protocol(TGNavigationControllerTabsController)])
            {
                for (id controller in ((UITabBarController *)maybeController).viewControllers)
                {
                    if ([controller isKindOfClass:[TGViewController class]])
                    {
                        [((TGViewController *)controller) setAdditionalNavigationBarHeight:_currentAdditionalNavigationBarHeight];
                    }
                }
            }
        }
    }
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    if (_animatingControllerPush)
        return;
    
    _fixNextInteractiveTransition = false;
    
    if (self.viewControllers.count == 0) {
        if ([viewController isKindOfClass:[TGViewController class]]) {
            [(TGViewController *)viewController setIsFirstInStack:true];
        } else {
            [(TGViewController *)viewController setIsFirstInStack:false];
        }
    }
    _isInControllerTransition = true;
    if (viewController != nil) {
        [self setupPlayerOnControllers:@[viewController]];
        [self setupStatusBarOnControllers:@[viewController]];
    }
    [super pushViewController:viewController animated:animated];
    _isInControllerTransition = false;
    
    _animatingControllerPush = animated;
    if (_animatingControllerPush)
    {
        TGDispatchAfter(0.3, dispatch_get_main_queue(), ^
        {
            _animatingControllerPush = false;
        });
    }
    
    if (iosMajorVersion() >= 8 && [viewController isKindOfClass:[QLPreviewController class]])
        object_setClass(self.interactivePopGestureRecognizer, [UIScreenEdgePanGestureRecognizer class]);
}

- (void)setViewControllers:(NSArray *)viewControllers animated:(BOOL)animated
{
    bool first = true;
    for (id controller in viewControllers) {
        if ([controller isKindOfClass:[TGViewController class]]) {
            [(TGViewController *)controller setIsFirstInStack:first];
        }
        first = false;
    }
    
    _isInControllerTransition = true;
    [self setupPlayerOnControllers:viewControllers];
    [self setupStatusBarOnControllers:viewControllers];
    [super setViewControllers:viewControllers animated:animated];
    _isInControllerTransition = false;
    
    _animatingControllerPush = animated;
    if (_animatingControllerPush)
    {
        TGDispatchAfter(0.3, dispatch_get_main_queue(), ^
        {
            _animatingControllerPush = false;
        });
    }
}

- (BOOL)navigationBar:(UINavigationBar *)navigationBar shouldPopItem:(UINavigationItem *)item
{
    if (self.viewControllers.count < navigationBar.items.count)
        return true;
    
    bool shouldPop = true;
    if (self.shouldPopController != nil) {
        shouldPop = self.shouldPopController(self.topViewController);
    }
    
    if (shouldPop)
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self popViewControllerAnimated:YES];
        });
    } else
    {
        for (UIView *subview in [navigationBar subviews])
        {
            if (0.< subview.alpha && subview.alpha < 1.)
            {
                [UIView animateWithDuration:.25 animations:^
                {
                    subview.alpha = 1.;
                }];
            }
        }
    }
    
    return false;
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated
{
    _fixNextInteractiveTransition = false;
    
    if (animated)
    {
        static ptrdiff_t controllerOffset = -1;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            controllerOffset = freedomIvarOffset([UINavigationController class], 0xb281e8fU);
        });

        if (controllerOffset != -1)
        {
            __unsafe_unretained NSObject **controller = (__unsafe_unretained NSObject **)(void *)(((uint8_t *)(__bridge void *)self) + controllerOffset);
            if (*controller != nil)
            {
                static Class decoratedClass = Nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^
                {
                   decoratedClass = freedomMakeClass([*controller class], [TGNavigationPercentTransition class]);
                });

                if (decoratedClass != Nil && ![*controller isKindOfClass:decoratedClass])
                    object_setClass(*controller, decoratedClass);
            }
        }
    }
    
    _isInPopTransition = true;
    UIViewController *result = [super popViewControllerAnimated:animated];
    _isInPopTransition = false;
    
    if (iosMajorVersion() >= 8 && !TGIsRTL() && [self.interactivePopGestureRecognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]])
        object_setClass(self.interactivePopGestureRecognizer, [TGNavigationPanGestureRecognizer class]);
    
    return result;
}

- (NSArray *)popToRootViewControllerAnimated:(BOOL)animated
{
    for (NSUInteger i = self.viewControllers.count - 1; i >= 1; i--)
    {
        UIViewController *viewController = self.viewControllers[i];
        if (viewController.presentedViewController != nil)
            [viewController dismissViewControllerAnimated:false completion:nil];
    }
    
    return [super popToRootViewControllerAnimated:animated];
}

TGNavigationController *findNavigationControllerInWindow(UIWindow *window)
{
    if ([window.rootViewController isKindOfClass:[TGNavigationController class]])
        return (TGNavigationController *)window.rootViewController;
    
    return nil;
}

TGNavigationController *findNavigationController()
{
    NSArray *windows = [[LegacyComponentsGlobals provider] applicationWindows];
    for (int i = (int)windows.count - 1; i >= 0; i--)
    {
        TGNavigationController *result = findNavigationControllerInWindow(windows[i]);
        if (result != nil)
            return result;
    }
    
    return nil;
}

- (CGFloat)myNominalTransitionAnimationDuration
{
    return 0.2f;
}

- (void)setPreferredContentSize:(CGSize)preferredContentSize
{
    _preferredContentSize = preferredContentSize;
}

- (CGSize)preferredContentSize
{
    return _preferredContentSize;
}

- (BOOL)prefersStatusBarHidden
{
    if (iosMajorVersion() >= 7)
        return [super prefersStatusBarHidden];
    
    return false;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return self.topViewController.preferredStatusBarStyle;
}

- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion {
    if (_customDismissSelf) {
        _customDismissSelf();
        if (completion) {
            completion();
        }
    } else {
        [super dismissViewControllerAnimated:flag completion:completion];
    }
}

@end

@implementation TGNavigationPercentTransition

- (void)updateInteractiveTransition:(CGFloat)percentComplete
{
    [super updateInteractiveTransition:percentComplete];
}

- (void)finishInteractiveTransition
{
    [super finishInteractiveTransition];
}

- (void)cancelInteractiveTransition
{
    [super cancelInteractiveTransition];
}

@end

@implementation TGDelegateProxy

@end


@implementation TGNavigationPanGestureRecognizer

- (UIRectEdge)edges {
    return UIRectEdgeLeft;
}

- (void)_setEdgeRegionSize:(CGFloat)edgeRegionSize
{
    __edgeRegionSize = edgeRegionSize;
}

- (id)recognizerTouchesToIgnoreForEvent:(id)event
{
    return nil;
}

@end


@implementation TGNavigationGestureDelegateProxy

- (BOOL)gestureRecognizerShouldBegin:(TGNavigationPanGestureRecognizer *)gestureRecognizer
{
    bool result = [self.delegate respondsToSelector:@selector(gestureRecognizerShouldBegin:)] && [self.delegate gestureRecognizerShouldBegin:gestureRecognizer];
    if (result && self.shouldBegin != nil)
        result = self.shouldBegin(gestureRecognizer);
    return result;
}

- (BOOL)gestureRecognizer:(TGNavigationPanGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    bool result = [self.delegate respondsToSelector:@selector(gestureRecognizer:shouldRecognizeSimultaneouslyWithGestureRecognizer:)] && [self.delegate gestureRecognizer:gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:otherGestureRecognizer];
    if (!result && self.shouldRecognizeWith != nil)
        result = self.shouldRecognizeWith(gestureRecognizer, otherGestureRecognizer);
    return result;
}

@end
