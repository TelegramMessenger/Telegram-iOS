#import <LegacyComponents/HPGrowingTextView.h>

@class TGModernConversationAssociatedInputPanel;
@class TGKeyCommandController;

@protocol TGMediaPickerCaptionInputPanelDelegate;

@interface TGMediaPickerCaptionInputPanel : UIView

- (instancetype)initWithKeyCommandController:(TGKeyCommandController *)keyCommandController frame:(CGRect)frame;

@property (nonatomic, weak) id<TGMediaPickerCaptionInputPanelDelegate> delegate;

@property (nonatomic, strong) NSString *caption;
- (void)setCaption:(NSString *)caption entities:(NSArray *)entities animated:(bool)animated;

@property (nonatomic, readonly) HPGrowingTextView *inputField;
@property (nonatomic, assign) bool allowEntities;

@property (nonatomic, assign) CGFloat bottomMargin;
@property (nonatomic, assign, getter=isCollapsed) bool collapsed;
- (void)setCollapsed:(bool)collapsed animated:(bool)animated;

- (void)replaceMention:(NSString *)mention;
- (void)replaceMention:(NSString *)mention username:(bool)username userId:(int32_t)userId;
- (void)replaceHashtag:(NSString *)hashtag;

- (void)adjustForOrientation:(UIInterfaceOrientation)orientation keyboardHeight:(CGFloat)keyboardHeight duration:(NSTimeInterval)duration animationCurve:(NSInteger)animationCurve;

- (void)dismiss;

- (CGFloat)heightForInputFieldHeight:(CGFloat)inputFieldHeight;
- (CGFloat)baseHeight;

- (void)setAssociatedPanel:(TGModernConversationAssociatedInputPanel *)associatedPanel animated:(bool)animated;
- (TGModernConversationAssociatedInputPanel *)associatedPanel;

- (void)setContentAreaHeight:(CGFloat)contentAreaHeight;

- (NSInteger)textCaretPosition;

@end

@protocol TGMediaPickerCaptionInputPanelDelegate <NSObject>

- (bool)inputPanelShouldBecomeFirstResponder:(TGMediaPickerCaptionInputPanel *)inputPanel;
- (void)inputPanelFocused:(TGMediaPickerCaptionInputPanel *)inputPanel;
- (void)inputPanelRequestedSetCaption:(TGMediaPickerCaptionInputPanel *)inputPanel text:(NSString *)text entities:(NSArray *)entities;
- (void)inputPanelMentionEntered:(TGMediaPickerCaptionInputPanel *)inputTextPanel mention:(NSString *)mention startOfLine:(bool)startOfLine;
- (void)inputPanelHashtagEntered:(TGMediaPickerCaptionInputPanel *)inputTextPanel hashtag:(NSString *)hashtag;
- (void)inputPanelAlphacodeEntered:(TGMediaPickerCaptionInputPanel *)inputTextPanel alphacode:(NSString *)alphacode;
- (void)inputPanelWillChangeHeight:(TGMediaPickerCaptionInputPanel *)inputPanel height:(CGFloat)height duration:(NSTimeInterval)duration animationCurve:(int)animationCurve;

@optional
- (void)inputPanelTextChanged:(TGMediaPickerCaptionInputPanel *)inputTextPanel text:(NSString *)text;

@end
