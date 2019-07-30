import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import Display
import TelegramCore
import AVFoundation
import Lottie
import TelegramUIPrivateModule
import Compression
import GZip
import RLottie
import MobileCoreServices

public struct LocalBundleResourceId: MediaResourceId {
    public let name: String
    public let ext: String
    
    public var uniqueId: String {
        return "local-bundle-\(self.name)-\(self.ext)"
    }
    
    public var hashValue: Int {
        return self.name.hashValue
    }
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? LocalBundleResourceId {
            return self.name == to.name && self.ext == to.ext
        } else {
            return false
        }
    }
}

public class LocalBundleResource: TelegramMediaResource {
    public let name: String
    public let ext: String
    
    public init(name: String, ext: String) {
        self.name = name
        self.ext = ext
    }
    
    public required init(decoder: PostboxDecoder) {
        self.name = decoder.decodeStringForKey("n", orElse: "")
        self.ext = decoder.decodeStringForKey("e", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.name, forKey: "n")
        encoder.encodeString(self.ext, forKey: "e")
    }
    
    public var id: MediaResourceId {
        return LocalBundleResourceId(name: self.name, ext: self.ext)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? LocalBundleResource {
            return self.name == to.name && self.ext == to.ext
        } else {
            return false
        }
    }
}

func fetchCompressedLottieFirstFrameAJpeg(data: Data, size: CGSize, cacheKey: String) -> Signal<TempBoxFile, NoError> {
    return Signal({ subscriber in
        let queue = Queue()
        
        let cancelled = Atomic<Bool>(value: false)
        
        queue.async {
            if cancelled.with({ $0 }) {
                return
            }
            
            let decompressedData = TGGUnzipData(data, 8 * 1024 * 1024)
            if let decompressedData = decompressedData, let player = LottieInstance(data: decompressedData, cacheKey: cacheKey) {
                if cancelled.with({ $0 }) {
                    return
                }
                
                let context = DrawingContext(size: size, scale: 1.0, clear: true)
                player.renderFrame(with: 0, into: context.bytes.assumingMemoryBound(to: UInt8.self), width: Int32(size.width), height: Int32(size.height), bytesPerRow: Int32(context.bytesPerRow))
                
                let yuvaPixelsPerAlphaRow = (Int(size.width) + 1) & (~1)
                assert(yuvaPixelsPerAlphaRow % 2 == 0)
                
                let yuvaLength = Int(size.width) * Int(size.height) * 2 + yuvaPixelsPerAlphaRow * Int(size.height) / 2
                var yuvaFrameData = malloc(yuvaLength)!
                memset(yuvaFrameData, 0, yuvaLength)
                
                defer {
                    free(yuvaFrameData)
                }
                
                encodeRGBAToYUVA(yuvaFrameData.assumingMemoryBound(to: UInt8.self), context.bytes.assumingMemoryBound(to: UInt8.self), Int32(size.width), Int32(size.height), Int32(context.bytesPerRow))
                decodeYUVAToRGBA(yuvaFrameData.assumingMemoryBound(to: UInt8.self), context.bytes.assumingMemoryBound(to: UInt8.self), Int32(size.width), Int32(size.height), Int32(context.bytesPerRow))
                
                if let colorImage = context.generateImage() {
                    let colorData = NSMutableData()
                    let alphaData = NSMutableData()
                    
                    let alphaImage = generateImage(size, contextGenerator: { size, context in
                        context.setFillColor(UIColor.white.cgColor)
                        context.fill(CGRect(origin: CGPoint(), size: size))
                        context.clip(to: CGRect(origin: CGPoint(), size: size), mask: colorImage.cgImage!)
                        context.setFillColor(UIColor.black.cgColor)
                        context.fill(CGRect(origin: CGPoint(), size: size))
                    }, scale: 1.0)
                    
                    if let alphaImage = alphaImage, let colorDestination = CGImageDestinationCreateWithData(colorData as CFMutableData, kUTTypeJPEG, 1, nil), let alphaDestination = CGImageDestinationCreateWithData(alphaData as CFMutableData, kUTTypeJPEG, 1, nil) {
                        CGImageDestinationSetProperties(colorDestination, [:] as CFDictionary)
                        CGImageDestinationSetProperties(alphaDestination, [:] as CFDictionary)
                        
                        let colorQuality: Float
                        let alphaQuality: Float
                        colorQuality = 0.5
                        alphaQuality = 0.4
                        
                        let options = NSMutableDictionary()
                        options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                        
                        let optionsAlpha = NSMutableDictionary()
                        optionsAlpha.setObject(alphaQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                        
                        CGImageDestinationAddImage(colorDestination, colorImage.cgImage!, options as CFDictionary)
                        CGImageDestinationAddImage(alphaDestination, alphaImage.cgImage!, optionsAlpha as CFDictionary)
                        if CGImageDestinationFinalize(colorDestination) && CGImageDestinationFinalize(alphaDestination) {
                            let finalData = NSMutableData()
                            var colorSize: Int32 = Int32(colorData.length)
                            finalData.append(&colorSize, length: 4)
                            finalData.append(colorData as Data)
                            var alphaSize: Int32 = Int32(alphaData.length)
                            finalData.append(&alphaSize, length: 4)
                            finalData.append(alphaData as Data)
                            
                            let tempFile = TempBox.shared.tempFile(fileName: "image.ajpg")
                            let _ = try? finalData.write(to: URL(fileURLWithPath: tempFile.path), options: [])
                            subscriber.putNext(tempFile)
                            subscriber.putCompletion()
                        }
                    }
                }
            }
        }
        return ActionDisposable {
            let _ = cancelled.swap(true)
        }
    })
}

private let threadPool: ThreadPool = {
    return ThreadPool(threadCount: 3, threadPriority: 0.5)
}()

@available(iOS 9.0, *)
func experimentalConvertCompressedLottieToCombinedMp4(data: Data, size: CGSize, cacheKey: String) -> Signal<String, NoError> {
    return Signal({ subscriber in
        let cancelled = Atomic<Bool>(value: false)
        
        threadPool.addTask(ThreadPoolTask({ _ in
            if cancelled.with({ $0 }) {
               //print("cancelled 1")
                return
            }
            
            let startTime = CACurrentMediaTime()
            var drawingTime: Double = 0
            var appendingTime: Double = 0
            var deltaTime: Double = 0
            var compressionTime: Double = 0
            
            let decompressedData = TGGUnzipData(data, 8 * 1024 * 1024)
            if let decompressedData = decompressedData, let player = LottieInstance(data: decompressedData, cacheKey: cacheKey) {
                let endFrame = Int(player.frameCount)
                
                if cancelled.with({ $0 }) {
                    //print("cancelled 2")
                    return
                }
                
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                let path = NSTemporaryDirectory() + "\(randomId).lz4v"
                guard let fileContext = ManagedFile(queue: nil, path: path, mode: .readwrite) else {
                    return
                }
                
                let scale = size.width / 512.0
                
                let bytesPerRow = (4 * Int(size.width) + 15) & (~15)
                
                var currentFrame: Int32 = 0
                
                var fps: Int32 = player.frameRate
                let _ = fileContext.write(&fps, count: 4)
                var widthValue: Int32 = Int32(size.width)
                var heightValue: Int32 = Int32(size.height)
                var bytesPerRowValue: Int32 = Int32(bytesPerRow)
                let _ = fileContext.write(&widthValue, count: 4)
                let _ = fileContext.write(&heightValue, count: 4)
                let _ = fileContext.write(&bytesPerRowValue, count: 4)
                
                let frameLength = bytesPerRow * Int(size.height)
                assert(frameLength % 16 == 0)
                
                let currentFrameData = malloc(frameLength)!
                memset(currentFrameData, 0, frameLength)
                
                let yuvaPixelsPerAlphaRow = (Int(size.width) + 1) & (~1)
                assert(yuvaPixelsPerAlphaRow % 2 == 0)
                
                let yuvaLength = Int(size.width) * Int(size.height) * 2 + yuvaPixelsPerAlphaRow * Int(size.height) / 2
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
                
                let scratchData = malloc(compression_encode_scratch_buffer_size(COMPRESSION_LZFSE))!
                defer {
                    free(scratchData)
                }
                
                while currentFrame < endFrame {
                    if cancelled.with({ $0 }) {
                        //print("cancelled 3")
                        return
                    }
                    
                    let drawStartTime = CACurrentMediaTime()
                    memset(currentFrameData, 0, frameLength)
                    player.renderFrame(with: Int32(currentFrame), into: currentFrameData.assumingMemoryBound(to: UInt8.self), width: Int32(size.width), height: Int32(size.height), bytesPerRow: Int32(bytesPerRow))
                    drawingTime += CACurrentMediaTime() - drawStartTime
                    
                    let appendStartTime = CACurrentMediaTime()
                    
                    encodeRGBAToYUVA(yuvaFrameData.assumingMemoryBound(to: UInt8.self), currentFrameData.assumingMemoryBound(to: UInt8.self), Int32(size.width), Int32(size.height), Int32(bytesPerRow))
                    
                    appendingTime += CACurrentMediaTime() - appendStartTime
                    
                    let deltaStartTime = CACurrentMediaTime()
                    var lhs = previousYuvaFrameData.assumingMemoryBound(to: UInt64.self)
                    var rhs = yuvaFrameData.assumingMemoryBound(to: UInt64.self)
                    for _ in 0 ..< yuvaLength / 8 {
                        lhs.pointee = rhs.pointee ^ lhs.pointee
                        lhs = lhs.advanced(by: 1)
                        rhs = rhs.advanced(by: 1)
                    }
                    for i in (yuvaLength / 8) * 8 ..< yuvaLength {
                        
                    }
                    deltaTime += CACurrentMediaTime() - deltaStartTime
                    
                    let compressionStartTime = CACurrentMediaTime()
                    compressedFrameData.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
                        let length = compression_encode_buffer(bytes, compressedFrameDataLength, previousYuvaFrameData.assumingMemoryBound(to: UInt8.self), yuvaLength, scratchData, COMPRESSION_LZFSE)
                        var frameLengthValue: Int32 = Int32(length)
                        let _ = fileContext.write(&frameLengthValue, count: 4)
                        let _ = fileContext.write(bytes, count: length)
                    }
                    
                    let tmp = previousYuvaFrameData
                    previousYuvaFrameData = yuvaFrameData
                    yuvaFrameData = tmp
                    
                    compressionTime += CACurrentMediaTime() - compressionStartTime
                    
                    currentFrame += 1
                }
                
                subscriber.putNext(path)
                subscriber.putCompletion()
                print("animation render time \(CACurrentMediaTime() - startTime)")
                print("of which drawing time \(drawingTime)")
                print("of which appending time \(appendingTime)")
                print("of which delta time \(deltaTime)")
                
                print("of which compression time \(compressionTime)")
            }
        }))
        return ActionDisposable {
            let _ = cancelled.swap(true)
        }
    })
}

private final class LocalBundleResourceCopyFile : MediaResourceDataFetchCopyLocalItem {
    let path: String
    init(path: String) {
        self.path = path
    }
    func copyTo(url: URL) -> Bool {
        do {
            try FileManager.default.copyItem(at: URL(fileURLWithPath: self.path), to: url)
            return true
        } catch {
            return false
        }
    }
}

func fetchLocalBundleResource(postbox: Postbox, resource: LocalBundleResource) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return Signal { subscriber in
        if let path = frameworkBundle.path(forResource: resource.name, ofType: resource.ext), let _ = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedRead]) {
            subscriber.putNext(.copyLocalItem(LocalBundleResourceCopyFile(path: path)))
            subscriber.putCompletion()
        }
        return EmptyDisposable
    }
}
