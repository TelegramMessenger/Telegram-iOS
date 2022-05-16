import Foundation
import CoreMedia
import FFMpegBinding

final class FFMpegAudioFrameDecoder: MediaTrackFrameDecoder {
    private let codecContext: FFMpegAVCodecContext
    private let swrContext: FFMpegSWResample
    
    private let audioFrame: FFMpegAVFrame
    private var resetDecoderOnNextFrame = true
    
    private let formatDescription: CMAudioFormatDescription
    
    private var delayedFrames: [MediaTrackFrame] = []
    
    init(codecContext: FFMpegAVCodecContext, sampleRate: Int = 44100, channelCount: Int = 2) {
        self.codecContext = codecContext
        self.audioFrame = FFMpegAVFrame()
        
        self.swrContext = FFMpegSWResample(sourceChannelCount: Int(codecContext.channels()), sourceSampleRate: Int(codecContext.sampleRate()), sourceSampleFormat: codecContext.sampleFormat(), destinationChannelCount: channelCount, destinationSampleRate: sampleRate, destinationSampleFormat: FFMPEG_AV_SAMPLE_FMT_S16)
        
        var outputDescription = AudioStreamBasicDescription(
            mSampleRate: Float64(sampleRate),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked,
            mBytesPerPacket: UInt32(2 * channelCount),
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(2 * channelCount),
            mChannelsPerFrame: UInt32(channelCount),
            mBitsPerChannel: 16,
            mReserved: 0
        )
        
        var channelLayout = AudioChannelLayout()
        memset(&channelLayout, 0, MemoryLayout<AudioChannelLayout>.size)
        channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Mono
        
        var formatDescription: CMAudioFormatDescription?
        CMAudioFormatDescriptionCreate(allocator: nil, asbd: &outputDescription, layoutSize: MemoryLayout<AudioChannelLayout>.size, layout: &channelLayout, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &formatDescription)
        
        self.formatDescription = formatDescription!
    }
    
    func decodeRaw(frame: MediaTrackDecodableFrame) -> Data? {
        let status = frame.packet.send(toDecoder: self.codecContext)
        if status == 0 {
            let result = self.codecContext.receive(into: self.audioFrame)
            if case .success = result {
                guard let data = self.swrContext.resample(self.audioFrame) else {
                    return nil
                }
                
                return data
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    func decode(frame: MediaTrackDecodableFrame) -> MediaTrackFrame? {
        let status = frame.packet.send(toDecoder: self.codecContext)
        if status == 0 {
            while true {
                let result = self.codecContext.receive(into: self.audioFrame)
                if case .success = result {
                    if let convertedFrame = convertAudioFrame(self.audioFrame, pts: frame.pts, duration: frame.duration) {
                        self.delayedFrames.append(convertedFrame)
                    }
                } else {
                    break
                }
            }
            
            if self.delayedFrames.count >= 1 {
                var minFrameIndex = 0
                var minPosition = self.delayedFrames[0].position
                for i in 1 ..< self.delayedFrames.count {
                    if CMTimeCompare(self.delayedFrames[i].position, minPosition) < 0 {
                        minFrameIndex = i
                        minPosition = self.delayedFrames[i].position
                    }
                }
                return self.delayedFrames.remove(at: minFrameIndex)
            }
        }
        
        return nil
    }
    
    func takeQueuedFrame() -> MediaTrackFrame? {
        if self.delayedFrames.count >= 1 {
            var minFrameIndex = 0
            var minPosition = self.delayedFrames[0].position
            for i in 1 ..< self.delayedFrames.count {
                if CMTimeCompare(self.delayedFrames[i].position, minPosition) < 0 {
                    minFrameIndex = i
                    minPosition = self.delayedFrames[i].position
                }
            }
            return self.delayedFrames.remove(at: minFrameIndex)
        } else {
            return nil
        }
    }
    
    func takeRemainingFrame() -> MediaTrackFrame? {
        if !self.delayedFrames.isEmpty {
            var minFrameIndex = 0
            var minPosition = self.delayedFrames[0].position
            for i in 1 ..< self.delayedFrames.count {
                if CMTimeCompare(self.delayedFrames[i].position, minPosition) < 0 {
                    minFrameIndex = i
                    minPosition = self.delayedFrames[i].position
                }
            }
            return self.delayedFrames.remove(at: minFrameIndex)
        } else {
            return nil
        }
    }
    
    private func convertAudioFrame(_ frame: FFMpegAVFrame, pts: CMTime, duration: CMTime) -> MediaTrackFrame? {
        guard let data = self.swrContext.resample(frame) else {
            return nil
        }
        
        var blockBuffer: CMBlockBuffer?
        
        let bytes = malloc(data.count)!
        data.copyBytes(to: bytes.assumingMemoryBound(to: UInt8.self), count: data.count)
        let status = CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: bytes, blockLength: data.count, blockAllocator: nil, customBlockSource: nil, offsetToData: 0, dataLength: data.count, flags: 0, blockBufferOut: &blockBuffer)
        if status != noErr {
            return nil
        }
        
        //var timingInfo = CMSampleTimingInfo(duration: duration, presentationTimeStamp: pts, decodeTimeStamp: pts)
        var sampleBuffer: CMSampleBuffer?
        //var sampleSize = data.count
        
        guard CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: nil, dataBuffer: blockBuffer!, formatDescription: self.formatDescription, sampleCount: Int(data.count / 2), presentationTimeStamp: pts, packetDescriptions: nil, sampleBufferOut: &sampleBuffer) == noErr else {
            return nil
        }
        
        /*guard CMSampleBufferCreate(allocator: nil, dataBuffer: blockBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: self.formatDescription, sampleCount: Int(frame.duration), sampleTimingEntryCount: 1, sampleTimingArray: &timingInfo, sampleSizeEntryCount: 1, sampleSizeArray: &sampleSize, sampleBufferOut: &sampleBuffer) == noErr else {
            return nil
        }*/
        
        let resetDecoder = self.resetDecoderOnNextFrame
        self.resetDecoderOnNextFrame = false
        
        return MediaTrackFrame(type: .audio, sampleBuffer: sampleBuffer!, resetDecoder: resetDecoder, decoded: true)
    }
    
    func reset() {
        self.codecContext.flushBuffers()
        self.resetDecoderOnNextFrame = true
    }
}
