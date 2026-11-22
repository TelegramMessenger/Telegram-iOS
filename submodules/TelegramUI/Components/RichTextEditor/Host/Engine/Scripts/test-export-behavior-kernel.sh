#!/bin/bash
# Exports into a temp dir and asserts the snapshot SHAPE. Run from the InputDec repo root.
#
# Note what it does NOT do: it does not `grep` the generated contract data for a class name.
# That file is a hex byte array, so any such grep is vacuous in both directions; the manifest's
# content is checked by test-generate-contract-data.py (Task A1) and, on the parsed object, by
# ContractManifestTests (Task A6).
set -euo pipefail
DEST="$(mktemp -d)/RichTextInputDecObjC"
mkdir -p "$DEST"
Scripts/export-behavior-kernel.sh "$DEST"
for f in IDUIKitBehaviorKernel IDUIKitInputControllerCapability IDUIKitInteractionCapability \
         IDUIKitAutoscrollEntryCapability IDUIKitCapabilityResolver IDUIKitRuntimeContract \
         IDUIKitBehaviorReport; do
  test -f "$DEST/Kernel/$f.m" || { echo "missing Kernel/$f.m"; exit 1; }
  test -f "$DEST/include/Kernel/$f.h" || { echo "missing include/Kernel/$f.h"; exit 1; }
done
test -f "$DEST/include/Kernel/IDUIKitBehaviorCapabilities.h"
test -f "$DEST/include/Kernel/IDUIKitBehaviorBackend.h"
test -f "$DEST/Host/TGRichTextInputDecHostPreflight.m"
test -f "$DEST/include/TGRichTextInputDecHostPreflight.h"
test -f "$DEST/Host/TGRichTextInputDecSelectionRect.m"
test -f "$DEST/include/TGRichTextInputDecSelectionRect.h"
test -f "$DEST/Generated/TGRichTextInputDecContractData.m"
test -f "$DEST/Vendor/UIKitBehaviorContracts-iOS26.5.json"
test -f "$DEST/Vendor/VENDOR.md"

# EVERY copied .m AND .h must be TARGET_OS_IOS-guarded. The headers matter as much as the
# sources: SwiftPM's publicHeadersPath synthesizes an umbrella-DIRECTORY module over include/**,
# so IDUIKitBehaviorKernel.h's line-1 `#import <UIKit/UIKit.h>` is compiled on the macOS
# `swift build`/`swift test` loop and fails with "module 'UIKit' not found".
for f in "$DEST"/Kernel/*.m "$DEST"/include/Kernel/*.h \
         "$DEST/include/TGRichTextInputDecSelectionRect.h" \
         "$DEST/Host/TGRichTextInputDecSelectionRect.m"; do
  head -2 "$f" | grep -q "TargetConditionals.h" || { echo "unguarded: $f"; exit 1; }
  head -3 "$f" | grep -q "^#if TARGET_OS_IOS"   || { echo "unguarded: $f"; exit 1; }
  tail -1 "$f" | grep -q "^#endif"              || { echo "unterminated guard: $f"; exit 1; }
done

! grep -q "IDPrivateUIKit" "$DEST/Kernel/"*.m || { echo "IDPrivateUIKit still referenced"; exit 1; }
! grep -q "static #import" "$DEST/Kernel/"*.m || { echo "Edit 1 spliced into a static decl"; exit 1; }
! grep -q "@throw" "$DEST/Kernel/IDUIKitBehaviorKernel.m" || { echo "kernel manifest @throw survived"; exit 1; }
grep -q "IDUIKitRuntimeManifest \*IDUIKitBehaviorRuntimeManifest" "$DEST/Kernel/IDUIKitBehaviorKernel.m"
grep -q "static IDUIKitRuntimeManifest \*IDUIKitInteractionManifest" \
  "$DEST/Kernel/IDUIKitInteractionCapability.m" \
  || { echo "IDUIKitInteractionManifest lost its static linkage"; exit 1; }
# No #import may appear after the first @implementation — the Edit-1 rewrite hoists them.
python3 - "$DEST" <<'PY'
import pathlib, sys
for p in (pathlib.Path(sys.argv[1]) / "Kernel").glob("*.m"):
    lines = p.read_text().splitlines()
    impl = next((i for i, l in enumerate(lines) if l.startswith("@implementation")), None)
    if impl is None:
        continue
    late = [l for l in lines[impl:] if l.startswith("#import")]
    assert not late, "%s has an #import after @implementation: %s" % (p.name, late)
PY

# ---------------------------------------------------------------------------------------------
# ADDED beyond the brief's listing. Both checks defend findings this plan already paid for.
# ---------------------------------------------------------------------------------------------

# (a) The carved preflight must be the NARROWED, 3-spec one. Task A2 §7.1 measured that
#     IDInteractionHostABISpecs() demands 11 specs at the pre-narrowing revision and 3 after it,
#     that +requireInteractionHost:stage: @throws unless the host answers EVERY spec, and that
#     the 8 extra specs are exactly the canvas-shaped selectors Global Constraint 12 forbids from
#     travelling. The trap is that the wrong carve COMPILES and only raises at the first host
#     check — so nothing downstream of here would catch it. Assert the count at the point of
#     production, and name the forbidden eight so a re-widening is reported by name.
python3 - "$DEST" <<'PY'
import pathlib, re, sys
m = (pathlib.Path(sys.argv[1]) / "Host" / "TGRichTextInputDecHostPreflight.m").read_text()
body = re.search(r"static NSArray<IDInteractionABISpec \*> \*IDInteractionHostABISpecs"
                 r"\(void\) \{.*?\n\}\n", m, re.S)
assert body, "IDInteractionHostABISpecs() is not in the carve"
# `\s*` after the paren is NOT cosmetic. The 11th spec of the PRE-narrowing list wraps its
# selector onto a continuation line (`IDInteractionABISpecMake(\n    @"_visualSelectionRange…"`),
# so the un-anchored form silently counts 10 where the truth is 11 — an undercount, i.e. exactly
# the direction that would hide a re-widening. Measured, after two counts disagreed.
specs = re.findall(r'IDInteractionABISpecMake\(\s*@"([^"]+)"', body.group(0))
assert specs == ["interactionAssistant",
                 "_textInputViewForAddingGestureRecognizers",
                 "selectionContainerView"], \
    "the carved host ABI is not the narrowed 3-spec one: %r" % (specs,)
CANVAS_SHAPED = ["customRenderController", "_convertPointFromRenderSpace:",
                 "_isInteractiveTextSelectionDisabled", "_updateSelectionGestures",
                 "_textKit2CanvasDidLayout", "isEditing", "hasEditableSelection",
                 "_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:"]
leaked = [s for s in CANVAS_SHAPED if s in m]
assert not leaked, "canvas-shaped selectors travelled into the snapshot: %s" % leaked
PY

# (b) VENDOR.md must pin the three per-file revisions, not merely HEAD. A re-export otherwise
#     cannot tell WHICH preflight, WHICH carver and WHICH codegen it reproduced — and the carve's
#     content genuinely differs between revisions of IDPrivateUIKit.m (see (a)).
python3 - "$DEST" <<'PY'
import pathlib, re, sys
v = (pathlib.Path(sys.argv[1]) / "Vendor" / "VENDOR.md").read_text()
SHA = re.compile(r"\b[0-9a-f]{40}\b")
for label in ("upstream commit",
              "PrivateUIKit/IDPrivateUIKit.m",
              "Scripts/carve-host-preflight.sh",
              "Scripts/generate-contract-data.py"):
    # `any`, not `next`: several of these labels appear more than once in the file (the codegen
    # is also named in a prose heading), and pinning the FIRST occurrence would make this pass or
    # fail on section order rather than on content.
    hits = [l for l in v.splitlines() if label in l]
    assert hits, "VENDOR.md does not record: " + label
    assert any(SHA.search(l) for l in hits), \
        "VENDOR.md names %r but never with a full SHA: %r" % (label, hits)
PY

echo "export snapshot OK"
