import Foundation
import AVFoundation
import SwiftSignalKit
import TelegramCore

private let defaultFPS: Double = 30.0

final class CameraDevice {
    var position: Camera.Position = .back
    
    deinit {
        if let videoDevice = self.videoDevice {
            self.unsubscribeFromChanges(videoDevice)
        }
    }
    
    public private(set) var videoDevice: AVCaptureDevice? = nil {
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
    
    public private(set) var audioDevice: AVCaptureDevice? = nil
        
    func configure(for session: CameraSession, position: Camera.Position, dual: Bool) {
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
        
        self.audioDevice = AVCaptureDevice.default(for: .audio)
    }
    
    func configureDeviceFormat(maxDimensions: CMVideoDimensions, maxFramerate: Double) {
        guard let device = self.videoDevice else {
            return
        }
        self.transaction(device) { device in
            var maxWidth: Int32 = 0
            var maxHeight: Int32 = 0
            var hasSecondaryZoomLevels = false
            var candidates: [AVCaptureDevice.Format] = []
            var photoCandidates: [AVCaptureDevice.Format] = []
     outer: for format in device.formats {
                if format.mediaType != .video || format.value(forKey: "isPhotoFormat") as? Bool == true {
                    continue
                }
                
                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                if dimensions.width >= maxWidth && dimensions.width <= maxDimensions.width && dimensions.height >= maxHeight && dimensions.height <= maxDimensions.height {
                    if dimensions.width > maxWidth {
                        hasSecondaryZoomLevels = false
                        candidates.removeAll()
                    }
                    let subtype = CMFormatDescriptionGetMediaSubType(format.formatDescription)
                    if subtype == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange {
                        for range in format.videoSupportedFrameRateRanges {
                            if range.maxFrameRate > 60 {
                                continue outer
                            }
                        }
                        
                        maxWidth = dimensions.width
                        maxHeight = dimensions.height
                        
                        if #available(iOS 16.0, *), !format.secondaryNativeResolutionZoomFactors.isEmpty {
                            hasSecondaryZoomLevels = true
                            candidates.append(format)
                            if format.isHighPhotoQualitySupported {
                                photoCandidates.append(format)
                            }
                        } else if !hasSecondaryZoomLevels {
                            candidates.append(format)
                            if #available(iOS 15.0, *), format.isHighPhotoQualitySupported {
                                photoCandidates.append(format)
                            }
                        }
                    }
                }
            }
            
            if !candidates.isEmpty {
                var bestFormat: AVCaptureDevice.Format?
    photoOuter: for format in photoCandidates {
                    for range in format.videoSupportedFrameRateRanges {
                        if range.maxFrameRate > maxFramerate {
                            continue photoOuter
                        }
                        bestFormat = format
                    }
                }
                if bestFormat == nil {
             outer: for format in candidates {
                        for range in format.videoSupportedFrameRateRanges {
                            if range.maxFrameRate > maxFramerate {
                                continue outer
                            }
                            bestFormat = format
                        }
                    }
                }
                if bestFormat == nil {
                    bestFormat = candidates.last
                }
                device.activeFormat = bestFormat!
                    
                Logger.shared.log("Camera", "Selected format:")
                Logger.shared.log("Camera", bestFormat!.description)
            } else {
                Logger.shared.log("Camera", "No format selected")
            }
            
            Logger.shared.log("Camera", "Available formats:")
            for format in device.formats {
                Logger.shared.log("Camera", format.description)
            }
            
            if let targetFPS = device.actualFPS(maxFramerate) {
                device.activeVideoMinFrameDuration = targetFPS.duration
                device.activeVideoMaxFrameDuration = targetFPS.duration
            }
            
            if device.isLowLightBoostSupported {
                device.automaticallyEnablesLowLightBoostWhenAvailable = true
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
        self.setFocusPoint(CGPoint(x: 0.5, y: 0.5), focusMode: .continuousAutoFocus, exposureMode: .continuousAutoExposure, monitorSubjectAreaChange: false)
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
            device.torchMode = active ? .on : .off
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
            device.videoZoomFactor = max(device.neutralZoomFactor, min(10.0, device.neutralZoomFactor + zoomLevel))
        }
    }
    
    func setZoomDelta(_ zoomDelta: CGFloat) {
        guard let device = self.videoDevice else {
            return
        }
        self.transaction(device) { device in
            device.videoZoomFactor = max(1.0, min(10.0, device.videoZoomFactor * zoomDelta))
        }
    }
    
    func resetZoom(neutral: Bool = true) {
        guard let device = self.videoDevice else {
            return
        }
        self.transaction(device) { device in
            device.videoZoomFactor = neutral ? device.neutralZoomFactor : device.minAvailableVideoZoomFactor
        }
    }
}
