#import "TGVideoMessageCaptureController.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGCameraController.h>

#import <LegacyComponents/TGImageBlur.h>
#import <LegacyComponents/TGPhotoEditorUtils.h>
#import <LegacyComponents/TGTimerTarget.h>
#import <LegacyComponents/TGImageBlur.h>
#import <LegacyComponents/TGObserverProxy.h>

#import <LegacyComponents/TGMediaAssetImageSignals.h>

#import <LegacyComponents/TGModernButton.h>
#import <LegacyComponents/TGVideoCameraGLView.h>
#import "TGVideoCameraPipeline.h"
#import <LegacyComponents/PGCameraVolumeButtonHandler.h>

#import <LegacyComponents/TGVideoMessageControls.h>
#import <LegacyComponents/TGVideoMessageRingView.h>
#import <LegacyComponents/TGVideoMessageScrubber.h>
#import <LegacyComponents/TGModernGalleryVideoView.h>

#import <LegacyComponents/TGModernConversationInputMicButton.h>

#import "TGColor.h"
#import "TGImageUtils.h"

#import "TGMediaPickerSendActionSheetController.h"
#import "TGOverlayControllerWindow.h"

const NSTimeInterval TGVideoMessageMaximumDuration = 60.0;

typedef enum
{
    TGVideoMessageTransitionTypeUsual,
    TGVideoMessageTransitionTypeSimplified,
    TGVideoMessageTransitionTypeLegacy
} TGVideoMessageTransitionType;

@interface TGVideoMessageCaptureControllerWindow  : TGOverlayControllerWindow

@property (nonatomic, assign) CGRect controlsFrame;
@property (nonatomic, assign) bool locked;

@end

@implementation TGVideoMessageCaptureControllerAssets

- (instancetype)initWithSendImage:(UIImage *)sendImage slideToCancelImage:(UIImage *)slideToCancelImage actionDelete:(UIImage *)actionDelete {
    self = [super init];
    if (self != nil) {
        _sendImage = sendImage;
        _slideToCancelImage = slideToCancelImage;
        _actionDelete = actionDelete;
    }
    return self;
}

@end

@interface TGVideoMessageCaptureController () <TGVideoCameraPipelineDelegate, TGVideoMessageScrubberDataSource, TGVideoMessageScrubberDelegate, UIGestureRecognizerDelegate>
{
    SQueue *_queue;
    
    AVCaptureDevicePosition _preferredPosition;
    TGVideoCameraPipeline *_capturePipeline;
    NSURL *_url;
    
    PGCameraVolumeButtonHandler *_buttonHandler;
    bool _autorotationWasEnabled;
    bool _dismissed;
    bool _gpuAvailable;
    bool _locked;
    bool _positionChangeLocked;
    bool _alreadyStarted;
    
    CGRect _controlsFrame;
    TGVideoMessageControls *_controlsView;
    TGModernButton *_switchButton;
    
    UIView *_wrapperView;
    
    UIView *_blurView;
    
    UIView *_fadeView;
    UIView *_circleWrapperView;
    UIImageView *_shadowView;
    UIView *_circleView;
    TGVideoCameraGLView *_previewView;
    TGVideoMessageRingView *_ringView;
    
    UIPinchGestureRecognizer *_pinchGestureRecognizer;
    
    UIView *_separatorView;
    
    UIImageView *_placeholderView;
    TGVideoMessageShimmerView *_shimmerView;
    
    bool _automaticDismiss;
    NSTimeInterval _startTimestamp;
    NSTimer *_recordingTimer;
    
    NSTimeInterval _previousDuration;
    NSUInteger _audioRecordingDurationSeconds;
    NSUInteger _audioRecordingDurationMilliseconds;
    
    id _activityHolder;
    SMetaDisposable *_activityDisposable;
    
    SMetaDisposable *_currentAudioSession;
    bool _otherAudioPlaying;
    
    id _didEnterBackgroundObserver;
    
    bool _stopped;
    id _liveUploadData;
    UIImage *_thumbnailImage;
    NSDictionary *_thumbnails;
    NSTimeInterval _duration;
    AVPlayer *_player;
    id _didPlayToEndObserver;
    
    TGModernGalleryVideoView *_videoView;
    UIImageView *_muteView;
    bool _muted;
    
    SMetaDisposable *_thumbnailsDisposable;
    id<LegacyComponentsContext> _context;
    UIView *(^_transitionInView)();
    id<TGLiveUploadInterface> _liveUploadInterface;
    
    int32_t _slowmodeTimestamp;
    UIView * (^_slowmodeView)(void);
    
	TGVideoMessageCaptureControllerAssets *_assets;
    
    bool _canSendSilently;
    bool _canSchedule;
    bool _reminder;
    
    UIImpactFeedbackGenerator *_generator;
}

@property (nonatomic, copy) bool(^isAlreadyLocked)(void);

@end

@implementation TGVideoMessageCaptureController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context assets:(TGVideoMessageCaptureControllerAssets *)assets transitionInView:(UIView *(^)(void))transitionInView parentController:(TGViewController *)parentController controlsFrame:(CGRect)controlsFrame isAlreadyLocked:(bool (^)(void))isAlreadyLocked liveUploadInterface:(id<TGLiveUploadInterface>)liveUploadInterface pallete:(TGModernConversationInputMicPallete *)pallete slowmodeTimestamp:(int32_t)slowmodeTimestamp slowmodeView:(UIView *(^)(void))slowmodeView canSendSilently:(bool)canSendSilently canSchedule:(bool)canSchedule reminder:(bool)reminder
{
    self = [super initWithContext:context];
    if (self != nil)
    {
        _context = context;
        _transitionInView = [transitionInView copy];
        self.isAlreadyLocked = isAlreadyLocked;
        _liveUploadInterface = liveUploadInterface;
        _assets = assets;
        _pallete = pallete;
        _canSendSilently = canSendSilently;
        _canSchedule = canSchedule;
        _reminder = reminder;
        _slowmodeTimestamp = slowmodeTimestamp;
        _slowmodeView = [slowmodeView copy];
        
        _url = [TGVideoMessageCaptureController tempOutputPath];
        _queue = [[SQueue alloc] init];
        
        _previousDuration = 0.0;
        _preferredPosition = AVCaptureDevicePositionFront;
        
        self.isImportant = true;
        _controlsFrame = controlsFrame;
        
        _gpuAvailable = true;
        
        _activityDisposable = [[SMetaDisposable alloc] init];
        _currentAudioSession = [[SMetaDisposable alloc] init];
        
        __weak TGVideoMessageCaptureController *weakSelf = self;
        _didEnterBackgroundObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:nil usingBlock:^(__unused NSNotification *notification)
        {
            __strong TGVideoMessageCaptureController *strongSelf = weakSelf;
            if (strongSelf != nil && !strongSelf->_stopped)
            {
                strongSelf->_automaticDismiss = true;
                strongSelf->_gpuAvailable = false;
                [strongSelf dismiss:true];
            }
        }];
        
        _thumbnailsDisposable = [[SMetaDisposable alloc] init];
        
        TGVideoMessageCaptureControllerWindow *window = [[TGVideoMessageCaptureControllerWindow alloc] initWithManager:[_context makeOverlayWindowManager] parentController:parentController contentController:self keepKeyboard:true];
        window.windowLevel = 1000000000.0f - 0.001f;
        window.hidden = false;
        window.controlsFrame = controlsFrame;
    }
    return self;
}

- (void)dealloc
{
    printf("Video controller dealloc\n");
    [_thumbnailsDisposable dispose];
    [[NSNotificationCenter defaultCenter] removeObserver:_didEnterBackgroundObserver];
    [_activityDisposable dispose];
    id<SDisposable> currentAudioSession = _currentAudioSession;
    [_queue dispatch:^{
         [currentAudioSession dispose];
    }];
}

+ (NSURL *)tempOutputPath
{
    return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"cam_%x.mp4", (int)arc4random()]]];
}

- (void)setPallete:(TGModernConversationInputMicPallete *)pallete {
    _pallete = pallete;
    
    if (!_alreadyStarted)
        return;
    
    TGVideoMessageTransitionType type = [self _transitionType];
    if (type != TGVideoMessageTransitionTypeLegacy && ((UIVisualEffectView *)_blurView).effect != nil)
    {
        UIBlurEffect *effect = [UIBlurEffect effectWithStyle:self.pallete.isDark ? UIBlurEffectStyleDark : UIBlurEffectStyleLight];
        
        ((UIVisualEffectView *)_blurView).effect = effect;
    }
    
    UIColor *curtainColor = [UIColor whiteColor];
    if (self.pallete != nil && self.pallete.isDark)
        curtainColor = [UIColor blackColor];
    
    _fadeView.backgroundColor = [curtainColor colorWithAlphaComponent:0.4f];
    _ringView.accentColor = self.pallete != nil ? self.pallete.buttonColor : TGAccentColor();
    _controlsView.pallete = self.pallete;
    _separatorView.backgroundColor = self.pallete != nil ? self.pallete.borderColor : UIColorRGB(0xb2b2b2);
    
    UIImage *switchImage = TGComponentsImageNamed(@"VideoRecordPositionSwitch");
    if (self.pallete != nil)
        switchImage = TGTintedImage(switchImage, self.pallete.buttonColor);
    
    [_switchButton setImage:switchImage forState:UIControlStateNormal];
}

- (void)loadView
{
    [super loadView];
    
    self.view.backgroundColor = [UIColor clearColor];
    
    CGFloat bottomOffset = self.view.frame.size.height - CGRectGetMaxY(_controlsFrame);
    if (bottomOffset > 44.0) {
        bottomOffset = 0.0f;
    }
    CGRect wrapperFrame = TGIsPad() ? CGRectMake(0.0f, 0.0f, self.view.frame.size.width, CGRectGetMaxY(_controlsFrame) + bottomOffset): CGRectMake(0.0f, 0.0f, self.view.frame.size.width, CGRectGetMinY(_controlsFrame));
    
    _wrapperView = [[UIView alloc] initWithFrame:wrapperFrame];
    _wrapperView.clipsToBounds = true;
    [self.view addSubview:_wrapperView];
    
    UIColor *curtainColor = [UIColor whiteColor];
    if (self.pallete != nil && self.pallete.isDark)
        curtainColor = [UIColor blackColor];
    
    TGVideoMessageTransitionType type = [self _transitionType];
    CGRect fadeFrame = CGRectMake(0.0f, 0.0f, _wrapperView.frame.size.width, _wrapperView.frame.size.height);
    if (type != TGVideoMessageTransitionTypeLegacy)
    {
        UIBlurEffect *effect = nil;
        if (type == TGVideoMessageTransitionTypeSimplified)
            effect = [UIBlurEffect effectWithStyle:self.pallete.isDark ? UIBlurEffectStyleDark : UIBlurEffectStyleLight];
        
        _blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
        [_wrapperView addSubview:_blurView];
        
        if (type == TGVideoMessageTransitionTypeSimplified)
        {
            _blurView.alpha = 0.0f;
        }
        else
        {
            _fadeView = [[UIView alloc] initWithFrame:fadeFrame];
            _fadeView.alpha = 0.0f;
            _fadeView.backgroundColor = [curtainColor colorWithAlphaComponent:0.4f];
            [_wrapperView addSubview:_fadeView];
        }
    }
    else
    {
        _fadeView = [[UIView alloc] initWithFrame:fadeFrame];
        _fadeView.alpha = 0.0f;
        _fadeView.backgroundColor = [curtainColor colorWithAlphaComponent:0.6f];
        [_wrapperView addSubview:_fadeView];
    }
    
    CGFloat minSide = MIN(_wrapperView.frame.size.width, _wrapperView.frame.size.height);
    CGFloat diameter = minSide == 320.0 ? 216.0 : MIN(404.0, minSide - 24.0f);
    CGFloat shadowSize = 21.0f;
    
    CGFloat circleWrapperViewLength = diameter + shadowSize * 2.0;
    _circleWrapperView = [[UIView alloc] initWithFrame:(CGRect){
        .origin.x = (_wrapperView.bounds.size.width - circleWrapperViewLength) / 2.0f,
        .origin.y = _wrapperView.bounds.size.height + circleWrapperViewLength * 0.3f,
        .size.width = circleWrapperViewLength,
        .size.height = circleWrapperViewLength
    }];
    
    _circleWrapperView.alpha = 0.0f;
    _circleWrapperView.clipsToBounds = false;
    [_wrapperView addSubview:_circleWrapperView];
    
    _shadowView = [[UIImageView alloc] initWithImage:TGComponentsImageNamed(@"VideoMessageShadow")];
    _shadowView.frame = _circleWrapperView.bounds;
    [_circleWrapperView addSubview:_shadowView];
    
    _circleView = [[UIView alloc] initWithFrame:CGRectInset(_circleWrapperView.bounds, shadowSize, shadowSize)];
    _circleView.clipsToBounds = true;
    _circleView.layer.cornerRadius = _circleView.frame.size.width / 2.0f;
    [_circleWrapperView addSubview:_circleView];
    
    _placeholderView = [[UIImageView alloc] initWithFrame:_circleView.bounds];
    _placeholderView.backgroundColor = [UIColor blackColor];
    _placeholderView.image = [TGVideoMessageCaptureController startImage];
    [_circleView addSubview:_placeholderView];
    
    _shimmerView = [[TGVideoMessageShimmerView alloc] initWithFrame:_circleView.bounds];
    [_shimmerView updateAbsoluteRect:_circleView.bounds containerSize:_circleView.bounds.size];
    [_circleView addSubview:_shimmerView];
    
    if (@available(iOS 11.0, *)) {
        _shadowView.accessibilityIgnoresInvertColors = true;
        _placeholderView.accessibilityIgnoresInvertColors = true;
    }
    
    CGFloat ringViewLength = diameter - 8.0f;
    _ringView = [[TGVideoMessageRingView alloc] initWithFrame:(CGRect){
        .origin.x = (_circleWrapperView.bounds.size.width - ringViewLength) / 2.0f,
        .origin.y = (_circleWrapperView.bounds.size.height - ringViewLength) / 2.0f,
        .size.width = ringViewLength,
        .size.height = ringViewLength
    }];
    _ringView.accentColor = [UIColor colorWithWhite:1.0 alpha:0.6];
    [_circleWrapperView addSubview:_ringView];
    
    CGRect controlsFrame = _controlsFrame;
    
    _controlsView = [[TGVideoMessageControls alloc] initWithFrame:controlsFrame assets:_assets slowmodeTimestamp:_slowmodeTimestamp slowmodeView:_slowmodeView];
    _controlsView.pallete = self.pallete;
    _controlsView.clipsToBounds = true;
    _controlsView.parent = self;
    _controlsView.isAlreadyLocked = self.isAlreadyLocked;
    _controlsView.controlsHeight = _controlsFrame.size.height;
    
    __weak TGVideoMessageCaptureController *weakSelf = self;
    _controlsView.cancel = ^
    {
        __strong TGVideoMessageCaptureController *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            strongSelf->_automaticDismiss = true;
            [strongSelf dismiss:true];
            
            if (strongSelf.onCancel != nil)
                strongSelf.onCancel();
        }
    };
    _controlsView.deletePressed = ^
    {
        __strong TGVideoMessageCaptureController *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            strongSelf->_automaticDismiss = true;
            [strongSelf dismiss:true];
            
            if (strongSelf.onCancel != nil)
                strongSelf.onCancel();

        };
    };
    _controlsView.sendPressed = ^bool 
    {
        __strong TGVideoMessageCaptureController *strongSelf = weakSelf;
        if (strongSelf != nil) {
            return [strongSelf sendPressed];
        } else {
            return false;
        }
    };
    _controlsView.sendLongPressed = ^bool{
        __strong TGVideoMessageCaptureController *strongSelf = weakSelf;
        if (strongSelf != nil) {
            [strongSelf sendLongPressed];
        }
        return true;
    };
    [self.view addSubview:_controlsView];
    
    _separatorView = [[UIView alloc] initWithFrame:CGRectMake(controlsFrame.origin.x, controlsFrame.origin.y - TGScreenPixel, controlsFrame.size.width, TGScreenPixel)];
    _separatorView.backgroundColor = self.pallete != nil ? self.pallete.borderColor : UIColorRGB(0xb2b2b2);
    _separatorView.userInteractionEnabled = false;
    [self.view addSubview:_separatorView];
    
    if ([TGVideoCameraPipeline cameraPositionChangeAvailable])
    {
        UIImage *switchImage = TGComponentsImageNamed(@"VideoRecordPositionSwitch");
        if (self.pallete != nil)
            switchImage = TGTintedImage(switchImage, self.pallete.buttonColor);
        
        _switchButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 44.0f, 44.0f)];
        _switchButton.alpha = 0.0f;
        _switchButton.adjustsImageWhenHighlighted = false;
        _switchButton.adjustsImageWhenDisabled = false;
        [_switchButton setImage:switchImage forState:UIControlStateNormal];
        [_switchButton addTarget:self action:@selector(changeCameraPosition) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_switchButton];
    }
    
    _pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
    _pinchGestureRecognizer.delegate = self;
    [self.view addGestureRecognizer:_pinchGestureRecognizer];
    
    void (^voidBlock)(void) = ^{};
    _buttonHandler = [[PGCameraVolumeButtonHandler alloc] initWithUpButtonPressedBlock:voidBlock upButtonReleasedBlock:voidBlock downButtonPressedBlock:voidBlock downButtonReleasedBlock:voidBlock];
    
    [self configureCamera];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer == _pinchGestureRecognizer)
        return _capturePipeline.isZoomAvailable;
    
    return true;
}

- (void)handlePinch:(UIPinchGestureRecognizer *)gestureRecognizer
{
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateChanged:
        {
            CGFloat delta = (gestureRecognizer.scale - 1.0f) / 1.5f;
            CGFloat value = MAX(0.0f, MIN(1.0f, _capturePipeline.zoomLevel + delta));
            
            [_capturePipeline setZoomLevel:value];
            
            gestureRecognizer.scale = 1.0f;
        }
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
            [_capturePipeline cancelZoom];
            break;
        default:
            break;
    }
}

- (TGVideoMessageTransitionType)_transitionType
{
    static dispatch_once_t onceToken;
    static TGVideoMessageTransitionType type;
    dispatch_once(&onceToken, ^
    {
        CGSize screenSize = TGScreenSize();
        if (iosMajorVersion() < 8 || (NSInteger)screenSize.height == 480)
            type = TGVideoMessageTransitionTypeLegacy;
        else if (iosMajorVersion() == 8)
            type = TGVideoMessageTransitionTypeSimplified;
        else
            type = TGVideoMessageTransitionTypeUsual;
    });
    
    return type;
}

- (void)setupPreviewView
{
    _previewView = [[TGVideoCameraGLView alloc] initWithFrame:_circleView.bounds];
    [_circleView insertSubview:_previewView belowSubview:_placeholderView];
    
    if (@available(iOS 11.0, *)) {
        _previewView.accessibilityIgnoresInvertColors = true;
    }
    
    [self captureStarted];
}

- (void)_transitionIn
{
    TGVideoMessageTransitionType type = [self _transitionType];
    if (type == TGVideoMessageTransitionTypeUsual)
    {
        UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        
        UIView *rootView = _transitionInView();
        rootView.superview.backgroundColor = [UIColor whiteColor];
        
        [UIView animateWithDuration:0.22 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^
        {
            ((UIVisualEffectView *)_blurView).effect = effect;
            _fadeView.alpha = 1.0f;
        } completion:nil];
    }
    else if (type == TGVideoMessageTransitionTypeSimplified)
    {
        [UIView animateWithDuration:0.22 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^
        {
             _blurView.alpha = 1.0f;
        } completion:nil];
    }
    else
    {
        [UIView animateWithDuration:0.25 animations:^
        {
            _fadeView.alpha = 1.0f;
        }];
    }
}

- (void)_transitionOut
{
    TGVideoMessageTransitionType type = [self _transitionType];
    if (type == TGVideoMessageTransitionTypeUsual)
    {
        [UIView animateWithDuration:0.22 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^
        {
            ((UIVisualEffectView *)_blurView).effect = nil;
            _fadeView.alpha = 0.0f;
         } completion:nil];
    }
    else if (type == TGVideoMessageTransitionTypeSimplified)
    {
        [UIView animateWithDuration:0.22 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^
        {
            _blurView.alpha = 0.0f;
        } completion:nil];
    }
    else
    {
        [UIView animateWithDuration:0.15 animations:^
        {
            _fadeView.alpha = 0.0f;
        }];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    if (self.ignoreAppearEvents) {
        return;
    }
    
    [super viewWillAppear:animated];
    
    _capturePipeline.renderingEnabled = true;
    
    _startTimestamp = CFAbsoluteTimeGetCurrent();
    
    [_controlsView setShowRecordingInterface:true velocity:0.0f];
    
    [[[LegacyComponentsGlobals provider] applicationInstance] setIdleTimerDisabled:true];
    
    [self _transitionIn];
    
    [self _beginAudioSession:false];
    [_queue dispatch:^
    {
        [_capturePipeline startRunning];
    }];
}

- (void)viewDidAppear:(BOOL)animated
{
    if (self.ignoreAppearEvents) {
        return;
    }
    [super viewDidAppear:animated];
    
    _autorotationWasEnabled = [TGViewController autorotationAllowed];
    [TGViewController disableAutorotation];
    
    _circleWrapperView.transform = CGAffineTransformMakeScale(0.3f, 0.3f);
    
    CGPoint targetPosition = (CGPoint){
        .x = _wrapperView.frame.size.width / 2.0f,
        .y = _wrapperView.frame.size.height / 2.0f - _controlsView.frame.size.height
    };
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    switch (self.interfaceOrientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
            break;
        case UIInterfaceOrientationLandscapeRight:
            break;
        default:
            if (self.view.frame.size.height > self.view.frame.size.width && fabs(_wrapperView.frame.size.height - self.view.frame.size.height) < 50.0f)
                targetPosition.y = _wrapperView.frame.size.height / 3.0f - 20.0f;
            
            targetPosition.y = MAX(_circleWrapperView.bounds.size.height / 2.0f + 40.0f, targetPosition.y);
            break;
    }
#pragma clang diagnostic pop
    
    if (TGIsPad()) {
        _circleWrapperView.center = targetPosition;
    }
    
    [UIView animateWithDuration:0.5 delay:0.0 usingSpringWithDamping:0.8f initialSpringVelocity:0.2f options:kNilOptions animations:^
    {
        if (!TGIsPad()) {
            _circleWrapperView.center = targetPosition;
        }
        _circleWrapperView.transform = CGAffineTransformIdentity;
    } completion:nil];
    
    [UIView animateWithDuration:0.2 animations:^
    {
        _circleWrapperView.alpha = 1.0f;
    } completion:nil];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    CGRect fadeFrame = TGIsPad() ? self.view.bounds : CGRectMake(0.0f, 0.0f, _wrapperView.frame.size.width, _wrapperView.frame.size.height);
    _blurView.frame = fadeFrame;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)__unused toInterfaceOrientation duration:(NSTimeInterval)__unused duration
{
    if (TGIsPad())
    {
        _automaticDismiss = true;
        [self dismiss:true];
    }
}

- (void)dismissImmediately
{
    [super dismiss];
    
    [[[LegacyComponentsGlobals provider] applicationInstance] setIdleTimerDisabled:false];
    [self stopCapture];
    
    [self _endAudioSession];
    
    if (_autorotationWasEnabled)
        [TGViewController enableAutorotation];
    
    if (_didDismiss) {
        _didDismiss();
    }
}

- (void)dismiss
{
    [self dismiss:true];
}

- (void)dismiss:(bool)cancelled
{
    _dismissed = cancelled;
    
    if (self.onDismiss != nil)
        self.onDismiss(_automaticDismiss, cancelled);
    
    if (_player != nil)
        [_player pause];
    
    self.view.backgroundColor = [UIColor clearColor];
    self.view.userInteractionEnabled = false;
    
    [UIView animateWithDuration:0.15 animations:^
    {
        _circleWrapperView.alpha = 0.0f;
        _switchButton.alpha = 0.0f;
    }];
    
    [self _transitionOut];
    
    [_controlsView setShowRecordingInterface:false velocity:0.0f];
    
    TGDispatchAfter(0.3, dispatch_get_main_queue(), ^
    {
        [self dismissImmediately];
    });
}

- (void)complete
{
    if (_stopped)
        return;
    
    [_activityDisposable dispose];
    [self stopRecording:^() {
        TGDispatchOnMainThread(^{
            //[self dismiss:false];
            [self description];
        });
    }];
}

- (void)buttonInteractionUpdate:(CGPoint)value
{
    [_controlsView buttonInteractionUpdate:value];
}

- (void)setLocked
{
    if ([self.view.window isKindOfClass:[TGVideoMessageCaptureControllerWindow class]]) {
        ((TGVideoMessageCaptureControllerWindow *)self.view.window).locked = true;
    }
    [_controlsView setLocked];
}

- (CGRect)frameForSendButton {
    return [_controlsView convertRect:[_controlsView frameForSendButton] toView:self.view];
}

- (bool)stop
{
    if (!_capturePipeline.isRecording)
        return false;
    
    if (_capturePipeline.videoDuration < 0.33)
        return false;
    
    if ([self.view.window isKindOfClass:[TGVideoMessageCaptureControllerWindow class]]) {
        ((TGVideoMessageCaptureControllerWindow *)self.view.window).locked = false;
    }
    _stopped = true;
    _gpuAvailable = false;
    _switchButton.userInteractionEnabled = false;
    
    [_activityDisposable dispose];
    [self stopRecording:^{}];
    return true;
}

- (bool)sendPressed
{
    if (_slowmodeTimestamp != 0) {
        int32_t timestamp = (int32_t)[[NSDate date] timeIntervalSince1970];
        if (timestamp < _slowmodeTimestamp) {
            if (_displaySlowmodeTooltip) {
                _displaySlowmodeTooltip();
            }
            return false;
        }
    }
    
    [self finishWithURL:_url dimensions:CGSizeMake(240.0f, 240.0f) duration:_duration liveUploadData:_liveUploadData thumbnailImage:_thumbnailImage isSilent:false scheduleTimestamp:0];
    
    _automaticDismiss = true;
    [self dismiss:false];
    return true;
}

- (void)sendLongPressed {
    if (iosMajorVersion() >= 10) {
        if (_generator == nil) {
            _generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        }
        [_generator impactOccurred];
    }
    
    TGMediaPickerSendActionSheetController *controller = [[TGMediaPickerSendActionSheetController alloc] initWithContext:_context isDark:self.pallete.isDark sendButtonFrame:[_controlsView convertRect:[_controlsView frameForSendButton] toView:nil] canSendSilently:_canSendSilently canSchedule:_canSchedule reminder:_reminder hasTimer:false];
    __weak TGVideoMessageCaptureController *weakSelf = self;
    controller.send = ^{
        __strong TGVideoMessageCaptureController *strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        
        [strongSelf finishWithURL:strongSelf->_url dimensions:CGSizeMake(240.0f, 240.0f) duration:strongSelf->_duration liveUploadData:strongSelf->_liveUploadData thumbnailImage:strongSelf->_thumbnailImage isSilent:false scheduleTimestamp:0];
        
        _automaticDismiss = true;
        [strongSelf dismiss:false];
    };
    controller.sendSilently = ^{
        __strong TGVideoMessageCaptureController *strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        
        [strongSelf finishWithURL:strongSelf->_url dimensions:CGSizeMake(240.0f, 240.0f) duration:strongSelf->_duration liveUploadData:strongSelf->_liveUploadData thumbnailImage:strongSelf->_thumbnailImage isSilent:true scheduleTimestamp:0];
        
        _automaticDismiss = true;
        [strongSelf dismiss:false];
    };
    controller.schedule = ^{
        __strong TGVideoMessageCaptureController *strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        
        if (strongSelf.presentScheduleController) {
            strongSelf.presentScheduleController(^(int32_t time) {
                __strong TGVideoMessageCaptureController *strongSelf = weakSelf;
                if (strongSelf == nil) {
                    return;
                }
                
                [strongSelf finishWithURL:strongSelf->_url dimensions:CGSizeMake(240.0f, 240.0f) duration:strongSelf->_duration liveUploadData:strongSelf->_liveUploadData thumbnailImage:strongSelf->_thumbnailImage isSilent:false scheduleTimestamp:time];
                
                _automaticDismiss = true;
                [strongSelf dismiss:false];
            });
        }
    };
    
    TGOverlayControllerWindow *controllerWindow = [[TGOverlayControllerWindow alloc] initWithManager:[_context makeOverlayWindowManager] parentController:self contentController:controller];
    controllerWindow.hidden = false;
}

- (void)unmutePressed
{
    [self _updateMuted:false];
    
    [[SQueue concurrentDefaultQueue] dispatch:^
    {
        _player.muted = false;
        
        [self _seekToPosition:_controlsView.scrubberView.trimStartValue];
    }];
}

- (void)_stop
{
    [_controlsView setStopped];
    [UIView animateWithDuration:0.2 animations:^
    {
        _switchButton.alpha = 0.0f;
        _ringView.alpha = 0.0f;
    } completion:^(__unused BOOL finished)
    {
        _ringView.hidden = true;
        _switchButton.hidden = true;
    }];
}

- (UIImage *)systemUnmuteButton {
    static UIImage *image = nil;
    if (image == nil)
    {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(24.0f, 24.0f), false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        UIColor *color = UIColorRGBA(0x000000, 0.4f);
        
        CGContextSetFillColorWithColor(context, color.CGColor);
        CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, 24.0f, 24.0f));
        
        UIImage *iconImage = TGComponentsImageNamed(@"VideoMessageMutedIcon.png");
        [iconImage drawAtPoint:CGPointMake(CGFloor((24.0f - iconImage.size.width) / 2.0f), CGFloor((24.0f - iconImage.size.height) / 2.0f))];
        
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return image;
}

- (void)setupVideoView
{
    _controlsView.scrubberView.trimStartValue = 0.0;
    _controlsView.scrubberView.trimEndValue = _duration;
    [_controlsView.scrubberView setTrimApplied:false];
    [_controlsView.scrubberView reloadData];
    
    _player = [[AVPlayer alloc] initWithURL:_url];
    _player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    _player.muted = true;
    
    _didPlayToEndObserver = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(playerItemDidPlayToEndTime:) name:AVPlayerItemDidPlayToEndTimeNotification object:_player.currentItem];
    
    _videoView = [[TGModernGalleryVideoView alloc] initWithFrame: CGRectInset(_previewView.frame, -3.0, -3.0) player:_player];
    [_previewView.superview insertSubview:_videoView belowSubview:_previewView];
    
    UITapGestureRecognizer *gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(unmutePressed)];
    [_videoView addGestureRecognizer:gestureRecognizer];
    
    _muted = true;
    _muteView = [[UIImageView alloc] initWithImage:[self systemUnmuteButton]];
    _muteView.frame = CGRectMake(floor(CGRectGetMidX(_circleView.bounds) - 12.0f), CGRectGetMaxY(_circleView.bounds) - 24.0f - 8.0f, 24.0f, 24.0f);
    [_previewView.superview addSubview:_muteView];
    
    [_player play];
    
    [UIView animateWithDuration:0.1 delay:0.1 options:kNilOptions animations:^
    {
        _previewView.alpha = 0.0f;
    } completion:nil];
}

- (void)_updateMuted:(bool)muted
{
    if (muted == _muted)
        return;
    
    _muted = muted;
    
    UIView *muteButtonView = _muteView;
    [muteButtonView.layer removeAllAnimations];
    
    if ((muteButtonView.transform.a < 0.3f || muteButtonView.transform.a > 1.0f) || muteButtonView.alpha < FLT_EPSILON)
    {
        muteButtonView.transform = CGAffineTransformMakeScale(0.001f, 0.001f);
        muteButtonView.alpha = 0.0f;
    }
    
    [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState | 7 << 16 animations:^
    {
        muteButtonView.transform = muted ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.001f, 0.001f);
    } completion:nil];
    
    [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
    {
        muteButtonView.alpha = muted ? 1.0f : 0.0f;
    } completion:nil];
}

- (void)_seekToPosition:(NSTimeInterval)position
{
    CMTime targetTime = CMTimeMakeWithSeconds(MIN(position, _duration - 0.1), NSEC_PER_SEC);
    [_player.currentItem seekToTime:targetTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}

- (void)playerItemDidPlayToEndTime:(NSNotification *)__unused notification
{
    [self _seekToPosition:_controlsView.scrubberView.trimStartValue];
    
    TGDispatchOnMainThread(^
    {
        [self _updateMuted:true];
        
        [[SQueue concurrentDefaultQueue] dispatch:^
        {
            _player.muted = true;
        }];
    });
}

#pragma mark -

- (void)changeCameraPosition
{
    if (_positionChangeLocked)
        return;
    
    _preferredPosition = (_preferredPosition == AVCaptureDevicePositionFront) ? AVCaptureDevicePositionBack : AVCaptureDevicePositionFront;
    
    _gpuAvailable = false;
    [_previewView removeFromSuperview];
    _previewView = nil;

    _ringView.alpha = 0.0f;
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        [UIView transitionWithView:_circleWrapperView duration:0.4f options:UIViewAnimationOptionTransitionFlipFromLeft | UIViewAnimationOptionCurveEaseOut animations:^
        {
            _placeholderView.hidden = false;
        } completion:^(__unused BOOL finished)
        {
            _ringView.alpha = 1.0f;
            _gpuAvailable = true;
        }];
        
        [_capturePipeline setCameraPosition:_preferredPosition];
        
        _positionChangeLocked = true;
        TGDispatchAfter(1.0, dispatch_get_main_queue(), ^
        {
            _positionChangeLocked = false;
        });
    });
}

#pragma mark -

- (void)startRecording
{
    [_buttonHandler ignoreEventsFor:1.0f andDisable:false];
    [_capturePipeline startRecording:_url preset:TGMediaVideoConversionPresetVideoMessage liveUpload:true];
    
    [self startRecordingTimer];
}

- (void)stopRecording:(void (^)())completed
{
    __weak TGVideoMessageCaptureController *weakSelf = self;
    [_capturePipeline stopRecording:^(bool success) {
        TGDispatchOnMainThread(^{
            __strong TGVideoMessageCaptureController *strongSelf = weakSelf;
            if (strongSelf == nil) {
                return;
            }
            if (!success) {
                if (!strongSelf->_dismissed && strongSelf.finishedWithVideo != nil) {
                    strongSelf.finishedWithVideo(nil, nil, 0, 0.0, CGSizeZero, nil, nil, false, 0);
                }
            }
        });
    }];
    [_buttonHandler ignoreEventsFor:1.0f andDisable:true];
    [_capturePipeline stopRunning];
}

- (void)finishWithURL:(NSURL *)url dimensions:(CGSize)dimensions duration:(NSTimeInterval)duration liveUploadData:(id )liveUploadData thumbnailImage:(UIImage *)thumbnailImage isSilent:(bool)isSilent scheduleTimestamp:(int32_t)scheduleTimestamp
{
    if (duration < 1.0)
        _dismissed = true;
    
    CGFloat minSize = MIN(thumbnailImage.size.width, thumbnailImage.size.height);
    CGFloat maxSize = MAX(thumbnailImage.size.width, thumbnailImage.size.height);
    
    bool mirrored = true;
    UIImageOrientation orientation = [self orientationForThumbnailWithTransform:_capturePipeline.videoTransform mirrored:mirrored];
    
    UIImage *image = TGPhotoEditorCrop(thumbnailImage, nil, orientation, 0.0f, CGRectMake((maxSize - minSize) / 2.0f, 0.0f, minSize, minSize), mirrored, CGSizeMake(240.0f, 240.0f), thumbnailImage.size, true);
    
    NSDictionary *fileDictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:url.path error:NULL];
    NSUInteger fileSize = (NSUInteger)[fileDictionary fileSize];
    
    UIImage *startImage = TGSecretBlurredAttachmentImage(image, image.size, NULL, false, 0);
    [TGVideoMessageCaptureController saveStartImage:startImage];
    
    TGVideoEditAdjustments *adjustments = nil;
    if (_stopped)
    {
        NSTimeInterval trimStartValue = _controlsView.scrubberView.trimStartValue;
        NSTimeInterval trimEndValue = _controlsView.scrubberView.trimEndValue;
        
        if (trimStartValue > DBL_EPSILON || trimEndValue < _duration - DBL_EPSILON)
        {
            adjustments = [TGVideoEditAdjustments editAdjustmentsWithOriginalSize:dimensions cropRect:CGRectMake(0.0f, 0.0f, dimensions.width, dimensions.height) cropOrientation:UIImageOrientationUp cropRotation:0.0 cropLockedAspectRatio:1.0 cropMirrored:false trimStartValue:trimStartValue trimEndValue:trimEndValue toolValues:nil paintingData:nil sendAsGif:false preset:TGMediaVideoConversionPresetVideoMessage];
            
            duration = trimEndValue - trimStartValue;
        }
        
        if (trimStartValue > DBL_EPSILON)
        {
            bool generatedImage = false;
            AVAsset *asset = [[AVURLAsset alloc] initWithURL:url options:nil];
            if (asset != nil) {
                AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
                imageGenerator.maximumSize = dimensions;
                imageGenerator.appliesPreferredTrackTransform = true;
                CGImageRef imageRef = [imageGenerator copyCGImageAtTime:CMTimeMakeWithSeconds(trimStartValue, 24) actualTime:nil error:nil];
                if (imageRef != nil) {
                    image = [UIImage imageWithCGImage:imageRef];
                    CGImageRelease(imageRef);
                    generatedImage = true;
                }
            }
            
            if (!generatedImage) {
                NSArray *thumbnail = [self thumbnailsForTimestamps:@[@(trimStartValue)]];
                image = thumbnail.firstObject;
            }
        }
    }
    
    if (!_dismissed) {
        self.finishedWithVideo(url, image, fileSize, duration, dimensions, liveUploadData, adjustments, isSilent, scheduleTimestamp);
    } else {
        [[NSFileManager defaultManager] removeItemAtURL:url error:NULL];
        if (self.finishedWithVideo != nil) {
            self.finishedWithVideo(nil, nil, 0, 0.0, CGSizeZero, nil, nil, false, 0);
        }
    }
}

- (UIImageOrientation)orientationForThumbnailWithTransform:(CGAffineTransform)transform mirrored:(bool)mirrored
{
    CGFloat angle = atan2(transform.b, transform.a);
    NSInteger degrees =  (360 + (NSInteger)TGRadiansToDegrees(angle)) % 360;
    
    switch (degrees)
    {
        case 90:
            return mirrored ? UIImageOrientationLeft : UIImageOrientationRight;
            break;
            
        case 180:
            return UIImageOrientationDown;
            break;
            
        case 270:
            return mirrored ? UIImageOrientationLeft : UIImageOrientationRight;
            
        default:
            break;
    }
    
    return UIImageOrientationUp;
}

#pragma mark -

- (void)startRecordingTimer
{
    [_controlsView recordingStarted];
    [_controlsView setDurationString:@"0:00,00"];
    self.onDuration(0);
    
    _audioRecordingDurationSeconds = 0;
    _audioRecordingDurationMilliseconds = 0.0;
    _recordingTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(timerEvent) interval:2.0 / 60.0 repeat:false];
}

- (void)timerEvent
{
    if (_recordingTimer != nil)
    {
        [_recordingTimer invalidate];
        _recordingTimer = nil;
    }
    
    NSTimeInterval recordingDuration = _capturePipeline.videoDuration;
    if (isnan(recordingDuration))
        recordingDuration = 0.0;
    
    if (recordingDuration < _previousDuration)
        recordingDuration = _previousDuration;
    
    _previousDuration = recordingDuration;
    [_ringView setValue:recordingDuration / TGVideoMessageMaximumDuration];
    
    CFAbsoluteTime currentTime = CACurrentMediaTime();
    NSUInteger currentDurationSeconds = (NSUInteger)recordingDuration;
    NSUInteger currentDurationMilliseconds = (int)(recordingDuration * 100.0f) % 100;
    if (currentDurationSeconds == _audioRecordingDurationSeconds && currentDurationMilliseconds == _audioRecordingDurationMilliseconds)
    {
        _recordingTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(timerEvent) interval:MAX(0.01, _audioRecordingDurationSeconds + 2.0 / 60.0 - currentTime) repeat:false];
    }
    else
    {
        self.onDuration(recordingDuration);
        _audioRecordingDurationSeconds = currentDurationSeconds;
        _audioRecordingDurationMilliseconds = currentDurationMilliseconds;
        [_controlsView setDurationString:[[NSString alloc] initWithFormat:@"%d:%02d,%02d", (int)_audioRecordingDurationSeconds / 60, (int)_audioRecordingDurationSeconds % 60, (int)_audioRecordingDurationMilliseconds]];
        _recordingTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(timerEvent) interval:2.0 / 60.0 repeat:false];
    }
    
    if (recordingDuration >= TGVideoMessageMaximumDuration)
    {
        [_recordingTimer invalidate];
        _recordingTimer = nil;
        
        _automaticDismiss = true;
        [self stop];
        
        if (self.onStop != nil)
            self.onStop();
    }
}

- (void)stopRecordingTimer
{
    if (_recordingTimer != nil)
    {
        [_recordingTimer invalidate];
        _recordingTimer = nil;
    }
}

#pragma mark -

- (void)captureStarted
{
    bool firstTime = !_alreadyStarted;
    _alreadyStarted = true;
    
    _switchButton.frame = CGRectMake(11.0f, _controlsFrame.origin.y - _switchButton.frame.size.height - 7.0f, _switchButton.frame.size.width, _switchButton.frame.size.height);
    
    NSTimeInterval delay = firstTime ? 0.1 : 0.2;
    [UIView animateWithDuration:0.3 delay:delay options:kNilOptions animations:^
    {
        _placeholderView.alpha = 0.0f;
        _shimmerView.alpha = 0.0f;
        _switchButton.alpha = 1.0f;
    } completion:^(__unused BOOL finished)
    {
        _shimmerView.hidden = true;
        _placeholderView.hidden = true;
        _placeholderView.alpha = 1.0f;
    }];
    
    if (firstTime)
    {
        TGDispatchAfter(0.2, dispatch_get_main_queue(), ^
        {
            [self startRecording];
        });
    }
}

- (void)stopCapture
{
    [_capturePipeline stopRunning];
}

- (void)configureCamera
{
    _capturePipeline = [[TGVideoCameraPipeline alloc] initWithDelegate:self position:_preferredPosition callbackQueue:dispatch_get_main_queue() liveUploadInterface:_liveUploadInterface];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    _capturePipeline.orientation = (AVCaptureVideoOrientation)self.interfaceOrientation;
#pragma clang diagnostic pop
    
    __weak TGVideoMessageCaptureController *weakSelf = self;
    _capturePipeline.micLevel = ^(CGFloat level)
    {
        TGDispatchOnMainThread(^
        {
            __strong TGVideoMessageCaptureController *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf.micLevel != nil)
                strongSelf.micLevel(level);
        });
    };
}

#pragma mark -

- (void)capturePipeline:(TGVideoCameraPipeline *)__unused capturePipeline didStopRunningWithError:(NSError *)__unused error
{
}

- (void)capturePipeline:(TGVideoCameraPipeline *)__unused capturePipeline previewPixelBufferReadyForDisplay:(CVPixelBufferRef)previewPixelBuffer
{
    if (!_gpuAvailable)
        return;
    
    if (!_previewView)
        [self setupPreviewView];
    
    [_previewView displayPixelBuffer:previewPixelBuffer];
}

- (void)capturePipelineDidRunOutOfPreviewBuffers:(TGVideoCameraPipeline *)__unused capturePipeline
{
    if (_gpuAvailable)
        [_previewView flushPixelBufferCache];
}

- (void)capturePipelineRecordingDidStart:(TGVideoCameraPipeline *)__unused capturePipeline
{
    __weak TGVideoMessageCaptureController *weakSelf = self;
    [_activityDisposable setDisposable:[[[SSignal complete] delay:0.3 onQueue:[SQueue mainQueue]] startWithNext:nil error:nil completed:^{
        __strong TGVideoMessageCaptureController *strongSelf = weakSelf;
        if (strongSelf != nil && strongSelf->_requestActivityHolder) {
            strongSelf->_activityHolder = strongSelf->_requestActivityHolder();
        }
    }]];
}

- (void)capturePipelineRecordingWillStop:(TGVideoCameraPipeline *)__unused capturePipeline
{
}

- (void)capturePipelineRecordingDidStop:(TGVideoCameraPipeline *)__unused capturePipeline duration:(NSTimeInterval)duration liveUploadData:(id)liveUploadData thumbnailImage:(UIImage *)thumbnailImage thumbnails:(NSDictionary *)thumbnails
{
    if (_stopped && duration > 0.33)
    {
        _duration = duration;
        _liveUploadData = liveUploadData;
        _thumbnailImage = thumbnailImage;
        _thumbnails = thumbnails;
        TGDispatchOnMainThread(^
        {
            [self _stop];
            [self setupVideoView];
        });
    }
    else
    {
        [self finishWithURL:_url dimensions:CGSizeMake(240.0f, 240.0f) duration:duration liveUploadData:liveUploadData thumbnailImage:thumbnailImage isSilent:false scheduleTimestamp:0];
    }
}

- (void)capturePipeline:(TGVideoCameraPipeline *)__unused capturePipeline recordingDidFailWithError:(NSError *)__unused error
{
}

#pragma mark - 

- (void)_beginAudioSession:(bool)speaker
{
    [_queue dispatch:^
    {
        _otherAudioPlaying = [[AVAudioSession sharedInstance] isOtherAudioPlaying];
        
        __weak TGVideoMessageCaptureController *weakSelf = self;
        id<SDisposable> disposable = [[LegacyComponentsGlobals provider] requestAudioSession:speaker ? TGAudioSessionTypePlayAndRecordHeadphones : TGAudioSessionTypePlayAndRecord interrupted:^
        {
            TGDispatchOnMainThread(^{
                __strong TGVideoMessageCaptureController *strongSelf = weakSelf;
                if (strongSelf != nil) {
                    strongSelf->_automaticDismiss = true;
                    [strongSelf complete];
                }
            });
        }];
        [_currentAudioSession setDisposable:disposable];
    }];
}

- (void)_endAudioSession
{
    id<SDisposable> currentAudioSession = _currentAudioSession;
    [_queue dispatch:^
    {
        [currentAudioSession dispose];
    }];
}

#pragma mark -

static UIImage *startImage = nil;

+ (NSString *)_startImagePath
{
    return [[[LegacyComponentsGlobals provider] dataCachePath] stringByAppendingPathComponent:@"startImage.jpg"];
}

+ (UIImage *)startImage
{
    if (startImage == nil)
        startImage = [UIImage imageWithContentsOfFile:[self _startImagePath]] ? : TGComponentsImageNamed (@"VideoMessagePlaceholder.jpg");
    
    return startImage;
}

+ (void)saveStartImage:(UIImage *)image
{
    if (image == nil)
        return;
    
    [self clearStartImage];
    
    startImage = image;
    
    NSData *data = UIImageJPEGRepresentation(image, 0.8f);
    [data writeToFile:[self _startImagePath] atomically:true];
}

+ (void)clearStartImage
{
    startImage = nil;
    [[NSFileManager defaultManager] removeItemAtPath:[self _startImagePath] error:NULL];
}

+ (void)requestCameraAccess:(void (^)(bool granted, bool wasNotDetermined))resultBlock
{
    if (iosMajorVersion() < 7)
    {
        if (resultBlock != nil)
            resultBlock(true, false);
        return;
    }
    
    bool wasNotDetermined = ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo] == AVAuthorizationStatusNotDetermined);
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted)
    {
        TGDispatchOnMainThread(^
        {
            if (resultBlock != nil)
                resultBlock(granted, wasNotDetermined);
        });
    }];
}

+ (void)requestMicrophoneAccess:(void (^)(bool granted, bool wasNotDetermined))resultBlock
{
    if (iosMajorVersion() < 7)
    {
        if (resultBlock != nil)
            resultBlock(true, false);
        return;
    }
    
    bool wasNotDetermined = ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio] == AVAuthorizationStatusNotDetermined);
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted)
    {
        TGDispatchOnMainThread(^
        {
            if (resultBlock != nil)
                resultBlock(granted, wasNotDetermined);
        });
    }];
}

#pragma mark - Scrubbing

- (NSTimeInterval)videoScrubberDuration:(TGVideoMessageScrubber *)__unused videoScrubber
{
    return _duration;
}

- (void)videoScrubberDidBeginScrubbing:(TGVideoMessageScrubber *)__unused videoScrubber
{
}

- (void)videoScrubberDidEndScrubbing:(TGVideoMessageScrubber *)__unused videoScrubber
{
}

- (void)videoScrubber:(TGVideoMessageScrubber *)__unused videoScrubber valueDidChange:(NSTimeInterval)__unused position
{
}

#pragma mark - Trimming

- (void)videoScrubberDidBeginEditing:(TGVideoMessageScrubber *)__unused videoScrubber
{
    [_player pause];
}

- (void)videoScrubberDidEndEditing:(TGVideoMessageScrubber *)videoScrubber endValueChanged:(bool)endValueChanged
{
    [self updatePlayerRange:videoScrubber.trimEndValue];
    
    if (endValueChanged)
        [self _seekToPosition:videoScrubber.trimStartValue];
    
    [_player play];
}

- (void)videoScrubber:(TGVideoMessageScrubber *)__unused videoScrubber editingStartValueDidChange:(NSTimeInterval)startValue
{
    [self _seekToPosition:startValue];
}

- (void)videoScrubber:(TGVideoMessageScrubber *)__unused videoScrubber editingEndValueDidChange:(NSTimeInterval)endValue
{
   [self _seekToPosition:endValue];
}

- (void)updatePlayerRange:(NSTimeInterval)trimEndValue
{
    _player.currentItem.forwardPlaybackEndTime = CMTimeMakeWithSeconds(trimEndValue, NSEC_PER_SEC);
}

#pragma mark - Thumbnails

- (CGFloat)videoScrubberThumbnailAspectRatio:(TGVideoMessageScrubber *)__unused videoScrubber
{
    return 1.0f;
}

- (NSArray *)videoScrubber:(TGVideoMessageScrubber *)videoScrubber evenlySpacedTimestamps:(NSInteger)count startingAt:(NSTimeInterval)startTimestamp endingAt:(NSTimeInterval)endTimestamp
{
    if (endTimestamp < startTimestamp)
        return nil;
    
    if (count == 0)
        return nil;
    
    NSTimeInterval duration = [self videoScrubberDuration:videoScrubber];
    if (endTimestamp > duration)
        endTimestamp = duration;
    
    NSTimeInterval interval = (endTimestamp - startTimestamp) / count;
    
    NSMutableArray *timestamps = [[NSMutableArray alloc] init];
    for (NSInteger i = 0; i < count; i++)
        [timestamps addObject:@(startTimestamp + i * interval)];
    
    return timestamps;
}

- (NSArray *)thumbnailsForTimestamps:(NSArray *)timestamps
{
    NSArray *thumbnailTimestamps = [_thumbnails.allKeys sortedArrayUsingSelector:@selector(compare:)];
    NSMutableArray *thumbnails = [[NSMutableArray alloc] init];
    
    __block NSUInteger i = 1;
    [timestamps enumerateObjectsUsingBlock:^(NSNumber *timestampVal, __unused NSUInteger index, __unused BOOL *stop)
    {
        NSTimeInterval timestamp = timestampVal.doubleValue;
        NSNumber *closestTimestamp = [self closestTimestampForTimestamp:timestamp timestamps:thumbnailTimestamps start:i finalIndex:&i];
        if (closestTimestamp != nil) {
            [thumbnails addObject:_thumbnails[closestTimestamp]];
        }
    }];
    
    return thumbnails;
}

- (NSNumber *)closestTimestampForTimestamp:(NSTimeInterval)timestamp timestamps:(NSArray *)timestamps start:(NSUInteger)start finalIndex:(NSUInteger *)finalIndex
{
    if (start >= timestamps.count) {
        return nil;
    }
    NSTimeInterval leftTimestamp = [timestamps[start - 1] doubleValue];
    NSTimeInterval rightTimestamp = [timestamps[start] doubleValue];
    
    if (fabs(leftTimestamp - timestamp) < fabs(rightTimestamp - timestamp))
    {
        *finalIndex = start;
        return timestamps[start - 1];
    }
    else
    {
        if (start == timestamps.count - 1)
        {
            *finalIndex = start;
            return timestamps[start];
        }
        
        return [self closestTimestampForTimestamp:timestamp timestamps:timestamps start:start + 1 finalIndex:finalIndex];
    }
}

- (void)videoScrubber:(TGVideoMessageScrubber *)__unused videoScrubber requestThumbnailImagesForTimestamps:(NSArray *)timestamps size:(CGSize)__unused size isSummaryThumbnails:(bool)isSummaryThumbnails
{
    if (timestamps.count == 0)
        return;
    
    NSArray *thumbnails = [self thumbnailsForTimestamps:timestamps];
    [thumbnails enumerateObjectsUsingBlock:^(UIImage *image, NSUInteger index, __unused BOOL *stop)
    {
        if (index < timestamps.count)
            [_controlsView.scrubberView setThumbnailImage:image forTimestamp:[timestamps[index] doubleValue] isSummaryThubmnail:isSummaryThumbnails];
    }];
}

- (void)videoScrubberDidFinishRequestingThumbnails:(TGVideoMessageScrubber *)__unused videoScrubber
{
    [_controlsView showScrubberView];
}

- (void)videoScrubberDidCancelRequestingThumbnails:(TGVideoMessageScrubber *)__unused videoScrubber
{
}

- (CGSize)videoScrubberOriginalSize:(TGVideoMessageScrubber *)__unused videoScrubber cropRect:(CGRect *)cropRect cropOrientation:(UIImageOrientation *)cropOrientation cropMirrored:(bool *)cropMirrored
{
    if (cropRect != NULL)
        *cropRect = CGRectMake(0.0f, 0.0f, 240.0f, 240.0f);
    
    if (cropOrientation != NULL)
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
            *cropOrientation = UIImageOrientationUp;
        else if (self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
            *cropOrientation = UIImageOrientationRight;
        else if (self.interfaceOrientation == UIInterfaceOrientationLandscapeRight)
            *cropOrientation = UIImageOrientationLeft;
#pragma clang diagnostic pop
    }
    
    if (cropMirrored != NULL)
        *cropMirrored = false;
    
    return CGSizeMake(240.0f, 240.0f);
}

- (UIView *)extractVideoContent {
    UIView *result = [_circleView snapshotViewAfterScreenUpdates:false];
    result.frame = [_circleView convertRect:_circleView.bounds toView:nil];
    return result;
}

- (void)hideVideoContent {
    _circleWrapperView.alpha = 0.02f;
}

@end


@implementation TGVideoMessageCaptureControllerWindow

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    bool flag = [super pointInside:point withEvent:event];
    if (_locked)
    {
        if (point.x >= self.frame.size.width - 60.0f && point.y >= self.controlsFrame.origin.y && point.y < CGRectGetMaxY(self.controlsFrame))
            return false;
    }
    return flag;
}

@end
