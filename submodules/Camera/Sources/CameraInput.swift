import AVFoundation
import TelegramCore

class CameraInput {
    var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    
    func configure(for session: CameraSession, device: CameraDevice, audio: Bool) {
        if let videoDevice = device.videoDevice {
            self.configureVideoInput(for: session, device: videoDevice)
        }
        if audio, let audioDevice = device.audioDevice {
            self.configureAudioInput(for: session, device: audioDevice)
        }
    }
    
    func invalidate(for session: CameraSession) {
        for input in session.session.inputs {
            session.session.removeInput(input)
        }
    }
    
    private func configureVideoInput(for session: CameraSession, device: AVCaptureDevice) {
        if let currentVideoInput = self.videoInput {
            session.session.removeInput(currentVideoInput)
            self.videoInput = nil
        }
        if let videoInput = try? AVCaptureDeviceInput(device: device) {
            self.videoInput = videoInput
            if session.session.canAddInput(videoInput) {
                if session.hasMultiCam {
                    session.session.addInputWithNoConnections(videoInput)
                } else {
                    session.session.addInput(videoInput)
                }
            } else {
                Logger.shared.log("Camera", "Can't add video input")
            }
        }
    }
    
    private func configureAudioInput(for session: CameraSession, device: AVCaptureDevice) {
        if let currentAudioInput = self.audioInput {
            session.session.removeInput(currentAudioInput)
            self.audioInput = nil
        }
        if let audioInput = try? AVCaptureDeviceInput(device: device) {
            self.audioInput = audioInput
            if session.session.canAddInput(audioInput) {
                session.session.addInput(audioInput)
            } else {
                Logger.shared.log("Camera", "Can't add audio input")
            }
        }
    }
}
