@import UIKit;

NS_ASSUME_NONNULL_BEGIN

@class IDTextView;

@protocol IDTextViewDelegate <UIScrollViewDelegate>
@optional
- (BOOL)textView:(IDTextView *)textView
        shouldChangeTextInRange:(NSRange)range
        replacementText:(NSString *)text;
- (void)textViewDidBeginEditing:(IDTextView *)textView;
- (void)textViewDidChange:(IDTextView *)textView;
- (void)textViewDidChangeSelection:(IDTextView *)textView;
- (void)textViewDidEndEditing:(IDTextView *)textView;
@end

@interface IDTextView : UIScrollView <UITextPasteConfigurationSupporting>

@property(nonatomic, copy) NSString *text;
@property(nonatomic, strong) UIFont *font;
@property(nonatomic, strong) UIColor *textColor;
@property(nonatomic) NSTextAlignment textAlignment;
@property(nonatomic) UIEdgeInsets textContainerInset;
@property(nonatomic, getter=isEditable) BOOL editable;
@property(nonatomic, getter=isSelectable) BOOL selectable;
@property(nonatomic) UITextAutocapitalizationType autocapitalizationType;
@property(nonatomic) UITextAutocorrectionType autocorrectionType;
@property(nonatomic) UITextSpellCheckingType spellCheckingType;
@property(nonatomic) UITextSmartQuotesType smartQuotesType;
@property(nonatomic) UITextSmartDashesType smartDashesType;
@property(nonatomic) UITextSmartInsertDeleteType smartInsertDeleteType;
@property(nonatomic) UITextInlinePredictionType inlinePredictionType;
@property(nonatomic) UITextMathExpressionCompletionType mathExpressionCompletionType;
@property(nonatomic) UIKeyboardType keyboardType;
@property(nonatomic) UIKeyboardAppearance keyboardAppearance;
@property(nonatomic) UIReturnKeyType returnKeyType;
@property(nonatomic) BOOL enablesReturnKeyAutomatically;
@property(nonatomic, getter=isSecureTextEntry) BOOL secureTextEntry;
@property(nullable, nonatomic, copy) UITextContentType textContentType;
@property(nullable, nonatomic, copy) UITextInputPasswordRules *passwordRules;
@property(nonatomic) UIWritingToolsBehavior writingToolsBehavior;
@property(nonatomic) UIWritingToolsResultOptions allowedWritingToolsResultOptions;
@property(nullable, nonatomic, strong) UIConversationContext *conversationContext;
@property(nonatomic) BOOL allowsNumberPadPopover;
@property(nullable, nonatomic, weak) id<IDTextViewDelegate> delegate;
@property(nullable, nonatomic, copy) UIPasteConfiguration *pasteConfiguration;
@property(nullable, nonatomic, weak) id<UITextPasteDelegate> pasteDelegate;

- (void)scrollRangeToVisible:(NSRange)range;

@end

@interface IDTextView (TextInputConformance) <UITextInput>
@end

NS_ASSUME_NONNULL_END
