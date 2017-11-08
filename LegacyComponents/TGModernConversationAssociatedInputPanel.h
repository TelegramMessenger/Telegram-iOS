#import <UIKit/UIKit.h>

typedef enum
{
    TGModernConversationAssociatedInputPanelDefaultStyle,
    TGModernConversationAssociatedInputPanelDarkStyle,
    TGModernConversationAssociatedInputPanelDarkBlurredStyle
} TGModernConversationAssociatedInputPanelStyle;

@interface TGModernConversationAssociatedInputPanel : UIView
{
    UIEdgeInsets _safeAreaInset;
}

@property (nonatomic, readonly) TGModernConversationAssociatedInputPanelStyle style;
@property (nonatomic, copy) void (^preferredHeightUpdated)();

@property (nonatomic, copy) void (^resultPreviewAppeared)(void);
@property (nonatomic, copy) void (^resultPreviewDisappeared)(bool restoreFocus);

@property (nonatomic) UIEdgeInsets safeAreaInset;
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

- (bool)hasSelectedItem;
- (void)selectPreviousItem;
- (void)selectNextItem;
- (void)commitSelectedItem;

- (void)animateIn;
- (void)animateOut:(void (^)())completion;

- (void)setBarInset:(CGFloat)barInset animated:(bool)animated;

@end
