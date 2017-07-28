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
