#import "TGCameraMainTabletView.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"

#import "UIControl+HitTestEdgeInsets.h"

#import "TGCameraInterfaceAssets.h"

#import <LegacyComponents/TGModernButton.h>
#import "TGCameraShutterButton.h"
#import "TGCameraModeControl.h"
#import "TGCameraFlipButton.h"
#import "TGCameraTimeCodeView.h"
#import "TGCameraZoomView.h"

const CGFloat TGCameraTabletPanelViewWidth = 102.0f;

@interface TGCameraMainTabletView ()
{
    UIView *_panelView;
    UIView *_panelBackgroundView;
}
@end

@implementation TGCameraMainTabletView

@synthesize cameraFlipped;
@synthesize cameraModeChanged;
@synthesize flashModeChanged;
@synthesize focusPointChanged;
@synthesize expositionChanged;
@synthesize shutterPressed;
@synthesize shutterReleased;
@synthesize cancelPressed;

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _panelView = [[UIView alloc] initWithFrame:CGRectMake(frame.size.width - TGCameraTabletPanelViewWidth, 0, TGCameraTabletPanelViewWidth, frame.size.height)];
        [self addSubview:_panelView];
        
        _panelBackgroundView = [[UIView alloc] initWithFrame:_panelView.bounds];
        _panelBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _panelBackgroundView.backgroundColor = [TGCameraInterfaceAssets transparentPanelBackgroundColor];
        [_panelView addSubview:_panelBackgroundView];
        
        _cancelButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0, 0, 60, 44)];
        _cancelButton.backgroundColor = [UIColor clearColor];
        _cancelButton.exclusiveTouch = true;
        _cancelButton.titleLabel.font = TGSystemFontOfSize(18);
        [_cancelButton setTitle:TGLocalized(@"Common.Cancel") forState:UIControlStateNormal];
        [_cancelButton setTintColor:[TGCameraInterfaceAssets normalColor]];
        [_cancelButton sizeToFit];
        _cancelButton.frame = CGRectMake(0, 0.5f, MAX(60.0f, _cancelButton.frame.size.width), 44);
        [_cancelButton addTarget:self action:@selector(cancelButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_panelView addSubview:_cancelButton];
        
        _shutterButton = [[TGCameraShutterButton alloc] initWithFrame:CGRectMake(0, 0, 66, 66)];
        [_shutterButton addTarget:self action:@selector(shutterButtonPressed) forControlEvents:UIControlEventTouchDown];
        [_shutterButton addTarget:self action:@selector(shutterButtonReleased) forControlEvents:UIControlEventTouchUpInside];
        [_panelView addSubview:_shutterButton];
        
        _modeControl = [[TGCameraModeControl alloc] initWithFrame:CGRectMake(0, 0, _panelView.frame.size.width, 260)];
        [_panelView addSubview:_modeControl];
        
        __weak TGCameraMainTabletView *weakSelf = self;
        
        _timecodeView = [[TGCameraTimeCodeView alloc] initWithFrame:CGRectMake((frame.size.width - 120) / 2, frame.size.height / 4 - 10, 120, 20)];
        _timecodeView.hidden = true;
        _timecodeView.requestedRecordingDuration = ^NSTimeInterval
        {
            __strong TGCameraMainTabletView *strongSelf = weakSelf;
            if (strongSelf == nil || strongSelf.requestedVideoRecordingDuration == nil)
                return 0.0;
            
            return strongSelf.requestedVideoRecordingDuration();
        };
        [_panelView addSubview:_timecodeView];
        
        _flipButton = [[TGCameraFlipButton alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
        [_flipButton addTarget:self action:@selector(flipButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_panelView addSubview:_flipButton];
        
        _zoomView = [[TGCameraZoomView alloc] initWithFrame:CGRectMake(10, frame.size.height - 18, frame.size.width - 20, 1.5f)];
        [self addSubview:_zoomView];
        
        _modeControl.modeChanged = ^(PGCameraMode mode, __unused PGCameraMode previousMode)
        {
            __strong TGCameraMainTabletView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (strongSelf.cameraModeChanged != nil)
                strongSelf.cameraModeChanged(mode);
            
            if (mode == PGCameraModePhoto)
            {
                [strongSelf->_shutterButton setButtonMode:TGCameraShutterButtonNormalMode animated:true];
                [strongSelf->_timecodeView setHidden:true animated:true];
            }
            else if (mode == PGCameraModeVideo)
            {
                [strongSelf->_shutterButton setButtonMode:TGCameraShutterButtonVideoMode animated:true];
                [strongSelf->_timecodeView setHidden:false animated:true];
            }
        };
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *view = [super hitTest:point withEvent:event];
    
    if ([view isDescendantOfView:_panelView])
        return view;
    
    return nil;
}

- (void)setInterfaceHiddenForVideoRecording:(bool)hidden animated:(bool)animated
{
    if (animated)
    {
        _modeControl.hidden = false;
        _cancelButton.hidden = false;
        _flipButton.hidden = false;
        _panelBackgroundView.hidden = false;
        
        [UIView animateWithDuration:0.25f
                         animations:^
         {
             CGFloat alpha = hidden ? 0.0f : 1.0f;
             _modeControl.alpha = alpha;
             _cancelButton.alpha = alpha;
             _flipButton.alpha = alpha;
             _panelBackgroundView.alpha = alpha;
         } completion:^(BOOL finished)
         {
             if (finished)
             {
                 _modeControl.hidden = hidden;
                 _cancelButton.hidden = hidden;
                 _flipButton.hidden = hidden;
                 _panelBackgroundView.hidden = hidden;
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
        _flipButton.hidden = hidden;
        _flipButton.alpha = alpha;
        _panelBackgroundView.hidden = hidden;
        _panelBackgroundView.alpha = alpha;
    }
}

- (void)layoutSubviews
{
    CGSize referenceSize = self.frame.size;
    if (UIInterfaceOrientationIsLandscape(_interfaceOrientation))
        referenceSize = CGSizeMake(referenceSize.height, referenceSize.width);
    
    _panelView.frame = CGRectMake(referenceSize.width - TGCameraTabletPanelViewWidth, 0, TGCameraTabletPanelViewWidth, referenceSize.height);
    _shutterButton.frame = CGRectMake((_panelView.frame.size.width - _shutterButton.frame.size.width) / 2,
                                      (_panelView.frame.size.height - _shutterButton.frame.size.height) / 2,
                                      _shutterButton.frame.size.width, _shutterButton.frame.size.height);
    _flipButton.frame = CGRectMake((_panelView.frame.size.width - _flipButton.frame.size.width) / 2, 0,
                                   _flipButton.frame.size.width, _flipButton.frame.size.height);
    
    _cancelButton.frame = CGRectMake((_panelView.frame.size.width - _cancelButton.frame.size.width) / 2, _panelView.frame.size.height - _cancelButton.frame.size.height - 7, _cancelButton.frame.size.width, _cancelButton.frame.size.height);
    
    _modeControl.frame = CGRectMake(_modeControl.frame.origin.x, CGFloor(referenceSize.height / 4 * 3 - _modeControl.frame.size.height / 2 - 12), _modeControl.frame.size.width, _modeControl.frame.size.height);
    
    _timecodeView.frame = CGRectMake((_panelView.frame.size.width - _timecodeView.frame.size.width) / 2, _panelView.frame.size.height / 4 - _timecodeView.frame.size.height / 2, _timecodeView.frame.size.width, _timecodeView.frame.size.height);
    
    _zoomView.frame = CGRectMake(10, referenceSize.height - 18, referenceSize.width - 20 - _panelView.frame.size.width, 1.5f);
}

@end
