import XCTest

final class CameraVideoOrientationTests: XCTestCase {
    private let all: [CameraVideoOrientation] = [.portrait, .landscapeRight, .portraitUpsideDown, .landscapeLeft]

    /// Every screen but iPhone Duo's inner one: the screen's portrait is the body's, so the connection takes the
    /// window's interface orientation as it is (what every iPhone and iPad did before).
    func testScreenWithTheDevicesPortraitKeepsTheInterfaceOrientation() {
        for orientation in self.all {
            XCTAssertEqual(CameraVideoOrientation(interfaceOrientation: orientation, screenPortrait: .portrait), orientation)
        }
    }

    /// iPhone Duo's inner screen: its portrait is the body in landscape (`UIDeviceOrientation.landscapeLeft`, the Home
    /// side on the right, which `AVCaptureVideoOrientation` names `.landscapeRight`), and its landscape-right the body
    /// upside down (measured on the device with `AVCaptureDevice.RotationCoordinator`, iOS 27.1). The camera is fixed
    /// in the body, so the connection takes the body position, a quarter turn on from the window's orientation.
    func testIPhoneDuoInnerScreenIsAQuarterTurnFromTheBody() {
        let innerScreenPortrait: CameraVideoOrientation = .landscapeRight
        XCTAssertEqual(CameraVideoOrientation(interfaceOrientation: .portrait, screenPortrait: innerScreenPortrait), .landscapeRight)
        XCTAssertEqual(CameraVideoOrientation(interfaceOrientation: .landscapeRight, screenPortrait: innerScreenPortrait), .portraitUpsideDown)
        XCTAssertEqual(CameraVideoOrientation(interfaceOrientation: .portraitUpsideDown, screenPortrait: innerScreenPortrait), .landscapeLeft)
        XCTAssertEqual(CameraVideoOrientation(interfaceOrientation: .landscapeLeft, screenPortrait: innerScreenPortrait), .portrait)
    }

    /// The quarter turns compose: a screen turned the other way round, or upside down, from the body.
    func testQuarterTurnsCompose() {
        XCTAssertEqual(CameraVideoOrientation(interfaceOrientation: .portrait, screenPortrait: .landscapeLeft), .landscapeLeft)
        XCTAssertEqual(CameraVideoOrientation(interfaceOrientation: .landscapeLeft, screenPortrait: .landscapeLeft), .portraitUpsideDown)
        XCTAssertEqual(CameraVideoOrientation(interfaceOrientation: .landscapeRight, screenPortrait: .portraitUpsideDown), .landscapeLeft)
        for orientation in self.all {
            let twice = CameraVideoOrientation(interfaceOrientation: CameraVideoOrientation(interfaceOrientation: orientation, screenPortrait: .landscapeRight), screenPortrait: .landscapeRight)
            XCTAssertEqual(CameraVideoOrientation(interfaceOrientation: orientation, screenPortrait: .portraitUpsideDown), twice)
        }
    }
}
