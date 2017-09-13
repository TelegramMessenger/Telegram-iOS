#import "TGLocationVenueCell.h"

#import "LegacyComponentsInternal.h"
#import "TGColor.h"
#import "TGFont.h"
#import "TGStringUtils.h"
#import "TGImageUtils.h"

#import "TGLocationVenue.h"

#import <LegacyComponents/TGImageView.h>

NSString *const TGLocationVenueCellKind = @"TGLocationVenueCellKind";
const CGFloat TGLocationVenueCellHeight = 56.0f;

@interface TGLocationVenueCell ()
{
    TGImageView *_iconView;
    UILabel *_titleLabel;
    UILabel *_addressLabel;
    UIView *_separatorView;
}
@end

@implementation TGLocationVenueCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self != nil)
    {
        self.selectedBackgroundView = [[UIView alloc] init];
        self.selectedBackgroundView.backgroundColor = TGSelectionColor();
        
        _iconView = [[TGImageView alloc] init];
        [self.contentView addSubview:_iconView];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGSystemFontOfSize(TGIsRetina() ? 16.5f : 16.0f);
        _titleLabel.textColor = [UIColor blackColor];
        [self.contentView addSubview:_titleLabel];
        
        _addressLabel = [[UILabel alloc] init];
        _addressLabel.backgroundColor = [UIColor clearColor];
        _addressLabel.font = TGSystemFontOfSize(13);
        _addressLabel.textColor = UIColorRGB(0xa6a6a6);
        [self.contentView addSubview:_addressLabel];
        
        _separatorView = [[UIView alloc] init];
        _separatorView.backgroundColor = TGSeparatorColor();
        [self addSubview:_separatorView];
    }
    return self;
}

- (void)prepareForReuse
{
    [_iconView reset];
}

- (void)configureWithVenue:(TGLocationVenue *)venue
{
    _titleLabel.text = venue.name;
    _addressLabel.text = venue.displayAddress;
    if (venue.categoryIconUrl != nil)
    {
        [_iconView loadUri:[NSString stringWithFormat:@"location-venue-icon://url=%@&width=%d&height=%d", [TGStringUtils stringByEscapingForURL:venue.categoryIconUrl.absoluteString], 48, 48] withOptions:nil];
    }
    else
    {
        [_iconView loadUri:@"embedded://" withOptions:@{ TGImageViewOptionEmbeddedImage:TGComponentsImageNamed(@"LocationGenericIcon.png") }];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat padding = 76.0f;
    CGFloat separatorThickness = TGScreenPixel;

    _iconView.frame = CGRectMake(12.0f, 4.0f, 48.0f, 48.0f);
    _titleLabel.frame = CGRectMake(padding, 9, self.frame.size.width - padding - 14, 20);
    _addressLabel.frame = CGRectMake(padding, 29, self.frame.size.width - padding - 14, 20);
    _separatorView.frame = CGRectMake(padding, self.frame.size.height - separatorThickness, self.frame.size.width - padding, separatorThickness);
}

@end
