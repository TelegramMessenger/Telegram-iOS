// TELEGRAM-AUTHORED (not ported). See the header.

#import "IDStockParityRuntime.h"
// BY DIRECTORY, never by bare name. TWO headers are called IDSpellingReadinessProbe.h: this
// package's (Tests/StockParitySupport/include/), which declares IDRunMainRunLoopForInterval and
// IDStockTemporaryRenderingRanges under its TELEGRAM ADDITION pragma, and upstream's own
// (Host/Engine/Tests/), which declares NEITHER. A bare quoted import resolved to upstream's, so the
// two calls below became implicit declarations — an ERROR in current clang, which took the whole
// InputDecHostTests bundle out of the build. A quoted import resolves relative to the including
// file's own directory first, so the "include/" prefix can only mean this one; the same reason the
// package's public headers import the kernel as "Kernel/...".
//
// Latent since Host/Engine/Tests was imported (2026-09-15) because this file's object stayed cached,
// and invisible when it fired: a bundle that fails to BUILD still lets the run print the OTHER
// scheme's "Executed N tests, 0 failures", which reads as green.
#import "include/IDSpellingReadinessProbe.h"

NSString *IDCurrentInputModePrimaryLanguage(void) {
    return UITextInputMode.currentInputMode.primaryLanguage;
}

BOOL IDHasCurrentInputMode(void) {
    return UITextInputMode.currentInputMode != nil;
}

NSDictionary<NSString *, NSNumber *> *IDPrivateTextInputClassAvailability(void) {
    NSArray<NSString *> *names = @[
        @"UITextInputController",
        @"UITextCheckingController",
        @"UIKeyboardImpl",
        @"_UITextMagnifiedGlassLoupeView",
    ];
    NSMutableDictionary<NSString *, NSNumber *> *result = [NSMutableDictionary dictionary];
    for (NSString *name in names) {
        result[name] = @(NSClassFromString(name) != Nil);
    }
    return result.copy;
}


@interface UITextView (IDStockParityContinuousChecking)
- (void)setContinuousSpellCheckingEnabled:(BOOL)enabled;
- (BOOL)isContinuousSpellCheckingEnabled;
@end

void IDSetContinuousSpellCheckingEnabled(id view, BOOL enabled) {
    if ([view respondsToSelector:@selector(setContinuousSpellCheckingEnabled:)]) {
        [(UITextView *)view setContinuousSpellCheckingEnabled:enabled];
    }
}

BOOL IDIsContinuousSpellCheckingEnabled(id view) {
    if ([view respondsToSelector:@selector(isContinuousSpellCheckingEnabled)]) {
        return [(UITextView *)view isContinuousSpellCheckingEnabled];
    }
    return NO;
}

NSArray<NSDictionary<NSString *, NSNumber *> *> *
IDObserveStockAnnotationRangesForText(UITextView *editor,
                                      NSString *text,
                                      NSTimeInterval timeout) {
    if (editor.window == nil || editor.window.hidden || editor.hidden) {
        [NSException raise:NSInvalidArgumentException
                    format:@"The annotation sampler requires a visible hosted editor"];
    }
    editor.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    editor.backgroundColor = UIColor.whiteColor;
    editor.font = [UIFont systemFontOfSize:17.0];
    editor.textColor = UIColor.blackColor;
    editor.autocorrectionType = UITextAutocorrectionTypeNo;
    editor.spellCheckingType = UITextSpellCheckingTypeYes;
    editor.smartQuotesType = UITextSmartQuotesTypeNo;
    editor.smartDashesType = UITextSmartDashesTypeNo;
    editor.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
    editor.inlinePredictionType = UITextInlinePredictionTypeNo;
    editor.text = @"";
    [editor layoutIfNeeded];
    [editor becomeFirstResponder];
    IDSetContinuousSpellCheckingEnabled(editor, YES);
    [editor insertText:text];
    return IDStockPumpAndSampleAnnotationRanges(editor, timeout);
}

NSArray<NSDictionary<NSString *, NSNumber *> *> *
IDStockPumpAndSampleAnnotationRanges(UITextView *editor, NSTimeInterval timeout) {
    IDRunMainRunLoopForInterval(MAX(timeout, 0));
    [editor setNeedsLayout];
    [editor layoutIfNeeded];
    [editor.textLayoutManager ensureLayoutForBounds:editor.bounds];
    return IDStockTemporaryRenderingRanges(editor);
}
