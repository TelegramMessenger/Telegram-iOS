#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "TGPrivateRuntimeNames.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <string.h>

#import "TGRichTextInputDecCanvasABIWitness.h"
#import "TGRichTextInputDecCanvasCallbacks.h"
#import "TGRichTextInputDecTextStorageFacade.h"

NSErrorDomain const TGRichTextInputDecCanvasCallbacksErrorDomain =
    @"TGRichTextInputDecCanvasCallbacksErrorDomain";

static const void *TGRichTextInputDecAttachedBridgeKey = &TGRichTextInputDecAttachedBridgeKey;

void TGRichTextInputDecSetAttachedBridge(
    UIView *canvas, id<TGRichTextInputDecClientBridging> bridge) {
    objc_setAssociatedObject(canvas, TGRichTextInputDecAttachedBridgeKey, bridge,
                             OBJC_ASSOCIATION_ASSIGN);   // the backend owns the bridge strongly
}

id<TGRichTextInputDecClientBridging> TGRichTextInputDecAttachedBridge(id canvas) {
    return objc_getAssociatedObject(canvas, TGRichTextInputDecAttachedBridgeKey);
}

static NSError *TGError(NSString *reason) {
    return [NSError errorWithDomain:TGRichTextInputDecCanvasCallbacksErrorDomain
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey: reason}];
}

static id TGThunk_textStorage(id self, SEL _cmd) {
    id<TGRichTextInputDecClientBridging> bridge = TGRichTextInputDecAttachedBridge(self);
    if (bridge == nil) { return nil; }
    return [bridge textStorageFacade];
}

static id TGThunk_textInputView(id self, SEL _cmd) {
    return TGRichTextInputDecAttachedBridge(self) == nil ? nil : self;
}

// Task C7 (Family 4) — the shared latch setter every pre-mutation thunk in this file (plus
// `TGRichTextInputDecCanvasABIWitness`'s `keyboardInputShouldDelete:`) funnels through. `bridge`
// is untyped `id<TGRichTextInputDecClientBridging>` on purpose, matching every other function in
// this file — the intent latch is Family-4 state living on the façade `bridge.textStorageFacade`
// vends, never on the bridge itself.
void TGRichTextInputDecLatchIntent(id<TGRichTextInputDecClientBridging> bridge,
                                    TGRichTextInputDecIntent intent) {
    if (bridge == nil) { return; }
    NSTextStorage *storage = [bridge textStorageFacade];
    if ([storage isKindOfClass:TGRichTextInputDecTextStorageFacade.class]) {
        ((TGRichTextInputDecTextStorageFacade *)storage).currentIntent = intent;
    }
}

// ================================ TASK F3 — THE SHAPES ARE PROBED ================================
//
// THE PARAMETER SHAPES IN THIS FILE ARE NO LONGER A RECONSTRUCTION. Task C6/C7/C12/C14 installed
// them as documented guesses, because the vendored manifest does not carry these rows
// (Vendor/VENDOR.md records that `referenceOnly` — 53 rows — was dropped from this snapshot) and
// because the resolver therefore never validates them. Task F3 measured them instead, and one guess
// turned out to be a live crash.
//
// HOW THEY WERE MEASURED (repeat it with `IDCanvasCallbackABITests`, which does the same census in
// process): for each selector, enumerate every class in the running process that implements it
// DIRECTLY (`class_copyMethodList`, ~34,000 classes in a test host) and read
// `method_getTypeEncoding`. Every selector below has exactly ONE distinct encoding across the whole
// runtime, and most are additionally DECLARED in a private protocol — a second, independent witness.
// Measured on iOS 26.5 / 23F73 (the kernel's certified build) and on iOS 27.0; the two agree
// exactly.
//
//   textInputDidChange:                                       v@:@    UITextInputControllerDelegate
//   textInputDidChangeSelection:                              v@:@    UITextInputControllerDelegate
//   keyboardInputChangedSelection:                            v@:@    UIKeyboardInput
//   keyboardInput:shouldInsertText:isMarkedText:              B@:@@B  UIKeyboardInput
//   textInput:shouldChangeCharactersInRanges:replacementText: B@:@@@  UITextInputControllerDelegate
//   _deleteBackwardAndNotify:                                 v@:B    UITextInput_Internal (required)
//   interactionAssistant / _textInputViewForAddingGestureRecognizers / selectionContainerView
//                                                             @@:     UITextInputPrivate,
//                                                                     UITextInputAdditions
//   setContinuousSpellCheckingEnabled:                        v@:B
//   isContinuousSpellCheckingEnabled                          B@:
//   textStorage / textInputView                               @@:     _UITextContent, UITextInput
//
// Five of C6/C7's six guesses were right. The sixth — `_deleteBackwardAndNotify:` — was not, and it
// SEGFAULTED THE APP on the first Backspace after the first keystroke: the real argument is a BOOL,
// C6 declared the IMP `(id self, SEL _cmd, id arg)` and installed it as `"v@:@"`, and ARC's
// `objc_storeStrong` on the incoming `YES` retained address 0x1. The body did `(void)arg;` and never
// read it — THE RETAIN ALONE WAS FATAL, so "we ignore the argument" is not protection. See the note
// at that row below for why it is now not installed at all.
//
// THE RULE THIS FILE NOW ENFORCES: an `id` parameter is the only shape that can turn a wrong guess
// into a segfault, because ARC touches it whether or not the body reads it. Never declare one unless
// the runtime's own encoding for that selector says `@`. `TGAddThunk` (below) refuses, at runtime,
// to install any encoding that contradicts an implementation already present on the superclass
// chain; `IDCanvasCallbackABITests` covers the rest against the full runtime census.
// ================================================================================================

// TASK C6 — the four input-delegate thunks (Family 3). Each reads the attached bridge, returns
// (a safe no-op) if none is attached, and forwards. None of the four is one of the manifest's 47
// resolver-validated `incomingCallbacks` rows (grep confirms: none of these selector names appear
// there) — they are installed the same UNCONDITIONAL way `textStorage`/`textInputView` above are,
// not borrowed from `TGRichTextInputDecCanvasABIWitness`.
//
// TASK F2 CORRECTION — the sentence that used to end this paragraph ("None of the four is reachable
// today regardless (real kernel construction still fails at the `incomingCallbacks` gate ... so
// `TGRichTextInputDecInstallCanvasCallbacks` itself is never even called by any test in this
// stage)") was true when C6 wrote it and EXPIRED AT TASK C14, which landed the final 7
// `incomingCallbacks` rows. Kernel construction now succeeds and this function runs on every attach;
// `CanvasCallbackInstallationTests`, `IDTextEditorBackendInteractionPreflightTests`,
// `IDBackendFamily9Tests` and `IDKeyboardActivationTests` all exercise it. It is removed rather than
// struck through because a stale reachability claim in a source comment is what sent Task F2's first
// hypothesis at an already-covered path.

// Each of the three selectors below has ONE colon (arity 1) and the runtime's own encoding for each
// is `v@:@` — a trailing OBJECT — so the `id` parameter is correct here, verified rather than
// assumed (see the Task F3 table above).
//
// ============================ TASK H1 — WHO ACTUALLY SENDS THESE ============================
//
// The three are NOT one family, and treating them as one is what hid a whole dead mechanism:
//
//   textInputDidChange:            UITextInputControllerDelegate  → sent to the controller's DELEGATE
//   textInputDidChangeSelection:   UITextInputControllerDelegate  → sent to the controller's DELEGATE
//   keyboardInputChangedSelection: UIKeyboardInput                → sent to the VIEW
//
// Installing the first two on the canvas only does something if the canvas IS the delegate. Until
// task H1 it was not — `IDTextEditorBackend.attach(to:)` passed the client BRIDGE as `delegate:` —
// and the bridge answers `respondsToSelector:` NO for both, so the controller never sent them.
// MEASURED, in-process, on an attached backend: `-[UITextInputController setDelegate:]` caches a
// responds-to bitmask at assignment time (17 selectors, these two among them) and re-queries none
// of them afterwards, so a delegate that answers NO is asked once and then silently skipped for the
// life of the controller. With a delegate that answers YES, ONE kernel-driven `deleteBackward()`
// delivers `textInputDidChangeSelection:` twice and `textInputDidChange:` once. The attach site now
// passes the canvas, so these two thunks are live; the third was always live-or-not on its own
// terms (a live software-keyboard session), unaffected either way.
// ===========================================================================================

static void TGThunk_textInputDidChange(id self, SEL _cmd, id arg) {
    (void)arg;
    id<TGRichTextInputDecClientBridging> bridge = TGRichTextInputDecAttachedBridge(self);
    if (bridge == nil) { return; }
    [bridge delegateTextInputDidChange];
}

static void TGThunk_textInputDidChangeSelection(id self, SEL _cmd, id arg) {
    (void)arg;
    id<TGRichTextInputDecClientBridging> bridge = TGRichTextInputDecAttachedBridge(self);
    if (bridge == nil) { return; }
    [bridge delegateTextInputDidChangeSelection];
}

static void TGThunk_keyboardInputChangedSelection(id self, SEL _cmd, id arg) {
    (void)arg;
    id<TGRichTextInputDecClientBridging> bridge = TGRichTextInputDecAttachedBridge(self);
    if (bridge == nil) { return; }
    [bridge delegateKeyboardInputChangedSelection];
}

// `_deleteBackwardAndNotify:` HAS NO THUNK, DELIBERATELY (Task F3). Task C6 installed one on the
// reading that this selector REPORTS a delete the private controller had already performed
// ("AndNotify"), so the canvas could adopt the selection it left behind. BOTH halves of that reading
// are measurably wrong:
//
//   1. ABI — the real encoding is `v@:B` (a BOOL; declared REQUIRED in the private protocol
//      `UITextInput_Internal`), not the `v@:@` C6 installed. That is the segfault: see the Task F3
//      block above.
//
//   2. SEMANTICS — the selector asks the responder to PERFORM the backward delete; the flag governs
//      notification, not the payload. Measured on iOS 26.5: `-[UIResponder _deleteBackwardAndNotify:]`
//      calls `-deleteBackward` on self for BOTH flag values, and `-[UITextView
//      _deleteBackwardAndNotify:]` really removes a character ("abc" -> "ab"). So nothing has deleted
//      anything by the time the callback arrives: C6's thunk seated the PRE-delete selection (a
//      no-op) and, worse, SWALLOWED THE DELETE — with the ABI fixed and the thunk kept, Backspace
//      under `.inputDec` would have done nothing at all.
//
// Declining to install is NOT "leaving the row unimplemented". `UIResponder` implements this
// selector for every responder in the system, so the canvas simply inherits UIKit's own
// implementation — which calls `-deleteBackward`, which `DocumentCanvasView` routes to
// `inputBackend.deleteBackward()` (`IDTextEditorBackend+KeyInput.swift`, covered by
// `IDBackendFamily5Tests`). That is EXACTLY the path the legacy backend takes today: the legacy
// canvas never installed this selector and its Backspace works. `.inputDec` now reaches Backspace
// on the same route, with no guessed private ABI anywhere in it. `IDCanvasCallbackABITests` pins
// both facts (not installed; the inherited implementation still deletes).

// TASK C7 — the two pre-mutation thunks (Family 4) that set the intent latch BEFORE UIKit drives
// the actual storage mutation through `TGRichTextInputDecTextStorageFacade.replaceCharactersInRange:
// withString:`. Same status as C6's four: neither selector appears in the vendored manifest's 47
// `incomingCallbacks` rows (nor anywhere else the snapshot carries — see C6's own note and
// DIVERGENCES.md entries 6-7), so both are a documented, best-effort reconstruction, installed the
// same UNCONDITIONAL way (`class_addMethod`, no ABI-witness borrow, no resolver validation) as
// `textStorage`/`textInputView`/C6's four. (TASK F2: the sentence that stood here claiming neither is
// reachable by any test "for the same reason C6's four are not" expired at Task C14 along with C6's
// own — see the correction in C6's group comment above. TASK F3: the "uncertified parameter shapes"
// caveat that stood here is also gone — both shapes were PROBED and both were right; see the Task F3
// table above.)
//
// `keyboardInput:shouldInsertText:isMarkedText:` mirrors the historically-documented private
// `UIKeyboardInputDelegate`-family preflight UIKit's software keyboard sends before inserting text
// (three colons: the asking keyboard-input object, the candidate text, and whether it is currently
// marked/composing text) — always returns YES (this thunk only latches intent; it is not an
// admission-control gate, which happens later inside the façade's two-phase transaction).
static BOOL TGThunk_keyboardInputShouldInsertTextIsMarkedText(
    id self, SEL _cmd, id keyboardInput, id text, BOOL isMarkedText) {
    (void)keyboardInput;
    (void)text;
    id<TGRichTextInputDecClientBridging> bridge = TGRichTextInputDecAttachedBridge(self);
    TGRichTextInputDecLatchIntent(bridge, isMarkedText ? TGRichTextInputDecIntentMarkedText
                                                        : TGRichTextInputDecIntentInsertText);
    return YES;
}

// `textInput:shouldChangeCharactersInRanges:replacementText:` is the ONE thunk here whose own
// selector carries no keyboard/deletion-specific qualifier at all — unlike its two siblings, its
// name does not say WHICH origin fired it, only that SOME external agent is about to replace text
// in (possibly several) ranges. Of the six `TGRichTextInputDecIntent` cases, only `.programmatic`
// (which the Swift mapper turns into the general `RichTextInputMutation.replaceText` shape) is
// something this selector's own name supports without inventing information it does not carry —
// see this task's report for the full reasoning. Latches EXPLICITLY (not "leave whatever was
// there"), so a genuine system-driven range replace can never inherit a stale, only-coincidentally-
// preceding keyboard thunk's intent.
//
// TASK H1 — THIS ONE IS ALSO A `UITextInputControllerDelegate` MEMBER (task F3 §2's census), so it
// shares the reachability finding recorded in the C6 group comment above: it was installed on the
// canvas while the bridge was the delegate, and was therefore never sent. It is live now. Two
// things measured about it while settling that, both worth having written down:
//   * the controller DOES ask its delegate about this selector at `-setDelegate:` time (it is one
//     of the 17), so it is a genuine delegate row and not decoration; but
//   * it did NOT fire on any of the three kernel-driven paths exercised (`deleteBackward`, a
//     `selectedTextRange` write, `insertText`), so the `.programmatic` latch below does not race
//     the Swift-side `.deleteBackward`/`.insertText` latches on those paths.
// STILL DIVERGENT, deliberately left for a later row: upstream returns `self.isEditable` here
// (`IDBlockTextView+PrivateInputDelegate.m`), not an unconditional YES. H1 changed the RECEIVER of
// this callback and not its answer — making a never-delivered callback both arrive AND start
// refusing edits in the same change is two changes, and the port's real admission control is the
// façade's two-phase transaction regardless.
static BOOL TGThunk_textInputShouldChangeCharactersInRangesReplacementText(
    id self, SEL _cmd, id textInput, id ranges, id replacementText) {
    (void)textInput;
    (void)ranges;
    (void)replacementText;
    id<TGRichTextInputDecClientBridging> bridge = TGRichTextInputDecAttachedBridge(self);
    TGRichTextInputDecLatchIntent(bridge, TGRichTextInputDecIntentProgrammatic);
    return YES;
}

// TASK C12 — the three interaction-host thunks (Family 9). UNLIKE every thunk above, none of
// these three is validated by the `incomingCallbacks` resolver (Family 1-7's rows); they exist
// so `TGRichTextInputDecHostPreflight.requireInteractionHost:stage:` — a SEPARATE ABI-shape check
// the kernel's own `IDUIKitInteractionCapability` init runs while constructing the `.interaction`
// capability — finds a canvas that answers all three selectors with the right shape (zero
// arguments, `id` return: `"@@:"`, matching `textStorage`/`textInputView` above). Installed
// unconditionally, same as every other thunk in this file.

/// Backs `-interactionAssistant`. `respondsToSelector:` before sending, mirroring every other
/// thunk's `@optional`-protocol caution in this file (`bridge` is `IDTextEditorBackendClientBridge`
/// in production, which implements this unconditionally — but `StubBridge`
/// (`CanvasCallbackInstallationTests`) does not, and the protocol method is `@optional`).
static id TGThunk_interactionAssistant(id self, SEL _cmd) {
    id<TGRichTextInputDecClientBridging> bridge = TGRichTextInputDecAttachedBridge(self);
    if (bridge == nil || ![bridge respondsToSelector:@selector(canvasInteractionAssistant)]) { return nil; }
    return [bridge canvasInteractionAssistant];
}

/// Backs `-_textInputViewForAddingGestureRecognizers`. The canvas ITSELF is the view UIKit's
/// private interaction assistant adds its gesture recognizers to — mirrors `TGThunk_textInputView`
/// above exactly (same "inert without an attached bridge" shape) and needs no bridge crossing.
static id TGThunk_textInputViewForAddingGestureRecognizers(id self, SEL _cmd) {
    return TGRichTextInputDecAttachedBridge(self) == nil ? nil : self;
}

/// Backs `-selectionContainerView`.
static id TGThunk_selectionContainerView(id self, SEL _cmd) {
    id<TGRichTextInputDecClientBridging> bridge = TGRichTextInputDecAttachedBridge(self);
    if (bridge == nil || ![bridge respondsToSelector:@selector(interactionContainerView)]) { return nil; }
    return [bridge interactionContainerView];
}

// TASK C14 — the two spellchecking thunks (Family 11). UNLIKE Family 9's three above, these are
// NOT probed by any `TGRichTextInputDecHostPreflight` ABI check — they exist because
// `CanvasCallbackInstallationTests`'s 22-name census (planned at Task A/B, before this family's
// own work began) already names them, and because neither
// `setContinuousSpellCheckingEnabled:`/`isContinuousSpellCheckingEnabled` is one of the 47
// resolver-validated `incomingCallbacks` rows (the manifest's OWN `checking` capability group
// names two members with these EXACT selectors, but on class `UITextInputController` with
// `direction: outgoing` — i.e. calls TELEGRAM makes OUT to the kernel's real `activeController`,
// never something the kernel calls IN on us). So, like C6/C7/C12's own non-certified additions,
// these are a documented, best-effort reconstruction — see DIVERGENCES.md entry 14 for the full
// design-decision writeup, including why the setter ALSO reaches the kernel's outgoing capability
// (through the bridge, which owns the `TGRichTextInputDecPerform` guard on the Swift side — this
// file never touches `kernelInput` directly, mirroring every other thunk's "cross through the
// bridge, never call the kernel from here" shape).

static void TGThunk_setContinuousSpellCheckingEnabled(id self, SEL _cmd, BOOL enabled) {
    id<TGRichTextInputDecClientBridging> bridge = TGRichTextInputDecAttachedBridge(self);
    if (bridge == nil || ![bridge respondsToSelector:@selector(setNativeContinuousSpellCheckingEnabled:)]) {
        return;
    }
    [bridge setNativeContinuousSpellCheckingEnabled:enabled];
}

static BOOL TGThunk_isContinuousSpellCheckingEnabled(id self, SEL _cmd) {
    id<TGRichTextInputDecClientBridging> bridge = TGRichTextInputDecAttachedBridge(self);
    if (bridge == nil || ![bridge respondsToSelector:@selector(isNativeContinuousSpellCheckingEnabled)]) {
        return NO;
    }
    return [bridge isNativeContinuousSpellCheckingEnabled];
}

// TASK F3 — the runtime half of the "never install a guessed shape" rule.
//
// `TGLastABIRejections` records rows this installer REFUSED on the last call, main-thread only (the
// installer itself only ever runs from `attach(to:)`). Rebuilt from scratch per call, so it always
// describes the current state of `canvasClass` rather than accumulating history.
static NSArray<NSString *> *TGLastABIRejections = nil;

NSArray<NSString *> *TGRichTextInputDecCanvasCallbackABIRejections(void) {
    return TGLastABIRejections ?: @[];
}

/// Compares two Objective-C method type encodings for ABI equivalence, ignoring the frame-size and
/// argument-offset digits the runtime bakes into its own (`"v20@0:8B16"` vs our `"v@:B"`).
/// `NSMethodSignature` does the normalising, exactly as `TGRichTextInputDecHostPreflight` already
/// does for the three interaction rows.
static BOOL TGEncodingsDescribeTheSameABI(const char *lhs, const char *rhs) {
    if (lhs == NULL || rhs == NULL) { return lhs == rhs; }
    NSMethodSignature *a = nil;
    NSMethodSignature *b = nil;
    @try {
        a = [NSMethodSignature signatureWithObjCTypes:lhs];
        b = [NSMethodSignature signatureWithObjCTypes:rhs];
    } @catch (NSException *exception) {
        return NO;   // a malformed encoding can never be "the same ABI" as anything
    }
    if (a == nil || b == nil) { return NO; }
    if (a.numberOfArguments != b.numberOfArguments) { return NO; }
    if (strcmp(a.methodReturnType, b.methodReturnType) != 0) { return NO; }
    for (NSUInteger index = 0; index < a.numberOfArguments; index += 1) {
        if (strcmp([a getArgumentTypeAtIndex:index], [b getArgumentTypeAtIndex:index]) != 0) {
            return NO;
        }
    }
    return YES;
}

/// The same admission test `TGAddThunk` applies, exposed so a test can prove the guard is not
/// vacuous — `IDCanvasCallbackABITests` asserts that `_deleteBackwardAndNotify:` accepts `"v@:B"`
/// and REFUSES the `"v@:@"` that crashed the app. There is no other way to exercise the refusal
/// path: every encoding this file installs is a literal, so a test cannot inject a wrong one.
BOOL TGRichTextInputDecCanvasCallbackABIWouldAccept(Class canvasClass, SEL selector,
                                                    const char *types) {
    if (canvasClass == Nil || selector == NULL || types == NULL) { return NO; }
    Method inherited = class_getInstanceMethod(class_getSuperclass(canvasClass), selector);
    if (inherited == NULL) { return YES; }   // nothing to check against — see TGAddThunk's note
    return TGEncodingsDescribeTheSameABI(method_getTypeEncoding(inherited), types);
}

/// Every `class_addMethod` in this file goes through here (Task F3).
///
/// WHEN THE SUPERCLASS CHAIN ALREADY IMPLEMENTS THE SELECTOR, THE RUNTIME IS HOLDING THE REAL,
/// CERTIFIED ENCODING FOR IT. A thunk whose declared encoding disagrees is, by construction, a wrong
/// reconstruction of a private ABI — and installing it hands UIKit an IMP that reads its arguments
/// out of the wrong registers. That is not theoretical: it is precisely how C6's
/// `_deleteBackwardAndNotify:` (`v@:@` over UIResponder's real `v@:B`) segfaulted the app on the
/// first Backspace. So a mismatch REFUSES the install and records the row; the canvas then keeps the
/// inherited system implementation, which is by definition a safer fallback than a wrong one.
///
/// No check is possible for the selectors nothing up the chain implements (most rows here) — that
/// needs a census of every class in the process, which is `IDCanvasCallbackABITests`' job, not
/// something to pay for on every attach.
static void TGAddThunk(Class canvasClass, SEL selector, IMP implementation, const char *types,
                       NSMutableArray<NSString *> *rejected) {
    Method inherited = class_getInstanceMethod(class_getSuperclass(canvasClass), selector);
    if (inherited != NULL) {
        const char *inheritedTypes = method_getTypeEncoding(inherited);
        if (!TGEncodingsDescribeTheSameABI(inheritedTypes, types)) {
            [rejected addObject:[NSString stringWithFormat:
                @"%@: refused to install \"%s\" over the runtime's own \"%s\"",
                NSStringFromSelector(selector), types, inheritedTypes ?: "(null)"]];
            return;
        }
    }
    // class_addMethod returns NO when the selector already exists on this class, which makes
    // the whole installer naturally idempotent.
    class_addMethod(canvasClass, selector, implementation, types);
}

BOOL TGRichTextInputDecInstallCanvasCallbacks(
    Class canvasClass, Class forbiddenBaseClass, NSError **error) {
    if (canvasClass == Nil || forbiddenBaseClass == Nil) {
        if (error != NULL) { *error = TGError(@"nil class"); }
        return NO;
    }
    if (canvasClass == forbiddenBaseClass) {
        if (error != NULL) {
            *error = TGError(@"refusing to install private callbacks onto the legacy canvas class");
        }
        return NO;
    }
    if (class_getSuperclass(canvasClass) != forbiddenBaseClass) {
        if (error != NULL) {
            *error = TGError(@"the canvas class must be a DIRECT subclass of the legacy class");
        }
        return NO;
    }
    // TASK F3 — every row below goes through `TGAddThunk`, which refuses an encoding that
    // contradicts one already on the superclass chain. Encodings are PROBED, not guessed; the table
    // and the measurement recipe are in this file's Task F3 block above.
    NSMutableArray<NSString *> *rejected = [NSMutableArray array];
    TGAddThunk(canvasClass, @selector(textStorage), (IMP)TGThunk_textStorage, "@@:", rejected);
    TGAddThunk(canvasClass, NSSelectorFromString(@"textInputView"),
               (IMP)TGThunk_textInputView, "@@:", rejected);
    // TASK C6 — the input-delegate thunks (Family 3), unconditional like the two above (none is a
    // resolver-validated `incomingCallbacks` row). Void return, one trailing OBJECT argument: "v@:@".
    // THREE rows, not C6's four: `_deleteBackwardAndNotify:` is deliberately not installed — see the
    // note where its thunk used to be.
    TGAddThunk(canvasClass, NSSelectorFromString(TGPN_textInputDidChange_()),
               (IMP)TGThunk_textInputDidChange, "v@:@", rejected);
    TGAddThunk(canvasClass, NSSelectorFromString(TGPN_textInputDidChangeSelection_()),
               (IMP)TGThunk_textInputDidChangeSelection, "v@:@", rejected);
    TGAddThunk(canvasClass, NSSelectorFromString(TGPN_keyboardInputChangedSelection_()),
               (IMP)TGThunk_keyboardInputChangedSelection, "v@:@", rejected);
    // TASK C7 — the two pre-mutation thunks (Family 4), unconditional like C6's above (neither
    // is a resolver-validated `incomingCallbacks` row). Both return BOOL; three trailing arguments
    // each (matching each selector's three colons): "B@:@@B" / "B@:@@@".
    TGAddThunk(canvasClass, NSSelectorFromString(TGPN_keyboardInput_shouldInsertText_isMarkedText_()),
               (IMP)TGThunk_keyboardInputShouldInsertTextIsMarkedText, "B@:@@B", rejected);
    TGAddThunk(canvasClass,
               NSSelectorFromString(@"textInput:shouldChangeCharactersInRanges:replacementText:"),
               (IMP)TGThunk_textInputShouldChangeCharactersInRangesReplacementText, "B@:@@@", rejected);
    // TASK C12 — the three interaction-host thunks (Family 9), unconditional like every thunk
    // above (none is a resolver-validated `incomingCallbacks` row — see this file's own note on
    // this group). Zero arguments, `id` return each: "@@:".
    TGAddThunk(canvasClass, NSSelectorFromString(TGPN_interactionAssistant()),
               (IMP)TGThunk_interactionAssistant, "@@:", rejected);
    TGAddThunk(canvasClass, NSSelectorFromString(TGPN__textInputViewForAddingGestureRecognizers()),
               (IMP)TGThunk_textInputViewForAddingGestureRecognizers, "@@:", rejected);
    TGAddThunk(canvasClass, NSSelectorFromString(TGPN_selectionContainerView()),
               (IMP)TGThunk_selectionContainerView, "@@:", rejected);
    // TASK C14 — the two spellchecking thunks (Family 11), unconditional like every thunk above
    // (neither is a resolver-validated `incomingCallbacks` row — see this file's own note on this
    // pair). One BOOL argument / void return ("v@:B"); zero arguments / BOOL return ("B@:").
    TGAddThunk(canvasClass, NSSelectorFromString(TGPN_setContinuousSpellCheckingEnabled_()),
               (IMP)TGThunk_setContinuousSpellCheckingEnabled, "v@:B", rejected);
    TGAddThunk(canvasClass, NSSelectorFromString(TGPN_isContinuousSpellCheckingEnabled()),
               (IMP)TGThunk_isContinuousSpellCheckingEnabled, "B@:", rejected);
    // The three ABI-witnessed rows install the very IMPs the resolver validated. They carry the
    // COMPILED encoding of `TGRichTextInputDecCanvasABIWitness`'s own methods rather than a literal,
    // so there is nothing to mistype here — but they go through `TGAddThunk` all the same, so the
    // rule is "every row in this installer is checked", with no exempt path for a future author to
    // reach for.
    for (NSString *name in @[TGPN_keyboardInputShouldDelete_(), TGPN_startAutoscroll_(), @"cancelAutoscroll"]) {
        SEL selector = NSSelectorFromString(name);
        Method method = class_getInstanceMethod(TGRichTextInputDecCanvasABIWitness.class, selector);
        if (method == NULL) {
            if (error != NULL) { *error = TGError([@"witness lacks " stringByAppendingString:name]); }
            TGLastABIRejections = rejected.copy;
            return NO;
        }
        TGAddThunk(canvasClass, selector, method_getImplementation(method),
                   method_getTypeEncoding(method), rejected);
    }
    TGLastABIRejections = rejected.copy;
    return YES;
}

// ================================ TASK F4 — TRAIT SYNCHRONISATION ================================
//
// THE MECHANISM THIS PORT WAS MISSING ENTIRELY, recovered from the upstream host rather than
// reconstructed: `IDPrivateSynchronizeTextInputTraits` in
// `~/Documents/InputDec/PrivateUIKit/IDPrivateUIKit.m`, called by `IDBlockTextView` at construction
// (`TextView/IDBlockTextView.m`, `[self id_syncTextInputTraits]`) and again from EVERY trait setter.
//
// Why it matters: with the InputDec backend installed, the object UIKit's keyboard configures itself
// from is the PRIVATE input controller's own traits, not the host view's. Measured on an attached ID
// canvas in this package's own test host: the canvas answers `autocorrectionType = .yes` /
// `spellCheckingType = .yes`, while `-[UITextInputController _textInputTraits]` still answers
// `0`/`0`/`0` — byte-identical to `+[UITextInputTraits defaultTextInputTraits]`. Nothing had ever
// written it.
//
// The rows below are PUBLIC `UITextInputTraits` property setters, so unlike the private canvas
// callbacks above they need no ABI probe — but every one is still `respondsToSelector:`-guarded and
// sent through an explicitly-typed `objc_msgSend` cast, because the receiver is a private class and
// a future OS may drop a row. A missing row is SKIPPED; upstream `@throw`s, which this port cannot
// do (Swift cannot catch an NSException — see `TGRichTextInputDecExceptionGuard.h`).

static void TGSyncIntegerTrait(id traits, NSString *setterName, NSInteger value) {
    SEL selector = NSSelectorFromString(setterName);
    if (![traits respondsToSelector:selector]) { return; }
    ((void (*)(id, SEL, NSInteger))objc_msgSend)(traits, selector, value);
}

static void TGSyncBoolTrait(id traits, NSString *setterName, BOOL value) {
    SEL selector = NSSelectorFromString(setterName);
    if (![traits respondsToSelector:selector]) { return; }
    ((void (*)(id, SEL, BOOL))objc_msgSend)(traits, selector, value);
}

static void TGSyncObjectTrait(id traits, NSString *setterName, id value) {
    SEL selector = NSSelectorFromString(setterName);
    if (![traits respondsToSelector:selector]) { return; }
    ((void (*)(id, SEL, id))objc_msgSend)(traits, selector, value);
}

/// Reads an `@optional` scalar `UITextInputTraits` getter off `source`, or `fallback` when the
/// source does not implement it. `UITextInputTraits`' members are ALL `@optional` in Objective-C, so
/// a plain `[source autocorrectionType]` on a conformer that only implements some of them would be
/// an unrecognized selector — this is not defensive padding, it is the protocol's actual contract.
static NSInteger TGSourceIntegerTrait(id source, NSString *getterName, NSInteger fallback) {
    SEL selector = NSSelectorFromString(getterName);
    if (![source respondsToSelector:selector]) { return fallback; }
    return ((NSInteger (*)(id, SEL))objc_msgSend)(source, selector);
}

static BOOL TGSourceBoolTrait(id source, NSString *getterName, BOOL fallback) {
    SEL selector = NSSelectorFromString(getterName);
    if (![source respondsToSelector:selector]) { return fallback; }
    return ((BOOL (*)(id, SEL))objc_msgSend)(source, selector);
}

static id TGSourceObjectTrait(id source, NSString *getterName) {
    SEL selector = NSSelectorFromString(getterName);
    if (![source respondsToSelector:selector]) { return nil; }
    return ((id (*)(id, SEL))objc_msgSend)(source, selector);
}

void TGRichTextInputDecSynchronizeTextInputTraits(id traits, id<UITextInputTraits> source) {
    if (traits == nil || source == nil) { return; }
    // Order and membership are upstream's list, minus the two rows whose getters do not exist on
    // `UITextInputTraits` at all (upstream reads them off its own concrete host):
    // `mathExpressionCompletionType` and `allowsNumberPadPopover`. Every remaining row is a real
    // `UITextInputTraits` member, so the getter guards above can only miss on a partial conformer.
    TGSyncIntegerTrait(traits, @"setAutocapitalizationType:",
                       TGSourceIntegerTrait(source, @"autocapitalizationType",
                                            UITextAutocapitalizationTypeSentences));
    TGSyncIntegerTrait(traits, @"setAutocorrectionType:",
                       TGSourceIntegerTrait(source, @"autocorrectionType",
                                            UITextAutocorrectionTypeDefault));
    TGSyncIntegerTrait(traits, @"setSpellCheckingType:",
                       TGSourceIntegerTrait(source, @"spellCheckingType",
                                            UITextSpellCheckingTypeDefault));
    TGSyncIntegerTrait(traits, @"setSmartQuotesType:",
                       TGSourceIntegerTrait(source, @"smartQuotesType",
                                            UITextSmartQuotesTypeDefault));
    TGSyncIntegerTrait(traits, @"setSmartDashesType:",
                       TGSourceIntegerTrait(source, @"smartDashesType",
                                            UITextSmartDashesTypeDefault));
    TGSyncIntegerTrait(traits, @"setSmartInsertDeleteType:",
                       TGSourceIntegerTrait(source, @"smartInsertDeleteType",
                                            UITextSmartInsertDeleteTypeDefault));
    TGSyncIntegerTrait(traits, @"setInlinePredictionType:",
                       TGSourceIntegerTrait(source, @"inlinePredictionType", 0));
    TGSyncIntegerTrait(traits, @"setKeyboardType:",
                       TGSourceIntegerTrait(source, @"keyboardType", UIKeyboardTypeDefault));
    TGSyncIntegerTrait(traits, @"setKeyboardAppearance:",
                       TGSourceIntegerTrait(source, @"keyboardAppearance",
                                            UIKeyboardAppearanceDefault));
    TGSyncIntegerTrait(traits, @"setReturnKeyType:",
                       TGSourceIntegerTrait(source, @"returnKeyType", UIReturnKeyDefault));
    TGSyncBoolTrait(traits, @"setEnablesReturnKeyAutomatically:",
                    TGSourceBoolTrait(source, @"enablesReturnKeyAutomatically", NO));
    TGSyncBoolTrait(traits, @"setSecureTextEntry:",
                    TGSourceBoolTrait(source, @"isSecureTextEntry", NO));
    TGSyncObjectTrait(traits, @"setTextContentType:",
                      TGSourceObjectTrait(source, @"textContentType"));
    TGSyncObjectTrait(traits, @"setPasswordRules:",
                      TGSourceObjectTrait(source, @"passwordRules"));
}

#endif
