# Block Render-Space Conversion Withdrawal Report

Date: 2026-08-07  
Compatibility boundary: UIKitCore iOS 26.5, build 23F73  
Decision: `safeFallback`; permanently remove the block interaction-host
`_convertPointFromRenderSpace:` callback and its required ABI row.

## Scope and result

This pass removed only:

- `-[IDBlockTextView(PrivateInteractionCallbacks) _convertPointFromRenderSpace:]`;
- the `_convertPointFromRenderSpace:` member of `IDInteractionHostABISpecs`.

The previously authorized absence of the block host's
`customRenderController` callback remains intact. The final block interaction
host therefore has neither render-fallback selector, and its required ABI list
contains neither row. Runtime contracts prove true absence: inherited lookup
with `class_getInstanceMethod` returns `NULL`, the live block editor does not
respond to either selector, and interaction-host validation succeeds without
them. No forwarding target, dynamic resolution, alternate selector, identity
shim, or replacement coordinate-conversion layer was introduced.

UIKit-owned selection handles, loupe, gestures, autoscroll interaction,
floating cursor, and transient chrome retained their observed stock parity.
Project-owned document geometry, layout, and drawing remain unchanged.

## Baseline integrity

The pre-experiment Git object hashes were:

| Surface | Baseline SHA-1 |
| --- | --- |
| `IDBlockTextView+PrivateInteractionCallbacks.m` | `9434896430a86eb79e701edd4be99096b1844e60` |
| `IDPrivateUIKit.m` | `644ddbe83121d79bcb74ffcd745a2a9cbbf95436` |
| production behavior manifest | `d2143fb0a8d056793885a4a1ea117d93a83fff59` |
| test-only behavior manifest | `bca0b918c3d6f490772834379244a78f682d94c0` |
| flat interaction callbacks | `03408d1ac1a25608e51a1e84ef637502cde49a1d` |
| canvas bridge | `76fdd6e28dfbfa3e43fcd847e08dcefb217bf8a3` |
| block canvas callbacks | `0afc81e2e1166bbbb2a9435d1e37a423e0d6ef09` |
| `IDTextLayoutCanvasView.m` | `62c33125d9ab44fa1edae8b294a7afa17533ebcd` |

The block callback initially contained the exact identity implementation, and
the interaction ABI contained exactly one matching row. The block
`customRenderController` method and ABI row were already absent. Manifest
accounting began at 127 production members, 53 reference-only members, and 24
test-only members. The selector's manifest occurrences were classified by
their declared source; none represented the block-host callback, so no
manifest edit was authorized.

The repository already had unrelated tracked exploration changes. The index
was empty, no XCTest process was active, and `git diff --check` passed before
the experiment. Those changes were preserved without staging, reset, cleanup,
commit, simulator creation, or simulator reset.

## Hopper receiver evidence

The selected Hopper document was UIKitCore iOS 26.5 build 23F73. All addresses
below are file-relative.

- `-[UITextView _convertPointFromRenderSpace:]` is at `0x16107b0`. It asks for
  `customRenderController`; a nil renderer follows the branch at `0x16107dc`
  to the identity return at `0x1610804`. A capable nonnil renderer receives
  `convertPointFromRenderSpace:`.
- `_objc_msgSend$_convertPointFromRenderSpace:` is at `0x21293c0`. Its only
  direct xref is the send at `0xc3e6cc` in
  `-[_UITextKit2LayoutController cursorPositionAtPoint:inContainer:]`, whose
  procedure begins at `0xc3e60c`.
- That TextKit 2 controller weak-loads its `_textView` and sends the callback
  unconditionally when the weak receiver exists. It has no
  `respondsToSelector:` guard and no missing-selector fallback.
- `-[UITextInteractionAssistant _updateRenderSpaceConversionConformance]` at
  `0x156370c` probes only `_convertPointToRenderSpace:textRange:` and
  `_convertPointToRenderSpace:textPosition:`. It neither probes nor sends the
  withdrawn selector.

This unconditional UIKit receiver is relevant to the flat editor, which uses
`_UITextKit2LayoutController`; the flat callback therefore remains required.
The block editor instead installs the project-owned
`IDRichTextLayoutController`, which owns its cursor-position path and never
enters the UIKit TextKit 2 receiver above. Static evidence authorized only a
paired block-host true-absence experiment. It did not by itself authorize
deletion.

## Paired true-absence experiment

The existing two focused contracts first passed in
`.render-space-withdrawal-task2-prior-contracts.xcresult` (2 passed, no
failures or skips). TDD then established both failure modes:

| Artifact | Expected result | Observed |
| --- | --- | --- |
| `.render-space-withdrawal-task2-runtime-red.xcresult` | method, response, and ABI still present | 1 failed, 0 skipped |
| `.render-space-withdrawal-task2-source-red.xcresult` | paired exact source guards absent | 1 failed, 0 skipped |
| `.render-space-withdrawal-task2-source-green.xcresult` | source guards paired and narrowly scoped | 1 passed, 0 skipped |
| `.render-space-withdrawal-task2-runtime-green.xcresult` | true absence with both controls enabled | 1 passed, 0 skipped |

The temporary controls were
`ID_WITHDRAW_BLOCK_RENDER_SPACE_CONVERSION` and
`ID_OMIT_BLOCK_RENDER_SPACE_CONVERSION_ABI`. A method-only build under
`.render-space-withdrawal-task2-unpaired-method-derived` and an ABI-only build
under `.render-space-withdrawal-task2-unpaired-abi-derived` both failed to
compile. Each diagnostic artifact contains the exact message:

```text
Block render-space conversion withdrawal controls must be paired
```

Thus the test could never accidentally characterize a half-withdrawn host.

## Withdrawal-build characterization

One paired withdrawal build was created under
`.render-space-withdrawal-task3-derived` and reused without rebuilding between
groups. Its focused absence, ABI, integration, and protected-provider suite
passed 74 tests with zero failures or skips in
`.render-space-withdrawal-task3-units.xcresult`.

The exact 17-consumer selection/geometry/native-chrome matrix passed 17 tests
with zero failures or skips in
`.render-space-withdrawal-task3-consumers.xcresult`. It covered public
selection geometry across independent blocks, mixed-BiDi endpoint roles,
large-document select-all, native handles and loupe, structural-boundary and
autoscroll handle drags, floating-cursor anchor crossing/reversal/BiDi cases,
and the reduced-surface batched touch/floating checkpoints.

The experimental app's `InputDec.debug.dylib` contained:

```text
present -[IDTextView(PrivateInteractionCallbacks) customRenderController]
present -[IDTextView(PrivateInteractionCallbacks) _convertPointFromRenderSpace:]
absent  -[IDBlockTextView(PrivateInteractionCallbacks) customRenderController]
absent  -[IDBlockTextView(PrivateInteractionCallbacks) _convertPointFromRenderSpace:]
```

No block ABI row or forwarding substitute existed in that build. Complete
method-surface absence plus the green unit and UI differential authorized the
single decision `safeFallback`.

## Permanent deletion and normal-build evidence

Before production deletion, the permanent runtime contract failed only because
the conversion method, response, and ABI row remained; block
`customRenderController` absence was already satisfied:

- `.render-space-withdrawal-task4-runtime-red.xcresult`: 1 failed, 0 skipped.

The permanent source audit likewise failed while the experiment controls,
method, and ABI row remained:

- `.render-space-withdrawal-task4-source-red.xcresult`: 1 failed, 0 skipped.

After deleting the exact method and ABI row and removing all temporary control
infrastructure, the focused normal-build gate passed 73 tests with no failures
or skips in
`.render-space-withdrawal-task4-permanent-focused.xcresult`.

The complete normal-build gates were:

| Gate | Result |
| --- | --- |
| wrapper-boundary repair audit, `.render-space-withdrawal-task5-wrapper-audit.xcresult` | 1 passed, 0 failed/skipped |
| complete units, `.render-space-withdrawal-task5-all-units.xcresult` | 970 passed, 0 failed/skipped |
| exact final UI consumers, `.render-space-withdrawal-task5-consumers.xcresult` | 17 passed, 0 failed/skipped in 487.807 seconds |
| fast semantics, `.render-space-withdrawal-task5-fast` | 271 passed, 0 failed/skipped, 13.682 seconds, no semantic retry |
| optimized Release, `.render-space-withdrawal-task5-release-derived` | build succeeded |

The complete-unit gate initially exposed a source-boundary fixture issue: an
integration absence assertion spelled the private selector as one raw literal,
which the standing wrapper audit correctly rejected. Splitting the test-only
selector spelling preserved the runtime absence assertion without widening
production private-API use. The dedicated wrapper audit and the corrected full
unit gate then passed as recorded above.

## Final binary, source, and inventory audit

The optimized Release app binary contains:

```text
present -[IDTextView(PrivateInteractionCallbacks) customRenderController]
present -[IDTextView(PrivateInteractionCallbacks) _convertPointFromRenderSpace:]
absent  -[IDBlockTextView(PrivateInteractionCallbacks) customRenderController]
absent  -[IDBlockTextView(PrivateInteractionCallbacks) _convertPointFromRenderSpace:]
absent  ID_WITHDRAW_BLOCK_RENDER_SPACE_CONVERSION
absent  ID_OMIT_BLOCK_RENDER_SPACE_CONVERSION_ABI
```

The block callback sources contain neither implementation nor a forwarding or
dynamic-resolution substitute. `IDInteractionHostABISpecs` contains neither
block render-fallback row. The same conversion selector still appears in the
explicitly retained flat callback and test-only inspection wrapper; those are
not block-host implementations.

Final manifest counts remain `127`, `53`, and `24`. The manifests and all four
protected flat/canvas files retain their baseline hashes. Authorized final
hashes are:

| Surface | Final SHA-1 |
| --- | --- |
| `IDBlockTextView+PrivateInteractionCallbacks.m` | `02a187788a2d2f2856518a0cdde1af6feada694d` |
| `IDPrivateUIKit.m` | `f873dab48c55e3ccf3a8d77fd5a5bbf59085e35f` |
| `IDInteractionCallbackWithdrawalTests.m` | `347f79f4d5c0bc1b829cb458653ec6e90bad9a02` |
| `IDProjectSmokeTests.m` | `630556d1de643cde98c0faf234a8b9ddc8f70c54` |
| `IDBlockTextViewIntegrationTests.m` | `f77b29752f2a530ecc9c56af818fada350413833` |

Two consecutive `xcodegen generate` runs produced the same project SHA-256:

`0d899d8134f9dcd59fa86ce98314a752602cdd8b1839e82651df3d20a14ff462`

The generated project has no tracked diff, `git diff --check` passes, and the
index remains empty. The unrelated dirty-tree entries recorded before this
pass remain present; this work did not stage, reset, clean, or commit them.

## Retained authority boundary

Both render-fallback selectors are absent only from the block interaction host
and its required interaction ABI. The following distinct authorities remain
intentional:

- the flat `IDTextView` implementation of `_convertPointFromRenderSpace:`,
  because UIKit's `_UITextKit2LayoutController` sends it unconditionally;
- `IDPrivateUIKit+TextLayoutCanvas` canvas/context coordinate-conversion
  bridges;
- `IDTextLayoutCanvasView.id_customRenderController`, the flat editor's
  `customRenderController`, and
  `IDBlockLayout(PrivateCanvasCallbacks).customRenderController`;
- the project-owned selection container and presentation backend;
- `IDRichTextLayoutController`, block geometry, document projection, canvas
  placement, layout, and drawing.

This preserves one customizable project layout/drawing authority while UIKit
continues to own the native interaction presentation pipeline.

## Compatibility boundary and remaining risk

This authorization is limited to UIKitCore iOS 26.5 build 23F73 and the tested
iOS 26 driver on simulator
`FA6F7462-AA97-42FE-9E57-8DA0593CE756`. Private receiver ownership can change
on another UIKit build. Supporting another OS version requires repeating the
receiver trace, true-absence experiment, stock differential, and optimized
binary audit there. In particular, this result does not authorize removing the
flat callback or any project canvas/context rendering provider.
