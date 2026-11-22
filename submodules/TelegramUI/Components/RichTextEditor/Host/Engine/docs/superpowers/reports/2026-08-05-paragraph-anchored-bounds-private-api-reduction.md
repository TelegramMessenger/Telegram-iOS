# Paragraph-Anchored Bounds Private-API Reduction Report

## Outcome

The iOS 26.5 selector
`-[NSTextLayoutFragment boundsForTextParagraphAnchoredAttachment:]` was **not**
removed. Hopper and runtime evidence show that the adapter's origin subtraction
is reproducible, but its input frame is private mutable state produced by
UIFoundation's paragraph layout. Replacing the selector with `frame`, KVC, an
ivar read, or another private callback would only rename the private dependency.

The investigation and test-oracle work completed successfully. The production
private-surface delta is zero.

## Current production consumers

`IDPrivateCanvasParagraphAnchoredBounds` remains declared in
`PrivateUIKit/IDPrivateUIKit+TextLayoutCanvas.h` and implemented in the matching
`.m` file. `IDTextLayoutCanvasView.m` calls it twice:

1. viewport admission for paragraph-anchored surfaces; and
2. final wrapper placement in canvas coordinates.

The iOS 26.5 manifest entry `reference.anchoredBounds` remains present. The
related provider, draw, support, and attachment-enumeration dependencies are
unchanged and outside this pass's removal gate.

## UIFoundation implementation and ABI

Hopper resolves the method at UIFoundation file-relative `0xd64c`. The arm64
ABI receives the fragment in `x0`, the attachment in `x2`, and returns the
four-double `CGRect` in `v0` through `v3`.

The method checks whether `fragment.anchoredTextAttachments` contains the
candidate. A nonmember returns `CGRectZero`. For a member it reads the
attachment frame, subtracts `layoutFragmentFrameOrigin` from x and y, and
preserves width and height. The private origin getter at `0x7b14` tail-calls
the public `layoutFragmentFrame` getter, so that subtraction alone has a public
equivalent.

## Attachment frame provenance

`-[NSTextParagraphAnchoredAttachment frame]` at `0x65d98` copies a stored
32-byte rectangle. `_updateLayoutFrame:` at `0x65d44` writes that storage. Its
message stub has two callers, both inside `-[NSTextLayoutFragment _layout]` and
its block:

- the primary path obtains width and height through the attachment-bounds
  callback, computes x from padding, anchor position, writing direction, and
  available line extent, and computes y from private fragment/line state; and
- the replay path adjusts accumulated exclusion rectangles by a captured
  private vertical delta before writing them back.

InputDec does not own these exact values at the later viewport-admission and
placement call sites.

## UIKitCore consumer closure

UIKitCore's bounds message stub has exactly two callers. The rendering-surface
update block adds the fragment origin and performs viewport intersection. The
stock `frameForAnchoredTextAttachment:associatedLayoutFragment:` method either
converts through a realized fragment surface or adds the fragment and text
container origins for fallback placement. These match InputDec's two semantic
consumers.

## Test-only oracle isolation

Commit `a770bcb` adds an oracle category and fixtures only to
`Tests/IDTextCanvasAttachmentCoordinatorTests.m`. Two deterministic cases lock
the member/nonmember branches and exact rectangle arithmetic. A third case
resolves the private class and attribute constant inside the test target,
performs a real TextKit 2 layout, and compares the inherited method result with
the layout-produced private frame using a one-display-pixel tolerance.

`IDProjectSmokeTests` verifies that the oracle fixture vocabulary is absent
from the production canvas and PrivateUIKit files. The direct private `frame`
send exists only in the real UIKit test oracle and is not a proposed production
dependency.

## Evidence-gate classification

**Classification: `opaque`.**

1. X and y originate in private paragraph/line layout state; width and height
   originate in a public callback invoked with layout inputs unavailable at the
   later consumers.
2. InputDec does not own those exact values before viewport admission and
   placement.
3. Production cannot obtain them at that point without a new private selector,
   class, ivar, callback, or equivalent private contract.

The approved no-swap rule therefore requires retaining the current helper.

## Focused and fast verification

All Simulator XCTest commands used
`Scripts/with-inputdec-simulator-test-lock.sh` and
`-parallel-testing-enabled NO` on iPhone 17 Pro K3 simulator
`FA6F7462-AA97-42FE-9E57-8DA0593CE756`, iOS 26.5 build 23F73.

- Pre-change attachment baseline:
  `.anchored-bounds-task-1-baseline.xcresult`, 8/8 passed.
- Test-only oracle:
  `.anchored-bounds-task-3-oracle2.xcresult`, 4/4 passed.
- Final attachment/canvas/private-contract gate:
  `.anchored-bounds-task-5-focused.xcresult`, 69/69 passed.
- Bounded semantic differential:
  `.anchored-bounds-task-5-fast/summary.json`, 246/246 passed in 11.93 seconds.

Every result reported zero failures and zero skips. The complete real-keyboard
certification was intentionally not rerun because this outcome changes no
production behavior.

## Private-surface delta

Zero. The helper declaration and implementation, both production consumers,
and `reference.anchoredBounds` remain intact. No replacement production
selector, protocol, KVC lookup, ivar offset, or anchored-frame cache was added.

## Worktree preservation

The pass committed only its Hopper evidence section and the two test-file
hunks. Existing tracked edits in the editor, PrivateUIKit, scripts, tests, and
fixtures, plus existing untracked result bundles and diagnostic directories,
were preserved. Generated `.xcresult` and fast-gate output remain untracked and
were not committed.

## Required next pass

Further reduction requires a project-owned paragraph-anchored attachment
layout-frame slice. That pass must compute and own each frame during layout,
define its lifecycle and invalidation rules, and prove viewport admission and
final placement against stock UIKit. It should not replace this getter with a
direct read of `NSTextParagraphAnchoredAttachment.frame` or another private
adapter.
