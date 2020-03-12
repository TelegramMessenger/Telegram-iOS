#import <UIKit/UIKit.h>

typedef enum
{
    TGModernConversationAssociatedInputPanelDefaultStyle,
    TGModernConversationAssociatedInputPanelDarkStyle,
    TGModernConversationAssociatedInputPanelDarkBlurredStyle
} TGModernConversationAssociatedInputPanelStyle;

@interface TGConversationAssociatedInputPanelPallete : NSObject

@property (nonatomic, readonly) bool isDark;
@property (nonatomic, readonly) UIColor *backgroundColor;
@property (nonatomic, readonly) UIColor *separatorColor;
@property (nonatomic, readonly) UIColor *selectionColor;
@property (nonatomic, readonly) UIColor *barBackgroundColor;
@property (nonatomic, readonly) UIColor *barSeparatorColor;
@property (nonatomic, readonly) UIColor *textColor;
@property (nonatomic, readonly) UIColor *secondaryTextColor;
@property (nonatomic, readonly) UIColor *accentColor;
@property (nonatomic, readonly) UIColor *placeholderBackgroundColor;
@property (nonatomic, readonly) UIColor *placeholderIconColor;
@property (nonatomic, readonly) UIImage *avatarPlaceholder;
@property (nonatomic, readonly) UIImage *closeIcon;
@property (nonatomic, readonly) UIImage *largeCloseIcon;

+ (instancetype)palleteWithDark:(bool)dark backgroundColor:(UIColor *)backgroundColor separatorColor:(UIColor *)separatorColor selectionColor:(UIColor *)selectionColor barBackgroundColor:(UIColor *)barBackgroundColor barSeparatorColor:(UIColor *)barSeparatorColor textColor:(UIColor *)textColor secondaryTextColor:(UIColor *)secondaryTextColor accentColor:(UIColor *)accentColor placeholderBackgroundColor:(UIColor *)placeholderBackgroundColor placeholderIconColor:(UIColor *)placeholderIconColor avatarPlaceholder:(UIImage *)avatarPlaceholder closeIcon:(UIImage *)closeIcon largeCloseIcon:(UIImage *)largeCloseIcon;

@end

@interface TGModernConversationAssociatedInputPanel : UIView
{
    UIEdgeInsets _safeAreaInset;
}

@property (nonatomic, readonly) TGModernConversationAssociatedInputPanelStyle style;
@property (nonatomic, copy) void (^preferredHeightUpdated)();

@property (nonatomic, copy) void (^resultPreviewAppeared)(void);
@property (nonatomic, copy) void (^resultPreviewDisappeared)(bool restoreFocus);

@property (nonatomic, strong) TGConversationAssociatedInputPanelPallete *pallete;
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
