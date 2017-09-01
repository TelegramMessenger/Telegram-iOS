#import "TGProgressWindow.h"

#import "LegacyComponentsInternal.h"

#import "TGProgressSpinnerView.h"

@interface TGProgressWindowController ()
{
    bool _light;
    UIVisualEffectView *_effectView;
    UIView *_backgroundView;
    TGProgressSpinnerView *_spinner;
}

@property (nonatomic, weak) UIWindow *weakWindow;
@property (nonatomic, strong) UIView *containerView;

@end

@implementation TGProgressWindowController

- (instancetype)init:(bool)light
{
    self = [super init];
    if (self != nil)
    {
        _light = light;
    }
    return self;
}

- (void)loadView
{
    [super loadView];

    _containerView = [[UIView alloc] initWithFrame:CGRectMake(CGFloor(self.view.frame.size.width - 100) / 2, CGFloor(self.view.frame.size.height - 100) / 2, 100, 100)];
    _containerView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    _containerView.alpha = 0.0f;
    _containerView.clipsToBounds = true;
    _containerView.layer.cornerRadius = 20.0f;
    [self.view addSubview:_containerView];
    
    if (iosMajorVersion() >= 9)
    {
        _effectView = [[UIVisualEffectView alloc] initWithEffect:_light ? [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight] : [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
        _effectView.frame = _containerView.bounds;
        [_containerView addSubview:_effectView];
        
        if (_light)
        {
            UIView *tintView = [[UIView alloc] initWithFrame:_effectView.bounds];
            tintView.backgroundColor = UIColorRGBA(0xf4f4f4, 0.75f);
            [_containerView addSubview:tintView];
        }
    }
    else
    {
        _backgroundView = [[UIView alloc] initWithFrame:_containerView.bounds];
        _backgroundView.backgroundColor = UIColorRGBA(0xeaeaea, 0.92f);
        [_containerView addSubview:_backgroundView];
    }
    
    _spinner = [[TGProgressSpinnerView alloc] initWithFrame:CGRectMake((_containerView.frame.size.width - 48.0f) / 2.0f, (_containerView.frame.size.height - 48.0f) / 2.0f, 48.0f, 48.0f) light:_light];
    [_containerView addSubview:_spinner];
}

- (void)show:(bool)animated
{
    UIWindow *window = _weakWindow;
    
    window.userInteractionEnabled = true;
    window.hidden = false;
    
    [_spinner setProgress];
    
    if (animated)
    {
        _containerView.transform = CGAffineTransformMakeScale(0.6f, 0.6f);
        if (iosMajorVersion() >= 7)
        {
            [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^{
                _containerView.transform = CGAffineTransformIdentity;
            } completion:nil];
        }
        
        [UIView animateWithDuration:0.3f animations:^
        {
            _containerView.alpha = 1.0f;
            if (iosMajorVersion() < 7)
                _containerView.transform = CGAffineTransformIdentity;
        }];
    }
    else
        _containerView.alpha = 1.0f;
}

- (void)dismiss:(bool)animated {
    [self dismiss:animated completion:nil];
}

- (void)dismiss:(bool)animated completion:(void (^)())completion
{
    TGProgressWindow *window = (TGProgressWindow *)_weakWindow;
    
    window.userInteractionEnabled = false;
    if (animated)
    {
        [UIView animateWithDuration:0.3f delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            _containerView.alpha = 0.0f;
        } completion:^(BOOL finished)
        {
            if (completion) {
                completion();
            }
            if (finished)
            {
                window.hidden = true;
                
                if (window.skipMakeKeyWindowOnDismiss)
                    return;
                
                NSArray *windows = [[LegacyComponentsGlobals provider] applicationWindows];
                for (int i = (int)windows.count - 1; i >= 0; i--)
                {
                    if ([windows objectAtIndex:i] != window) {
                        [[windows objectAtIndex:i] makeKeyWindow];
                    }
                }
            }
        }];
    }
    else
    {
        _containerView.alpha = 0.0f;
        window.hidden = true;
        
        if (window.skipMakeKeyWindowOnDismiss)
            return;
        
        NSArray *windows = [[LegacyComponentsGlobals provider] applicationWindows];
        for (int i = (int)windows.count - 1; i >= 0; i--)
        {
            if ([windows objectAtIndex:i] != window) {
                [[windows objectAtIndex:i] makeKeyWindow];
            }
        }
        
        if (completion) {
            completion();
        }
    }
}

- (void)dismissWithSuccess
{
    TGProgressWindow *window = (TGProgressWindow *)_weakWindow;
    
    window.userInteractionEnabled = false;
    
    void (^dismissBlock)(void) = ^
    {
        [UIView animateWithDuration:0.3 delay:0.55 options:0 animations:^
        {
            _containerView.alpha = 0.0f;
        } completion:^(BOOL finished)
        {
            if (finished)
            {
                window.hidden = true;
                
                if (window.skipMakeKeyWindowOnDismiss)
                    return;
                
                NSArray *windows = [[LegacyComponentsGlobals provider] applicationWindows];
                for (int i = (int)windows.count - 1; i >= 0; i--)
                {
                    if ([windows objectAtIndex:i] != window) {
                        [[windows objectAtIndex:i] makeKeyWindow];
                    }
                }
            }
        }];
    };
    
    if (window.hidden)
    {
        window.hidden = false;
        _containerView.transform = CGAffineTransformMakeScale(0.6f, 0.6f);
        
        if (iosMajorVersion() >= 7)
        {
            [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^{
                _containerView.transform = CGAffineTransformIdentity;
            } completion:nil];
        }

        [UIView animateWithDuration:0.3f animations:^
        {
             _containerView.alpha = 1.0f;
            if (iosMajorVersion() < 7)
                _containerView.transform = CGAffineTransformIdentity;
        } completion:^(__unused BOOL finished) {
            dismissBlock();
        }];
        
        TGDispatchAfter(0.15, dispatch_get_main_queue(), ^{
            [_spinner setSucceed];
        });
    }
    else
    {
        _spinner.onSuccess = ^{
            dismissBlock();
        };
        [_spinner setSucceed];
    }
}

- (BOOL)canBecomeFirstResponder {
    return false;
}

@end

@interface TGProgressWindow () {
    bool _dismissed;
    bool _appeared;
}

@end

static bool TGProgressWindowIsLight = true;

@implementation TGProgressWindow

- (instancetype)init {
    return [self initWithFrame:[[UIScreen mainScreen] bounds]];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.windowLevel = UIWindowLevelStatusBar;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        TGProgressWindowController *controller = [[TGProgressWindowController alloc] init:TGProgressWindowIsLight];
        controller.weakWindow = self;
        self.rootViewController = controller;
        
        self.opaque = false;
    }
    return self;
}

- (void)showAnimated
{
    [self show:true];
}

- (void)showWithDelay:(NSTimeInterval)delay {
    __weak TGProgressWindow *weakSelf = self;
    TGDispatchAfter(delay, dispatch_get_main_queue(), ^{
        __strong TGProgressWindow *strongSelf = weakSelf;
        if (strongSelf != nil && !strongSelf->_dismissed) {
            [strongSelf show:true];
        }
    });
}

- (void)show:(bool)animated
{
    _appeared = true;
    [((TGProgressWindowController *)self.rootViewController) show:animated];
}

- (void)dismiss:(bool)animated
{
    if (!_dismissed) {
        _dismissed = true;
        self.userInteractionEnabled = false;
        
        [((TGProgressWindowController *)self.rootViewController) dismiss:animated];
    }
}

- (void)dismissWithSuccess
{
    if (!_dismissed) {
        _dismissed = true;
        [((TGProgressWindowController *)self.rootViewController) dismissWithSuccess];
    }
}

+ (void)changeStyle
{
    TGProgressWindowIsLight = !TGProgressWindowIsLight;
}

@end
