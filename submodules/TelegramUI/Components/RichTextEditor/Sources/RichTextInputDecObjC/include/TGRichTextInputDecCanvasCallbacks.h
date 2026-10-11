#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <UIKit/UIKit.h>
#import "TGRichTextInputDecClientBridge.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const TGRichTextInputDecCanvasCallbacksErrorDomain;

/// Installs the private canvas callbacks onto `canvasClass` as free IMPs.
///
/// `canvasClass` MUST be a DIRECT subclass of `forbiddenBaseClass` and MUST NOT be
/// `forbiddenBaseClass` itself; both are checked and the call fails with an error otherwise.
/// `class_addMethod` touches only the class it is given, so the base class can never acquire
/// these selectors. Idempotent per class.
///
/// A category is deliberately NOT used: a category is unconditional and class-global, and there
/// is no way to give a class private methods "only for one backend".
FOUNDATION_EXPORT BOOL TGRichTextInputDecInstallCanvasCallbacks(
    Class canvasClass, Class forbiddenBaseClass, NSError **error);

/// The rows `TGRichTextInputDecInstallCanvasCallbacks` REFUSED to install on its last call, one
/// human-readable line each; empty when everything installed (Task F3).
///
/// A row is refused when the encoding we were about to install contradicts an implementation the
/// superclass chain already carries — i.e. when our declared private ABI disagrees with the
/// runtime's own. The canvas then keeps the inherited system implementation instead of a wrong
/// thunk. This is the runtime half of the guard; `IDCanvasCallbackABITests` is the standing test
/// half, and covers the rows nothing up the chain implements.
///
/// Main thread only (the installer runs from `attach(to:)`), and rebuilt from scratch on every
/// call, so it always describes the current state rather than accumulating history.
FOUNDATION_EXPORT NSArray<NSString *> *TGRichTextInputDecCanvasCallbackABIRejections(void);

/// Whether the installer WOULD accept `types` as the encoding for `selector` on `canvasClass` —
/// the admission test `TGRichTextInputDecInstallCanvasCallbacks` applies to every row, exposed so a
/// test can prove that test is not vacuous. `YES` when nothing on the superclass chain implements
/// `selector` (there is then nothing to check against).
FOUNDATION_EXPORT BOOL TGRichTextInputDecCanvasCallbackABIWouldAccept(
    Class canvasClass, SEL selector, const char *types);

/// The associated-object channel every installed thunk validates before doing anything.
/// Set at attach, cleared at detach; with no bridge every thunk returns a safe default.
FOUNDATION_EXPORT void TGRichTextInputDecSetAttachedBridge(
    UIView *canvas, id<TGRichTextInputDecClientBridging> _Nullable bridge);

FOUNDATION_EXPORT id<TGRichTextInputDecClientBridging> _Nullable
    TGRichTextInputDecAttachedBridge(id canvas);

/// Task C7 (Family 4) — sets `bridge`'s storage façade's `currentIntent` latch, when the façade
/// `bridge.textStorageFacade` vends actually IS a `TGRichTextInputDecTextStorageFacade` (never any
/// other `NSTextStorage`, e.g. a test double that stubs the façade with a plain instance). Every
/// pre-mutation canvas thunk that needs to touch the latch — the two below plus
/// `TGRichTextInputDecCanvasABIWitness`'s `keyboardInputShouldDelete:` — shares this one function
/// rather than three copies of the same `isKindOfClass:` dance. A no-op when `bridge` is nil or the
/// façade is not our subclass.
FOUNDATION_EXPORT void TGRichTextInputDecLatchIntent(
    id<TGRichTextInputDecClientBridging> _Nullable bridge, TGRichTextInputDecIntent intent);

/// Task F4 — copies every `UITextInputTraits` value from `source` onto `traits`.
///
/// `traits` is the PRIVATE input controller's own traits object (`IDUIKitInputControllerCapability
/// .textInputTraits`, i.e. `-[UITextInputController _textInputTraits]`, manifest row
/// `typingAttributes.controllerTraits`). It is a real object that UIKit hands the keyboard, and
/// until something writes it, it carries `+[UITextInputTraits defaultTextInputTraits]` — measured:
/// `autocorrectionType`/`spellCheckingType`/`inlinePredictionType` all `0` (`.default`) while the
/// host canvas answers `.yes`. Nothing in this port ever wrote it, so the host's traits never
/// reached the object the keyboard actually configures itself from.
///
/// This mirrors the upstream host's `IDPrivateSynchronizeTextInputTraits`
/// (`~/Documents/InputDec/PrivateUIKit/IDPrivateUIKit.m`), which `IDBlockTextView` calls at
/// construction and from every trait setter. Two deliberate differences, both in the safe
/// direction: upstream `@throw`s when a setter's ABI does not match, and asserts the traits object
/// is non-nil — this function instead SKIPS any row the live object does not answer and returns
/// harmlessly on a nil `traits`, because a raised `NSException` here would cross back into Swift
/// (see `TGRichTextInputDecExceptionGuard.h`) and because a partially-synchronised traits object is
/// strictly better than a wholly-unsynchronised one.
///
/// Every setter is sent through `objc_msgSend` with the argument type the runtime's own encoding
/// declares (`q` for the NS_ENUM rows, `B` for the BOOL rows, `@` for the object rows), and each is
/// preceded by `respondsToSelector:` — no row here is a guessed ABI: they are all public
/// `UITextInputTraits` property setters, which is why this needs no probe of the kind Task F3 ran.
FOUNDATION_EXPORT void TGRichTextInputDecSynchronizeTextInputTraits(
    id _Nullable traits, id<UITextInputTraits> _Nullable source);

NS_ASSUME_NONNULL_END

#endif
