#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDBlockTextView.h"

#import "IDBlockStackCanvasView.h"
#import "IDBlockTextViewInternal.h"
#import "IDInlineTextStyleResolver.h"
#import "IDPrivateUIKit.h"
#import "IDRichTextLayoutControllerInternal.h"
#import "IDRichTextSelectionRect.h"
#import "IDUIKitInputControllerCapability.h"
#import "IDUIKitInteractionCapability.h"
#import "IDCanonicalTextStorageAdapterInternal.h"

@protocol IDBlockUndoRedoResponderActions <NSObject>
- (void)undo:(id)sender;
- (void)redo:(id)sender;
@end

@implementation IDBlockTextView (TextInputConformance)

- (void)id_recordLatestCanonicalSelectionForAutoscroll {
    if (self.id_isPublishingAutoscrollSelection) {
        return;
    }
    NSRange current =
        [self id_NSRangeForTextRange:self.selectedTextRange];
    if (current.location == NSNotFound) {
        return;
    }
    self.id_previousCanonicalSelection =
        self.id_latestCanonicalSelection;
    self.id_latestCanonicalSelection = current;
}

- (void)id_setVerticalAutoscrollContentOffset:
    (CGPoint)contentOffset
                                      duration:
    (NSTimeInterval)duration {
    CGPoint current = self.contentOffset;
    CGFloat fraction = duration <= 0.0
        ? 1.0
        : MIN(0.075 / duration, 1.0);
    CGPoint incremental = CGPointMake(
        contentOffset.x,
        current.y +
            (contentOffset.y - current.y) * fraction);
    [UIView animateWithDuration:MIN(duration, 0.075)
                          delay:0.0
                        options:
        UIViewAnimationOptionBeginFromCurrentState |
        UIViewAnimationOptionAllowUserInteraction |
        UIViewAnimationOptionCurveLinear
                     animations:^{
                         self.contentOffset = incremental;
                     }
                     completion:nil];
}

- (NSString *)textInRange:(UITextRange *)range {
    return [self.id_behaviorInput textInRange:range];
}

- (void)replaceRange:(UITextRange *)range withText:(NSString *)text {
    [self.id_behaviorInput replaceRange:range withText:text];
}

- (UITextRange *)selectedTextRange {
    return self.id_behaviorInput.selectedTextRange;
}

- (void)setSelectedTextRange:(UITextRange *)range {
    [self.id_richLayoutController id_directSelectionReplacementDidOccur];
    self.id_behaviorInput.selectedTextRange = range;
}

- (UITextRange *)markedTextRange {
    return self.id_behaviorInput.markedTextRange;
}

- (NSDictionary<NSAttributedStringKey, id> *)markedTextStyle {
    return self.id_behaviorInput.markedTextStyle;
}

- (void)setMarkedTextStyle:(NSDictionary<NSAttributedStringKey, id> *)style {
    self.id_behaviorInput.markedTextStyle = style;
}

- (void)setMarkedText:(NSString *)text selectedRange:(NSRange)range {
    [self id_noteCompositionStartIfNeeded];
    [self.id_behaviorInput setMarkedText:text selectedRange:range];
}

- (void)setAttributedMarkedText:(NSAttributedString *)text
                  selectedRange:(NSRange)range {
    [self id_noteCompositionStartIfNeeded];
    [self.id_behaviorInput setAttributedMarkedText:text
                                    selectedRange:range];
}

/// Records what typing would have used, at the moment a composition starts. See
/// `id_compositionTypingAttributes`.
- (void)id_noteCompositionStartIfNeeded {
    // Only a host with a typed-text policy re-attributes a commit, so only then is the start worth
    // reading: the bare engine keeps its exact stock-parity read sequence.
    if (self.typedTextAttributePolicy == nil) {
        return;
    }
    if (self.markedTextRange == nil) {
        UITextRange *selection = self.selectedTextRange;
        self.id_compositionTypingAttributes = self.id_behaviorInput.typingAttributes;
        self.id_compositionReplacesSelection = self.id_compositionStartsOverResolvedSelection
            || (selection != nil && !selection.empty);
        self.id_compositionStartsOverResolvedSelection = NO;
    }
}

/// Gives a composition's committed text the attributes typing it would have had: first the typing
/// attributes the composition started with (what `insertText:` over the same selection uses), then —
/// for a composition at a CARET, where typing runs it — the host's typed-text policy. Over a SELECTION the controller attributes marked text by a rule of
/// its own — measured, a composition over a bold selection committed plain where typing stays bold,
/// and one over a selection ending in bold+spoiler took both where typing took neither (Telegram
/// composer harness, 2026-09-24, `HarnessCompositionFormattingTests`).
- (void)id_attributeCommittedComposition:(NSRange)committed
                        typingAttributes:(nullable NSDictionary<NSAttributedStringKey, id> *)typingAttributes
                       replacedSelection:(BOOL)replacedSelection {
    if (committed.location == NSNotFound || committed.length == 0) {
        return;
    }
    // Only when it changes something: a commit whose text already carries these attributes is not
    // an edit, and a no-op transform would still advance the document revision (the engine's own
    // `IDIMECompositionLifecycleContractTests` pins that a commit does not).
    //
    // And only for a composition that REPLACED A SELECTION: at a caret the controller already
    // attributes marked text with the typing attributes, as a stock text view does, and the engine's
    // own IME differential (`IDTextInputFastLifecycleTests`) pins that a caret composition's commit
    // matches stock exactly.
    __block BOOL differs = NO;
    if (replacedSelection && typingAttributes.count > 0 && NSMaxRange(committed) <= self.id_textStorageAdapter.length) {
        NSUInteger location = committed.location;
        while (location < NSMaxRange(committed) && !differs) {
            NSRange effective = NSMakeRange(location, 1);
            NSDictionary<NSAttributedStringKey, id> *attributes =
                [self.id_textStorageAdapter attributesAtIndex:location effectiveRange:&effective];
            if (![attributes isEqualToDictionary:typingAttributes]) {
                differs = YES;
            }
            location = MAX(location + 1, NSMaxRange(effective));
        }
    }
    if (differs) {
        [self.id_textStorageAdapter
            id_transformTextAttributesInCanonicalRange:committed
                                            usingBlock:^NSDictionary<NSAttributedStringKey, id> *(
                                                NSDictionary<NSAttributedStringKey, id> *attributes) {
            return typingAttributes;
        }];
    }
    if (!replacedSelection) {
        [self id_applyTypedTextPolicyToRange:committed];
    }
}

/// A composition's COMMIT is typing: the committed text gets the host's typed-text policy, as the
/// same text typed with `insertText:` does. The controller inserts marked text through its own
/// replacement, which the policy never sees, and nothing re-attributed the text when the composition
/// ended — so a composition inside a run whose marker only the policy continues (a host's spoiler,
/// inline code) committed OUTSIDE that run (Telegram composer harness, 2026-09-24,
/// `HarnessCompositionFormattingTests`).
- (void)unmarkText {
    if (self.typedTextAttributePolicy == nil) {
        [self.id_behaviorInput unmarkText];
        return;
    }
    UITextRange *marked = self.markedTextRange;
    NSRange committed = NSMakeRange(NSNotFound, 0);
    if (marked != nil && !marked.empty) {
        NSInteger start = [self offsetFromPosition:self.beginningOfDocument toPosition:marked.start];
        NSInteger length = [self offsetFromPosition:marked.start toPosition:marked.end];
        if (start >= 0 && length > 0) {
            committed = NSMakeRange((NSUInteger)start, (NSUInteger)length);
        }
    }
    NSDictionary<NSAttributedStringKey, id> *typingAttributes = self.id_compositionTypingAttributes;
    BOOL replacedSelection = self.id_compositionReplacesSelection;
    [self.id_behaviorInput unmarkText];
    if (self.markedTextRange == nil) {
        self.id_compositionTypingAttributes = nil;
        self.id_compositionReplacesSelection = NO;
        [self id_attributeCommittedComposition:committed typingAttributes:typingAttributes
                             replacedSelection:replacedSelection];
    }
}

- (UITextPosition *)beginningOfDocument {
    return self.id_behaviorInput.beginningOfDocument;
}

- (UITextPosition *)endOfDocument {
    return self.id_behaviorInput.endOfDocument;
}

- (UITextRange *)textRangeFromPosition:(UITextPosition *)fromPosition
                            toPosition:(UITextPosition *)toPosition {
    return [self.id_behaviorInput
        textRangeFromPosition:fromPosition
        toPosition:toPosition];
}

- (UITextPosition *)positionFromPosition:(UITextPosition *)position offset:(NSInteger)offset {
    return [self.id_behaviorInput positionFromPosition:position
                                               offset:offset];
}

- (UITextPosition *)positionFromPosition:(UITextPosition *)position
                             inDirection:(UITextLayoutDirection)direction
                                  offset:(NSInteger)offset {
    return [self.id_behaviorInput positionFromPosition:position
                                           inDirection:direction
                                                offset:offset];
}

- (NSComparisonResult)comparePosition:(UITextPosition *)position
                           toPosition:(UITextPosition *)other {
    return [self.id_behaviorInput comparePosition:position
                                       toPosition:other];
}

- (NSInteger)offsetFromPosition:(UITextPosition *)from
                     toPosition:(UITextPosition *)toPosition {
    return [self.id_behaviorInput offsetFromPosition:from
                                         toPosition:toPosition];
}

- (id<UITextInputDelegate>)inputDelegate {
    return self.id_behaviorInput.inputDelegate;
}

- (void)setInputDelegate:(id<UITextInputDelegate>)delegate {
    self.id_behaviorInput.inputDelegate = delegate;
}

- (id<UITextInputTokenizer>)tokenizer {
    return self.id_behaviorInput.tokenizer;
}

- (UITextPosition *)positionWithinRange:(UITextRange *)range
                    farthestInDirection:(UITextLayoutDirection)direction {
    return [self.id_behaviorInput
        positionWithinRange:range
        farthestInDirection:direction];
}

- (UITextRange *)characterRangeByExtendingPosition:(UITextPosition *)position
                                       inDirection:(UITextLayoutDirection)direction {
    return [self.id_behaviorInput
        characterRangeByExtendingPosition:position
        inDirection:direction];
}

- (NSWritingDirection)baseWritingDirectionForPosition:(UITextPosition *)position
                                           inDirection:(UITextStorageDirection)direction {
    return [self.id_behaviorInput
        baseWritingDirectionForPosition:position
        inDirection:direction];
}

- (void)setBaseWritingDirection:(NSWritingDirection)writingDirection
                       forRange:(UITextRange *)range {
    [self.id_behaviorInput setBaseWritingDirection:writingDirection
                                         forRange:range];
}

- (CGRect)firstRectForRange:(UITextRange *)range {
    return [self.id_behaviorInput firstRectForRange:range];
}

- (CGRect)caretRectForPosition:(UITextPosition *)position {
    return [self.id_behaviorInput caretRectForPosition:position];
}

- (NSArray<UITextSelectionRect *> *)selectionRectsForRange:(UITextRange *)range {
    if (range != nil && range.empty) {
        NSArray<UITextSelectionRect *> *documentRects =
            [self.id_behaviorInput selectionRectsForRange:range];
        NSMutableArray<UITextSelectionRect *> *editorRects =
            [NSMutableArray arrayWithCapacity:documentRects.count];
        for (UITextSelectionRect *documentRect in documentRects) {
            CGRect rect = [self.id_blockStack
                convertRect:documentRect.rect toView:self];
            CGFloat baselineOffset =
                [documentRect isKindOfClass:IDRichTextSelectionRect.class]
                    ? ((IDRichTextSelectionRect *)documentRect).baselineOffset : 0.0;
            [editorRects addObject:[[IDRichTextSelectionRect alloc]
                initWithRect:rect
                baselineOffset:baselineOffset
                containsStart:documentRect.containsStart
                containsEnd:documentRect.containsEnd
                isVertical:documentRect.isVertical
                writingDirection:documentRect.writingDirection]];
        }
        return editorRects.copy;
    }
    return [self.id_behaviorInput selectionRectsForRange:range];
}

- (UITextPosition *)closestPositionToPoint:(CGPoint)point {
    return [self.id_behaviorInput closestPositionToPoint:point];
}

- (UITextPosition *)closestPositionToPoint:(CGPoint)point withinRange:(UITextRange *)range {
    return [self.id_behaviorInput closestPositionToPoint:point
                                            withinRange:range];
}

- (UITextRange *)characterRangeAtPoint:(CGPoint)point {
    return [self.id_behaviorInput characterRangeAtPoint:point];
}

- (NSDictionary<NSAttributedStringKey, id> *)textStylingAtPosition:(UITextPosition *)position
                                                        inDirection:(UITextStorageDirection)direction {
    return [self.id_behaviorInput textStylingAtPosition:position
                                           inDirection:direction];
}

- (UITextPosition *)positionWithinRange:(UITextRange *)range
                      atCharacterOffset:(NSInteger)offset {
    if (offset < 0) {
        return nil;
    }
    UITextPosition *position = [self positionFromPosition:range.start offset:offset];
    if (position == nil ||
        [self comparePosition:position toPosition:range.end] == NSOrderedDescending) {
        return nil;
    }
    return position;
}

- (NSInteger)characterOffsetOfPosition:(UITextPosition *)position
                           withinRange:(UITextRange *)range {
    if ([self comparePosition:position toPosition:range.start] == NSOrderedAscending ||
        [self comparePosition:position toPosition:range.end] == NSOrderedDescending) {
        return (NSInteger)NSNotFound;
    }
    return [self offsetFromPosition:range.start toPosition:position];
}

- (void)insertDictationResult:(NSArray<UIDictationPhrase *> *)dictationResult {
    if ([self.id_behaviorInput
            insertDictationResultIfSupported:dictationResult]) {
        return;
    }
    NSMutableString *text = [NSMutableString string];
    for (UIDictationPhrase *phrase in dictationResult) {
        [text appendString:phrase.text ?: @""];
    }
    [self insertText:text];
}

- (BOOL)hasText {
    return self.text.length > 0;
}

- (void)insertText:(NSString *)text {
    UITextRange *selection = self.selectedTextRange;
    NSInteger selectionStart = selection == nil ? -1 :
        [self offsetFromPosition:self.beginningOfDocument
                      toPosition:selection.start];
    // Inserting while a composition is open COMMITS it: the text replaces the marked range, so the
    // run typed starts where the marked range does, not at the caret inside it.
    UITextRange *marked = self.typedTextAttributePolicy == nil ? nil : self.markedTextRange;
    NSInteger policyStart = marked == nil ? selectionStart :
        [self offsetFromPosition:self.beginningOfDocument toPosition:marked.start];
    // ...and it is typed with the attributes typing had when the composition started, not with the
    // controller's marked-text attributes (see `id_attributeCommittedComposition:`).
    NSDictionary<NSAttributedStringKey, id> *compositionAttributes = marked == nil ? nil : self.id_compositionTypingAttributes;
    BOOL compositionReplacedSelection = marked != nil && self.id_compositionReplacesSelection;
    if (marked != nil) {
        self.id_compositionTypingAttributes = nil;
        self.id_compositionReplacesSelection = NO;
    }
    NSInteger selectionEnd = selection == nil ? -1 :
        [self offsetFromPosition:self.beginningOfDocument
                      toPosition:selection.end];
    NSInteger documentEnd =
        [self offsetFromPosition:self.beginningOfDocument
                      toPosition:self.endOfDocument];
    BOOL preserveEndParagraphTyping =
        [text isEqualToString:@"\n"] &&
        selectionStart >= 0 &&
        selectionStart == selectionEnd &&
        selectionEnd == documentEnd;
    NSDictionary<NSAttributedStringKey, id> *typingAttributes =
        preserveEndParagraphTyping
            ? self.id_behaviorInput.typingAttributes
            : nil;
    [self.id_behaviorInput insertText:text];
    if (typingAttributes != nil) {
        self.id_behaviorInput.typingAttributes = typingAttributes;
        // The preserved attributes are the default for the paragraph the Return opened; what the
        // host says that EMPTY block is — its provider's answer, settled inside the change
        // notification — wins over them. Without this a Return at the end of a container's last
        // line typed the paragraph after it in the line's face.
        [self id_adoptEmptyBlockTypingAttributesIfNeeded];
    }
    if (policyStart >= 0 && selectionStart == selectionEnd) {
        UITextRange *after = marked == nil ? nil : self.selectedTextRange;
        NSInteger caret = after == nil || !after.empty ? -1
            : [self offsetFromPosition:self.beginningOfDocument toPosition:after.start];
        if (marked != nil && caret > policyStart && ![text containsString:@"\n"]) {
            [self id_attributeCommittedComposition:NSMakeRange((NSUInteger)policyStart, (NSUInteger)(caret - policyStart))
                                  typingAttributes:compositionAttributes
                                 replacedSelection:compositionReplacedSelection];
        } else {
            [self id_applyTypedTextPolicyForInsertionAt:(NSUInteger)policyStart];
        }
    }
}

/// Applies the host's typed-text policy to the run just typed.
///
/// Runs AFTER the insert rather than filtering it: the private input controller inserts through
/// `replaceCharactersInRange:withAttributedString:` with a string it has already built, so
/// `id_insertionAttributesForReplacedRange:` is never consulted for typed text. Filtering that
/// replace instead would also rewrite a PASTE, which is not typing.
- (void)id_applyTypedTextPolicyForInsertionAt:(NSUInteger)start {
    NSDictionary<NSAttributedStringKey, id> *(^policy)(
        NSDictionary<NSAttributedStringKey, id> *,
        NSDictionary<NSAttributedStringKey, id> *,
        NSDictionary<NSAttributedStringKey, id> *,
        NSString *) = self.typedTextAttributePolicy;
    if (policy == nil) {
        return;
    }
    UITextRange *selection = self.selectedTextRange;
    if (selection == nil || !selection.empty) {
        return;
    }
    NSInteger caret = [self offsetFromPosition:self.beginningOfDocument
                                    toPosition:selection.start];
    if (caret <= (NSInteger)start) {
        return;
    }
    [self id_applyTypedTextPolicyToRange:NSMakeRange(start, (NSUInteger)caret - start)];
}

/// The typed-text policy for the run at `inserted` — typed text, or a composition's committed text.
- (void)id_applyTypedTextPolicyToRange:(NSRange)inserted {
    NSDictionary<NSAttributedStringKey, id> *(^policy)(
        NSDictionary<NSAttributedStringKey, id> *,
        NSDictionary<NSAttributedStringKey, id> *,
        NSDictionary<NSAttributedStringKey, id> *,
        NSString *) = self.typedTextAttributePolicy;
    if (policy == nil || inserted.length == 0) {
        return;
    }
    if (NSMaxRange(inserted) > self.id_textStorageAdapter.length) {
        return;
    }
    NSUInteger start = inserted.location;
    NSDictionary<NSAttributedStringKey, id> *current =
        [self.id_textStorageAdapter attributesAtIndex:inserted.location effectiveRange:NULL];
    NSString *storageString = self.id_textStorageAdapter.string;
    // The character the run was typed AFTER, when it is in the same block. A block separator
    // (U+000A) belongs to the block above, and its attributes are that block's last character's:
    // handed over as `preceding`, the first character typed into an empty block took the marks of
    // the block above — a space typed into a pull quote's empty author line after an inline-code
    // body came out as inline code (composer harness, 2026-09-23, fuzz seed 15). The host's policy
    // tells a block's start by the caret, which this is called too late for: the caret is already
    // past the run.
    NSDictionary<NSAttributedStringKey, id> *preceding =
        start > 0 && [storageString characterAtIndex:start - 1] != '\n'
            ? [self.id_textStorageAdapter attributesAtIndex:start - 1 effectiveRange:NULL]
            : @{};
    NSString *insertedText = [storageString substringWithRange:inserted];
    // The character the run was typed BEFORE, when it is in the same block: a line break (a block
    // separator or an in-block one) ends the run the caret sits in, so what follows it says nothing
    // about whether the caret is INSIDE that run.
    NSDictionary<NSAttributedStringKey, id> *following = @{};
    NSUInteger followingLocation = NSMaxRange(inserted);
    if (followingLocation < storageString.length) {
        unichar next = [storageString characterAtIndex:followingLocation];
        if (![[NSCharacterSet newlineCharacterSet] characterIsMember:next]) {
            following = [self.id_textStorageAdapter attributesAtIndex:followingLocation effectiveRange:NULL];
        }
    }

    NSDictionary<NSAttributedStringKey, id> *resolved =
        policy(current, preceding, following, insertedText);
    if (resolved == nil || [resolved isEqualToDictionary:current]) {
        return;
    }
    [self.id_textStorageAdapter
        id_transformTextAttributesInCanonicalRange:inserted
                                        usingBlock:
        ^NSDictionary<NSAttributedStringKey, id> *(
            NSDictionary<NSAttributedStringKey, id> *attributes) {
        return resolved;
    }];

    // THE DECISION MUST STICK, not just apply to the run that provoked it.
    //
    // Rewriting the inserted run alone fixes one keystroke and nothing after it: the typing
    // attributes still carry what the policy just rejected, so the NEXT character arrives with it
    // again — from the typing state, not from the preceding run. On device that read as a link
    // swallowing everything typed after it even though every individual keystroke was being
    // corrected, which is exactly what the trace showed (`precedingHasLink=0` and
    // `currentHasLink=1` on the same insert). Only with the caret at the run's end: a committed
    // composition whose caret the IME left inside it says nothing about what is typed next.
    UITextRange *selection = self.selectedTextRange;
    if (selection != nil && selection.empty
        && [self offsetFromPosition:self.beginningOfDocument toPosition:selection.start] == (NSInteger)NSMaxRange(inserted)) {
        self.id_behaviorInput.typingAttributes = resolved;
    }
}

- (void)deleteBackward {
    [self.id_behaviorInput deleteBackward];
}

- (NSUndoManager *)undoManager {
    return self.id_behaviorInput.undoManager;
}

- (UITextStorageDirection)selectionAffinity {
    return self.id_behaviorInput.selectionAffinity;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    UITextRange *selection = self.selectedTextRange;
    BOOL hasSelection = selection != nil && !selection.empty;
    BOOL hasText = self.text.length > 0;
    BOOL isEditing = self.isFirstResponder && self.isEditable;
    if (action == @selector(copy:)) {
        return hasSelection && !self.isSecureTextEntry;
    }
    if (action == @selector(cut:)) {
        return self.isEditable && self.isSelectable && hasSelection &&
            !self.isSecureTextEntry;
    }
    if (action == @selector(paste:)) {
        return isEditing && UIPasteboard.generalPasteboard.hasStrings;
    }
    if (action == @selector(select:)) {
        return isEditing && self.isSelectable && hasText && !hasSelection &&
            !self.isSecureTextEntry;
    }
    if (action == @selector(selectAll:)) {
        return isEditing && self.isSelectable && hasText && !hasSelection;
    }
    if (action == @selector(undo:)) {
        return self.isEditable && self.undoManager.canUndo;
    }
    if (action == @selector(redo:)) {
        return self.isEditable && self.undoManager.canRedo;
    }
    return [super canPerformAction:action withSender:sender];
}

- (void)cut:(id)sender {
    if ([self canPerformAction:_cmd withSender:sender] &&
        IDPrivateTextViewShouldDelete(self, self)) {
        [self.id_behaviorInput performCut:sender];
    }
}

- (void)copy:(id)sender {
    if ([self canPerformAction:_cmd withSender:sender]) {
        [self.id_behaviorInput performCopy:sender];
    }
}

- (void)paste:(id)sender {
    [self.id_behaviorInput performPaste:sender];
}

- (void)select:(id)sender {
    if ([self canPerformAction:_cmd withSender:sender]) {
        [self.id_interactionCapability id_selectWord];
    }
}

- (void)selectAll:(id)sender {
    [self.id_interactionCapability selectAll:sender];
}

- (NSAttributedString *)textPasteConfigurationSupporting:
    (id<UITextPasteConfigurationSupporting>)supporting
    combineItemAttributedStrings:
        (NSArray<NSAttributedString *> *)itemStrings
                       forRange:(UITextRange *)textRange {
    NSMutableAttributedString *combined =
        [[NSMutableAttributedString alloc] init];
    for (NSAttributedString *item in itemStrings) {
        [combined appendAttributedString:item];
    }
    return [self.id_inlineTextStyleResolver
        importAttributedString:combined];
}

@end

#endif
