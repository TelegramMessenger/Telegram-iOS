@import XCTest;

#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"

/// **The caret must be on the text at the end of the layout pass, not one run-loop iteration later.**
///
/// Marking UIKit's selection display dirty does not move the cursor: `-[UITextSelectionDisplayInteraction
/// setNeedsSelectionUpdate]` sets a pending flag and schedules the real work through
/// `-performSelector:withObject:afterDelay:inModes:` with a delay of 0. A zero-delay timer cannot run
/// in the iteration that scheduled it, so without `-id_flushSelectionDisplayUpdate` the cursor is drawn
/// from the PREVIOUS state in the CoreAnimation commit that draws the new glyphs — reported as "when
/// typing the cursor sometimes lags behind the typed text", and visible exactly in proportion to how
/// long the main thread is busy between iterations.
///
/// A stock `UITextView` is the oracle here, and it is an oracle rather than a control: it takes the
/// same deferred arm of `-[UITextInteractionAssistant selectionChanged]` and is rescued by a
/// notification its own canvas posts from `-layoutSubviews`, which a text input that draws its own
/// canvas never posts. So both sides of this file must hold, and they must hold for the same reason:
/// the cursor is correct once the view has laid out, with no run loop in between.
///
/// **The run loop must not be spun between the edit and the assertion.** One turn and the timer fires,
/// the cursor is correct whatever this class does, and the test passes while the defect stands.
@interface IDSelectionDisplayFlushParityTests : XCTestCase
@end

@implementation IDSelectionDisplayFlushParityTests

#pragma mark - Hosting

- (UIWindow *)hostView:(UIView *)view {
    UIWindowScene *windowScene = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class]) {
            windowScene = (UIWindowScene *)scene;
            break;
        }
    }
    XCTAssertNotNil(windowScene);
    UIWindow *priorKeyWindow = windowScene.keyWindow;
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:windowScene];
    window.frame = CGRectMake(0, 0, CGRectGetWidth(view.frame), CGRectGetHeight(view.frame));
    UIViewController *controller = [UIViewController new];
    window.rootViewController = controller;
    [controller.view addSubview:view];
    [window makeKeyAndVisible];
    [controller.view layoutIfNeeded];
    [view layoutIfNeeded];
    XCTAssertTrue([view becomeFirstResponder]);
    // Settling the interaction's installation is the ONE place a run loop belongs in this file, and
    // it is before the edit: UIKit creates the selection-display interaction and its cursor view on
    // its own schedule after the view takes the responder role.
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    // ...and on that schedule the cursor's FIRST placement can take longer than 0.05 s: measured
    // (composer harness p22, 2026-10-01), the "before typing" precondition failed 5 of 8 focused runs
    // of this class and 1 of 3 full-suite runs, for the STOCK oracle as often as for the engine, always
    // in the first case of a fresh process — the cursor view still at x = 0. That is the installation
    // settling, not the defect this file pins (which is about the edit, below), so the setup waits for
    // the initial placement, bounded, before any edit is made. Still no run loop after the edit.
    if ([view conformsToProtocol:@protocol(UITextInput)]) {
        UIView<UITextInput> *input = (UIView<UITextInput> *)view;
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2.0];
        while (deadline.timeIntervalSinceNow > 0) {
            UITextRange *selection = input.selectedTextRange;
            CGRect drawn = [self drawnCursorRectInTextInput:view];
            if (selection != nil && !CGRectIsNull(drawn)
                && fabs(CGRectGetMinX(drawn) - CGRectGetMinX([input caretRectForPosition:selection.end])) <= 1.0) {
                break;
            }
            [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        }
    }
    [self addTeardownBlock:^{
        [view resignFirstResponder];
        [view removeFromSuperview];
        window.hidden = YES;
        window.rootViewController = nil;
        [priorKeyWindow makeKeyWindow];
    }];
    return window;
}

/// UIKit's cursor, through the interaction's PUBLIC `cursorView` rather than by class name: the
/// concrete class has been spelled several ways across releases, and a name match that stops
/// matching would report "no lag" by finding nothing.
- (UIView *)cursorViewForTextInput:(UIView *)view {
    for (id<UIInteraction> interaction in view.interactions) {
        if ([interaction isKindOfClass:UITextSelectionDisplayInteraction.class]) {
            return ((UITextSelectionDisplayInteraction *)interaction).cursorView;
        }
    }
    return nil;
}

/// Where the cursor is DRAWN, in the text input's own coordinates — the space `caretRectForPosition:`
/// answers in. The cursor's frame is in its host's space, which is not the same view in both arms.
- (CGRect)drawnCursorRectInTextInput:(UIView *)view {
    UIView *cursor = [self cursorViewForTextInput:view];
    if (cursor == nil) { return CGRectNull; }
    return [cursor.superview convertRect:cursor.frame toView:view];
}

- (void)assertCursorSitsOnTheCaretIn:(UIView<UITextInput> *)view label:(NSString *)label {
    UITextRange *selection = view.selectedTextRange;
    XCTAssertNotNil(selection, @"%@: no selection", label);
    CGRect caret = [view caretRectForPosition:selection.end];
    CGRect drawn = [self drawnCursorRectInTextInput:view];
    XCTAssertFalse(CGRectIsNull(drawn), @"%@: no cursor view to measure", label);
    XCTAssertEqualWithAccuracy(CGRectGetMinX(drawn), CGRectGetMinX(caret), 1.0,
                               @"%@: the cursor is drawn at %.1f while the caret is at %.1f — the "
                               @"selection display was left to its run-loop timer",
                               label, CGRectGetMinX(drawn), CGRectGetMinX(caret));
}

/// Caret to the end, then one character, then the layout pass the commit would run — and nothing else.
- (void)typeOneCharacterAndLayOut:(UIView<UITextInput> *)view {
    view.selectedTextRange = [view textRangeFromPosition:view.endOfDocument
                                              toPosition:view.endOfDocument];
    [(id)view insertText:@"W"];
    [view setNeedsLayout];
    [view layoutIfNeeded];
}

#pragma mark - The engine

- (void)test_theCursorIsOnTheCaretAfterTypingWithoutARunLoopTurn {
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:17.0]};
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 200)
     attributedBlocks:@[[[NSAttributedString alloc] initWithString:@"The quick brown fox"
                                                        attributes:attributes]]];
    view.editable = YES;
    [self hostView:view];

    [self assertCursorSitsOnTheCaretIn:view label:@"engine, before typing"];
    [self typeOneCharacterAndLayOut:view];
    [self assertCursorSitsOnTheCaretIn:view label:@"engine, after typing"];
}

/// A SECOND character, because the first one after a fresh focus can be carried by the setup's own
/// settling. A run of keystrokes with no run loop between them is the reported shape.
- (void)test_theCursorTracksARunOfKeystrokes {
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:17.0]};
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 200)
     attributedBlocks:@[[[NSAttributedString alloc] initWithString:@"The quick brown fox"
                                                        attributes:attributes]]];
    view.editable = YES;
    [self hostView:view];

    for (NSUInteger index = 0; index < 4; index += 1) {
        [self typeOneCharacterAndLayOut:view];
        [self assertCursorSitsOnTheCaretIn:view
                                     label:[NSString stringWithFormat:@"engine, keystroke %lu",
                                                                      (unsigned long)index + 1]];
    }
}

#pragma mark - The oracle

- (void)test_aStockTextViewKeepsItsCursorOnTheCaretTheSameWay {
    UITextView *view = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 320, 200)];
    view.font = [UIFont systemFontOfSize:17.0];
    view.text = @"The quick brown fox";
    [self hostView:view];

    [self assertCursorSitsOnTheCaretIn:view label:@"stock, before typing"];
    [self typeOneCharacterAndLayOut:view];
    [self assertCursorSitsOnTheCaretIn:view label:@"stock, after typing"];
}

@end
