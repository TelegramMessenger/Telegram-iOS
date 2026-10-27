import Foundation
import AVFoundation
import UIKit
import ImageIO
import SwiftSignalKit
import Camera
import TelegramCore

final class PhotoCaptureContext: NSObject, AVCapturePhotoCaptureDelegate {
    private let ciContext: CIContext
    private let pipe = ValuePipe<PhotoCaptureResult>()
    private let orientation: AVCaptureVideoOrientation
    private let mirror: Bool
    private let isEncoded: Bool
    
    init(ciContext: CIContext, settings: AVCapturePhotoSettings, orientation: AVCaptureVideoOrientation, mirror: Bool, isEncoded: Bool = false) {
        self.ciContext = ciContext
        self.orientation = orientation
        self.mirror = mirror
        self.isEncoded = isEncoded
        
        super.init()
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        self.pipe.putNext(.began)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let _ = error {
            self.pipe.putNext(.failed)
        } else if self.isEncoded {
            guard let data = photo.fileDataRepresentation(), let source = CGImageSourceCreateWithData(data as CFData, nil), let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                Logger.shared.log("Camera", "Photo capture produced no encoded data")
                self.pipe.putNext(.failed)
                return
            }
            let orientation = exifOrientation(for: self.orientation, mirror: self.mirror)
            let ci = CIImage(cgImage: cgImage).oriented(forExifOrientation: orientation)
            if let orientedImage = self.ciContext.createCGImage(ci, from: ci.extent) {
                self.pipe.putNext(.finished(UIImage(cgImage: orientedImage, scale: 1.0, orientation: .up), nil, CACurrentMediaTime()))
            } else {
                self.pipe.putNext(.failed)
            }
        } else {
            guard let photoPixelBuffer = photo.pixelBuffer else {
                Logger.shared.log("Camera", "Photo capture produced no pixel buffer (\(String(describing: error)))")
                self.pipe.putNext(.failed)
                return
            }
                        
            //if let value = photo.metadata[kCGImagePropertyOrientation as String] as? NSNumber {
            //    orientation = value.int32Value
            //} else {
            let orientation = exifOrientation(for: self.orientation, mirror: self.mirror)
            //}

            let ci = CIImage(cvImageBuffer: photoPixelBuffer).oriented(forExifOrientation: orientation)
            if let cgImage = self.ciContext.createCGImage(ci, from: ci.extent) {
                let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
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
