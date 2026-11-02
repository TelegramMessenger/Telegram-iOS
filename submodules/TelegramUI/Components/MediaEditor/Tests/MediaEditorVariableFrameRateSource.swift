import Foundation
import AVFoundation
import CoreVideo

enum MediaEditorVariableFrameRateSource {
    static let frameTimes: [Double] = {
        let gaps: [Double] = [1.0 / 60.0, 1.0 / 30.0, 0.1, 0.25, 0.5, 1.0 / 60.0, 1.0 / 60.0, 0.017]
        var times: [Double] = []
        var time = 0.0
        var index = 0
        while time < 8.0 {
            times.append(time)
            time += index < 40 ? 1.0 / 60.0 : gaps[index % gaps.count]
            index += 1
        }
        return times
    }()

    static func url() -> URL? {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("variable-frame-rate.mp4")
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        return generate(to: url) ? url : nil
    }

    private static func sourceFrames() -> [CVPixelBuffer] {
        let asset = AVURLAsset(url: MediaEditorExportFixtures.url("video-portrait.mp4"))
        guard let track = asset.tracks(withMediaType: .video).first, let reader = try? AVAssetReader(asset: asset) else {
            return []
        }
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        reader.add(output)
        reader.startReading()
        var frames: [CVPixelBuffer] = []
        while let sampleBuffer = output.copyNextSampleBuffer() {
            if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                frames.append(pixelBuffer)
            }
        }
        return frames
    }

    private static func generate(to url: URL) -> Bool {
        let frames = sourceFrames()
        guard let first = frames.first else {
            return false
        }
        let temporaryUrl = url.deletingLastPathComponent().appendingPathComponent("variable-frame-rate-partial.mp4")
        try? FileManager.default.removeItem(at: temporaryUrl)
        guard let writer = try? AVAssetWriter(outputURL: temporaryUrl, fileType: .mp4) else {
            return false
        }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: CVPixelBufferGetWidth(first),
            AVVideoHeightKey: CVPixelBufferGetHeight(first)
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        writer.add(input)
        guard writer.startWriting() else {
            return false
        }
        writer.startSession(atSourceTime: .zero)
        for (index, time) in frameTimes.enumerated() {
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.002)
            }
            if !adaptor.append(frames[index % frames.count], withPresentationTime: CMTime(seconds: time, preferredTimescale: 600000)) {
                return false
            }
        }
        input.markAsFinished()
        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()
        guard writer.status == .completed else {
            return false
        }
        return (try? FileManager.default.moveItem(at: temporaryUrl, to: url)) != nil
    }
}
