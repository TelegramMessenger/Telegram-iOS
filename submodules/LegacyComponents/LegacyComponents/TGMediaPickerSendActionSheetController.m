#import "TGMediaPickerSendActionSheetController.h"
#import "LegacyComponentsInternal.h"

#import "TGFont.h"
#import "TGImageUtils.h"
#import "TGModernButton.h"
#import "TGMediaAssetsController.h"

@interface TGMediaPickerSendActionSheetController ()
{
    id<LegacyComponentsContext> _context;
    
    CGRect _sendButtonFrame;
    bool _autorotationWasEnabled;
    
    UIVisualEffectView *_effectView;
    TGModernButton *_sendButton;
    
    UIView *_containerView;
    TGModernButton *_buttonView;
    UILabel *_buttonLabel;
    UIImageView *_buttonIcon;
}
@end

@implementation TGMediaPickerSendActionSheetController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context sendButtonFrame:(CGRect)sendButtonFrame {
    self = [super initWithContext:context];
    if (self != nil) {
        _context = context;
        _sendButtonFrame = sendButtonFrame;
    }
    return self;
}

- (void)loadView {
    [super loadView];
    
    _effectView = [[UIVisualEffectView alloc] initWithEffect:nil];
    if (iosMajorVersion() >= 9) {
        _effectView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    }
    [self.view addSubview:_effectView];
    
    _containerView = [[UIView alloc] init];
    _containerView.backgroundColor = UIColorRGB(0x1f1f1f);
    _containerView.clipsToBounds = true;
    _containerView.layer.cornerRadius = 12.0;
    [self.view addSubview:_containerView];
    
    __weak TGMediaPickerSendActionSheetController *weakSelf = self;
    _buttonView = [[TGModernButton alloc] init];
    _buttonView.adjustsImageWhenHighlighted = false;
    _buttonView.highlitedChanged = ^(bool highlighted) {
        __strong TGMediaPickerSendActionSheetController *strongSelf = weakSelf;
        if (strongSelf != nil) {
            if (highlighted) {
                strongSelf->_buttonView.backgroundColor = UIColorRGB(0x363636);
            } else {
                strongSelf->_buttonView.backgroundColor = [UIColor clearColor];
            }
        }
    };
    [_buttonView addTarget:self action:@selector(sendSilentlyPressed) forControlEvents:UIControlEventTouchUpInside];
    [_containerView addSubview:_buttonView];
    
    _buttonLabel = [[UILabel alloc] init];
    _buttonLabel.font = TGSystemFontOfSize(17.0f);
    _buttonLabel.text = TGLocalized(@"Conversation.SendMessage.SendSilently");
    _buttonLabel.textColor = [UIColor whiteColor];
    [_buttonLabel sizeToFit];
    _buttonLabel.userInteractionEnabled = false;
    [_containerView addSubview:_buttonLabel];
    
    _buttonIcon = [[UIImageView alloc] init];
    _buttonIcon.image = TGTintedImage(TGComponentsImageNamed(@"MediaMute"), [UIColor whiteColor]);
    [_buttonIcon sizeToFit];
    [_containerView addSubview:_buttonIcon];
    
    TGMediaAssetsPallete *pallete = nil;
    if ([[LegacyComponentsGlobals provider] respondsToSelector:@selector(mediaAssetsPallete)])
        pallete = [[LegacyComponentsGlobals provider] mediaAssetsPallete];
    
    UIImage *doneImage = pallete != nil ? pallete.sendIconImage : TGComponentsImageNamed(@"PhotoPickerSendIcon");
    
    _sendButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0.0, 0.0, 33.0, 33.0)];
    _sendButton.adjustsImageWhenDisabled = false;
    _sendButton.adjustsImageWhenHighlighted = false;
    [_sendButton setImage:doneImage forState:UIControlStateNormal];
    [_sendButton addTarget:self action:@selector(sendPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_sendButton];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    _autorotationWasEnabled = [TGViewController autorotationAllowed];
    [TGViewController disableAutorotation];
    
    [self animateIn];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] init];
    [tapRecognizer addTarget:self action:@selector(dimTapGesture)];
    [_effectView addGestureRecognizer:tapRecognizer];
}

- (void)dimTapGesture {
    [self animateOut:true];
}

- (BOOL)prefersStatusBarHidden {
    return true;
}

- (bool)statusBarShouldBeHidden {
    return true;
}

- (void)animateIn {
    if (_effectView.effect != nil) {
        _effectView.alpha = 0.0f;
    }
    [UIView animateWithDuration:0.3 animations:^{
        if (_effectView.effect == nil) {
            _effectView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        } else {
            _effectView.alpha = 1.0f;
        }
    }];
    
    CGPoint targetPosition = _containerView.center;
    _containerView.center = CGPointMake(targetPosition.x + 160.0, targetPosition.y + 44.0);
    [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^{
        _containerView.center = targetPosition;
    } completion:nil];
    
    _containerView.alpha = 0.0f;
    [UIView animateWithDuration:0.3 animations:^{
        _containerView.alpha = 1.0f;
    }];
}

- (void)animateOut:(bool)cancel {
    [UIView animateWithDuration:0.3 animations:^{
        if (iosMajorVersion() >= 9) {
            _effectView.effect = nil;
        } else {
            _effectView.alpha = 0.0f;
        }
        
        _containerView.alpha = 0.0f;
    } completion:^(BOOL finished) {
        if (!cancel) {
            [self dismiss];
        }
    }];
    
    if (cancel) {
        [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^{
            _containerView.center = CGPointMake(_containerView.center.x + 160.0, _containerView.center.y + 44.0);
        } completion:^(BOOL finished) {
            [self dismiss];
        }];
    }
    
    if (_autorotationWasEnabled) {
         [TGViewController enableAutorotation];
    }
}

- (void)viewDidLayoutSubviews {
    _effectView.frame = self.view.bounds;
    _sendButton.frame = _sendButtonFrame;
    
    _buttonLabel.frame = CGRectMake(16.0, 11.0, _buttonLabel.frame.size.width, _buttonLabel.frame.size.height);
    CGFloat containerWidth = MAX(240.0, _buttonLabel.frame.size.width + 84.0);
    _containerView.frame = CGRectMake(CGRectGetMaxX(_sendButtonFrame) - containerWidth - 8.0, _sendButtonFrame.origin.y - 44.0 - 4.0, containerWidth, 44.0);
    _buttonView.frame = _containerView.bounds;
    _buttonIcon.frame = CGRectMake(_containerView.frame.size.width - _buttonIcon.frame.size.width - 12.0, 9.0, _buttonIcon.frame.size.width, _buttonIcon.frame.size.height);
}

- (void)sendPressed {
    [self animateOut:false];
    
    if (self.send != nil)
        self.send();
}

- (void)sendSilentlyPressed {
    [self animateOut:false];
    
    if (self.sendSilently != nil)
        self.sendSilently();
}

@end
