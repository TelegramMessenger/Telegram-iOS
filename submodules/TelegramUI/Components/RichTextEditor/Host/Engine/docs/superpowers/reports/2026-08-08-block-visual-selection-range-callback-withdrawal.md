# Block visual-selection-range callback withdrawal report

Date: 2026-08-08  
Runtime: iOS 26.5 build 23F73, iPhone 17 Pro K3 simulator  
Simulator UDID: `FA6F7462-AA97-42FE-9E57-8DA0593CE756`

## Decision and exact private-surface delta

Decision: `safeFallback` for
`-[IDBlockTextView(PrivateCallbacks)
_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:]` on the
pinned runtime.

The permanent ordinary source removes only the outer block callback and its
block-specific plumbing:

- the forwarding method on `IDBlockTextView(PrivateCallbacks)`;
- the corresponding row from `IDInteractionHostABISpecs()`;
- `IDPrivateRequireBlockTextViewVisualSelectionABI` and its declaration and
  construction-time call; and
- the temporary withdrawal header, compile switches, trace bridge, and paired
  experiment branches.

The rich-layout private incoming callback remains unconditional on
`IDRichTextLayoutController(PrivateCallbacks)`. Its clean-room implementation,
`id_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:`, is the
single project algorithm authority. The production behavior manifest still
owns the selector at
`PrivateUIKit/IDRichTextLayoutController+PrivateCallbacks.m`, not at the outer
block view. The authorization record is
`Tests/Fixtures/BlockVisualSelectionRangeCallbackAuthorization-iOS26.5.json`.

## UIKitCore stock forwarder and guarded fallback evidence

All addresses are file-relative addresses from UIKitCore iOS 26.5 build
23F73.

| Address | Recovered role |
| --- | --- |
| `0x1616060` | `-[UITextView _visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:]`; loads `_textLayoutController` and forwards the same selector |
| `0x21b30e0` | selector message-send stub |
| `0xc3c988` | `-[_UITextKit2LayoutController _visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:]` |
| `0x1576b20` | `-[UITextSelection _boundedOrInvertedSelectionRangeForExtent:forPoint:fromPosition:inDirection:]` |
| `0x1576bcc` | guarded document send inside that selection procedure |
| `0xc69c6c` | `-[UITextSelectionDisplayInteraction _initWithTextInput:delegate:activated:]` |
| `0xc6b750` | `-[UITextSelectionDisplayInteraction _activeSelection]` |
| `0x1574a24` | `-[UITextSelection initWithDocument:]` |
| `0x1577adc` | `-[UITextSelection document]` |
| `0x107e9a4` | `-[_UIKeyboardTextSelectionController selection]` |

The native display interaction stores the supplied text input weakly and later
constructs `UITextSelection` with that object as its document. The live
receiver can therefore be the outer `IDBlockTextView`, even though the rich
controller owns InputDec's visual-selection algorithm.

The recovered `UITextSelection` procedure explicitly checks
`respondsToSelector:` before the send at `0x1576bcc`. When the document lacks
the selector, or when the callback yields no range, UIKit continues through
its ordinary public text-input operations: it constructs a range from the two
positions, compares and conditionally reverses endpoints, and otherwise uses
caret geometry, the point's relevant axis, closest-position lookup, and
tokenizer boundary navigation to bound the selection. This is a guarded
fallback rather than an unguarded private requirement.

The complete Hopper ledger is in `docs/hopper/UIKitCore-iOS26.5.md` under
“Block visual-selection-range callback withdrawal evidence.”

## Retained invocation and withdrawn lookup observations

The retained diagnostic instrumented the outer forwarder passively. Native
handle/floating interactions invoked it, and the trace recorded the canonical
extent, anchor, direction, point, and resulting selection without introducing
a synthetic selector send. The retained callback forwarded once to the rich
controller and contained no local range algorithm.

The withdrawn build removed the method itself, not merely its body. Runtime
method-list inspection observed:

- no local provider on `IDBlockTextView`;
- `respondsToSelector:` false for the outer candidate;
- no outer ABI row or block-only ABI preflight; and
- the rich controller's local provider still present.

The ordinary permanent probe now publishes selector-free schema 4 ownership
data. It does not send the candidate selector and contains no trace storage.
Source/runtime tests reject forwarding, `forwardInvocation:`, and dynamic
method-resolution substitutes for the deleted outer provider.

## Rich-controller authority and neutral-range repair

Direct custom parity tests now invoke the rich controller authority. Stock
comparisons continue to send the private selector to stock `UITextView` as the
oracle. This prevents tests from preserving the optional outer boundary merely
because they call it directly.

The expanded authority matrix added empty-middle-block, extended-family-emoji,
and mixed-bidirectional cases without mutating the document. It exposed a
pre-existing cross-block bidi anchor discrepancy: stock returned canonical
range `{5,7}` while custom returned `{6,6}`. The repair does not add a second
word-selection policy. It asks the anchor block's own
`NSTextSelectionNavigation` to normalize the anchor against the opposite block
edge, then composes the one canonical cross-block range. The repaired custom
result matches stock while the rich controller remains the only algorithm.

Authority artifacts:

| Variant | Result | Artifact |
| --- | --- | --- |
| retained | 13 passed, 0 failed/skipped | `.block-visual-selection-task4-authority-retained-full.xcresult` |
| withdrawn | 14 passed, 0 failed/skipped | `.block-visual-selection-task4-authority-withdrawn-full.xcresult` |

The count differs by the retained-only outer-provider characterization. It is
not a semantic skip.

## Full retained/withdrawn interaction differential

Both variants ran the same 14 physical UI scenarios against stock behavior:

- public horizontal navigation over bidi text, composed emoji, and consecutive
  empty blocks;
- large-document Select All while visible geometry changes;
- leading/top and trailing/bottom selection-handle autoscroll;
- long-press native loupe tracking;
- mixed-bidi endpoint roles and cross-structural-boundary handle dragging;
- floating-cursor crossing of one and multiple block boundaries;
- mixed-bidi floating reversal and anchor crossing;
- floating selection held below the viewport with scroll/extension;
- reduced-surface touch and floating chrome batches; and
- selectable/noneditable Copy-menu cancellation, reentry, and restoration.

| Variant | Result | Artifact |
| --- | --- | --- |
| retained | 14 passed, 0 failed/skipped | `.block-visual-selection-task5-retained-ui.xcresult` |
| withdrawn | 14 passed, 0 failed/skipped | `.block-visual-selection-task5-withdrawn-ui.xcresult` |

The retained and withdrawn UI products were built independently. Their debug
dylib SHA-256 values were respectively
`5e1758c3f519f620aa0fe2679fe83790279973fb0d4a30aa2ba752d9b2d80fb6`
and
`a34f33f9a001b5513f139a0dd3cf4a6de8b9ceca1f36f231f0bcd77c9cf0dfd5`,
proving that the paired matrix did not accidentally exercise one shared
binary.

The lifecycle differential separately covered three live HID reconstruction
sessions without interaction-graph leakage, floating-cursor selectable and
editable transitions, detach/reattach, and project-owner teardown:

| Variant | Result | Artifact |
| --- | --- | --- |
| retained | 4 passed, 0 failed/skipped | `.block-visual-selection-task5-retained-lifecycle.xcresult` |
| withdrawn | 4 passed, 0 failed/skipped | `.block-visual-selection-task5-withdrawn-lifecycle.xcresult` |

The complete withdrawn matrix was green and equivalent. No range, endpoint,
affinity, direction, geometry, selection chrome, topology, autoscroll, menu,
or lifecycle difference followed callback absence, so the design's
`safeFallback` classification rule was satisfied.

## Permanent source and runtime contracts

The permanent focused suite passed 30/30 with zero failures or skips in
`.block-visual-selection-task6-permanent-contracts-2.xcresult`. It verifies:

- exact authorization-fixture schema, runtime, decision, Hopper addresses, and
  artifact existence;
- class-local absence and `respondsToSelector:` absence on the outer block
  view;
- continued rich-provider ownership and direct algorithm authority;
- the missing-selector UIKit fallback characterization;
- selector-free probe schema and no candidate send;
- no outer ABI row, preflight, experiment header, trace bridge, or temporary
  token; and
- the retained required gesture-host callback and the other previously
  classified interaction-host decisions.

The complete unit suite then passed 1,002/1,002 with zero failures or skips in
`.block-visual-selection-task7-all-units.xcresult`.

## Final ordinary-build interaction and semantic gates

The permanent ordinary build reran the full 14-scenario UI matrix in
`.block-visual-selection-task7-final-ui.xcresult`: 14 passed, 0 failed, 0
skipped. Test execution was 447.276 seconds; the result-bundle interval was
449.775 seconds.

The fixed-duration semantic gate passed 284/284, with zero failures/skips, in
12.035 seconds. Its machine-readable result is
`.block-visual-selection-task7-fast/summary.json`, comfortably below the
30-second ceiling.

Every Simulator XCTest invocation used the repository simulator lock and
`-parallel-testing-enabled NO`. No XCTest process overlapped another run.

## Optimized Release binary audit

The ordinary Release simulator product was built with
`CODE_SIGNING_ALLOWED=NO` at
`.block-visual-selection-task7-release-derived`. `lipo -archs` reports
`x86_64 arm64`.

For each architecture, `nm -a`, `otool -ov`, and `strings` establish:

- no
  `-[IDBlockTextView(PrivateCallbacks)
  _visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:]` symbol or
  method-list entry;
- exactly one private provider,
  `-[IDRichTextLayoutController(PrivateCallbacks)
  _visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:]`;
- exactly one project algorithm,
  `-[IDRichTextLayoutController
  id_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:]`;
- only the expected rich-controller algorithm send stub; and
- no withdrawal macro, omit-ABI macro, temporary header, trace API, or
  `visualSelectionTrace` string.

The selector spelling correctly remains in the binary because the required
rich-controller provider remains. The audit is receiver-specific and does not
mistake that protected provider for the deleted outer method.

## Manifests, project generation, and hashes

Final inventories remain 127 minimal production members, 53 reference-only
members, and 24 test-only members. The production selector row remains:

```text
_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:
PrivateUIKit/IDRichTextLayoutController+PrivateCallbacks.m|_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:
```

Two consecutive `xcodegen generate` runs produced identical project SHA-256
`5bc4940dd82deca2dd322b299d02046fe4f348b3be883f0233869e44a2cda87e`.

Final Git-object SHA-1 values for the private boundary and authority are:

| File | Final SHA-1 | Classification |
| --- | --- | --- |
| `PrivateUIKit/IDBlockTextView+PrivateCallbacks.m` | `3a52ebc0cd82f8cdf98189b433b73cd02ed92e1c` | intentionally changed: outer forwarder deleted |
| `PrivateUIKit/IDPrivateUIKit.m` | `37c371ab4ae51ec4eb58c0299d1377ce14e57608` | intentionally changed: outer ABI row deleted |
| `PrivateUIKit/IDPrivateUIKit+RichTextLayout.h` | `8caa310a08422179dcc2d711f5c534a4971bc3f8` | experiment preflight removed; ordinary API reconciled |
| `PrivateUIKit/IDPrivateUIKit+RichTextLayout.m` | `8cd74cb57061c0d1a32b2bd72ce8fa760fd431d6` | experiment preflight removed; ordinary API reconciled |
| `PrivateUIKit/IDRichTextLayoutController+PrivateCallbacks.m` | `c8325530e00330c3895778bc90c9849692a561f0` | protected rich provider retained |
| `TextView/IDBlockTextView.m` | `d0793716a5acf008a53155a580eed94cb34946d3` | block-only preflight call absent |
| `TextView/IDRichTextLayoutController.m` | `dc1adeee6eae9cd0cf012ee035ef30a73714812a` | intentionally changed by the stock-derived bidi anchor repair |
| production behavior contract | `d2143fb0a8d056793885a4a1ea117d93a83fff59` | protected ownership/count unchanged |
| authorization fixture | `d19f59199d360bbf14869ad2a9f874c43bd999fe` | new permanent evidence |

The rich callback file and production behavior contract were protected through
the paired experiment. The rich algorithm's entry hash was
`50210ad85ba0b4e1e7232097a3c8e6b6e56000bc`, recorded by the immediately
preceding interaction-host pass; its final change is the intentional neutral
mixed-bidi repair described above, not callback withdrawal logic.

## Experiment-token and substitute-provider audit

Permanent source tests construct forbidden token names from fragments, so the
literal experiment names cannot hide in the tests that audit them. The scan
covers `App`, `TextView`, `PrivateUIKit`, `Tests`, `UITests`, `Scripts`,
`project.yml`, and the generated project. It rejects:

- callback-withdrawal and ABI-omission macros;
- the temporary withdrawal header;
- reset/record/copy trace APIs and `visualSelectionTrace` storage;
- the removed block preflight; and
- a forwarding, invocation, or dynamic-resolution replacement provider.

The same tokens are absent from both optimized architecture slices. The only
remaining private selector provider is the intended rich controller.

## Dirty-tree, index, process, and platform hygiene

This is an intentionally dirty exploration repository containing extensive
earlier editor, keyboard, diagnostic, test, documentation, and generated
evidence. This pass preserved that state and performed no reset, checkout,
clean, staging, commit, or artifact deletion. The new result bundles and
derived products were retained as evidence.

`git diff --check` is clean, the Git index is empty, and the final process
audit found no live `xcodebuild test`, `xctest`, or `XCTRunner` process. Xcode
scheme and command-line simulator parallelization remained disabled.

This authorization is limited to UIKitCore iOS 26.5 build 23F73. Private
receiver routing and fallback behavior must be re-characterized on other iOS
versions before this receiver-specific deletion is generalized. In
particular, the report does not prove the same safe fallback on iOS 16 through
iOS 25.
