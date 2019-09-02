import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import Display
import TelegramCore
import Compression
import GZip
import RLottieBinding
import MediaResources
import MobileCoreServices
import MediaResources
import YuvConversion

let colorKeyRegex = try? NSRegularExpression(pattern: "\"k\":\\[[\\d\\.]+\\,[\\d\\.]+\\,[\\d\\.]+\\,[\\d\\.]+\\]")

private func transformedWithFitzModifier(data: Data, fitzModifier: EmojiFitzModifier?) -> Data {
    if let fitzModifier = fitzModifier, var string = String(data: data, encoding: .utf8) {        
        var colors: [UIColor] = [0xf77e41, 0xffb139, 0xffd140, 0xffdf79].map { UIColor(rgb: $0) }
        let replacementColors: [UIColor]
        switch fitzModifier {
            case .type12:
                replacementColors = [0xca907a, 0xedc5a5, 0xf7e3c3, 0xfbefd6].map { UIColor(rgb: $0) }
            case .type3:
                replacementColors = [0xaa7c60, 0xc8a987, 0xddc89f, 0xe6d6b2].map { UIColor(rgb: $0) }
            case .type4:
                replacementColors = [0x8c6148, 0xad8562, 0xc49e76, 0xd4b188].map { UIColor(rgb: $0) }
            case .type5:
                replacementColors = [0x6e3c2c, 0x925a34, 0xa16e46, 0xac7a52].map { UIColor(rgb: $0) }
            case .type6:
                replacementColors = [0x291c12, 0x472a22, 0x573b30, 0x68493c].map { UIColor(rgb: $0) }
        }
        
        func colorToString(_ color: UIColor) -> String {
            var r: CGFloat = 0.0
            var g: CGFloat = 0.0
            var b: CGFloat = 0.0
            if color.getRed(&r, green: &g, blue: &b, alpha: nil) {
                return "\"k\":[\(r),\(g),\(b),1]"
            }
            return ""
        }
        
        func match(_ a: Double, _ b: Double, eps: Double) -> Bool {
            return abs(a - b) < eps
        }
        
        var replacements: [(NSTextCheckingResult, String)] = []
        
        if let colorKeyRegex = colorKeyRegex {
            let results = colorKeyRegex.matches(in: string, range: NSRange(string.startIndex..., in: string))
            for result in results.reversed()  {
                if let range = Range(result.range, in: string) {
                    let substring = String(string[range])
                    let color = substring[substring.index(string.startIndex, offsetBy: "\"k\":[".count) ..< substring.index(before: substring.endIndex)]
                    let components = color.split(separator: ",")
                    if components.count == 4, let r = Double(components[0]), let g = Double(components[1]), let b = Double(components[2]), let a = Double(components[3]) {
                        if match(a, 1.0, eps: 0.01) {
                            for i in 0 ..< colors.count {
                                let color = colors[i]
                                var cr: CGFloat = 0.0
                                var cg: CGFloat = 0.0
                                var cb: CGFloat = 0.0
                                if color.getRed(&cr, green: &cg, blue: &cb, alpha: nil) {
                                    if match(r, Double(cr), eps: 0.01) && match(g, Double(cg), eps: 0.01) && match(b, Double(cb), eps: 0.01) {
                                        replacements.append((result, colorToString(replacementColors[i])))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        for (result, text) in replacements {
            if let range = Range(result.range, in: string) {
                string = string.replacingCharacters(in: range, with: text)
            }
        }
        
        return string.data(using: .utf8) ?? data
    } else {
        return data
    }
}

public func fetchCompressedLottieFirstFrameAJpeg(data: Data, size: CGSize, fitzModifier: EmojiFitzModifier? = nil, cacheKey: String) -> Signal<TempBoxFile, NoError> {
    return Signal({ subscriber in
        let queue = Queue()
        
        let cancelled = Atomic<Bool>(value: false)
        
        queue.async {
            if cancelled.with({ $0 }) {
                return
            }
            
            let decompressedData = TGGUnzipData(data, 8 * 1024 * 1024)
            if let decompressedData = decompressedData {
                let decompressedData = transformedWithFitzModifier(data: decompressedData, fitzModifier: fitzModifier)
                if let player = LottieInstance(data: decompressedData, cacheKey: cacheKey) {
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
                    
                    if let colorSourceImage = context.generateImage(), let alphaImage = generateGrayscaleAlphaMaskImage(image: colorSourceImage) {
                        let colorContext = DrawingContext(size: size, scale: 1.0, clear: false)
                        colorContext.withFlippedContext { c in
                            c.setFillColor(UIColor.black.cgColor)
                            c.fill(CGRect(origin: CGPoint(), size: size))
                            c.draw(colorSourceImage.cgImage!, in: CGRect(origin: CGPoint(), size: size))
                        }
                        guard let colorImage = colorContext.generateImage() else {
                            return
                        }
                        
                        let colorData = NSMutableData()
                        let alphaData = NSMutableData()
                        
                        if let colorDestination = CGImageDestinationCreateWithData(colorData as CFMutableData, kUTTypeJPEG, 1, nil), let alphaDestination = CGImageDestinationCreateWithData(alphaData as CFMutableData, kUTTypeJPEG, 1, nil) {
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
public func experimentalConvertCompressedLottieToCombinedMp4(data: Data, size: CGSize, fitzModifier: EmojiFitzModifier? = nil, cacheKey: String) -> Signal<String, NoError> {
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
            if let decompressedData = decompressedData {
                let decompressedData = transformedWithFitzModifier(data: decompressedData, fitzModifier: fitzModifier)
                if let player = LottieInstance(data: decompressedData, cacheKey: cacheKey) {
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
                    
                    let bytesPerRow = (4 * Int(size.width) + 15) & (~15)
                    
                    var currentFrame: Int32 = 0
                    
                    var fps: Int32 = player.frameRate
                    var frameCount: Int32 = player.frameCount
                    let _ = fileContext.write(&fps, count: 4)
                    let _ = fileContext.write(&frameCount, count: 4)
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
                        var lhsRest = previousYuvaFrameData.assumingMemoryBound(to: UInt8.self).advanced(by: (yuvaLength / 8) * 8)
                        var rhsRest = yuvaFrameData.assumingMemoryBound(to: UInt8.self).advanced(by: (yuvaLength / 8) * 8)
                        for _ in (yuvaLength / 8) * 8 ..< yuvaLength {
                            lhsRest.pointee = rhsRest.pointee ^ lhsRest.pointee
                            lhsRest = lhsRest.advanced(by: 1)
                            rhsRest = rhsRest.advanced(by: 1)
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
            }
        }))
        return ActionDisposable {
            let _ = cancelled.swap(true)
        }
    })
}
