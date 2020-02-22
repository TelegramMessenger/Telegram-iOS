#import "TGItemPreviewController.h"

#import "LegacyComponentsInternal.h"
#import "TGViewController.h"

#import "TGItemPreviewView.h"

#import "TGOverlayControllerWindow.h"

@interface TGItemPreviewController ()
{
    bool _autorotationWasEnabled;
    id<LegacyComponentsContext> _context;
}
@end

@implementation TGItemPreviewController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context parentController:(TGViewController *)parentController previewView:(TGItemPreviewView *)previewView
{
    self = [self initWithContext:context];
    if (self != nil)
    {
        _context = context;
        _previewView = previewView;
        _previewView.safeAreaInset = [TGViewController safeAreaInsetForOrientation:[LegacyComponentsGlobals provider].applicationStatusBarOrientation hasOnScreenNavigation:false];
        
        TGOverlayControllerWindow *window = [[TGOverlayControllerWindow alloc] initWithManager:[context makeOverlayWindowManager] parentController:parentController contentController:self keepKeyboard:true];
        window.windowLevel = UIWindowLevelStatusBar;
        window.tag = 0xbeef;
        window.userInteractionEnabled = previewView.userInteractionEnabled;
        window.hidden = false;

        __weak TGItemPreviewController *weakSelf = self;
        _previewView.onDismiss = ^
        {
            __strong TGItemPreviewController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf dismissImmediately];
        };
        
        _previewView.willDismiss = ^{
            __strong TGItemPreviewController *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf.onDismiss != nil)
            {
                void (^onDismiss)(void) = [strongSelf.onDismiss copy];
                strongSelf.onDismiss = nil;
                onDismiss();
            }
        };
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLayoutSubviews
{
    self.view.frame = [_context fullscreenBounds];
}

- (void)applicationDidBecomeActive:(NSNotification *)__unused notification
{
    [self.view.window makeKeyAndVisible];
}

- (CGPoint (^)(id))sourcePointForItem
{
    return _previewView.sourcePointForItem;
}

- (void)setSourcePointForItem:(CGPoint (^)(id))sourcePointForItem
{
    _previewView.sourcePointForItem = [sourcePointForItem copy];
}

- (void)loadView
{
    [super loadView];
    
    _previewView.frame = self.view.bounds;
    _previewView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_previewView];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    _autorotationWasEnabled = [TGViewController autorotationAllowed];
    [TGViewController disableAutorotation];
    
    [_previewView animateAppear];
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

- (void)dismiss
{
    if (self.onDismiss != nil)
    {
        void (^onDismiss)(void) = [self.onDismiss copy];
        self.onDismiss = nil;
        onDismiss();
    }
    
    [_previewView animateDismiss:^
    {
        [self dismissImmediately];
    }];
}

- (void)_handlePanOffset:(CGFloat)offset
{
    [_previewView _handlePanOffset:offset];
}

- (void)dismissImmediately
{
    [super dismiss];
    
    if (_autorotationWasEnabled)
        [TGViewController enableAutorotation];
    
    if (self.onDismiss != nil)
        self.onDismiss();
}

@end
