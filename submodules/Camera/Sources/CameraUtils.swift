import UIKit
import AVFoundation
import Foundation
import Accelerate
import CoreImage

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
    
    var neutralZoomFactor: CGFloat {
        if #available(iOS 13.0, *) {
            if let indexOfWideAngle = self.constituentDevices.firstIndex(where: { $0.deviceType == .builtInWideAngleCamera }), indexOfWideAngle > 0 {
                let zoomFactor = self.virtualDeviceSwitchOverVideoZoomFactors[indexOfWideAngle - 1]
                return CGFloat(zoomFactor.doubleValue)
            }
        }
        return 1.0
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

extension AVCaptureVideoOrientation {
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

extension CameraPreviewView.Rotation {
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

func exifOrientationForDeviceOrientation(_ deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
    switch deviceOrientation {
    case .portraitUpsideDown:
        return .rightMirrored
    case .landscapeLeft:
        return .downMirrored
    case .landscapeRight:
        return .upMirrored
    default:
        return .leftMirrored
    }
}

func resizePixelBuffer(from srcPixelBuffer: CVPixelBuffer,
                       to dstPixelBuffer: CVPixelBuffer,
                       cropX: Int,
                       cropY: Int,
                       cropWidth: Int,
                       cropHeight: Int,
                       scaleWidth: Int,
                       scaleHeight: Int) {
    
    assert(CVPixelBufferGetWidth(dstPixelBuffer) >= scaleWidth)
    assert(CVPixelBufferGetHeight(dstPixelBuffer) >= scaleHeight)
    
    let srcFlags = CVPixelBufferLockFlags.readOnly
    let dstFlags = CVPixelBufferLockFlags(rawValue: 0)
    
    guard kCVReturnSuccess == CVPixelBufferLockBaseAddress(srcPixelBuffer, srcFlags) else {
        print("Error: could not lock source pixel buffer")
        return
    }
    defer { CVPixelBufferUnlockBaseAddress(srcPixelBuffer, srcFlags) }
    
    guard kCVReturnSuccess == CVPixelBufferLockBaseAddress(dstPixelBuffer, dstFlags) else {
        print("Error: could not lock destination pixel buffer")
        return
    }
    defer { CVPixelBufferUnlockBaseAddress(dstPixelBuffer, dstFlags) }
    
    guard let srcData = CVPixelBufferGetBaseAddress(srcPixelBuffer),
          let dstData = CVPixelBufferGetBaseAddress(dstPixelBuffer) else {
        print("Error: could not get pixel buffer base address")
        return
    }
    
    let srcBytesPerRow = CVPixelBufferGetBytesPerRow(srcPixelBuffer)
    let offset = cropY*srcBytesPerRow + cropX*4
    var srcBuffer = vImage_Buffer(data: srcData.advanced(by: offset),
                                  height: vImagePixelCount(cropHeight),
                                  width: vImagePixelCount(cropWidth),
                                  rowBytes: srcBytesPerRow)
    
    let dstBytesPerRow = CVPixelBufferGetBytesPerRow(dstPixelBuffer)
    var dstBuffer = vImage_Buffer(data: dstData,
                                  height: vImagePixelCount(scaleHeight),
                                  width: vImagePixelCount(scaleWidth),
                                  rowBytes: dstBytesPerRow)
    
    let error = vImageScale_ARGB8888(&srcBuffer, &dstBuffer, nil, vImage_Flags(0))
    if error != kvImageNoError {
        print("Error:", error)
    }
}

func resizePixelBuffer(from srcPixelBuffer: CVPixelBuffer,
                       to dstPixelBuffer: CVPixelBuffer,
                       width: Int, height: Int) {
    resizePixelBuffer(from: srcPixelBuffer, to: dstPixelBuffer,
                      cropX: 0, cropY: 0,
                      cropWidth: CVPixelBufferGetWidth(srcPixelBuffer),
                      cropHeight: CVPixelBufferGetHeight(srcPixelBuffer),
                      scaleWidth: width, scaleHeight: height)
}

func resizePixelBuffer(_ pixelBuffer: CVPixelBuffer,
                       width: Int, height: Int,
                       output: CVPixelBuffer, context: CIContext) {
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let sx = CGFloat(width) / CGFloat(CVPixelBufferGetWidth(pixelBuffer))
    let sy = CGFloat(height) / CGFloat(CVPixelBufferGetHeight(pixelBuffer))
    let scaleTransform = CGAffineTransform(scaleX: sx, y: sy)
    let scaledImage = ciImage.transformed(by: scaleTransform)
    context.render(scaledImage, to: output)
}

func imageFromCVPixelBuffer(_ pixelBuffer: CVPixelBuffer, orientation: UIImage.Orientation) -> UIImage? {
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    
    guard let context = CGContext(
        data: baseAddress,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
    ) else {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        return nil
    }
    
    guard let cgImage = context.makeImage() else {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        return nil
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        
    return UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
}

extension CVPixelBuffer {
    func deepCopy() -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        let format = CVPixelBufferGetPixelFormatType(self)
        
        let attributes: [NSObject: AnyObject] = [
            kCVPixelBufferCGImageCompatibilityKey: true as AnyObject,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true as AnyObject
        ]
    
        var newPixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            format,
            attributes as CFDictionary,
            &newPixelBuffer
        )
        
        guard status == kCVReturnSuccess, let unwrappedPixelBuffer = newPixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(self, .readOnly)
        CVPixelBufferLockBaseAddress(unwrappedPixelBuffer, [])
        
        guard let sourceBaseAddress = CVPixelBufferGetBaseAddress(self),
              let destinationBaseAddress = CVPixelBufferGetBaseAddress(unwrappedPixelBuffer) else {
            CVPixelBufferUnlockBaseAddress(self, .readOnly)
            CVPixelBufferUnlockBaseAddress(unwrappedPixelBuffer, [])
            return nil
        }
        
        let sourceBytesPerRow = CVPixelBufferGetBytesPerRow(self)
        let destinationBytesPerRow = CVPixelBufferGetBytesPerRow(unwrappedPixelBuffer)
        
        let imageSize = height * min(sourceBytesPerRow, destinationBytesPerRow)
        
        memcpy(destinationBaseAddress, sourceBaseAddress, imageSize)
        
        CVPixelBufferUnlockBaseAddress(self, .readOnly)
        CVPixelBufferUnlockBaseAddress(unwrappedPixelBuffer, [])
        
        return unwrappedPixelBuffer
    }
}
