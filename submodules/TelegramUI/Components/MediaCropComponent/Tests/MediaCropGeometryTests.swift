import XCTest
import CoreGraphics
import MediaEditor
import MediaCropComponent

final class MediaCropGeometryTests: XCTestCase {
    private func assertRect(_ rect: CGRect, _ expected: CGRect, accuracy: CGFloat = 0.001, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(rect.origin.x, expected.origin.x, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(rect.origin.y, expected.origin.y, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(rect.size.width, expected.size.width, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(rect.size.height, expected.size.height, accuracy: accuracy, file: file, line: line)
    }

    private let strings = (original: "Original", square: "Square")

    func testDefaultState() {
        let state = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        XCTAssertEqual(state.originalSize, CGSize(width: 4000.0, height: 3000.0))
        XCTAssertEqual(state.cropRect, CGRect(x: 0.0, y: 0.0, width: 4000.0, height: 3000.0))
        XCTAssertEqual(state.rotation, 0.0)
        XCTAssertEqual(state.orientation, .up)
        XCTAssertFalse(state.mirrored)
        XCTAssertNil(state.lockedAspectRatio)
        XCTAssertTrue(state.isDefault)
        XCTAssertEqual(mediaCropMinimumFrameSide, 44.0)
    }

    func testRotatedContentSize() {
        let size = mediaCropRotatedContentSize(CGSize(width: 4000.0, height: 3000.0), rotation: .pi / 6.0)
        XCTAssertEqual(size.width, 4964.1, accuracy: 0.5)
        XCTAssertEqual(size.height, 4598.1, accuracy: 0.5)

        let unrotated = mediaCropRotatedContentSize(CGSize(width: 4000.0, height: 3000.0), rotation: 0.0)
        XCTAssertEqual(unrotated.width, 4000.0, accuracy: 0.001)
        XCTAssertEqual(unrotated.height, 3000.0, accuracy: 0.001)
    }

    func testPresetOrder() {
        XCTAssertEqual(mediaCropAspectPresets, [.original, .square, .ratio(3, 2), .ratio(5, 3), .ratio(4, 3), .ratio(5, 4), .ratio(7, 5), .ratio(16, 9)])
    }

    func testPresetTitlesFollowDisplayedOrientation() {
        var state = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        state.cropRect = CGRect(x: 500.0, y: 0.0, width: 2000.0, height: 3000.0)
        let portrait = mediaCropDisplayedSize(state)
        XCTAssertEqual(portrait, CGSize(width: 2000.0, height: 3000.0))
        XCTAssertEqual(mediaCropPresetTitle(.ratio(3, 2), displayedSize: portrait, strings: strings), "2:3")
        XCTAssertEqual(mediaCropPresetTitle(.ratio(16, 9), displayedSize: portrait, strings: strings), "9:16")
        XCTAssertEqual(mediaCropPresetTitle(.original, displayedSize: portrait, strings: strings), "Original")
        XCTAssertEqual(mediaCropPresetTitle(.square, displayedSize: portrait, strings: strings), "Square")

        state.cropRect = CGRect(x: 0.0, y: 0.0, width: 4000.0, height: 3000.0)
        state.orientation = .left
        let sideward = mediaCropDisplayedSize(state)
        XCTAssertEqual(sideward, CGSize(width: 3000.0, height: 4000.0))
        XCTAssertEqual(mediaCropPresetTitle(.ratio(3, 2), displayedSize: sideward, strings: strings), "2:3")

        state.orientation = .down
        let landscape = mediaCropDisplayedSize(state)
        XCTAssertEqual(mediaCropPresetTitle(.ratio(3, 2), displayedSize: landscape, strings: strings), "3:2")

        let squareSize = CGSize(width: 1000.0, height: 1000.0)
        XCTAssertEqual(mediaCropPresetTitle(.ratio(4, 3), displayedSize: squareSize, strings: strings), "4:3")
    }

    func testPresetInvertedForSidewardOrientation() {
        var state = MediaCropState(originalSize: CGSize(width: 3000.0, height: 4000.0))
        state.orientation = .left
        XCTAssertEqual(mediaCropPresetTitle(.ratio(4, 3), displayedSize: mediaCropDisplayedSize(state), strings: strings), "4:3")
        XCTAssertEqual(mediaCropLockedRatio(for: .ratio(4, 3), state: state), 4.0 / 3.0, accuracy: 0.0001)

        state.orientation = .up
        XCTAssertEqual(mediaCropLockedRatio(for: .ratio(4, 3), state: state), 4.0 / 3.0, accuracy: 0.0001)

        var landscape = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        XCTAssertEqual(mediaCropLockedRatio(for: .ratio(4, 3), state: landscape), 0.75, accuracy: 0.0001)
        landscape.orientation = .right
        XCTAssertEqual(mediaCropLockedRatio(for: .ratio(4, 3), state: landscape), 0.75, accuracy: 0.0001)
        XCTAssertEqual(mediaCropLockedRatio(for: .square, state: landscape), 1.0)

        let applied = mediaCropApplyingLockedRatio(mediaCropLockedRatio(for: .ratio(16, 9), state: landscape), to: landscape)
        let displayed = mediaCropDisplayedSize(applied)
        XCTAssertEqual(displayed.width / displayed.height, 9.0 / 16.0, accuracy: 0.0001)
    }

    func testOriginalRatioNotInverted() {
        var state = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        XCTAssertEqual(mediaCropLockedRatio(for: .original, state: state), 0.75, accuracy: 0.0001)
        state.orientation = .left
        XCTAssertEqual(mediaCropLockedRatio(for: .original, state: state), 0.75, accuracy: 0.0001)
        state.cropRect = CGRect(x: 0.0, y: 0.0, width: 1000.0, height: 2000.0)
        XCTAssertEqual(mediaCropLockedRatio(for: .original, state: state), 0.75, accuracy: 0.0001)
    }

    func testApplyingRatioKeepsCenterAndStaysInside() {
        var state = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        state.cropRect = CGRect(x: 2500.0, y: 500.0, width: 1000.0, height: 1000.0)
        let wide = mediaCropApplyingLockedRatio(0.5625, to: state)
        assertRect(wide.cropRect, CGRect(x: 2500.0, y: 718.75, width: 1000.0, height: 562.5))
        XCTAssertEqual(wide.lockedAspectRatio, 0.5625)

        state.cropRect = CGRect(x: 0.0, y: 0.0, width: 4000.0, height: 3000.0)
        let square = mediaCropApplyingLockedRatio(1.0, to: state)
        assertRect(square.cropRect, CGRect(x: 500.0, y: 0.0, width: 3000.0, height: 3000.0))

        state.cropRect = CGRect(x: 3500.0, y: 0.0, width: 500.0, height: 500.0)
        let tall = mediaCropApplyingLockedRatio(2.0, to: state)
        assertRect(tall.cropRect, CGRect(x: 3500.0, y: 0.0, width: 500.0, height: 1000.0))

        state.cropRect = CGRect(x: 3600.0, y: 2600.0, width: 400.0, height: 400.0)
        let shifted = mediaCropApplyingLockedRatio(1.5, to: state)
        assertRect(shifted.cropRect, CGRect(x: 3600.0, y: 2400.0, width: 400.0, height: 600.0))

        state.rotation = 0.2
        state.cropRect = CGRect(x: 1000.0, y: 1000.0, width: 2000.0, height: 1000.0)
        let rotated = mediaCropApplyingLockedRatio(1.0, to: state)
        assertRect(rotated.cropRect, CGRect(x: 1500.0, y: 1000.0, width: 1000.0, height: 1000.0))
    }

    func testRotate90Sequence() {
        XCTAssertEqual(MediaCropOrientation.up.rotatedCCW, .left)
        XCTAssertEqual(MediaCropOrientation.left.rotatedCCW, .down)
        XCTAssertEqual(MediaCropOrientation.down.rotatedCCW, .right)
        XCTAssertEqual(MediaCropOrientation.right.rotatedCCW, .up)

        var state = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        var sequence: [MediaCropOrientation] = []
        for _ in 0 ..< 4 {
            state = mediaCropRotatedCCW(state)
            sequence.append(state.orientation)
        }
        XCTAssertEqual(sequence, [.left, .down, .right, .up])
        XCTAssertTrue(state.isDefault)

        XCTAssertEqual(MediaCropOrientation.left.rotation, .pi / 2.0)
        XCTAssertEqual(MediaCropOrientation.right.rotation, -.pi / 2.0)
        XCTAssertTrue(MediaCropOrientation.left.isSideward)
        XCTAssertFalse(MediaCropOrientation.down.isSideward)
    }

    func testRotate90KeepsLockedRegion() {
        var state = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        state = mediaCropApplyingLockedRatio(mediaCropLockedRatio(for: .ratio(16, 9), state: state), to: state)
        let lockedRect = state.cropRect
        let lockedRatio = state.lockedAspectRatio

        let rotated = mediaCropRotatedCCW(state)
        XCTAssertEqual(rotated.orientation, .left)
        XCTAssertEqual(rotated.cropRect, lockedRect)
        XCTAssertEqual(rotated.lockedAspectRatio, lockedRatio)
        let displayed = mediaCropDisplayedSize(rotated)
        XCTAssertEqual(displayed, CGSize(width: lockedRect.height, height: lockedRect.width))
        XCTAssertEqual(mediaCropPresetTitle(.ratio(16, 9), displayedSize: displayed, strings: strings), "9:16")
    }

    func testAreaFrameFitsInsetContainer() {
        let container = CGRect(x: 0.0, y: 0.0, width: 375.0, height: 500.0)
        let landscape = mediaCropAreaFrame(cropSize: CGSize(width: 4000.0, height: 3000.0), orientation: .up, container: container)
        assertRect(landscape, CGRect(x: 9.0, y: 116.5, width: 357.0, height: 267.0))

        let sideward = mediaCropAreaFrame(cropSize: CGSize(width: 4000.0, height: 3000.0), orientation: .left, container: container)
        assertRect(sideward, CGRect(x: 9.0, y: 12.0, width: 357.0, height: 476.0))

        let tall = mediaCropAreaFrame(cropSize: CGSize(width: 1000.0, height: 3000.0), orientation: .down, container: CGRect(x: 10.0, y: 20.0, width: 375.0, height: 500.0))
        assertRect(tall, CGRect(x: 117.5, y: 29.0, width: 160.0, height: 482.0))
        XCTAssertTrue(container.insetBy(dx: 9.0, dy: 9.0).contains(landscape))
    }

    func testMinimumCropIsTenthOfOriginal() {
        let state = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        let small = mediaCropClampedCropRect(CGRect(x: 100.0, y: 100.0, width: 200.0, height: 100.0), state: state)
        assertRect(small, CGRect(x: 100.0, y: 100.0, width: 400.0, height: 200.0))

        let smallTall = mediaCropClampedCropRect(CGRect(x: 100.0, y: 100.0, width: 100.0, height: 150.0), state: state)
        assertRect(smallTall, CGRect(x: 100.0, y: 100.0, width: 200.0, height: 300.0))

        let atEdge = mediaCropClampedCropRect(CGRect(x: 3900.0, y: 2950.0, width: 50.0, height: 40.0), state: state)
        assertRect(atEdge, CGRect(x: 3600.0, y: 2680.0, width: 400.0, height: 320.0))

        let narrowOnly = mediaCropClampedCropRect(CGRect(x: 0.0, y: 0.0, width: 100.0, height: 2000.0), state: state)
        assertRect(narrowOnly, CGRect(x: 0.0, y: 0.0, width: 100.0, height: 2000.0))

        let outside = mediaCropClampedCropRect(CGRect(x: -100.0, y: 2500.0, width: 1000.0, height: 1000.0), state: state)
        assertRect(outside, CGRect(x: 0.0, y: 2000.0, width: 1000.0, height: 1000.0))

        var rotated = state
        rotated.rotation = .pi / 6.0
        let rotatedEdge = mediaCropClampedCropRect(CGRect(x: 4900.0, y: 4500.0, width: 50.0, height: 40.0), state: rotated)
        let content = mediaCropRotatedContentSize(state.originalSize, rotation: .pi / 6.0)
        assertRect(rotatedEdge, CGRect(x: content.width - 400.0, y: content.height - 320.0, width: 400.0, height: 320.0))
    }

    func testCornerResizeWithLockFollowsDominantAxis() {
        var state = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        state.lockedAspectRatio = 0.75

        let byWidth = mediaCropResized(state, corner: .bottomRight, translation: CGPoint(x: -40.0, y: -10.0), scale: 0.1)
        assertRect(byWidth.cropRect, CGRect(x: 0.0, y: 0.0, width: 3600.0, height: 2700.0))

        let byHeight = mediaCropResized(state, corner: .bottomRight, translation: CGPoint(x: -10.0, y: -60.0), scale: 0.1)
        assertRect(byHeight.cropRect, CGRect(x: 0.0, y: 0.0, width: 3200.0, height: 2400.0))

        let topLeft = mediaCropResized(state, corner: .topLeft, translation: CGPoint(x: 40.0, y: 10.0), scale: 0.1)
        assertRect(topLeft.cropRect, CGRect(x: 400.0, y: 300.0, width: 3600.0, height: 2700.0))

        let topRight = mediaCropResized(state, corner: .topRight, translation: CGPoint(x: -10.0, y: 60.0), scale: 0.1)
        assertRect(topRight.cropRect, CGRect(x: 0.0, y: 600.0, width: 3200.0, height: 2400.0))

        let bottomLeft = mediaCropResized(state, corner: .bottomLeft, translation: CGPoint(x: 40.0, y: 0.0), scale: 0.1)
        assertRect(bottomLeft.cropRect, CGRect(x: 400.0, y: 0.0, width: 3600.0, height: 2700.0))

        let edge = mediaCropResized(state, corner: .right, translation: CGPoint(x: -100.0, y: 30.0), scale: 0.1)
        assertRect(edge.cropRect, CGRect(x: 0.0, y: 0.0, width: 3000.0, height: 2250.0))

        var free = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        free = mediaCropResized(free, corner: .topLeft, translation: CGPoint(x: 40.0, y: 10.0), scale: 0.1)
        assertRect(free.cropRect, CGRect(x: 400.0, y: 100.0, width: 3600.0, height: 2900.0))

        var sideward = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        sideward.orientation = .left
        let bottom = mediaCropResized(sideward, corner: .bottom, translation: CGPoint(x: 0.0, y: -100.0), scale: 0.1)
        assertRect(bottom.cropRect, CGRect(x: 1000.0, y: 0.0, width: 3000.0, height: 3000.0))
        sideward.orientation = .right
        let rightSide = mediaCropResized(sideward, corner: .bottom, translation: CGPoint(x: 0.0, y: -100.0), scale: 0.1)
        assertRect(rightSide.cropRect, CGRect(x: 0.0, y: 0.0, width: 3000.0, height: 3000.0))
        sideward.orientation = .down
        let downSide = mediaCropResized(sideward, corner: .left, translation: CGPoint(x: 100.0, y: 0.0), scale: 0.1)
        assertRect(downSide.cropRect, CGRect(x: 0.0, y: 0.0, width: 3000.0, height: 3000.0))

        var sidewardLocked = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        sidewardLocked.orientation = .left
        sidewardLocked.lockedAspectRatio = 0.75
        let lockedBottom = mediaCropResized(sidewardLocked, corner: .bottomRight, translation: CGPoint(x: -30.0, y: -5.0), scale: 0.1)
        assertRect(lockedBottom.cropRect, CGRect(x: 400.0, y: 0.0, width: 3600.0, height: 2700.0))
        XCTAssertEqual(mediaCropDisplayedSize(lockedBottom).height / mediaCropDisplayedSize(lockedBottom).width, 4.0 / 3.0, accuracy: 0.0001)
    }

    func testMinimumFrameSide44() {
        let state = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        let free = mediaCropResized(state, corner: .bottomRight, translation: CGPoint(x: -1000.0, y: -1000.0), scale: 0.1)
        assertRect(free.cropRect, CGRect(x: 0.0, y: 0.0, width: 440.0, height: 440.0))

        var wide = state
        wide.lockedAspectRatio = 0.5
        let lockedWide = mediaCropResized(wide, corner: .bottomRight, translation: CGPoint(x: -1000.0, y: -900.0), scale: 0.1)
        assertRect(lockedWide.cropRect, CGRect(x: 0.0, y: 0.0, width: 880.0, height: 440.0))

        var tall = state
        tall.lockedAspectRatio = 2.0
        let lockedTall = mediaCropResized(tall, corner: .bottomRight, translation: CGPoint(x: -1000.0, y: -900.0), scale: 0.1)
        assertRect(lockedTall.cropRect, CGRect(x: 0.0, y: 0.0, width: 440.0, height: 880.0))
    }

    func testIsDefaultTolerance() {
        var state = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        state.cropRect = CGRect(x: 0.5, y: 0.5, width: 3999.0, height: 2999.0)
        XCTAssertTrue(state.isDefault)

        state.cropRect = CGRect(x: 0.0, y: 0.0, width: 3998.5, height: 2998.5)
        XCTAssertTrue(state.isDefault)

        state.cropRect = CGRect(x: 10.0, y: 10.0, width: 3980.0, height: 2980.0)
        XCTAssertFalse(state.isDefault)

        state.cropRect = CGRect(x: 1.0, y: 0.0, width: 4000.0, height: 3000.0)
        XCTAssertFalse(state.isDefault)

        state.cropRect = CGRect(x: 0.0, y: 0.0, width: 3998.0, height: 3000.0)
        XCTAssertFalse(state.isDefault)

        state = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        state.rotation = 0.01
        XCTAssertFalse(state.isDefault)

        state = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        state.mirrored = true
        XCTAssertFalse(state.isDefault)

        state = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        state.orientation = .left
        XCTAssertFalse(state.isDefault)

        state = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        state.lockedAspectRatio = 0.75
        XCTAssertTrue(state.isDefault)
    }

    private func assertPoint(_ point: CGPoint, _ expected: CGPoint, accuracy: CGFloat = 0.001, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(point.x, expected.x, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(point.y, expected.y, accuracy: accuracy, file: file, line: line)
    }

    func testPopSpringParameters() {
        let spring = mediaCropPopSpring(speed: 7.0, bounciness: 1.0)
        XCTAssertEqual(spring.mass, 1.0)
        XCTAssertEqual(spring.stiffness, 235.896, accuracy: 0.01)
        XCTAssertEqual(spring.damping, 28.914, accuracy: 0.01)
    }

    func testContentPlacementRoundTrip() {
        var state = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        state.rotation = 0.2
        state.orientation = .left
        let cropRect = CGRect(x: 500.0, y: 400.0, width: 1200.0, height: 2000.0)
        let frame = CGRect(x: 10.0, y: 20.0, width: 200.0, height: 120.0)
        let placement = mediaCropContentPlacement(cropRect: cropRect, state: state, frame: frame)
        XCTAssertEqual(placement.scale, 0.1, accuracy: 0.0001)
        assertRect(mediaCropRect(frame: frame, placement: placement, state: state), cropRect)
        assertRect(mediaCropDisplayedFrame(cropRect: cropRect, placement: placement, state: state), frame)

        var leftHalf = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        leftHalf.orientation = .left
        let leftHalfPlacement = mediaCropContentPlacement(cropRect: CGRect(x: 0.0, y: 0.0, width: 2000.0, height: 3000.0), state: leftHalf, frame: CGRect(x: 0.0, y: 0.0, width: 300.0, height: 200.0))
        XCTAssertEqual(leftHalfPlacement.scale, 0.1, accuracy: 0.0001)
        assertPoint(leftHalfPlacement.center, CGPoint(x: 150.0, y: 0.0))

        let full = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        let fullFrame = CGRect(x: 9.0, y: 100.0, width: 400.0, height: 300.0)
        let fullPlacement = mediaCropContentPlacement(cropRect: full.cropRect, state: full, frame: fullFrame)
        assertPoint(fullPlacement.center, CGPoint(x: fullFrame.midX, y: fullFrame.midY))
        XCTAssertEqual(fullPlacement.scale, 0.1, accuracy: 0.0001)
    }

    func testCoverFitScalesUpToCoverFrame() {
        let state = MediaCropState(originalSize: CGSize(width: 1000.0, height: 500.0))
        let frame = CGRect(x: 0.0, y: 0.0, width: 300.0, height: 300.0)
        let fitted = mediaCropCoverFit(MediaCropContentPlacement(center: CGPoint(x: 150.0, y: 150.0), scale: 0.4), frame: frame, state: state, allowScale: true)
        XCTAssertEqual(fitted.scale, 0.6, accuracy: 0.0001)
        assertPoint(fitted.center, CGPoint(x: 150.0, y: 150.0))

        let unscaled = mediaCropCoverFit(MediaCropContentPlacement(center: CGPoint(x: 150.0, y: 150.0), scale: 0.4), frame: frame, state: state, allowScale: false)
        XCTAssertEqual(unscaled.scale, 0.4, accuracy: 0.0001)

        var rotated = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        rotated.rotation = .pi / 6.0
        rotated.orientation = .left
        let rotatedFrame = CGRect(x: 20.0, y: 100.0, width: 300.0, height: 400.0)
        let rotatedFitted = mediaCropCoverFit(MediaCropContentPlacement(center: CGPoint(x: 100.0, y: 200.0), scale: 0.05), frame: rotatedFrame, state: rotated, allowScale: true)
        XCTAssertGreaterThan(rotatedFitted.scale, 0.05)
        let angle = rotated.rotation - rotated.orientation.rotation
        let halfWidth = rotated.originalSize.width * rotatedFitted.scale / 2.0
        let halfHeight = rotated.originalSize.height * rotatedFitted.scale / 2.0
        for corner in [CGPoint(x: rotatedFrame.minX, y: rotatedFrame.minY), CGPoint(x: rotatedFrame.maxX, y: rotatedFrame.minY), CGPoint(x: rotatedFrame.minX, y: rotatedFrame.maxY), CGPoint(x: rotatedFrame.maxX, y: rotatedFrame.maxY)] {
            let vector = CGPoint(x: corner.x - rotatedFitted.center.x, y: corner.y - rotatedFitted.center.y)
            let local = CGPoint(x: vector.x * cos(-angle) - vector.y * sin(-angle), y: vector.x * sin(-angle) + vector.y * cos(-angle))
            XCTAssertLessThanOrEqual(abs(local.x), halfWidth + 0.01)
            XCTAssertLessThanOrEqual(abs(local.y), halfHeight + 0.01)
        }
    }

    func testCoverFitTranslatesToNearestValid() {
        let state = MediaCropState(originalSize: CGSize(width: 1000.0, height: 500.0))
        let frame = CGRect(x: 0.0, y: 0.0, width: 300.0, height: 300.0)

        let inside = MediaCropContentPlacement(center: CGPoint(x: 150.0, y: 150.0), scale: 1.0)
        XCTAssertEqual(mediaCropCoverFit(inside, frame: frame, state: state, allowScale: true), inside)

        let fitted = mediaCropCoverFit(MediaCropContentPlacement(center: CGPoint(x: 550.0, y: -100.0), scale: 1.0), frame: frame, state: state, allowScale: true)
        XCTAssertEqual(fitted.scale, 1.0, accuracy: 0.0001)
        assertPoint(fitted.center, CGPoint(x: 500.0, y: 50.0))

        let other = mediaCropCoverFit(MediaCropContentPlacement(center: CGPoint(x: -300.0, y: 300.0), scale: 1.0), frame: frame, state: state, allowScale: true)
        assertPoint(other.center, CGPoint(x: -200.0, y: 250.0))
    }

    func testCappedFrame() {
        let bounds = CGRect(x: 9.0, y: 9.0, width: 372.0, height: 500.0)
        assertRect(mediaCropCappedFrame(CGRect(x: 200.0, y: 100.0, width: 250.0, height: 150.0), bounds: bounds, aspectRatio: 0.5), CGRect(x: 200.0, y: 100.0, width: 181.0, height: 90.5))
        assertRect(mediaCropCappedFrame(CGRect(x: 0.0, y: 50.0, width: 100.0, height: 100.0), bounds: bounds, aspectRatio: nil), CGRect(x: 9.0, y: 50.0, width: 91.0, height: 100.0))
        assertRect(mediaCropCappedFrame(CGRect(x: 100.0, y: 450.0, width: 100.0, height: 100.0), bounds: bounds, aspectRatio: 2.0), CGRect(x: 100.0, y: 450.0, width: 29.5, height: 59.0))
        let inside = CGRect(x: 50.0, y: 60.0, width: 100.0, height: 100.0)
        assertRect(mediaCropCappedFrame(inside, bounds: bounds, aspectRatio: 1.0), inside)
    }

    func testDisplayedLockedRatio() {
        var state = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        XCTAssertNil(mediaCropDisplayedLockedRatio(state))
        state.lockedAspectRatio = 0.75
        XCTAssertEqual(mediaCropDisplayedLockedRatio(state) ?? 0.0, 0.75, accuracy: 0.0001)
        state.orientation = .right
        XCTAssertEqual(mediaCropDisplayedLockedRatio(state) ?? 0.0, 4.0 / 3.0, accuracy: 0.0001)
    }

    func testMinimumZoomScale() {
        var state = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        XCTAssertEqual(mediaCropMinimumZoomScale(frameSize: CGSize(width: 300.0, height: 200.0), state: state), 0.075, accuracy: 0.0001)
        state.orientation = .left
        XCTAssertEqual(mediaCropMinimumZoomScale(frameSize: CGSize(width: 300.0, height: 200.0), state: state), 0.1, accuracy: 0.0001)
    }

    func testPinchScaleClampsAndRubberBands() {
        XCTAssertEqual(mediaCropPinchScale(startScale: 0.1, gestureScale: 200.0, minimumScale: 0.1, contentWidth: 1000.0), 1.0, accuracy: 0.0001)
        XCTAssertEqual(mediaCropPinchScale(startScale: 0.1, gestureScale: 2.0, minimumScale: 0.1, contentWidth: 1000.0), 0.2, accuracy: 0.0001)
        XCTAssertEqual(mediaCropPinchScale(startScale: 0.1, gestureScale: 0.5, minimumScale: 0.1, contentWidth: 1000.0), 0.0725762, accuracy: 0.00001)
        XCTAssertGreaterThanOrEqual(mediaCropPinchScale(startScale: 0.1, gestureScale: 0.0001, minimumScale: 0.1, contentWidth: 1000.0), 0.025)
    }
    func testRotationRangeIsFortyFiveDegrees() {
        XCTAssertEqual(mediaCropMaximumWheelAngle, 45.0)
    }

    func testPlacementRotatedAroundFrameCenter() {
        let rotated = mediaCropPlacementRotated(MediaCropContentPlacement(center: CGPoint(x: 110.0, y: 50.0), scale: 0.5), around: CGPoint(x: 100.0, y: 50.0), by: .pi / 2.0)
        assertPoint(rotated.center, CGPoint(x: 100.0, y: 60.0))
        XCTAssertEqual(rotated.scale, 0.5)
    }

    func testWheelRotationFitCoversAndKeepsStartScale() {
        var state = MediaCropState(originalSize: CGSize(width: 1000.0, height: 500.0))
        let frame = CGRect(x: 0.0, y: 0.0, width: 300.0, height: 150.0)
        let start = MediaCropContentPlacement(center: CGPoint(x: 150.0, y: 75.0), scale: 0.3)

        state.rotation = 10.0 * .pi / 180.0
        let turned = mediaCropCoverFit(start, frame: frame, state: state, allowScale: true, rotationStartScale: 0.29)
        XCTAssertGreaterThan(turned.scale, 0.3)
        let halfWidth = state.originalSize.width * turned.scale / 2.0
        let halfHeight = state.originalSize.height * turned.scale / 2.0
        for corner in [CGPoint(x: frame.minX, y: frame.minY), CGPoint(x: frame.maxX, y: frame.minY), CGPoint(x: frame.minX, y: frame.maxY), CGPoint(x: frame.maxX, y: frame.maxY)] {
            let vector = CGPoint(x: corner.x - turned.center.x, y: corner.y - turned.center.y)
            let angle = -state.rotation
            let local = CGPoint(x: vector.x * cos(angle) - vector.y * sin(angle), y: vector.x * sin(angle) + vector.y * cos(angle))
            XCTAssertLessThanOrEqual(abs(local.x), halfWidth + 0.01)
            XCTAssertLessThanOrEqual(abs(local.y), halfHeight + 0.01)
        }

        state.rotation = 0.0
        let back = mediaCropCoverFit(turned, frame: frame, state: state, allowScale: true, rotationStartScale: 0.29)
        XCTAssertEqual(back.scale, 0.3, accuracy: 0.0001)

        let zoomed = MediaCropContentPlacement(center: CGPoint(x: 150.0, y: 75.0), scale: 0.4)
        let kept = mediaCropCoverFit(zoomed, frame: frame, state: state, allowScale: true, rotationStartScale: 0.35)
        XCTAssertEqual(kept.scale, 0.4, accuracy: 0.0001)

        XCTAssertEqual(mediaCropCoverFit(zoomed, frame: frame, state: state, allowScale: true), zoomed)
    }

    func testQuarterTurnTakesShortWayCounterClockwise() {
        let up = mediaCropOrientationScreenAngle(.up)
        let left = mediaCropOrientationScreenAngle(.left)
        let down = mediaCropOrientationScreenAngle(.down)
        let right = mediaCropOrientationScreenAngle(.right)
        XCTAssertEqual(left, -.pi / 2.0, accuracy: 0.0001)
        XCTAssertEqual(down, -.pi, accuracy: 0.0001)
        XCTAssertEqual(right, .pi / 2.0, accuracy: 0.0001)

        XCTAssertEqual(mediaCropQuarterTurnTargetAngle(current: up, target: left), -.pi / 2.0, accuracy: 0.0001)
        XCTAssertEqual(mediaCropQuarterTurnTargetAngle(current: left, target: down), -.pi, accuracy: 0.0001)
        XCTAssertEqual(mediaCropQuarterTurnTargetAngle(current: down, target: right), -1.5 * .pi, accuracy: 0.0001)
        XCTAssertEqual(mediaCropQuarterTurnTargetAngle(current: .pi, target: right), .pi / 2.0, accuracy: 0.0001)
        XCTAssertEqual(mediaCropQuarterTurnTargetAngle(current: right, target: up), 0.0, accuracy: 0.0001)
    }
}
