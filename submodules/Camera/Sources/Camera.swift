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
    private var invalidated = false
    
    private var previousSampleBuffer: CMSampleBuffer?
    var processSampleBuffer: ((CMSampleBuffer) -> Void)?
    
    private let detectedCodesPipe = ValuePipe<[CameraCode]>()
    
    var previewNode: CameraPreviewNode? {
        didSet {
            self.previewNode?.prepare()
        }
    }
    
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
        
        self.output.processCodes = { [weak self] codes in
            self?.detectedCodesPipe.putNext(codes)
        }
    }
    
    func startCapture() {
        guard !self.session.isRunning else {
            return
        }
        
        self.session.startRunning()
    }
    
    func stopCapture(invalidate: Bool = false) {
        if invalidate {
            self.session.beginConfiguration()
            self.input.invalidate(for: self.session)
            self.output.invalidate(for: self.session)
            self.session.commitConfiguration()
        }
        
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
    
    var hasTorch: Signal<Bool, NoError> {
        return self.device.isFlashAvailable
    }
    
    func setTorchActive(_ active: Bool) {
        self.device.setTorchActive(active)
    }
    
    var detectedCodes: Signal<[CameraCode], NoError> {
        return self.detectedCodesPipe.signal()
    }
}

public final class Camera {
    public typealias Preset = AVCaptureSession.Preset
    public typealias Position = AVCaptureDevice.Position
    public typealias FocusMode = AVCaptureDevice.FocusMode
    public typealias ExposureMode = AVCaptureDevice.ExposureMode
    
    public struct Configuration {
        let preset: Preset
        let position: Position
        let audio: Bool
        
        public init(preset: Preset, position: Position, audio: Bool) {
            self.preset = preset
            self.position = position
            self.audio = audio
        }
    }
    
    private let queue = Queue()
    private var contextRef: Unmanaged<CameraContext>?
    
    public init(configuration: Camera.Configuration = Configuration(preset: .hd1920x1080, position: .back, audio: true)) {
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
    
    public func startCapture() {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.startCapture()
            }
        }
    }
    
    public func stopCapture(invalidate: Bool = false) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.stopCapture(invalidate: invalidate)
            }
        }
    }
    
    public func togglePosition() {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.togglePosition()
            }
        }
    }
    
    public func takePhoto() -> Signal<Void, NoError> {
        return .never()
    }
    
    public func focus(at point: CGPoint) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.focus(at: point)
            }
        }
    }
    
    public func setFPS(_ fps: Double) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.setFPS(fps)
            }
        }
    }
    
    public func setTorchActive(_ active: Bool) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.setTorchActive(active)
            }
        }
    }
    
    public var hasTorch: Signal<Bool, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                if let context = self.contextRef?.takeUnretainedValue() {
                    disposable.set(context.hasTorch.start(next: { hasTorch in
                        subscriber.putNext(hasTorch)
                        subscriber.putCompletion()
                    }))
                }
            }
            return disposable
        }
    }

    public func attachPreviewNode(_ node: CameraPreviewNode) {
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
    
    public func setProcessSampleBuffer(_ block: ((CMSampleBuffer) -> Void)?) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.processSampleBuffer = block
            }
        }
    }
    
    public var detectedCodes: Signal<[CameraCode], NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                if let context = self.contextRef?.takeUnretainedValue() {
                    disposable.set(context.detectedCodes.start(next: { codes in
                        subscriber.putNext(codes)
                    }))
                }
            }
            return disposable
        }
    }
}
