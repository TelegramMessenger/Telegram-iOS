# The InputDec behavior kernel — origin

**THIS REPOSITORY IS THE SOURCE OF TRUTH FOR THESE FILES (2026-09-15).** The old header said DO NOT
HAND-EDIT and named `InputDec/Scripts/export-behavior-kernel.sh` as the way to change them. There is
nothing to export FROM any more: `~/Documents/InputDec` lost its `.git` and is an archive, so this
copy is the live one. Edit `Kernel/`, `include/Kernel/` and the two carved `Host/` pairs here, like
any other source.

**Two files are still GENERATED, and that has not changed**: `Vendor/`'s pristine manifest JSON and
`Generated/TGRichTextInputDecContractData.m`, produced from it by `generate-contract-data.py` with
the transforms recorded below. `VendorSnapshotIntegrityTests` still hashes both against the pins
listed here — not to forbid a change, but so that an ACCIDENTAL edit to a generated blob is caught
and a deliberate one has to re-record the pin and say why. The generator itself has not been brought
across yet; until it is, a change to the manifest is hand-maintained, which is a reason to prefer
regenerating over editing.

- taken from: /Users/isaac/Documents/InputDec (archive since 2026-09-15)
- last revision taken: fdad9ca519f5f27a07362e00dc6cefdcb73ca369
- exported: 2026-08-24T19:50:23Z
- certified OS band: 26.5 (build 23F73) — the only combination this kernel has been run on
- pristine manifest SHA-256: a60bb026db345de4c487b45661f97f41e05c1270d1d2c7f5f58d5d92b5440e43
- generated contract data SHA-256: 9e4a5ec1c1f0aa213ed94159b8bd6be8037a06f83f91513458733480710c4761
- generated contract data decoded SHA-256: 68bc058fb91f8ea924ea96d196afeee6855d2e2d299b6c548a699d02d933699a

Both generated blobs store every byte XOR 0x5A (2026-10-12), so the private UIKit names in the
manifest do not reach the binary as text; each is decoded once when loaded. Encoding changed the
FILE's digest (it was af87291249fbc474ac908b885527d935265df22514732f815638b68648aaadf0) and not
its content: the decoded digest above is the one the bytes had before, and the pristine blob in
`RichTextInputDecUpstream/Generated/` decodes to the pristine manifest's digest. A regeneration
must encode again: `Scripts/generate-private-runtime-names.py --encode-bytes <plain file>` prints the
array's rows (verified to reproduce both checked-in arrays byte for byte).

## Exact revision of every input that is not copied verbatim
`upstream commit` alone cannot answer "which one did this reproduce?" for the three inputs whose
content is transformed on the way in. Each is the last commit that touched that path.

| input | revision | why it matters |
| --- | --- | --- |
| `PrivateUIKit/IDPrivateUIKit.m` | c1517772529a3610f238b5a7caa47ec42b3f1f40 | decides the carved host ABI: **3** portable specs at this revision, **11** before it. `+requireInteractionHost:stage:` @throws unless the host answers every one, and the 8 extra are the canvas-shaped selectors Global Constraint 12 forbids from travelling. The wrong carve compiles and fails only at the first host check. |
| `Scripts/carve-host-preflight.sh` | 60b15b9dcb6bf8663632c987dddaf481c48ac773 | produced Host/TGRichTextInputDecHostPreflight.{h,m} |
| `Scripts/generate-contract-data.py` | 548d0a4cb654691b60b5eae445a364627590c28f | produced Generated/TGRichTextInputDecContractData.m, including the class renames below |

## Manifest transforms (applied by Scripts/generate-contract-data.py)
Renames are applied on the member's `"class"` key — the JSON spells it `class`, and the
`className` name appears only on the parsed Objective-C property (IDUIKitRuntimeContract.m:344).
| manifest rows | upstream class | vendored class |
| --- | --- | --- |
| 47 capabilities.incomingCallbacks.members[*] | IDRichTextLayoutController | TGRichTextInputDecLayoutController |
| 1 capabilities.inputController.members[keyboardDeletePreflight] | IDBlockTextView | TGRichTextInputDecCanvasABIWitness |
| 2 capabilities.autoscrollEntry.members[start, cancel] | IDBlockTextView | TGRichTextInputDecCanvasABIWitness |

`referenceOnly` is emptied to `{}` (53 rows dropped). The KEY is retained: the manifest parser
demands the exact top-level key set {schema, runtime, capabilities, referenceOnly, forbidden}.
`forbidden` (8 symbols) travels intact as a deny-list the telegram-ios tests assert against.

Because of these transforms the shipped manifest is NOT byte-identical to the certified one.
"Certified" here means: every ABI row (name, returnType, argumentTypes, kind) is unchanged.

## Behavior this snapshot DOES change (one case, found 2026-09-15)

`referenceOnly` being emptied is recorded above as a manifest transform, and it was described as
ABI-preserving — which it is, row for row. **It is not behaviour-preserving.** A capability whose
REJECTION upstream comes from a `referenceOnly` contract is merely *unavailable* here: the kernel
reports `IDUIKitCapabilityStateUnavailable` where upstream reports `…RejectedContract`. Measured on
`autoscrollEntry`, which appears in the pristine manifest's `referenceOnly` while the shipped
`Generated/TGRichTextInputDecContractData.m` contains the string `referenceOnly` zero times.

It surfaced because the engine's own suites were imported: upstream's
`IDUIKitBehaviorBackendDifferentialTests.testEveryOptionalCapabilityHasUnavailableAndRejectedFallback`
asserts exactly this and is the one imported case retired for a behavioural rather than a layout
reason. Restoring it is a decision about the kernel — put the 53 rows back — not about its tests.

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
xcodebuild test -project InputDec.xcodeproj -scheme InputDec \
  -destination id=FA6F7462-AA97-42FE-9E57-8DA0593CE756 -parallel-testing-enabled NO
