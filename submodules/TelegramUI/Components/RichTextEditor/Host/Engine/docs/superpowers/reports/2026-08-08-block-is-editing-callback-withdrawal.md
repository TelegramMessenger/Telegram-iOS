# Block `isEditing` callback withdrawal report

Date: 2026-08-08  
Runtime: iOS 26.5 (23F73), iPhone 17 Pro K3 simulator

## Decision and exact private-surface delta

Decision: `safeFallback` for `-[IDBlockTextView(PrivateInteractionCallbacks) isEditing]` on the pinned runtime.

The ordinary source now permanently removes:

- the class-local block interaction-host `isEditing` method;
- the `isEditing` row from `IDInteractionHostABISpecs()`; and
- the paired withdrawal header, macros, imports, and conditional source.

The flat `IDTextView`, live `IDTextLayoutCanvasView`, and `IDBlockLayout`
providers remain unchanged. This is one local-provider deletion and one host
ABI-row deletion. It is not absolute selector absence: an `IDBlockTextView`
still returns true from `respondsToSelector:isEditing` because it inherits
UIKit's implementation from `UIResponder`.

The permanent authorization is pinned in
`Tests/Fixtures/BlockIsEditingCallbackAuthorization-iOS26.5.json`.

## UIKitCore receiver, guard, and fallback evidence

All addresses are file-relative in UIKitCore from iOS 26.5 build 23F73.

- `_objc_msgSend$isEditing`: `0x22299c0`.
- `-[UIResponder isEditing]`: `0x10c7f08`; a tail branch to
  `isFirstResponder`.
- `-[UITextInputController isEditing]`: `0x15e9398`; forwards to its weak text
  input.
- `-[UITextView setEditable:]`: `0x1616584`; every changed editable value first
  resigns the responder, including `NO -> YES`.

Hopper tracing found unguarded sends from the text-interaction tap policy,
drag assistant, refinement/loupe behavior, keyboard-state selection and
autocorrection paths, edit-menu and selection clipping, choice-acceleration
underline geometry, and `UITextInputController` action handling. The guarded
keyboard-state path still observes selector support through `UIResponder`, so
there is no missing-selector branch for this object.

The only semantic difference under direct lookup is a focused, noneditable
outer block host: the deleted provider returned
`isFirstResponder && isEditable`, whereas `UIResponder` returns
`isFirstResponder`. This state was therefore included explicitly in the
public lifecycle, menu, touch, loupe, floating-cursor, autocorrection, spelling,
and keyboard differentials. Full caller details are in
`docs/hopper/UIKitCore-iOS26.5.md` under “Block interaction-host `isEditing`
withdrawal ledger.”

## Local method-list and resolved-IMP observations

The permanent runtime contract proves:

- `IDBlockTextView` has no class-local `isEditing` method;
- an instance still responds to `isEditing`;
- the resolved block IMP exactly equals the direct-superclass IMP;
- the ordinary probe reports `localProvider = false`,
  `resolvedMatchesDirectSuperclass = true`, and
  `resolvedOwner = directSuperclass`; and
- `IDTextView` and `IDTextLayoutCanvasView` still locally implement the
  selector.

The interaction-host ABI is now exactly:

1. `interactionAssistant`
2. `_textInputViewForAddingGestureRecognizers`
3. `selectionContainerView`
4. `_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:`

The retained direct-IMP diagnostic observed four values
`[false, true, false, true]` across attached, focused, editable-off/resigned,
and restored/refocused states. The permanent inherited-IMP diagnostic records
the same sequence and additionally proves direct-superclass IMP identity.
Neither diagnostic sends `isEditing` through ordinary Objective-C dispatch.

## Retained, withdrawn, and stock public-state matrix

The differential covers attached nonresponder, focused editable/selectable,
editable disabled, selectable/noneditable word selection, resigned
selectable/noneditable, editable restored/refocused, selectable disabled,
selectable restored/refocused, detached, and reattached/refocused states.

For each state the custom editor matched stock `UITextView` for responder,
editable/selectable, selection, and action availability. The withdrawn build
also preserved one active interaction owner and stable selection-container
topology. The setter repair derived from `UITextView setEditable:` ensures
that restoring editability requires a fresh responder transition, as UIKit
does.

Permanent focused evidence:
`.block-is-editing-withdrawal-task6-permanent-focused.xcresult` — 16 passed,
0 failed, 0 skipped.

## Touch, floating, spelling, and English keyboard evidence

Withdrawal evidence retained by the authorization fixture:

- units: `.block-is-editing-withdrawal-task4-units-final.xcresult`;
- lifecycle: `.block-is-editing-withdrawal-task4-lifecycle-ui-green.xcresult`;
- touch/loupe/handles: `.block-is-editing-withdrawal-task5-touch-ui-green.xcresult`;
- floating cursor: `.block-is-editing-withdrawal-task5-floating-ui.xcresult`;
- typing and spelling: `.block-is-editing-withdrawal-task5-typing-spelling-ui.xcresult`;
- English keyboard lifecycle: `.block-is-editing-withdrawal-task5-english-keyboard-ui-green.xcresult`.

The English bundle merges seven independently clean semantic runs covering
autocorrection accept, rejection, immediate undo, inline acceptance, inline
dismissal, post-boundary acceptance, and marked-text commit. A grouped
diagnostic that inherited Simulator rejection history failed the same two
autocorrection cases in stock `UITextView`; it is intentionally excluded from
safe evidence. The validated learning reset deletes only the Simulator's
autocorrection-rejection and dynamic-lexicon state between semantic families.

Final ordinary-build UI evidence:
`.block-is-editing-withdrawal-task7-final-ui.xcresult` — 8 passed, 0 failed,
0 skipped in one serial run. It includes touch chrome, floating chrome,
noneditable copy-menu cancellation/reentry, cross-block spelling-marker
return/backspace, spelling underline appearance/clear, autocorrection undo,
inline prediction accept/delete, and real-keyboard marked-text formatting.

## Permanent source, runtime, and Release-binary contracts

The source audit rejects both experiment token names throughout product,
tests, UI tests, scripts, `project.yml`, and the generated project. It also
requires the deleted method/ABI state, the absent experiment header, and the
unchanged canvas behavior-manifest row.

The Release Simulator product built successfully with
`CODE_SIGNING_ALLOWED=NO` and contains both `x86_64` and `arm64`. For each
architecture, `nm -a`, `otool -ov`, and `strings` establish:

- no `-[IDBlockTextView(PrivateInteractionCallbacks) isEditing]` method;
- present `IDTextView(PrivateInteractionCallbacks)`,
  `IDTextLayoutCanvasView(PrivateCallbacks)`, and
  `IDBlockLayout(PrivateCanvasCallbacks)` `isEditing` methods; and
- no withdrawal macro/header strings.

`IDBlockTextView(PrivateCallbacks)` retains its pre-existing
`forwardingTargetForSelector:` implementation for `UITextInputTraits`.
`UITextInputTraits` does not implement `isEditing`; the runtime contract
requires the forwarder to return nil for this selector and proves there is no
`forwardInvocation:` or dynamic resolution replacement. Thus it is not a
substitute provider for the deleted callback.

## Final gates

- XcodeGen SHA-256, first run:
  `4107ff04a1c92f8a6f419ea7c06f3056a81cd0c6318530ac59df022a839ed1ad`.
- XcodeGen SHA-256, second run: identical.
- Complete units:
  `.block-is-editing-withdrawal-task7-all-units-green.xcresult` — 997 passed,
  0 failed, 0 skipped.
- Fast semantic gate:
  `.block-is-editing-withdrawal-task7-fast/summary.json` — 281 passed,
  0 failed, 0 skipped in 11.879 seconds, below the fixed 30-second ceiling.

Every Simulator XCTest command used the repository lock and
`-parallel-testing-enabled NO`; no XCTest runs overlapped.

## Manifest counts and before/after hashes

Manifest counts remained 127 production capability members, 53
reference-only members, and 24 test-only capability members.

| File | Before | After |
| --- | --- | --- |
| `IDBlockTextView+PrivateInteractionCallbacks.m` | `cb0b47126526278e137f00c2fb0383c8f3debe99` | `8b75f350a7df2b7446a4b23b3eda088beae26100` |
| `IDPrivateUIKit.m` | `f73bce18e80160e48fb5740603229b0a23e45369` | `6b6cbe29257b88fd81bdd82a7e0b0130be844d6c` |
| `IDTextView+PrivateInteractionCallbacks.m` | `03408d1ac1a25608e51a1e84ef637502cde49a1d` | identical |
| `IDTextLayoutCanvasView+PrivateCallbacks.m` | `2570e3906e08e2ee83d373371c853a6887b1a134` | identical |
| production behavior contract | `d2143fb0a8d056793885a4a1ea117d93a83fff59` | identical |
| test-only behavior contract | `bca0b918c3d6f490772834379244a78f682d94c0` | identical |
| new authorization fixture | absent | `440263389a31410c1a4368f05ecf8335cf9cc43f` |

The two changed “before” hashes are the Task 1 ordinary source reconstructed
without experiment guards: the candidate method and ABI row were
unconditional at that point. Protected provider and manifest hashes are
direct before/after identities.

## Dirty-tree, index, process, and platform hygiene

`git diff --check` is clean and the Git index is empty. The repository was an
already-dirty exploration tree containing extensive earlier editor,
diagnostic, test, and generated-project work; this pass preserved that work
and made no reset, checkout, staging, commit, or cleanup operation. The final
generated project includes the new authorization fixture and was deterministic
across two generations.

This authorization is limited to iOS 26.5 build 23F73. The inherited
implementation and UIKit consumers are private implementation details and
must be re-audited on another OS/build before treating the deletion as
portable evidence.
