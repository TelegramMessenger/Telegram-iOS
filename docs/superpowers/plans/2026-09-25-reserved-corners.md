# Reserved Corners in ContainerViewLayout — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Carry the iPhone Duo's per-corner reserved blocks and fold in `ContainerViewLayout`, then stop widening a corner block into a full-edge safe inset on iPhone Duo.

**Architecture:** A pure function in Display turns the window's system safe insets plus the active `.occlusion` rects from `UIView.reservedRegions(kind:)` (iOS 27.1) into corner-free safe insets plus four corner sizes. The window layer reads the regions on multi-display devices only, stores them in `WindowLayout`, and hands them to `ContainerViewLayout` as two new required fields that every derived layout must forward, split, or zero explicitly.

**Tech Stack:** Swift, UIKit, AsyncDisplayKit, Bazel (`Make.py`), XCTest via `ios_unit_test`.

**Spec:** `docs/superpowers/specs/2026-09-25-reserved-corners-design.md` — read it first; its measurement table is the source of every number in the tests below.

## Global Constraints

- Everything new is gated on `DeviceMetrics.hasMultipleDisplays` (iPhone19,4). Every other device must keep `reservedCorners == .zero`, `division == nil`, and its current safe insets.
- `reservedRegions(kind:)` is iOS 27.1+: call it only behind `#available(iOS 27.1, *)`; earlier systems report no regions.
- Only **active** regions are used (`region.isActive`); inactive ones (the inner camera) are ignored.
- The new `ContainerViewLayout` initializer parameters `reservedCorners:` and `division:` have **no default value**.
- Tolerance for "touches an edge" is 0.5pt.
- Bottom safe inset is never changed by this work (it is the on-screen navigation height path).
- Display builds with `-warnings-as-errors`: no unused variables, no always-true casts.
- Build = full `Make.py build` (no per-module build). Run it from the controller session in the background and read Bazel's own exit status; do not append `; echo $?`.
- Never install to a simulator yourself. Hand the build to the user; they install it and drive fold/rotation on the "Duo Probe" / iPhone Duo simulator.
- Commit after each task. Never push.

## Review Focus

1. **A region change with no safe-area change** (mid-unfold the corner block became 134x82 with identical insets): the window must still pick it up. Covered by Task 4's layout-pass trigger; verified in Task 4 Step 6 by watching the log while the user folds.
2. **Re-reading in `layoutSubviews` must converge**, not re-dirty layout forever. `updateLayout` already drops an equal update; Task 4 Step 6 checks that the log prints only on change, not every frame.
3. **A derived layout silently dropping the corners.** Prevented by required parameters; Task 3 classifies every site and the reviewer checks the classification table against the diff.
4. **An inset only partly explained by a corner block** (closed landscape-right: 84pt inset, 82pt block). Pinned by `test_closedLandscapeRight_blockNarrowerThanInset_cornerTakesInset` in Task 1.
5. **An edge reserved in both corners, or by a full-edge rect**, must keep its inset. Pinned by `test_blocksInBothCornersOfEdge_insetKept` and `test_rectSpanningWholeEdge_insetKept` in Task 1.

---

### Task 1: Corner types, `resolveReservedArea`, and the Display test target

**Files:**
- Create: `submodules/Display/Source/ReservedArea.swift`
- Create: `submodules/Display/Tests/ReservedAreaTests.swift`
- Modify: `submodules/Display/BUILD`

**Interfaces:**
- Produces:
  - `public struct ContainerViewLayoutCorners: Equatable { topLeft, topRight, bottomLeft, bottomRight: CGSize; static let zero; var bottomOnly: ContainerViewLayoutCorners }`
  - `struct ReservedAreaResolution: Equatable { var safeInsets: UIEdgeInsets; var reservedCorners: ContainerViewLayoutCorners }`
  - `func resolveReservedArea(size: CGSize, systemSafeInsets: UIEdgeInsets, occlusions: [CGRect]) -> ReservedAreaResolution`

- [ ] **Step 1: Add the test target to `submodules/Display/BUILD`**

Replace the file with (the `Display` library is unchanged; its glob is `Source/**` so `Tests/` is not compiled into it):

```python
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "Display",
    module_name = "Display",
    srcs = glob([
        "Source/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
    	"//submodules/ObjCRuntimeUtils:ObjCRuntimeUtils",
    	"//submodules/UIKitRuntimeUtils:UIKitRuntimeUtils",
        "//submodules/AppBundle:AppBundle",
    	"//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Markdown:Markdown",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "DisplayTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":Display",
    ],
)

# The runner MUST pin a real device/OS: the default runner picks an invalid
# device and the test process exits 15.
ios_test_runner(
    name = "DisplayTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "DisplayTests",
    minimum_os_version = "15.0",
    runner = ":DisplayTestRunner",
    deps = [
        ":DisplayTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
```

- [ ] **Step 2: Write the failing tests**

`submodules/Display/Tests/ReservedAreaTests.swift` (every size and rect is from the spec's measurement table):

```swift
import XCTest
import UIKit
@testable import Display

final class ReservedAreaTests: XCTestCase {
    private func insets(_ top: CGFloat, _ left: CGFloat, _ bottom: CGFloat, _ right: CGFloat) -> UIEdgeInsets {
        return UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
    }

    private func corners(topLeft: CGSize = .zero, topRight: CGSize = .zero, bottomLeft: CGSize = .zero, bottomRight: CGSize = .zero) -> ContainerViewLayoutCorners {
        return ContainerViewLayoutCorners(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight)
    }

    func test_openLandscape_statusCornerMovesRightInsetIntoTopRight() {
        let result = resolveReservedArea(size: CGSize(width: 951.0, height: 669.0), systemSafeInsets: insets(0, 0, 0, 84), occlusions: [CGRect(x: 867.0, y: 0.0, width: 84.0, height: 120.0)])
        XCTAssertEqual(result, ReservedAreaResolution(safeInsets: insets(0, 0, 0, 0), reservedCorners: corners(topRight: CGSize(width: 84.0, height: 120.0))))
    }

    func test_openPortrait_bottomRightBlockLeavesInsetsUnchanged() {
        let result = resolveReservedArea(size: CGSize(width: 669.0, height: 951.0), systemSafeInsets: insets(82, 0, 0, 0), occlusions: [CGRect(x: 587.0, y: 817.0, width: 82.0, height: 134.0)])
        XCTAssertEqual(result, ReservedAreaResolution(safeInsets: insets(82, 0, 0, 0), reservedCorners: corners(bottomRight: CGSize(width: 82.0, height: 134.0))))
    }

    func test_closedPortrait_cameraInsideStatusBlockAddsNothing() {
        let result = resolveReservedArea(size: CGSize(width: 466.0, height: 678.0), systemSafeInsets: insets(0, 0, 0, 84), occlusions: [
            CGRect(x: 399.0 + 2.0 / 3.0, y: 29.0 + 1.0 / 3.0, width: 37.0, height: 37.0),
            CGRect(x: 382.0, y: 0.0, width: 84.0, height: 170.0)
        ])
        XCTAssertEqual(result, ReservedAreaResolution(safeInsets: insets(0, 0, 0, 0), reservedCorners: corners(topRight: CGSize(width: 84.0, height: 170.0))))
    }

    func test_closedLandscapeLeft_bottomRightBlock() {
        let result = resolveReservedArea(size: CGSize(width: 678.0, height: 466.0), systemSafeInsets: insets(0, 0, 0, 84), occlusions: [
            CGRect(x: 611.0 + 2.0 / 3.0, y: 399.0 + 2.0 / 3.0, width: 37.0, height: 37.0),
            CGRect(x: 594.0, y: 384.0, width: 84.0, height: 82.0)
        ])
        XCTAssertEqual(result, ReservedAreaResolution(safeInsets: insets(0, 0, 0, 0), reservedCorners: corners(bottomRight: CGSize(width: 84.0, height: 82.0))))
    }

    func test_closedLandscapeRight_blockNarrowerThanInset_cornerTakesInset() {
        let result = resolveReservedArea(size: CGSize(width: 678.0, height: 466.0), systemSafeInsets: insets(0, 84, 0, 0), occlusions: [
            CGRect(x: 29.0 + 1.0 / 3.0, y: 29.0 + 1.0 / 3.0, width: 37.0, height: 37.0),
            CGRect(x: 0.0, y: 0.0, width: 82.0, height: 84.0)
        ])
        XCTAssertEqual(result, ReservedAreaResolution(safeInsets: insets(0, 0, 0, 0), reservedCorners: corners(topLeft: CGSize(width: 84.0, height: 84.0))))
    }

    func test_noOcclusions_insetsUnchanged() {
        let result = resolveReservedArea(size: CGSize(width: 951.0, height: 669.0), systemSafeInsets: insets(82, 0, 0, 0), occlusions: [])
        XCTAssertEqual(result, ReservedAreaResolution(safeInsets: insets(82, 0, 0, 0), reservedCorners: .zero))
    }

    func test_rectTouchingOneEdgeOnly_ignored() {
        let result = resolveReservedArea(size: CGSize(width: 951.0, height: 669.0), systemSafeInsets: insets(0, 0, 0, 84), occlusions: [CGRect(x: 677.0, y: 0.0, width: 58.0, height: 37.0)])
        XCTAssertEqual(result, ReservedAreaResolution(safeInsets: insets(0, 0, 0, 84), reservedCorners: .zero))
    }

    func test_twoRectsInOneCorner_takeLargestExtentPerAxis() {
        let result = resolveReservedArea(size: CGSize(width: 951.0, height: 669.0), systemSafeInsets: insets(0, 0, 0, 84), occlusions: [
            CGRect(x: 867.0, y: 0.0, width: 84.0, height: 120.0),
            CGRect(x: 900.0, y: 0.0, width: 51.0, height: 150.0)
        ])
        XCTAssertEqual(result, ReservedAreaResolution(safeInsets: insets(0, 0, 0, 0), reservedCorners: corners(topRight: CGSize(width: 84.0, height: 150.0))))
    }

    func test_rectSpanningWholeEdge_insetKept() {
        let result = resolveReservedArea(size: CGSize(width: 951.0, height: 669.0), systemSafeInsets: insets(0, 0, 0, 84), occlusions: [CGRect(x: 867.0, y: 0.0, width: 84.0, height: 669.0)])
        XCTAssertEqual(result.safeInsets, insets(0, 0, 0, 84))
    }

    func test_blocksInBothCornersOfEdge_insetKept() {
        let result = resolveReservedArea(size: CGSize(width: 951.0, height: 669.0), systemSafeInsets: insets(0, 0, 0, 84), occlusions: [
            CGRect(x: 867.0, y: 0.0, width: 84.0, height: 120.0),
            CGRect(x: 867.0, y: 549.0, width: 84.0, height: 120.0)
        ])
        XCTAssertEqual(result, ReservedAreaResolution(safeInsets: insets(0, 0, 0, 84), reservedCorners: corners(topRight: CGSize(width: 84.0, height: 120.0), bottomRight: CGSize(width: 84.0, height: 120.0))))
    }

    func test_bottomInsetNeverChanged() {
        let result = resolveReservedArea(size: CGSize(width: 669.0, height: 951.0), systemSafeInsets: insets(0, 0, 34, 0), occlusions: [CGRect(x: 587.0, y: 817.0, width: 82.0, height: 134.0)])
        XCTAssertEqual(result.safeInsets, insets(0, 0, 34, 0))
    }

    func test_bottomOnly_dropsTopCorners() {
        let value = corners(topLeft: CGSize(width: 1.0, height: 2.0), topRight: CGSize(width: 3.0, height: 4.0), bottomLeft: CGSize(width: 5.0, height: 6.0), bottomRight: CGSize(width: 7.0, height: 8.0))
        XCTAssertEqual(value.bottomOnly, corners(bottomLeft: CGSize(width: 5.0, height: 6.0), bottomRight: CGSize(width: 7.0, height: 8.0)))
    }
}
```

- [ ] **Step 3: Run the tests to verify they fail**

```sh
source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion --cacheDir ~/telegram-bazel-cache \
 test --configurationPath build-system/appstore-configuration.json \
 --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git \
 --gitCodesigningType development --gitCodesigningUseCurrent --target //submodules/Display:DisplayTests
```

Expected: compile failure, `cannot find 'resolveReservedArea' in scope` / `cannot find type 'ContainerViewLayoutCorners'`.

- [ ] **Step 4: Implement `submodules/Display/Source/ReservedArea.swift`**

```swift
import UIKit

/// The size of the block the system reserves in each corner of a layout, measured from that corner.
/// Zero means the corner is free. See `resolveReservedArea`.
public struct ContainerViewLayoutCorners: Equatable {
    public var topLeft: CGSize
    public var topRight: CGSize
    public var bottomLeft: CGSize
    public var bottomRight: CGSize

    public init(topLeft: CGSize, topRight: CGSize, bottomLeft: CGSize, bottomRight: CGSize) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }

    public static let zero = ContainerViewLayoutCorners(topLeft: .zero, topRight: .zero, bottomLeft: .zero, bottomRight: .zero)

    /// For a layout whose top edge is not the screen's top edge (a sheet below the status bar).
    public var bottomOnly: ContainerViewLayoutCorners {
        return ContainerViewLayoutCorners(topLeft: .zero, topRight: .zero, bottomLeft: self.bottomLeft, bottomRight: self.bottomRight)
    }
}

struct ReservedAreaResolution: Equatable {
    var safeInsets: UIEdgeInsets
    var reservedCorners: ContainerViewLayoutCorners
}

private let reservedAreaEdgeTolerance: CGFloat = 0.5

private func maxSize(_ lhs: CGSize, _ rhs: CGSize) -> CGSize {
    return CGSize(width: max(lhs.width, rhs.width), height: max(lhs.height, rhs.height))
}

/// Splits the system's safe insets into what is reserved along a whole edge and what is reserved in
/// a corner.
///
/// UIKit widens a corner block (iPhone Duo's status corner) into a full-edge `safeAreaInsets`
/// inset. `occlusions` are the active `.occlusion` reserved regions in the layout's coordinates.
/// A rect that touches two edges is a corner block, sized from its corner. An edge inset is moved
/// into a corner when that edge has exactly one corner block and the block does not span the edge;
/// the corner then keeps `max(block, inset)`, so no reserved space is lost. The bottom inset is
/// never changed: it is the on-screen navigation height, carried separately.
func resolveReservedArea(size: CGSize, systemSafeInsets: UIEdgeInsets, occlusions: [CGRect]) -> ReservedAreaResolution {
    let tolerance = reservedAreaEdgeTolerance
    var corners = ContainerViewLayoutCorners.zero
    for rect in occlusions {
        let touchesLeft = rect.minX <= tolerance
        let touchesRight = rect.maxX >= size.width - tolerance
        let touchesTop = rect.minY <= tolerance
        let touchesBottom = rect.maxY >= size.height - tolerance
        let fromLeft = rect.maxX
        let fromRight = size.width - rect.minX
        let fromTop = rect.maxY
        let fromBottom = size.height - rect.minY
        if touchesTop && touchesLeft {
            corners.topLeft = maxSize(corners.topLeft, CGSize(width: fromLeft, height: fromTop))
        }
        if touchesTop && touchesRight {
            corners.topRight = maxSize(corners.topRight, CGSize(width: fromRight, height: fromTop))
        }
        if touchesBottom && touchesLeft {
            corners.bottomLeft = maxSize(corners.bottomLeft, CGSize(width: fromLeft, height: fromBottom))
        }
        if touchesBottom && touchesRight {
            corners.bottomRight = maxSize(corners.bottomRight, CGSize(width: fromRight, height: fromBottom))
        }
    }

    var safeInsets = systemSafeInsets

    // Right edge: blocks in topRight / bottomRight; perpendicular extent is the width.
    if safeInsets.right > 0.0 {
        let top = corners.topRight != .zero
        let bottom = corners.bottomRight != .zero
        if top != bottom {
            if top, corners.topRight.height < size.height - tolerance {
                corners.topRight.width = max(corners.topRight.width, safeInsets.right)
                safeInsets.right = 0.0
            } else if bottom, corners.bottomRight.height < size.height - tolerance {
                corners.bottomRight.width = max(corners.bottomRight.width, safeInsets.right)
                safeInsets.right = 0.0
            }
        }
    }
    // Left edge.
    if safeInsets.left > 0.0 {
        let top = corners.topLeft != .zero
        let bottom = corners.bottomLeft != .zero
        if top != bottom {
            if top, corners.topLeft.height < size.height - tolerance {
                corners.topLeft.width = max(corners.topLeft.width, safeInsets.left)
                safeInsets.left = 0.0
            } else if bottom, corners.bottomLeft.height < size.height - tolerance {
                corners.bottomLeft.width = max(corners.bottomLeft.width, safeInsets.left)
                safeInsets.left = 0.0
            }
        }
    }
    // Top edge: blocks in topLeft / topRight; perpendicular extent is the height.
    if safeInsets.top > 0.0 {
        let left = corners.topLeft != .zero
        let right = corners.topRight != .zero
        if left != right {
            if left, corners.topLeft.width < size.width - tolerance {
                corners.topLeft.height = max(corners.topLeft.height, safeInsets.top)
                safeInsets.top = 0.0
            } else if right, corners.topRight.width < size.width - tolerance {
                corners.topRight.height = max(corners.topRight.height, safeInsets.top)
                safeInsets.top = 0.0
            }
        }
    }

    return ReservedAreaResolution(safeInsets: safeInsets, reservedCorners: corners)
}
```

Note on `test_rectSpanningWholeEdge_insetKept`: an 84x669 rect touches top, bottom and right, so it lands in both `topRight` and `bottomRight`; the right edge then has blocks in both corners and rule 3 keeps the inset.

- [ ] **Step 5: Run the tests to verify they pass**

Same command as Step 3. Expected: `Executed 12 tests, with 0 failures`. Confirm `test_closedLandscapeRight_blockNarrowerThanInset_cornerTakesInset` appears as `started` in the output (a bundle that fails to compile can still print another scheme's "0 failures").

- [ ] **Step 6: Commit**

```bash
git add submodules/Display/BUILD submodules/Display/Source/ReservedArea.swift submodules/Display/Tests/ReservedAreaTests.swift
git commit -m "feat(display): resolve corner-reserved areas from system insets and occlusion regions"
```

---

### Task 2: Pane assignment helper

**Files:**
- Modify: `submodules/Display/Source/ReservedArea.swift`
- Modify: `submodules/Display/Tests/ReservedAreaTests.swift`

**Interfaces:**
- Consumes: `ContainerViewLayoutCorners` (Task 1).
- Produces: `func reservedAreaForPane(corners: ContainerViewLayoutCorners, division: CGRect?, paneFrame: CGRect, containerSize: CGSize) -> (corners: ContainerViewLayoutCorners, division: CGRect?)`

- [ ] **Step 1: Write the failing tests** (append to `ReservedAreaTests`)

```swift
    func test_pane_masterKeepsOnlyLeftCorners_andDropsDivisionItDoesNotCross() {
        let result = reservedAreaForPane(corners: corners(topLeft: CGSize(width: 10.0, height: 10.0), topRight: CGSize(width: 84.0, height: 120.0)), division: CGRect(x: 455.5, y: 0.0, width: 40.0, height: 669.0), paneFrame: CGRect(x: 0.0, y: 0.0, width: 320.0, height: 669.0), containerSize: CGSize(width: 951.0, height: 669.0))
        XCTAssertEqual(result.corners, corners(topLeft: CGSize(width: 10.0, height: 10.0)))
        XCTAssertNil(result.division)
    }

    func test_pane_detailKeepsRightCorners_andTranslatesDivision() {
        let result = reservedAreaForPane(corners: corners(topLeft: CGSize(width: 10.0, height: 10.0), topRight: CGSize(width: 84.0, height: 120.0)), division: CGRect(x: 455.5, y: 0.0, width: 40.0, height: 669.0), paneFrame: CGRect(x: 320.0, y: 0.0, width: 631.0, height: 669.0), containerSize: CGSize(width: 951.0, height: 669.0))
        XCTAssertEqual(result.corners, corners(topRight: CGSize(width: 84.0, height: 120.0)))
        XCTAssertEqual(result.division, CGRect(x: 135.5, y: 0.0, width: 40.0, height: 669.0))
    }

    func test_pane_fullFrameKeepsEverything() {
        let all = corners(topLeft: CGSize(width: 1.0, height: 1.0), topRight: CGSize(width: 2.0, height: 2.0), bottomLeft: CGSize(width: 3.0, height: 3.0), bottomRight: CGSize(width: 4.0, height: 4.0))
        let result = reservedAreaForPane(corners: all, division: nil, paneFrame: CGRect(x: 0.0, y: 0.0, width: 951.0, height: 669.0), containerSize: CGSize(width: 951.0, height: 669.0))
        XCTAssertEqual(result.corners, all)
        XCTAssertNil(result.division)
    }
```

- [ ] **Step 2: Run to verify failure**

Same `Make.py test --target //submodules/Display:DisplayTests` command. Expected: `cannot find 'reservedAreaForPane' in scope`.

- [ ] **Step 3: Implement** (append to `ReservedArea.swift`)

```swift
/// The part of a layout's reserved area that belongs to a pane at `paneFrame` inside it: a corner is
/// kept only when the pane reaches that corner of the container, and the division is translated
/// into the pane's coordinates and dropped when it does not cross the pane.
func reservedAreaForPane(corners: ContainerViewLayoutCorners, division: CGRect?, paneFrame: CGRect, containerSize: CGSize) -> (corners: ContainerViewLayoutCorners, division: CGRect?) {
    let tolerance = reservedAreaEdgeTolerance
    let reachesLeft = paneFrame.minX <= tolerance
    let reachesRight = paneFrame.maxX >= containerSize.width - tolerance
    let reachesTop = paneFrame.minY <= tolerance
    let reachesBottom = paneFrame.maxY >= containerSize.height - tolerance

    let paneCorners = ContainerViewLayoutCorners(
        topLeft: reachesTop && reachesLeft ? corners.topLeft : .zero,
        topRight: reachesTop && reachesRight ? corners.topRight : .zero,
        bottomLeft: reachesBottom && reachesLeft ? corners.bottomLeft : .zero,
        bottomRight: reachesBottom && reachesRight ? corners.bottomRight : .zero
    )

    var paneDivision: CGRect?
    if let division {
        let translated = division.offsetBy(dx: -paneFrame.minX, dy: -paneFrame.minY)
        if translated.intersects(CGRect(origin: .zero, size: paneFrame.size)) {
            paneDivision = translated
        }
    }
    return (paneCorners, paneDivision)
}
```

- [ ] **Step 4: Run to verify pass.** Expected: `Executed 15 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add submodules/Display/Source/ReservedArea.swift submodules/Display/Tests/ReservedAreaTests.swift
git commit -m "feat(display): assign reserved corners and the fold to a pane"
```

---

### Task 3: `ContainerViewLayout` fields and every construction site

**Files:**
- Modify: `submodules/Display/Source/ContainerViewLayout.swift`
- Modify: `submodules/Display/Source/Navigation/NavigationSplitContainer.swift:98-106`
- Modify: every `ContainerViewLayout(` construction site (list and rules below)

**Interfaces:**
- Consumes: `ContainerViewLayoutCorners`, `.bottomOnly`, `reservedAreaForPane` (Tasks 1–2).
- Produces: `ContainerViewLayout.reservedCorners: ContainerViewLayoutCorners`, `ContainerViewLayout.division: CGRect?`; initializer `ContainerViewLayout(size:metrics:deviceMetrics:intrinsicInsets:safeInsets:reservedCorners:division:additionalInsets:statusBarHeight:inputHeight:inputHeightIsInteractivellyChanging:inVoiceOver:presentedInFormSheet:)`.

- [ ] **Step 1: Add the fields in `ContainerViewLayout.swift`**

Add after `public var safeInsets: UIEdgeInsets`:

```swift
    /// The block reserved in each corner (iPhone Duo's status corner), in this layout's coordinates.
    /// `safeInsets` does not include it. Zero on every device without such blocks.
    public var reservedCorners: ContainerViewLayoutCorners
    /// The fold while the system reports it active, including its margins, in this layout's
    /// coordinates. Nil when there is none or it does not cross this layout.
    public var division: CGRect?
```

Change the initializer signature to insert `reservedCorners: ContainerViewLayoutCorners, division: CGRect?,` right after `safeInsets: UIEdgeInsets,` (no defaults), and assign both in the body. In the seven helpers (`addedInsets`, `withUpdatedSize`, `withUpdatedIntrinsicInsets`, `withUpdatedSafeInsets`, `withUpdatedAdditionalInsets`, `withUpdatedInputHeight`, `withUpdatedMetrics`) insert `reservedCorners: self.reservedCorners, division: self.division,` after each `safeInsets:` argument.

- [ ] **Step 2: Update `NavigationSplitContainer`**

Replace the two `update(layout:)` calls (after the existing `masterSafeInsets` / `detailSafeInsets` lines) so each pane gets its own part:

```swift
        let masterReserved = reservedAreaForPane(corners: layout.reservedCorners, division: layout.division, paneFrame: CGRect(x: 0.0, y: 0.0, width: masterWidth, height: layout.size.height), containerSize: layout.size)
        let detailReserved = reservedAreaForPane(corners: layout.reservedCorners, division: layout.division, paneFrame: CGRect(x: masterWidth, y: 0.0, width: detailWidth, height: layout.size.height), containerSize: layout.size)
```

and pass `reservedCorners: masterReserved.corners, division: masterReserved.division,` / `reservedCorners: detailReserved.corners, division: detailReserved.division,` after the respective `safeInsets:` arguments.

- [ ] **Step 3: Update every other construction site**

Find them all (single- and multi-line):

```sh
grep -rn --include='*.swift' -E "ContainerViewLayout\((size:|$)" submodules Telegram | grep -v '/.claude/'
```

Insert the two arguments right after each site's `safeInsets:` argument, choosing by this rule — **do to the corners what the site already does to `safeInsets`**:

| Site's `safeInsets` argument | `reservedCorners:` | `division:` |
|---|---|---|
| `layout.safeInsets`, `self.safeInsets`, or a local copied from it (same frame) | `layout.reservedCorners` | `layout.division` |
| Parent insets with `top: 0.0` (sheet below the status bar) | `layout.reservedCorners.bottomOnly` | `nil` |
| `UIEdgeInsets()`, `.zero`, or custom values not taken from a parent `ContainerViewLayout` (including component-environment layouts built from `environment.safeInsets`) | `.zero` | `nil` |
| `WindowContent.swift` `containedLayoutForWindowLayout` | handled in Task 4; for now `.zero` | `nil` |

Classification of the single-line sites (the multi-line ones are component screens building from `environment`, which are all row 3 unless they have a `ContainerViewLayout` named `layout` in scope, then row 1):

| Site | Row |
|---|---|
| HashtagSearchControllerNode.swift:595, 608, 624, 724 | 1 |
| InstantPageSlideshowItemNode.swift:437 | 3 |
| ContactsControllerNode.swift:439 | 1 |
| AttachmentContainer.swift:600 | 2 |
| AttachmentContainer.swift:623 | 3 |
| AvatarGalleryController.swift:895, GalleryController.swift:1987 | 3 |
| ContextContentContainerNode.swift:26 | 3 |
| NavigationModalContainer.swift:430 | 2 |
| NavigationModalContainer.swift:485 | 3 |
| DrawingMessageRenderer.swift:132 | 3 |
| ContextControllerImpl.swift:1583, 1593; ContextControllerExtractedPresentationNode.swift:1014 | 3 |
| PeerSelectionControllerNode.swift:1339 | 1 |
| PeerInfoChatPaneNode.swift:321, PeerInfoChatListPaneNode.swift:586 | 3 |
| ContactSelectionControllerNode.swift:296, 306 | 1 |
| ContactMultiselectionControllerNode.swift:425, 518, 530 | 1 |
| OverlayMediaController.swift:79, ComposeControllerNode.swift:112 | 1 |
| BotReceiptControllerNode.swift:351, BotCheckoutControllerNode.swift:1266 | 1 |
| SearchDisplayController.swift:210, 237 | 1 |
| LocationPickerControllerNode.swift:1299 | 1 |

Record the row chosen for every multi-line site in the commit message body (one line per file).

- [ ] **Step 4: Build**

```sh
source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion --cacheDir ~/telegram-bazel-cache \
 build --continueOnError --configurationPath build-system/appstore-configuration.json \
 --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git \
 --gitCodesigningType development --gitCodesigningUseCurrent --buildNumber=1 --configuration=debug_sim_arm64
```

Expected: `Build completed successfully`. Any `missing argument for parameter 'reservedCorners'` is a site the grep missed: classify it by the table and rebuild. Re-run the Display tests (Task 1 Step 3 command); expected 15 passing.

- [ ] **Step 5: Commit**

```bash
git add -A submodules Telegram -- ':!submodules/TelegramCore/Sources/PendingMessages/EnqueueMessage.swift' ':!submodules/TelegramCore/Tests'
git commit -m "feat(display): carry reserved corners and the fold in ContainerViewLayout"
```

(Stage only files this task changed; the working tree has unrelated edits. Check `git diff --cached --stat` before committing.)

---

### Task 4: Read the regions in the window (no behavior change)

**Files:**
- Modify: `submodules/Display/Source/WindowContent.swift` (`WindowLayout`, `UpdatingLayout.update*`, `WindowHostView`, `windowSafeInsets`, `containedLayoutForWindowLayout`, `init`, `updateSize`, `updateSystemInsets`, `layoutSubviews` wiring at ~line 544, the `WindowLayout(` rebuild at ~line 1380)

**Interfaces:**
- Consumes: `resolveReservedArea`, `ContainerViewLayoutCorners` (Task 1); new `ContainerViewLayout` fields (Task 3).
- Produces: `private struct WindowReservedArea: Equatable { var safeInsets: UIEdgeInsets; var reservedCorners: ContainerViewLayoutCorners; var division: CGRect? }` and `private func windowReservedArea(hostView:deviceMetrics:windowSize:) -> WindowReservedArea`, which Task 5 changes.

- [ ] **Step 1: Region accessor on `WindowHostView`** (next to `systemSafeAreaInsets`)

```swift
    /// Multi-display devices only: the active occlusion and division reserved regions of the window,
    /// in `eventView` coordinates. Empty before iOS 27.1.
    fileprivate var activeReservedRegions: (occlusions: [CGRect], division: CGRect?) {
        if #available(iOS 27.1, *) {
            let occlusions = self.eventView.reservedRegions(kind: .occlusion).filter(\.isActive).map(\.frame)
            let division = self.eventView.reservedRegions(kind: .division).first(where: \.isActive)?.frame
            return (occlusions, division)
        }
        return ([], nil)
    }
```

- [ ] **Step 2: `WindowReservedArea` replaces `WindowLayout.safeInsets`**

Add above `WindowLayout`:

```swift
private struct WindowReservedArea: Equatable {
    var safeInsets: UIEdgeInsets
    var reservedCorners: ContainerViewLayoutCorners
    var division: CGRect?
}
```

In `WindowLayout`, replace `let safeInsets: UIEdgeInsets` with `let reservedArea: WindowReservedArea`. In every `WindowLayout(...)` construction in the file replace `safeInsets: X` with `reservedArea: X` where `X` is the corresponding `reservedArea` value (`self.layout.reservedArea`, `updatingLayout.layout.reservedArea`, or the new parameter). Rename `update(safeInsets:transition:overrideTransition:)` to `update(reservedArea: WindowReservedArea, transition:overrideTransition:)`, and in `update(size:metrics:safeInsets:...)` rename that parameter to `reservedArea: WindowReservedArea`. In `containedLayoutForWindowLayout`, read `layout.reservedArea.safeInsets` where it read `layout.safeInsets`.

- [ ] **Step 3: `windowReservedArea` replaces `windowSafeInsets`**

```swift
private func windowReservedArea(hostView: WindowHostView, deviceMetrics: DeviceMetrics, windowSize: CGSize) -> WindowReservedArea {
    if DeviceMetrics.hasMultipleDisplays {
        let systemInsets = hostView.systemSafeAreaInsets
        let systemSafeInsets = UIEdgeInsets(top: systemInsets.top, left: systemInsets.left, bottom: 0.0, right: systemInsets.right)
        let regions = hostView.activeReservedRegions
        let resolution = resolveReservedArea(size: windowSize, systemSafeInsets: systemSafeInsets, occlusions: regions.occlusions)
        // Step 1 of the rollout: corners are carried, safe insets stay the system's.
        return WindowReservedArea(safeInsets: systemSafeInsets, reservedCorners: resolution.reservedCorners, division: regions.division)
    }
    return WindowReservedArea(safeInsets: deviceSafeInsets(deviceMetrics: deviceMetrics, windowSize: windowSize), reservedCorners: .zero, division: nil)
}
```

Keep the existing doc comment of `windowSafeInsets` on it and add one line: "Also resolves the corner blocks and the fold (see `resolveReservedArea`)." Update the three callers (`init` ~line 473, `updateSize` ~line 1008, `updateSystemInsets` ~line 1024).

In `containedLayoutForWindowLayout`, pass `reservedCorners: layout.reservedArea.reservedCorners, division: layout.reservedArea.division` (replacing Task 3's temporary `.zero`/`nil`). The existing non-multi-display fallback that recomputes `resolvedSafeInsets` from `deviceSafeInsets` is unchanged.

- [ ] **Step 4: Re-read on every window layout pass**

In `updateSystemInsets`, log the value when it changes (temporary, removed in Task 5):

```swift
        self.updateLayout { layout in
            let size = layout.layout.size
            let reservedArea = windowReservedArea(hostView: self.hostView, deviceMetrics: self.deviceMetrics, windowSize: size)
            if reservedArea != layout.layout.reservedArea {
                NSLog("ReservedArea size=%@ safe=%@ corners=%@ division=%@", "\(size)", "\(reservedArea.safeInsets)", "\(reservedArea.reservedCorners)", "\(String(describing: reservedArea.division))")
            }
            layout.update(reservedArea: reservedArea, transition: .immediate, overrideTransition: false)
            layout.update(onScreenNavigationHeight: windowOnScreenNavigationHeight(hostView: self.hostView, deviceMetrics: self.deviceMetrics, isLandscape: size.width > size.height), transition: .immediate, overrideTransition: false)
        }
```

In the `hostView.layoutSubviews` closure (~line 544), call it before the layout pass:

```swift
        self.hostView.layoutSubviews = { [weak self] in
            // Reserved regions can change without a safe-area change (measured mid-unfold on
            // iPhone Duo), and every change arrives with a layout pass. An equal value is dropped
            // by `updateLayout`, so this converges.
            self?.updateSystemInsets()
            self?.layoutSubviews(force: false)
        }
```

(`updateSystemInsets` already returns immediately unless `DeviceMetrics.hasMultipleDisplays`.)

- [ ] **Step 5: Build** (Task 3 Step 4 command, without `--continueOnError`). Expected: `Build completed successfully`. Re-run DisplayTests: 15 passing.

- [ ] **Step 6: Runtime check, driven by the user**

Hand over: "Build is at `bazel-bin/Telegram/Telegram.ipa`; please install it on the iPhone Duo sim, then: unfold → landscape, rotate to portrait, rotate to landscape-right, fold, and half-open (~128°)." Then read the log:

```sh
xcrun simctl spawn <duo-udid> log show --last 10m --style compact --predicate 'eventMessage CONTAINS "ReservedArea"'
```

Expected, matching the spec table: open landscape `corners` topRight 84x120, `safe` right 84 (unchanged in this step); open portrait bottomRight 82x134; closed portrait topRight 84x170; `division` non-nil only at the half-open angle. The line must print only when the value changes — a steady stream while idle means the layout trigger does not converge (Review Focus 2). The app must look identical to before this task.

- [ ] **Step 7: Commit**

```bash
git add submodules/Display/Source/WindowContent.swift
git commit -m "feat(display): read iPhone Duo reserved regions into the window layout"
```

---

### Task 5: Corner-free safe insets on iPhone Duo

**Files:**
- Modify: `submodules/Display/Source/WindowContent.swift` (`windowReservedArea`, `updateSystemInsets`)

**Interfaces:**
- Consumes: `windowReservedArea`, `resolveReservedArea` (Tasks 1, 4).

- [ ] **Step 1: Use the resolved safe insets**

In `windowReservedArea`, replace the multi-display return with:

```swift
        return WindowReservedArea(safeInsets: resolution.safeInsets, reservedCorners: resolution.reservedCorners, division: regions.division)
```

and delete the "Step 1 of the rollout" comment.

- [ ] **Step 2: Remove the temporary `NSLog`** from `updateSystemInsets` (the `if reservedArea != ... { NSLog(...) }` block). Keep the `reservedArea` local.

- [ ] **Step 3: Build** (Task 4 Step 5). Expected: `Build completed successfully`; DisplayTests 15 passing.

- [ ] **Step 4: Visual check, driven by the user**

Hand over the build as in Task 4 Step 6 and ask for screenshots of the chat list + an open chat in the split layout: unfolded landscape, unfolded portrait, and closed. Compare with the screenshot from before the change. Expected: in unfolded landscape the chat pane is no longer inset 84pt along the whole right edge (content now reaches the right edge below the top-right corner); unfolded portrait and closed portrait/landscape differ only by the corresponding side inset disappearing. Anything in a corner (e.g. the chat's avatar under the clock) may now overlap the status corner: that is expected and is rollout step 3, not a regression of this plan — list each such overlap for the step-3 designs.

- [ ] **Step 5: Commit**

```bash
git add submodules/Display/Source/WindowContent.swift
git commit -m "feat(display): stop widening iPhone Duo's status corner into a full-edge safe inset"
```
