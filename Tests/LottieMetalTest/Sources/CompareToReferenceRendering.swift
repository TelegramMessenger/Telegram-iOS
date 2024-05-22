import Foundation
import UIKit
import LottieMetal
import LottieCpp
import RLottieBinding
import Display
import Accelerate
import QOILoader
import SoftwareLottieRenderer
import LottieSwift

@available(iOS 13.0, *)
func areImagesEqual(_ lhs: UIImage, _ rhs: UIImage) -> UIImage? {
    let lhsBuffer = try! vImage_Buffer(cgImage: lhs.cgImage!)
    let rhsBuffer = try! vImage_Buffer(cgImage: rhs.cgImage!)
    
    let maxDifferenceCount = Int((Double(Int(lhs.size.width) * Int(lhs.size.height)) * 0.01))
    
    var foundDifferenceCount = 0
    
    outer: for y in 0 ..< Int(lhs.size.height) {
        let lhsRowPixels = lhsBuffer.data.assumingMemoryBound(to: UInt8.self).advanced(by: y * lhsBuffer.rowBytes)
        let rhsRowPixels = rhsBuffer.data.assumingMemoryBound(to: UInt8.self).advanced(by: y * lhsBuffer.rowBytes)
        
        for x in 0 ..< Int(lhs.size.width) {
            let lhs0 = lhsRowPixels.advanced(by: x * 4 + 0).pointee
            let lhs1 = lhsRowPixels.advanced(by: x * 4 + 1).pointee
            let lhs2 = lhsRowPixels.advanced(by: x * 4 + 2).pointee
            let lhs3 = lhsRowPixels.advanced(by: x * 4 + 3).pointee
            
            let rhs0 = rhsRowPixels.advanced(by: x * 4 + 0).pointee
            let rhs1 = rhsRowPixels.advanced(by: x * 4 + 1).pointee
            let rhs2 = rhsRowPixels.advanced(by: x * 4 + 2).pointee
            let rhs3 = rhsRowPixels.advanced(by: x * 4 + 3).pointee
            
            let maxDiff = 25
            if abs(Int(lhs0) - Int(rhs0)) > maxDiff || abs(Int(lhs1) - Int(rhs1)) > maxDiff || abs(Int(lhs2) - Int(rhs2)) > maxDiff || abs(Int(lhs3) - Int(rhs3)) > maxDiff {
                
                /*if false {
                    lhsRowPixels.advanced(by: x * 4 + 0).pointee = 255
                    lhsRowPixels.advanced(by: x * 4 + 1).pointee = 0
                    lhsRowPixels.advanced(by: x * 4 + 2).pointee = 0
                    lhsRowPixels.advanced(by: x * 4 + 3).pointee = 255
                }*/
                
                foundDifferenceCount += 1
            }
        }
    }
    
    lhsBuffer.free()
    rhsBuffer.free()
    
    if foundDifferenceCount > maxDifferenceCount {
        let colorSpace = Unmanaged<CGColorSpace>.passRetained(lhs.cgImage!.colorSpace!)
        let diffImage = try! lhsBuffer.createCGImage(format: vImage_CGImageFormat(bitsPerComponent: 8, bitsPerPixel: 32, colorSpace: colorSpace, bitmapInfo: lhs.cgImage!.bitmapInfo, version: 0, decode: nil, renderingIntent: .defaultIntent), flags: .doNotTile)
        return UIImage(cgImage: diffImage)
    } else {
        return nil
    }
}

@available(iOS 13.0, *)
func processDrawAnimation(baseCachePath: String, path: String, name: String, size: CGSize, alwaysDraw: Bool, updateImage: @escaping (UIImage?, UIImage?) -> Void) async -> Bool {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
        print("Could not load \(path)")
        return false
    }
    
    guard let animation = LottieAnimation(data: data) else {
        print("Could not parse animation at \(path)")
        return false
    }
    
    let layer = LottieAnimationContainer(animation: animation)
    
    let cacheFolderPath = cacheReferenceFolderPath(baseCachePath: baseCachePath, width: Int(size.width), name: name)
    if !FileManager.default.fileExists(atPath: cacheFolderPath) {
        let _ = await cacheReferenceAnimation(baseCachePath: baseCachePath, width: Int(size.width), path: path, name: name)
    }
    
    let renderer = SoftwareLottieRenderer(animationContainer: layer)
    
    for i in 0 ..< min(100000, animation.frameCount) {
        let frameResult = autoreleasepool {
            let frameIndex = i % animation.frameCount
            
            let referenceImageData = try! Data(contentsOf: URL(fileURLWithPath: cacheFolderPath + "/frame\(frameIndex)"))
            let referenceImage = decompressImageFrame(data: referenceImageData)
            
            layer.update(frameIndex)
            let image = renderer.render(for: size, useReferenceRendering: true)!
            
            if let diffImage = areImagesEqual(image, referenceImage) {
                updateImage(diffImage, referenceImage)
                
                print("Mismatch in frame \(frameIndex)")
                return false
            } else {
                if alwaysDraw {
                    updateImage(image, referenceImage)
                }
                return true
            }
        }
        
        /*if #available(iOS 16.0, *) {
            try? await Task.sleep(for: .seconds(0.1))
        }*/
        
        if !frameResult {
            return false
        }
    }
    
    return true
}

private func processAnimationFolder(basePath: String, path: String, stopOnFailure: Bool, process: (String, String) -> Bool) -> Bool {
    let directoryPath = "\(basePath)\(path.isEmpty ? "" : "/")/\(path)"
    for fileName in try! FileManager.default.contentsOfDirectory(atPath: directoryPath) {
        let filePath = directoryPath + "/" + fileName
        var isDirectory = ObjCBool(false)
        if FileManager.default.fileExists(atPath: filePath, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                if !processAnimationFolder(basePath: basePath, path: "\(path)\(path.isEmpty ? "" : "/")/\(fileName)", stopOnFailure: stopOnFailure, process: process) {
                    if stopOnFailure {
                        return false
                    }
                }
            } else if fileName.hasSuffix("json") {
                var processAnimationResult = false
                autoreleasepool {
                    processAnimationResult = process(filePath, fileName)
                }
                if !processAnimationResult {
                    print("Error processing \(path)\(path.isEmpty ? "" : "/")\(fileName)")
                    if stopOnFailure {
                        return false
                    }
                } else {
                    print("[OK] processing \(path)\(path.isEmpty ? "" : "/")\(fileName)")
                }
            }
        }
    }
    return true
}

func buildAnimationFolderItems(basePath: String, path: String) -> [(String, String)] {
    var result: [(String, String)] = []
    
    let directoryPath = "\(basePath)\(path.isEmpty ? "" : "/")/\(path)"
    for fileName in try! FileManager.default.contentsOfDirectory(atPath: directoryPath) {
        let filePath = directoryPath + "/" + fileName
        var isDirectory = ObjCBool(false)
        if FileManager.default.fileExists(atPath: filePath, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                result.append(contentsOf: buildAnimationFolderItems(basePath: basePath, path: "\(path)\(path.isEmpty ? "" : "/")/\(fileName)"))
            } else if fileName.hasSuffix("json") {
                result.append((filePath, fileName))
            }
        }
    }
    
    return result
}

@available (iOS 13.0, *)
private func processAnimationFolderItems(items: [(String, String)], countPerBucket: Int, stopOnFailure: Bool, process: @escaping (String, String, Bool) async -> Bool) async -> Bool {
    let bucketCount = items.count / countPerBucket
    var buckets: [[(String, String)]] = []
    for item in items {
        if buckets.isEmpty {
            buckets.append([])
        }
        if buckets[buckets.count - 1].count < bucketCount {
            buckets[buckets.count - 1].append(item)
        } else {
            buckets.append([item])
        }
    }
    
    var count = 0
    for bucket in buckets {
        for (filePath, fileName) in bucket {
            var processAnimationResult = false
            processAnimationResult = await process(filePath, fileName, true)
            if !processAnimationResult {
                print("Error processing \(fileName)")
                if stopOnFailure {
                    return false
                }
            } else {
                count += 1
                print("[OK \(count) / \(items.count)] processing \(fileName)")
            }
        }
    }
    
    return true
}

@available(iOS 13.0, *)
private func processAnimationFolderItemsParallel(items: [(String, String)], stopOnFailure: Bool, process: @escaping (String, String, Bool) async -> Bool) async -> Bool {
    let bucketCount = items.count / 7
    var buckets: [[(String, String)]] = []
    for item in items {
        if buckets.isEmpty {
            buckets.append([])
        }
        if buckets[buckets.count - 1].count < bucketCount {
            buckets[buckets.count - 1].append(item)
        } else {
            buckets.append([item])
        }
    }
    
    class AtomicCounter {
        var value: Int = 0
    }
    let count = AtomicCounter()
    let itemCount = items.count
    let countQueue = DispatchQueue(label: "com.example.count-queue")
    
    let result = await withTaskGroup(of: Bool.self, body: { group in
        var alwaysDraw = true
        for bucket in buckets {
            let alwaysDrawValue = alwaysDraw
            alwaysDraw = false
            group.addTask(operation: {
                for (filePath, fileName) in bucket {
                    var processAnimationResult = false
                    processAnimationResult = await process(filePath, fileName, alwaysDrawValue)
                    if !processAnimationResult {
                        print("Error processing \(fileName)")
                        if stopOnFailure {
                            return false
                        }
                    } else {
                        countQueue.async {
                            count.value += 1
                            print("[OK \(count.value) / \(itemCount)] processing \(fileName)")
                        }
                    }
                }
                return true
            })
        }
        
        for await result in group {
            if !result {
                return false
            }
        }
        return true
    })

    return result
}

@available (iOS 13.0, *)
func processAnimationFolderAsync(basePath: String, path: String, stopOnFailure: Bool, process: @escaping (String, String, Bool) async -> Bool) async -> Bool {
    let items = buildAnimationFolderItems(basePath: basePath, path: path)
    return await processAnimationFolderItems(items: items, countPerBucket: 1, stopOnFailure: stopOnFailure, process: process)
}

@available(iOS 13.0, *)
func processAnimationFolderParallel(basePath: String, path: String, stopOnFailure: Bool, process: @escaping (String, String, Bool) async -> Bool) async -> Bool {
    let items = buildAnimationFolderItems(basePath: basePath, path: path)
    return await processAnimationFolderItemsParallel(items: items, stopOnFailure: stopOnFailure, process: process)
}

func cacheReferenceFolderPath(baseCachePath: String, width: Int, name: String) -> String {
    return baseCachePath + "/" + name + "_\(width)"
}

func compressImageFrame(image: UIImage) -> Data {
    return encodeImageQOI(image)!
}

func decompressImageFrame(data: Data) -> UIImage {
    return decodeImageQOI(data)!
}

@MainActor
func cacheReferenceAnimation(baseCachePath: String, width: Int, path: String, name: String) -> String {
    let targetFolderPath = cacheReferenceFolderPath(baseCachePath: baseCachePath, width: width, name: name)
    if FileManager.default.fileExists(atPath: targetFolderPath) {
        return targetFolderPath
    }
    
    guard let referenceAnimation = Animation.filepath(path) else {
        preconditionFailure("Could not parse reference animation at \(path)")
    }
    let referenceLayer = MainThreadAnimationLayer(animation: referenceAnimation, imageProvider: BlankImageProvider(), textProvider: DefaultTextProvider(), fontProvider: DefaultFontProvider())
    
    let cacheFolderPath = NSTemporaryDirectory() + "\(UInt64.random(in: 0 ... UInt64.max))"
    let _ = try? FileManager.default.createDirectory(atPath: cacheFolderPath, withIntermediateDirectories: true)
    
    let frameCount = Int(referenceAnimation.endFrame - referenceAnimation.startFrame)
    
    let size = CGSize(width: CGFloat(width), height: CGFloat(width))
    
    for i in 0 ..< min(100000, frameCount) {
        let frameIndex = i % frameCount
        
        referenceLayer.currentFrame = CGFloat(frameIndex)
        referenceLayer.displayUpdate()
        referenceLayer.position = referenceAnimation.bounds.center
        
        referenceLayer.isOpaque = false
        referenceLayer.backgroundColor = nil
        let referenceContext = ImageContext(width: width, height: width)
        referenceContext.context.clear(CGRect(origin: CGPoint(), size: size))
        referenceContext.context.scaleBy(x: size.width / CGFloat(referenceAnimation.width), y: size.height / CGFloat(referenceAnimation.height))
        
        referenceLayer.render(in: referenceContext.context)
        
        let referenceImage = referenceContext.makeImage()
        try! compressImageFrame(image: referenceImage).write(to: URL(fileURLWithPath: cacheFolderPath + "/frame\(i)"))
    }
    
    let _ = try! FileManager.default.moveItem(atPath: cacheFolderPath, toPath: targetFolderPath)
    
    return targetFolderPath
}
