import Foundation
import SwiftSignalKit
import Display
import AVFoundation
import Lottie
import TelegramUIPrivateModule

private func verifyLottieItems(_ items: [Any]?, shapes: Bool = true) -> Bool {
    if let items = items {
        for case let item as [AnyHashable: Any] in items {
            if let type = item["ty"] as? String {
                if type == "rp" || type == "sr" || type == "mm" || type == "gs" {
                    return false
                }
            }
            
            if shapes, let subitems = item["it"] as? [Any] {
                if !verifyLottieItems(subitems, shapes: false) {
                    return false
                }
            }
        }
    }
    return true;
}

private func verifyLottieLayers(_ layers: [AnyHashable: Any]?) -> Bool {
    return true
}

func validateStickerComposition(json: [AnyHashable: Any]) -> Bool {
    guard let tgs = json["tgs"] as? Int, tgs == 1 else {
        return false
    }
    
    return true
}

func convertCompressedLottieToCombinedMp4(data: Data, size: CGSize) -> Signal<String, NoError> {
    return Signal({ subscriber in
        let startTime = CACurrentMediaTime()
        let decompressedData = TGGUnzipData(data)
        if let decompressedData = decompressedData, let json = (try? JSONSerialization.jsonObject(with: decompressedData, options: [])) as? [AnyHashable: Any] {
            if let _ = json["tgs"] {
                let model = LOTComposition(json: json)
                if let startFrame = model.startFrame?.int32Value, let endFrame = model.endFrame?.int32Value {
                    var randomId: Int64 = 0
                    arc4random_buf(&randomId, 8)
                    let path = NSTemporaryDirectory() + "\(randomId).mp4"
                    let url = URL(fileURLWithPath: path)
                    
                    let videoSize = CGSize(width: size.width, height: size.height * 2.0)
                    let scale = size.width / 512.0
                    
                    if let assetWriter = try? AVAssetWriter(outputURL: url, fileType: AVFileType.mp4) {
                        let videoSettings: [String: AnyObject] = [AVVideoCodecKey : AVVideoCodecH264 as AnyObject, AVVideoWidthKey : videoSize.width as AnyObject, AVVideoHeightKey : videoSize.height as AnyObject]
                        
                        let assetWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
                        let sourceBufferAttributes = [(kCVPixelBufferPixelFormatTypeKey as String): Int(kCVPixelFormatType_32ARGB),
                                                      (kCVPixelBufferWidthKey as String): Float(videoSize.width),
                                                      (kCVPixelBufferHeightKey as String): Float(videoSize.height)] as [String : Any]
                        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput, sourcePixelBufferAttributes: sourceBufferAttributes)

                        assetWriter.add(assetWriterInput)
                        
                        if assetWriter.startWriting() {
                            print("startedWriting at \(CACurrentMediaTime() - startTime)")
                            assetWriter.startSession(atSourceTime: kCMTimeZero)
                            
                            var currentFrame: Int32 = 0
                            let writeQueue = DispatchQueue(label: "assetWriterQueue")
                            writeQueue.async {
                                let container = LOTAnimationLayerContainer(model: model, size: size)
                                
                                let singleContext = DrawingContext(size: size, scale: 1.0, clear: true)
                                let context = DrawingContext(size: size, scale: 1.0, clear: false)
                                
                                let fps: Int32 = model.framerate?.int32Value ?? 30
                                let frameDuration = CMTimeMake(1, fps)
                                
                                assetWriterInput.requestMediaDataWhenReady(on: writeQueue) {
                                    while assetWriterInput.isReadyForMoreMediaData && startFrame + currentFrame < endFrame {
                                        let lastFrameTime = CMTimeMake(Int64(currentFrame - startFrame), fps)
                                        let presentationTime = currentFrame == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)
                                        
                                        singleContext.withContext { context in
                                            context.clear(CGRect(origin: CGPoint(), size: size))
                                            context.saveGState()
                                            context.scaleBy(x: scale, y: scale)
                                            container?.renderFrame(startFrame + currentFrame, in: context)
                                            context.restoreGState()
                                        }
                                        
                                        let image = singleContext.generateImage()
                                        let alphaImage = generateTintedImage(image: image, color: .white, backgroundColor: .black)
                                        context.withFlippedContext { context in
                                            context.setFillColor(UIColor.white.cgColor)
                                            context.fill(CGRect(origin: CGPoint(x: 0.0, y: size.height), size: videoSize))
                                            if let image = image?.cgImage {
                                                context.draw(image, in: CGRect(origin: CGPoint(x: 0.0, y: size.height), size: size))
                                            }
                                            if let alphaImage = alphaImage?.cgImage {
                                                context.draw(alphaImage, in: CGRect(origin: CGPoint(), size: size))
                                            }
                                        }
                                        
                                        if let image = context.generateImage() {
                                            if let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool {
                                                let pixelBufferPointer = UnsafeMutablePointer<CVPixelBuffer?>.allocate(capacity: 1)
                                                let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, pixelBufferPointer)
                                                if let pixelBuffer = pixelBufferPointer.pointee, status == 0 {
                                                    fillPixelBufferFromImage(image, pixelBuffer: pixelBuffer)

                                                    pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                                                    pixelBufferPointer.deinitialize(count: 1)
                                                } else {
                                                    break
                                                }
                                                
                                                pixelBufferPointer.deallocate()
                                            } else {
                                                break
                                            }
                                        }
                                        currentFrame += 1
                                    }
                                    
                                    if startFrame + currentFrame == endFrame {
                                        assetWriterInput.markAsFinished()
                                        assetWriter.finishWriting {
                                            subscriber.putNext(path)
                                            subscriber.putCompletion()
                                            print("animation render time \(CACurrentMediaTime() - startTime)")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        return EmptyDisposable
    })
}

private func fillPixelBufferFromImage(_ image: UIImage, pixelBuffer: CVPixelBuffer) {
    CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(data: pixelData, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
    context?.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
    CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
}
