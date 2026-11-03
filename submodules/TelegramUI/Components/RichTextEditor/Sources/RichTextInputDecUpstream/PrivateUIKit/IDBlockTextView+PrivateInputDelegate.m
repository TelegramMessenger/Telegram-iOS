#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "TGPrivateRuntimeNames.h"

#import "TGPrivateMethodAliases.h"

#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"
#import "IDPrivateUIKit.h"
#import "IDPrivateUIKit+TextLayoutCanvas.h"
#import "IDUIKitInputControllerCapability.h"

static BOOL IDBlockAllowsKeyboardReplacement(IDBlockTextView *view) {
    return view.isEditable;
}

@implementation IDBlockTextView (PrivateInputDelegate)

- (void)tgpn_setContinuousSpellCheckingEnabled:(BOOL)enabled {
    [self.id_behaviorInput id_setContinuousSpellCheckingEnabled:enabled];
}

- (BOOL)tgpn_isContinuousSpellCheckingEnabled {
    return self.id_behaviorInput.id_isContinuousSpellCheckingEnabled;
}

- (BOOL)textInput:(id)input
    shouldChangeCharactersInRanges:(NSArray<NSValue *> *)ranges
                   replacementText:(NSString *)text {
    return self.isEditable;
}

- (BOOL)tgpn_keyboardInput:(id)input
    shouldReplaceTextInRange:(NSRange)range
             replacementText:(NSString *)text {
    (void)input;
    (void)range;
    (void)text;
    return IDBlockAllowsKeyboardReplacement(self);
}

- (void)tgpn_textInputDidChange:(id)input {
    IDRecordAutocorrectionTraceForUITesting(@"textDidChange");
    [self id_reconcileDerivedState];
    [self id_scrollCaretToVisibleIfNeeded];
}

- (void)tgpn_textInputDidChangeSelection:(id)input {
    IDRecordAutocorrectionTraceForUITesting(@"selectionDidChange");
    [self id_selectionStateDidChange];
}

- (void)tgpn_keyboardInputChangedSelection:(id)input {
    id delegate = self.delegate;
    if (delegate != self) {
        IDPrivateKeyboardInputChangedSelection(delegate, input);
    }
}

- (BOOL)tgpn_keyboardInput:(id)input
      shouldInsertText:(NSString *)text
          isMarkedText:(BOOL)marked {
    return self.isEditable;
}

- (BOOL)tgpn_keyboardInputShouldDelete:(id)input {
    (void)self.id_behaviorInput.backwardDeleteRange;
    return self.isEditable;
}

- (void)tgpn__deleteBackwardAndNotify:(BOOL)notify {
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

// This file's callbacks, added under their private names (`IDBlockTextViewInstallPrivateCallbacks`).
void IDBlockTextViewInstallPrivateInputDelegateCallbacks(Class cls) {
    const TGPrivateMethodAlias aliases[] = {
        { TGPN_setContinuousSpellCheckingEnabled_, @selector(tgpn_setContinuousSpellCheckingEnabled:) },
        { TGPN_isContinuousSpellCheckingEnabled, @selector(tgpn_isContinuousSpellCheckingEnabled) },
        { TGPN_keyboardInput_shouldReplaceTextInRange_replacementText_, @selector(tgpn_keyboardInput:shouldReplaceTextInRange:replacementText:) },
        { TGPN_textInputDidChange_, @selector(tgpn_textInputDidChange:) },
        { TGPN_textInputDidChangeSelection_, @selector(tgpn_textInputDidChangeSelection:) },
        { TGPN_keyboardInputChangedSelection_, @selector(tgpn_keyboardInputChangedSelection:) },
        { TGPN_keyboardInput_shouldInsertText_isMarkedText_, @selector(tgpn_keyboardInput:shouldInsertText:isMarkedText:) },
        { TGPN_keyboardInputShouldDelete_, @selector(tgpn_keyboardInputShouldDelete:) },
        { TGPN__deleteBackwardAndNotify_, @selector(tgpn__deleteBackwardAndNotify:) },
    };
    TGPrivateInstallMethodAliases(cls, aliases, sizeof(aliases) / sizeof(aliases[0]));
}

#endif
