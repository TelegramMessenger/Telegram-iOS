#!/bin/bash
# Exports the document-neutral UIKit behavior kernel into a telegram-ios snapshot directory.
# The ONLY sanctioned way to produce Sources/RichTextInputDecObjC/{Kernel,include/Kernel,Host,Generated,Vendor}.
set -euo pipefail
DEST="${1:?usage: export-behavior-kernel.sh <abs-dest>}"
case "$DEST" in
  /*) ;;
  *) echo "export: <dest> must be ABSOLUTE — this script cd's to the repo root and a relative"
     echo "        path would silently resolve against it instead of your cwd"; exit 1;;
esac
cd "$(dirname "$0")/.."

# ---------------------------------------------------------------------------------------------
# Clean-tree guard.
#
# `--untracked-files=no` deliberately: a snapshot must be reproducible from a COMMIT, so tracked
# modifications are refused — but untracked files (a scratch build dir, or these very scripts
# before they are committed) do not affect what gets exported and must not block the run.
# RULED 2026-08-24 (Task A1 found this four tasks early, and it was verified before ruling).
#
# The whole-tree form of this guard CANNOT PASS: InputDec carries 53 modified tracked files of
# unrelated in-flight work — Tests/ 14, Scripts/ 9, PrivateUIKit/ 7, UITests/ 6, TextView/ 6,
# Scripts/tests 3, App/ 2, docs/hopper 1, plus README and the xcodeproj. A guard that can never
# be satisfied is a guard someone deletes, which is worse than a narrow one.
#
# SO SCOPE IT TO WHAT THE EXPORT ACTUALLY READS. That preserves the guard's real purpose — the
# snapshot must correspond to a known committed state of its SOURCE — and it is safe here because
# THE KERNEL IS CLEAN, verified rather than assumed: every path below was resolved with
# `git ls-files --error-unmatch` and checked with `git status --porcelain` before this list was
# written, and NOT ONE of them appears among the 53. The modified PrivateUIKit/ and TextView/
# files are the editor and demo layer — IDBlockTextView*, IDPrivateUIKit+*, IDBlockDocument*,
# IDRichTextLayoutController* — which this export does not copy.
#
# CORRECTED 2026-08-24 (a): the kernel lives in `PrivateUIKit/BehaviorKernel/`, not
# `PrivateUIKit/`. The first version of this list named seven paths that DO NOT EXIST, so
# `git status -- <them>` matched nothing and the guard was **vacuously clean for the very files
# being exported**. Caught only by the `--error-unmatch` resolution below — which is exactly why
# it is there. Verify these resolve before trusting a clean result.
#
# CORRECTED 2026-08-24 (b), Task A3: the list was nine paths and the export reads TWENTY-TWO.
# Thirteen inputs that are copied verbatim INTO the snapshot were unguarded: the nine
# BehaviorKernel HEADERS (which travel to include/Kernel/ and are the half the TARGET_OS_IOS trap
# lives in), TextView/IDRichTextSelectionRect.{h,m}, and the two tool scripts this script SHELLS
# OUT TO. That is the same "an omitted path makes the check silently clean" failure the paragraph
# above warns about, thirteen times over — and it was in the version that carried the warning.
# The two tool scripts are here because their OUTPUT is baked into the snapshot, so a dirty
# codegen or carver makes the recorded revisions below describe something that was not run.
#
# NOT in the list, deliberately: THIS script. Self-guarding creates a bootstrap loop — the script
# could not be run at all between an edit and its commit, which makes the red/green loop that
# produced it impossible and is precisely how a guard earns a deletion. Its identity is instead
# recorded downstream, by `upstream commit` in VENDOR.md.
#
# If a future export needs a file not listed here, widen this list rather than the guard's scope.
# ---------------------------------------------------------------------------------------------
KERNEL_PATHS=(
  PrivateUIKit/BehaviorKernel/IDUIKitBehaviorKernel.m
  PrivateUIKit/BehaviorKernel/IDUIKitInputControllerCapability.m
  PrivateUIKit/BehaviorKernel/IDUIKitInteractionCapability.m
  PrivateUIKit/BehaviorKernel/IDUIKitAutoscrollEntryCapability.m
  PrivateUIKit/BehaviorKernel/IDUIKitCapabilityResolver.m
  PrivateUIKit/BehaviorKernel/IDUIKitRuntimeContract.m
  PrivateUIKit/BehaviorKernel/IDUIKitBehaviorReport.m
  PrivateUIKit/BehaviorKernel/IDUIKitBehaviorKernel.h
  PrivateUIKit/BehaviorKernel/IDUIKitInputControllerCapability.h
  PrivateUIKit/BehaviorKernel/IDUIKitInteractionCapability.h
  PrivateUIKit/BehaviorKernel/IDUIKitAutoscrollEntryCapability.h
  PrivateUIKit/BehaviorKernel/IDUIKitCapabilityResolver.h
  PrivateUIKit/BehaviorKernel/IDUIKitRuntimeContract.h
  PrivateUIKit/BehaviorKernel/IDUIKitBehaviorReport.h
  PrivateUIKit/BehaviorKernel/IDUIKitBehaviorCapabilities.h
  PrivateUIKit/BehaviorKernel/IDUIKitBehaviorBackend.h
  PrivateUIKit/Contracts/UIKitBehaviorContracts-iOS26.5.json
  PrivateUIKit/IDPrivateUIKit.m
  TextView/IDRichTextSelectionRect.h
  TextView/IDRichTextSelectionRect.m
  Scripts/carve-host-preflight.sh
  Scripts/generate-contract-data.py
)
# `IDPrivateUIKit.m` is NOT one of the 16 copied files, but Task A2's host-preflight carve READS
# it, so the export depends on it just as much — and its content decides how many private
# selectors the telegram-ios host must answer (3 after the narrowing in c1517772, 11 before it;
# `+requireInteractionHost:stage:` @throws unless the host answers every one). Leaving it out
# made the guard vacuous for that input.
#
# Use an ARRAY and expand it quoted. A space-separated string expanded unquoted does NOT
# word-split under zsh, so the whole list arrives as ONE pathspec, matches nothing, and the guard
# passes vacuously — the same failure by a second route.
#
# Resolve each with `git ls-files --error-unmatch` FIRST, so a path that moves or is renamed
# fails loudly here instead of silently dropping out of the guard.
for p in "${KERNEL_PATHS[@]}"; do
  git ls-files --error-unmatch "$p" >/dev/null 2>&1 \
    || { echo "guard path missing (moved, renamed or untracked): $p"; exit 1; }
done
[ -z "$(git status --porcelain --untracked-files=no -- "${KERNEL_PATHS[@]}")" ] \
  || { echo "refusing to export with uncommitted tracked changes:";
       git status --porcelain --untracked-files=no -- "${KERNEL_PATHS[@]}";
       echo "NOTE: 'git stash' is NOT automatically the right remedy — for IDPrivateUIKit.m it";
       echo "      reverts to a WIDER host ABI that compiles and then @throws at the first host";
       echo "      check. Commit the intended state instead. (Task A2 §7.1.)"; exit 1; }
REV="$(git rev-parse HEAD)"
# Per-file revisions. `git rev-parse HEAD` alone cannot tell a re-export WHICH preflight, WHICH
# carver or WHICH codegen it reproduced, and the carve's CONTENT genuinely differs between
# revisions of IDPrivateUIKit.m.
REV_PREFLIGHT="$(git log -1 --format=%H -- PrivateUIKit/IDPrivateUIKit.m)"
REV_CODEGEN="$(git log -1 --format=%H -- Scripts/generate-contract-data.py)"
REV_CARVER="$(git log -1 --format=%H -- Scripts/carve-host-preflight.sh)"

mkdir -p "$DEST"/{Kernel,include/Kernel,Host,Generated,Vendor}

K=PrivateUIKit/BehaviorKernel
cp "$K"/*.h "$DEST/include/Kernel/"
cp "$K"/*.m "$DEST/Kernel/"

# Edit 1 — the two duplicated resource lookups become one compiled-in-bytes call that returns
# nil instead of @throw-ing. A @throw on a missing resource is a launch-time crash inside the
# Telegram app, where NSBundle bundleForClass: resolves to the framework bundle and the two
# build systems locate resources differently.
#
# Three things a naive version gets wrong and this one does not: the pattern must absorb an
# optional `static` (IDUIKitInteractionManifest is declared static, and matching from
# `IDUIKitRuntimeManifest *` leaves a dangling `static ` in front of the replacement, producing
# `static #import "…"`, which does not compile); the storage class must be PRESERVED, or the
# rewrite silently promotes a file-local symbol to a global one in the app binary; and the
# `#import` must be hoisted to the top of the file rather than emitted at the match site.
python3 - "$DEST" <<'PY'
import re, sys, pathlib
dest = pathlib.Path(sys.argv[1])
IMPORT = '#import "TGRichTextInputDecContract.h"'
BODY = ('%sIDUIKitRuntimeManifest *%s(void) {\n'
        '    return TGRichTextInputDecContractManifest();\n'
        '}\n')
for name, fn in (("IDUIKitBehaviorKernel.m", "IDUIKitBehaviorRuntimeManifest"),
                 ("IDUIKitInteractionCapability.m", "IDUIKitInteractionManifest")):
    p = dest / "Kernel" / name
    s = p.read_text()
    pattern = re.compile(r"(?P<storage>static\s+)?IDUIKitRuntimeManifest \*"
                         + fn + r"\(void\) \{.*?\n\}\n", re.S)
    match = pattern.search(s)
    assert match, "manifest lookup not found in " + name
    storage = match.group("storage") or ""
    s = s[:match.start()] + (BODY % (storage, fn)) + s[match.end():]

    # Hoist the import: place it directly after the LAST leading #import of the file, so no
    # directive ever lands inside or after a declaration.
    lines = s.splitlines(keepends=True)
    last_import = max(i for i, l in enumerate(lines) if l.startswith("#import"))
    lines.insert(last_import + 1, IMPORT + "\n")
    s = "".join(lines)

    assert "static #import" not in s, name + ": import spliced into a storage-class decl"
    impl = s.find("@implementation")
    if impl != -1:
        assert IMPORT not in s[impl:], name + ": import landed after @implementation"
    p.write_text(s)
PY

# Edits 2 and 3 — the only two places the kernel reaches outside BehaviorKernel/ (4 grep hits).
python3 - "$DEST" <<'PY'
import sys, pathlib
dest = pathlib.Path(sys.argv[1])
for name in ("IDUIKitInteractionCapability.m", "IDUIKitAutoscrollEntryCapability.m"):
    p = dest / "Kernel" / name
    s = p.read_text()
    s = s.replace('#import "IDPrivateUIKit.h"', '#import "TGRichTextInputDecHostPreflight.h"')
    s = s.replace("[IDPrivateUIKit", "[TGRichTextInputDecHostPreflight")
    assert "IDPrivateUIKit" not in s, name + " still references IDPrivateUIKit"
    p.write_text(s)
PY

# Guard EVERY vendored translation unit and EVERY vendored header. The header half is not
# optional: IDUIKitBehaviorKernel.h:1, IDUIKitInputControllerCapability.h:1,
# IDUIKitInteractionCapability.h:1 and IDRichTextSelectionRect.h:1 each begin
# `#import <UIKit/UIKit.h>`, and SwiftPM's publicHeadersPath compiles every header under
# include/** into the synthesized umbrella-directory module. Package.swift also declares
# .macOS(.v10_13), so an unguarded header fails the mandatory macOS `swift build` with
# "module 'UIKit' not found". See the comment in test-export-behavior-kernel.sh.
guard_file() {
  python3 - "$1" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
if "TARGET_OS_IOS" in s:
    sys.exit(0)
p.write_text("#import <TargetConditionals.h>\n#if TARGET_OS_IOS\n\n" + s.rstrip("\n") + "\n\n#endif\n")
PY
}
for f in "$DEST"/Kernel/*.m "$DEST"/include/Kernel/*.h; do guard_file "$f"; done

Scripts/carve-host-preflight.sh "$DEST"     # emits Host/ + include/ TGRichTextInputDecHostPreflight

cp TextView/IDRichTextSelectionRect.h "$DEST/include/TGRichTextInputDecSelectionRect.h"
cp TextView/IDRichTextSelectionRect.m "$DEST/Host/TGRichTextInputDecSelectionRect.m"
sed -i '' 's/IDRichTextSelectionRect/TGRichTextInputDecSelectionRect/g' \
  "$DEST/include/TGRichTextInputDecSelectionRect.h" "$DEST/Host/TGRichTextInputDecSelectionRect.m"
guard_file "$DEST/include/TGRichTextInputDecSelectionRect.h"
guard_file "$DEST/Host/TGRichTextInputDecSelectionRect.m"

JSON=PrivateUIKit/Contracts/UIKitBehaviorContracts-iOS26.5.json
cp "$JSON" "$DEST/Vendor/"
Scripts/generate-contract-data.py "$JSON" "$DEST/Generated/TGRichTextInputDecContractData.m"

OSV="$(python3 -c 'import json,sys;m=json.load(open(sys.argv[1]));print(m["runtime"]["osVersion"])' "$JSON")"
OSB="$(python3 -c 'import json,sys;m=json.load(open(sys.argv[1]));print(m["runtime"]["osBuild"])' "$JSON")"
cat > "$DEST/Vendor/VENDOR.md" <<EOF
# Vendored InputDec behavior kernel — provenance

DO NOT HAND-EDIT anything under Kernel/, include/Kernel/, Generated/, Vendor/, or
Host/TGRichTextInputDecHostPreflight.* or Host/TGRichTextInputDecSelectionRect.*.
Re-sync with: InputDec/Scripts/export-behavior-kernel.sh <abs path to this directory>

- upstream repo: /Users/isaac/Documents/InputDec
- upstream commit: $REV
- exported: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- certified OS band: $OSV (build $OSB) — the only combination this kernel has been run on
- pristine manifest SHA-256: $(shasum -a 256 "$JSON" | cut -d' ' -f1)
- generated contract data SHA-256: $(shasum -a 256 "$DEST/Generated/TGRichTextInputDecContractData.m" | cut -d' ' -f1)

## Exact revision of every input that is not copied verbatim
\`upstream commit\` alone cannot answer "which one did this reproduce?" for the three inputs whose
content is transformed on the way in. Each is the last commit that touched that path.

| input | revision | why it matters |
| --- | --- | --- |
| \`PrivateUIKit/IDPrivateUIKit.m\` | $REV_PREFLIGHT | decides the carved host ABI: **3** portable specs at this revision, **11** before it. \`+requireInteractionHost:stage:\` @throws unless the host answers every one, and the 8 extra are the canvas-shaped selectors Global Constraint 12 forbids from travelling. The wrong carve compiles and fails only at the first host check. |
| \`Scripts/carve-host-preflight.sh\` | $REV_CARVER | produced Host/TGRichTextInputDecHostPreflight.{h,m} |
| \`Scripts/generate-contract-data.py\` | $REV_CODEGEN | produced Generated/TGRichTextInputDecContractData.m, including the class renames below |

## Manifest transforms (applied by Scripts/generate-contract-data.py)
Renames are applied on the member's \`"class"\` key — the JSON spells it \`class\`, and the
\`className\` name appears only on the parsed Objective-C property (IDUIKitRuntimeContract.m:344).
| manifest rows | upstream class | vendored class |
| --- | --- | --- |
| 47 capabilities.incomingCallbacks.members[*] | IDRichTextLayoutController | TGRichTextInputDecLayoutController |
| 1 capabilities.inputController.members[keyboardDeletePreflight] | IDBlockTextView | TGRichTextInputDecCanvasABIWitness |
| 2 capabilities.autoscrollEntry.members[start, cancel] | IDBlockTextView | TGRichTextInputDecCanvasABIWitness |

\`referenceOnly\` is emptied to \`{}\` (53 rows dropped). The KEY is retained: the manifest parser
demands the exact top-level key set {schema, runtime, capabilities, referenceOnly, forbidden}.
\`forbidden\` (8 symbols) travels intact as a deny-list the telegram-ios tests assert against.

Because of these transforms the shipped manifest is NOT byte-identical to the certified one.
"Certified" here means: every ABI row (name, returnType, argumentTypes, kind) is unchanged.

## Behavior this snapshot does NOT change
The kernel still raises NSException on a contract mismatch. **Seven sites survive**, at these
upstream line numbers:

- IDUIKitBehaviorReport.m:80
- IDUIKitInteractionCapability.m:144, 157, 262
- IDUIKitInputControllerCapability.m:131, 228, 531

plus TGRichTextInputDecHostPreflight's two methods. Only the two manifest-resource lookups were
converted to nil-returning — one of which was IDUIKitInteractionCapability.m:130, which is why
that file goes from four @throw sites to three. (Add two for the TARGET_OS_IOS guard to convert
these to line numbers in the vendored copies.)

The telegram-ios side must funnel every entry point through TGRichTextInputDecExceptionGuard;
see that plan's Task A8.

## Paths this script owns (everything else in the module is telegram-ios-authored)
Kernel/, include/Kernel/, Generated/, Vendor/,
Host/TGRichTextInputDecHostPreflight.m, include/TGRichTextInputDecHostPreflight.h,
Host/TGRichTextInputDecSelectionRect.m, include/TGRichTextInputDecSelectionRect.h

## Upstream green-run evidence
xcodebuild test -project InputDec.xcodeproj -scheme InputDec \\
  -destination id=FA6F7462-AA97-42FE-9E57-8DA0593CE756 -parallel-testing-enabled NO
EOF
echo "exported kernel @ $REV -> $DEST"
