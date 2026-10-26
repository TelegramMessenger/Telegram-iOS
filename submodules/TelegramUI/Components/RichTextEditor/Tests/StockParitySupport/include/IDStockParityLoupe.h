// PORTED from /Users/isaac/Documents/InputDec/Tests/IDBlockTouchSelectionParityTests.m:1-88
// @ fdad9ca519f5f27a07362e00dc6cefdcb73ca369 — the file-static helpers at the top of that suite,
// lifted into a shared target because Task P1 had to DROP the loupe test outright for want of them.
//
// **Why these cannot live in Swift.** `IDSendTestLoupeGesture` casts `objc_msgSend` to a
// 6-argument function pointer whose 2nd/3rd/4th arguments are `CGPoint`-returning blocks and whose
// 6th is an out-`BOOL *`. Swift cannot form that call: `objc_msgSend` is not callable through a
// `@convention(c)` cast there. This is the entire reason this Objective-C target exists alongside
// the Swift suites.

@import UIKit;

NS_ASSUME_NONNULL_BEGIN

/// Drives the private
/// `-loupeGestureWithState:location:translation:velocity:modifierFlags:shouldCancel:` on a
/// `UITextInteractionAssistant`-shaped object. Returns NO when the assistant cancelled the sequence
/// (upstream `NSCAssert`s on that; the port returns it so a Swift test can fail with a message).
FOUNDATION_EXPORT BOOL IDSendTestLoupeGesture(id assistant,
                                              UIGestureRecognizerState state,
                                              CGPoint location,
                                              CGPoint translation,
                                              CGPoint velocity);

/// The object a `UITextInput`-conforming view publishes as its `interactionAssistant`, or nil.
/// Upstream reaches it through `objc_msgSend`; Swift can send this one, but routing it here keeps
/// the private-selector surface in one file.
FOUNDATION_EXPORT id _Nullable IDInteractionAssistantOfInput(id input);

/// The assistant's private `_caretView`, or nil.
FOUNDATION_EXPORT UIView *_Nullable IDCaretViewOfAssistant(id assistant);

/// Composites every visible window of `scene` into one image (upstream `IDCaptureWindowScene`).
FOUNDATION_EXPORT UIImage *IDCaptureWindowScene(UIWindowScene *scene);

/// Spins the run loop 0.4s to let the loupe present (upstream `IDWaitForLoupePresentation`).
FOUNDATION_EXPORT void IDWaitForLoupePresentation(void);

/// Waits up to 2s for a visible `_UITextMagnifiedGlassLoupeView` anywhere in `scene`
/// (`visible == NO` waits for its disappearance). Upstream `IDWaitForLoupeInScene`.
FOUNDATION_EXPORT UIView *_Nullable IDWaitForLoupeInScene(UIWindowScene *scene, BOOL visible);

/// `[view convertRect:view.bounds toView:nil]` — upstream `IDScreenRectForView`.
FOUNDATION_EXPORT CGRect IDScreenRectForView(UIView *view);

NS_ASSUME_NONNULL_END
