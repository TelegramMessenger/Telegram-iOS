#import "TGPhotoStickersSectionHeaderView.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"
#import "TGImageUtils.h"

const CGFloat TGPhotoStickersSectionHeaderHeight = 56.0f;

@interface TGPhotoStickersSectionHeaderView ()
{
    UILabel *_titleLabel;
}
@end

@implementation TGPhotoStickersSectionHeaderView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.textColor = UIColorRGB(0xafb2b1);
        _titleLabel.font = TGSystemFontOfSize(17.0f);
        [self addSubview:_titleLabel];
    }
    return self;
}

- (void)setTitle:(NSString *)title
{
    _titleLabel.text = title;
    [_titleLabel sizeToFit];
    
    [self setNeedsLayout];
}

- (void)setTextColor:(UIColor *)color
{
    _titleLabel.textColor = color;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    _titleLabel.frame = (CGRect){{16.0f, TGRetinaFloor((self.bounds.size.height - _titleLabel.frame.size.height) / 2.0f) + 5.0f}, { _titleLabel.frame.size.width, _titleLabel.frame.size.height }};
}

@end
