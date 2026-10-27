import XCTest
import CoreGraphics
import MediaEditor
import MediaCropComponent

private let perspectiveLimit = mediaEditorCropMaximumPerspectiveAngle * .pi / 180.0

private func displayedOutline(_ state: MediaCropState) -> [CGPoint] {
    let quad = mediaCropContentQuad(state)
    let rotatedSize = mediaCropRotatedContentSize(state.originalSize, rotation: state.rotation)
    let angle = -state.orientation.rotation
    return quad.map { point in
        let x = point.x - rotatedSize.width / 2.0
        let y = point.y - rotatedSize.height / 2.0
        return CGPoint(x: x * cos(angle) - y * sin(angle), y: x * sin(angle) + y * cos(angle))
    }
}

private func edgeLengths(_ outline: [CGPoint]) -> (top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat) {
    let byY = outline.sorted { $0.y < $1.y }
    let byX = outline.sorted { $0.x < $1.x }
    return (
        top: abs(byY[0].x - byY[1].x),
        bottom: abs(byY[2].x - byY[3].x),
        left: abs(byX[0].y - byX[1].y),
        right: abs(byX[2].y - byX[3].y)
    )
}

private func fittedCropRect(_ state: MediaCropState, frame: CGRect) -> CGRect {
    let placement = mediaCropContentPlacement(cropRect: state.cropRect, state: state, frame: frame)
    let fitted = mediaCropCoverFit(placement, frame: frame, state: state, allowScale: true)
    return mediaCropRect(frame: frame, placement: fitted, state: state)
}

final class MediaCropPerspectiveGeometryTests: XCTestCase {
    func testDefaultStateHasNoPerspective() {
        var state = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        XCTAssertEqual(state.perspective, .zero)
        XCTAssertTrue(state.isDefault)
        state.perspective = MediaEditorCropPerspective(vertical: 0.01, horizontal: 0.0)
        XCTAssertFalse(state.isDefault)
    }

    func testZeroPerspectiveQuadIsRotatedRectangle() {
        var state = MediaCropState(originalSize: CGSize(width: 400.0, height: 300.0))
        state.rotation = 0.2
        let rotatedSize = mediaCropRotatedContentSize(state.originalSize, rotation: state.rotation)
        let expected = [CGPoint(x: -200.0, y: -150.0), CGPoint(x: 200.0, y: -150.0), CGPoint(x: 200.0, y: 150.0), CGPoint(x: -200.0, y: 150.0)].map { point in
            CGPoint(x: point.x * cos(0.2) - point.y * sin(0.2) + rotatedSize.width / 2.0, y: point.x * sin(0.2) + point.y * cos(0.2) + rotatedSize.height / 2.0)
        }
        let quad = mediaCropContentQuad(state)
        XCTAssertEqual(quad.count, 4)
        for (actual, expected) in zip(quad, expected) {
            XCTAssertEqual(actual.x, expected.x, accuracy: 1e-6)
            XCTAssertEqual(actual.y, expected.y, accuracy: 1e-6)
        }
    }

    func testFullRectFitsOnlyWithoutPerspective() {
        var state = MediaCropState(originalSize: CGSize(width: 400.0, height: 300.0))
        XCTAssertTrue(mediaCropRectFits(state.cropRect, state: state))
        state.perspective = MediaEditorCropPerspective(vertical: 0.3, horizontal: 0.0)
        XCTAssertFalse(mediaCropRectFits(state.cropRect, state: state))
        XCTAssertTrue(mediaCropRectFits(CGRect(x: 150.0, y: 100.0, width: 100.0, height: 100.0), state: state))
    }

    func testScreenVerticalMakesDisplayedOutlineTrapezoidVertically() {
        for orientation in [MediaCropOrientation.up, .left, .down, .right] {
            for mirrored in [false, true] {
                var state = MediaCropState(originalSize: CGSize(width: 400.0, height: 300.0))
                state.orientation = orientation
                if mirrored {
                    state = mediaCropMirrored(state)
                }
                state = mediaCropSettingScreenPerspective(state, MediaEditorCropPerspective(vertical: 0.3, horizontal: 0.0))
                let screen = mediaCropScreenPerspective(state)
                XCTAssertEqual(screen.vertical, 0.3, accuracy: 1e-9)
                XCTAssertEqual(screen.horizontal, 0.0, accuracy: 1e-9)
                let edges = edgeLengths(displayedOutline(state))
                XCTAssertLessThan(edges.top, edges.bottom - 1.0, "\(orientation) mirrored \(mirrored)")
                XCTAssertEqual(edges.left, edges.right, accuracy: 1e-6, "\(orientation) mirrored \(mirrored)")
            }
        }
    }

    func testScreenHorizontalMakesDisplayedOutlineTrapezoidHorizontally() {
        for orientation in [MediaCropOrientation.up, .left, .down, .right] {
            for mirrored in [false, true] {
                var state = MediaCropState(originalSize: CGSize(width: 400.0, height: 300.0))
                state.orientation = orientation
                if mirrored {
                    state = mediaCropMirrored(state)
                }
                state = mediaCropSettingScreenPerspective(state, MediaEditorCropPerspective(vertical: 0.0, horizontal: 0.3))
                let edges = edgeLengths(displayedOutline(state))
                XCTAssertLessThan(edges.left, edges.right - 1.0, "\(orientation) mirrored \(mirrored)")
                XCTAssertEqual(edges.top, edges.bottom, accuracy: 1e-6, "\(orientation) mirrored \(mirrored)")
            }
        }
    }

    func testRotateCCWSwapsScreenAxes() {
        var state = MediaCropState(originalSize: CGSize(width: 400.0, height: 300.0))
        state.perspective = MediaEditorCropPerspective(vertical: 0.2, horizontal: 0.0)
        let rotated = mediaCropRotatedCCW(state)
        XCTAssertEqual(rotated.perspective, state.perspective)
        let screen = mediaCropScreenPerspective(rotated)
        XCTAssertEqual(screen.vertical, 0.0, accuracy: 1e-9)
        XCTAssertEqual(abs(screen.horizontal), 0.2, accuracy: 1e-9)
    }

    func testMirrorNegatesStoredHorizontal() {
        var state = MediaCropState(originalSize: CGSize(width: 400.0, height: 300.0))
        state.perspective = MediaEditorCropPerspective(vertical: 0.2, horizontal: -0.1)
        let mirrored = mediaCropMirrored(state)
        XCTAssertEqual(mirrored.perspective, MediaEditorCropPerspective(vertical: 0.2, horizontal: 0.1))
        XCTAssertEqual(mediaCropMirrored(mirrored).perspective, state.perspective)
    }

    func testCoverFitKeepsFrameInsideQuad() {
        let frame = CGRect(x: 20.0, y: 40.0, width: 300.0, height: 400.0)
        for vertical in [-perspectiveLimit, perspectiveLimit] {
            for horizontal in [-perspectiveLimit, perspectiveLimit] {
                for rotation in [-20.0 * .pi / 180.0, 0.0, 20.0 * .pi / 180.0] as [CGFloat] {
                    var state = MediaCropState(originalSize: CGSize(width: 3024.0, height: 4032.0))
                    state.rotation = rotation
                    state.perspective = MediaEditorCropPerspective(vertical: vertical, horizontal: horizontal)
                    let rotatedSize = mediaCropRotatedContentSize(state.originalSize, rotation: rotation)
                    state.cropRect = CGRect(x: (rotatedSize.width - 3024.0) / 2.0, y: (rotatedSize.height - 4032.0) / 2.0, width: 3024.0, height: 4032.0)
                    let cropRect = fittedCropRect(state, frame: frame)
                    XCTAssertTrue(mediaCropRectFits(cropRect.insetBy(dx: 0.5, dy: 0.5), state: state), "\(vertical) \(horizontal) \(rotation)")
                    XCTAssertGreaterThan(cropRect.width, 100.0)
                }
            }
        }
    }

    func testCoverFitMovesOffsetContentBackInside() {
        let frame = CGRect(x: 0.0, y: 0.0, width: 300.0, height: 300.0)
        var state = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        state.perspective = MediaEditorCropPerspective(vertical: 0.3, horizontal: 0.0)
        state.cropRect = CGRect(x: 0.0, y: 0.0, width: 1000.0, height: 1000.0)
        let placement = mediaCropContentPlacement(cropRect: state.cropRect, state: state, frame: frame)
        let fitted = mediaCropCoverFit(placement, frame: frame, state: state, allowScale: false)
        XCTAssertEqual(fitted.scale, placement.scale, accuracy: 1e-9)
        let cropRect = mediaCropRect(frame: frame, placement: fitted, state: state)
        XCTAssertTrue(mediaCropRectFits(cropRect.insetBy(dx: 0.5, dy: 0.5), state: state))
    }

    func testZeroPerspectiveCoverFitMatchesRotationOnlyResult() {
        let frame = CGRect(x: 0.0, y: 0.0, width: 300.0, height: 200.0)
        var state = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        state.rotation = 0.3
        let placement = MediaCropContentPlacement(center: CGPoint(x: 100.0, y: 80.0), scale: 0.05)
        let fitted = mediaCropCoverFit(placement, frame: frame, state: state, allowScale: true)
        let angle = mediaCropContentAngle(state)
        let boundsSize = mediaCropRotatedContentSize(frame.size, rotation: state.rotation)
        let contentSize = CGSize(width: 4000.0 * fitted.scale, height: 3000.0 * fitted.scale)
        XCTAssertEqual(max(boundsSize.width / contentSize.width, boundsSize.height / contentSize.height), 1.0, accuracy: 5e-3)
        let offset = CGPoint(x: frame.midX - fitted.center.x, y: frame.midY - fitted.center.y)
        let local = CGPoint(x: offset.x * cos(-angle) - offset.y * sin(-angle), y: offset.x * sin(-angle) + offset.y * cos(-angle))
        XCTAssertLessThanOrEqual(abs(local.x) + boundsSize.width / 2.0, contentSize.width / 2.0 + 1e-3)
        XCTAssertLessThanOrEqual(abs(local.y) + boundsSize.height / 2.0, contentSize.height / 2.0 + 1e-3)
    }

    func testLockedSixteenNineAtLimitStaysPositive() {
        let frame = CGRect(x: 0.0, y: 0.0, width: 300.0, height: 400.0)
        var state = MediaCropState(originalSize: CGSize(width: 3024.0, height: 4032.0))
        state.perspective = MediaEditorCropPerspective(vertical: perspectiveLimit, horizontal: perspectiveLimit)
        state.cropRect = fittedCropRect(state, frame: frame)
        let ratio = mediaCropLockedRatio(for: .ratio(16, 9), state: state)
        let locked = mediaCropApplyingLockedRatio(ratio, to: state)
        XCTAssertTrue(mediaCropRectFits(locked.cropRect.insetBy(dx: 0.5, dy: 0.5), state: locked))
        XCTAssertGreaterThan(locked.cropRect.width, 3024.0 / 10.0)
        XCTAssertGreaterThan(locked.cropRect.height, 4032.0 / 10.0 * 9.0 / 16.0)
        XCTAssertEqual(locked.cropRect.height / locked.cropRect.width, ratio, accuracy: 1e-3)
    }

    func testAdjustmentShrinksKeepingAspectAndHorizontalCentre() {
        let frame = CGRect(x: 0.0, y: 0.0, width: 300.0, height: 225.0)
        var state = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        let before = state.cropRect
        state.perspective = MediaEditorCropPerspective(vertical: 0.3, horizontal: 0.0)
        let after = fittedCropRect(state, frame: frame)
        XCTAssertLessThan(after.width, before.width)
        XCTAssertEqual(after.height / after.width, before.height / before.width, accuracy: 1e-3)
        XCTAssertEqual(after.midX, before.midX, accuracy: 0.5)
        XCTAssertTrue(mediaCropRectFits(after.insetBy(dx: 0.5, dy: 0.5), state: state))
    }

    func testTurningPerspectiveOffZoomsBackOutToTheStartScale() {
        let frame = CGRect(x: 0.0, y: 0.0, width: 400.0, height: 225.0)
        var state = MediaCropState(originalSize: CGSize(width: 4000.0, height: 2250.0))
        let start = mediaCropContentPlacement(cropRect: state.cropRect, state: state, frame: frame)
        state.perspective = MediaEditorCropPerspective(vertical: perspectiveLimit, horizontal: 0.0)
        let tilted = mediaCropAdjustmentFit(start, frame: frame, state: state, rotationStartScale: start.scale)
        XCTAssertGreaterThan(tilted.scale, start.scale * 1.05)
        state.cropRect = mediaCropRect(frame: frame, placement: tilted, state: state)
        let settled = mediaCropContentPlacement(cropRect: state.cropRect, state: state, frame: frame)
        state.perspective = .zero
        let restored = mediaCropAdjustmentFit(settled, frame: frame, state: state, rotationStartScale: start.scale)
        XCTAssertEqual(restored.scale, start.scale, accuracy: start.scale * 0.01)
        XCTAssertTrue(mediaCropRectFits(mediaCropRect(frame: frame, placement: restored, state: state).insetBy(dx: 0.5, dy: 0.5), state: state))
    }

    func testConfirmClampKeepsCropInsideFlaredQuad() {
        var state = MediaCropState(originalSize: CGSize(width: 3024.0, height: 4032.0))
        state.perspective = MediaEditorCropPerspective(vertical: perspectiveLimit, horizontal: 0.0)
        let rect = CGRect(x: 1512.0, y: 2016.0, width: 1300.0, height: 2400.0)
        XCTAssertTrue(mediaCropRectFits(rect, state: state))
        XCTAssertGreaterThan(rect.maxY, 4032.0)
        let clamped = mediaCropClampedCropRect(rect, state: state)
        XCTAssertTrue(mediaCropRectFits(clamped.insetBy(dx: 0.5, dy: 0.5), state: state))
        XCTAssertEqual(clamped.width / clamped.height, rect.width / rect.height, accuracy: 1e-3)
    }

    func testConfirmClampMovesOutsideCropIntoQuad() {
        var state = MediaCropState(originalSize: CGSize(width: 3024.0, height: 4032.0))
        state.perspective = MediaEditorCropPerspective(vertical: perspectiveLimit, horizontal: 0.0)
        let clamped = mediaCropClampedCropRect(CGRect(x: 0.0, y: 0.0, width: 1000.0, height: 1000.0), state: state)
        XCTAssertTrue(mediaCropRectFits(clamped.insetBy(dx: 0.5, dy: 0.5), state: state))
    }

    func testPerspectiveIsClampedToTheLimit() {
        let state = MediaCropState(originalSize: CGSize(width: 3024.0, height: 4032.0))
        let updated = mediaCropSettingScreenPerspective(state, MediaEditorCropPerspective(vertical: 45.0 * .pi / 180.0, horizontal: -60.0 * .pi / 180.0))
        XCTAssertEqual(updated.perspective.vertical, perspectiveLimit, accuracy: 1e-9)
        XCTAssertEqual(updated.perspective.horizontal, -perspectiveLimit, accuracy: 1e-9)
    }
}
