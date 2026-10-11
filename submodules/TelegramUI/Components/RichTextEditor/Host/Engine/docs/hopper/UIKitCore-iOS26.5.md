# UIKitCore iOS 26.5 text-view contracts

Verified against the iOS 26.5 (`23F73`) `UIKitCore` documents examined in Hopper. Addresses in the
opening tables that begin `0x189...`/`0x18a...` are **VM addresses from the device image**. Later
tables explicitly labeled **file-relative** use offsets from the iOS 26.5 simulator document. A
file-relative offset is never presented as a VM address. UIFoundation evidence is labeled
separately because it comes from that private framework rather than UIKitCore.

The procedure entry points and decompiled responsibilities are:

| Address | Procedure | Mirrored responsibility |
|---|---|---|
| `0x189421214` | `+[_UITextLayoutControllerBase layoutControllerWithTextView:textContainer:]` | Select TextKit 2 controller |
| `0x1893e6440` | `-[_UITextKit2LayoutController initWithTextView:textContainer:]` | Bind view, text container, layout manager |
| `0x18967edec` | `-[_UITextKit2LayoutController .cxx_destruct]` | Clear five strong fields, then destroy weak host-view field |
| `0x189370920` | `-[UITextInputController initWithTextLayoutController:]` | Create semantic input state |
| `0x1893dad5c` | `-[UITextInteractionAssistant initWithView:textInteractionMode:]` | Install interaction gestures |
| `0x1893e17dc` | `-[UITextInteractionAssistant initWithView:]` | Default interaction initialization |
| `0x1896896b4` | `-[UITextView caretRectForPosition:]` | Forward to input controller |
| `0x18968d5f8` | `-[UITextView selectionRectsForRange:]` | Forward to input controller |
| `0x18a9ffcac` | `-[UITextView beginFloatingCursorAtPoint:]` | Forward to interaction assistant |
| `0x18a9ffd64` | `-[UITextView updateFloatingCursorAtPoint:animated:]` | Forward to interaction assistant |
| `0x18a9ffdd0` | `-[UITextView endFloatingCursor]` | Forward to interaction assistant |
| `0x1896874d0` | `-[UITextView textInputDidChangeSelection:]` | Notify delegate, update formatting, then keep caret visible |
| `0x189687548` | `-[UITextView _scrollToCaretIfNeeded]` | Gate and scroll active caret inside effective insets |
| `0x18a9fbbf4` | `_scrollToCaretIfNeeded block` | Layout canvas and obtain the active selection caret rect |

## Production dependency and provenance index

This ledger covers every private runtime dependency compiled into `PrivateUIKit/`. It separates
address-backed Hopper recovery from live-runtime verification so that a missing procedure address
is never guessed.

- Private classes: `_UITextLayoutControllerBase`, `_UITextKit2LayoutController`,
  `UITextInputController`, and `UITextInteractionAssistant`. Their constructors and ownership are
  covered by the address table above and **Task 4 controller-construction callbacks**. The optional
  base factory and mandatory concrete simulator path are distinguished under **Device and simulator
  capability divergence**.
- Internal protocol: `UITextPasteConfigurationSupporting_Internal`. Its runtime adoption and
  controller dependency are covered under **Commands, asynchronous paste support, and undo
  ownership**, based on Hopper procedure `0x18937103c` plus live protocol lookup/conformance tests.
- Layout construction selectors: `layoutControllerWithTextView:textContainer:`,
  `initWithTextView:textContainer:`, `initWithTextLayoutController:`, and `setDelegate:`. These are
  address-backed in the first table and Task 4 table. `setTextView:` and the reciprocal `textView`
  container query are grouped under **Text-container host root cause and coordinate result**; the
  selector ABIs are live-runtime verified because the open UIKitCore document did not provide a
  procedure address for the container method.
- Interaction selectors: `initWithView:`, `selectionChanged`, `setGestureRecognizers`,
  `clearGestureRecognizers:`, `setNeedsSelectionDisplayUpdate`, `beginFloatingCursorAtPoint:`,
  `updateFloatingCursorAtPoint:animated:`, `endFloatingCursor`, `selectWord`, and `selectAll:` are
  covered by the address table and **Task 7 native interaction hosting, loupe, and floating cursor**.
  The hosted view's `interactionAssistant` callback returns that constructed assistant directly.
  The adjacent `activateSelection`, `deactivateSelection`, and `setSelectionDisplayVisible:` sends
  use `void <- ()`, `void <- ()`, and `void <- BOOL` respectively; they are mandatory,
  compatibility-guarded live iOS 26.5 contracts used only for responder lifecycle transitions.
- Input-command selectors: `undoManager`, `cut:`, `copy:`, `paste:`,
  `_canHandleResponderAction:`, `_shouldHandleResponderAction:withSender:`,
  `_rangesForBackwardsDelete`, `keyboardInputShouldDelete:`, and `selectionAffinity` are covered by
  **Task 8 geometry, scrolling, edit commands, and controller-owned undo**. The deletion-ranges
  helper's `unionRange` is a live aggregate ABI returning `NSRange`. Construction safely obtains the
  initial `_rangesForBackwardsDelete` result and validates non-nil `unionRange` support without
  invoking `unionRange`; ordinary delete/cut handling repeats the query and validation immediately
  before its typed send. A changed aggregate ABI therefore fails inside editor construction and is
  surfaced by the demo's narrow construction diagnostic path. `keyboardInputChangedSelection:` is
  a guarded optional delegate callback.
- Geometry/range selectors: `selectionRectsForRange:fromView:forContainerPassingTest:` is
  address-backed under Task 8. The range adapter's `textKit2Ranges` object-array return is a
  live-runtime-verified diagnostic ABI and is selector-validated on each dynamic range adapter.
  Every unconditional public `UITextInput` forward in **Task 5 `UITextInput` semantic forwarding**
  is a mandatory `UITextInputController` preflight contract. The two locally derived character-
  offset methods send only through those required public primitives; `insertDictationResult:` is
  guarded and inventoried as optional with a public insertion fallback. The forwards use the grouped
  object/integer/`CGPoint`/`CGRect`/`NSRange` message shapes rather than private SDK headers.
- Runtime mechanisms: `NSClassFromString`, `NSProtocolFromString`, `NSSelectorFromString`,
  `class_getInstanceMethod`, `class_conformsToProtocol`, `class_addProtocol`, and typed
  `objc_msgSend` are confined to `PrivateUIKit/IDPrivateUIKit.m`. The compatibility table validates
  every mandatory statically knowable class/selector before construction; the private paste protocol
  is validated before runtime adoption. Source-audit tests mechanically compare every direct
  input-controller forward and every literal bridge send with this required/optional/staged inventory.

## Hopper pseudo-code summary

- `0x189421214` checks the text view's `textLayoutManager`, constructs `_UITextKit2LayoutController` when present, and otherwise falls back to `_UITextKit1LayoutController`.
- `0x1893e6440` initializes the host-view field with weak ARC storage, retains the container's text layout manager, assigns itself as the layout-manager delegate when needed, validates and stores the text content manager, observes it, and creates its mapping table.
- `0x18967edec` clears strong fields at offsets `0x50`, `0x48`, `0x40`, `0x38`, and `0x30`, in that order, then tail-destroys the weak host-view field at offset `0x28`.
- `0x189370920` requires a layout controller, attaches it, observes its text storage, initializes an empty selection at the beginning of the document, and builds supporting semantic input state.
- `0x1893dad5c` stores the view and interaction mode, installs gesture recognizers, updates conformance state, and registers for notifications.
- `0x1893e17dc` delegates to `initWithView:textInteractionMode:` with the default mode value.
- `0x1896896b4` and `0x18968d5f8` load the input controller stored by `UITextView` and forward geometry queries to it.
- `0x18a9ffcac`, `0x18a9ffd64`, and `0x18a9ffdd0` obtain the view's interaction assistant and forward floating-cursor lifecycle calls.

The editor owns the TextKit stack. The layout controller owns position/range geometry. The input controller owns selected and marked ranges plus input-delegate ordering. The interaction assistant owns gestures and transient selection UI.

The layout controller does not retain its host editor. In the initializer, assembly at
`0x1893e64b8`–`0x1893e64c4` initializes the first host slot through the weak ARC path (the image's
`objc_initWeak` import stub is at `0x18ac4d058`). The destructor at `0x18967edec` performs five
`objc_storeStrong(..., nil)` calls for offsets `0x50` through `0x30`, then tail-branches through the
weak-destroy path for offset `0x28` (the image's `objc_destroyWeak` import stub is at `0x18ac4cfa8`).
This initializer/destructor pair is the ownership evidence; the host association is weak.

## Task 4 controller-construction callbacks

For Task 4, `procedure_callees` and `procedure_pseudo_code` were queried for each
constructor and editor callback below. The recovered object-return contracts are:

| Address | Procedure | `procedure_callees` / pseudo-code evidence |
|---|---|---|
| `0x189421214` | `+[_UITextLayoutControllerBase layoutControllerWithTextView:textContainer:]` | Calls `textLayoutManager`; a non-nil result selects `_UITextKit2LayoutController` and invokes `initWithTextView:textContainer:`. |
| `0x1893e6440` | `-[_UITextKit2LayoutController initWithTextView:textContainer:]` | Calls the container's `textLayoutManager`, then that manager's `delegate`, `setDelegate:`, and `textContentManager`. |
| `0x189370920` | `-[UITextInputController initWithTextLayoutController:]` | Calls the supplied layout controller's `textStorage`, `beginningOfDocument`, and `emptyTextRangeAtPosition:` before creating semantic input state. |
| `0x1893eb608` | `-[UITextView textLayoutManager]` | Calls `textContainer`, then returns its `textLayoutManager`. |
| `0x189423910` | `-[UITextView textContainer]` | Returns the stored text-container ivar directly; no callees. |
| `0x189665600` | `-[UITextView textStorage]` | Returns the stored text-storage ivar directly; no callees. |
| `0x189423e68` | `-[UITextView textInputView]` | Returns the stored text-input/canvas view ivar directly; no callees. |
| `0x189423e00` | `-[UITextView _textInputViewForAddingGestureRecognizers]` | Has no callees and consists only of `ret`, preserving the incoming `self` in `x0` as the returned view. |
| `0x189666704` | `-[UITextView textLayoutController]` | Returns the stored layout-controller ivar directly; no callees. |
| `0x18968d6e8` | `-[UITextView(_UITextAssistantManagerNullabilitySupport) _internalTextLayoutController]` | Calls `textLayoutController`, validates the result, and returns it when valid. |

`IDTextView` therefore exposes its existing TextKit 2 objects through typed callbacks,
owns the concrete layout and input controllers in that order, and leaves the interaction
assistant nil until the later interaction task. The iOS 26.5 simulator completed both
constructors without requesting any additional callback.

## Device and simulator capability divergence

The device `UIKitCore` image inspected in Hopper contains the `_UITextLayoutControllerBase` factory at `0x189421214`. The iOS 26.5 (23F73) simulator runtime exposes `_UITextLayoutControllerBase` but does not respond to `layoutControllerWithTextView:textContainer:`. It does expose the concrete `_UITextKit2LayoutController` initializer at `0x1893e6440`'s recovered contract. The bridge therefore treats the concrete initializer as mandatory, prefers the base factory when available, and otherwise constructs the TextKit 2 controller directly. Its compatibility report identifies the active path.

## Task 5 `UITextInput` semantic forwarding

`procedure_callees`, `procedure_pseudo_code`, and (for the non-object ABIs) `procedure_assembly`
were checked for the iOS 26.5 device `UIKitCore` procedures below. In each forwarding
procedure, `UITextView` loads its input-controller ivar and sends the same public selector.
The ABI column uses the iOS 26.5 SDK declarations and the AArch64 register usage; Hopper's
automatically recovered Objective-C signatures label many object and aggregate values as `int`.

| Address | `UITextView` procedure | Forwarded ABI |
|---|---|---|
| `0x1897f213c` | `textInRange:` | object ← object |
| `0x18aa0127c` | `replaceRange:withText:` | void ← object, object |
| `0x189423ff8` | `selectedTextRange` | object ← no arguments |
| `0x18aa01484` | `setSelectedTextRange:` | void ← object; then selection UI notification |
| `0x1893e97f4` | `markedTextRange` | object ← no arguments |
| `0x18aa01560` | `markedTextStyle` | object ← no arguments |
| `0x18aa015b8` | `setMarkedTextStyle:` | void ← object |
| `0x18aa01624` | `setMarkedText:selectedRange:` | void ← object, `NSRange` |
| `0x18aa0172c` | `unmarkText` | void ← no arguments |
| `0x18961dd24` | `beginningOfDocument` | object ← no arguments |
| `0x189689374` | `endOfDocument` | object ← no arguments |
| `0x1897f1dbc` | `textRangeFromPosition:toPosition:` | object ← object, object |
| `0x1897f1730` | `positionFromPosition:offset:` | object ← object, `NSInteger` |
| `0x18aa01774` | `positionFromPosition:inDirection:offset:` | object ← object, `NSInteger`, `NSInteger` |
| `0x1897f17ac` | `comparePosition:toPosition:` | `NSInteger` ← object, object |
| `0x18961dd7c` | `offsetFromPosition:toPosition:` | `NSInteger` ← object, object |
| `0x1893e79f0` | `inputDelegate` | object ← no arguments |
| `0x1897f1510` | `setInputDelegate:` | void ← object |
| `0x1893e984c` | `tokenizer` | object ← no arguments |
| `0x18aa01800` | `positionWithinRange:farthestInDirection:` | object ← object, `NSInteger` |
| `0x18aa0187c` | `characterRangeByExtendingPosition:inDirection:` | object ← object, `NSInteger` |
| `0x18aa01960` | `baseWritingDirectionForPosition:inDirection:` | `NSInteger` ← object, `NSInteger` |
| `0x1897f9d84` | `setBaseWritingDirection:forRange:` | void ← `NSInteger`, object |
| `0x18aa019c4` | `firstRectForRange:` | `CGRect` ← object |
| `0x1896896b4` | `caretRectForPosition:` | `CGRect` ← object |
| `0x18968d5f8` | `selectionRectsForRange:` | object ← object |
| `0x18aa01a48` | `closestPositionToPoint:` | object ← `CGPoint` |
| `0x18aa01ab8` | `closestPositionToPoint:withinRange:` | object ← `CGPoint`, object |
| `0x18aa01b44` | `characterRangeAtPoint:` | object ← `CGPoint` |
| `0x1897f1e40` | `textStylingAtPosition:inDirection:` | object ← object, `NSInteger` |
| `0x18a9ff7d4` | `insertText:` | void ← object |
| `0x18a9ff9c0` | `deleteBackward` | void ← no arguments |
| `0x1897f112c` | `hasText` | `BOOL` ← no arguments |

The bridge therefore has distinct typed sends for object, integer, `CGPoint`, `CGRect`, and
`NSRange` shapes. `IDTextView` follows the task contract and computes `hasText` from its plain-text
storage, while the remaining table entries use the input controller and the same public selector.

### Optional-method divergence

Hopper contains no `UITextView` procedures named
`positionWithinRange:atCharacterOffset:`, `characterOffsetOfPosition:withinRange:`, or
`insertDictationResult:`. The iOS 26.5 simulator's live `UITextInputController` likewise returns
false from `respondsToSelector:` for those three selectors, while it returns true for
`textStylingAtPosition:inDirection:`. Sending the absent position selector was confirmed to raise
`NSInvalidArgumentException`.

Accordingly, the two character-offset optionals are derived from the already-forwarded public
position, comparison, and offset primitives, with bounds enforced against the supplied range.
Dictation uses the typed direct send only when the live controller accepts it; otherwise it
concatenates each `UIDictationPhrase.text` and inserts the result through `insertText:`. This avoids
inventing private selectors or swallowing unknown messages.

## Task 6 responder lifecycle and controller-delegate ordering

`procedure_callees` and `procedure_pseudo_code` were queried for the required lifecycle and
delegate procedures. The input controller's notification funnel and change-gating helper were
also inspected to establish which callbacks are synchronous and their exact order.

| Address | Procedure | iOS 26.5 behavior mirrored |
|---|---|---|
| `0x18a9fc730` | `-[UITextView canBecomeFirstResponder]` | Performs responder/delegate eligibility checks. `IDTextView` applies its explicit public contract: interaction enabled and either editable or selectable. |
| `0x1897f4c5c` | `-[UITextView becomeFirstResponder]` | On a successful editable transition, sends the begin-editing notification; then updates selection gestures, makes selection visible, and activates selection. An already-first-responder call returns without repeating lifecycle work. |
| `0x160fdfc` | `-[UITextView resignFirstResponder]` | Calls `_cleanUpForResignFirstResponder` only after the superclass transition succeeds. |
| `0x160fccc` | `-[UITextView _cleanUpForResignFirstResponder]` | Orders selection-visible NO, assistant `deactivateSelection`, selection-gesture refresh, and the input-controller did-end transition. It never calls assistant `resignedFirstResponder`. |
| `0x18aa05ea0` | `-[UITextView textInput:shouldChangeCharactersInRanges:replacementText:]` | Consults the public delegate before mutation, preferring the multi-range delegate and otherwise reducing to the legacy range callback. |
| `0x18aa01fd8` | `-[UITextView textInputDidChange:]` | Updates layout/display state, then invokes `textViewDidChange:`. It does not invoke the public selection callback. |
| `0x1896874d0` | `-[UITextView textInputDidChangeSelection:]` | Invokes `textViewDidChangeSelection:` and then performs selection-related UI updates. |
| `0x189687360` | `-[UITextInputController _sendDelegateChangeNotificationsForText:selection:replacement:characterRange:]` | Sends `textInputDidChangeSelection:` first when selection changed, then `textInputDidChange:` when text changed. Both sends are synchronous. |
| `0x18a9de9f0` | `-[UITextInputController _delegateShouldChangeTextInRange:replacementText:]` | Uses `textInput:shouldChangeCharactersInRanges:replacementText:` when the delegate implements it; otherwise uses the singular-range form. |

The controller therefore owns edit notification timing. Public mutators forward to it without a
second manual `id_didMutateText` call. A live accepted insertion records exactly
`should -> selection -> change`; the earlier Task 5 post-send hooks produced
`selection -> change -> selection -> change -> selection` once the delegate callbacks existed.
Selection assignment also relies exclusively on the live controller callback: a changed normalized
range produces one synchronous notification, while assigning the same normalized range produces
none.

### Additional keyboard-input callbacks

Hopper contains these adjacent procedures:

| Address | Procedure | Responsibility |
|---|---|---|
| `0x1896872d0` | `-[UITextView keyboardInputChangedSelection:]` | Forwards the selection change to a distinct keyboard-input delegate when present. |
| `0x18aa055fc` | `-[UITextView keyboardInput:shouldReplaceTextInRange:replacementText:]` | Wraps one range and delegates to the plural replacement callback. |
| `0x18aa056ec` | `-[UITextView keyboardInput:shouldReplaceTextInRanges:replacementText:]` | Gates replacement through the public text-view delegate. |
| `0x18aa057bc` | `-[UITextView keyboardInput:shouldInsertText:isMarkedText:]` | Gates insertion at the selected range through the public text-view delegate. |
| `0x18aa058e0` | `-[UITextView keyboardInputShouldDelete:]` | Gates backward deletion using the controller's computed deletion ranges. |
| `0x18aa05a0c` | `-[UITextView keyboardInputChanged:]` | Forwards to a distinct keyboard-input delegate when present. |

The required `keyboardInputChangedSelection:` and
`keyboardInput:shouldInsertText:isMarkedText:` entry points are implemented explicitly. The live
`UITextInputController` insertion path invoked the `textInput...` gating/change callbacks, not the
remaining keyboard-layer procedures, so no speculative replacement/delete/change definitions
were added. All controller delegate callback definitions remain in
`PrivateUIKit/IDTextView+PrivateInputDelegate.m`.

## Task 7 native interaction hosting, loupe, and floating cursor

The live iOS 26.5 assistant was constructed only after the layout and input controllers. Its
initializer installed UIKit's recognizers directly on `IDTextView`, whose
`_textInputViewForAddingGestureRecognizers` callback returns the editor itself. The simulator
reported these text-interaction classes: `UITextMultiTapRecognizer`,
`UITapAndAHalfRecognizer`, `UIVariableDelayLoupeGesture`,
`_UIPanOrFlickGestureRecognizer`, `UITextTapRecognizer`, and
`UITextRangeAdjustmentGestureRecognizer` (alongside the editor's normal scroll-view gestures).

| Address | Procedure | iOS 26.5 behavior mirrored |
|---|---|---|
| `0x1893dad5c` | `-[UITextInteractionAssistant initWithView:textInteractionMode:]` | Stores the view and mode, calls `setGestureRecognizers`, updates render-space and formatting conformance, then registers notifications. |
| `0x1893e17e4` | `-[UITextInteractionAssistant setGestureRecognizers]` | Computes gesture state, clears old recognizers, asks the view for `_textInputViewForAddingGestureRecognizers`, and calls `addGestureRecognizersToView:` on that host. |
| `0x18a97c8c0` | `-[UITextInteractionAssistant shouldDisplayLoupeSessionForTouchType:]` | Returns true for the primary touch type without consulting the hosted view. |
| `0x18a97d5cc` | `-[UITextInteractionAssistant loupeGestureWithState:location:translation:velocity:modifierFlags:shouldCancel:]` | Obtains UIKit's refinement interaction, calls `willBeginExternalGesture`, and forwards the complete loupe gesture. No editor-side loupe is synthesized. |
| `0x189423e00` | `-[UITextView _textInputViewForAddingGestureRecognizers]` | Returns `self`; the procedure is one `ret` instruction. |
| `0x1893e9694` | `-[UITextView selectionContainerView]` | Lazily obtains or creates a separate selection container and places it relative to the text host. |
| `0x1894202f8` | `-[UITextView _existingSelectionContainerView]` | Returns the existing hosted selection view without forcing creation. |
| `0x189423ea8` | `-[UITextView _placeSelectionContainerView]` | Attaches the selection container to the applicable TextKit 2 canvas or editor hierarchy and requests layout. |
| `0x189423e04` | `-[UITextView _isInteractiveTextSelectionDisabled]` | Treats a selectable text view as interactive unless an independent override disables selection. |
| `0x1894244c8` | `-[UITextView _updateSelectionGestures]` | Installs assistant gestures for selectable content and clears them when selection is unavailable or conflicting drag/drop is active. |
| `0x18961cb9c` | `-[UITextView customRenderController]` | Returns a nullable stored controller directly. A nil callback selects TextKit 2's normal layout-manager enumeration path. |
| `0x189686d1c` | `-[UITextInteractionAssistant selectionChanged]` | Updates native selection UI, then calls `notifyKeyboardSelectionChanged` for the synchronous interaction path. |
| `0x1896871ec` | `-[UITextInteractionAssistant notifyKeyboardSelectionChanged]` | Obtains the current keyboard input delegate and calls the hosted view's `keyboardInputChangedSelection:` callback. |
| `0x1896872d0` | `-[UITextView keyboardInputChangedSelection:]` | Forwards only to a distinct delegate that implements the callback; it does not call the interaction assistant again. |

The project keeps `IDTextView`'s separate transparent selection container above its canvas.
Every UIKit-private host callback is defined in
`PrivateUIKit/IDTextView+PrivateInteractionCallbacks.m`; dynamic class/selector lookup and typed
message sends remain in the bridge. The public floating-cursor methods forward to the installed
assistant as recovered at `0x18a9ffcac`, `0x18a9ffd64`, and `0x18a9ffdd0`.
Selection mutation uses the input-controller delegate callback to notify the assistant exactly
once. The assistant's subsequent keyboard notification is forwarded only to a distinct delegate,
preventing re-entry into `selectionChanged`.

The public `selectable` lifecycle now converges with UIKit's private callback without adding a
private selector: `setSelectable:` performs an actual-change check and calls the project-internal
`id_updateSelectionGestures` helper, while `_updateSelectionGestures` calls that same helper. The
helper uses the existing typed bridge operations for `setGestureRecognizers` and
`clearGestureRecognizers:`. This follows the previously captured live Hopper procedures at
`0x1893e17e4` (assistant installation clears old recognizers before adding the computed set) and
`0x1894244c8` (the text view installs or clears assistant gestures according to selection state).

### Floating-cursor selection extension (Task 3)

The pinned iOS 26.5 software keyboard enters ranged selection with an added touch while the
spacebar pan is already active. It does not require a Shift HID event. Hopper's UIKitCore file
offsets and recovered branches are:

| File offset | Procedure / branch | Recovered behavior |
|---|---|---|
| `0x1088508` | `-[_UIKeyboardTextSelectionInteraction panningGestureAddedTouch:]` | On recognizer state `began` while the owner is panning, calls `setHadAddedTouch:YES` at `0x1088578`. |
| `0x10885f4` | `-[_UIKeyboardTextSelectionInteraction panningGesture:]` | Reads `hadAddedTouch`; the ranged-selection branch calls the selection controller's `switchToRangedSelection` at `0x1088dd4`. The distinct hardware-Shift alternative is queried at `0x1088d04` and forwarded at `0x1088e50`; it was not active in the pinned software-keyboard trace. |
| `0x107f5f4` | `-[_UIKeyboardTextSelectionController switchToRangedSelection]` | Obtains the interaction assistant, sends `setSelectionHighlightMode:0`, then tail-calls `updateSelectionRects`. |
| `0x1080118` | `-[_UIKeyboardTextSelectionController restartSelection]` | Copies the input delegate's `selectedTextRange` to `initialSelection`, then sets `selectionBase` to that canonical range. |
| `0x1576660` | `-[UITextSelection updateBaseAndInitialExtent]` | Computes base and initial extent from the native selection geometry. |
| `0x1576d44` | `-[UITextSelection setRangedSelectionExtentPoint:baseIsStart:allowFlipping:]` | Maps/clips the moving point through the document, compares it with the base, permits endpoint flipping, and installs the selected range. |

The live iPhone 17 Pro simulator trace measured the spacebar frame as
`{{103.3333333333,752},{197.3333333333,54}}`. One synthesized record used primary touch
`path-0` at `{202,779}` (`down=0.000`, activation `0.550`, first point `{154,779}` at
`2.400`, second point `{254,779}` at `8.400`, lift `9.800`) and added touch `path-1` at
`{152.6666666667,779}` (`down=0.850`, held through `9.200`, lift `9.500`). No observable
modifier was active. Pre-lift stock samples were `{45,1}`, `{45,1}`, `{43,3}`, `{40,6}`,
`{40,6}`, `{40,6}`, `{40,7}`, `{40,9}`, `{40,11}`, and `{40,12}`. The pre-cross samples
keep logical end `46` fixed; after crossing, UIKit flips to fixed logical start `40`. The
canonical 257-UTF-16-unit text remained unchanged through both lifts and quiescence.

## Task 1 touch-selection recovery (iOS 26.5 simulator, `23F73`)

### Gesture-recognizer host callback fallback (file-relative)

The current Hopper document is UIKitCore from iOS 26.5 build `23F73`. The
candidate `-[UITextView _textInputViewForAddingGestureRecognizers]` is the
single-instruction procedure at `0x1615ff4`; its `ret` preserves incoming
`self` in `x0`. Its selector stub is `0x219d620`, named
`_objc_msgSend$_textInputViewForAddingGestureRecognizers`, and Hopper reports
one xref at `0x15661f8` inside
`-[UITextInteractionAssistant setGestureRecognizers]` (`0x1566108`).

The recovered host order in `setGestureRecognizers` is exact: after clearing
the old graph, UIKit probes the hosted input with `respondsToSelector:` and
uses `_textInputViewForAddingGestureRecognizers` when present. If absent it
uses `externalInteractions.view` when nonnil, otherwise the hosted input's
`textInputView`. Each branch passes the selected host to
`addGestureRecognizersToView:` (`0x15663f4`).

`-[UITextInteractionAssistant initWithView:textInteractionMode:]` at
`0x156460c` weak-stores the hosted view and calls `setGestureRecognizers` at
`0x1564668` before its notification registration. Therefore InputDec's
ordinary missing-callback construction path reaches the existing block
`textInputView`, `IDBlockStackCanvasView`, unless a live external-interactions
host has already been supplied. `addGestureRecognizersToView:` is the full
interaction-graph installer, not a tap-recognizer-only helper.

Hopper MCP was reconnected with `current_document == UIKitCore`. The open simulator document
returned the file-relative entry points below. Queries at the previously recorded device VM
addresses (`0x1893e17e4`, `0x18a97c8c0`, `0x18a97d5cc`, `0x1893e9694`,
`0x1894202f8`, `0x189423ea8`, and `0x1894244c8`) correctly returned no procedure in this
file-relative document; those VM addresses remain in the Task 7 table and are not relabeled as
simulator offsets. Name searches reconfirmed their corresponding simulator procedures:

| File-relative address | Procedure | Hopper ABI / recovered contract |
|---|---|---|
| `0x1566108` | `-[UITextInteractionAssistant setGestureRecognizers]` | `void <- ()`; installs the assistant-owned recognizer set on the hosted input view. |
| `0x1565240` | `-[UITextInteractionAssistant shouldDisplayLoupeSessionForTouchType:]` | `BOOL <- NSInteger`. |
| `0x15679c8` | `-[UITextInteractionAssistant loupeGestureWithState:location:translation:velocity:modifierFlags:shouldCancel:]` | `void <- NSInteger, object, object, object, NSInteger, BOOL *`. Assembly preserves `x2...x7`, retains the three object arguments, calls `willBeginExternalGesture`, then forwards the same six arguments to the refinement interaction. |
| `0x1615f44` | `-[UITextView selectionContainerView]` | object return; reuses `_existingSelectionContainerView`, or allocates, stores, and places one container. |
| `0x1615ed8` | `-[UITextView _existingSelectionContainerView]` | object return; no forced creation. |
| `0x1608d84` | `-[UITextView _placeSelectionContainerView]` | no-argument placement callback. |
| `0x161d01c` | `-[UITextView _updateSelectionGestures]` | `void <- ()`. |
| `0x1565428` | `-[UITextInteractionAssistant activeSelectionController]` | object return; calls `_setTextSelectionControllerFromDelegate`, then returns the retained/autoreleased assistant field. |
| `0x156cf7c` | `-[UITextInteractionAssistant selectionContainerView]` | object return; weak-loads the hosted view and uses its `selectionContainerView`, falling back to `textInputView`. |

The tap and granularity path is assistant/controller owned, not editor owned. Hopper returned
`0x153e25c` for `-[UITextSelectionInteraction _handleMultiTapGesture:]`; it obtains the assistant
delegate's `activeSelectionController`, checks repeated taps, and updates tap history. The exact
selection entry points are `0x153da78`
`tappedToUpdateSelectionWithGesture:atPoint:granularity:completionHandler:`, `0x153ddf4`
`tappedToPositionCursorWithGesture:atPoint:granularity:completionHandler:`, and `0x153e05c`
`tappedToSelectTextWithGesture:atPoint:granularity:completionHandler:`, each with ABI
`void <- object, CGPoint, NSInteger, block`. Cursor positioning calls
`selectPositionAtPoint:granularity:completionHandler:`; ranged selection calls
`selectTextWithGranularity:atPoint:completionHandler:`. The granularity calculation is at
`0x153d5c8`, ABI `NSInteger <- NSUInteger tapCount`; its pseudo-code uses a recovered lookup table
for counts through two and returns granularity `3` above two. The table contents were not returned,
so no numeric word/paragraph mapping is asserted. Word selection is separately present at
`0x15681d8` (`void <- ()`, `selectWord`), and paragraph expansion at `0x1124f34` has the exact
aggregate ABI `NSRange <- NSRange` (`paragraphRangeForRange:`).

Range adjustment uses two explicit point spaces. `0x156c924`
`_rangeAdjustmentPointInTextInputCoordinateSpace:` has ABI `CGPoint <- CGPoint` and converts from
the range-adjustment container into `view._proxyTextInput.textInputView`. `0x156cee4`
`containerCoordinateSpaceForTextRangeAdjustmentInteraction:` returns the container coordinate
space. The begin/move/end callbacks are:

| Address | Callback ABI | Recovered ordering |
|---|---|---|
| `0x156ca34` | `void <- object, CGPoint` | convert point; delegate-will-move; hide commands; will-begin interaction; begin selection change; seed base/extent (including visual-BIDI branch); notify keyboard selection; request display update; notify selection-view manager. |
| `0x156cd48` | `void <- object, CGPoint, CGPoint` | thin move callback into the range-adjustment update path. |
| `0x156cc68` | `void <- CGPoint, CGPoint, NSInteger` | convert both points to text-input coordinates; set the active selection extent; notify keyboard selection; invalidate/request selection display; start autoscroll. |
| `0x156cd4c` | `void <- object, CGPoint` | optionally show commands and commit; end selection change; did-end interaction; cancel autoscroll; notify selection-view manager. |

The adjacent legacy range callbacks returned at `0x1568c80`, `0x1569124`, and `0x1568e70` with
ABIs `void <- CGPoint`, `void <- CGPoint, CGPoint`, and `void <- CGPoint`. Edge scrolling remains
assistant owned: `0x1569e88` (`startAutoscroll:`, `void <- CGPoint`) first gates through
`_canAutoscroll`, records the extent converted from `textInputView`, and starts the scroll client;
`0x156a160` (`updateAutoscroll:`, `void <- object`) reads scroll bounds/insets/offset, updates the
selection point, and sets content offset; `0x156a020` (`cancelAutoscroll`, `void <- ()`) terminates
that session. Thus UIKit owns gesture state, tap semantics, range-adjustment sequencing, loupe, and
edge-scroll timing. The clean-room editor supplies only canonical range/geometry callbacks through
`IDRichTextLayoutController` and a stable selection-container host.

## Task 4 native loupe host recovery (iOS 26.5 simulator, `23F73`)

The held-loupe pass followed the assistant call into refinement behavior and recovered the
above-text host lookup rather than adding an editor-owned magnifier or calling UIKit's gesture
handler from production code:

| File-relative address | Procedure | Hopper ABI / recovered contract |
|---|---|---|
| `0x15679c8` | `-[UITextInteractionAssistant loupeGestureWithState:location:translation:velocity:modifierFlags:shouldCancel:]` | `void <- NSInteger, object, object, object, NSInteger, BOOL *`; the three object arguments are point-provider blocks. The assistant obtains the interactive-refinement interaction, calls `willBeginExternalGesture`, and forwards all six arguments unchanged. |
| `0x153a0bc` | `-[UITextRefinementInteraction loupeGestureWithState:location:translation:velocity:modifierFlags:shouldCancel:]` | Forwards the same ABI to the refinement behavior delegate. |
| `0xb23f58` | touch refinement behavior loupe implementation | Invokes the provider blocks for `CGPoint` values. State `1` begins the native loupe session, state `2` updates it from the active selection/caret geometry, and terminal states through `4` end it. |
| `0x156cffc` | `-[UITextInteractionAssistant selectionContainerViewAboveText]` | Weak-loads the hosted view; calls `_selectionContainerViewAboveText` when present, otherwise returns the hosted `textInputView`. |
| `0x1615ff0` | `-[UITextView _selectionContainerViewAboveText]` | Tail-calls the text view's `_contentView`. |
| `0x160b880` | `-[UITextView _contentView]` | A single `ret` in this iOS 26.5 build, so the inherited object result is the `UITextView` receiver itself. |
| `0x16107b0` | `-[UITextView _convertPointFromRenderSpace:]` | Returns the point unchanged when `customRenderController` is nil; conversion is delegated only when a custom render controller exists. This rules out subtracting text-container insets in the callback. |

The clean-room `_contentView` analogue is `IDBlockTextView.id_blockStack`, not the outer scroll
view and not the lazily created selection overlay: independent block text and UIKit's caret are
laid out in that inset canvas. A test-only direct native-loupe sequence measured the stock loupe
at `{{32,199.5},{115,85}}` with caret `{{88,229},{3,26}}`, and the custom fallback/block-stack
loupe at `{{37,207.5},{115,85}}` with caret `{{93,237},{3,26}}`. Both loupe-minus-caret center
vectors are exactly `{0,0}`. As a falsification check, returning the outer editor moved only the
custom loupe to `{{42,215.5},{115,85}}`; its vector became `{5,8}`, exactly the configured left/top
text-container inset. Therefore the explicit callback returns the already-existing block stack.
Construction preflight validates the object-return ABI before UIKit adopts the host; the callback
does not create or place a second selection container.

Unit coverage drives the recovered ABI only from test-target source, captures the scene with
`drawViewHierarchyInRect:afterScreenUpdates:`, and observes UIKit's exact runtime
`_UITextMagnifiedGlassLoupeView` for size, caret-relative offset, movement, and lifecycle. The UI
test remains the visible oracle: it captures baseline, held, moved, and ended full-screen images
during real XCU long-press/drag gestures and requires a loupe-sized changed component above the
touch.

## Task 8 geometry, scrolling, edit commands, and controller-owned undo

Hopper MCP remained available for this task. Address-level pseudo-code and callee queries were
used for the procedures below; the live iOS 26.5 (23F73) simulator then verified the aggregate
ABIs and the container-hosting state that is not visible in the open `UIKitCore` document.

| Address | Procedure | iOS 26.5 contract mirrored |
|---|---|---|
| `0x18aa019c4` | `-[UITextView firstRectForRange:]` | Direct `CGRect <- object` forwarding to the input controller. |
| `0x1896896b4` | `-[UITextView caretRectForPosition:]` | Direct `CGRect <- object` forwarding to the input controller. |
| `0x18968d5f8` | `-[UITextView selectionRectsForRange:]` | Direct object-array forwarding to the input controller. |
| `0x18968c438` | `-[_UITextKit2LayoutController selectionRectsForRange:fromView:forContainerPassingTest:]` | Enumerates each range's TextKit 2 segments and creates UIKit selection rects using the segment's text-container origin and the supplied view. |
| `0x18968ddf8` | `___48-[UITextInputController selectionRectsForRange:]_block_invoke` | Obtains each text container's `textView`, then calls `_shouldConsiderTextViewForGeometry:`; a container without its editor host is rejected. |
| `0x189688e04` | `-[UITextView textContainerOrigin]` | Returns the hosted layout view's text-container origin; the custom editor supplies its left/top `textContainerInset`. |
| `0x18aa009d0` | `-[UITextView scrollRangeToVisible:]` | Calls `_scrollRangeToVisible:animated:` using UIKit's current animation state. The public custom API keeps the active range edge visible and clamps against adjusted bottom inset. |
| `0x18aa01908` | `-[UITextView undoManager]` | Directly returns `UITextInputController.undoManager`; no editor-owned history is created. |
| `0x1896848f8` | `-[UITextInputController undoManager]` | Lazily creates `_UITextUndoManager`, sets the input controller, and installs its observer. |
| `0x18aa044b4` / `0x18aa04528` / `0x18aa04978` | `-[UITextView cut:]` / `copy:` / `paste:` | Cut and copy forward an `object -> void` sender to the input controller. Stock paste also forwards to the controller. |
| `0x18a9ecbb4` / `0x18a9ecc94` / `0x18a9ecc98` | `-[UITextInputController cut:]` / `copy:` / `paste:` | Cut copies, registers a controller undo operation, then deletes; copy writes the selection; paste enters `_pasteAndMatchStyle:`. |
| `0x18aa04d68` / `0x18aa04dac` | `-[UITextView select:]` / `selectAll:` | Uses the interaction assistant's `selectWord` and `selectAll:` operations. |
| `0x18aa04320` | `-[UITextView canPerformAction:withSender:]` | Gives the input controller first refusal through `_canHandleResponderAction:` and `_shouldHandleResponderAction:withSender:`, with view-level gates for remaining actions. |
| `0x18a9ea8c0` / `0x18a9eab08` | `-[UITextInputController _canHandleResponderAction:]` / `_shouldHandleResponderAction:withSender:` | Paste availability is controller-owned; the latter requires editing state and a pasteboard representation before allowing `paste:`. |
| `0x18937103c` | `-[UITextInputController _pasteController]` | Creates `UITextPasteController` only when the hosted view (or its superview) conforms to `UITextPasteConfigurationSupporting_Internal`. |
| `0x18a9ac4ec` | `-[UITextPasteController beginPastingItems:toRange:delegate:matchesTextStyles:]` | Pulls `_inputController` and `_implicitPasteConfigurationClasses` from the supporting view, then transforms item providers asynchronously. |
| `0x18a9edad8` | `-[UITextInputController _pasteRawAttributedString:asRichText:]` | Registers undo type 3 with the localized Paste action name, asks the delegate, then inserts through the controller. |
| `0x18aa058e0` | `-[UITextView keyboardInputShouldDelete:]` | Resolves `_rangesForBackwardsDelete`, calls the delegate with the union range, and gates public `cut:` before controller forwarding. |
| `0x18a70e91c` / `0x18a70e97c` | `-[UIWindow undo:]` / `redo:` | Obtains the window's first responder and sends undo/redo to that responder's undo manager. |
| `0x189615bcc` | `-[UITextView setTextContainerInset:]` | Updates layout state and asks the active interaction assistant for `setNeedsSelectionDisplayUpdate`. |
| `0x1896874d0` | `-[UITextView textInputDidChangeSelection:]` | Calls `textViewDidChangeSelection:` for every controller callback, then updates formatting state and scrolls the caret; no range or affinity deduplication occurs. |
| `0x189687548` | `-[UITextView _scrollToCaretIfNeeded]` | Reads the assistant's active selection, requires a caret, scrolling enabled, and editing, then compares its caret rect with bounds clipped by all four effective content insets before calling `scrollRectToVisible:animated:`. |
| `0x18a9fbbf4` | `___36-[UITextView _scrollToCaretIfNeeded]_block_invoke` | Lays out the canvas, obtains `activeSelection.caretRect`, gets `textInputView`, and converts that caret rect into editor coordinates. |
| `0x18aa01520` / `0x18a9e41dc` | `-[UITextView selectionAffinity]` / `-[UITextInputController selectionAffinity]` | The view directly returns the controller's integer `UITextStorageDirection`; the controller derives it from the selection end position and layout affinity. |
| `0x18a5bd7b4` / `0x18a5bf5ac` | `-[UITextInputController(UITextInput_Internal) _updateSelectionWithTextRange:withAffinityDownstream:]` / `_setSelectedTextRange:withAffinityDownstream:` | Private affinity-aware selection operations take `(object, BOOL)`, but iOS 26.5 provides no `UITextView` or `UITextInputController` implementation of public `setSelectionAffinity:`. They are not repurposed as an invented public setter. |
| `0x18a9fce6c` | `-[UITextView _convertPointFromRenderSpace:]` | Returns the point unchanged when `customRenderController` is nil; otherwise uses the custom renderer. |

The custom editor maps UIKit's `isEditing` branch to `isFirstResponder && isEditable`; it does not
invent the separate non-editing enclosing-scroller path. Its internal helper requires a collapsed
selection, `scrollEnabled`, current layout, and a finite caret, then tests containment against all
four adjusted content insets and scrolls the selection end (the active caret edge) without calling
the public `scrollRangeToVisible:` API. The helper runs after assistant/public selection notification,
matching `0x1896874d0`'s recovered order. iOS 26.5's input controller can expose its final insertion
caret only as its text-change callback settles, so mutation handling performs an idempotent
containment-gated reconciliation at the first post-mutation layout point and once at callback return;
neither pass emits delegate notifications. Navigation-only selection changes use the direct selection
callback path. Window-hosted tests cover both paths, bottom-inset containment, and callback counts.

After `UITextInputController` is created and nil-validated, the editor invokes a dedicated typed
bridge preflight for `_rangesForBackwardsDelete`. The bridge requires a non-nil result responding to
`unionRange` but intentionally does not call `unionRange`, so construction cannot perform a delete,
selection mutation, or undo registration. The action bridge retains its independent immediate guard.
Tests use an overridable construction probe to prove one live invocation, unchanged empty text and
selection, and no undo/redo history; a bridge aggregate probe proves zero `unionRange` calls.

One scrolling fidelity difference remains explicit: UIKit's recovered implementation forwards the
current animation state to `scrollRectToVisible:animated:` and preserves/restores scroll-animation
duration. The custom internal caret correction currently uses a synchronous nonanimated content
offset. Geometry, gating, callback order, and inset containment are mirrored; animation policy is not.

### Text-container host root cause and coordinate result

An independently created `NSTextContainer` initially had a nil private `textView`. Direct calls to
the TextKit 2 layout controller produced a finite first-line rect (`{{5,0},{29.33,24}}`), but the
input controller rejected that container in the block at `0x18968ddf8` and returned its
`{{inf,inf},{0,0}}` fallback. The bridge now performs the live `object <- object` association
`setTextView:` before constructing the private layout controller. The iOS 26.5 runtime requires
that selector and synchronously calls the hosted editor's `setTextContainer:`,
`invalidateTextContainerOrigin`, and later `textContainerOrigin`; those definitions live only in
the `PrivateUIKit` callback category. The reciprocal setter validates identity with an always-on
`NSInternalInconsistencyException` and does not replace storage, so release builds cannot acquire a
competing owner or recurse.

After this binding, live controller caret, first-rect, and selection-rect results are finite and
already expressed in editor coordinates. `IDTextView` therefore matches the three direct Hopper
forwarders and does not convert or wrap selection rects. The earlier apparent canvas-local caret
was a consequence of the missing host association, not the stable UIKit contract.

`NSTextContainer -setTextView:` is mandatory in the simulator compatibility table. Its
implementation is outside the open `UIKitCore` Hopper document (no procedure address was
available there), so the exact selector/ABI and reciprocal callbacks were recorded from the live
runtime rather than assigned an invented address.

### Commands, asynchronous paste support, and undo ownership

Copy and cut use specific typed bridge functions and the recovered input-controller commands.
Select and select-all use specific interaction-assistant bridge functions. A nil custom render
controller makes `_convertPointFromRenderSpace:` an identity operation, exactly as recovered at
`0x18a9fce6c`.

The first direct controller paste attempt stopped at a nil `_pasteController`. Hopper at
`0x18937103c` exposed the missing composition rule: the hosted view must conform to the private
`UITextPasteConfigurationSupporting_Internal` protocol. `IDPrivateUIKit` now validates and installs
that protocol, while private `_inputController` and `_implicitPasteConfigurationClasses` callbacks
remain in the private callback category. With that graph in place, the window-attached iOS 26.5
test follows the real asynchronous item-provider path, restores smart-cut whitespace, emits the
delegate/selection/change sequence, and produces the controller-owned localized Paste undo action.
There is no pasteboard-string fallback.

Paste menu gating uses the recovered typed `_canHandleResponderAction:` and
`_shouldHandleResponderAction:withSender:` bridge plus the view's editable gate. Cut first mirrors
`keyboardInputShouldDelete:` so the delegate receives the smart-delete union range before the
controller performs its two distinct selection transitions.

`IDTextView.undoManager` directly returns the controller's lazy `_UITextUndoManager`. Live tests
verify insertion undo and redo, and no `NSUndoManager` registration occurs in the editor layer.
Window responder-chain tests additionally exercise `UIWindow undo:` and `redo:` and verify the
controller's exact public notification order. The view publishes every selection callback exactly
as stock UIKit does, including repeated endpoint ranges during undo/redo and marked text. This is
required because affinity, direction, and marked state can change without changing public range
endpoints. The optional `selectionAffinity` getter uses a specific typed controller bridge and is
verified at a live wrap boundary.

## iOS 26.5 `_UITextLayoutCanvasView` composition

| Address | Procedure | Recovered responsibility |
|---|---|---|
| `0x18936e7f4` | `-[_UITextKit2LayoutController dequeueCanvasViewForTextContainer:]` | Look up the controller's map at offset `0x50`; create/store a canvas on miss |
| `0x18936e894` | `-[_UITextLayoutCanvasView initWithTextLayoutManager:textContainer:]` | Bind layout manager/container, adopt viewport controller delegate, create bookkeeping |
| `0x1894ccdb4` | `-[_UITextLayoutCanvasView layoutSubviews]` | Perform viewport layout and update custom-renderer scale |
| `0x1894ccf88` | `-[_UITextLayoutCanvasView _performViewportLayout:]` | Reentrancy guard and ordered will/layout/did transaction |
| `0x1894cd1e0` | `-[_UITextLayoutCanvasView _viewportWillLayout]` | Mark mapped fragments and external surfaces unused; begin custom layout |
| `0x1894cd398` | `-[_UITextLayoutCanvasView viewportBoundsForTextViewportLayoutController:]` | Convert visible scroll bounds into canvas coordinates |
| `0x1894cd524` | `-[_UITextLayoutCanvasView textViewportLayoutController:presentationLayoutFragmentFrameForTextLayoutFragment:proposedOrigin:]` | Resolve presentation fragment geometry |
| `0x1894cd7d4` | `-[_UITextLayoutCanvasView textViewportLayoutController:renderingSurfaceForTextLayoutFragment:]` | Keyed fragment-surface reuse/creation |
| `0x1894cd944` | `-[_UITextLayoutCanvasView textViewportLayoutController:configureRenderingSurfaceForTextLayoutFragment:]` | Configure geometry, z-order, renderer callback, and attachments |
| `0x1894ce21c` | `-[_UITextLayoutCanvasView _viewportDidLayout]` | Remove stale elements, finish renderer, redraw, reconcile content/attachments/context |
| `0x1894ce5ec` | `-[_UITextLayoutCanvasView updateContentSizeIfNeeded]` | Publish changed TextKit content extent and flush selection navigation cache |
| `0x1894ced54` | `-[_UITextLayoutCanvasView textViewportLayoutControllerWillLayout:]` | Enter externally initiated viewport transaction |
| `0x1894cef74` | `-[_UITextLayoutCanvasView textViewportLayoutControllerDidLayout:]` | Leave externally initiated viewport transaction |
| `0x1894cf038` | `-[_UITextLayoutCanvasView _removeUnusedElementViews]` | Teardown and remove still-unused fragment surfaces |
| `0x18961df44` | `-[_UITextLayoutCanvasView textViewportLayoutController:addRenderingSurface:group:placement:]` | Place and track non-fragment rendering surfaces |
| `0x18961e550` | `-[_UITextLayoutCanvasView setNeedsDisplayInRect:]` | Invalidate intersecting mapped surface frames |
| `0x18979f6ac` | `-[_UITextLayoutCanvasView flushElementViews]` | Mark all fragment keys unused and teardown all mapped views |
| `0x18a217b3c` | `-[_UITextLayoutCanvasView invalidateTemporaryAttributesInRange:]` | Capability-gated custom-renderer invalidation; native path redraws through fragment layout |
| `0x1895e4bdc` | `-[_UITextLayoutFragmentViewBase initWithLayoutFragment:containerOrigin:containerSize:clipRect:]` | Store fragment geometry and update frame/bounds |
| `0x1894cddec` | `-[_UITextLayoutFragmentViewBase _updateGeometry]` | Pixel-integralize/intersect rendering surface geometry |
| `0x1894ce140` | `-[_UITextLayoutFragmentViewBase enumerateTextAttachmentViewsUsingBlock:]` | Enumerate provider views and fragment-relative frames |
| `0x1895e46fc` | `-[_UITextLayoutFragmentViewBase teardown]` | Clear fragment/attachment state before removal |
| `0x1895e4f64` | `-[_UITextLayoutFragmentViewBase _updateTextAttachmentGeometry]` | Place provider views inside the surface |
| `0x189617ac4` | `-[_UITextLayoutFragmentView drawRect:]` | Draw native fragment through TextKit 2 |
| `0x189198430` | `-[_UIKeyboardStateManager setAutocorrectSpellingEnabled:]` | Derive continuous-spelling preference and notify input delegate manager |
| `0x189198560` | `-[UIKBInputDelegateManager setContinuousSpellCheckingEnabled:]` | Send private spelling setter to the key input delegate |
| `0x1897f1584` | `-[UITextView setContinuousSpellCheckingEnabled:]` | Forward enablement to `UITextInputController` |
| `0x1896ec6fc` | `-[UITextInputController setContinuousSpellCheckingEnabled:]` | Store checking state |
| `0x18aa1dad8` | `-[UITextCheckingController checkSpellingForSelectionChangeFromRange:]` | Check the departed word |
| `0x18aa1b698` | spelling word-check procedure | Add private spelling annotation to annotated substring |
| `0x18a9f091c` | `-[UITextInputController replaceRange:withAnnotatedString:relativeReplacementRange:]` | Convert annotations to rendering attributes |
| `0x18a23c81c` | `-[_UITextKit2LayoutController addRenderingAttributes:forRange:]` | Add TextKit 2 temporary attributes |
| `0x18a23c3f4` | `-[_UITextKit2LayoutController _invalidateTemporaryAttributesInRange:]` | Broadcast invalidation to registered canvases |

### Spelling annotation-to-surface path

The device-VM entries above form one continuous recovered pipeline. Keyboard state derives the
continuous-spelling preference, `UITextInputController` stores it, `UITextCheckingController`
checks the word departed by the selection and adds a private spelling annotation, annotated
replacement converts that annotation into rendering attributes, and the TextKit 2 layout controller
stores temporary rendering attributes then broadcasts invalidation to every canvas registered in
its text-container map. The native branch of the canvas invalidation callback does not manufacture
an underline: its visible fragment surfaces redraw and `NSTextLayoutFragment` renders the marker.
The checker path is asynchronous. On a cold service, the first departed word may remain unannotated;
subsequent departed words are checked after the service becomes ready. The mirror does not insert a
synthetic result to conceal that native behavior.

### Continuous-spelling cold-checker lifecycle

The August 7 stock-only lifecycle trace recovered and then observed the exact
cold-start boundary:

| File-relative address | Procedure | Recovered responsibility |
|---|---|---|
| `0x16367f8` | `-[UITextCheckingController didChangeSelectionFromRange:]` | Convert the previous text range to `NSRange` and schedule selection-change spelling |
| `0x163627c` | `-[UITextCheckingController checkSpellingForSelectionChangeFromRange:]` | Resolve the departed word and call the word checker |
| `0x16338dc` | `-[UITextCheckingController textChecker]` | Lazily allocate `UITextChecker` with `_initWithAsynchronousLoading:YES`; return `nil` until `_doneLoading` |
| `0x1633940` | `-[UITextCheckingController preheatTextChecker]` | Start the same asynchronous allocation without waiting; not used by the InputDec observer |
| `0x1633f40` | `-[UITextCheckingController checkSpellingForWordInRange:]` | Return immediately when `textChecker` is nil; otherwise check and write the style-2 annotation |
| `0x162d608` | `+[UITextChecker keyboardLanguages]` | Derive checking languages from the shared input-mode controller and dictation languages |

`checkSpellingForWordInRange:` contains no retry when the asynchronous checker
is unavailable. Merely waiting after the first request cannot produce an
annotation; another departed-word selection change is required.

The live-only stock trace in
`.spelling-lifecycle-notification-green.xcresult` observed:

- one-shot `mispelled `: `didChangeSelectionFromRange:` → selection check →
  word check → `textChecker == nil`; no keyboard-language call and no temporary
  rendering attributes;
- staged departed words: the checker was ready, `keyboardLanguages` returned
  `en_US`, and temporary attributes covered `{0,9}` and `{10,4}`;
- `UITextInputController endSelectionChange` was not sent by these
  programmatic insertions, but the checking-controller notification path was,
  so that method is not a required scheduling boundary for this stimulus.

Simulator file-relative confirmation used for the final mirror:

| File-relative offset | Procedure | Recovered responsibility |
|---|---|---|
| `0xc3e9d8` | `-[_UITextKit2LayoutController _invalidateTemporaryAttributesInRange:]` | Enumerate all registered canvases and forward the original range adapter |
| `0xc0a360` / `0xc0a42c` | `-[_UITextLayoutCanvasView invalidateTemporaryAttributesInRange:]` / range block | Native no-op branch; capable custom renderer expands `textKit2Ranges`, otherwise requests full display |
| `0x15fc750` / `0x15fc758` | `-[UITextInputController continuousSpellCheckingEnabled]` / setter | Exact BOOL load/store ABI |
| `0x1616e84` | `-[UITextView setContinuousSpellCheckingEnabled:]` | Forward enablement to the input controller |
| `0xbe63ac` | `-[UIKBInputDelegateManager setContinuousSpellCheckingEnabled:]` path | Capability-check and forward to the key-input delegate |

### Task 5 composition and attachment lifecycle (simulator file-relative)

| File-relative offset | Procedure | Recovered responsibility |
|---|---|---|
| `0xc09ffc` | `-[_UITextLayoutCanvasView textViewportLayoutController:addRenderingSurface:group:placement:]` | Enforce two groups/two placements, z-order external surfaces, apply flexible sizing, and mark autoresizing hosts as layout-engine hosts |
| `0xc06e70` | `-[_UITextLayoutCanvasView setSelectionContainerView:]` | Replace the selection host and schedule layout |
| `0xc06ef4` / `0xc070e8` | `setTextEmphasisBackgroundView:withTextView:` / updater block | Install the weak platform updater with ABI `(viewportController, textRange, CGRect)` |
| `0xc0718c` / `0xc07598` | `_updateRenderingSurfaceViewsForTextRange:inTextView:bounds:` / attribute block | Convert range, enumerate `NSTextHighlightStyleAttributeName`, position/show the emphasis surface, or hide a previously hosted surface |
| `0xc075b4` | anchored-fragment update block | Intersect anchored bounds with the viewport and refresh the keyed anchored surface |
| `0xc07820` | `frameForAnchoredTextAttachment:associatedLayoutFragment:` | Convert through an existing fragment surface or use text-container-origin plus fragment-frame fallback |
| `0xd0692c` / `0xd069f4` / `0xd06b9c` | anchored wrapper init/layout/draw | Retain weak associations, consume the fragment's provider, fill the wrapper, or route drawing back to the fragment |
| `0xd0688c` / `0x5bed74` | anchored/native `isLayoutFragmentView` | Return NO for anchored wrappers and YES for ordinary fragment surfaces |
| `0x5bf3f0` | native fragment-surface attachment enumeration | Consume `layoutFragment.textAttachmentViewProviders` and fragment-relative frames |
| `0x5bf594` / `0x5bf60c` | hosted layout / `didMoveToSuperview` | Refresh attachment geometry while hosted; defer and consume one pending refresh while detached |
| `0xc07934` / `0xc0825c` | `_viewportWillLayout` / `_viewportDidLayout` | Mark surfaces unused and begin rendering; then remove stale elements, finish display, update content, diff attachments, and notify the host |
| `0xc0810c` / `0xc07ad4` | `_removeUnusedElementViews` / `flushElementViews` | Teardown stale keyed surfaces or flush all element views |
| `0xc08f70` | `layoutSubviews` | Drive viewport layout and composition updates |
| `0xc09174` / `0xc09150` | `requestHoverEffectsUpdate` / `isEditingDidChange` | Schedule optional hover layout on hover/editing changes |
| `0xc06d28` / `0xc07e0c` | `observeEnclosingScrollView` / `_traitsChanged` | Forward scroll-host and display-scale lifecycle changes |
| `0xc0a7a0` / `0xc0a7b0` | Writing Tools animated-layout getter/setter | Retain and return the opaque animated-layout state |
| `0x1443e24` | `+[_UITextLayoutControllerBase layoutControllerWithTextView:textContainer:]` | Choose TextKit 2 for a container with an `NSTextLayoutManager` |
| `0xc3b5d4` / `0xc3b440` | two-/three-argument TextKit 2 initializers | Adopt an existing manager and canvas map, or construct the native text-view graph |
| `0x16083bc` | `-[UITextView _configureWithTextContainer:layoutManager:textLayoutManagerEnabled:]` | Establish native controller/canvas/selection/emphasis construction ordering |

The nil-emphasis branch at `0xc06ef4` asks the content manager whether it
`supportsAnchoredTextAttachments`. A false result branches at `0xc06f8c` and clears the updater at
`0xc07044..0xc07054`; a true result preserves it so anchored servicing can continue. The mirror
uses the same condition and does not retain a stale weak host when the updater is cleared.

### Direct-fragment-rendering marker removal

The `isLayoutFragmentView` message-send stub is at file-relative
`0x222bd80`. It has exactly two UIKitCore xrefs:

| Call site | Caller | Recovered responsibility |
|---|---|---|
| `0xc081c4` | `-[_UITextLayoutCanvasView _removeUnusedElementViews]` | Query a stale keyed view; call `teardown` only when the marker returns true, then remove the view and map entry |
| `0xc083e8` | `-[_UITextLayoutCanvasView _viewportDidLayout]` | Query each realized keyed view; call `setNeedsDisplay` only when the marker returns true |

The ordinary native implementation is
`-[_UITextLayoutFragmentViewBase isLayoutFragmentView]` at `0x5bed74` and
returns true. The paragraph-anchored wrapper implementation is
`-[_UITextParagraphAnchoredAttachmentView isLayoutFragmentView]` at
`0xd0688c` and returns false.

InputDec does not execute either concrete `_UITextLayoutCanvasView` caller.
Its recovered incoming `_removeUnusedElementViews` and `_viewportDidLayout`
callbacks forward to the project-owned `id_removeUnusedElementViews` and
`id_viewportDidLayout` methods. Those methods own the keyed fragment-surface
map and directly send `teardown` or `setNeedsDisplay`; neither queries the
private marker. The marker therefore provides no behavior to either the
reference or minimal InputDec backend and can be removed instead of moved to
a reference adapter.

### UIFoundation iOS 26.5 provider gate (file-relative)

At UIFoundation file-relative `0xbab30`, `-[NSTextAttachment setFileType:]` resolves the identifier
through `UTType typeWithIdentifier:`. An undeclared identifier therefore becomes nil even when a
provider class has been registered globally, and the attachment's instance provider-class lookup
cannot pass. The demo exports exactly `com.inputdec.demo.attachment` and
`com.inputdec.demo.interaction-attachment`, both conforming to `public.data`; those declarations let
UIFoundation's real gate produce provider instances for both stock and custom editors. The canvas
only consumes providers returned on layout fragments. It does not register or construct a private
provider. No procedure address was retained for the downstream provider factory calls, so none is
invented here.

### Task 6 measured parity fixes (simulator file-relative)

| File-relative offset | Procedure | Recovered responsibility |
|---|---|---|
| `0xc0962c` | `textViewportLayoutController:renderingSurfaceForTextLayoutFragment:` | Obtain `textContainerOrigin`, container size, and `_clipRectForFadedEdges` from the context and pass them to surface initialization |
| `0xc09a24` | `textViewportLayoutController:configureRenderingSurfaceForTextLayoutFragment:` | Re-read `_clipRectForFadedEdges` for each configuration transaction |
| `0x1624eec` | `-[_UITextContainerView textContainerUsageDidChangeToSize:]` | Add text-container insets before forwarding the constrained frame size |
| `0x16243c0` | `-[_UITextContainerView setConstrainedFrameSize:]` | Apply ARM64 `frintp` positive-infinity rounding on enabled axes before applying the frame |

These procedures resolved the only measured Task 6 divergences: the custom canvas now returns
`CGRectNull` for its no-faded-edge state instead of clipping surfaces to its bounds, and the final
inset-inclusive content height is rounded upward. Seven stock-reference tests then matched visible
surface count/geometry, pre/post-scroll surfaces, overflow content size, fixed-offset caret,
two-line selection rects/flags, native spelling pixels/removal, and attachment provider frames.

## Floating-cursor stock contract (iOS 26.5 simulator, 23F73)

These are file-relative offsets in the currently loaded simulator `UIKitCore` Hopper document.
They are intentionally distinct from the older device VM addresses near the top of this ledger.
Hopper pseudo-code was checked together with each procedure's callee list; aggregate ABIs below
use the SDK types rather than Hopper's occasionally lossy inferred names.

| File offset | Class / selector | Exact ABI | Input space | Output space | Order / state transition | Evidence |
|---|---|---|---|---|---|---|
| `0x1613e0c` | `-[UITextView beginFloatingCursorAtPoint:]` | `void <- CGPoint` | hosted `textInputView` coordinate supplied to the text view | unchanged assistant input | obtains `interactionAssistant`, forwards begin, then releases it | Hopper pseudo/assembly plus existing ledger |
| `0x1613e54` | `-[UITextView updateFloatingCursorAtPoint:]` | `void <- CGPoint` | hosted `textInputView` | unchanged assistant input | forwards the unanimated update | Hopper pseudo and callee list |
| `0x1613e9c` | `-[UITextView updateFloatingCursorAtPoint:animated:]` | `void <- CGPoint, BOOL` | hosted `textInputView` | unchanged assistant input | forwards point and animation policy | Hopper pseudo and callee list |
| `0x1613ef4` | `-[UITextView endFloatingCursor]` | `void <- no arguments` | current text-view session | assistant session state | obtains assistant, forwards normal end, releases assistant | Hopper pseudo and callee list |
| `0x1569a7c` | `-[UITextInteractionAssistant beginFloatingCursorAtPoint:]` | `void <- CGPoint` | hosted `textInputView` | session/controller space identified by callee trace | starts assistant floating-cursor session; expand every callee below this row | Hopper pseudo/assembly plus existing ledger |
| `0xc6eb04` | `-[UITextSelectionDisplayInteraction _beginFloatingCursorSessionAtPoint:inContainer:]` | `object <- CGPoint, object` | point plus hosted `textInputView` coordinate space | selection-container session space | invalidates a prior session, creates `_UITextFloatingCursorSession`, stores it, performs its first animated update, and returns it | Hopper pseudo and callee list |
| `0xa49d00` | `-[_UITextFloatingCursorSession updateWithPoint:inContainer:animated:]` | `void <- CGPoint, object, BOOL` | supplied container coordinate space | native selection-container space | converts once through `_selectionContainerView`, clamps/resolves the cursor position, retargets or springs the native view, then updates faded visibility | Hopper pseudo and callee list |
| `0xa4a264` | `-[_UITextFloatingCursorSession floatingCursorPositionForPoint:lineSnapping:]` | `CGPoint <- CGPoint, BOOL` | selection-container space | clamped selection-container cursor position | obtains `selectionClipRect`/`_selectionClipRect`, falls back to `textInputView.bounds`, converts the clip rect, clamps the point, and optionally accounts for the cursor frame | Hopper pseudo and callee list |
| `0xa4a16c` | `-[_UITextFloatingCursorSession _updateCursorFadedHiddenForFloatingCursorAtPoint:]` | `void <- CGPoint` | selection-container point | cursor presentation state | compares the point with the real cursor frame (15-point x and 30-point y thresholds) and updates faded-hidden state animated | Hopper pseudo and ARM64 floating comparisons |
| `0xc6f5fc` | `-[UITextSelectionDisplayInteraction _setCursorFadedHiddenForFloatingCursor:animated:]` | `void <- BOOL, BOOL` | presentation state | managed cursor views | changes state only when needed; animates or immediately lays out managed subviews | Hopper pseudo and callee list |
| `0x1569ba4` | `-[UITextInteractionAssistant updateFloatingCursorAtPoint:animated:]` | `void <- CGPoint, BOOL` | hosted `textInputView` | modern session space or legacy selection-view space | modern branch updates the retained session in its container; legacy branch converts into selection-view space; both then call `startAutoscroll:` | Hopper pseudo and callee list |
| `0x157dcc8` | `-[UITextSelectionView beginFloatingCursorAtPoint:]` | `void <- CGPoint` | legacy selection-view input | legacy floating-caret presentation | requires a selected range, hides commands/caret, acquires a nonblinking assertion, creates the floating caret, chooses direct versus indirect presentation, then performs the first update | Hopper pseudo and callee list |
| `0x157dec0` | `-[UITextSelectionView floatingCursorPositionForPoint:lineSnapping:]` | `CGPoint <- CGPoint, BOOL` | legacy selection-view input | clamped legacy floating-caret space | reads `_selectionClipRect`/`selectionClipRect` or hosted bounds, converts once, clamps, and optionally accounts for the caret frame | Hopper pseudo and callee list |
| `0x157e1dc` | `-[UITextSelectionView updateFloatingCursorAtPoint:animated:]` | `void <- CGPoint, BOOL` | legacy selection-view input | floating-caret layer position and visible caret state | resolves the clamped point; either toggles ghost-caret visibility near the real cursor or moves the floating-caret layer, respecting animation policy | Hopper pseudo and callee list |
| `0x1567cf8` | `-[UITextInteractionAssistant setSelectionWithPoint:]` | `void <- CGPoint` | hosted selection point | active-selection controller space | for editable or editable-selection state, forwards a collapsed selection point and resets granularity | Hopper pseudo and callee list |
| `0x1567e78` | `-[UITextInteractionAssistant extendSelectionToPoint:]` | `void <- CGPoint` | hosted selection point | active-selection controller space | for editable or editable-selection state, forwards extension and resets granularity | Hopper pseudo and callee list |
| `0x1567f0c` | `-[UITextInteractionAssistant extendSelectionToLoupeOrSetToPoint:]` | `void <- CGPoint` | hosted selection point | active-selection controller space | restores the saved range and extends while the loupe gesture is active; otherwise collapses through `setSelectionWithPoint:` | Hopper pseudo and callee list |
| `0x1576660` | `-[UITextSelection updateBaseAndInitialExtent]` | `void <- no arguments` | current selection rectangles in document space | canonical position/range anchors | resolves start/end edge midpoints with `closestPositionToPoint:`, stores an empty range as fixed base and another as initial extent | Hopper pseudo and callee list |
| `0x1576d44` | `-[UITextSelection setRangedSelectionExtentPoint:baseIsStart:allowFlipping:]` | `BOOL <- CGPoint, BOOL, BOOL` | document/text-input-view point plus endpoint-role flags | canonical selected range | resolves the moving extent, compares it with base endpoints, uses the fixed base/initial extent, and calls the bounded-or-inverted helper so crossing may flip roles only when allowed | Hopper pseudo and callee list |
| `0x1569e88` | `-[UITextInteractionAssistant startAutoscroll:]` | `void <- CGPoint` | hosted `textInputView` point | scroll-view/field-editor space and stored untransformed extent | gates on `_canAutoscroll`, marks the scroll owner active, converts/stores the extent once, then starts native text, BE, or async-client autoscroll | Hopper pseudo and callee list |
| `0x156a160` | `-[UITextInteractionAssistant updateAutoscroll:]` | `void <- object` | native autoscroll tick plus stored hosted extent | scroll content offset, then active-selection space | computes edge direction/distance, updates the native scroll view, converts the stored extent after scrolling, then chooses collapsed `setSelectionWithPoint:` plus `commit` versus ranged `updateSelectionWithPoint:`; cancels when no direction remains | Hopper pseudo and callee list |
| `0x156a020` | `-[UITextInteractionAssistant cancelAutoscroll]` | `void <- no arguments` | current assistant/scroll state | stopped native scroll state | clears scroll-view autoscrolling and cancels the native text, BE, or async-client autoscroll owner | Hopper pseudo and callee list |
| `0x1569e3c` | `-[UITextInteractionAssistant endFloatingCursor]` | `void <- no arguments` | current assistant session | ordinary caret/selection presentation | normal end first cancels autoscroll, then invalidates and releases the modern session or ends the legacy floating caret, and finally clears `inGesture` | Hopper pseudo and callee list |
| `0xa4a0f4` | `-[_UITextFloatingCursorSession _invalidate]` | `void <- no arguments` | active modern session | invalidating session | delegates to `_invalidateAnimated:YES` | Hopper pseudo and callee list |
| `0xa49e94` | `-[_UITextFloatingCursorSession _invalidateAnimated:]` | `void <- BOOL` | active modern session | inactive native cursor presentation | marks the session inactive before either spring-restoring the cursor view or running cleanup immediately | Hopper pseudo and callee list |
| `0x157e84c` | `-[UITextSelectionView endFloatingCursor]` | `void <- no arguments` | active legacy floating caret | ordinary caret presentation | drops the blink assertion, animates the floating caret back to the real caret when hosted (otherwise removes it), then ends floating-caret state | Hopper pseudo and callee list |
| `0x15690a4` | `-[UITextInteractionAssistant rangeSelectionCanceled]` | `void <- no arguments` | active legacy range-selection state | ended selection interaction | clears forced-range/magnifying state, ends the selection change, then announces interaction end | Hopper pseudo and callee list |
| `0x156ce34` | `-[UITextInteractionAssistant textRangeAdjustmentInteractionWasCancelled:]` | `void <- object` | cancelled range-adjustment interaction | ended selection and stopped autoscroll | ends selection change, announces interaction end, then cancels autoscroll | Hopper pseudo and callee list |
| `0x15694a0` | `-[UITextInteractionAssistant resignedFirstResponder]` | `void <- no arguments` | direct assistant callers, not `UITextView` resign | hidden, inactive selection presentation | the selector exists, but later `UITextView` call-graph recovery proves it is not on the editor's resign path | Hopper pseudo and later `0x160fdfc` / `0x160fccc` caller trace |
| `live-runtime-only; no file offset recovered` | distinct keyboard floating-cursor cancellation callback | `unknown; no callable selector recovered` | system keyboard session | assistant/responder lifecycle | no distinct cancel callback was recovered; later lifecycle tests must measure whether dismissal arrives solely through responder loss rather than inventing an address or ABI | live runtime ledger plus negative Hopper procedure search |

The modern begin/update path never asks the editor to render a floating cursor. UIKit owns the
session, selection-container conversion, cursor view, animation, and autoscroll object. At an
autoscroll tick, an empty selected range is the cursor branch; a nonempty selected range is the
selection-extension branch. `UITextSelection` owns the fixed base, moving extent, comparisons,
inversion, and optional endpoint flipping. Normal end and the two recovered cancellation paths are
separate transitions; responder loss handles visible teardown, while no distinct keyboard-dismissal
floating-cursor selector or ABI was recovered from this image.

### Floating-cursor cancellation and lifecycle cleanup (Task 6)

The final lifecycle pass expanded the address-backed trace through destruction. Normal end remains
`-[UITextInteractionAssistant endFloatingCursor]` at `0x1569e3c`: cancel native autoscroll,
invalidate/release the modern session through `0xa4a0f4` / `0xa49e94`, then clear `inGesture`.
Responder loss follows `UITextView resignFirstResponder` at `0x160fdfc` into
`_cleanUpForResignFirstResponder` at `0x160fccc`; it never calls assistant
`resignedFirstResponder`. This later call-graph recovery supersedes the early ledger attribution to
the existing assistant selector at `0x15694a0`. Cleanup orders selection-visible NO, assistant
deactivation, gesture refresh, and input-controller did-end. The zero-delay display update chain is
`deactivateSelection` at `0x1564e08` → display `setActivated:NO` at `0xc6de0c` →
`setNeedsSelectionUpdate` at `0xc6b690` → update clearing the active display-session slot `+0x88`
at `0xc6db70..94`. Interruption is not implemented by sending normal end. Graph destruction uses `-[UITextInteractionAssistant detach:]`
at `0x156563c` with `YES`, which removes installed interactions and reaches forced
`clearGestureRecognizers:YES` at `0x1565d8c` even while `inGesture` is true. Private sends and ABI
knowledge are confined to `IDPrivateUIKit`; preflight rejects a wrong responder-cleanup return type
and a same-sized non-`BOOL` detach argument before either typed send.

Pinned stock and custom lifecycle observations on iPhone 17 Pro simulator
`404DA68C-E273-46A5-8F6C-B3BF556B80D6`, iOS 26.5 (`23F73`):

| Termination | Stock pre-state | Immediate result | 500 ms settled result |
|---|---|---|---|
| normal lift | focused, keyboard visible, held collapsed cursor | focused; cursor commits; container stable | same selection/offset; no delayed mutation |
| explicit in-gesture cancel | no distinct keyboard floating-cancel selector or callable ABI recovered | not invented or sent | no explicit-cancel test added |
| resign / keyboard dismissal | focused live hold | responder false; selection freezes | keyboard absent; same selection; stable container |
| window detach | focused stock programmatic hold | window nil and responder false | selection unchanged |
| editable YES -> NO | focused stock hold | editable false and responder false | selectable remains true; selection unchanged |
| selectable YES -> NO | focused stock hold | selectable/editable/responder false; gestures 29 -> 14 | assistant getter nil; selection unchanged |
| release attempt after normal end | ended graph, assistant session cleared | host/root/window replaced and keyboard ownership handed off | weak editor/assistant/container/inactive-autoscroll references remain; session is nil |
| release attempt after interruption | force-detached graph with invalid session | host/root/window replaced and keyboard ownership handed off | weak editor/assistant/container/inactive-autoscroll/session references remain |

The paired real-HID interruption oracle uses one record containing two simultaneous paths:
a physical spacebar long-press held until 2.70 seconds and a stock/custom lifecycle-control press at
1.05--1.15 seconds. Immediate and 500 ms settled status plus screenshots are captured before the
keyboard-path lift, followed by a final quiesced status 500 ms after terminal lift. Responder loss, keyboard dismissal, editable-off, and selectable-off use the
same measured screen coordinates for stock then custom, retain matching selections in every phase,
produce responder flags `YES/YES/NO/NO/NO`, preserve the real observed presentation-container
identity, require no retained session or live autoscroll timer, and show no post-lift selection or presentation
mutation. A timing mutation that moves action-up to 2.80 seconds is rejected,
so a post-lift interruption cannot satisfy the live proof. Evidence is retained in
`.derivedData-floating-task6-green-authoritative-4/Result.xcresult`; the mutation RED is
`.derivedData-floating-task6-timing-mutation-red/Result.xcresult`.

### Floating-cursor viewport scrolling and publication (Task 5)

The tall `floating-scroll` live trace confirmed the recovered iOS 26.5 order without adding an
editor-owned scrolling mechanism. `-[UITextInteractionAssistant updateFloatingCursorAtPoint:animated:]`
at `0x1569ba4` starts native autoscroll after updating the session. Each
`-[UITextInteractionAssistant updateAutoscroll:]` tick at `0x156a160` first changes the native
scroll offset, converts the stored hosted extent in the new viewport, and only then publishes the
collapsed or ranged selection. Normal `endFloatingCursor` at `0x1569e3c` cancels that owner before
invalidating the session.

The real custom scroll/layout path retains the five-stage publication boundary recovered for
touch-selection autoscroll: content offset, completed block layout, visible rectangle, assistant
selection-display invalidation, and one coalesced backend presentation snapshot. The recording
backend observes exactly `offset -> layout -> visible -> interaction -> presentation`; that one
snapshot contains the new offset, visible rectangle, and current block origins. Canonical selection
is unchanged by viewport-only layout, and the stable presentation container remains a single
instance.

Pinned iPhone 17 Pro simulator traces (iOS 26.5 build 23F73) use one exact stock/custom keyboard
path per direction and mode. Sampling begins before HID synthesis, retains every parsed status after
the first directional movement (including plateaus), and captures the held screenshot before lift.
Both upper and lower cursor and selection-extension cases show monotonic offset/active-endpoint
movement, strict first-to-last progress, a fixed opposite endpoint in selection mode, identical
stock/custom final canonical outcomes, and no selection or offset change during the 500 ms
post-lift quiescence window. Direct tall-document geometry at canonical offset 900 independently
matches stock caret and content height; fixture readiness is published only after focus-triggered
layout has placed the caret at the requested physical edge.

## Clean-room rich layout controller contract

| File-relative address | Procedure | Required layout-controller behavior |
|---|---|---|
| `0x15e57bc` | `-[UITextInputController initWithTextLayoutController:]` | Reads `textStorage`, `beginningOfDocument`, and `emptyTextRangeAtPosition:`; observes that storage |
| `0x15e5ab0` | `-[UITextInputController setTextLayoutController:]` | Sends detach/adopt; queries `canAccessLayoutManager`; conditionally reads `layoutManager` |
| `0x15e7fe4` | `-[UITextInputController _insertText:fromKeyboard:]` | Mutates canonical storage and rebuilds selection through range conversion selectors |
| `0x15ed1e8` | attributed replacement implementation | Mutates canonical storage, converts ranges, updates selection, and notifies delegate |
| `0x15ede9c` | marked-text implementation | Mutates canonical storage and calls `invalidateDisplayForCharacterRange:` |
| `0x15ebb48` | `-[UITextInputController selectionRectsForRange:]` | Requests container-filtered layout-controller selection rectangles |
| `0x15f089c` | `-[UITextInputController caretRectForPosition:]` | Resolves position/container and requests insertion geometry |
| `0x1565428` | `-[UITextInteractionAssistant activeSelectionController]` | Builds the selection controller around the hosted input view |
| `0x1569a7c` | `-[UITextInteractionAssistant beginFloatingCursorAtPoint:]` | Starts floating cursor in `view.textInputView` coordinates |
| `0x156cf7c` | `-[UITextInteractionAssistant selectionContainerView]` | Obtains native selection-display container from the host |

```text
textStorage
beginningOfDocument
endOfDocument
emptyTextRangeAtPosition:
textRangeFromPosition:toPosition:
positionFromPosition:offset:
positionFromPosition:offset:affinity:
comparePosition:toPosition:
offsetFromPosition:toPosition:
affinityForPosition:
characterRangeForTextRange:
characterRangeForTextRange:clippedToDocument:
characterRangesForTextRange:clippedToDocument:
textRangeForCharacterRange:
textRangeForCharacterRanges:
positionWithOffset:affinity:
adoptTextInputController:
detachFromTextInputController
canAccessLayoutManager
invalidateDisplayForCharacterRange:
```

## Return–Backspace spelling-marker geometry callback

The iOS 26.5 (`23F73`) simulator UIKitCore file-relative procedures establish
the delete-time spelling cleanup contract:

| File-relative address | Procedure / instruction | Recovered responsibility |
| --- | --- | --- |
| `0x15eb4e0` | `-[UITextInputController removeSpellingMarkersFromWordInRange:]` | Read style-2 annotation, remove it, request its character-range bounds, and invalidate the text input view |
| `0x15eb5ac` | `removeAnnotationAttribute:forRange:` send | Remove `NSTextAlternativesDisplayStyleAttributeName` from the word range |
| `0x15eb5c8` | `boundingRectForCharacterRange:` send | Request `CGRect` for the canonical `NSRange` from weak `_textLayoutController` at input-controller offset `0xf8` |
| `0x15eb5cc` | return after the geometry send | Crash return address when the clean-room callback was absent |
| `0xc416b4` | `-[_UITextKit2LayoutController boundingRectForCharacterRange:]` | Convert `NSRange` with `textRangeForCharacterRange:` and forward to `boundingRectForRange:` |
| `0xc40928` | `-[_UITextKit2LayoutController boundingRectForRange:]` | Union standard TextKit 2 segments with `RangeNotRequired`, then add text-container origin |
| `0x15eb054` | `-[UITextInputController checkSpellingForWordInRange:]` | Add alternatives display style `2` when `UITextChecker` reports a misspelled word |
| `0xc40d74` | `-[_UITextKit2LayoutController characterRangeForTextRange:clippedToDocument:]` | Send `unionTextRange`; return `{0,0}` when the argument and union range are nil |

The exact arm64 callback is
`- (CGRect)boundingRectForCharacterRange:(NSRange)range`, encoded as
`{CGRect={CGPoint=dd}{CGSize=dd}}32@0:8{_NSRange=QQ}16`. The clean-room rich
layout controller implements and preflights that exact struct ABI. It adapts
UIKit's single TextKit graph by unioning standard segment rectangles from the
participating independent block graphs in the text input view's coordinates.

The deterministic XCUITest also recovered stock's preceding nil-range
conversion. During `dictationLanguageForSelectedText`,
`attributedTextInRange:` can call `characterRangeForTextRange:` with nil.
Stock's `unionTextRange` send therefore yields nil and returns `{0,0}`; the
clean-room singular callbacks mirror that result without accepting non-nil
foreign range classes.

## Touch-count selection dispatch

The iOS 26.5 (`23F73`) simulator UIKitCore procedures show that a physical
tap is not specified solely by the public `closestPositionToPoint:` result:

| File-relative address | Procedure | Recovered responsibility |
| --- | --- | --- |
| `0x153d5c8` | `-[UITextSelectionInteraction _textGranularityForNumberOfTaps:]` | Map the recognizer's tap count through the recovered lookup for counts through two and return numeric granularity value `3` above two. The lookup contents and semantic enum names are not recovered here. |
| `0x153ddf4` | `tappedToPositionCursorWithGesture:atPoint:granularity:completionHandler:` | Query `closestPositionToPoint:` only for replacement/dictation work, then bracket the active controller's `selectPositionAtPoint:granularity:completionHandler:` with `beginSelection` / `endSelection` |
| `0x153da78` | `tappedToUpdateSelectionWithGesture:atPoint:granularity:completionHandler:` | Continue an existing selection through the active selection controller rather than assigning the preliminary closest position |
| `0x153e25c` | `-[UITextSelectionInteraction _handleMultiTapGesture:]` | Adopt the assistant delegate's active selection controller and route recognized/repeated taps through UIKit's selection-interaction state machine |

The direct 370-point oracle gives both stock `UITextView` and
`IDBlockTextView` offset `36` for `closestPositionToPoint:` at the chosen
constellation probe. A paired XCU physical single tap at that same normalized
point gives offset `46` in both editors. Therefore physical-tap parity must be
asserted against a physically tapped stock editor; substituting the preliminary
closest-position query changes the semantic layer being tested.

For the XCU driver itself, Xcode 26.5's `XCUIAutomation` binary exposes
`tapWithNumberOfTaps:numberOfTouches:` on `XCUIElement` (file offset
`0x516e4`). `XCUICoordinate` exposes `tap` (`0x4a21c`) and `doubleTap`
(`0x4a480`) but no arbitrary-tap-count selector. Triple tap is consequently
sent to the editor element at its activation point, with the expected stock
paragraph derived at that same point.

The paragraph wording in the preceding sentence is a live behavioral
observation from the stock tokenizer/XCU oracle, not a semantic decoding of
numeric value `3` in the disassembly. No obscured-input/document-granularity
mapping is asserted without exact branch and enum-value evidence. This keeps
the static Hopper provenance distinct from the public behavioral oracle.

## Selection-handle range adjustment

The iOS 26.5 (`23F73`) UIKitCore procedures place handle dragging downstream
of the text input's canonical geometry callbacks:

| File-relative address | Procedure | Recovered responsibility |
| --- | --- | --- |
| `0x9f3954` | `-[UITextRangeAdjustmentInteraction _pointCloserToEnd:]` | Choose the active endpoint from padded adjustment regions and endpoint rectangles |
| `0x9f3ac4` | `-[UITextRangeAdjustmentInteraction updateBaseAndExtentPointsFromEdges]` | Derive the logical base and extent points from the selection edge rectangles |
| `0x156c924` | `-[UITextInteractionAssistant _rangeAdjustmentPointInTextInputCoordinateSpace:]` | Convert the adjustment-container point into the proxy text-input view's coordinates |
| `0x156cc68` | `-[UITextInteractionAssistant _textRangeAdjustmentForPoint:withTouchPoint:selectionChangeReason:]` | Forward the point to the active selection through `setRangedSelectionExtentPoint:baseIsStart:` |
| `0x1576d44` | `-[UITextSelection setRangedSelectionExtentPoint:baseIsStart:allowFlipping:]` | Resolve `closestPositionToPoint:`, bound or invert the extent, and publish the selected range |
| `0x156c8b4` | `-[UITextInteractionAssistant _rangeAdjustmentViewContainer]` | Obtain the modern selection display interaction's adjustment container |

Direct stock/custom boundary and mixed-BiDi oracles agree on canonical ranges,
logical `containsStart` / `containsEnd` roles, writing directions, and endpoint
rectangle positions. Visible-handle tests also find two distinct filtered blue
components within 8 points of those logical endpoints. The first observed
difference while probing a drag across a directional-run boundary therefore
occurs after endpoint projection and host conversion, in UIKit's transient
range-adjustment/placement policy; it is not evidence for reordering canonical
endpoints. The supported within-run BiDi drag and the cross-block structural
drag match an isolated stock `UITextView` exactly, so no production geometry or
selection-container change is justified by this slice.

## Selection edge autoscroll

The iOS 26.5 (`23F73`) edge-scroll loop remains UIKit-owned:

| File-relative address | Procedure | Recovered responsibility |
| --- | --- | --- |
| `0x156cc68` | `-[UITextInteractionAssistant _textRangeAdjustmentForPoint:withTouchPoint:selectionChangeReason:]` | Publish adjustment, invalidate selection presentation, then call `startAutoscroll:` |
| `0x156c924` | `-[UITextInteractionAssistant _rangeAdjustmentPointInTextInputCoordinateSpace:]` | Convert the adjustment-container point into proxy `textInputView` coordinates |
| `0x161a040` | `-[UITextView startAutoscroll:]` | Lazily obtain `UIAutoscroll`, derive the inset edge band, choose direction, and start a `0.075`-second repeat |
| `0x161a278` | `-[UITextView cancelAutoscroll]` | Load retained `_autoscroll` and tail-call `invalidate`; the ivar is not cleared |
| `0x17c4f28` / `0x17c5210` / `0x17c52cc` | `UIAutoscroll` start / invalidate / timer | Own timer lifecycle and repeat selection adjustment through the assistant |

Phone edge padding is 8 points; the recovered tablet/Mac branch uses 32. `UITextView`
contracts bounds by text-container and effective content insets and starts only for vertically
scrollable content with a point outside the safe band.

The clean-room editor exposes its inset block stack as `textInputView`, while stock `UITextView`
is its own text-input view. Its callback point is therefore converted once from block-stack to
outer scroll-view coordinates before applying the recovered edge policy and calling
`UIAutoscroll`. UIKit continues to own timer cadence, offset mutation, endpoint extension,
selection invalidation, and cancellation; there is no custom timer, velocity curve, or range
extension loop.

The recovered publication boundary is also preserved after each outer scroll-view layout:
the new `contentOffset` is committed first, completed block origins and the inset visible rect
are then observable from `_textKit2CanvasDidLayout`, the real interaction assistant receives
`setNeedsSelectionDisplayUpdate`, and the custom backend publishes its presentation snapshot
asynchronously last. The clean-room order is therefore `contentOffset -> canvas/layout origins
-> visible state -> assistant invalidation -> backend presentation`. Presentation requests are
coalesced while one is already pending so this layout-owned assistant invalidation does not
create a self-sustaining layout loop.

Physical synthesis has role-specific handle-grab offsets. Normalized `.75,.96` / `.25,.04`
describe assistant points, not raw finger endpoints; pinned stock calibration measured trailing
`{−0.3333,−56.5333}` and leading `{−0.3333,+20.5333}`. The visible-handle oracle associates the
private lollipop with the logical active endpoint in one main-thread snapshot, subtracts that
snapshot's content offset, and clips to the viewport. This avoids false mismatches caused by
combining selection status with pixels captured several 75-ms ticks later.

## Task 7 final interaction-parity gate

The final floating-cursor gate exercised the recovered contracts on iPhone 17 Pro simulator
`404DA68C-E273-46A5-8F6C-B3BF556B80D6`, iOS 26.5 build `23F73`, arm64. It did not reopen and
independently revalidate every listed Hopper offset. No address was invented or converted between
the simulator file-relative image and the retained device VM table. The clean-room ownership
boundary remained exact:

- one native presentation-backend construction site;
- one block interaction-assistant factory call site plus one separately inventoried legacy
  flat-editor factory call site, both routed through the centralized private bridge;
- one canonical rich layout-controller owner;
- one stable presentation container with replaceable backend identity;
- private callback definitions only under `PrivateUIKit/`; and
- no production `UITextView`, XCTest HID, handcrafted cursor/loupe/handle drawing, display link,
  timer, or editor-owned autoscroll loop.

Current-head evidence covers collapsed movement, selection extension and reversal, structural
boundaries, mixed BiDi, both-direction cursor and selection autoscroll, normal end, responder loss,
keyboard dismissal, window detach, editable/selectable transitions, and pinned-runtime release
retention. Boundary selection ends at `{15,25}` and includes exactly one virtual newline. Mixed
BiDi begins at Hebrew word `{15,5}`, preserves logical endpoint roles, and matches stock at target
UTF-16 offset 17. Lower cursor reaches 1728 from the tall fixture; upper cursor reaches 0 from 891;
selection variants retain the opposite endpoint at 900. Every terminal result remains unchanged
through the 500-ms quiescence window.

The final exact source/ownership audit plus focused same/down/up anchor gate passes 65/65. The
complete serial floating gate passes 209/209 with zero skips, and exports 293 retained artifacts
plus its manifest. The inherited UI gate passes
31/31. Inherited parity passes every method except the retained native spelling-pixel difference
(custom 104, stock 162, tolerance 12). Exact commands, bundles, ranges, lifecycle truth, and
limitations are recorded in
`docs/superpowers/reports/2026-07-20-floating-cursor-interaction-parity.md`.

The final parity rerun also enforced the later-recovered vertical-anchor coordinate contract.
`UITextInputController` obtains `CGRectGetMinX` from the layout controller's container-local
insertion rectangle at `0x15eed9c..0x15eee28`; `_UITextKit2LayoutController` passes that unchanged
to `NSTextSelection.anchorPositionOffset` at `0xc3c400..0xc3c460`. InputDec's clean-room insertion
boundary returns its caret in the document stack's coordinates. The rich controller must therefore
convert the incoming stack-local X into the current block canvas before same-block TextKit
navigation, and independently into an adjacent block canvas before cross-block navigation. This
preserves UIKit's container-local TextKit contract while honoring nonzero/asymmetric canvas frames
and bounds origins exactly once. Real insertion-boundary regressions cover both paths.

## Floating-cursor document interaction-container composition

The iOS 26.5 (`23F73`) host trace corrects the earlier provisional outer-host adapter inference:

| File-relative address | Procedure | Recovered responsibility |
| --- | --- | --- |
| `0x15e6574` | `-[UITextInputController _updateFirstTextView]` | Enumerate layout-controller containers, inspect each `textView`, unwrap real UIKit `_UITextContainerView` instances, choose the visible/frontmost eligible host, weak-store it at `+0x98`, then update selection. This routine does not send `setTextContainer:`. |
| `0x16209b8` | `-[UITextView textContainer]` | Return the outer text view's stored container. No outer `setTextContainer:` implementation exists. |
| `0x16258b8` | `-[_UITextContainerView setTextContainer:]` | Perform only a weak store. Nil, foreign, and repeated containers are accepted without reciprocal work or layout side effects. |
| `0x15ec46c` | `-[UITextInputController _characterPositionForPoint:]` | Enumerate the exposed containers, obtain the eligible container text view, subtract its `textContainerOrigin` exactly once, then call the layout controller with the resulting container-local point. |
| `0x15f089c` | `-[UITextInputController caretRectForPosition:]` | Request the container-local insertion rect and add the chosen container text view's origin exactly once. |

`NSTextContainer setTextView:` performs the synchronous reciprocal `setTextContainer:` binding.
Attaching the interaction container directly to `IDBlockTextView` therefore crashed because the
outer clean-room editor, like stock `UITextView`, has no setter. The corrected composition uses
`IDBlockStackCanvasView` as the clean-room inner container view: it weakly stores
`textContainer`, remains the document-level `textInputView`, and dynamically returns
`[stack convertPoint:CGPointZero toView:outerHost]` from `textContainerOrigin`. Per-block TextKit
containers remain private render containers and never appear in UIKit-facing container inventory.

The focused host test first failed because the stack had no `textContainer` selector, then passed
after the weak binding was added. The origin test separately failed because
`textContainerOrigin` was absent; after the dynamic callback was added, the complete direct/public
floating-cursor parity and adapter lifecycle gate passed 29/29 with zero skips. The public geometry
failure before that callback was an exact `{-5,-8}` caret delta, matching the stack frame origin;
the callback corrected both `_characterPositionForPoint:` subtraction and caret add-back without
changing the controller's document-local point contract.

### Keyboard trackpad acceleration makes independent live HID runs non-identical

Task 4's alternating mixed-BiDi result was traced above the text-input controller. Atomic stock
and custom probes showed that identical declared HID waypoints can reach
`cursorPositionAtPoint:inContainer:` with different x coordinates; each layout controller then
deterministically returned the correct position for the point it actually received.

| Simulator file-relative offset | Simulator VM address | Procedure | Measured responsibility |
| --- | --- | --- | --- |
| `0x1084cc0` | Not recorded | `-[_UIKeyboardTextSelectionInteraction acceleratedTranslation:velocity:isActive:]` | Subtract `owner.lastPanTranslation`, transform each delivered event-delta magnitude through `_UICubicPolyTangent.keyboardTrackpadCurve` / `piecewiseCubicAcceleratedSpeed:`, and accumulate the scaled delta in `owner.accumulatedAcceleration`. The nonlinear per-event transform makes the endpoint sensitive to interpolation/event sampling. |
| `0x108640c` | Not recorded | `-[_UIKeyboardTextSelectionInteraction cursorLocationForTranslation:]` | Add the accelerated translation to `owner.cursorLocationBase`. |
| `0x1085f48` | Not recorded | `-[_UIKeyboardTextSelectionInteraction updateTwoFingerPanWithTranslation:executionContext:]` | Send the synthesized location to `updateFloatingCursorAtPoint:`, then update the caret/ranged selection. |
| `0x107f8d0` | Not recorded | `-[_UIKeyboardTextSelectionController updateFloatingCursorAtPoint:]` | Forward that point unchanged to the input delegate. |

The same HID declaration produced stock phase-1 x values `218.877` and `217.393` on consecutive
runs. A paired stock/custom run produced `218.877` and `223.572`, while both mapped to canonical
offset 25. This is not a layout-controller coordinate predicate. The live oracle now uses slower,
subdivided plateaus centered inside stock's directly scanned caret-stop intervals and retains exact
range/affinity equality. It also records the actual callback point and requires a three-point
minimum distance from the adjacent stop threshold, preventing a passing rerun from hiding an
unstable boundary sample.

### Floating-cursor lifecycle review correction (Task 6)

The review follow-up did not change the recovered ownership conclusion: normal
`endFloatingCursor` remains distinct from interruption cleanup, and no editor-owned timer,
recognizer, or floating session was added. It corrected the evidence boundary instead:

- every stock private selector, ivar lookup, swizzle, and `objc_msgSend` now lives behind typed
  `PrivateUIKit` entry points; `StockOracleHost/main.m` contains none of that knowledge;
- Resign (`resignFirstResponder`) and Keyboard Dismiss (`endEditing:YES`) are separate aligned HID
  targets with separate action-request counters;
- Editable Off and Selectable Off likewise have request counters distinct from observed setter
  counters, so the evidence never invents a callback that UIKit did not emit;
- lifecycle state is sampled from real container identity/subviews, presentation fingerprints,
  assistant session/autoscroll objects, live timers, flags, responder state, and recognizer sets;
- interruption synthesis is rejected unless action-up precedes keyboard lift, exact settled capture
  is action-up + 0.500 seconds, and post-lift capture is keyboard-lift + 0.500 seconds.

The literal stock record now includes normal lift, responder loss, distinct keyboard dismissal,
window detach, editable off, selectable off, and release attempts after both normal end and
interruption. This is test evidence for the pinned iOS 26.5 runtime, not an additional claim about
unrecovered UIKit procedures.

Third-review correction: all eight stock rows now come from immutable app-side phase snapshots,
not dictionaries assembled by the UI test at later read times. Each snapshot captures selection,
affinity, responder/keyboard state, container/presentation state, content offset, the complete
lifecycle record, and actual weak retention in one call. Its observation metadata carries the
literal source `app-side-weak-reference-snapshot` and one shared sequence number for lifecycle and
retention. A held-state predicate stores the pre-terminal point; the actual terminal callback
stores terminal state; the next main-run-loop turn stores immediate state; timers in common run-loop
modes store terminal/release +0.500 seconds and keyboard-lift +0.500 seconds. The UI test only reads
those frozen phase elements after the gesture schedule completes. Ordinary rows retain
`releaseEpoch == 0`; release-attempt rows record the later release epoch explicitly.

Second-review correction: the final two rows are release attempts, not proof of deallocation.
Fresh hosted editors that were never exposed through an editor AX proxy remained retained after
their host, root, and window were replaced. The normal row retained editor/assistant/container/
inactive-autoscroll but released its session; the interrupted row retained those objects plus the
same invalid session. Exact session observation uses assistant `_floatingCursorSession` at
`+0x120`, display interaction `_activeFloatingCursorSession` at `+0x88`, and session `_isValid` at
`+0x8`. `endFloatingCursor` at `0x1569e3c` clears the assistant slot; invalidation is at
`0xa49e94`. This supersedes the earlier weak-nil statement.

Keyboard ownership exclusion follows `UIKeyboardImpl +activeInstance` (`0xfc2058`),
`-keyboardStateManager` (`0xfe72c0`), and `-[UIKeyboardImpl inputDelegateManager]` (`0xfd51c4`,
manager slot `+0x2a8`). `UIKBInputDelegateManager` stores strong key/selectable/async delegates at
`+0x28`, `+0x30`, and `+0x40`; the selectable wrapper's `_textInput` was also inspected. Before and
after root/window replacement the direct key target was the sacrificial handoff field, never the
released editor.

Selectable teardown was also recovered exactly. `setSelectable:` writes OFF, resigns, then
`_updateSelectableInteractions` performs forced and nonforced cleanup. When editable remains set,
UIKit changes the raw flag through KVO and `isEditableDidChange` rather than recursively calling
public `setEditable:`. The default path at `0x1616924–0x1616938` clears the strong interaction
assistant before synchronously releasing it; the assistant destructor at `0x15644c8` clears its
session. The ON path at `0x1616860` constructs/replaces the assistant and installs recognizers at
`0x1616988`. The clean-room editor now mirrors that ordering.

Third-review semantic correction: Selectable Off has one bounded, nonsemantic weak-retention
difference at terminal and immediate. Stock's captured weak session cleared about 3 ms after the
action boundary and the clean-room reference about 13 ms after it. At both boundaries the live
assistant/display/session owners were nil, `sessionOwnersMatch`, `sessionActive`, and
`autoscrollActive` were false, and responder, keyboard, selection, affinities, container,
content-offset, presentation, counter, and recognizer relations matched. Only
`retention.sessionRetained` may differ for Selectable Off at terminal/immediate; exact action+500
ms and post-lift must be weak-nil. Every other action and phase remains strict.

Recognizer identity is frozen atomically from the exact text-input view at immutable held, after
UIKit's lazy floating recognizers exist and before action. Initial and concurrent mutable samples
are not recognizer authority. Held through post-lift must have unique identities, zero unexpected
identities, and remain subsets of held. A paired within-process HID probe ran three OFF/ON sessions
per host: stock held `29/29/29`, custom `22/22/22`, with fresh session tokens, weak-nil exact/post,
exactly one callback delta per cycle, stable container identity, and no unexpected recognizer.
`setEditable:` now refreshes gestures once after its raw bit transition for both YES and NO,
matching recovered stock behavior; only OFF publishes the terminal event.

Release chronology preserves literal targets. Release+500 ms and keyboard-lift+500 ms remain
independent: an earlier post target has an earlier sequence, while equal targets remain exact then
post. Release-interruption records its action on the current recorder before terminal/release, so
`0 < actionEpoch <= terminalEpoch`.

## Autocorrection decision and learning ownership

The iOS 26.5 stock path is owned by `_UIKeyboardStateManager`, its
`UIKeyboardAutocorrectionController`, `UIKBInputDelegateManager`, and the TextInput backend—not by
`UITextView`. Word-terminator acceptance enters
`acceptAutocorrectionForWordTerminator:executionContextPassingTIKeyboardCandidate:` at `0x7bb1c8`,
checks `shouldAcceptCandidate:beforeInputString:`, and calls
`acceptAutocorrection:executionContextPassingTIKeyboardCandidate:`. The final bookkeeping method,
`didAcceptAutocorrection:inputCandidate:wordTerminator:learningFlagsMask:` at `0x7bb6e8`, has ABI
`v@:@@@Q`; it inserts a separator when necessary and synchronizes the accepted candidate into the
input manager. Replacement reaches `UIKBInputDelegateManager
applyAutocorrection:toString:shouldUnderline:withCompletionHandler:` at `0xbebfc8` (ABI
`v@:@@B@`), which chooses web, async, async-WebKit, or local delegate replacement.
`addWordTerminator:afterSpace:afterAcceptingCandidate:elapsedTime:executionContext:` at `0x7bd9bc`
(ABI `v@:@B@d@`) separately calls `callShouldInsertText:`, clears input/candidates, handles any
autospace/double-space replacement, records `noteWordTerminator:replacement:`, and sends the
terminator through `handleKeyboardInput:executionContext:`. This explains the two observable text
and selection mutations for a length-changing correction accepted by Space.

Direct candidate taps flow through `UIKeyboardCandidateController
candidateView:didAcceptCandidate:atIndexPath:inGridType:generateFeedback:` at `0xdb2b48`; it sets
the current candidate and asks the candidate-list delegate to `candidateListAcceptCandidate:`.
Pre-commit rejection reaches `_UIKeyboardStateManager rejectAutocorrection:` at `0x7c3174`, queues
the decision, and its block calls `candidateRejected:` on the input manager. Prompt-fade rejection
does the same synchronously at `0x7cef98`.

Backspace enters `_UIKeyboardStateManager deleteBackward` at `0x7b8c8c`, then
`deleteBackwardAndNotify:` at `0x7b8814`, and
`deleteBackwardAndNotifyAtEnd:deletionCount:reinsertTextInLoop:` at `0x7b8820`. After dismissing the
underlined choice prompt, the manager forwards to `UIKBInputDelegateManager
_deleteBackwardAndNotify:reinsertText:` at `0xbeb198`, a thin forward to
`_deleteBackwardAndNotify:reinsertText:overrideOriginalContextBeforeInputWith:`. The latter snapshots
`contextBeforeInput`, marked text, and selected text; expands the backward-deletion cluster through
the text-input delegate; dispatches deletion through the web, async, selectable, or key-input
delegate; refreshes keyboard state; and finally publishes `didDeleteBackwardText:`. It contains no
`NSUndoManager` correction restoration. Fresh `adress` stock truth confirms the corresponding
immediate Backspace is ordinary deletion: first the terminator is removed, then the corrected
token's final character is removed and the keyboard offers `address` again.

The Task 5 differential exposed one further stock-host branch. `UITextView
_deleteBackwardAndNotify:` at `0x1613b90` has ABI `v@:B`: when notification is requested it calls
`deleteBackward`; otherwise it passes a block to `UITextInputController
_performWhileSuppressingDelegateNotifications:` at `0x15edd90` (ABI `v@:@?`), and that block calls
the controller's `deleteBackward`. The controller method sets its delegate-notification suppression
bit around the block and restores it afterward. This is forwarding/notification policy only; it
does not own correction history or register an undo operation.

`UIKBInputDelegateManager storeDelegateConformance` at `0xbe4e14` caches formal protocol
conformance, including bit `0x40` for `UIKeyboardInput`; `legacyInputDelegate` at `0xbe5a94`
returns the key-input delegate only when that bit is present. In
`_deleteBackwardAndNotify:reinsertText:overrideOriginalContextBeforeInputWith:` at `0xbead40`, a
non-nil legacy delegate skips the manager's separate
`_expandSelectionToBackwardDeletionClusterWithReinsertionOut:` call before forwarding deletion.
Without formal `UIKeyboardInput` adoption, the clean-room editor entered the nonlegacy branch,
published an extra selected-character callback, and left the keyboard's document state one
selection behind. Runtime ownership probes confirmed stock resolves `UITextView` and the repaired
custom path resolves `IDBlockTextView` as the legacy delegate. The clean-room editor therefore
adopts the protocol dynamically (avoiding a private link-time symbol) and mirrors only the exact
host forwarding method. Fresh proof is retained in
`.autocorrection-task5-keyboard-input-protocol-green2.xcresult`, while all nine fresh-erased custom
undo rows are retained in `.autocorrection-task5-interior-undo-space-green1.xcresult` and
`.autocorrection-task5-undo-row-{2...9}-green1.xcresult`.

Hopper also recovered why ordinary fixture resets were insufficient. `_UIKeyboardStateManager
setCorrectionLearningAllowed:` at `0x794c14` (ABI `v@:B`) stores a separate allow bit, updates the
copied traits' `learnsCorrections`, and sends `setWordLearningEnabled:` to its `TIKeyboardState`.
`finishSetInputMode:didChangeDirection:` at `0x7942d0` independently sets autocorrection enablement
from `autocorrectionPreferenceForTraits`, then computes word learning as
`traits.learnsCorrections && correctionLearningAllowed`. `UIKeyboard` forwards the selector at
`0xfb73bc` through `+[UIKeyboardImpl activeInstance]`; `UIKeyboardImpl` forwards it at `0xfd0c44`.

This was tested as a diagnostic only: after native candidate `the` was actionable, calling
`setCorrectionLearningAllowed:NO` changed the control successfully but immediately removed the
offered candidate. Directly setting `learnsCorrections:NO` also suppresses correction generation.
Neither is observationally neutral, so both experiments were removed. Authoritative stock truth
must instead execute each matrix row on a freshly erased simulator, leaving UIKit's correction and
learning policy unchanged for the duration of that row.

Fresh-erasure stock probes also rejected `teh` -> `the` as an oracle fixture. Under identical
English (US) traits, isolated rows alternated between an actionable `the` correction and the native
prediction strip `“teh”`, `tech`, `rehearsal`; extending the no-input warmup from 5 to 15 seconds
did not change the latter result. The retained failing artifacts are
`.autocorrection-task1-stock-truth-authoritative/interior-accept-candidate.xcresult` and
`.autocorrection-task1-candidate-isolated-green1.xcresult`. `wrod` -> `word` was stable in two
independently erased candidate-tap probes, but its equal token lengths did not exercise correction
range rebasing. `helllo` exposed only the selected original prediction `“helllo”`, with no native
`hello` alternative, in `.autocorrection-task1-helllo-undo-space-probe1.xcresult`.

The replacement test-only fixture is `adress` -> `address`. Two independently erased undo-space
runs exposed actionable `address` and reproduced the same seven phases; the passing repeat is
`.autocorrection-task1-adress-undo-space-probe2.xcresult`. Six typed characters produce offered
document/text/selection/checking epochs of 6. Space acceptance performs the length-changing
replacement plus delimiter insertion, producing epochs of 8 and an interior caret at 16. First
Backspace removes only the delimiter (`address  ` -> `address `), with no actionable correction;
second Backspace performs ordinary deletion (`address` -> `addres`) and exposes `address` again.
The earlier `teh` correction-restoration observation did not reproduce on fresh simulator state and
is not stock truth. This fixture change affects only the test oracle, not production correction
policy.

The completed authoritative capture is
`.autocorrection-task1-stock-truth-authoritative-adress7/`. It contains 21 passing truth bundles,
21 passing fresh-erasure warmup bundles, and 21 direct summaries with zero failures or skips. A
direct `xcresulttool` activity-tree audit verified one screenshot plus one immutable status payload
for each required phase: five phases for every accept/reject row and seven for every undo row.

At the decision phase, Space and punctuation acceptance finish at document/text/selection/checking
epoch 8 in all three locations. Direct candidate acceptance is location-sensitive because the
before-boundary path also materializes the separator before the structural newline:

| Location | Direct-candidate canonical shape | Caret | Document/text/checking | Selection |
| --- | --- | ---: | ---: | ---: |
| Interior | `address` followed by the existing space | 16 | 9 | 10 |
| Before boundary | `address ` followed by the structural newline | 16 | 8 | 8 |
| After boundary | `address` followed by the existing space | 23 | 9 | 10 |

Pre-commit rejection preserves `adress`. Its decision epochs are 8/8/8/9 for
document/text/checking/selection at the interior location, 7/7/7/7 before the boundary, and
8/8/8/9 after it. For candidate-tap immediate deletion, the first Backspace epochs are 10/10/10/11
at interior, 9/9/9/9 before the boundary, and 10/10/10/11 after it; the second Backspace increments
each field once and makes `address` actionable again. These callback-count differences are stock
truth and must remain visible to the differential harness rather than being normalized away.

The custom interior acceptance RED initially appeared to hang in caret geometry while
`_UITextChoiceAccelerationAssistant` requested correction-underline rectangles. Sampling the
live process showed the enclosing owner was actually
`-[UIResponder _underlineRectsByDocumentLineForSelectionRange:]`. Hopper decompilation at
`0x10b65b0` recovered its progress guard: after asking the tokenizer for the next document-line
range, UIKit breaks only when `[nextRange isEqual:currentRange]` succeeds. InputDec's independently
constructed `IDRichTextRange` values still used NSObject identity, so the same terminal line was
enumerated forever.

The matching UIKit value contracts are `_UITextKitTextPosition isEqual:` at `0x15fef0c`, which
compares logical offsets and deliberately ignores affinity, and `_UITextKitTextRange isEqual:` /
`hash` at `0x15ff854` / `0x15ff7f8`, which compare endpoint positions and derive the hash from
endpoint offsets (plus native subrange count). The clean-room positions now compare canonical
offsets within the same document, ranges compare their endpoints, and both publish compatible
hashes. No candidate, underline, timer, or correction policy moved into InputDec. With only this
value-semantic repair, the fresh-erased interior Space, punctuation, and direct-candidate rows all
completed and passed; the experimental caret-enumeration throttles used during diagnosis were
removed.

Pre-commit rejection was extended with a following Space probe. Stock preserves the rejected
`adress`, dismisses the candidate, and stays first responder at all three locations. Before the
structural newline, stock publishes one no-op text/selection transaction (epochs 7 -> 8) while the
clean-room responder receives two top-level controller commands: `deleteBackward`, whose private
implementation enters `_insertText:@"" fromKeyboard:YES`, followed by `insertText:@" "`. The
canonical adapter consequently publishes the transient deletion and restoration separately
(text/document 7 -> 9, selection 7 -> 10), although its final text, caret, candidate state, block
boundary, and subsequent correction behavior match stock. Retained controller-trace evidence is
`.autocorrection-task4-custom-before-controller-trace1.xcresult`.

The relevant stock delegate surface was recovered at `UITextView
keyboardInput:shouldReplaceTextInRange:replacementText:` (`0x161ba68`), its plural-ranges variant
(`0x161bb54`), and `keyboardInputShouldDelete:` (`0x161bd40`). The singular replacement method
boxes its range and calls the plural method. Backward-delete approval always evaluates
`UITextInputController _rangesForBackwardsDelete` before consulting the public delegate. InputDec
now mirrors that complete approval family and the range-evaluation side effect. Neither changes
the keyboard-owned two-command boundary sequence, so the differential harness keeps the custom
chronology explicit rather than adding a correction flag, timer, candidate UI, or fixture-specific
mutation policy.

## Inline-prediction lifecycle ownership

The iOS 26.5 (23F73) English keyboard presents inline completion as marked
text. The stock `UITextView` does not own a candidate model or a separate
prediction canvas on this path. UIKit inserts an attributed marked suffix
through the ordinary input controller, so the text layout controller and
canvas render it as part of their existing marked-text layout.

| Offset | Procedure | Recovered contract |
| --- | --- | --- |
| `0x165a3cc` | `-[UIInlineTextCompletionController _updateTextCompletionPrompt:executionContext:]` | Validates context and candidate progress, derives the candidate suffix, creates marked attributes and an `RTIStyledIntermediateText`, and calls the delegate's `presentTextCompletionAsMarkedText:`. |
| `0xfb6bc0` | `+[UIKeyboard presentsInlineTextCompletionAsMarkedText]` | Returns the cached feature decision selecting the marked-text path. |
| `0xfd7950` | `-[UIKeyboardImpl presentTextCompletionAsMarkedText:]` | Object-argument forward to `_UIKeyboardStateManager`. |
| `0x7c9968` | `-[_UIKeyboardStateManager presentTextCompletionAsMarkedText:]` | Reads the styled display/input/search strings and selected `NSRange`, notes inline marked state, and calls `_setAttributedMarkedText:...`; returns `BOOL`. |
| `0x7a66ac` | `-[_UIKeyboardStateManager _setAttributedMarkedText:selectedRange:inputString:lastInputString:searchString:compareAttributes:]` | Object, `NSRange`, four object strings, and `BOOL` arguments; forwards the attributed marked value through the input-delegate manager and returns a status integer. |
| `0x1615af8` | `-[UITextView setAttributedMarkedText:selectedRange:]` | `void` with object plus `NSRange`; loads the weak `_inputController` and forwards the callback unchanged. The view does not coerce the attributed value through public `setMarkedText:selectedRange:`. |
| `0x10c7790` | `-[UITextInputController _setAttributedMarkedText:selectedRange:]` | Private attributed-marked entry retaining the styled intermediate value before entering the keyboard-aware marked-text transaction. |
| `0x15ee62c` | `-[UITextInputController setAttributedMarkedText:selectedRange:]` | `void` with object plus `NSRange`; constructs the insertion value and enters `_setAttributedMarkedText:selectedRange:fromKeyboard:useTextStyle:`. |
| `0x15ede9c` | `-[UITextInputController _setAttributedMarkedText:selectedRange:fromKeyboard:useTextStyle:]` | Performs one `coordinateEditing:` storage transaction, invalidates the affected layout-controller character range, updates selection/interaction state, and emits controller-owned delegate notifications. |
| `0x7baf48` | `-[_UIKeyboardStateManager acceptAutocorrectionForWordTerminator:]` | Enqueues the complete word-terminator transaction on the keyboard task queue and returns the resulting candidate. |
| `0x7bb1c8` | `-[_UIKeyboardStateManager acceptAutocorrectionForWordTerminator:executionContextPassingTIKeyboardCandidate:]` | When Space acceptance is enabled, selects interaction `0` for ordinary typing (`2` only while direct-tap state is active), obtains the terminator string from the keyboard input, and calls `acceptTextCompletionWithInteraction:wordTerminator:outputHandledByCaller:YES`. The returned completion then participates in the same keyboard-output transaction as the typed terminator. |
| `0x165bb10` | `-[UIInlineTextCompletionController _acceptTypeForTypeWordTerminator:]` | Classifies a nonempty single long character through `_shouldAcceptFirstWordOfCandidateForWordTerminator:` and the input manager's `stringEndsWord:` result; this is the accept-type policy for interaction `0`. |
| `0x165bbe8` | `-[UIInlineTextCompletionController _acceptTypeForInteraction:wordTerminator:]` | Returns terminator-derived policy for interaction `0`; interactions `1`–`4` use the explicit interaction policy, while unsupported values reject. Assembly confirms `0` is not interchangeable with the direct-tap value `2`. |
| `0x165be94` | `-[UIInlineTextCompletionController acceptTextCompletionWithInteraction:wordTerminator:outputHandledByCaller:]` | With `outputHandledByCaller:YES`, performs completion learning/removal bookkeeping and returns the candidate output for the keyboard state manager to apply atomically with the typed key. Calling the two-argument convenience method alone cannot reproduce Space typing-through when the first predicted character is the terminator. |
| `0x165bc7c` | `-[UIInlineTextCompletionController _acceptTextCompletionWithInteraction:wordTerminator:]` | Returns the accepted completion object. It classifies interaction/terminator, may accept only through the next word, and delegates the chosen completion to `_acceptTextCompletion:learningMode:`. |
| `0x165b8b4` | `-[UIInlineTextCompletionController _acceptTextCompletion:learningMode:]` | `void` with two object arguments. Registers learning, calls the delegate's `acceptPredictiveInput:`, stores the last accepted completion, then removes the prompt with reason `2`. |
| `0xfd6dd8` | `-[UIKeyboardImpl acceptInlineCompletionWithCompletionHandler:]` | `void` with a completion block. Marks direct-tap acceptance and routes through `acceptAutocorrectionWithCompletionHandler:`. |
| `0x1659b44` | `-[UIInlineTextCompletionController _removeTextCompletionPromptForReason:]` | `void` with an integer reason. On the marked path clears `presentingTextCompletionAsMarkedText`, then calls the delegate's `removeTextCompletionFromMarkedText:`. |
| `0x7c9b34` | `-[_UIKeyboardStateManager removeTextCompletionFromMarkedText:]` | `void` with the expected string. If it matches current marked text, publishes an empty `RTIStyledIntermediateText` through `_setAttributedMarkedText:...` and clears the inline-completion custom-info state. |
| `0x7cb038` | `-[_UIKeyboardStateManager removeInlineTextCompletionPrompt]` | For local input, forwards to `UIInlineTextCompletionController removeTextCompletionPrompt`; remote input forwards the event to the UI host. |
| `0xfd85bc` | `-[UIKeyboardImpl removeInlineTextCompletionPrompt]` | `void` with no explicit arguments; directly forwards to its `_keyboardStateManager`. |
| `0x7c0a98` | `-[_UIKeyboardStateManager _acceptAutocorrection]` | The end-to-end local acceptance path. When a requested inline completion and key-input delegate are present, it updates keyboard state and routes through `acceptAutocorrectionForWordTerminator:nil`; unlike a direct completion-controller call, this retains keyboard-output handling. |
| `0xfd70bc` | `-[UIKeyboardImpl acceptAutocorrection]` | `void` with no explicit arguments; forwards to `_UIKeyboardStateManager acceptAutocorrection`, which selects the local `_acceptAutocorrection` path when no remote input partner owns output. |
| `0xfd6dd8` | `-[UIKeyboardImpl acceptInlineCompletionWithCompletionHandler:]` | `void` with one block argument. Marks direct-tap inline acceptance, routes through `acceptAutocorrectionWithCompletionHandler:`, then clears direct-tap state and invokes the optional completion block. It is a direct-tap policy entry point, not a substitute for the physical-Space transaction. |
| `0xfc2058` | `+[UIKeyboardImpl activeInstance]` | Object return with no explicit arguments; returns the retained/autoreleased process-wide keyboard implementation singleton. |
| `0x165c468` | `-[UIInlineTextCompletionController undoAcceptedTextCompletionExecutionContext:]` | `void` with an execution-context object. If an undo candidate exists, records immediate-delete rejection learning, clears the last accepted completion and prompt, and asks the delegate to `acceptPredictiveInput:appendSeparator:executionContext:` with the recovered prior candidate. Otherwise it returns execution to the parent. |

An explicit differential probe rejected
`acceptInlineCompletionWithCompletionHandler:` as the acceptance harness for
the frozen fixture. On both stock `UITextView` and `IDBlockTextView`, the
completion block fired after an empty attributed marked-text callback removed
the visible `" to"` suffix; the private call generated one separator and the
following physical Space generated another, leaving `I look forward  ` in
both hosts. The stock truth method had previously checked only phase shape and
offer visibility, so it falsely passed this rejected outcome. Stock truth now
requires exact accepted canonical text, selection, prompt removal, and both
post-accept Backspace results. The retained direct-tap bundles are diagnostic
evidence only. The two-Space keyboard transaction is likewise retained only
as evidence of why a leading-space fixture is unstable.

A second differential probe showed that tapping the marked suffix's glyph
rectangle is not a prompt tap: it removes the marked suffix and places the
caret. A recursive runtime inspection found no
`UIInlineTextCompletionPrompt` instance in any application window while the
English iOS 26.5 marked-text path was active. The prompt class and its
`touchesEnded:withEvent:`/`accept` methods belong to the alternate view-based
presentation path; they are not an acceptance target for this fixture.

Calling
`UIInlineTextCompletionController
acceptTextCompletionWithInteraction:wordTerminator:` with direct-tap
interaction `2` was also rejected by exact stock truth. It removed the
visible `" to"` suffix and retained only the boundary space. This agrees with
the rejected `UIKeyboardImpl` direct-tap probe and confirms that neither
private entry point substitutes for the keyboard-output transaction on the
marked-text path.

All completion ranges observed at the editor boundary are `UITextRange`
values backed by canonical UTF-16 offsets; internal styled-intermediate
selection is an `NSRange`. The marked prediction geometry comes from
`-[UITextView firstRectForRange:]` in the text view's content coordinate
space. Stock `UITextView` therefore supplies the same ordinary text storage,
marked-range, selection, and geometry contracts that it already forwards to
`UITextInputController`; keyboard/controller objects own offer, policy,
acceptance, dismissal, learning, and undo eligibility.

The original prefix `i look forward` and offered suffix ` to` crossed two
prediction cycles: the first Space removed the original controller candidate,
then the test depended on the keyboard generating a new `to` candidate.
Unified `willPerformKeyboardOutput:`/`didPerformKeyboardOutput:` traces showed
that the accepting key did not operate on the original offer. That
regeneration is keyboard-history dependent and therefore cannot be a frozen
oracle.

The corrected frozen K3 observation is prefix `i look forward `, offered
suffix `to` at canonical range `{33,2}`. One physical software-keyboard Space
accepts it in a single keyboard-output transaction, producing the exact
canonical `…look forward to  ` state with the caret at offset `36`.
Dismissal uses
`UIKeyboardImpl removeInlineTextCompletionPrompt`, avoiding geometry-dependent
touch selection. After full acceptance, the first
Backspace removes the terminating separator (`…to  ` to `…to `); the second
performs ordinary character deletion (`…to ` to `…t `). In this concrete
single-cycle acceptance path, the first two Backspaces do not restore the marked
completion, although UIKit retains the separate undo machinery described
above for eligible immediate-delete interactions.

The corrected fixture exposed one missing stock forwarding method:
`-[UITextView setAttributedMarkedText:selectedRange:]` at `0x1615af8`.
Without the matching method on `IDBlockTextView`, UIKit generated `to` after
the trailing Space for stock but did not publish it to the custom editor.
Forwarding the attributed value and `NSRange` unchanged to
`UITextInputController setAttributedMarkedText:selectedRange:` restores the
stock candidate lifecycle. The controller selector is now a required
fail-closed compatibility contract, and both custom text-view families have
focused marked-range/selection tests for this private entry.

The repaired `IDBlockTextView` interior differential confirms that the
remaining ownership path is reusable end to end. Its canonical text, independent
blocks, selection, marked range, prediction descriptor, temporary rendering,
keyboard state, and responder state match stock across accept, dismiss/type,
and two-Backspace phases. No new private completion selector is required.
The custom geometry is subpixel-close to stock (`23×26` versus
`22.333×25.667` points), and its canonical storage coalesces marked-text
transactions more aggressively than the stock oracle's synthetic
delegate-event revision counter; neither changes the user-visible lifecycle.

## IME keyboard input-mode provisioning ownership

The iOS 26.5 (23F73) provisioning path is a global keyboard preference read
by UIKit, not an editor-owned language policy. K3's read-only
`.GlobalPreferences.plist` contained `AppleKeyboards` as an array of expanded
identifier strings and `AppleKeyboardsExpanded` as integer/Boolean `1`.

| Offset | Procedure | Recovered contract |
| --- | --- | --- |
| `0xdce4f8` | `-[UIKeyboardInputModeController init]` | Standard object-return initializer. Registers `keyboardsPreferencesChanged:` for `AppleKeyboardsPreferencesChangedNotification`; UIKit owns preference cache invalidation. |
| `0xddc568` | `-[UIKeyboardInputModeController enabledInputModeIdentifiers:]` | Object return with one `BOOL` argument (`@@:B`). At `0xddc5ec` it obtains the shared preferences controller, asks its actions object for `_TIAppleKeyboardsPreference`, and treats the result as an identifier array. It separately reads `_TIAppleKeyboardsExpandedPreference`; when expanded, it validates and materializes every system input mode. |
| `0xde6ae4` | `_UIKeyboardInputModeGetIdentifierWithKeyboardLayouts` | AArch64 object argument in `x0`, object return in `x0`. Parses `sw`/`hw` components, supplies supported defaults when absent, and rebuilds the expanded identifier. Host provisioning therefore persists explicit software layout and `hw=Automatic` rather than depending on locale defaults. |
| `0xdce76c` | `-[UIKeyboardInputModeController inputModeWithIdentifier:]` | Object return with one object argument (`@@:@`). The read-only K3 runtime probe used this factory to validate both target identifiers through UIKit itself. |
| `0xde2cf8` | `-[UIKeyboardInputMode primaryLanguage]` | Object return with no explicit arguments (`@@:`). The runtime probe returned `ja-JP` for Japanese Romaji and `zh-Hans` for Simplified Chinese Pinyin. |
| `0xde2d90` / `0xde2ddc` | `-[UIKeyboardInputMode identifier]` / `normalizedIdentifier` | Object returns (`@@:`). Expanded Japanese normalizes to `ja_JP-Romaji`; expanded Simplified Chinese Pinyin normalizes to `zh_Hans-Pinyin`. |

The runtime's
`System/Library/TextInput/TextInput_ja.bundle/InputMode_ja.plist` declares
`ja_JP-Romaji` with software layout `QWERTY-Japanese`.
`TextInput_zh.bundle/InputMode_zh.plist` declares
`zh_Hans-Pinyin@sw=Pinyin-Simplified`. A read-only UIKit probe then accepted
the exact persisted forms
`ja_JP-Romaji@sw=QWERTY-Japanese;hw=Automatic` and
`zh_Hans-Pinyin@sw=Pinyin-Simplified;hw=Automatic`, reporting primary
languages `ja-JP` and `zh-Hans`.

The frozen contract is
`UITests/Fixtures/ime-keyboard-modes-ios26.5-v1.json`. The harness writes only
`NSGlobalDomain/AppleKeyboards` and `AppleKeyboardsExpanded` on the already
booted pinned K3 simulator, then reboots that same simulator to cross a clean
UIKit process/cache boundary. It never creates, clones, erases, or selects a
different device. Active-language validation remains a separate editor-side
gate; a successful preference write alone is not behavioral IME evidence.

The first erased provisioning proof retained at
`.ime-task2-provision-green/` showed a further system-owned invariant. The
write command contained exactly the two target IMEs, but after reboot iOS
persisted `en_AU@sw=QWERTY;hw=Automatic` as an ASCII fallback. A later
independently erased Task 9 host retained the same exact two-identifier write
in `commands.json`, followed after reboot by
`ru_RU@sw=Russian;hw=Automatic` instead. That variability changed real IME
behavior: independently erased hosts with different fallbacks could
automatically return to different primary languages after a candidate
decision. The differential harness therefore writes one fixed observed ASCII
fallback, `en_AU@sw=QWERTY;hw=Automatic`, after the two target identifiers.
A later erased boot demonstrated that iOS can append Russian even when English
was explicitly persisted, and a retained stock hierarchy then showed the
keyboard switching from Chinese QWERTY to Russian in the middle of marked-text
input. The harness therefore rewrites the same exact three-item array after
the reboot, publishes `AppleKeyboardsPreferencesChangedNotification`, and
requires exact read-back before app launch. This makes the stock and custom
comparison environments equivalent while rejecting every missing, reordered,
duplicate, or unknown value.

## IME selection-affinity publication

The first independently erased Japanese interior differential reported stock
`forward` versus custom `backward` during `firstComposition`. This was an
oracle defect, not an editor defect: `IDStockIMEStatus` had hard-coded
`forward`, while the custom host queried UIKit's live controller state.

| Offset | Procedure | Recovered contract |
| --- | --- | --- |
| `0x161596c` | `-[UITextView selectionAffinity]` | Loads the weak `_inputController`, sends `selectionAffinity`, and returns the integer unchanged. `UITextView` contributes no affinity policy. |
| `0x15eddd4` | `-[UITextInputController selectionAffinity]` | Obtains the selected range end, calls the adopted layout controller's `affinityForPosition:`, then applies its internal explicit-affinity override when present. Return value is `UITextStorageDirection` in `x0`. |
| `0x10c722c` | `-[UITextInputController _selectionAffinity]` | For a selectable text object that implements `selectionAffinity`, forwards directly. Its tokenizer boundary fallback is used only when that selector is unavailable. |

The stock status endpoint now reads `editor.selectionAffinity`, exactly as
the custom endpoint reads the reused `UITextInputController`. This preserves
UIKit's marked-text affinity transition instead of normalizing it away.

The next Japanese update differed only in `documentRevision` (`2` stock,
`3` custom), while canonical text, marked state, delegate trace, and all
text/selection/checking epochs agreed. The controller path explains why:
`-[UITextView setAttributedMarkedText:selectedRange:]` at `0x1615af8`
forwards the attributed string and by-value `NSRange` unchanged. The
controller's
`_setAttributedMarkedText:selectedRange:fromKeyboard:useTextStyle:` at
`0x15ede9c` builds one attributed replacement, wraps the text storage change
in `coordinateEditing:`, invalidates display, sets selection, and emits one
text/selection delegate transaction. `IDBlockDocument.documentRevision`
also counts an internal persistent-attribute mutation made while realizing
that attributed replacement; the stock oracle's delegate counter cannot
observe an equivalent `NSTextStorage` sub-mutation. Differential comparison
therefore requires each host's document revision to be valid and monotonic,
but uses the exact delegate traces and text/selection/checking epochs for
cross-host transaction parity.

After that normalization, the candidate decision exposed a real affinity
differential: stock changed from backward while marked to forward after
commit, while custom remained backward. UIKit's
`-[UITextInputController unmarkText:]` at `0x15ee970` clears marked state and
calls `setSelectedRange:` with the resulting canonical `NSRange`.
`setSelectedRange:afterDelta:appliedToRange:` converts that range through the
adopted layout controller's `textRangeForCharacterRange:` before publishing
selection. `_UITextKit2LayoutController textRangeForCharacterRange:` at
`0xc41158` constructs `_UITextKitTextRange` with affinity argument `0`
(forward). The custom native conversion had instead created an empty range
from a backward-affinity start. It now uses forward affinity for empty private
character-range conversions, matching the stock post-unmark caret without
changing the typed canonical range helper.

## IME Return/Undo and responder-loss reuse

The terminal IME differential required no additional private policy or
production repair. `IDBlockTextView` already returns the controller-owned
`_UITextUndoManager`, matching `-[UITextView undoManager]` at `0x18aa01908`
and `-[UITextInputController undoManager]` at `0x1896848f8`. Its responder
transition also continues through ordinary `resignFirstResponder`, matching
the stock cleanup entry at `0x160fdfc`; the host does not synthesize an IME
commit or cancellation decision.

The retained `.ime-task8-terminal-differential/` evidence contains six
independently erased stock/custom pairs on K3, iOS 26.5 (`23F73`): Return
commit followed by one immediate controller Undo before and after the
structural block boundary for both Japanese Romaji and Simplified Chinese
Pinyin, plus before-boundary responder loss for both languages. All six
comparisons passed. Return commit, immediate/quiesced state, Undo restoration,
responder cleanup, canonical text, selection/affinity, marked state, stable
block and anchor identities, epochs, callback chronology, keyboard state, and
geometry therefore remain UIKit-owned end to end. No language-specific
transaction grouping or responder-loss state machine is mirrored in the
custom view.

Task 9's longer order-reversed repetitions subsequently exposed a host
contract that the six-row Task 8 sample did not trigger consistently. In two
independent Japanese Return/Undo comparisons, stock retained `ja-JP` through
Undo while the custom host switched to the provisioned `en-AU` fallback after
otherwise identical canonical, marked, selection, responder, and keyboard
states. This was not a block transaction or IME policy difference: the custom
view had synthesized the public `UITextInputTraits` properties in separate
ivars and did not expose the controller's complete traits object.

| Offset | Procedure | Recovered contract |
| --- | --- | --- |
| `0x161cbb8` | `-[UITextView textInputTraits]` | Returns `_textInputTraits` unchanged. |
| `0x161cbbc` | `-[UITextView _textInputTraits]` | If the weak input controller implements `_textInputTraits`, returns that controller-owned object. If no controller exists, lazily obtains `+[UITextInputTraits defaultTextInputTraits]`. |
| `0x15fb7d8` | `-[UITextInputController _textInputTraits]` | Returns the `UITextInputTraits` object allocated and owned by the controller. |
| `0x161cce0` | `-[UITextView forwardingTargetForSelector:]` | For every selector implemented by `UITextInputTraits`, forwards to `_textInputTraits`; otherwise uses the superclass target. |
| `0x161cd5c` | `-[UITextView respondsToSelector:]` | Advertises the union of the text-view method family and every `UITextInputTraits` instance selector (with a delegate-specific exception for `insertTextSuggestion:`). |
| `0x161ce14` | `-[UITextView methodSignatureForSelector:]` | Resolves the text-view class signature first, then the `UITextInputTraits` class signature. |
| `0xbe6204` | `-[UIKBInputDelegateManager textInputTraits]` | Obtains the private input delegate's `textInputTraits`, adopts it as the canonical keyboard traits object, and overlays protocol/delegate state. |

`IDBlockTextView` now mirrors this ownership boundary. `_textInputTraits` and
`textInputTraits` expose the controller-owned object, the complete private
trait selector family participates in response/signature/target forwarding,
and all public traits are synchronized into that object at construction and
on mutation. The two private constructors/getters and every synchronized
setter are ABI-preflighted; missing or wrong-but-present encodings throw
before dispatch. The custom editor retains its existing continuous-spelling
bridge while eliminating the split keyboard-traits state that could affect
UIKit's late input-mode choice.

## Inline formatting and typing attributes

`IDInlineFormattingStockOracleTests` records the following stock `UITextView`
truth on K3, iOS 26.5 (`23F73`). Trait arrays below are normalized from
`typingAttributes` and the text storage's concrete font/decorations; U+000A is
treated as an unformatted structural unit for comparison with the independent
block document.

| Transition | Selection | Effective typing traits | Persistent run result | Undo result |
| --- | --- | --- | --- | --- |
| Caret at the start of a bold run | `{0, 0}` | bold | unchanged | none |
| Caret inside a bold run | `{1, 0}` | bold | unchanged | none |
| Caret at bold/italic boundary | `{2, 0}` | bold (left-biased) | unchanged | none |
| Caret at end of italic run | `{4, 0}` | italic | unchanged | none |
| Explicit bold at a plain caret | `{1, 0}` | bold | document remains plain | none |
| Insert `X` after explicit bold | `{2, 0}` | bold | inserted `X` is bold | one typing undo |
| Insert Return before following plain text | `{3, 0}` | plain | U+000A is structural; following insertion is plain | remains in typing undo |
| Insert Return at document end after explicit bold | `{3, 0}` | bold | U+000A is structural; following `Y` is bold | remains in typing undo |
| Move explicit-bold caret to italic document end | `{2, 0}` | italic | document unchanged | none |
| Replace selected plain text after setting italic + underline typing attributes | `{2, 0}` | italic + underline | replacement carries both traits | one replacement undo |
| Delete bold character before italic run | `{0, 0}` | italic | remaining character stays italic | one delete undo |
| Undo bold + strikethrough insertion | `{1, 0}` | plain | original plain document restored | redo available |
| Redo bold + strikethrough insertion | `{2, 0}` | bold + strikethrough | formatted insertion restored | undo available |

Two details constrain the block implementation:

1. Context at an ordinary run boundary is left-biased, including the exact
   boundary between bold and italic runs.
2. Return does not have one unconditional inheritance rule. When text follows
   the inserted newline, UIKit adopts that following paragraph's formatting;
   at document end, it preserves the explicit typing override into the new
   paragraph.

### Private typing-attribute ownership and insertion call graph

The authoritative caret-typing seam is the reused `UITextInputController`
cache. It is not `_UITextKit2LayoutController
attributesAtPosition:inDirection:`. UIKit derives ordinary context from the
adopted `NSTextStorage`, stores explicit or derived attributes on the input
controller, and uses that dictionary to construct the attributed insertion
before mutating storage.

| Offset | Procedure | Recovered contract |
| --- | --- | --- |
| `0x1616cfc` | `-[UITextView typingAttributes]` | Synchronizes the extra-line fragment, then returns `[_inputController typingAttributes]`. |
| `0x1616d48` | `-[UITextView setTypingAttributes:]` | Removes dictation-result metadata, forwards the copied dictionary to `[_inputController setTypingAttributes:]`, then invalidates extra-line layout as needed. |
| `0x15efe3c` | `-[UITextInputController typingAttributes]` | Returns the cached dictionary. If the cache is nil, derives it with `_attributesForReplacementInRange:` for the selected range, stores it through `setTypingAttributes:`, and returns the cache. |
| `0x15fc730` | `-[UITextInputController setTypingAttributes:]` | `objc_setProperty_nonatomic_copy`; the controller itself is the explicit typing-attribute owner. |
| `0x15effe0` | `-[UITextInputController _invalidateTypingAttributes]` | Clears the cache by setting `typingAttributes` to nil. |
| `0x15e7670` | `___46-[UITextInputController setSelectedTextRange:]_block_invoke_3` | Publishes the new selected range, calls `_invalidateTypingAttributes`, tells the interaction assistant that selection changed, and sends selection delegate notifications. Thus an explicit selection move discards an explicit typing override. |
| `0x15efb30` | `-[UITextInputController _attributesForReplacementInRange:]` | Reads the adopted text storage under `coordinateReading:`, chooses contextual attributes in its block, then passes them through `_fixupTypingAttributeForAttributes:`. |
| `0x15efc34` | `___58-[UITextInputController _attributesForReplacementInRange:]_block_invoke` | Implements UIKit's boundary rule directly on `NSTextStorage`: ordinary collapsed ranges use the preceding unit, document start uses the first unit, document end uses the last unit, and newline adjacency selects the following paragraph where available. |
| `0x15ef360` | `-[UITextInputController _fixupTypingAttributeForAttributes:]` | Copies only keys in `_allowedTypingAttributes`, excluding system-only keys, and repairs the original-font attribute. Custom semantic keys are lost unless explicitly admitted. |
| `0x15ef128` | `-[UITextInputController _allowedTypingAttributes]` | Returns the per-controller allowed set when installed, otherwise UIKit's process-wide concrete text-attribute set. |
| `0x15ef324` | `-[UITextInputController _setAllowedTypingAttributes:]` | Copies a per-controller allowed-key set. |
| `0x1619a28` | `-[UITextView _setAllowedTypingAttributes:]` | Thin forwarding wrapper to the input controller's `_setAllowedTypingAttributes:`. |
| `0x15efac4` | `-[UITextInputController _attributesForInsertionOfText:]` | Uses cached `typingAttributes` when the replacement range is the active selected range; otherwise derives replacement context. |
| `0x15ef54c` | `-[UITextInputController _newAttributedStringForInsertionOfText:inRange:]` | Creates an `NSMutableAttributedString` from the plain input text and `_attributesForInsertionOfText:` before storage mutation, then offers it to the insertion delegate. |
| `0x15e8830` | `___50-[UITextInputController _insertText:fromKeyboard:]_block_invoke_2` | In the TextKit 2 path, calls `handleInsertedText:...updatedTypingAttributes:`; otherwise creates the attributed insertion directly and calls `replaceCharactersInRange:withAttributedString:` on adopted storage. |
| `0x15e7fe4` | `-[UITextInputController _insertText:fromKeyboard:]` | Coordinates the storage edit, advances selection through `setSelectedTextRange:` (which invalidates the cache), then applies the insertion path's `updatedTypingAttributes` with `setTypingAttributes:`. This is why typing advances preserve an override while an unrelated explicit move clears it. |
| `0x16170cc` | `-[UITextView textInputDidChangeSelection:]` | Only notifies the public delegate, refreshes the formatting controller, and scrolls the caret. It does not own typing-attribute invalidation. |

`_UITextKit1LayoutController attributesAtPosition:inDirection:` at
`0x6ffecc` and `_UITextKit2LayoutController
attributesAtPosition:inDirection:` at `0xc3d3a0` read layout-backed document
attributes for other text-input consumers. Neither participates in
`UITextInputController`'s typing-attribute derivation above, so overriding that
callback would create a second, incomplete source of truth.

The clean-room block host therefore follows the same ownership boundary:

1. Add the four semantic attribute names to the reused controller's allowed
   typing-attribute set.
2. For a collapsed formatting command, read the controller's complete current
   `typingAttributes`, change only the requested semantic trait through
   `IDInlineTextStyleResolver`, and write the resulting concrete + semantic
   dictionary back with `setTypingAttributes:`.
3. Let UIKit invalidate, derive, preserve, and restore that cache through its
   existing selection, insertion, deletion, Return, and undo paths.
4. Keep `IDCanonicalTextStorageAdapter` accepting UIKit's attributed
   replacement unchanged. No independent insertion provider or layout
   attribute override is installed.

This single seam matches the measured stock truth table and avoids duplicating
UIKit's transition state machine.

### Differential Return and undo/redo repairs

The 14-row semantic-formatting differential corpus exposed two representation
differences that require narrow host-side synchronization while leaving the
interaction policy in UIKit.

| Offset | Procedure | Recovered contract |
| --- | --- | --- |
| `0x15e89f4` | `-[UITextInputController supportsTextKit2TextLists]` | Asks the delegate whether TextKit 2 text-list handling is supported. |
| `0x16217c4` | `-[UITextView _supportsTextKit2TextLists]` | Normally reports support, subject to the text view's list-marker state. |
| `0x15e8a60` | `-[UITextInputController handleInsertedText:intoTextStorage:replacementRange:updatedTypingAttributes:]` | Produces updated typing attributes for the TextKit 2 list insertion path; it is not the general non-list Return inheritance mechanism. |
| `0x15e3540` | `-[_UITextUndoOperationTyping _undoRedo]` | Restores attributed content, publishes the restored selection, and reports the replacement to the undo delegate. |
| `0x15f1664` | `-[UITextInputController undoManagerDidFinishUndoRedo]` | Notifies the delegate and republishes the selected range after an undo or redo finishes. |

At document end, stock `UITextView` temporarily retains paragraph context on
the inserted newline in its single text storage. InputDec deliberately strips
semantic attributes from U+000A because its newline is a structural separator
between independent blocks. A separately delivered Return would therefore let
the controller rederive plain attributes from that separator. The custom host
captures the controller's complete typing attributes only for a collapsed
document-end Return and restores them after insertion; the separator remains
unformatted and the next typed character inherits the same explicit traits as
stock.

After typing undo/redo, UIKit's operation restores attributed content and
selection, but InputDec's separate-block restoration can leave the reused
controller's cached typing dictionary stale. Observing the host undo manager's
did-undo and did-redo notifications and invoking the measured
`_invalidateTypingAttributes` seam makes the controller lazily derive the
restored context on its next read. No custom undo grouping, insertion policy,
or selection transition is introduced.

### Attributed paste import boundary

The rich-paste path must import concrete font and decoration attributes before
UIKit performs its final replacement. Implementing the paste delegate's final
mutation callback would move too much transaction ownership into the custom
view.

| Offset | Procedure | Recovered contract |
| --- | --- | --- |
| `0x159adb4` | `-[UITextPasteController _performPasteOfAttributedString:toRange:forSession:completion:]` | Tests whether the paste delegate implements the final perform callback. If it does, UIKit calls that delegate directly; otherwise UIKit forwards the combined attributed string to the input controller. |
| `0x15f8a20` | `-[UITextInputController _pasteAttributedString:toRange:completion:]` | Normalizes the attributed insertion, pins input views, invokes `_pasteRawAttributedString:asRichText:`, derives the resulting text range, and completes through the paste controller. |

InputDec therefore installs itself only as the attributed-string combination
delegate. It concatenates UIKit's already-loaded paste items and runs
`IDInlineTextStyleResolver` import on that combined value. Because it does not
implement `performPasteOfAttributedString:toRange:`, UIKit's input controller
still owns approval, rich insertion, selection advancement, undo registration,
and completion. Correction, inline prediction, and marked-text replacements
never cross this import boundary, so temporary presentation attributes cannot
become durable semantic intent.

## Behavior kernel Pass 1 provenance

Pass 1 is complete for iOS 26.5 build 23F73. It changed ownership and
preflight boundaries using the already-recovered evidence in this ledger; it
does not claim a new Hopper disassembly pass. The exhaustive member-level
ledger is
`PrivateUIKit/Contracts/UIKitBehaviorContracts-iOS26.5.json`: every retained
production member records its owner capability, direction, exact return and
argument encodings, source occurrence, fallback, evidence anchor, and
teardown rule. The summary below groups those exact entries by lifecycle.

| Class / member family | Direction and exact ABI family | Final owner capability | Source seam | Enabled behavior / fallback | Evidence, tests, and teardown |
| --- | --- | --- | --- | --- | --- |
| `UITextInputController initWithTextLayoutController:` | outgoing, `@ <- @` | mandatory `inputController` | `IDUIKitInputControllerCapability.m` through the manifest-backed resolver | UIKit input state machine over `IDRichTextLayoutController`; no fallback | construction path recovered above; constructor/ABI/fault tests reject before allocation; detach through `_detachFromLayoutManager` |
| `UITextInputController setDelegate:` | outgoing, `void <- @` | mandatory `inputController` | `IDUIKitInputControllerCapability.m` | adopts `IDBlockTextView` callbacks; no fallback | construction and throwing-setter lifecycle tests; set once after successful initialization and clear through detach |
| `UITextInputController` public-input forwarding family | outgoing object, integer, range, point, rect, BOOL, and block ABIs exactly enumerated in the manifest | mandatory `inputController` | `IDUIKitInputControllerCapability.m` | selection, marked text, tokenizer, geometry, edits, Undo, and affinity; no mandatory fallback | typed-forwarding ABI tests plus 216-scenario stock/reference/minimal differential; reject calls after idempotent detach |
| `_textInputTraits`, `typingAttributes`, setters, allowed-attribute and invalidation family | outgoing `@ <- ()`, `void <- @`, and related exact scalar/object ABIs | mandatory `typingAttributes` for the rich slice | `IDUIKitInputControllerCapability.m` | complete controller-owned trait family and semantic typing cache; plaintext remains possible when this capability is not requested | `0x15fb7d8`, `0x15efe3c`, `0x15fc730`, `0x15ef128`–`0x15ef324`; formatting unit/differential/real-keyboard pairs; invalidate before releasing formatting observers |
| `_rangesForBackwardsDelete` and returned `unionRange` | outgoing `@ <- ()`, then `{NSRange=QQ} <- ()` | mandatory `inputController` | `IDUIKitInputControllerCapability.m` | stock-like backward-delete approval; no unsafe nil fallback | `UITextView keyboardInputShouldDelete:` call graph above; malformed/wrong-ABI and line-break merge regressions; release the transient aggregate immediately |
| `UITextInteractionAssistant` construction, selection lifecycle, recognizer, responder, select-word/all, and detach family | outgoing exact object/BOOL/void/CGPoint ABIs enumerated in the manifest | optional `interaction` | `IDUIKitInteractionCapability.m` | native gestures, loupe, handles, edit menu, and selection session; fallback is project-owned selection presentation | assistant construction/ABI/fault matrix and touch differentials; clear recognizers, end transient state, then detach |
| `beginFloatingCursorAtPoint:`, `updateFloatingCursorAtPoint:animated:`, `endFloatingCursor` | outgoing `void <- CGPoint`, `void <- CGPoint, BOOL`, `void <- ()` | optional `floatingCursor`, depends on `interaction` | `IDUIKitInteractionCapability.m` | UIKit keyboard-trackpad session; fallback is ordinary selection | `0x1569ba4` and adjacent call graph; stock/minimal normal-end and selection-extension sentinels; end session before assistant detach |
| `UITextAutoscrolling` plus incoming `startAutoscroll:` / `cancelAutoscroll` | incoming protocol and callbacks: `@`, `void <- CGPoint`, `void <- ()` | optional `autoscrollEntry` | `IDUIKitAutoscrollEntryCapability.m`, `IDBlockTextView+PrivateInteractionCallbacks.m` | UIKit assistant recognizes gestures; minimal mode uses project cadence, public scroll geometry, and project endpoint extension | `0x161a040` / `0x161a278` define the boundary; exact-count manifest tests require one protocol and two callbacks; cancel the project session before view teardown |
| `autoscrollWillNotStart` | outgoing `void <- ()` | optional `interaction` | `IDUIKitInteractionCapability.m` | closes an assistant attempt rejected by public edge policy | `0x1569e88` call graph and routing tests; exactly one retained assistant closure message |
| `UIAutoscroll` class/start/invalidate family | reference-only outgoing `# <- ()`, `BOOL <- @, @, CGPoint, int, double`, `void <- ()` | `referenceOnly.legacyAutoscroll` | typed adapter in `IDPrivateUIKit.m` | reference backend preserves UIKit cadence; unreachable from the minimal branch | `0x17c4f28`, `0x17c5210`, `0x17c52cc`; exactly three reference-only members; invalidate before release |
| continuous-checking getter/setter and annotation callbacks | outgoing `BOOL <- ()`, `void <- BOOL`; incoming annotation/range/object ABIs in the manifest | optional `checking` plus mandatory incoming callback ownership | `IDUIKitInputControllerCapability.m`, `IDBlockTextView+PrivateCallbacks.m`, `IDRichTextLayoutController+PrivateCallbacks.m` | UIKit spelling annotations and native temporary marker rendering over project layout; fallback is editing without checking annotations | `0x15fc758` / device `0x1896ec6fc`; spelling annotation/cleanup and fault tests; stop checking and drop ephemeral annotations before detach |
| `setAttributedMarkedText:selectedRange:` | outgoing `void <- @, {NSRange=QQ}` | optional `prediction` | `IDUIKitInputControllerCapability.m` | UIKit inline-prediction marked-text lifecycle; fallback is ordinary marked text | prediction lifecycle disassembly above; nine-row differential and stock/minimal real-keyboard accept/dismiss tests; clear marked state before detach |
| paste protocol/class and cut/copy/paste/action helpers | outgoing class/object/SEL/BOOL ABIs exactly enumerated in the manifest; incoming adopted protocol | optional `paste` | `IDUIKitInputControllerCapability.m`, `IDBlockTextView+PrivateCallbacks.m` | UIKit approval and rich insertion when active; fallback is project-owned paste | `_pasteAttributedString:toRange:completion:` path above; paste ABI/fault and formatting tests; remove transient paste state with input detach |
| `insertDictationResult:` | outgoing `void <- @` | optional `dictation` | `IDUIKitInputControllerCapability.m` | native phrase insertion; fallback inserts phrase text through the project path | recovered optional selector contract and fault matrix; no retained dictation state after the call |
| `IDRichTextLayoutController` / `IDBlockTextView` incoming callback families | incoming exact per-member ABIs; 47 manifest entries | mandatory `incomingCallbacks` | `IDRichTextLayoutController+PrivateCallbacks.m`, `IDBlockTextView+PrivateCallbacks.m`, `IDBlockTextView+PrivateInteractionCallbacks.m` | canonical text/ranges, geometry, storage, annotations, traits, interaction host, and selection display without a concrete private layout controller | recovered callback sections throughout this ledger; incoming ABI/source audits, 216 fast scenarios, and 24 keyboard sentinels; detach UIKit owners before document/layout release |
| `_UITextLayoutControllerBase`, `_UITextKit2LayoutController`, concrete canvas/rendering/attachment family, and `+0x50` map | outgoing/private storage, exact 53-member reference-only manifest | `referenceOnly.legacyLayout` / `referenceOnly.legacyCanvas` | retained reference adapters | behavioral control only; unreachable from minimal capabilities | existing layout/canvas evidence above; source audit proves forbidden symbols absent from `BehaviorKernel`; release canvas/attachment ownership before reference controller teardown |
| stock cursor/layout/keyboard/autoscroll introspection and method swizzles | test-only outgoing/introspection, exact 25-member manifest | test-only `interaction` | diagnostic adapters and tests | differential diagnostics only; never production compatibility | established stock-oracle evidence and source audit; restore/contain swizzles and exclude every entry from production reports |

Final counts are 127 minimal production members (98 in mandatory
capabilities, 29 in optional capabilities), 56 reference-only members, and 25
test-only members. The reference total comprises 53 layout/canvas members and
three legacy `UIAutoscroll` members. Concrete UIKit
layout/canvas/rendering/autoscroll membership in the minimal capability
dictionary is zero. The aggregate minimal count remains 127 because the
removed concrete autoscroll class/start/invalidate family was replaced at the
same three-member boundary by one adopted `UITextAutoscrolling` protocol and
two incoming callbacks; the four eliminated private geometry reads were
implementation details and never separate manifest members. The final
216-test semantic gate and
24-method real-keyboard stock/minimal gate both pass with zero failures or
skips; complete evidence paths and durations are recorded in
`docs/superpowers/reports/2026-07-28-minimal-private-input-kernel-pass1.md`.

## Clean-room vertical-autoscroll oracle

The clean-room vertical-autoscroll pass rechecked UIKitCore live in Hopper and
froze a direct test-only oracle before implementing the project engine. This
section supplements the earlier selection-edge analysis; it does not change
the reference backend.

| Address | Procedure | Recovered rule | Frozen test |
| --- | --- | --- | --- |
| `0x17c4f28` | `-[UIAutoscroll startAutoscroll:scrollContainer:point:directions:repeatInterval:]` | Validate `updateAutoscroll:`, disabled state, optional container policy, nonnil container, nonzero direction/interval | invalid, disabled, and policy-rejection truth rows |
| `0x17c4f70`–`0x17c5064` | same | Convert old/new points through `convertPoint:toView:nil`; coalesce only for identical target/container, distance `< 70`, identical direction, and exactly equal interval; update point only | 69.999 coalesces, exactly 70 restarts, transformed container proves global distance |
| `0x17c5108`–`0x17c5198` | same | Reuse/reschedule or create a repeating `NSTimer`, fire at now, add to current run loop in `NSDefaultRunLoopMode` | immediate-first-fire and 75 ms cadence truth row |
| `0x17c519c`–`0x17c5204` | same | Reset count only when direction changes, then store weak target, strong container, point, direction, interval, and active state | interval preserves count; direction resets it |
| `0x17c5210` | `-[UIAutoscroll invalidate]` | Hop cleanup to main when needed and clear timer/session state | repeated invalidation and ownership release |
| `0x17c52cc` | `-[UIAutoscroll timerFired:]` | Increment count before calling target `updateAutoscroll:` | callback observes counts 1 then 2 |
| `0x161a040` | `-[UITextView startAutoscroll:]` | Lazily obtain `UIAutoscroll` and start with a 0.075-second interval | existing physical top/bottom edge-hold baseline |
| `0x156a160` | `-[UITextInteractionAssistant updateAutoscroll:]` | Consume the tick for vertical offset movement and active-endpoint extension | retained as the Task 4/8 differential reference |

The oracle calls and reads are uniquely owned by
`Tests/Fixtures/UIKitBehaviorTestOnlyContracts-iOS26.5.json`. The 25-member
test-only count consists of the previous 15 diagnostic contracts plus ten
`UIAutoscroll` getter/control contracts. None is a minimal production
dependency.

Minimal mode now mirrors those recovered rules with
`IDVerticalAutoscroll`. Its engine owns a weak target, strong scroll
container, transformed-point coalescing, immediate first tick, 75 ms repeating
timer, count reset on direction changes, idempotent invalidation, and
main-thread cleanup. `IDVerticalAutoscrollGeometry` derives the vertical safe
band exclusively from public `bounds`, `adjustedContentInset`, and
`contentOffset`. The editor then applies the recovered order: incrementally
scroll, reconcile block layout, reproject the held adjustment point, update
only the active logical endpoint, and publish selection presentation.

The private surface retained by minimal mode is therefore exactly one protocol
(`UITextAutoscrolling`), two incoming callbacks (`startAutoscroll:` and
`cancelAutoscroll`), and one already-owned assistant closure message
(`autoscrollWillNotStart`). Minimal production performs zero `UIAutoscroll`
class/message operations, zero private scroll-geometry reads, and zero
`updateAutoscroll:` sends. The real `UIAutoscroll` family remains available
only to the reference backend as a differential control.

## Canvas lifecycle callback reduction

This reduction was rechecked against the open UIKitCore image for iOS 26.5
build 23F73. The selector-stub search and every stub's complete caller list
were reproduced live before changing InputDec.

| Selector | Stub | UIKit callers | Receiver | ABI | Classification |
| --- | ---: | --- | --- | --- | --- |
| `_performViewportLayout:` | `0x2165340` | `-[_UITextLayoutCanvasView textRangeForBounds:layoutIfNeeded:]`; `-[_UITextLayoutCanvasView layoutSubviews]` | concrete `_UITextLayoutCanvasView` | `void <- BOOL` | concrete-UIKit-only |
| `_viewportWillLayout` | `0x21b2600` | `-[_UITextLayoutCanvasView _performViewportLayout:]`; `-[_UITextLayoutCanvasView textViewportLayoutControllerWillLayout:]` | concrete `_UITextLayoutCanvasView` | `void <- no arguments` | concrete-UIKit-only |
| `_viewportDidLayout` | `0x21b25e0` | `-[_UITextLayoutCanvasView _performViewportLayout:]`; `-[_UITextLayoutCanvasView textViewportLayoutControllerDidLayout:]` | concrete `_UITextLayoutCanvasView` | `void <- no arguments` | concrete-UIKit-only |
| `_removeUnusedElementViews` | `0x21727e0` | `-[_UITextLayoutCanvasView flushElementViews]`; `-[_UITextLayoutCanvasView configureCustomTextRenderer]`; `-[_UITextLayoutCanvasView _viewportDidLayout]` | concrete `_UITextLayoutCanvasView` | `void <- no arguments` | concrete-UIKit-only |
| `updateContentSizeIfNeeded` | `0x22dcfa0` | `-[_UITextLayoutCanvasView _viewportDidLayout]`; `-[UITextView textInputDidChange:]` | concrete UIKit canvas | `void <- no arguments` | concrete-UIKit-only |
| `flushElementViews` | `0x22035a0` | `-[UITextView setCustomRenderController:]` | concrete UIKit canvas | `void <- no arguments` | concrete-UIKit-only |

The receiver-producing assembly establishes the classification independently
of the caller names:

- `textRangeForBounds:layoutIfNeeded:` preserves entry `self` in `x19`, then
  moves `x19` into `x0` immediately before the send at `0xc0888c`.
  `layoutSubviews` sends at `0xc08fa0` while entry `x0` is still the receiver.
- `_performViewportLayout:` preserves entry `self` in `x19`, then moves `x19`
  into `x0` before the will and did sends at `0xc08dc8` and `0xc08df8`.
- The viewport delegate methods preserve entry `self` in `x19` or `x20`,
  restore that register into `x0`, and send at `0xc09f30` and `0xc09f80`.
- `flushElementViews`, `configureCustomTextRenderer`, and
  `_viewportDidLayout` preserve entry `self` in `x19` or `x20`, restore it
  into `x0`, and send cleanup/content-size messages at `0xc07bb0`,
  `0xc07d30`, `0xc082b0`, and `0xc08460`.
- `UITextView textInputDidChange:` loads its private `_containerView` ivar,
  sends `canvasView`, retains that result, and sends
  `updateContentSizeIfNeeded` to the result at `0x1616fa4`.
- `UITextView setCustomRenderController:` follows the same private
  `_containerView` → `canvasView` path and sends `flushElementViews` to the
  retained result at `0x1610448`.

No caller loads an arbitrary `NSTextViewportLayoutControllerDelegate`, and no
path can obtain InputDec's `IDTextLayoutCanvasView`. InputDec is a direct
`UIView` subclass and does not instantiate UIKit's concrete
`_UITextLayoutCanvasView`.

InputDec's lifecycle entry is independent of these concrete UIKit callbacks.
`IDTextLayoutCanvasView.layoutSubviews` calls project
`performViewportLayout`; that transaction calls `id_viewportWillLayout` and
`id_viewportDidLayout` directly. The retained public
`NSTextViewportLayoutControllerDelegate` methods also call the project
`id_viewportWillLayout` and `id_viewportDidLayout` methods directly. Project
completion calls `id_removeUnusedElementViews` and
`id_updateContentSizeIfNeeded`, while project `id_flushElementViews` calls
project eviction directly. The six private forwarding selectors are therefore
redundant compatibility surface rather than InputDec lifecycle entry points.

## Canvas environment notification callbacks

This pass was reproduced against UIKitCore from iOS 26.5 build 23F73. Before
the reduction, each private selector appeared exactly twice in InputDec: once
as a declaration and once as a forwarding implementation in
`IDTextLayoutCanvasView+PrivateCallbacks.m`. The corresponding project methods
remain ordinary, directly invoked implementation hooks:

| Private selector | UIKit implementation | UIKit entry points | Concrete receiver derivation | Project entry |
| --- | ---: | --- | --- | --- |
| `isEditingDidChange` | `0xc09150` | `-[UITextView becomeFirstResponder]`; `-[UITextView _cleanUpForResignFirstResponder]` | load `UITextView._containerView`, send `canvasView`, then send to the returned UIKit canvas | `IDTextView` calls `id_isEditingDidChange` directly when first-responder state changes |
| `observeEnclosingScrollView` | `0xc06d28` | `-[_UITextContainerView setEnclosingScrollView:]` | load `_UITextContainerView._canvasView` after storing the weak enclosing-scroll-view reference | no live project caller; the `id_observeEnclosingScrollView` hook is dormant |
| `_traitsChanged` | `0xc07e0c` | registered by `-[_UITextLayoutCanvasView configureCustomTextRenderer]` | concrete canvas `self` is passed as both registration receiver and action target | `IDTextView` registers public display-scale trait observation and calls `id_traitsChanged` directly |

The editing-state sends occur at `0x160fa10` and `0x160fd44`. Both caller
sequences load the concrete `UITextView._containerView` ivar and obtain its
`canvasView`; neither accepts an arbitrary delegate or canvas. UIKit's
implementation tail-calls `requestHoverEffectsUpdate` (`0xc09174`), which
marks the concrete canvas for layout only when its `_hoverEffectsLayer` is
present.

The enclosing-scroll-view send occurs at `0x1624db4`, after
`-[_UITextContainerView setEnclosingScrollView:]` loads its own `_canvasView`
ivar. The canvas implementation asks its context whether the enclosing scroll
view was overridden and, when true, installs a geometry-change observer.
`_UITextContainerView` itself is allocated by
`-[UITextView _newContainerViewWithFrame:textContainer:textLayoutController:]`
and its initializer installs the dequeued concrete UIKit canvas. InputDec
neither creates `_UITextContainerView` nor routes its canvas through this
setter.

Trait notification uses registered-action dispatch rather than an Objective-C
message stub, so a direct caller search is intentionally empty.
`-[_UITextLayoutCanvasView configureCustomTextRenderer]` loads
`@selector(_traitsChanged)` at `0xc07d8c`–`0xc07d90` and passes the preserved
concrete canvas in both the receiver and target registers at
`0xc07d94`–`0xc07da0`. The returned token is stored in the concrete
`_traitChangeToken` ivar. The callback reads that canvas's trait collection and
invokes `_updateTraitsForCustomTextRenderer:`, which updates renderer scale
and invalidates renderer display when required.

All three selectors are therefore **concrete-UIKit-only**. None is a dynamic
callback into an arbitrary `UITextInput`, text-layout delegate, or InputDec
canvas. Removing their private forwarding declarations and implementations
does not remove InputDec behavior: editing and trait changes already enter
through direct `id_` calls, while enclosing-scroll observation has no project
caller.

## Canvas text-container-origin callbacks

This pass was reproduced against UIKitCore from iOS 26.5 build 23F73. The two
selectors were classified independently because they have different receiver
graphs. UIKitCore contains no implementations named
`-[_UITextLayoutCanvasView invalidateTextContainerOrigin]` or
`-[_UITextLayoutCanvasView textContainerOrigin]`; both names resolve only
through shared Objective-C message stubs.

### Pre-change inventory

`IDTextLayoutCanvasView+PrivateCallbacks.m` contains no separate declarations
for these selectors and contains exactly one forwarding implementation of
each:

- `invalidateTextContainerOrigin` calls the project method
  `id_invalidateTextContainerOrigin`;
- `textContainerOrigin` returns the project method
  `id_textContainerOrigin`.

The project methods remain declared in
`IDTextLayoutCanvasViewInternal.h`. The getter in
`IDTextLayoutCanvasView.m` asks the canvas context for its origin through
`IDPrivateCanvasContextTextContainerOrigin`; the invalidation hook marks the
canvas as needing layout. The origin is also consumed internally when placing
attachment and emphasis surfaces. Those project methods are distinct from the
private forwarding-selector surface.

The required non-canvas providers are:

- `IDTextView`, which returns its public text-container inset;
- `IDBlockStackCanvasView`, which converts its zero point into its outer host;
- `IDBlockTextView`, which converts the block stack's zero point into the
  editor;
- `IDBlockLayout`, whose canvas-context origin is zero;
- `IDPrivateCanvasContextTextContainerOrigin`, which dynamically reads the
  origin from the canvas context.

None of those providers is in the removal scope.

### `invalidateTextContainerOrigin`

The UIKitCore message stub is `_objc_msgSend$invalidateTextContainerOrigin` at
`0x2227200`. Its complete UIKitCore-local caller list has four entries:

| Caller/address | Send address | Receiver derivation | Can reach `IDTextLayoutCanvasView`? | State effect |
| --- | ---: | --- | --- | --- |
| `__UITextContainerViewResyncNSTextContainer` (`0x16228dc`) | `0x1622a28` | Reloads the helper's input `_UITextContainerView`; the helper is called by concrete container-view initialization and frame/bounds handling | No | Marks the same container view dirty, then the caller sends `setNeedsDisplay` |
| `-[_UITextContainerView setTextContainerInset:]` (`0x16238e8`) | `0x16239f4` | Preserved entry `self` in `x19` is restored to `x0` | No | Invalidates the cached origin, then schedules display and insertion-point updates |
| `___76-[_UITextContainerView _setFrameOrBounds:oldRect:isFrameRect:settingAction:]_block_invoke_2` (`0x16240b8`) | `0x1624108` | Loads the block's captured concrete `_UITextContainerView` from offset `0x20` | No | Invalidates origin, schedules display, posts geometry notification, and resynchronizes the text container |
| `-[_UITextContainerView setUsesStandardTextScaling:]` (`0x16249e8`) | `0x1624a04` | Entry `self` is preserved in `x19`; the weak text view is not loaded until after this send | No | Invalidates origin before updating scaling flags and zoom-scale state |

The only concrete implementation is
`-[_UITextContainerView invalidateTextContainerOrigin]` at `0x1623cc4`,
with ABI `v@:`. It loads the concrete class's `_tcvFlags` ivar, ORs bit
`0x1`, stores the byte, and returns. It does not call a delegate, context,
text input, canvas, or arbitrary receiver. InputDec neither allocates
`_UITextContainerView` nor routes its project canvas through one.

UIKitCore-local xrefs are not the complete framework boundary. A removal probe
crashed deterministically in
`-[NSTextLayoutManager updateLayoutWithTextLayoutFragment:addition:]`, which
is implemented by UIFoundation. Disassembly of the iOS 26.5 build 23F73
simulator UIFoundation binary recovered the missing chain:

| UIFoundation procedure/address | Send address | Receiver derivation | InputDec reach |
| --- | ---: | --- | --- |
| `-[NSLayoutManager(NSPrivate) _updateUsageForTextContainer:addingUsedRect:]` (`0x21d8c`) | `0x21f5c` | Calls `textView` on the supplied `NSTextContainer`, retains that result, and sends after used-rect mutation | Directly reaches a registered TextKit 1 host |
| `-[NSLayoutManager(NSPrivate) _recalculateUsageForTextContainerAtIndex:]` | `0x226ec` | Calls `textView` on the selected text container and sends after recomputing usage and resizing | Directly reaches a registered TextKit 1 host |
| `-[NSTextLayoutManager updateLayoutWithTextLayoutFragment:addition:]` (`0x43b58`) | `0x44178` | `___NSTextLayoutManagerGetTextContainerEntryAndIndexForLocation` returns entry `x21`; the send receiver is the entry's object at offset zero, the `NSTextContainer` | Reaches InputDec through the forwarding method below |
| `-[NSTextContainer(NSPrivate) invalidateTextContainerOrigin]` (`0xa5460`) | tail branch at `0xa5464` | Loads the private text-view ivar at offset `0x10` and tail-forwards the same selector | InputDec explicitly stores `IDTextLayoutCanvasView` as this private `textView` |

The TextKit 2 call occurs after the entry's used rectangle changes: the method
updates the entry, publishes KVO changes when applicable, loads its text
container, and invalidates the registered text view's origin. With the canvas
bridge removed, the ordinary nonzero-inset layout characterization terminates
with `NSInvalidArgumentException` because
`IDTextLayoutCanvasView` does not recognize the selector.

The canvas forwarding selector is therefore **externally-required** and must
remain. Its project target, `id_invalidateTextContainerOrigin`, marks the
canvas for layout, matching the invalidation required after UIFoundation
changes text-container usage.

### `textContainerOrigin`

The message stub is `_objc_msgSend$textContainerOrigin` at `0x22cec40`, with
the observed return ABI `{CGPoint=dd}@:`. UIKit's concrete
`-[_UITextContainerView textContainerOrigin]` implementation is at
`0x1623a40`. It checks dirty bit `0x1`, obtains the concrete view's text
container, used rect, bounds, size, and inset, computes and caches the
centered/offset origin in `_textContainerOrigin`, schedules display if the
cached value changed, clears the dirty bit, and returns the cached point.
That concrete implementation is not inherited or called by InputDec's
`UIView` subclass.

The getter stub is intentionally shared by many text geometry owners. This is
the complete caller list and receiver provenance:

| Caller/address | Send address | Receiver derivation | Can reach `IDTextLayoutCanvasView`? | Coordinate/state use |
| --- | ---: | --- | --- | --- |
| `sub_3e49b8` (`0x3e49b8`) | `0x3e49f8` | Direct object argument in `x1` | Possible | Applies the origin while composing input rectangle coordinates |
| `sub_3ea890` (`0x3ea890`) | `0x3ea8bc` | Direct object argument in `x1` | Possible | Applies the origin to a rectangle calculation |
| `-[UISearchTextField _characterIndexForTokenTapGestureRecognizer]` (`0x68c9c4`) | `0x68ca1c` | Preserved search text field in `x22` | No | Subtracts the field origin from the gesture point before layout lookup |
| TextKit 1 selection-rect block (`0x700254`) | `0x700420` | Accepted container/view from the enumerated receiver array | Possible for a supplied host | Adds the origin to selection rectangles |
| `-[_UITextKit1LayoutController boundingRectForCharacterRange:]` (`0x701fc8`) | `0x702104` | Layout controller's retained coordinate-space host in `x22` | Possible for a supplied host | Offsets the computed character bounding rect |
| `-[_UITextLayoutBaselineCalculator _baselineOffsetAtPosition:]` (`0xb5f660`) | `0xb5f75c` | Stored text-container/coordinate host at calculator offset `0x28`; guarded by its `textView` being nonnil | Possible | Uses the vertical origin for baseline offset |
| `-[_UITextLayoutCanvasView _updateRenderingSurfaceViewsForTextRange:inTextView:bounds:]` (`0xc070e8`) | `0xc07338` | Result of concrete canvas `context` | No direct canvas reach; InputDec's context is its host text view | Adds context origin when positioning highlight surfaces |
| `-[_UITextLayoutCanvasView frameForAnchoredTextAttachment:associatedLayoutFragment:]` (`0xc07840`) | `0xc078d8` | Result of concrete canvas `context` | No direct canvas reach | Adds context origin to the layout-fragment frame |
| `-[_UITextLayoutCanvasView viewportBoundsForTextViewportLayoutController:]` (`0xc091e8`) | `0xc09240` | Result of concrete canvas `context` | No direct canvas reach | Converts canvas bounds into text-container coordinates once |
| `-[_UITextLayoutCanvasView textViewportLayoutController:renderingSurfaceForTextLayoutFragment:]` (`0xc09630`) | `0xc09670` | Result of concrete canvas `context` | No direct canvas reach | Offsets rendering-surface placement |
| `-[_UITextLayoutCanvasView textViewportLayoutController:configureRenderingSurfaceForTextLayoutFragment:]` (`0xc09a28`) | `0xc09a78` | Result of concrete canvas `context` | No direct canvas reach | Offsets configured rendering geometry |
| `-[_UITextLayoutCanvasView drawTextInRect:]` (`0xc0a478`) | `0xc0a4c0` | Result of concrete canvas `context` | No direct canvas reach | Builds the draw translation from the context origin |
| `-[_UITextKit2LayoutController _visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:]` (`0xc3c910`) | `0xc3ca94` | Result of `textContainerForLocation:` | Possible for an InputDec-managed container graph | Subtracts the origin before constraining the visual-selection point |
| TextKit 2 selection-rect block (`0xc3e52c`) | `0xc3e584` | Object selected from the captured container/host array | Yes in a controller initialized with InputDec's canvas host | Adds the origin to selection rectangles |
| `-[_UITextKit2LayoutController boundingRectForRange:]` (`0xc408dc`) | `0xc40a28` | Captured nonnil coordinate-space host at block offset `0x28` | Yes in a controller initialized with InputDec's canvas host | Offsets the enumerated text-segment union |
| `-[_UITextViewCanvasView drawTextInRect:]` (`0x159055c`) | `0x1590664` | Concrete legacy canvas `self` in `x19` | No | Stores origin in the glyph drawing context |
| Legacy canvas draw block (`0x1590744`) | `0x1590794` | Captured concrete legacy canvas at block offset `0x30` | No | Stores origin before glyph-range drawing |
| `-[_UITextFieldCanvasView drawTextInRect:]` (`0x159087c`) | `0x15909f0` | Concrete text-field canvas saved in the stack frame | No | Adds origin to TextKit 1 draw geometry |
| `-[_UISearchTextFieldCanvasView _updateTokenViews]` (`0x1590dcc`) | `0x1590e3c` | Result of concrete search-field canvas `context` | No | Offsets token views |
| `-[UITextField _updateBaselineInformationDependentOnBoundsAllowingInvalidation:]` (`0x15cb800`) | `0x15cb94c` | Concrete `UITextField self` in `x19` | No | Supplies fallback origin to the baseline calculator |
| `-[UITextField textContainerOrigin]` (`0x15ce1f8`) | `0x15ce204` | Loads the field's concrete private container-view ivar | No | Tail-forwards the container view's cached origin |
| `-[UITextField _visibleRangeWithLayout:]` (`0x15da82c`) | `0x15da954` | Concrete `UITextField self` in `x19` | No | Negates the origin before visible-range intersection |
| `-[UITextInputController _characterPositionForPoint:]` (`0x15ec46c`) | `0x15ec584` | Enumerates the layout manager's text containers, calls `textView`, retains that arbitrary result in `x21`, checks geometry eligibility and `respondsToSelector:`, then sends to that result | **Yes**: InputDec sets its `NSTextContainer.textView` to `IDTextLayoutCanvasView` | Subtracts the origin exactly once before bounds testing and character lookup |
| `-[UITextInputController caretRectForPosition:]` (`0x15f089c`) | `0x15f09f0` | Coordinate-space/container host returned through the layout insertion-rect out parameter | Possible in InputDec's controller graph | Adds the origin exactly once to the insertion rect |
| `-[UITextView _updateContentSize]` (`0x160d0f4`) | `0x160d234` | Concrete `UITextView._textContainer` | No direct canvas reach | Uses origin with container/view bounds to derive content size |
| `___37-[UITextView _baselineOffsetsAtSize:]_block_invoke` (`0x160e230`) | `0x160e294` | Captured concrete `UITextView` | No | Supplies fallback origin to the baseline calculator |
| `-[UITextView _rectForScrollToVisible:]` (`0x1614340`) | `0x16144a4` | Concrete `UITextView._textContainer` | No direct canvas reach | Adds origin before conversion through the container's text view |
| `-[UITextView textContainerOrigin]` (`0x1618580`) | `0x161858c` | Loads concrete `UITextView._containerView` | No | Tail-forwards the concrete container-view origin |
| `-[UITextView _textInteractableItemAtPoint:precision:]` (`0x161dbf8`) | `0x161dc34` | Concrete `UITextView._textContainer` | No direct canvas reach | Subtracts origin before interactable-item hit testing |
| `-[UITextView _textInteractableItemForTag:]` (`0x161e348`) | `0x161e4a0` | Text container loaded from an enumerated concrete `UITextView` | No direct canvas reach | Adds origin to candidate item bounds |
| `-[_UITextContainerView _ensureLayoutCompleteForRect:]` (`0x16251f0`) | `0x16252b0` | Concrete container-view `self` in `x20` | No | Converts the requested rect into container coordinates |
| `-[_UIBoundingTextRectsSolver _calculateRectsUsingTextLayoutManager:]` (`0x164258c`) | `0x16425c8` | Solver's stored coordinate-space host at offset `0x98` | Possible when initialized for an InputDec host | Adds origin to TextKit 2 bounding-text rectangles |
| `-[_UIBoundingTextRectsSolver _calculateRectsUsingLayoutManager:]` (`0x16427f4`) | `0x1642830` | Same stored coordinate-space host at offset `0x98` | Possible when initialized for an InputDec host | Adds origin to TextKit 1 bounding-text rectangles |

The decisive live path is
`-[UITextInputController _characterPositionForPoint:]`. InputDec explicitly
registers its canvas as the text container's private `textView` using
`IDPrivateTextContainerSetTextView(_id_textContainer, _id_canvasView)`.
UIKit enumerates that container, obtains the registered canvas, verifies that
it responds to `textContainerOrigin`, and subtracts the returned point before
hit testing. Removing the canvas getter would therefore change cursor
placement and can make that optional send fall back to zero.

The canvas getter is **externally-required** and must remain. Its returned
value is the context origin, and the inspected paths either add it when
converting layout coordinates outward or subtract it when converting view
coordinates inward; no inspected InputDec path composes a second inset around
the same send.

### Required non-canvas origin providers

The `IDTextView`, `IDBlockStackCanvasView`, `IDBlockTextView`, and
`IDBlockLayout` implementations remain required by the context, block-layout,
selection, caret, and conversion graphs described above. The context helper
also remains required by project rendering, attachment, and emphasis
placement. A canvas-only source audit must not use repository-wide selector
counts as its removal oracle.

### Independent reduction decisions

| Canvas selector | Classification | Decision |
| --- | --- | --- |
| `invalidateTextContainerOrigin` | **externally-required** | Retain the `IDTextLayoutCanvasView` forwarding implementation unchanged |
| `textContainerOrigin` | **externally-required** | Retain the `IDTextLayoutCanvasView` forwarding implementation unchanged |

The project-owned `id_invalidateTextContainerOrigin` and
`id_textContainerOrigin` methods both remain. No non-canvas provider, context
helper, block-layout callback, origin calculation, or coordinate conversion
is removed or renamed. This pass removes no origin callback.

## Canvas controller-getter callbacks

This pass was reproduced against UIKitCore and UIFoundation from iOS 26.5
build 23F73. The selector family was classified per member:

- `textLayoutController`;
- `layoutManager`;
- `customRenderController`.

The pre-change canvas category forwards those names to three project methods.
Those project methods remain authoritative and are not part of the removal:

| Project method | Exact behavior |
| --- | --- |
| `id_textLayoutController` | returns `self.textLayoutManager.delegate` |
| `id_layoutManager` | deliberately returns `nil` |
| `id_customRenderController` | returns the optional renderer supplied by the canvas context |

Required non-canvas providers also remain. `IDTextView` and
`IDBlockTextView` provide `textLayoutController`;
`IDRichTextLayoutController` and `IDBlockLayout` provide `layoutManager`; and
the text-view, block-text-view, block-layout, and interaction contexts provide
`customRenderController`. The dynamic context renderer lookup in
`IDPrivateUIKit+TextLayoutCanvas.m` is likewise outside the canvas-selector
removal.

### ABI and implementations

All three getters have the object-returning Objective-C ABI `@16@0:8`
(`@@:`). UIKitCore contains these relevant implementations and shared message
stubs:

| Selector/implementation | Address | ABI/behavior |
| --- | ---: | --- |
| `_objc_msgSend$textLayoutController` | `0x22d0120` | shared object-return send |
| `-[_UITextLayoutCanvasView _internalTextLayoutController]` | `0xc08724` | obtains `context`, then sends `textLayoutController` to that context |
| `_objc_msgSend$layoutManager` | `0x2236360` | shared object-return send |
| `_objc_msgSend$customRenderController` | `0x21e6360` | shared object-return send |
| `-[_UITextLayoutCanvasView customRenderController]` | `0xc06df8` | loads weak `_context`, checks the context for the selector, and forwards to the context |
| `-[_UITextContainerView layoutManager]` | `0x1623600` | forwards to its weak delegate |
| `-[_UITextContainerView customRenderController]` | `0x1623738` | forwards to its weak delegate |
| `-[_UITextContainerView textLayoutController]` | `0x1625888` | forwards to its weak delegate |

UIKitCore has no implementation named
`-[_UITextLayoutCanvasView textLayoutController]` or
`-[_UITextLayoutCanvasView layoutManager]`. The concrete UIKit canvas uses
`_internalTextLayoutController` for the former and has no canvas
`layoutManager` getter.

### UIKitCore `textLayoutController` callers

The complete UIKitCore stub xref list is:

```text
0x54672c 0x68ca40 0x68e368 0x68e8f0 0xc08744
0x10e0970 0x10e0ab8
0x11220e8 0x11221dc 0x1122224 0x112230c 0x1124210 0x1124e64
0x13c8b9c 0x13c8e74 0x13c9204 0x13c92fc
0x158f7d0 0x158f82c 0x158f9bc 0x158fbd0
0x15badf8 0x15cb924 0x15d3a24 0x15d78d4
0x15fff7c 0x1600100 0x160aeac 0x160f50c 0x161375c 0x162158c
```

The caller and receiver ledger is:

| Caller/address family | Receiver derivation | Can reach `IDTextLayoutCanvasView`? | Return-value use |
| --- | --- | --- | --- |
| `_UITextLinkInteractionHandler` (`0x54672c`) | text input recovered from the link interaction; InputDec supplies its outer `IDTextView` | No | obtains the text layout controller for link sharing |
| `UISearchTextField` (`0x68ca40`, `0x68e368`, `0x68e8f0`) | concrete search field | No | token lookup, cut, and atom selection |
| `_UITextLayoutCanvasView._internalTextLayoutController` (`0xc08744`) | result of concrete canvas `context`; assembly loads `context` before the send | No direct canvas reach | returns the context controller after a capability check |
| `UIKBAutofillController` (`0x10e0970`, `0x10e0ab8`) | supplied text field | No | reads document range to add/remove temporary color |
| `_UITextAssistantManager` (`0x11220e8`, `0x11221dc`, `0x1122224`, `0x112230c`, `0x1124210`, `0x1124e64`) | retained weak text input at manager offset `0x68`; InputDec installs `IDTextView` | No | document-range, preview, and viewport invalidation work |
| animated insertion (`0x13c8b9c`, `0x13c8e74`, `0x13c9204`, `0x13c92fc`) | concrete `UITextView` or `UITextField` | No | replacement animation layout |
| `_UITextCanvasView` (`0x158f7d0`, `0x158f82c`, `0x158f9bc`, `0x158fbd0`) | result of the concrete legacy canvas context lookup | No | debug baselines and tiled-layer masking |
| `UIFieldEditor`/`UITextField` (`0x15badf8`, `0x15cb924`, `0x15d3a24`, `0x15d78d4`) | concrete field/editor or its delegate | No | controller forwarding, baseline data, and layout invalidation |
| `_UITextInputControllerTokenizer` (`0x15fff7c`, `0x1600100`) | tokenizer's weak text input/controller | No; InputDec supplies a non-canvas controller host | positional and token-range geometry |
| `UITextView` (`0x160aeac`, `0x160f50c`, `0x161375c`, `0x162158c`) | concrete text view `self` | No | attributed-text, baseline, placeholder, and internal-controller work |

No caller obtains `NSTextContainer.textView` before this selector send.
InputDec constructs `_UITextKit2LayoutController` with the outer
`IDTextView`, so its generic text-input/controller paths resolve through the
preserved `IDTextView.textLayoutController`, not through the canvas.

### UIKitCore `customRenderController` callers

The complete UIKitCore stub xref list is:

```text
0xc06e3c 0xc07a84 0xc07c1c 0xc07e88 0xc08004 0xc082b8
0xc08d4c 0xc08fdc 0xc096a4 0xc09ba8 0xc09ee8 0xc09f00
0xc09f88 0xc0a380 0xc0a3b0 0xc0a44c
0xc3e154 0xc3e1a0
0x16107cc 0x161084c 0x161090c 0x1623758
```

| Caller/address family | Receiver derivation | Can reach `IDTextLayoutCanvasView`? | Return-value use |
| --- | --- | --- | --- |
| concrete `_UITextLayoutCanvasView` (`0xc06e3c`, `0xc07a84`, `0xc07c1c`, `0xc07e88`, `0xc08004`, `0xc082b8`, `0xc08d4c`, `0xc08fdc`, `0xc096a4`, `0xc09ba8`, `0xc09ee8`, `0xc09f00`, `0xc09f88`, `0xc0a380`, `0xc0a3b0`, `0xc0a44c`) | either the concrete canvas `self`, a block-captured concrete canvas, or its weak `_context` | No: InputDec's canvas is a `UIView` subclass, not this class | renderer identity, layout lifecycle, traits, surface configuration, and invalidation |
| `_UITextKit2LayoutController` selection-rect block (`0xc3e154`, `0xc3e1a0`) | weak `_textView` ivar of the controller | No: InputDec initializes the controller with outer `IDTextView` | tests optional renderer enumeration and invokes renderer segment enumeration |
| `UITextView` conversion (`0x16107cc`, `0x161084c`, `0x161090c`) | concrete text view `self` | No | converts points to/from custom render space |
| `_UITextContainerView.customRenderController` (`0x1623758`) | weak delegate of a concrete `_UITextContainerView` | No: InputDec neither allocates nor embeds its canvas in `_UITextContainerView` | returns the delegate renderer |

The concrete canvas implementation at `0xc06df8` is itself a context
forwarder. InputDec's equivalent project behavior remains directly available
through `id_customRenderController` and through the non-canvas context
providers; none of the external sends above targets the project canvas.

### UIKitCore `layoutManager` callers

The complete UIKitCore xref set contains 103 sends. It partitions into the
following receiver families:

| Caller/address family | Exact send addresses | Receiver derivation | Canvas reach |
| --- | --- | --- | --- |
| accessibility/search token UI | `0x4f7168`, `0x4f737c`, `0x4f7474`, `0x6befe0` | concrete HUD labels or attachment text containers | No |
| `_UITextKit1LayoutController` | `0x6fe7e4`, `0x6fe984`, `0x6feb6c`, `0x6febe8`, `0x6fee4c`, `0x6ff2ec`, `0x6ffd34`, `0x700068`, `0x70015c`, `0x7006fc`, `0x700a74`, `0x700bd8`, `0x700d38`, `0x700dc8`, `0x700e4c`, `0x700ed4`, `0x700f5c`, `0x700fdc`, `0x7010cc`, `0x701240`, `0x70127c`, `0x7013f4`, `0x701520`, `0x7015ac`, `0x701844`, `0x7019d8`, `0x701a40`, `0x701a94`, `0x701b24`, `0x701bf8`, `0x701c70`, `0x701ed4`, `0x701fcc`, `0x702254`, `0x70248c`, `0x702530`, `0x702568`, `0x7025b4`, `0x7025f0`, `0x702630` | concrete controller `self`, its concrete text view, or supplied TextKit 1 manager/container | No; InputDec uses the TextKit 2 controller and does not pass its canvas to this initializer |
| collection/status/table layout managers | `0x7f247c`, `0x12bfed0`, `0x12c5bf4`, `0x12c5c48`, `0x12c9c40`, `0x12dd1a4`, `0x12dd41c`, `0x12dd8e0`, `0x12dd99c`, `0x1409d04`, `0x140b2e4`, `0x140dc30`, `0x140dca8`, `0x140dd20`, `0x140dd9c`, `0x140de08`, `0x140de90`, `0x1412a3c`, `0x1412d04`, `0x1412dd0`, `0x1412e1c`, `0x1412e70`, `0x1413284`, `0x14133a0`, `0x14136e8`, `0x1414388`, `0x1414404`, `0x14174d4`, `0x147c944`, `0x1480330`, `0x1481908` | concrete UI layout-manager properties unrelated to text canvas | No |
| drag preview/attachment/legacy canvases | `0x14f4ae0`, `0x14f5110`, `0x14f56a8`, `0x14f576c`, `0x158af2c`, `0x1590430`, `0x1590600`, `0x15909c8`, `0x1590e6c` | retained text layout controller, `NSTextContainer`, or concrete TextKit 1 canvas | No |
| field/input/text view | `0x15bb1f8`, `0x15ccc20`, `0x15e5c20`, `0x16085e4`, `0x1609e4c`, `0x160afb0`, `0x160b19c`, `0x160e5f4`, `0x1610be0`, `0x1610c54` | field/view `self`, stored text layout controller, or supplied controller | No; the project controller's own `layoutManager` implementation remains |
| `_UITextContainerView` | `0x1623658`, `0x16239d4`, `0x1624664`, `0x16246f8`, `0x1624b18`, `0x1625180`, `0x162525c`, `0x1625568` | concrete container view `self`, its weak delegate, or its stored controller | No: InputDec does not create this class |
| `_UIBoundingTextRectsSolver` | `0x1642518` | stored layout controller at offset `0x98` | No; this reaches a controller provider, not the canvas |

There is no `_UITextLayoutCanvasView` caller in this set. In particular,
UIKit's TextKit 2 canvas never asks itself for `layoutManager`.

### UIFoundation closure

UIFoundation contains neither the `textLayoutController` nor
`customRenderController` selector, implementation, or message stub. Its only
member of this family is `_objc_msgSend$layoutManager` at `0x1548e0`.
Disassembly yields the following complete 67-send set:

```text
0xd8ec 0x29228 0x2f040 0x31f04 0x31f18
0x32740 0x32760 0x327ac 0x327cc 0x328a8 0x328c8 0x37b44
0x71bc4 0x74f68 0x77b6c 0x77f28 0x8f05c 0x8f08c
0x92884 0x92894 0x928a8 0x928bc 0x928d0 0x928e4 0x928f8
0x92928 0x9295c 0x92a28 0x92a64 0x92ac4 0x92ba8 0x92bb8 0x92bc8
0xa10b8 0xa2870 0xa2888 0xa28a0 0xa2c74
0xa3fac 0xa40a4 0xa4110 0xa4428 0xa4588 0xa4ef8 0xa4f04
0xae5e4 0xb45c4 0xb47d8 0xb4e54 0xb4e74 0xb4f30 0xb4f50
0xb5000 0xb5020 0xb50cc 0xb50ec 0xb5138 0xb5258
0xbb63c 0xbc674 0xe4b50 0xe6608 0xe66d0
0xf00d8 0xf01d0 0xf0524 0xf09bc
```

Every receiver is a concrete UIFoundation text object or an explicitly
supplied TextKit object: `NSTextLayoutFragment`, `NSLayoutManager`,
`NSATSTypesetter`, `NSSingleLineTypesetter`, `NSStringDrawingTextStorage`,
`NSTextContainer`, `NSTypesetter`, `NSTextAttachment`, `NSATSLineFragment`,
`NSTextBlock`, or `NSTextTable`. The `NSTextContainer` callers send to the
container itself; the attachment callers obtain the manager from their
supplied text container. None loads `NSTextContainer.textView` and none sends
`layoutManager` to the registered canvas host.

This differs from the externally required origin callbacks: the
UIFoundation origin path explicitly loads `NSTextContainer.textView`, while
the three getter paths do not.

### InputDec reachability and decisions

InputDec constructs `_UITextKit2LayoutController` with outer `IDTextView`,
registers `IDTextLayoutCanvasView` only in the controller's container-to-canvas
map, and separately stores the canvas as `NSTextContainer.textView` for the
origin callbacks. The inspected getter callers use the first host/controller
relationship or concrete UIKit/UIFoundation objects; none follows the
container's `textView` link to the canvas.

| Canvas selector | Classification | Decision |
| --- | --- | --- |
| `textLayoutController` | **public-or-project-duplicate** | Remove only the canvas forwarder; preserve `IDTextView`, `IDBlockTextView`, and `id_textLayoutController` |
| `layoutManager` | **public-or-project-duplicate** | Remove only the canvas forwarder; preserve rich/block layout-controller providers and deliberate `id_layoutManager == nil` semantics |
| `customRenderController` | **public-or-project-duplicate** | Remove only the canvas forwarder; preserve all context/interaction providers and `id_customRenderController` |

No ambiguous receiver remains across the two frameworks. The private canvas
selector family is therefore removable, while the project-owned getter
semantics and every non-canvas provider remain unchanged.

## Canvas state-getter callbacks

This pass was reproduced against UIKitCore and UIFoundation from iOS 26.5
build 23F73. The independently classified selector family is:

- `textColor`;
- `isEditable`;
- `isEditing`.

The pre-change canvas category forwards those selectors to project-owned
methods. Those methods remain authoritative and are not part of the removal:

| Project method | Exact behavior |
| --- | --- |
| `id_textColor` | obtains the context color and falls back to `UIColor.labelColor` for nil context |
| `id_isEditable` | obtains required `isEditable` state from a nonnil context and returns `NO` for nil context |
| `id_isEditing` | obtains optional `isEditing` state from the context and returns `NO` for nil or nonparticipating context |

Required non-canvas providers remain. `IDTextView`, `IDBlockTextView`,
`IDBlockLayout`, text interaction contexts, `UITextInputController`, and the
private TextKit 2 layout controller use outer text-input/controller objects,
not the registered canvas, for state. The dynamic context sends in
`IDPrivateUIKit+TextLayoutCanvas.m` likewise remain project-owned behavior.

### ABI and implementations

`textColor` has the object-returning ABI `@16@0:8` (`@@:`). `isEditable` and
`isEditing` have the Boolean-returning ABI `B16@0:8` (`B@:`). UIKitCore
contains these shared stubs and relevant concrete implementations:

| Selector/implementation | Address | ABI/behavior |
| --- | ---: | --- |
| `_objc_msgSend$textColor` | `0x22cea60` | shared object-return send |
| `_objc_msgSend$isEditable` | `0x2229960` | shared Boolean-return send |
| `_objc_msgSend$isEditing` | `0x22299c0` | shared Boolean-return send |
| `-[_UITextContainerView textColor]` | `0x1624ce0` | loads weak `_textView`, forwards `textColor`, and returns the retained color |
| `-[_UITextContainerView isEditable]` | `0x1624e14` | loads weak `_textView` and forwards `isEditable` |
| `-[_UITextContainerView isEditing]` | `0x1624e50` | loads weak `_textView` and forwards `isEditing` |
| `-[UITextInputController isEditable]` | `0x15e9364` | loads weak text input at offset `0x98` and forwards |
| `-[UITextInputController isEditing]` | `0x15e9398` | loads weak text input at offset `0x98` and forwards |
| `-[_UITextKit2LayoutController isEditable]` | `0xc41ce8` | returns the controller's stored editable state |

UIKitCore has no implementation named
`-[_UITextLayoutCanvasView textColor]`,
`-[_UITextLayoutCanvasView isEditable]`, or
`-[_UITextLayoutCanvasView isEditing]`. The methods added by InputDec were
compatibility forwarders, not mirrors of concrete UIKit canvas methods.
If those forwarders are removed, `isEditable` and `isEditing` still
participate in ordinary inherited lookup through `UIResponder`.
`-[UIResponder isEditable]` at `0x10c7ebc` derives state from its text
interaction mode, while `-[UIResponder isEditing]` at `0x10c7f08`
tail-calls `isFirstResponder`. Behavioral certification subsequently proved
that inherited `isEditing` is not semantically equivalent to InputDec's
context-backed override, so only the `isEditable` observation applies to the
final removal.

### UIKitCore `textColor` callers

The complete UIKitCore stub xref set contains 91 sends:

```text
0x25e44c 0x50bfd0 0x642f2c 0x642f64 0x64328c 0x681c98
0x681e70 0x6a6c38 0x6aa5e8 0x6b5354 0xb6a460 0xb6aac0
0xbd4e4c 0xbd645c 0xd9db64 0xd9de04 0xd9e098 0xdadbe8
0xdadc44 0xdbccbc 0xdbd0a8 0xdbddb8 0xdbe0a0 0xe07d3c
0xe07e50 0xe78528 0xe7bfcc 0xe85708 0xe8dd60 0xe8e318
0xe8e624 0xea7b00 0xea7b1c 0xea80b8 0xea80d4 0xeae634
0xeaf824 0xeafab0 0xeafe58 0xeb1124 0xeb1160 0xeb13a4
0xebb018 0xebb0c8 0xf5ef8c 0x10ec728 0x129a900 0x12cc2ac
0x12ec9d8 0x12eccf8 0x12ecdc0 0x12ed024 0x12ed0e4
0x12f104c 0x1324f88 0x133856c 0x1380c74 0x13a4bc0
0x13a50d0 0x13a50ec 0x13c8b24 0x13c918c 0x140ac98
0x142c17c 0x15bc68c 0x15bd4c0 0x15bd7ac 0x15c389c
0x15c4be8 0x15c4c04 0x15cc408 0x15ce824 0x15ce840
0x15cf3b8 0x15d1570 0x15d5c58 0x15d5d80 0x15d5dc0
0x160a074 0x160a090 0x1624d00 0x1669bd0 0x1669e18
0x166a448 0x175db0c 0x175efcc 0x1764204 0x1765294
0x176530c 0x176ccf4 0x1894bbc
```

| Caller family | Receiver derivation | Can reach `IDTextLayoutCanvasView`? | Return-value use |
| --- | --- | --- | --- |
| labels, badges, search bars, status bar, pickers, and table cells | concrete UI component `self` or its concrete configuration | No | component styling, equality, encoding, and drawing |
| keyboard candidate, menu, render-factory, and key-style paths | concrete keyboard style or label objects | No | key glyph and candidate rendering |
| `UITextField`, `UIFieldEditor`, and concrete `UITextView` | concrete field/editor/view `self`, typing attributes, or label | No | typing color, attributed text, encoding, and replacement animation |
| `UILabel` and web document paths | concrete label or web view | No | synthesized attributes and caret color |
| `_UITextContainerView.textColor` (`0x1624d00`) | weak `_textView` of a concrete `_UITextContainerView` | No; InputDec does not allocate this container class | returns the owning stock text view's color |

No send targets `_UITextLayoutCanvasView`, a canvas context, or
`NSTextContainer.textView`.

### UIKitCore `isEditable` callers

The complete UIKitCore stub xref set contains 75 sends:

```text
0x49b75c 0x69f998 0x6d6eec 0x7a0cd0 0x7a0d1c 0xb23d88
0xb2493c 0xbc6d50 0xc3b50c 0xdd8ff4 0xe24d58 0xe96498
0xe965c4 0xe97040 0xf7b168 0xfd5c54 0x1247d38
0x124cd40 0x124e180 0x14f1600 0x14f25d8 0x1514c34
0x1515804 0x15158d0 0x1515b18 0x15183f0 0x1518690
0x1518a58 0x151cca0 0x1539f24 0x153f500 0x1565e54
0x1565fa0 0x156643c 0x1567d34 0x1567dcc 0x1567eb4
0x1568240 0x156834c 0x156a5b0 0x1576350 0x1576390
0x157a078 0x1581a54 0x1581c08 0x158565c 0x158568c
0x15c62c4 0x15d1b88 0x15d6d90 0x15e937c 0x15f6818
0x1603278 0x160a130 0x160f7c4 0x160f994 0x160fd18
0x1610d54 0x1611c88 0x1616570 0x1619fc8 0x161b2a4
0x161ceb8 0x1620db4 0x162106c 0x1624e34 0x1640d18
0x17816e4 0x1783de0 0x1828a28 0x186acf4 0x1885e30
0x188f4dc 0x1893544 0x1895c90
```

| Caller family | Receiver derivation | Can reach `IDTextLayoutCanvasView`? | Return-value use |
| --- | --- | --- | --- |
| keyboard, dictation, responder, drag, writing-tools, and focus paths | current or supplied text input | No; InputDec supplies outer `IDTextView` or `IDBlockTextView` | mutation eligibility, keyboard requirements, and focus |
| loupe, refinement, selection, and interaction assistant paths | assistant's retained interaction/text-input host | No; InputDec installs interaction on the outer editor | gesture, painting, and editable-selection policy |
| `UITextContentView`, `UITextField`, and concrete `UITextView` | concrete view `self` | No | responder, data detector, formatting, and restoration decisions |
| `_UITextKit2LayoutController` initializer (`0xc3b50c`) | weak `_textView` loaded from initializer argument `x19` | No; InputDec passes its outer editor to this initializer | initializes `breaksLinesForInteractiveText` |
| `UITextInputController.isEditable` (`0x15e937c`) | controller's weak text input at offset `0x98` | No; this is the outer InputDec text input | forwards editable state |
| `_UITextContainerView.isEditable` (`0x1624e34`) | weak `_textView` of concrete `_UITextContainerView` | No; InputDec does not instantiate this class | forwards stock text-view state |
| tab/sidebar/web and unrelated collection UI | concrete component `self` | No | component edit/customization state |

No caller follows `NSTextContainer.textView` to the registered canvas.

### UIKitCore `isEditing` callers

The complete UIKitCore stub xref set contains 247 sends:

```text
0x4c28e8 0x56ace8 0x56b2d4 0x56b3e0 0x56b4e0 0x56b5ac
0x56b6e4 0x56b8e0 0x56b99c 0x5b7d9c 0x5f74b0 0x5f7898
0x682a24 0x684cd4 0x685730 0x686350 0x68642c 0x6870c0
0x687588 0x6884a8 0x697c60 0x7a0cb0 0x7a8454 0x7c08a4
0x7c0af4 0x7e4e18 0x7e4e44 0x7e6a78 0x7ea514 0x7eab24
0x7f2c48 0x7f2c68 0x7f2c88 0x7fcf1c 0x7fddac 0x825c2c
0x858bfc 0x8ee488 0x906074 0x94e52c 0x9ad418 0x9ade40
0x9ade9c 0x9ae13c 0x9e004c 0x9f5c2c 0xb10e34 0xb23aa0
0xb240b4 0xb24280 0xb67f1c 0xba2aa4 0xba2af0 0xbc6a54
0xbd93cc 0xbee588 0xbee6f0 0xc09ccc 0xd0c1d0 0xd65a58
0xe96fa0 0xf1802c 0x1015fd8 0x101a0e0 0x110d590
0x12cbd70 0x12cc160 0x1362d70 0x1363728 0x1363928
0x1363b64 0x13651dc 0x1365444 0x1365b48 0x13663d8
0x1366a24 0x1366f24 0x1367d60 0x1367ea8 0x1367f1c
0x1368300 0x13684c0 0x13687c0 0x136890c 0x13cdb5c
0x13fa948 0x13fa9b4 0x13faa34 0x13faac0 0x13fab3c
0x13fac1c 0x13facc8 0x13fbe40 0x13fc5c0 0x13fc5dc
0x13fd974 0x13fd990 0x140b2f8 0x140dc44 0x140dcbc
0x140de1c 0x140dea4 0x140fe54 0x1410dc8 0x1410de8
0x1411134 0x14111c4 0x14111e4 0x14112c8 0x1411468
0x14114a8 0x14114c8 0x1412a50 0x1413298 0x14133b4
0x14136fc 0x141439c 0x1414418 0x1414454 0x1419860
0x1419954 0x141a0fc 0x1435c98 0x14360e8 0x14374d4
0x14374f8 0x1437560 0x1437584 0x14375ec 0x143790c
0x1437af4 0x1467adc 0x1467b8c 0x1467c10 0x148030c
0x148f518 0x1493f08 0x1498874 0x14bac74 0x14f0528
0x1515810 0x1515b88 0x1516a5c 0x1517540 0x151757c
0x1518354 0x151884c 0x151cc88 0x1534090 0x157f9f4
0x15c9df8 0x15cbde8 0x15cbffc 0x15cc3f0 0x15cc588
0x15cf558 0x15cf690 0x15d26f8 0x15d3b90 0x15d3df4
0x15d3e60 0x15d3f58 0x15d3ff0 0x15d566c 0x15d59ac
0x15e93b0 0x15f60a0 0x15f62e4 0x15f6304 0x15f6364
0x15f64a4 0x15f6544 0x15f678c 0x15f67b4 0x15f6abc
0x16033fc 0x1603550 0x160cb84 0x160ce78 0x160d6ac
0x160f74c 0x160fbc4 0x160fc6c 0x16184fc 0x161878c
0x1624e70 0x16f8efc 0x16f8fa0 0x176eb08 0x176ecf8
0x177dab0 0x177e378 0x177f6d8 0x177fb30 0x177fd08
0x17809c0 0x1780c18 0x17811a8 0x1781594 0x1781698
0x17816f0 0x1782158 0x1782290 0x1782818 0x1782e10
0x1782f20 0x178376c 0x1783a84 0x178784c 0x1787c50
0x1787e24 0x187f694 0x187f8cc 0x1880b00 0x1881454
0x18814dc 0x18815d8 0x18818ec 0x1882f18 0x1883480
0x188360c 0x1884b1c 0x1885b10 0x1885da8 0x1885e1c
0x1886654 0x1887c34 0x1887e9c 0x1888010 0x1888170
0x18881e8 0x1888368 0x1888498 0x18885b0 0x1888968
0x1888ad4 0x1888bd0 0x1888e04 0x188904c 0x18896ec
0x1889b34 0x18930a0 0x1895ce0 0x18a5474 0x18ac934
0x18f9ae4 0x18f9b20
```

| Caller family | Receiver derivation | Can reach `IDTextLayoutCanvasView`? | Return-value use |
| --- | --- | --- | --- |
| keyboard state, autocorrection, dictation, responder-action, and input-controller paths | current or retained text input | No; InputDec supplies the outer editor | candidate acceptance, responder action, and keyboard state |
| loupe, refinement, interaction, selection, and edit-menu paths | retained interaction/text-input host | No; InputDec installs these owners on the outer editor | gesture, menu, selection, and visibility policy |
| concrete search, field, content, web, and `UITextView` paths | concrete view `self` | No | controls, responder behavior, scrolling, and restoration |
| `_UITextLayoutCanvasView` rendering callback (`0xc09ccc`) | weak `_context` loaded from concrete canvas offset through `objc_loadWeakRetained` | No direct canvas reach; InputDec's equivalent context providers remain | hides or shows the concrete hover-effects layer |
| `UITextInputController.isEditing` (`0x15e93b0`) | controller's weak text input at offset `0x98` | **Yes at runtime**; InputDec's private controller resolves this weak input to `IDTextLayoutCanvasView` through the layout-controller/container graph | forwards active editing state into responder-action policy |
| `_UITextContainerView.isEditing` (`0x1624e70`) | weak `_textView` of concrete `_UITextContainerView` | No; InputDec does not instantiate this class | forwards stock text-view state |
| table, collection, tab, sidebar, and navigation UI | concrete component `self`, model, or configuration | No | component editing appearance and interaction |

The single concrete `_UITextLayoutCanvasView` procedure in the static set does not
send to canvas `self`: assembly at `0xc09cb8`–`0xc09ccc` loads the weak
`_context` before the send. Its return only gates the native hover-effects
layer. That result does not close the generic `UITextInputController`
receiver: live instrumentation proves that controller forwarding can reach
InputDec's canvas.

### Block interaction-host `isEditing` withdrawal ledger

This August 8, 2026 follow-up separates the outer duck-typed
`IDBlockTextView` candidate from the required `IDTextLayoutCanvasView`
provider above. The shared selector stub remains `_objc_msgSend$isEditing` at
`0x22299c0`. `-[UIResponder isEditing]` at `0x10c7f08` is a one-instruction
tail branch to `isFirstResponder`; therefore deleting only the class-local
block provider does **not** make the selector unrecognized. Ordinary lookup
continues through the direct superclass and changes the predicate from
`isFirstResponder && isEditable` to `isFirstResponder`. That predicate change,
rather than selector absence, is the exact runtime experiment.

The relevant UIKit consumers that can receive InputDec's outer text input are:

| Caller / send | Receiver derivation and guard | True / false use when the receiver is `IDBlockTextView` |
| --- | --- | --- |
| `-[UITextInteraction containerChangesSelectionOnOneFingerTap]` `0x1534060`, send `0x1534090` | Loads the interaction's `_textInput`; no `respondsToSelector:` guard around `isEditing`. It first checks `clearingBehavior`. | Editing returns `YES`; nonediting follows the has-text/clearing-behavior branch. With no local provider, a focused noneditable block takes the editing branch through inherited `UIResponder`. |
| `-[UITextDragAssistant _dragInteraction:shouldDelayCompetingGestureRecognizer:]` `0x14f0494`, send `0x14f0528` | Weak-loads the text input at offset `0xc8`; unguarded send for the relevant gesture-type-6 branch. | The Boolean is inverted to decide whether the competing gesture recognizer is delayed. Inherited lookup treats a focused noneditable block as editing. |
| `-[UITextRefinementTouchBehavior adjustVariableDelaySettingsForLoupeInteraction:]` `0xb23a40`, send `0xb23aa0` | Obtains the text input from the interaction; unguarded send. | Editing selects zero delay; nonediting selects `0.5` seconds. |
| `-[UITextRefinementTouchBehavior textLoupeInteraction:willBeginAtPoint:withMode:]` family `0xb23f58`, sends `0xb240b4` and `0xb24280` | The text input is retained in `x21`; both sends are unguarded. | Gates keyboard suppression and near-caret refinement during loupe startup. The inherited predicate changes only focused/noneditable behavior. |
| `-[_UIKeyboardStateManager isCurrentEditResponderInEditingMode]` `0x7a0c0c`, probe `0x7a0ca4`, send `0x7a0cb0` | Loads `delegateAsResponder->_responderForEditing`; explicitly checks `respondsToSelector:isEditing`. | A true result is followed by an `isEditable` query at `0x7a0ccc`. The nominal missing-callback fallback uses delegate editability/first-responder state, but it is unreachable here because inherited `UIResponder.isEditing` keeps the selector supported. |
| `-[_UIKeyboardStateManager selectionWillChange:]` `0x7a83ec`, send `0x7a8454` | Loads `inputDelegateManager.forwardingInputDelegate`; no selector guard. | The true path compares `interactionAssistant.view` with the forwarding delegate and can clear that delegate or resign. |
| `-[_UIKeyboardStateManager _local_acceptAutocorrection]` `0x7c0860`, send `0x7c08a4` | Loads `inputDelegateManager.privateInputDelegate`; unguarded. | False exits through `0x7c09e0`; true continues local autocorrection acceptance. |
| `-[_UIKeyboardStateManager _acceptAutocorrection]` `0x7c0a98`, send `0x7c0af4` | Loads the private input delegate; unguarded. | False jumps to `0x7c0e34`; true continues the acceptance pipeline. |
| `-[_UITextInteractionEditMenuAssistant _clippedTargetRect:]` `0x9f56cc`, send `0x9f5c2c` | Loads `interactionAssistant.view`; unguarded. | Editing subtracts the active keyboard frame from the target region; nonediting follows the unclipped alternative. |
| `-[UITextSelectionView clippedTargetRect:]` `0x157f5e0`, send `0x157f9f4` | Loads `interactionAssistant.view`; unguarded. | Editing subtracts the keyboard frame when clipping selection chrome. |
| `-[_UITextChoiceAccelerationAssistant updateUnderlineGeometryIfNeeded]` `0xbd9360`, send `0xbd93cc` | Loads its `_document`; unguarded. | False removes underlines and dismisses the assistant; true continues underline geometry. The document can resolve through the outer text-input host. |
| `-[UITextInputController _shouldHandleResponderAction:withSender:]` `0x15f6038`, sends `0x15f60a0`, `0x15f62e4`, `0x15f6304`, `0x15f6364`, `0x15f64a4`, `0x15f6544`, `0x15f678c`, `0x15f67b4`; block send `0x15f6abc` | Receiver `x20` is the controller's controlled text input; the block uses its captured input. The sends are not protected by a missing-selector fallback relevant to this host. | The result participates in paste, secure-entry, selection, writing/drawing, and responder-action availability. |
| `-[UITextInputController isEditing]` `0x15e9398`, send `0x15e93b0` | Weak-loads its text input at offset `0x98` and forwards directly. | Returns the outer input's resolved value. This path may also terminate at the separately required canvas provider depending on controller ownership; that canvas method is outside this experiment. |

The recovered callers establish that class-local withdrawal is mechanically
safe from an unrecognized-selector crash because `IDBlockTextView` inherits
`UIResponder.isEditing`; they do not establish behavioral equivalence. Most
callers send without a guard, and even the guarded keyboard-state caller still
observes inherited support. The decisive differential is consequently a
first-responder block with `editable == NO`: retained InputDec returns `NO`,
whereas inherited UIKit returns `YES`. Touch selection, menu clipping, loupe
delay/refinement, keyboard delegate lifecycle, autocorrection, spelling
underline geometry, responder actions, and floating-cursor behavior must all
be tested in that state before deletion can be authorized. The flat
`IDTextView` provider, the live-path `IDTextLayoutCanvasView` provider, and
`IDBlockLayout.isEditing` remain protected and unchanged.

Adjacent lifecycle evidence from `-[UITextView setEditable:]` at `0x1616584`
also constrains the differential fixture. On every changed editable value,
UIKit first sends `resignFirstResponder`, then changes the `_tvFlags` editable
bit, updates selection gestures/data-detector state, and calls
`isEditableDidChange`. This includes the `NO` to `YES` transition. Therefore a
noneditable selection responder does not automatically become an editable
keyboard responder when editability is restored; a fresh responder transition
is required. InputDec mirrors that unconditional resignation so the next
`becomeFirstResponder` creates a fresh UIKit input session and keyboard.

### UIFoundation closure

UIFoundation from the same runtime contains none of the exact selectors
`textColor`, `isEditable`, or `isEditing` in Objective-C metadata, method
lists, selector strings, or message stubs. `nm`, `otool -ov`, `strings`, and
the full `otool -tvV` disassembly agree. UIFoundation's only nearby symbol is
the distinct private selector `-[NSTextStorage _isEditing]` at `0xa7c90`,
with `_objc_msgSend$_isEditing` at `0x14afc0`; it is not a member of this
family.

There is therefore no UIFoundation caller that can recover
`NSTextContainer.textView` or send one of these three selectors to the
registered canvas.

### InputDec reachability and independent decisions

InputDec constructs `_UITextKit2LayoutController` with the outer
`IDTextView`, then constructs `UITextInputController` from that layout
controller.
Interaction, loupe, selection, and keyboard owners likewise retain the outer
editor. `IDTextLayoutCanvasView` is registered separately in the TextKit 2
container-to-canvas map and as the text container's private text view only
for the proven origin callbacks. Static receiver tracing originally treated
the input controller's weak text input as the outer editor; the post-removal
runtime probe corrected that assumption for `isEditing`.

With the canvas override absent, the isolated
`testCopyCutAndPasteAvailabilityAndMutations` regression returns `NO` from
paste availability after a successful cut. Restoring `isEditable` alone does
not change the failure. Restoring `isEditing` alone passes. A temporary
stack-only diagnostic on the restored method captured the exact live path:

```text
-[IDTextLayoutCanvasView(PrivateCallbacks) isEditing]
-[UITextInputController isEditing]
-[UITextInputController _shouldHandleResponderAction:withSender:]
IDPrivateInputShouldHandlePaste
-[IDTextView(TextInputConformance) canPerformAction:withSender:]
```

The diagnostic was removed after capture. This path consumes the
context-backed editing state; inherited `UIResponder.isEditing` reports the
canvas view's own first-responder state and is therefore not equivalent.

| Canvas selector | Classification | Decision |
| --- | --- | --- |
| `textColor` | **concrete-UIKit-only** | Remove only the canvas forwarder; preserve outer/block color providers and `id_textColor` |
| `isEditable` | **public-or-project-duplicate** | Remove only the canvas forwarder; preserve outer editor, input-controller, block/context, and `id_isEditable` providers |
| `isEditing` | **externally-required** | Retain the canvas forwarder and `B16@0:8` ABI; `UITextInputController` consumes it while deciding responder-action availability |

The final partition removes two canvas state getter forwarders and retains
`isEditing`. The project-owned getters, non-canvas providers, and
`textContainerUsageDidChangeToSize:` remain unchanged.

## Canvas content-size callback reduction

This pass was reproduced on July 30, 2026 against UIKitCore and UIFoundation
from the iOS 26.5 build 23F73 simulator runtime. The exact callback ABI is
`v32@0:8{CGSize=dd}16`: `self` and `_cmd` occupy the first 16 bytes, and the
two-double `CGSize` argument is passed in `d0`/`d1` on arm64.

### UIKitCore caller closure

Hopper resolves the callback message stub at file-relative `0x22cec80`.
Its complete xref set contains three sends:

| Framework | Caller/send | Receiver derivation | Capability guard | Size derivation | InputDec canvas reachable |
| --- | --- | --- | --- | --- | --- |
| UIKitCore | `-[_UITextLayoutCanvasView updateContentSizeIfNeeded]` (`0xc0a5a8`), send at `0xc0a624` | Calls `context` on concrete canvas `self`, retains that separate object, and sends to the context | None | `ui_contentSizeForLastContainerView`; compare with `_contentSize`; flush selection-navigation cache before sending the changed `CGSize` | No. InputDec does not expose UIKit's `updateContentSizeIfNeeded`; its project method is `id_updateContentSizeIfNeeded`. Its canvas contexts are outer `IDTextView` or `IDBlockLayout`, never the canvas itself |
| UIKitCore | `-[UIFieldEditor _applyCorrectTextContainerSize:]` (`0x15bb488`), send at `0x15bb5d4` | Sends to concrete `UIFieldEditor self` after updating its supplied text container | None after the preceding non-null layout result check | Uses the width and height returned by `updateLayoutForSizeChangeOfTextContainer:` | No; InputDec does not instantiate or subclass `UIFieldEditor` |
| UIKitCore | `-[UITextField textContainerUsageDidChangeToSize:]` (`0x15c2fe8`), tail send at `0x15c2ff4` | Loads the concrete field editor from the `UITextField` ivar and forwards the unchanged `CGSize` | None | Unchanged callback argument | No; both the sender and receiver belong to the stock text-field graph |

UIKitCore also defines the following concrete providers:

- `-[UIFieldEditor textContainerUsageDidChangeToSize:]` at `0x15c0d6c`;
- `-[UITextField textContainerUsageDidChangeToSize:]` at `0x15c2fe8`;
- `-[_UITextContainerView textContainerUsageDidChangeToSize:]` at
  `0x1624eec`.

The `_UITextContainerView` provider adds left plus right inset to width and
top plus bottom inset to height, then tail-calls
`setConstrainedFrameSize:`. That method at `0x16243c0` uses arm64 `frintp`
positive-infinity rounding on enabled axes and clamps to its concrete minimum
and maximum sizes. It is a provider, not another generic sender.

The stock `_UITextLayoutCanvasView` path is deliberately unguarded because
UIKit owns its context contract. It does not create a removal hazard for
InputDec: the earlier lifecycle reduction removed the private
`updateContentSizeIfNeeded` entry point from `IDTextLayoutCanvasView`, and the
project's post-viewport method reads usage and publishes directly without
sending this callback.

### UIFoundation closure

The exact build 23F73 binary at:

```text
/Library/Developer/CoreSimulator/Volumes/iOS_23F73/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 26.5.simruntime/Contents/Resources/RuntimeRoot/System/Library/PrivateFrameworks/UIFoundation.framework/UIFoundation
```

contains no `textContainerUsageDidChangeToSize:` selector string,
Objective-C method metadata, implementation, or message stub. `nm -m`,
`otool -ov`, and `strings -a` all return no match. UIFoundation therefore
cannot independently recover `NSTextContainer.textView` and send this
callback to InputDec's registered canvas.

### Runtime ordering and reachability

Temporary all-canvas instrumentation recorded both the private callback and
the project-owned completed-layout boundary while running:

- the canonical viewport lifecycle;
- ordinary insertion and backward deletion;
- independent-block return/split;
- independent-block backward-delete/merge;
- narrow-to-wide host reflow.

The first result bundle,
`.canvas-content-size-task-1-characterization.xcresult`, passed 4/4. Its log
contains 11 completed-layout events across the demo host and selected tests.
The reflow bundle,
`.canvas-content-size-task-1-reflow-characterization.xcresult`, passed 1/1
and contains 6 completed-layout events. Narrow usage
`{{5, 0}, {120, 110}}` settled to wide usage
`{{5, 0}, {248.01904296875, 44}}`.

Across all 17 completed-layout events, the private callback count was exactly
zero. Split and merge each published fresh completed usage through
`id_updateContentSizeIfNeeded`; no UIKit callback preceded, followed, or
interleaved with those project events. The temporary instrumentation and
temporary reflow test were removed after capture, leaving no source diff.

The pre-change focused baseline
`.canvas-content-size-task-1-baseline.xcresult` passed 105/105 with zero
failures and zero skips on simulator
`FA6F7462-AA97-42FE-9E57-8DA0593CE756`, iOS 26.5 build 23F73.

### Classification

**Classification:** `safe-to-remove`

**Reason:** UIKitCore's only generic-looking send targets the separate
context of a concrete stock canvas and is reachable only through the private
stock `updateContentSizeIfNeeded` lifecycle method, which InputDec no longer
implements. The other UIKitCore receivers are concrete field-editor objects,
UIFoundation contains no sender, and live instrumentation observes only
InputDec's completed-layout publisher. Removing the canvas callback does not
leave an unconditional message send targeting `IDTextLayoutCanvasView`.

### Final removal and certification

The clean-room canvas no longer defines
`textContainerUsageDidChangeToSize:` and no longer declares or implements
`id_textContainerUsageDidChangeToSize:`. Content-size publication now has one
owner: `id_updateContentSizeIfNeeded`, invoked after completed viewport
layout. It validates the full usage rectangle and derived extents, clamps
negative maxima to zero, deduplicates, and publishes through the
project-owned `contentSizeDidChange` block. It does not request another
layout pass.

The final source inventory over `App`, `TextView`, `PrivateUIKit`, and
`Tests` contains neither removed spelling. The final behavior and structure
evidence on iOS 26.5 build 23F73 is:

- focused canvas/host, block/rich-text, rendering/spelling, and interaction:
  263/263;
- final complete unit target: 805/805;
- stock/custom IME, autocorrection, and inline-prediction differential:
  216/216 comparisons and 432/432 host executions;
- real system keyboards: 24/24;
- final project smoke: 98/98;
- final selector/source audit: 3/3.

All simulator XCTest runs disabled parallel testing and used the repository
serialization lock. The full command, bundle, rerun, and environment record
is in
`docs/superpowers/reports/2026-07-29-canvas-content-size-callback-reduction.md`.

## Canvas attachment callback reduction

This ledger uses UIKitCore and UIFoundation from the iOS 26.5 build 23F73
simulator runtime. The layout callback has a void return, one object argument,
and one `CGRect` argument; arm64 passes the rectangle's four doubles in
`d0`-`d3`. The enter/leave callbacks have a void return and one object
argument.

### didLayoutTextAttachmentView:inFragmentRect:

| Framework | Caller/send | Receiver derivation | Guard | Argument derivation | InputDec reachable |
| --- | --- | --- | --- | --- | --- |
| UIKitCore | `___103-[_UITextLayoutCanvasView textViewportLayoutController:configureRenderingSurfaceForTextLayoutFragment:]_block_invoke_2` (`0xc09df4`), send at `0xc09e40` through stub `0x21efd80` | Captured context of the concrete stock `_UITextLayoutCanvasView` | None | Provider view plus the fragment-local rectangle produced while enumerating the configured fragment | No. InputDec owns its viewport delegate/configuration implementation and never enters this stock canvas method |
| UIKitCore | Concrete implementations on `_UITextContainerView` (`0x1624f18`) and `UITextField` (`0x15c3000`) | Concrete stock receivers | N/A | N/A; both implementations are no-ops | No |
| UIKitCore | `UISearchTextField` implementation (`0x68ab40`) | Concrete search-field receiver | N/A | Updates search-token mask/visible geometry | No |

The message-stub xref set contains exactly the single send at `0xc09e40`;
the remaining selector-string xrefs are stubs or Objective-C metadata.

**Classification:** `safe-to-remove`

### didAddTextAttachmentViews:

| Framework | Caller/send | Receiver derivation | Guard | Argument derivation | InputDec reachable |
| --- | --- | --- | --- | --- | --- |
| UIKitCore | `-[_UITextLayoutCanvasView _viewportDidLayout]` (`0xc0825c`), send at `0xc084dc` through stub `0x21ee9e0` | Calls `context` once on the concrete stock canvas and sends to that separate object | None | `current - previous` attachment-view identity set after fragment configuration | No. InputDec implements `id_viewportDidLayout`, not stock `_viewportDidLayout` |
| UIKitCore | Concrete implementations on `_UITextContainerView` (`0x1624f14`) and `UITextField` (`0x15c2ffc`) | Concrete stock receivers | N/A | N/A; both implementations are no-ops | No |
| UIKitCore | `UISearchTextField` implementation (`0x68a8d8`) | Concrete search-field receiver | N/A | Reconciles search-token layout views | No |

The message-stub xref set contains exactly the single send at `0xc084dc`.

**Classification:** `safe-to-remove`

### didRemoveTextAttachmentViews:

| Framework | Caller/send | Receiver derivation | Guard | Argument derivation | InputDec reachable |
| --- | --- | --- | --- | --- | --- |
| UIKitCore | `-[_UITextLayoutCanvasView _viewportDidLayout]` (`0xc0825c`), send at `0xc084b0` through stub `0x21f02e0` | Same separately obtained stock-canvas context as the add send | None | `previous - current` attachment-view identity set; sent before the add set | No. InputDec's lifecycle is project-owned |
| UIKitCore | Concrete implementations on `_UITextContainerView` (`0x1624f1c`) and `UITextField` (`0x15c2ff8`) | Concrete stock receivers | N/A | N/A; both implementations are no-ops | No |
| UIKitCore | `UISearchTextField` implementation (`0x68aa0c`) | Concrete search-field receiver | N/A | Reconciles search-token layout views | No |

The message-stub xref set contains exactly the single send at `0xc084b0`.

**Classification:** `safe-to-remove`

### UIFoundation closure

Exact `strings -a`, `nm -m`, and `otool -ov` searches of the build 23F73
UIFoundation binary found none of the three selector spellings. UIFoundation
therefore supplies neither an implementation nor an independent sender for
this callback family.

### Runtime ordering and sender evidence

The focused pre-change baseline at
`.canvas-attachment-callback-task-1-baseline.xcresult` passed 99/99 with zero
failures and zero skips. Temporary sender/receiver instrumentation then ran
ordinary provider placement, viewport exit, repeated layout, coordinator
flush, paragraph-anchored placement, rendering-surface recovery, and the
independent-block host boundary. The corrected characterization bundle at
`.canvas-attachment-callback-task-1-characterization-green1.xcresult` passed
7/7 with zero failures and zero skips.

The log contains 12 project layout events, three project add events, and two
project remove events. It contains five private layout events and one private
add event, all received by `IDTextView`, and no private remove event in the
visible-editor subset. Every observed private event immediately followed its
matching project send. Representative stacks are
`IDTextLayoutCanvasView id_configureRenderingSurfaceForTextLayoutFragment:`
to `IDPrivateCanvasDidLayoutAttachmentView` to the text-view adapter, and
`IDTextCanvasAttachmentCoordinator finishViewportLayout` to
`IDPrivateCanvasDidAddAttachmentViews` to the text-view adapter. No event had
a UIKit-origin sender.

Rendering-surface layout assigns the provider view's fragment-local frame
before the canvas enumerates it; the current coordinator then assigns the
same frame while recording identity. Repeated layout preserves identity and
does not publish another enter batch. Viewport diffing publishes remove
before add, and flush removes views from their superviews before publishing
one leave batch. Probe contexts and nil contexts produced project events only.

These callbacks are therefore project-only private vocabulary in the current
tree, with no reachable UIKit sender. Each is independently safe to replace
with an ABI-unrelated, typed project protocol while retaining the coordinator's
frame, identity, ordering, and weak-ownership behavior.

### Final removal and certification

The final source inventory contains no production or test-source occurrence
of the three private selector spellings, their former `id_did...` bridges, or
the three removed behavior-contract identifiers. The canvas, editor, and
block-layout receivers are gone; no ABI adapter was retained.

`IDTextCanvasAttachmentCoordinator` now publishes through the weak typed
`IDTextCanvasAttachmentLifecycleSink` protocol. The project methods are
`id_attachmentView:didLayoutInFragmentFrame:`,
`id_attachmentViewsDidEnterViewport:`, and
`id_attachmentViewsDidLeaveViewport:`. Frame assignment, view identity,
immutable batches, remove-before-add ordering, weak host ownership, and flush
cleanup remain coordinator-owned. Independent blocks forward the same project
protocol through their weak host boundary.

Final evidence on simulator `FA6F7462-AA97-42FE-9E57-8DA0593CE756`, iOS 26.5
build 23F73:

- corrected runtime characterization: 7/7;
- typed-sink focused GREEN: 29/29;
- attachment/canvas, rendering, block/rich-text, and interaction regressions:
  271/271;
- fresh complete unit target: 811/811;
- fast semantic gate: 239/239;
- real system-keyboard sentinels: 24/24;
- IME, autocorrection, and inline-prediction differential: 216/216
  comparisons and 432/432 host executions;
- post-keyboard attachment contracts: 6/6;
- final project smoke: 99/99;
- final selector/source audit: 4/4.

All simulator XCTest runs disabled parallel testing and used the repository
serialization lock. The full source, Hopper, runtime, rerun, and certification
record is in
`docs/superpowers/reports/2026-07-31-canvas-attachment-callback-reduction.md`.

## Anchored attachment frame callback reduction

This August 1, 2026 pass uses UIKitCore and UIFoundation from the iOS 26.5
build 23F73 simulator runtime. Hopper's current document was `UIKitCore`.

### `frameForAnchoredTextAttachment:associatedLayoutFragment:`

Hopper resolves the concrete implementation at file-relative `0xc07820` and
the message stub at `0x2206020`. The implementation has four basic blocks over
`0xc07820`–`0xc07930`. Its Objective-C ABI is:

```text
x0 = concrete _UITextLayoutCanvasView receiver
x1 = selector
x2 = anchored attachment
x3 = NSTextLayoutFragment
v0, v1, v2, v3 = CGRect { origin.x, origin.y, width, height } return
```

The implementation retains `x3`, loads the concrete canvas's
`_textViewportViews`, and looks up the fragment surface by that fragment. It
sends `boundsForTextParagraphAnchoredAttachment:` to the fragment with the
attachment from `x2`. When the surface exists, it sends
`convertRect:fromView:` to the concrete canvas. Without a surface, it adds
both `context.textContainerOrigin` and `layoutFragmentFrame.origin`. Assembly
preserves the four doubles in `d11`, `d10`, `d9`, and `d8`, then returns them
in `v0`–`v3`. The only caller consumes those registers immediately as the
argument to `setFrame:`. Stock UIKit does not add InputDec's subsequent finite
validation or horizontal normalization.

### UIKitCore caller and receiver closure

The complete xref set for message stub `0x2206020` contains one send:

| Framework | Caller/send | Receiver derivation | Guard | Argument derivation | InputDec reachable |
| --- | --- | --- | --- | --- | --- |
| UIKitCore | `-[_UITextParagraphAnchoredAttachmentView layoutSubviews]` (`0xd069f4`), send at `0xd06a70` | Loads weak `_textLayoutCanvasView` from the concrete stock wrapper and sends directly to it | Layout returns through its nil-fragment path before loading the receiver; wrapper creation is gated by `supportsAnchoredTextAttachments` in the concrete canvas update method | Loads weak `_anchoredAttachment` into `x2` and weak `textLayoutFragment` into `x3` | No |

The receiver exclusion is structural rather than selector-based. The only
factory for `_UITextParagraphAnchoredAttachmentView` is the block at
`0xc075b4` inside the concrete
`-[_UITextLayoutCanvasView _updateRenderingSurfaceViewsForTextRange:inTextView:bounds:]`.
At `0xc07414`–`0xc07468`, that concrete method captures its `self` (`x22`) as
a weak block field. At `0xc076b4`–`0xc076dc`, the block directly allocates the
stock wrapper, reloads that captured weak object, and passes it as
`initWithTextLayoutCanvasView:anchoredAttachment:` argument `x2`. The
initializer at `0xd0692c` stores that exact argument weakly in
`_textLayoutCanvasView`. No protocol lookup, delegate lookup, forwarding
path, or arbitrary canvas-provider lookup intervenes.

InputDec never allocates `_UITextParagraphAnchoredAttachmentView`. Its source
inventory creates `IDTextParagraphAnchoredAttachmentSurface` directly in
`IDTextLayoutCanvasView.m`, and that project wrapper calls the `id_` geometry
method directly. The only UIKitCore sender therefore remains confined to
UIKit's concrete canvas/wrapper pair.

### UIFoundation closure

The authoritative binary is:

```text
/Library/Developer/CoreSimulator/Volumes/iOS_23F73/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 26.5.simruntime/Contents/Resources/RuntimeRoot/System/Library/PrivateFrameworks/UIFoundation.framework/UIFoundation
```

Exact `strings -a`, `nm -m`, and `otool -ov` searches find no
`frameForAnchoredTextAttachment:associatedLayoutFragment:` spelling and no
`_UITextParagraphAnchoredAttachmentView` class. UIFoundation therefore
contains neither an implementation, protocol declaration, message stub, nor
independent sender for this callback.

### Runtime sender evidence

The focused baseline bundle
`.anchored-frame-callback-task-1-baseline-1.xcresult` passed 38/38 with zero
failures and zero skips on simulator
`FA6F7462-AA97-42FE-9E57-8DA0593CE756`. Temporary dual-entry instrumentation
then exercised provider reuse and scrolling, nonzero-origin fallback,
provider-backed drawing, and nil-provider fallback drawing. The bundle
`.anchored-frame-callback-task-1-characterization-1.xcresult` passed 4/4.

Its log contains five project geometry entries and zero private callback
entries. Every project stack originates in
`IDTextParagraphAnchoredAttachmentSurface.layoutSubviews` or the direct
fallback geometry test. No UIKit-origin sender reaches
`IDTextLayoutCanvasView`. Temporary instrumentation was removed after capture
and left no source diff.

**Classification:** `safe-to-remove`

The private selector is not part of InputDec's reachable UIKit interaction
graph. Project callers can move to
`id_frameForParagraphAnchoredAttachment:layoutFragment:` and the private
category declaration and implementation can be deleted without an adapter.

### Retained fragment helper boundary

This classification does not apply to the fragment-side capabilities
`boundsForTextParagraphAnchoredAttachment:`,
`textAttachmentViewProviderForTextParagraphAnchoredAttachment:`, provider
`view`, `drawTextParagraphAnchoredAttachment:bounds:context:`,
`supportsAnchoredTextAttachments`, or `anchoredTextAttachments`. Their dynamic
sends and the manifest contracts `reference.anchoredBounds`,
`reference.anchoredProvider`, and `reference.anchoredDraw` remain unchanged
and require separate reduction passes.

### Implementation and final source inventory

Commit `05dce82` removed the private category declaration and forwarding
implementation. `IDTextParagraphAnchoredAttachmentSurface` now calls the
project-owned
`id_frameForParagraphAnchoredAttachment:layoutFragment:` method directly;
the geometry body is unchanged. Exact post-change inventory finds no
`frameForAnchoredTextAttachment:associatedLayoutFragment:` occurrence in
`App`, `TextView`, `PrivateUIKit`, or `Tests`. The project seam occurs only in
the internal declaration, canvas implementation, custom wrapper call, and
behavior/source tests.

The retained helper header, implementation, and iOS 26.5 behavior manifest
have no diff from the production-change parent. Their exact selector and
contract inventory remains present, so this callback classification does not
silently remove or weaken the fragment capability boundary.

Current-tree verification on pinned simulator
`FA6F7462-AA97-42FE-9E57-8DA0593CE756`, iOS 26.5 build 23F73, includes:

- focused callback-removal GREEN: 32/32;
- attachment/canvas/editor: 94/94;
- rendering and spelling: 51/51;
- independent blocks and rich text: 129/129;
- interaction: 65/65;
- fresh complete unit target: 818/818;
- bounded semantic differential: 240/240 in 12.69 seconds; and
- real-system-keyboard sentinels: 24/24.

Every simulator XCTest command above used the repository serialization lock
and `-parallel-testing-enabled NO`. The complete command, rerun, environment,
and differential record is in
`docs/superpowers/reports/2026-08-01-anchored-attachment-frame-callback-reduction.md`.

## Paragraph-anchored bounds private-API reduction

This August 5, 2026 pass uses UIKitCore and UIFoundation from iOS 26.5 build
23F73. Hopper had both matching binaries open. The focused pre-change baseline
at `.anchored-bounds-task-1-baseline.xcresult` passed 8/8 with zero failures
and skips on simulator `FA6F7462-AA97-42FE-9E57-8DA0593CE756`.

### UIFoundation bounds implementation and ABI

Hopper resolves
`-[NSTextLayoutFragment boundsForTextParagraphAnchoredAttachment:]` at
UIFoundation file-relative `0xd64c`. The method has four basic blocks through
`0xd6cc`. Its arm64 Objective-C ABI is:

```text
x0 = NSTextLayoutFragment receiver
x1 = selector
x2 = candidate paragraph-anchored attachment
v0, v1, v2, v3 = CGRect { origin.x, origin.y, width, height } return
```

The method sends `anchoredTextAttachments` to the fragment and then
`containsObject:` with the attachment. A nonmember returns the four doubles of
`CGRectZero`. A member receives `frame`; the returned width and height are
preserved, while `layoutFragmentFrameOrigin.x` and `.y` are subtracted from
the frame origin. Assembly at `0xd680`-`0xd68c` preserves the four frame
components, `0xd698`-`0xd69c` subtracts only the origin, and `0xd6b4`-`0xd6b8`
restores width and height to `v2` and `v3`.

Equivalent control flow is:

```objc
if (![[fragment anchoredTextAttachments] containsObject:attachment]) {
    return CGRectZero;
}
CGRect frame = [attachment frame];
CGPoint origin = [fragment layoutFragmentFrameOrigin];
return CGRectOffset(frame, -origin.x, -origin.y);
```

`containsObject:` supplies ordinary Objective-C equality semantics rather than
a pointer-only comparison.

### Attachment membership semantics

`-[NSTextLayoutFragment anchoredTextAttachments]` is at `0xd6d0`. It loads the
fragment's weak text element at offset `0x10`. If that element is an
`NSTextParagraph`, it tail-calls the paragraph's `anchoredTextAttachments`;
otherwise it returns the shared empty array.

`-[NSTextParagraph anchoredTextAttachments]` is at `0x6a1cc`. It enumerates
`NSTextParagraphAnchoredAttachmentAttributeName` over the paragraph attributed
string. A scalar attribute value is normalized to a one-element array; an
array value is retained as the attachment array. This membership path is
already represented by InputDec's separately retained
`IDPrivateCanvasAnchoredTextAttachments` dependency and is not reduced in this
pass.

### Attachment frame storage and writers

`-[NSTextParagraphAnchoredAttachment frame]` at `0x65d98` copies 32 bytes from
private object storage at offset `0x28` with `objc_copyStruct` and returns them
as four doubles. `-[NSTextParagraphAnchoredAttachment _updateLayoutFrame:]` at
`0x65d44` is the corresponding private writer: it stores `d0`/`d1` at offsets
`0x28`/`0x30` and `d2`/`d3` at `0x38`/`0x40`.

The `_objc_msgSend$_updateLayoutFrame:` stub at `0x14d3a0` has exactly two
call sites:

| Caller/send | Receiver | Rectangle provenance |
| --- | --- | --- |
| `-[NSTextLayoutFragment _layout]` (`0x8c44`, 138 basic blocks), send at `0x9768` | Current object from the paragraph's anchored-attachment array | Width and height come from `NSTextAttachment`'s `attachmentBoundsForAttributes:location:textContainer:proposedLineFragment:position:`. X begins at text-container `lineFragmentPadding` and is conditionally shifted by the anchored position, base writing direction, available line extent, and attachment width. Y combines the fragment's accumulated vertical layout offset with private line/layout accumulator state. |
| `___31-[NSTextLayoutFragment _layout]_block_invoke_4` (`0xac50`), send at `0xace8` | Anchored attachment selected by the enumerated rectangle index | Reads a previously accumulated exclusion rectangle from `NSValue`, adds a captured private vertical layout delta to its Y component, records the adjusted rectangle, and writes it back to the corresponding anchored attachment. |

The primary path at `0x9660` first asks the private anchored object for its
`textAttachment`. At `0x9684`-`0x969c` it calls the attachment-bounds callback
with paragraph attributes, paragraph content location, the active text
container, the proposed line fragment, and a layout position. At
`0x96b4`-`0x96f0`, private `position` and `_baseWritingDirection` control
leading, centered, or trailing horizontal placement. At `0x9744`-`0x9750`,
private captured layout accumulators produce the stored Y. The write follows
at `0x9754`-`0x9768`. The second writer is installed at
`0x98e8`-`0x992c` and replays the exclusion rectangles after an accumulated
vertical adjustment.

The stored frame is therefore an output of UIFoundation's complete fragment
layout transaction. It is not derivable at InputDec's later viewport-admission
or wrapper-placement call sites from `NSTextAttachment.bounds` alone.

### Layout-fragment origin equivalence

`-[NSTextLayoutFragment layoutFragmentFrameOrigin]` at `0x7b14` is a single
tail branch to the ordinary `layoutFragmentFrame` getter. It returns the first
two doubles unchanged. This dependency has an exact public equivalent:
`fragment.layoutFragmentFrame.origin`.

### UIKitCore consumers

UIKitCore's message stub
`_objc_msgSend$boundsForTextParagraphAnchoredAttachment:` at `0x21ceb20` has
exactly two xrefs:

| Caller/send | Use of returned bounds |
| --- | --- |
| `___86-[_UITextLayoutCanvasView _updateRenderingSurfaceViewsForTextRange:inTextView:bounds:]_block_invoke_2` (`0xc075b4`), send at `0xc07670` | Adds `layoutFragmentFrame.origin`, intersects with viewport bounds, and creates or revives the stock anchored wrapper. |
| `-[_UITextLayoutCanvasView frameForAnchoredTextAttachment:associatedLayoutFragment:]` (`0xc07820`), send at `0xc0787c` | Converts through a realized fragment surface, or adds `context.textContainerOrigin` and `layoutFragmentFrame.origin` for fallback placement. |

InputDec has the same two semantic consumers in
`IDTextLayoutCanvasView.m`: viewport admission and final anchored-surface frame
placement.

### Public/project-owned availability table

| CGRect component | UIFoundation source | Writer | Public equivalent | Project-owned at call time | Classification |
| --- | --- | --- | --- | --- | --- |
| X | Padding plus position/direction/available-line calculation | `_layout` at `0x96b4`-`0x9768`, or adjusted exclusion replay at `0xace8` | No complete equivalent | No | Opaque |
| Y | Accumulated private fragment/line vertical state | `_layout` at `0x9744`-`0x9768`, or captured replay delta at `0xac8c`-`0xace8` | No | No | Opaque |
| Width | Attachment-bounds callback result, possibly replayed | `_layout` at `0x9684`-`0x9768` or `0xace8` | The callback is public, but its exact layout inputs are not available at the later consumers | No | Opaque |
| Height | Attachment-bounds callback result, possibly replayed | `_layout` at `0x9684`-`0x9768` or `0xace8` | The callback is public, but its exact layout inputs are not available at the later consumers | No | Opaque |
| Fragment-origin subtraction | `layoutFragmentFrameOrigin` | Read-only adapter at `0x7b14` | `layoutFragmentFrame.origin` | Yes | Reproducible |
| Membership | Paragraph anchored attribute array | `anchoredTextAttachments` at `0xd6d0`/`0x6a1cc` | No | Available only through an already retained private helper | Retained separate dependency |

### Evidence-gate classification

**Classification: `opaque`.**

The bounds adapter itself is simple, but its input frame is private mutable
state produced inside UIFoundation's 138-block fragment layout transaction.
InputDec neither owns that state nor receives the exact inputs at the two later
canvas call sites. Reading `[attachment frame]`, using KVC, reading the private
ivar at offset `0x28`, calling `_updateLayoutFrame:`, or declaring a new private
attachment protocol would exchange one private dependency for another rather
than reduce the private surface.

Under the approved no-swap gate, this pass must retain
`IDPrivateCanvasParagraphAnchoredBounds` and `reference.anchoredBounds`.
Removing them requires a larger project-owned paragraph-anchored layout-frame
slice that computes and owns the frame during layout, not a port of this getter
alone.

### Runtime oracle and final verification

The test-only oracle in `IDTextCanvasAttachmentCoordinatorTests.m` invokes the
inherited UIFoundation implementation directly. Deterministic member and
nonmember fragments verify the membership branch, exact origin subtraction,
and width/height preservation. A separate integration observation constructs
the real private anchored object and attribute only inside the test target,
performs a real TextKit 2 layout, and compares the method result with the
layout-produced attachment frame. Rectangle comparisons use one display pixel
as their tolerance.

`.anchored-bounds-task-3-oracle2.xcresult` passed 4/4 with zero failures or
skips. `.anchored-bounds-task-5-focused.xcresult` passed 69/69 with zero
failures or skips. `.anchored-bounds-task-5-fast/summary.json` passed 246/246
in 11.93 seconds with zero failures or skips. All ran on iPhone 17 Pro K3
simulator `FA6F7462-AA97-42FE-9E57-8DA0593CE756`, iOS 26.5 build 23F73; every
Simulator XCTest invocation used the repository lock and
`-parallel-testing-enabled NO`.

The final inventory retains `IDPrivateCanvasParagraphAnchoredBounds`, its two
canvas consumers, the forwarding implementation, and
`reference.anchoredBounds`. The provider, draw, support, and enumeration
contracts are likewise unchanged. The production private-surface delta for
this evidence-gated pass is therefore zero.

## Selection-container callback reduction evidence

This August 7, 2026 reduction pass uses the active Hopper `UIKitCore` document
from iOS 26.5 build 23F73. All addresses below are file-relative. The committed
baseline has 127 production capability members, 53 reference-only members, and
25 test-only members. The corresponding Git object hashes are
`d2143fb0a8d056793885a4a1ea117d93a83fff59` for the production behavior
contract, `b6b7d08f1cf628a78d30f1a20347cd8dc4c5aacd` for the test-only contract,
`9380140300042646873abcd251ca06697ee403f8` for the block interaction callback
implementation, `1e8932f895b1b34deaf62c282c979d30396f97e9` for
`IDPrivateUIKit.h`, and `e6c83173a538ba6917b80606c9a0c27d36370a0a`
for `IDPrivateUIKit.m`. `+[IDPrivateUIKit requireInteractionHost:stage:]`
requires 15 callbacks; the five candidates in this pass are only the five
selection-container/interaction-geometry rows named below.

| Address | Procedure | Decompiled branch and fallback | Hopper caller/callee evidence |
| --- | --- | --- | --- |
| `0x156cf7c` | `-[UITextInteractionAssistant selectionContainerView]` | Weak-loads the hosted delegate. If it responds to `selectionContainerView`, returns that result; otherwise returns the delegate's `textInputView`. | Direct callees include the two selector stubs. Hopper reports no statically resolved callers because ordinary Objective-C sends dispatch through the stub. |
| `0x156cffc` | `-[UITextInteractionAssistant selectionContainerViewAboveText]` | Weak-loads the hosted delegate. If it responds to `_selectionContainerViewAboveText`, returns that result; otherwise returns `textInputView`. | Direct callees include `_selectionContainerViewAboveText` and `textInputView`; callers are dynamically dispatched. |
| `0x1615f44` | `-[UITextView selectionContainerView]` | With modern selection enabled, asks `_existingSelectionContainerView`; if absent, allocates the private selection-container class, stores it in `_selectionContainerView`, invokes `_placeSelectionContainerView`, and returns the existing container. With modern selection disabled, returns `textInputView`. | Statically calls `_existingSelectionContainerView` and `_placeSelectionContainerView`; also calls `textInputView` on the legacy branch. |
| `0x1615ff0` | `-[UITextView _selectionContainerViewAboveText]` | Single tail call to `_contentView`. | Only `_contentView` is a direct callee; selector consumers dispatch dynamically. |
| `0x1615ed8` | `-[UITextView _existingSelectionContainerView]` | Reads `_containerView.selectionContainerView` first and falls back to the `_selectionContainerView` ivar without creating either object. | `-[UITextView selectionContainerView]` is its statically resolved caller; its direct semantic callee is `selectionContainerView` on `_containerView`. |
| `0x1608d84` | `-[UITextView _placeSelectionContainerView]` | Returns without work when the receiver or `_selectionContainerView` is absent. For TextKit 2 when `__UITextViewAllowSelectionContainerInTextLayoutCanvas()` is true, removes the container from its old superview and installs it through the layout canvas's `setSelectionContainerView:`. Otherwise clears `_containerView.selectionContainerView`, inserts the selection container below the content view, and requests layout. | Called by `selectionContainerView` and by the layout-manager reconfiguration block `___94-[UITextView _reconfigureWithLayoutManager:triggeredByLayoutManagerAccess:triggeringSelector:]_block_invoke`. |
| `0x1610f04` | `-[UITextView _updateInteractionGeometry]` | Obtains `interactionAssistant` and sends `updateSelectionForTextAnimation`; it does not itself calculate geometry. | Direct callees are the assistant getter and `updateSelectionForTextAnimation`; callers dispatch dynamically. |
| `0xa4a228` | `-[_UITextFloatingCursorSession _selectionContainerView]` | Weak-loads its display-interaction host, asks that object for `_hostViewAboveText`, and returns the result. | Its only semantic callee is `_hostViewAboveText`; its consumers dispatch dynamically. |

Two adjacent paths clarify responsibility. At `0xc6b01c`,
`-[UITextSelectionDisplayInteraction _hostViewAboveText]` prefers its
assistant/delegate's `selectionContainerViewAboveText`; when that produces no
view, it chooses either the host's `_selectionContainerViewAboveText` or
`textInputView` according to interaction flags. The modern floating-cursor
session therefore consumes the above-text host through the selection-display
interaction rather than calling the editor's selection-container callback
directly. At `0x156cb9c`,
`-[UITextInteractionAssistant updateSelectionForTextAnimation]` either adjusts
the active touched extent or invalidates selection display, then recomputes the
render-space model position from the active selected range. This makes
`_updateInteractionGeometry` a trigger into UIKit's active interaction state,
not a layout provider.

The assistant's explicit `textInputView` fallbacks make
`selectionContainerView` and `_selectionContainerViewAboveText` plausible
withdrawal candidates. They do not authorize deletion by themselves. Stock
`UITextView`'s `_selectionContainerView` and `_containerView` ivars, its canvas
feature gate, and its below-content insertion order are class-private storage
policy and cannot be projected onto the duck-typed `IDBlockTextView`. Hopper
also cannot prove whether direct UIKit message sends require
`_existingSelectionContainerView`, `_placeSelectionContainerView`, or
`_updateInteractionGeometry` to be present on that host, nor whether a fallback
preserves highlight, handles, loupe, autoscroll, container identity, and
floating-cursor coordinates. Each candidate therefore requires a separate
build in which its method and ABI requirement are genuinely absent, followed
by the stock-differential runtime oracle.

### True-withdrawal authorization results

The compile-time withdrawal matrix at
`.selection-container-reduction-task5-matrix2` ran serially on the pinned
iPhone 17 Pro K3 simulator, iOS 26.5 build 23F73. The retained build and four
withdrawn builds each passed all six selected contracts with zero failures or
skips. The `selectionContainerView` build passed all four method-surface tests
and the complete touch-chrome batch, but failed the floating batch at its first
container-identity checkpoint. An isolated rerun at
`.selection-container-reduction-task5-confirm-selectionContainerView-floating1.xcresult`
reproduced the same first divergence.

| Withdrawn selector | Result | Authorization | Runtime conclusion |
| --- | --- | --- | --- |
| `selectionContainerView` | 5 passed, 1 failed | `requiredNativeChrome` | Before floating motion, the canonical selection and responder remained correct, but `containerStable` was false, `containerToken` was `nil`, and assistant/display session ownership was absent. The isolated confirmation reproduced this exact state. |
| `_selectionContainerViewAboveText` | 6 passed | `safeFallback` | The assistant/display fallback preserved selection highlight, handles, loupe, scrolling stability, normal floating motion, selection extension, anchor crossing, and lift/quiescence parity. |
| `_existingSelectionContainerView` | 6 passed | `safeFallback` | No method-surface, semantic, geometry, transient-chrome, container-identity, or floating divergence was observed. |
| `_placeSelectionContainerView` | 6 passed | `safeFallback` | Project-owned backend placement remained sufficient; all touch and floating checkpoints retained stock parity. |
| `_updateInteractionGeometry` | 6 passed | `safeFallback` | Existing project-owned presentation updates preserved every observed geometry and interaction checkpoint without this UIKit trigger. |

No candidate was `highlightOnly`: every safe candidate retained the native
selection highlight together with handles and loupe, while the one failed
candidate lost required floating-container identity rather than highlight
alone. The explicit translucent-highlight detector was repeated in touch-only
true-withdrawal builds under
`.selection-container-reduction-task5-highlight-safe1`; all four safe
candidates passed. These authorizations apply only to this iOS 26.5 build and
current iOS 26 driver.

## Block host `_convertPointFromRenderSpace:` withdrawal

This August 7, 2026 pass uses the selected Hopper `UIKitCore` document for iOS
26.5 build 23F73. `-[UITextView _convertPointFromRenderSpace:]` is at
`0x16107b0` (112 bytes, four basic blocks). It calls `customRenderController`;
when that result is nil, the branch at `0x16107dc` falls through to the identity
return at `0x1610804`. When the renderer exists and
`_customRenderControllerCanConvertPointFromRenderSpace` is true, UIKit sends
`convertPointFromRenderSpace:` to that renderer.

The selector stub `_objc_msgSend$_convertPointFromRenderSpace:` is at
`0x21293c0`. Hopper reports exactly one direct xref, the instruction at
`0xc3e6cc` in
`-[_UITextKit2LayoutController cursorPositionAtPoint:inContainer:]`
(`0xc3e60c`). That procedure weak-loads its `_textView` and, when the weak
reference is nonnil, sends `_convertPointFromRenderSpace:` unconditionally;
there is no `respondsToSelector:` guard or missing-selector fallback around the
send. It then resolves the text selections interacting at the converted point.

Receiver ownership is decisive for the experiment boundary. The flat
`IDTextView` uses `_UITextKit2LayoutController` and therefore retains its
`_convertPointFromRenderSpace:` implementation. `IDBlockTextView`, however,
installs project-owned `IDRichTextLayoutController` as its layout controller;
that controller owns the block cursor-position callback and does not route the
point through UIKit's `_UITextKit2LayoutController` receiver path. UIKit's
`-[UITextInteractionAssistant _updateRenderSpaceConversionConformance]` at
`0x156370c` separately probes only `_convertPointToRenderSpace:textRange:` and
`_convertPointToRenderSpace:textPosition:` with
`objc_opt_respondsToSelector`; it neither probes nor sends
`_convertPointFromRenderSpace:`.

Static reachability therefore authorizes a paired true-absence experiment for
the block interaction host, not permanent deletion. The direct private
TextKit 2 receiver prevents withdrawing the flat-editor implementation, while
the block editor's project-owned layout controller makes the block method and
its interaction-host ABI row candidates for runtime withdrawal. Permanent
authorization still requires the complete method-surface, geometry, native
chrome, and semantic differential with both block entries genuinely absent.

## Block interaction policy callback reduction evidence

This August 8, 2026 pass uses the selected iOS 26.5 build 23F73 `UIKitCore`
document. The table classifies only the methods published by the duck-typed
`IDBlockTextView` interaction host. It does not authorize removal of the flat
`IDTextView` methods, the project-owned `id_` lifecycle helpers, or the inner
`IDBlockLayout` canvas-context callback.

| Selector | UIKit implementation / stub | Complete relevant receiver path and missing-selector behavior | InputDec reachability | Static decision |
| --- | --- | --- | --- | --- |
| `_updateSelectionGestures` | `-[UITextView _updateSelectionGestures]` at `0x161d01c`; selector stub at `0x21acb60` | The stub's `UITextView` sends are concrete lifecycle `self` calls from `becomeFirstResponder`, `_cleanUpForResignFirstResponder`, `_setInteractiveTextSelectionDisabled:`, `setEditable:`, `setClearsOnInsertion:`, `draggingFinished:`, and `resignDropResponderWithDropPerformed:`. The remaining xrefs are the corresponding concrete `UITextField` lifecycle calls. The implementation gates on selectable, active drag/drop, and first-responder state, then installs or clears gestures on its concrete interaction assistant and hides the menu when disabling. No UIKit path sends this selector to the duck-typed hosted delegate, so there is no block-host missing-selector branch to exercise. | Project lifecycle code calls `id_updateSelectionGestures` directly; the private block-host method is only a duplicate entry point. | `eligible` for paired true-absence testing. |
| `_isInteractiveTextSelectionDisabled` | `-[UITextView _isInteractiveTextSelectionDisabled]` at `0x1610d88`; selector stub at `0x2151cc0` | `-[UITextInteractionAssistant isInteractiveSelectionDisabled]` (`0x1563840`) weak-loads its hosted delegate, caches `respondsToSelector:`, and returns `NO` when the selector is absent. `-[UITextInteractionAssistant addGestureRecognizersToView:]` probes at `0x15664c4`, sends at `0x15664d0` only when supported, and sets the missing-selector result to `NO` at `0x15664dc`. `-[UITextDragAssistant dragInteraction:itemsForBeginningSession:]` likewise checks `respondsToSelector:` before sending. The concrete `UITextView` implementation returns disabled for its override flag, otherwise returns `NO` when selectable and consults link-interaction delegates only when not selectable. | UIKit can reach the block host only through guarded assistant/drag-assistant probes, whose exact absence fallback is interactive selection enabled (`NO`). | `eligible` for paired true-absence testing. |
| `hasEditableSelection` | `-[UITextSelection hasEditableSelection]` at `0x1576314`; selector stub at `0x220c8a0` | Every text-system xref sends to a `UITextSelection`/active-selection object: `UITextSelectionDisplayInteraction` cursor visibility and accessory policy; `UITextSelectionInteraction setHybridSelectionWithPoint:`; `UITextInteractionAssistant` set, commit, and extend selection; `UITextSelection alterSelectionGranularity:`; and `UITextSelectionView updateSelectionRects`. The method derives its answer from the selection's range and document editability. Other xrefs are concrete legacy `UIWebDocumentView`/undo paths. The assistant callers first test the hosted view's public `isEditable`; when false they ask the active selection object, never the hosted editor. No copy/cut/paste, edit-menu, responder-action, or Writing Tools path sends this selector to the block host in the complete stub xref set. | `IDBlockTextView.hasEditableSelection` is not a receiver in UIKit's recovered graph; public `isEditable` and UIKit's own active-selection object remain authoritative. | `eligible` for paired true-absence testing. |
| `_textKit2CanvasDidLayout` | `-[_UITextContainerView _textKit2CanvasDidLayout]` at `0x1624f28`, no-op `-[UITextField _textKit2CanvasDidLayout]` at `0x15c2fcc`; selector stub at `0x219d740` | The stub has one xref, the unconditional send at `0xc08580` in `-[_UITextLayoutCanvasView _viewportDidLayout]`. The receiver is the concrete canvas's retained `context`, loaded immediately before the send. `_UITextContainerView` weak-loads its text view, obtains `_existingTextAssistantManager`, and calls `textViewDidReflowLayout`; `UITextField` returns immediately. UIKit does not send this selector to an interaction assistant or selection-display owner. InputDec's clean-room canvas follows the same ordering: remove/update fragment surfaces, update content size, finish attachment publication, notify its context, then optionally update interaction geometry for custom rendering. Its block canvas context is `IDBlockLayout`, which must retain `_textKit2CanvasDidLayout`; that method separately probes its outer canvas host with `respondsToSelector:` and performs no action when the outer method is absent. Outer `IDBlockTextView.layoutSubviews` and the direct `id_canvasDidLayout` lifecycle continue to place the selection container and schedule the deferred presentation snapshot. | The unconditional canvas-context obligation terminates at `IDBlockLayout`; only the guarded second hop can reach `IDBlockTextView`, with an exact no-action fallback. | `eligible` for paired true-absence testing of the outer block-host method and ABI row only. |

The four decisions authorize experiments, not deletion. Each method and its
corresponding interaction-host ABI row must be absent together, one candidate
per build, and must retain the stock-differential semantic, geometry,
selection-chrome, loupe, floating-cursor, autoscroll, responder, and layout
ordering contracts before permanent removal is considered.

## Block visual-selection-range callback withdrawal evidence

This August 8, 2026 pass uses the selected iOS 26.5 build 23F73 `UIKitCore`
document. `-[UITextView
_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:]` is the
single forwarder at `0x1616060`: it loads `_textLayoutController` and sends the
same selector without adding range, geometry, or direction logic. The selector
stub is at `0x21b30e0`; the stock TextKit 2 provider is at `0xc3c988`.

The native selection path can nevertheless use the outer text-input object as
its document. `-[UITextSelectionDisplayInteraction
_initWithTextInput:delegate:activated:]` at `0xc69c6c` stores the supplied text
input weakly at offset `0xf0`. `-_activeSelection` at `0xc6b750` weak-loads that
same object and passes it to `-[UITextSelection initWithDocument:]` at
`0x1574a24`; `-[UITextSelection document]` at `0x1577adc` later weak-loads it.
The keyboard selection controller at `0x107e9a4` likewise constructs a
selection from its input delegate. The relevant live receiver can therefore be
the outer `IDBlockTextView`, even though `IDRichTextLayoutController` owns the
project's visual-selection algorithm.

`-[UITextSelection
_boundedOrInvertedSelectionRangeForExtent:forPoint:fromPosition:inDirection:]`
at `0x1576b20` explicitly guards the document send at `0x1576bcc` with
`respondsToSelector:`. When the callback is unavailable (or returns nil), UIKit
falls back to public text-input operations: it first builds
`textRangeFromPosition:toPosition:`, compares the endpoints, reverses them when
selection inversion is allowed, and otherwise uses `caretRectForPosition:` plus
the relevant point axis, `closestPositionToPoint:`, and tokenizer boundary
navigation to produce a bounded range. The missing-selector branch therefore
does not crash and does not require a replacement provider.

This guarded fallback makes the outer forwarder eligible for paired
true-absence testing, not deletion by inspection. InputDec must keep the rich
controller callback, manifest row, and algorithm unconditional while removing
only the outer method, outer interaction-host ABI row, and block-specific ABI
preflight in the experimental build. Permanent removal requires retained,
withdrawn, and stock equivalence for cross-block handles, mixed bidirectional
text, loupe, floating selection, vertical autoscroll, noneditable selection,
empty blocks, composed characters, and large-document selection.

## Block `_internalTextLayoutController` receiver ledger

This August 8, 2026 pass uses the selected UIKitCore document for iOS 26.5
build 23F73. Hopper reports `_objc_msgSend$_internalTextLayoutController` at
`0x214d520` and exactly three direct xrefs:

| Send address | Procedure | Recovered receiver |
| --- | --- | --- |
| `0xc084fc` | `-[_UITextLayoutCanvasView _viewportDidLayout]` (`0xc0825c`) | concrete `_UITextLayoutCanvasView` `self` |
| `0x15d7924` | `-[UITextField _NSTextRangeFromNSRange:]` (`0x15d790c`) | concrete `UITextField` `self` |
| `0x16215dc` | `-[UITextView _NSTextRangeFromNSRange:]` (`0x16215c4`) | concrete `UITextView` `self` |

The canvas pseudocode retains the result of
`[self _internalTextLayoutController]`, asks it for `searchableObject`, and
performs the searchable-object update without animation. Entry `self` is
preserved as the concrete canvas throughout this procedure. The field and
text-view conversion procedures each send the selector directly to their own
concrete `self`; when the result is nonnil they send
`_rangeForCharacterRange:` to that controller, otherwise they return nil.

The stock provider `-[UITextView _internalTextLayoutController]` is at
`0x1621580`. Its recovered logic is:

```text
controller = retain([self textLayoutController])
if controller does not respond to the required internal range interface:
    release(controller)
    controller = nil
return autorelease(controller)
```

This is a concrete `UITextView` adapter, not evidence of a generic send to an
arbitrary `UITextInput`. `IDBlockTextView` is a `UIScrollView` subclass and its
minimal canvas is the project-owned `IDTextLayoutCanvasView`, not
`_UITextLayoutCanvasView`. None of the complete direct xref set can therefore
target the block provider. The retained block `textLayoutController` callback
continues to expose `IDRichTextLayoutController` independently.

At experiment entry the relevant Git object hashes are:

```text
3a52ebc0cd82f8cdf98189b433b73cd02ed92e1c  PrivateUIKit/IDBlockTextView+PrivateCallbacks.m
11161058090d3efe7f021b62bb2be34929efbd6c  PrivateUIKit/IDTextView+PrivateCallbacks.m
1e8932f895b1b34deaf62c282c979d30396f97e9  PrivateUIKit/IDPrivateUIKit.h
37c371ab4ae51ec4eb58c0299d1377ce14e57608  PrivateUIKit/IDPrivateUIKit.m
c8325530e00330c3895778bc90c9849692a561f0  PrivateUIKit/IDRichTextLayoutController+PrivateCallbacks.m
dc1adeee6eae9cd0cf012ee035ef30a73714812a  TextView/IDRichTextLayoutController.m
821a31ec61d9351e8ce146c2a6d8cbbb3d87adc0  TextView/IDRichTextLayoutControllerInternal.h
d2143fb0a8d056793885a4a1ea117d93a83fff59  PrivateUIKit/Contracts/UIKitBehaviorContracts-iOS26.5.json
bca0b918c3d6f490772834379244a78f682d94c0  Tests/Fixtures/UIKitBehaviorTestOnlyContracts-iOS26.5.json
```

The entry inventory is 127 production capability members, 53 reference-only
members, and 24 test-only members. The only manifest row for the selector is
the test-only observation described below; it is not a production capability.

### Test-only observation boundary

`IDPrivateTestingInternalTextLayoutController` is retained solely for
observing stock `UITextView`. Custom-editor lifecycle diagnostics must receive
the project-owned rich controller explicitly and must not send this selector
to `IDBlockTextView`. The test-only manifest receiver is consequently
`UITextView`; this diagnostic boundary does not authorize or require a block
provider.

## Block plural keyboard-replacement callback receiver ledger

This August 8, 2026 pass uses the selected UIKitCore document for iOS 26.5
build 23F73. The replacement manager and selector stubs are:

| Address | Procedure or stub |
| --- | --- |
| `0xbed7d4` | `-[UIKBInputDelegateManager callShouldReplaceExtendedRange:withText:includeMarkedText:]` |
| `0xbee8b8` | `-[UIKBInputDelegateManager shouldDeleteForward]` |
| `0x2232600` | `_objc_msgSend$keyboardInput:shouldReplaceTextInRanges:replacementText:` |
| `0x22325e0` | `_objc_msgSend$keyboardInput:shouldReplaceTextInRange:replacementText:` |

`callShouldReplaceExtendedRange:withText:includeMarkedText:` loads
`_UITextKitTextRange` at `0xbed86c`, calls `objc_opt_isKindOfClass` at
`0xbed87c`, and branches to the non-UIKit-range path at `0xbed880`. The UIKit
range path obtains `.ranges`, requires a nonzero count, and tests the plural
selector at `0xbed8b8`–`0xbed8c0`; its plural send is at `0xbedfb4`. The
non-UIKit-range path begins at `0xbed9fc`, tests the singular selector at
`0xbeda14`–`0xbeda18`, and sends it at `0xbedcac`.

`shouldDeleteForward` has the corresponding split: the singular send is at
`0xbeeaf4`, while the private multi-range branch sends the plural selector at
`0xbeeda4`.

Hopper reports these complete selector-stub xref sets:

```text
plural   0xbedfb4 0xbeeda4 0x1518dbc 0x15d3d7c 0x161bb04
singular 0xbedcac 0xbeeaf4 0x15bbdf4 0x18952b0
```

The additional plural xrefs are concrete stock wrapper paths in
`UITextContentView`, `UITextField`, and `UITextView`; they do not establish a
plural send to an arbitrary `UITextInput` receiver. InputDec selections use
`IDRichTextRange : UITextRange`, not UIKit's private `_UITextKitTextRange`.
UIKit therefore selects the singular branch for `IDBlockTextView`. At
experiment entry, InputDec's singular implementation itself boxes the range
and invokes the plural method, so a nesting-aware runtime trace is still
required to prove UIKit never sends the plural selector directly.

At experiment entry the relevant Git object hashes are:

```text
fa2179c0f3ec91b7f3229fe4ddd3b9cb5fdb896e  PrivateUIKit/IDBlockTextView+PrivateInputDelegate.m
874c679dda5c343e48c5cee07a6f03425ddf5237  TextView/IDRichTextRange.h
152df54fc8adc6bb854565fdb76eae58c5713ea0  PrivateUIKit/BehaviorKernel/IDUIKitInputControllerCapability.m
435a9243f9439005c25c0ff9e9ad48355b36b474  TextView/IDBlockTextView+TextInput.m
a85a6842aaec40eabe3c9654ee322189632c0ca5  PrivateUIKit/IDBlockTextView+PrivateCallbacks.m
d2143fb0a8d056793885a4a1ea117d93a83fff59  PrivateUIKit/Contracts/UIKitBehaviorContracts-iOS26.5.json
8861741fbdfbb2f915753dadd47beca5ac0b13b4  Tests/Fixtures/UIKitBehaviorTestOnlyContracts-iOS26.5.json
```

The entry inventory is 127 production capability members, 53 reference-only
members, and 24 test-only members. Neither keyboard replacement selector has a
production capability or required-ABI row; they are incoming delegate
callbacks supplied by the block host.

### Final plural-callback classification

The paired iOS 26.5 experiment classified the block-only plural provider as
`safeFallback`. Across the complete retained 24-method real-keyboard matrix,
temporary nesting-aware traces recorded 180 singular entries and 180 plural
entries reached only through InputDec's singular wrapper. They recorded zero
direct UIKit plural sends. The withdrawn product recorded the same 180
singular entries and zero plural entries.

True absence preserved the focused input contracts, UIKit manager-level
forward delete and immediate undo, the 24-method keyboard matrix, the bounded
semantic matrix, and the complete 14-test navigation/touch/loupe/floating
physical matrix. The ordinary source therefore permanently removes
`keyboardInput:shouldReplaceTextInRanges:replacementText:` from
`IDBlockTextView(PrivateInputDelegate)`. It retains the singular callback and
routes that callback directly to `IDBlockAllowsKeyboardReplacement`.

The optimized universal Simulator product contains one unique singular
implementation in each architecture and no plural provider, plural selector
string, experiment control, nesting state, or trace token. The authorization
record is
`Tests/Fixtures/BlockPluralKeyboardReplacementAuthorization-iOS26.5.json`.
This classification is receiver-specific and remains limited to iOS 26.5
build 23F73; it does not apply to UIKit's `_UITextKitTextRange` branch or to a
future TextKit 1 driver.

## Geometry forwarding: the text-geometry result block (2026-09-11)

`-[_UITextKit2LayoutController requestTextGeometryAtPosition:typingAttributes:resultBlock:]`
(23F73) enumerates the standard text segment at the position and invokes the result block as
`void (^)(NSTextContainer *container, CGRect rect, CGFloat baselineOffset, UITextPosition *position)`
— block descriptor `v64?0"NSTextContainer"8{CGRect}16d48"UITextPosition"56`, the container asserted
equal to the segment's (`thisTextContainer == textContainer`, `_UITextKit2LayoutController.m:909`).
`-[UITextInputController selectionRectsForRange:]` calls it for the range's end position and stamps
the baseline (`-[UITextSelectionRect setBaselineOffset:]`) on every rect the layout controller
returned. `-[_UITextChoiceAccelerationAssistant underlineRectForTextSelectionRect:forCandidate:]`
reads it back (`baselineOffset`, falling back to 0.75 × height only when it reads 0) to place an
accepted autocorrection's underline — the blue one a tap reverts from.

Recovered by in-process lldb after the engine's block, invoked with the rect alone, left the
baseline in an unset register: the stamped value read infinity on device and the underline sat at
`y = infinity`, invisible. The engine now answers all four arguments and its selection rects carry
TextKit's segment baseline of their own.


## One coordinate space: the selection container and `-textInputView` (2026-09-11)

The text-choice prompt — the bubble a tap on an underlined autocorrection opens — reaches the screen
through two conversions that must cancel out, and it performs only the first.

`-[_UITextChoiceAccelerationAssistant convertedSelectionRect:]` (23F73) is exactly
`[[self _underlineView] convertRect:[rect rect] fromView:[[self _document] textInputView]]`: a
`UITextSelectionRect` from the text input, moved into the space of `_UITextUnderlineView`, which
UIKit hangs inside the client's `-selectionContainerView`.
`-[_UITextChoiceAccelerationAssistant showPromptForReplacementCandidate:originalCandidate:delay:]`
keeps that converted rect and, from its delayed block, sends
`-[_UITextChoiceAccelerationBubble updateWithChoices:fromParentView:referenceTextView:presentedFromRect:textHighlightColor:]`
with `referenceTextView:` = `[… textInputView]` — the rect is read back relative to the text input
view, with no second conversion. (`presentedFromRect:` is a boxed rect: the signature is
`v56@0:8@16@24@32@40@48`.) The bubble stores it as `referenceRect` and pins its `textAnchor` layout
guide there.

So UIKit requires the selection container and `-textInputView` to be ONE coordinate space. A stock
text view satisfies it by construction: with a 300×200 view scrolled to `contentOffset` 120, its
`-textInputView` (`_UITextContainerView`) and its selection container are both `{{0, 0}, {300, 306}}`
and the container reports `{0, 0}` as its origin in that view.

Measured on device (K3, 23F73) while the engine's container was anchored to the host's `bounds`
instead: the word's selection rect `{{16, 137}, {25, 24}}` in block-stack space — window
`{{16, 269.3}, …}`, where the word is drawn — reached the bubble as `referenceRect`
`{{16, 337.3}, {25, 24}}`, one 68pt content offset below, and the prompt was drawn there.
