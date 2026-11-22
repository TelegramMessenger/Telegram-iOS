#import "IDTextView.h"
#import "IDTextLayoutCanvasView.h"
#import "IDTextLayoutCanvasViewInternal.h"
#import "IDTextCanvasAttachmentLifecycle.h"
#import "IDPrivateUIKit.h"
#import "IDPrivateUIKit+TextLayoutCanvas.h"

#include <math.h>

@interface IDTextView (Interaction)
- (void)id_installInteractionAssistant;
- (void)id_updateSelectionGestures;
@end

@interface IDTextView () <IDTextCanvasAttachmentLifecycleSink>

@property(nonatomic, strong, readwrite) NSTextContentStorage *id_textContentStorage;
@property(nonatomic, strong, readwrite) NSTextLayoutManager *id_textLayoutManager;
@property(nonatomic, strong, readwrite) NSTextContainer *id_textContainer;
@property(nonatomic, strong, readwrite) IDTextLayoutCanvasView *id_canvasView;
@property(nonatomic, strong, nullable, readwrite) id id_layoutController;
@property(nonatomic, strong, nullable, readwrite) id id_inputController;
@property(nonatomic, strong, nullable, readwrite) id id_interactionAssistant;
@property(nonatomic, strong, nullable, readwrite) UIView *id_selectionContainerView;

- (void)id_applyCanvasContentSize:(CGSize)canvasContentSize;

@end

@implementation IDTextView

@dynamic delegate;
@synthesize autocapitalizationType = _autocapitalizationType;
@synthesize autocorrectionType = _autocorrectionType;
@synthesize spellCheckingType = _spellCheckingType;
@synthesize smartQuotesType = _smartQuotesType;
@synthesize smartDashesType = _smartDashesType;
@synthesize smartInsertDeleteType = _smartInsertDeleteType;
@synthesize inlinePredictionType = _inlinePredictionType;
@synthesize mathExpressionCompletionType = _mathExpressionCompletionType;
@synthesize keyboardType = _keyboardType;
@synthesize keyboardAppearance = _keyboardAppearance;
@synthesize returnKeyType = _returnKeyType;
@synthesize enablesReturnKeyAutomatically = _enablesReturnKeyAutomatically;
@synthesize secureTextEntry = _secureTextEntry;
@synthesize textContentType = _textContentType;
@synthesize passwordRules = _passwordRules;
@synthesize writingToolsBehavior = _writingToolsBehavior;
@synthesize allowedWritingToolsResultOptions = _allowedWritingToolsResultOptions;
@synthesize conversationContext = _conversationContext;
@synthesize allowsNumberPadPopover = _allowsNumberPadPopover;

- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame
      initialSpellCheckingType:UITextSpellCheckingTypeDefault];
}

- (instancetype)initWithFrame:(CGRect)frame
      initialSpellCheckingType:(UITextSpellCheckingType)spellCheckingType {
    self = [super initWithFrame:frame];
    if (self == nil) {
        return nil;
    }

    _font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    _textColor = UIColor.labelColor;
    _textContainerInset = UIEdgeInsetsMake(8, 5, 8, 5);
    _editable = YES;
    _selectable = YES;
    _autocapitalizationType = UITextAutocapitalizationTypeSentences;
    _autocorrectionType = UITextAutocorrectionTypeDefault;
    _spellCheckingType = spellCheckingType;
    _smartQuotesType = UITextSmartQuotesTypeDefault;
    _smartDashesType = UITextSmartDashesTypeDefault;
    _smartInsertDeleteType = UITextSmartInsertDeleteTypeDefault;
    _inlinePredictionType = UITextInlinePredictionTypeDefault;
    _mathExpressionCompletionType = UITextMathExpressionCompletionTypeDefault;
    _keyboardType = UIKeyboardTypeDefault;
    _keyboardAppearance = UIKeyboardAppearanceDefault;
    _returnKeyType = UIReturnKeyDefault;
    _enablesReturnKeyAutomatically = NO;
    _secureTextEntry = NO;
    _writingToolsBehavior = UIWritingToolsBehaviorDefault;
    _allowedWritingToolsResultOptions = UIWritingToolsResultDefault;
    _allowsNumberPadPopover = YES;
    _pasteConfiguration = [[UIPasteConfiguration alloc]
        initWithTypeIdentifiersForAcceptingClass:NSString.class];

    [IDPrivateUIKit requireCompatibleRuntime];
    [IDPrivateUIKit installTextPasteSupportOnClass:self.class];

    _id_textContentStorage = [NSTextContentStorage new];
    _id_textContentStorage.textStorage = [NSTextStorage new];
    _id_textLayoutManager = [NSTextLayoutManager new];
    [_id_textContentStorage addTextLayoutManager:_id_textLayoutManager];
    _id_textContainer = [[NSTextContainer alloc]
        initWithSize:CGSizeMake(MAX(frame.size.width - 10, 0), CGFLOAT_MAX)];
    _id_textLayoutManager.textContainer = _id_textContainer;

    _id_layoutController = [IDPrivateUIKit newLayoutControllerWithTextView:self
                                                             textContainer:_id_textContainer];
    [IDPrivateUIKit requireObject:_id_layoutController
                            stage:@"Private layout controller creation"];

    _id_canvasView = [[IDTextLayoutCanvasView alloc]
        initWithTextLayoutManager:_id_textLayoutManager
                    textContainer:_id_textContainer];
    _id_canvasView.context = self;
    IDPrivateRegisterTextLayoutCanvas(_id_layoutController, _id_textContainer, _id_canvasView);
    [self addSubview:_id_canvasView];
    IDPrivateTextContainerSetTextView(_id_textContainer, _id_canvasView);

    __weak IDTextView *weakSelf = self;
    _id_canvasView.contentSizeDidChange = ^(CGSize size) {
        [weakSelf id_applyCanvasContentSize:size];
    };
    [self registerForTraitChanges:@[UITraitDisplayScale.class]
                     withHandler:^(__kindof IDTextView *textView,
                                   UITraitCollection *previousCollection) {
        [textView.id_canvasView id_traitsChanged];
    }];

    _id_inputController = [IDPrivateUIKit newInputControllerWithLayoutController:_id_layoutController
                                                                         delegate:self];
    [IDPrivateUIKit requireObject:_id_inputController
                            stage:@"Private input controller creation"];
    [self id_preflightInputController:_id_inputController];
    switch (self.spellCheckingType) {
        case UITextSpellCheckingTypeNo:
            [self id_setInitialContinuousSpellCheckingEnabled:NO
                                            onInputController:_id_inputController];
            break;
        case UITextSpellCheckingTypeYes:
            [self id_setInitialContinuousSpellCheckingEnabled:YES
                                            onInputController:_id_inputController];
            break;
        case UITextSpellCheckingTypeDefault:
            break;
    }

    self.alwaysBounceVertical = YES;
    self.backgroundColor = UIColor.clearColor;
    [self id_installInteractionAssistant];
    return self;
}

- (void)id_setInitialContinuousSpellCheckingEnabled:(BOOL)enabled
                                  onInputController:(id)inputController {
    IDPrivateSetContinuousSpellCheckingEnabled(inputController, enabled);
}

- (void)id_preflightInputController:(id)controller {
    IDPrivateInputPreflightBackwardDeleteRanges(controller);
}

- (BOOL)canBecomeFirstResponder {
    return self.userInteractionEnabled && (self.isEditable || self.isSelectable);
}

- (void)setSelectable:(BOOL)selectable {
    if (_selectable == selectable) {
        return;
    }
    _selectable = selectable;
    [self id_updateSelectionGestures];
}

- (BOOL)becomeFirstResponder {
    BOOL wasFirstResponder = self.isFirstResponder;
    BOOL became = [super becomeFirstResponder];
    if (became && !wasFirstResponder) {
        IDPrivateInteractionSetSelectionVisible(self.id_interactionAssistant, YES);
        IDPrivateInteractionActivateSelection(self.id_interactionAssistant);
        [self.id_canvasView id_isEditingDidChange];
        if (self.id_selectionContainerView != nil) {
            [self bringSubviewToFront:self.id_selectionContainerView];
        }
        if (self.isEditable &&
            [self.delegate respondsToSelector:@selector(textViewDidBeginEditing:)]) {
            [self.delegate textViewDidBeginEditing:self];
        }
    }
    return became;
}

- (BOOL)resignFirstResponder {
    BOOL wasFirstResponder = self.isFirstResponder;
    BOOL wasEditable = self.isEditable;
    BOOL resigned = [super resignFirstResponder];
    if (resigned && wasFirstResponder) {
        IDPrivateInteractionSetSelectionVisible(self.id_interactionAssistant, NO);
        IDPrivateInteractionDeactivateSelection(self.id_interactionAssistant);
        [self.id_canvasView id_isEditingDidChange];
        if (self.id_selectionContainerView != nil) {
            [self bringSubviewToFront:self.id_selectionContainerView];
        }
        if (wasEditable &&
            [self.delegate respondsToSelector:@selector(textViewDidEndEditing:)]) {
            [self.delegate textViewDidEndEditing:self];
        }
    }
    return resigned;
}

- (void)id_reloadInputViewsForChangedTrait {
    if (self.isFirstResponder) {
        [self reloadInputViews];
    }
}

#define ID_DEFINE_SCALAR_TRAIT_SETTER(TYPE, NAME, IVAR) \
    - (void)set##NAME:(TYPE)value {                         \
        if (IVAR == value) {                               \
            return;                                        \
        }                                                   \
        IVAR = value;                                       \
        [self id_reloadInputViewsForChangedTrait];           \
    }

ID_DEFINE_SCALAR_TRAIT_SETTER(UITextAutocapitalizationType,
                              AutocapitalizationType,
                              _autocapitalizationType)
ID_DEFINE_SCALAR_TRAIT_SETTER(UITextAutocorrectionType, AutocorrectionType, _autocorrectionType)
ID_DEFINE_SCALAR_TRAIT_SETTER(UITextSpellCheckingType, SpellCheckingType, _spellCheckingType)
ID_DEFINE_SCALAR_TRAIT_SETTER(UITextSmartQuotesType, SmartQuotesType, _smartQuotesType)
ID_DEFINE_SCALAR_TRAIT_SETTER(UITextSmartDashesType, SmartDashesType, _smartDashesType)
ID_DEFINE_SCALAR_TRAIT_SETTER(UITextSmartInsertDeleteType,
                              SmartInsertDeleteType,
                              _smartInsertDeleteType)
ID_DEFINE_SCALAR_TRAIT_SETTER(UITextInlinePredictionType,
                              InlinePredictionType,
                              _inlinePredictionType)
ID_DEFINE_SCALAR_TRAIT_SETTER(UITextMathExpressionCompletionType,
                              MathExpressionCompletionType,
                              _mathExpressionCompletionType)
ID_DEFINE_SCALAR_TRAIT_SETTER(UIKeyboardType, KeyboardType, _keyboardType)
ID_DEFINE_SCALAR_TRAIT_SETTER(UIKeyboardAppearance, KeyboardAppearance, _keyboardAppearance)
ID_DEFINE_SCALAR_TRAIT_SETTER(UIReturnKeyType, ReturnKeyType, _returnKeyType)
ID_DEFINE_SCALAR_TRAIT_SETTER(BOOL,
                              EnablesReturnKeyAutomatically,
                              _enablesReturnKeyAutomatically)
ID_DEFINE_SCALAR_TRAIT_SETTER(BOOL, SecureTextEntry, _secureTextEntry)
ID_DEFINE_SCALAR_TRAIT_SETTER(UIWritingToolsBehavior,
                              WritingToolsBehavior,
                              _writingToolsBehavior)
ID_DEFINE_SCALAR_TRAIT_SETTER(UIWritingToolsResultOptions,
                              AllowedWritingToolsResultOptions,
                              _allowedWritingToolsResultOptions)
ID_DEFINE_SCALAR_TRAIT_SETTER(BOOL, AllowsNumberPadPopover, _allowsNumberPadPopover)

#undef ID_DEFINE_SCALAR_TRAIT_SETTER

- (void)setTextContentType:(UITextContentType)textContentType {
    if (_textContentType == textContentType || [_textContentType isEqualToString:textContentType]) {
        return;
    }
    _textContentType = [textContentType copy];
    [self id_reloadInputViewsForChangedTrait];
}

- (void)setPasswordRules:(UITextInputPasswordRules *)passwordRules {
    if (_passwordRules == passwordRules || [_passwordRules isEqual:passwordRules]) {
        return;
    }
    _passwordRules = [passwordRules copy];
    [self id_reloadInputViewsForChangedTrait];
}

- (void)setConversationContext:(UIConversationContext *)conversationContext {
    if (_conversationContext == conversationContext) {
        return;
    }
    _conversationContext = conversationContext;
    [self id_reloadInputViewsForChangedTrait];
}

- (NSString *)text {
    return self.id_textContentStorage.textStorage.string ?: @"";
}

- (NSString *)accessibilityValue {
    return self.text;
}

- (void)setText:(NSString *)text {
    NSString *plainText = text ?: @"";
    [self.id_textContentStorage performEditingTransactionUsingBlock:^{
        NSAttributedString *value = [[NSAttributedString alloc] initWithString:plainText];
        [self.id_textContentStorage.textStorage setAttributedString:value];
    }];
    [self id_applyUniformAttributes];
    [self setNeedsLayout];
}

- (void)setFont:(UIFont *)font {
    _font = font;
    [self id_applyUniformAttributes];
    [self setNeedsLayout];
}

- (void)setTextColor:(UIColor *)textColor {
    _textColor = textColor;
    [self id_applyUniformAttributes];
    [self.id_canvasView setNeedsDisplay];
}

- (void)setTextAlignment:(NSTextAlignment)textAlignment {
    _textAlignment = textAlignment;
    [self id_applyUniformAttributes];
    [self setNeedsLayout];
}

- (void)setTextContainerInset:(UIEdgeInsets)textContainerInset {
    _textContainerInset = textContainerInset;
    [self setNeedsLayout];
    IDPrivateInteractionSetNeedsSelectionDisplayUpdate(self.id_interactionAssistant);
}

- (void)id_applyUniformAttributes {
    NSTextStorage *textStorage = self.id_textContentStorage.textStorage;
    if (textStorage.length == 0 || self.font == nil || self.textColor == nil) {
        return;
    }

    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.alignment = self.textAlignment;
    NSRange all = NSMakeRange(0, textStorage.length);
    [textStorage addAttributes:@{
        NSFontAttributeName: self.font,
        NSForegroundColorAttributeName: self.textColor,
        NSParagraphStyleAttributeName: paragraph,
    } range:all];
    [self.id_canvasView setNeedsDisplay];
}

- (void)id_didMutateText {
    [self id_applyUniformAttributes];
    [self setNeedsLayout];
    [self.id_canvasView setNeedsDisplay];
    // The private controller can deliver selection before its final mutation geometry.
    // Reconcile visibility at the first point where the new storage extent is available.
    [self id_scrollCaretToVisibleIfNeeded];
    if ([self.delegate respondsToSelector:@selector(textViewDidChange:)]) {
        [self.delegate textViewDidChange:self];
    }
}

- (void)id_notifySelectionChanged {
    IDPrivateInteractionSelectionChanged(self.id_interactionAssistant);
    if ([self.delegate respondsToSelector:@selector(textViewDidChangeSelection:)]) {
        [self.delegate textViewDidChangeSelection:self];
    }
    [self id_scrollCaretToVisibleIfNeeded];
}

- (NSRange)id_NSRangeForTextRange:(UITextRange *)range {
    if (range == nil) {
        return NSMakeRange(NSNotFound, 0);
    }
    NSInteger location = [self offsetFromPosition:self.beginningOfDocument toPosition:range.start];
    NSInteger length = [self offsetFromPosition:range.start toPosition:range.end];
    return location < 0 || length < 0
        ? NSMakeRange(NSNotFound, 0)
        : NSMakeRange((NSUInteger)location, (NSUInteger)length);
}

- (NSRange)id_NSRangeForTextKitRanges:(NSArray<NSTextRange *> *)ranges {
    id<NSTextLocation> documentStart = self.id_textContentStorage.documentRange.location;
    NSUInteger minimum = NSNotFound;
    NSUInteger maximum = 0;
    for (NSTextRange *range in ranges) {
        NSInteger start = [self.id_textContentStorage offsetFromLocation:documentStart
                                                               toLocation:range.location];
        NSInteger end = [self.id_textContentStorage offsetFromLocation:documentStart
                                                             toLocation:range.endLocation];
        if (start < 0 || end < start) {
            return NSMakeRange(NSNotFound, 0);
        }
        minimum = minimum == NSNotFound ? (NSUInteger)start : MIN(minimum, (NSUInteger)start);
        maximum = MAX(maximum, (NSUInteger)end);
    }
    return minimum == NSNotFound
        ? NSMakeRange(NSNotFound, 0)
        : NSMakeRange(minimum, maximum - minimum);
}

- (void)id_scrollRectToVisible:(CGRect)target {
    UIEdgeInsets insets = self.adjustedContentInset;
    CGFloat visibleLeft = self.contentOffset.x + insets.left;
    CGFloat visibleRight = self.contentOffset.x + CGRectGetWidth(self.bounds) - insets.right;
    CGFloat visibleTop = self.contentOffset.y + insets.top;
    CGFloat visibleBottom = self.contentOffset.y + CGRectGetHeight(self.bounds) - insets.bottom;
    CGFloat targetOffsetX = self.contentOffset.x;
    CGFloat targetOffsetY = self.contentOffset.y;
    if (CGRectGetMinX(target) < visibleLeft) {
        targetOffsetX = CGRectGetMinX(target) - insets.left;
    } else if (CGRectGetMaxX(target) > visibleRight) {
        targetOffsetX = CGRectGetMaxX(target) - CGRectGetWidth(self.bounds) + insets.right;
    }
    if (CGRectGetMinY(target) < visibleTop) {
        targetOffsetY = CGRectGetMinY(target) - insets.top;
    } else if (CGRectGetMaxY(target) > visibleBottom) {
        targetOffsetY = CGRectGetMaxY(target) - CGRectGetHeight(self.bounds) + insets.bottom;
    }

    CGFloat minimumX = -insets.left;
    CGFloat maximumX = MAX(minimumX,
                           self.contentSize.width - CGRectGetWidth(self.bounds) + insets.right);
    CGFloat minimumY = -insets.top;
    CGFloat maximumY = MAX(minimumY,
                           self.contentSize.height - CGRectGetHeight(self.bounds) + insets.bottom);
    targetOffsetX = MIN(MAX(targetOffsetX, minimumX), maximumX);
    targetOffsetY = MIN(MAX(targetOffsetY, minimumY), maximumY);
    CGPoint targetOffset = CGPointMake(targetOffsetX, targetOffsetY);
    if (!CGPointEqualToPoint(targetOffset, self.contentOffset)) {
        [self setContentOffset:targetOffset animated:NO];
    }
}

- (void)id_scrollCaretToVisibleIfNeeded {
    // UIKit's private isEditing gate maps to this editor's public editing lifecycle.
    if (!self.isFirstResponder || !self.isEditable || !self.isScrollEnabled) {
        return;
    }
    UITextRange *selection = self.selectedTextRange;
    if (selection == nil || !selection.empty) {
        return;
    }

    // The controller can report selection before its text-change callback; force the
    // current TextKit storage through layout before deriving scroll limits.
    [self setNeedsLayout];
    [self layoutIfNeeded];
    CGRect caret = [self caretRectForPosition:selection.end];
    if (CGRectIsNull(caret) || !isfinite(caret.origin.x) || !isfinite(caret.origin.y) ||
        !isfinite(caret.size.width) || !isfinite(caret.size.height)) {
        return;
    }

    UIEdgeInsets insets = self.adjustedContentInset;
    CGRect visible = CGRectMake(self.contentOffset.x + insets.left,
                                self.contentOffset.y + insets.top,
                                MAX(CGRectGetWidth(self.bounds) - insets.left - insets.right, 0),
                                MAX(CGRectGetHeight(self.bounds) - insets.top - insets.bottom, 0));
    if (CGRectContainsRect(visible, caret)) {
        return;
    }
    [self id_scrollRectToVisible:caret];
}

- (void)scrollRangeToVisible:(NSRange)range {
    if (range.location == NSNotFound || range.location > self.text.length ||
        range.length > self.text.length - range.location) {
        return;
    }

    [self layoutIfNeeded];
    UITextPosition *start = [self positionFromPosition:self.beginningOfDocument
                                                offset:(NSInteger)range.location];
    UITextPosition *activeEdge = [self positionFromPosition:start
                                                     offset:(NSInteger)range.length];
    if (activeEdge == nil) {
        return;
    }

    CGRect target = [self caretRectForPosition:activeEdge];
    if (CGRectIsNull(target) || !isfinite(target.origin.x) || !isfinite(target.origin.y) ||
        !isfinite(target.size.width) || !isfinite(target.size.height)) {
        return;
    }
    [self id_scrollRectToVisible:CGRectInset(target, -4.0, -4.0)];
}

- (void)setNeedsDisplay {
    [super setNeedsDisplay];
    [self.id_canvasView setNeedsDisplay];
}

- (void)setContentOffset:(CGPoint)contentOffset {
    [super setContentOffset:contentOffset];
    [self.id_canvasView viewportBoundsDidChange];
}

- (void)setBounds:(CGRect)bounds {
    BOOL changed = !CGRectEqualToRect(self.bounds, bounds);
    [super setBounds:bounds];
    if (changed) {
        [self.id_canvasView viewportBoundsDidChange];
    }
}

- (void)safeAreaInsetsDidChange {
    [super safeAreaInsetsDidChange];
    [self.id_canvasView viewportBoundsDidChange];
}

- (void)adjustedContentInsetDidChange {
    [super adjustedContentInsetDidChange];
    [self.id_canvasView viewportBoundsDidChange];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat horizontalInset = self.textContainerInset.left + self.textContainerInset.right;
    CGFloat width = MAX(CGRectGetWidth(self.bounds) - horizontalInset, 0);
    self.id_textContainer.size = CGSizeMake(width, CGFLOAT_MAX);
    [self.id_textLayoutManager ensureLayoutForRange:self.id_textContentStorage.documentRange];

    CGRect usage = self.id_textLayoutManager.usageBoundsForTextContainer;
    CGSize canvasContentSize = CGSizeMake(MAX(CGRectGetMaxX(usage), 0),
                                          MAX(CGRectGetMaxY(usage), 0));
    [self id_applyCanvasContentSize:canvasContentSize];
    [self.id_canvasView setNeedsDisplay];
}

- (void)id_applyCanvasContentSize:(CGSize)canvasContentSize {
    CGFloat horizontalInset = self.textContainerInset.left + self.textContainerInset.right;
    CGFloat width = MAX(CGRectGetWidth(self.bounds) - horizontalInset, 0);
    CGFloat verticalInset = self.textContainerInset.top + self.textContainerInset.bottom;
    CGFloat height = ceil(MAX(CGRectGetHeight(self.bounds),
                              canvasContentSize.height + verticalInset));
    UITextRange *selection = self.selectedTextRange;
    if (selection != nil && selection.empty) {
        CGRect caret = [self caretRectForPosition:selection.end];
        if (!CGRectIsNull(caret) && isfinite(CGRectGetMaxY(caret))) {
            height = MAX(height, CGRectGetMaxY(caret) + self.textContainerInset.bottom);
        }
    }
    self.id_canvasView.frame = CGRectMake(self.textContainerInset.left,
                                          self.textContainerInset.top,
                                          width,
                                          MAX(0, height - verticalInset));
    if (self.id_selectionContainerView != nil) {
        self.id_selectionContainerView.frame = [self id_selectionContainerFrame];
        [self bringSubviewToFront:self.id_selectionContainerView];
    }
    [self.id_canvasView viewportBoundsDidChange];
    self.contentSize = CGSizeMake(CGRectGetWidth(self.bounds), height);
}

/// Where the selection container goes: at the canvas's origin, NOT the scroll host's.
///
/// UIKit hangs its selection views inside that container and moves geometry across the two spaces in
/// both directions — it converts a selection rect INTO the container (from `-textInputView`, which is
/// the canvas) and later reads the same numbers back relative to `-textInputView` again, without a
/// second conversion. So the two must be ONE space, and the canvas is positioned AT the text
/// container inset. A container left at this view's own origin was that inset out, which is where
/// the prompt offering the original spelling of a corrected word would come up.
- (CGRect)id_selectionContainerFrame {
    UIView *canvas = self.id_canvasView;
    CGPoint origin = canvas == nil ? CGPointZero : canvas.frame.origin;
    return (CGRect){origin, self.bounds.size};
}

- (void)id_canvasDidLayout {
    if (self.id_selectionContainerView != nil) {
        [self bringSubviewToFront:self.id_selectionContainerView];
    }
}

- (void)id_updateInteractionGeometry {
    IDPrivateInteractionSetNeedsSelectionDisplayUpdate(self.id_interactionAssistant);
    if (self.id_selectionContainerView != nil) {
        [self bringSubviewToFront:self.id_selectionContainerView];
    }
}

- (void)id_attachmentView:(UIView *)view
    didLayoutInFragmentFrame:(CGRect)fragmentFrame {
}

- (void)id_attachmentViewsDidEnterViewport:(NSSet<UIView *> *)views {
}

- (void)id_attachmentViewsDidLeaveViewport:(NSSet<UIView *> *)views {
}

@end
