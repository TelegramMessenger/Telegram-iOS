import Foundation
import UIKit
import AVFoundation
import DeviceModel

/// Whether a round video is recorded in its preview's orientation rather than in the body's portrait: on an iPad, and on
/// iPhone Duo, whose inner screen's portrait is the body in landscape. Elsewhere the round camera's screen is portrait.
public var cameraRecordsRoundVideoInPreviewOrientation: Bool {
    return DeviceModel.current.isIpad || DeviceModel.current == .iPhoneDuo
}

public extension CameraVideoOrientation {
    init(_ interfaceOrientation: UIInterfaceOrientation) {
        switch interfaceOrientation {
        case .landscapeRight:
            self = .landscapeRight
        case .portraitUpsideDown:
            self = .portraitUpsideDown
        case .landscapeLeft:
            self = .landscapeLeft
        default:
            self = .portrait
        }
    }

    /// The two enums name a landscape position from opposite points of view: `UIDeviceOrientation.landscapeLeft` is
    /// the Home side on the right, `landscapeRight` here.
    init(_ deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .landscapeLeft:
            self = .landscapeRight
        case .portraitUpsideDown:
            self = .portraitUpsideDown
        case .landscapeRight:
            self = .landscapeLeft
        default:
            self = .portrait
        }
    }

    var avCaptureVideoOrientation: AVCaptureVideoOrientation {
        switch self {
        case .portrait:
            return .portrait
        case .landscapeRight:
            return .landscapeRight
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft
        }
    }
}
