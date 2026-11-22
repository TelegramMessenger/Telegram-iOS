# The InputDec text engine — origin

**THIS REPOSITORY IS THE SOURCE OF TRUTH FOR THESE FILES (2026-09-15).** Edit them here, like any
other source in the tree. There is no upstream to change first, nothing to re-port, no hash list to
re-record, and no ceremony around a change — a fix to the engine is an ordinary commit.

That was not true until 2026-09-15, and everything below the next section is the record of how the
code got here, which is still worth reading: the file set, the layout, and the six ways this copy
differs from the tree it was taken from are all facts about the code you are editing.

**What changed and why.** These 78 files were a FORK of `~/Documents/InputDec`, kept honest by this
document plus two SHA-256 lists and `Scripts/verify-ported-files.sh`, with every change made
upstream first and copied across. That arrangement rested on upstream being a repository. It stopped
being one: its `.git` went missing on this machine between 2026-09-11 and 2026-09-12, so from then
on the "source of truth" was an unversioned working tree on one disk, and this port — which IS
versioned, reviewed and CI-adjacent — was the better copy of the same code. Three changes had
already been recorded as "working tree at ⟨date⟩" rather than as a commit, because no commit
existed to name.

So the direction is reversed: `~/Documents/InputDec` is now an archive, this is the live code, and
the ceremony that existed to keep the two in step is gone. `PORTED-FILES.sha256`,
`PORTED-FILES-local.sha256` and `Scripts/verify-ported-files.sh` are deleted — a hash list over
files you are free to edit fires on every legitimate change and is re-recorded reflexively, which is
a tripwire with no signal.

**What this does NOT bring across, and it is the open half:** upstream also holds the engine's
PROOF — 1,078 unit and 196 UI test cases, the stock-`UITextView` oracle host they compare against,
and their fixtures. Until those are imported, this repo owns the engine without owning what shows it
works. See the package `CLAUDE.md` for where that stands.

## Origin

| | |
| --- | --- |
| taken from | `~/Documents/InputDec` — an archive since 2026-09-15, not a dependency |
| last revision taken | working tree at 2026-09-15 (a selection whose boundary lands on a PARAGRAPH BREAK is still drawn — the head side of a separator answered a zero-width rect as a failure to measure, which discarded the whole document's selection geometry; reported as "the selection is invisible if one of the selected lines is empty", because an empty line has one offset and every selection touching it is bounded that way); previously working tree at 2026-09-15 (a run is caught in the instant UIKit reports it is NOT decelerating, and a caught run is PINNED until the finger lifts — the single offset assignment cancelled nothing, because at that instant there is no deceleration to cancel); previously working tree at 2026-09-12 (a content touch is no longer held back for 150ms — `delaysContentTouches = NO` on the text view; **the upstream repo's `.git` went missing on this machine between that commit and this port, so this row names a tree rather than a commit**); previously `8f08291e` (only the CAUGHT run settles on release — settling every run on every touch ate the ordinary rubber band); previously `4356ae63` (catching a bounce holds it and the release springs it back); previously `5556bb11` (a caught run keeps the gesture that caught it); previously `ec31cab8` (a caught run stays in flight while the finger is down); previously `0c4005c9` (a host can ask whether a placed run is in flight — `id_hasPlacedRunInFlight`, so an outer sheet's dismiss pan keeps off it); previously `8fb91aa1` (a decelerating run is caught through its pan's own per-touch callback); previously `984086f7` (the canvas catches a decelerating run because the run never sees a touch); previously `e7f9a5d8` (a run rests in its COLUMN and is clipped by its WINDOW — `placedRunColumnOutsets`, so one boundary can clip a table and its chrome together); previously `12484b05` (a narrowed clip adds the travel it takes away, superseded by the column); previously `1e604527` (a host says where one run of placed blocks ends — `placedRunStarts`, so two tables never share a scroll view or a clip); previously `a71301dd` (a block inset narrows the text it reserves space for — a stacked block's horizontal insets now leave its measure, as a placed block's always did); previously `7c338fd6` (the caret is drawn in the commit that draws the glyphs — `id_flushSelectionDisplayUpdate`); previously `e0c2a0df` (re-port 2026-09-11, a host says where a placed run's clip ends — `placedRunClipOutsets`); previously `d0787f4b` (re-port 2026-09-11, the selection container keeps `-textInputView`'s coordinate space, so the autocorrection prompt lands on its word); previously `315fd8f0` (re-port 2026-09-11, UIKit's text-geometry result block gets all four arguments and selection rects carry a baseline — the autocorrection underline); previously `be498c3d` (re-port 2026-09-11 later, the run's scroller shows no indicator); previously `511a07b4` (re-port 2026-09-11, a placed run's offset clamped only when its geometry changes, so the rubber band survives the per-tick pass); previously `9fe032c4` (re-port 2026-09-04, correction contract, empty-line providers, host attribute-only edits, trailing-Return adoption); previously `442f395`; originally `fdad9ca519f5f27a07362e00dc6cefdcb73ca369` |
| brought across | 2026-08-26T23:09:27Z; re-ported 2026-09-01 (the three `IDBlockLayout`/`IDBlockStackCanvasView`/`IDBlockTextView` pairs, for host-supplied empty-line attributes), 2026-08-28 (`TextView/IDBlockTextView.m`), 2026-08-28 (three iOS-18.4 availability gates), 2026-08-30 (`IDInlineTextStyleResolver.{h,m}`, then `IDInlineTextStyleResolver.h` + `IDBlockTextView.m` for the source-scan prose fixes, then `IDBlockTextView.{h,m}` + `IDInlineTextFormattingController.{h,m}` for the host-attribute storage seam), 2026-08-31 (`IDCanonicalTextStorageAdapter.{m,h}` + `IDInlineTextStyleResolver.{h,m}` + `IDBlockTextView.m` moving the contributor pass to the render read), 2026-09-11 (`TextView/IDBlockStackCanvasView.m`, for the placed run's rubber band, then again for its indicator), 2026-09-11 (`TextView/IDBlockTextView.m` + `TextView/IDBlockTextViewInternal.h`, flushing UIKit's pending selection display from `-layoutSubviews` so the caret is not drawn one run-loop iteration behind the glyphs), 2026-09-12 (`TextView/IDBlockTextView.m`, `delaysContentTouches = NO` — note the theory behind that one was WRONG: the property delays touches to VIEWS, not gesture-recogniser callbacks, so it cannot have gated the catch), 2026-09-15 (`TextView/IDBlockStackCanvasView.m`, the real catch fix: `id_isAnimatingNow` replaces the `isDecelerating` gate and `-setContentOffset:` pins a caught run), 2026-09-15 (`TextView/IDBlockTextGeometry.m` + `TextView/IDDocumentLayoutCoordinator.m`, the empty-line selection fix: a zero-length range no extension could widen contributes NO segment instead of declaring the block inexact, and the head side of a separator yields its canonical range — and the logical endpoint that lands on it — to the tail side that already took it) |
| files | **78** (`.h` 41 + `.m` 37) |
| upstream lines | **16,492** (16,464 for PORT-PLAN §3.1's 77 + 28 for the 78th, below) |

### RESOLVED 2026-08-28: the thirteen uncommitted files are now committed upstream

`task-PORT-PLAN.md` §9.6 raised this as a medium risk and it was real: for eighteen months of this
port's life its source of truth was a **working tree**, not a commit. Thirteen of the 78 were
modified-not-committed at `fdad9ca5`, and they were precisely the load-bearing ones — the host, the
engine, all three private categories, and the temporary-attribute file:

```
PrivateUIKit/IDBlockTextView+PrivateCallbacks.m       TextView/IDBlockDocument.m
PrivateUIKit/IDBlockTextView+PrivateInputDelegate.m   TextView/IDBlockDocumentInternal.h
PrivateUIKit/IDBlockTextView+PrivateInteractionCallbacks.m  TextView/IDBlockTextView+TextInput.m
PrivateUIKit/IDPrivateUIKit+RichTextLayout.h          TextView/IDBlockTextView.m
PrivateUIKit/IDPrivateUIKit+RichTextLayout.m          TextView/IDBlockTextViewInternal.h
PrivateUIKit/IDPrivateUIKit+Testing.h                 TextView/IDRichTextLayoutController.m
PrivateUIKit/IDPrivateUIKit.h
```

**Those thirteen were committed upstream on 2026-08-28 as `f01960b`** (a snapshot of the whole
in-progress tree, artifacts excluded), and `442f395` on top of it moved the keyboard-input install
off `+load`. So for the middle of this port's life the revisions above name commits that genuinely
contain what was copied.

**It did not last, and that is what ended the arrangement.** Upstream's `.git` went missing between
2026-09-11 and 2026-09-12, so the last three rows name a working tree again — and this time with no
prospect of a commit to replace them. The hash lists that stood in for a commit id
(`PORTED-FILES.sha256`, upstream-relative, and `PORTED-FILES-local.sha256` over the copies here)
went with the arrangement they served: this repo's own history is the answer to "which revision is
this?" now, and it is a better one than either list ever was.

## Layout — and why the headers are flat

```
include/        32 upstream .h, FLAT + 2 telegram-authored headers   (the PUBLIC module surface)
Internal/        9 upstream *Internal.h, FLAT                       (private to this target)
TextView/       28 upstream .m + 1 telegram-authored anchor impl    (upstream TextView/ + TextView/Autoscroll/)
PrivateUIKit/    9 upstream .m                                      (upstream PrivateUIKit/, minus BehaviorKernel/)
Generated/       1 telegram-authored blob — the pristine contract manifest (deviation 5)
```

**`Internal/` is not tidiness — it is required, and the reason is deviation 6.**

Implementations keep upstream's `TextView/` vs `PrivateUIKit/` grouping. **Headers are deliberately
flattened**, and this is load-bearing rather than cosmetic:

- Every quoted `#import` in all 78 files is a **bare basename** — upstream builds with a flat header
  search path across `TextView/`, `TextView/Autoscroll/` and `PrivateUIKit/`. Three of them cross an
  upstream directory boundary (`IDBlockTextViewInternal.h` → `IDVerticalAutoscrollGeometry.h`,
  `IDUIKitBehaviorBackend.h`, `IDUIKitBehaviorCapabilities.h`).
- With headers flat, **every header→header import resolves sibling-relative**, so no build system
  needs a search path merely to *compile a header*. That matters concretely: SwiftPM propagates a
  target's `publicHeadersPath` directory to dependents and **nothing else** — not its `cSettings`
  header search paths. A nested `include/TextView/` + `include/PrivateUIKit/` layout compiles for the
  target itself and then fails the moment a dependent imports the module.
- There are **no basename collisions** among the 41 headers (checked), so flattening loses nothing.

The `.m` files reach headers through one search path (`includes` in Bazel, `.headerSearchPath` in
SwiftPM). Kernel headers come from the vendored sibling module, which this target depends on.

## Every deviation from a verbatim copy

There were **six** at the port, and only the second and fifth change a line of upstream logic. A seventh, repo-wide, came later (2026-10-12).

**The fidelity check, stated exactly.** Strip the five wrapper lines from each ported file and
`diff` the remainder against its upstream original:

```
byte-identical after stripping the wrapper : 76
differing (recorded deviations)            : IDPrivateUIKit+RichTextLayout.m  IDPrivateUIKit.m
lines only in upstream (REMOVED by us)     : 0  and  0
lines only in port     (ADDED   by us)     : 7  and  17
```

**76 + 2, not "0 differences across all 78"** — an earlier revision of this file said the latter one
sentence after carving out the two deviations, which is the sentence a future reader would have
quoted. The two that differ carry exactly the recorded deviations and nothing else, and both are
**purely additive**: no upstream line is removed or altered in either file.

(Deriving that "purely additive" claim has a trap worth recording, because I fell into it: the
polarity of `diff` decides which marker means "we added". With `diff <upstream> <port>`, our
additions are `>` and a `<` line would mean we deleted upstream code. Reversing the operands
silently reverses the meaning, and the first run of this check reported both files as non-additive
purely because the arguments were the other way round.)

### 1. The `#if TARGET_OS_IOS` wrapper — all 78 files, mechanical

Five lines per file: three prepended, two appended.

```objc
#import <TargetConditionals.h>
#if TARGET_OS_IOS
<blank>
…the file, unchanged…
<blank>
#endif
```

**Why:** this SwiftPM package declares `.macOS(.v10_13)` alongside `.iOS(.v13)`, and 14 of these
files open with `@import UIKit;`. Without the wrapper `swift build` on macOS fails at "module
'UIKit' not found".

**Why exactly this shape:** it is not invented here. It is byte-for-byte what
`InputDec/Scripts/export-behavior-kernel.sh` already applies to every file of the vendored kernel
next door — confirmed by diffing a vendored kernel file against its upstream original, which yields
exactly these five lines and nothing else. Applying the same transform keeps one convention across
both directories.

**Consequence:** on macOS the entire module compiles to nothing. `TextView/RichTextInputDecUpstreamModuleAnchor.m`
(deviation 4) exists to give it a symbol there, mirroring `Host/TGRichTextInputDecModuleAnchor.m`
in the vendored sibling.

### 2. `IDPrivateUIKit.m` — one attribute on one `@interface` line

The only edit to upstream logic in the port, and it changes no behaviour.

```objc
__attribute__((objc_runtime_name("IDUpstreamInteractionABISpec")))
@interface IDInteractionABISpec : NSObject
```

**Why:** the vendored `../RichTextInputDecObjC/Host/TGRichTextInputDecHostPreflight.m` **also**
defines a class called `IDInteractionABISpec` — because `Scripts/carve-host-preflight.sh` carved it
out of this very file. Both objects link into the same binary, so the two would collide as duplicate
`_OBJC_CLASS_$_IDInteractionABISpec` symbols and the link would fail. The carve is vendor-owned and
must not be edited, so the rename has to happen on this side.

**Why an attribute and not a rename:** the class is referenced 48 times in this file. A runtime-name
attribute changes **one** line and leaves the other 47 references byte-identical to upstream, so the
next person diffing this file against upstream sees one hunk rather than forty-eight.

This was the **only** collision. A full pre-scan compared all 45 Objective-C class names and 280
file-scope C identifiers in the port against everything already in `RichTextInputDecObjC`; the C
helpers that share names (`IDInteractionABIMismatch`, `IDInteractionHostABISpecs`, …) are `static`
in both files and therefore file-local. Post-build `nm` over both modules' objects confirms no
duplicate `_OBJC_CLASS_$_` symbols remain (the duplicates it does report are weak/coalesced protocol
records and block helpers, which are legal).

### 3. `IDPrivateUIKit+Testing.h` is here although PORT-PLAN §3.1 excludes it

§3.1's derived set is "everything in both directories except the `IDTextView` single-view host,
`IDPrivateUIKit+Testing.h`, `.gitkeep`, and the already-vendored kernel" = 77 files / 16,464 lines,
which reproduces exactly. But `PrivateUIKit/IDPrivateUIKit.m` **imports** it, so the 77-file set does
not compile. It is 28 lines and §4.2 marks it PORT in the end state anyway, so the exclusion looks
like an artefact of the arithmetic rather than an intent. Result: **78 files, 16,492 lines.**

### 4. Four telegram-authored files that are not upstream at all

| file | why |
| --- | --- |
| `include/RichTextInputDecUpstreamModuleAnchor.h` + `TextView/…ModuleAnchor.m` | one function, `TGRichTextInputDecUpstreamPortedFileCount()`. Deliberately **not** `TARGET_OS_IOS`-wrapped — see deviation 1 — so the module carries a symbol on macOS, where all 78 ported files compile to nothing |
| `include/RichTextInputDecUpstreamPristineManifest.h` + `Generated/…PristineManifest.m` | deviation 5's bytes. The header is Foundation-only on purpose: it is public, and deviation 6 exists because a public header importing a kernel header breaks a dependent's module build |

None contains ported logic. Also telegram-authored: this file.

These four used to be the files the hash list deliberately did not pin, because they were ours to
edit and the 78 were not. Every file in this directory is ours to edit now; the distinction survives
only as a reading aid — a change to one of these four is local work, a change to one of the 78 is a
change to the engine, and the second deserves the more careful commit message.

### 5. The pristine-manifest fallback — one line, at two sites

The only deviation that changes behaviour. It is one line, in the same shape, in two files:

```objc
if (data == nil) { data = TGRichTextInputDecUpstreamPristineContractJSON(); }
```

- `PrivateUIKit/IDPrivateUIKit+RichTextLayout.m`, in `IDPrivateRichInputControllerContract()`
- `PrivateUIKit/IDPrivateUIKit.m`, in `IDProductionContractDictionary()`

**Why it is needed at all.** Both functions read `UIKitBehaviorContracts-iOS26.5.json` as a bundle
**resource**. That resource does not exist anywhere in this tree — the manifest ships compiled in —
so both lookups always return nil, and the two failure modes are opposite and both bad:

- The first `@throw`s. Every smoke test died with *"The input-controller runtime contract resource is
  unavailable"*; the port could not construct an input controller at all.
- The second **fails silently**: it degrades to `@{}`, so `IDRequiredContracts()` is empty and
  `requireCompatibleRuntime` — the first step of `IDBlockTextView`'s reference construction path —
  iterates **zero** contracts across all ten capabilities. It passes because it has nothing to check.
  Every runtime result in this phase was gathered that way until this fallback landed.

**Why at the DATA level.** An earlier revision put the fallback one level higher, on the parsed
manifest object. Moving it down to the bytes means upstream's parse, its error handling and its
`@throw` all still run, unchanged, on upstream's own data — the only thing that changes is where the
bytes came from. Upstream's resource lookup still runs first and still wins wherever the JSON exists.

**Which manifest, and why it is emphatically NOT the one next door.** The bytes are
`../RichTextInputDecObjC/Vendor/UIKitBehaviorContracts-iOS26.5.json`, byte-for-byte upstream's own
file (SHA-256 `a60bb026db345de4c487b45661f97f41e05c1270d1d2c7f5f58d5d92b5440e43`, which is exactly
what `VENDOR.md` records as "pristine manifest SHA-256"), compiled into
`Generated/RichTextInputDecUpstreamPristineManifest.m`.

The obvious-looking alternative — call `TGRichTextInputDecContractManifest()`, which the export
script itself substitutes for this very lookup — is **upstream-sanctioned as a FUNCTION and wrong as
DATA**, and an earlier revision of this port did exactly that. Decoding
`Generated/TGRichTextInputDecContractData.m` and deep-comparing it against the pristine JSON:

```
class rebindings: 50
   47 x IDRichTextLayoutController -> TGRichTextInputDecLayoutController
    3 x IDBlockTextView            -> TGRichTextInputDecCanvasABIWitness
referenceOnly: 53 members upstream -> {} in the generated copy
```

One of those three — `inputController.keyboardDeletePreflight` — sits **inside the exact capability
the input-controller preflight reads**. `IDUIKitCapabilityResolver` resolves each member against its
`className`, so with the transformed data `keyboardInputShouldDelete:` is validated on
`TGRichTextInputDecCanvasABIWitness`, a reconstruction stand-in the ported engine never instantiates.
Both classes happen to implement it, so it **passes — for the wrong reason.** The port ships the real
`IDBlockTextView` and the real `IDRichTextLayoutController`, and those are the classes the gate has
to check.

**What this reverses, deliberately.** Carrying `referenceOnly` re-populates the 53 rows the export
script drops under upstream Global Constraint 12 ("canvas-shaped selectors must not travel"). That
constraint is reversed by user directive for this port, and PORT-PLAN §9.4 names re-populating
`referenceOnly` as one of the two sanctioned ways to close the gap. **Nothing under `Vendor/`,
`Generated/` or `Kernel/` is touched** — the vendored snapshot and its two SHA-256 pins are exactly
as exported, and the kernel keeps reading the transformed manifest, which is correct for the
reconstruction it was generated for.

**Effect, measured.** `compatibilityReport` prints the number of rows it preflighted: **0** before,
**140** after (180 manifest members → 179 contracts once `kind == "protocol"` rows are skipped → 140
with `required == true`). `IDPrivateUIKit.isCompatible` is `YES` on iOS 26.5, so the gate is both
real and green. `test_theRuntimeContractGateActuallyChecksSomething` and
`test_theGateReadsUpstreamsOwnManifestAndNotTheRewrittenOne` pin all of it.

**Regenerating the blob.** Since 2026-10-12 the array stores every byte XOR 0x5A (deviation 7), so
it is regenerated through the encoder rather than copied:

```sh
# from submodules/TelegramUI/Components/RichTextEditor/
src=Sources/RichTextInputDecObjC/Vendor/UIKitBehaviorContracts-iOS26.5.json
shasum -a 256 "$src"     # a60bb026..., 118270 bytes
Scripts/generate-private-runtime-names.py --encode-bytes "$src"   # the array's rows
```

### 6. The nine `*Internal.h` headers are private, not public

No file content changes; they live in `Internal/` rather than `include/`.

**Why:** with all 41 headers in `include/`, SwiftPM builds an umbrella-**directory** module map over
the whole directory, so **every** header there is compiled when a dependent imports the module. That
fails:

```
include/IDBlockTextViewInternal.h:7:9: fatal error: 'IDUIKitBehaviorBackend.h' file not found
module-include.input:1:2: fatal error: could not build module 'RichTextInputDecUpstream'
```

SwiftPM propagates a dependency's `publicHeadersPath` directory and **nothing else** — not its
`cSettings` header search paths — so the kernel include directory that the target compiles its own
sources with is simply absent when a dependent builds the module map.

`IDBlockTextViewInternal.h` is the **only** public header that imports kernel headers (three of them),
and it is an internal header that had no business in the public surface. Moving all nine keeps the
rule simple. Both build systems get `Internal/` as a private search path. Note the sibling module
solves the same problem differently, by spelling its cross-directory imports path-qualified
(`#import "Kernel/IDUIKitRuntimeContract.h"`, `../RichTextInputDecObjC/include/TGRichTextInputDec.h:29-37`)
— that option is not open here, because it would mean editing upstream's import lines.

### 7. Private UIKit names are not spelled in source (2026-10-12)

Not a port deviation: a repo-wide rule applied after the port, to this tree and to
`RichTextInputDecObjC` alike, recorded here because it changes many upstream lines. Every private
UIKit name the engine reaches at run time is spelled through `TGPN_<name>()`
(`RichTextInputDecObjC/include/TGPrivateRuntimeNames.h`, generated from
`Scripts/private-runtime-names.txt`), and every callback UIKit sends to an engine object is compiled
under a neutral `tgpn_` (or existing `id_`) name and added under the private one from `+initialize`
(`TGPrivateMethodAliases.h`). Some of the engine's OWN members whose names collided with a private
UIKit name were renamed `id_…` (for example `id_textInputController`, `id_selectionContainerView`,
`id_scrollContainer`). The package `CLAUDE.md`, "Private UIKit names are not in the binary", has the
rules; `PrivateRuntimeNamesTests` enforces them. So the 76/2 fidelity check above describes the
tree as it was at the port, not this one.

## What did NOT come across, and why

| upstream | files | why not |
| --- | --- | --- |
| `TextView/IDTextView.{h,m}`, `IDTextViewInternal.h`, `IDTextView+{Interaction,TextInput}.m` | 5 / 970 | the single-view **reference** host — one `NSTextLayoutManager` for the whole document, no block model. PORT-PLAN §4.1 NOT-NEEDED. Nothing in the 78 references it (checked) |
| `PrivateUIKit/IDTextView+Private{Callbacks,InputDelegate,InteractionCallbacks}.m` | 3 / 204 | categories on the above; §4.2 marks them PORT for a later phase (they are where obligations C16–C23 come from), but they cannot compile without their class |
| `PrivateUIKit/BehaviorKernel/**`, `PrivateUIKit/Contracts/*.json` | 17 / 6,278 | **already vendored** next door and verified current (PORT-PLAN §4.3: upstream HEAD == the recorded export commit, manifest md5 identical). Reused unchanged; deliberately NOT re-exported |
| `PrivateUIKit/Contracts/.gitkeep` | 1 | placeholder |
| the `.xcresult` RUN RECORDS the authorization fixtures cite | 48 cited | upstream's own TDD audit trail (`…task3-withdrawal-red`, `…task3-withdrawn-green`), written by test runs rather than authored. **22 survive in the `~/Documents/InputDec` archive; 26 exist nowhere at all** — `.xcresult` bundles are transient run output. The fixtures themselves ARE here (`Host/Engine/Tests/Fixtures/`) and their contents are asserted in full; the suites check that each artifact is NAMED, not that it is on disk, because that check was true on one machine at one moment and cannot be satisfied anywhere now. See `IDIsUpstreamRunArtifactPath`. The **Hopper markdown** those fixtures cite alongside them DID come across (`Host/Engine/docs/hopper/`) and keeps its on-disk assertion |

## Known runtime residuals introduced by the port

Recorded here rather than discovered later. **Residual 1 of the first revision — the vacuous runtime
gate — is CLOSED by deviation 5** and is deliberately left described there rather than deleted,
because "the gate was off while we gathered our evidence" is the kind of fact that should stay
findable.

1. **The vendored kernel still preflights hosts against the 3-spec carve, not upstream's 11.**
   `IDUIKitInteractionCapability` / `IDUIKitAutoscrollEntryCapability` call
   `TGRichTextInputDecHostPreflight`, whose spec list was carved at upstream
   `c1517772529a3610f238b5a7caa47ec42b3f1f40` down to 3 portable specs. Now that the full
   `IDPrivateUIKit` is present, the two coexist and the *kernel's* check remains the narrower one.
   `IDBlockTextView` satisfies all 11, so nothing fails — but the kernel is checking less than
   upstream's kernel does. PORT-PLAN §9.5 assigns the decision; it is **not** settled by this port.
   Coexistence was chosen because it is the only option that edits neither a vendor-owned file nor
   upstream source. It is a deferral, not an answer.

2. **`IDBlockTextView`'s `+load` can `@throw` before `main()`, so the port is kept out of the app.**
   It calls `installKeyboardInputSupportOnClass:`, which resolves the private `UIKeyboardInput`
   protocol by name and raises an **uncaught** `NSException` if that or `class_addProtocol` fails
   (`IDPrivateUIKit.m:1413-1425`). Pre-`main` means `TGRichTextInputDecExceptionGuard` cannot wrap it
   and no feature flag can switch it off: a launch-time abort with no telemetry. It is almost
   certainly benign today (`UIKeyboardInput` exists across the app's floor through iOS 26), but
   "almost certainly" is not a basis for shipping it while the port is reachable from nothing.
   **Consequence: `RichTextEditorUIKit` deliberately does not depend on this module in either build
   system** — see the comment in `BUILD`. Revisit when the port is reachable behind
   `ExperimentalUISettings.inputDecTextBackend`, and assess it on a real launch at that point.

3. **No `-warnings-as-errors` on this target**, matching the vendored sibling and unlike most of this
   repo. Deliberate: the alternative to tolerating upstream's warnings is editing verbatim
   third-party source to silence them. The count depends entirely on the deployment target, so it
   only means something with the flag attached:

   ```
   $ bazel build --platforms=@build_bazel_apple_support//platforms:ios_sim_arm64 \
       //submodules/TelegramUI/Components/RichTextEditor:RichTextInputDecUpstream
   2 warnings      (1 -Wnonnull, 1 -Wincompatible-pointer-types — both upstream's own)

   $ …the same, plus --ios_minimum_os=13.0   (this package's declared floor)
   390 warnings    (388 -Wunguarded-availability-new, plus the same 2)
   ```

   The 388 are iOS 17/18/18.4 API used without `@available`, which upstream can do because its own
   floor is higher. Only two warnings are substantive, and both are upstream's.

## What had been verified when the port landed, and what had not

Every number here was produced by a command and copied from its output — **in August 2026, at
phase 1.** It is a snapshot of the port's own acceptance, not a description of today: the module is
on the app graph now, an adapter and an editor drive it, and the hosted suite is nearly 1,300 cases.
Read the two `CLAUDE.md`s for the present. The list is kept because the *traps* in it are still
live and still cost hours when forgotten.

**Verified:**

- **Fidelity: 76 of 78 byte-identical** after stripping the wrapper; the other 2 carry exactly the
  recorded deviations and are purely additive (0 upstream lines removed, +7 and +17). See the block
  under "Every deviation" for the derivation and its polarity trap.
- **The 78 copies were pinned mechanically until 2026-09-15**, by `Scripts/verify-ported-files.sh`
  against `PORTED-FILES-local.sha256`, with a second optional half reporting whether upstream had
  moved. Both halves passed at the moment the port was frozen, which is the last thing either ever
  said. The script and both lists are deleted; the note below is kept because its lesson outlives
  them.

  **A re-port that forgot to refresh the lists left the check FAILING, and nobody noticed.**
  The 2026-08-28 availability-gating re-port updated three ported headers
  (`IDInlineTextFormattingController.h`, `IDNativeSelectionPresentationBackend.h`,
  `IDSelectionPresentation.h`) and did not re-record either list, so from that commit until
  2026-08-30 the script reported FAIL on files that were in fact correct re-ports. That is the
  worst failure mode a tripwire has: it cries wolf about real work, and the next person to see it
  red learns to expect red. **It is also the argument against keeping a hash list over files you
  own** — every legitimate edit is now that re-port, so the list would be red by default and
  re-recorded without reading.

  The stronger invariant the lists only approximated was *port == upstream + wrapper*, checkable
  directly and without anyone having recorded anything. It held at the freeze:

  ```
  port == upstream+wrapper : 76      (all four upstream dirs, incl. TextView/Autoscroll/)
  recorded deviations      :  2      IDPrivateUIKit.m, IDPrivateUIKit+RichTextLayout.m
  ```

  Re-deriving the wrapper for that check is itself worth a control: applying it to files you did
  **not** touch must reproduce their committed bytes exactly (26/26 `.m` files did). Without that,
  a wrapper that is subtly wrong reports your new file as fine and every old one as drifted.
- **Bazel, real iOS simulator:** green.
  `--platforms=@build_bazel_apple_support//platforms:ios_sim_arm64` → a 2,087,312-byte archive with
  `LC_BUILD_VERSION platform 7`, and `_OBJC_CLASS_$_IDUpstreamInteractionABISpec` present.
- **The port is NOT in the app**, by query, with a control proving the query works:

  ```
  $ bazel query 'somepath(//Telegram:Telegram, //…:RichTextInputDecUpstream)'
  INFO: Empty results
  $ bazel query 'somepath(//Telegram:Telegram, //…:RichTextInputDecObjC)'
  //Telegram:Telegram → //Telegram:Lib → //submodules/TelegramUI:TelegramUI
    → …:RichTextEditorUIKit → …:RichTextInputDecObjC
  ```

- **It RUNS, with upstream's runtime gate ON:** `InputDecUpstreamHostSmokeTests`, **8 tests, 8
  passing** on the iOS simulator. `IDBlockTextView` stands up its whole graph, becomes first
  responder, accepts `insertText` / `deleteBackward`, and the document agrees; the gate preflights
  **140** contracts (it preflighted 0 before deviation 5) and reports the runtime compatible.
- Regression spot-check: `RichTextEditorViewTests`, 27 tests, 27 passing.

**Two traps that cost real time here, both of which report success while doing nothing:**

1. **A bare bazel build of this target under `--apple_platform_type=ios --cpu=ios_sim_arm64`
   "succeeds" in 8 seconds and produces a 21 KB archive of 38 EMPTY objects** — `--cpu` no longer
   selects the platform, so everything compiles as macOS, where every ported file is
   `TARGET_OS_IOS`-guarded to nothing. It prints `Build completed successfully`. Always check
   `otool -l … | grep -A3 LC_BUILD_VERSION` (7 = iOS simulator, 1 = macOS).
2. **Adding a NEW header to this module's `include/` does not invalidate Xcode's precompiled clang
   module.** SwiftPM generates an umbrella-*directory* module map, and the cached `.pcm` records only
   the headers that existed when it was built, so Swift keeps reporting `cannot find <symbol> in
   scope` for a function whose declaration is plainly in a header the module map covers. The module
   map on disk looks correct, which is what makes it confusing. Remove the project's DerivedData
   directory and rebuild.

**NOT verified:**

- **The full Bazel app build.** Not run here, and now less load-bearing than it was: the port is off
  the app graph entirely, so an app build can no longer compile it either. The two things that
  *would* have made it evidence — that the module compiles for iOS, and that it links — are covered
  by the standalone bazel build and the test run above.
- **Nothing enforces the exit criterion automatically.** This package has no `ios_unit_test`, so
  `InputDecUpstreamHostSmokeTests` runs only when someone runs `Scripts/iostest.sh`. PORT-PLAN §9.8
  listed standing up an app-hosted test target as an open phase-0 question; `Host/` answered it, and
  that is where the engine's own suites go when they are imported.
- **Anything beyond typing.** Selection geometry, marked text, autocorrect, the temporary-attribute
  rendering path, traits, interaction — all ported, none exercised. PORT-PLAN §10 phases 2-7.
- **Any Telegram integration.** No adapter, no debug screen, no call site: nothing in this tree
  imports this module except the smoke test. `RichTextEditorView` stays `.legacy` and
  `ExperimentalUISettings.inputDecTextBackend` stays `false`.
