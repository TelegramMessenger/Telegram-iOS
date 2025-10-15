import Foundation
import UIKit
import Display
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import VideoToolbox
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import FileMediaResourceStatus
import ZipArchive
import ImageTransparency

private let queue = Queue()

public enum CutoutAvailability {
    case available
    case progress(Float)
    case unavailable
}

private var forceCoreMLVariant: Bool {
#if targetEnvironment(simulator)
    return true
#else
    return false
#endif
}

private func modelPath() -> String {
    return NSTemporaryDirectory() + "u2netp.mlmodelc"
}

public func cutoutAvailability(context: AccountContext) -> Signal<CutoutAvailability, NoError> {
    if #available(iOS 17.0, *), !forceCoreMLVariant {
        return .single(.available)
    } else if #available(iOS 14.0, *) {
        let compiledModelPath = modelPath()
                
        if FileManager.default.fileExists(atPath: compiledModelPath) {
            return .single(.available)
        }
        return context.engine.peers.resolvePeerByName(name: "stickersbackgroundseparation", referrer: nil)
        |> mapToSignal { result -> Signal<CutoutAvailability, NoError> in
            guard case let .result(maybePeer) = result else {
                return .complete()
            }
            guard let peer = maybePeer else {
                return .single(.unavailable)
            }
            
            return context.account.viewTracker.aroundMessageHistoryViewForLocation(.peer(peerId: peer.id, threadId: nil), index: .lowerBound, anchorIndex: .lowerBound, count: 5, fixedCombinedReadStates: nil)
            |> mapToSignal { view -> Signal<(TelegramMediaFile, EngineMessage)?, NoError> in
                if !view.0.isLoading {
                    if let message = view.0.entries.last?.message, let file = message.media.first(where: { $0 is TelegramMediaFile }) as? TelegramMediaFile {
                        return .single((file, EngineMessage(message)))
                    } else {
                        return .single(nil)
                    }
                } else {
                    return .complete()
                }
            }
            |> take(1)
            |> mapToSignal { maybeFileAndMessage -> Signal<CutoutAvailability, NoError> in
                if let (file, message) = maybeFileAndMessage {
                    let fetchedData = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .other, userContentType: .file, reference: FileMediaReference.message(message: MessageReference(message._asMessage()), media: file).resourceReference(file.resource))
                    
                    enum FetchStatus {
                        case completed(String)
                        case progress(Float)
                        case failed
                    }
                                        
                    let fetchStatus = Signal<FetchStatus, NoError> { subscriber in
                        let fetchedDisposable = fetchedData.start()
                        let resourceDataDisposable = context.account.postbox.mediaBox.resourceData(file.resource, attemptSynchronously: false).start(next: { next in
                            if next.complete {
                                SSZipArchive.unzipFile(atPath: next.path, toDestination: NSTemporaryDirectory())
                                subscriber.putNext(.completed(compiledModelPath))
                                subscriber.putCompletion()
                            }
                        }, error: subscriber.putError, completed: subscriber.putCompletion)
                        let progressDisposable = messageFileMediaResourceStatus(context: context, file: file, message: message, isRecentActions: false).start(next: { status in
                            switch status.fetchStatus {
                            case let .Remote(progress), let .Fetching(_, progress), let .Paused(progress):
                                subscriber.putNext(.progress(progress))
                            default:
                                break
                            }
                        })
                        return ActionDisposable {
                            fetchedDisposable.dispose()
                            resourceDataDisposable.dispose()
                            progressDisposable.dispose()
                        }
                    }
                    return fetchStatus
                    |> mapToSignal { status -> Signal<CutoutAvailability, NoError> in
                        switch status {
                        case .completed:
                            return .single(.available)
                        case let .progress(progress):
                            return .single(.progress(progress))
                        case .failed:
                            return .single(.unavailable)
                        }
                    }
                } else {
                    return .single(.unavailable)
                }
            }
        }
    } else {
        return .single(.unavailable)
    }
}

public func cutoutStickerImage(from image: UIImage, context: AccountContext? = nil, onlyCheck: Bool = false) -> Signal<UIImage?, NoError> {
    guard let cgImage = image.cgImage else {
        return .single(nil)
    }
    if #available(iOS 17.0, *), !forceCoreMLVariant {
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
    } else if #available(iOS 14.0, *), onlyCheck {
        return Signal { subscriber in
            U2netp.load(contentsOf: URL(fileURLWithPath: modelPath()), completionHandler: { result in
                switch result {
                case let .success(model):
                    let modelImageSize = CGSize(width: 320, height: 320)
                    if let squareImage = scaleImageToPixelSize(image: image, size: modelImageSize),
                          let pixelBuffer = buffer(from: squareImage),
                          let result = try? model.prediction(in_0: pixelBuffer),
                          let resultImage = UIImage(pixelBuffer: result.out_p1),
                          imageHasSubject(resultImage) {
                        subscriber.putNext(UIImage())
                    } else {
                        subscriber.putNext(nil)
                    }
                    subscriber.putCompletion()
                case .failure:
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                }
            })
            return EmptyDisposable
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
    crop: (offset: CGPoint, rotation: CGFloat, scale: CGFloat)?,
    target: CutoutTarget,
    includeExtracted: Bool = true,
    completion: @escaping ([CutoutResult]) -> Void
) {
    guard #available(iOS 14.0, *), let cgImage = image.cgImage else {
        completion([])
        return
    }
    
    let ciContext = CIContext(options: nil)
    let inputImage = CIImage(cgImage: cgImage)
    var results: [CutoutResult] = []
    
    func process(instance: Int, mask originalMaskImage: CIImage) {
        let extractedImage: CutoutResult.Image?
        if includeExtracted {
            let filter = CIFilter.blendWithMask()
            filter.backgroundImage = CIImage(color: .clear)
            
            let dimensions: CGSize
            var maskImage = originalMaskImage
            if let editedImage = editedImage?.cgImage.flatMap({ CIImage(cgImage: $0) }) {
                filter.inputImage = editedImage
                dimensions = editedImage.extent.size
                
                if let (cropOffset, cropRotation, cropScale) = crop {
                    let initialScale: CGFloat
                    if maskImage.extent.height > maskImage.extent.width {
                        initialScale = dimensions.width / maskImage.extent.width
                    } else {
                        initialScale = dimensions.width / maskImage.extent.height
                    }
                    
                    let dimensions = editedImage.extent.size
                    maskImage = maskImage.transformed(by: CGAffineTransform(translationX: -maskImage.extent.width / 2.0, y: -maskImage.extent.height / 2.0))
                    
                    var transform = CGAffineTransform.identity
                    transform = transform.translatedBy(x: dimensions.width / 2.0 + cropOffset.x, y: dimensions.height / 2.0 + cropOffset.y * -1.0)
                    transform = transform.rotated(by: -cropRotation)
                    transform = transform.scaledBy(x: cropScale * initialScale, y: cropScale * initialScale)
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
        maskFilter.maskImage = originalMaskImage
        
        let refinedMaskFilter = CIFilter.blendWithMask()
        refinedMaskFilter.inputImage = whiteImage
        refinedMaskFilter.backgroundImage = blackImage
        refinedMaskFilter.maskImage = refineEdges(originalMaskImage)
        
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

    if #available(iOS 17.0, *), !forceCoreMLVariant {
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
                
                for instance in targetInstances {
                    if let mask = try? result.generateScaledMaskForImage(forInstances: IndexSet(integer: instance), from: handler) {
                        process(instance: instance, mask: CIImage(cvPixelBuffer: mask))
                    }
                }
                completion(results)
            }
            
            try? handler.perform([request])
        }
    } else {
        U2netp.load(contentsOf: URL(fileURLWithPath: modelPath()), completionHandler: { result in
            switch result {
            case let .success(model):
                let modelImageSize = CGSize(width: 320, height: 320)
                if let squareImage = scaleImageToPixelSize(image: image, size: modelImageSize), let pixelBuffer = buffer(from: squareImage), let result = try? model.prediction(in_0: pixelBuffer), let maskImage = UIImage(pixelBuffer: result.out_p1), let scaledMaskImage = scaleImageToPixelSize(image: maskImage, size: image.size), let ciImage = CIImage(image: scaledMaskImage) {
                    process(instance: 0, mask: ciImage)
                }
            case .failure:
                break
            }
            completion(results)
        })
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

private func scaleImageToPixelSize(image: UIImage, size: CGSize) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
    image.draw(in: CGRect(origin: CGPoint(), size: size), blendMode: .copy, alpha: 1.0)
    let result = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return result
}

private func buffer(from image: UIImage) -> CVPixelBuffer? {
    let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
    var pixelBuffer : CVPixelBuffer?
    let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.size.width), Int(image.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
    guard (status == kCVReturnSuccess) else {
        return nil
    }
    
    guard let pixelBufferUnwrapped = pixelBuffer else {
        return nil
    }
    
    CVPixelBufferLockBaseAddress(pixelBufferUnwrapped, CVPixelBufferLockFlags(rawValue: 0))
    let pixelData = CVPixelBufferGetBaseAddress(pixelBufferUnwrapped)
    
    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    
    guard let context = CGContext(data: pixelData, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBufferUnwrapped), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
        return nil
    }
    
    context.translateBy(x: 0, y: image.size.height)
    context.scaleBy(x: 1.0, y: -1.0)
    
    UIGraphicsPushContext(context)
    image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
    UIGraphicsPopContext()
    CVPixelBufferUnlockBaseAddress(pixelBufferUnwrapped, CVPixelBufferLockFlags(rawValue: 0))
    
    return pixelBufferUnwrapped
}
