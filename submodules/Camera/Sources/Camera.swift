import Foundation
import UIKit
import AVFoundation
import CoreMedia
import SwiftSignalKit

public enum Camera {
    public typealias Preset = AVCaptureSession.Preset
    public typealias Position = AVCaptureDevice.Position
    public typealias FocusMode = AVCaptureDevice.FocusMode
    public typealias ExposureMode = AVCaptureDevice.ExposureMode
    public typealias FlashMode = AVCaptureDevice.FlashMode

    public struct CollageGrid: Hashable {
        public struct Row: Hashable {
            public let columns: Int

            public init(columns: Int) {
                self.columns = columns
            }
        }

        public let rows: [Row]

        public init(rows: [Row]) {
            self.rows = rows
        }

        public var count: Int {
            return self.rows.reduce(0) { $0 + $1.columns }
        }
    }

    public struct Configuration {
        public let preset: Preset
        public let position: Position
        public let isDualEnabled: Bool
        public let audio: Bool
        public let photo: Bool
        public let metadata: Bool
        public let preferWide: Bool
        public let preferLowerFramerate: Bool
        public let reportAudioLevel: Bool
        public let isRoundVideo: Bool

        public init(
            preset: Preset,
            position: Position,
            isDualEnabled: Bool = false,
            audio: Bool,
            photo: Bool,
            metadata: Bool,
            preferWide: Bool = false,
            preferLowerFramerate: Bool = false,
            reportAudioLevel: Bool = false,
            isRoundVideo: Bool = false
        ) {
            self.preset = preset
            self.position = position
            self.isDualEnabled = isDualEnabled
            self.audio = audio
            self.photo = photo
            self.metadata = metadata
            self.preferWide = preferWide
            self.preferLowerFramerate = preferLowerFramerate
            self.reportAudioLevel = reportAudioLevel
            self.isRoundVideo = isRoundVideo
        }
    }

    public enum ModeChange: Equatable {
        case none
        case position
        case dualCamera
    }
}

public protocol CameraProtocol: AnyObject {
    var metrics: Camera.Metrics { get }

    func startCapture()
    func stopCapture(invalidate: Bool)

    var position: Signal<Camera.Position, NoError> { get }
    func togglePosition()
    func setPosition(_ position: Camera.Position)
    func setDualCameraEnabled(_ enabled: Bool)

    func takePhoto() -> Signal<PhotoCaptureResult, NoError>
    func startRecording() -> Signal<CameraRecordingData, CameraRecordingError>
    func stopRecording() -> Signal<VideoCaptureResult, NoError>

    func focus(at point: CGPoint, autoFocus: Bool)
    func setFps(_ fps: Double)
    func setFlashMode(_ flashMode: Camera.FlashMode)
    func setZoomLevel(_ zoomLevel: CGFloat)
    func setZoomDelta(_ zoomDelta: CGFloat)
    func rampZoom(_ zoomLevel: CGFloat, rate: CGFloat)
    func setTorchActive(_ active: Bool)

    var hasTorch: Signal<Bool, NoError> { get }
    var isFlashActive: Signal<Bool, NoError> { get }
    var flashMode: Signal<Camera.FlashMode, NoError> { get }

    func setMainVideoOutput(_ output: CameraVideoOutput?)
    func setAdditionalVideoOutput(_ output: CameraVideoOutput?)
    func attachSimplePreviewView(_ view: CameraSimplePreviewView)

    var detectedCodes: Signal<[CameraCode], NoError> { get }
    var audioLevel: Signal<Float, NoError> { get }
    var transitionImage: Signal<UIImage?, NoError> { get }
    var modeChange: Signal<Camera.ModeChange, NoError> { get }
}

public extension CameraProtocol {
    func stopCapture() {
        self.stopCapture(invalidate: false)
    }

    func focus(at point: CGPoint) {
        self.focus(at: point, autoFocus: true)
    }
}

public protocol CameraSimplePreviewView: UIView {
    var isEnabled: Bool { get set }
    @available(iOS 13.0, *)
    var isPreviewing: Signal<Bool, NoError> { get }

    func removePlaceholder(delay: Double)
    func resetPlaceholder(front: Bool)
    func cameraPoint(for location: CGPoint) -> CGPoint
}

public extension CameraSimplePreviewView {
    func removePlaceholder() {
        self.removePlaceholder(delay: 0.0)
    }
}

public protocol CameraImpl: AnyObject {
    var isIpad: Bool { get }

    func isDualCameraSupported(forRoundVideo: Bool) -> Bool
    func makeCamera(
        configuration: Camera.Configuration,
        previewView: CameraSimplePreviewView?,
        secondaryPreviewView: CameraSimplePreviewView?
    ) -> CameraProtocol
    func makeCameraSimplePreviewView(frame: CGRect, main: Bool, roundVideo: Bool) -> CameraSimplePreviewView
}

public final class CameraHolder {
    public let camera: CameraProtocol
    public let previewView: CameraSimplePreviewView
    public let parentView: UIView
    public let restore: () -> Void

    public init(
        camera: CameraProtocol,
        previewView: CameraSimplePreviewView,
        parentView: UIView,
        restore: @escaping () -> Void
    ) {
        self.camera = camera
        self.previewView = previewView
        self.parentView = parentView
        self.restore = restore
    }
}

public struct CameraRecordingData {
    public let duration: Double
    public let filePath: String

    public init(duration: Double, filePath: String) {
        self.duration = duration
        self.filePath = filePath
    }
}

public enum CameraRecordingError: Error {
    case videoRecorderInitializationError
    case audioInitializationError
}

public final class CameraVideoOutput {
    private let sink: (CMSampleBuffer, Bool) -> Void

    public init(sink: @escaping (CMSampleBuffer, Bool) -> Void) {
        self.sink = sink
    }

    public func push(_ buffer: CMSampleBuffer, mirror: Bool) {
        self.sink(buffer, mirror)
    }
}
