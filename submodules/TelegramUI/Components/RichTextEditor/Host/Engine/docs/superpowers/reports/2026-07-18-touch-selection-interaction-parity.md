# Touch Selection Interaction Parity Evidence

## Outcome and runtime

This slice is **DONE_WITH_CONCERNS** on the pinned iPhone 17 Pro simulator
`404DA68C-E273-46A5-8F6C-B3BF556B80D6`, iOS 26.5 build `23F73`, arm64, Xcode 26.5
(`17F42`). UIKit owns tap dispatch, range adjustment, loupe presentation, selection handles, and
the edge-autoscroll timer. `IDRichTextLayoutController` owns canonical ranges and geometry, and the
replaceable presentation backend owns only the stable selection-container presentation surface.

The original Task 7 diagnostic focused command executed 130 tests: 127 passed, 3 failed, and 0
skipped. Its two fixed-delay settled-layout misses and one tap-history double-tap miss drove the
final-review harness corrections below; those bundles remain diagnostic history, not the
authoritative gate. The authoritative current-head count and bundle are recorded under “Commands
and result bundles.” The exact inherited UI gate passed 6/6. The inherited parity gate passed
11/12 and retained only the allowed spelling-pixel mismatch: custom `104`, stock `162`, tolerance
`12`.

## Recovered UIKitCore contracts

All addresses below are file-relative offsets in the open iOS 26.5 simulator UIKitCore image unless
explicitly labeled as device VM addresses. Object arguments named “block” are the three point
provider blocks recovered for the loupe ABI.

| Address | Selector / procedure | ABI, coordinate space, and recovered order |
|---|---|---|
| `0x1566108` | `-[UITextInteractionAssistant setGestureRecognizers]` | `void <- ()`; installs assistant-owned recognizers on the hosted input view. |
| `0x1565240` | `shouldDisplayLoupeSessionForTouchType:` | `BOOL <- NSInteger`; primary touch is eligible. |
| `0x1565428` | `activeSelectionController` | object return after `_setTextSelectionControllerFromDelegate`. |
| `0x156cf7c` | `selectionContainerView` | object return; hosted selection container, falling back to `textInputView`. |
| `0x1615f44` / `0x1615ed8` | `selectionContainerView` / `_existingSelectionContainerView` | object returns; lazy one-container creation versus noncreating lookup. |
| `0x1608d84` / `0x161d01c` | `_placeSelectionContainerView` / `_updateSelectionGestures` | `void <- ()`; place the stable host, then maintain assistant gestures. |
| `0x153e25c` | `_handleMultiTapGesture:` | assistant/controller-owned repeated-tap history and dispatch. |
| `0x153da78` / `0x153ddf4` / `0x153e05c` | tapped update / cursor / ranged-selection entry points | `void <- object, CGPoint, NSInteger, block`; gesture point enters the active selection controller between begin/end selection. |
| `0x153d5c8` | `_textGranularityForNumberOfTaps:` | `NSInteger <- NSUInteger`; recovered lookup through two taps, paragraph granularity above two. |
| `0x15681d8` / `0x1124f34` | `selectWord` / `paragraphRangeForRange:` | `void <- ()`; `NSRange <- NSRange`. |
| `0x156c924` | `_rangeAdjustmentPointInTextInputCoordinateSpace:` | `CGPoint <- CGPoint`; adjustment-container point converted into proxy `textInputView` coordinates. |
| `0x156cee4` | `containerCoordinateSpaceForTextRangeAdjustmentInteraction:` | object coordinate-space return for the adjustment container. |
| `0x156ca34` | range adjustment begin | `void <- object, CGPoint`; convert, delegate-will-move, hide commands, begin interaction/change, seed base/extent including BiDi, notify keyboard, request display, notify manager. |
| `0x156cd48` / `0x156cc68` | range adjustment move / update | `void <- object, CGPoint, CGPoint`; then `void <- CGPoint, CGPoint, NSInteger`; convert both points, set extent, notify keyboard, invalidate/display, start autoscroll. |
| `0x156cd4c` | range adjustment end | `void <- object, CGPoint`; commit/show commands as applicable, end change/interaction, cancel autoscroll, notify manager. |
| `0x1568c80` / `0x1569124` / `0x1568e70` | legacy adjustment begin/move/end | `void <- CGPoint`; `void <- CGPoint, CGPoint`; `void <- CGPoint`. |
| `0x9f3954` / `0x9f3ac4` | `_pointCloserToEnd:` / `updateBaseAndExtentPointsFromEdges` | Chooses logical endpoint from padded regions, then derives base/extent from endpoint rects. |
| `0x1576d44` | `setRangedSelectionExtentPoint:baseIsStart:allowFlipping:` | point-to-position and bounded/inverted range policy after editor-supplied geometry. |
| `0x156c8b4` | modern range-adjustment container lookup | obtains the selection-display interaction's adjustment container. |
| `0x15679c8` | assistant loupe gesture | `void <- NSInteger, block, block, block, NSInteger, BOOL *`; preserves all six arguments, begins external refinement, forwards unchanged. |
| `0x153a0bc` / `0xb23f58` | refinement loupe forwarding / behavior | same ABI; state 1 begins, state 2 updates from active selection geometry, terminal states through 4 end. |
| `0x156cffc` / `0x1615ff0` / `0x160b880` | above-text host chain | assistant calls `_selectionContainerViewAboveText`; stock tail-calls `_contentView`; stock `_contentView` returns self. Custom returns its inset block stack. |
| `0x16107b0` | `_convertPointFromRenderSpace:` | identity without a custom renderer; no invented inset subtraction. |
| `0x1569e88` / `0x156a160` / `0x156a020` | assistant start/update/cancel autoscroll | point begins in `textInputView`; update reads scroll geometry and extends selection; cancel terminates the session. |
| `0x161a040` / `0x161a278` | stock host start/cancel autoscroll | convert block-stack point once to outer scroll host; 8-point phone edge band, directions `4`/`8`, repeat `0.075`; cancel invalidates. |
| `0x17c4f28` / `0x17c5210` / `0x17c52cc` | `UIAutoscroll` start/invalidate/timer | UIKit owns timer, offset mutation, selection update, invalidation, and repetition. |

The corresponding device VM addresses retained in the ledger are `0x1893dad5c`, `0x1893e17e4`,
`0x18a97c8c0`, `0x18a97d5cc`, `0x1893e9694`, `0x1894202f8`, `0x189423ea8`,
`0x189423e04`, `0x1894244c8`, `0x18961cb9c`, `0x189686d1c`, `0x1896871ec`, and
`0x1896872d0`. They are not relabeled as simulator offsets.

## Range and visible evidence

### Taps and loupe

- Physical single-tap target: stock and custom both `{46,0}` after the observed focus tap and
  1.0-second tap-history isolation. The immediate timing mutation also recorded `{46,0}` for both.
- Double tap on “constellation”: stock tokenizer and custom physical selection `{33,13}`. The
  measured gesture is preceded by an observed focus tap and a 1.0-second quiescence interval, so
  prior recognizer history cannot turn it into a triple tap; the exact range was not relaxed.
- Triple tap: `XCUIElement` activates the exact local editor center. That point lies below the
  short laid-out text, so stock `closestPositionToPoint:` returns end-of-document; backward
  paragraph tokenization at that physical position yields the final paragraph `{160,80}`, which
  matches the custom physical triple tap.
- Direct native loupe geometry: stock loupe `{{32,199.5},{115,85}}`, caret
  `{{88,229},{3,26}}`; custom block-stack loupe `{{37,207.5},{115,85}}`, caret
  `{{93,237},{3,26}}`. Both loupe-center-minus-caret-center vectors are `{0,0}`. Returning the
  outer custom editor produced the falsifying `{5,8}` vector.
- Current focused bundle retains `loupe-baseline`, `loupe-held`, `loupe-moved`, and `loupe-ended`.

### Handles

All component bounds are screen-space filtered blue components; selection rectangles are
editor/document-space telemetry. Both logical endpoints matched a distinct component within 8
points, and the presentation container stayed at one stable creation.

| Scenario | Range / result | Stock components | Custom components |
|---|---|---|---|
| LTR word | `{33,13}` | unavailable: no stock LTR screenshot was retained; exact substitute oracle is stock tokenizer range `{33,13}` plus distinct custom endpoint matching within 8 points | `{{23.667,223.333},{16.667,39.667}}`, `{{133.667,237},{16.667,39.333}}` |
| Structural boundary | initial `omega={15,5}`; final stock/custom `{15,25}`, containing the one virtual newline | `{{160.333,198},{16.667,32.667}}`, `{{219.667,205},{16.667,39}}` | `{{165.667,199.333},{16.667,39.667}}`, `{{224.667,213},{16.667,39.333}}` |
| Mixed BiDi | initial Hebrew word `{15,5}`; logical end dragged to target UTF-16 offset `17`, exact final stock/custom equality | `{{367.667,215.333},{16.667,39}}`, `{{313.667,229},{16.667,38.667}}` | `{{372.667,223.333},{13.333,39.667}}`, `{{318.667,237},{16.667,32}}` |

Retained attachment names are `handles-ltr`, `handles-ltr-component-bounds`,
`handles-boundary-stock/custom` with component bounds, and `handles-bidi-stock/custom` with
component bounds.

### Edge autoscroll

- Lower custom held atomic sample: offset `5`, selection `{302,69}`, visible `{{0,5},{370,360}}`,
  logical start rect `{{102,270},{258,24}}`, logical end rect `{{10,318},{259,25}}`, active
  handles `{{265.75,326},{23.75,38.5}}` and `{{99.75,264.5},{23.75,37.5}}`; one stable
  container and 15 presentation updates.
- Lower stock held atomic sample: offset `3.3333`, selection `{302,88}`, last assistant point
  `{277.5,345.3333}`, 47 starts, visible `{{0,3.3333},{370,360}}`, one stable container.
- Earlier calibrated custom diagnostic: assistant point `{272.5,337.5}` converted once to outer
  scroll point `{277.5,345.5}`, offset `5.667`, logical-end rect `y=342 h=25`, active lollipop
  `y=350 h=38.5`.
- Upper custom exact sequence: initial offset `1303`, selection `{1408,2}`, fixed logical end
  `1410`, visible `{{0,1303},{370,360}}`; pre-lift samples `(1294.6667,{1384,26})`,
  `(999.3333,{1099,311})`, `(582.6667,{684,726})`, `(8,{88,1322})`. The atomic active snapshot
  had offset/visible origin `1294.6667`,
  selection `{1384,26}`, and leading handle
  `{{83.75,1290.5},{23.75,38.5}}`.
- Upper stock exact sequence: initial offset `1303`, selection `{1435,5}`, fixed logical end
  `1440`, visible `{{0,1303},{370,360}}`; pre-lift samples `(1297.3333,{1385,55})`,
  `(1037.6667,{1100,340})`, `(674,{735,705})`, `(0,{169,1271})`. The atomic active snapshot had
  offset/visible origin `1297.3333`,
  selection `{1385,55}`, and leading handle
  `{{83.0833,1282.1667},{23.75,38.5}}`.
- Both exact upper sequences are retained as `edge-autoscroll-top-samples` and
  `stock-edge-autoscroll-top-samples`; they prove monotonically decreasing offset/start, fixed
  logical end, an active leading handle in the 12-point edge band, and 500-ms post-lift stability.
  Lower observations mirror those assertions with increasing offset/end and fixed logical start.
- Retained attachments: `edge-autoscroll-top-held/released`,
  `edge-autoscroll-bottom-held/atomic-status/released`, and stock top/bottom held evidence.

## Backend substitution and ownership

The recording backend receives the same canonical selection and composed geometry as the native
backend. Equivalent native/recording editors preserve text, selected range, marked-range presence,
and undo availability. Teardown removes the presentation container without changing document or
selection state. Native construction creates exactly one stable container above the block stack.

The final source boundary is fail-closed:

- one `IDNativeSelectionPresentationBackend` allocation in `TextView/IDBlockTextView.m`;
- one block `newInteractionAssistantWithView:` call in `TextView/IDBlockTextView+Interaction.m`;
- one canonical `IDRichTextLayoutController` allocation owner in `TextView/IDBlockTextView.m` and
  one implementation in `TextView/IDRichTextLayoutController.m`;
- zero production `UITextView` tokens across `App/`, `TextView/`, and `PrivateUIKit/`;
- zero `CAShapeLayer`, `UIBezierPath`, custom handle/loupe, or stroke-path tokens in production;
- private callback definitions confined to `PrivateUIKit/`; the exact public
  `selectionContainerView` definition is removed only from
  `TextView/IDNativeSelectionPresentationBackend.m` before the forbidden-selector scan, with no
  count exception; and
- all 40 production `.m` files are classified by an exact 24-file experimental manifest or exact
  16-file legacy manifest. Any unknown path fails. Adversarial tests prove the classifier rejects
  an unknown file and construction scans recognize `alloc`, `new`, and named factory forms.

## Commands and result bundles

The implementation plan records intended commands, not execution evidence. The ledger below uses
only actual retained task reports and xcresult summaries. “Not retained” means the historical
report omitted the literal shell invocation or raw shell exit; the command is not reconstructed
from the plan.

| Task | Gate | Actual command record | Shell exit | Passed / failed / skipped | Retained result evidence |
|---|---|---|---|---|---|
| 1 | RED | `[T1-R]` below | `65` | `0 / 1 / 0` | `.derivedData-touch-task1-red/Result.xcresult` |
| 1 | final GREEN | `[T1-G]` below | `0` | `2 / 0 / 0` | `.derivedData-touch-task1-final/Result.xcresult` |
| 2 | compile RED | `[T2-R]` below | not separately retained; report records `** TEST FAILED **` | `0 / 0 / 0` (compile failure) | `.derivedData-touch-task2-red-1/Result.xcresult` |
| 2 | final GREEN | `[T2-G]` below | not separately retained; report records `** TEST SUCCEEDED **` | `55 / 0 / 0` | `.derivedData-touch-task2-green-final/Result.xcresult` |
| 3 | corrected physical-tap RED | literal invocation and shell exit not retained | not retained | `2 / 1 / 0` | `.derivedData-touch-task3-ui-red-3/Result.xcresult` |
| 3 | final focused GREEN | literal invocation and shell exit not retained | not retained; xcresult is Passed | `50 / 0 / 0` | `.derivedData-touch-task3-review-gate-1/Result.xcresult` |
| 4 | callback/ABI RED | literal invocation and shell exit not retained | not retained; xcresult is Failed | `0 / 2 / 0` | `.derivedData-touch-task4-callback-red/Logs/Test/Test-InputDec-2026.07.19_19-30-49-+0800.xcresult` |
| 4 | final review GREEN | literal invocation and shell exit not retained | not retained; xcresult is Passed | `34 / 0 / 0` | `.derivedData-touch-task4-review-green/Result.xcresult` |
| 5 | boundary-fixture RED | literal invocation and shell exit not retained | not retained; xcresult is Failed | `0 / 1 / 0` | `.derivedData-touch-task5-boundary-red2/Result.xcresult` |
| 5 | final post-review GREEN | literal invocation and shell exit not retained | not retained; xcresult is Passed | `47 / 0 / 0` | `.derivedData-touch-task5-final-green3/Result.xcresult` |
| 6 | real five-stage ordering RED | literal invocation and shell exit not retained | not retained; xcresult is Failed | `0 / 1 / 0` | `.task6-review-order-real-red.xcresult` |
| 6 | post-review focused GREEN | literal invocation and shell exit not retained | not retained; xcresult is Passed | `4 / 0 / 0` | `.task6-review-focused2.xcresult` |
| 6 | post-review physical edge GREEN | literal invocation and shell exit not retained | not retained; xcresult is Passed | `4 / 0 / 0` | `.task6-review-edge1.xcresult` |

Actual retained Task 1 commands:

```bash
# [T1-R]
xcodebuild test -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-touch-task1-red \
  -resultBundlePath .derivedData-touch-task1-red/Result.xcresult \
  -only-testing:InputDecUITests/IDBlockTouchSelectionUITests/testTouchLTRScenarioExposesExactStatusSchema

# [T1-G]
xcodebuild test -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-touch-task1-final \
  -resultBundlePath .derivedData-touch-task1-final/Result.xcresult \
  -only-testing:InputDecTests/IDProjectSmokeTests/testTouchScenariosExposeExactFixturesAndDeterministicStatusSchema \
  -only-testing:InputDecUITests/IDBlockTouchSelectionUITests/testTouchLTRScenarioExposesExactStatusSchema
```

Actual retained Task 2 commands:

```bash
# [T2-R]
xcodebuild test -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-touch-task2-red-1 \
  -resultBundlePath .derivedData-touch-task2-red-1/Result.xcresult \
  -only-testing:InputDecTests/IDSelectionPresentationBackendTests

# [T2-G]
xcodebuild test -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-touch-task2-green-final \
  -resultBundlePath .derivedData-touch-task2-green-final/Result.xcresult \
  -only-testing:InputDecTests/IDSelectionPresentationBackendTests \
  -only-testing:InputDecTests/IDBlockTextViewIntegrationTests \
  -only-testing:InputDecTests/IDProjectSmokeTests \
  -only-testing:InputDecUITests/IDBlockTouchSelectionUITests/testTouchLTRScenarioExposesExactStatusSchema
```

### Final-review ownership RED and GREEN

```bash
xcodebuild test -quiet -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-touch-final-fix-ownership-red2 \
  -resultBundlePath .derivedData-touch-final-fix-ownership-red2/Result.xcresult \
  -only-testing:InputDecTests/IDProjectSmokeTests/testFinalOwnershipClassifierRejectsAnUnknownProductionImplementation \
  -only-testing:InputDecTests/IDProjectSmokeTests/testFinalOwnershipConstructionScannerRejectsAllocNewAndFactoryForms \
  -only-testing:InputDecTests/IDProjectSmokeTests/testFinalOwnershipPrivateCallbackAuditRemovesOnlyExactPublicCollision
```

RED exited `65` before tests executed because all three intended audit helpers were undefined;
bundle `.derivedData-touch-final-fix-ownership-red2/Result.xcresult` retains the compiler failures.

```bash
xcodebuild test -quiet -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-touch-final-fix-ownership-green2 \
  -resultBundlePath .derivedData-touch-final-fix-ownership-green2/Result.xcresult \
  -only-testing:InputDecTests/IDProjectSmokeTests/testProductionSourceDoesNotReferenceUITextView \
  -only-testing:InputDecTests/IDProjectSmokeTests/testFinalOwnershipClassifierRejectsAnUnknownProductionImplementation \
  -only-testing:InputDecTests/IDProjectSmokeTests/testFinalOwnershipConstructionScannerRejectsAllocNewAndFactoryForms \
  -only-testing:InputDecTests/IDProjectSmokeTests/testFinalOwnershipPrivateCallbackAuditRemovesOnlyExactPublicCollision \
  -only-testing:InputDecTests/IDProjectSmokeTests/testFinalOwnershipHasOneNativeSelectionBackendConstructionSite \
  -only-testing:InputDecTests/IDProjectSmokeTests/testFinalOwnershipHasOneBlockInteractionAssistantConstructionSite \
  -only-testing:InputDecTests/IDProjectSmokeTests/testFinalOwnershipHasOneCanonicalRichLayoutControllerOwner \
  -only-testing:InputDecTests/IDProjectSmokeTests/testFinalOwnershipRejectsCustomSelectionDrawingAcrossProduction \
  -only-testing:InputDecTests/IDProjectSmokeTests/testFinalOwnershipKeepsPrivateCallbackDefinitionsUnderPrivateUIKit \
  -only-testing:InputDecTests/IDProjectSmokeTests/testFinalOwnershipInventoriesEveryExperimentalImplementationPathExactly
```

GREEN exited `0`: 10 passed, 0 failed, 0 skipped; bundle
`.derivedData-touch-final-fix-ownership-green2/Result.xcresult`.

### Focused and isolated gates

```bash
xcodebuild test -quiet -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-touch-final-fix-focused-green4 \
  -resultBundlePath .derivedData-touch-final-fix-focused-green4/Result.xcresult \
  -only-testing:InputDecTests/IDSelectionPresentationBackendTests \
  -only-testing:InputDecTests/IDBlockTouchSelectionParityTests \
  -only-testing:InputDecTests/IDBlockTextViewIntegrationTests \
  -only-testing:InputDecTests/IDRichTextLayoutControllerTests \
  -only-testing:InputDecTests/IDRichTextLayoutControllerContractTests \
  -only-testing:InputDecTests/IDPrivateUIKitTests \
  -only-testing:InputDecUITests/IDBlockTouchSelectionUITests
```

Authoritative result: exit `0`, 130 passed, 0 failed, 0 skipped in
`.derivedData-touch-final-fix-focused-green4/Result.xcresult`. Historical diagnostic bundles remain preserved:
`.derivedData-touch-final/Result.xcresult` was 127/130 (settled counts twice and double tap),
`.derivedData-touch-final-fix-focused/Result.xcresult` was 129/130 (forward paragraph tokenization
at the exact physical center returned nil), and
`.derivedData-touch-final-fix-focused-green/Result.xcresult` was 129/130 (a 2-by-9-pixel caret
blink phase differed in the loupe-dismissal ROI), and
`.derivedData-touch-final-fix-focused-green2/Result.xcresult` was 129/130 (stock upper-edge
calibration compared the physical callback point with ideal normalized multiplication instead of
the synthesized coordinate). The interrupted stale green3 bundle is not evidence. None is the
authoritative gate.

```bash
xcodebuild test -quiet -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-touch-final-fix-settled \
  -resultBundlePath .derivedData-touch-final-fix-settled/Result.xcresult \
  -only-testing:InputDecTests/IDBlockTextViewIntegrationTests
```

Exit `0`: 16 passed, 0 failed, 0 skipped. The two additional exact isolated commands selected
the physical triple-tap and loupe methods:

```bash
xcodebuild test -quiet -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-touch-final-fix-triple-green \
  -resultBundlePath .derivedData-touch-final-fix-triple-green/Result.xcresult \
  -only-testing:InputDecUITests/IDBlockTouchSelectionUITests/testTripleTapSelectsExactStockParagraphRange
xcodebuild test -quiet -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-touch-final-fix-loupe-green \
  -resultBundlePath .derivedData-touch-final-fix-loupe-green/Result.xcresult \
  -only-testing:InputDecUITests/IDBlockTouchSelectionUITests/testLongPressShowsNativeLoupeAndTracksCanonicalInsertion
```

Each exited `0` with 1 passed and zero failed/skipped in the named bundle.

The exact synthesized-coordinate correction was isolated with:

```bash
xcodebuild test -quiet -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-touch-final-fix-stock-top-green2 \
  -resultBundlePath .derivedData-touch-final-fix-stock-top-green2/Result.xcresult \
  -only-testing:InputDecUITests/IDBlockTouchSelectionUITests/testStockProbeLeadingHandleHeldAtTopAutoscrolls
```

Exit `0`: 1 passed, 0 failed, 0 skipped. The unchanged 0.5-point assertion now compares the
assistant callback with `edge.screenPoint - editor.frame.origin + initialContentOffset` rather
than ideal normalized multiplication.

### Inherited and build gates

```bash
xcodebuild test -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-touch-inherited-ui \
  -resultBundlePath .derivedData-touch-inherited-ui/Result.xcresult \
  -only-testing:InputDecUITests/IDBlockTextViewUITests \
  -only-testing:InputDecUITests/IDTextLayoutCanvasUITests/testNativeSpellingMarkerAppearsForMisspellingAndClearsAfterCorrection
```

Exit `0`: 6 passed, 0 failed, 0 skipped.

```bash
xcodebuild test -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=404DA68C-E273-46A5-8F6C-B3BF556B80D6' \
  -derivedDataPath .derivedData-touch-inherited-parity \
  -resultBundlePath .derivedData-touch-inherited-parity/Result.xcresult \
  -only-testing:InputDecTests/IDBlockTextViewParityTests
```

Exit `65`: 11 passed, 1 failed, 0 skipped; the sole failure is the retained spelling density
oracle (custom `104`, stock `162`, tolerance `12`).

```bash
xcodebuild build-for-testing -project InputDec.xcodeproj -scheme InputDec \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .derivedData-touch-final-fix-build
xcodegen generate
xcodegen generate
git diff --exit-code -- InputDec.xcodeproj/project.pbxproj
git diff --check
```

Build exited `0`. Before commit, the checked-in candidate, first generation, and second generation
all had identical SHA-1 `9fb25c39dcc82feb25955124363ae7cb21edd0f6`. The generated
`IDBlockTextGeometry` UUIDs are accepted as the deterministic output; they are not manually
restored after generation. The post-commit `git diff --exit-code` result is recorded in the final
verification: two fresh `xcodegen generate` invocations followed by
`git diff --exit-code -- InputDec.xcodeproj/project.pbxproj` and `git diff --check` each exited
`0`. `SESSION_HANDOFF.md` and all result bundles remain untracked and untouched.

## Limitations and self-review

- The retained spelling divergence is custom `104` versus stock `162` red pixels, tolerance `12`.
- Settled-layout tests now use a bounded condition over the pending/scheduled state and exact
  publication count, not a fixed 10-ms drain. The measured double tap uses the established
  focus/quiescence isolation. No selection range, geometry tolerance, or production behavior was
  changed.
- Loupe dismissal still requires the original pixel-identical ROI; bounded sampling waits through
  caret blink phase rather than masking pixels or accepting a larger difference.
- No production UIKit editor token, handcrafted selection rendering, editor-owned autoscroll
  timer, private callback outside `PrivateUIKit`, or test-only private gesture driver entered the
  production target.
- Floating cursor, autocorrection, inline prediction, IME, dictation, hardware keys as a general
  matrix, dark mode, Dynamic Type, landscape, iPad, and physical-device variants remain unchecked.
- This report retains failed bundles as diagnostic history and labels only the final current-head
  result as authoritative.
