import TelegramUIPrivateModule
import CoreMedia

final class FFMpegMediaVideoFrameDecoder: MediaTrackFrameDecoder {
    private let codecContext: UnsafeMutablePointer<AVCodecContext>
    
    private let videoFrame: UnsafeMutablePointer<AVFrame>
    private var resetDecoderOnNextFrame = true
    
    init(codecContext: UnsafeMutablePointer<AVCodecContext>) {
        self.codecContext = codecContext
        self.videoFrame = av_frame_alloc()
    }
    
    deinit {
        av_frame_unref(self.videoFrame)
        
        var codecContextRef: UnsafeMutablePointer<AVCodecContext>? = codecContext
        avcodec_free_context(&codecContextRef)
    }
    
    func decode(frame: MediaTrackDecodableFrame) -> MediaTrackFrame? {
        var status = avcodec_send_packet(self.codecContext, frame.packet)
        if status == 0 {
            status = avcodec_receive_frame(self.codecContext, self.videoFrame)
            if status == 0 {
                return convertVideoFrame(self.videoFrame, pts: frame.pts, duration: frame.duration)
            }
        }
        
        return nil
    }
    
    private func convertVideoFrame(_ frame: UnsafeMutablePointer<AVFrame>, pts: CMTime, duration: CMTime) -> MediaTrackFrame? {
        return nil
    }
    
    func reset() {
        avcodec_flush_buffers(self.codecContext)
        self.resetDecoderOnNextFrame = true
    }
}
