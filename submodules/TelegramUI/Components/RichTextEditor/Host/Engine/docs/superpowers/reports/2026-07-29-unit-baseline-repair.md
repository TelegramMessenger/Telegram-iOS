# Unit Baseline Repair Report

## Runtime

- Simulator: `FA6F7462-AA97-42FE-9E57-8DA0593CE756` (`iPhone 17 Pro K3`)
- OS: iOS 26.5
- Build: `23F73`
- Parallel simulator testing: disabled
- XCTest execution: serialized through the repository simulator lock

## Floating Cursor

- Ownership seam: `IDUIKitInteractionCapability.privateAssistant`
- Production changes: none
- Focused result: 24 passed, 0 failed, 0 skipped
- Coverage retained: public begin/update/animated-update/end, responder loss,
  editability/selectability cleanup, gesture cleanup, and graph teardown

## Smart Paste

- `UITextSmartInsertDeleteTypeNo`: stock and custom both produced `"AX"` for
  plain and rich paste.
- `UITextSmartInsertDeleteTypeYes`: stock and custom both produced `"A X"` for
  plain and rich paste.
- Plain paste preserved the active bold typing trait.
- Rich paste preserved bold, italic, underline, and strikethrough traits.
- Every row matched the stock selection, `should` → `selection` → `change`
  callback order, undo availability, and undo result (`"A"`).
- Production repair:
  `PrivateUIKit/IDBlockTextView+PrivateCallbacks.m` mirrors
  `UITextView`'s `_attributedStringForInsertionOfAttributedString:` forwarding
  bridge to the UIKit input controller.
- Focused result: 30 passed, 0 failed, 0 skipped

## Spelling

- First divergent layer: typing context, before spelling annotation projection
  or rendering. Insertion into an empty custom block fell back to Helvetica
  12 pt, while stock used the configured 17 pt font.
- Stock before repair: red rows 22–24 were `[54, 54, 54]`, total 162.
- Custom before repair: red rows 17–19 were `[36, 37, 31]`, total 104.
- Custom after repair: red rows 22–24 are `[54, 54, 54]`, total 162,
  identical to stock in three consecutive diagnostic runs.
- Annotation coverage remained the exact half-open word range `[0, 9)`.
- Repair:
  - `TextView/IDBlockLayout.m` exposes an empty block's separator/default
    attributes as its native typing context.
  - `TextView/IDBlockDocument.m` carries changed defaults into empty-block
    separator attributes while preserving other separator metadata.
  - `TextView/IDBlockTextView.m` allows and initializes UIKit-owned font/color
    typing attributes and refreshes them when view defaults change.
- No custom spelling underline, checker policy, canvas invalidation, surface
  clipping, or rasterization code was added.
- Pixel tolerance: 12 pixels, unchanged.
- Focused spelling/layout result: 24 passed, 0 failed, 0 skipped.
- Related typing/formatting/backend regression result: 72 passed, 0 failed,
  0 skipped.

## Final Gates

- `InputDecTests`: 758 passed, 0 failed, 0 skipped.
- Fast differential: 225 passed, 0 failed, 0 skipped.
- Floating keyboard sentinels: 4/4 passed.
- Complete real-keyboard gate: 24/24 passed, 0 failed, 0 skipped.
- The documented keyboard-readiness retry was used for two inline-prediction
  methods; both subsequently passed.

## Preserved Work

- Controller-owned text-input traits preserved.
- IME work preserved.
- Inline formatting work preserved.
- Clean-room vertical autoscroll unchanged.
- Pre-existing uncommitted traits, IME, fixtures, scripts, and documentation
  changes remain in the working tree and were not included in repair commits.
