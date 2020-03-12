#import "TGLocationSectionHeaderCell.h"

#import "TGLocationMapViewController.h"
#import "LegacyComponentsInternal.h"
#import "TGFont.h"

NSString *const TGLocationSectionHeaderKind = @"TGLocationSectionHeaderKind";
const CGFloat TGLocationSectionHeaderHeight = 29.0f;

@interface TGLocationSectionHeaderCell ()
{
    UILabel *_titleLabel;
}
@end

@implementation TGLocationSectionHeaderCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self != nil)
    {
        self.backgroundColor = UIColorRGB(0xf7f7f7);
        self.selectedBackgroundView = [[UIView alloc] init];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = self.backgroundColor;
        _titleLabel.font = TGMediumSystemFontOfSize(12);
        _titleLabel.textColor = UIColorRGB(0x8e8e93);
        [self addSubview:_titleLabel];
    }
    return self;
}

- (void)setPallete:(TGLocationPallete *)pallete
{
    if (pallete == nil || _pallete == pallete)
        return;
    
    _pallete = pallete;
    
    self.backgroundColor = pallete.sectionHeaderBackgroundColor;
    _titleLabel.backgroundColor = self.backgroundColor;
    _titleLabel.textColor = pallete.sectionHeaderTextColor;
}

- (void)configureWithTitle:(NSString *)title
{
    title = [title uppercaseString];
    
    void (^changeBlock)(void) = ^
    {
        _titleLabel.text = title;
    };
    
    if ([_titleLabel.text isEqualToString:title])
        return;
    
    if (_titleLabel.text.length == 0)
        changeBlock();
    else
        [UIView transitionWithView:_titleLabel duration:0.2 options:UIViewAnimationOptionTransitionCrossDissolve animations:changeBlock completion:nil];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat padding = 14.0f;
    _titleLabel.frame = CGRectMake(padding, 1.0f, self.frame.size.width - padding, self.frame.size.height - 2.0f);
}

@end
