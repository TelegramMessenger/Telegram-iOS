import Foundation
import AVFoundation
import CoreMedia
import FFMpegBinding
import VideoToolbox

#if os(macOS)
private let isHardwareAv1Supported: Bool = {
    let value = VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1)
    return value
}()
#endif

public protocol MediaDataReader: AnyObject {
    var hasVideo: Bool { get }
    var hasAudio: Bool { get }
        
    func readSampleBuffer() -> CMSampleBuffer?
}

public final class FFMpegMediaDataReader: MediaDataReader {
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
    
    public func readSampleBuffer() -> CMSampleBuffer? {
        if let videoSource {
            let frame = videoSource.readFrame()
            if let frame {
                return frame.sampleBuffer
            } else {
                return nil
            }
        } else if let audioSource {
            return audioSource.readSampleBuffer()
        }
        
        return nil
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
    
    public func readSampleBuffer() -> CMSampleBuffer? {
        guard let mediaInfo = self.mediaInfo, let assetReader = self.assetReader, let assetOutput = self.assetOutput else {
            return nil
        }
        var retryCount = 0
        while true {
            if let sampleBuffer = assetOutput.copyNextSampleBuffer() {
                return createSampleBuffer(fromSampleBuffer: sampleBuffer, withTimeOffset: mediaInfo.startTime, duration: nil)
            } else if assetReader.status == .reading && retryCount < 100 {
                Thread.sleep(forTimeInterval: 1.0 / 60.0)
                retryCount += 1
            } else {
                break
            }
        }
        
        return nil
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
