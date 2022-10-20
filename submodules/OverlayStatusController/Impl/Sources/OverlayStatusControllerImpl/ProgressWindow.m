#import "ProgressWindow.h"

#import "ProgressSpinnerView.h"

#define UIColorRGBA(rgb,a) ([[UIColor alloc] initWithRed:(((rgb >> 16) & 0xff) / 255.0f) green:(((rgb >> 8) & 0xff) / 255.0f) blue:(((rgb) & 0xff) / 255.0f) alpha:a])

#ifdef __LP64__
#   define CGFloor floor
#else
#   define CGFloor floorf
#endif

static inline void dispatchAfter(double delay, dispatch_queue_t queue, dispatch_block_t block)
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((delay) * NSEC_PER_SEC)), queue, block);
}

static bool ProgressWindowIsLight = true;

@interface ProgressWindowController ()
{
    bool _light;
    UIVisualEffectView *_effectView;
    UIView *_backgroundView;
    ProgressSpinnerView *_spinner;
}

@property (nonatomic, weak) UIWindow *weakWindow;
@property (nonatomic, strong) UIView *containerView;

@end

@implementation ProgressWindowController

- (instancetype)init {
    return [self initWithLight:ProgressWindowIsLight];
}

- (instancetype)initWithLight:(bool)light
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
    _containerView.userInteractionEnabled = false;
    [self.view addSubview:_containerView];
    
    if ([[[UIDevice currentDevice] systemVersion] intValue] >= 9)
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
        _backgroundView.backgroundColor = _light ? UIColorRGBA(0xeaeaea, 0.92f) : UIColorRGBA(0x000000, 0.9f);
        [_containerView addSubview:_backgroundView];
    }
    
    _spinner = [[ProgressSpinnerView alloc] initWithFrame:CGRectMake((_containerView.frame.size.width - 48.0f) / 2.0f, (_containerView.frame.size.height - 48.0f) / 2.0f, 48.0f, 48.0f) light:_light];
    [_containerView addSubview:_spinner];
    
    self.view.userInteractionEnabled = true;
    [self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGesture:)]];
}

- (void)tapGesture:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        if (_cancelled) {
            _cancelled();
        }
    }
}

- (void)updateLayout {
    _containerView.frame = CGRectMake(CGFloor(self.view.frame.size.width - 100) / 2, CGFloor(self.view.frame.size.height - 100) / 2, 100, 100);
    _spinner.frame = CGRectMake((_containerView.frame.size.width - 48.0f) / 2.0f, (_containerView.frame.size.height - 48.0f) / 2.0f, 48.0f, 48.0f);
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
        [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^{
            _containerView.transform = CGAffineTransformIdentity;
        } completion:nil];
        
        [UIView animateWithDuration:0.3f animations:^
        {
            _containerView.alpha = 1.0f;
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
    if (animated)
    {
        [UIView animateWithDuration:0.3f delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            _containerView.alpha = 0.0f;
        } completion:^(__unused BOOL finished)
        {
            if (completion) {
                completion();
            }
        }];
    }
    else
    {
        _containerView.alpha = 0.0f;
        
        if (completion) {
            completion();
        }
    }
}

- (void)dismissWithSuccess:(void (^)(void))completion
{
    void (^dismissBlock)(void) = ^
    {
        [UIView animateWithDuration:0.3 delay:0.55 options:0 animations:^
        {
            _containerView.alpha = 0.0f;
        } completion:^(BOOL finished)
        {
            if (finished)
            {
                if (completion) {
                    completion();
                }
            }
        }];
    };
    
    _containerView.transform = CGAffineTransformMakeScale(0.6f, 0.6f);
    
    [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^{
        _containerView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.3f animations:^
    {
         _containerView.alpha = 1.0f;
    } completion:^(__unused BOOL finished) {
        dismissBlock();
    }];
    
    dispatchAfter(0.15, dispatch_get_main_queue(), ^{
        [_spinner setSucceed];
    });
}

- (BOOL)canBecomeFirstResponder {
    return false;
}

@end
