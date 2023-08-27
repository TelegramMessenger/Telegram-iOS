import Foundation
import UIKit
import SwiftSignalKit
import AVFoundation
import CoreImage
import TelegramCore

final class CameraSession {
    private let singleSession: AVCaptureSession?
    private let multiSession: Any?
    
    let hasMultiCam: Bool
        
    init() {
        if #available(iOS 13.0, *), AVCaptureMultiCamSession.isMultiCamSupported {
            self.multiSession = AVCaptureMultiCamSession()
            self.singleSession = nil
            self.hasMultiCam = true
        } else {
            self.singleSession = AVCaptureSession()
            self.multiSession = nil
            self.hasMultiCam = false
        }
        self.session.sessionPreset = .inputPriority
    }
    
    var session: AVCaptureSession {
        if #available(iOS 13.0, *), let multiSession = self.multiSession as? AVCaptureMultiCamSession {
            return multiSession
        } else if let session = self.singleSession {
            return session
        } else {
            fatalError()
        }
    }
    
    var supportsDualCam: Bool {
        return self.multiSession != nil
    }
}

final class CameraDeviceContext {
    private weak var session: CameraSession?
    private weak var previewView: CameraSimplePreviewView?
    
    private let exclusive: Bool
    private let additional: Bool
    
    let device = CameraDevice()
    let input = CameraInput()
    let output: CameraOutput
    
    init(session: CameraSession, exclusive: Bool, additional: Bool) {
        self.session = session
        self.exclusive = exclusive
        self.additional = additional
        self.output = CameraOutput(exclusive: exclusive)
    }
    
    func configure(position: Camera.Position, previewView: CameraSimplePreviewView?, audio: Bool, photo: Bool, metadata: Bool) {
        guard let session = self.session else {
            return
        }
        
        self.previewView = previewView
        
        self.device.configure(for: session, position: position, dual: !exclusive || additional)
        self.device.configureDeviceFormat(maxDimensions: self.preferredMaxDimensions, maxFramerate: self.preferredMaxFrameRate)
        self.input.configure(for: session, device: self.device, audio: audio)
        self.output.configure(for: session, device: self.device, input: self.input, previewView: previewView, audio: audio, photo: photo, metadata: metadata)
        
        self.output.configureVideoStabilization()
        
        self.device.resetZoom(neutral: self.exclusive || !self.additional)
    }
    
    func invalidate() {
        guard let session = self.session else {
            return
        }
        self.output.invalidate(for: session)
        self.input.invalidate(for: session)
    }
    
    private var preferredMaxDimensions: CMVideoDimensions {
        if self.additional {
            return CMVideoDimensions(width: 1920, height: 1440)
        } else {
            return CMVideoDimensions(width: 1920, height: 1080)
        }
    }
    
    private var preferredMaxFrameRate: Double {
        if !self.exclusive {
            return 30.0
        }
        switch DeviceModel.current {
        case .iPhone14ProMax, .iPhone13ProMax:
            return 60.0
        default:
            return 30.0
        }
    }
}

private final class CameraContext {
    private let queue: Queue
    
    private let session: CameraSession
    
    private var mainDeviceContext: CameraDeviceContext?
    private var additionalDeviceContext: CameraDeviceContext?

    private let cameraImageContext = CIContext()
    
    private let initialConfiguration: Camera.Configuration
    private var invalidated = false
    
    private let detectedCodesPipe = ValuePipe<[CameraCode]>()
    fileprivate let modeChangePromise = ValuePromise<Camera.ModeChange>(.none)
    
    var previewNode: CameraPreviewNode? {
        didSet {
            self.previewNode?.prepare()
        }
    }
    
    var previewView: CameraPreviewView?
    
    var simplePreviewView: CameraSimplePreviewView?
    var secondaryPreviewView: CameraSimplePreviewView?
    
    private var lastSnapshotTimestamp: Double = CACurrentMediaTime()
    private var lastAdditionalSnapshotTimestamp: Double = CACurrentMediaTime()
    private func savePreviewSnapshot(pixelBuffer: CVPixelBuffer, front: Bool) {
        Queue.concurrentDefaultQueue().async {
            var ciImage = CIImage(cvImageBuffer: pixelBuffer)
            let size = ciImage.extent.size
            if front {
                var transform = CGAffineTransformMakeScale(1.0, -1.0)
                transform = CGAffineTransformTranslate(transform, 0.0, -size.height)
                ciImage = ciImage.transformed(by: transform)
            }
            ciImage = ciImage.clampedToExtent().applyingGaussianBlur(sigma: 40.0).cropped(to: CGRect(origin: .zero, size: size))
            if let cgImage = self.cameraImageContext.createCGImage(ciImage, from: ciImage.extent) {
                let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
                if front {
                    CameraSimplePreviewView.saveLastFrontImage(uiImage)
                } else {
                    CameraSimplePreviewView.saveLastBackImage(uiImage)
                }
            }
        }
    }
        
    init(queue: Queue, session: CameraSession, configuration: Camera.Configuration, metrics: Camera.Metrics, previewView: CameraSimplePreviewView?, secondaryPreviewView: CameraSimplePreviewView?) {
        self.queue = queue
        self.session = session
        self.initialConfiguration = configuration
        self.simplePreviewView = previewView
        self.secondaryPreviewView = secondaryPreviewView
        
        self.positionValue = configuration.position
        self._positionPromise = ValuePromise<Camera.Position>(configuration.position)
        
        self.setDualCameraEnabled(configuration.isDualEnabled, change: false)
                        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.sessionRuntimeError),
            name: .AVCaptureSessionRuntimeError,
            object: self.session.session
        )
    }
        
    private var isSessionRunning = false
    func startCapture() {
        guard !self.session.session.isRunning else {
            return
        }
        self.session.session.startRunning()
        self.isSessionRunning = self.session.session.isRunning
    }
    
    func stopCapture(invalidate: Bool = false) {
        if invalidate {
            self.mainDeviceContext?.device.resetZoom()
            
            self.configure {
                self.mainDeviceContext?.invalidate()
            }
        }
        
        self.session.session.stopRunning()
    }
    
    func focus(at point: CGPoint, autoFocus: Bool) {
        let focusMode: AVCaptureDevice.FocusMode
        let exposureMode: AVCaptureDevice.ExposureMode
        if autoFocus {
            focusMode = .continuousAutoFocus
            exposureMode = .continuousAutoExposure
        } else {
            focusMode = .autoFocus
            exposureMode = .autoExpose
        }
        self.mainDeviceContext?.device.setFocusPoint(point, focusMode: focusMode, exposureMode: exposureMode, monitorSubjectAreaChange: true)
    }
    
    func setFps(_ fps: Float64) {
        self.mainDeviceContext?.device.fps = fps
    }
    
    private var modeChange: Camera.ModeChange = .none {
        didSet {
            if oldValue != self.modeChange {
                self.modeChangePromise.set(self.modeChange)
            }
        }
    }
    
    private var _positionPromise: ValuePromise<Camera.Position>
    var position: Signal<Camera.Position, NoError> {
        return self._positionPromise.get()
    }
    
    private var positionValue: Camera.Position = .back
    func togglePosition() {
        guard let mainDeviceContext = self.mainDeviceContext else {
            return
        }
        if self.isDualCameraEnabled == true {
            let targetPosition: Camera.Position
            if case .back = self.positionValue {
                targetPosition = .front
            } else {
                targetPosition = .back
            }
            self.positionValue = targetPosition
            self._positionPromise.set(targetPosition)
            
            mainDeviceContext.output.markPositionChange(position: targetPosition)
        } else {
            self.configure {
                self.mainDeviceContext?.invalidate()
                
                let targetPosition: Camera.Position
                if case .back = mainDeviceContext.device.position {
                    targetPosition = .front
                } else {
                    targetPosition = .back
                }
                self.positionValue = targetPosition
                self._positionPromise.set(targetPosition)
                self.modeChange = .position
                
                mainDeviceContext.configure(position: targetPosition, previewView: self.simplePreviewView, audio: self.initialConfiguration.audio, photo: self.initialConfiguration.photo, metadata: self.initialConfiguration.metadata)
                
                self.queue.after(0.5) {
                    self.modeChange = .none
                }
            }
        }
    }
    
    public func setPosition(_ position: Camera.Position) {
        self.configure {
            self.mainDeviceContext?.invalidate()
            
            self._positionPromise.set(position)
            self.positionValue = position
            self.modeChange = .position
            
            self.mainDeviceContext?.configure(position: position, previewView: self.simplePreviewView, audio: self.initialConfiguration.audio, photo: self.initialConfiguration.photo, metadata: self.initialConfiguration.metadata)
                        
            self.queue.after(0.5) {
                self.modeChange = .none
            }
        }
    }
    
    private var isDualCameraEnabled: Bool?
    public func setDualCameraEnabled(_ enabled: Bool, change: Bool = true) {
        guard enabled != self.isDualCameraEnabled else {
            return
        }
        self.isDualCameraEnabled = enabled
        
        if change {
            self.modeChange = .dualCamera
        }
        
        if enabled {
            self.configure {
                self.mainDeviceContext?.invalidate()
                self.mainDeviceContext = CameraDeviceContext(session: self.session, exclusive: false, additional: false)
                self.mainDeviceContext?.configure(position: .back, previewView: self.simplePreviewView, audio: self.initialConfiguration.audio, photo: self.initialConfiguration.photo, metadata: self.initialConfiguration.metadata)
            
                self.additionalDeviceContext = CameraDeviceContext(session: self.session, exclusive: false, additional: true)
                self.additionalDeviceContext?.configure(position: .front, previewView: self.secondaryPreviewView, audio: false, photo: true, metadata: false)
            }
            self.mainDeviceContext?.output.processSampleBuffer = { [weak self] sampleBuffer, pixelBuffer, connection in
                guard let self, let mainDeviceContext = self.mainDeviceContext else {
                    return
                }
                self.previewNode?.enqueue(sampleBuffer)
                
                let timestamp = CACurrentMediaTime()
                if timestamp > self.lastSnapshotTimestamp + 2.5, !mainDeviceContext.output.isRecording {
                    var front = false
                    if #available(iOS 13.0, *) {
                        front = connection.inputPorts.first?.sourceDevicePosition == .front
                    }
                    self.savePreviewSnapshot(pixelBuffer: pixelBuffer, front: front)
                    self.lastSnapshotTimestamp = timestamp
                }
            }
            self.additionalDeviceContext?.output.processSampleBuffer = { [weak self] sampleBuffer, pixelBuffer, connection in
                guard let self, let additionalDeviceContext = self.additionalDeviceContext else {
                    return
                }
                let timestamp = CACurrentMediaTime()
                if timestamp > self.lastAdditionalSnapshotTimestamp + 2.5, !additionalDeviceContext.output.isRecording {
                    var front = false
                    if #available(iOS 13.0, *) {
                        front = connection.inputPorts.first?.sourceDevicePosition == .front
                    }
                    self.savePreviewSnapshot(pixelBuffer: pixelBuffer, front: front)
                    self.lastAdditionalSnapshotTimestamp = timestamp
                }
            }
        } else {
            self.configure {
                self.mainDeviceContext?.invalidate()
                self.additionalDeviceContext?.invalidate()
                self.additionalDeviceContext = nil
                
                self.mainDeviceContext = CameraDeviceContext(session: self.session, exclusive: true, additional: false)
                self.mainDeviceContext?.configure(position: self.positionValue, previewView: self.simplePreviewView, audio: self.initialConfiguration.audio, photo: self.initialConfiguration.photo, metadata: self.initialConfiguration.metadata)
            }
            self.mainDeviceContext?.output.processSampleBuffer = { [weak self] sampleBuffer, pixelBuffer, connection in
                guard let self, let mainDeviceContext = self.mainDeviceContext else {
                    return
                }
                self.previewNode?.enqueue(sampleBuffer)
                
                let timestamp = CACurrentMediaTime()
                if timestamp > self.lastSnapshotTimestamp + 2.5, !mainDeviceContext.output.isRecording {
                    var front = false
                    if #available(iOS 13.0, *) {
                        front = connection.inputPorts.first?.sourceDevicePosition == .front
                    }
                    self.savePreviewSnapshot(pixelBuffer: pixelBuffer, front: front)
                    self.lastSnapshotTimestamp = timestamp
                }
            }
            self.mainDeviceContext?.output.processCodes = { [weak self] codes in
                self?.detectedCodesPipe.putNext(codes)
            }
        }
        
        if change {
            if #available(iOS 13.0, *), let previewView = self.simplePreviewView {
                if enabled, let secondaryPreviewView = self.secondaryPreviewView {
                    let _ = (combineLatest(previewView.isPreviewing, secondaryPreviewView.isPreviewing)
                             |> map { first, second in
                        return first && second
                    }
                    |> filter { $0 }
                    |> take(1)
                    |> delay(0.1, queue: self.queue)
                    |> deliverOn(self.queue)).start(next: { [weak self] _ in
                        self?.modeChange = .none
                    })
                } else {
                    let _ = (previewView.isPreviewing
                    |> filter { $0 }
                    |> take(1)
                    |> deliverOn(self.queue)).start(next: { [weak self] _ in
                        self?.modeChange = .none
                    })
                }
            } else {
                self.queue.after(0.4) {
                    self.modeChange = .none
                }
            }
        }
    }
    
    private func configure(_ f: () -> Void) {
        self.session.session.beginConfiguration()
        f()
        self.session.session.commitConfiguration()
    }
    
    var hasTorch: Signal<Bool, NoError> {
        return self.mainDeviceContext?.device.isTorchAvailable ?? .never()
    }
    
    func setTorchActive(_ active: Bool) {
        self.mainDeviceContext?.device.setTorchActive(active)
    }
    
    var isFlashActive: Signal<Bool, NoError> {
        return self.mainDeviceContext?.output.isFlashActive ?? .never()
    }
    
    private var _flashMode: Camera.FlashMode = .off {
        didSet {
            self._flashModePromise.set(self._flashMode)
        }
    }
    private var _flashModePromise = ValuePromise<Camera.FlashMode>(.off)
    var flashMode: Signal<Camera.FlashMode, NoError> {
        return self._flashModePromise.get()
    }
    
    func setFlashMode(_ mode: Camera.FlashMode) {
        self._flashMode = mode
    }
    
    func setZoomLevel(_ zoomLevel: CGFloat) {
        self.mainDeviceContext?.device.setZoomLevel(zoomLevel)
    }
    
    func setZoomDelta(_ zoomDelta: CGFloat) {
        self.mainDeviceContext?.device.setZoomDelta(zoomDelta)
    }
    
    func takePhoto() -> Signal<PhotoCaptureResult, NoError> {
        guard let mainDeviceContext = self.mainDeviceContext else {
            return .complete()
        }
        let orientation = self.simplePreviewView?.videoPreviewLayer.connection?.videoOrientation ?? .portrait
        if let additionalDeviceContext = self.additionalDeviceContext {
            let dualPosition = self.positionValue
            return combineLatest(
                mainDeviceContext.output.takePhoto(orientation: orientation, flashMode: self._flashMode),
                additionalDeviceContext.output.takePhoto(orientation: orientation, flashMode: self._flashMode)
            ) |> map { main, additional in
                if case let .finished(mainImage, _, _) = main, case let .finished(additionalImage, _, _) = additional {
                    if dualPosition == .front {
                        return .finished(additionalImage, mainImage, CACurrentMediaTime())
                    } else {
                        return .finished(mainImage, additionalImage, CACurrentMediaTime())
                    }
                } else {
                    return .began
                }
            } |> distinctUntilChanged
        } else {
            return mainDeviceContext.output.takePhoto(orientation: orientation, flashMode: self._flashMode)
        }
    }
    
    public func startRecording() -> Signal<Double, NoError> {
        guard let mainDeviceContext = self.mainDeviceContext else {
            return .complete()
        }
        mainDeviceContext.device.setTorchMode(self._flashMode)
        
        let orientation = self.simplePreviewView?.videoPreviewLayer.connection?.videoOrientation ?? .portrait
        if let additionalDeviceContext = self.additionalDeviceContext {
            return combineLatest(
                mainDeviceContext.output.startRecording(isDualCamera: true, position: self.positionValue, orientation: orientation),
                additionalDeviceContext.output.startRecording(isDualCamera: true, orientation: .portrait)
            ) |> map { value, _ in
                return value
            }
        } else {
            return mainDeviceContext.output.startRecording(isDualCamera: false, orientation: orientation)
        }
    }
    
    public func stopRecording() -> Signal<VideoCaptureResult, NoError> {
        guard let mainDeviceContext = self.mainDeviceContext else {
            return .complete()
        }
        if let additionalDeviceContext = self.additionalDeviceContext {
            return combineLatest(
                mainDeviceContext.output.stopRecording(),
                additionalDeviceContext.output.stopRecording()
            ) |> mapToSignal { main, additional in
                if case let .finished(mainResult, _, duration, positionChangeTimestamps, _) = main, case let .finished(additionalResult, _, _, _, _) = additional {
                    var additionalTransitionImage = additionalResult.1
                    if let cgImage = additionalResult.1.cgImage {
                        additionalTransitionImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .leftMirrored)
                    }
                    return .single(.finished(mainResult, (additionalResult.0, additionalTransitionImage, true, additionalResult.3), duration, positionChangeTimestamps, CACurrentMediaTime()))
                } else {
                    return .complete()
                }
            }
        } else {
            let mirror = self.positionValue == .front
            return mainDeviceContext.output.stopRecording()
            |> map { result -> VideoCaptureResult in
                if case let .finished(mainResult, _, duration, positionChangeTimestamps, time) = result {
                    var transitionImage = mainResult.1
                    if mirror, let cgImage = transitionImage.cgImage {
                        transitionImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .leftMirrored)
                    }
                    return .finished((mainResult.0, transitionImage, mirror, mainResult.3), nil, duration, positionChangeTimestamps, time)
                } else {
                    return result
                }
            }
        }
    }
    
    var detectedCodes: Signal<[CameraCode], NoError> {
        return self.detectedCodesPipe.signal()
    }
    
    @objc private func sessionInterruptionEnded(notification: NSNotification) {
    }
    
    @objc private func sessionRuntimeError(notification: NSNotification) {
        guard let errorValue = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError else {
            return
        }
        
        let error = AVError(_nsError: errorValue)
        Logger.shared.log("Camera", "Runtime error: \(error)")
    
        if error.code == .mediaServicesWereReset {
            self.queue.async {
                if self.isSessionRunning {
                    self.session.session.startRunning()
                    self.isSessionRunning = self.session.session.isRunning
                }
            }
        }
    }
}

public final class Camera {
    public typealias Preset = AVCaptureSession.Preset
    public typealias Position = AVCaptureDevice.Position
    public typealias FocusMode = AVCaptureDevice.FocusMode
    public typealias ExposureMode = AVCaptureDevice.ExposureMode
    public typealias FlashMode = AVCaptureDevice.FlashMode
    
    public struct Configuration {
        let preset: Preset
        let position: Position
        let isDualEnabled: Bool
        let audio: Bool
        let photo: Bool
        let metadata: Bool
        let preferredFps: Double
        
        public init(preset: Preset, position: Position, isDualEnabled: Bool = false, audio: Bool, photo: Bool, metadata: Bool, preferredFps: Double) {
            self.preset = preset
            self.position = position
            self.isDualEnabled = isDualEnabled
            self.audio = audio
            self.photo = photo
            self.metadata = metadata
            self.preferredFps = preferredFps
        }
    }
    
    private let queue = Queue()
    private var contextRef: Unmanaged<CameraContext>?

    private weak var previewView: CameraPreviewView?
    
    public let metrics: Camera.Metrics
    
    public init(configuration: Camera.Configuration = Configuration(preset: .hd1920x1080, position: .back, audio: true, photo: false, metadata: false, preferredFps: 60.0), previewView: CameraSimplePreviewView? = nil, secondaryPreviewView: CameraSimplePreviewView? = nil) {
        self.metrics = Camera.Metrics(model: DeviceModel.current)
        
        let session = CameraSession()
        session.session.usesApplicationAudioSession = true
        session.session.automaticallyConfiguresApplicationAudioSession = false
        session.session.automaticallyConfiguresCaptureDeviceForWideColor = false
        if let previewView {
            previewView.setSession(session.session, autoConnect: !session.hasMultiCam)
        }
        if let secondaryPreviewView, session.hasMultiCam {
            secondaryPreviewView.setSession(session.session, autoConnect: false)
        }
        
        self.queue.async {
            let context = CameraContext(queue: self.queue, session: session, configuration: configuration, metrics: self.metrics, previewView: previewView, secondaryPreviewView: secondaryPreviewView)
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
#if targetEnvironment(simulator)
#else
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.startCapture()
            }
        }
#endif
    }
    
    public func stopCapture(invalidate: Bool = false) {
#if targetEnvironment(simulator)
#else
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.stopCapture(invalidate: invalidate)
            }
        }
#endif
    }
    
    public var position: Signal<Camera.Position, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                if let context = self.contextRef?.takeUnretainedValue() {
                    disposable.set(context.position.start(next: { flashMode in
                        subscriber.putNext(flashMode)
                    }, completed: {
                        subscriber.putCompletion()
                    }))
                }
            }
            return disposable
        }
    }
    
    public func togglePosition() {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.togglePosition()
            }
        }
    }
    
    public func setPosition(_ position: Camera.Position) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.setPosition(position)
            }
        }
    }
    
    public func setDualCameraEnabled(_ enabled: Bool) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.setDualCameraEnabled(enabled)
            }
        }
    }
    
    public func takePhoto() -> Signal<PhotoCaptureResult, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                if let context = self.contextRef?.takeUnretainedValue() {
                    disposable.set(context.takePhoto().start(next: { value in
                        subscriber.putNext(value)
                    }, completed: {
                        subscriber.putCompletion()
                    }))
                }
            }
            return disposable
        }
    }
    
    public func startRecording() -> Signal<Double, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                if let context = self.contextRef?.takeUnretainedValue() {
                    disposable.set(context.startRecording().start(next: { value in
                        subscriber.putNext(value)
                    }, completed: {
                        subscriber.putCompletion()
                    }))
                }
            }
            return disposable
        }
    }
    
    public func stopRecording() -> Signal<VideoCaptureResult, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                if let context = self.contextRef?.takeUnretainedValue() {
                    disposable.set(context.stopRecording().start(next: { value in
                        subscriber.putNext(value)
                    }, completed: {
                        subscriber.putCompletion()
                    }))
                }
            }
            return disposable
        }
    }
    
    public func focus(at point: CGPoint, autoFocus: Bool = true) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.focus(at: point, autoFocus: autoFocus)
            }
        }
    }
    
    public func setFps(_ fps: Double) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.setFps(fps)
            }
        }
    }
    
    public func setFlashMode(_ flashMode: FlashMode) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.setFlashMode(flashMode)
            }
        }
    }
    
    public func setZoomLevel(_ zoomLevel: CGFloat) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.setZoomLevel(zoomLevel)
            }
        }
    }
    
    
    public func setZoomDelta(_ zoomDelta: CGFloat) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.setZoomDelta(zoomDelta)
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
                    }, completed: {
                        subscriber.putCompletion()
                    }))
                }
            }
            return disposable
        }
    }
    
    public var isFlashActive: Signal<Bool, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                if let context = self.contextRef?.takeUnretainedValue() {
                    disposable.set(context.isFlashActive.start(next: { isFlashActive in
                        subscriber.putNext(isFlashActive)
                    }, completed: {
                        subscriber.putCompletion()
                    }))
                }
            }
            return disposable
        }
    }
    
    public var flashMode: Signal<Camera.FlashMode, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                if let context = self.contextRef?.takeUnretainedValue() {
                    disposable.set(context.flashMode.start(next: { flashMode in
                        subscriber.putNext(flashMode)
                    }, completed: {
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
    
    public func attachPreviewView(_ view: CameraPreviewView) {
        self.previewView = view
        let viewRef: Unmanaged<CameraPreviewView> = Unmanaged.passRetained(view)
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.previewView = viewRef.takeUnretainedValue()
                viewRef.release()
            } else {
                Queue.mainQueue().async {
                    viewRef.release()
                }
            }
        }
    }
    
    public func attachSimplePreviewView(_ view: CameraSimplePreviewView) {
        let viewRef: Unmanaged<CameraSimplePreviewView> = Unmanaged.passRetained(view)
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.simplePreviewView = viewRef.takeUnretainedValue()
                viewRef.release()
            } else {
                Queue.mainQueue().async {
                    viewRef.release()
                }
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
    
    public enum ModeChange: Equatable {
        case none
        case position
        case dualCamera
    }
    public var modeChange: Signal<ModeChange, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                if let context = self.contextRef?.takeUnretainedValue() {
                    disposable.set(context.modeChangePromise.get().start(next: { value in
                        subscriber.putNext(value)
                    }))
                }
            }
            return disposable
        }
    }
    
    public static var isDualCameraSupported: Bool {
        if #available(iOS 13.0, *), AVCaptureMultiCamSession.isMultiCamSupported && !DeviceModel.current.isIpad {
            return true
        } else {
            return false
        }
    }
}

public final class CameraHolder {
    public let camera: Camera
    public let previewView: CameraPreviewView
    
    public init(camera: Camera, previewView: CameraPreviewView) {
        self.camera = camera
        self.previewView = previewView
    }
}
