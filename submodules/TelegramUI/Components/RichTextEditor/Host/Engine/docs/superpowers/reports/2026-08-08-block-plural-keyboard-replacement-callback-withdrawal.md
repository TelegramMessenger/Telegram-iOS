# Block plural keyboard-replacement callback withdrawal report

Date: 2026-08-08  
Runtime: iOS 26.5 build 23F73, iPhone 17 Pro K3 simulator  
Simulator UDID: `FA6F7462-AA97-42FE-9E57-8DA0593CE756`

## Decision and exact private-surface delta

Decision: `safeFallback` for
`-[IDBlockTextView(PrivateInputDelegate)
keyboardInput:shouldReplaceTextInRanges:replacementText:]` on the pinned
runtime.

The permanent source removes one block-only private provider. It retains
`keyboardInput:shouldReplaceTextInRange:replacementText:` and makes it call the
project-owned `IDBlockAllowsKeyboardReplacement` helper directly. The helper
continues to return `view.isEditable`. The public-shaped
`textInput:shouldChangeCharactersInRanges:replacementText:` callback and the
rest of the UIKit-owned input pipeline are unchanged.

The temporary compile control, header, nesting depth, three trace tokens, and
all retained/withdrawn branches were deleted. The permanent decision is pinned
in
`Tests/Fixtures/BlockPluralKeyboardReplacementAuthorization-iOS26.5.json`.

## UIKitCore receiver evidence

Hopper recovered the decisive split in UIKitCore iOS 26.5:

| Address | Role |
| --- | --- |
| `0xbed7d4` | `UIKBInputDelegateManager` replacement manager |
| `0xbee8b8` | forward-delete manager |
| `0x2232600` | plural callback send stub |
| `0x22325e0` | singular callback send stub |
| `0xbedfb4` | replacement-manager plural send |
| `0xbedcac` | replacement-manager singular send |
| `0xbeeda4` | forward-delete plural send |
| `0xbeeaf4` | forward-delete singular send |

The replacement manager tests for `_UITextKitTextRange` at `0xbed86c` through
`0xbed880`. UIKit's private range branch uses the plural callback; the
non-UIKit range branch uses the singular callback. InputDec supplies
`IDRichTextRange : UITextRange`, so it follows the singular branch.

Complete selector-stub xrefs were:

```text
plural   0xbedfb4 0xbeeda4 0x1518dbc 0x15d3d7c 0x161bb04
singular 0xbedcac 0xbeeaf4 0x15bbdf4 0x18952b0
```

The additional plural xrefs are concrete UIKit text wrappers and do not prove
a plural send to the duck-typed block host. Full decompilation notes are in
`docs/hopper/UIKitCore-iOS26.5.md`.

## Test-first and paired-product evidence

The absence contract first failed against the ordinary retained source in
`.block-plural-replacement-task2-absence-red.xcresult` solely because the
plural method existed. The paired boundary/trace tests also produced their
intended RED artifact in
`.block-plural-replacement-task3-boundary-red2.xcresult` before the experiment
implementation was added.

The retained and withdrawn focused products each passed 61/61 tests with no
failure or skip:

- `.block-plural-replacement-task3-retained-focused.xcresult`;
- `.block-plural-replacement-task3-withdrawn-focused.xcresult`.

Their corresponding SHA-256 values prove distinct products:

| Product | Retained | Withdrawn |
| --- | --- | --- |
| app debug dylib | `739c828576dc8b2feaa4efa3de8504260a43fe2efa49129526ee901e8bc50bee` | `b7b2ac8282550f1142a70b507152f4264de04d7f7465ade27add11759b76c37f` |
| unit bundle | `4b1e89bd59cc880718c5742a3785ec4027d573e41ef91ba1838a780ba92f4aaa` | `98bb30cc82dcc26692ee4c351c3173a9186379aed1644d98c010ddb4c4206d3e` |
| UI bundle | `6f2300e9d087ed71dbf752963a5cfd3a802cb762471dfd9086a21a29198c8684` | `ab5f32d6442a95bde60f0d6dfe2153eeb0914171ab7f737e9c6326ccc46d002f` |

## Direct-send trace and keyboard evidence

Both paired variants passed the same 24-method real-system-keyboard matrix:

| Variant | Result | Wall duration | Artifact |
| --- | --- | ---: | --- |
| retained | 24 passed, 0 failed/skipped | 739 s | `.block-plural-replacement-task4-retained-keyboard` |
| withdrawn | 24 passed, 0 failed/skipped | 767 s | `.block-plural-replacement-task4-withdrawn-keyboard` |

Exported trace attachments contained:

| Event | Retained | Withdrawn |
| --- | ---: | ---: |
| singular callback | 180 | 180 |
| plural via singular wrapper | 180 | 0 |
| direct plural callback | 0 | 0 |

Thus instrumentation was reachable and UIKit never directly sent the plural
selector. Each paired keyboard run used two bounded prediction-readiness
retries (`inline-accept-minimal` and `inline-dismiss-before-boundary`); first
attempt artifacts were preserved.

The UIKit manager-level forward-delete differential passed in
`.block-plural-replacement-task2-forward-delete-manager-green2.xcresult`. It
matched stock canonical text, post-delete caret, immediate-undo text, and
stock's restored one-character undo selection. XCUI Function-Delete was not
used because iOS 26.5 does not deliver either exported form to stock
`UITextView` in this harness.

## Semantic and physical differentials

The retained semantic product passed 288/288 tests in 11.638 seconds; the
withdrawn product passed 288/288 in 11.537 seconds:

- `.block-plural-replacement-task4-retained-fast2`;
- `.block-plural-replacement-task4-withdrawn-fast`.

The first withdrawn 14-test physical matrix passed 13 tests and failed only
the second loupe screenshot capture. The same unmodified loupe method then
passed twice withdrawn and once retained:

- `.block-plural-replacement-task4-loupe-withdrawn-rerun1.xcresult`;
- `.block-plural-replacement-task4-loupe-withdrawn-rerun2.xcresult`;
- `.block-plural-replacement-task4-loupe-retained-isolation.xcresult`.

The complete withdrawn rerun
`.block-plural-replacement-task4-withdrawn-ui-green2.xcresult` passed 14/14
with zero failures/skips. This classified the earlier screenshot miss as
capture readiness noise rather than a behavioral difference; no assertion was
weakened.

## Permanent contracts and final ordinary-build gates

The permanent method-state test proves:

- the singular method exists and preserves editable/noneditable policy;
- the plural method is absent and `respondsToSelector:` is false;
- there is no plural forwarding target, class-local `forwardInvocation:`, or
  dynamic resolver; and
- a direct plural send raises the ordinary unrecognized-selector exception.

`IDBlockTextView` retains its pre-existing `UITextInputTraits`
`methodSignatureForSelector:` bridge. It can return a generic signature for
unknown selectors, but it does not claim or forward the plural selector and
has no invocation handler, so it is not a substitute provider.

Final evidence:

| Gate | Result | Artifact |
| --- | --- | --- |
| permanent focused | 55 passed, 0 failed/skipped | `.block-plural-replacement-task5-permanent-focused-green4.xcresult` |
| complete units | 1,010 passed, 0 failed/skipped | `.block-plural-replacement-task6-all-units-green2.xcresult` |
| real keyboards | 24 passed, 0 failed/skipped; 765 s | `.block-plural-replacement-task6-keyboard` |
| physical UI | 14 passed, 0 failed/skipped; 449.54 s | `.block-plural-replacement-task6-final-ui.xcresult` |
| bounded semantic | 289 passed, 0 failed/skipped; 12.439 s | `.block-plural-replacement-task6-fast` |

The final keyboard matrix covered 20 English, two Japanese, and two
Simplified Chinese methods. It used the same two bounded readiness retries as
the paired runs and preserved both attempts.

Before the green complete unit run, one aggregate run inherited `zh-Hans` as
the active input mode and failed stock and custom spelling-pixel checks plus
two historically order-sensitive iPad layout checks. The pinned English-US
profile was provisioned and verified; the exact eight failed methods then
passed unchanged in
`.block-plural-replacement-task6-exact-failures-isolated.xcresult`, followed by
the green 1,010-test aggregate. No product assertion was skipped or weakened.

The four focused runner command-contract tests passed and prove the fast and
keyboard entry points retain the global lock, exact derived-data selection,
`test-without-building`, and `-parallel-testing-enabled NO` behavior.

## Optimized Release audit

The Release Simulator product built successfully at
`.block-plural-replacement-task6-release-derived` with `CODE_SIGNING_ALLOWED=NO`.
It contains `x86_64 arm64`.

For both architecture slices, `nm -a`, `otool -ov`, and `strings` establish:

- one unique singular block-provider implementation address;
- zero plural block-provider symbols or method-list entries;
- zero plural selector strings;
- zero withdrawal-header, macro, nesting, or trace strings; and
- no forwarding or dynamic-resolution substitute introduced by this pass.

The singular implementation addresses are `0x10000b24c` on arm64 and
`0x10000ed42` on x86_64. Slice SHA-256 values are
`24439cc5a74cd250b88022d15ece24c3234125323de53d5520bb6488ef3d049c`
and
`21812866699fa255d30d6e3fe7c827dc75240287035ce221a397289b91e178b8`;
the universal executable hash is
`f1dce46fb4d23431bb4e60da38803b3da02c49a9e065cff114391a812ca0b75f`.

## Manifests, hashes, and repository hygiene

Inventories remain 127 production capability members, 53 reference-only
members, and 24 test-only members. Neither replacement callback has a
production capability or required-ABI row.

| File | Entry hash | Final hash |
| --- | --- | --- |
| block private input delegate | `fa2179c0f3ec91b7f3229fe4ddd3b9cb5fdb896e` | `3ad5ec69e60bfd04e2e39ddca6d3d62046f982f3` |
| `IDRichTextRange.h` | `874c679dda5c343e48c5cee07a6f03425ddf5237` | identical |
| input-controller capability | `152df54fc8adc6bb854565fdb76eae58c5713ea0` | identical |
| block text input | `435a9243f9439005c25c0ff9e9ad48355b36b474` | identical |
| block private callbacks | `a85a6842aaec40eabe3c9654ee322189632c0ca5` | identical |
| production behavior contract | `d2143fb0a8d056793885a4a1ea117d93a83fff59` | identical |
| test-only behavior contract | `8861741fbdfbb2f915753dadd47beca5ac0b13b4` | identical |
| authorization fixture | absent | `26eff872bfbac4ed73ed746d65d17974ce3bed63` |

Two consecutive XcodeGen runs produced identical project SHA-256
`a91b7292c6e56311aafbeec2c511d8101abfbcf50c8b22f4a52a30591373d67c`.
Every Simulator XCTest command used the repository lock and
`-parallel-testing-enabled NO`; no XCTest runs overlapped.

The repository was already a dirty exploration tree. This pass performed no
reset, checkout, staging, commit, or cleanup operation and preserved unrelated
work.

## Compatibility boundary

This authorization applies only to `IDBlockTextView` on UIKitCore iOS 26.5
build 23F73. It does not authorize removing the plural wrapper from stock
UIKit classes, a future TextKit 1 driver, iOS 16 through iOS 25, or any receiver
that uses UIKit's private `_UITextKitTextRange` multi-range representation.
Those environments require their own caller graphs and paired differentials.
