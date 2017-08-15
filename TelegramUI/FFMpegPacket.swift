import Foundation
import TelegramUIPrivateModule

final class FFMpegPacket {
    var packet = AVPacket()
    
    init() {
        av_init_packet(&self.packet)
    }
    
    deinit {
        av_packet_unref(&self.packet)
    }
    
    var pts: Int64 {
        let avNoPtsRawValue: UInt64 = 0x8000000000000000
        let avNoPtsValue = Int64(bitPattern: avNoPtsRawValue)
        let packetPts = self.packet.pts == avNoPtsValue ? self.packet.dts : self.packet.pts
        
        return packetPts
    }
    
    func sendToDecoder(_ codecContext: UnsafeMutablePointer<AVCodecContext>) -> Int32 {
        return avcodec_send_packet(codecContext, &self.packet)
    }
}
