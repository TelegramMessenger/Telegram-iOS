#import "TGCameraMainPhoneView.h"

#import <SSignalKit/SSignalKit.h>
#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"
#import "TGFont.h"

#import <LegacyComponents/UIControl+HitTestEdgeInsets.h>

#import <LegacyComponents/TGPhotoEditorUtils.h>
#import <LegacyComponents/TGCameraInterfaceAssets.h>
#import <LegacyComponents/TGTimerTarget.h>

#import "TGModernButton.h"
#import "TGCameraShutterButton.h"
#import "TGCameraModeControl.h"
#import "TGCameraFlashControl.h"
#import "TGCameraFlashActiveView.h"
#import "TGCameraFlipButton.h"
#import "TGCameraTimeCodeView.h"
#import "TGCameraZoomView.h"
#import "TGCameraToastView.h"

#import "TGMenuView.h"

#import "TGMediaPickerPhotoCounterButton.h"
#import "TGMediaPickerPhotoStripView.h"

@interface TGCameraTopPanelView : UIView

@property (nonatomic, copy) bool(^isPointInside)(CGPoint point);

@end

@implementation TGCameraTopPanelView

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    if (self.hidden)
        return [super pointInside:point withEvent:event];
    
    CGRect relativeFrame = self.bounds;
    bool insideBounds = CGRectContainsPoint(relativeFrame, point);
    
    bool additionalCheck = false;
    if (self.isPointInside != nil)
        additionalCheck = self.isPointInside(point);
    
    return insideBounds || additionalCheck;
}

@end

@interface TGCameraMainPhoneView () <ASWatcher>
{
    TGCameraTopPanelView *_topPanelView;
    UIView *_topPanelBackgroundView;
    UIView *_bottomPanelView;
    UIView *_bottomPanelBackgroundView;
    
    UIView *_topDocumentFrameView;
    UIView *_bottomDocumentFrameView;
    
    UIView *_videoLandscapePanelView;
    
    TGCameraFlashControl *_flashControl;
    
    TGCameraSmallFlipButton *_topFlipButton;
            
    bool _hasResults;
    
    CGFloat _topPanelOffset;
    CGFloat _topPanelHeight;
    
    CGFloat _bottomPanelOffset;
    CGFloat _bottomPanelHeight;
    
    CGFloat _modeControlOffset;
    CGFloat _modeControlHeight;
    
    CGFloat _counterOffset;
    
    bool _displayedTooltip;
    TGMenuContainerView *_tooltipContainerView;
    NSTimer *_tooltipTimer;
    
    int _dismissingWheelCounter;
}
@end

@implementation TGCameraMainPhoneView

@synthesize requestedVideoRecordingDuration;
@synthesize cameraFlipped;
@synthesize cameraModeChanged;
@synthesize flashModeChanged;
@synthesize focusPointChanged;
@synthesize expositionChanged;
@synthesize shutterPressed;
@synthesize shutterReleased;
@synthesize cancelPressed;
@synthesize actionHandle = _actionHandle;

- (instancetype)initWithFrame:(CGRect)frame avatar:(bool)avatar hasUltrawideCamera:(bool)hasUltrawideCamera hasTelephotoCamera:(bool)hasTelephotoCamera
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _dismissingWheelCounter = 0;
        
        CGFloat shutterButtonWidth = 66.0f;
        CGSize screenSize = TGScreenSize();
        CGFloat widescreenWidth = MAX(screenSize.width, screenSize.height);
        if (widescreenWidth == 926.0f)
        {
            _topPanelOffset = 34.0f;
            _topPanelHeight = 48.0f;
            _bottomPanelOffset = 94.0f;
            _bottomPanelHeight = 140.0f;
            _modeControlOffset = -2.0f;
            _modeControlHeight = 66.0f;
            _counterOffset = 7.0f;
            shutterButtonWidth = 72.0f;
        }
        else if (widescreenWidth == 896.0f)
        {
            _topPanelOffset = 33.0f;
            _topPanelHeight = 44.0f;
            _bottomPanelOffset = 94.0f;
            _bottomPanelHeight = 123.0f;
            _modeControlOffset = -5.0f;
            _modeControlHeight = 56.0f;
            _counterOffset = 7.0f;
            shutterButtonWidth = 72.0f;
        }
        else if (widescreenWidth == 844.0f)
        {
            _topPanelOffset = 33.0f;
            _topPanelHeight = 44.0f;
            _bottomPanelOffset = 63.0f;
            _bottomPanelHeight = 128.0f;
            _modeControlOffset = 3.0f;
            _modeControlHeight = 40.0f;
            _counterOffset = 7.0f;
            shutterButtonWidth = 70.0f;
        }
        else if (widescreenWidth == 812.0f)
        {
            _topPanelOffset = 33.0f;
            _topPanelHeight = 44.0f;
            _bottomPanelOffset = 63.0f;
            _bottomPanelHeight = 123.0f;
            _modeControlOffset = 3.0f;
            _modeControlHeight = 40.0f;
            _counterOffset = 7.0f;
            shutterButtonWidth = 70.0f;
        }
        else if (widescreenWidth >= 736.0f - FLT_EPSILON)
        {
            _topPanelHeight = 44.0f;
            _bottomPanelHeight = 129.0f;
            _modeControlHeight = 50.0f;
            _counterOffset = 8.0f;
            shutterButtonWidth = 70.0f;
        }
        else if (widescreenWidth >= 667.0f - FLT_EPSILON)
        {
            _topPanelHeight = 44.0f;
            _bottomPanelHeight = 123.0f;
            _modeControlOffset = 4.0f;
            _modeControlHeight = 36.0f;
            _counterOffset = 6.0f;
            shutterButtonWidth = 70.0f;
        }
        else
        {
            _topPanelHeight = 40.0f;
            _bottomPanelHeight = 101.0f;
            _modeControlHeight = 31.0f;
            _counterOffset = 8.0f;
        }
        
        __weak TGCameraMainPhoneView *weakSelf = self;
        
        _topPanelView = [[TGCameraTopPanelView alloc] init];
        _topPanelView.clipsToBounds = false;
        _topPanelView.isPointInside = ^bool(CGPoint point)
        {
            __strong TGCameraMainPhoneView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return false;
            
            CGRect rect = [strongSelf->_topPanelView convertRect:strongSelf->_flashControl.frame fromView:strongSelf->_flashControl.superview];
            return CGRectContainsPoint(rect, point);
        };
        [self addSubview:_topPanelView];
        
        _topPanelBackgroundView = [[UIView alloc] initWithFrame:_topPanelView.bounds];
        _topPanelBackgroundView.backgroundColor = [TGCameraInterfaceAssets transparentPanelBackgroundColor];
        [_topPanelView addSubview:_topPanelBackgroundView];
        
        _zoomModeView = [[TGCameraZoomModeView alloc] initWithFrame:CGRectMake(floor((frame.size.width - 129.0) / 2.0), frame.size.height - _bottomPanelHeight - _bottomPanelOffset - 18 - 43, 129, 43) hasUltrawideCamera:hasUltrawideCamera hasTelephotoCamera:hasTelephotoCamera minZoomLevel:hasUltrawideCamera ? 0.5 : 1.0 maxZoomLevel:8.0];
        _zoomModeView.zoomChanged = ^(CGFloat zoomLevel, bool done, bool animated) {
            __strong TGCameraMainPhoneView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (done) {
                [strongSelf->_zoomWheelView setZoomLevel:zoomLevel];
                [strongSelf->_zoomModeView setZoomLevel:zoomLevel animated:false];
                
                if (!strongSelf->_zoomWheelView.isHidden) {
                    NSInteger counter = strongSelf->_dismissingWheelCounter + 1;
                    strongSelf->_dismissingWheelCounter = (int)counter;
                    
                    TGDispatchAfter(1.5, dispatch_get_main_queue(), ^{
                        if (strongSelf->_dismissingWheelCounter == counter) {
                            [strongSelf->_zoomModeView setHidden:false animated:true];
                            [strongSelf->_zoomWheelView setHidden:true animated:true];
                        }
                    });
                }
            } else {
                NSInteger counter = strongSelf->_dismissingWheelCounter + 1;
                strongSelf->_dismissingWheelCounter = (int)counter;
                [strongSelf->_zoomWheelView setZoomLevel:zoomLevel panning:true];
                [strongSelf->_zoomModeView setHidden:true animated:true];
                [strongSelf->_zoomWheelView setHidden:false animated:true];
            }
            
            if (strongSelf.zoomChanged != nil)
                strongSelf.zoomChanged(zoomLevel, animated);
        };
        [_zoomModeView setZoomLevel:1.0];
        if (hasTelephotoCamera || hasUltrawideCamera) {
            [self addSubview:_zoomModeView];
        }
        
        _zoomWheelView = [[TGCameraZoomWheelView alloc] initWithFrame:CGRectMake(0.0, frame.size.height - _bottomPanelHeight - _bottomPanelOffset - 132, frame.size.width, 132) hasUltrawideCamera:hasUltrawideCamera hasTelephotoCamera:hasTelephotoCamera];
        [_zoomWheelView setHidden:true animated:false];
        [_zoomWheelView setZoomLevel:1.0];
        _zoomWheelView.panGesture = ^(UIPanGestureRecognizer *gestureRecognizer) {
            __strong TGCameraMainPhoneView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            [strongSelf->_zoomModeView panGesture:gestureRecognizer];
        };
        if (hasTelephotoCamera || hasUltrawideCamera) {
            [self addSubview:_zoomWheelView];
        }
        
        _zoomView = [[TGCameraZoomView alloc] initWithFrame:CGRectMake(10, frame.size.height - _bottomPanelHeight - _bottomPanelOffset - 18, frame.size.width - 20, 1.5f)];
        _zoomView.activityChanged = ^(bool active)
        {
        };
        if (!hasTelephotoCamera && !hasUltrawideCamera) {
            [self addSubview:_zoomView];
        }
        
        _bottomPanelView = [[UIView alloc] init];
        [self addSubview:_bottomPanelView];
        
        _bottomPanelBackgroundView = [[UIView alloc] initWithFrame:_bottomPanelView.bounds];
        _bottomPanelBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _bottomPanelBackgroundView.backgroundColor = [TGCameraInterfaceAssets transparentPanelBackgroundColor];
        [_bottomPanelView addSubview:_bottomPanelBackgroundView];
        
        _cancelButton = [[TGCameraCancelButton alloc] initWithFrame:CGRectMake(0, 0, 48, 48)];
        [_cancelButton addTarget:self action:@selector(cancelButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_bottomPanelView addSubview:_cancelButton];
        
        _doneButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0, 0, 60, 44)];
        _doneButton.backgroundColor = [UIColor clearColor];
        _doneButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
        _doneButton.exclusiveTouch = true;
        _doneButton.hidden = true;
        _doneButton.titleLabel.font = TGMediumSystemFontOfSize(18);
        _doneButton.contentEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 20);
        [_doneButton setTitle:TGLocalized(@"Common.Done") forState:UIControlStateNormal];
        [_doneButton setTintColor:[TGCameraInterfaceAssets normalColor]];
        [_doneButton sizeToFit];
        _doneButton.frame = CGRectMake(0, 0, MAX(60.0f, _doneButton.frame.size.width), 44);
        [_doneButton addTarget:self action:@selector(doneButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_bottomPanelView addSubview:_doneButton];
        
        UIPanGestureRecognizer *shutterPanGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(shutterButtonPanGesture:)];
        _shutterButton = [[TGCameraShutterButton alloc] initWithFrame:CGRectMake((frame.size.width - shutterButtonWidth) / 2, 10, shutterButtonWidth, shutterButtonWidth)];
        [_shutterButton addTarget:self action:@selector(shutterButtonReleased) forControlEvents:UIControlEventTouchUpInside];
        [_shutterButton addTarget:self action:@selector(shutterButtonPressed) forControlEvents:UIControlEventTouchDown];
        [_shutterButton addGestureRecognizer:shutterPanGestureRecognizer];
        [_bottomPanelView addSubview:_shutterButton];
        
        _modeControl = [[TGCameraModeControl alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, _modeControlHeight) avatar:avatar];
        [_bottomPanelView addSubview:_modeControl];
        
        _flipButton = [[TGCameraFlipButton alloc] initWithFrame:CGRectMake(0, 0, 48, 48)];
        [_flipButton addTarget:self action:@selector(flipButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_bottomPanelView addSubview:_flipButton];
        
        _flashControl = [[TGCameraFlashControl alloc] initWithFrame:CGRectMake(3.0, 0, TGCameraFlashControlHeight, TGCameraFlashControlHeight)];
        [_topPanelView addSubview:_flashControl];
        
        _topFlipButton = [[TGCameraSmallFlipButton alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
        _topFlipButton.hidden = true;
        [_topFlipButton addTarget:self action:@selector(flipButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_topPanelView addSubview:_topFlipButton];
        
        _timecodeView = [[TGCameraTimeCodeView alloc] initWithFrame:CGRectMake((frame.size.width - 120) / 2, 12, 120, 28)];
        _timecodeView.alpha = 0.0;
        _timecodeView.requestedRecordingDuration = ^NSTimeInterval
        {
            __strong TGCameraMainPhoneView *strongSelf = weakSelf;
            if (strongSelf == nil || strongSelf.requestedVideoRecordingDuration == nil)
                return 0.0;
            
            return strongSelf.requestedVideoRecordingDuration();
        };
        _timecodeView.userInteractionEnabled = false;
        [_topPanelView addSubview:_timecodeView];
        
        _videoLandscapePanelView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 274, 44)];
        _videoLandscapePanelView.alpha = 0.0f;
        _videoLandscapePanelView.hidden = true;
        [self addSubview:_videoLandscapePanelView];
        
        _toastView = [[TGCameraToastView alloc] initWithFrame:CGRectMake(0, frame.size.height - _bottomPanelHeight - 42, frame.size.width, 32)];
        _toastView.userInteractionEnabled = false;
        [self addSubview:_toastView];
        
        _flashControl.modeChanged = ^(PGCameraFlashMode mode)
        {
            __strong TGCameraMainPhoneView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (strongSelf.flashModeChanged != nil)
                strongSelf.flashModeChanged(mode);
        };
        
        _modeControl.modeChanged = ^(PGCameraMode mode, PGCameraMode previousMode)
        {
            __strong TGCameraMainPhoneView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            bool change = true;
            if (strongSelf.cameraShouldLeaveMode != nil)
                change = strongSelf.cameraShouldLeaveMode(previousMode);
            
            void (^changeBlock)(void) = ^
            {
                if (strongSelf.cameraModeChanged != nil)
                    strongSelf.cameraModeChanged(mode);
                
                [strongSelf updateForCameraModeChangeWithPreviousMode:previousMode];
            };
            
            changeBlock();
        };
        
        
        _selectedPhotosView = [[TGMediaPickerPhotoStripView alloc] initWithFrame:CGRectZero];
        _selectedPhotosView.interfaceOrientation = UIInterfaceOrientationPortrait;
        _selectedPhotosView.removable = true;
        _selectedPhotosView.itemSelected = ^(NSInteger index)
        {
            __strong TGCameraMainPhoneView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf->_photoCounterButton setSelected:false animated:true];
            [strongSelf->_selectedPhotosView setHidden:true animated:true];
            
            if (strongSelf.resultPressed != nil)
                strongSelf.resultPressed(index);
        };
        _selectedPhotosView.itemRemoved = ^(NSInteger index)
        {
            __strong TGCameraMainPhoneView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (strongSelf.itemRemoved != nil)
                strongSelf.itemRemoved(index);
        };
        _selectedPhotosView.hidden = true;
        [self addSubview:_selectedPhotosView];
    
        _photoCounterButton = [[TGMediaPickerPhotoCounterButton alloc] initWithFrame:CGRectMake(0, 0, 64, 38)];
        [_photoCounterButton addTarget:self action:@selector(photoCounterButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        _photoCounterButton.userInteractionEnabled = false;
        [_bottomPanelView addSubview:_photoCounterButton];
    }
    return self;
}

- (void)dealloc
{
     [_actionHandle reset];
}

- (void)setResults:(NSArray *)results
{
    if (results.count == 0)
    {
        _hasResults = false;
        _topFlipButton.hidden = true;
        _flipButton.hidden = false;
        _doneButton.hidden = true;
    }
    else
    {
        _hasResults = true;
        _topFlipButton.hidden = _modeControl.cameraMode == PGCameraModePhotoScan;
        _flipButton.hidden = true;
        _doneButton.hidden = false;
        if (_modeControl.cameraMode == PGCameraModePhotoScan) {
            _modeControl.hidden = true;
        }
    }
}

- (void)setupTooltip
{
    bool displayed = [[[NSUserDefaults standardUserDefaults] objectForKey:@"TG_displayedCameraHoldToVideoTooltip_v0"] boolValue];
    if (displayed)
        return;

    if (_tooltipContainerView != nil)
        return;
    
    _tooltipTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(tooltipTimerTick) interval:2.5 repeat:false];
    
    _tooltipContainerView = [[TGMenuContainerView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.frame.size.width, self.frame.size.height)];
    [self addSubview:_tooltipContainerView];
    
    NSMutableArray *actions = [[NSMutableArray alloc] init];
    [actions addObject:[[NSDictionary alloc] initWithObjectsAndKeys:TGLocalized(@"Camera.TapAndHoldForVideo"), @"title", nil]];
    
    [_tooltipContainerView.menuView setButtonsAndActions:actions watcherHandle:_actionHandle];
    [_tooltipContainerView.menuView sizeToFit];
    _tooltipContainerView.menuView.buttonHighlightDisabled = true;
    
    CGRect frame = [_shutterButton convertRect:_shutterButton.bounds toView:self];
    frame = CGRectOffset(frame, 0.0f, 1.0f);
    [_tooltipContainerView showMenuFromRect:frame animated:false];
    
    [[NSUserDefaults standardUserDefaults] setObject:@true forKey:@"TG_displayedCameraHoldToVideoTooltip_v0"];
}

- (void)tooltipTimerTick
{
    [_tooltipTimer invalidate];
    _tooltipTimer = nil;
    
    [_tooltipContainerView hideMenu];
}

- (void)actionStageActionRequested:(NSString *)action options:(id)__unused options
{
    if ([action isEqualToString:@"menuAction"])
    {
        [_tooltipTimer invalidate];
        _tooltipTimer = nil;
        
        [_tooltipContainerView hideMenu];
    }
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *view = [super hitTest:point withEvent:event];
    
    if (!_zoomModeView.isHidden && CGRectContainsPoint(_zoomModeView.frame, point)) {
        CGPoint zoomPoint = [self convertPoint:point toView:_zoomModeView];
        return [_zoomModeView hitTest:zoomPoint withEvent:event];
    }
    
    if ([view isDescendantOfView:_topPanelView] || [view isDescendantOfView:_bottomPanelView] || [view isDescendantOfView:_videoLandscapePanelView] || [view isDescendantOfView:_tooltipContainerView] || [view isDescendantOfView:_selectedPhotosView] || [view isDescendantOfView:_zoomModeView] || view == _zoomModeView || (view == _zoomWheelView && !_zoomWheelView.isHidden))
        return view;
    
    return nil;
}

#pragma mark - Actions

- (void)updateForCameraModeChangeWithPreviousMode:(PGCameraMode)previousMode
{
    [super updateForCameraModeChangeWithPreviousMode:previousMode];
    
    UIInterfaceOrientation orientation = _interfaceOrientation;
    PGCameraMode cameraMode = _modeControl.cameraMode;
    
    if (previousMode == PGCameraModePhoto && cameraMode == PGCameraModeVideo) {
        [UIView animateWithDuration:0.25f delay:0.0f options:UIViewAnimationOptionCurveLinear animations:^
        {
            _timecodeView.alpha = 1.0;
            _bottomPanelBackgroundView.alpha = 0.0;
        } completion:nil];
    } else if (previousMode == PGCameraModeVideo && cameraMode == PGCameraModePhoto) {
        [UIView animateWithDuration:0.25f delay:0.0f options:UIViewAnimationOptionCurveLinear animations:^
        {
            _timecodeView.alpha = 0.0;
        } completion:nil];
        [UIView animateWithDuration:0.25f delay:1.5f options:UIViewAnimationOptionCurveLinear animations:^
        {
            _bottomPanelBackgroundView.alpha = 1.0;
        } completion:nil];
    }
    if (UIInterfaceOrientationIsLandscape(orientation) && !((cameraMode == PGCameraModePhoto && previousMode == PGCameraModeSquarePhoto) || (cameraMode == PGCameraModeSquarePhoto && previousMode == PGCameraModePhoto)))
    {
        [UIView animateWithDuration:0.25f delay:0.0f options:UIViewAnimationOptionCurveLinear animations:^
        {
            _videoLandscapePanelView.alpha = 0.0f;
        } completion:^(__unused BOOL finished)
        {
            if (cameraMode == PGCameraModeVideo)
            {
                _flashControl.transform = CGAffineTransformIdentity;
                _flashControl.interfaceOrientation = UIInterfaceOrientationPortrait;
                [self _layoutTopPanelViewForInterfaceOrientation:orientation];
            }
            else
            {
                _flashControl.transform = CGAffineTransformMakeRotation(TGRotationForInterfaceOrientation(orientation));
                _flashControl.interfaceOrientation = orientation;
                [self _layoutTopPanelViewForInterfaceOrientation:UIInterfaceOrientationPortrait];
            }
             
            if (cameraMode == PGCameraModeVideo)
                [self _attachControlsToLandscapePanel];
            else
                [self _attachControlsToTopPanel];
            
            [self _layoutTopPanelSubviewsForInterfaceOrientation:orientation];
            
            [UIView animateWithDuration:0.2f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^
            {
                if (cameraMode == PGCameraModeVideo)
                    _videoLandscapePanelView.alpha = 1.0f;
            } completion:nil];
        }];
    }
}

#pragma mark - Flash

- (void)setFlashMode:(PGCameraFlashMode)mode
{
    [_flashControl setMode:mode];
}

- (void)setFlashActive:(bool)active
{
    [_flashControl setFlashActive:active];
}

- (void)setFlashUnavailable:(bool)unavailable
{
    [_flashControl setFlashUnavailable:unavailable];
}

- (void)setHasFlash:(bool)hasFlash
{
    [_flashControl setHidden:!hasFlash animated:true];
}

#pragma mark -

- (void)setDocumentFrameHidden:(bool)hidden
{
    if (!hidden)
    {
        if (_topDocumentFrameView == nil)
        {
            _topDocumentFrameView = [[UIView alloc] init];
            _topDocumentFrameView.backgroundColor = [TGCameraInterfaceAssets transparentOverlayBackgroundColor];
            [self addSubview:_topDocumentFrameView];
            
            _bottomDocumentFrameView = [[UIView alloc] init];
            _bottomDocumentFrameView.backgroundColor = [TGCameraInterfaceAssets transparentOverlayBackgroundColor];
            [self addSubview:_bottomDocumentFrameView];
            
            [self setNeedsLayout];
        }
    }
    else
    {
        _topDocumentFrameView.hidden = true;
        _bottomDocumentFrameView.hidden = true;
    }
}

#pragma mark - Layout

- (void)setInterfaceHiddenForVideoRecording:(bool)hidden animated:(bool)animated
{
    bool hasDoneButton = _hasResults;
    
    _zoomWheelView.clipsToBounds = !hidden;
    
    if (animated)
    {
        if (!hidden)
        {
            _modeControl.hidden = false;
            _cancelButton.hidden = false;
            _flashControl.hidden = false;
            _flipButton.hidden = hasDoneButton;
            _topFlipButton.hidden = !hasDoneButton;
        }
        
        [UIView animateWithDuration:0.2 delay:0.0 options:7 << 16 animations:^{
            CGFloat offset = hidden ? 19 : 18 + 43;
            _zoomModeView.frame = CGRectMake(floor((self.bounds.size.width - 129.0) / 2.0), self.bounds.size.height - _bottomPanelHeight - _bottomPanelOffset - offset, 129, 43);
        } completion:nil];
        
        [UIView animateWithDuration:0.25 animations:^
        {
            CGFloat alpha = hidden ? 0.0f : 1.0f;
            _modeControl.alpha = alpha;
            _cancelButton.alpha = alpha;
            _flashControl.alpha = alpha;
            _flipButton.alpha = alpha;
            _topFlipButton.alpha = alpha;
            
            if (hasDoneButton)
                _doneButton.alpha = alpha;
        } completion:^(BOOL finished)
        {
            if (finished)
            {
                _modeControl.hidden = hidden;
                _cancelButton.hidden = hidden;
                _flashControl.hidden = hidden;
                _flipButton.hidden = hidden || hasDoneButton;
                _topFlipButton.hidden = hidden || !hasDoneButton;
                
                if (hasDoneButton)
                    _doneButton.hidden = hidden;
            }
        }];
    }
    else
    {
        [_modeControl setHidden:hidden animated:false];
        
        CGFloat alpha = hidden ? 0.0f : 1.0f;
        _modeControl.hidden = hidden;
        _modeControl.alpha = alpha;
        _cancelButton.hidden = hidden;
        _cancelButton.alpha = alpha;
        _flashControl.hidden = hidden;
        _flashControl.alpha = alpha;
        _flipButton.hidden = hidden || hasDoneButton;
        _flipButton.alpha = alpha;
        _topFlipButton.hidden = hidden || !hasDoneButton;
        _topFlipButton.alpha = alpha;
        
        CGFloat offset = hidden ? 19 : 18 + 43;
        _zoomModeView.frame = CGRectMake(floor((self.bounds.size.width - 129.0) / 2.0), self.bounds.size.height - _bottomPanelHeight - _bottomPanelOffset - offset, 129, 43);
        
        if (hasDoneButton)
        {
            _doneButton.hidden = hidden;
            _doneButton.alpha = alpha;
        }
    }
    
    if (hidden && _photoCounterButton.selected)
    {
        [_photoCounterButton setSelected:false animated:true];
        [_selectedPhotosView setHidden:true animated:true];
    }
    [_photoCounterButton setHidden:hidden animated:animated];
}

- (void)setInterfaceOrientation:(UIInterfaceOrientation)orientation animated:(bool)animated
{
    if (orientation == UIInterfaceOrientationUnknown || orientation == _interfaceOrientation)
        return;
 
    _interfaceOrientation = orientation;
    
    if (animated)
    {
        [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^
        {
            if (_modeControl.cameraMode == PGCameraModeVideo)
            {
                _videoLandscapePanelView.alpha = 0.0f;
            }
            
            _flipButton.transform = CGAffineTransformMakeRotation(TGRotationForInterfaceOrientation(orientation));
            _flashControl.transform = CGAffineTransformMakeRotation(TGRotationForInterfaceOrientation(orientation));
            _zoomModeView.interfaceOrientation = orientation;
            _timecodeView.interfaceOrientation = orientation;
            _zoomWheelView.interfaceOrientation = orientation;
            _topFlipButton.transform = CGAffineTransformMakeRotation(TGRotationForInterfaceOrientation(orientation));
        } completion:^(__unused BOOL finished)
        {
            if (_modeControl.cameraMode == PGCameraModeVideo)
            {
                [self _layoutTopPanelViewForInterfaceOrientation:orientation];
                
                if (UIInterfaceOrientationIsLandscape(orientation))
                    [self _attachControlsToLandscapePanel];
                else
                    [self _attachControlsToTopPanel];
            }
            
            [self _layoutTopPanelSubviewsForInterfaceOrientation:orientation];
            
            [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^
            {
                if (_modeControl.cameraMode == PGCameraModeVideo)
                {
                    if (UIInterfaceOrientationIsLandscape(orientation))
                        _videoLandscapePanelView.alpha = 1.0f;
                }
            } completion:nil];
        }];
    }
    else
    {
        _flipButton.transform = CGAffineTransformMakeRotation(TGRotationForInterfaceOrientation(orientation));
        _flashControl.transform = CGAffineTransformMakeRotation(TGRotationForInterfaceOrientation(orientation));
        _zoomModeView.interfaceOrientation = orientation;
        _timecodeView.interfaceOrientation = orientation;
        _zoomWheelView.interfaceOrientation = orientation;
        _topFlipButton.transform = CGAffineTransformMakeRotation(TGRotationForInterfaceOrientation(orientation));
        
        [self _layoutTopPanelSubviewsForInterfaceOrientation:orientation];
    }
}

- (void)_layoutTopPanelViewForInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    CGAffineTransform transform = CGAffineTransformMakeRotation(TGRotationForInterfaceOrientation(orientation));
    
    switch (orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
        {
            _videoLandscapePanelView.hidden = false;
            
            _videoLandscapePanelView.transform = transform;
            _videoLandscapePanelView.frame = CGRectMake(3, (self.frame.size.height - _videoLandscapePanelView.frame.size.height) / 2, _videoLandscapePanelView.frame.size.width, _videoLandscapePanelView.frame.size.height);
        }
            break;
        case UIInterfaceOrientationLandscapeRight:
        {
            _videoLandscapePanelView.hidden = false;
            
            _videoLandscapePanelView.transform = transform;
            _videoLandscapePanelView.frame = CGRectMake(self.frame.size.width - _videoLandscapePanelView.frame.size.width - 3, (self.frame.size.height - _videoLandscapePanelView.frame.size.height) / 2, _videoLandscapePanelView.frame.size.width, _videoLandscapePanelView.frame.size.height);
        }
            break;
            
        case UIInterfaceOrientationPortraitUpsideDown:
        {
            _videoLandscapePanelView.hidden = true;
            
            _topPanelView.transform = transform;
            _topPanelView.frame = CGRectMake(0, _topPanelOffset, _topPanelView.frame.size.width, _topPanelView.frame.size.height);
        }
            break;
            
        default:
        {
            _videoLandscapePanelView.hidden = true;
            
            _topPanelView.transform = transform;
            _topPanelView.frame = CGRectMake(0, _topPanelOffset, _topPanelView.frame.size.width, _topPanelView.frame.size.height);
        }
            break;
    }
}

- (void)_attachControlsToTopPanel
{
    [_topPanelView addSubview:_timecodeView];
}

- (void)_attachControlsToLandscapePanel
{
    [_videoLandscapePanelView addSubview:_timecodeView];
}

- (void)_layoutTopPanelSubviewsForInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    UIView *superview = _timecodeView.superview;
    CGSize superviewSize = superview.frame.size;
    
    if (superview == _videoLandscapePanelView && superviewSize.width < superviewSize.height)
        superviewSize = CGSizeMake(superviewSize.height, superviewSize.width);
    
    _timecodeView.frame = CGRectMake((superviewSize.width - 120) / 2, (superviewSize.height - 28) / 2, 120, 28);
}

- (void)layoutSubviews
{
    _topPanelView.frame = CGRectMake(0, _topPanelOffset, self.frame.size.width, _topPanelHeight);
    _topPanelBackgroundView.frame = CGRectMake(0.0f, -_topPanelOffset, self.frame.size.width, _topPanelHeight + _topPanelOffset);
    [self _layoutTopPanelSubviewsForInterfaceOrientation:_interfaceOrientation];
    
    _bottomPanelView.frame = CGRectMake(0, self.frame.size.height - _bottomPanelHeight - _bottomPanelOffset, self.frame.size.width, _bottomPanelHeight + _bottomPanelOffset);
    
    CGFloat documentFrameHeight = self.frame.size.width * 0.704f;
    CGFloat documentTopEdge = CGRectGetMidY(self.previewViewFrame) - documentFrameHeight / 2.0f;
    CGFloat documentBottomEdge = CGRectGetMidY(self.previewViewFrame) + documentFrameHeight / 2.0f;
    
    _topDocumentFrameView.frame = CGRectMake(0.0f, CGRectGetMaxY(_topPanelView.frame), self.frame.size.width, documentTopEdge - CGRectGetMaxY(_topPanelView.frame));
    _bottomDocumentFrameView.frame = CGRectMake(0.0f, documentBottomEdge, self.frame.size.width, CGRectGetMinY(_bottomPanelView.frame) - documentBottomEdge);
    
    _modeControl.frame = CGRectMake(0, _modeControlOffset, self.frame.size.width, _modeControlHeight);
    _shutterButton.frame = CGRectMake(round((self.frame.size.width - _shutterButton.frame.size.width) / 2), _modeControlHeight + _modeControlOffset, _shutterButton.frame.size.width, _shutterButton.frame.size.height);
   
    _cancelButton.frame = CGRectMake(20.0,  round(_shutterButton.center.y - _cancelButton.frame.size.height / 2.0f), _cancelButton.frame.size.width, _cancelButton.frame.size.height);
   
    _doneButton.frame = CGRectMake(_bottomPanelView.frame.size.width - _doneButton.frame.size.width, round(_shutterButton.center.y - _doneButton.frame.size.height / 2.0f), _doneButton.frame.size.width, _doneButton.frame.size.height);
    
    _flipButton.frame = CGRectMake(self.frame.size.width - _flipButton.frame.size.width - 20.0f, round(_shutterButton.center.y - _flipButton.frame.size.height / 2.0f), _flipButton.frame.size.width, _flipButton.frame.size.height);
    
    _topFlipButton.frame = CGRectMake(self.frame.size.width - _topFlipButton.frame.size.width - 4.0f, 0.0f, _topFlipButton.frame.size.width, _topFlipButton.frame.size.height);
    
    _toastView.frame = CGRectMake(0, self.frame.size.height - _bottomPanelHeight - _bottomPanelOffset - 32 - 16, self.frame.size.width, 32);
    
    CGFloat photosViewSize = TGPhotoThumbnailSizeForCurrentScreen().height + 4 * 2;
    _photoCounterButton.frame = CGRectMake(self.frame.size.width - 56.0f - 10.0f, _counterOffset, 64, 38);
    _selectedPhotosView.frame = CGRectMake(4.0f, [_photoCounterButton convertRect:_photoCounterButton.bounds toView:self].origin.y - photosViewSize - 20.0f, self.frame.size.width - 4.0f * 2.0f, photosViewSize);
    
    if (!_displayedTooltip && _modeControl.superview != nil)
    {
        _displayedTooltip = true;
        [self setupTooltip];
    }
}

@end
