#import "TGMenuSheetTitleItemView.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"

#import "TGMenuSheetController.h"

@interface TGMenuSheetTitleItemView ()
{
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    
    bool _solidSubtitle;
}
@end

@implementation TGMenuSheetTitleItemView

- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle
{
    return [self initWithTitle:title subtitle:subtitle solidSubtitle:false];
}

- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle solidSubtitle:(bool)solidSubtitle
{
    self = [super initWithType:TGMenuSheetItemTypeDefault];
    if (self != nil)
    {
        _solidSubtitle = solidSubtitle;
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor whiteColor];
        _titleLabel.font = TGMediumSystemFontOfSize(13);
        _titleLabel.numberOfLines = 0;
        _titleLabel.text = title;
        _titleLabel.textColor = UIColorRGB(0x8f8f8f);
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_titleLabel];
        
        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.backgroundColor = [UIColor whiteColor];
        _subtitleLabel.font = TGSystemFontOfSize(13);
        _subtitleLabel.numberOfLines = 0;
        _subtitleLabel.text = subtitle;
        _subtitleLabel.textColor = UIColorRGB(0x8f8f8f);
        _subtitleLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_subtitleLabel];
    }
    return self;
}

- (void)setDark
{
    _titleLabel.backgroundColor = [UIColor clearColor];
    _titleLabel.textColor = UIColorRGB(0x777777);
    
    _subtitleLabel.backgroundColor = [UIColor clearColor];
    _subtitleLabel.textColor = UIColorRGB(0x777777);
    
    if (@available(iOS 11.0, *)) {
        self.accessibilityIgnoresInvertColors = true;
    }
}

- (void)setPallete:(TGMenuSheetPallete *)pallete
{
    _titleLabel.backgroundColor = [UIColor clearColor];
    _titleLabel.textColor = pallete.textColor;
    
    _subtitleLabel.backgroundColor = [UIColor clearColor];
    _subtitleLabel.textColor = _solidSubtitle ? pallete.textColor : pallete.secondaryTextColor;
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width screenHeight:(CGFloat)__unused screenHeight
{
    CGFloat height = 17.0f;
    
    if (_titleLabel.text.length > 0)
    {
        NSAttributedString *string = [[NSAttributedString alloc] initWithString:_titleLabel.text attributes:@{ NSFontAttributeName: _titleLabel.font }];
        CGSize textSize = [string boundingRectWithSize:CGSizeMake(width - 10.0f * 2.0f, screenHeight) options:NSStringDrawingUsesLineFragmentOrigin context:nil].size;
        _titleLabel.frame = CGRectMake(_titleLabel.frame.origin.x, _titleLabel.frame.origin.y, ceil(textSize.width), ceil(textSize.height));
        height += _titleLabel.frame.size.height;
    }

    if (_subtitleLabel.text.length > 0)
    {
        NSAttributedString *string = [[NSAttributedString alloc] initWithString:_subtitleLabel.text attributes:@{ NSFontAttributeName: _subtitleLabel.font }];
        CGSize textSize = [string boundingRectWithSize:CGSizeMake(width - 10.0f * 2.0f, screenHeight) options:NSStringDrawingUsesLineFragmentOrigin context:nil].size;
        _subtitleLabel.frame = CGRectMake(_subtitleLabel.frame.origin.x, _subtitleLabel.frame.origin.y, ceil(textSize.width), ceil(textSize.height));
        height += _subtitleLabel.frame.size.height;
    }
    
    height += 15.0f;
    
    return height;
}

- (bool)requiresDivider
{
    return true;
}

- (void)layoutSubviews
{
    CGFloat topOffset = 17.0f;
    
    if (_titleLabel.text.length > 0)
    {
        _titleLabel.frame = CGRectMake(floor((self.frame.size.width - _titleLabel.frame.size.width) / 2.0f), topOffset, _titleLabel.frame.size.width, _titleLabel.frame.size.height);
        topOffset += _titleLabel.frame.size.height;
    }
    
    if (_subtitleLabel.text.length > 0)
    {
        _subtitleLabel.frame = CGRectMake(floor((self.frame.size.width - _subtitleLabel.frame.size.width) / 2.0f), topOffset, _subtitleLabel.frame.size.width, _subtitleLabel.frame.size.height);
        topOffset += _subtitleLabel.frame.size.height;
    }
}

@end
