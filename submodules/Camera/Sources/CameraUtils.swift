import UIKit
import AVFoundation

extension AVFrameRateRange {
    func clamp(rate: Float64) -> Float64 {
        return max(self.minFrameRate, min(self.maxFrameRate, rate))
    }
    
    func contains(rate: Float64) -> Bool {
        return (self.minFrameRate...self.maxFrameRate) ~= rate
    }
}

extension AVCaptureDevice {
    func actualFPS(_ fps: Double) -> (fps: Double, duration: CMTime)? {
        var durations: [CMTime] = []
        var frameRates: [Double] = []
        
        for range in self.activeFormat.videoSupportedFrameRateRanges {
            if range.minFrameRate == range.maxFrameRate {
                durations.append(range.minFrameDuration)
                frameRates.append(range.maxFrameRate)
                continue
            }
            
            if range.contains(rate: fps) {
                return (fps, CMTimeMake(value: 100, timescale: Int32(100 * fps)))
            }
            
            let actualFPS: Double = range.clamp(rate: fps)
            return (actualFPS, CMTimeMake(value: 100, timescale: Int32(100 * actualFPS)))
        }
        
        let diff = frameRates.map { abs($0 - fps) }
        if let minElement: Float64 = diff.min() {
            for i in 0..<diff.count where diff[i] == minElement {
                return (frameRates[i], durations[i])
            }
        }
        
        return nil
    }
}

extension CMSampleBuffer {
    var presentationTimestamp: CMTime {
        return CMSampleBufferGetPresentationTimeStamp(self)
    }
    
    var type: CMMediaType {
        if let formatDescription = CMSampleBufferGetFormatDescription(self) {
            return CMFormatDescriptionGetMediaType(formatDescription)
        } else {
            return kCMMediaType_Video
        }
    }
}

public extension AVCaptureVideoOrientation {
    init?(interfaceOrientation: UIInterfaceOrientation) {
        switch interfaceOrientation {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeLeft
        case .landscapeRight: self = .landscapeRight
        default: return nil
        }
    }
}

public extension CameraPreviewView.Rotation {
    init?(with interfaceOrientation: UIInterfaceOrientation, videoOrientation: AVCaptureVideoOrientation, cameraPosition: AVCaptureDevice.Position) {
        switch videoOrientation {
        case .portrait:
            switch interfaceOrientation {
            case .landscapeRight:
                if cameraPosition == .front {
                    self = .rotate90Degrees
                } else {
                    self = .rotate270Degrees
                }
                
            case .landscapeLeft:
                if cameraPosition == .front {
                    self = .rotate270Degrees
                } else {
                    self = .rotate90Degrees
                }
                
            case .portrait:
                self = .rotate0Degrees
                
            case .portraitUpsideDown:
                self = .rotate180Degrees
                
            default: return nil
            }
        case .portraitUpsideDown:
            switch interfaceOrientation {
            case .landscapeRight:
                if cameraPosition == .front {
                    self = .rotate270Degrees
                } else {
                    self = .rotate90Degrees
                }
                
            case .landscapeLeft:
                if cameraPosition == .front {
                    self = .rotate90Degrees
                } else {
                    self = .rotate270Degrees
                }
                
            case .portrait:
                self = .rotate180Degrees
                
            case .portraitUpsideDown:
                self = .rotate0Degrees
                
            default: return nil
            }
            
        case .landscapeRight:
            switch interfaceOrientation {
            case .landscapeRight:
                self = .rotate0Degrees
                
            case .landscapeLeft:
                self = .rotate180Degrees
                
            case .portrait:
                if cameraPosition == .front {
                    self = .rotate270Degrees
                } else {
                    self = .rotate90Degrees
                }
                
            case .portraitUpsideDown:
                if cameraPosition == .front {
                    self = .rotate90Degrees
                } else {
                    self = .rotate270Degrees
                }
                
            default: return nil
            }
            
        case .landscapeLeft:
            switch interfaceOrientation {
            case .landscapeLeft:
                self = .rotate0Degrees
                
            case .landscapeRight:
                self = .rotate180Degrees
                
            case .portrait:
                if cameraPosition == .front {
                    self = .rotate90Degrees
                } else {
                    self = .rotate270Degrees
                }
                
            case .portraitUpsideDown:
                if cameraPosition == .front {
                    self = .rotate270Degrees
                } else {
                    self = .rotate90Degrees
                }
                
            default: return nil
            }
        @unknown default:
            fatalError("Unknown orientation.")
        }
    }
}

