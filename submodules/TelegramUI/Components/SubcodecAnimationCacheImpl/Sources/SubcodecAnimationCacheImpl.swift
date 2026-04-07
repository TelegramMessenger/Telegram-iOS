import Foundation
import UIKit
import SwiftSignalKit
import CryptoUtils
import ManagedFile
import AnimationCache
import SubcodecObjC

public struct MbsMetadata {
    public let frameCount: Int
    public let frameDurations: [Double]
}

private func md5Hash(_ string: String) -> String {
    let hashData = string.data(using: .utf8)!.withUnsafeBytes { bytes -> Data in
        return CryptoMD5(bytes.baseAddress!, Int32(bytes.count))
    }
    return hashData.withUnsafeBytes { bytes -> String in
        let uintBytes = bytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
        return String(format: "%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", uintBytes[0], uintBytes[1], uintBytes[2], uintBytes[3], uintBytes[4], uintBytes[5], uintBytes[6], uintBytes[7], uintBytes[8], uintBytes[9], uintBytes[10], uintBytes[11], uintBytes[12], uintBytes[13], uintBytes[14], uintBytes[15])
    }
}

private func itemSubpath(hashString: String, width: Int, height: Int) -> (directory: String, fileName: String) {
    assert(hashString.count == 32)
    let directory = String(hashString[hashString.startIndex ..< hashString.index(hashString.startIndex, offsetBy: 2)])
    return (directory, "\(hashString)_\(width)x\(height)")
}

private func roundUp(_ numToRound: Int, multiple: Int) -> Int {
    if multiple == 0 {
        return numToRound
    }
    let remainder = numToRound % multiple
    if remainder == 0 {
        return numToRound
    }
    return numToRound + multiple - remainder
}

private func convertARGBToYUVA420(
    argb: UnsafePointer<UInt8>,
    width: Int,
    height: Int,
    bytesPerRow: Int
) -> (y: Data, cb: Data, cr: Data, alpha: Data, yStride: Int, cbStride: Int, crStride: Int, alphaStride: Int) {
    let chromaWidth = width / 2
    let chromaHeight = height / 2

    var yData = Data(count: width * height)
    var cbData = Data(count: chromaWidth * chromaHeight)
    var crData = Data(count: chromaWidth * chromaHeight)
    var alphaData = Data(count: width * height)

    yData.withUnsafeMutableBytes { yBuf in
        cbData.withUnsafeMutableBytes { cbBuf in
            crData.withUnsafeMutableBytes { crBuf in
                alphaData.withUnsafeMutableBytes { aBuf in
                    let yPtr = yBuf.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    let cbPtr = cbBuf.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    let crPtr = crBuf.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    let aPtr = aBuf.baseAddress!.assumingMemoryBound(to: UInt8.self)

                    for row in 0 ..< height {
                        let srcRow = argb.advanced(by: row * bytesPerRow)
                        for col in 0 ..< width {
                            let px = srcRow.advanced(by: col * 4)
                            // BGRA layout (CoreGraphics premultiplied)
                            let b = Int(px[0])
                            let g = Int(px[1])
                            let r = Int(px[2])
                            let a = Int(px[3])

                            // Un-premultiply
                            let rr: Int
                            let gg: Int
                            let bb: Int
                            if a > 0 {
                                rr = min(255, r * 255 / a)
                                gg = min(255, g * 255 / a)
                                bb = min(255, b * 255 / a)
                            } else {
                                rr = 0
                                gg = 0
                                bb = 0
                            }

                            // BT.709
                            let y = 16 + (65 * rr + 129 * gg + 25 * bb + 128) / 256
                            yPtr[row * width + col] = UInt8(clamping: y)
                            aPtr[row * width + col] = UInt8(a)
                        }
                    }

                    // Chroma at half resolution (average 2x2 blocks)
                    for row in 0 ..< chromaHeight {
                        for col in 0 ..< chromaWidth {
                            var sumR = 0
                            var sumG = 0
                            var sumB = 0
                            for dy in 0 ..< 2 {
                                for dx in 0 ..< 2 {
                                    let srcRow = argb.advanced(by: (row * 2 + dy) * bytesPerRow)
                                    let px = srcRow.advanced(by: (col * 2 + dx) * 4)
                                    let b = Int(px[0])
                                    let g = Int(px[1])
                                    let r = Int(px[2])
                                    let a = Int(px[3])
                                    if a > 0 {
                                        sumR += min(255, r * 255 / a)
                                        sumG += min(255, g * 255 / a)
                                        sumB += min(255, b * 255 / a)
                                    }
                                }
                            }
                            let avgR = sumR / 4
                            let avgG = sumG / 4
                            let avgB = sumB / 4

                            let cb = 128 + (-38 * avgR - 74 * avgG + 112 * avgB + 128) / 256
                            let cr = 128 + (112 * avgR - 94 * avgG - 18 * avgB + 128) / 256
                            cbPtr[row * chromaWidth + col] = UInt8(clamping: cb)
                            crPtr[row * chromaWidth + col] = UInt8(clamping: cr)
                        }
                    }
                }
            }
        }
    }

    return (yData, cbData, crData, alphaData, width, chromaWidth, chromaWidth, width)
}

private final class AnimationCacheItemWriterImpl: AnimationCacheItemWriter {
    struct CompressedResult {
        var mbsPath: String
        var metaPath: String
    }

    var queue: Queue {
        return self.innerQueue
    }
    let innerQueue: Queue
    var isCancelled: Bool = false

    private let mbsOutputPath: String
    private let metaOutputPath: String
    private let completion: (CompressedResult?) -> Void

    private var spriteExtractor: SCSprite?
    private var frameDurations: [Double] = []
    private var isFailed: Bool = false
    private var isFinished: Bool = false
    private var spriteWidth: Int = 0
    private var spriteHeight: Int = 0

    private let lock = Lock()

    init?(queue: Queue, allocateTempFile: @escaping () -> String, completion: @escaping (CompressedResult?) -> Void) {
        self.innerQueue = queue
        self.mbsOutputPath = allocateTempFile()
        self.metaOutputPath = allocateTempFile()
        self.completion = completion
    }

    func add(with drawingBlock: (AnimationCacheItemDrawingSurface) -> Double?, proposedWidth: Int, proposedHeight: Int, insertKeyframe: Bool) {
        self.lock.locked {
            if self.isFailed || self.isFinished {
                return
            }

            let width = roundUp(proposedWidth, multiple: 16)
            let height = roundUp(proposedHeight, multiple: 16)

            if width == 0 || height == 0 {
                self.isFailed = true
                return
            }

            // Create extractor on first frame
            if self.spriteExtractor == nil {
                self.spriteWidth = width
                self.spriteHeight = height
                let spriteSize = max(width, height)
                do {
                    self.spriteExtractor = try SCSprite.extractor(withSpriteSize: Int32(spriteSize), qp: 26, outputPath: self.mbsOutputPath)
                } catch {
                    self.isFailed = true
                    return
                }
            }

            guard self.spriteWidth == width && self.spriteHeight == height else {
                self.isFailed = true
                return
            }

            // Allocate ARGB surface
            let bytesPerRow = width * 4
            let bufferSize = height * bytesPerRow
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }
            memset(buffer, 0, bufferSize)

            guard let duration = drawingBlock(AnimationCacheItemDrawingSurface(
                argb: buffer,
                width: width,
                height: height,
                bytesPerRow: bytesPerRow,
                length: bufferSize
            )) else {
                return
            }

            // Convert ARGB → YUV planes
            let planes = convertARGBToYUVA420(
                argb: buffer,
                width: width,
                height: height,
                bytesPerRow: bytesPerRow
            )

            // Feed to extractor
            do {
                try self.spriteExtractor?.addFrameY(
                    planes.y, yStride: Int32(planes.yStride),
                    cb: planes.cb, cbStride: Int32(planes.cbStride),
                    cr: planes.cr, crStride: Int32(planes.crStride),
                    alpha: planes.alpha, alphaStride: Int32(planes.alphaStride)
                )
            } catch {
                self.isFailed = true
                return
            }

            self.frameDurations.append(duration)
        }
    }

    func finish() {
        var result: CompressedResult?

        self.lock.locked {
            if self.isFinished {
                return
            }
            self.isFinished = true

            if self.isFailed || self.spriteExtractor == nil {
                return
            }

            do {
                try self.spriteExtractor?.finalizeExtraction()
            } catch {
                self.isFailed = true
                return
            }

            // Write metadata file: frame count + durations
            var metaData = Data()
            var frameCount = UInt32(self.frameDurations.count)
            metaData.append(Data(bytes: &frameCount, count: 4))
            for duration in self.frameDurations {
                var d = Float32(duration)
                metaData.append(Data(bytes: &d, count: 4))
            }
            do {
                try metaData.write(to: URL(fileURLWithPath: self.metaOutputPath))
            } catch {
                self.isFailed = true
                return
            }

            result = CompressedResult(mbsPath: self.mbsOutputPath, metaPath: self.metaOutputPath)
        }

        if !self.isFailed {
            self.completion(result)
        } else {
            let _ = try? FileManager.default.removeItem(atPath: self.mbsOutputPath)
            let _ = try? FileManager.default.removeItem(atPath: self.metaOutputPath)
            self.completion(nil)
        }
    }
}
