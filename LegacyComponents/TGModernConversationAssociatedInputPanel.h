#import <UIKit/UIKit.h>

typedef enum
{
    TGModernConversationAssociatedInputPanelDefaultStyle,
    TGModernConversationAssociatedInputPanelDarkStyle,
    TGModernConversationAssociatedInputPanelDarkBlurredStyle
} TGModernConversationAssociatedInputPanelStyle;

@interface TGModernConversationAssociatedInputPanel : UIView

@property (nonatomic, readonly) TGModernConversationAssociatedInputPanelStyle style;
@property (nonatomic, copy) void (^preferredHeightUpdated)();

@property (nonatomic) CGFloat overlayBarOffset;
@property (nonatomic) CGFloat barInset;
@property (nonatomic, copy) void (^updateOverlayBarOffset)(CGFloat);

- (CGFloat)preferredHeight;
- (bool)displayForTextEntryOnly;
- (bool)fillsAvailableSpace;
- (void)setNeedsPreferredHeightUpdate;

- (void)setSendAreaWidth:(CGFloat)sendAreaWidth attachmentAreaWidth:(CGFloat)attachmentAreaWidth;
- (void)setContentAreaHeight:(CGFloat)contentAreaHeight;

- (instancetype)initWithStyle:(TGModernConversationAssociatedInputPanelStyle)style;

- (void)selectPreviousItem;
- (void)selectNextItem;
- (void)commitSelectedItem;

- (void)animateIn;
- (void)animateOut:(void (^)())completion;

- (void)setBarInset:(CGFloat)barInset animated:(bool)animated;

@end
