import Foundation
import UIKit
import AVFoundation
import Metal
import SwiftSignalKit
import Postbox
import TelegramCore
@testable import MediaEditor

struct MediaEditorExportRun {
    let totalSeconds: Double
    let compositionSeconds: [Double]
    let frames: [Int: CGImage]
    let outputPath: String?
    let frameCount: Int
    let outputDimensions: CGSize?
    let expectedDuration: Double?
    let frameDuration: Double?
    let error: String?
}

struct MediaEditorDecodedVideo {
    let frameCount: Int
    let dimensions: CGSize
    let duration: Double
    let frames: [Int: CGImage]
    let lastFrame: CGImage?
}

private final class LockedValue<T> {
    private let lock = NSLock()
    private var value: T

    init(_ value: T) {
        self.value = value
    }

    func with<R>(_ f: (inout T) -> R) -> R {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return f(&self.value)
    }
}

enum MediaEditorExportRunner {
    static let exportTimeout: Double = 300.0

    static func makePostbox() -> Postbox? {
        let basePath = NSTemporaryDirectory() + "MediaEditorExportPostbox-\(UUID().uuidString)"
        let encryptionParameters = ValueBoxEncryptionParameters(
            forceEncryptionIfNoSet: false,
            key: ValueBoxEncryptionParameters.Key(data: Data(repeating: 0xA5, count: 32))!,
            salt: ValueBoxEncryptionParameters.Salt(data: Data(repeating: 0x5A, count: 16))!
        )
        let semaphore = DispatchSemaphore(value: 0)
        let result = LockedValue<Postbox?>(nil)
        let disposable = openPostbox(
            basePath: basePath,
            seedConfiguration: telegramPostboxSeedConfiguration,
            encryptionParameters: encryptionParameters,
            timestampForAbsoluteTimeBasedOperations: Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970),
            isMainProcess: true,
            isTemporary: true,
            isReadOnly: false,
            useCopy: false,
            useCaches: false,
            removeDatabaseOnError: true
        ).start(next: { value in
            switch value {
            case let .postbox(postbox):
                result.with { $0 = postbox }
                semaphore.signal()
            case .error:
                semaphore.signal()
            case .upgrading:
                break
            }
        })
        let _ = semaphore.wait(timeout: .now() + 30.0)
        disposable.dispose()
        return result.with { $0 }
    }

    static func run(_ scenario: MediaEditorExportScenario, postbox: Postbox, capturesFrames: Bool = true) -> MediaEditorExportRun {
        switch scenario.makeInputs(postbox: postbox) {
        case let .video(subject, configuration, textScale, expectedFrameCount, expectedDuration):
            return self.runExport(id: scenario.id, postbox: postbox, subject: subject, configuration: configuration, textScale: textScale, expectedFrameCount: expectedFrameCount, expectedDuration: expectedDuration, capturesFrames: capturesFrames)
        case let .photoStory(image, values, dimensions, textScale):
            return self.runPhoto(image: image) { input, completion in
                makeEditorImageComposition(postbox: postbox, input: input, dimensions: dimensions, values: values, time: .zero, textScale: textScale, completion: completion)
            }
        case let .photoChat(image, values, maxOutputSide):
            return self.runPhoto(image: image) { input, completion in
                makeChatEditorImageComposition(postbox: postbox, input: input, values: values, time: .zero, maxOutputSide: maxOutputSide, completion: completion)
            }
        case let .unavailable(reason):
            return self.failedRun(reason)
        }
    }

    private static func failedRun(_ error: String) -> MediaEditorExportRun {
        return MediaEditorExportRun(totalSeconds: 0.0, compositionSeconds: [], frames: [:], outputPath: nil, frameCount: 0, outputDimensions: nil, expectedDuration: nil, frameDuration: nil, error: error)
    }

    private static func runPhoto(image: UIImage, compose: (MediaEditorCompositionInput, @escaping (UIImage?) -> Void) -> Void) -> MediaEditorExportRun {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return self.failedRun("no Metal device")
        }
        guard let texture = loadTexture(image: image, device: device) else {
            return self.failedRun("cannot upload the input texture")
        }

        let startTime = CACurrentMediaTime()
        let compositionStartTime = startTime
        let outcome = LockedValue<(UIImage?, Double)?>(nil)
        let semaphore = DispatchSemaphore(value: 0)
        compose(.editorResult(texture), { image in
            outcome.with { $0 = (image, CACurrentMediaTime()) }
            semaphore.signal()
        })
        if Thread.isMainThread {
            let deadline = Date(timeIntervalSinceNow: self.exportTimeout)
            while outcome.with({ $0 }) == nil && Date() < deadline {
                RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
            }
        } else {
            let _ = semaphore.wait(timeout: .now() + self.exportTimeout)
        }
        let totalSeconds = CACurrentMediaTime() - startTime
        guard case let (result, compositionEndTime)? = outcome.with({ $0 }) else {
            return self.failedRun("photo composition timed out")
        }
        guard let cgImage = result?.cgImage else {
            return self.failedRun("photo composition returned no image")
        }
        return MediaEditorExportRun(
            totalSeconds: totalSeconds,
            compositionSeconds: [compositionEndTime - compositionStartTime],
            frames: [0: cgImage],
            outputPath: nil,
            frameCount: 1,
            outputDimensions: CGSize(width: cgImage.width, height: cgImage.height),
            expectedDuration: nil,
            frameDuration: nil,
            error: nil
        )
    }

    private static func runExport(id: String, postbox: Postbox, subject: MediaEditorVideoExport.Subject, configuration: MediaEditorVideoExport.Configuration, textScale: CGFloat, expectedFrameCount: Int, expectedDuration: Double, capturesFrames: Bool) -> MediaEditorExportRun {
        let directory = NSTemporaryDirectory() + "MediaEditorExportRuns"
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let outputPath = directory + "/\(id).\(configuration.isSticker ? "webm" : "mp4")"
        try? FileManager.default.removeItem(atPath: outputPath)

        let middleIndex = expectedFrameCount / 2
        let compositionSeconds = LockedValue<[Double]>([])
        let frames = LockedValue<[Int: CGImage]>([:])
        let lastFrame = LockedValue<(Int, CGImage)?>(nil)
        let frameCount = LockedValue<Int>(0)
        let outcome = LockedValue<String?>(nil)
        let semaphore = DispatchSemaphore(value: 0)

        let startTime = CACurrentMediaTime()
        let compositionObserver: (Double) -> Void = { seconds in
            compositionSeconds.with { $0.append(seconds) }
        }
        let frameObserver: (CVPixelBuffer, CMTime) -> Void = { pixelBuffer, _ in
            let index = frameCount.with { value -> Int in
                let index = value
                value += 1
                return index
            }
            guard capturesFrames, let image = cgImage(from: pixelBuffer) else {
                return
            }
            DispatchQueue.main.sync {
            }
            if index == 0 || index == middleIndex {
                frames.with { $0[index] = image }
            }
            lastFrame.with { $0 = (index, image) }
        }
        let export = MediaEditorVideoExport(postbox: postbox, subject: subject, configuration: configuration, outputPath: outputPath, textScale: textScale, debugFrameObserver: frameObserver, debugCompositionTimeObserver: compositionObserver)
        let disposable = export.status.start(next: { status in
            switch status {
            case .completed:
                outcome.with { $0 = "completed" }
                semaphore.signal()
            case let .failed(error):
                outcome.with { $0 = "failed: \(error)" }
                semaphore.signal()
            default:
                break
            }
        })
        let timedOut = semaphore.wait(timeout: .now() + self.exportTimeout) == .timedOut
        let totalSeconds = CACurrentMediaTime() - startTime
        disposable.dispose()
        if timedOut {
            export.cancel()
            return self.failedRun("export timed out")
        }
        if let outcome = outcome.with({ $0 }), outcome != "completed" {
            return self.failedRun("export \(outcome)")
        }

        var capturedFrames = frames.with { $0 }
        if case let (index, image)? = lastFrame.with({ $0 }) {
            capturedFrames[index] = image
        }
        return MediaEditorExportRun(
            totalSeconds: totalSeconds,
            compositionSeconds: compositionSeconds.with { $0 },
            frames: capturedFrames,
            outputPath: outputPath,
            frameCount: frameCount.with { $0 },
            outputDimensions: configuration.dimensions,
            expectedDuration: expectedDuration,
            frameDuration: 1.0 / Double(configuration.frameRate),
            error: nil
        )
    }

    static func decodeVideo(path: String, frameIndices: Set<Int>) -> MediaEditorDecodedVideo? {
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        guard let track = asset.tracks(withMediaType: .video).first, let reader = try? AVAssetReader(asset: asset) else {
            return nil
        }
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        output.alwaysCopiesSampleData = true
        guard reader.canAdd(output) else {
            return nil
        }
        reader.add(output)
        guard reader.startReading() else {
            return nil
        }
        var count = 0
        var dimensions = CGSize()
        var frames: [Int: CGImage] = [:]
        var lastPixelBuffer: CVPixelBuffer?
        while let sampleBuffer = output.copyNextSampleBuffer() {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                continue
            }
            dimensions = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
            if frameIndices.contains(count), let image = cgImage(from: pixelBuffer) {
                frames[count] = image
            }
            lastPixelBuffer = pixelBuffer
            count += 1
        }
        guard reader.status == .completed else {
            return nil
        }
        return MediaEditorDecodedVideo(frameCount: count, dimensions: dimensions, duration: asset.duration.seconds, frames: frames, lastFrame: lastPixelBuffer.flatMap { cgImage(from: $0) })
    }
}
