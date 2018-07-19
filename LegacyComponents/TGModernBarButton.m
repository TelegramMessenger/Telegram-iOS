#import "TGModernBarButton.h"

#import <LegacyComponents/TGModernBackToolbarButton.h>

@interface TGModernBarButton ()
{
    UIImageView *_iconView;
}

@end

@implementation TGModernBarButton

- (instancetype)initWithImage:(UIImage *)image
{
    self = [super initWithFrame:CGRectMake(0.0f, 0.0f, image.size.width, image.size.height)];
    if (self)
    {
        _iconView = [[UIImageView alloc] initWithImage:image];
        [self addSubview:_iconView];
    }
    return self;
}

- (UIImage *)image
{
    return _iconView.image;
}

- (void)setImage:(UIImage *)image
{
    _iconView.image = image;
    _iconView.frame = CGRectMake(0.0f, 0.0f, image.size.width, image.size.height);
    [self setNeedsLayout];
}

- (UIEdgeInsets)alignmentRectInsets
{
    UIEdgeInsets insets = UIEdgeInsetsZero;
    insets = UIEdgeInsetsMake(0.0f, 0.0f, 8.0f, 0.0f);
    return insets;
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    if (self.superview.frame.size.height > 32.0f + 1.0f)
        _iconView.frame = CGRectMake(_portraitAdjustment.x, _portraitAdjustment.y, _iconView.frame.size.width, _iconView.frame.size.height);
    else
        _iconView.frame = CGRectMake(_landscapeAdjustment.x, _landscapeAdjustment.y, _iconView.frame.size.width, _iconView.frame.size.height);
}

@end
