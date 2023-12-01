import Foundation
import UIKit
import Vision
import CoreImage
import SwiftSignalKit
import VideoToolbox

private let queue = Queue()

func cutoutStickerImage(from image: UIImage) -> Signal<UIImage?, NoError> {
    if #available(iOS 17.0, *) {
        guard let cgImage = image.cgImage else {
            return .single(nil)
        }
        return Signal { subscriber in
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNGenerateForegroundInstanceMaskRequest { [weak handler] request, error in
                guard let handler, let result = request.results?.first as? VNInstanceMaskObservation else {
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                    return
                }
                let instances = instances(atPoint: nil, inObservation: result)
                if let mask = try? result.generateScaledMaskForImage(forInstances: instances, from: handler), let image = UIImage(pixelBuffer: mask) {
                    subscriber.putNext(image)
                    subscriber.putCompletion()
                } else {
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                }
            }
            try? handler.perform([request])
            return ActionDisposable {
                request.cancel()
            }
        }
        |> runOn(queue)
    } else {
        return .single(nil)
    }
}

@available(iOS 17.0, *)
private func instances(atPoint maybePoint: CGPoint?, inObservation observation: VNInstanceMaskObservation) -> IndexSet {
    guard let point = maybePoint else {
        return observation.allInstances
    }

    let instanceMap = observation.instanceMask
    let coords = VNImagePointForNormalizedPoint(point, CVPixelBufferGetWidth(instanceMap) - 1, CVPixelBufferGetHeight(instanceMap) - 1)

    CVPixelBufferLockBaseAddress(instanceMap, .readOnly)
    guard let pixels = CVPixelBufferGetBaseAddress(instanceMap) else {
        fatalError()
    }
    let bytesPerRow = CVPixelBufferGetBytesPerRow(instanceMap)
    let instanceLabel = pixels.load(fromByteOffset: Int(coords.y) * bytesPerRow + Int(coords.x), as: UInt8.self)
    CVPixelBufferUnlockBaseAddress(instanceMap, .readOnly)

    return instanceLabel == 0 ? observation.allInstances : [Int(instanceLabel)]
}

private extension UIImage {
    convenience init?(pixelBuffer: CVPixelBuffer) {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)

        guard let cgImage = cgImage else {
            return nil
        }

        self.init(cgImage: cgImage)
    }
}
