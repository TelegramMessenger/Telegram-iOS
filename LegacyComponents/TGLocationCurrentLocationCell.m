#import "TGLocationCurrentLocationCell.h"
#import "TGLocationVenueCell.h"

#import "LegacyComponentsInternal.h"
#import "TGColor.h"
#import "TGImageUtils.h"
#import "TGFont.h"
#import "TGLocationUtils.h"

#import "TGLocationWavesView.h"

NSString *const TGLocationCurrentLocationCellKind = @"TGLocationCurrentLocationCellKind";
const CGFloat TGLocationCurrentLocationCellHeight = 68;

@interface TGLocationCurrentLocationCell ()
{
    UIView *_highlightView;
    
    UIImageView *_circleView;
    UIImageView *_iconView;
    TGLocationWavesView *_wavesView;
    
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    
    bool _isCurrentLocation;
    
    UIView *_separatorView;
}
@end

@implementation TGLocationCurrentLocationCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self != nil)
    {
        self.selectedBackgroundView = [[UIView alloc] init];
        self.selectedBackgroundView.backgroundColor = [UIColor clearColor];
        
        _highlightView = [[UIView alloc] initWithFrame:self.bounds];
        _highlightView.alpha = 0.0f;
        _highlightView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _highlightView.backgroundColor = TGSelectionColor();
        _highlightView.userInteractionEnabled = false;
        [self.contentView addSubview:_highlightView];
                                                       
        _circleView = [[UIImageView alloc] initWithFrame:CGRectMake(12.0f, 10.0f, 48.0f, 48.0f)];
        [self.contentView addSubview:_circleView];
        
        _iconView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 48.0f, 48.0f)];
        _iconView.contentMode = UIViewContentModeCenter;
        [_circleView addSubview:_iconView];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGBoldSystemFontOfSize(16.0);
        _titleLabel.text = TGLocalized(@"Map.SendMyCurrentLocation");
        _titleLabel.textColor = TGAccentColor();
        [self.contentView addSubview:_titleLabel];
        
        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.backgroundColor = [UIColor clearColor];
        _subtitleLabel.font = TGSystemFontOfSize(13);
        _subtitleLabel.text = TGLocalized(@"Map.Locating");
        _subtitleLabel.textColor = UIColorRGB(0xa6a6a6);
        [self.contentView addSubview:_subtitleLabel];
        
        _separatorView = [[UIView alloc] init];
        _separatorView.backgroundColor = TGSeparatorColor();
        [self addSubview:_separatorView];
        
        _wavesView = [[TGLocationWavesView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 48.0f, 48.0f)];
        [_circleView addSubview:_wavesView];
        
        _isCurrentLocation = true;
    }
    return self;
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    if (animated)
    {
        [UIView animateWithDuration:0.2 animations:^
         {
             _highlightView.alpha = highlighted ? 1.0f : 0.0f;
             _edgeView.alpha = highlighted ? 1.0f : 0.0f;
         }];
    }
    else
    {
        _highlightView.alpha = highlighted ? 1.0f : 0.0f;
        _edgeView.alpha = highlighted ? 1.0f : 0.0f;
    }
}

- (void)setCircleColor:(UIColor *)color
{
    UIImage *circleImage = [TGLocationVenueCell circleImage];
    _circleView.image = TGTintedImage(circleImage, color);
}

- (void)configureForCurrentLocationWithAccuracy:(CLLocationAccuracy)accuracy
{
    _iconView.image = TGComponentsImageNamed(@"LocationMessagePinIcon");
    
    if (!_isCurrentLocation)
    {
        [UIView transitionWithView:self duration:0.2f options:UIViewAnimationOptionTransitionCrossDissolve animations:^
        {
            _titleLabel.text = TGLocalized(@"Map.SendMyCurrentLocation");
            
            if (accuracy > DBL_EPSILON)
            {
                NSString *accuracyString = [TGLocationUtils stringFromAccuracy:(NSInteger)accuracy];
                _subtitleLabel.text = [NSString stringWithFormat:TGLocalized(@"Map.AccurateTo"), accuracyString];
                
                _circleView.alpha = 1.0f;
                _titleLabel.alpha = 1.0f;
                _subtitleLabel.alpha = 1.0f;
            }
            else
            {
                _subtitleLabel.text = TGLocalized(@"Map.Locating");
                
                _circleView.alpha = 0.5f;
                _titleLabel.alpha = 0.5f;
                _subtitleLabel.alpha = 0.5f;
            }
        } completion:nil];
        
        _isCurrentLocation = true;
    }
    else
    {
        if (accuracy > DBL_EPSILON)
        {
            NSString *accuracyString = [TGLocationUtils stringFromAccuracy:(NSInteger)accuracy];
            _subtitleLabel.text = [NSString stringWithFormat:TGLocalized(@"Map.AccurateTo"), accuracyString];
            
            [UIView animateWithDuration:0.2f animations:^
            {
                _circleView.alpha = 1.0f;
                _titleLabel.alpha = 1.0f;
                _subtitleLabel.alpha = 1.0f;
            }];
        }
        else
        {
            _subtitleLabel.text = TGLocalized(@"Map.Locating");
            
            _circleView.alpha = 0.5f;
            _titleLabel.alpha = 0.5f;
            _subtitleLabel.alpha = 0.5f;
        }
    }
    
    [self setCircleColor:UIColorRGB(0x008df2)];
    
    _separatorView.hidden = false;
    [_wavesView stop];
    _wavesView.hidden = true;
}

- (void)configureForLiveLocationWithAccuracy:(CLLocationAccuracy)accuracy
{
    _iconView.image = TGComponentsImageNamed(@"LocationMessageLiveIcon");
    
    [UIView transitionWithView:self duration:0.2f options:UIViewAnimationOptionTransitionCrossDissolve animations:^
    {
        _titleLabel.text = TGLocalized(@"Map.ShareLiveLocation");
        _subtitleLabel.text = TGLocalized(@"Map.ShareLiveLocationHelp");
        
        if (accuracy > DBL_EPSILON)
        {
            _circleView.alpha = 1.0f;
            _titleLabel.alpha = 1.0f;
            _subtitleLabel.alpha = 1.0f;
        }
        else
        {
            _circleView.alpha = 0.5f;
            _titleLabel.alpha = 0.5f;
            _subtitleLabel.alpha = 0.5f;
        }
    } completion:nil];
    
    [self setCircleColor:UIColorRGB(0xff6464)];
    
    _separatorView.hidden = true;
    [_wavesView stop];
    _wavesView.hidden = true;
}

- (void)configureForStopLiveLocation
{
    _iconView.image = TGComponentsImageNamed(@"LocationMessagePinIcon");
    
    _titleLabel.text = TGLocalized(@"Map.StopLiveLocation");
    _subtitleLabel.text = TGLocalized(@"Map.ShareLiveLocationHelp");
    
    _circleView.alpha = 1.0f;
    _titleLabel.alpha = 1.0f;
    _subtitleLabel.alpha = 1.0f;
    
    [self setCircleColor:UIColorRGB(0xff6464)];
    
    _separatorView.hidden = true;
    _wavesView.hidden = false;
    [_wavesView start];
}

- (void)configureForCustomLocationWithAddress:(NSString *)address
{
    _iconView.image = TGComponentsImageNamed(@"LocationMessagePinIcon");
    
    if (_isCurrentLocation)
    {
        [UIView transitionWithView:self duration:0.2f options:UIViewAnimationOptionTransitionCrossDissolve animations:^
        {
            _titleLabel.text = TGLocalized(@"Map.SendThisLocation");
            _subtitleLabel.text = [self _subtitleForAddress:address];
            
            _circleView.alpha = 1.0f;
            _titleLabel.alpha = 1.0f;
            _subtitleLabel.alpha = 1.0f;
        } completion:nil];
        
        _isCurrentLocation = false;
    }
    else
    {
        [UIView transitionWithView:self duration:0.2f options:UIViewAnimationOptionTransitionCrossDissolve animations:^
        {
            _subtitleLabel.text = [self _subtitleForAddress:address];
        } completion:nil];
    }
    
    [self setCircleColor:UIColorRGB(0x008df2)];
    
    _separatorView.hidden = false;
    [_wavesView stop];
    _wavesView.hidden = true;
}

- (NSString *)_subtitleForAddress:(NSString *)address
{
    if (address != nil && address.length == 0)
    {
        return TGLocalized(@"Map.Unknown");
    }
    else if (address == nil)
    {
        return TGLocalized(@"Map.Locating");
    }

    return address;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
        
    CGFloat padding = 76.0f;
    CGFloat separatorThickness = TGScreenPixel;
    
    _titleLabel.frame = CGRectMake(padding, 14, self.frame.size.width - padding - 14, 20);
    _subtitleLabel.frame = CGRectMake(padding, 36, self.frame.size.width - padding - 14, 20);
    _separatorView.frame = CGRectMake(padding, self.frame.size.height - separatorThickness, self.frame.size.width - padding, separatorThickness);
}

@end
