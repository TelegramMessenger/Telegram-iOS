#import "TGAlphacodePanelCell.h"

#import "LegacyComponentsInternal.h"
#import "TGColor.h"
#import "TGFont.h"

#import "TGModernConversationAssociatedInputPanel.h"

NSString *const TGAlphacodePanelCellKind = @"TGAlphacodePanelCell";

@interface TGAlphacodePanelCell () {
    UILabel *_emojiLabel;
    UILabel *_descriptionLabel;
}

@end

@implementation TGAlphacodePanelCell

- (instancetype)initWithStyle:(TGModernConversationAssociatedInputPanelStyle)style {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:TGAlphacodePanelCellKind];
    if (self != nil) {
        UIColor *backgroundColor = [UIColor whiteColor];
        UIColor *nameColor = [UIColor blackColor];
        UIColor *usernameColor = [UIColor blackColor];
        UIColor *selectionColor = TGSelectionColor();
        
        if (style == TGModernConversationAssociatedInputPanelDarkStyle)
        {
            backgroundColor = UIColorRGB(0x171717);
            nameColor = [UIColor whiteColor];
            usernameColor = UIColorRGB(0x828282);
            selectionColor = UIColorRGB(0x292929);
        }
        else if (style == TGModernConversationAssociatedInputPanelDarkBlurredStyle)
        {
            backgroundColor = [UIColor clearColor];
            nameColor = [UIColor whiteColor];
            usernameColor = UIColorRGB(0x828282);
            selectionColor = UIColorRGB(0x3d3d3d);
        }
        
        self.backgroundColor = backgroundColor;
        self.backgroundView = [[UIView alloc] init];
        self.backgroundView.backgroundColor = backgroundColor;
        self.backgroundView.opaque = false;
        
        self.selectedBackgroundView = [[UIView alloc] init];
        self.selectedBackgroundView.backgroundColor = selectionColor;
        
        _emojiLabel = [[UILabel alloc] init];
        _emojiLabel.backgroundColor = [UIColor clearColor];
        _emojiLabel.textColor = nameColor;
        _emojiLabel.font = TGSystemFontOfSize(14.0f);
        _emojiLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_emojiLabel];
        
        _descriptionLabel = [[UILabel alloc] init];
        _descriptionLabel.backgroundColor = [UIColor clearColor];
        _descriptionLabel.textColor = usernameColor;
        _descriptionLabel.font = TGSystemFontOfSize(14.0f);
        _descriptionLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_descriptionLabel];
    }
    return self;
}

- (void)setPallete:(TGConversationAssociatedInputPanelPallete *)pallete
{
    if (pallete == nil || _pallete == pallete)
        return;
    
    _pallete = pallete;
    
    _emojiLabel.textColor = pallete.textColor;
    _descriptionLabel.textColor = pallete.textColor;
    
    self.backgroundColor = pallete.backgroundColor;
    self.backgroundView.backgroundColor = self.backgroundColor;
    self.selectedBackgroundView.backgroundColor = pallete.selectionColor;
}

- (void)setEmoji:(NSString *)emoji label:(NSString *)label {
    _emojiLabel.text = emoji;
    _descriptionLabel.text = label;
    
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGSize boundsSize = self.bounds.size;
    
    CGFloat leftInset = 11.0f;
    CGFloat rightInset = 6.0f;
    
    CGSize titleSize = [_emojiLabel.text sizeWithFont:_emojiLabel.font];
    titleSize.width = CGCeil(MIN((boundsSize.width - leftInset - rightInset) * 3.0f / 4.0f, titleSize.width));
    titleSize.height = CGCeil(titleSize.height);
    
    CGSize descriptionSize = [_descriptionLabel.text sizeWithFont:_descriptionLabel.font];
    descriptionSize.width = CGCeil(MIN(boundsSize.width - leftInset - 40.0f, descriptionSize.width));
    
    _emojiLabel.frame = CGRectMake(leftInset, CGFloor((boundsSize.height - titleSize.height) / 2.0f), titleSize.width, titleSize.height);
    _descriptionLabel.frame = CGRectMake(40.0f, CGFloor((boundsSize.height - descriptionSize.height) / 2.0f), descriptionSize.width, descriptionSize.height);
}

@end
