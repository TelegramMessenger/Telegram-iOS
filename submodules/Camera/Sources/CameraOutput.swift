import AVFoundation

final class CameraOutput: NSObject {
    //private let photoOutput = CameraPhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let audioOutput = AVCaptureAudioDataOutput()
    private let metadataOutput = AVCaptureMetadataOutput()
    
    private let queue = DispatchQueue(label: "")
    
    var processSampleBuffer: ((CMSampleBuffer, AVCaptureConnection) -> Void)?
    var processQRCode: ((String, AVMetadataMachineReadableCodeObject) -> Void)?
    
    override init() {
        super.init()
        
        self.videoOutput.alwaysDiscardsLateVideoFrames = true;
        self.videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] as [String : Any]
    }
    
    deinit {
        self.videoOutput.setSampleBufferDelegate(nil, queue: nil)
        self.audioOutput.setSampleBufferDelegate(nil, queue: nil)
    }
    
    func configure(for session: AVCaptureSession) {
        if session.canAddOutput(self.videoOutput) {
            session.addOutput(self.videoOutput)
            self.videoOutput.setSampleBufferDelegate(self, queue: self.queue)
        }
        if session.canAddOutput(self.audioOutput) {
            session.addOutput(self.audioOutput)
            self.audioOutput.setSampleBufferDelegate(self, queue: self.queue)
        }
        if session.canAddOutput(self.metadataOutput) {
            session.addOutput(self.metadataOutput)
        }
    }
    
    func invalidate(for session: AVCaptureSession) {
        for output in session.outputs {
            session.removeOutput(output)
        }
    }
}

extension CameraOutput: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else {
            return
        }
        
        self.processSampleBuffer?(sampleBuffer, connection)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
    }
}

extension CameraOutput: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject, object.type == .qr, let stringValue = object.stringValue, !stringValue.isEmpty {
            self.processQRCode?(stringValue, object)
        }
    }
}
