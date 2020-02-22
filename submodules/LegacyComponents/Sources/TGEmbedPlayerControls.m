#import "TGEmbedPlayerControls.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"

#import <SSignalKit/SSignalKit.h>

#import <LegacyComponents/TGTimerTarget.h>
#import <LegacyComponents/TGModernButton.h>
#import <LegacyComponents/UIControl+HitTestEdgeInsets.h>

#import "TGEmbedPlayerScrubber.h"

#import "TGEmbedPlayerState.h"

const CGFloat TGEmbedPlayerControlsPanelHeight = 32.0f;

@interface TGEmbedPlayerControls ()
{
    TGEmbedPlayerControlsType _type;
    
    UIButton *_screenAreaButton;
    
    UIView *_backgroundView;
    UIView *_backgroundContentView;
    TGModernButton *_playButton;
    TGModernButton *_pauseButton;
    
    UILabel *_positionLabel;
    UILabel *_remainingLabel;
    TGEmbedPlayerScrubber *_scrubber;
    TGModernButton *_pictureInPictureButton;
    
    UIView *_fullscreenButtonWrapper;
    TGModernButton *_fullscreenButton;
    
    UIView *_largePlayButtonBack;
    TGModernButton *_largePlayButton;
    
    UIButton *_watermarkView;
    bool _watermarkDenyHiding;
    
    bool _disabled;
    bool _controlsHidden;
    bool _panelHidden;
    bool _animatingPanel;
    bool _playing;
    bool _hasPlaybackButton;
    bool _showingLargeButton;
    
    bool _wasPlayingBeforeScrubbing;
    
    NSTimer *_hidePanelTimer;
}
@end

@implementation TGEmbedPlayerControls

- (instancetype)initWithFrame:(CGRect)frame type:(TGEmbedPlayerControlsType)type
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _type = type;
        
        _panelHidden = true;
        self.clipsToBounds = true;
        
        _screenAreaButton = [[UIButton alloc] initWithFrame:self.bounds];
        _screenAreaButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _screenAreaButton.exclusiveTouch = true;
        [_screenAreaButton addTarget:self action:@selector(screenAreaPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_screenAreaButton];
        
        if (type == TGEmbedPlayerControlsTypeFull)
        {
            if (iosMajorVersion() >= 8)
            {
                UIVisualEffectView *effectView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
                _backgroundView = effectView;
                _backgroundContentView = effectView.contentView;
                
                UIView *whiteView = [[UIView alloc] initWithFrame:effectView.bounds];
                whiteView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                whiteView.backgroundColor = UIColorRGBA(0xffffff, 0.3f);
                [effectView.contentView addSubview:whiteView];
            }
            else
            {
                _backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
                _backgroundContentView = _backgroundView;
            }
            [self addSubview:_backgroundView];
            
            _pauseButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0, 0, 38, TGEmbedPlayerControlsPanelHeight)];
            _pauseButton.exclusiveTouch = true;
            [_pauseButton setImage:TGComponentsImageNamed(@"EmbedVideoPauseIcon") forState:UIControlStateNormal];
            [_pauseButton addTarget:self action:@selector(pauseButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            [_backgroundContentView addSubview:_pauseButton];
            
            _playButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0, 0, 38, TGEmbedPlayerControlsPanelHeight)];
            _playButton.exclusiveTouch = true;
            [_playButton setImage:TGComponentsImageNamed(@"EmbedVideoPlayIcon") forState:UIControlStateNormal];
            [_playButton addTarget:self action:@selector(playButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            [_backgroundContentView addSubview:_playButton];
            
            _positionLabel = [[UILabel alloc] initWithFrame:CGRectMake(24.0f, 0, 56.0f, TGEmbedPlayerControlsPanelHeight)];
            _positionLabel.backgroundColor = [UIColor clearColor];
            _positionLabel.font = TGSystemFontOfSize(13.0f);
            _positionLabel.text = @"0:00";
            _positionLabel.textAlignment = NSTextAlignmentCenter;
            _positionLabel.textColor = UIColorRGB(0x302e2e);
            _positionLabel.userInteractionEnabled = false;
            [_backgroundContentView addSubview:_positionLabel];
            
            _remainingLabel = [[UILabel alloc] initWithFrame:CGRectMake(frame.size.width - 56.0f, 0, 56, TGEmbedPlayerControlsPanelHeight)];
            _remainingLabel.backgroundColor = [UIColor clearColor];
            _remainingLabel.font = TGSystemFontOfSize(13.0f);
            _remainingLabel.text = @"-0:00";
            _remainingLabel.textAlignment = NSTextAlignmentCenter;
            _remainingLabel.textColor = UIColorRGB(0x302e2e);
            _remainingLabel.userInteractionEnabled = false;
            [_backgroundContentView addSubview:_remainingLabel];
            
            _pictureInPictureButton = [[TGModernButton alloc] initWithFrame:CGRectMake(frame.size.width - 45.0f, 0, 45.0f, TGEmbedPlayerControlsPanelHeight)];
            _pictureInPictureButton.exclusiveTouch = true;
            [_pictureInPictureButton setImage:TGComponentsImageNamed(@"EmbedVideoPIPIcon") forState:UIControlStateNormal];
            [_pictureInPictureButton addTarget:self action:@selector(pictureInPictureButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            [_backgroundContentView addSubview:_pictureInPictureButton];
            
            __weak TGEmbedPlayerControls *weakSelf = self;
            _scrubber = [[TGEmbedPlayerScrubber alloc] initWithFrame:CGRectZero];
            _scrubber.onInteractionStart = ^
            {
                __strong TGEmbedPlayerControls *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                if (strongSelf->_playing)
                {
                    strongSelf->_wasPlayingBeforeScrubbing = true;
                    if (strongSelf.pausePressed != nil)
                        strongSelf.pausePressed();
                }
                [strongSelf _invalidateTimer];
            };
            _scrubber.onSeek = ^(CGFloat position)
            {
                __strong TGEmbedPlayerControls *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                if (strongSelf.seekToPosition != nil)
                    strongSelf.seekToPosition(position);
            };
            _scrubber.onInteractionEnd = ^
            {
                __strong TGEmbedPlayerControls *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                [strongSelf _startTimerIfNeeded];
                
                if (strongSelf->_wasPlayingBeforeScrubbing)
                {
                    strongSelf->_wasPlayingBeforeScrubbing = false;
                    if (strongSelf.playPressed != nil)
                        strongSelf.playPressed();
                }
            };
            [_scrubber setTintColor:UIColorRGB(0x2f2e2e)];
            [_backgroundContentView addSubview:_scrubber];
        }
        
        if (type == TGEmbedPlayerControlsTypeSimple)
        {
            [self showLargePlayButton:false];
        }
        
        if (type == TGEmbedPlayerControlsTypeSimple || type == TGEmbedPlayerControlsTypeFull)
        {
            _fullscreenButtonWrapper = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 51.0f, 51.0f)];
            _fullscreenButtonWrapper.alpha = 0.0f;
            _fullscreenButtonWrapper.userInteractionEnabled = false;
            [self addSubview:_fullscreenButtonWrapper];
            
            if (iosMajorVersion() >= 8)
            {
                UIVisualEffectView *effectView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
                effectView.contentView.backgroundColor = UIColorRGBA(0xffffff, 0.3f);
                effectView.clipsToBounds = true;
                effectView.frame = CGRectMake(12.0f, 12.0f, 27.0f, 27.0f);
                effectView.layer.cornerRadius = 13.5f;
                [_fullscreenButtonWrapper addSubview:effectView];
            }
            
            _fullscreenButton = [[TGModernButton alloc] initWithFrame:_fullscreenButtonWrapper.bounds];
            _fullscreenButton.exclusiveTouch = true;
            [_fullscreenButton setImage:TGComponentsImageNamed(@"EmbedVideoFullScreenIcon") forState:UIControlStateNormal];
            [_fullscreenButton addTarget:self action:@selector(fullscreenButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            [_fullscreenButtonWrapper addSubview:_fullscreenButton];
        }
        
        _watermarkView = [[UIButton alloc] init];
        _watermarkView.alpha = 0.6f;
        _watermarkView.adjustsImageWhenHighlighted = false;
        _watermarkView.exclusiveTouch = true;
        _watermarkView.hitTestEdgeInsets = UIEdgeInsetsMake(-12.0f, -12.0f, -12.0f, -12.0f);
        [_watermarkView addTarget:self action:@selector(watermarkButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_watermarkView];
        
        _watermarkDenyHiding = true;
    }
    return self;
}

- (void)showLargePlayButton:(bool)force
{
    if (_largePlayButton != nil)
        return;
    
    if (iosMajorVersion() >= 8)
    {
        UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        
        UIVisualEffectView *effectView = [[UIVisualEffectView alloc] initWithEffect:effect];
        effectView.alpha = 1.0f;
        effectView.clipsToBounds = true;
        effectView.frame = CGRectMake(0.0f, 0.0f, 72.0f, 72.0f);
        effectView.layer.cornerRadius = 36.0f;
        [self addSubview:effectView];
        
        UIVisualEffectView *vibrancyView = [[UIVisualEffectView alloc] initWithEffect:[UIVibrancyEffect effectForBlurEffect:effect]];
        vibrancyView.contentView.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.6f];
        vibrancyView.frame = effectView.bounds;
        [effectView.contentView addSubview:vibrancyView];
        
        _largePlayButtonBack = effectView;
        
        if (!force)
            _largePlayButtonBack.hidden = true;
        
        static dispatch_once_t onceToken;
        static UIImage *largePlayIcon;
        dispatch_once(&onceToken, ^
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(72, 72), false, 0.0f);
            CGContextRef ctx = UIGraphicsGetCurrentContext();
            
            CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.8f alpha:0.09f].CGColor);
            CGContextFillRect(ctx, CGRectMake(0, 0, 72, 72));
            
            CGContextBeginPath(ctx);
            CGContextMoveToPoint(ctx, 25.0f, 18.0f);
            CGContextAddLineToPoint(ctx, 58.0f, 36.5f);
            CGContextAddLineToPoint(ctx, 25.0f, 55.0f);
            CGContextClosePath(ctx);
            
            CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.0f alpha:0.7f].CGColor);
            CGContextFillPath(ctx);
            
            largePlayIcon = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        });
        
        _largePlayButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0, 0, 72, 72)];
        [_largePlayButton setImage:largePlayIcon forState:UIControlStateNormal];
        [_largePlayButton addTarget:self action:@selector(playButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [effectView.contentView addSubview:_largePlayButton];
        
        _showingLargeButton = force;
    }
}

- (void)setHidden:(bool)hidden animated:(bool)__unused animated
{
    if (hidden == _controlsHidden)
        return;
    
    _controlsHidden = hidden;
    
    _backgroundView.hidden = hidden;
    _fullscreenButtonWrapper.hidden = hidden;
    
    if (_type == TGEmbedPlayerControlsTypeSimple)
        _largePlayButtonBack.hidden = hidden || _playing;
    
    if (hidden)
        [self setPanelHidden:true animated:false];
}

#pragma mark -

- (void)watermarkButtonPressed
{
    if (self.watermarkPressed != nil)
        self.watermarkPressed();
}

- (void)setWatermarkHidden:(bool)hidden
{
    _watermarkView.hidden = hidden;
}

- (void)setWatermarkPrerenderedOpacity:(bool)watermarkPrerenderedOpacity
{
    _watermarkPrerenderedOpacity = watermarkPrerenderedOpacity;
    if (watermarkPrerenderedOpacity && _watermarkView.alpha > FLT_EPSILON)
        _watermarkView.alpha = 1.0f;
}

- (void)setInternalWatermarkHidden:(bool)hidden animated:(bool)animated
{
    if (_type != TGEmbedPlayerControlsTypeFull)
        return;
    
    CGFloat visibleAlpha = _watermarkPrerenderedOpacity ? 1.0f : 0.6f;
    
    if (animated)
    {
        [UIView animateWithDuration:0.25 animations:^
        {
            _watermarkView.alpha = hidden ? 0.0f : visibleAlpha;
        }];
    }
    else
    {
        _watermarkView.alpha = hidden ? 0.0f : visibleAlpha;
    }
}

- (UIImage *)watermarkImage
{
    return [_watermarkView imageForState:UIControlStateNormal];
}

- (void)setWatermarkImage:(UIImage *)watermarkImage
{
    [_watermarkView setImage:watermarkImage forState:UIControlStateNormal];
    [_watermarkView sizeToFit];
    [self setNeedsLayout];
}

- (void)setWatermarkOffset:(CGPoint)watermarkOffset
{
    _watermarkOffset = watermarkOffset;
    [self setNeedsLayout];
}

- (void)setWatermarkPosition:(TGEmbedPlayerWatermarkPosition)watermarkPosition
{
    _watermarkPosition = watermarkPosition;
    [self setNeedsLayout];
}

#pragma mark -

- (void)setState:(TGEmbedPlayerState *)state
{
    _playing = state.isPlaying;
    
    if (_type == TGEmbedPlayerControlsTypeFull)
    {
        _playButton.hidden = _playing;
        _pauseButton.hidden = !_playing;
        
        NSInteger position = (NSInteger)state.position;
        NSString *positionString = [[NSString alloc] initWithFormat:@"%d:%02d", (int)position / 60, (int)position % 60];
        _positionLabel.text = positionString;
        
        NSInteger remaining = (NSInteger)(state.duration - state.position);
        NSString *remainingString = [[NSString alloc] initWithFormat:@"-%d:%02d", (int)remaining / 60, (int)remaining % 60];
        _remainingLabel.text = remainingString;
        
        CGFloat fractPosition = state.position / MAX(state.duration, 0.001);
        if (state.duration <= 0.01 || isnan(state.downloadProgress))
        {
            _remainingLabel.hidden = true;
            _scrubber.hidden = true;
        }
        else
        {
            _remainingLabel.hidden = false;
            _scrubber.hidden = false;
        }
        
        _positionLabel.hidden = (state.position < 0.0);
        
        if (!_scrubber.hidden)
        {
            [_scrubber setDownloadProgress:state.downloadProgress];
            [_scrubber setPosition:fractPosition];
        }
        
        if (!_watermarkDenyHiding)
            [self setInternalWatermarkHidden:_playing animated:true];
        
        if (_playing)
        {
            _largePlayButtonBack.hidden = true;
            _showingLargeButton = false;
        }
        
        if (!_playing && !_animatingPanel && _panelHidden && !_showingLargeButton)
        {
            [self setPanelHidden:false animated:true];
        }
        else
        {
            if (!_playing && _hidePanelTimer != nil)
                [self _invalidateTimer];
            else
                [self _startTimerIfNeeded];
        }
    }
    else if (_type == TGEmbedPlayerControlsTypeSimple)
    {
        _largePlayButtonBack.hidden = _controlsHidden || _playing;
    }
}

- (void)hidePanelEvent
{
    [self _invalidateTimer];
    [self setPanelHidden:true animated:true];
}

- (void)_startTimer
{
    _hidePanelTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(hidePanelEvent) interval:3.0 repeat:false];
}

- (void)_startTimerIfNeeded
{
    if (_playing && !_panelHidden && _hidePanelTimer == nil)
        [self _startTimer];
}

- (void)_invalidateTimer
{
    [_hidePanelTimer invalidate];
    _hidePanelTimer = nil;
}

- (void)screenAreaPressed
{
    if (_type == TGEmbedPlayerControlsTypeFull)
    {
        if (_panelHidden)
        {
            [self setPanelHidden:false animated:true];
        }
        else
        {
            if (_playing)
                [self pauseButtonPressed];
            else
                [self playButtonPressed];
        }
    }
    else if (_type == TGEmbedPlayerControlsTypeSimple)
    {
        if (_playing)
            [self pauseButtonPressed];
        else
            [self playButtonPressed];
    }
}

- (void)playButtonPressed
{
    if (_type == TGEmbedPlayerControlsTypeFull)
    {
        _largePlayButtonBack.hidden = true;
    }
    
    if (self.playPressed != nil)
        self.playPressed();
}

- (void)pauseButtonPressed
{
    _watermarkDenyHiding = false;
    
    if (self.pausePressed != nil)
        self.pausePressed();
}

- (void)fullscreenButtonPressed
{
    if (self.fullscreenPressed != nil)
        self.fullscreenPressed();
}

- (void)pictureInPictureButtonPressed
{
    if (self.pictureInPicturePressed != nil)
        self.pictureInPicturePressed();
}

- (void)setPictureInPictureHidden:(bool)hidden
{
    _pictureInPictureButton.hidden = hidden;
    [self setNeedsLayout];
}

- (void)setPanelHidden:(bool)hidden animated:(bool)animated
{
    if (_panelHidden == hidden)
        return;
    
    _panelHidden = hidden;
    
    if (self.panelVisibilityChange != nil)
        self.panelVisibilityChange(hidden);
    
    [self setFullscreenButtonDimmed:hidden animated:true];
    
    if (animated)
    {
        UIViewAnimationOptions options = kNilOptions;
        if (!hidden && iosMajorVersion() >= 7)
            options |= (7 << 16);
        else if (hidden)
            options |= UIViewAnimationOptionCurveEaseOut;

        _animatingPanel = true;
        
        NSTimeInterval duration = hidden ? 0.4 : 0.25;
        [UIView animateWithDuration:duration delay:0.0 options:options animations:^
        {
            if (hidden)
                _backgroundView.frame = CGRectMake(0, self.frame.size.height, self.frame.size.width, TGEmbedPlayerControlsPanelHeight);
            else
                _backgroundView.frame = CGRectMake(0, self.frame.size.height - _backgroundView.frame.size.height, self.frame.size.width, TGEmbedPlayerControlsPanelHeight);
            
            [self _layoutWatermark];
        } completion:^(__unused BOOL finished)
        {
            _animatingPanel = false;
        }];
    }
    else
    {
        _animatingPanel = false;
        if (hidden)
            _backgroundView.frame = CGRectMake(0, self.frame.size.height, self.frame.size.width, TGEmbedPlayerControlsPanelHeight);
        else
            _backgroundView.frame = CGRectMake(0, self.frame.size.height - _backgroundView.frame.size.height, self.frame.size.width, TGEmbedPlayerControlsPanelHeight);
        
        [self _layoutWatermark];
    }
}

- (void)setFullscreenButtonHidden:(bool)hidden animated:(bool)animated
{
    CGFloat visibleAlpha = self.inhibitFullscreenButton ? 0.65f : 1.0f;
    if (animated)
    {
        _fullscreenButtonWrapper.userInteractionEnabled = !hidden;
        [UIView animateWithDuration:0.25 animations:^
        {
            _fullscreenButtonWrapper.alpha = hidden ? 0.0f : visibleAlpha;
        }];
    }
    else
    {
        _fullscreenButtonWrapper.userInteractionEnabled = !hidden;
        _fullscreenButtonWrapper.alpha = hidden ? 0.0f : visibleAlpha;
    }
}

- (void)setFullscreenButtonDimmed:(bool)dimmed animated:(bool)animated
{
    if (self.inhibitFullscreenButton && dimmed && _fullscreenButtonWrapper.alpha < FLT_EPSILON)
        return;
    
    if (animated)
    {
        NSTimeInterval duration = dimmed ? 0.5 : 0.25;
        [UIView animateWithDuration:duration animations:^
        {
            _fullscreenButtonWrapper.alpha = dimmed ? 0.65f : 1.0f;
        }];
    }
    else
    {
        _fullscreenButtonWrapper.alpha = dimmed ? 0.65f : 1.0f;
    }
}

- (void)setDisabled
{
    _disabled = true;
    _screenAreaButton.userInteractionEnabled = false;
}

- (void)hidePlayButton
{
    [_largePlayButtonBack removeFromSuperview];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *view = [super hitTest:point withEvent:event];
    if (!_disabled)
        return view;
    
    if (view == _watermarkView)
        return view;
    
    return nil;
}

- (void)notifyOfPlaybackStart
{
    TGDispatchAfter(0.1, dispatch_get_main_queue(), ^
    {
        if (!self.inhibitFullscreenButton)
            [self setFullscreenButtonHidden:false animated:true];
        
        TGDispatchAfter(2.5, dispatch_get_main_queue(), ^
        {
            if (_panelHidden)
                [self setFullscreenButtonDimmed:true animated:true];
        
            if (_playing)
                [self setInternalWatermarkHidden:true animated:true];
            
            _watermarkDenyHiding = false;
        });
    });
}

- (void)_layoutWatermark
{
    CGFloat visiblePanelHeight = _panelHidden ? 0.0f : TGEmbedPlayerControlsPanelHeight;
    CGRect watermarkFrame = CGRectMake(0, 0, _watermarkView.frame.size.width, _watermarkView.frame.size.height);
    switch (_watermarkPosition)
    {
        case TGEmbedPlayerWatermarkPositionTopLeft:
        {
            watermarkFrame.origin = _watermarkOffset;
        }
            break;
            
        case TGEmbedPlayerWatermarkPositionBottomLeft:
        {
            watermarkFrame.origin = CGPointMake(_watermarkOffset.x, self.frame.size.height - watermarkFrame.size.height - visiblePanelHeight + _watermarkOffset.y);
        }
            break;
            
        case TGEmbedPlayerWatermarkPositionBottomRight:
        {
            watermarkFrame.origin = CGPointMake(self.frame.size.width - watermarkFrame.size.width + _watermarkOffset.x, self.frame.size.height - watermarkFrame.size.height - visiblePanelHeight + _watermarkOffset.y);
        }
            break;
            
        default:
            break;
    }
    _watermarkView.frame = watermarkFrame;
}

- (void)layoutSubviews
{
    _fullscreenButtonWrapper.frame = CGRectMake(self.bounds.size.width - _fullscreenButtonWrapper.frame.size.width, 0, _fullscreenButtonWrapper.frame.size.width, _fullscreenButtonWrapper.frame.size.height);
    
    CGFloat rightOffset = _pictureInPictureButton.hidden ? 0.0f : 35.0f;
    _remainingLabel.frame = CGRectMake(self.frame.size.width - _remainingLabel.frame.size.width - rightOffset, 0.0f, _remainingLabel.frame.size.width, _remainingLabel.frame.size.height);
    
    _pictureInPictureButton.frame = CGRectMake(self.frame.size.width - _pictureInPictureButton.frame.size.width, 0, _pictureInPictureButton.frame.size.width, _pictureInPictureButton.frame.size.height);
    
    _scrubber.frame = CGRectMake(CGRectGetMaxX(_positionLabel.frame), 14.5f, self.frame.size.width - CGRectGetMaxX(_positionLabel.frame) - _remainingLabel.frame.size.width - rightOffset, 3.0f);
    
    if (!_animatingPanel || _backgroundView.frame.size.width < FLT_EPSILON)
    {
        if (_panelHidden)
            _backgroundView.frame = CGRectMake(0, self.frame.size.height, self.frame.size.width, TGEmbedPlayerControlsPanelHeight);
        else
            _backgroundView.frame = CGRectMake(0, self.frame.size.height - _backgroundView.frame.size.height, self.frame.size.width, TGEmbedPlayerControlsPanelHeight);
    }

    [self _layoutWatermark];
    
    _largePlayButtonBack.frame = CGRectMake(CGFloor((self.frame.size.width - _largePlayButtonBack.frame.size.width) / 2.0f), CGFloor((self.frame.size.height - _largePlayButtonBack.frame.size.height) / 2.0f), _largePlayButtonBack.frame.size.width, _largePlayButtonBack.frame.size.height);
}

@end
