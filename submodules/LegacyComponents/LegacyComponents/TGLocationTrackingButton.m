#import "TGLocationTrackingButton.h"

#import "TGImageUtils.h"
#import "LegacyComponentsInternal.h"

@interface TGLocationTrackingButton ()
{
    UIImageView *_noneModeIconView;
    UIImageView *_followModeIconView;
    UIImageView *_followWithHeadingModeIconView;
    UIActivityIndicatorView *_activityIndicator;
}
@end

@implementation TGLocationTrackingButton

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.exclusiveTouch = true;
        
        _noneModeIconView = [[UIImageView alloc] initWithFrame:self.bounds];
        _noneModeIconView.contentMode = UIViewContentModeCenter;
        _noneModeIconView.image = TGComponentsImageNamed(@"TrackingLocationOff.png");
        [self addSubview:_noneModeIconView];
        
        _followModeIconView = [[UIImageView alloc] initWithFrame:self.bounds];
        _followModeIconView.contentMode = UIViewContentModeCenter;
        _followModeIconView.image = TGComponentsImageNamed(@"TrackingLocation.png");
        [self addSubview:_followModeIconView];
        
        _followWithHeadingModeIconView = [[UIImageView alloc] initWithFrame:CGRectOffset(self.bounds, 1, 0.5f)];
        _followWithHeadingModeIconView.contentMode = UIViewContentModeCenter;
        _followWithHeadingModeIconView.image = TGComponentsImageNamed(@"TrackingHeading.png");
        [self addSubview:_followWithHeadingModeIconView];
        
        _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _activityIndicator.userInteractionEnabled = false;
        _activityIndicator.frame = CGRectOffset(_activityIndicator.frame, 0, 0);
        _activityIndicator.alpha = 0.0f;
        _activityIndicator.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
        [self addSubview:_activityIndicator];
        
        _locationAvailable = true;
        [self setTrackingMode:TGLocationTrackingModeNone];
    }
    return self;
}

- (void)setAccentColor:(UIColor *)accentColor spinnerColor:(UIColor *)spinnerColor
{
    _noneModeIconView.image = TGTintedImage(TGComponentsImageNamed(@"TrackingLocationOff.png"), accentColor);
    _followModeIconView.image = TGTintedImage(TGComponentsImageNamed(@"TrackingLocation.png"), accentColor);
    _followWithHeadingModeIconView.image = TGTintedImage(TGComponentsImageNamed(@"TrackingHeading.png"), accentColor);
    _activityIndicator.color = spinnerColor;
}

- (void)setTrackingMode:(TGLocationTrackingMode)trackingMode
{
    [self setTrackingMode:trackingMode animated:false];
}

- (void)setTrackingMode:(TGLocationTrackingMode)trackingMode animated:(bool)animated
{
    _trackingMode = trackingMode;
    
    CGFloat noneModeAlpha = (trackingMode == TGLocationTrackingModeNone) ? 1.0f : 0.0f;
    CGFloat followModeAlpha = (trackingMode == TGLocationTrackingModeFollow) ? 1.0f : 0.0f;
    CGFloat followWithHeadingModeAlpha = (trackingMode == TGLocationTrackingModeFollowWithHeading) ? 1.0f : 0.0f;
    
    void (^changeBlock)(void) = ^
    {
        _noneModeIconView.alpha = noneModeAlpha;
        _followModeIconView.alpha = followModeAlpha;
        _followWithHeadingModeIconView.alpha = followWithHeadingModeAlpha;
        
        if (followWithHeadingModeAlpha < FLT_EPSILON)
        {
            _noneModeIconView.transform = CGAffineTransformIdentity;
            _followModeIconView.transform = CGAffineTransformIdentity;
            _followWithHeadingModeIconView.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
        }
        else
        {
            _noneModeIconView.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
            _followModeIconView.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
            _followWithHeadingModeIconView.transform = CGAffineTransformIdentity;
        }
    };
    
    if (animated)
        [UIView animateWithDuration:0.2f delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:changeBlock completion:nil];
    else
        changeBlock();
}

- (void)setIsLocationAvailable:(bool)available
{
    [self setLocationAvailable:available animated:false];
}

- (void)setLocationAvailable:(bool)available animated:(bool)animated
{
    if (available == _locationAvailable)
        return;
    
    _locationAvailable = available;
    
    if (animated)
    {
        
    }
    else
    {
        
    }
}

+ (TGLocationTrackingMode)locationTrackingModeWithUserTrackingMode:(MKUserTrackingMode)mode
{
    switch (mode)
    {
        case MKUserTrackingModeFollow:
            return TGLocationTrackingModeFollow;
            
        case MKUserTrackingModeFollowWithHeading:
            return TGLocationTrackingModeFollowWithHeading;
            
        default:
            return TGLocationTrackingModeNone;
    }
}

+ (MKUserTrackingMode)userTrackingModeWithLocationTrackingMode:(TGLocationTrackingMode)mode
{
    switch (mode)
    {
        case TGLocationTrackingModeFollow:
            return MKUserTrackingModeFollow;
            
        case TGLocationTrackingModeFollowWithHeading:
            return MKUserTrackingModeFollowWithHeading;
            
        default:
            return MKUserTrackingModeNone;
    }
}

@end
