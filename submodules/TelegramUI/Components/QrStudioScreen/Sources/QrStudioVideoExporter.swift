import Foundation
import UIKit
import AVFoundation

final class QrStudioVideoExporter {
    private let scene: QrStudioExportScene
    private let canvas: QrStudioExportCanvas
    private let frameCount: Int
    private let queue = DispatchQueue(label: "org.telegram.QrStudioVideoExporter", qos: .userInitiated)
    private let lock = NSLock()
    private var cancelled = false
    private var started = false

    var isCancelled: Bool {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.cancelled
    }

    init(scene: QrStudioExportScene, canvas: QrStudioExportCanvas = .story, frameCount: Int = QrStudioExportMotion.frameCount) {
        self.scene = scene
        self.canvas = canvas
        self.frameCount = frameCount
    }

    func cancel() {
        self.lock.lock()
        self.cancelled = true
        self.lock.unlock()
    }

    func start(progress: @escaping (Float) -> Void, completion: @escaping (URL?) -> Void) {
        guard !self.started else {
            return
        }
        self.started = true
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("qr-\(UInt64.random(in: 0 ... UInt64.max)).mp4")
        self.queue.async {
            let success = self.write(to: url, progress: { value in
                DispatchQueue.main.async {
                    progress(value)
                }
            })
            let isCancelled = self.isCancelled
            if !success || isCancelled {
                try? FileManager.default.removeItem(at: url)
            }
            let output: URL? = success && !isCancelled ? url : nil
            DispatchQueue.main.async {
                completion(output)
            }
        }
    }

    private func write(to url: URL, progress: @escaping (Float) -> Void) -> Bool {
        let pixel = self.canvas.pixelSize
        let width = Int(pixel.width)
        let height = Int(pixel.height)
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else {
            return false
        }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 8_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ] as [String: Any]
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ])
        guard writer.canAdd(input) else {
            return false
        }
        writer.add(input)
        guard writer.startWriting() else {
            return false
        }
        writer.startSession(atSourceTime: .zero)
        let fps = Int32(QrStudioExportMotion.fps)
        for index in 0 ..< self.frameCount {
            while !input.isReadyForMoreMediaData {
                if self.isCancelled || writer.status != .writing {
                    writer.cancelWriting()
                    return false
                }
                Thread.sleep(forTimeInterval: 0.002)
            }
            if self.isCancelled {
                writer.cancelWriting()
                return false
            }
            guard let pool = adaptor.pixelBufferPool else {
                writer.cancelWriting()
                return false
            }
            var pixelBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
            guard let buffer = pixelBuffer else {
                writer.cancelWriting()
                return false
            }
            CVPixelBufferLockBaseAddress(buffer, [])
            let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
            if let context {
                context.setFillColor(UIColor.black.cgColor)
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
                qrStudioDrawExportFrame(self.scene, canvas: self.canvas, time: Double(index) / Double(fps), in: context)
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            guard context != nil, adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(index), timescale: fps)) else {
                writer.cancelWriting()
                return false
            }
            progress(Float(index + 1) / Float(self.frameCount))
        }
        input.markAsFinished()
        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()
        return writer.status == .completed
    }
}
