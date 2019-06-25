import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import Display
import AVFoundation
import Lottie
import TelegramUIPrivateModule
import Compression
import GZip
import RLottie

private func validateAnimationItems(_ items: [Any]?, shapes: Bool = true) -> Bool {
    if let items = items {
        for case let item as [AnyHashable: Any] in items {
            if let type = item["ty"] as? String {
                if type == "rp" || type == "sr" || type == "gs" {
                    return false
                }
            }
            
            if shapes, let subitems = item["it"] as? [Any] {
                if !validateAnimationItems(subitems, shapes: false) {
                    return false
                }
            }
        }
    }
    return true;
}

private func validateAnimationLayers(_ layers: [Any]?) -> Bool {
    if let layers = layers {
        for case let layer as [AnyHashable: Any] in layers {
            if let ddd = layer["ddd"] as? Int, ddd != 0 {
                return false
            }
            if let sr = layer["sr"] as? Int, sr != 1 {
                return false
            }
            if let _ = layer["tm"] {
                return false
            }
            if let ty = layer["ty"] as? Int {
                if ty == 1 || ty == 2 || ty == 5 || ty == 9 {
                    return false
                }
            }
            if let hasMask = layer["hasMask"] as? Bool, hasMask {
                return false
            }
            if let _ = layer["masksProperties"] {
                return false
            }
            if let _ = layer["tt"] {
                return false
            }
            if let ao = layer["ao"] as? Int, ao == 1 {
                return false
            }
            
            if let shapes = layer["shapes"] as? [Any], !validateAnimationItems(shapes, shapes: true) {
                return false
            }
        }
    }
    return true
}

func validateAnimationComposition(json: [AnyHashable: Any]) -> Bool {
    guard let tgs = json["tgs"] as? Int, tgs == 1 else {
        return false
    }
    guard let width = json["w"] as? Int, width == 512 else {
        return false
    }
    guard let height = json["h"] as? Int, height == 512 else {
        return false
    }
    
    return true
}

@available(iOS 9.0, *)
func experimentalConvertCompressedLottieToCombinedMp4(data: Data, size: CGSize, cacheKey: String) -> Signal<String, NoError> {
    return Signal({ subscriber in
        let queue = Queue()
        
        queue.async {
            let startTime = CACurrentMediaTime()
            var drawingTime: Double = 0
            var appendingTime: Double = 0
            
            let decompressedData = TGGUnzipData(data)
            if let decompressedData = decompressedData, let player = LottieInstance(data: decompressedData, cacheKey: cacheKey) {
                let endFrame = Int(player.frameCount)
                print("read at \(CACurrentMediaTime() - startTime)")
                
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                let path = NSTemporaryDirectory() + "\(randomId).lz4v"
                guard let fileContext = ManagedFile(queue: queue, path: path, mode: .readwrite) else {
                    return
                }
                
                let scale = size.width / 512.0
                
                var currentFrame: Int32 = 0
                
                var fps: Int32 = player.frameRate
                let _ = fileContext.write(&fps, count: 4)
                var widthValue: Int32 = Int32(size.width)
                var heightValue: Int32 = Int32(size.height)
                let _ = fileContext.write(&widthValue, count: 4)
                let _ = fileContext.write(&heightValue, count: 4)
                
                let frameLength = Int(size.width) * Int(size.height) * 4
                assert(frameLength % 16 == 0)
                
                let currentFrameData = malloc(frameLength)!
                memset(currentFrameData, 0, frameLength)
                
                let yuvaLength = Int(size.width) * Int(size.height) * 2 + Int(size.width) * Int(size.height) / 2
                assert(yuvaLength % 8 == 0)
                var yuvaFrameData = malloc(yuvaLength)!
                memset(yuvaFrameData, 0, yuvaLength)
                
                var previousYuvaFrameData = malloc(yuvaLength)!
                memset(previousYuvaFrameData, 0, yuvaLength)
                
                defer {
                    free(currentFrameData)
                    free(previousYuvaFrameData)
                    free(yuvaFrameData)
                }
                
                var compressedFrameData = Data(count: frameLength)
                let compressedFrameDataLength = compressedFrameData.count
                
                let scratchData = malloc(compression_encode_scratch_buffer_size(COMPRESSION_LZ4))!
                defer {
                    free(scratchData)
                }
                
                while currentFrame < endFrame {
                    let drawStartTime = CACurrentMediaTime()
                    memset(currentFrameData, 0, frameLength)
                    player.renderFrame(with: Int32(currentFrame), into: currentFrameData.assumingMemoryBound(to: UInt8.self), width: Int32(size.width), height: Int32(size.height))
                    
                    let appendStartTime = CACurrentMediaTime()
                    
                    encodeRGBAToYUVA(yuvaFrameData.assumingMemoryBound(to: UInt8.self), currentFrameData.assumingMemoryBound(to: UInt8.self), Int32(size.width), Int32(size.height))
                    //decodeYUVAToRGBA(yuvaFrameData.assumingMemoryBound(to: UInt8.self), singleContext.bytes.assumingMemoryBound(to: UInt8.self), Int32(size.width), Int32(size.height))
                    
                    appendingTime += CACurrentMediaTime() - appendStartTime
                    
                    var lhs = previousYuvaFrameData.assumingMemoryBound(to: UInt64.self)
                    var rhs = yuvaFrameData.assumingMemoryBound(to: UInt64.self)
                    for _ in 0 ..< yuvaLength / 8 {
                        lhs.pointee = rhs.pointee ^ lhs.pointee
                        lhs = lhs.advanced(by: 1)
                        rhs = rhs.advanced(by: 1)
                    }
                    
                    drawingTime += CACurrentMediaTime() - drawStartTime
                    
                    compressedFrameData.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
                        let length = compression_encode_buffer(bytes, compressedFrameDataLength, previousYuvaFrameData.assumingMemoryBound(to: UInt8.self), yuvaLength, scratchData, COMPRESSION_LZ4)
                        var frameLengthValue: Int32 = Int32(length)
                        let _ = fileContext.write(&frameLengthValue, count: 4)
                        let _ = fileContext.write(bytes, count: length)
                    }
                    
                    let tmp = previousYuvaFrameData
                    previousYuvaFrameData = yuvaFrameData
                    yuvaFrameData = tmp
                    
                    currentFrame += 1
                }
                
                subscriber.putNext(path)
                subscriber.putCompletion()
                print("animation render time \(CACurrentMediaTime() - startTime)")
                print("of which drawing time \(drawingTime)")
                print("of which appending time \(appendingTime)")
            }
        }
        return EmptyDisposable
    })
}

func convertCompressedLottieToCombinedMp4(data: Data, size: CGSize) -> Signal<String, NoError> {
    return Signal({ subscriber in
        let startTime = CACurrentMediaTime()
        var drawingTime: Double = 0
        var appendingTime: Double = 0
        
        let decompressedData = TGGUnzipData(data)
        if let decompressedData = decompressedData, let json = (try? JSONSerialization.jsonObject(with: decompressedData, options: [])) as? [AnyHashable: Any] {
            if validateAnimationComposition(json: json) {
                let model = LOTComposition(json: json)
                if let startFrame = model.startFrame?.int32Value, let endFrame = model.endFrame?.int32Value {
                    print("read at \(CACurrentMediaTime() - startTime)")
                    
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
                                let context = DrawingContext(size: videoSize, scale: 1.0, clear: false)
                                
                                let fps: Int32 = model.framerate?.int32Value ?? 30
                                let frameDuration = CMTimeMake(1, fps)
                                
                                assetWriterInput.requestMediaDataWhenReady(on: writeQueue) {
                                    while assetWriterInput.isReadyForMoreMediaData && startFrame + currentFrame < endFrame {
                                        let lastFrameTime = CMTimeMake(Int64(currentFrame - startFrame), fps)
                                        let presentationTime = currentFrame == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)
                                        
                                        let drawStartTime = CACurrentMediaTime()
                                        singleContext.withContext { context in
                                            context.clear(CGRect(origin: CGPoint(), size: size))
                                            context.saveGState()
                                            context.scaleBy(x: scale, y: scale)
                                            container?.renderFrame(startFrame + currentFrame, in: context)
                                            context.restoreGState()
                                        }
                                        
                                        if let image = singleContext.generateImage()?.cgImage {
                                            
                                            let maskDecode = [
                                                CGFloat(1.0), CGFloat(1.0),
                                                CGFloat(1.0), CGFloat(1.0),
                                                CGFloat(1.0), CGFloat(1.0),
                                                CGFloat(1.0), CGFloat(1.0)]
                                            
                                            let maskImage =  CGImage(width: image.width, height: image.height, bitsPerComponent: image.bitsPerComponent, bitsPerPixel: image.bitsPerPixel, bytesPerRow: image.bytesPerRow, space: image.colorSpace!, bitmapInfo:         image.bitmapInfo, provider: image.dataProvider!, decode: maskDecode, shouldInterpolate:  image.shouldInterpolate, intent: image.renderingIntent)!

                                            context.withFlippedContext { context in
                                                context.setFillColor(UIColor.white.cgColor)
                                                context.fill(CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: videoSize))
                                                context.draw(image, in: CGRect(origin: CGPoint(x: 0.0, y: size.height), size: size))
                                                context.draw(maskImage, in: CGRect(origin: CGPoint(), size: size))
                                            }
                                            drawingTime += CACurrentMediaTime() - drawStartTime
                                            
                                            let appendStartTime = CACurrentMediaTime()
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
                                            appendingTime += CACurrentMediaTime() - appendStartTime
                                        }
                                        currentFrame += 1
                                    }
                                    
                                    if startFrame + currentFrame >= endFrame {
                                        assetWriterInput.markAsFinished()
                                        assetWriter.finishWriting {
                                            subscriber.putNext(path)
                                            subscriber.putCompletion()
                                            print("animation render time \(CACurrentMediaTime() - startTime)")
                                            print("of which drawing time \(drawingTime)")
                                            print("of which appending time \(appendingTime)")
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
