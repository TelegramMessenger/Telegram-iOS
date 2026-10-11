#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"
#import "IDPrivateUIKit.h"
#import "IDPrivateUIKit+TextLayoutCanvas.h"
#import "IDUIKitInputControllerCapability.h"

static BOOL IDBlockAllowsKeyboardReplacement(IDBlockTextView *view) {
    return view.isEditable;
}

@implementation IDBlockTextView (PrivateInputDelegate)

- (void)setContinuousSpellCheckingEnabled:(BOOL)enabled {
    [self.id_behaviorInput setContinuousSpellCheckingEnabled:enabled];
}

- (BOOL)isContinuousSpellCheckingEnabled {
    return self.id_behaviorInput.isContinuousSpellCheckingEnabled;
}

- (BOOL)textInput:(id)input
    shouldChangeCharactersInRanges:(NSArray<NSValue *> *)ranges
                   replacementText:(NSString *)text {
    return self.isEditable;
}

- (BOOL)keyboardInput:(id)input
    shouldReplaceTextInRange:(NSRange)range
             replacementText:(NSString *)text {
    (void)input;
    (void)range;
    (void)text;
    return IDBlockAllowsKeyboardReplacement(self);
}

- (void)textInputDidChange:(id)input {
    IDRecordAutocorrectionTraceForUITesting(@"textDidChange");
    [self id_reconcileDerivedState];
    [self id_scrollCaretToVisibleIfNeeded];
}

- (void)textInputDidChangeSelection:(id)input {
    IDRecordAutocorrectionTraceForUITesting(@"selectionDidChange");
    [self id_selectionStateDidChange];
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
    return self.isEditable;
}

- (BOOL)keyboardInputShouldDelete:(id)input {
    (void)self.id_behaviorInput.backwardDeleteRange;
    return self.isEditable;
}

- (void)_deleteBackwardAndNotify:(BOOL)notify {
    if (notify) {
        [self deleteBackward];
        return;
    }
    IDUIKitInputControllerCapability *input = self.id_behaviorInput;
    [input performWhileSuppressingDelegateNotifications:^{
        [input deleteBackward];
    }];
}

@end

#endif
