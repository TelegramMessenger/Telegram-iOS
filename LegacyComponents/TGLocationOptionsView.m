#import "TGLocationOptionsView.h"

#import "TGModernButton.h"
#import "TGLocationMapModeControl.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"

@interface TGLocationOptionsView ()
{
    UIImageView *_backgroundView;
    TGModernButton *_mapModeButton;
    UIView *_mapModeClipView;
    UIView *_mapModeBackgroundView;
    TGLocationMapModeControl *_mapModeControl;
    TGLocationTrackingButton *_trackButton;
    UIView *_separatorView;
}
@end

@implementation TGLocationOptionsView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _mapModeClipView = [[UIView alloc] init];
        _mapModeClipView.clipsToBounds = true;
        [self addSubview:_mapModeClipView];
        
        _backgroundView = [[UIImageView alloc] init];
        _backgroundView.image = [TGComponentsImageNamed(@"LocationTopPanel") resizableImageWithCapInsets:UIEdgeInsetsMake(15.0f, 15.0f, 18.0f, 15.0f)];
        [self addSubview:_backgroundView];
        
        UIView *mapModeBackgroundView = nil;
        if (iosMajorVersion() >= 8)
        {
            _mapModeBackgroundView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight]];
            mapModeBackgroundView = ((UIVisualEffectView *)_mapModeBackgroundView).contentView;
        }
        else
        {
            _mapModeBackgroundView = [[UIView alloc] init];
            _mapModeBackgroundView.backgroundColor = [UIColor whiteColor];
            mapModeBackgroundView = _mapModeBackgroundView;
        }
        _mapModeBackgroundView.clipsToBounds = true;
        _mapModeBackgroundView.layer.cornerRadius = 4.0f;
        _mapModeBackgroundView.alpha = 0.0f;
        _mapModeBackgroundView.userInteractionEnabled = false;
        _mapModeBackgroundView.hidden = true;
        [_mapModeClipView addSubview:_mapModeBackgroundView];
        
        _mapModeControl = [[TGLocationMapModeControl alloc] init];
        _mapModeControl.selectedSegmentIndex = 0;
        [_mapModeControl addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
        [mapModeBackgroundView addSubview:_mapModeControl];
        
        _mapModeButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 45.0f, 45.0f)];
        _mapModeButton.adjustsImageWhenHighlighted = false;
        [_mapModeButton setImage:TGComponentsImageNamed(@"LocationInfo.png") forState:UIControlStateNormal];
        [_mapModeButton setImage:TGComponentsImageNamed(@"LocationInfo_Active.png") forState:UIControlStateSelected];
        [_mapModeButton setImage:TGComponentsImageNamed(@"LocationInfo_Active.png") forState:UIControlStateSelected | UIControlStateHighlighted];
        [_mapModeButton addTarget:self action:@selector(mapModeButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_mapModeButton];
        
        _trackButton = [[TGLocationTrackingButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 45.0f, 45.0f)];
        [_trackButton addTarget:self action:@selector(trackPressed:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_trackButton];
        
        _separatorView = [[UIView alloc] init];
        _separatorView.backgroundColor = UIColorRGB(0xcccccc);
        [self addSubview:_separatorView];
    }
    return self;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    bool result = [super pointInside:point withEvent:event];
    if (!result)
        result = [_mapModeControl pointInside:[self convertPoint:point toView:_mapModeControl] withEvent:event];
    
    return result;
}

- (void)mapModeButtonPressed
{
    _mapModeButton.selected = !_mapModeButton.selected;
    [self setMapModeControlHidden:!_mapModeButton.selected animated:true];
}

- (void)modeChanged:(TGLocationMapModeControl *)sender
{
    if (self.mapModeChanged != nil)
        self.mapModeChanged(sender.selectedSegmentIndex);
    
    _mapModeButton.selected = false;
    [self setMapModeControlHidden:true animated:true];
}

- (void)trackPressed:(TGLocationTrackingButton *)sender
{
    if (self.trackModePressed != nil)
        self.trackModePressed();
}

- (void)setTrackingMode:(TGLocationTrackingMode)trackingMode animated:(bool)animated
{
    [_trackButton setTrackingMode:trackingMode animated:animated];
}

- (void)setLocationAvailable:(bool)available animated:(bool)animated
{
    [_trackButton setLocationAvailable:available animated:animated];
}

- (void)layoutSubviews
{
    _backgroundView.frame = CGRectMake(-5.0f, -5.0f, 45.0f + 10.0f, 90.0f + 5.0f + 6.0f);
    _mapModeButton.frame = CGRectMake(0.0f, 0.0f, 45.0f, 45.0f);
    _trackButton.frame = CGRectMake(0.0f, 45.0f, 45.0f, 45.0f);
    _separatorView.frame = CGRectMake(0.0f, 45.0f, 45.0f, TGScreenPixel);
}

- (void)setMapModeControlHidden:(bool)hidden animated:(bool)animated
{
    _mapModeBackgroundView.userInteractionEnabled = !hidden;
    
    if (!hidden)
    {
        _mapModeClipView.frame = CGRectMake(-self.frame.origin.x + 12.0f, 8.0f, self.superview.frame.size.width - 45.0f - 12.0f, _mapModeControl.frame.size.height);
        _mapModeControl.frame = CGRectMake(0.0f, 0.0f, _mapModeClipView.frame.size.width - 16.0f, _mapModeControl.frame.size.height);
        
        if (_mapModeBackgroundView.hidden)
        {
            _mapModeBackgroundView.hidden = false;
            _mapModeBackgroundView.frame = CGRectMake(_mapModeClipView.frame.size.width, 0.0f, _mapModeClipView.frame.size.width - 16.0f, _mapModeControl.frame.size.height);
        }
    }
    
    if (animated)
    {
        [UIView animateWithDuration:0.3f delay:0.0f options:7 << 16 animations:^
        {
            _mapModeBackgroundView.frame = CGRectMake(hidden ? _mapModeClipView.frame.size.width : 0.0f, 0.0f, _mapModeClipView.frame.size.width - 16.0f, _mapModeControl.frame.size.height);
        } completion:nil];
        
        [UIView animateWithDuration:0.25f animations:^
        {
            _mapModeBackgroundView.alpha = hidden ? 0.0f : 1.0f;
        }];
    }
    else
    {
        _mapModeBackgroundView.alpha = hidden ? 0.0f : 1.0f;
    }
}

@end
