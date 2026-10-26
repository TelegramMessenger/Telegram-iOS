import XCTest
import CoreGraphics
import MediaEditor
import MediaCropComponent

final class MediaCropPhotosStyleTests: XCTestCase {
    func testDialTicksMatchPhotosRuler() {
        let ticks = mediaCropDialTicks()
        XCTAssertEqual(ticks.count, 41)
        XCTAssertEqual(ticks.first?.degrees, -45.0)
        XCTAssertEqual(ticks.last?.degrees, 45.0)
        XCTAssertEqual(ticks.first?.position, -180.0)
        XCTAssertEqual(ticks.last?.position, 180.0)
        XCTAssertEqual(ticks[21].position - ticks[20].position, 9.0)
        XCTAssertEqual(ticks[21].degrees - ticks[20].degrees, 2.25)
        XCTAssertEqual(ticks.filter { $0.isMajor }.map { $0.degrees }, [-45.0, -22.5, 0.0, 22.5, 45.0])
        XCTAssertEqual(mediaCropDialPointsPerDegree, 4.0)
    }

    func testDialRulerFollowsTheFinger() {
        XCTAssertEqual(mediaCropDialRulerOffset(degrees: 0.0), 0.0)
        XCTAssertEqual(mediaCropDialRulerOffset(degrees: 20.0), -80.0)
        XCTAssertEqual(mediaCropDialRulerOffset(degrees: -45.0), 180.0)
    }

    func testDialDragMapsFourPointsPerDegree() {
        XCTAssertEqual(mediaCropDialDraggedDegrees(rawDegrees: 0.0, translation: -80.0), 20.0, accuracy: 0.0001)
        XCTAssertEqual(mediaCropDialDraggedDegrees(rawDegrees: 0.0, translation: 36.0), -9.0, accuracy: 0.0001)
        XCTAssertEqual(mediaCropDialDraggedDegrees(rawDegrees: 40.0, translation: -100.0), 65.0, accuracy: 0.0001)
    }

    func testDialValueClampsAndSnaps() {
        XCTAssertEqual(mediaCropDialValue(rawDegrees: 65.0), 45.0)
        XCTAssertEqual(mediaCropDialValue(rawDegrees: -50.0), -45.0)
        XCTAssertEqual(mediaCropDialValue(rawDegrees: 0.6), 0.0)
        XCTAssertEqual(mediaCropDialValue(rawDegrees: 12.5), 12.5)
    }

    func testDialRubberBandsPastTheLimits() {
        XCTAssertEqual(mediaCropDialVisualDegrees(rawDegrees: 20.0, dimension: 200.0), 20.0)
        XCTAssertEqual(mediaCropDialVisualDegrees(rawDegrees: 0.5, dimension: 200.0), 0.0)
        let over = mediaCropDialVisualDegrees(rawDegrees: 45.0 + 290.0 / 4.0, dimension: 201.0)
        XCTAssertEqual((over - 45.0) * 4.0, 89.0, accuracy: 1.0)
        XCTAssertLessThan(over, 45.0 + 290.0 / 4.0)
        let under = mediaCropDialVisualDegrees(rawDegrees: -45.0 - 10.0, dimension: 201.0)
        XCTAssertLessThan(under, -45.0)
        XCTAssertGreaterThan(under, -55.0)
    }

    func testDialMarkerSitsOnTheTickAtOrBelowTheValue() {
        XCTAssertEqual(mediaCropDialSelectedTickIndex(visualDegrees: 0.0), 0)
        XCTAssertEqual(mediaCropDialSelectedTickIndex(visualDegrees: 2.0), 0)
        XCTAssertEqual(mediaCropDialSelectedTickIndex(visualDegrees: 3.0), 1)
        XCTAssertEqual(mediaCropDialSelectedTickIndex(visualDegrees: 9.0), 4)
        XCTAssertEqual(mediaCropDialSelectedTickIndex(visualDegrees: -0.3), -1)
        XCTAssertEqual(mediaCropDialSelectedTickIndex(visualDegrees: 45.0), 20)
        XCTAssertEqual(mediaCropDialSelectedTickIndex(visualDegrees: 70.0), 20)
        XCTAssertEqual(mediaCropDialSelectedTickIndex(visualDegrees: -70.0), -20)

        XCTAssertEqual(mediaCropDialMarkerOffset(visualDegrees: 0.0), 0.0)
        XCTAssertEqual(mediaCropDialMarkerOffset(visualDegrees: 1.0), -4.0, accuracy: 0.0001)
        XCTAssertEqual(mediaCropDialMarkerOffset(visualDegrees: 3.0), -3.0, accuracy: 0.0001)
        XCTAssertEqual(mediaCropDialMarkerOffset(visualDegrees: 20.0), -8.0, accuracy: 0.0001)
        XCTAssertEqual(mediaCropDialMarkerOffset(visualDegrees: -0.3), -7.8, accuracy: 0.0001)
        XCTAssertEqual(mediaCropDialMarkerOffset(visualDegrees: 50.0), -20.0, accuracy: 0.0001)
    }

    func testPassedTicksLightUpAndSettle() {
        XCTAssertEqual(mediaCropDialTickExcitation(elapsed: 0.0), 1.0)
        XCTAssertEqual(mediaCropDialTickExcitation(elapsed: 0.11), 0.5, accuracy: 0.001)
        XCTAssertEqual(mediaCropDialTickExcitation(elapsed: 0.048), 0.876, accuracy: 0.01)
        XCTAssertEqual(mediaCropDialTickExcitation(elapsed: 0.22), 0.0)
        XCTAssertEqual(mediaCropDialTickExcitation(elapsed: 1.0), 0.0)

        let rest = mediaCropDialTickAppearance(excitation: 0.0, isMajor: false)
        XCTAssertEqual(rest.height, 14.0)
        XCTAssertEqual(rest.alpha, 0.4, accuracy: 0.0001)
        let major = mediaCropDialTickAppearance(excitation: 0.0, isMajor: true)
        XCTAssertEqual(major.height, 14.0)
        XCTAssertEqual(major.alpha, 0.75, accuracy: 0.0001)
        let lit = mediaCropDialTickAppearance(excitation: 1.0, isMajor: false)
        XCTAssertEqual(lit.height, 28.0)
        XCTAssertEqual(lit.alpha, 1.0)
        let half = mediaCropDialTickAppearance(excitation: 0.5, isMajor: false)
        XCTAssertEqual(half.height, 21.0)
        XCTAssertEqual(half.alpha, 0.7, accuracy: 0.0001)

        XCTAssertEqual(mediaCropDialPassedTickIndices(from: 0, to: 3), [0, 1, 2])
        XCTAssertEqual(mediaCropDialPassedTickIndices(from: 2, to: -1), [2, 1, 0])
        XCTAssertEqual(mediaCropDialPassedTickIndices(from: 4, to: 4), [])
    }

    func testDialCoastsLikeAFastScrollView() {
        XCTAssertEqual(mediaCropDialInertiaDistance(velocity: 1000.0), 99.0, accuracy: 0.01)
        XCTAssertEqual(mediaCropDialInertiaDistance(velocity: -500.0), -49.5, accuracy: 0.01)
        XCTAssertEqual(mediaCropDialInertiaFraction(time: 0.0), 0.0)
        XCTAssertEqual(mediaCropDialInertiaFraction(time: 0.458), 0.99, accuracy: 0.001)
        XCTAssertEqual(mediaCropDialInertiaDuration(distance: 99.0), 0.5951, accuracy: 0.001)
        XCTAssertEqual(mediaCropDialInertiaDuration(distance: 0.1), 0.0)
    }

    func testDialSnapsToZero() {
        XCTAssertEqual(mediaCropDialSnappedDegrees(0.9), 0.0)
        XCTAssertEqual(mediaCropDialSnappedDegrees(-0.99), 0.0)
        XCTAssertEqual(mediaCropDialSnappedDegrees(1.0), 1.0)
        XCTAssertEqual(mediaCropDialSnappedDegrees(-12.5), -12.5)
    }

    func testDialDetentsAtZeroAndLimits() {
        XCTAssertTrue(mediaCropDialDetentReached(from: 2.0, to: 0.0))
        XCTAssertTrue(mediaCropDialDetentReached(from: -1.5, to: 0.0))
        XCTAssertFalse(mediaCropDialDetentReached(from: 0.0, to: 0.0))
        XCTAssertFalse(mediaCropDialDetentReached(from: 0.0, to: 1.2))
        XCTAssertTrue(mediaCropDialDetentReached(from: 44.0, to: 45.0))
        XCTAssertTrue(mediaCropDialDetentReached(from: -44.5, to: -45.0))
        XCTAssertFalse(mediaCropDialDetentReached(from: 45.0, to: 45.0))
        XCTAssertFalse(mediaCropDialDetentReached(from: 10.0, to: 12.0))
    }

    func testDialHeightAndAvailableArea() {
        XCTAssertEqual(mediaCropRotationDialHeight, 28.0)
        XCTAssertEqual(mediaCropAvailableArea(container: CGRect(x: 0.0, y: 62.0, width: 402.0, height: 614.0)), CGRect(x: 9.0, y: 71.0, width: 384.0, height: 596.0))
    }

    func testMidEdgeHandlesNeedRoomBetweenCorners() {
        XCTAssertFalse(mediaCropShowsMidEdgeHandle(sideLength: 44.0))
        XCTAssertFalse(mediaCropShowsMidEdgeHandle(sideLength: 70.0))
        XCTAssertTrue(mediaCropShowsMidEdgeHandle(sideLength: 71.0))
        XCTAssertTrue(mediaCropShowsMidEdgeHandle(sideLength: 300.0))
    }

    func testMirroredStateShowsTheMirrorImage() {
        var state = MediaCropState(originalSize: CGSize(width: 1000.0, height: 600.0))
        state.cropRect = CGRect(x: 100.0, y: 50.0, width: 400.0, height: 300.0)
        state.rotation = 10.0 * .pi / 180.0
        state.orientation = .left
        state.lockedAspectRatio = 0.75

        let mirrored = mediaCropMirrored(state)
        XCTAssertTrue(mirrored.mirrored)
        XCTAssertEqual(mirrored.rotation, -state.rotation, accuracy: 0.000001)
        XCTAssertEqual(mirrored.orientation, .right)
        XCTAssertEqual(mirrored.lockedAspectRatio, 0.75)
        let rotatedSize = mediaCropRotatedContentSize(state.originalSize, rotation: state.rotation)
        XCTAssertEqual(mirrored.cropRect.minX, rotatedSize.width - state.cropRect.maxX, accuracy: 0.0001)
        XCTAssertEqual(mirrored.cropRect.minY, state.cropRect.minY, accuracy: 0.0001)
        XCTAssertEqual(mirrored.cropRect.size, state.cropRect.size)

        let frame = CGRect(x: 20.0, y: 40.0, width: 300.0, height: 400.0)
        let placement = mediaCropContentPlacement(cropRect: state.cropRect, state: state, frame: frame)
        let mirroredPlacement = mediaCropContentPlacement(cropRect: mirrored.cropRect, state: mirrored, frame: frame)
        XCTAssertEqual(mirroredPlacement.scale, placement.scale, accuracy: 0.000001)
        XCTAssertEqual(mirroredPlacement.center.x, 2.0 * frame.midX - placement.center.x, accuracy: 0.001)
        XCTAssertEqual(mirroredPlacement.center.y, placement.center.y, accuracy: 0.001)

        XCTAssertEqual(mediaCropContentAngle(mirrored), -mediaCropContentAngle(state), accuracy: 0.000001)

        let back = mediaCropMirrored(mirrored)
        XCTAssertFalse(back.mirrored)
        XCTAssertEqual(back.orientation, .left)
        XCTAssertEqual(back.rotation, state.rotation, accuracy: 0.000001)
        XCTAssertEqual(back.cropRect.minX, state.cropRect.minX, accuracy: 0.0001)

        var upright = MediaCropState(originalSize: CGSize(width: 1000.0, height: 600.0))
        upright.orientation = .down
        XCTAssertEqual(mediaCropMirrored(upright).orientation, .down)
        XCTAssertEqual(mediaCropMirrored(upright).cropRect, upright.cropRect)
    }

    func testMirrorFlipFollowsTheMeasuredPhotosCurve() {
        XCTAssertEqual(mediaCropMirrorDuration, 0.5)
        let scale: (Double) -> CGFloat = { 1.0 - 2.0 * mediaCropMirrorFlipProgress(time: $0) }
        XCTAssertEqual(scale(0.0), 1.0, accuracy: 0.0001)
        XCTAssertEqual(scale(0.085), 0.0, accuracy: 0.05)
        XCTAssertEqual(scale(0.2), -0.816, accuracy: 0.01)
        XCTAssertEqual(scale(0.5), -1.0, accuracy: 0.002)
        XCTAssertEqual(mediaCropMirrorFlipProgress(time: 1.0), 1.0)
        let samples = stride(from: 0.0, through: 0.5, by: 0.01).map { mediaCropMirrorFlipProgress(time: $0) }
        XCTAssertEqual(samples, samples.sorted())
    }
}
