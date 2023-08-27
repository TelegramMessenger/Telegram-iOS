import Foundation
import AVFoundation
import UIKit
import SwiftSignalKit

public enum PhotoCaptureResult: Equatable {
    case began
    case finished(UIImage, UIImage?, Double)
    case failed
    
    public static func == (lhs: PhotoCaptureResult, rhs: PhotoCaptureResult) -> Bool {
        switch lhs {
        case .began:
            if case .began = rhs {
                return true
            } else {
                return false
            }
        case .failed:
            if case .failed = rhs {
                return true
            } else {
                return false
            }
        case let .finished(_, _, lhsTime):
            if case let .finished(_, _, rhsTime) = rhs, lhsTime == rhsTime {
                return true
            } else {
                return false
            }
        }
    }
}

final class PhotoCaptureContext: NSObject, AVCapturePhotoCaptureDelegate {
    private let pipe = ValuePipe<PhotoCaptureResult>()
    private let orientation: AVCaptureVideoOrientation
    private let mirror: Bool
    
    init(settings: AVCapturePhotoSettings, orientation: AVCaptureVideoOrientation, mirror: Bool) {
        self.orientation = orientation
        self.mirror = mirror
        
        super.init()
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        self.pipe.putNext(.began)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let _ = error {
            self.pipe.putNext(.failed)
        } else {
            guard let photoPixelBuffer = photo.pixelBuffer else {
                print("Error occurred while capturing photo: Missing pixel buffer (\(String(describing: error)))")
                return
            }
            
            var photoFormatDescription: CMFormatDescription?
            CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: photoPixelBuffer, formatDescriptionOut: &photoFormatDescription)
            
            var orientation: UIImage.Orientation = .right
            if self.orientation == .landscapeLeft {
                orientation = .down
            } else if self.orientation == .landscapeRight {
                orientation = .up
            } else if self.orientation == .portraitUpsideDown {
                orientation = .left
            }
            
            let finalPixelBuffer = photoPixelBuffer
            let ciContext = CIContext()
            let renderedCIImage = CIImage(cvImageBuffer: finalPixelBuffer)
            if let cgImage = ciContext.createCGImage(renderedCIImage, from: renderedCIImage.extent)  {
                var image = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
                if image.imageOrientation != .up {
                    UIGraphicsBeginImageContextWithOptions(image.size, true, image.scale)
                    if self.mirror, let context = UIGraphicsGetCurrentContext() {
                        context.translateBy(x: image.size.width / 2.0, y: image.size.height / 2.0)
                        context.scaleBy(x: -1.0, y: 1.0)
                        context.translateBy(x: -image.size.width / 2.0, y: -image.size.height / 2.0)
                    }
                    image.draw(in: CGRect(origin: .zero, size: image.size))
                    if let currentImage = UIGraphicsGetImageFromCurrentImageContext() {
                        image = currentImage
                    }
                    UIGraphicsEndImageContext()
                }
                self.pipe.putNext(.finished(image, nil, CACurrentMediaTime()))
            } else {
                self.pipe.putNext(.failed)
            }
        }
    }
    
    var signal: Signal<PhotoCaptureResult, NoError> {
        return self.pipe.signal()
        |> take(until: { next in
            let complete: Bool
            switch next {
            case .finished, .failed:
                complete = true
            default:
                complete = false
            }
            return SignalTakeAction(passthrough: true, complete: complete)
        })
    }
}
