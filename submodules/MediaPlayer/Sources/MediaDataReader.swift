import Foundation
import AVFoundation
import CoreMedia
import FFMpegBinding
import VideoToolbox
import Postbox

#if os(macOS)
public let internal_isHardwareAv1Supported: Bool = {
    let value = VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1)
    return value
}()
#endif

public enum MediaDataReaderReadSampleBufferResult {
    case frame(CMSampleBuffer)
    case waitingForMoreData
    case endOfStream
    case error
}

public protocol MediaDataReader: AnyObject {
    var hasVideo: Bool { get }
    var hasAudio: Bool { get }
        
    func readSampleBuffer() -> MediaDataReaderReadSampleBufferResult
}

public final class FFMpegMediaDataReaderV2: MediaDataReader {
    public enum Content {
        case tempFile(ChunkMediaPlayerPart.TempFile)
        case directStream(ChunkMediaPlayerPartsState.DirectReader.Stream)
    }
    
    private let content: Content
    private let isVideo: Bool
    private let videoSource: FFMpegFileReader?
    private let audioSource: FFMpegFileReader?
    
    public var hasVideo: Bool {
        return self.videoSource != nil
    }
    
    public var hasAudio: Bool {
        return self.audioSource != nil
    }
    
    public init(content: Content, isVideo: Bool, codecName: String?) {
        self.content = content
        self.isVideo = isVideo
        
        let source: FFMpegFileReader.SourceDescription
        var seek: FFMpegFileReader.Seek?
        var maxReadablePts: (streamIndex: Int, pts: Int64, isEnded: Bool)?
        switch content {
        case let .tempFile(tempFile):
            source = .file(tempFile.file.path)
        case let .directStream(directStream):
            let mappedRanges: [Range<Int64>]
            #if DEBUG && false
            var mappedRangesValue: [Range<Int64>] = []
            var testOffset: Int64 = 0
            while testOffset < directStream.size {
                let testBlock: Int64 = min(3 * 1024 + 1, directStream.size - testOffset)
                mappedRangesValue.append(testOffset ..< (testOffset + testBlock))
                testOffset += testBlock
            }
            mappedRanges = mappedRangesValue
            #else
            mappedRanges = [0 ..< directStream.size]
            #endif
            source = .resource(mediaBox: directStream.mediaBox, resource: directStream.resource, resourceSize: directStream.size, mappedRanges: mappedRanges)
            seek = .stream(streamIndex: directStream.seek.streamIndex, pts: directStream.seek.pts)
            maxReadablePts = directStream.maxReadablePts
        }
        
        if self.isVideo {
            var passthroughDecoder = true
            var useHardwareAcceleration = false
            
            if (codecName == "h264" || codecName == "hevc") {
                passthroughDecoder = false
                #if targetEnvironment(simulator)
                useHardwareAcceleration = false
                #else
                useHardwareAcceleration = true
                #endif
            }
            if (codecName == "av1" || codecName == "av01") {
                passthroughDecoder = false
                useHardwareAcceleration = internal_isHardwareAv1Supported
            }
            if codecName == "vp9" || codecName == "vp8" {
                passthroughDecoder = false
            }
            
            /*#if DEBUG
            if codecName == "h264" {
                passthroughDecoder = false
                useHardwareAcceleration = true
            }
            #endif*/
            
            if let videoSource = FFMpegFileReader(source: source, passthroughDecoder: passthroughDecoder, useHardwareAcceleration: useHardwareAcceleration, selectedStream: .mediaType(.video), seek: seek, maxReadablePts: maxReadablePts) {
                self.videoSource = videoSource
            } else {
                self.videoSource = nil
            }
            self.audioSource = nil
        } else {
            if let audioSource = FFMpegFileReader(source: source, passthroughDecoder: false, useHardwareAcceleration: false, selectedStream: .mediaType(.audio), seek: seek, maxReadablePts: maxReadablePts) {
                self.audioSource = audioSource
            } else {
                self.audioSource = nil
            }
            self.videoSource = nil
        }
    }
    
    public func update(content: Content) {
        guard case let .directStream(directStream) = content else {
            return
        }
        if let audioSource = self.audioSource {
            audioSource.updateMaxReadablePts(pts: directStream.maxReadablePts)
        } else if let videoSource = self.videoSource {
            videoSource.updateMaxReadablePts(pts: directStream.maxReadablePts)
        }
    }
    
    public func readSampleBuffer() -> MediaDataReaderReadSampleBufferResult {
        if let videoSource {
            switch videoSource.readFrame() {
            case let .frame(frame):
                return .frame(frame.sampleBuffer)
            case .waitingForMoreData:
                return .waitingForMoreData
            case .endOfStream:
                return .endOfStream
            case .error:
                return .error
            }
        } else if let audioSource {
            switch audioSource.readFrame() {
            case let .frame(frame):
                return .frame(frame.sampleBuffer)
            case .waitingForMoreData:
                return .waitingForMoreData
            case .endOfStream:
                return .endOfStream
            case .error:
                return .error
            }
        } else {
            return .endOfStream
        }
    }
}

public final class FFMpegMediaDataReaderV1: MediaDataReader {
    private let isVideo: Bool
    private let videoSource: SoftwareVideoReader?
    private let audioSource: SoftwareAudioSource?
    
    public var hasVideo: Bool {
        return self.videoSource != nil
    }
    
    public var hasAudio: Bool {
        return self.audioSource != nil
    }
    
    public init(filePath: String, isVideo: Bool, codecName: String?) {
        self.isVideo = isVideo
        
        if self.isVideo {
            var passthroughDecoder = true
            if (codecName == "av1" || codecName == "av01") && !internal_isHardwareAv1Supported {
                passthroughDecoder = false
            }
            let videoSource = SoftwareVideoReader(path: filePath, hintVP9: false, passthroughDecoder: passthroughDecoder)
            if videoSource.hasStream {
                self.videoSource = videoSource
            } else {
                self.videoSource = nil
            }
            self.audioSource = nil
        } else {
            let audioSource = SoftwareAudioSource(path: filePath)
            if audioSource.hasStream {
                self.audioSource = audioSource
            } else {
                self.audioSource = nil
            }
            self.videoSource = nil
        }
    }
    
    public func readSampleBuffer() -> MediaDataReaderReadSampleBufferResult {
        if let videoSource {
            let frame = videoSource.readFrame()
            if let frame {
                return .frame(frame.sampleBuffer)
            } else {
                return .endOfStream
            }
        } else if let audioSource {
            if let sampleBuffer = audioSource.readSampleBuffer() {
                return .frame(sampleBuffer)
            } else {
                return .endOfStream
            }
        } else {
            return .endOfStream
        }
    }
}

public final class AVAssetVideoDataReader: MediaDataReader {
    private let isVideo: Bool
    private var mediaInfo: FFMpegMediaInfo.Info?
    private var assetReader: AVAssetReader?
    private var assetOutput: AVAssetReaderOutput?
    
    public var hasVideo: Bool {
        return self.assetOutput != nil
    }
    
    public var hasAudio: Bool {
        return false
    }
    
    public init(filePath: String, isVideo: Bool) {
        self.isVideo = isVideo
        
        if self.isVideo {
            guard let video = extractFFMpegMediaInfo(path: filePath)?.video else {
                return
            }
            self.mediaInfo = video
            
            let asset = AVURLAsset(url: URL(fileURLWithPath: filePath))
            guard let assetReader = try? AVAssetReader(asset: asset) else {
                return
            }
            guard let videoTrack = asset.tracks(withMediaType: .video).first else {
                return
            }
            let videoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange])
            assetReader.add(videoOutput)
            if assetReader.startReading() {
                self.assetReader = assetReader
                self.assetOutput = videoOutput
            }
        }
    }
    
    public func readSampleBuffer() -> MediaDataReaderReadSampleBufferResult {
        guard let mediaInfo = self.mediaInfo, let assetReader = self.assetReader, let assetOutput = self.assetOutput else {
            return .endOfStream
        }
        var retryCount = 0
        while true {
            if let sampleBuffer = assetOutput.copyNextSampleBuffer() {
                if let convertedSampleBuffer = createSampleBuffer(fromSampleBuffer: sampleBuffer, withTimeOffset: mediaInfo.startTime, duration: nil) {
                    return .frame(convertedSampleBuffer)
                } else {
                    return .endOfStream
                }
            } else if assetReader.status == .reading && retryCount < 100 {
                Thread.sleep(forTimeInterval: 1.0 / 60.0)
                retryCount += 1
            } else {
                break
            }
        }
        
        return .endOfStream
    }
}

private func createSampleBuffer(fromSampleBuffer sampleBuffer: CMSampleBuffer, withTimeOffset timeOffset: CMTime, duration: CMTime?) -> CMSampleBuffer? {
    var itemCount: CMItemCount = 0
    var status = CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, entryCount: 0, arrayToFill: nil, entriesNeededOut: &itemCount)
    if status != 0 {
        return nil
    }
    
    var timingInfo = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(duration: CMTimeMake(value: 0, timescale: 0), presentationTimeStamp: CMTimeMake(value: 0, timescale: 0), decodeTimeStamp: CMTimeMake(value: 0, timescale: 0)), count: itemCount)
    status = CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, entryCount: itemCount, arrayToFill: &timingInfo, entriesNeededOut: &itemCount)
    if status != 0 {
        return nil
    }
    
    if let dur = duration {
        for i in 0 ..< itemCount {
            timingInfo[i].decodeTimeStamp = CMTimeAdd(timingInfo[i].decodeTimeStamp, timeOffset)
            timingInfo[i].presentationTimeStamp = CMTimeAdd(timingInfo[i].presentationTimeStamp, timeOffset)
            timingInfo[i].duration = dur
        }
    } else {
        for i in 0 ..< itemCount {
            timingInfo[i].decodeTimeStamp = CMTimeAdd(timingInfo[i].decodeTimeStamp, timeOffset)
            timingInfo[i].presentationTimeStamp = CMTimeAdd(timingInfo[i].presentationTimeStamp, timeOffset)
        }
    }
    
    var sampleBufferOffset: CMSampleBuffer?
    CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault, sampleBuffer: sampleBuffer, sampleTimingEntryCount: itemCount, sampleTimingArray: &timingInfo, sampleBufferOut: &sampleBufferOffset)
    
    if let output = sampleBufferOffset {
        return output
    } else {
        return nil
    }
}
