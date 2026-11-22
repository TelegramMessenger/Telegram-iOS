import Foundation
import AVFoundation
import SwiftSignalKit
import Camera
import TelegramCore

private let defaultFPS: Double = 30.0

final class CameraDevice {
    var position: Camera.Position = .back
    var queue: Queue?
    
    deinit {
        if let videoDevice = self.videoDevice {
            self.unsubscribeFromChanges(videoDevice)
        }
    }
    
    private(set) var videoDevice: AVCaptureDevice? = nil {
        didSet {
            if let previousVideoDevice = oldValue {
                self.unsubscribeFromChanges(previousVideoDevice)
            }
            self.videoDevicePromise.set(.single(self.videoDevice))
            if let videoDevice = self.videoDevice {
                self.subscribeForChanges(videoDevice)
            }
        }
    }
    private var videoDevicePromise = Promise<AVCaptureDevice?>()
    
    private(set) var audioDevice: AVCaptureDevice? = nil
        
    func configure(for session: CameraSession, position: Camera.Position, dual: Bool, switchAudio: Bool) {
        self.position = position
        
        var selectedDevice: AVCaptureDevice?
        if #available(iOS 13.0, *), position != .front && !dual {
            if let device = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: position) {
                selectedDevice = device
            } else if let device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: position) {
                selectedDevice = device
            } else if let device = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: position) {
                selectedDevice = device
            } else if let device = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInTelephotoCamera], mediaType: .video, position: position).devices.first {
                selectedDevice = device
            }
        } else {
            if selectedDevice == nil {
                selectedDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInTelephotoCamera], mediaType: .video, position: position).devices.first
            }
        }
        
        if selectedDevice == nil, #available(iOS 13.0, *) {
            let allDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInTripleCamera, .builtInTelephotoCamera, .builtInDualWideCamera, .builtInTrueDepthCamera, .builtInWideAngleCamera, .builtInUltraWideCamera], mediaType: .video, position: position).devices
            Logger.shared.log("Camera", "No device selected, availabled devices: \(allDevices)")
        }
        
        self.videoDevice = selectedDevice
        self.videoDevicePromise.set(.single(selectedDevice))
        
        if switchAudio {
            self.audioDevice = AVCaptureDevice.default(for: .audio)
        }
    }
    
    private(set) var photoDimensions: CMVideoDimensions?
    
    func configureDeviceFormat(maxDimensions: CMVideoDimensions, maxFramerate: Double, captureMode: CameraCaptureMode? = nil) {
        guard let device = self.videoDevice else {
            return
        }
        self.photoDimensions = nil
        self.transaction(device) { device in
            var formats: [AVCaptureDevice.Format] = []
            var descriptors: [CameraFormatDescriptor] = []
            for format in device.formats {
                if format.mediaType != .video || format.value(forKey: "isPhotoFormat") as? Bool == true {
                    continue
                }
                descriptors.append(cameraFormatDescriptor(format, index: formats.count))
                formats.append(format)
            }
            
            let rule = cameraFormatRule(captureMode: captureMode, legacyMaxDimensions: CameraFormatDescriptor.Dimensions(width: maxDimensions.width, height: maxDimensions.height))
            if let bestDescriptor = cameraPreferredFormat(formats: descriptors, rule: rule, maxFramerate: maxFramerate) {
                let bestFormat = formats[bestDescriptor.index]
                device.activeFormat = bestFormat
                
                if case .photo = rule, let photoDimensions = cameraPreferredPhotoDimensions(for: bestDescriptor) {
                    self.photoDimensions = CMVideoDimensions(width: photoDimensions.width, height: photoDimensions.height)
                }
                    
                Logger.shared.log("Camera", "Selected format:")
                Logger.shared.log("Camera", bestFormat.description)
            } else {
                Logger.shared.log("Camera", "No format selected")
            }
            
            #if DEBUG
            Logger.shared.log("Camera", "Available formats:")
            for format in device.formats {
                Logger.shared.log("Camera", format.description)
            }
            #endif
            
            if let targetFPS = device.actualFPS(maxFramerate) {
                device.activeVideoMinFrameDuration = targetFPS.duration
                device.activeVideoMaxFrameDuration = targetFPS.duration
            }
            
            if device.isLowLightBoostSupported {
                device.automaticallyEnablesLowLightBoostWhenAvailable = true
            }
                        
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
        }
    }
    
    func transaction(_ device: AVCaptureDevice, update: (AVCaptureDevice) -> Void) {
        if let _ = try? device.lockForConfiguration() {
            update(device)
            device.unlockForConfiguration()
        }
    }
    
    private func subscribeForChanges(_ device: AVCaptureDevice) {
        NotificationCenter.default.addObserver(self, selector: #selector(self.subjectAreaChanged), name: Notification.Name.AVCaptureDeviceSubjectAreaDidChange, object: device)
    }
    
    private func unsubscribeFromChanges(_ device: AVCaptureDevice) {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.AVCaptureDeviceSubjectAreaDidChange, object: device)
    }
    
    @objc private func subjectAreaChanged() {
        if let queue = self.queue {
            queue.async { [weak self] in
                self?.setFocusPoint(CGPoint(x: 0.5, y: 0.5), focusMode: .continuousAutoFocus, exposureMode: .continuousAutoExposure, monitorSubjectAreaChange: false)
            }
        } else {
            self.setFocusPoint(CGPoint(x: 0.5, y: 0.5), focusMode: .continuousAutoFocus, exposureMode: .continuousAutoExposure, monitorSubjectAreaChange: false)
        }
    }
    
    private(set) var fps: Double = defaultFPS
    
    func setFps(_ fps: Double) {
        guard let device = self.videoDevice, let targetFPS = device.actualFPS(Double(fps)) else {
            return
        }
        self.fps = targetFPS.fps
        self.transaction(device) { device in
            device.activeVideoMinFrameDuration = targetFPS.duration
            device.activeVideoMaxFrameDuration = targetFPS.duration
        }
    }
    
    var isTorchAvailable: Signal<Bool, NoError> {
        return self.videoDevicePromise.get()
        |> mapToSignal { device -> Signal<Bool, NoError> in
            return Signal { subscriber in
                guard let device else {
                    return EmptyDisposable
                }
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
                guard let device else {
                    return EmptyDisposable
                }
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
    
    private(set) var focusPoint = CGPoint(x: 0.5, y: 0.5)
    
    func setFocusPoint(_ point: CGPoint, focusMode: Camera.FocusMode, exposureMode: Camera.ExposureMode, monitorSubjectAreaChange: Bool) {
        guard let device = self.videoDevice else {
            return
        }
        self.focusPoint = point
        self.transaction(device) { device in
            if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
                device.exposurePointOfInterest = point
                device.exposureMode = exposureMode
            }
            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
                device.focusPointOfInterest = point
                device.focusMode = focusMode
            }
            
            device.isSubjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
            
            if abs(device.exposureTargetBias) > 0.0 {
                device.setExposureTargetBias(0.0)
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
            let torchMode: AVCaptureDevice.TorchMode = active ? .on : .off
            if device.isTorchModeSupported(torchMode) {
                device.torchMode = active ? .on : .off
            }
        }
    }
    
    func setTorchMode(_ flashMode: AVCaptureDevice.FlashMode) {
        guard let device = self.videoDevice else {
            return
        }
        self.transaction(device) { device in
            let torchMode: AVCaptureDevice.TorchMode
            switch flashMode {
            case .on:
                torchMode = .on
            case .off:
                torchMode = .off
            case .auto:
                torchMode = .auto
            @unknown default:
                torchMode = .off
            }
            if device.isTorchModeSupported(torchMode) {
                device.torchMode = torchMode
            }
        }
    }
    
    func setZoomLevel(_ zoomLevel: CGFloat) {
        guard let device = self.videoDevice else {
            return
        }
        self.transaction(device) { device in
            let target = device.neutralZoomFactor + zoomLevel
            device.videoZoomFactor = self.clampedZoomFactor(target, for: device)
        }
    }
    
    func setZoomDelta(_ zoomDelta: CGFloat) {
        guard let device = self.videoDevice else {
            return
        }
        self.transaction(device) { device in
            let target = device.videoZoomFactor * zoomDelta
            device.videoZoomFactor = self.clampedZoomFactor(target, for: device)
        }
    }
    
    func setZoomScale(_ zoomScale: CGFloat) {
        guard let device = self.videoDevice else {
            return
        }
        self.transaction(device) { device in
            let target = device.neutralZoomFactor * zoomScale
            device.videoZoomFactor = self.clampedZoomFactor(target, for: device)
        }
    }

    var zoomFactor: CGFloat? {
        return self.videoDevice?.videoZoomFactor
    }

    func setZoomFactor(_ zoomFactor: CGFloat) {
        guard let device = self.videoDevice else {
            return
        }
        self.transaction(device) { device in
            device.videoZoomFactor = self.clampedZoomFactor(zoomFactor, for: device)
        }
    }

    func rampZoom(_ zoomLevel: CGFloat, rate: CGFloat) {
        guard let device = self.videoDevice else {
            return
        }
        self.transaction(device) { device in
            let target = self.clampedZoomFactor(zoomLevel, for: device)
            device.ramp(toVideoZoomFactor: target, withRate: Float(rate))
        }
    }
    
    func resetZoom(neutral: Bool = true) {
        guard let device = self.videoDevice else {
            return
        }
        self.transaction(device) { device in
            let target = neutral ? device.neutralZoomFactor : device.minAvailableVideoZoomFactor
            device.videoZoomFactor = self.clampedZoomFactor(target, for: device)
        }
    }

    private func clampedZoomFactor(_ value: CGFloat, for device: AVCaptureDevice) -> CGFloat {
        let minimum = max(1.0, device.minAvailableVideoZoomFactor)
        let maximum = max(minimum, device.maxAvailableVideoZoomFactor)
        return min(maximum, max(minimum, value))
    }
}

private func cameraFormatDescriptor(_ format: AVCaptureDevice.Format, index: Int) -> CameraFormatDescriptor {
    let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
    let subtype = CMFormatDescriptionGetMediaSubType(format.formatDescription)
    var hasSecondaryZoomLevels = false
    var maxPhotoDimensions: [CameraFormatDescriptor.Dimensions] = []
    if #available(iOS 16.0, *) {
        hasSecondaryZoomLevels = !format.secondaryNativeResolutionZoomFactors.isEmpty
        maxPhotoDimensions = format.supportedMaxPhotoDimensions.map { CameraFormatDescriptor.Dimensions(width: $0.width, height: $0.height) }
    } else {
        let highResolution = format.highResolutionStillImageDimensions
        maxPhotoDimensions = [CameraFormatDescriptor.Dimensions(width: highResolution.width, height: highResolution.height)]
    }
    return CameraFormatDescriptor(
        index: index,
        dimensions: CameraFormatDescriptor.Dimensions(width: dimensions.width, height: dimensions.height),
        isVideoRange420: subtype == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
        maxFrameRates: format.videoSupportedFrameRateRanges.map { $0.maxFrameRate },
        hasSecondaryZoomLevels: hasSecondaryZoomLevels,
        isHighPhotoQualitySupported: format.isHighPhotoQualitySupported,
        maxPhotoDimensions: maxPhotoDimensions
    )
}
