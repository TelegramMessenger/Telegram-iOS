# Selection-Container Private-Surface Reduction Report

## Outcome

The iOS 26 driver now exposes one selection-container callback on
`IDBlockTextView`: `selectionContainerView`. Four optional callbacks were
removed from the production class and its required interaction-host ABI:

- `_selectionContainerViewAboveText`
- `_existingSelectionContainerView`
- `_placeSelectionContainerView`
- `_updateInteractionGeometry`

UIKit still owns selection handles, the loupe, selection gestures, floating
cursor sessions, and transient selection chrome. No replacement selection,
layout, or geometry authority was introduced. The reduction is authorized only
for UIKitCore iOS 26.5 build 23F73 and this repository's current iOS 26 driver.

Implementation commits are `7bd8165` (production deletion), `4d09953`
(permanent authority gate and temporary-infrastructure deletion), and `642e5d2`
(deterministic XcodeGen fixture exclusion).

## Baseline callback and ABI surface

At baseline, `IDBlockTextView(PrivateInteractionCallbacks)` implemented all
five candidates and `+[IDPrivateUIKit requireInteractionHost:stage:]` required
15 methods, including those five. Manifest counts were 127 production members,
53 reference-only members, and 25 test-only members.

Baseline Git object hashes were:

| Artifact | Baseline hash |
| --- | --- |
| production behavior contract | `d2143fb0a8d056793885a4a1ea117d93a83fff59` |
| test-only behavior contract | `b6b7d08f1cf628a78d30f1a20347cd8dc4c5aacd` |
| block interaction callbacks | `9380140300042646873abcd251ca06697ee403f8` |
| `IDPrivateUIKit.h` | `1e8932f895b1b34deaf62c282c979d30396f97e9` |
| `IDPrivateUIKit.m` | `e6c83173a538ba6917b80606c9a0c27d36370a0a` |

The retained baseline gate passed 108 tests with no failures or skips in
`.selection-container-reduction-task1-baseline.xcresult`.

## Hopper responsibility map

Hopper analysis used the active UIKitCore iOS 26.5/23F73 image. The detailed
pseudocode and call graph are recorded in
`docs/hopper/UIKitCore-iOS26.5.md` under “Selection-container callback reduction
evidence.” The decisive procedures were:

| Address | Procedure | Responsibility |
| --- | --- | --- |
| `0x156cf7c` | `-[UITextInteractionAssistant selectionContainerView]` | asks the host, then falls back to `textInputView` |
| `0x156cffc` | `-[UITextInteractionAssistant selectionContainerViewAboveText]` | asks `_selectionContainerViewAboveText`, then falls back to `textInputView` |
| `0x1615f44` | `-[UITextView selectionContainerView]` | creates/caches/places stock UITextView's private container |
| `0x1615ff0` | `-[UITextView _selectionContainerViewAboveText]` | returns `_contentView` |
| `0x1615ed8` | `-[UITextView _existingSelectionContainerView]` | reads container state without creating it |
| `0x1608d84` | `-[UITextView _placeSelectionContainerView]` | installs the stock container in its canvas or view hierarchy |
| `0x1610f04` | `-[UITextView _updateInteractionGeometry]` | triggers `updateSelectionForTextAnimation` on the assistant |
| `0xa4a228` | `-[_UITextFloatingCursorSession _selectionContainerView]` | obtains `_hostViewAboveText` from display interaction |

The assistant's fallbacks made four callbacks plausible deletions, but Hopper
alone could not prove behavior for a duck-typed custom host. True method
absence and stock-differential runtime tests supplied that authorization.

## True-withdrawal method

The temporary experiment compiled exactly one candidate out of both the class
implementation and required host ABI at a time. Runtime masking was not used as
authorization. Each build proved the candidate absent through
`respondsToSelector:`, exercised the real custom editor, and ran method-surface,
touch, floating-cursor, handle, loupe, highlight, and container-identity checks.

The serial matrix is preserved at
`.selection-container-reduction-task5-matrix2`; follow-up artifacts are named
in `Tests/Fixtures/SelectionCallbackAuthorization-iOS26.5.json`. Temporary
macros, exported experiment helpers, the withdrawal runner, and its command
tests were deleted after authorization.

## Per-candidate runtime evidence

| Candidate | Authorization | Result |
| --- | --- | --- |
| `selectionContainerView` | `requiredNativeChrome` | floating container identity failed twice before motion: unstable container, nil token, and absent assistant/display-session ownership |
| `_selectionContainerViewAboveText` | `safeFallback` | all six method/touch/floating checks passed; UIKit fallback retained visible behavior |
| `_existingSelectionContainerView` | `safeFallback` | all six checks passed; no direct runtime dependency observed |
| `_placeSelectionContainerView` | `safeFallback` | all six checks passed; project backend placement was sufficient |
| `_updateInteractionGeometry` | `safeFallback` | all six checks passed; existing presentation invalidation preserved geometry |

`selectionContainerView` failed again in
`.selection-container-reduction-task5-confirm-selectionContainerView-floating1.xcresult`.
The four safe candidates also passed explicit highlight checks under
`.selection-container-reduction-task5-highlight-safe1`.

## Deleted callbacks

The four `safeFallback` methods are absent specifically from
`IDBlockTextView(PrivateInteractionCallbacks)` and from its static interaction
ABI. Same-named backend properties, canvas methods, flat-editor methods, stock
oracle methods, and diagnostic strings are distinct surfaces and were not
deleted.

The optimized Release binary at
`.selection-container-reduction-task9-release-derived/Build/Products/Release-iphonesimulator/InputDec.app/InputDec`
contains exactly this candidate-family method on the block-host category:

```text
-[IDBlockTextView(PrivateInteractionCallbacks) selectionContainerView]
```

It contains none of the other four block-host category methods and no
`ID_WITHDRAW_`, `IDInteractionWithdrawnCallbackName`, or temporary-runner
string. The Release build succeeded for arm64 and x86_64 simulator slices.

## Retained native-chrome dependencies

`selectionContainerView` is retained because UIKit's floating cursor requires
stable selection-container identity, not merely because stock `UITextView`
implements the selector. The retained method delegates creation and placement
to the project-owned selection-presentation backend while allowing UIKit's
assistant/display-session graph to observe one stable view.

Handles, loupe, interaction recognizers, autoscroll gestures, floating cursor,
and transient chrome remain UIKit-owned. The project continues to own canonical
selection, independent-block layout, coordinate conversion, and backend
placement.

## Conditional highlight outcome

No candidate was `highlightOnly`. All four safe withdrawals retained the
native highlight as well as handles and loupe. The one unsafe withdrawal broke
floating-container identity. Therefore Task 7's conditional custom highlight
overlay was not authorized and no overlay or hybrid backend was added.

## Touch, handles, loupe, autoscroll, and floating evidence

The permanent reduced-surface batch passed 2/2 with zero skips in 61.58 seconds
at `.selection-container-reduction-task8-ui-green1.xcresult`. It covers touch
highlight/handles, handle drag, loupe, scrolling stability, floating motion,
selection extension, reversal, and stock comparison.

The broader 15-consumer run produced 14 passes and one mixed-BiDi
keyboard-selection failure after the large-document test. The failed case then
passed alone in 31.25 seconds at
`.selection-container-reduction-task9-bidi-isolated1.xcresult`, establishing a
batch-order/state leak rather than a deterministic callback regression. All six
touch consumers and all six floating consumers passed in the combined run.

## Debug, Release, semantic, and keyboard verification

- Focused authority/integration: 243/243 passed, zero skips, in
  `.selection-container-reduction-task8-unit-green3.xcresult`.
- Permanent reduced-surface UI batch: 2/2 passed, zero skips, in
  `.selection-container-reduction-task8-ui-green1.xcresult`.
- Fast semantic gate: 266/266 passed, zero skips, 12.758 seconds, in
  `.selection-container-reduction-task9-fast`.
- Release: optimized simulator build succeeded and the class-specific method
  inventory contains only retained `selectionContainerView`.
- Focused real-keyboard floating selection: 4/4 passed, zero skips, 133.254
  seconds, without rebooting or resetting learning, in
  `.selection-container-reduction-task10-keyboard-selection.xcresult`.
- The input-authority diff from `09b0f5c` is empty, so the prior 24/24 keyboard
  certification remains applicable.

The complete 940-test unit target was intentionally not reported green: 932
passed and eight methods failed. Five spelling/pixel methods observed zero red
pixels in both stock `UITextView` and the custom editor. The two predeclared
unrelated failures reproduced (`testEmptyBlockExposesConfiguredDefaultsToNativeTypingAndInsertion`
and `testStockOracleHostContainsNoPrivateRuntimeKnowledgeOrSyntheticLifecycleCounters`).
`testRegularIPadLayoutUsesHorizontalControlRowsAndReachableEditor` failed only
in the complete run and passed in the exact-failure rerun. None of these methods
exercise the removed selection callbacks; no exclusion was used to claim a
green complete target.

## Private inventory and generated-project delta

Final committed counts are 127 production, 53 reference-only, and 24 test-only
members. Production and reference-only manifests are unchanged. The one-entry
test-only reduction reflects deletion of the temporary experimental surface.
Final committed object hashes are:

| Artifact | Final hash |
| --- | --- |
| production behavior contract | `d2143fb0a8d056793885a4a1ea117d93a83fff59` |
| test-only behavior contract | `bca0b918c3d6f490772834379244a78f682d94c0` |
| block interaction callbacks | `2224141b035c9ce344df8ff1021f53254a2722b5` |
| `IDPrivateUIKit.h` | `b480d57bbb44118bfe043e7751a8854aec7bfe38` |
| `IDPrivateUIKit.m` | `742eb70595a976141248a3907f042b5f7b1cf693` |

Two consecutive `xcodegen generate` runs produced the identical project SHA-256
`56496727e0ee98ba6f23e903647ca0e512471731a1f7959723cdef1a5760671f`
and no project diff. `project.yml` excludes the authorization JSON from the
unit-test source glob because it is a source-tree audit fixture, not a bundle
resource.

## iOS 26.5 compatibility boundary

This authorization is deliberately narrow. UIKit private dispatch, fallback
order, and floating-session ownership can change on any OS build. A new driver
or runtime must rerun Hopper responsibility mapping, exact ABI checks, true
absence characterization, and the permanent touch/floating differential before
deleting or retaining a callback. Older OS drivers must not infer this result
from selector spelling alone.

## Worktree preservation

All repository work occurred in the shared exploration tree. Unrelated text
input traits, IME scripts/fixtures, tests, Hopper notes, and generated result
artifacts were preserved and left unstaged. Mixed files were staged hunk by
hunk; the selection-reduction commits do not include the unrelated exploration
changes.

## Next private-surface reduction

The next reduction should target a single remaining interaction-host callback
family with the same class-scoped method-absence discipline. The strongest
candidate is an interaction notification/forwarding callback whose public or
project-owned equivalent already exists. `selectionContainerView` should not
be revisited until the project intentionally owns the complete transient
selection-container/display-session identity contract; the current evidence
shows that removing it would trade one private selector for a larger and more
fragile reimplementation.
