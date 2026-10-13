import Foundation
import UIKit
import AVFoundation
import CoreMedia
import CoreVideo
import SwiftSignalKit
import DeviceModel
import Camera

private let roundVideoFrameRate: Double = 30.0

private enum CaptureInitializationStatus {
    case pending
    case ready
    case failed(CameraRecordingError)
}

final class CameraNeo: NSObject, CameraProtocol {
    private let configuration: Camera.Configuration
    private let useMultiCam: Bool
    private let previewView: CameraPreviewView?
    private let secondaryPreviewView: CameraPreviewView?

    private let sessionQueue = DispatchQueue(label: "Camera.Session", qos: .userInitiated)
    private let mediaQueue = DispatchQueue(label: "Camera.Media", qos: .userInitiated)
    private let sessionQueueKey = DispatchSpecificKey<Void>()
    private let mediaQueueKey = DispatchSpecificKey<Void>()

    private let session: AVCaptureSession
    private var wantsRunning = false
    private var isConfigured = false
    private var isInvalidated = false

    private var backDevice: AVCaptureDevice?
    private var frontDevice: AVCaptureDevice?
    private var singleVideoInput: AVCaptureDeviceInput?
    private var backVideoInput: AVCaptureDeviceInput?
    private var frontVideoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?

    private var primaryVideoOutput: AVCaptureVideoDataOutput?
    private var secondaryVideoOutput: AVCaptureVideoDataOutput?
    private var audioOutput: AVCaptureAudioDataOutput?
    private let secondaryVideoOutputIdentity = Atomic<ObjectIdentifier?>(value: nil)
    private let audioOutputIdentity = Atomic<ObjectIdentifier?>(value: nil)

    private var singleFramesEnabled = true
    private var singleMediaPosition: Camera.Position
    private var recordingOrientation: AVCaptureVideoOrientation = .portrait

    private var frameProcessor: RoundVideoFrameProcessor?
    private var recorder: VideoRecorder?
    private let recordingActive = Atomic<Bool>(value: false)
    private let recordingStopRequested = Atomic<Bool>(value: false)
    private let recordingDuration = Atomic<Double>(value: 0.0)
    private let singleCameraSwitchGeneration = Atomic<Int>(value: 0)
    private let recordingCompletionPipe = ValuePipe<VideoCaptureResult>()
    private let captureInitializationStatus = Atomic<CaptureInitializationStatus>(value: .pending)

    private var mainVideoOutput: CameraVideoOutput?
    private var additionalVideoOutput: CameraVideoOutput?

    private let positionValue: Atomic<Camera.Position>
    private let positionPromise: ValuePromise<Camera.Position>
    private let flashModePromise = ValuePromise<Camera.FlashMode>(.off)
    private let hasTorchPromise = ValuePromise<Bool>(false)
    private let isFlashActivePromise = ValuePromise<Bool>(false)
    private let transitionImagePromise = ValuePromise<UIImage?>(nil)
    private let modeChangePromise = ValuePromise<Camera.ModeChange>(.none)

    let metrics: Camera.Metrics

    init(
        configuration: Camera.Configuration,
        previewView: CameraPreviewView?,
        secondaryPreviewView: CameraPreviewView?,
        useMultiCam: Bool
    ) {
        self.configuration = configuration
        self.previewView = previewView
        self.secondaryPreviewView = secondaryPreviewView
        self.useMultiCam = useMultiCam
        self.singleMediaPosition = configuration.position
        self.positionValue = Atomic<Camera.Position>(value: configuration.position)
        self.positionPromise = ValuePromise<Camera.Position>(configuration.position)
        self.metrics = Camera.Metrics(model: DeviceModel.current)

        if useMultiCam, #available(iOS 13.0, *) {
            self.session = AVCaptureMultiCamSession()
        } else {
            self.session = AVCaptureSession()
        }

        super.init()

        self.session.usesApplicationAudioSession = true
        self.session.automaticallyConfiguresApplicationAudioSession = false

        self.sessionQueue.setSpecific(key: self.sessionQueueKey, value: ())
        self.mediaQueue.setSpecific(key: self.mediaQueueKey, value: ())
        self.previewView?.setSession(self.session, automaticallyConnect: !useMultiCam)
        if useMultiCam {
            self.secondaryPreviewView?.setSession(self.session, automaticallyConnect: false)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.sessionRuntimeError(_:)),
            name: .AVCaptureSessionRuntimeError,
            object: self.session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.sessionInterruptionEnded(_:)),
            name: .AVCaptureSessionInterruptionEnded,
            object: self.session
        )

        self.sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        let cleanUpSession = {
            self.primaryVideoOutput?.setSampleBufferDelegate(nil, queue: nil)
            self.secondaryVideoOutput?.setSampleBufferDelegate(nil, queue: nil)
            self.audioOutput?.setSampleBufferDelegate(nil, queue: nil)
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.tearDownSession()
        }
        if DispatchQueue.getSpecific(key: self.sessionQueueKey) != nil {
            cleanUpSession()
        } else {
            self.sessionQueue.sync(execute: cleanUpSession)
        }
        if DispatchQueue.getSpecific(key: self.mediaQueueKey) != nil {
            self.recorder?.cancel()
        } else {
            self.mediaQueue.sync {
                self.recorder?.cancel()
            }
        }
    }

    func startCapture() {
        self.sessionQueue.async { [weak self] in
            guard let self, !self.isInvalidated else {
                return
            }
            self.wantsRunning = true
            if !self.isConfigured {
                self.configureSession()
            }
            if self.isConfigured && !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stopCapture(invalidate: Bool) {
        self.sessionQueue.async { [weak self] in
            guard let self else {
                return
            }
            self.wantsRunning = false
            if self.session.isRunning {
                self.session.stopRunning()
            }
            if invalidate {
                self.isInvalidated = true
                self.tearDownSession()
                DispatchQueue.main.async { [weak self] in
                    self?.previewView?.invalidate()
                    self?.secondaryPreviewView?.invalidate()
                }
            }
        }

        if invalidate {
            self.mediaQueue.async { [weak self] in
                guard let self else {
                    return
                }
                self.recorder?.cancel()
                self.recorder = nil
                let _ = self.recordingActive.modify { _ in false }
                let _ = self.recordingStopRequested.modify { _ in false }
            }
        }
    }

    var position: Signal<Camera.Position, NoError> {
        return self.positionPromise.get()
    }

    func togglePosition() {
        let currentPosition = self.positionValue.with { $0 }
        self.setPosition(currentPosition == .front ? .back : .front)
    }

    func setPosition(_ position: Camera.Position) {
        let previousPosition = self.positionValue.swap(position)
        guard previousPosition != position else {
            return
        }

        let switchGeneration = self.useMultiCam ? 0 : self.singleCameraSwitchGeneration.modify { $0 + 1 }

        self.modeChangePromise.set(.position)
        self.positionPromise.set(position)
        self.mediaQueue.async { [weak self] in
            guard let self else {
                return
            }
            if !self.useMultiCam {
                self.recorder?.beginSingleCameraSwitch(
                    generation: switchGeneration,
                    from: previousPosition,
                    to: position
                )
            }
            self.recorder?.beginPositionChange(to: position)
            if !self.useMultiCam {
                self.singleFramesEnabled = false
            }
        }

        self.sessionQueue.async { [weak self] in
            guard let self, self.isConfigured, !self.isInvalidated else {
                return
            }
            if previousPosition == .back, position == .front, let backDevice = self.backDevice {
                self.withLockedDevice(backDevice) { device in
                    if device.isTorchModeSupported(.off) {
                        device.torchMode = .off
                    }
                }
            }
            if self.useMultiCam {
                self.updateActiveDeviceState()
            } else {
                self.switchSingleCamera(to: position, generation: switchGeneration)
            }
            self.sessionQueue.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.modeChangePromise.set(.none)
            }
        }
    }

    func setDualCameraEnabled(_ enabled: Bool) {
    }

    func takePhoto() -> Signal<PhotoCaptureResult, NoError> {
        return .complete()
    }

    func startRecording() -> Signal<CameraRecordingData, CameraRecordingError> {
        guard self.configuration.isRoundVideo else {
            return .complete()
        }
        if case let .failed(error) = self.captureInitializationStatus.with({ $0 }) {
            return .fail(error)
        }

        var wasActive = false
        let _ = self.recordingActive.modify { current in
            wasActive = current
            return true
        }
        guard !wasActive else {
            return .complete()
        }
        let _ = self.recordingStopRequested.modify { _ in false }

        let outputUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
        let orientation: AVCaptureVideoOrientation
        if DeviceModel.current.isIpad {
            orientation = self.previewView?.captureOrientation ?? .portrait
        } else {
            orientation = .portrait
        }
        let _ = self.recordingDuration.modify { _ in 0.0 }
        self.transitionImagePromise.set(nil)

        return Signal { [weak self] subscriber in
            guard let self else {
                subscriber.putCompletion()
                return EmptyDisposable
            }

            let subscriberActive = Atomic<Bool>(value: true)
            let recordingPrepared = Atomic<Bool>(value: false)
            let beginRecording: (RoundVideoDecorationResources?) -> Void = { [weak self] decorationResources in
                guard let self else {
                    return
                }
                self.mediaQueue.async { [weak self] in
                    guard let self else {
                        return
                    }
                    guard subscriberActive.with({ $0 }), self.recordingActive.with({ $0 }) else {
                        let _ = self.recordingActive.modify { _ in false }
                        let _ = self.recordingStopRequested.modify { _ in false }
                        return
                    }
                    if case let .failed(error) = self.captureInitializationStatus.with({ $0 }) {
                        let _ = self.recordingActive.modify { _ in false }
                        let _ = self.recordingStopRequested.modify { _ in false }
                        if subscriberActive.swap(false) {
                            subscriber.putError(error)
                        }
                        return
                    }

                    let processor: RoundVideoFrameProcessor
                    if let current = self.frameProcessor {
                        processor = current
                    } else if let decorationResources, let current = RoundVideoFrameProcessor(mediaQueue: self.mediaQueue, decorationResources: decorationResources) {
                        self.frameProcessor = current
                        processor = current
                    } else {
                        guard let current = RoundVideoFrameProcessor(mediaQueue: self.mediaQueue, decorationResources: nil) else {
                            let _ = self.recordingActive.modify { _ in false }
                            let _ = self.recordingStopRequested.modify { _ in false }
                            if subscriberActive.swap(false) {
                                subscriber.putError(.videoRecorderInitializationError)
                            }
                            return
                        }
                        self.frameProcessor = current
                        processor = current
                    }

                    self.recordingOrientation = orientation
                    let recorder = VideoRecorder(
                        mediaQueue: self.mediaQueue,
                        processor: processor,
                        url: outputUrl,
                        hasAudio: self.configuration.audio,
                        initialPosition: self.positionValue.with { $0 },
                        durationUpdated: { [weak self] duration in
                            guard let self else {
                                return
                            }
                            let _ = self.recordingDuration.modify { _ in duration }
                        },
                        transitionImageUpdated: { [weak self] image in
                            self?.transitionImagePromise.set(image)
                        },
                        runtimeFailure: { error in
                            let wasActive = subscriberActive.swap(false)
                            if wasActive {
                                subscriber.putError(error)
                            }
                        },
                        completion: { [weak self] result in
                            guard let self else {
                                return
                            }
                            self.recorder = nil
                            let _ = self.recordingActive.modify { _ in false }
                            let _ = self.recordingStopRequested.modify { _ in false }
                            switch result {
                            case let .success(url, thumbnail, duration, positionChangeTimestamps):
                                self.recordingCompletionPipe.putNext(.finished(
                                    main: VideoCaptureResult.Result(
                                        path: url.path,
                                        thumbnail: thumbnail ?? UIImage(),
                                        isMirrored: false,
                                        dimensions: CGSize(width: RoundVideoFrameProcessor.outputWidth, height: RoundVideoFrameProcessor.outputHeight)
                                    ),
                                    additional: nil,
                                    duration: duration,
                                    positionChangeTimestamps: positionChangeTimestamps.map { ($0.0 == .front, $0.1) },
                                    captureTimestamp: CACurrentMediaTime()
                                ))
                            case .failed:
                                self.recordingCompletionPipe.putNext(.failed)
                            }
                        }
                    )
                    self.recorder = recorder
                    let _ = recordingPrepared.modify { _ in true }
                    if self.recordingStopRequested.with({ $0 }) {
                        recorder.stop()
                    }
                }
            }

            RoundVideoDecorationProvider.shared.prepare(completion: beginRecording)

            let timer = SwiftSignalKit.Timer(timeout: 0.09, repeat: true, completion: { [weak self] in
                guard let self, subscriberActive.with({ $0 }), recordingPrepared.with({ $0 }) else {
                    return
                }
                subscriber.putNext(CameraRecordingData(
                    duration: self.recordingDuration.with { $0 },
                    filePath: outputUrl.path
                ))
            }, queue: Queue.mainQueue())
            timer.start()

            return ActionDisposable {
                let _ = subscriberActive.modify { _ in false }
                timer.invalidate()
            }
        }
    }

    func stopRecording() -> Signal<VideoCaptureResult, NoError> {
        guard self.recordingActive.with({ $0 }) else {
            return .complete()
        }
        let _ = self.recordingStopRequested.modify { _ in true }
        self.mediaQueue.async { [weak self] in
            self?.recorder?.stop()
        }
        return self.recordingCompletionPipe.signal()
        |> take(1)
    }

    func focus(at point: CGPoint, autoFocus: Bool) {
        self.sessionQueue.async { [weak self] in
            guard let device = self?.activeDevice else {
                return
            }
            self?.withLockedDevice(device) { device in
                let focusMode: AVCaptureDevice.FocusMode = autoFocus ? .continuousAutoFocus : .autoFocus
                let exposureMode: AVCaptureDevice.ExposureMode = autoFocus ? .continuousAutoExposure : .autoExpose
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
                    device.focusPointOfInterest = point
                    device.focusMode = focusMode
                }
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
                    device.exposurePointOfInterest = point
                    device.exposureMode = exposureMode
                }
                device.isSubjectAreaChangeMonitoringEnabled = true
            }
        }
    }

    func setFps(_ fps: Double) {
        self.sessionQueue.async { [weak self] in
            guard let self, !self.isInvalidated else {
                return
            }
            self.session.beginConfiguration()
            if self.useMultiCam {
                if let backDevice = self.backDevice, let backVideoInput = self.backVideoInput {
                    self.configureFrameRate(fps, device: backDevice, input: backVideoInput)
                }
                if let frontDevice = self.frontDevice, let frontVideoInput = self.frontVideoInput {
                    self.configureFrameRate(fps, device: frontDevice, input: frontVideoInput)
                }
            } else if let activeDevice = self.activeDevice, let singleVideoInput = self.singleVideoInput {
                self.configureFrameRate(fps, device: activeDevice, input: singleVideoInput)
            }
            self.session.commitConfiguration()
            self.configureVideoStabilization()
        }
    }

    func setFlashMode(_ flashMode: Camera.FlashMode) {
        self.flashModePromise.set(flashMode)
    }

    func setZoomLevel(_ zoomLevel: CGFloat) {
        self.updateZoom { device in
            return 1.0 + zoomLevel
        }
    }

    func setZoomDelta(_ zoomDelta: CGFloat) {
        self.updateZoom { device in
            return device.videoZoomFactor * zoomDelta
        }
    }

    func rampZoom(_ zoomLevel: CGFloat, rate: CGFloat) {
        self.sessionQueue.async { [weak self] in
            guard let self, let device = self.activeDevice else {
                return
            }
            self.withLockedDevice(device) { device in
                device.ramp(toVideoZoomFactor: self.clampedZoom(zoomLevel, device: device), withRate: Float(rate))
            }
        }
    }

    func setTorchActive(_ active: Bool) {
        self.sessionQueue.async { [weak self] in
            guard let self, let device = self.activeDevice else {
                return
            }
            var effectiveActive = false
            self.withLockedDevice(device) { device in
                let mode: AVCaptureDevice.TorchMode = active ? .on : .off
                if device.isTorchModeSupported(mode) {
                    device.torchMode = mode
                    effectiveActive = active
                }
            }
            self.isFlashActivePromise.set(effectiveActive)
        }
    }

    var hasTorch: Signal<Bool, NoError> {
        return self.hasTorchPromise.get()
    }

    var isFlashActive: Signal<Bool, NoError> {
        return self.isFlashActivePromise.get()
    }

    var flashMode: Signal<Camera.FlashMode, NoError> {
        return self.flashModePromise.get()
    }

    func setMainVideoOutput(_ output: CameraVideoOutput?) {
        self.mediaQueue.async { [weak self] in
            self?.mainVideoOutput = output
        }
    }

    func setAdditionalVideoOutput(_ output: CameraVideoOutput?) {
        self.mediaQueue.async { [weak self] in
            self?.additionalVideoOutput = output
        }
    }

    func attachSimplePreviewView(_ view: CameraSimplePreviewView) {
    }

    var detectedCodes: Signal<[CameraCode], NoError> {
        return .never()
    }

    var audioLevel: Signal<Float, NoError> {
        return .never()
    }

    var transitionImage: Signal<UIImage?, NoError> {
        return self.transitionImagePromise.get()
    }

    var modeChange: Signal<Camera.ModeChange, NoError> {
        return self.modeChangePromise.get()
    }

    private var activeDevice: AVCaptureDevice? {
        if self.positionValue.with({ $0 }) == .front {
            return self.frontDevice
        } else {
            return self.backDevice
        }
    }

    private func configureSession() {
        dispatchPrecondition(condition: .onQueue(self.sessionQueue))
        guard !self.isConfigured, !self.isInvalidated else {
            return
        }

        self.session.beginConfiguration()
        self.session.sessionPreset = .inputPriority
        let videoConfigured: Bool
        if self.useMultiCam {
            videoConfigured = self.configureMultiCamVideo()
        } else {
            videoConfigured = self.configureSingleCameraVideo(position: self.positionValue.with { $0 }, addOutput: true)
        }
        let audioConfigured = !self.configuration.audio || self.configureAudio()
        self.session.commitConfiguration()
        self.configureVideoStabilization()

        self.isConfigured = videoConfigured && audioConfigured
        let initializationStatus: CaptureInitializationStatus
        if !videoConfigured {
            initializationStatus = .failed(.videoRecorderInitializationError)
        } else if !audioConfigured {
            initializationStatus = .failed(.audioInitializationError)
        } else {
            initializationStatus = .ready
        }
        let _ = self.captureInitializationStatus.modify { _ in initializationStatus }
        if !self.isConfigured {
            self.tearDownSession()
            if case let .failed(error) = initializationStatus {
                self.mediaQueue.async { [weak self] in
                    self?.recorder?.failInitialization(error)
                }
            }
        }
        self.updateActiveDeviceState()
        DispatchQueue.main.async { [weak self] in
            self?.previewView?.updateOrientation()
            self?.secondaryPreviewView?.updateOrientation()
        }
    }

    private func configureSingleCameraVideo(position: Camera.Position, addOutput: Bool) -> Bool {
        guard let device = self.makeVideoDevice(position: position) else {
            return false
        }
        guard self.configureCaptureFormat(device: device) else {
            return false
        }

        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: device)
        } catch {
            return false
        }
        guard self.session.canAddInput(videoInput) else {
            return false
        }
        self.session.addInput(videoInput)
        self.configureFrameRate(roundVideoFrameRate, device: device, input: videoInput)

        if addOutput {
            guard let output = self.makeVideoOutput(), self.session.canAddOutput(output) else {
                self.session.removeInput(videoInput)
                return false
            }
            self.session.addOutput(output)
            self.primaryVideoOutput = output
        }

        self.singleVideoInput = videoInput
        if position == .front {
            self.frontDevice = device
        } else {
            self.backDevice = device
        }
        return true
    }

    private func configureMultiCamVideo() -> Bool {
        guard #available(iOS 13.0, *),
              let multiCamSession = self.session as? AVCaptureMultiCamSession,
              let backDevice = self.makeVideoDevice(position: .back),
              let frontDevice = self.makeVideoDevice(position: .front) else {
            return false
        }
        guard self.configureCaptureFormat(device: backDevice), self.configureCaptureFormat(device: frontDevice) else {
            return false
        }

        guard let backInput = try? AVCaptureDeviceInput(device: backDevice),
              let frontInput = try? AVCaptureDeviceInput(device: frontDevice),
              multiCamSession.canAddInput(backInput),
              multiCamSession.canAddInput(frontInput),
              let backOutput = self.makeVideoOutput(),
              let frontOutput = self.makeVideoOutput(),
              multiCamSession.canAddOutput(backOutput),
              multiCamSession.canAddOutput(frontOutput) else {
            return false
        }

        multiCamSession.addInputWithNoConnections(backInput)
        multiCamSession.addInputWithNoConnections(frontInput)
        self.configureFrameRate(roundVideoFrameRate, device: backDevice, input: backInput)
        self.configureFrameRate(roundVideoFrameRate, device: frontDevice, input: frontInput)
        multiCamSession.addOutputWithNoConnections(backOutput)
        multiCamSession.addOutputWithNoConnections(frontOutput)

        guard self.connectVideo(
            input: backInput,
            output: backOutput,
            previewView: self.previewView,
            mirrored: false
        ), self.connectVideo(
            input: frontInput,
            output: frontOutput,
            previewView: self.secondaryPreviewView,
            mirrored: true
        ) else {
            return false
        }

        self.backDevice = backDevice
        self.frontDevice = frontDevice
        self.backVideoInput = backInput
        self.frontVideoInput = frontInput
        self.primaryVideoOutput = backOutput
        self.secondaryVideoOutput = frontOutput
        let _ = self.secondaryVideoOutputIdentity.modify { _ in ObjectIdentifier(frontOutput) }
        return true
    }

    @available(iOS 13.0, *)
    private func connectVideo(
        input: AVCaptureDeviceInput,
        output: AVCaptureVideoDataOutput,
        previewView: CameraPreviewView?,
        mirrored: Bool
    ) -> Bool {
        let videoPorts = input.ports.filter { $0.mediaType == .video }
        guard !videoPorts.isEmpty else {
            return false
        }

        let outputConnection = AVCaptureConnection(inputPorts: videoPorts, output: output)
        outputConnection.automaticallyAdjustsVideoMirroring = false
        if outputConnection.isVideoMirroringSupported {
            outputConnection.isVideoMirrored = false
        }
        guard self.session.canAddConnection(outputConnection) else {
            return false
        }
        self.session.addConnection(outputConnection)

        if let previewView, let port = videoPorts.first {
            let previewConnection = AVCaptureConnection(inputPort: port, videoPreviewLayer: previewView.videoPreviewLayer)
            previewConnection.automaticallyAdjustsVideoMirroring = false
            if previewConnection.isVideoMirroringSupported {
                previewConnection.isVideoMirrored = mirrored
            }
            guard self.session.canAddConnection(previewConnection) else {
                return false
            }
            self.session.addConnection(previewConnection)
        }
        return true
    }

    private func configureAudio() -> Bool {
        guard let audioDevice = AVCaptureDevice.default(for: .audio),
              let input = try? AVCaptureDeviceInput(device: audioDevice) else {
            return false
        }
        let output = AVCaptureAudioDataOutput()
        output.setSampleBufferDelegate(self, queue: self.mediaQueue)

        if self.useMultiCam, #available(iOS 13.0, *), let multiCamSession = self.session as? AVCaptureMultiCamSession {
            guard multiCamSession.canAddInput(input), multiCamSession.canAddOutput(output) else {
                return false
            }
            multiCamSession.addInputWithNoConnections(input)
            multiCamSession.addOutputWithNoConnections(output)
            let audioPorts = input.ports.filter { $0.mediaType == .audio }
            guard !audioPorts.isEmpty else {
                return false
            }
            let connection = AVCaptureConnection(inputPorts: audioPorts, output: output)
            guard multiCamSession.canAddConnection(connection) else {
                return false
            }
            multiCamSession.addConnection(connection)
        } else {
            guard self.session.canAddInput(input), self.session.canAddOutput(output) else {
                return false
            }
            self.session.addInput(input)
            self.session.addOutput(output)
        }

        self.audioInput = input
        self.audioOutput = output
        let _ = self.audioOutputIdentity.modify { _ in ObjectIdentifier(output) }
        return true
    }

    private func makeVideoOutput() -> AVCaptureVideoDataOutput? {
        let output = AVCaptureVideoDataOutput()
        let formats = output.availableVideoPixelFormatTypes
        let pixelFormat: OSType
        if formats.contains(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
            pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        } else if formats.contains(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
            pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        } else {
            return nil
        }
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormat
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: self.mediaQueue)
        return output
    }

    private func makeVideoDevice(position: Camera.Position) -> AVCaptureDevice? {
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) {
            return device
        }
        return AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInTrueDepthCamera],
            mediaType: .video,
            position: position
        ).devices.first
    }

    private func configureCaptureFormat(device: AVCaptureDevice) -> Bool {
        let candidates = device.formats.filter { format in
            if self.useMultiCam, #available(iOS 13.0, *), !format.isMultiCamSupported {
                return false
            }
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let mediaSubtype = CMFormatDescriptionGetMediaSubType(format.formatDescription)
            guard dimensions.width == 640, dimensions.height == 480,
                  (mediaSubtype == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange || mediaSubtype == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) else {
                return false
            }
            return format.videoSupportedFrameRateRanges.contains(where: {
                $0.minFrameRate <= roundVideoFrameRate && $0.maxFrameRate >= roundVideoFrameRate
            })
        }
        let selectedFormat = candidates.min { lhs, rhs in
            let lhsMaximumFps = lhs.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0.0
            let rhsMaximumFps = rhs.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0.0
            return lhsMaximumFps < rhsMaximumFps
        }

        guard let selectedFormat else {
            return false
        }
        do {
            try device.lockForConfiguration()
            device.activeFormat = selectedFormat
            if device.isLowLightBoostSupported {
                device.automaticallyEnablesLowLightBoostWhenAvailable = true
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
            return true
        } catch {
            return false
        }
    }

    private func configureFrameRate(_ fps: Double, device: AVCaptureDevice, input: AVCaptureDeviceInput) {
        guard fps.isFinite, fps > 0.0 else {
            return
        }
        guard let range = device.activeFormat.videoSupportedFrameRateRanges.first(where: { $0.minFrameRate <= fps && $0.maxFrameRate >= fps }) else {
            return
        }
        let effectiveFps = min(range.maxFrameRate, max(range.minFrameRate, fps))
        let duration = CMTime(seconds: 1.0 / effectiveFps, preferredTimescale: 60_000)
        self.withLockedDevice(device) { device in
            if #available(iOS 18.0, *), device.activeFormat.isAutoVideoFrameRateSupported, device.isAutoVideoFrameRateEnabled {
                device.isAutoVideoFrameRateEnabled = false
            }
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
        }
        input.videoMinFrameDurationOverride = duration
    }

    private func configureVideoStabilization() {
        dispatchPrecondition(condition: .onQueue(self.sessionQueue))
        for output in [self.primaryVideoOutput, self.secondaryVideoOutput] {
            guard let connection = output?.connection(with: .video), connection.isVideoStabilizationSupported else {
                continue
            }
            connection.preferredVideoStabilizationMode = .standard
        }
    }

    private func switchSingleCamera(to position: Camera.Position, generation: Int) {
        dispatchPrecondition(condition: .onQueue(self.sessionQueue))
        self.session.beginConfiguration()
        if let singleVideoInput = self.singleVideoInput {
            self.session.removeInput(singleVideoInput)
        }
        self.singleVideoInput = nil
        let configured = self.configureSingleCameraVideo(position: position, addOutput: false)
        self.session.commitConfiguration()
        self.configureVideoStabilization()

        if !configured {
            let error = CameraRecordingError.videoRecorderInitializationError
            let _ = self.captureInitializationStatus.modify { _ in .failed(error) }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.tearDownSession()
            self.mediaQueue.async { [weak self] in
                self?.recorder?.noteSingleCameraSwitchCommitted(generation: generation)
                self?.singleFramesEnabled = false
                self?.recorder?.failInitialization(error)
            }
            self.updateActiveDeviceState()
            return
        }

        self.mediaQueue.async { [weak self] in
            self?.recorder?.noteSingleCameraSwitchCommitted(generation: generation)
            self?.singleMediaPosition = position
            self?.singleFramesEnabled = true
        }
        self.updateActiveDeviceState()
    }

    private func updateActiveDeviceState() {
        guard let device = self.activeDevice else {
            self.hasTorchPromise.set(false)
            self.isFlashActivePromise.set(false)
            return
        }
        self.hasTorchPromise.set(device.hasTorch && device.isTorchAvailable)
        self.isFlashActivePromise.set(device.torchMode == .on)
    }

    private func updateZoom(_ value: @escaping (AVCaptureDevice) -> CGFloat) {
        self.sessionQueue.async { [weak self] in
            guard let self, let device = self.activeDevice else {
                return
            }
            self.withLockedDevice(device) { device in
                device.videoZoomFactor = self.clampedZoom(value(device), device: device)
            }
        }
    }

    private func clampedZoom(_ value: CGFloat, device: AVCaptureDevice) -> CGFloat {
        let minimum = max(1.0, device.minAvailableVideoZoomFactor)
        let maximum = max(minimum, device.maxAvailableVideoZoomFactor)
        return min(maximum, max(minimum, value))
    }

    private func withLockedDevice(_ device: AVCaptureDevice, _ update: (AVCaptureDevice) -> Void) {
        do {
            try device.lockForConfiguration()
            update(device)
            device.unlockForConfiguration()
        } catch {
        }
    }

    private func tearDownSession() {
        dispatchPrecondition(condition: .onQueue(self.sessionQueue))
        self.primaryVideoOutput?.setSampleBufferDelegate(nil, queue: nil)
        self.secondaryVideoOutput?.setSampleBufferDelegate(nil, queue: nil)
        self.audioOutput?.setSampleBufferDelegate(nil, queue: nil)

        self.session.beginConfiguration()
        for output in self.session.outputs {
            self.session.removeOutput(output)
        }
        for input in self.session.inputs {
            self.session.removeInput(input)
        }
        self.session.commitConfiguration()

        self.primaryVideoOutput = nil
        self.secondaryVideoOutput = nil
        self.audioOutput = nil
        let _ = self.secondaryVideoOutputIdentity.modify { _ in nil }
        let _ = self.audioOutputIdentity.modify { _ in nil }
        self.singleVideoInput = nil
        self.backVideoInput = nil
        self.frontVideoInput = nil
        self.audioInput = nil
        self.backDevice = nil
        self.frontDevice = nil
        self.isConfigured = false
    }

    @objc private func sessionRuntimeError(_ notification: Notification) {
        guard let errorValue = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError,
              AVError(_nsError: errorValue).code == .mediaServicesWereReset else {
            return
        }
        self.sessionQueue.async { [weak self] in
            guard let self, !self.isInvalidated else {
                return
            }
            let shouldRestart = self.wantsRunning
            let _ = self.captureInitializationStatus.modify { _ in .pending }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.tearDownSession()
            if shouldRestart {
                self.configureSession()
                if self.isConfigured {
                    self.session.startRunning()
                }
            }
        }
    }

    @objc private func sessionInterruptionEnded(_ notification: Notification) {
        self.sessionQueue.async { [weak self] in
            guard let self, self.wantsRunning, self.isConfigured, !self.isInvalidated, !self.session.isRunning else {
                return
            }
            self.session.startRunning()
        }
    }
}

extension CameraNeo: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        dispatchPrecondition(condition: .onQueue(self.mediaQueue))

        let outputIdentity = ObjectIdentifier(output)
        if self.audioOutputIdentity.with({ $0 }) == outputIdentity {
            self.recorder?.appendAudioSampleBuffer(sampleBuffer)
            return
        }

        let position: Camera.Position
        if self.useMultiCam {
            if self.secondaryVideoOutputIdentity.with({ $0 }) == outputIdentity {
                position = .front
            } else {
                position = .back
            }
        } else {
            position = self.singleMediaPosition
        }

        if !self.useMultiCam, !self.singleFramesEnabled {
            return
        }

        self.recorder?.appendVideoSampleBuffer(
            sampleBuffer,
            position: position,
            orientation: self.recordingOrientation
        )

        if self.useMultiCam {
            if position == .front {
                self.additionalVideoOutput?.push(sampleBuffer, mirror: true)
            } else {
                self.mainVideoOutput?.push(sampleBuffer, mirror: false)
            }
        } else {
            self.mainVideoOutput?.push(sampleBuffer, mirror: position == .front)
        }
    }

}
