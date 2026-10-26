#!/bin/bash
# Carves the interaction-host preflight + autoscroll protocol adoption out of the 2998-line
# IDPrivateUIKit.m into a standalone ~150-line vendored file. Symbol-driven, not line-driven:
# that file is actively edited, so hard-coded ranges rot silently (as of 2026-08-24 the two
# IDInteractionABISpec declarations sit at 941/950 in the working tree and 678/687 in HEAD).
set -euo pipefail
DEST="${1:?usage: carve-host-preflight.sh <abs-dest>}"
SRC=PrivateUIKit/IDPrivateUIKit.m
[ -f "$SRC" ] || { echo "carve: $SRC not found — run this from the InputDec repo root"; exit 1; }
mkdir -p "$DEST/Host" "$DEST/include"

cat > "$DEST/include/TGRichTextInputDecHostPreflight.h" <<'EOF'
// CARVED from InputDec/PrivateUIKit/IDPrivateUIKit.m by Scripts/carve-host-preflight.sh.
// DO NOT HAND-EDIT — see Vendor/VENDOR.md.
#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// The two IDPrivateUIKit class methods the vendored behavior kernel calls, and nothing else.
/// BOTH RAISE NSException on a mismatch — that is upstream behavior and is deliberately
/// preserved; the Swift adapter routes every call through TGRichTextInputDecExceptionGuard.
@interface TGRichTextInputDecHostPreflight : NSObject
+ (void)requireInteractionHost:(id)host stage:(NSString *)stage;
+ (BOOL)adoptResolvedTextAutoscrollingProtocol:(Protocol *)protocol onClass:(Class)viewClass;
@end

NS_ASSUME_NONNULL_END

#endif
EOF

# awk extractor: print from a line matching $1 until the first line that is exactly "}"
# at column 0 (both C functions and ObjC method bodies in this file close that way).
#
# The pattern travels through ENVIRON, NOT through `awk -v`. Measured on macOS awk (BWK,
# version 20200816): a -v assignment escape-processes its value, so `\(` arrives as a bare
# `(`. For the `^static ...\(` patterns that is a loud `illegal primary in regular
# expression`; for `^\+ \(void\)...` it silently becomes a capture group that matches
# NOTHING, and awk still exits 0. ENVIRON values are not escape-processed.
extract() {
  local out
  out="$(ID_CARVE_PAT="$1" awk '
    BEGIN { pat = ENVIRON["ID_CARVE_PAT"] }
    $0 ~ pat { emit = 1 }
    emit { print }
    emit && /^\}$/ { exit }
  ' "$SRC")"
  # An awk miss is an EMPTY region, not an error. Fail here rather than emitting a
  # translation unit that only breaks at Task A6/A7 link time.
  [ -n "$out" ] || { echo "carve: no region matched /$1/ in $SRC" >&2; exit 1; }
  printf '%s\n' "$out"
}

{
  echo '// CARVED from the InputDec behavior kernel by Scripts/carve-host-preflight.sh.'
  echo '// DO NOT HAND-EDIT — see Vendor/VENDOR.md for the upstream file, commit and date.'
  echo '#import <TargetConditionals.h>'
  echo '#if TARGET_OS_IOS'
  echo
  echo '#import <objc/runtime.h>'
  echo '#import "TGRichTextInputDecHostPreflight.h"'
  echo
  # 1. The spec value type: @interface … @end then @implementation … @end.
  awk '/^@interface IDInteractionABISpec /,/^@end$/' "$SRC"
  echo
  awk '/^@implementation IDInteractionABISpec$/,/^@end$/' "$SRC"
  echo
  # 2. The file-static helpers, in DEPENDENCY ORDER. The chain is not the three obvious ones:
  #    IDInteractionABIMismatches -> IDInteractionABIMismatch -> IDInteractionABIMismatchForSignature
  #    -> IDInteractionTypeMatches -> IDInteractionSkipTypeQualifiers, and both the signature
  #    formatter and the mismatch text call IDInteractionTypeEncoding. Omitting any of the three
  #    inner helpers leaves the carved translation unit referencing undefined statics — it fails at
  #    Task A6/A7, and the presence loop below cannot catch it unless the name is listed there too.
  #    (IDInteractionInstanceABIMismatches is deliberately NOT carved: nothing the two class
  #    methods call reaches it.)
  for fn in IDInteractionTypeEncoding IDInteractionABISpecMake IDInteractionHostABISpecs \
            IDInteractionSkipTypeQualifiers IDInteractionTypeMatches \
            IDInteractionABIMismatchForSignature \
            IDInteractionABIMismatch IDInteractionABIMismatches; do
    extract "^static .*[ *]${fn}\\("
    echo
  done
  # 3. The two class methods, rehomed onto the carved class.
  echo '@implementation TGRichTextInputDecHostPreflight'
  echo
  extract '^\+ \(void\)requireInteractionHost:'
  echo
  extract '^\+ \(BOOL\)adoptResolvedTextAutoscrollingProtocol:'
  echo
  echo '@end'
  echo
  echo '#endif'
} > "$DEST/Host/TGRichTextInputDecHostPreflight.m"

# Every helper the carve names must actually be present; an awk miss produces an empty region
# that would otherwise only surface as a link error inside the Telegram build.
# NB: substring greps are not enough on their own — `grep -q IDInteractionABIMismatch` succeeds on
# a file that only contains IDInteractionABIMismatches. Each name is therefore checked as a
# DEFINITION (`^static ...<name>(`), which is exact.
for sym in IDInteractionTypeEncoding IDInteractionABISpecMake IDInteractionHostABISpecs \
           IDInteractionSkipTypeQualifiers IDInteractionTypeMatches \
           IDInteractionABIMismatchForSignature IDInteractionABIMismatch \
           IDInteractionABIMismatches; do
  grep -qE "^static .*[ *]${sym}\\(" "$DEST/Host/TGRichTextInputDecHostPreflight.m" \
    || { echo "carve lost the definition of $sym — the upstream symbol was renamed or reshaped"; exit 1; }
done
for sym in requireInteractionHost adoptResolvedTextAutoscrollingProtocol; do
  grep -q "$sym" "$DEST/Host/TGRichTextInputDecHostPreflight.m" \
    || { echo "carve lost $sym — the upstream symbol was renamed or reshaped"; exit 1; }
done
echo "carved host preflight -> $DEST"
