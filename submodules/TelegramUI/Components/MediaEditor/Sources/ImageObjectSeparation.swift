import Foundation
import UIKit
import Display
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftSignalKit
import VideoToolbox

private let queue = Queue()

public func cutoutStickerImage(from image: UIImage, onlyCheck: Bool = false) -> Signal<UIImage?, NoError> {
    if #available(iOS 17.0, *) {
        guard let cgImage = image.cgImage else {
            return .single(nil)
        }
        return Signal { subscriber in
            let ciContext = CIContext(options: nil)
            let inputImage = CIImage(cgImage: cgImage)
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNGenerateForegroundInstanceMaskRequest { [weak handler] request, error in
                guard let handler, let result = request.results?.first as? VNInstanceMaskObservation else {
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                    return
                }
                if onlyCheck {
                    subscriber.putNext(UIImage())
                    subscriber.putCompletion()
                } else {
                    let instances = instances(atPoint: nil, inObservation: result)
                    if let mask = try? result.generateScaledMaskForImage(forInstances: instances, from: handler) {
                        let filter = CIFilter.blendWithMask()
                        filter.inputImage = inputImage
                        filter.backgroundImage = CIImage(color: .clear)
                        filter.maskImage = CIImage(cvPixelBuffer: mask)
                        if let output  = filter.outputImage, let cgImage = ciContext.createCGImage(output, from: inputImage.extent) {
                            let image = UIImage(cgImage: cgImage)
                            subscriber.putNext(image)
                            subscriber.putCompletion()
                            return
                        }
                    }
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

public struct CutoutResult {
    public enum Image {
        case image(UIImage, CIImage)
        case pixelBuffer(CVPixelBuffer)
    }
    
    public let index: Int
    public let extractedImage: Image?
    public let edgesMaskImage: Image?
    public let maskImage: Image?
    public let backgroundImage: Image?
}

public enum CutoutTarget {
    case point(CGPoint?)
    case index(Int)
    case all
}


func refineEdges(_ maskImage: CIImage) -> CIImage? {
    let maskImage = maskImage.clampedToExtent()
        
    let blurFilter = CIFilter(name: "CIGaussianBlur")!
    blurFilter.setValue(maskImage, forKey: kCIInputImageKey)
    blurFilter.setValue(11.4, forKey: kCIInputRadiusKey)
        
    let controlsFilter = CIFilter(name: "CIColorControls")!
    controlsFilter.setValue(blurFilter.outputImage, forKey: kCIInputImageKey)
    controlsFilter.setValue(6.61, forKey: kCIInputContrastKey)
    
    let sharpenFilter = CIFilter(name: "CISharpenLuminance")!
    sharpenFilter.setValue(controlsFilter.outputImage, forKey: kCIInputImageKey)
    sharpenFilter.setValue(250.0, forKey: kCIInputSharpnessKey)
    
    return sharpenFilter.outputImage?.cropped(to: maskImage.extent)
}

public func cutoutImage(
    from image: UIImage,
    editedImage: UIImage? = nil,
    values: MediaEditorValues?,
    target: CutoutTarget,
    includeExtracted: Bool = true,
    completion: @escaping ([CutoutResult]) -> Void
) {
    if #available(iOS 17.0, *), let cgImage = image.cgImage {
        let ciContext = CIContext(options: nil)
        let inputImage = CIImage(cgImage: cgImage)
        
        queue.async {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNGenerateForegroundInstanceMaskRequest { [weak handler] request, error in
                guard let handler, let result = request.results?.first as? VNInstanceMaskObservation else {
                    completion([])
                    return
                }

                let targetInstances: IndexSet
                switch target {
                case let .point(point):
                    targetInstances = instances(atPoint: point, inObservation: result)
                case let .index(index):
                    targetInstances = IndexSet([index])
                case .all:
                    targetInstances = result.allInstances
                }
                
                var results: [CutoutResult] = []
                for instance in targetInstances {
                    if let mask = try? result.generateScaledMaskForImage(forInstances: IndexSet(integer: instance), from: handler) {
                        let extractedImage: CutoutResult.Image?
                        if includeExtracted {
                            let filter = CIFilter.blendWithMask()
                            filter.backgroundImage = CIImage(color: .clear)
                            
                            let dimensions: CGSize
                            var maskImage = CIImage(cvPixelBuffer: mask)
                            if let editedImage = editedImage?.cgImage.flatMap({ CIImage(cgImage: $0) }) {
                                filter.inputImage = editedImage
                                dimensions = editedImage.extent.size
                                
                                if let values {
                                    let initialScale: CGFloat
                                    if maskImage.extent.height > maskImage.extent.width {
                                        initialScale = dimensions.width / maskImage.extent.width
                                    } else {
                                        initialScale = dimensions.width / maskImage.extent.height
                                    }
                                    
                                    let dimensions = editedImage.extent.size
                                    maskImage = maskImage.transformed(by: CGAffineTransform(translationX: -maskImage.extent.width / 2.0, y: -maskImage.extent.height / 2.0))
                                    
                                    var transform = CGAffineTransform.identity
                                    let position = values.cropOffset
                                    let rotation = values.cropRotation
                                    let scale = values.cropScale
                                    transform = transform.translatedBy(x: dimensions.width / 2.0 + position.x, y: dimensions.height / 2.0 + position.y * -1.0)
                                    transform = transform.rotated(by: -rotation)
                                    transform = transform.scaledBy(x: scale * initialScale, y: scale * initialScale)
                                    maskImage = maskImage.transformed(by: transform)
                                }
                            } else {
                                filter.inputImage = inputImage
                                dimensions = inputImage.extent.size
                            }
                            filter.maskImage = maskImage
                            
                            if let output = filter.outputImage, let cgImage = ciContext.createCGImage(output, from: CGRect(origin: .zero, size: dimensions)) {
                                extractedImage = .image(UIImage(cgImage: cgImage), output)
                            } else {
                                extractedImage = nil
                            }
                        } else {
                            extractedImage = nil
                        }
                        
                        let whiteImage = CIImage(color: .white)
                        let blackImage = CIImage(color: .black)
                        
                        let maskFilter = CIFilter.blendWithMask()
                        maskFilter.inputImage = whiteImage
                        maskFilter.backgroundImage = blackImage
                        maskFilter.maskImage = CIImage(cvPixelBuffer: mask)
                        
                        let refinedMaskFilter = CIFilter.blendWithMask()
                        refinedMaskFilter.inputImage = whiteImage
                        refinedMaskFilter.backgroundImage = blackImage
                        refinedMaskFilter.maskImage = refineEdges(CIImage(cvPixelBuffer: mask))
                        
                        let edgesMaskImage: CutoutResult.Image?
                        let maskImage: CutoutResult.Image?
                        if let maskOutput = maskFilter.outputImage?.cropped(to: inputImage.extent), let maskCgImage = ciContext.createCGImage(maskOutput, from: inputImage.extent), let refinedMaskOutput = refinedMaskFilter.outputImage?.cropped(to: inputImage.extent), let refinedMaskCgImage = ciContext.createCGImage(refinedMaskOutput, from: inputImage.extent) {
                            edgesMaskImage = .image(UIImage(cgImage: maskCgImage), maskOutput)
                            maskImage = .image(UIImage(cgImage: refinedMaskCgImage), refinedMaskOutput)
                        } else {
                            edgesMaskImage = nil
                            maskImage = nil
                        }
                        
                        if extractedImage != nil || maskImage != nil {
                            results.append(CutoutResult(index: instance, extractedImage: extractedImage, edgesMaskImage: edgesMaskImage, maskImage: maskImage, backgroundImage: nil))
                        }
                    }
                }
                completion(results)
            }
            
            try? handler.perform([request])
        }
    } else {
        completion([])
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
