import AVFoundation

class CameraInput {
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    
    func configure(for session: AVCaptureSession, device: CameraDevice, audio: Bool) {
        if let videoDevice = device.videoDevice {
            self.configureVideoInput(for: session, device: videoDevice)
        }
        if audio, let audioDevice = device.audioDevice {
            self.configureAudioInput(for: session, device: audioDevice)
        }
    }
    
    func invalidate(for session: AVCaptureSession) {
        for input in session.inputs {
            session.removeInput(input)
        }
    }
    
    private func configureVideoInput(for session: AVCaptureSession, device: AVCaptureDevice) {
        if let videoInput = try? AVCaptureDeviceInput(device: device) {
            if let currentVideoInput = self.videoInput {
                session.removeInput(currentVideoInput)
            }
            self.videoInput = videoInput
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            }
        }
    }
    
    private func configureAudioInput(for session: AVCaptureSession, device: AVCaptureDevice) {
        guard self.audioInput == nil else {
            return
        }
        if let audioInput = try? AVCaptureDeviceInput(device: device) {
            self.audioInput = audioInput
            if session.canAddInput(audioInput) {
                session.addInput(audioInput)
            }
        }
    }
}
