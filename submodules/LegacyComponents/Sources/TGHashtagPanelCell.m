#import "TGHashtagPanelCell.h"

#import "LegacyComponentsInternal.h"
#import "TGColor.h"
#import "TGFont.h"
#import "TGImageUtils.h"

#import "TGModernConversationAssociatedInputPanel.h"

NSString *const TGHashtagPanelCellKind = @"TGHashtagPanelCell";

@interface TGHashtagPanelCell ()
{
    TGModernConversationAssociatedInputPanelStyle _style;
    UILabel *_label;
    UIView *_separatorView;
}

@end

@implementation TGHashtagPanelCell

- (instancetype)initWithStyle:(TGModernConversationAssociatedInputPanelStyle)style
{
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:TGHashtagPanelCellKind];
    if (self != nil)
    {
        _style = style;
        
        UIColor *backgroundColor = [UIColor whiteColor];
        UIColor *textColor = [UIColor blackColor];
        UIColor *selectionColor = TGSelectionColor();
        
        if (style == TGModernConversationAssociatedInputPanelDarkStyle)
        {
            backgroundColor = UIColorRGB(0x171717);
            textColor = [UIColor whiteColor];
            selectionColor = UIColorRGB(0x292929);
        }
        else if (style == TGModernConversationAssociatedInputPanelDarkBlurredStyle)
        {
            backgroundColor = [UIColor clearColor];
            textColor = [UIColor whiteColor];
            selectionColor = UIColorRGB(0x3d3d3d);
        }
        
        self.backgroundColor = backgroundColor;
        self.backgroundView = [[UIView alloc] init];
        self.backgroundView.backgroundColor = backgroundColor;
        self.backgroundView.opaque = false;
        
        self.selectedBackgroundView = [[UIView alloc] init];
        self.selectedBackgroundView.backgroundColor = selectionColor;
        
        _label = [[UILabel alloc] init];
        _label.backgroundColor = [UIColor clearColor];
        _label.textColor = textColor;
        _label.font = TGSystemFontOfSize(14.0f);
        [self.contentView addSubview:_label];
    }
    return self;
}

- (void)setPallete:(TGConversationAssociatedInputPanelPallete *)pallete
{
    if (pallete == nil || _pallete == pallete)
        return;
    
    _pallete = pallete;
    
    _label.textColor = pallete.textColor;
    
    self.backgroundColor = pallete.backgroundColor;
    self.backgroundView.backgroundColor = self.backgroundColor;
    self.selectedBackgroundView.backgroundColor = pallete.selectionColor;
    
    _separatorView.backgroundColor = pallete.separatorColor;
}

- (void)setDisplaySeparator:(bool)displaySeparator
{
    if (displaySeparator && _separatorView == nil)
    {
        UIColor *separatorColor = _pallete != nil ? _pallete.separatorColor : TGSeparatorColor();
        if (_style == TGModernConversationAssociatedInputPanelDarkStyle)
            separatorColor = UIColorRGB(0x292929);
        
        _separatorView = [[UIView alloc] init];
        _separatorView.backgroundColor = separatorColor;
        [self insertSubview:_separatorView belowSubview:self.contentView];
        [self setNeedsLayout];
    }
}

- (void)setHashtag:(NSString *)hashtag
{
    _label.text = [[NSString alloc] initWithFormat:@"#%@", hashtag];
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat inset = 15.0f;
    CGSize labelSize = [_label.text sizeWithFont:_label.font];
    labelSize.width = CGCeil(MIN(labelSize.width, self.frame.size.width - inset * 2.0f));
    labelSize.height = CGCeil(labelSize.height);
    _label.frame = CGRectMake(inset, CGFloor((self.frame.size.height - labelSize.height) / 2.0f), labelSize.width, labelSize.height);
    
    if (_separatorView != nil)
    {
        CGFloat separatorHeight = TGScreenPixel;
        _separatorView.frame = CGRectMake(inset, self.frame.size.height - separatorHeight, self.frame.size.width - inset, separatorHeight);
    }
}

@end
