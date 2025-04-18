#import "TGCameraFocusCrosshairsControl.h"
#import <QuartzCore/QuartzCore.h>

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGCameraPreviewView.h>

#import <LegacyComponents/TGPhotoEditorUtils.h>
#import <LegacyComponents/TGCameraInterfaceAssets.h>

@interface TGCameraFocusCrosshairsControl ()
{
    bool _animatingFocusPOI;
    
    UIView *_wrapperView;
    
    UIView *_focusIndicatorView;
    UIImageView *_focusIndicatorImageView;
    
    UIImageView *_autoFocusIndicator;
    
    UITapGestureRecognizer *_tapGestureRecognizer;
    UIPanGestureRecognizer *_panGestureRecognizer;
    
    UIView *_exposureWrapperView;
    UIView *_exposureClipView;
    UIView *_exposureIndicatorView;
    UIImageView *_exposureIconView;
    UIView *_exposureTopLine;
    UIView *_exposureBottomLine;
    
    CGFloat _exposureValue;
    
    UIInterfaceOrientation _interfaceOrientation;
    
    bool _hideOnStop;
    
    bool _ignoreAutofocusForExposing;
}
@end

@implementation TGCameraFocusCrosshairsControl

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.backgroundColor = [UIColor clearColor];
        
        _wrapperView = [[UIView alloc] initWithFrame:self.bounds];
        _wrapperView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_wrapperView];
        
        _tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleFocusTap:)];
        [_wrapperView addGestureRecognizer:_tapGestureRecognizer];
        
        _focusIndicatorView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 75 + 90, 75 + 90)];
        _focusIndicatorView.hidden = true;
        [_wrapperView addSubview:_focusIndicatorView];
        
        _focusIndicatorImageView = [[UIImageView alloc] initWithFrame:CGRectMake(45, 45, 75, 75)];
        _focusIndicatorImageView.image = TGComponentsImageNamed(@"CameraFocusCrosshairs");
        _focusIndicatorImageView.alpha = 0.0;
        [_focusIndicatorView addSubview:_focusIndicatorImageView];
        
        _autoFocusIndicator = [[UIImageView alloc] initWithFrame:CGRectMake(CGFloor((self.bounds.size.width - 125) / 2), CGFloor((self.bounds.size.height - 125) / 2), 125, 125)];
        _autoFocusIndicator.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
        _autoFocusIndicator.backgroundColor = [UIColor clearColor];
        _autoFocusIndicator.image = TGComponentsImageNamed(@"CameraAutoFocusCrosshairs");
        _autoFocusIndicator.alpha = 0.0f;
        [_wrapperView addSubview:_autoFocusIndicator];
        
        if (iosMajorVersion() >= 8)
        {
            _exposureWrapperView = [[UIView alloc] initWithFrame:_focusIndicatorView.bounds];
            [_focusIndicatorView addSubview:_exposureWrapperView];
            
            _exposureClipView = [[UIView alloc] initWithFrame:CGRectMake(45 + _focusIndicatorImageView.frame.size.width + 5, 45 + (_focusIndicatorImageView.frame.size.height - 144) / 2, 25, 144)];
            _exposureClipView.clipsToBounds = true;
            [_exposureWrapperView addSubview:_exposureClipView];
            
            _exposureIndicatorView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 25, 144)];
            [_exposureClipView addSubview:_exposureIndicatorView];
            
            _exposureIconView = [[UIImageView alloc] initWithFrame:CGRectMake(-1, 59.5f, 25, 25)];
            _exposureIconView.image = TGComponentsImageNamed(@"CameraExposureIcon");
            [_exposureIndicatorView addSubview:_exposureIconView];
            
            _exposureTopLine = [[UIView alloc] initWithFrame:CGRectMake(11, _exposureIconView.frame.origin.y - 3 - _exposureIndicatorView.frame.size.height, 1, _exposureIndicatorView.frame.size.height)];
            _exposureTopLine.alpha = 0.0f;
            _exposureTopLine.backgroundColor = [TGCameraInterfaceAssets accentColor];
            [_exposureIndicatorView addSubview:_exposureTopLine];
            
            _exposureBottomLine = [[UIView alloc] initWithFrame:CGRectMake(11, _exposureIconView.frame.origin.y + _exposureIconView.frame.size.height + 3, 1, _exposureIndicatorView.frame.size.height)];
            _exposureBottomLine.alpha = 0.0f;
            _exposureBottomLine.backgroundColor = [TGCameraInterfaceAssets accentColor];
            [_exposureIndicatorView addSubview:_exposureBottomLine];
            
            _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
            [_focusIndicatorView addGestureRecognizer:_panGestureRecognizer];
        }
        else
        {
            _hideOnStop = true;
        }
    }
    
    return self;
}

- (void)handleFocusTap:(UITapGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateRecognized)
    {
        TGCameraPreviewView *previewView = self.previewView;
        CGPoint previewLocation = [gestureRecognizer locationInView:previewView];
        
        if (self.focusPOIChanged != nil)
            self.focusPOIChanged([previewView devicePointOfInterestForPoint:previewLocation]);
        
        CGPoint location = [gestureRecognizer locationInView:self];
        _focusIndicatorView.frame = CGRectMake(CGFloor(location.x - _focusIndicatorView.frame.size.width / 2), CGFloor(location.y - _focusIndicatorView.frame.size.height / 2), _focusIndicatorView.frame.size.width, _focusIndicatorView.frame.size.height);
        [self playFocusPOIAnimation];
        
        _exposureValue = 0.0f;
        [self setExposureSliderPosition:0.0f];
        [self setExposureSliderTrackHidden:true animated:false];
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(deactivateFocusIndicatorAnimated) object:nil];
        
        [self updateExposureIndicatorPositionForOrientation:_interfaceOrientation];
    }
}

- (void)playAutoFocusAnimation
{
    if (!_animatingFocusPOI)
    {
        if (self.ignoreAutofocusing || _ignoreAutofocusForExposing)
            return;
        
        _focusIndicatorView.hidden = true;
        _autoFocusIndicator.hidden = false;
        
        CAKeyframeAnimation *scaleAnimation = [CAKeyframeAnimation animationWithKeyPath:@"transform"];
        NSArray *scaleValues                = [NSArray arrayWithObjects:
                                               [NSValue valueWithCATransform3D:CATransform3DScale(_autoFocusIndicator.layer.transform, 2, 2, 1)],
                                               [NSValue valueWithCATransform3D:CATransform3DScale(_autoFocusIndicator.layer.transform, 1, 1, 1)], nil];
        [scaleAnimation setValues:scaleValues];
        scaleAnimation.fillMode = kCAFillModeForwards;
        scaleAnimation.duration = 0.2f;
        [_autoFocusIndicator.layer addAnimation:scaleAnimation forKey:@"scale"];
        
        CAKeyframeAnimation *blinkAnim = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
        blinkAnim.duration = 2.0f;
        blinkAnim.autoreverses = false;
        blinkAnim.fillMode = kCAFillModeForwards;
        blinkAnim.repeatCount = HUGE_VALF;
        
        blinkAnim.keyTimes = @[ @0.0f, @0.1f, @0.2f, @0.3f, @0.4f, @0.5f, @0.6f, @0.7f, @0.8f, @0.9f, @1.0f ];
        blinkAnim.values = @[ @0.4f, @1.0f, @0.4f, @1.0f, @0.4f, @1.0f, @0.4f, @1.0f, @0.4f, @1.0f, @0.4f ];
        
        [_autoFocusIndicator.layer addAnimation:blinkAnim forKey:@"opacity"];
    }
    else
    {
        [_autoFocusIndicator.layer removeAnimationForKey:@"scale"];
        [_autoFocusIndicator.layer removeAnimationForKey:@"opacity"];
    }
}

- (void)stopAutoFocusAnimation
{
    if (!_animatingFocusPOI)
    {
        if (![_autoFocusIndicator.layer.animationKeys containsObject:@"opacity"])
            return;
        
        [_autoFocusIndicator.layer removeAnimationForKey:@"opacity"];
     
        CAKeyframeAnimation *blinkAnim = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
        blinkAnim.duration = 0.2f;
        blinkAnim.autoreverses = false;
        blinkAnim.fillMode = kCAFillModeForwards;
        
        blinkAnim.keyTimes = @[ @0.0f, @1.0f ];
        blinkAnim.values = @[ @1.0f, @0.0f ];
        
        [_autoFocusIndicator.layer addAnimation:blinkAnim forKey:@"opacity"];
    }
    else
    {
        [self stopFocusPOIAnimation];
    }
}

- (void)playFocusPOIAnimation
{
    if (self.stopAutomatically)
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopFocusPOIAnimation) object:nil];
    
    _focusIndicatorView.alpha = 1.0f;
    _focusIndicatorView.hidden = false;
    _autoFocusIndicator.hidden = true;
    _animatingFocusPOI = true;
    
    CAKeyframeAnimation *scaleAnimation = [CAKeyframeAnimation animationWithKeyPath:@"transform"];
    NSArray *scaleValues                = [NSArray arrayWithObjects:
                                           [NSValue valueWithCATransform3D:CATransform3DScale(_focusIndicatorView.layer.transform, 2, 2, 1)],
                                           [NSValue valueWithCATransform3D:CATransform3DScale(_focusIndicatorView.layer.transform, 1, 1, 1)], nil];
    [scaleAnimation setValues:scaleValues];
    scaleAnimation.fillMode = kCAFillModeForwards;
    scaleAnimation.duration = 0.15f;
    [_focusIndicatorView.layer addAnimation:scaleAnimation forKey:@"scale"];

    CAKeyframeAnimation *blinkAnim = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    blinkAnim.duration = 2.0f;
    blinkAnim.autoreverses = false;
    blinkAnim.fillMode = kCAFillModeForwards;
    blinkAnim.repeatCount = HUGE_VALF;
    
    blinkAnim.keyTimes = @[ @0.0f, @0.1f, @0.2f, @0.3f, @0.4f, @0.5f, @0.6f, @0.7f, @0.8f, @0.9f, @1.0f ];
    blinkAnim.values = @[ @0.6f, @1.0f, @0.6f, @1.0f, @0.6f, @1.0f, @0.6f, @1.0f, @0.6f, @1.0f, @0.6f ];
    
    [_focusIndicatorImageView.layer addAnimation:blinkAnim forKey:@"opacity"];
    
    if (self.stopAutomatically)
        [self performSelector:@selector(stopFocusPOIAnimation) withObject:nil afterDelay:1.0f];
}

- (void)stopFocusPOIAnimation
{
    [_focusIndicatorImageView.layer removeAnimationForKey:@"opacity"];
    _focusIndicatorImageView.layer.opacity = 1.0f;
 
    if (_hideOnStop)
    {
        [UIView animateWithDuration:0.2f delay:0.9f options:0 animations:^
        {
            _focusIndicatorView.alpha = 0.0f;
        } completion:^(__unused BOOL finished)
        {
            _focusIndicatorView.hidden = true;
            _animatingFocusPOI = false;
        }];
    }
    else
    {
        [UIView animateWithDuration:0.2f delay:0.9f options:UIViewAnimationOptionAllowUserInteraction animations:^
        {
            _focusIndicatorView.alpha = 0.5f;
        } completion:^(__unused BOOL finished)
        {
            _animatingFocusPOI = false;
        }];
    }
}

- (void)reset
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopFocusPOIAnimation) object:nil];
    [self stopAutoFocusAnimation];
    _focusIndicatorView.hidden = true;
}

- (BOOL)enabled
{
    return _tapGestureRecognizer.enabled;
}

- (void)setEnabled:(BOOL)enabled
{
    _tapGestureRecognizer.enabled = enabled;
}

- (bool)active
{
    return !_wrapperView.hidden;
}

- (void)setActive:(bool)active
{
    _wrapperView.hidden = !active;
}


- (void)setIgnoreAutofocusing:(bool)ignoreAutofocusing
{
    _ignoreAutofocusing = ignoreAutofocusing;

    if (ignoreAutofocusing)
    {
        _autoFocusIndicator.hidden = true;
        [_autoFocusIndicator.layer removeAnimationForKey:@"scale"];
        [_autoFocusIndicator.layer removeAnimationForKey:@"opacity"];
    }
}

#pragma mark - Exposure Control

- (void)setFocusIndicatorActive:(bool)active animated:(bool)animated
{
    CGFloat targetAlpha = active ? 1.0f : 0.5f;

    if (animated)
    {
        [UIView animateWithDuration:0.3f animations:^
        {
            _focusIndicatorView.alpha = targetAlpha;
        }];
    }
    else
    {
        _focusIndicatorView.alpha = targetAlpha;
    }
}

- (void)deactivateFocusIndicatorAnimated
{
    [self setFocusIndicatorActive:false animated:true];
    [self setExposureSliderTrackHidden:true animated:true];
    
    if (self.endedExposureChange != nil)
        self.endedExposureChange();
}

- (void)setExposureSliderTrackHidden:(bool)hidden animated:(bool)animated
{
    CGFloat targetAlpha = hidden ? 0.0f : 1.0f;
    
    if (animated)
    {
        [UIView animateWithDuration:0.3f animations:^
        {
            _exposureTopLine.alpha = targetAlpha;
            _exposureBottomLine.alpha = targetAlpha;
        }];
    }
    else
    {
        _exposureTopLine.alpha = targetAlpha;
        _exposureBottomLine.alpha = targetAlpha;
    }
}

- (void)setExposureSliderPosition:(CGFloat)exposureValue
{
    _exposureIndicatorView.frame = CGRectMake(_exposureIndicatorView.frame.origin.x,
                                              exposureValue * (_exposureIndicatorView.frame.size.height - _exposureIconView.frame.size.height) / 2,
                                              _exposureIndicatorView.frame.size.width, _exposureIndicatorView.frame.size.height);
}

- (void)handlePan:(UIPanGestureRecognizer *)gestureRecognizer
{
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(deactivateFocusIndicatorAnimated) object:nil];
            
            _ignoreAutofocusForExposing = true;
            
            if (self.beganExposureChange != nil)
                self.beganExposureChange();
        }
        case UIGestureRecognizerStateChanged:
        {
            CGPoint translation = [gestureRecognizer translationInView:gestureRecognizer.view];
            CGFloat delta = 0.0f;
            switch (_interfaceOrientation)
            {
                case UIInterfaceOrientationLandscapeLeft:
                    delta = translation.x / 750.0f;
                    break;
                    
                case UIInterfaceOrientationLandscapeRight:
                    delta = translation.x / -750.0f;
                    break;
                    
                default:
                    delta = translation.y / 750.0f;
                    break;
            }
            
            CGFloat newValue = MAX(-1.0f, MIN(1.0f, _exposureValue + delta));
            _exposureValue = newValue;
            [self setExposureSliderPosition:newValue];
            [self setExposureSliderTrackHidden:false animated:false];
            [self setFocusIndicatorActive:true animated:false];
            
            [gestureRecognizer setTranslation:CGPointZero inView:gestureRecognizer.view];
            
            if (self.exposureChanged != nil)
                self.exposureChanged(_exposureValue * -1);
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            _ignoreAutofocusForExposing = false;
            
            [self performSelector:@selector(deactivateFocusIndicatorAnimated) withObject:nil afterDelay:2.0f];
        }
            break;
            
        default:
            break;
    }
}

- (void)updateExposureIndicatorPositionForOrientation:(UIInterfaceOrientation)orientation
{
    CGRect defaultPositionFrame = CGRectMake(45 + _focusIndicatorImageView.frame.size.width + 5, 45 + (_focusIndicatorImageView.frame.size.height - 144) / 2, 25, 144);
    CGRect mirroredPositionFrame = CGRectMake(15, 45 + (_focusIndicatorImageView.frame.size.height - 144) / 2, 25, 144);
    switch (orientation)
    {
        case UIInterfaceOrientationPortraitUpsideDown:
        {
            if (CGRectGetMinX(_focusIndicatorView.frame) < 0)
                _exposureClipView.frame = mirroredPositionFrame;
            else
                _exposureClipView.frame = defaultPositionFrame;
        }
            break;
            
        case UIInterfaceOrientationLandscapeLeft:
        {
            if (CGRectGetMinY(_focusIndicatorView.frame) < 0)
                _exposureClipView.frame = mirroredPositionFrame;
            else
                _exposureClipView.frame = defaultPositionFrame;
        }
            break;
            
        case UIInterfaceOrientationLandscapeRight:
        {
            if (CGRectGetMaxY(_focusIndicatorView.frame) > self.frame.size.height)
                _exposureClipView.frame = mirroredPositionFrame;
            else
                _exposureClipView.frame = defaultPositionFrame;
        }
            break;
            
        default:
        {
            if (CGRectGetMaxX(_focusIndicatorView.frame) > self.frame.size.width)
                _exposureClipView.frame = mirroredPositionFrame;
            else
                _exposureClipView.frame = defaultPositionFrame;
        }
            break;
    }
}

- (void)setInterfaceOrientation:(UIInterfaceOrientation)orientation animated:(bool)animated
{
    if (orientation == UIInterfaceOrientationUnknown || orientation == _interfaceOrientation)
        return;
    
    _interfaceOrientation = orientation;
    
    if (animated)
    {
        [UIView animateWithDuration:0.25f delay:0.0f options:UIViewAnimationOptionCurveLinear animations:^
        {
            _exposureWrapperView.alpha = 0.0f;
        } completion:^(__unused BOOL finished)
        {
            _exposureWrapperView.transform = CGAffineTransformMakeRotation(TGRotationForInterfaceOrientation(orientation));
            [self updateExposureIndicatorPositionForOrientation:orientation];
            
            [UIView animateWithDuration:0.2f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^
            {
                _exposureWrapperView.alpha = 1.0f;
            } completion:nil];
        }];
    }
    else
    {
        _exposureWrapperView.transform = CGAffineTransformMakeRotation(TGRotationForInterfaceOrientation(orientation));
        [self updateExposureIndicatorPositionForOrientation:orientation];
    }
}

@end
