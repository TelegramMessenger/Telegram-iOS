import Foundation
import AVFoundation
import UIKit
import SwiftSignalKit
import Camera

final class PhotoCaptureContext: NSObject, AVCapturePhotoCaptureDelegate {
    private let ciContext: CIContext
    private let pipe = ValuePipe<PhotoCaptureResult>()
    private let orientation: AVCaptureVideoOrientation
    private let mirror: Bool
    
    init(ciContext: CIContext, settings: AVCapturePhotoSettings, orientation: AVCaptureVideoOrientation, mirror: Bool) {
        self.ciContext = ciContext
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
