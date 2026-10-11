# The engine's own suites, imported from InputDec

**What this is.** InputDec's own tests for the text engine and behaviour kernel this repo vendors,
brought across 2026-09-15 when `~/Documents/InputDec` stopped being a repository and this became the
source of truth for the code.

Run them:

```sh
xcodebuild test -project Host/InputDecHost.xcodeproj -scheme InputDecEngine \
  -destination "platform=iOS Simulator,id=<udid>" -parallel-testing-enabled NO
```

`-parallel-testing-enabled NO` is not optional and not a preference. These suites drive a REAL
keyboard, a shared simulator and, for the parity cases, two apps at once; parallel clones of that
interfere with each other and the results stop meaning anything. `IDProjectSmokeTests`
.testRunnableDocumentationTestCommandsDisableParallelTesting enforces it over this very file — it
caught the first version of this line, which is exactly the point of importing it.

**Their own scheme, deliberately.** `InputDecHost`'s scheme still runs only this repo's own suites
(`Scripts/hostapp.sh test`), whose number is a target: 1,237 cases, 5 known-environmental failures.
This one is a MEASUREMENT, described below, and merging the two would bury that green in red neither
suite owns.

## The numbers, and what they are measured against

**The baseline is upstream's own suite, run in upstream's own project on the same simulator** — that
is what "as good as before the vendor" means, and it is a number rather than an assumption:

```sh
cd ~/Documents/InputDec && xcodebuild test -project InputDec.xcodeproj -scheme InputDec \
  -destination "platform=iOS Simulator,id=<26.5 control>" -only-testing:InputDecTests \
  -parallel-testing-enabled NO
```

| run | executed | failed cases |
| --- | --- | --- |
| upstream, its own project, iOS 26.5 / 23F73 | 1,078 | 6 |
| **here, iOS 26.5 / 23F73** | 1,059 | **6 — the same six** |
| **here, iOS 27.0 / 24A434** | 1,059 | **6 — the same six** |

**Parity.** Every case that fails here fails upstream too: all six are
`…FixtureIsPinnedAndComplete`, upstream's own drift, not ours to fix. The import's deficit went
57 → 0. The 19-case difference in the executed count is retirement, not skipping, and each
retirement is recorded as a comment in the file it was removed from.

**The two runtimes now agree**, which they did not a day ago: iOS 27 stood at 82 failures and the
whole gap was ONE ivar found by offset instead of by name. See "The iOS 27 gap was one constant"
below. **Making the 26.5 control takes seconds**, and it stays the way to tell the runtime from the
code:

```sh
xcrun simctl create ID-control-26.5 "iPhone 16 Pro" com.apple.CoreSimulator.SimRuntime.iOS-26-5
```

## The iOS 27 gap was one constant

`IDPrivateUIKit+TextLayoutCanvas.m` found the layout controller's container-to-canvas map by
scanning its ivars for one at offset **`0x50`**. It reflected — `class_copyIvarList`,
`object_getIvar` — and then threw the reflection away by matching a hardcoded number, which is a
promise about a struct layout Apple never made.

Read off both runtimes with `class_copyIvarList`:

| ivar | iOS 26.5 / 23F73 | iOS 27.0 / 24A434 |
| --- | --- | --- |
| `_textCanvasViews` (`NSMapTable`) | **+0x50** | **+0x58** |
| what is at +0x50 on 27 | — | `_invisibleRanges`, an `NSMutableSet` |

`_UITextLayoutControllerBase` gained `_textOriginOverride` at `+0x10` on 27 and every later ivar
moved down eight bytes. So the scan handed back a SET, the contract check refused it — correctly —
and the engine could not register a canvas at all. That is the whole of
`Canvas map at _UITextKit2LayoutController +0x50 failed`, and it was **76 of the 82** iOS 27
failures.

The fix is `class_getInstanceVariable(cls, "_textCanvasViews")`: a name is what the Objective-C
runtime guarantees to carry, it survives a re-layout, and the lookup already walks the superclass
chain. The offset is still read — by `object_getIvar`, from the ivar the runtime resolved — which is
the difference between using reflection and hardcoding the answer reflection would have given.

**The contract checks stay and are the real guard.** A name can be renamed as easily as a layout can
shift; what makes either safe to discover is refusing anything that does not answer
`setObject:forKey:` and `objectForKey:` — which turns a silent write to the wrong object into a loud
refusal at construction. That is exactly what happened here: the engine did not corrupt a set, it
declined to start.

It was the only hardcoded offset in the tree. Every other `ivar_getOffset` call resolves its ivar by
name first and then asks where it lives, which is correct use.

## Closing the 57: all layout, and two real defects — both mine

Every one of the 57 passed upstream, so none of them was the engine. Most were resolution:
`IDEngineSourceLayout` translates upstream-relative paths onto this layout (flat headers, the kernel
as its own module, `TextView/Autoscroll/` flattened, `App/` and `Tests/` beside the suites, and the
project description — this repo's equivalent of a checked-in `project.pbxproj` is
`Host/project.yml`). Data moved the other way, under `Host/Engine/` where `__FILE__`'s grandparent
already pointed. The test host became upstream's own demo app.

**Two were defects rather than paths:**

- Five shared support files were COPIED into `Tests/` to make the bundle compile.
  `testPrivateXCTestHIDABIInvocationsStayInSharedTestSupport` requires the private XCTest HID ABI to
  live in exactly ONE sanctioned file, so that duplicate was a real violation of a real rule. They
  are referenced from `UITests/` now — one copy, as upstream does it.
- `testRunnableDocumentationTestCommandsDisableParallelTesting` caught THIS FILE: the command at the
  top of it did not pass `-parallel-testing-enabled NO`. An imported rule finding a defect in our own
  documentation on its first day is the best argument for having imported it.

## What was retired (19), and what was deliberately kept

Importing a suite wholesale imports its assumptions. The test applied to every case was **"could
this fail for any change made in this repository?"**

- **13 whose subject is upstream's REPOSITORY** — certification and stock-truth runners, matrix
  drivers, keyboard provisioning, "registered in both test targets", the exported UTI pair. **Eleven
  were PASSING**, green against a carried copy of a project nothing here builds. A test that cannot
  fail is not coverage; it is a tick that reads as coverage, which is worse than the red beside it.
- **4 ownership audits that INVENTORY a layout this port deliberately restructured** — 55
  implementations and 56 headers against a walk that finds 43 and 4. Not adapted, because deriving
  the on-disk set from the manifest makes them pass while checking nothing: agreement between those
  two IS the assertion. An honest adaptation re-authors both in this repo's vocabulary, which is a
  new rule worth writing — "no file enters the vendored engine unclassified" — not a path fix.
- **1 auditing a `.superpowers/` subagent scratch report**, a file this repo's rules forbid
  committing, so the rule can never hold here.
- **1 for a real BEHAVIOURAL difference**, and it is the valuable one:
  `testEveryOptionalCapabilityHasUnavailableAndRejectedFallback` expects `autoscrollEntry` to be
  REJECTED, which upstream gets from a `referenceOnly` contract row — and the vendored kernel empties
  `referenceOnly` by design. Verified rather than assumed: that capability is in the pristine
  manifest's `referenceOnly`, and the shipped contract data contains the string zero times. The
  transform was documented as ABI-preserving, which it is. **This is its behavioural consequence, and
  it is in `VENDOR.md` now because these tests found it.**

**Nearly lost: 19 real code rules.** A first, blunter sweep classified by "does the body mention a
repo path anywhere" and retired 32. Nineteen of those audit the engine's production graph and merely
list one repo path among 40-100 engine paths —
`testProjectCanvasStateGetterImplementationsRemain` asserts `IDTextLayoutCanvasView.m` still defines
`- (BOOL)id_isEditable`. **Classify by the paths a case READS, never by what its text mentions.**

**Kept: `IDTextView`'s suites**, although Telegram ships no `IDTextView`. It shares the private-UIKit
interaction layer with the block engine, so they are a second witness on code we do ship — and they
are the most sensitive detector of the iOS 27 drift.

**Kept for now: the four duplicated parity suites.** Once the engine scheme is part of the routine
loop the Swift adaptations in the package become the redundant pair; that is the moment to retire
them.

## One defect fixed on the way in

`IDTextCanvasAttachmentCoordinatorTests.testAttachmentSetDiffNotifiesAddThenRemoveExactlyOnce` took
`[events indexOfObject:@"add"]`, asserted it was not `NSNotFound`, and then looped up to it. An
Objective-C `XCTAssert` does not leave the method, so when no "add" arrived the loop ran
`NSUIntegerMax` times: on the certified runtime it spun past **3.3 million iterations and a
3.3-million-line log**, taking the entire target's run with it. One `return` after the assertion
turns that into the clean failure it had already reported. It is the only instance of the pattern in
the imported files — checked, not assumed.

## What is here

```
Tests/            the unit suites, their support, Fixtures/, TextInputDifferential/,
                  and IDEngineSourceLayout.{h,m} — the one adaptation, described above
App/              upstream's demo app — the TEST HOST (target InputDecEngineApp)
StockOracleHost/  a stock UITextView in an app of its own (target InputDecStockOracleHost),
                  which the parity suites drive beside the engine and compare
Sources/          8 files — IDTextView, upstream's OTHER editor (compiled into the APP target)
TestFixtures/     scenario corpora the differential suites load
PrivateUIKit/     Contracts/ — the runtime ABI inventory IDPrivateUIKitTests checks against
Scripts/          upstream's 40+ runners and provisioning scripts — CARRIED, NOT WIRED
UITests/          196 cases — CARRIED, NOT WIRED (no target yet)
docs/             upstream's own design record, 156 files
Config/           upstream's own Info.plists, kept because its smoke suite reads them
project.yml       UPSTREAM's project description, carried as DATA — IDProjectSmokeTests reads it.
                  It is not built by anything here; this project is Host/project.yml
UPSTREAM-README.md, AGENTS.md   upstream's own, kept under their own names
```

**Carried, not wired** means the bytes are safe here but nothing runs them: `UITests/` has no target
and the scripts have never been run against this layout. That is deliberate — they are the only copy
and losing them was the risk worth closing first.

`IDTextView` is a sibling of the block engine, not part of it, and nothing in Telegram uses it — but
several engine suites drive it alongside the block view, so its 8 files come along. They are
compiled into the imported APP target (the demo view controller drives them) and deliberately not
into `Sources/RichTextInputDecUpstream/`: there they would land in Telegram's binary with no
consumer. That
also corrects the spec's original estimate, which put group C's cost at ~26 files; the real figure
is 8, because `IDTextCanvas*`, `IDTextLayoutCanvasView` and `IDTextRenderingSurfaceView` were
already vendored.

## Not here yet

- **iOS 27 certification.** This is the next piece of work and the suite now exists to drive it: a
  green 26.5 baseline, an 82-case gap on 27, and a mechanism already named. `Scripts/` is carried
  for exactly this — the stock-truth runners and keyboard provisioning are how a new OS band gets
  certified.
- A target for `UITests/` (196 cases). Both apps it needs now exist, so this is wiring rather than
  porting.
- The "no file enters the vendored engine unclassified" rule, if we want it: the four retired
  ownership audits are the shape to copy, re-authored against this repo's own layout.

**`~/Documents/InputDec` is now fully copied into this repo** — source, tests, UI tests, fixtures,
scripts and docs. Nothing of it exists only there any more.
