#import "TGLocationCurrentLocationCell.h"

#import "LegacyComponentsInternal.h"
#import "TGColor.h"
#import "TGImageUtils.h"
#import "TGFont.h"

#import "TGLocationUtils.h"

NSString *const TGLocationCurrentLocationCellKind = @"TGLocationCurrentLocationCellKind";
const CGFloat TGLocationCurrentLocationCellHeight = 57;

@interface TGLocationCurrentLocationCell ()
{
    UIImageView *_iconView;
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    
    bool _isCurrentLocation;
}
@end

@implementation TGLocationCurrentLocationCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self != nil)
    {
        self.selectedBackgroundView = [[UIView alloc] init];
        self.selectedBackgroundView.backgroundColor = TGSelectionColor();
        
        _iconView = [[UIImageView alloc] initWithFrame:CGRectMake(14 + TGRetinaPixel, 8 + TGRetinaPixel, 40, 40)];
        _iconView.image = TGComponentsImageNamed(@"LocationCurrentIcon.png");
        [self.contentView addSubview:_iconView];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGBoldSystemFontOfSize(TGIsRetina() ? 16.5f : 16.0f);
        _titleLabel.text = TGLocalized(@"Map.SendMyCurrentLocation");
        _titleLabel.textColor = TGAccentColor();
        [self.contentView addSubview:_titleLabel];
        
        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.backgroundColor = [UIColor clearColor];
        _subtitleLabel.font = TGSystemFontOfSize(13);
        _subtitleLabel.text = TGLocalized(@"Map.Locating");
        _subtitleLabel.textColor = UIColorRGB(0xa6a6a6);
        [self.contentView addSubview:_subtitleLabel];
        
        _isCurrentLocation = true;
    }
    return self;
}

- (void)configureForCurrentLocationWithAccuracy:(CLLocationAccuracy)accuracy
{
    if (!_isCurrentLocation)
    {
        [UIView transitionWithView:self duration:0.2f options:UIViewAnimationOptionTransitionCrossDissolve animations:^
        {
            _titleLabel.text = TGLocalized(@"Map.SendMyCurrentLocation");
            _iconView.image = TGComponentsImageNamed(@"LocationCurrentIcon.png");
            
            if (accuracy > DBL_EPSILON)
            {
                NSString *accuracyString = [TGLocationUtils stringFromAccuracy:(NSInteger)accuracy];
                _subtitleLabel.text = [NSString stringWithFormat:TGLocalized(@"Map.AccurateTo"), accuracyString];
                
                _iconView.alpha = 1.0f;
                _titleLabel.alpha = 1.0f;
                _subtitleLabel.alpha = 1.0f;
            }
            else
            {
                _subtitleLabel.text = TGLocalized(@"Map.Locating");
                
                _iconView.alpha = 0.5f;
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
                _iconView.alpha = 1.0f;
                _titleLabel.alpha = 1.0f;
                _subtitleLabel.alpha = 1.0f;
            }];
        }
        else
        {
            _subtitleLabel.text = TGLocalized(@"Map.Locating");
            
            _iconView.alpha = 0.5f;
            _titleLabel.alpha = 0.5f;
            _subtitleLabel.alpha = 0.5f;
        }
    }
}

- (void)configureForCustomLocationWithAddress:(NSString *)address
{
    if (_isCurrentLocation)
    {
        [UIView transitionWithView:self duration:0.2f options:UIViewAnimationOptionTransitionCrossDissolve animations:^
        {
            _titleLabel.text = TGLocalized(@"Map.SendThisLocation");
            _iconView.image = TGComponentsImageNamed(@"LocationPinIcon.png");
            _subtitleLabel.text = [self _subtitleForAddress:address];
            
            _iconView.alpha = 1.0f;
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
        
    CGFloat padding = 65.0f;
    _titleLabel.frame = CGRectMake(padding, 9, self.frame.size.width - padding - 14, 20);
    _subtitleLabel.frame = CGRectMake(padding, 29 + TGRetinaPixel, self.frame.size.width - padding - 14, 20);
}

@end
