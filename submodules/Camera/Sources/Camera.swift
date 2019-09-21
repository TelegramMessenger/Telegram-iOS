import Foundation
import SwiftSignalKit
import AVFoundation

private final class CameraContext {
    private let queue: Queue
    private let session = AVCaptureSession()
    private let device: CameraDevice
    private let input = CameraInput()
    private let output = CameraOutput()
    
    private let initialConfiguration: Camera.Configuration
    
    var previewNode: CameraPreviewNode? {
        didSet {
            self.previewNode?.prepare()
        }
    }
    
    var previousSampleBuffer: CMSampleBuffer?
    var processSampleBuffer: ((CMSampleBuffer) -> Void)?
    
    private var invalidated = false
    
    init(queue: Queue, configuration: Camera.Configuration) {
        self.queue = queue
        self.initialConfiguration = configuration
        
        self.device = CameraDevice()
        self.device.configure(for: self.session, position: configuration.position)
        
        self.session.beginConfiguration()
        self.session.sessionPreset = configuration.preset
        self.input.configure(for: self.session, device: self.device, audio: configuration.audio)
        self.output.configure(for: self.session)
        self.session.commitConfiguration()
        
        self.output.processSampleBuffer = { [weak self] sampleBuffer, connection in
            if let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer), CMFormatDescriptionGetMediaType(formatDescription) == kCMMediaType_Video {
                self?.previousSampleBuffer = sampleBuffer
                self?.previewNode?.enqueue(sampleBuffer)
            }
            
            self?.queue.async {
                self?.processSampleBuffer?(sampleBuffer)
            }
        }
    }
    
    func startCapture() {
        guard !self.session.isRunning else {
            return
        }
        
        self.session.startRunning()
    }
    
    func stopCapture() {
        self.session.beginConfiguration()
        self.input.invalidate(for: self.session)
        self.output.invalidate(for: self.session)
        self.session.commitConfiguration()
        
        self.session.stopRunning()
    }
    
    func focus(at point: CGPoint) {
        self.device.setFocusPoint(point, focusMode: .continuousAutoFocus, exposureMode: .continuousAutoExposure, monitorSubjectAreaChange: true)
    }
    
    func setFPS(_ fps: Float64) {
        self.device.fps = fps
    }
    
    func togglePosition() {
        self.session.beginConfiguration()
        self.input.invalidate(for: self.session)
        let targetPosition: Camera.Position
        if case .back = self.device.position {
            targetPosition = .front
        } else {
            targetPosition = .back
        }
        self.device.configure(for: self.session, position: targetPosition)
        self.input.configure(for: self.session, device: self.device, audio: self.initialConfiguration.audio)
        self.session.commitConfiguration()
    }
}

final class Camera {
    typealias Preset = AVCaptureSession.Preset
    typealias Position = AVCaptureDevice.Position
    typealias FocusMode = AVCaptureDevice.FocusMode
    typealias ExposureMode = AVCaptureDevice.ExposureMode
    
    struct Configuration {
        let preset: Preset
        let position: Position
        let audio: Bool
    }
    
    private let queue = Queue()
    private var contextRef: Unmanaged<CameraContext>?
    
    init(configuration: Camera.Configuration = Configuration(preset: .hd1920x1080, position: .back, audio: true)) {
        self.queue.async {
            let context = CameraContext(queue: self.queue, configuration: configuration)
            self.contextRef = Unmanaged.passRetained(context)
        }
    }
    
    deinit {
        let contextRef = self.contextRef
        self.queue.async {
            contextRef?.release()
        }
    }
    
    func startCapture() {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.startCapture()
            }
        }
    }
    
    func stopCapture() {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.stopCapture()
            }
        }
    }
    func togglePosition() {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.togglePosition()
            }
        }
    }
    
    func takePhoto() -> Signal<Void, NoError> {
        return .never()
    }
    
    func focus(at point: CGPoint) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.focus(at: point)
            }
        }
    }
    
    func setFPS(_ fps: Double) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.setFPS(fps)
            }
        }
    }
    
    func attachPreviewNode(_ node: CameraPreviewNode) {
        let nodeRef: Unmanaged<CameraPreviewNode> = Unmanaged.passRetained(node)
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.previewNode = nodeRef.takeUnretainedValue()
                nodeRef.release()
            } else {
                Queue.mainQueue().async {
                    nodeRef.release()
                }
            }
        }
    }
    
    func setProcessSampleBuffer(_ block: ((CMSampleBuffer) -> Void)?) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.processSampleBuffer = block
            }
        }
    }
}
