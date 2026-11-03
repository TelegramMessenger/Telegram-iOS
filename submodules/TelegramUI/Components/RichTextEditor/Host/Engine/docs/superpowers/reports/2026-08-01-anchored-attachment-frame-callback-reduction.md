# Anchored Attachment Frame Callback Reduction Report

## Outcome

InputDec no longer implements or advertises UIKit's private
`frameForAnchoredTextAttachment:associatedLayoutFragment:` callback. The
project-owned anchored wrapper now calls
`id_frameForParagraphAnchoredAttachment:layoutFragment:` directly. The
existing geometry algorithm, retained fragment capabilities, attachment
provider lifecycle, and drawing fallback were not changed.

The change is split into evidence, behavior-lock, contract, and production
commits: `079e075`, `fcda631`, `b3eafa1`, and `05dce82`. The design and plan
are `2b75d08` and `645b351`.

## Removed and retained private surface

Removed from `IDTextLayoutCanvasView+PrivateCallbacks.m`:

- the private callback declaration;
- its forwarding implementation; and
- its broad callback-boundary allowlist entry.

Retained unchanged:

- `boundsForTextParagraphAnchoredAttachment:`;
- `textAttachmentViewProviderForTextParagraphAnchoredAttachment:` and the
  provider's `view` capability;
- `drawTextParagraphAnchoredAttachment:bounds:context:`;
- `supportsAnchoredTextAttachments` and `anchoredTextAttachments`; and
- `reference.anchoredBounds`, `reference.anchoredProvider`, and
  `reference.anchoredDraw` in the iOS 26.5 behavior manifest.

The retained helper header, implementation, and manifest have no diff from
the production-change parent. They remain a separate private-surface family
and are not implicitly classified by this pass.

## Project-owned geometry architecture

`IDTextParagraphAnchoredAttachmentSurface.layoutSubviews` loads its weak
canvas, attachment, and fragment references and calls the project method
directly. The canvas continues to obtain fragment-relative anchored bounds,
convert from a realized fragment surface when available, or compose the
fragment origin and text-container origin when it is not. It then validates
finite geometry and normalizes the horizontal extent to the canvas width.

This keeps frame policy in the custom layout/drawing layer while UIKit still
owns the retained fragment-side discovery, provider, and draw operations.
No dynamic selector alias, forwarding target, protocol callback, KVO hook,
or notification recreates the removed selector.

## Hopper caller, receiver, and ABI evidence

On UIKitCore from iOS 26.5 build 23F73, Hopper resolves the implementation at
`0xc07820` and its message stub at `0x2206020`. The four-basic-block method
accepts the attachment in `x2`, the layout fragment in `x3`, and returns the
four `CGRect` doubles in `v0` through `v3`.

The message stub has one caller: the send at `0xd06a70` in
`-[_UITextParagraphAnchoredAttachmentView layoutSubviews]` (`0xd069f4`). The
wrapper receives its weak canvas from the concrete
`_UITextLayoutCanvasView` update block at `0xc075b4`; that block captures the
concrete canvas weakly at `0xc07414`-`0xc07468` and passes the reloaded object
to the wrapper initializer at `0xc076b4`-`0xc076dc`. The initializer at
`0xd0692c` stores that exact argument. There is no arbitrary provider or
protocol receiver path, so `IDTextLayoutCanvasView` is unreachable.

Exact `strings`, `nm`, and Objective-C metadata searches against the matching
UIFoundation binary found neither the selector nor the stock wrapper class.

## Runtime sender evidence

The pre-change focused baseline
`.anchored-frame-callback-task-1-baseline-1.xcresult` passed 38/38. Temporary
logs at both the private adapter and project geometry entry produced five
project calls and zero private calls while exercising realized surfaces,
scroll/removal, nonzero-origin fallback, provider-backed drawing, and
nil-provider drawing. The characterization bundle
`.anchored-frame-callback-task-1-characterization-1.xcresult` passed 4/4.
The logs were then removed and source inventory confirmed no instrumentation
remained.

The combined static and runtime classification is `safe-to-remove`.

## Surface conversion and fallback geometry

The behavior locks cover both paths. A realized fragment surface is converted
into canvas coordinates and preserves the exact anchored bounds. Without a
surface, the frame composes the fragment frame origin with the nonzero text
container origin. Repeated layout preserves both provider identity and
provider-view identity and does not duplicate viewport-entry publication.

## Horizontal normalization and invalid geometry

Table-driven locks cover left clipping, right clipping, a frame wider than
the canvas, a fully offscreen frame, and zero-width intersections. Vertical
origin and height remain unchanged. Nonfinite anchored bounds, fragment
frames, text-container origins, and composed results throw rather than
installing invalid view geometry.

One planned expectation was corrected before production code changed:
`CGRectGetWidth` standardizes a synthetic negative-width rectangle to a
positive width. The final test therefore locks standard `CGRect` behavior
instead of incorrectly requiring negative bounds to behave like zero width.

## Surface, provider, and lifecycle identity

Tests lock one project wrapper per attachment, exact provider reuse, provider
view containment, removal when a fragment leaves the viewport, fallback draw
suppression when a provider exists, fallback drawing when it does not, and
flush removal. These behaviors remain owned by
`IDTextCanvasAttachmentCoordinator` and the project wrapper; callback removal
did not change their ordering or ownership.

## Focused RED/GREEN evidence

The intentional RED bundle
`.anchored-frame-callback-task-3-contracts-red-1.xcresult` failed for only the
new contract reasons: the project selector did not yet exist, the private
selector was still installed on the receiver, and source inventory still
found the adapter/caller/allowlist. After the production change,
`.anchored-frame-callback-task-4-focused-green-1.xcresult` passed 32/32 with
zero failures and skips.

The strengthened coordinator suite
`.anchored-frame-callback-task-2-behavior-green-2.xcresult` passed 30/30.

## Attachment, rendering, block, and interaction verification

All focused runs used pinned simulator
`FA6F7462-AA97-42FE-9E57-8DA0593CE756`, iOS 26.5 build 23F73, the repository
XCTest lock, and `-parallel-testing-enabled NO`:

| Evidence | Scope | Passed | Failed | Skipped |
| --- | --- | ---: | ---: | ---: |
| `.anchored-frame-callback-task-5-canvas-1.xcresult` | attachment coordinator, canvas, editor | 94 | 0 | 0 |
| `.anchored-frame-callback-task-5-rendering-1.xcresult` | rendering, canvas parity, spelling | 51 | 0 | 0 |
| `.anchored-frame-callback-task-5-blocks-1.xcresult` | independent blocks and rich text | 129 | 0 | 0 |
| `.anchored-frame-callback-task-5-interaction-1.xcresult` | selection, touch, autoscroll, floating cursor | 65 | 0 | 0 |

## Full unit and fast results

The fresh-derived-data unit bundle
`.anchored-frame-callback-task-6-all-units-1.xcresult` passed 818/818 with
zero failures and skips. The bounded semantic differential at
`.anchored-frame-callback-task-6-fast-1/summary.json` passed 240/240 with zero
failures and skips in 12.69 seconds.

## Differential and real-system-keyboard results

The current-tree real-system-keyboard sentinel summary at
`.anchored-frame-callback-task-6-ios26-certification-2/keyboard-sentinels/summary.json`
passed 24/24: 20 English autocorrection, inline-prediction, floating-cursor,
and inline-formatting rows; two Japanese rows; and two Simplified Chinese
rows. The harness used its bounded readiness retry for two inline-prediction
methods. Successful attempts and discarded readiness attempts are preserved.

The complete IME, autocorrection, and inline-prediction matrices are being
collected under `.anchored-frame-callback-task-6-ios26-certification-2/`.
Their final counts are recorded below after completion.

## Environmental reruns

The first certification attempt stopped in the minimal English autocorrection
row because the pinned simulator inherited host preferences
`AppleLanguages = [en-US, ru-PT]` and
`AppleLocale = en_US@rg=ptzzzz`; UIKit switched the active keyboard to
`ru-RU`, so an English correction candidate could not exist. This is the same
environmental condition documented by the July 29 reduction pass.

Normalizing only the pinned simulator to `en-US`/`en_US` made the row remain
`en-AU`. The first isolated probe then encountered the runner's ordinary
candidate-readiness condition; the fresh sentinel runner's bounded retry
passed it. A later IME provisioning reboot reapplied the host preferences and
stalled `CoreLocationMigrator`. That attempt was interrupted before any IME
host execution, the pinned device was shut down cleanly, and an untracked
pinned-UDID-only `xcrun` shim restored the normalized values immediately
after each subsequent boot. No host preference and no other simulator was
modified. The temporary shim is removed after certification.

## Worktree preservation

The repository began this pass with unrelated tracked changes in the block
editor, private UIKit support, IME scripts and fixture, tests, and Hopper
notebook, plus extensive untracked research evidence. Production and test
commits staged only callback-specific files or hunks. In particular, the
unrelated Russian-fallback fixture hunk in `IDProjectSmokeTests.m` remains
unstaged and unchanged by this pass.

## Remaining private anchored-attachment surface

The remaining private surface is the fragment helper family listed above,
not a canvas callback. It still determines fragment-owned anchored bounds,
provider discovery, fallback drawing, and capability/attachment enumeration.
Ordinary attachment provider placement and the typed project lifecycle sink
are outside this reduction.

## Recommended next reduction pass

Investigate `boundsForTextParagraphAnchoredAttachment:` first as the next
narrow pass. It is the geometry primitive consumed by both wrapper placement
and fallback drawing, so it offers a meaningful reduction if its fragment
layout calculation can be recovered without duplicating provider lifecycle.
Keep provider discovery and drawing separate until bounds parity is locked
for realized, fallback, invalid, and independent-block layouts.
