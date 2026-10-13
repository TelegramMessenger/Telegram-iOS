import Foundation
import UIKit
import AVFoundation
import CoreMedia
import CoreVideo
import DeviceModel
import Camera

private func supportsDualCameraCapture(forRoundVideo: Bool) -> Bool {
    guard #available(iOS 13.0, *), AVCaptureMultiCamSession.isMultiCamSupported, !DeviceModel.current.isIpad else {
        return false
    }
    if forRoundVideo && DeviceModel.current == .iPhoneXR {
        return false
    }
    let positions: [AVCaptureDevice.Position] = [.back, .front]
    return positions.allSatisfy { position in
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            return false
        }
        return device.formats.contains { format in
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let mediaSubtype = CMFormatDescriptionGetMediaSubType(format.formatDescription)
            return format.isMultiCamSupported
                && dimensions.width == 640
                && dimensions.height == 480
                && (mediaSubtype == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange || mediaSubtype == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
                && format.videoSupportedFrameRateRanges.contains(where: { $0.minFrameRate <= 30.0 && $0.maxFrameRate >= 30.0 })
        }
    }
}

public final class NeoCameraImpl: CameraImpl {
    public static let shared = NeoCameraImpl()

    private init() {
        RoundVideoDecorationProvider.shared.warmUp()
    }

    public var isIpad: Bool {
        return DeviceModel.current.isIpad
    }

    public func isDualCameraSupported(forRoundVideo: Bool) -> Bool {
        return supportsDualCameraCapture(forRoundVideo: forRoundVideo)
    }

    public func makeCamera(
        configuration: Camera.Configuration,
        previewView: CameraSimplePreviewView?,
        secondaryPreviewView: CameraSimplePreviewView?
    ) -> CameraProtocol {
        let cameraPreviewView: CameraPreviewView?
        if let previewView {
            guard let previewView = previewView as? CameraPreviewView else {
                preconditionFailure()
            }
            cameraPreviewView = previewView
        } else {
            cameraPreviewView = nil
        }

        let cameraSecondaryPreviewView: CameraPreviewView?
        if let secondaryPreviewView {
            guard let secondaryPreviewView = secondaryPreviewView as? CameraPreviewView else {
                preconditionFailure()
            }
            cameraSecondaryPreviewView = secondaryPreviewView
        } else {
            cameraSecondaryPreviewView = nil
        }

        return CameraNeo(
            configuration: configuration,
            previewView: cameraPreviewView,
            secondaryPreviewView: cameraSecondaryPreviewView,
            useMultiCam: configuration.isDualEnabled && self.isDualCameraSupported(forRoundVideo: configuration.isRoundVideo)
        )
    }

    public func makeCameraSimplePreviewView(frame: CGRect, main: Bool, roundVideo: Bool) -> CameraSimplePreviewView {
        return CameraPreviewView(frame: frame, main: main, roundVideo: roundVideo)
    }
}
