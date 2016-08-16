import Foundation
import TelegramCorePrivate

final class FFMpegAudioFrameDecoder: MediaTrackFrameDecoder {
    private let codecContext: UnsafeMutablePointer<AVCodecContext>
    private let swrContext: FFMpegSwResample
    
    private let audioFrame: UnsafeMutablePointer<AVFrame>
    private var resetDecoderOnNextFrame = true
    
    init(codecContext: UnsafeMutablePointer<AVCodecContext>) {
        self.codecContext = codecContext
        self.audioFrame = av_frame_alloc()
        
        
        self.swrContext = FFMpegSwResample(sourceChannelCount: Int(codecContext.pointee.channels), sourceSampleRate: Int(codecContext.pointee.sample_rate), sourceSampleFormat: codecContext.pointee.sample_fmt, destinationChannelCount: 2, destinationSampleRate: 44100, destinationSampleFormat: AV_SAMPLE_FMT_S16)
    }
    
    deinit {
        av_frame_unref(self.audioFrame)
        
        var codecContextRef: UnsafeMutablePointer<AVCodecContext>? = codecContext
        avcodec_free_context(&codecContextRef)
    }
    
    func decode(frame: MediaTrackDecodableFrame) -> MediaTrackFrame? {
        var status = avcodec_send_packet(self.codecContext, frame.packet)
        if status == 0 {
            status = avcodec_receive_frame(self.codecContext, self.audioFrame)
            if status == 0 {
                return convertAudioFrame(self.audioFrame, pts: frame.pts, duration: frame.duration)
            }
        }
        
        return nil
    }
    
    private func convertAudioFrame(_ frame: UnsafeMutablePointer<AVFrame>, pts: CMTime, duration: CMTime) -> MediaTrackFrame? {
        guard let data = self.swrContext.resample(frame) else {
            return nil
        }
        
        var blockBuffer: CMBlockBuffer?
        
        let bytes = malloc(data.count)!
        data.copyBytes(to: UnsafeMutablePointer<UInt8>(bytes), count: data.count)
        let status = CMBlockBufferCreateWithMemoryBlock(nil, UnsafeMutablePointer(bytes), data.count, nil, nil, 0, data.count, 0, &blockBuffer)
        if status != noErr {
            return nil
        }
        
        var timingInfo = CMSampleTimingInfo(duration: duration, presentationTimeStamp: pts, decodeTimeStamp: pts)
        var sampleBuffer: CMSampleBuffer?
        var sampleSize = data.count
        guard CMSampleBufferCreate(nil, blockBuffer, true, nil, nil, nil, 1, 1, &timingInfo, 1, &sampleSize, &sampleBuffer) == noErr else {
            return nil
        }
        
        let resetDecoder = self.resetDecoderOnNextFrame
        self.resetDecoderOnNextFrame = false
        
        return MediaTrackFrame(type: .audio, sampleBuffer: sampleBuffer!, resetDecoder: resetDecoder)
    }
    
    func reset() {
        avcodec_flush_buffers(self.codecContext)
        self.resetDecoderOnNextFrame = true
    }
}
