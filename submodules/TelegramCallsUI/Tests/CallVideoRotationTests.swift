import Foundation
import UIKit
import XCTest
import CallScreen

/// Pins the rotation policy of `resolveCallVideoRotationAngle`.
///
/// Every frame undoes the surface rotation (`interfaceOrientation`). A remote frame carries the
/// sender's gravity-relative rotation and additionally undoes the receiver's body rotation
/// (`deviceOrientation`); a local frame is body-relative and does not. On the portrait-locked
/// iPhone call screen that leaves the device correction for remote frames; where the interface
/// follows the device (iPad) the two cancel.
final class CallVideoRotationTests: XCTestCase {
    private let quarter: Float = Float.pi * 0.5
    private let half: Float = Float.pi
    private let threeQuarters: Float = Float.pi * 3.0 / 2.0

    private var quarterTurns: [Float] {
        return [0.0, self.quarter, self.half, self.threeQuarters]
    }

    func testRemoteFrameIsUntouchedWhileDeviceIsPortrait() {
        for angle in self.quarterTurns {
            XCTAssertEqual(resolveCallVideoRotationAngle(angle: angle, followsDeviceOrientation: false, interfaceOrientation: .portrait, deviceOrientation: deviceOrientationMatching(.portrait)), angle)
            XCTAssertEqual(resolveCallVideoRotationAngle(angle: angle, followsDeviceOrientation: false, interfaceOrientation: .portrait, deviceOrientation: .portrait), angle)
        }
    }

    /// The sign convention is the one the pre-V2 call UI shipped for years: device landscapeLeft
    /// (home button to the right, body turned counter-clockwise) counter-rotates the content by a
    /// clockwise quarter turn, which is a positive angle in UIKit's flipped coordinates.
    func testRemoteFrameCounterRotatesByDeviceOrientation() {
        XCTAssertEqual(resolveCallVideoRotationAngle(angle: 0.0, followsDeviceOrientation: false, interfaceOrientation: .portrait, deviceOrientation: .landscapeLeft), self.quarter)
        XCTAssertEqual(resolveCallVideoRotationAngle(angle: 0.0, followsDeviceOrientation: false, interfaceOrientation: .portrait, deviceOrientation: .landscapeRight), self.threeQuarters)
        XCTAssertEqual(resolveCallVideoRotationAngle(angle: 0.0, followsDeviceOrientation: false, interfaceOrientation: .portrait, deviceOrientation: .portraitUpsideDown), self.half)

        // A frame the sender captured in portrait (rotation 90) shown on a phone turned to landscapeLeft.
        XCTAssertEqual(resolveCallVideoRotationAngle(angle: self.quarter, followsDeviceOrientation: false, interfaceOrientation: .portrait, deviceOrientation: .landscapeLeft), self.half)
        // Wraps past a full turn.
        XCTAssertEqual(resolveCallVideoRotationAngle(angle: self.threeQuarters, followsDeviceOrientation: false, interfaceOrientation: .portrait, deviceOrientation: .landscapeLeft), 0.0)
        XCTAssertEqual(resolveCallVideoRotationAngle(angle: self.threeQuarters, followsDeviceOrientation: false, interfaceOrientation: .portrait, deviceOrientation: .landscapeRight), self.half)
    }

    /// UIKit defines the two landscape cases across the two enums as the same physical position
    /// with swapped names (`UIOrientation.h`). The mapping helpers must agree with that definition.
    func testOrientationEquivalenceFollowsUIKitDefinition() {
        XCTAssertEqual(UIInterfaceOrientation.landscapeLeft.rawValue, UIDeviceOrientation.landscapeRight.rawValue)
        XCTAssertEqual(UIInterfaceOrientation.landscapeRight.rawValue, UIDeviceOrientation.landscapeLeft.rawValue)

        XCTAssertEqual(deviceOrientationMatching(.landscapeLeft), .landscapeRight)
        XCTAssertEqual(deviceOrientationMatching(.landscapeRight), .landscapeLeft)
        XCTAssertEqual(deviceOrientationMatching(.portrait), .portrait)
        XCTAssertEqual(deviceOrientationMatching(.portraitUpsideDown), .portraitUpsideDown)

        XCTAssertEqual(interfaceOrientationMatching(.landscapeLeft), .landscapeRight)
        XCTAssertEqual(interfaceOrientationMatching(.landscapeRight), .landscapeLeft)
        XCTAssertEqual(interfaceOrientationMatching(.portrait), .portrait)
        XCTAssertEqual(interfaceOrientationMatching(.portraitUpsideDown), .portraitUpsideDown)
        for orientation in [UIDeviceOrientation.faceUp, .faceDown, .unknown] {
            XCTAssertEqual(interfaceOrientationMatching(orientation), .portrait)
        }

        for orientation in [UIInterfaceOrientation.portrait, .landscapeLeft, .landscapeRight, .portraitUpsideDown] {
            XCTAssertEqual(interfaceOrientationMatching(deviceOrientationMatching(orientation)), orientation)
        }
    }

    /// iPad: the interface followed the device, so the remote frame is already upright and must be
    /// shown as sent. This is the case the function must recognise without help from the caller.
    func testRemoteFrameIsUntouchedWhereInterfaceFollowsDevice() {
        for angle in self.quarterTurns {
            for interfaceOrientation in [UIInterfaceOrientation.portrait, .landscapeLeft, .landscapeRight, .portraitUpsideDown] {
                XCTAssertEqual(resolveCallVideoRotationAngle(angle: angle, followsDeviceOrientation: false, interfaceOrientation: interfaceOrientation, deviceOrientation: deviceOrientationMatching(interfaceOrientation)), angle)
            }
        }
    }

    /// A surface that was turned while the body stayed upright (or the body is unknown) must undo
    /// the surface turn for a gravity-relative frame, exactly as it does for a local frame.
    func testRemoteFrameOnTurnedSurfaceWithUprightBodyUndoesTheSurfaceTurn() {
        XCTAssertEqual(resolveCallVideoRotationAngle(angle: 0.0, followsDeviceOrientation: false, interfaceOrientation: .landscapeLeft, deviceOrientation: .portrait), self.quarter)
        XCTAssertEqual(resolveCallVideoRotationAngle(angle: 0.0, followsDeviceOrientation: false, interfaceOrientation: .landscapeRight, deviceOrientation: .portrait), self.threeQuarters)
        XCTAssertEqual(resolveCallVideoRotationAngle(angle: 0.0, followsDeviceOrientation: false, interfaceOrientation: .portraitUpsideDown, deviceOrientation: .portrait), self.half)
        for angle in self.quarterTurns {
            for interfaceOrientation in [UIInterfaceOrientation.landscapeLeft, .landscapeRight, .portraitUpsideDown] {
                XCTAssertEqual(
                    resolveCallVideoRotationAngle(angle: angle, followsDeviceOrientation: false, interfaceOrientation: interfaceOrientation, deviceOrientation: .portrait),
                    resolveCallVideoRotationAngle(angle: angle, followsDeviceOrientation: true, interfaceOrientation: interfaceOrientation, deviceOrientation: .portrait)
                )
            }
        }
    }

    func testFlatOrUnknownDeviceOrientationAppliesNoCorrection() {
        for orientation in [UIDeviceOrientation.faceUp, .faceDown, .unknown] {
            XCTAssertEqual(resolveCallVideoRotationAngle(angle: self.quarter, followsDeviceOrientation: false, interfaceOrientation: .portrait, deviceOrientation: orientation), self.quarter)
        }
    }

    func testLocalFrameIgnoresDeviceOrientation() {
        // A device-relative frame is already upright against gravity on a locked surface; adding
        // the device rotation would rotate the preview away from the user.
        for angle in self.quarterTurns {
            XCTAssertEqual(resolveCallVideoRotationAngle(angle: angle, followsDeviceOrientation: true, interfaceOrientation: .portrait, deviceOrientation: .landscapeLeft), angle)
            XCTAssertEqual(resolveCallVideoRotationAngle(angle: angle, followsDeviceOrientation: true, interfaceOrientation: .portrait, deviceOrientation: .landscapeRight), angle)
        }
    }

    func testLocalFrameFollowsInterfaceOrientation() {
        XCTAssertEqual(resolveCallVideoRotationAngle(angle: 0.0, followsDeviceOrientation: true, interfaceOrientation: .landscapeLeft, deviceOrientation: deviceOrientationMatching(.landscapeLeft)), self.quarter)
        XCTAssertEqual(resolveCallVideoRotationAngle(angle: 0.0, followsDeviceOrientation: true, interfaceOrientation: .landscapeRight, deviceOrientation: deviceOrientationMatching(.landscapeRight)), self.threeQuarters)
        XCTAssertEqual(resolveCallVideoRotationAngle(angle: 0.0, followsDeviceOrientation: true, interfaceOrientation: .portraitUpsideDown, deviceOrientation: deviceOrientationMatching(.portraitUpsideDown)), self.half)
        XCTAssertEqual(resolveCallVideoRotationAngle(angle: self.quarter, followsDeviceOrientation: true, interfaceOrientation: .landscapeLeft, deviceOrientation: deviceOrientationMatching(.landscapeLeft)), self.half)
        XCTAssertEqual(resolveCallVideoRotationAngle(angle: self.threeQuarters, followsDeviceOrientation: true, interfaceOrientation: .landscapeLeft, deviceOrientation: deviceOrientationMatching(.landscapeLeft)), 0.0)
    }

    /// `VideoContainerView` compares the result against the literals `Float.pi * 0.5` and
    /// `Float.pi * 3.0 / 2.0` with `==`, so a sum that lands one ulp off would silently skip the
    /// width/height swap. The result must be bit-identical to those literals.
    func testResultIsBitIdenticalToQuarterTurnLiterals() {
        for angle in self.quarterTurns {
            for orientation in [UIDeviceOrientation.portrait, .landscapeLeft, .landscapeRight, .portraitUpsideDown] {
                let resolved = resolveCallVideoRotationAngle(angle: angle, followsDeviceOrientation: false, interfaceOrientation: .portrait, deviceOrientation: orientation)
                XCTAssertTrue(self.quarterTurns.contains(where: { $0.bitPattern == resolved.bitPattern }), "\(resolved) is not one of the quarter-turn literals")
            }
            for orientation in [UIInterfaceOrientation.portrait, .landscapeLeft, .landscapeRight, .portraitUpsideDown] {
                let resolved = resolveCallVideoRotationAngle(angle: angle, followsDeviceOrientation: true, interfaceOrientation: orientation, deviceOrientation: deviceOrientationMatching(orientation))
                XCTAssertTrue(self.quarterTurns.contains(where: { $0.bitPattern == resolved.bitPattern }), "\(resolved) is not one of the quarter-turn literals")
                let resolvedRemote = resolveCallVideoRotationAngle(angle: angle, followsDeviceOrientation: false, interfaceOrientation: orientation, deviceOrientation: .landscapeLeft)
                XCTAssertTrue(self.quarterTurns.contains(where: { $0.bitPattern == resolvedRemote.bitPattern }), "\(resolvedRemote) is not one of the quarter-turn literals")
            }
        }
    }
}
