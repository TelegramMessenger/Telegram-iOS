# Canvas Controller-Getter Callback Reduction Report

## Runtime and scope

This pass classified the following private getters on
`IDTextLayoutCanvasView` independently:

- `textLayoutController`
- `layoutManager`
- `customRenderController`

The authoritative target was UIKitCore and UIFoundation from iOS 26.5 build
23F73. Runtime verification used iPhone 17 Pro simulator
`FA6F7462-AA97-42FE-9E57-8DA0593CE756`. Every direct simulator XCTest command
was serialized through `Scripts/with-inputdec-simulator-test-lock.sh` and used
`-parallel-testing-enabled NO`.

Only the three forwarding implementations in
`PrivateUIKit/IDTextLayoutCanvasView+PrivateCallbacks.m` were eligible for
production changes. The project-owned getters, outer text-view providers,
layout-controller providers, rendering contexts, block architecture, and all
other private callback families were out of scope.

## UIKitCore and UIFoundation caller graphs

All three selectors have the object-returning Objective-C ABI `@16@0:8`
(`@@:`). The relevant UIKitCore addresses are:

| Selector or implementation | Address | Behavior |
| --- | ---: | --- |
| `_objc_msgSend$textLayoutController` | `0x22d0120` | Shared object-return send |
| `-[_UITextLayoutCanvasView _internalTextLayoutController]` | `0xc08724` | Sends `textLayoutController` to the concrete canvas context |
| `_objc_msgSend$layoutManager` | `0x2236360` | Shared object-return send |
| `_objc_msgSend$customRenderController` | `0x21e6360` | Shared object-return send |
| `-[_UITextLayoutCanvasView customRenderController]` | `0xc06df8` | Forwards to the concrete canvas's weak context |
| `-[_UITextContainerView layoutManager]` | `0x1623600` | Forwards to a concrete container view's weak delegate |
| `-[_UITextContainerView customRenderController]` | `0x1623738` | Forwards to a concrete container view's weak delegate |
| `-[_UITextContainerView textLayoutController]` | `0x1625888` | Forwards to a concrete container view's weak delegate |

UIKitCore has no implementation named
`-[_UITextLayoutCanvasView textLayoutController]` or
`-[_UITextLayoutCanvasView layoutManager]`. Its concrete canvas uses
`_internalTextLayoutController` for the first relationship and has no canvas
`layoutManager` getter.

The complete UIKitCore `textLayoutController` graph contains sends from link
interaction, search fields, the concrete canvas context, autofill, text
assistant, animated insertion, legacy canvas, field editor, tokenizer, and
concrete `UITextView` paths. Generic text-input paths retain the outer
`IDTextView`; the concrete-canvas path first loads that canvas's context.
None obtains `NSTextContainer.textView`, and none can recover InputDec's
`UIView`-based canvas. Return values are used for document ranges, token and
selection geometry, previews, baseline data, and layout invalidation through
the preserved outer controller provider.

The complete UIKitCore `customRenderController` graph contains 22 sends:
16 sends from concrete `_UITextLayoutCanvasView` code, two from the
`_UITextKit2LayoutController` selection-rect block, three from concrete
`UITextView` coordinate conversion, and one from `_UITextContainerView`.
Concrete canvas sends target either that class's `self`, a block-captured
instance, or its weak context. The TextKit 2 controller retains the outer
`IDTextView`, and InputDec never creates `_UITextContainerView`. Return values
are used for renderer identity, surface lifecycle, traits, invalidation,
segment enumeration, and coordinate conversion, but never through the
project canvas getter.

The complete UIKitCore `layoutManager` graph contains 103 sends. Receiver
provenance partitions into concrete accessibility/search UI, the TextKit 1
controller and its supplied TextKit objects, unrelated collection/table
layout managers, drag/attachment/legacy text objects, field and text-view
controllers, concrete `_UITextContainerView`, and
`_UIBoundingTextRectsSolver`'s stored controller. No send targets
`_UITextLayoutCanvasView`, and no path follows a text container to InputDec's
registered canvas.

UIFoundation contains neither `textLayoutController` nor
`customRenderController` as a selector, implementation, or message stub. Its
only family member is `_objc_msgSend$layoutManager` at `0x1548e0`, with 67
sends. Every receiver is a concrete or explicitly supplied TextKit object:
`NSTextLayoutFragment`, `NSLayoutManager`, `NSATSTypesetter`,
`NSSingleLineTypesetter`, `NSStringDrawingTextStorage`, `NSTextContainer`,
`NSTypesetter`, `NSTextAttachment`, `NSATSLineFragment`, `NSTextBlock`, or
`NSTextTable`. The container sends target the container itself; attachment
paths recover a manager from their supplied container. None loads
`NSTextContainer.textView`.

The complete xref addresses, per-family receiver derivations, and return uses
are retained in `docs/hopper/UIKitCore-iOS26.5.md`.

## Before/after canvas inventory

Before this pass, the canvas private-callback category contained exactly one
forwarder for each member:

```objc
- (id)textLayoutController {
    return [self id_textLayoutController];
}

- (id)layoutManager {
    return [self id_layoutManager];
}

- (id)customRenderController {
    return [self id_customRenderController];
}
```

The final inventory is:

| Canvas selector | Before | After | Delta |
| --- | ---: | ---: | ---: |
| `textLayoutController` | 1 | 0 | -1 |
| `layoutManager` | 1 | 0 | -1 |
| `customRenderController` | 1 | 0 | -1 |

No removed selector was renamed, moved to another category or class,
dynamically forwarded, dynamically resolved, or otherwise replaced.

## Required non-canvas providers

The final source audit confirms that the required providers remain:

- `IDTextView` and `IDBlockTextView` provide `textLayoutController`.
- `IDRichTextLayoutController` and `IDBlockLayout` provide `layoutManager`.
- Text-view, block-text-view, block-layout, and interaction contexts provide
  `customRenderController`.
- `IDPrivateUIKit+TextLayoutCanvas.m` retains its dynamic context renderer
  lookup and renderer lifecycle helpers.
- The project canvas retains `id_textLayoutController`, `id_layoutManager`,
  and `id_customRenderController`.

These are distinct receiver roles. Removing canvas duplicates did not remove
the controller and renderer interfaces that UIKit can actually reach.

## Independent getter classifications

| Canvas selector | Classification | Reason | Decision |
| --- | --- | --- | --- |
| `textLayoutController` | **public-or-project-duplicate** | UIKit's generic paths target the preserved outer text input/controller; its concrete canvas path targets the concrete canvas context | Remove canvas forwarder |
| `layoutManager` | **public-or-project-duplicate** | All 103 UIKitCore and 67 UIFoundation sends target concrete or explicit controller/TextKit objects; no caller targets the project canvas | Remove canvas forwarder |
| `customRenderController` | **public-or-project-duplicate** | Concrete canvas calls cannot target InputDec's `UIView` subclass, while generic controller calls target the outer text view | Remove canvas forwarder |

No receiver remained ambiguous in either framework.

## Removed canvas getters

All three canvas forwarding getters were removed. The runtime contract
constructs their names without registering literal private selectors and
verifies that:

- `IDTextLayoutCanvasView` does not respond to any member;
- `class_getInstanceMethod` returns `NULL` for every member;
- the exact removable/retained partition covers the three-member universe;
- source contains no replacement implementation in the canvas category.

## Retained canvas getters

None of the private getters in this family remains on the canvas. The retained
set is deliberately empty, and the ABI contract verifies that this empty set
matches the independent classification. This does not affect the project-owned
`id_*` methods or the required non-canvas providers.

## Project-owned getter semantics

The internal project methods remain unchanged:

| Project method | Locked behavior |
| --- | --- |
| `id_textLayoutController` | Returns the exact current `textLayoutManager.delegate`, including nil and identity changes |
| `id_layoutManager` | Deliberately returns nil even while the canvas owns and uses a live TextKit 2 layout manager |
| `id_customRenderController` | Returns the exact optional renderer supplied by the current canvas context |

The characterization tests exercise these behaviors without invoking the
private selector spellings. The source contract positively preserves the
three implementations.

## Rendering, invalidation, geometry, and backend evidence

| Gate | Evidence | Passed | Failed | Skipped | Wall duration |
| --- | --- | ---: | ---: | ---: | ---: |
| Focused post-removal contracts and behavior | `.canvas-controller-getter-task-4-focused-green.xcresult` | 10 | 0 | 0 | — |
| Rendering/invalidation corpus | `.canvas-controller-getter-task-5-rendering.xcresult` | 92 | 1 known checker method | 0 | 11.345 s |
| Rendering/invalidation, checker oracle excluded | `.canvas-controller-getter-task-5-rendering-excluding-checker.xcresult` | 92 | 0 | 0 | 2.387 s |
| Input, geometry, block, and backend corpus | `.canvas-controller-getter-task-5-input.xcresult` | 75 | 0 | 0 | 5.087 s |
| Final selector/source contracts | `.canvas-controller-getter-task-6-final-contracts.xcresult` | 8 | 0 | 0 | 2.000 s |

These gates cover canvas surface lifecycle, custom-renderer identity,
temporary-attribute invalidation, fragment rendering, attachments, emphasis,
caret and selection geometry, viewport behavior, independent block layout,
interaction ownership, rich-text input, and reference/minimal backend
behavior. No production repair was required after removal.

## Unit, fast, and keyboard gates

The complete unit run
`.canvas-controller-getter-task-6-all-units.xcresult` executed 790 tests in
48.460 seconds:

- 784 passed;
- 6 methods failed;
- 0 skipped.

Five failures were the repository's documented checker-service condition.
The native spelling renderer produced zero red pixels for both stock
`UITextView` and InputDec. The sixth was the documented aggregate-only iPad
demo-layout threshold.

The prescribed checker-excluded run
`.canvas-controller-getter-task-6-units-excluding-checker.xcresult` executed
785 tests in 18.900 seconds: 784 passed, zero skipped, and only the aggregate
iPad threshold failed. The exact unmodified iPad method then passed 1/1 in
`.canvas-controller-getter-task-6-ipad-layout-isolated.xcresult`.

The fast stock/reference/minimal differential
`.canvas-controller-getter-task-6-fast/summary.json` passed 234 tests with
zero failures or skips in 13.102 seconds.

The real-system-keyboard runner
`.canvas-controller-getter-task-6-keyboard/summary.json` passed all 24
sentinels with zero failures or skips:

| Group | Passed | Duration |
| --- | ---: | ---: |
| English | 20 | 645.565 s |
| Japanese | 2 | 37.021 s |
| Chinese | 2 | 39.240 s |

The runner wall duration was 802 seconds. The
`inline-accept-minimal` and `inline-dismiss-before-boundary` cases each used
one normal keyboard-readiness retry and then passed. Retry artifacts remain
under the runner output.

## Known harness conditions

Two pre-existing simulator-wide conditions recurred:

1. Native spelling-marker pixels were unavailable for stock and custom
   editors even though the checker recognized the misspelling. The five
   documented pixel methods failed without a stock/custom divergence.
2. `testRegularIPadLayoutUsesHorizontalControlRowsAndReachableEditor` measured
   an editor height of 878 rather than greater than 900 only in the aggregate
   process. The exact method passed unchanged in isolation.

All evidence was retained. No assertion, timeout, or threshold was weakened,
and neither condition implicates the removed controller-getter forwarders.

## Preserved private families

This pass did not change:

- text-container registration, `textContainerOrigin`, or
  `invalidateTextContainerOrigin`;
- private TextKit graph construction or controller installation;
- rendering-surface, attachment, paragraph-anchored attachment, or emphasis
  callbacks;
- selection, interaction, loupe, floating cursor, or autoscroll behavior;
- spelling, autocorrection, inline prediction, writing-tools, or IME
  callbacks;
- viewport lifecycle, environment notification, state-getter, or block-layout
  callback families;
- `textColor`, `isEditable`, `isEditing`, block layout, or drawing
  architecture.

## Deferred next reduction

The next pass should choose one narrowly bounded remaining canvas callback
family and repeat the same UIKitCore/UIFoundation receiver-provenance process.
The controller-getter family is closed: all three canvas duplicates are
removed, while reachable outer/controller/context providers are now protected
by positive source and behavior contracts.

## Commits

| Commit | Purpose |
| --- | --- |
| `34272db` | Design the canvas controller-getter reduction |
| `fa2181b` | Plan the cross-framework classification and certification |
| `abb3408` | Record UIKitCore/UIFoundation caller graphs and decisions |
| `5826a30` | Lock project-owned getter behavior |
| `413abe6` | Add classification-dependent runtime and source contracts |
| `c120fbc` | Remove the three redundant canvas forwarding getters |

The working tree contained unrelated user changes and historical result
artifacts throughout this pass. Only task-specific documentation, test hunks,
and the three-method production deletion were staged in the commits above.
No result bundle or runner output was staged.
