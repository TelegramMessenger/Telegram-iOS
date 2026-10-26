#import "IDTextView.h"
#import "IDTextViewInternal.h"
#import "IDPrivateUIKit.h"
#import "IDPrivateUIKit+TextLayoutCanvas.h"

@implementation IDTextView (PrivateInputDelegate)

- (void)setContinuousSpellCheckingEnabled:(BOOL)enabled {
    IDPrivateSetContinuousSpellCheckingEnabled(self.id_inputController, enabled);
}

- (BOOL)isContinuousSpellCheckingEnabled {
    return IDPrivateContinuousSpellCheckingEnabled(self.id_inputController);
}

- (BOOL)textInput:(id)input
    shouldChangeCharactersInRanges:(NSArray<NSValue *> *)ranges
                   replacementText:(NSString *)text {
    if (![self.delegate respondsToSelector:
            @selector(textView:shouldChangeTextInRange:replacementText:)]) {
        return YES;
    }

    for (NSValue *value in ranges) {
        if (![self.delegate textView:self
              shouldChangeTextInRange:value.rangeValue
                      replacementText:text]) {
            return NO;
        }
    }
    return YES;
}

- (void)textInputDidChange:(id)input {
    [self id_didMutateText];
    // Some controller operations settle their final caret after the delegate callback
    // returns. The helper is containment-gated, so this is an idempotent final pass.
    [self id_scrollCaretToVisibleIfNeeded];
}

- (void)textInputDidChangeSelection:(id)input {
    [self id_notifySelectionChanged];
}

- (void)keyboardInputChangedSelection:(id)input {
    id delegate = self.delegate;
    if (delegate != self) {
        IDPrivateKeyboardInputChangedSelection(delegate, input);
    }
}

- (BOOL)keyboardInput:(id)input
      shouldInsertText:(NSString *)text
          isMarkedText:(BOOL)marked {
    NSRange range = [self id_NSRangeForTextRange:self.selectedTextRange];
    return [self textInput:input
        shouldChangeCharactersInRanges:@[[NSValue valueWithRange:range]]
                       replacementText:text];
}

- (BOOL)keyboardInputShouldDelete:(id)input {
    if (![self.delegate respondsToSelector:
            @selector(textView:shouldChangeTextInRange:replacementText:)]) {
        return YES;
    }
    return [self.delegate textView:self
           shouldChangeTextInRange:IDPrivateInputBackwardDeleteRange(self.id_inputController)
                   replacementText:@""];
}

@end
