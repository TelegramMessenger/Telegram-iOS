#import "TGLocationCurrentLocationCell.h"
#import "TGLocationVenueCell.h"

#import "TGLocationMapViewController.h"
#import "LegacyComponentsInternal.h"
#import "TGColor.h"
#import "TGImageUtils.h"
#import "TGFont.h"
#import "TGLocationUtils.h"
#import "TGDateUtils.h"

#import "TGMessage.h"

#import "TGLocationWavesView.h"
#import "TGLocationLiveElapsedView.h"

NSString *const TGLocationCurrentLocationCellKind = @"TGLocationCurrentLocationCellKind";
const CGFloat TGLocationCurrentLocationCellHeight = 68;

@interface TGLocationCurrentLocationCell ()
{
    int32_t _messageId;
    bool _isCurrentLocation;
    
    UIView *_highlightView;
    
    UIImageView *_circleView;
    UIImageView *_iconView;
    TGLocationWavesView *_wavesView;
    
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    TGLocationLiveElapsedView *_elapsedView;
    UIView *_separatorView;
    
    SMetaDisposable *_remainingDisposable;
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
        
        _elapsedView = [[TGLocationLiveElapsedView alloc] init];
        [self.contentView addSubview:_elapsedView];
        
        _separatorView = [[UIView alloc] init];
        _separatorView.backgroundColor = TGSeparatorColor();
        [self addSubview:_separatorView];
        
        _wavesView = [[TGLocationWavesView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 48.0f, 48.0f)];
        [_circleView addSubview:_wavesView];
        
        _isCurrentLocation = true;
    }
    return self;
}

- (void)dealloc
{
    [_wavesView invalidate];
}

- (void)setPallete:(TGLocationPallete *)pallete
{
    if (pallete == nil || _pallete == pallete)
        return;
    
    _pallete = pallete;
    
    self.backgroundColor = pallete.backgroundColor;
    _highlightView.backgroundColor = pallete.selectionColor;
    _titleLabel.textColor = pallete.accentColor;
    _subtitleLabel.textColor = pallete.secondaryTextColor;
    _separatorView.backgroundColor = pallete.separatorColor;
    [_elapsedView setColor:pallete.accentColor];
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
    _messageId = 0;
    
    
    UIImage *icon = TGComponentsImageNamed(@"LocationMessagePinIcon");
    if (_pallete != nil)
        icon = TGTintedImage(icon, _pallete.iconColor);
    
    _iconView.image = icon;
    _titleLabel.textColor = self.pallete != nil ? self.pallete.accentColor : TGAccentColor();
    _elapsedView.hidden = true;
    
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
    
    [self setCircleColor:_pallete != nil ? _pallete.locationColor : UIColorRGB(0x008df2)];
    
    _separatorView.hidden = false;
    [_wavesView stop];
    _wavesView.hidden = true;
    
    [self setNeedsLayout];
}

- (void)configureForLiveLocationWithAccuracy:(CLLocationAccuracy)accuracy
{
    _messageId = 0;
    
    UIImage *icon = TGComponentsImageNamed(@"LocationMessageLiveIcon");
    if (_pallete != nil)
        icon = TGTintedImage(icon, _pallete.iconColor);
    
    _iconView.image = icon;
    _titleLabel.textColor = self.pallete != nil ? self.pallete.accentColor : TGAccentColor();
    _elapsedView.hidden = true;
    
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
    
    [self setCircleColor:_pallete != nil ? _pallete.liveLocationColor : UIColorRGB(0xff6464)];
    
    _separatorView.hidden = true;
    [_wavesView stop];
    _wavesView.hidden = true;
    
    [self setNeedsLayout];
}

- (void)configureForStopWithMessage:(TGMessage *)message remaining:(SSignal *)remaining
{
    bool changed = message.mid != _messageId;
    _messageId = message.mid;
    
    UIImage *icon = TGComponentsImageNamed(@"LocationMessagePinIcon");
    if (_pallete != nil)
        icon = TGTintedImage(icon, _pallete.iconColor);
    
    _iconView.image = icon;
    
    _titleLabel.textColor = self.pallete != nil ? self.pallete.destructiveColor : UIColorRGB(0xff3b2f);
    _titleLabel.text = TGLocalized(@"Map.StopLiveLocation");
    _subtitleLabel.text = [TGDateUtils stringForRelativeUpdate:[message actualDate]];
    
    _circleView.alpha = 1.0f;
    _titleLabel.alpha = 1.0f;
    _subtitleLabel.alpha = 1.0f;
    
    [self setCircleColor:_pallete != nil ? _pallete.liveLocationColor : UIColorRGB(0xff6464)];
    
    _separatorView.hidden = true;
    _wavesView.hidden = false;
    _wavesView.color = self.pallete != nil ? _pallete.iconColor : [UIColor whiteColor];
    [_wavesView start];
    
    if (changed)
    {
        _elapsedView.hidden = false;
        [self setNeedsLayout];
        
        TGLocationMediaAttachment *locationAttachment = message.locationAttachment;
        if (_remainingDisposable == nil)
            _remainingDisposable = [[SMetaDisposable alloc] init];
        
        __weak TGLocationCurrentLocationCell *weakSelf = self;
        [_remainingDisposable setDisposable:[remaining startWithNext:^(NSNumber *next)
        {
            __strong TGLocationCurrentLocationCell *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf->_elapsedView setRemaining:next.intValue period:locationAttachment.period];
        } completed:^
        {
            __strong TGLocationCurrentLocationCell *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                strongSelf->_elapsedView.hidden = true;
                [strongSelf setNeedsLayout];
            }
        }]];
    }
}

- (void)configureForCustomLocationWithAddress:(NSString *)address
{
    _messageId = 0;
    
    UIImage *icon = TGComponentsImageNamed(@"LocationMessagePinIcon");
    if (_pallete != nil)
        icon = TGTintedImage(icon, _pallete.iconColor);
    _iconView.image = icon;
    _titleLabel.textColor = self.pallete != nil ? self.pallete.accentColor : TGAccentColor();
    _elapsedView.hidden = true;
    
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
    
    [self setCircleColor:_pallete != nil ? _pallete.locationColor : UIColorRGB(0x008df2)];
    
    _separatorView.hidden = false;
    [_wavesView stop];
    _wavesView.hidden = true;
    
    [self setNeedsLayout];
}

- (void)configureForGroupLocationWithAddress:(NSString *)address
{
    _messageId = 0;
    
    UIImage *icon = TGComponentsImageNamed(@"LocationMessagePinIcon");
    if (_pallete != nil)
        icon = TGTintedImage(icon, _pallete.iconColor);
    _iconView.image = icon;
    _titleLabel.textColor = self.pallete != nil ? self.pallete.accentColor : TGAccentColor();
    _elapsedView.hidden = true;
    
    if (_isCurrentLocation)
    {
        [UIView transitionWithView:self duration:0.2f options:UIViewAnimationOptionTransitionCrossDissolve animations:^
         {
             _titleLabel.text = TGLocalized(@"Map.SetThisLocation");
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
    
    [self setCircleColor:_pallete != nil ? _pallete.locationColor : UIColorRGB(0x008df2)];
    
    _separatorView.hidden = true;
    [_wavesView stop];
    _wavesView.hidden = true;
    
    [self setNeedsLayout];
}

- (NSString *)_subtitleForAddress:(NSString *)address
{
    if (address != nil && address.length == 0)
        return TGLocalized(@"Map.Unknown");
    else if (address == nil)
        return TGLocalized(@"Map.Locating");

    return address;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
        
    CGFloat padding = 76.0f;
    CGFloat separatorThickness = TGScreenPixel;
    
    _titleLabel.frame = CGRectMake(padding, 14, self.frame.size.width - padding - 14 - (_elapsedView.hidden ? 0.0f : 38.0f), 20);
    _subtitleLabel.frame = CGRectMake(padding, 36, self.frame.size.width - padding - 14 - (_elapsedView.hidden ? 0.0f : 38.0f), 20);
    _separatorView.frame = CGRectMake(padding, self.frame.size.height - separatorThickness, self.frame.size.width - padding, separatorThickness);
    _elapsedView.frame = CGRectMake(self.frame.size.width - 30.0f - 15.0f, floor((self.frame.size.height - 30.0f) / 2.0f), 30.0f, 30.0f);
}

@end
