import Foundation
import AVFoundation
import UIKit
import SwiftSignalKit

public enum PhotoCaptureResult {
    case began
    case finished(UIImage)
    case failed
}

final class PhotoCaptureContext: NSObject, AVCapturePhotoCaptureDelegate {
    private let pipe = ValuePipe<PhotoCaptureResult>()
    private let filter: CameraFilter?
    
    init(settings: AVCapturePhotoSettings, filter: CameraFilter?) {
        self.filter = filter
        
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
            
            var finalPixelBuffer = photoPixelBuffer
            if let filter = self.filter {
                if !filter.isPrepared {
                    if let unwrappedPhotoFormatDescription = photoFormatDescription {
                        filter.prepare(with: unwrappedPhotoFormatDescription, outputRetainedBufferCountHint: 2)
                    }
                }
                
                guard let filteredPixelBuffer = filter.render(pixelBuffer: finalPixelBuffer) else {
                    print("Unable to filter photo buffer")
                    return
                }
                finalPixelBuffer = filteredPixelBuffer
            }
            
            let ciContext = CIContext()
            let renderedCIImage = CIImage(cvImageBuffer: finalPixelBuffer)
            if let cgImage = ciContext.createCGImage(renderedCIImage, from: renderedCIImage.extent)  {
                var image = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
                if image.imageOrientation != .up {
                    UIGraphicsBeginImageContextWithOptions(image.size, true, image.scale)
                    image.draw(in: CGRect(origin: .zero, size: image.size))
                    if let currentImage = UIGraphicsGetImageFromCurrentImageContext() {
                        image = currentImage
                    }
                    UIGraphicsEndImageContext()
                }
                self.pipe.putNext(.finished(image))
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
