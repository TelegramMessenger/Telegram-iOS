import Foundation
import AVFoundation
import SwiftSignalKit

private let defaultFPS: Double = 30.0

final class CameraDevice {
    public private(set) var videoDevice: AVCaptureDevice? = nil
    public private(set) var audioDevice: AVCaptureDevice? = nil
    private var videoDevicePromise = Promise<AVCaptureDevice>()
    
    init() {
    }
    
    var position: Camera.Position = .back
    
    func configure(for session: AVCaptureSession, position: Camera.Position) {
        self.position = position
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            self.videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera, .builtInTelephotoCamera], mediaType: .video, position: position).devices.first
        } else {
            self.videoDevice = AVCaptureDevice.devices(for: .video).filter { $0.position == position }.first
        }
        if let videoDevice = self.videoDevice {
            self.videoDevicePromise.set(.single(videoDevice))
        }
        self.audioDevice = AVCaptureDevice.default(for: .audio)
    }
    
    func transaction(_ device: AVCaptureDevice, update: (AVCaptureDevice) -> Void) {
        if let _ = try? device.lockForConfiguration() {
            update(device)
            device.unlockForConfiguration()
        }
    }
    
    private func subscribeForChanges() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.subjectAreaChanged), name: Notification.Name.AVCaptureDeviceSubjectAreaDidChange, object: self.videoDevice)
    }
    
    private func unsubscribeFromChanges() {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.AVCaptureDeviceSubjectAreaDidChange, object: self.videoDevice)
    }
    
    @objc private func subjectAreaChanged() {
        
    }
    
    var fps: Double = defaultFPS {
        didSet {
            guard let device = self.videoDevice, let targetFPS = device.actualFPS(Double(self.fps)) else {
                return
            }
            
            self.fps = targetFPS.fps
            
            self.transaction(device) { device in
                device.activeVideoMinFrameDuration = targetFPS.duration
                device.activeVideoMaxFrameDuration = targetFPS.duration
            }
        }
    }
    
    /*var isFlashActive: Signal<Bool, NoError> {
        return self.videoDevicePromise.get()
        |> mapToSignal { device -> Signal<Bool, NoError> in
            return Signal { subscriber in
                subscriber.putNext(device.isFlashActive)
                let observer = device.observe(\.isFlashActive, options: [.new], changeHandler: { device, _ in
                    subscriber.putNext(device.isFlashActive)
                })
                return ActionDisposable {
                    observer.invalidate()
                }
            }
            |> distinctUntilChanged
        }
    }*/
    
    var isFlashAvailable: Signal<Bool, NoError> {
        return self.videoDevicePromise.get()
        |> mapToSignal { device -> Signal<Bool, NoError> in
            return Signal { subscriber in
                subscriber.putNext(device.isFlashAvailable)
                let observer = device.observe(\.isFlashAvailable, options: [.new], changeHandler: { device, _ in
                    subscriber.putNext(device.isFlashAvailable)
                })
                return ActionDisposable {
                    observer.invalidate()
                }
            }
            |> distinctUntilChanged
        }
    }
    
    var isAdjustingFocus: Signal<Bool, NoError> {
        return self.videoDevicePromise.get()
        |> mapToSignal { device -> Signal<Bool, NoError> in
            return Signal { subscriber in
                subscriber.putNext(device.isAdjustingFocus)
                let observer = device.observe(\.isAdjustingFocus, options: [.new], changeHandler: { device, _ in
                    subscriber.putNext(device.isAdjustingFocus)
                })
                return ActionDisposable {
                    observer.invalidate()
                }
            }
            |> distinctUntilChanged
        }
    }
    
    func setFocusPoint(_ point: CGPoint, focusMode: Camera.FocusMode, exposureMode: Camera.ExposureMode, monitorSubjectAreaChange: Bool) {
        guard let device = self.videoDevice else {
            return
        }
        self.transaction(device) { device in
            if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
                device.exposurePointOfInterest = point
                device.exposureMode = exposureMode
            }
            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
                device.focusPointOfInterest = point
                device.focusMode = focusMode
            }
        }
    }
    
    func setExposureTargetBias(_ bias: Float) {
        guard let device = self.videoDevice else {
            return
        }
        self.transaction(device) { device in
            let extremum = (bias >= 0) ? device.maxExposureTargetBias : device.minExposureTargetBias;
            let value = abs(bias) * extremum * 0.85
            device.setExposureTargetBias(value, completionHandler: nil)
        }
    }
    
    func setTorchActive(_ active: Bool) {
        guard let device = self.videoDevice else {
            return
        }
        self.transaction(device) { device in
            device.torchMode = active ? .on : .off
        }
    }
}
