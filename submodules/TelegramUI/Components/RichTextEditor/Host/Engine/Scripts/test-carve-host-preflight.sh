#!/bin/bash
set -euo pipefail
DEST="$(mktemp -d)/snap"; mkdir -p "$DEST"/{Host,include}
Scripts/carve-host-preflight.sh "$DEST"
H="$DEST/include/TGRichTextInputDecHostPreflight.h"
M="$DEST/Host/TGRichTextInputDecHostPreflight.m"
grep -q "@interface TGRichTextInputDecHostPreflight : NSObject" "$H"
grep -q "requireInteractionHost:(id)host stage:" "$H"
grep -q "adoptResolvedTextAutoscrollingProtocol:" "$H"
grep -q "^#if TARGET_OS_IOS" "$H"
grep -q "^#if TARGET_OS_IOS" "$M"
# Every static in the mismatch chain must be DEFINED, not merely mentioned. A bare
# `grep -q IDInteractionABIMismatch` is satisfied by IDInteractionABIMismatches, which is why
# each check anchors on the definition line.
for sym in IDInteractionTypeEncoding IDInteractionABISpecMake IDInteractionHostABISpecs \
           IDInteractionSkipTypeQualifiers IDInteractionTypeMatches \
           IDInteractionABIMismatchForSignature IDInteractionABIMismatch \
           IDInteractionABIMismatches; do
  grep -qE "^static .*[ *]${sym}\(" "$M" || { echo "carve is missing static $sym"; exit 1; }
done
grep -q "interactionAssistant" "$M"
grep -q "_textInputViewForAddingGestureRecognizers" "$M"
grep -q "selectionContainerView" "$M"
! grep -q "IDPrivateUIKit" "$M"
# The carve must NOT drag the reference backend in.
for forbidden in objc_allocateClassPair _UITextLayoutCanvasView IDTextView IDBlockDocument; do
  ! grep -q "$forbidden" "$M" || { echo "carve dragged in $forbidden"; exit 1; }
done
test "$(wc -l < "$M")" -lt 250 || { echo "carve is too large — it grabbed extra regions"; exit 1; }
echo "carve OK"
