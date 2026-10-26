#import "IDTextView.h"

#import "IDPrivateUIKit.h"
#import "IDTextViewInternal.h"

@protocol IDUndoRedoResponderActions <NSObject>
- (void)undo:(id)sender;
- (void)redo:(id)sender;
@end

@implementation IDTextView (TextInputConformance)

- (NSString *)textInRange:(UITextRange *)range {
    return IDPrivateObject1(self.id_inputController, _cmd, range);
}

- (void)replaceRange:(UITextRange *)range withText:(NSString *)text {
    IDPrivateVoid2(self.id_inputController, _cmd, range, text);
}

- (UITextRange *)selectedTextRange {
    return IDPrivateObject0(self.id_inputController, _cmd);
}

- (void)setSelectedTextRange:(UITextRange *)range {
    IDPrivateVoid1(self.id_inputController, _cmd, range);
}

- (UITextRange *)markedTextRange {
    return IDPrivateObject0(self.id_inputController, _cmd);
}

- (NSDictionary<NSAttributedStringKey, id> *)markedTextStyle {
    return IDPrivateObject0(self.id_inputController, _cmd);
}

- (void)setMarkedTextStyle:(NSDictionary<NSAttributedStringKey, id> *)style {
    IDPrivateVoid1(self.id_inputController, _cmd, style);
}

- (void)setMarkedText:(NSString *)text selectedRange:(NSRange)range {
    IDPrivateVoidObjectRange(self.id_inputController, _cmd, text, range);
}

- (void)setAttributedMarkedText:(NSAttributedString *)text
                  selectedRange:(NSRange)range {
    IDPrivateVoidObjectRange(self.id_inputController, _cmd, text, range);
}

- (void)unmarkText {
    IDPrivateVoid0(self.id_inputController, _cmd);
}

- (UITextPosition *)beginningOfDocument {
    return IDPrivateObject0(self.id_inputController, _cmd);
}

- (UITextPosition *)endOfDocument {
    return IDPrivateObject0(self.id_inputController, _cmd);
}

- (UITextRange *)textRangeFromPosition:(UITextPosition *)fromPosition
                            toPosition:(UITextPosition *)toPosition {
    return IDPrivateObject2(self.id_inputController, _cmd, fromPosition, toPosition);
}

- (UITextPosition *)positionFromPosition:(UITextPosition *)position offset:(NSInteger)offset {
    return IDPrivateObjectObjectInteger(self.id_inputController, _cmd, position, offset);
}

- (UITextPosition *)positionFromPosition:(UITextPosition *)position
                             inDirection:(UITextLayoutDirection)direction
                                  offset:(NSInteger)offset {
    return IDPrivateObjectObjectIntegerInteger(
        self.id_inputController,
        _cmd,
        position,
        direction,
        offset);
}

- (NSComparisonResult)comparePosition:(UITextPosition *)position
                           toPosition:(UITextPosition *)other {
    return IDPrivateInteger2(self.id_inputController, _cmd, position, other);
}

- (NSInteger)offsetFromPosition:(UITextPosition *)from
                     toPosition:(UITextPosition *)toPosition {
    return IDPrivateInteger2(self.id_inputController, _cmd, from, toPosition);
}

- (id<UITextInputDelegate>)inputDelegate {
    return IDPrivateObject0(self.id_inputController, _cmd);
}

- (void)setInputDelegate:(id<UITextInputDelegate>)delegate {
    IDPrivateVoid1(self.id_inputController, _cmd, delegate);
}

- (id<UITextInputTokenizer>)tokenizer {
    return IDPrivateObject0(self.id_inputController, _cmd);
}

- (UITextPosition *)positionWithinRange:(UITextRange *)range
                    farthestInDirection:(UITextLayoutDirection)direction {
    return IDPrivateObjectObjectInteger(self.id_inputController, _cmd, range, direction);
}

- (UITextRange *)characterRangeByExtendingPosition:(UITextPosition *)position
                                       inDirection:(UITextLayoutDirection)direction {
    return IDPrivateObjectObjectInteger(self.id_inputController, _cmd, position, direction);
}

- (NSWritingDirection)baseWritingDirectionForPosition:(UITextPosition *)position
                                           inDirection:(UITextStorageDirection)direction {
    return IDPrivateIntegerObjectInteger(self.id_inputController, _cmd, position, direction);
}

- (void)setBaseWritingDirection:(NSWritingDirection)writingDirection
                       forRange:(UITextRange *)range {
    IDPrivateVoidIntegerObject(self.id_inputController, _cmd, writingDirection, range);
}

- (CGRect)firstRectForRange:(UITextRange *)range {
    return IDPrivateRectObject(self.id_inputController, _cmd, range);
}

- (CGRect)caretRectForPosition:(UITextPosition *)position {
    return IDPrivateRectObject(self.id_inputController, _cmd, position);
}

- (NSArray<UITextSelectionRect *> *)selectionRectsForRange:(UITextRange *)range {
    return IDPrivateObject1(self.id_inputController, _cmd, range);
}

- (UITextPosition *)closestPositionToPoint:(CGPoint)point {
    return IDPrivateObjectPoint(self.id_inputController, _cmd, point);
}

- (UITextPosition *)closestPositionToPoint:(CGPoint)point withinRange:(UITextRange *)range {
    return IDPrivateObjectPointObject(self.id_inputController, _cmd, point, range);
}

- (UITextRange *)characterRangeAtPoint:(CGPoint)point {
    return IDPrivateObjectPoint(self.id_inputController, _cmd, point);
}

- (NSDictionary<NSAttributedStringKey, id> *)textStylingAtPosition:(UITextPosition *)position
                                                        inDirection:(UITextStorageDirection)direction {
    return IDPrivateObjectObjectInteger(self.id_inputController, _cmd, position, direction);
}

- (UITextPosition *)positionWithinRange:(UITextRange *)range
                      atCharacterOffset:(NSInteger)offset {
    if (offset < 0) {
        return nil;
    }
    UITextPosition *position = [self positionFromPosition:range.start offset:offset];
    if (position == nil || [self comparePosition:position toPosition:range.end] == NSOrderedDescending) {
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
    if (IDPrivateRespondsToSelector(self.id_inputController, _cmd)) {
        IDPrivateVoid1(self.id_inputController, _cmd, dictationResult);
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
    IDPrivateVoid1(self.id_inputController, _cmd, text);
}

- (void)deleteBackward {
    IDPrivateVoid0(self.id_inputController, _cmd);
}

- (NSUndoManager *)undoManager {
    return IDPrivateInputUndoManager(self.id_inputController);
}

- (UITextStorageDirection)selectionAffinity {
    return IDPrivateInputSelectionAffinity(self.id_inputController);
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    UITextRange *selection = self.selectedTextRange;
    BOOL hasSelection = selection != nil && !selection.empty;
    BOOL hasText = self.text.length > 0;

    if (action == @selector(copy:)) {
        return self.isSelectable && hasSelection && !self.isSecureTextEntry;
    }
    if (action == @selector(cut:)) {
        return self.isEditable && self.isSelectable && hasSelection &&
               !self.isSecureTextEntry;
    }
    if (action == @selector(paste:)) {
        return self.isEditable &&
               IDPrivateInputShouldHandlePaste(self.id_inputController, sender);
    }
    if (action == @selector(select:)) {
        return self.isSelectable && hasText && !hasSelection;
    }
    if (action == @selector(selectAll:)) {
        NSRange selectedRange = [self id_NSRangeForTextRange:selection];
        BOOL allSelected = selectedRange.location == 0 && selectedRange.length == self.text.length;
        return self.isSelectable && hasText && !allSelected;
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
        IDPrivateInputCut(self.id_inputController, sender);
    }
}

- (void)copy:(id)sender {
    if ([self canPerformAction:_cmd withSender:sender]) {
        IDPrivateInputCopy(self.id_inputController, sender);
    }
}

- (void)paste:(id)sender {
    IDPrivateInputPaste(self.id_inputController, sender);
}

- (void)select:(id)sender {
    if ([self canPerformAction:_cmd withSender:sender]) {
        IDPrivateInteractionSelectWord(self.id_interactionAssistant);
    }
}

- (void)selectAll:(id)sender {
    if ([self canPerformAction:_cmd withSender:sender]) {
        IDPrivateInteractionSelectAll(self.id_interactionAssistant, sender);
    }
}

@end
