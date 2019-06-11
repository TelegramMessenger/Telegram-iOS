#import "TGLocationVenueCell.h"

#import "TGLocationMapViewController.h"
#import "LegacyComponentsInternal.h"
#import "TGColor.h"
#import "TGFont.h"
#import "TGStringUtils.h"
#import "TGImageUtils.h"

#import "TGLocationVenue.h"

#import <LegacyComponents/TGImageView.h>

NSString *const TGLocationVenueCellKind = @"TGLocationVenueCell";
const CGFloat TGLocationVenueCellHeight = 56.0f;

@interface TGLocationVenueCell ()
{
    UIImageView *_circleView;
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
        
        _circleView = [[UIImageView alloc] initWithFrame:CGRectMake(12.0f, 12.0f, 48.0f, 48.0f)];
        [self setCircleColor:UIColorRGB(0xf2f2f2)];
        [self.contentView addSubview:_circleView];
        
        _iconView = [[TGImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 48.0f, 48.0f)];
        _iconView.contentMode = UIViewContentModeCenter;
        [_circleView addSubview:_iconView];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGSystemFontOfSize(16.0f);
        _titleLabel.textColor = [UIColor blackColor];
        [self.contentView addSubview:_titleLabel];
        
        _addressLabel = [[UILabel alloc] init];
        _addressLabel.backgroundColor = [UIColor clearColor];
        _addressLabel.font = TGSystemFontOfSize(13);
        _addressLabel.textColor = UIColorRGB(0x8e8e93);
        [self.contentView addSubview:_addressLabel];
        
        _separatorView = [[UIView alloc] init];
        _separatorView.backgroundColor = TGSeparatorColor();
        [self addSubview:_separatorView];
    }
    return self;
}

- (void)setPallete:(TGLocationPallete *)pallete
{
    if (pallete == nil || _pallete == pallete)
        return;
    
    _pallete = pallete;
    
    self.backgroundColor = pallete.backgroundColor;
    self.selectedBackgroundView.backgroundColor = pallete.selectionColor;
    [self setCircleColor:pallete.sectionHeaderBackgroundColor];
    _titleLabel.textColor = pallete.textColor;
    _addressLabel.textColor = pallete.secondaryTextColor;
    _separatorView.backgroundColor = pallete.separatorColor;
}

- (void)setCircleColor:(UIColor *)color
{
    UIImage *circleImage = [TGLocationVenueCell circleImage];
    _circleView.image = TGTintedImage(circleImage, color);
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [_iconView reset];
}

- (void)configureWithVenue:(TGLocationVenue *)venue
{
    _titleLabel.text = venue.name;
    _addressLabel.text = venue.displayAddress;
    if (venue.categoryName.length > 0)
    {
        [_iconView loadUri:[NSString stringWithFormat:@"location-venue-icon://type=%@&width=%d&height=%d&color=%d", venue.categoryName, 48, 48, TGColorHexCode(_pallete != nil ? _pallete.sectionHeaderTextColor : UIColorRGB(0xa0a0a0))] withOptions:nil];
    }
    else
    {
        UIImage *pinImage = TGComponentsImageNamed(@"LocationMessagePinIcon");
        if (self.pallete != nil)
            pinImage = TGTintedImage(pinImage, self.pallete.sectionHeaderTextColor);
        else
            pinImage = TGTintedImage(pinImage, UIColorRGB(0xa0a0a0));
        [_iconView loadUri:@"embedded://" withOptions:@{ TGImageViewOptionEmbeddedImage:pinImage }];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat padding = 76.0f;
    CGFloat separatorThickness = TGScreenPixel;

    _circleView.frame = CGRectMake(12.0f, 4.0f, 48.0f, 48.0f);
    _iconView.frame = CGRectMake(0.0f, 0.0f, 48.0f, 48.0f);
    _titleLabel.frame = CGRectMake(padding, 8, self.frame.size.width - padding - 14, 20);
    _addressLabel.frame = CGRectMake(padding, 29, self.frame.size.width - padding - 14, 20);
    _separatorView.frame = CGRectMake(padding, self.frame.size.height - separatorThickness, self.frame.size.width - padding, separatorThickness);
}

+ (UIImage *)circleImage
{
    static dispatch_once_t onceToken;
    static UIImage *circleImage;
    dispatch_once(&onceToken, ^
    {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(48.0f, 48.0f), false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
        CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, 48.0f, 48.0f));
        circleImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return circleImage;
}

@end
