# Block `customRenderController` Withdrawal Report

Date: 2026-08-07  
Compatibility boundary: UIKitCore iOS 26.5, build 23F73  
Decision: `safeFallback`; permanently remove the block interaction-host callback and its required ABI row.

## Scope and result

This pass removed only:

- `-[IDBlockTextView(PrivateInteractionCallbacks) customRenderController]`;
- the `customRenderController` member of `IDInteractionHostABISpecs`.

The block host still implements the identity conversion
`-[IDBlockTextView(PrivateInteractionCallbacks) _convertPointFromRenderSpace:]`.
UIKit-owned selection, handles, loupe, autoscroll, and floating-cursor behavior
continued to match the stock oracle with the callback truly absent.

This is not a general removal of custom-render-controller support. The following
distinct project rendering surfaces are intentionally retained:

- `IDTextLayoutCanvasView.id_customRenderController`;
- the flat editor's `customRenderController` provider;
- `IDBlockLayout(PrivateCanvasCallbacks).customRenderController`;
- the canvas/context custom-renderer bridges in
  `IDPrivateUIKit+TextLayoutCanvas`.

## Baseline integrity

The pre-withdrawal source hashes were:

| Surface | Baseline SHA-1 |
| --- | --- |
| `IDBlockTextView+PrivateInteractionCallbacks.m` | `2224141b035c9ce344df8ff1021f53254a272b5` |
| `IDPrivateUIKit.m` | `99aeb4631c5cfaacb6e241b302fc7b65ea411e58` |
| production behavior manifest | `d2143fb0a8d056793885a4a1ea117d93a83fff59` |
| test-only behavior manifest | `bca0b918c3d6f490772834379244a78f682d94c0` |
| `IDTextLayoutCanvasView.m` | `62c33125d9ab44fa1edae8b294a7afa17533ebcd` |
| flat interaction callbacks | `03408d1ac1a25608e51a1e84ef637502cde49a1d` |
| block canvas callbacks | `0afc81e2e1166bbbb2a9435d1e37a423e0d6ef09` |

The final hashes of the two deliberately changed production files are:

- `IDBlockTextView+PrivateInteractionCallbacks.m`:
  `9434896430a86eb79e701edd4be99096b1844e60`;
- `IDPrivateUIKit.m`: `644ddbe83121d79bcb74ffcd745a2a9cbbf95436`.

Both manifests and all three protected provider files retained their exact
baseline hashes. Manifest accounting remained 127 production members, 53
reference-only members, and 24 test-only members.

## Receiver evidence and controlled experiment

The existing Hopper receiver trace in `docs/hopper/UIKitCore-iOS26.5.md` showed
that UIKit's relevant receiver path tolerates the block host not providing this
selector. No contradictory iOS 26.5 receiver evidence was found, so the Hopper
document required no edit.

The experiment paired two compile controls so the method and required ABI row
could never be withdrawn independently. The permanent source guard test first
failed before those controls existed:

- `.custom-render-withdrawal-task2-source-red.xcresult`.

The corrected runtime absence contract failed with the method present:

- `.custom-render-withdrawal-task2-runtime-red2.xcresult`.

After adding the paired controls, both focused contracts passed:

- `.custom-render-withdrawal-task2-source-green.xcresult`;
- `.custom-render-withdrawal-task2-runtime-green.xcresult`.

Method-only and ABI-only builds each failed compilation with the exact pairing
diagnostic, recorded under:

- `.custom-render-withdrawal-task2-unpaired-method-derived`;
- `.custom-render-withdrawal-task2-unpaired-abi-derived`.

The withdrawal build was created once under
`.custom-render-withdrawal-task3-derived` and reused for all characterization.
Its evidence was:

- 96 absence, ABI, and protected-renderer unit tests passed in
  `.custom-render-withdrawal-task3-units.xcresult`;
- 2 batched native-chrome differentials passed in
  `.custom-render-withdrawal-task3-batched-ui.xcresult`;
- all 15 explicit consumers passed in
  `.custom-render-withdrawal-task3-consumers.xcresult`.

The experimental binary contained the block host's identity conversion and no
block-host `customRenderController` method. Other flat/canvas providers remained
present. This complete green result authorized `safeFallback` and unconditional
deletion.

## Permanent normal-build contracts

Before production deletion, the permanent runtime contract failed three
assertions because the normal build still had the method and ABI row:

- `.custom-render-withdrawal-task4-runtime-red.xcresult`.

The permanent source audit failed six assertions because the controls, callback,
and ABI row were still present:

- `.custom-render-withdrawal-task4-source-red.xcresult`.

After deleting only the authorized method, ABI row, and temporary controls, the
focused normal-build suite passed 101 tests with zero failures or skips:

- `.custom-render-withdrawal-task4-permanent-focused.xcresult`.

The complete unit target initially exposed one stale integration assertion: it
called a testing wrapper that intentionally throws when `customRenderController`
is unavailable. The production behavior was already correct. The assertion was
changed to require true selector absence, passed alone in
`.custom-render-withdrawal-task5-integration-repair.xcresult`, and the complete
unit target then passed 969 of 969 tests with zero skips in
`.custom-render-withdrawal-task5-all-units-green.xcresult`.

The remaining final gates passed:

- 17 of 17 explicit UI consumers, comprising the 15-consumer matrix and two
  batched native-chrome authority methods, in
  `.custom-render-withdrawal-task5-consumers.xcresult`;
- 270 of 270 fast semantic tests, with zero failures, skips, or semantic retry,
  under `.custom-render-withdrawal-task5-fast`;
- optimized Release simulator build under
  `.custom-render-withdrawal-task5-release-derived`.

## Final binary and source audit

The optimized Release app binary has:

```text
absent  -[IDBlockTextView(PrivateInteractionCallbacks) customRenderController]
present -[IDBlockTextView(PrivateInteractionCallbacks) _convertPointFromRenderSpace:]
absent  ID_WITHDRAW_BLOCK_CUSTOM_RENDER_CONTROLLER
absent  ID_OMIT_BLOCK_CUSTOM_RENDER_CONTROLLER_ABI
```

The final source scan found no experiment token in `App`, `TextView`,
`PrivateUIKit`, `Tests`, `UITests`, `Scripts`, or `project.yml`. The block
interaction category has no dynamic forwarding substitute. The same-named code
remaining in `IDPrivateUIKit.m` is the explicitly test-only inspection wrapper,
not an interaction-host implementation or forwarding path.

Two consecutive `xcodegen generate` runs produced the identical project SHA-256:

`0d899d8134f9dcd59fa86ce98314a752602cdd8b1839e82651df3d20a14ff462`

The generated project has no tracked diff, `git diff --check` passes, and the
index remains untouched. The repository already contained unrelated tracked
exploration changes; this pass preserved them and did not stage, reset, clean,
or commit anything.

## Remaining risks and next boundary

The authorization is specific to UIKitCore iOS 26.5/23F73. Private receiver
behavior can change on another OS build, so expanding the compatibility range
requires the same receiver trace, true-absence experiment, stock differential,
and optimized-binary audit on that build. The retained flat/canvas rendering
surfaces must not be inferred removable from this result: they serve the custom
layout and drawing authority rather than the withdrawn block interaction-host
fallback.

The next reduction should target another independently characterized block-host
callback. It should preserve the now-established boundary: UIKit may own native
interaction presentation while project-owned document geometry and canvas
rendering remain the single customizable layout/drawing authority.
