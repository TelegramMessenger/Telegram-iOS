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
#import "TGCameraSegmentsView.h"

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
    TGCameraFlashActiveView *_flashActiveView;
    
    TGCameraFlipButton *_topFlipButton;
    
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

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        CGFloat shutterButtonWidth = 66.0f;
        CGSize screenSize = TGScreenSize();
        CGFloat widescreenWidth = MAX(screenSize.width, screenSize.height);
        if (widescreenWidth == 896.0f)
        {
            _topPanelOffset = 33.0f;
            _topPanelHeight = 44.0f;
            _bottomPanelOffset = 94.0f;
            _bottomPanelHeight = 123.0f;
            _modeControlOffset = 0.0f;
            _modeControlHeight = 52.0f;
            _counterOffset = 7.0f;
            shutterButtonWidth = 72.0f;
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
            _bottomPanelHeight = 140.0f;
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
        
        _bottomPanelView = [[UIView alloc] init];
        [self addSubview:_bottomPanelView];
        
        _bottomPanelBackgroundView = [[UIView alloc] initWithFrame:_bottomPanelView.bounds];
        _bottomPanelBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _bottomPanelBackgroundView.backgroundColor = [TGCameraInterfaceAssets transparentPanelBackgroundColor];
        [_bottomPanelView addSubview:_bottomPanelBackgroundView];
        
        _cancelButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0, 0, 60, 44)];
        _cancelButton.backgroundColor = [UIColor clearColor];
        _cancelButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        _cancelButton.exclusiveTouch = true;
        _cancelButton.titleLabel.font = TGSystemFontOfSize(18);
        _cancelButton.contentEdgeInsets = UIEdgeInsetsMake(0, 20, 0, 0);
        [_cancelButton setTitle:TGLocalized(@"Common.Cancel") forState:UIControlStateNormal];
        [_cancelButton setTintColor:[TGCameraInterfaceAssets normalColor]];
        [_cancelButton sizeToFit];
        _cancelButton.frame = CGRectMake(0, 0, MAX(60.0f, _cancelButton.frame.size.width), 44);
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
        
        _shutterButton = [[TGCameraShutterButton alloc] initWithFrame:CGRectMake((frame.size.width - shutterButtonWidth) / 2, 10, shutterButtonWidth, shutterButtonWidth)];
        [_shutterButton addTarget:self action:@selector(shutterButtonReleased) forControlEvents:UIControlEventTouchUpInside];
        [_shutterButton addTarget:self action:@selector(shutterButtonPressed) forControlEvents:UIControlEventTouchDown];
        [_bottomPanelView addSubview:_shutterButton];
        
        _modeControl = [[TGCameraModeControl alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, _modeControlHeight)];
        [_bottomPanelView addSubview:_modeControl];
        
        _flipButton = [[TGCameraFlipButton alloc] initWithFrame:CGRectMake(0, 0, 56, 56) large:true];
        [_flipButton addTarget:self action:@selector(flipButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_bottomPanelView addSubview:_flipButton];
        
        _flashControl = [[TGCameraFlashControl alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, TGCameraFlashControlHeight)];
        [_topPanelView addSubview:_flashControl];
        
        _topFlipButton = [[TGCameraFlipButton alloc] initWithFrame:CGRectMake(0, 0, 44, 44) large:false];
        _topFlipButton.hidden = true;
        [_topFlipButton addTarget:self action:@selector(flipButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_topPanelView addSubview:_topFlipButton];
        
        _timecodeView = [[TGCameraTimeCodeView alloc] initWithFrame:CGRectMake((frame.size.width - 120) / 2, 12, 120, 20)];
        _timecodeView.hidden = true;
        _timecodeView.requestedRecordingDuration = ^NSTimeInterval
        {
            __strong TGCameraMainPhoneView *strongSelf = weakSelf;
            if (strongSelf == nil || strongSelf.requestedVideoRecordingDuration == nil)
                return 0.0;
            
            return strongSelf.requestedVideoRecordingDuration();
        };
        [_topPanelView addSubview:_timecodeView];
        
        _videoLandscapePanelView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 274, 44)];
        _videoLandscapePanelView.alpha = 0.0f;
        _videoLandscapePanelView.backgroundColor = [TGCameraInterfaceAssets transparentPanelBackgroundColor];
        _videoLandscapePanelView.hidden = true;
        _videoLandscapePanelView.layer.cornerRadius = 3.5f;
        [self addSubview:_videoLandscapePanelView];
        
        _flashActiveView = [[TGCameraFlashActiveView alloc] initWithFrame:CGRectMake((frame.size.width - 40) / 2, frame.size.height - _bottomPanelHeight - 37, 40, 21)];
        [self addSubview:_flashActiveView];
        
        _zoomView = [[TGCameraZoomView alloc] initWithFrame:CGRectMake(10, frame.size.height - _bottomPanelHeight - _bottomPanelOffset - 18, frame.size.width - 20, 1.5f)];
        _zoomView.activityChanged = ^(bool active)
        {
            __strong TGCameraMainPhoneView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^
            {
                [strongSelf _layoutFlashActiveViewForInterfaceOrientation:strongSelf->_interfaceOrientation zoomViewHidden:!active];
            } completion:nil];
        };
        [self addSubview:_zoomView];
    
        _flashControl.becameActive = ^
        {
            __strong TGCameraMainPhoneView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (strongSelf->_modeControl.cameraMode == PGCameraModeVideo)
                [strongSelf->_timecodeView setHidden:true animated:true];
        };
        
        _flashControl.modeChanged = ^(PGCameraFlashMode mode)
        {
            __strong TGCameraMainPhoneView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (strongSelf.flashModeChanged != nil)
                strongSelf.flashModeChanged(mode);
            
            if (strongSelf->_modeControl.cameraMode == PGCameraModeVideo)
                [strongSelf->_timecodeView setHidden:false animated:true];
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
        _topFlipButton.hidden = false;
        _flipButton.hidden = true;
        _doneButton.hidden = false;
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
    
    if ([view isDescendantOfView:_topPanelView] || [view isDescendantOfView:_bottomPanelView] || [view isDescendantOfView:_videoLandscapePanelView] || [view isDescendantOfView:_tooltipContainerView] || [view isDescendantOfView:_selectedPhotosView])
        return view;
    
    return nil;
}

#pragma mark - Actions

- (void)shutterButtonReleased
{
    [super shutterButtonReleased];
    
    [_flashControl dismissAnimated:true];
}

- (void)updateForCameraModeChangeWithPreviousMode:(PGCameraMode)previousMode
{
    [super updateForCameraModeChangeWithPreviousMode:previousMode];
    
    UIInterfaceOrientation orientation = _interfaceOrientation;
    PGCameraMode cameraMode = _modeControl.cameraMode;
    
    if (UIInterfaceOrientationIsLandscape(orientation) && !((cameraMode == PGCameraModePhoto && previousMode == PGCameraModeSquare) || (cameraMode == PGCameraModeSquare && previousMode == PGCameraModePhoto)))
    {
        if (cameraMode == PGCameraModeVideo)
            _timecodeView.hidden = true;
        
        [UIView animateWithDuration:0.25f delay:0.0f options:UIViewAnimationOptionCurveLinear animations:^
        {
            _topPanelView.alpha = 0.0f;
            _videoLandscapePanelView.alpha = 0.0f;
        } completion:^(__unused BOOL finished)
        {
            if (cameraMode == PGCameraModeVideo)
            {
                _timecodeView.hidden = false;
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
            [_flashControl dismissAnimated:false];
            
            [UIView animateWithDuration:0.2f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^
            {
                if (cameraMode == PGCameraModeVideo)
                    _videoLandscapePanelView.alpha = 1.0f;
                else
                    _topPanelView.alpha = 1.0f;
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
    [_flashActiveView setActive:active animated:true];
}

- (void)setFlashUnavailable:(bool)unavailable
{
    [_flashControl setFlashUnavailable:unavailable];
}

- (void)setHasFlash:(bool)hasFlash
{
    if (!hasFlash)
        [_flashActiveView setActive:false animated:true];
    
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
    
    if (animated)
    {
        if (!hidden)
        {
            _modeControl.hidden = false;
            _cancelButton.hidden = false;
            _flashControl.hidden = false;
            _flipButton.hidden = hasDoneButton;
            _bottomPanelBackgroundView.hidden = false;
            _topFlipButton.hidden = !hasDoneButton;
        }
        
        [UIView animateWithDuration:0.25 animations:^
        {
            CGFloat alpha = hidden ? 0.0f : 1.0f;
            _modeControl.alpha = alpha;
            _cancelButton.alpha = alpha;
            _flashControl.alpha = alpha;
            _flipButton.alpha = alpha;
            _topFlipButton.alpha = alpha;
            _bottomPanelBackgroundView.alpha = alpha;
            
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
                _bottomPanelBackgroundView.hidden = hidden;
                
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
        _bottomPanelBackgroundView.hidden = hidden;
        _bottomPanelBackgroundView.alpha = alpha;
        
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
            _flashActiveView.alpha = 0.0f;
            
            if (_modeControl.cameraMode == PGCameraModeVideo)
            {
                _topPanelView.alpha = 0.0f;
                _videoLandscapePanelView.alpha = 0.0f;
            }
            else
            {
                _flashControl.alpha = 0.0f;
            }
            
            _topFlipButton.transform = CGAffineTransformMakeRotation(TGRotationForInterfaceOrientation(orientation));
            _flipButton.transform = CGAffineTransformMakeRotation(TGRotationForInterfaceOrientation(orientation));
        } completion:^(__unused BOOL finished)
        {
            [self _layoutFlashActiveViewForInterfaceOrientation:orientation zoomViewHidden:!_zoomView.isActive];
            
            if (_modeControl.cameraMode == PGCameraModeVideo)
            {
                _flashControl.transform = CGAffineTransformIdentity;
                _flashControl.interfaceOrientation = UIInterfaceOrientationPortrait;
             
                [self _layoutTopPanelViewForInterfaceOrientation:orientation];
                
                if (UIInterfaceOrientationIsLandscape(orientation))
                    [self _attachControlsToLandscapePanel];
                else
                    [self _attachControlsToTopPanel];
                
                _timecodeView.hidden = false;
            }
            else
            {
                _flashControl.transform = CGAffineTransformMakeRotation(TGRotationForInterfaceOrientation(orientation));
                _flashControl.interfaceOrientation = orientation;
            }
            
            [self _layoutTopPanelSubviewsForInterfaceOrientation:orientation];

            [_flashControl dismissAnimated:false];
            
            [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^
            {
                _flashActiveView.alpha = 1.0f;
                
                if (_modeControl.cameraMode == PGCameraModeVideo)
                {
                    if (UIInterfaceOrientationIsLandscape(orientation))
                        _videoLandscapePanelView.alpha = 1.0f;
                    else
                        _topPanelView.alpha = 1.0f;
                }
                else
                {
                    _flashControl.alpha = 1.0f;
                }
            } completion:nil];
        }];
    }
    else
    {
        [_flashControl dismissAnimated:false];
        
        _topFlipButton.transform = CGAffineTransformMakeRotation(TGRotationForInterfaceOrientation(orientation));
        _flipButton.transform = CGAffineTransformMakeRotation(TGRotationForInterfaceOrientation(orientation));
        _flashControl.transform = CGAffineTransformMakeRotation(TGRotationForInterfaceOrientation(orientation));
        _flashControl.interfaceOrientation = orientation;
        
        [self _layoutTopPanelSubviewsForInterfaceOrientation:orientation];
        
        [self _layoutFlashActiveViewForInterfaceOrientation:orientation zoomViewHidden:!_zoomView.isActive];
        
        if (_modeControl.cameraMode == PGCameraModeVideo)
            _timecodeView.hidden = false;
    }
}

- (void)_layoutFlashActiveViewForInterfaceOrientation:(UIInterfaceOrientation)orientation zoomViewHidden:(bool)zoomViewHidden
{
    CGFloat zoomOffset = 0;
    if (!zoomViewHidden)
        zoomOffset -= 23;
    
    _flashActiveView.transform = CGAffineTransformMakeRotation(TGRotationForInterfaceOrientation(orientation));
    switch (orientation)
    {
        case UIInterfaceOrientationPortraitUpsideDown:
        {
            _flashActiveView.frame = CGRectMake((self.frame.size.width - 40) / 2, _topPanelHeight + 16, 40, 21);
        }
            break;
            
        case UIInterfaceOrientationLandscapeLeft:
        {
            _flashActiveView.frame = CGRectMake(self.frame.size.width - 37, _topPanelHeight + (self.frame.size.height - _topPanelHeight - _bottomPanelHeight - _bottomPanelOffset - 40) / 2, 21, 40);
        }
            break;
            
        case UIInterfaceOrientationLandscapeRight:
        {
            _flashActiveView.frame = CGRectMake(16, _topPanelHeight + (self.frame.size.height - _topPanelHeight - _bottomPanelHeight - _bottomPanelOffset - 40) / 2, 21, 40);
        }
            break;
            
        default:
        {
            _flashActiveView.frame = CGRectMake((self.frame.size.width - 40) / 2, self.frame.size.height - _bottomPanelHeight - _bottomPanelOffset - 37 + zoomOffset, 40, 21);
        }
            break;
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
            _topPanelView.hidden = true;
            
            _videoLandscapePanelView.transform = transform;
            _videoLandscapePanelView.frame = CGRectMake(3, (self.frame.size.height - _videoLandscapePanelView.frame.size.height) / 2, _videoLandscapePanelView.frame.size.width, _videoLandscapePanelView.frame.size.height);
        }
            break;
        case UIInterfaceOrientationLandscapeRight:
        {
            _videoLandscapePanelView.hidden = false;
            _topPanelView.hidden = true;
            
            _videoLandscapePanelView.transform = transform;
            _videoLandscapePanelView.frame = CGRectMake(self.frame.size.width - _videoLandscapePanelView.frame.size.width - 3, (self.frame.size.height - _videoLandscapePanelView.frame.size.height) / 2, _videoLandscapePanelView.frame.size.width, _videoLandscapePanelView.frame.size.height);
        }
            break;
            
        case UIInterfaceOrientationPortraitUpsideDown:
        {
            _videoLandscapePanelView.hidden = true;
            _topPanelView.hidden = false;
            
            _topPanelView.transform = transform;
            _topPanelView.frame = CGRectMake(0, 0, _topPanelView.frame.size.width, _topPanelView.frame.size.height);
        }
            break;
            
        default:
        {
            _videoLandscapePanelView.hidden = true;
            _topPanelView.hidden = false;
            
            _topPanelView.transform = transform;
            _topPanelView.frame = CGRectMake(0, 0, _topPanelView.frame.size.width, _topPanelView.frame.size.height);
        }
            break;
    }
}

- (void)_attachControlsToTopPanel
{
    [_topPanelView addSubview:_flashControl];
    [_topPanelView addSubview:_timecodeView];
}

- (void)_attachControlsToLandscapePanel
{
    [_videoLandscapePanelView addSubview:_flashControl];
    [_videoLandscapePanelView addSubview:_timecodeView];
}

- (void)_layoutTopPanelSubviewsForInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    UIView *superview = _flashControl.superview;
    CGSize superviewSize = superview.frame.size;
    
    if (superview == _videoLandscapePanelView && superviewSize.width < superviewSize.height)
        superviewSize = CGSizeMake(superviewSize.height, superviewSize.width);
    
    if (UIInterfaceOrientationIsLandscape(orientation) && _flashControl.interfaceOrientation == orientation && _flashControl.superview == _topPanelView)
    {
        if (orientation == UIInterfaceOrientationLandscapeLeft)
            _flashControl.frame = CGRectMake(7, 0, TGCameraFlashControlHeight, 370);
        else if (orientation == UIInterfaceOrientationLandscapeRight)
            _flashControl.frame = CGRectMake(7, 0, TGCameraFlashControlHeight, 370);
    }
    else
    {
        _flashControl.frame = CGRectMake(0, (superviewSize.height - TGCameraFlashControlHeight) / 2, superviewSize.width, TGCameraFlashControlHeight);
    }
    _timecodeView.frame = CGRectMake((superviewSize.width - 120) / 2, (superviewSize.height - 20) / 2, 120, 20);
}

- (void)layoutPreviewRelativeViews
{
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
    _cancelButton.frame = CGRectMake(0, round(_shutterButton.center.y - _cancelButton.frame.size.height / 2.0f), _cancelButton.frame.size.width, _cancelButton.frame.size.height);
    _doneButton.frame = CGRectMake(_bottomPanelView.frame.size.width - _doneButton.frame.size.width, round(_shutterButton.center.y - _doneButton.frame.size.height / 2.0f), _doneButton.frame.size.width, _doneButton.frame.size.height);
    
    _flipButton.frame = CGRectMake(self.frame.size.width - _flipButton.frame.size.width - 4.0f - 7.0f, round(_shutterButton.center.y - _flipButton.frame.size.height / 2.0f), _flipButton.frame.size.width, _flipButton.frame.size.height);
    
    _topFlipButton.frame = CGRectMake(self.frame.size.width - _topFlipButton.frame.size.width - 4.0f, 0.0f, _topFlipButton.frame.size.width, _topFlipButton.frame.size.height);
    
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
