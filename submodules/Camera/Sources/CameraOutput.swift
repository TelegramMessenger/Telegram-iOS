import AVFoundation
import SwiftSignalKit
import Vision

public struct CameraCode: Equatable {
    public enum CodeType {
        case qr
    }
    
    public let type: CodeType
    public let message: String
    public let corners: [CGPoint]
    
    public init(type: CameraCode.CodeType, message: String, corners: [CGPoint]) {
        self.type = type
        self.message = message
        self.corners = corners
    }
    
    public var boundingBox: CGRect {
        let x = self.corners.map { $0.x }
        let y = self.corners.map { $0.y }
        if let minX = x.min(), let minY = y.min(), let maxX = x.max(), let maxY = y.max() {
            return CGRect(x: minX, y: minY, width: abs(maxX - minX), height: abs(maxY - minY))
        }
        return CGRect.null
    }
    
    public static func == (lhs: CameraCode, rhs: CameraCode) -> Bool {
        if lhs.type != rhs.type {
            return false
        }
        if lhs.message != rhs.message {
            return false
        }
        if lhs.corners != rhs.corners {
            return false
        }
        return true
    }
}

final class CameraOutput: NSObject {
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let audioOutput = AVCaptureAudioDataOutput()
    private let metadataOutput = AVCaptureMetadataOutput()
    private let faceLandmarksOutput = FaceLandmarksDataOutput()
    
    private let queue = DispatchQueue(label: "")
    private let metadataQueue = DispatchQueue(label: "")
    private let faceLandmarksQueue = DispatchQueue(label: "")
    
    private var photoCaptureRequests: [Int64: PhotoCaptureContext] = [:]
    private var videoRecorder: VideoRecorder?
    
    var activeFilter: CameraFilter?
    var faceLandmarks: Bool = false
    
    var processSampleBuffer: ((CVImageBuffer, AVCaptureConnection) -> Void)?
    var processCodes: (([CameraCode]) -> Void)?
    var processFaceLandmarks: (([VNFaceObservation]) -> Void)?
    
    override init() {
        super.init()

        self.videoOutput.alwaysDiscardsLateVideoFrames = false
        //self.videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA] as [String : Any]
        self.videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] as [String : Any]
        
        self.faceLandmarksOutput.outputFaceObservations = { [weak self] observations in
            if let self {
                self.processFaceLandmarks?(observations)
            }
        }
    }
    
    deinit {
        self.videoOutput.setSampleBufferDelegate(nil, queue: nil)
        self.audioOutput.setSampleBufferDelegate(nil, queue: nil)
    }
    
    func configure(for session: AVCaptureSession, configuration: Camera.Configuration) {
        if session.canAddOutput(self.videoOutput) {
            session.addOutput(self.videoOutput)
            self.videoOutput.setSampleBufferDelegate(self, queue: self.queue)
        }
        if configuration.audio, session.canAddOutput(self.audioOutput) {
            session.addOutput(self.audioOutput)
            self.audioOutput.setSampleBufferDelegate(self, queue: self.queue)
        }
        if configuration.photo, session.canAddOutput(self.photoOutput) {
            session.addOutput(self.photoOutput)
        }
        if configuration.metadata, session.canAddOutput(self.metadataOutput) {
            session.addOutput(self.metadataOutput)
            
            self.metadataOutput.setMetadataObjectsDelegate(self, queue: self.metadataQueue)
            if self.metadataOutput.availableMetadataObjectTypes.contains(.qr) {
                self.metadataOutput.metadataObjectTypes = [.qr]
            }
        }
    }
    
    func invalidate(for session: AVCaptureSession) {
        for output in session.outputs {
            session.removeOutput(output)
        }
    }
    
    func configureVideoStabilization() {
        if let videoDataOutputConnection = self.videoOutput.connection(with: .video), videoDataOutputConnection.isVideoStabilizationSupported {
            if #available(iOS 13.0, *) {
                videoDataOutputConnection.preferredVideoStabilizationMode = .cinematicExtended
            } else {
                videoDataOutputConnection.preferredVideoStabilizationMode = .cinematic
            }
        }
    }
    
    var isFlashActive: Signal<Bool, NoError> {
        return Signal { [weak self] subscriber in
            guard let self else {
                return EmptyDisposable
            }
            subscriber.putNext(self.photoOutput.isFlashScene)
            let observer = self.photoOutput.observe(\.isFlashScene, options: [.new], changeHandler: { device, _ in
                subscriber.putNext(self.photoOutput.isFlashScene)
            })
            return ActionDisposable {
                observer.invalidate()
            }
        }
        |> distinctUntilChanged
    }
    
    func takePhoto(orientation: AVCaptureVideoOrientation, flashMode: AVCaptureDevice.FlashMode) -> Signal<PhotoCaptureResult, NoError> {
        if let connection = self.photoOutput.connection(with: .video) {
            connection.videoOrientation = orientation
        }
        
//        var settings = AVCapturePhotoSettings()
//        if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
//            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
//        }
        let settings = AVCapturePhotoSettings(format: [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)])
        settings.flashMode = flashMode
        if let previewPhotoPixelFormatType = settings.availablePreviewPhotoPixelFormatTypes.first {
            settings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPhotoPixelFormatType]
        }
        if #available(iOS 13.0, *) {
            settings.photoQualityPrioritization = .balanced
        }
        
        let uniqueId = settings.uniqueID
        let photoCapture = PhotoCaptureContext(settings: settings, filter: self.activeFilter)
        self.photoCaptureRequests[uniqueId] = photoCapture
        self.photoOutput.capturePhoto(with: settings, delegate: photoCapture)
        
        return photoCapture.signal
        |> afterDisposed { [weak self] in
            self?.photoCaptureRequests.removeValue(forKey: uniqueId)
        }
    }
    
    private var recordingCompletionPipe = ValuePipe<String?>()
    func startRecording() -> Signal<Double, NoError> {
        guard self.videoRecorder == nil else {
            return .complete()
        }
        
        guard let videoSettings = self.videoOutput.recommendedVideoSettings(forVideoCodecType: .h264, assetWriterOutputFileType: .mp4) else {
            return .complete()
        }
        guard let audioSettings = self.audioOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mp4) else {
            return .complete()
        }
        
        let outputFileName = NSUUID().uuidString
        let outputFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(outputFileName).appendingPathExtension("mp4")
        let outputFilePath = outputFileURL.absoluteString
        let videoRecorder = VideoRecorder(preset: MediaPreset(videoSettings: videoSettings, audioSettings: audioSettings), videoTransform: CGAffineTransform(rotationAngle: .pi / 2.0), fileUrl: outputFileURL, completion: { [weak self] result in
            if case .success = result {
                self?.recordingCompletionPipe.putNext(outputFilePath)
            } else {
                self?.recordingCompletionPipe.putNext(nil)
            }
        })
        
        videoRecorder.start()
        self.videoRecorder = videoRecorder
        
        return Signal { subscriber in
            let timer = SwiftSignalKit.Timer(timeout: 0.1, repeat: true, completion: { [weak videoRecorder] in
                subscriber.putNext(videoRecorder?.duration ?? 0.0)
            }, queue: Queue.mainQueue())
            timer.start()
            
            return ActionDisposable {
                timer.invalidate()
            }
        }
    }
    
    func stopRecording() -> Signal<String?, NoError> {
        self.videoRecorder?.stop()
        
        return self.recordingCompletionPipe.signal()
        |> take(1)
        |> afterDisposed {
            self.videoRecorder = nil
        }
    }
}

extension CameraOutput: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else {
            return
        }
        
        if self.faceLandmarks {
            self.faceLandmarksQueue.async {
                self.faceLandmarksOutput.process(sampleBuffer: sampleBuffer)
            }
        }
        
//        let finalSampleBuffer: CMSampleBuffer = sampleBuffer
//        if let videoPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer), let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) {
//            var finalVideoPixelBuffer = videoPixelBuffer
//            if let filter = self.activeFilter {
//                if !filter.isPrepared {
//                    filter.prepare(with: formatDescription, outputRetainedBufferCountHint: 3)
//                }
//
//                guard let filteredBuffer = filter.render(pixelBuffer: finalVideoPixelBuffer) else {
//                    return
//                }
//                finalVideoPixelBuffer = filteredBuffer
//            }
//            self.processSampleBuffer?(finalVideoPixelBuffer, connection)
//        }
        
        if let videoRecorder = self.videoRecorder, videoRecorder.isRecording || videoRecorder.isStopping {
            let mediaType = sampleBuffer.type
            if mediaType == kCMMediaType_Video {
                videoRecorder.appendVideo(sampleBuffer: sampleBuffer)
            } else if mediaType == kCMMediaType_Audio {
                videoRecorder.appendAudio(sampleBuffer: sampleBuffer)
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
    }
}

extension CameraOutput: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        let codes: [CameraCode] = metadataObjects.filter { $0.type == .qr }.compactMap { object in
            if let object = object as? AVMetadataMachineReadableCodeObject, let stringValue = object.stringValue, !stringValue.isEmpty {
                #if targetEnvironment(simulator)
                return CameraCode(type: .qr, message: stringValue, corners: [CGPoint(), CGPoint(), CGPoint(), CGPoint()])
                #else
                return CameraCode(type: .qr, message: stringValue, corners: object.corners)
                #endif
            } else {
                return nil
            }
        }
        self.processCodes?(codes)
    }
}
