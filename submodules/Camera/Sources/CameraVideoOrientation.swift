import Foundation

/// A position of the device body, named as `AVCaptureVideoOrientation` (and `UIInterfaceOrientation`) name them:
/// `landscapeRight` is the Home side on the right, `UIDeviceOrientation.landscapeLeft`. Kept free of AVFoundation's
/// type, deprecated on macOS, so the decision below runs in the host tests.
public enum CameraVideoOrientation: Equatable {
    case portrait
    case landscapeRight
    case portraitUpsideDown
    case landscapeLeft

    /// The orientation a capture connection takes for video that reads upright in a window whose interface orientation
    /// is `interfaceOrientation`.
    ///
    /// The camera is fixed in the device body and a connection's orientation names a body position, while a window's
    /// interface orientation is measured against its own screen. `screenPortrait` is the body position in which that
    /// screen's portrait reads upright (`DeviceMetrics.screenPortraitDeviceOrientation(size:)`): portrait on every
    /// screen but iPhone Duo's inner one, so the window's orientation passes through, and `landscapeRight` there (the
    /// inner screen's portrait is the body in `UIDeviceOrientation.landscapeLeft`). The call screens make the same
    /// conversion for their video (`callInterfaceOrientationInDeviceFrame`).
    public init(interfaceOrientation: CameraVideoOrientation, screenPortrait: CameraVideoOrientation) {
        self.init(quarterTurns: interfaceOrientation.quarterTurns + screenPortrait.quarterTurns)
    }

    /// Quarter turns of the body counter-clockwise from portrait.
    private var quarterTurns: Int {
        switch self {
        case .portrait:
            return 0
        case .landscapeRight:
            return 1
        case .portraitUpsideDown:
            return 2
        case .landscapeLeft:
            return 3
        }
    }

    private init(quarterTurns: Int) {
        switch quarterTurns % 4 {
        case 1:
            self = .landscapeRight
        case 2:
            self = .portraitUpsideDown
        case 3:
            self = .landscapeLeft
        default:
            self = .portrait
        }
    }
}
