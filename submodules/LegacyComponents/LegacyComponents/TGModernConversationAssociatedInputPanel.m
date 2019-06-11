#import "TGModernConversationAssociatedInputPanel.h"

@implementation TGModernConversationAssociatedInputPanel

- (instancetype)initWithStyle:(TGModernConversationAssociatedInputPanelStyle)style
{
    _style = style;
    return [self initWithFrame:CGRectZero];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
    }
    return self;
}

- (CGFloat)preferredHeight
{
    return 75.0f;
}

- (bool)displayForTextEntryOnly {
    return false;
}

- (bool)fillsAvailableSpace {
    return false;
}

- (void)setNeedsPreferredHeightUpdate
{
    if (_preferredHeightUpdated)
        _preferredHeightUpdated();
}

- (void)setSendAreaWidth:(CGFloat)__unused sendAreaWidth attachmentAreaWidth:(CGFloat)__unused attachmentAreaWidth
{
}

- (void)setContentAreaHeight:(CGFloat)__unused contentAreaHeight {
}

- (bool)hasSelectedItem
{
    return false;
}

- (void)selectPreviousItem
{
}

- (void)selectNextItem
{
}

- (void)commitSelectedItem
{
}

- (void)animateIn {
}

- (void)animateOut:(void (^)())completion {
    if (completion) {
        completion();
    }
}

- (void)setBarInset:(CGFloat)barInset {
    [self setBarInset:barInset animated:false];
}

- (void)setBarInset:(CGFloat)barInset animated:(bool)__unused animated {
    _barInset = barInset;
}

@end


@implementation TGConversationAssociatedInputPanelPallete

+ (instancetype)palleteWithDark:(bool)dark backgroundColor:(UIColor *)backgroundColor separatorColor:(UIColor *)separatorColor selectionColor:(UIColor *)selectionColor barBackgroundColor:(UIColor *)barBackgroundColor barSeparatorColor:(UIColor *)barSeparatorColor textColor:(UIColor *)textColor secondaryTextColor:(UIColor *)secondaryTextColor accentColor:(UIColor *)accentColor placeholderBackgroundColor:(UIColor *)placeholderBackgroundColor placeholderIconColor:(UIColor *)placeholderIconColor avatarPlaceholder:(UIImage *)avatarPlaceholder closeIcon:(UIImage *)closeIcon largeCloseIcon:(UIImage *)largeCloseIcon
{
    TGConversationAssociatedInputPanelPallete *pallete = [[TGConversationAssociatedInputPanelPallete alloc] init];
    pallete->_isDark = dark;
    pallete->_backgroundColor = backgroundColor;
    pallete->_separatorColor = separatorColor;
    pallete->_selectionColor = selectionColor;
    pallete->_barBackgroundColor = barBackgroundColor;
    pallete->_barSeparatorColor = barSeparatorColor;
    pallete->_textColor = textColor;
    pallete->_secondaryTextColor = secondaryTextColor;
    pallete->_accentColor = accentColor;
    pallete->_placeholderBackgroundColor = placeholderBackgroundColor;
    pallete->_placeholderIconColor = placeholderIconColor;
    pallete->_avatarPlaceholder = avatarPlaceholder;
    pallete->_closeIcon = closeIcon;
    pallete->_largeCloseIcon = largeCloseIcon;
    return pallete;
}

@end
